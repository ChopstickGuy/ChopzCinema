// Forward-lit geometry drawn after the deferred pass.
// Everything goes into colortex6 (alpha blended over a cleared buffer) and is
// composited over the lit scene in composite.fsh.
// Variants: WATER_PASS, DH_WATER, PARTICLES, WEATHER, HAND, EMISSIVE_ONLY, GLINT, LINE, CLOUDS

#include "/lib/common.glsl"
#include "/lib/atmosphere.glsl"
#include "/lib/waving.glsl"
#if defined WATER_PASS || defined HAND
#include "/lib/shadows.glsl"
#else
#define NO_SHADOWMAP
#endif
#include "/lib/lighting.glsl"
#include "/lib/water.glsl"

#ifdef VERTEX
// ============================================================== VERTEX
in vec4 mc_Entity;

out vec2 texcoord;
out vec2 lmcoord;
out vec4 tint;
out vec3 worldNormal;
out vec3 playerPos;
flat out int blockId;
flat out vec3 lightColor;
flat out vec3 skyAmbient;
flat out vec3 lightDir;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
#ifdef DH_WATER
    lmcoord = clamp(((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy - 0.03125) * 1.06667, 0.0, 1.0);
    blockId = dhMaterialId == DH_BLOCK_WATER ? ID_WATER : 0;
#else
    lmcoord = clamp((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy * (33.05 / 32.0) - (1.05 / 32.0), 0.0, 1.0);
    blockId = int(mc_Entity.x + 0.5);
#endif
    tint = gl_Color;

    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    playerPos = (gbufferModelViewInverse * viewPos).xyz;
#ifdef DH_WATER
    gl_Position = jitterPosition(dhProjection * viewPos);
#elif defined CLOUDS
    gl_Position = gl_ProjectionMatrix * viewPos;
#else
    gl_Position = jitterPosition(gl_ProjectionMatrix * viewPos);
#endif
    worldNormal = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * gl_Normal);

    vec3 sunDir = sunDirWorld();
    lightDir = lightDirWorld();
    getFrameLighting(sunDir, lightColor, skyAmbient);
}

#else
// ============================================================== FRAGMENT
in vec2 texcoord;
in vec2 lmcoord;
in vec4 tint;
in vec3 worldNormal;
in vec3 playerPos;
flat in int blockId;
flat in vec3 lightColor;
flat in vec3 skyAmbient;
flat in vec3 lightDir;

uniform sampler2D gtexture;
uniform int biome_precipitation;

#if defined WATER_PASS || defined DH_WATER
/* RENDERTARGETS: 6,4 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outTranslucent;
#else
/* RENDERTARGETS: 6 */
layout(location = 0) out vec4 outColor;
#endif

void main() {
#if defined CLOUDS && defined VOLUMETRIC_CLOUDS
    discard;
#endif

#if defined DH_WATER || defined LINE
    vec4 albedo = tint;
#else
    vec4 albedo = texture(gtexture, texcoord) * tint;
#endif
    albedo.rgb = pow(albedo.rgb, vec3(2.2));

#ifdef DH_WATER
    // vanilla water covers the near area
    if (length(playerPos.xz) < far * 0.8) discard;
#endif

    float noise = ignAnimated(gl_FragCoord.xy);
    vec3 n = normalize(worldNormal);

#if defined WATER_PASS || defined DH_WATER
    int type = TR_OTHER;
    float smoothness = 0.35;
    if (blockId == ID_WATER) type = TR_WATER;
    else if (blockId == ID_GLASS) type = TR_GLASS;
    else if (blockId == ID_ICE) type = TR_ICE;

    if (type == TR_WATER) {
        vec3 wp = playerPos + cameraPosition;
        // waves only on (roughly) horizontal surfaces
        if (n.y > 0.5) {
            n = waterNormal(wp, length(playerPos));
            // raindrops hitting the surface
            vec2 rg = rainRipples(wp.xz) * smoothstep(0.85, 0.95, lmcoord.y) * smoothstep(40.0, 6.0, length(playerPos));
            n = normalize(n + vec3(-rg.x, 0.0, -rg.y));
        }
        else if (n.y < -0.5) n = -waterNormal(wp, length(playerPos));
        smoothness = 0.97;
        // water body colour is handled in composite (absorption + scattering),
        // optionally keep a bit of the vanilla texture
        vec3 texCol = albedo.rgb;
        Surface s = Surface(texCol, n, lmcoord, 0.0, 0.0, 0.0, 0.0, 1.0);
#ifdef DH_WATER
        vec3 lit = shadeSurface(s, playerPos, lightDir, lightColor, skyAmbient, noise, false);
#else
        vec3 lit = shadeSurface(s, playerPos, lightDir, lightColor, skyAmbient, noise, true);
#endif
        outColor = vec4(lit, WATER_TEXTURE * 0.35);
    } else {
        if (albedo.a < 0.01) discard;
        smoothness = type == TR_GLASS ? 0.95 : (type == TR_ICE ? 0.85 : 0.35);
        Surface s = Surface(albedo.rgb, n, lmcoord, smoothness * 0.5, 0.0, 0.0, 0.0, 1.0);
#ifdef DH_WATER
        vec3 lit = shadeSurface(s, playerPos, lightDir, lightColor, skyAmbient, noise, false);
#else
        vec3 lit = shadeSurface(s, playerPos, lightDir, lightColor, skyAmbient, noise, true);
#endif
        outColor = vec4(lit, albedo.a);
    }
    outTranslucent = vec4(encodeNormal(n), (float(type) + lmcoord.y * 0.8) / 8.0, smoothness);

#elif defined EMISSIVE_ONLY
    if (albedo.a < 0.01) discard;
    outColor = vec4(albedo.rgb * 3.0, albedo.a);

#elif defined GLINT
    // armor / item glint - additive look through alpha blending
    outColor = vec4(albedo.rgb * 1.5, luminance(albedo.rgb));

#elif defined LINE
    outColor = vec4(albedo.rgb * 0.5, albedo.a);

#else
    // particles, rain/snow, hand, vanilla clouds
    if (albedo.a < 0.1) discard;
#ifdef WEATHER
    // cinematic rain: thin, mostly transparent streaks that catch the light.
    // Backlit by the sun/moon they glow, near torches they turn warm.
    bool snow = biome_precipitation == 2;
    vec3 v = normalize(playerPos);
    float back = pow(saturate(dot(v, lightDir)), 6.0);
    vec3 streakLight = skyAmbient * 1.6 + lightColor * (0.12 + back * 2.5) * smoothstep(0.5, 0.9, lmcoord.y)
                     + blockLightAmount(lmcoord.x) * 1.5 + vec3(0.75, 0.8, 1.0) * lightningFlash() * 2.0;
    float a = albedo.a * (snow ? 0.6 : 0.2 * RAIN_STREAK_OPACITY);
    // keep streaks very faint right in front of the camera so they don't cover the view
    a *= smoothstep(0.5, 3.0, length(playerPos));
    vec3 tintCol = snow ? vec3(1.0) : vec3(0.85, 0.9, 1.0);
    outColor = vec4(tintCol * streakLight * (snow ? 0.8 : 1.0), a);
#else
#ifdef HAND
    Surface s = Surface(albedo.rgb, n, lmcoord, 0.0, 0.0, 0.0, 0.0, 1.0);
#else
    // particles face the camera, light them as if lit from all sides
    Surface s = Surface(albedo.rgb, normalize(lightDir + vec3(0.0, 0.5, 0.0)), lmcoord, 0.0, 0.0, 0.3, 0.0, 1.0);
#endif
#ifdef HAND
    vec3 lit = shadeSurface(s, playerPos, lightDir, lightColor, skyAmbient, noise, true);
#else
    vec3 lit = shadeSurface(s, playerPos, lightDir, lightColor, skyAmbient, noise, false);
#endif
    outColor = vec4(lit, albedo.a);
#endif
#endif
}
#endif

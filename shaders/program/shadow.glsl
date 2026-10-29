// Shadow map pass

#define SHADOW_PASS
#include "/lib/common.glsl"
#include "/lib/waving.glsl"
#include "/lib/shadows.glsl"

#ifdef VERTEX
in vec4 mc_Entity;
in vec2 mc_midTexCoord;

out vec2 texcoord;
out vec4 tint;
flat out int blockId;

uniform mat4 shadowModelViewInverse;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    tint = gl_Color;
    blockId = int(mc_Entity.x + 0.5);

    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
#if defined WAVING_PLANTS || defined WAVING_LEAVES
    if (blockId >= ID_LEAVES && blockId <= ID_PLANT_FULL) {
        vec3 playerPos = (shadowModelViewInverse * viewPos).xyz;
        float top = gl_MultiTexCoord0.y < mc_midTexCoord.y ? 1.0 : 0.0;
        float skyLm = clamp((gl_TextureMatrix[1] * gl_MultiTexCoord1).y * (33.05 / 32.0) - (1.05 / 32.0), 0.0, 1.0);
        vec3 worldPos = applyWaving(playerPos + cameraPosition, blockId, top, skyLm);
        viewPos = shadowModelView * vec4(worldPos - cameraPosition, 1.0);
    }
#endif
    vec4 clip = gl_ProjectionMatrix * viewPos;
    clip.xyz = distortShadow(clip.xyz);
    gl_Position = clip;
}

#else
in vec2 texcoord;
in vec4 tint;
flat in int blockId;

uniform sampler2D gtexture;

/* RENDERTARGETS: 0,1 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outWater; // x: water flag, z: depth of the water surface in the shadow map

void main() {
    vec4 albedo = texture(gtexture, texcoord) * tint;
    if (albedo.a < 0.1) discard;
    if (blockId == ID_WATER) {
        // water casts no shadow itself (white, no alpha) but marks where the surface is,
        // so lighting below can apply caustics and absorption along the light path
        outColor = vec4(1.0, 1.0, 1.0, 0.0);
        outWater = vec4(1.0, 0.0, gl_FragCoord.z, 1.0);
        return;
    }
    outColor = vec4(pow(albedo.rgb, vec3(2.2)), albedo.a);
    outWater = vec4(0.0);
}
#endif

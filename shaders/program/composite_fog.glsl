// composite2: apply atmospheric fog, ground mist, underwater fog and the light shafts -> colortex3

#include "/lib/common.glsl"

#ifdef VERTEX
#include "/program/fullscreen_vertex.glsl"
#else
#include "/lib/atmosphere.glsl"
#include "/lib/depth.glsl"
#include "/lib/fog.glsl"
#include "/lib/water.glsl"
#include "/lib/leaves.glsl"
#include "/program/fullscreen_frag_header.glsl"

uniform sampler2D colortex3;
uniform sampler2D colortex7;

/* RENDERTARGETS: 3 */
layout(location = 0) out vec4 outColor;

// bilinear upsample of the half resolution volume buffer incl. transmittance
vec4 upsampleVolume(vec2 uv) {
    vec2 halfSize = screenSize() * 0.5;
    vec2 p = uv * halfSize - 0.5;
    vec2 base = floor(p);
    vec2 f = p - base;
    vec4 sum = vec4(0.0);
    float wsum = 0.0;
    for (int i = 0; i < 4; i++) {
        vec2 o = vec2(i & 1, i >> 1);
        vec2 w2 = mix(1.0 - f, f, o);
        float w = w2.x * w2.y + 1e-4;
        sum += texelFetch(colortex7, ivec2(clamp(base + o, vec2(0.0), halfSize - 1.0)), 0) * w;
        wsum += w;
    }
    return sum / wsum;
}

// depth aware 2x upsample of the half resolution light shafts
vec3 upsampleVL(vec2 uv) {
#ifdef VOLUMETRIC_LIGHT
    vec2 halfSize = screenSize() * 0.5;
    vec2 p = uv * halfSize - 0.5;
    vec2 base = floor(p);
    vec3 sum = vec3(0.0);
    float wsum = 0.0;
    vec2 f = p - base;
    for (int i = 0; i < 4; i++) {
        vec2 o = vec2(i & 1, i >> 1);
        vec2 w2 = mix(1.0 - f, f, o);
        float w = w2.x * w2.y + 1e-4;
        sum += texelFetch(colortex7, ivec2(clamp(base + o, vec2(0.0), halfSize - 1.0)), 0).rgb * w;
        wsum += w;
    }
    return sum / wsum;
#else
    return vec3(0.0);
#endif
}

void main() {
    vec3 color = texture(colortex3, texcoord).rgb;
    DepthSample ds = sampleDepth(texcoord, true);
    vec3 playerPos = viewToPlayer(ds.viewPos);
    vec3 dir = normalize(playerPos);
    float dist = length(playerPos);
    float mu = dot(dir, lightDir);

#if defined DIM_NETHER
    float T = exp(-dist * 0.006 * FOG_DENSITY);
    if (ds.isSky) T = 0.0;
    // the lava ocean (y ~ 31) lights the haze from below: orange glow low down, darker fog higher up
    float yMid = cameraPosition.y + dir.y * min(dist, 256.0) * 0.5;
    float lavaGlow = exp(-max(yMid - 31.0, 0.0) / 20.0);
    lavaGlow *= 0.85 + 0.15 * sin(frameTimeCounter * 0.7 + yMid * 0.1);
#ifdef NETHER_SMOKE
    vec4 smoke = upsampleVolume(texcoord);
    color = color * smoke.a + smoke.rgb;
#endif
    vec3 netherFog = mix(vec3(luminance(fogColor)), fogColor, 0.35) * vec3(0.9, 0.75, 0.65) * 0.12 + vec3(1.0, 0.28, 0.04) * lavaGlow * 0.12 * NETHER_LAVA_GLOW;
    color = color * T + netherFog * (1.0 - T);
#elif defined DIM_END
    float T = exp(-dist * 0.0025 * FOG_DENSITY);
    if (ds.isSky) T = 1.0;
    color = color * T + vec3(0.03, 0.02, 0.05) * (1.0 - T);
#else
    if (isEyeInWater == 1) {
        vec3 T = exp(-waterAbsorption() * min(dist, 256.0));
        vec3 scatterLight = (skyAmbient * 0.8 + lightColor * 0.25 * max(lightDir.y, 0.0)) * max(eyeSkylight(), 0.15);
        color = color * T + waterScatterColor() * scatterLight * (1.0 - T) * 5.0;
        color += upsampleVL(texcoord);
    } else if (isEyeInWater == 2) {
        float T = exp(-dist * 1.5);
        color = color * T + vec3(1.0, 0.25, 0.02) * 2.0 * (1.0 - T);
    } else if (isEyeInWater == 3) {
        float T = exp(-dist * 1.0);
        color = color * T + skyAmbient * vec3(0.9, 0.95, 1.0) * (1.0 - T);
    } else {
        FogParams fp = getFogParams(sunDir);
        float len = ds.isSky ? 2500.0 : dist;
        float camY = cameraPosition.y;
        float odTotal = fogOpticalDepth(fp, camY, dir.y, len);
#ifdef RAIN_CURTAINS
        if (rainStrength > 0.01) {
            // drifting sheets of heavier rain in the distance
            float az = atan(dir.z, dir.x);
            vec2 q = vec2(az * 9.0 + frameTimeCounter * 0.05, dir.y * 0.6 + frameTimeCounter * 0.35);
            float sheets = textureLod(noisetex, q * vec2(0.35, 0.05), 0.0).x * 0.7
                         + textureLod(noisetex, q * vec2(1.1, 0.12) + 0.5, 0.0).x * 0.3;
            odTotal *= 1.0 + rainStrength * (sheets - 0.45) * 1.4 * smoothstep(25.0, 140.0, len);
        }
#endif
        float T = exp(-odTotal);

        // ambient light in the fog (sky colour), darker in caves
        float caveF = eyeSkylight();
        vec3 fogAmbient = skyAmbient * mix(0.04, 1.0, caveF);
#ifdef GOLDEN_ATMOSPHERE
        // painterly aerial perspective: warm golden haze by day, violet at dusk
        {
            float dayF = smoothstep(-0.05, 0.3, sunDir.y);
            float duskF = smoothstep(0.35, 0.05, sunDir.y) * smoothstep(-0.12, 0.0, sunDir.y);
            vec3 tint = mix(vec3(0.85, 0.75, 1.15), vec3(1.3, 1.05, 0.7), dayF);
            tint = mix(tint, vec3(1.45, 0.85, 0.5), duskF);   // glowing orange dusk
            fogAmbient = mix(fogAmbient, vec3(luminance(fogAmbient)) * tint, 0.6);
        }
#endif
        vec3 inscatter = fogAmbient * (1.0 - T);

        // sun light scattered in the fog beyond the ray-marched range is unshadowed
#ifdef VOLUMETRIC_LIGHT
        float vlLen = min(len, shadowDistance);
        float odNear = fogOpticalDepth(fp, camY, dir.y, vlLen);
        float farPart = exp(-odNear) - T;
        float goldenHour = smoothstep(0.4, 0.03, sunDir.y) * smoothstep(-0.06, 0.03, sunDir.y);
        inscatter += lightColor * fogPhase(mu) * farPart * VL_STRENGTH * caveF * 0.4 * (1.0 + 2.0 * goldenHour);
        inscatter += upsampleVL(texcoord);
#else
        inscatter += lightColor * fogPhase(mu) * (1.0 - T) * 0.25 * caveF;
#endif
        color = color * T + inscatter;

#ifdef CAVE_FOG
        // thin dark haze underground, gives caves depth without hiding torch light
        float caveFog = (1.0 - caveF) * (1.0 - smoothstep(40.0, 60.0, camY)) ;
        if (caveFog > 0.0) {
            float Tc = exp(-min(dist, 512.0) * 0.012 * caveFog * FOG_DENSITY);
            color = color * Tc + vec3(0.0025, 0.003, 0.004) * MIN_LIGHT * (1.0 - Tc);
        }
#endif
    }
#endif

#if defined FALLING_LEAVES && defined DIM_OVERWORLD
    if (isEyeInWater == 0 && eyeSkylight() > 0.3) {
        vec4 lv = fallingLeaves(cameraPosition + gbufferModelViewInverse[3].xyz, dir, ds.isSky ? 48.0 : dist, lightDir, lightColor, skyAmbient);
        color = color * (1.0 - lv.a) + lv.rgb * smoothstep(0.3, 0.6, eyeSkylight());
    }
#endif

    // blindness / darkness effect
    float dark = max(blindness, darknessFactor);
    if (dark > 0.0) color *= exp(-dist * dark * 0.3);

    outColor = vec4(color, 1.0);
}
#endif

// composite2: apply atmospheric fog, ground mist, underwater fog and the light shafts -> colortex3

#include "/lib/common.glsl"

#ifdef VERTEX
#include "/program/fullscreen_vertex.glsl"
#else
#include "/lib/atmosphere.glsl"
#include "/lib/depth.glsl"
#include "/lib/fog.glsl"
#include "/lib/water.glsl"
#include "/program/fullscreen_frag_header.glsl"

uniform sampler2D colortex3;
uniform sampler2D colortex7;

/* RENDERTARGETS: 3 */
layout(location = 0) out vec4 outColor;

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
    vec3 netherFog = fogColor * 0.4 + vec3(1.0, 0.32, 0.06) * lavaGlow * 0.35 * NETHER_LAVA_GLOW;
    color = color * T + netherFog * (1.0 - T);
#elif defined DIM_END
    float T = exp(-dist * 0.0025 * FOG_DENSITY);
    if (ds.isSky) T = 1.0;
    color = color * T + vec3(0.03, 0.02, 0.05) * (1.0 - T);
#else
    if (isEyeInWater == 1) {
        vec3 T = exp(-waterAbsorption() * min(dist, 256.0));
        vec3 scatterLight = (skyAmbient * 0.8 + lightColor * 0.25 * max(lightDir.y, 0.0)) * max(eyeSkylight(), 0.15);
        color = color * T + waterScatterColor() * scatterLight * (1.0 - T) * 4.0;
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
        float T = exp(-odTotal);

        // ambient light in the fog (sky colour), darker in caves
        float caveF = eyeSkylight();
        vec3 fogAmbient = skyAmbient * mix(0.04, 1.0, caveF);
        vec3 inscatter = fogAmbient * (1.0 - T);

        // sun light scattered in the fog beyond the ray-marched range is unshadowed
#ifdef VOLUMETRIC_LIGHT
        float vlLen = min(len, shadowDistance);
        float odNear = fogOpticalDepth(fp, camY, dir.y, vlLen);
        float farPart = exp(-odNear) - T;
        inscatter += lightColor * fogPhase(mu) * farPart * VL_STRENGTH * caveF;
        inscatter += upsampleVL(texcoord);
#else
        inscatter += lightColor * fogPhase(mu) * (1.0 - T) * 0.6 * caveF;
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

    // blindness / darkness effect
    float dark = max(blindness, darknessFactor);
    if (dark > 0.0) color *= exp(-dist * dark * 0.3);

    outColor = vec4(color, 1.0);
}
#endif

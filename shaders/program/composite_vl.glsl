// composite1: shadowed sun light scattered in fog / water (light shafts), half resolution -> colortex7

#include "/lib/common.glsl"

#ifdef VERTEX
#include "/program/fullscreen_vertex.glsl"
#else
#include "/lib/atmosphere.glsl"
#include "/lib/depth.glsl"
#include "/lib/shadows.glsl"
#include "/lib/fog.glsl"
#include "/lib/water.glsl"
#include "/lib/clouds.glsl"
#include "/program/fullscreen_frag_header.glsl"

/* RENDERTARGETS: 7 */
layout(location = 0) out vec4 outVL;

void main() {
#if defined VOLUMETRIC_LIGHT && defined DIM_OVERWORLD
    DepthSample ds = sampleDepth(texcoord, true);
    vec3 playerPos = viewToPlayer(ds.viewPos);
    float dist = ds.isSky ? 1e5 : length(playerPos);
    vec3 dir = playerPos / max(length(playerPos), 1e-4);
    float len = min(dist, shadowDistance);
    if (isEyeInWater == 1) len = min(dist, 48.0);

    float dither = ignAnimated(gl_FragCoord.xy);
    float mu = dot(dir, lightDir);
    vec3 sum = vec3(0.0);

    if (isEyeInWater == 1) {
        // underwater light shafts: sunlight focused by the waves (caustics) and
        // blocked by terrain, scattered by the water towards the camera
        const int uwSteps = VL_SAMPLES * 2;
        float uwLen = min(dist, 40.0);
        float dt = uwLen / float(uwSteps);
        vec3 absorb = waterAbsorption();
        for (int i = 0; i < uwSteps; i++) {
            float t = dt * (float(i) + dither);
            vec3 p = dir * t;
            float sh = getShadowFast(p);
            if (sh <= 0.0) continue;
            // light path: absorption from the surface down to p + caustic pattern (softened -> broad shafts)
            vec3 light = waterLightTransmit(p, lightDir, 0.35);
            // view path: absorption from p back to the camera
            sum += sh * light * exp(-absorb * t) * dt;
        }
        float phase = mix(hgPhase(mu, 0.6), 1.0 / (4.0 * PI), 0.3);
        sum *= lightColor * phase * waterScatterColor() * 3.0 * UNDERWATER_RAYS;
    } else {
        FogParams fp = getFogParams(sunDir);
        // squared distribution: more samples close to the camera
        float prevT = 0.0;
        for (int i = 0; i < VL_SAMPLES; i++) {
            float f = (float(i) + dither) / float(VL_SAMPLES);
            float t = len * f * f;
            float dt = t - prevT;
            prevT = t;
            vec3 p = dir * t;
            float y = p.y + cameraPosition.y;
            float dens = fogDensityAt(fp, y);
            float od = fogOpticalDepth(fp, cameraPosition.y, dir.y, t);
            float sh = getShadowFast(p);
            sum += vec3(dens * sh * exp(-od) * dt);
        }
        sum *= lightColor * fogPhase(mu) * VL_STRENGTH * 0.4;
        // inside caves the sun doesn't reach the fog anyway; avoids light leaking through the shadow map edge
        sum *= smoothstep(0.0, 0.4, eyeSkylight());
    }
    outVL = vec4(sum, 1.0);
#elif defined DIM_NETHER && defined NETHER_SMOKE
    // Nether smoke: slowly rising, swirling volumes lit orange by the lava ocean below
    DepthSample ds = sampleDepth(texcoord, true);
    vec3 playerPos = viewToPlayer(ds.viewPos);
    float dist = ds.isSky ? 160.0 : length(playerPos);
    vec3 dir = playerPos / max(length(playerPos), 1e-4);
    float len = min(dist, 128.0);
    const int steps = 16;
    float dt = len / float(steps);
    float dither = ignAnimated(gl_FragCoord.xy);
    float t0 = frameTimeCounter;
    vec3 sum = vec3(0.0);
    float trans = 1.0;
    for (int i = 0; i < steps; i++) {
        float t = dt * (float(i) + dither);
        vec3 p = cameraPosition + dir * t;
        float h = (p.y - 28.0) / 160.0;
        if (h < 0.0 || h > 1.0) continue;
        // rising motion + slow drift, two octaves of 3D noise
        vec3 q = p * 0.025 + vec3(t0 * 0.02, -t0 * 0.05, t0 * 0.015);
        float n = cloudNoise3D(q.xzy) * 0.65 + cloudNoise3D(q.xzy * 2.7 + 9.0) * 0.35;
        float dens = smoothstep(0.5, 0.82, n) * sq(1.0 - h) * 0.012 * NETHER_SMOKE_DENSITY;
        if (dens <= 0.0) continue;
        vec3 lavaLight = vec3(1.0, 0.33, 0.07) * exp(-max(p.y - 31.0, 0.0) / 24.0) * 0.35;
        vec3 ambient = vec3(luminance(fogColor)) * 0.06 + vec3(0.03, 0.01, 0.005);
        float tr = exp(-dens * dt);
        sum += trans * (lavaLight + ambient) * (1.0 - tr);
        trans *= tr;
        if (trans < 0.03) break;
    }
    outVL = vec4(sum, trans);
#else
    outVL = vec4(0.0, 0.0, 0.0, 1.0);
#endif
}
#endif

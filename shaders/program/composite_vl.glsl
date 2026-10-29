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
        sum *= lightColor * fogPhase(mu) * VL_STRENGTH;
        // inside caves the sun doesn't reach the fog anyway; avoids light leaking through the shadow map edge
        sum *= smoothstep(0.0, 0.4, eyeSkylight());
    }
    outVL = vec4(sum, 1.0);
#else
    outVL = vec4(0.0);
#endif
}
#endif

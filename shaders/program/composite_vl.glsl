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
        // underwater light shafts
        float dt = len / float(VL_SAMPLES);
        vec3 absorb = waterAbsorption();
        for (int i = 0; i < VL_SAMPLES; i++) {
            float t = dt * (float(i) + dither);
            vec3 p = dir * t;
            float sh = getShadowFast(p);
            // light travels down through the water as well
            float depthBelow = max(0.0, 63.0 - (p.y + cameraPosition.y));
            vec3 tr = exp(-absorb * (t + depthBelow * 0.5));
            sum += sh * tr * dt;
        }
        sum *= lightColor * hgPhase(mu, 0.5) * waterScatterColor() * 6.0;
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

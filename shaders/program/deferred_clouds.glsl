// deferred: volumetric clouds at half resolution -> colortex5

#include "/lib/common.glsl"

#ifdef VERTEX
#include "/program/fullscreen_vertex.glsl"
#else
#include "/lib/atmosphere.glsl"
#include "/lib/depth.glsl"
#include "/lib/clouds.glsl"
#include "/program/fullscreen_frag_header.glsl"

/* RENDERTARGETS: 5 */
layout(location = 0) out vec4 outClouds;

void main() {
#if defined VOLUMETRIC_CLOUDS && defined DIM_OVERWORLD
    DepthSample ds = sampleDepth(texcoord, true);
    vec3 playerPos = viewToPlayer(ds.viewPos);
    float rayLen = ds.isSky ? 1e6 : length(playerPos);
    vec3 dir = normalize(playerPos);
    float dither = ignAnimated(gl_FragCoord.xy);
    outClouds = renderClouds(dir, rayLen, sunDir, lightColor, skyAmbient, dither);
#else
    outClouds = vec4(0.0, 0.0, 0.0, 1.0);
#endif
}
#endif

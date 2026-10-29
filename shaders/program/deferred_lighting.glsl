// deferred1: light the G-buffer, draw the sky and blend in the clouds -> colortex3 (HDR)

#include "/lib/common.glsl"

#ifdef VERTEX
#include "/program/fullscreen_vertex.glsl"
#else
#include "/lib/atmosphere.glsl"
#include "/lib/depth.glsl"
#include "/lib/shadows.glsl"
#include "/lib/lighting.glsl"
#include "/lib/surface.glsl"
#include "/program/fullscreen_frag_header.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex5;

/* RENDERTARGETS: 3 */
layout(location = 0) out vec4 outColor;

vec3 renderSky(vec3 dir, vec4 albedoMat) {
#if defined DIM_NETHER
    return mix(vec3(luminance(fogColor)), fogColor, 0.35) * vec3(0.9, 0.75, 0.65) * 0.12;
#elif defined DIM_END
    vec3 c = vec3(0.025, 0.015, 0.04) + stars(normalize(dir + vec3(0.0, 0.3, 0.0)), vec3(0.0, -1.0, 0.0)) * 0.6;
    return c;
#else
    vec3 sky = skyRadiance(dir, sunDir);
    vec4 cirrus = cirrusClouds(dir, sunDir, lightColor, skyAmbient);
    sky = mix(sky, cirrus.rgb, cirrus.a);
    sky += sunDisk(dir, sunDir);
    sky += moonDisk(dir, sunDir);
    sky += nightSky(dir, sunDir, ignAnimated(gl_FragCoord.xy), false);
    sky += vec3(0.7, 0.75, 1.0) * lightningFlash() * 0.8 * smoothstep(-0.1, 0.3, dir.y);
    int mat = int(albedoMat.a * 255.0 + 0.5);
    if (mat == MAT_SKY_OBJECT) {
        // moon texture from gbuffers_skytextured
        sky += albedoMat.rgb * vec3(0.8, 0.9, 1.0) * 0.3 * NIGHT_BRIGHTNESS * (1.0 - rainStrength);
    }
    return sky;
#endif
}

void main() {
    ivec2 px = ivec2(gl_FragCoord.xy);
    vec4 albedoMat = texelFetch(colortex0, px, 0);
    DepthSample ds = sampleDepth(texcoord, true);
    vec3 playerPos = viewToPlayer(ds.viewPos);
    vec3 dir = normalize(playerPos);

    vec3 color;
    if (ds.isSky) {
        color = renderSky(dir, albedoMat);
    } else {
        vec4 nl = texelFetch(colortex1, px, 0);
        vec4 m = texelFetch(colortex2, px, 0);
        int mat = int(albedoMat.a * 255.0 + 0.5);

        Surface s;
        s.albedo = pow(albedoMat.rgb, vec3(2.2));
        s.normal = decodeNormal(nl.xy);
        s.lightmap = nl.zw;
        s.smoothness = m.r;
        s.emission = m.g;
        s.sss = m.b;
        s.metal = m.a;
        s.ao = 1.0;
        if (mat == MAT_LAVA) {
            // keep lava saturated: push the texture towards deep orange and limit its brightness
            s.albedo = s.albedo * vec3(1.0, 0.62, 0.3);
            s.emission = 0.2;
        }

        applyWetness(s, playerPos + cameraPosition);

        float noise = ignAnimated(gl_FragCoord.xy);
        color = shadeSurface(s, playerPos, lightDir, lightColor, skyAmbient, noise, !ds.isDH);
    }

#if defined VOLUMETRIC_CLOUDS && defined DIM_OVERWORLD
    vec4 clouds = texture(colortex5, texcoord);
    color = color * clouds.a + clouds.rgb;
#endif

    outColor = vec4(color, 1.0);
}
#endif

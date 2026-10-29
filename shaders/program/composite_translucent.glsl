// composite: refraction, water absorption, translucent blending and reflections

#include "/lib/common.glsl"

#ifdef VERTEX
#include "/program/fullscreen_vertex.glsl"
#else
#include "/lib/atmosphere.glsl"
#include "/lib/depth.glsl"
#include "/lib/shadows.glsl"
#include "/lib/lighting.glsl"
#include "/lib/surface.glsl"
#include "/lib/water.glsl"
#include "/lib/ssr.glsl"
#include "/program/fullscreen_frag_header.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex6;

/* RENDERTARGETS: 3 */
layout(location = 0) out vec4 outColor;

vec3 reflectionColor(vec3 viewPos, vec3 viewNormal, vec3 worldNormal, float skyLm, float smoothness, float dither, out float hitSky) {
    vec3 v = normalize(viewPos);
    vec3 r = reflect(v, viewNormal);
    vec3 rWorld = mat3(gbufferModelViewInverse) * r;
    hitSky = 1.0;
#ifdef SSR
    vec3 hit = traceSSR(viewPos, r, dither);
    if (hit.z > 0.5) {
        // fade near screen edges
        vec2 e = smoothstep(vec2(0.0), vec2(0.08), hit.xy) * smoothstep(vec2(1.0), vec2(0.92), hit.xy);
        float fade = e.x * e.y;
        vec3 c = texture(colortex3, hit.xy).rgb;
        hitSky = 1.0 - fade;
        vec3 sky = (skyRadianceCheap(rWorld, sunDir) + nightSky(rWorld, sunDir, dither, true)) * smoothstep(0.2, 0.9, skyLm);
        return mix(sky, c, fade);
    }
#endif
    vec3 sky;
#if defined DIM_NETHER
    sky = fogColor * 0.3;
#elif defined DIM_END
    sky = vec3(0.025, 0.015, 0.04);
#else
    sky = skyRadianceCheap(rWorld, sunDir) + nightSky(rWorld, sunDir, dither, true);
#endif
    return sky * smoothstep(0.2, 0.9, skyLm);
}

float fresnelSchlick(float cosTheta, float f0) {
    return f0 + (1.0 - f0) * pow(1.0 - saturate(cosTheta), 5.0);
}

void main() {
    ivec2 px = ivec2(gl_FragCoord.xy);
    vec2 uv = texcoord;
    vec4 tr = texelFetch(colortex4, px, 0);
    // z packs the translucent type (integer part of z*8) and the surface sky light (fraction)
    int type = int(tr.z * 8.0 + 0.001);
    float surfaceSkyLm = saturate(fract(tr.z * 8.0 + 0.001) / 0.8);
    vec4 tcol = texelFetch(colortex6, px, 0);

    DepthSample front = sampleDepth(uv, true);
    bool isHand = !front.isDH && front.depth < 0.56;
    float dither = ignAnimated(gl_FragCoord.xy);

    vec3 color;
    if (type != TR_NONE && !isHand) {
        vec3 n = decodeNormal(tr.xy);
        vec3 viewN = mat3(gbufferModelView) * n;
        vec3 frontPlayer = viewToPlayer(front.viewPos);

        // ---- refraction
        DepthSample back = sampleDepth(uv, false);
        float thick = length(back.viewPos - front.viewPos);
        float strength = (type == TR_WATER ? 0.06 : 0.025) * saturate(thick * 0.5);
        vec2 refrUV = uv + viewN.xy * strength / max(1.0, -front.viewPos.z * 0.1);
        DepthSample backR = sampleDepth(refrUV, false);
        // only refract things that are actually behind the surface
        if (backR.viewPos.z > front.viewPos.z || refrUV != clamp(refrUV, 0.0, 1.0)) { refrUV = uv; backR = back; }
        color = texture(colortex3, refrUV).rgb;

        // ---- water volume: absorption + in-scattering between surface and floor
        if (type == TR_WATER && isEyeInWater == 0) {
            float dist = backR.isSky ? 64.0 : min(length(backR.viewPos - front.viewPos), 64.0);
            vec3 trans = exp(-waterAbsorption() * dist);
            vec3 scatterLight = skyAmbient * 0.8 + lightColor * 0.25 * max(lightDir.y, 0.0);
            scatterLight *= surfaceSkyLm * surfaceSkyLm;
            color = color * trans + waterScatterColor() * scatterLight * (1.0 - trans) * 4.0;
        }

        // ---- translucent surface colour (glass tint, optional water texture)
        color = color * (1.0 - tcol.a) + tcol.rgb;

        // ---- reflection
        float smoothness = tr.w;
        float skyLm = surfaceSkyLm;
        float hitSky;
        vec3 refl = reflectionColor(front.viewPos, viewN, n, skyLm, smoothness, dither, hitSky);
        float nv = dot(-normalize(front.viewPos), viewN);
        float f0 = type == TR_WATER ? 0.02 : 0.04;
        float fres = fresnelSchlick(nv, f0) * smoothness;
        if (isEyeInWater == 1 && type == TR_WATER) {
            // looking up at the surface from below: total internal reflection near grazing
            fres = smoothstep(0.75, 0.6, nv) * 0.9;
        }
        color = mix(color, refl, fres);

        // sun glint
        if (lightColor.r + lightColor.g > 0.0) {
            float shadow = getShadowFast(frontPlayer + n * 0.1);
            float spec = ggxSpecular(n, -normalize(frontPlayer), lightDir, type == TR_WATER ? 0.06 : 0.1, f0);
            color += lightColor * spec * shadow * hitSky;
        }
    } else {
        color = texelFetch(colortex3, px, 0).rgb;

        // ---- reflections on smooth opaque surfaces (metal, polished blocks, puddles)
        DepthSample opaque = front;
        if (!opaque.isSky && !isHand) {
            vec4 m = texelFetch(colortex2, px, 0);
            vec4 nl = texelFetch(colortex1, px, 0);
            vec3 albedo = pow(texelFetch(colortex0, px, 0).rgb, vec3(2.2));
            Surface s;
            s.albedo = albedo; s.normal = decodeNormal(nl.xy); s.lightmap = nl.zw;
            s.smoothness = m.r; s.emission = m.g; s.sss = m.b; s.metal = m.a; s.ao = 1.0;
            vec3 playerPos = viewToPlayer(opaque.viewPos);
            applyWetness(s, playerPos + cameraPosition);
            if (s.smoothness > 0.45) {
                // raindrops ripple the puddles
                float puddle = puddleAmount(playerPos + cameraPosition, s.normal, s.lightmap.y);
                if (puddle > 0.0) {
                    vec2 rg = rainRipples((playerPos + cameraPosition).xz) * puddle * smoothstep(40.0, 6.0, length(playerPos));
                    s.normal = normalize(s.normal + vec3(-rg.x, 0.0, -rg.y));
                }
                vec3 viewN = mat3(gbufferModelView) * s.normal;
                float hitSky;
                vec3 refl = reflectionColor(opaque.viewPos, viewN, s.normal, s.lightmap.y, s.smoothness, dither, hitSky);
                float nv = dot(-normalize(opaque.viewPos), viewN);
                float rough = smoothstep(0.45, 0.95, s.smoothness);
                if (s.metal > 0.5) {
                    color += refl * albedo * fresnelSchlick(nv, 0.6) * rough * 0.8;
                } else {
                    color = mix(color, refl, fresnelSchlick(nv, 0.03) * rough);
                }
            }
        }
        // hand, particles, weather etc.
        color = color * (1.0 - tcol.a) + tcol.rgb;
    }

    outColor = vec4(color, 1.0);
}
#endif

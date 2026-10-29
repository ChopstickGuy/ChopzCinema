// Shadow map distortion + soft filtering

#define SHADOW_DISTORT 0.85

vec3 distortShadow(vec3 p) {
    float f = length(p.xy) * SHADOW_DISTORT + (1.0 - SHADOW_DISTORT);
    p.xy /= f;
    p.z *= 0.25;
    return p;
}
float shadowDistortFactor(vec2 p) {
    return length(p) * SHADOW_DISTORT + (1.0 - SHADOW_DISTORT);
}

#ifndef SHADOW_PASS
#include "/lib/water.glsl"
uniform sampler2DShadow shadowtex0;
uniform sampler2D shadowcolor1;
uniform sampler2DShadow shadowtex1;
uniform sampler2D shadowcolor0;

// world-relative (player) position -> undistorted shadow clip space
vec3 playerToShadowClip(vec3 playerPos) {
    vec3 sv = (shadowModelView * vec4(playerPos, 1.0)).xyz;
    return projectAndDivide(shadowProjection, sv);
}

vec3 sampleShadowTap(vec3 sc) {
    float s0 = texture(shadowtex0, sc);
#ifdef COLORED_SHADOWS
    if (s0 < 1.0) {
        float s1 = texture(shadowtex1, sc);
        if (s1 > s0) {
            vec4 c = texture(shadowcolor0, sc.xy);
            vec3 tint = mix(vec3(1.0), c.rgb, sqrt(c.a));
            return vec3(s0) + tint * (s1 - s0);
        }
    }
#endif
    return vec3(s0);
}

// Returns coloured shadow visibility. playerPos = position relative to camera (feet space),
// normal in world space, nl = dot(normal, lightDir).
vec3 getShadow(vec3 playerPos, vec3 worldNormal, float nl, float noise, float sss) {
    float dist = length(playerPos);
    float fade = smoothstep(shadowDistance * 0.85, shadowDistance, dist);
    if (fade >= 1.0) return vec3(1.0);

    // normal offset scaled by distance to keep acne away without peter-panning up close
    float bias = 0.03 + dist * 0.0015;
    vec3 p = playerPos + worldNormal * bias * (nl > 0.0 ? 1.0 : 0.3) * (2048.0 / float(shadowMapResolution));
    vec3 sc = playerToShadowClip(p);
    float df = shadowDistortFactor(sc.xy);
    vec3 d = distortShadow(sc);
    d = d * 0.5 + 0.5;
    d.z -= 0.0002 * df;

    // blocker-aware softness: farther from the occluder => softer
    float radius = SHADOW_SOFTNESS * 1.6 / float(shadowMapResolution) / df;
    radius *= mix(1.0, 3.0, sss);

    vec3 sum = vec3(0.0);
    float ang = noise * TAU;
    const float golden = 2.39996323;
    for (int i = 0; i < SHADOW_SAMPLES; i++) {
        float r = sqrt((float(i) + 0.5) / float(SHADOW_SAMPLES));
        float a = float(i) * golden + ang;
        vec2 off = vec2(cos(a), sin(a)) * r * radius;
        sum += sampleShadowTap(vec3(d.xy + off, d.z));
    }
    sum /= float(SHADOW_SAMPLES);
    return mix(sum, vec3(1.0), fade);
}

// Light reaching a point below a water surface: caustics + absorption along the light path.
// Returns 1 above water / outside the shadow map.
vec3 waterLightTransmit(vec3 playerPos, vec3 lightDir, float softness) {
#ifdef WATER_CAUSTICS
    vec3 d = distortShadow(playerToShadowClip(playerPos)) * 0.5 + 0.5;
    if (any(greaterThan(abs(d.xy - 0.5), vec2(0.499)))) return vec3(1.0);
    vec4 w = texelFetch(shadowcolor1, ivec2(d.xy * float(shadowMapResolution)), 0);
    if (w.x < 0.5) return vec3(1.0);
    // shadow depth -> blocks along the light direction
    float depthBlocks = (d.z - w.z) / (0.125 * abs(shadowProjection[2][2]));
    if (depthBlocks <= 0.05) return vec3(1.0);
    vec3 trans = exp(-waterAbsorption() * depthBlocks);
    vec3 surface = playerPos + cameraPosition + lightDir * depthBlocks;
    float c = softness > 0.0 ? waterCaustics(surface.xz, depthBlocks, true) : waterCaustics(surface.xz, depthBlocks, false);
    c = mix(c, 1.0, softness);
    return trans * c;
#else
    return vec3(1.0);
#endif
}

// Single tap hard shadow for volumetrics
float getShadowFast(vec3 playerPos) {
    vec3 d = distortShadow(playerToShadowClip(playerPos)) * 0.5 + 0.5;
    if (any(greaterThan(abs(d.xy - 0.5), vec2(0.5)))) return 1.0;
    return texture(shadowtex1, d);
}
#endif

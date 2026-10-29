// final: bloom, lens flare, exposure, filmic tonemap, colour grading, film effects

#include "/lib/common.glsl"

#ifdef VERTEX
out vec2 texcoord;
flat out vec3 sunScreen;   // xy: screen position of the sun / moon, z: visibility
flat out vec3 flareColor;
#include "/lib/atmosphere.glsl"
uniform sampler2D depthtex0;
#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex;
#endif

void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    vec3 sunDir = sunDirWorld();
    vec3 lp = shadowLightPosition;
    vec4 clip = gbufferProjection * vec4(lp, 1.0);
    vec2 sp = clip.xy / clip.w * 0.5 + 0.5;
    float vis = 0.0;
#if defined LENS_FLARE && defined DIM_OVERWORLD
    if (clip.w > 0.0 && isEyeInWater == 0) {
        // occlusion test: how much of a small disk around the sun is sky
        for (int i = 0; i < 16; i++) {
            float a = float(i) * 2.39996;
            vec2 o = vec2(cos(a), sin(a)) * sqrt(float(i) / 16.0) * 0.012 * vec2(viewHeight / viewWidth, 1.0);
            vec2 uv = sp + o;
            float d = texture(depthtex0, uv).r;
#ifdef DISTANT_HORIZONS
            d = min(d, texture(dhDepthTex, uv).r);
#endif
            vis += (d >= 1.0 && uv == clamp(uv, 0.0, 1.0)) ? 1.0 : 0.0;
        }
        vis /= 16.0;
    }
#endif
    sunScreen = vec3(sp, vis);
    flareColor = getShadowLightColor(sunDir) * (1.0 - rainStrength);
}

#else
const bool colortex3MipmapEnabled = true;
#include "/lib/buffers.glsl"

uniform sampler2D colortex3;
uniform sampler2D colortex9;

in vec2 texcoord;
flat in vec3 sunScreen;
flat in vec3 flareColor;

layout(location = 0) out vec4 fragColor;

// ---------------------------------------------------------------- bloom
vec3 bloomTap(vec2 uv, float lod) {
    vec2 ts = exp2(lod) / screenSize();
    // 3x3 tent filter made of 4 bilinear taps
    vec3 c = textureLod(colortex3, uv + vec2(-0.5, -0.5) * ts, lod).rgb
           + textureLod(colortex3, uv + vec2( 0.5, -0.5) * ts, lod).rgb
           + textureLod(colortex3, uv + vec2(-0.5,  0.5) * ts, lod).rgb
           + textureLod(colortex3, uv + vec2( 0.5,  0.5) * ts, lod).rgb;
    return c * 0.25;
}
vec3 getBloom(vec2 uv) {
    vec3 b = vec3(0.0);
    float wsum = 0.0;
    for (int i = 2; i <= 7; i++) {
        float w = pow(float(i) - 1.0, 0.7);
        b += bloomTap(uv, float(i)) * w;
        wsum += w;
    }
    return b / wsum;
}

#include "/lib/post.glsl"

// ---------------------------------------------------------------- lens flare (anamorphic)
vec3 lensFlare(vec2 uv) {
#if defined LENS_FLARE && defined DIM_OVERWORLD
    float vis = sunScreen.z;
    if (vis <= 0.0) return vec3(0.0);
    float aspect = viewWidth / viewHeight;
    vec2 d = (uv - sunScreen.xy) * vec2(aspect, 1.0);
    // horizontal streak, slightly blue like an anamorphic lens
    float streak = exp(-abs(d.y) * 260.0) * exp(-abs(d.x) * 2.2);
    vec3 col = streak * vec3(0.45, 0.65, 1.0) * 0.5;
    // soft ghosts along the axis through the screen centre
    vec2 axis = vec2(0.5) - sunScreen.xy;
    for (int i = 1; i <= 3; i++) {
        vec2 gp = sunScreen.xy + axis * (float(i) * 0.7);
        float r = 0.03 + float(i) * 0.025;
        float g = smoothstep(r, r * 0.6, length((uv - gp) * vec2(aspect, 1.0)));
        col += g * mix(vec3(1.0, 0.6, 0.3), vec3(0.3, 0.6, 1.0), float(i) / 3.0) * 0.02;
    }
    // stronger at low sun, when it's most cinematic
    return col * flareColor * vis * 1.5;
#else
    return vec3(0.0);
#endif
}

void main() {
    vec2 uv = texcoord;

    // letterbox
#if LETTERBOX > 0
#if LETTERBOX == 1
    const float targetAspect = 2.39;
#else
    const float targetAspect = 1.85;
#endif
    float aspectNow = viewWidth / viewHeight;
    if (aspectNow < targetAspect) {
        float bar = (1.0 - aspectNow / targetAspect) * 0.5;
        if (uv.y < bar || uv.y > 1.0 - bar) { fragColor = vec4(0.0, 0.0, 0.0, 1.0); return; }
    }
#endif

    // chromatic aberration towards the edges
    vec3 color;
    vec2 fromCenter = uv - 0.5;
    float ca = CHROMATIC_ABERRATION * 0.004 * dot(fromCenter, fromCenter) * 4.0;
    if (ca > 0.0) {
        color.r = texture(colortex3, uv - fromCenter * ca).r;
        color.g = texture(colortex3, uv).g;
        color.b = texture(colortex3, uv + fromCenter * ca).b;
    } else {
        color = texture(colortex3, uv).rgb;
    }

#ifdef TAA
    // light sharpening to counter the softness of temporal AA
    {
        vec2 ts = texelSize();
        vec3 nb = texture(colortex3, uv + vec2(ts.x, 0.0)).rgb + texture(colortex3, uv - vec2(ts.x, 0.0)).rgb
                + texture(colortex3, uv + vec2(0.0, ts.y)).rgb + texture(colortex3, uv - vec2(0.0, ts.y)).rgb;
        vec3 sharp = color + (color - nb * 0.25) * TAA_SHARPEN;
        color = max(sharp, color * 0.5);
    }
#endif

#ifdef BLOOM
    vec3 bloom = getBloom(uv);
    // slight warm halation tint like film
    bloom *= vec3(1.08, 0.98, 0.9);
    color = mix(color, bloom, 0.06 * BLOOM_STRENGTH * (1.0 + rainStrength));
#endif
    color += lensFlare(uv);

    float exposure = texelFetch(colortex9, ivec2(0), 0).a;
    if (exposure <= 0.0) exposure = 1.0;
    color *= exposure * exp2(EXPOSURE);

    color = tonemap(color);
    color = colorGrade(color);

    // vignette
    float vig = dot(fromCenter * vec2(viewWidth / viewHeight, 1.0) * 0.8, fromCenter * vec2(viewWidth / viewHeight, 1.0) * 0.8);
    color *= mix(1.0, smoothstep(1.0, 0.0, vig), VIGNETTE);

    color = linearToSrgb(color);

    // film grain (luminance weighted, strongest in the mid tones)
    float grain = hash12(gl_FragCoord.xy + fract(frameTimeCounter * 7.13) * 1000.0) - 0.5;
    float lum = luminance(color);
    color += grain * FILM_GRAIN * 0.08 * (1.0 - abs(lum - 0.5) * 1.4);

    // dithering against banding
    color += (hash12(gl_FragCoord.xy + 0.37) - 0.5) / 255.0;

    fragColor = vec4(color, 1.0);
}
#endif

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

#include "/lib/depth.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex3;
uniform sampler2D colortex9;
uniform float centerDepthSmooth;

in vec2 texcoord;
flat in vec3 sunScreen;
flat in vec3 flareColor;

layout(location = 0) out vec4 fragColor;

// ---------------------------------------------------------------- bloom
vec3 bloomTap(vec2 uv, float lod) {
    vec2 ts = exp2(lod) / screenSize();
    // 3x3 tent over one texel of this mip level: hides the blocky look of small mips
    vec3 c = textureLod(colortex3, uv, lod).rgb * 4.0;
    c += (textureLod(colortex3, uv + vec2(ts.x, 0.0), lod).rgb + textureLod(colortex3, uv - vec2(ts.x, 0.0), lod).rgb
        + textureLod(colortex3, uv + vec2(0.0, ts.y), lod).rgb + textureLod(colortex3, uv - vec2(0.0, ts.y), lod).rgb) * 2.0;
    c += textureLod(colortex3, uv + ts, lod).rgb + textureLod(colortex3, uv - ts, lod).rgb
       + textureLod(colortex3, uv + vec2(ts.x, -ts.y), lod).rgb + textureLod(colortex3, uv + vec2(-ts.x, ts.y), lod).rgb;
    return c / 16.0;
}
vec3 getBloom(vec2 uv) {
    vec3 b = vec3(0.0);
    float wsum = 0.0;
    for (int i = 1; i <= 5; i++) {
        float w = 1.0 / (float(i) - 0.5);
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
    // short, soft streak (wide in x, thin in y) - present but not dominating
    float streak = exp(-abs(d.y) * 180.0) * exp(-abs(d.x) * 6.0);
    streak += exp(-abs(d.y) * 60.0) * exp(-abs(d.x) * 14.0) * 0.3;
    vec3 col = streak * vec3(0.45, 0.65, 1.0) * 0.18;
    // soft ghosts along the axis through the screen centre
    vec2 axis = vec2(0.5) - sunScreen.xy;
    for (int i = 1; i <= 3; i++) {
        vec2 gp = sunScreen.xy + axis * (float(i) * 0.7);
        float r = 0.03 + float(i) * 0.025;
        float g = smoothstep(r, r * 0.6, length((uv - gp) * vec2(aspect, 1.0)));
        col += g * mix(vec3(1.0, 0.6, 0.3), vec3(0.3, 0.6, 1.0), float(i) / 3.0) * 0.004;
    }
    // stronger at low sun, when it's most cinematic
    return col * flareColor * vis * 0.5;
#else
    return vec3(0.0);
#endif
}

// ---------------------------------------------------------------- heat haze
// Air above lava / fire shimmers. We look downwards in screen space for hot surfaces
// and estimate how many blocks above them the current pixel is.
vec2 heatHaze(vec2 uv) {
#ifdef HEAT_HAZE
    DepthSample here = sampleDepth(uv, true);
    if (!here.isDH && here.depth < 0.56) return uv; // never distort the hand
    float heat = 0.0;
    float projScale = gbufferProjection[1][1];
    for (int i = 0; i <= 10; i++) {
        float off = i == 0 ? 0.0 : 0.003 * pow(1.5, float(i));
        vec2 suv = vec2(uv.x, uv.y - off);
        if (suv.y < 0.0) break;
        int mat = int(texelFetch(colortex0, ivec2(suv * screenSize()), 0).a * 255.0 + 0.5);
        if (mat != MAT_LAVA && mat != MAT_HOT) continue;
        DepthSample ds = sampleDepth(suv, true);
        if (ds.isSky) continue;
        float d = -ds.viewPos.z;
        // pixels -> blocks at the distance of the hot surface
        float blocksAbove = off * 2.0 * d / projScale;
        float reach = mat == MAT_LAVA ? 3.0 : 1.5;
        float h = exp(-blocksAbove / reach) * (mat == MAT_LAVA ? 1.0 : 0.6);
        // only things behind (or at) the hot air get distorted
        if (!here.isSky && -here.viewPos.z < d - 2.0) h = 0.0;
        // the effect weakens with distance so far lava doesn't turn into noise
        h *= 1.0 / (1.0 + d * 0.02);
        heat = max(heat, h);
    }
#if defined DIM_NETHER && defined NETHER_HEAT_HAZE
    // the whole Nether shimmers a bit in the distance
    float dist = here.isSky ? 200.0 : length(here.viewPos);
    heat = max(heat, 0.3 * smoothstep(12.0, 80.0, dist));
#endif
    if (heat <= 0.001) return uv;
    float t = frameTimeCounter;
    vec2 p = uv * vec2(viewWidth / viewHeight, 1.0);
    // noise scrolls upwards like rising hot air
    vec2 n = textureLod(noisetex, p * 1.6 - vec2(0.0, t * 0.12), 0.0).xy - 0.5;
    n += (textureLod(noisetex, p * 3.7 - vec2(t * 0.02, t * 0.25), 0.0).yx - 0.5) * 0.6;
    return uv + n * vec2(0.7, 1.0) * heat * 0.009 * HEAT_HAZE_STRENGTH;
#else
    return uv;
#endif
}

// ---------------------------------------------------------------- painterly filter
// Kuwahara filter: picks the calmest of four neighbourhoods -> flat, brush-stroke like areas
vec3 painterly(vec2 uv, float strength) {
    int r = clamp(int(strength * 2.0 + 0.5), 1, 4);
    vec2 px = (viewHeight / 1080.0) / screenSize();
    vec3 bestMean = vec3(0.0);
    float bestVar = 1e9;
    for (int q = 0; q < 4; q++) {
        vec2 dirq = vec2((q & 1) == 0 ? -1.0 : 1.0, (q & 2) == 0 ? -1.0 : 1.0);
        vec3 m = vec3(0.0), m2 = vec3(0.0);
        float n = 0.0;
        for (int y = 0; y <= r; y++) for (int x = 0; x <= r; x++) {
            vec3 c = texture(colortex3, uv + vec2(x, y) * dirq * px * 1.5).rgb;
            c = c / (1.0 + c); // compress highlights so they don't dominate
            m += c; m2 += c * c; n += 1.0;
        }
        m /= n;
        vec3 v = m2 / n - m * m;
        float var = v.r + v.g + v.b;
        if (var < bestVar) { bestVar = var; bestMean = m; }
    }
    return bestMean / max(1.0 - bestMean, 1e-3);
}

// ---------------------------------------------------------------- depth of field
float viewDistAt(vec2 uv) {
    DepthSample d = sampleDepth(uv, true);
    if (!d.isDH && d.depth < 0.56) return -1.0; // hand
    return d.isSky ? 4000.0 : length(d.viewPos);
}

// circle of confusion in pixels for a given distance
float cocPixels(float dist, float focus) {
    if (dist < 0.0) return 0.0;
    // thin lens: blur grows with the difference of inverse distances, so far scenery
    // stays sharp and only things close to the lens (or a close focus) go soft
    float c = abs(1.0 / focus - 1.0 / dist);
    return min(c * 14.0 * DOF_STRENGTH * viewHeight / 1080.0, 5.0 * DOF_STRENGTH);
}

vec3 depthOfField(vec2 uv, out bool applied) {
    applied = false;
#ifdef DEPTH_OF_FIELD
    vec3 fv = screenToView(vec3(0.5, 0.5, centerDepthSmooth), gbufferProjectionInverse);
    float focus = centerDepthSmooth >= 0.9999 ? 256.0 : clamp(length(fv), 0.5, 256.0);
    float dist = viewDistAt(uv);
    float coc = cocPixels(dist, focus);
    if (coc < 0.6) return vec3(0.0);
    applied = true;
    vec2 px = 1.0 / screenSize();
    vec3 sum = vec3(0.0);
    float wsum = 0.0;
    const int taps = 16;
    float rot = ign(gl_FragCoord.xy) * TAU;
    for (int i = 0; i < taps; i++) {
        float r = sqrt((float(i) + 0.5) / float(taps)) * coc;
        float a = float(i) * 2.39996 + rot;
        vec2 o = vec2(cos(a), sin(a)) * r * px;
        float sDist = viewDistAt(uv + o);
        // a sharp sample may only contribute if it is behind us in focus terms (no halo bleed)
        float sCoc = sDist < 0.0 ? coc : cocPixels(sDist, focus);
        float w = smoothstep(r - 1.0, r + 0.5, max(sCoc, sDist > dist ? coc : 0.0));
        w = max(w, 0.02);
        sum += textureLod(colortex3, uv + o, log2(max(coc * 0.25, 1.0))).rgb * w;
        wsum += w;
    }
    return sum / wsum;
#else
    return vec3(0.0);
#endif
}

void main() {
    vec2 uv = heatHaze(texcoord);


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
        if (texcoord.y < bar || texcoord.y > 1.0 - bar) { fragColor = vec4(0.0, 0.0, 0.0, 1.0); return; }
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
    if (PAINTERLY > 0.0) {
        DepthSample pd = sampleDepth(uv, true);
        if (pd.isDH || pd.depth >= 0.56) {
            float pdist = pd.isSky ? 1e4 : length(pd.viewPos);
            // strongest in the mid ground, gone in the far distance and right in front of the lens
            float w = smoothstep(1.5, 5.0, pdist) * (1.0 - smoothstep(40.0, 140.0, pdist));
            if (w > 0.01) color = mix(color, painterly(uv, PAINTERLY), w);
        }
    }
    bool dofApplied;
    vec3 dof = depthOfField(uv, dofApplied);
    if (dofApplied) color = dof;

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
    bloom *= vec3(1.2, 0.96, 0.82); // red-orange halation like film
    color = mix(color, bloom, 0.075 * BLOOM_STRENGTH * (1.0 + rainStrength));
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

#ifdef KUROSAWA_MODE
    // black & white samurai film: hard contrast, strong grain, deep vignette
    {
        float k = luminance(color);
        k = smoothstep(0.02, 0.85, k);
        color = vec3(k);
    }
#endif
    color = linearToSrgb(color);

    // film grain (luminance weighted, strongest in the mid tones)
    float grain = hash12(gl_FragCoord.xy + fract(frameTimeCounter * 7.13) * 1000.0) - 0.5;
    float lum = luminance(color);
#ifdef KUROSAWA_MODE
    color += grain * 0.14 * (1.0 - abs(lum - 0.5) * 1.2);
#else
    color += grain * FILM_GRAIN * 0.08 * (1.0 - abs(lum - 0.5) * 1.4);
#endif

    // dithering against banding
    color += (hash12(gl_FragCoord.xy + 0.37) - 0.5) / 255.0;

    fragColor = vec4(color, 1.0);
}
#endif

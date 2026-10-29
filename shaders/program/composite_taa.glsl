// composite3: temporal anti-aliasing + auto exposure -> colortex3 (resolved) and colortex9 (history)

#include "/lib/common.glsl"

#ifdef VERTEX
out vec2 texcoord;
void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
#else
#include "/lib/depth.glsl"

const bool colortex3MipmapEnabled = true;

uniform sampler2D colortex3;
uniform sampler2D colortex9;

in vec2 texcoord;

/* RENDERTARGETS: 3,9 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outHistory;

vec3 rgbToYCoCg(vec3 c) {
    return vec3(0.25 * c.r + 0.5 * c.g + 0.25 * c.b, 0.5 * c.r - 0.5 * c.b, -0.25 * c.r + 0.5 * c.g - 0.25 * c.b);
}
vec3 yCoCgToRgb(vec3 c) {
    return vec3(c.x + c.y - c.z, c.x + c.z, c.x - c.y - c.z);
}

vec2 reproject(vec2 uv) {
    DepthSample ds = sampleDepth(uv, true);
    if (!ds.isDH && ds.depth < 0.56) return uv; // hand
    vec3 viewPos = ds.isSky ? normalize(ds.viewPos) * 1e4 : ds.viewPos;
    vec3 playerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
    vec3 camDelta = ds.isSky ? vec3(0.0) : cameraPosition - previousCameraPosition;
    vec3 prevView = (gbufferPreviousModelView * vec4(playerPos + camDelta, 1.0)).xyz;
#ifdef DISTANT_HORIZONS
    if (ds.isDH) return viewToScreen(prevView, dhPreviousProjection).xy;
#endif
    return viewToScreen(prevView, gbufferPreviousProjection).xy;
}

// sample history with a 5-tap Catmull-Rom filter (keeps the image sharp)
vec3 sampleHistory(vec2 uv) {
    vec2 size = screenSize();
    vec2 p = uv * size;
    vec2 tc = floor(p - 0.5) + 0.5;
    vec2 f = p - tc;
    vec2 w0 = f * (-0.5 + f * (1.0 - 0.5 * f));
    vec2 w1 = 1.0 + f * f * (-2.5 + 1.5 * f);
    vec2 w2 = f * (0.5 + f * (2.0 - 1.5 * f));
    vec2 w3 = f * f * (-0.5 + 0.5 * f);
    vec2 w12 = w1 + w2;
    vec2 tc0 = (tc - 1.0) / size;
    vec2 tc3 = (tc + 2.0) / size;
    vec2 tc12 = (tc + w2 / w12) / size;
    vec3 c = texture(colortex9, vec2(tc12.x, tc0.y)).rgb * (w12.x * w0.y)
           + texture(colortex9, vec2(tc0.x, tc12.y)).rgb * (w0.x * w12.y)
           + texture(colortex9, vec2(tc12.x, tc12.y)).rgb * (w12.x * w12.y)
           + texture(colortex9, vec2(tc3.x, tc12.y)).rgb * (w3.x * w12.y)
           + texture(colortex9, vec2(tc12.x, tc3.y)).rgb * (w12.x * w3.y);
    float wsum = w12.x * w0.y + w0.x * w12.y + w12.x * w12.y + w3.x * w12.y + w12.x * w3.y;
    return max(c / wsum, 0.0);
}

float computeExposure() {
    float prev = texelFetch(colortex9, ivec2(0), 0).a;
#ifdef AUTO_EXPOSURE
    float maxLod = floor(log2(max(viewWidth, viewHeight)));
    float lod = maxLod - 3.0;
    // centre weighted average of the scene luminance
    float lum = 0.0, wsum = 0.0;
    for (int x = -2; x <= 2; x++) for (int y = -2; y <= 2; y++) {
        vec2 o = vec2(x, y) * 0.18;
        float w = exp(-dot(o, o) * 6.0);
        float l = luminance(textureLod(colortex3, vec2(0.5) + o, lod).rgb);
        lum += log2(max(l, 1e-5)) * w;
        wsum += w;
    }
    lum = exp2(lum / wsum);
    // partial adaptation: dark scenes stay darker than bright ones (nights look like nights)
    float target = 0.2 / pow(max(lum, 1e-5), 0.8);
    target = clamp(target, 0.2, 4.0);
    if (prev <= 0.0 || isnan(prev)) return target;
    // adapt faster to bright light than to darkness (like an eye)
    float speed = target < prev ? 2.2 : 1.0;
    return mix(prev, target, 1.0 - exp(-frameTime * speed));
#else
    return 1.0;
#endif
}

void main() {
    ivec2 px = ivec2(gl_FragCoord.xy);
    vec3 current = texelFetch(colortex3, px, 0).rgb;
    float exposure = computeExposure();

#ifdef TAA
    vec2 prevUV = reproject(texcoord);
    // neighbourhood clamp in YCoCg (variance clipping)
    vec3 m1 = vec3(0.0), m2 = vec3(0.0);
    vec3 cmin = vec3(1e9), cmax = vec3(-1e9);
    for (int x = -1; x <= 1; x++) for (int y = -1; y <= 1; y++) {
        vec3 c = rgbToYCoCg(texelFetch(colortex3, px + ivec2(x, y), 0).rgb);
        m1 += c; m2 += c * c;
        cmin = min(cmin, c); cmax = max(cmax, c);
    }
    m1 /= 9.0; m2 /= 9.0;
    vec3 sigma = sqrt(max(m2 - m1 * m1, 0.0));
    vec3 lo = max(cmin, m1 - sigma * 1.25);
    vec3 hi = min(cmax, m1 + sigma * 1.25);

    bool offscreen = prevUV != clamp(prevUV, 0.0, 1.0);
    vec3 history = sampleHistory(prevUV);
    history = yCoCgToRgb(clamp(rgbToYCoCg(history), lo, hi));

    float motion = length((prevUV - texcoord) * screenSize());
    float blend = offscreen ? 0.0 : mix(0.9, 0.75, saturate(motion * 0.1));
    // first frame / invalid history
    if (texelFetch(colortex9, ivec2(0), 0).a <= 0.0) blend = 0.0;

    // weight by inverse luminance to avoid fireflies flickering
    float wc = (1.0 - blend) / (1.0 + luminance(current));
    float wh = blend / (1.0 + luminance(history));
    vec3 result = (current * wc + history * wh) / (wc + wh);
#else
    vec3 result = current;
#endif
    result = max(result, 0.0);
    if (any(isnan(result))) result = vec3(0.0);

    outColor = vec4(result, 1.0);
    outHistory = vec4(result, exposure);
}
#endif

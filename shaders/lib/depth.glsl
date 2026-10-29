// Depth helpers that understand Distant Horizons' separate depth buffers.

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex;
uniform sampler2D dhDepthTex1;
#endif

struct DepthSample {
    float depth;    // raw depth of the buffer that was hit
    vec3 viewPos;
    bool isDH;
    bool isSky;
};

// translucent = true -> include water/glass (depthtex0 / dhDepthTex)
DepthSample sampleDepth(vec2 uv, bool translucent) {
    DepthSample s;
    s.depth = translucent ? texture(depthtex0, uv).r : texture(depthtex1, uv).r;
    s.isDH = false;
    s.isSky = false;
    if (s.depth < 1.0) {
        s.viewPos = screenToView(vec3(uv, s.depth), gbufferProjectionInverse);
        return s;
    }
#ifdef DISTANT_HORIZONS
    float dh = translucent ? texture(dhDepthTex, uv).r : texture(dhDepthTex1, uv).r;
    if (dh < 1.0) {
        s.depth = dh;
        s.isDH = true;
        s.viewPos = screenToView(vec3(uv, dh), dhProjectionInverse);
        return s;
    }
#endif
    s.isSky = true;
    s.viewPos = screenToView(vec3(uv, 1.0), gbufferProjectionInverse);
    s.viewPos = normalize(s.viewPos) * 1e5;
    return s;
}

float linearizeDepth(float d, float n, float f) {
    return (2.0 * n * f) / (f + n - (d * 2.0 - 1.0) * (f - n));
}

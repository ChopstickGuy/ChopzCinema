// Screen space reflections against the lit opaque scene (colortex3).
// Works in view space; understands Distant Horizons depth for far hits.

// view-space z of the opaque surface at uv (negative numbers, -inf for sky)
float sceneViewZ(vec2 uv) {
    float d = texture(depthtex1, uv).r;
    if (d < 1.0) return screenToView(vec3(uv, d), gbufferProjectionInverse).z;
#ifdef DISTANT_HORIZONS
    float dh = texture(dhDepthTex1, uv).r;
    if (dh < 1.0) return screenToView(vec3(uv, dh), dhProjectionInverse).z;
#endif
    return -1e6;
}

// returns xy = hit uv, z = 1 on hit
vec3 traceSSR(vec3 viewPos, vec3 viewDir, float dither) {
    // project both ends of the ray to screen space and march there
    float maxDist = viewDir.z > 0.0 ? min(-viewPos.z * 0.9 / max(viewDir.z, 1e-3), 512.0) : 512.0;
    float stepLen = max(-viewPos.z, 1.0) * 0.06;
    vec3 p = viewPos;
    float t = stepLen * (0.25 + dither);
    vec3 prev = viewPos;
    for (int i = 0; i < SSR_STEPS; i++) {
        p = viewPos + viewDir * t;
        vec3 sp = viewToScreen(p, gbufferProjection);
        if (sp.x < 0.0 || sp.x > 1.0 || sp.y < 0.0 || sp.y > 1.0 || p.z > -near) break;
        float sz = sceneViewZ(sp.xy);
        float diff = sz - p.z; // > 0: ray is behind the surface
        float thickness = max(stepLen * 2.0, abs(p.z) * 0.02);
        if (diff > 0.0 && diff < thickness) {
            // binary refine
            vec3 a = prev, b = p;
            for (int j = 0; j < 4; j++) {
                vec3 m = (a + b) * 0.5;
                vec3 msp = viewToScreen(m, gbufferProjection);
                if (sceneViewZ(msp.xy) - m.z > 0.0) b = m; else a = m;
            }
            return vec3(viewToScreen(b, gbufferProjection).xy, 1.0);
        }
        prev = p;
        t += stepLen;
        stepLen *= 1.35;
        if (t > maxDist) break;
    }
    return vec3(0.0);
}

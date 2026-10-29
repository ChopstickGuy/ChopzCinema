#ifndef WATER_GLSL
#define WATER_GLSL
// Procedural water surface: sum of directional waves with analytic derivatives.

// Smooth value noise with analytic derivatives (quintic interpolation, no grid artefacts).
// returns x = value, yz = gradient
vec3 waterNoised(vec2 x) {
    vec2 i = floor(x);
    vec2 f = x - i;
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    vec2 du = 30.0 * f * f * (f * (f - 2.0) + 1.0);
    ivec2 ii = ivec2(mod(i, 256.0));
    float a = texelFetch(noisetex, ii, 0).x;
    float b = texelFetch(noisetex, (ii + ivec2(1, 0)) & 255, 0).x;
    float c = texelFetch(noisetex, (ii + ivec2(0, 1)) & 255, 0).x;
    float d = texelFetch(noisetex, (ii + ivec2(1, 1)) & 255, 0).x;
    float k1 = b - a, k2 = c - a, k4 = a - b - c + d;
    return vec3(a + k1 * u.x + k2 * u.y + k4 * u.x * u.y, du * vec2(k1 + k4 * u.y, k2 + k4 * u.x));
}

// Gradient of the water height field: several octaves of rotated, drifting noise
// (irregular, no repeating pattern) on top of two gentle swells.
vec2 waterWaveGradient(vec2 p) {
    float t = frameTimeCounter;
    vec2 grad = vec2(0.0);

    // long, soft swells in two non-parallel directions
    vec2 d1 = normalize(vec2(0.83, 0.56)), d2 = normalize(vec2(-0.38, 0.92));
    grad += d1 * cos(dot(d1, p) * 0.22 + t * 0.8) * 0.22 * 0.35;
    grad += d2 * cos(dot(d2, p) * 0.31 + t * 0.6) * 0.31 * 0.22;

    // choppy detail: each octave rotated (~37 deg), scaled and drifting its own way
    const mat2 rot = mat2(0.8, 0.6, -0.6, 0.8);
    mat2 m = mat2(1.0);
    float freq = 0.45;
    float amp = 1.0;
    vec2 drift = vec2(0.35, 0.2);
    for (int i = 0; i < 5; i++) {
        vec2 q = m * p * freq + drift * t;
        vec3 n = waterNoised(q);
        // chain rule: d/dp of n(m * p * freq + ...) = freq * m^T * dn
        grad += transpose(m) * n.yz * freq * amp;
        m = rot * m;
        freq *= 1.85;
        amp *= 0.5;
        drift = vec2(-drift.y, drift.x) * 1.3;
    }
    return grad * 0.11 * WATER_WAVE_HEIGHT * (1.0 + rainStrength * 0.6);
}

// world-space normal for a horizontal water surface
vec3 waterNormal(vec3 worldPos, float dist) {
#ifdef WATER_WAVES
    vec2 g = waterWaveGradient(worldPos.xz);
    // flatten in the distance to avoid aliasing shimmer
    g *= 1.0 / (1.0 + dist * 0.02);
    return normalize(vec3(-g.x, 1.0, -g.y));
#else
    return vec3(0.0, 1.0, 0.0);
#endif
}

// Absorption coefficients for underwater / through-water fog (per block)
vec3 waterAbsorption() {
    return vec3(0.42, 0.11, 0.075) / WATER_CLARITY;
}
vec3 waterScatterColor() {
    return vec3(0.008, 0.036, 0.06);
}

// Distance to the nearest cell border of an animated Voronoi pattern (0 on the border).
float causticCells(vec2 p, float t) {
    vec2 ip = floor(p), fp = fract(p);
    float d1 = 8.0, d2 = 8.0;
    for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
        vec2 g = vec2(x, y);
        vec2 o = hash22(ip + g);
        o = 0.5 + 0.4 * sin(t + TAU * o);
        vec2 r = g + o - fp;
        float d = dot(r, r);
        if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
    }
    return sqrt(d2) - sqrt(d1);
}

// Caustics: bright net of focused light on things below the water surface (mean ~1).
// xz = point where the light entered the water, depth in blocks.
float waterCaustics(vec2 xz, float depth, const bool cheap) {
    float t = frameTimeCounter * 0.9;
    // gentle warp so the net wobbles with the waves
    vec2 p = xz * 0.45 + vec2(sin(xz.y * 0.4 + t * 0.7), cos(xz.x * 0.35 - t * 0.6)) * 0.35;
    // shallow water: sharp thin lines, deeper: wider and softer
    float width = mix(0.05, 0.22, saturate(depth / 12.0));
    float c = exp(-causticCells(p, t) / width);
    if (!cheap) c = (c + exp(-causticCells(p * 1.37 + 5.3, t * 1.13 + 2.0) / width)) * 0.5;
    float caustic = 0.35 + c * 2.6;
    return mix(caustic, 1.0, smoothstep(8.0, 28.0, depth));
}
#endif

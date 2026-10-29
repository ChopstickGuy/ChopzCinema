#ifndef WATER_GLSL
#define WATER_GLSL
// Procedural water surface: sum of directional waves with analytic derivatives.

vec2 waterWaveGradient(vec2 p) {
    float t = frameTimeCounter;
    vec2 grad = vec2(0.0);
    float amp = 0.055 * WATER_WAVE_HEIGHT;
    float freq = 0.55;
    float speed = 1.1;
    float ang = 0.6;
    // small domain warp so the pattern doesn't look like a grid of sines
    p += vec2(sin(p.y * 0.21 + t * 0.3), cos(p.x * 0.17 - t * 0.25)) * 0.9;
    for (int i = 0; i < 6; i++) {
        vec2 dir = vec2(cos(ang), sin(ang));
        float x = dot(dir, p) * freq + t * speed;
        // sharpened sine (peaky crests): h = amp * (sin+1)^2/2 -> dh = amp*(sin+1)*cos*freq
        float s = sin(x);
        grad += dir * amp * (s + 1.0) * cos(x) * freq;
        amp *= 0.62;
        freq *= 1.75;
        speed *= 1.3;
        ang += 2.1;
    }
    return grad * (1.0 + rainStrength * 0.6);
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
    return vec3(0.012, 0.06, 0.07);
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

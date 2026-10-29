#ifndef RAIN_GLSL
#define RAIN_GLSL
// Rain helpers: raindrop ripples on water/puddles and lightning flashes.

uniform vec4 lightningBoltPosition; // w = 1 while a bolt exists (Iris)

// 0..1 brightness of the current lightning flash, flickering like the real thing
float lightningFlash() {
#ifdef LIGHTNING_FLASH
    if (lightningBoltPosition.w < 0.5) return 0.0;
    return 0.55 + 0.45 * hashInt(frameCounter / 2);
#else
    return 0.0;
#endif
}

// one layer of expanding rings, one drop per cell
vec2 rippleLayer(vec2 p, float t, float seed) {
    vec2 cell = floor(p);
    vec2 f = fract(p);
    float h = hash12(cell + seed);
    float life = fract(t * (0.9 + 0.5 * h) + h);
    vec2 center = 0.25 + 0.5 * hash22(cell + seed * 1.7);
    vec2 d = f - center;
    float r = length(d);
    float x = r - life * 0.45;
    float env = exp(-x * x * 500.0) * sq(1.0 - life);
    float dh = cos(x * 70.0) * env;
    return d / max(r, 1e-4) * dh;
}

// gradient of the ripple height field at a horizontal position (0 when not raining)
vec2 rainRipples(vec2 xz) {
#ifdef RAIN_RIPPLES
    if (rainStrength < 0.01) return vec2(0.0);
    float t = frameTimeCounter * 1.3;
    vec2 g = rippleLayer(xz * 1.6, t, 0.0);
    g += rippleLayer(xz * 1.6 + vec2(0.37, 0.71), t + 0.5, 13.0);
    g += rippleLayer(xz * 2.3 + vec2(0.11, 0.53), t * 1.2 + 0.25, 29.0) * 0.6;
    return g * 0.35 * rainStrength;
#else
    return vec2(0.0);
#endif
}
#endif

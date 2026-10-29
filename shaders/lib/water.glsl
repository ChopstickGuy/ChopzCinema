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

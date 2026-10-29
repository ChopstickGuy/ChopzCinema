// Material tweaks shared between lighting and reflections.

// Rain makes upward facing, sky-exposed surfaces wet: darker albedo, shiny puddles.
float puddleAmount(vec3 worldPos, vec3 normal, float skyLm) {
#ifdef RAIN_PUDDLES
    float w = wetness * smoothstep(0.85, 0.95, skyLm) * smoothstep(0.7, 0.95, normal.y);
    if (w <= 0.0) return 0.0;
    vec2 p = worldPos.xz * 0.08;
    float n = textureLod(noisetex, p / 4.0, 0.0).x * 0.6 + textureLod(noisetex, p, 0.0).x * 0.4;
    return w * smoothstep(0.35, 0.6, n);
#else
    return 0.0;
#endif
}

void applyWetness(inout Surface s, vec3 worldPos) {
    float wet = wetness * smoothstep(0.85, 0.95, s.lightmap.y);
    s.albedo *= 1.0 - wet * 0.35 * (1.0 - s.metal);
    float puddle = puddleAmount(worldPos, s.normal, s.lightmap.y);
    s.smoothness = max(s.smoothness, mix(wet * 0.5, 0.95, puddle));
}

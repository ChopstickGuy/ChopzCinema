// Falling leaves and petals drifting on the wind (world anchored, so they parallax correctly).
// Needs atmosphere.glsl (hash13 from nightsky.glsl).

vec4 fallingLeaves(vec3 ro, vec3 rd, float maxDist, vec3 lightDir, vec3 lightCol, vec3 ambient) {
#ifdef FALLING_LEAVES
    const float S = 2.5;     // cell size in blocks
    const int steps = 18;
    float time = frameTimeCounter;
    vec4 acc = vec4(0.0);
    vec3 lastCell = vec3(-1e6);
    for (int i = 0; i < steps; i++) {
        float t = 1.0 + float(i) * S * 0.75;
        if (t > maxDist + S) break;
        vec3 cell = floor((ro + rd * t) / S);
        if (cell == lastCell) continue;
        lastCell = cell;
        float h = hash13(cell + 0.37);
        if (h > LEAVES_DENSITY * 0.26) continue;
        vec3 rnd = vec3(hash13(cell + 1.1), hash13(cell + 2.2), hash13(cell + 3.3));
        // leaf sinks through its cell and drifts with the wind
        float fall = fract(rnd.y - time * (0.06 + 0.05 * rnd.x));
        vec3 L = (cell + vec3(rnd.x, fall, rnd.z)) * S;
        L.x += sin(time * 0.9 + h * 40.0) * 0.35 + fract(time * 0.03 + rnd.z) * 0.6;
        L.z += cos(time * 0.7 + h * 30.0) * 0.35;
        float tc = dot(L - ro, rd);
        if (tc < 3.0 || tc > maxDist) continue;
        vec3 d = ro + rd * tc - L;
        // fluttering flat leaf: elliptical shape on a rotating axis
        float ang = time * (1.4 + rnd.z * 2.0) + h * 20.0;
        vec3 ax = normalize(vec3(cos(ang), 0.35 * sin(ang * 1.3), sin(ang)));
        float u = dot(d, ax);
        float v = length(d - ax * u);
        float size = 0.13 + 0.07 * rnd.x;
        float shape = sq(u / size) + sq(v / (size * 0.5));
        if (shape > 1.0) continue;
        float a = smoothstep(1.0, 0.55, shape);
        a *= smoothstep(0.0, 0.08, fall) * smoothstep(1.0, 0.92, fall); // fade at the cell edges
        a *= smoothstep(maxDist, maxDist - 1.0, tc) * smoothstep(48.0, 20.0, tc);
        // types: cherry petals, red maple, golden leaves, pale green
        float k = fract(h * 91.7);
        vec3 alb = k < 0.35 ? vec3(1.0, 0.7, 0.78) : (k < 0.65 ? vec3(0.8, 0.16, 0.06) : (k < 0.88 ? vec3(0.95, 0.66, 0.16) : vec3(0.6, 0.75, 0.3)));
        float back = pow(saturate(dot(rd, lightDir)), 3.0);
        vec3 lit = alb * (lightCol * (0.35 + 1.2 * back) + ambient * 1.3);
        acc.rgb += (1.0 - acc.a) * lit * a;
        acc.a += (1.0 - acc.a) * a;
        if (acc.a > 0.95) break;
    }
    return acc;
#else
    return vec4(0.0);
#endif
}

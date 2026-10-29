// Leaves and petals carried by the wind (world anchored, so they parallax correctly).
// Sparse most of the time, gusts throw bursts of them through the air.
// Needs atmosphere.glsl (hash13 from nightsky.glsl).

const vec2 LEAF_WIND = vec2(0.87, 0.49); // same direction as the wind gusts

// 0..1 gust strength at a world position (matches the gust fronts in waving.glsl)
float leafGust(vec3 p, float t) {
    float front = sin(dot(p.xz, vec2(0.085, 0.045)) - t * 1.4);
    return smoothstep(0.2, 1.0, front);
}

vec4 fallingLeaves(vec3 ro, vec3 rd, float maxDist, vec3 lightDir, vec3 lightCol, vec3 ambient, vec3 sunDir) {
#ifdef FALLING_LEAVES
    const float S = 2.5;     // cell size in blocks
    const int steps = 18;
    float time = frameTimeCounter;
    float storm = rainStrength;
    float dusk = smoothstep(0.35, 0.05, sunDir.y) * smoothstep(-0.1, 0.02, sunDir.y);
    vec4 acc = vec4(0.0);
    vec3 lastCell = vec3(-1e6);
    for (int i = 0; i < steps; i++) {
        float t = 3.0 + float(i) * S * 0.75;
        if (t > maxDist + S) break;
        vec3 cell = floor((ro + rd * t) / S);
        if (cell == lastCell) continue;
        lastCell = cell;
        float h = hash13(cell + 0.37);
        // dynamic density: a calm trickle, bursts where a gust passes, more in storms
        float gust = leafGust(cell * S, time);
        float density = LEAVES_DENSITY * (0.03 + 0.2 * gust + 0.5 * storm);
        if (h > density) continue;
        vec3 rnd = vec3(hash13(cell + 1.1), hash13(cell + 2.2), hash13(cell + 3.3));
        // carried sideways by the wind, slowly sinking, spiralling
        float speed = (0.25 + 0.35 * rnd.x) * (1.0 + 1.5 * gust + 2.0 * storm);
        vec3 f = vec3(fract(rnd.x + time * speed * LEAF_WIND.x * 0.4),
                      fract(rnd.y - time * (0.05 + 0.04 * rnd.z)),
                      fract(rnd.z + time * speed * LEAF_WIND.y * 0.4));
        vec3 L = (cell + f) * S;
        L += vec3(sin(time * 2.1 + h * 40.0), sin(time * 1.7 + h * 13.0) * 0.6, cos(time * 1.9 + h * 30.0)) * 0.18;
        float tc = dot(L - ro, rd);
        if (tc < 3.0 || tc > maxDist) continue;
        vec3 d = ro + rd * tc - L;
        // fluttering flat leaf: elongated ellipse on a tumbling axis
        float ang = time * (2.0 + rnd.z * 3.0) + h * 20.0;
        vec3 ax = normalize(vec3(cos(ang), 0.4 * sin(ang * 1.3), sin(ang)));
        float u = dot(d, ax);
        float v = length(d - ax * u);
        float size = 0.1 + 0.05 * rnd.x;
        float shape = sq(u / size) + sq(v / (size * 0.42));
        if (shape > 1.0) continue;
        float a = smoothstep(1.0, 0.5, shape);
        // fade where the leaf wraps around its cell
        vec3 edge = smoothstep(vec3(0.0), vec3(0.1), f) * smoothstep(vec3(1.0), vec3(0.9), f);
        a *= edge.x * edge.y * edge.z;
        a *= smoothstep(maxDist, maxDist - 1.0, tc) * smoothstep(42.0, 18.0, tc);
        // colours follow the mood: mostly green leaves, red petals at dusk, a little gold
        float k = fract(h * 91.7);
        float redShare = 0.12 + 0.5 * dusk;
        vec3 alb;
        if (k < redShare) alb = vec3(0.75, 0.07, 0.05);                       // red petals
        else if (k < redShare + 0.12) alb = vec3(0.85, 0.6, 0.15);            // golden leaves
        else alb = mix(vec3(0.18, 0.42, 0.1), vec3(0.4, 0.6, 0.15), fract(k * 7.3)); // green leaves
        float back = pow(saturate(dot(rd, lightDir)), 3.0);
        vec3 lit = alb * (lightCol * (0.35 + 1.4 * back) + ambient * 1.2);
        acc.rgb += (1.0 - acc.a) * lit * a;
        acc.a += (1.0 - acc.a) * a;
        if (acc.a > 0.95) break;
    }
    return acc;
#else
    return vec4(0.0);
#endif
}

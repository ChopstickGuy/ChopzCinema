// Tonemapping and colour grading

// ---------------------------------------------------------------- tonemapping
vec3 acesFitted(vec3 v) {
    const mat3 ACESInput = mat3(0.59719, 0.07600, 0.02840, 0.35458, 0.90834, 0.13383, 0.04823, 0.01566, 0.83777);
    const mat3 ACESOutput = mat3(1.60475, -0.10208, -0.00327, -0.53108, 1.10813, -0.07276, -0.07367, -0.00605, 1.07602);
    v = ACESInput * v;
    vec3 a = v * (v + 0.0245786) - 0.000090537;
    vec3 b = v * (0.983729 * v + 0.4329510) + 0.238081;
    return clamp(ACESOutput * (a / b), 0.0, 1.0);
}

vec3 agxContrast(vec3 x) {
    vec3 x2 = x * x;
    vec3 x4 = x2 * x2;
    return 15.5 * x4 * x2 - 40.14 * x4 * x + 31.96 * x4 - 6.868 * x2 * x + 0.4298 * x2 + 0.1191 * x - 0.00232;
}
vec3 agx(vec3 v) {
    const mat3 agxIn = mat3(0.842479062253094, 0.0423282422610123, 0.0423756549057051,
                            0.0784335999999992, 0.878468636469772, 0.0784336,
                            0.0792237451477643, 0.0791661274605434, 0.879142973793104);
    const mat3 agxOut = mat3(1.19687900512017, -0.0528968517574562, -0.0529716355144438,
                             -0.0980208811401368, 1.15190312990417, -0.0980434501171241,
                             -0.0990297440797205, -0.0989611768448433, 1.15107367264116);
    const float minEv = -12.47393, maxEv = 4.026069;
    v = agxIn * max(v, 1e-10);
    v = clamp(log2(v), minEv, maxEv);
    v = (v - minEv) / (maxEv - minEv);
    v = agxContrast(v);
    // "punchy" look: a bit more contrast and saturation
    v = pow(max(v, 0.0), vec3(1.2));
    float l = dot(v, vec3(0.2126, 0.7152, 0.0722));
    v = l + 1.1 * (v - l);
    v = agxOut * v;
    return clamp(pow(max(v, 0.0), vec3(2.2)), 0.0, 1.0);
}

vec3 tonemapUchimura(vec3 x) {
    const float P = 1.0, a = 1.0, m = 0.22, l = 0.4, c = 1.33, b = 0.0;
    float l0 = ((P - m) * l) / a;
    float S0 = m + l0, S1 = m + a * l0, C2 = (a * P) / (P - S1), CP = -C2 / P;
    vec3 w0 = 1.0 - smoothstep(0.0, m, x);
    vec3 w2 = step(m + l0, x);
    vec3 w1 = 1.0 - w0 - w2;
    vec3 T = m * pow(x / m, vec3(c)) + b;
    vec3 S = P - (P - S1) * exp(CP * (x - S0));
    vec3 L = m + a * (x - m);
    return T * w0 + L * w1 + S * w2;
}

vec3 tonemap(vec3 c) {
#if TONEMAP == 0
    return acesFitted(c);
#elif TONEMAP == 1
    return agx(c);
#else
    return tonemapUchimura(c);
#endif
}

// ---------------------------------------------------------------- grading (display-referred, linear)
vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}
vec3 hsv2rgb(vec3 c) {
    vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
    return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

// Print film style curve on display-referred linear values:
// crushed, inky toe ("shadows are not grey, they're black") and a firm S in the mids.
vec3 printCurve(vec3 c) {
    // nights keep a little more detail in the shadows
#ifdef DIM_OVERWORLD
    float night = smoothstep(0.0, -0.2, sunDirWorld().y);
#else
    float night = 0.0;
#endif
    float crush = mix(0.018, 0.006, night);
    vec3 p = pow(max(c, 0.0), vec3(1.0 / 2.2));
    p = max(p - crush, 0.0) / (1.0 - crush);         // black crush
    p = mix(p, p * p * (3.0 - 2.0 * p), 0.32);       // S-curve
    return pow(p, vec3(2.2));
}

vec3 colorGrade(vec3 c) {
    float l = luminance(c);
    vec3 graded = c;
#if COLOR_GRADE == 1
    // "Blockbuster": teal shadows, warm skin-tone highlights
    vec3 shadowTint = vec3(0.86, 1.0, 1.12);
    vec3 highTint = vec3(1.10, 1.0, 0.86);
    float hw = smoothstep(0.05, 0.6, l);
    graded *= mix(shadowTint, highTint, hw);
#elif COLOR_GRADE == 2
    // "Moody": cooler, slightly desaturated, deep blacks
    graded = mix(vec3(l), graded, 0.8) * vec3(0.93, 1.0, 1.08);
    graded = pow(graded, vec3(1.08));
#elif COLOR_GRADE == 3
    // "Golden hour": warm overall, soft highlights
    graded *= vec3(1.08, 1.0, 0.85);
    graded = mix(graded, vec3(l) * vec3(1.1, 0.95, 0.75), 0.08);
#elif COLOR_GRADE == 4
    // "Brand New Day": classic print curve, inky blacks, saturated reds and blues,
    // restrained greens, cool shadows / warm highlights
    graded = printCurve(graded);
    vec3 hsv = rgb2hsv(graded);
    float h = hsv.x;
    float red = max(smoothstep(0.09, 0.0, h), smoothstep(0.92, 1.0, h));
    float blue = exp(-sq((h - 0.61) / 0.07));
    float green = exp(-sq((h - 0.28) / 0.10));
    hsv.y *= 1.0 + 0.35 * red + 0.3 * blue - 0.18 * green;
    hsv.x += green * 0.015;                 // foliage drifts a touch towards teal like print film
    hsv.y = saturate(hsv.y);
    graded = hsv2rgb(hsv);
    float lum4 = luminance(graded);
    float sh = smoothstep(0.3, 0.02, lum4) * smoothstep(0.0, 0.02, lum4);
    float hi = smoothstep(0.4, 0.9, lum4);
#ifdef DIM_OVERWORLD
    float day4 = smoothstep(-0.05, 0.25, sunDirWorld().y);
#else
    float day4 = 0.0;
#endif
    // cool shadows at night, only a hint of it by day
    graded *= mix(vec3(1.0), vec3(0.9, 1.0, 1.1), sh * mix(0.7, 0.3, day4));
    // warm daylight white balance: sunny scenes feel golden instead of cold
    graded *= mix(vec3(1.0), vec3(1.07, 1.01, 0.88), day4 * 0.75);
    graded *= mix(vec3(1.0), vec3(1.07, 1.0, 0.9), hi * 0.7);
#elif COLOR_GRADE == 5
    // "Tsushima": painterly, lush and warm - saturated nature, golden light,
    // soft violet-blue shadows that never go fully black
    vec3 hsv5 = rgb2hsv(graded);
    float h5 = hsv5.x;
    float green5 = exp(-sq((h5 - 0.28) / 0.10));
    float red5 = max(smoothstep(0.09, 0.0, h5), smoothstep(0.92, 1.0, h5));
    float yellow5 = exp(-sq((h5 - 0.13) / 0.06));
    hsv5.x -= green5 * 0.025;                    // greens lean towards golden yellow-green
#ifdef DIM_OVERWORLD
    {
        // Tsushima dusk: oranges turn hot pink-red, blues turn violet
        float sy = sunDirWorld().y;
        float dusk5 = smoothstep(0.4, 0.04, sy) * smoothstep(-0.15, 0.0, sy) * (1.0 - rainStrength);
        float orange5 = exp(-sq((h5 - 0.08) / 0.07));
        float blue5 = exp(-sq((h5 - 0.62) / 0.1));
        hsv5.x += (-0.04 * orange5 + 0.06 * blue5) * dusk5;
        hsv5.x = fract(hsv5.x);
        hsv5.y *= 1.0 + 0.08 * dusk5;
    }
#endif
    hsv5.y = hsv5.y * (1.4 + 0.25 * red5 + 0.2 * yellow5);
    hsv5.y = 0.9 * (1.0 - exp(-hsv5.y * 1.9));   // soft saturation ceiling: no flat, clipped colour areas
    graded = hsv2rgb(hsv5);
    float lum5 = luminance(graded);
    graded = graded * 0.95 + vec3(0.032, 0.026, 0.055) * (1.0 - smoothstep(0.0, 0.35, lum5));
    graded *= mix(vec3(1.0), vec3(1.12, 1.02, 0.82), smoothstep(0.3, 0.9, lum5) * 0.8);
    vec3 p5 = pow(max(graded, 0.0), vec3(1.0 / 2.2));
    p5 = mix(p5, p5 * p5 * (3.0 - 2.0 * p5), 0.18);
    graded = pow(p5, vec3(2.2));
#endif
    graded = mix(c, graded, GRADE_STRENGTH);

    // golden hour: warm the whole frame a little while the sun is low
#ifdef DIM_OVERWORLD
    {
        float sy = sunDirWorld().y;
        float golden = smoothstep(0.55, 0.04, sy) * smoothstep(-0.08, 0.02, sy) * (1.0 - rainStrength);
        graded *= mix(vec3(1.0), vec3(1.1, 1.0, 0.84), golden * 0.7);
    }
#endif

    // rain: cooler, more desaturated, a bit more contrast - like a rainy scene in a film
    float rainMood = rainStrength * RAIN_MOOD;
    if (rainMood > 0.0) {
        float lr = luminance(graded);
#if COLOR_GRADE == 5
        vec3 moody = mix(vec3(lr), graded, 0.75) * vec3(0.9, 1.05, 0.98);   // Tsushima storms lean teal-green
#else
        vec3 moody = mix(vec3(lr), graded, 0.7) * vec3(0.93, 0.99, 1.07);
#endif
        graded = mix(graded, moody, rainMood);
    }

    // contrast around middle grey in log space
    vec3 lg = log2(max(graded, 1e-6));
    lg = (lg - log2(0.18)) * (CONTRAST + rainStrength * RAIN_MOOD * 0.06) + log2(0.18);
    graded = exp2(lg);
    // saturation
    float l2 = luminance(graded);
    graded = mix(vec3(l2), graded, SATURATION);
    return clamp(graded, 0.0, 1.0);
}

vec3 linearToSrgb(vec3 c) {
    return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
}


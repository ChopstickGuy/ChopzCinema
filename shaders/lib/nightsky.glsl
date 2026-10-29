// Night sky: rotating star field, Milky Way, shooting stars and the northern lights.
// All directions are world space, y = up. Needs common.glsl (noisetex, hashes).

// ---------------------------------------------------------------- helpers
vec3 rotateAxis(vec3 v, vec3 axis, float a) {
    float s = sin(a), c = cos(a);
    return v * c + cross(axis, v) * s + axis * dot(axis, v) * (1.0 - c);
}

// star field turns with the sun, like a real sky
vec3 toStarSpace(vec3 rd) {
    float r = radians(sunPathRotation);
    vec3 axis = normalize(vec3(0.0, sin(r), cos(r)));
    return rotateAxis(rd, axis, -sunAngle * TAU);
}

float hash13(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.zyx + 31.32);
    return fract((p.x + p.y) * p.z);
}

float valueNoise3(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x),
                   mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y),
               mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x),
                   mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm3(vec3 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += valueNoise3(p) * a;
        p = p * 2.03 + 7.1;
        a *= 0.5;
    }
    return v;
}

float nightFactor(vec3 sunDir) {
    return smoothstep(0.02, -0.18, sunDir.y) * (1.0 - rainStrength);
}

// ---------------------------------------------------------------- stars
// one layer of stars on a 3D grid; density = probability that a cell holds a star
vec3 starLayer(vec3 sd, float scale, float density, float size, float bright) {
    vec3 p = sd * scale;
    vec3 cell = floor(p);
    float h = hash13(cell);
    if (h > density) return vec3(0.0);
    // random position inside the cell
    vec3 center = cell + 0.25 + 0.5 * vec3(hash13(cell + 13.1), hash13(cell + 47.7), hash13(cell + 91.3));
    float d = length(p - center);
    float core = smoothstep(size, 0.0, d);
    if (core <= 0.0) return vec3(0.0);
    float rnd = hash13(cell + 5.5);
    // colour temperature: most stars white-blue, some warm
    float temp = rnd < 0.15 ? mix(3200.0, 4500.0, rnd / 0.15) : mix(6000.0, 11000.0, (rnd - 0.15) / 0.85);
    vec3 col = blackbody(temp);
    col /= max(maxOf(col), 1e-3);
    // magnitude distribution: many faint, few bright
    float mag = pow(hash13(cell + 2.2), 6.0) * 4.0 + 0.25;
    float twinkle = 0.8 + 0.2 * sin(frameTimeCounter * (2.0 + rnd * 3.0) + rnd * 100.0);
    return col * core * core * mag * twinkle * bright;
}

vec3 milkyWay(vec3 sd, out float bandMask) {
    bandMask = 0.0;
#ifdef MILKY_WAY
    const vec3 galacticNormal = normalize(vec3(0.35, 0.55, 0.76));
    float b = dot(sd, galacticNormal);
    float band = exp(-b * b * 22.0);
    bandMask = band;
    if (band < 0.01) return vec3(0.0);
    // galactic core is brighter on one side
    vec3 coreDir = normalize(cross(galacticNormal, vec3(0.0, 1.0, 0.0)));
    float core = pow(saturate(dot(sd, coreDir) * 0.5 + 0.5), 3.0);
    float clouds = fbm3(sd * 7.0);
    float fine = fbm3(sd * 22.0 + 3.0);
    float glow = band * (0.35 + 0.65 * smoothstep(0.3, 0.75, clouds)) * (0.6 + 0.8 * core);
    // dark dust lane through the middle
    float lane = exp(-b * b * 400.0) * smoothstep(0.35, 0.65, fbm3(sd * 11.0 + 9.0));
    glow *= 1.0 - lane * 0.85;
    glow *= 0.7 + 0.6 * fine;
    vec3 col = mix(vec3(0.55, 0.6, 1.0), vec3(1.0, 0.82, 0.62), core * 0.8 + clouds * 0.2);
    // faint reddish nebula patches
    col += vec3(0.6, 0.15, 0.25) * smoothstep(0.62, 0.8, fbm3(sd * 15.0 + 21.0)) * band;
    return col * glow * 0.01 * MILKY_WAY_BRIGHTNESS;
#else
    return vec3(0.0);
#endif
}

vec3 shootingStars(vec3 rd) {
#ifdef SHOOTING_STARS
    const float period = 7.0;   // one possible meteor every few seconds
    const float life = 0.9;
    float slot = floor(frameTimeCounter / period);
    float h = hashInt(int(slot) * 7919 + 17);
    if (h > 0.4) return vec3(0.0);
    float t = (frameTimeCounter - slot * period) / life;
    if (t > 1.0) return vec3(0.0);
    // random start in the upper sky and a random direction along the dome
    float az = hashInt(int(slot) * 31 + 5) * TAU;
    float el = mix(0.35, 1.1, hashInt(int(slot) * 131 + 9));
    vec3 start = vec3(cos(az) * cos(el), sin(el), sin(az) * cos(el));
    vec3 side = normalize(cross(start, vec3(0.0, 1.0, 0.0)));
    vec3 tangent = normalize(mix(side, -vec3(0.0, 1.0, 0.0), 0.35) * (hashInt(int(slot) * 61) > 0.5 ? 1.0 : -1.0));
    tangent = normalize(tangent - start * dot(tangent, start));
    float travel = 0.45;
    vec3 head = normalize(start + tangent * travel * t);
    vec3 tail = normalize(start + tangent * travel * max(t - 0.25, 0.0));
    vec3 ab = head - tail;
    float k = saturate(dot(rd - tail, ab) / max(dot(ab, ab), 1e-6));
    float d = length(rd - (tail + ab * k));
    float line = smoothstep(0.0018, 0.0, d) * k * k;  // bright head, fading tail
    float fade = smoothstep(0.0, 0.1, t) * smoothstep(1.0, 0.6, t);
    return vec3(0.9, 0.95, 1.0) * line * fade * 3.0;
#else
    return vec3(0.0);
#endif
}

// ---------------------------------------------------------------- northern lights
// 0 = none tonight, otherwise strength. Decided once per Minecraft day.
float auroraActivity() {
#if AURORA == 0 || !defined DIM_OVERWORLD
    return 0.0;
#else
    float night = smoothstep(-0.05, -0.25, sunDirWorld().y);
    if (night <= 0.0) return 0.0;
    float roll = hashInt(worldDay * 2654435 + 101);
#if AURORA == 1
    if (roll > AURORA_CHANCE) return 0.0;
#endif
    float strength = 0.55 + 0.45 * hashInt(worldDay * 9176 + 7);
    // slow "breathing" over the night
    float pulse = 0.65 + 0.35 * sin(frameTimeCounter * 0.06 + roll * 40.0);
    return night * strength * pulse * (1.0 - rainStrength) * AURORA_BRIGHTNESS;
#endif
}

float auroraNoise(vec2 p) {
    return textureLod(noisetex, p / 64.0, 0.0).x * 0.65 + textureLod(noisetex, p / 23.0 + 0.37, 0.0).x * 0.35;
}

// A few folded curtains hanging in the northern sky.
// p = horizontal position on the aurora layer (x = east/west, y = north/south)
float auroraCurtains(vec2 p, float t) {
    float acc = 0.0;
    for (int k = 0; k < 3; k++) {
        float fk = float(k);
        float baseZ = -2.6 - fk * 2.4;
        // big slow folds + smaller wobble
        float fold = sin(p.x * (0.28 + fk * 0.07) + t * 0.5 + fk * 2.1) * (1.0 + fk * 0.4)
                   + (auroraNoise(vec2(p.x * 0.9 + t * 1.5, fk * 17.0)) - 0.5) * 1.8;
        float d = p.y - (baseZ + fold);
        float w = 0.35 + fk * 0.12;
        float band = exp(-d * d / (w * w));
        // brightness varies along the curtain and over time
        float along = 0.35 + 0.65 * smoothstep(0.25, 0.75, auroraNoise(vec2(p.x * 0.35 - t * 0.8, fk * 5.0 + 3.0)));
        // fine vertical rays: depend only on the position along the curtain
        float rays = auroraNoise(vec2(p.x * 5.0 + fk * 31.0, t * 0.3));
        rays = 0.6 + 0.6 * rays * rays;
        acc += band * along * rays * (1.0 - fk * 0.25);
    }
    return acc;
}

vec3 aurora(vec3 rd, float activity, const int steps, float dither) {
    if (activity <= 0.0 || rd.y < 0.02) return vec3(0.0);
    float t = frameTimeCounter * 0.05;
    vec3 acc = vec3(0.0);
    for (int i = 0; i < steps; i++) {
        float h = (float(i) + dither) / float(steps);  // 0 = bottom edge of the curtain, 1 = top
        float alt = 1.0 + h * 1.8;
        vec2 p = rd.xz / rd.y * alt;
        float c = auroraCurtains(p, t);
        vec3 col = mix(vec3(0.1, 1.0, 0.35), vec3(0.1, 0.75, 0.9), smoothstep(0.2, 0.55, h));
        col = mix(col, vec3(0.7, 0.2, 0.95), smoothstep(0.5, 1.0, h));
        // sharp bright lower edge, soft fading top
        float profile = smoothstep(0.0, 0.05, h) * exp(-h * 2.2);
        acc += col * c * profile;
    }
    acc /= float(steps);
    float horizon = smoothstep(0.02, 0.15, rd.y);
    return acc * horizon * activity * 1.1;
}

// ---------------------------------------------------------------- moon
// Round procedural moon with craters and the vanilla moon phase.
vec3 moonDisk(vec3 rd, vec3 sunDir) {
#ifdef ROUND_SUN_MOON
    vec3 moonDir = -sunDir;
    float ang = smallAngle(rd, moonDir);
    const float baseRadius = 0.04;
    float r = baseRadius * MOON_SIZE;
    float glowAng = max(ang - r, 0.0);
    float vis = (1.0 - rainStrength) * smoothstep(-0.02, 0.0, rd.y);
    // soft halo around the moon (atmospheric scattering)
    vec3 halo = vec3(0.55, 0.65, 0.9) * (exp(-glowAng / (r * 1.5)) * 0.012 + exp(-ang / 0.15) * 0.002);
    if (ang > r * 1.02) return halo * vis * NIGHT_BRIGHTNESS;

    // local 2D coordinates on the disk
    vec3 right = normalize(cross(moonDir, abs(moonDir.y) > 0.98 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0)));
    vec3 up = cross(right, moonDir);
    vec2 uv = vec2(dot(rd - moonDir, right), dot(rd - moonDir, up)) / r;
    float d2 = dot(uv, uv);
    vec3 n = vec3(uv, sqrt(max(1.0 - d2, 0.0)));

    // phase: 0 = full moon, 4 = new moon. Light direction rotates around the moon.
    float phaseAngle = float(moonPhase) * (PI / 4.0);
    vec3 L = vec3(sin(phaseAngle), 0.0, cos(phaseAngle));
    float lit = smoothstep(-0.06, 0.12, dot(n, L));

    // surface: dark "seas" + small craters
    vec3 sp = vec3(uv * 2.2, 3.7);
    float maria = smoothstep(0.42, 0.62, fbm3(sp));
    float craters = fbm3(sp * 4.0 + 11.0);
    float albedo = mix(0.95, 0.55, maria) * (0.85 + 0.3 * craters);
    float limb = 0.75 + 0.25 * n.z;

    float edge = r * 0.06;
    float mask = 1.0 - smoothstep(r - edge, r + edge, ang);
    vec3 surface = vec3(0.92, 0.95, 1.0) * albedo * limb * (lit * 0.32 + 0.004);
    return (surface * mask + halo) * vis * NIGHT_BRIGHTNESS;
#else
    return vec3(0.0);
#endif
}

// ---------------------------------------------------------------- everything together
vec3 nightSky(vec3 rd, vec3 sunDir, float dither, const bool reflection) {
    float night = nightFactor(sunDir);
    vec3 col = vec3(0.0);
    if (rd.y > -0.05) {
#ifdef STARS
        if (night > 0.0) {
            vec3 sd = toStarSpace(rd);
            float band;
            vec3 mw = milkyWay(sd, band);
            vec3 st = starLayer(sd, 520.0, 0.10 * STAR_AMOUNT * (1.0 + band * 3.0), 0.34, 0.35);
            st += starLayer(sd, 220.0, 0.05 * STAR_AMOUNT * (1.0 + band), 0.26, 1.0);
            st += starLayer(sd * 1.0001, 90.0, 0.03 * STAR_AMOUNT, 0.16, 3.0);
            float horizonFade = smoothstep(-0.02, 0.25, rd.y);
            col += (st * 0.1 * STAR_BRIGHTNESS + mw) * night * horizonFade;
            if (!reflection) col += shootingStars(rd) * night * 0.05;
        }
#endif
        col += aurora(rd, auroraActivity(), reflection ? 10 : 24, dither);
    }
    return col;
}

// kept for the End dimension
vec3 stars(vec3 rd, vec3 sunDir) {
    vec3 sd = rd;
    vec3 st = starLayer(sd, 420.0, 0.06 * STAR_AMOUNT, 0.32, 0.25) + starLayer(sd, 160.0, 0.025 * STAR_AMOUNT, 0.22, 1.0);
    return st * 0.05 * STAR_BRIGHTNESS;
}

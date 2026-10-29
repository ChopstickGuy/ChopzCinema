// Raymarched volumetric cumulus layer. Rendered at half resolution.


// 3D value noise from the 2D noise texture: two offset slices blended along z.
// p.xy is the (horizontal) texture plane.
float cloudNoise3D(vec3 p) {
    float iz = floor(p.z);
    float fz = p.z - iz;
    fz = fz * fz * (3.0 - 2.0 * fz);
    vec2 uv = p.xy + vec2(37.0, 17.0) * iz;
    float a = textureLod(noisetex, (uv + 0.5) / 256.0, 0.0).x;
    float b = textureLod(noisetex, (uv + vec2(37.0, 17.0) + 0.5) / 256.0, 0.0).x;
    return mix(a, b, fz);
}

float cloudCoverage() {
    return mix(CLOUD_COVERAGE, 0.9, rainStrength);
}

// p: world position. returns density
float cloudDensity(vec3 p, const bool detail) {
    float h = (p.y - CLOUD_HEIGHT) / CLOUD_THICKNESS;
    if (h < 0.0 || h > 1.0) return 0.0;
    float t = frameTimeCounter * 0.6 * CLOUD_SPEED;
    vec3 wind = vec3(t * 2.0, 0.0, t * 0.8);
    vec3 q = (p + wind) * 0.0042;
    vec3 qh = q.xzy; // horizontal plane -> texture plane

    // large scale weather pattern decides where clouds may form
    float weather = cloudNoise3D(vec3(qh.xy * 0.22, 3.7));
    weather = smoothstep(0.25, 0.75, weather);

    float base = cloudNoise3D(vec3(qh.xy, qh.z * 0.5)) * 0.55;
    base += cloudNoise3D(qh * 2.4 + 11.0) * 0.28;
    base += cloudNoise3D(qh * 5.3 + 27.0) * 0.17;

    // vertical profile: flat bottoms, rounded towers
    float profile = smoothstep(0.0, 0.1, h) * smoothstep(1.0, 0.35, h);
    float cov = cloudCoverage() * mix(0.7, 1.25, weather);
    float d = base * mix(0.55, 1.0, profile) - (1.0 - cov);
    d *= profile;

    if (detail && d > -0.02) {
        float er = cloudNoise3D(p.xzy * 0.035 + vec3(t * 0.03, -t * 0.02, 0.0)) * 0.6
                 + cloudNoise3D(p.xzy * 0.09 + 5.0) * 0.4;
        // erode more at the bottom (wispy) than at the top (puffy)
        d -= er * 0.12 * (1.2 - h);
    }
    return saturate(d * 5.0);
}

// distance along ray to the cloud slab
vec2 cloudSlab(vec3 ro, vec3 rd) {
    float b0 = CLOUD_HEIGHT, b1 = CLOUD_HEIGHT + CLOUD_THICKNESS;
    if (abs(rd.y) < 1e-4) {
        if (ro.y < b0 || ro.y > b1) return vec2(-1.0);
        return vec2(0.0, 6000.0);
    }
    float t0 = (b0 - ro.y) / rd.y;
    float t1 = (b1 - ro.y) / rd.y;
    float tn = max(min(t0, t1), 0.0);
    float tf = max(t0, t1);
    if (tf <= 0.0) return vec2(-1.0);
    return vec2(tn, tf);
}

float cloudLightMarch(vec3 p, vec3 l) {
    float od = 0.0;
    float step = CLOUD_THICKNESS * 0.12;
    for (int i = 0; i < 4; i++) {
        p += l * step;
        od += cloudDensity(p, false) * step;
        step *= 1.6;
    }
    return od;
}

// Returns rgb in-scattered light, a = transmittance.
// rayLen = distance to opaque geometry (or huge for sky).
vec4 renderClouds(vec3 playerDir, float rayLen, vec3 sunDir, vec3 lightCol, vec3 skyCol, float dither) {
    vec3 ro = cameraPosition;
    vec2 slab = cloudSlab(ro, playerDir);
    if (slab.x < 0.0) return vec4(0.0, 0.0, 0.0, 1.0);
    float tStart = slab.x;
    float tEnd = min(slab.y, rayLen);
    tEnd = min(tEnd, tStart + 4000.0);
    if (tEnd <= tStart) return vec4(0.0, 0.0, 0.0, 1.0);

#if CLOUD_QUALITY == 0
    const int steps = 16;
#elif CLOUD_QUALITY == 1
    const int steps = 24;
#else
    const int steps = 40;
#endif
    float dt = (tEnd - tStart) / float(steps);
    vec3 l = sunDir.y > -0.05 ? sunDir : -sunDir;
    float mu = dot(playerDir, l);
    // dual-lobe phase: strong forward silver lining + soft back scatter
    float phase = mix(hgPhase(mu, 0.6), hgPhase(mu, -0.2), 0.3) * 4.0 * PI;

    float sigma = 0.06 * (1.0 + rainStrength);
    float trans = 1.0;
    vec3 scatter = vec3(0.0);
    vec3 ambient = skyCol;
    for (int i = 0; i < steps; i++) {
        float t = tStart + dt * (float(i) + dither);
        vec3 p = ro + playerDir * t;
        float d = cloudDensity(p, true);
        if (d <= 0.0) continue;
        float h = saturate((p.y - CLOUD_HEIGHT) / CLOUD_THICKNESS);
        float lod = cloudLightMarch(p, l) * sigma;
        // multiple scattering approximation (3 octaves)
        float beer = exp(-lod) + exp(-lod * 0.25) * 0.4 + exp(-lod * 0.06) * 0.15;
        float powder = 1.0 - exp(-d * 2.5);
        vec3 sun = lightCol * beer * phase * mix(1.0, powder, 0.6) * 0.45;
        vec3 amb = ambient * (0.3 + h * 0.7) * 1.4;
        vec3 s = (sun + amb) * d * sigma;
        float tr = exp(-d * sigma * dt);
        // energy-conserving integration
        scatter += trans * s * (1.0 - tr) / max(d * sigma, 1e-5);
        trans *= tr;
        if (trans < 0.02) break;
    }

    // fade into the distance (aerial perspective is applied by the fog pass)
    float fade = exp(-tStart * 0.00028);
    scatter *= fade;
    trans = mix(1.0, trans, fade);
    return vec4(scatter, trans);
}

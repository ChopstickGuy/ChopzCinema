// Physically based single-scattering sky (Rayleigh + Mie + ozone),
// with cheap analytic helpers for sun colour and ambient light.
// All directions are world space, y = up.

const float ATMO_R_GROUND = 6371e3;
const float ATMO_R_TOP = 6471e3;
const vec3 ATMO_RAYLEIGH = vec3(5.802e-6, 13.558e-6, 33.1e-6);
const float ATMO_H_RAYLEIGH = 8000.0;
const float ATMO_MIE_SCATTER = 3.996e-6;
const float ATMO_MIE_EXTINCT = 4.44e-6;
const float ATMO_H_MIE = 1200.0;
const vec3 ATMO_OZONE = vec3(0.650e-6, 1.881e-6, 0.085e-6);
const float SKY_GAIN = 18.0;

const float MOON_ILLUM = 0.035;

float rayleighPhase(float mu) { return 3.0 / (16.0 * PI) * (1.0 + mu * mu); }
float hgPhase(float mu, float g) {
    float g2 = g * g;
    return (1.0 - g2) / (4.0 * PI * pow(1.0 + g2 - 2.0 * g * mu, 1.5));
}
// Cornette-Shanks
float miePhase(float mu, float g) {
    float g2 = g * g;
    return 3.0 / (8.0 * PI) * ((1.0 - g2) * (1.0 + mu * mu)) / ((2.0 + g2) * pow(1.0 + g2 - 2.0 * g * mu, 1.5));
}

// distance to the far intersection with a sphere centered at origin
float raySphereFar(vec3 ro, vec3 rd, float r) {
    float b = dot(ro, rd);
    float c = dot(ro, ro) - r * r;
    float d = b * b - c;
    if (d < 0.0) return -1.0;
    return -b + sqrt(d);
}
float raySphereNear(vec3 ro, vec3 rd, float r) {
    float b = dot(ro, rd);
    float c = dot(ro, ro) - r * r;
    float d = b * b - c;
    if (d < 0.0) return -1.0;
    return -b - sqrt(d);
}

vec3 atmoDensity(float h) {
    // x: rayleigh, y: mie, z: ozone
    float oz = max(0.0, 1.0 - abs(h - 25000.0) / 15000.0);
    return vec3(exp(-h / ATMO_H_RAYLEIGH), exp(-h / ATMO_H_MIE), oz);
}

vec3 atmoExtinction(vec3 dens) {
    return ATMO_RAYLEIGH * dens.x + ATMO_MIE_EXTINCT * dens.y + ATMO_OZONE * dens.z;
}

// Transmittance from point p (planet space) towards direction l
vec3 atmoTransmittance(vec3 p, vec3 l, const int steps) {
    if (raySphereNear(p, l, ATMO_R_GROUND) > 0.0) return vec3(0.0);
    float tMax = raySphereFar(p, l, ATMO_R_TOP);
    float dt = tMax / float(steps);
    vec3 od = vec3(0.0);
    for (int i = 0; i < steps; i++) {
        vec3 s = p + l * (dt * (float(i) + 0.5));
        od += atmoDensity(length(s) - ATMO_R_GROUND);
    }
    return exp(-atmoExtinction(od * dt));
}

vec3 atmoViewer() {
    return vec3(0.0, ATMO_R_GROUND + 200.0 + max(cameraPosition.y - 63.0, 0.0) * 2.0, 0.0);
}

// Raw single scattering for one light source of illuminance 1
vec3 atmoScatter(vec3 rd, vec3 l, const int steps, const int lightSteps) {
    vec3 ro = atmoViewer();
    float tMax = raySphereFar(ro, rd, ATMO_R_TOP);
    float tGround = raySphereNear(ro, rd, ATMO_R_GROUND);
    if (tGround > 0.0) tMax = tGround;

    float mu = dot(rd, l);
    float pR = rayleighPhase(mu);
    float pM = miePhase(mu, 0.78);

    vec3 sumR = vec3(0.0), sumM = vec3(0.0);
    vec3 od = vec3(0.0);
    float tPrev = 0.0;
    for (int i = 0; i < steps; i++) {
        // quadratic step distribution: more samples close to the viewer
        float f = (float(i) + 0.5) / float(steps);
        float t = tMax * f * f;
        float dt = tMax * ((float(i) + 1.0) * (float(i) + 1.0) - float(i) * float(i)) / float(steps * steps);
        vec3 s = ro + rd * t;
        vec3 dens = atmoDensity(length(s) - ATMO_R_GROUND);
        od += dens * dt;
        vec3 tr = exp(-atmoExtinction(od)) * atmoTransmittance(s, l, lightSteps);
        sumR += tr * dens.x * dt;
        sumM += tr * dens.y * dt;
    }
    vec3 single = sumR * ATMO_RAYLEIGH * pR + sumM * ATMO_MIE_SCATTER * pM;
    // cheap multiple scattering fill-in so twilight and shadows don't go pitch black
    vec3 multi = (sumR * ATMO_RAYLEIGH + sumM * ATMO_MIE_SCATTER) * 0.08;
    return single + multi;
}

vec3 sunTransmittance(vec3 sunDir) {
    return atmoTransmittance(atmoViewer(), sunDir, 6);
}

// Colour of direct sunlight / moonlight reaching the ground
vec3 getSunlight(vec3 sunDir) {
    vec3 c = sunTransmittance(sunDir) * SUN_BRIGHTNESS;
    // soften the transition when the sun touches the horizon
    c *= smoothstep(-0.03, 0.04, sunDir.y);
    return c * (1.0 - 0.85 * rainStrength);
}
vec3 getMoonlight(vec3 sunDir) {
    vec3 moonDir = -sunDir;
    vec3 c = vec3(0.55, 0.7, 1.0) * MOON_ILLUM * NIGHT_BRIGHTNESS;
    c *= smoothstep(-0.03, 0.1, moonDir.y);
    return c * (1.0 - 0.75 * rainStrength);
}
// Light that actually casts the shadow (sun at day, moon at night)
vec3 getShadowLightColor(vec3 sunDir) {
    return sunDir.y > 0.0 ? getSunlight(sunDir) : getMoonlight(sunDir);
}

vec3 rainSky(vec3 sky, vec3 sunDir) {
    float dayF = smoothstep(-0.15, 0.25, sunDir.y);
    vec3 overcast = vec3(0.28, 0.30, 0.33) * mix(0.02, 1.0, dayF) * 0.9;
    return mix(sky, overcast, rainStrength * 0.85);
}

// Full sky radiance (no sun disk), steps tuned per use
vec3 skyRadianceQ(vec3 rd, vec3 sunDir, const int steps, const int lightSteps) {
    vec3 d = rd;
    // below the horizon: reuse a slightly darker horizon colour instead of the planet
    float below = saturate(-d.y * 4.0);
    d.y = max(d.y, 0.002);
    d = normalize(d);
    vec3 sky = atmoScatter(d, sunDir, steps, lightSteps) * SKY_GAIN * SUN_BRIGHTNESS;
    vec3 night = atmoScatter(d, -sunDir, steps / 2, 2) * SKY_GAIN * MOON_ILLUM * 0.8 * NIGHT_BRIGHTNESS;
    // a touch of blue airglow so nights never go completely flat
    night += vec3(0.0015, 0.0028, 0.006) * NIGHT_BRIGHTNESS;
    sky += night;
    sky = rainSky(sky, sunDir);
    return sky * mix(1.0, 0.45, below);
}
vec3 skyRadiance(vec3 rd, vec3 sunDir) { return skyRadianceQ(rd, sunDir, 10, 4); }
vec3 skyRadianceCheap(vec3 rd, vec3 sunDir) { return skyRadianceQ(rd, sunDir, 6, 2); }

// Irradiance-like ambient colour from the sky (call from vertex shaders)
vec3 getSkyAmbient(vec3 sunDir) {
    vec3 a = skyRadianceCheap(vec3(0.0, 1.0, 0.0), sunDir) * 0.5;
    vec3 h = normalize(vec3(sunDir.x, 0.0, sunDir.z) + vec3(0.0, 0.35, 0.0));
    a += skyRadianceCheap(h, sunDir) * 0.25;
    a += skyRadianceCheap(normalize(vec3(-h.x, h.y, -h.z)), sunDir) * 0.25;
    return a * AMBIENT_BRIGHTNESS;
}

vec3 sunDisk(vec3 rd, vec3 sunDir) {
    float mu = dot(rd, sunDir);
    float disk = smoothstep(0.99988, 0.99994, mu);
    vec3 tr = sunTransmittance(sunDir);
    return disk * tr * 120.0 * SUN_BRIGHTNESS * (1.0 - rainStrength) * step(-0.01, rd.y);
}

// Procedural stars (rendered behind everything at night)
vec3 stars(vec3 rd, vec3 sunDir) {
#ifdef STARS
    float night = smoothstep(0.05, -0.2, sunDir.y) * (1.0 - rainStrength);
    if (night <= 0.0 || rd.y < 0.0) return vec3(0.0);
    // rotate with the sky
    vec3 p = rd * 300.0;
    vec3 cell = floor(p);
    vec3 f = fract(p) - 0.5;
    float h = fract(sin(dot(cell, vec3(127.1, 311.7, 74.7))) * 43758.5453);
    float threshold = 1.0 - 0.0025 * STAR_AMOUNT;
    if (h < threshold) return vec3(0.0);
    float s = smoothstep(0.35, 0.0, length(f));
    float twinkle = 0.7 + 0.3 * sin(frameTimeCounter * 3.0 + h * 1000.0);
    vec3 col = mix(vec3(0.7, 0.8, 1.0), vec3(1.0, 0.85, 0.7), fract(h * 37.0));
    return col * s * twinkle * night * 0.6 * smoothstep(0.0, 0.2, rd.y);
#else
    return vec3(0.0);
#endif
}

// Per-frame light colours for the current dimension
void getFrameLighting(vec3 sunDir, out vec3 lightCol, out vec3 ambient) {
#if defined DIM_NETHER
    lightCol = vec3(0.0);
    ambient = mix(vec3(0.30, 0.12, 0.06), fogColor * 1.5, 0.5) * 0.35 * AMBIENT_BRIGHTNESS;
#elif defined DIM_END
    lightCol = vec3(0.0);
    ambient = vec3(0.16, 0.12, 0.22) * 0.5 * AMBIENT_BRIGHTNESS;
#else
    lightCol = getShadowLightColor(sunDir);
    ambient = getSkyAmbient(sunDir);
#endif
}

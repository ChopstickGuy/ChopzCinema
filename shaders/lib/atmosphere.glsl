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
// direct sun is several times stronger than the sky light - that's what gives real contrast
const float SUN_ILLUM = 3.0;

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
    vec3 c = sunTransmittance(sunDir) * SUN_ILLUM * SUN_BRIGHTNESS;
    // soften the transition when the sun touches the horizon
    c *= smoothstep(-0.03, 0.04, sunDir.y);
    return c * (1.0 - 0.85 * rainStrength);
}
vec3 getMoonlight(vec3 sunDir) {
    vec3 moonDir = -sunDir;
    vec3 c = vec3(0.55, 0.7, 1.0) * MOON_ILLUM * 3.5 * NIGHT_BRIGHTNESS;
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
    vec3 night = atmoScatter(d, -sunDir, steps / 2, 2) * SKY_GAIN * MOON_ILLUM * 0.22 * NIGHT_BRIGHTNESS;
    // a touch of blue airglow so nights never go completely flat
    night += vec3(0.0005, 0.0008, 0.0018) * NIGHT_BRIGHTNESS;
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
    // the night sky is drawn dark so the stars pop - keep the landscape readable with soft moon fill
    a += vec3(0.008, 0.011, 0.021) * NIGHT_BRIGHTNESS * smoothstep(0.0, -0.2, sunDir.y);
    return a * AMBIENT_BRIGHTNESS;
}

// angle between two unit vectors, precise for small angles
float smallAngle(vec3 a, vec3 b) {
    return 2.0 * asin(clamp(length(a - b) * 0.5, 0.0, 1.0));
}

vec3 sunDisk(vec3 rd, vec3 sunDir) {
    float ang = smallAngle(rd, sunDir);
    const float baseRadius = 0.032;
    float r = baseRadius * SUN_SIZE;
    // anti-aliased round edge
    float edge = r * 0.06;
    float disk = 1.0 - smoothstep(r - edge, r + edge, ang);
    // limb darkening: the centre is brighter and slightly whiter than the rim
    float x = saturate(ang / r);
    float limb = 0.55 + 0.45 * sqrt(max(1.0 - x * x, 0.0));
    // soft corona hugging the disk
    float lowSun = smoothstep(0.45, 0.02, sunDir.y);
    float corona = exp(-max(ang - r, 0.0) / (r * 0.9)) * 0.04 + exp(-ang / 0.12) * 0.004 * (1.0 + 4.0 * lowSun)
                 + exp(-ang / 0.35) * 0.0015 * lowSun;
    vec3 tr = sunTransmittance(sunDir);
    float vis = (1.0 - rainStrength) * smoothstep(-0.02, 0.0, rd.y);
    return (disk * limb * 60.0 + corona * 10.0) * tr * SUN_BRIGHTNESS * vis;
}

#include "/lib/nightsky.glsl"
#include "/lib/rain.glsl"

// High, wispy cirrus streaks painted onto the sky dome. rgb = colour, a = coverage
vec4 cirrusClouds(vec3 rd, vec3 sunDir, vec3 lightCol, vec3 ambient) {
#ifdef CIRRUS_CLOUDS
    if (rd.y <= 0.02) return vec4(0.0);
    vec2 p = rd.xz / (rd.y + 0.1);
    float t = frameTimeCounter * 0.0008;
    // stretch the noise along the wind so it forms long streaks
    vec2 w = vec2(0.87, 0.49);
    vec2 q = vec2(dot(p, w), dot(p, vec2(-w.y, w.x)));
    q *= vec2(0.45, 1.7);
    float n = textureLod(noisetex, q * 0.04 + vec2(t, 0.0), 0.0).x * 0.55
            + textureLod(noisetex, q * 0.11 + vec2(t * 1.7, 0.3), 0.0).x * 0.3
            + textureLod(noisetex, q * 0.29 + 0.6, 0.0).x * 0.15;
    float region = textureLod(noisetex, p * 0.006 + 0.2, 0.0).x;   // where streaks appear at all
    float c = smoothstep(0.56, 0.98, n) * smoothstep(0.45, 0.75, region + 0.1 * CIRRUS_AMOUNT);
    c *= smoothstep(0.02, 0.18, rd.y) * (1.0 - rainStrength) * min(CIRRUS_AMOUNT, 1.5);
    if (c <= 0.0) return vec4(0.0);
    float mu = dot(rd, sunDir);
    // thin ice crystals light up strongly around the sun (pink/orange at dusk)
    vec3 col = lightCol * (0.2 + 1.4 * pow(saturate(mu * 0.5 + 0.5), 6.0)) + ambient * 1.3;
    return vec4(col, c * 0.32);
#else
    return vec4(0.0);
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
    // faint green glow on the landscape when the northern lights are out
    ambient += vec3(0.1, 1.0, 0.45) * auroraActivity() * 0.004;
    // lightning lights up the whole landscape for a moment
    ambient += vec3(0.75, 0.8, 1.0) * lightningFlash() * 1.2;
#endif
}

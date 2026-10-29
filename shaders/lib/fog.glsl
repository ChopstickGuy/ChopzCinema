// Height based atmospheric fog + ground mist, analytically integrated.
// Densities are per block. y is world height.

struct FogParams {
    float hazeDensity;  // thin aerial-perspective haze
    float hazeHeight;   // falloff height in blocks
    float mistDensity;  // thick ground mist
    float mistHeight;
    float mistBase;     // altitude where mist sits
};

FogParams getFogParams(vec3 sunDir) {
    FogParams f;
    float lowSun = smoothstep(0.45, 0.02, abs(sunDir.y));
    float night = smoothstep(0.05, -0.15, sunDir.y);
    f.hazeDensity = 0.0005 * FOG_DENSITY * (1.0 + rainStrength * 1.5);
    f.hazeHeight = 90.0;
    float mist = MORNING_MIST * (0.15 + lowSun * 0.85 + night * 0.25) + rainStrength * 0.5;
    f.mistDensity = 0.010 * mist * FOG_DENSITY;
    f.mistHeight = 14.0 + rainStrength * 20.0;
    f.mistBase = 62.0;
    return f;
}

float fogDensityAt(FogParams f, float y) {
    float haze = f.hazeDensity * exp(-max(y - 64.0, -20.0) / f.hazeHeight);
    float mist = f.mistDensity * exp(-max(y - f.mistBase, -10.0) / f.mistHeight);
    return haze + mist;
}

// optical depth of one exponential layer along a ray
float expLayerOD(float a, float H, float base, float y0, float dy, float len) {
    y0 = max(y0, base - 12.0); // don't let the layer explode deep underground
    float k = a * exp(-(y0 - base) / H);
    if (abs(dy) < 1e-4) return k * len;
    float x = len * dy / H;
    x = max(x, -40.0);
    return k * H / dy * (1.0 - exp(-x));
}

float fogOpticalDepth(FogParams f, float y0, float dy, float len) {
    return expLayerOD(f.hazeDensity, f.hazeHeight, 64.0, y0, dy, len)
         + expLayerOD(f.mistDensity, f.mistHeight, f.mistBase, y0, dy, len);
}

float fogPhase(float mu) {
    return mix(1.0 / (4.0 * PI), hgPhase(mu, 0.65), 0.6);
}

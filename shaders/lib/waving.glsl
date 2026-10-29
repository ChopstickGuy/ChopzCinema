// Wind animation for plants and leaves. Operates on world-space position.
// Block ids come from block.properties.

const int ID_WATER = 10001;
const int ID_LEAVES = 10002;
const int ID_PLANT_BOTTOM = 10003; // anchored at the bottom (grass, flowers)
const int ID_PLANT_FULL = 10004;   // whole quad moves (upper half of tall plants, vines)
const int ID_PLANT_STILL = 10005;  // subsurface but static
const int ID_EMISSIVE = 10010;
const int ID_EMISSIVE_PART = 10011; // only bright texels glow (torches, lanterns)
const int ID_LAVA = 10012;
const int ID_GLASS = 10020;
const int ID_ICE = 10021;
const int ID_METAL = 10030;
const int ID_POLISHED = 10031;

vec3 windOffset(vec3 worldPos, float strength) {
    float t = frameTimeCounter * (1.0 + rainStrength * 0.8);
    float gust = sin(t * 0.35 + worldPos.x * 0.02 + worldPos.z * 0.015) * 0.5 + 0.5;
    gust = 0.35 + gust * 0.65;
    vec3 o;
    o.x = sin(t * 1.6 + worldPos.x * 0.7 + worldPos.y * 0.3) * 0.6 + sin(t * 2.7 + worldPos.z * 0.9) * 0.4;
    o.z = sin(t * 1.3 + worldPos.z * 0.6 + worldPos.x * 0.4) * 0.6 + sin(t * 2.3 + worldPos.x * 1.1) * 0.4;
    o.y = sin(t * 2.0 + worldPos.x + worldPos.z) * 0.15;
    return o * strength * gust * (0.06 + rainStrength * 0.05) * WAVING_STRENGTH;
}

vec3 applyWaving(vec3 worldPos, int id, float isTopVertex, float skyLight) {
    // plants in caves / indoors stay calm
    float exposure = smoothstep(0.3, 0.9, skyLight);
    if (exposure <= 0.0) return worldPos;
#ifdef WAVING_PLANTS
    if (id == ID_PLANT_BOTTOM) return worldPos + windOffset(worldPos, 1.0) * isTopVertex * exposure;
    if (id == ID_PLANT_FULL) return worldPos + windOffset(worldPos, 1.0) * exposure;
#endif
#ifdef WAVING_LEAVES
    if (id == ID_LEAVES) return worldPos + windOffset(worldPos, 0.45) * exposure;
#endif
    return worldPos;
}

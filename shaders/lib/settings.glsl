// ChopzCinema - user settings
// Every option here shows up in the in-game shader settings menu.

// ---------- Shadows ----------
const int shadowMapResolution = 2048; // [1024 1536 2048 3072 4096]
const float shadowDistance = 160.0; // [96.0 128.0 160.0 192.0 224.0 256.0]
const float shadowDistanceRenderMul = 1.0;
const float shadowIntervalSize = 2.0;
const bool shadowHardwareFiltering = true;
const bool shadowtex0Nearest = false;
const bool shadowtex1Nearest = false;
const float sunPathRotation = -25.0; // [-45.0 -40.0 -35.0 -30.0 -25.0 -20.0 -15.0 -10.0 -5.0 0.0 5.0 10.0 15.0 20.0 25.0 30.0]
const float ambientOcclusionLevel = 1.0;
const int noiseTextureResolution = 256;

#define SHADOW_SOFTNESS 1.0 // [0.0 0.5 1.0 1.5 2.0 3.0]
#define SHADOW_SAMPLES 12 // [4 8 12 16 24]
#define COLORED_SHADOWS

// ---------- Lighting ----------
#define SUN_BRIGHTNESS 1.0 // [0.5 0.75 1.0 1.25 1.5 2.0]
#define AMBIENT_BRIGHTNESS 0.9 // [0.4 0.5 0.6 0.75 0.9 1.0 1.25 1.5 2.0]
#define NIGHT_BRIGHTNESS 1.0 // [0.5 0.75 1.0 1.5 2.0 3.0]
#define BLOCKLIGHT_BRIGHTNESS 1.0 // [0.5 0.75 1.0 1.25 1.5 2.0]
#define BLOCKLIGHT_TEMP 2900 // [2200 2500 2900 3400 4000 5000]
#define MIN_LIGHT 0.6 // [0.0 0.3 0.6 1.0 2.0]
#define SUBSURFACE_SCATTERING
#define SPECULAR_HIGHLIGHTS

// ---------- Sky & Atmosphere ----------
#define ROUND_SUN_MOON
#define SUN_SIZE 1.0 // [0.5 0.75 1.0 1.25 1.5 2.0]
#define MOON_SIZE 1.0 // [0.5 0.75 1.0 1.25 1.5 2.0]
#define STARS
#define STAR_AMOUNT 1.0 // [0.5 0.75 1.0 1.5 2.0 3.0]
#define STAR_BRIGHTNESS 1.0 // [0.5 0.75 1.0 1.5 2.0 3.0]
#define MILKY_WAY
#define MILKY_WAY_BRIGHTNESS 1.0 // [0.25 0.5 0.75 1.0 1.5 2.0]
#define SHOOTING_STARS
#define AURORA 1 // [0 1 2]
#define AURORA_CHANCE 0.3 // [0.1 0.2 0.3 0.5 0.75 1.0]
#define AURORA_BRIGHTNESS 1.0 // [0.5 0.75 1.0 1.5 2.0 3.0]

// ---------- Volumetric clouds ----------
#define VOLUMETRIC_CLOUDS
//#define CIRRUS_CLOUDS
#define CIRRUS_AMOUNT 1.0 // [0.5 1.0 1.5 2.0]
#define CLOUD_QUALITY 1 // [0 1 2]
#define CLOUD_HEIGHT 230.0 // [160.0 190.0 230.0 260.0 300.0 350.0]
#define CLOUD_THICKNESS 180.0 // [100.0 140.0 180.0 240.0 300.0]
#define CLOUD_COVERAGE 0.45 // [0.25 0.35 0.45 0.55 0.65 0.75]
#define CLOUD_SPEED 1.0 // [0.0 0.5 1.0 2.0 4.0]

// ---------- Fog & volumetric light ----------
#define VOLUMETRIC_LIGHT
#define VL_SAMPLES 12 // [6 8 12 16 24]
#define FOG_DENSITY 1.0 // [0.0 0.25 0.5 0.75 1.0 1.25 1.5 2.0 3.0]
#define MORNING_MIST 1.0 // [0.0 0.5 1.0 1.5 2.0]
#define VL_STRENGTH 1.0 // [0.25 0.5 0.75 1.0 1.5 2.0]
#define CAVE_FOG
#define NETHER_LAVA_GLOW 1.0 // [0.0 0.5 1.0 1.5 2.0]

// ---------- Rain ----------
#define RAIN_RIPPLES
#define LIGHTNING_FLASH
#define RAIN_MOOD 1.0 // [0.0 0.5 1.0 1.5]
#define RAIN_STREAK_OPACITY 1.0 // [0.25 0.5 0.75 1.0 1.5 2.0]
#define RAIN_CURTAINS

// ---------- Heat ----------
#define HEAT_HAZE
#define HEAT_HAZE_STRENGTH 1.0 // [0.25 0.5 0.75 1.0 1.5 2.0 3.0]
#define NETHER_HEAT_HAZE
#define NETHER_SMOKE
#define NETHER_SMOKE_DENSITY 1.0 // [0.25 0.5 0.75 1.0 1.5 2.0 3.0]
#define WAVING_LAVA

// ---------- Water ----------
#define WATER_WAVES
#define WATER_WAVE_HEIGHT 1.0 // [0.25 0.5 0.75 1.0 1.5 2.0]
#define WATER_CLARITY 1.0 // [0.5 0.75 1.0 1.5 2.0]
#define WATER_TEXTURE 0.0 // [0.0 0.25 0.5 0.75 1.0]
#define WATER_CAUSTICS
#define UNDERWATER_RAYS 1.0 // [0.0 0.25 0.5 0.75 1.0 1.5 2.0 3.0]

// ---------- Reflections ----------
#define SSR
#define SSR_STEPS 20 // [12 16 20 28 40]
#define RAIN_PUDDLES
#define BLOCK_REFLECTIONS

// ---------- Waving ----------
#define WAVING_PLANTS
#define WAVING_LEAVES
#define WAVING_STRENGTH 1.0 // [0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.5]

// ---------- Camera / Film ----------
#define TAA
#define TAA_SHARPEN 0.35 // [0.0 0.15 0.25 0.35 0.5 0.75]
#define AUTO_EXPOSURE
#define EXPOSURE 0.0 // [-2.0 -1.5 -1.0 -0.5 0.0 0.5 1.0 1.5 2.0]
#define BLOOM
#define BLOOM_STRENGTH 1.0 // [0.0 0.25 0.5 0.75 1.0 1.5 1.75 2.0 3.0]
#define TONEMAP 1 // [0 1 2]
#define COLOR_GRADE 4 // [0 1 2 3 4 5]
#define GRADE_STRENGTH 1.0 // [0.0 0.25 0.5 0.75 1.0 1.25 1.5]
#define CONTRAST 1.05 // [0.9 0.95 1.0 1.05 1.1 1.15 1.2]
#define SATURATION 1.0 // [0.7 0.8 0.9 1.0 1.1 1.2 1.3]
#define VIGNETTE 0.45 // [0.0 0.15 0.25 0.35 0.45 0.6 0.75]
#define FILM_GRAIN 0.25 // [0.0 0.1 0.25 0.5 0.75 1.0]
#define CHROMATIC_ABERRATION 0.25 // [0.0 0.25 0.5 1.0]
#define LENS_FLARE
#define DEPTH_OF_FIELD
#define DOF_STRENGTH 0.5 // [0.0 0.25 0.5 0.75 1.0 1.5 2.0 3.0]
const float centerDepthHalflife = 1.5;
#define LETTERBOX 0 // [0 1 2]

// ---------- Story look (Ghost of Tsushima inspired) ----------
#define PAINTERLY 0.0 // [0.0 0.5 1.0 1.5 2.0]
//#define FALLING_LEAVES
#define LEAVES_DENSITY 1.0 // [0.5 1.0 1.5 2.0 3.0]
#define WIND_GUSTS
//#define GOLDEN_ATMOSPHERE
//#define KUROSAWA_MODE

// Iris only lists boolean options it sees in a plain #ifdef - reference all of them here.
#ifdef COLORED_SHADOWS
#endif
#ifdef SUBSURFACE_SCATTERING
#endif
#ifdef SPECULAR_HIGHLIGHTS
#endif
#ifdef ROUND_SUN_MOON
#endif
#ifdef STARS
#endif
#ifdef MILKY_WAY
#endif
#ifdef SHOOTING_STARS
#endif
#ifdef VOLUMETRIC_CLOUDS
#endif
#ifdef CIRRUS_CLOUDS
#endif
#ifdef VOLUMETRIC_LIGHT
#endif
#ifdef CAVE_FOG
#endif
#ifdef RAIN_RIPPLES
#endif
#ifdef LIGHTNING_FLASH
#endif
#ifdef RAIN_CURTAINS
#endif
#ifdef HEAT_HAZE
#endif
#ifdef NETHER_HEAT_HAZE
#endif
#ifdef NETHER_SMOKE
#endif
#ifdef WAVING_LAVA
#endif
#ifdef WATER_WAVES
#endif
#ifdef WATER_CAUSTICS
#endif
#ifdef SSR
#endif
#ifdef RAIN_PUDDLES
#endif
#ifdef BLOCK_REFLECTIONS
#endif
#ifdef WAVING_PLANTS
#endif
#ifdef WAVING_LEAVES
#endif
#ifdef TAA
#endif
#ifdef AUTO_EXPOSURE
#endif
#ifdef BLOOM
#endif
#ifdef LENS_FLARE
#endif
#ifdef DEPTH_OF_FIELD
#endif
#ifdef FALLING_LEAVES
#endif
#ifdef WIND_GUSTS
#endif
#ifdef GOLDEN_ATMOSPHERE
#endif
#ifdef KUROSAWA_MODE
#endif

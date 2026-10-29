// Shared uniforms, constants and small helpers.

#include "/lib/settings.glsl"

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform vec3 sunPosition;
uniform vec3 shadowLightPosition;

uniform float viewWidth;
uniform float viewHeight;
uniform float near;
uniform float far;
uniform float frameTimeCounter;
uniform int frameCounter;
uniform int worldTime;
uniform int worldDay;
uniform float sunAngle;
uniform float rainStrength;
uniform float wetness;
uniform ivec2 eyeBrightnessSmooth;
uniform int isEyeInWater;
uniform float nightVision;
uniform float blindness;
uniform float darknessFactor;
uniform vec3 fogColor;
uniform float frameTime;
uniform sampler2D noisetex;

#ifdef DISTANT_HORIZONS
uniform float dhNearPlane;
uniform float dhFarPlane;
uniform int dhRenderDistance;
uniform mat4 dhProjection;
uniform mat4 dhProjectionInverse;
uniform mat4 dhPreviousProjection;
#endif

const float PI = 3.14159265;
const float TAU = 6.28318531;

// Material ids written into gbuffer (colortex0.a * 255)
const int MAT_DEFAULT = 0;
const int MAT_FOLIAGE = 1;   // grass, flowers, leaves: subsurface
const int MAT_EMISSIVE = 2;
const int MAT_METAL = 3;
const int MAT_POLISHED = 4;
const int MAT_HAND = 5;
const int MAT_ENTITY = 6;
const int MAT_SKY_OBJECT = 7; // moon, stars
const int MAT_LAVA = 8;

// Translucent types (integer part of colortex4.z * 8)
const int TR_NONE = 0;
const int TR_WATER = 1;
const int TR_GLASS = 2;
const int TR_ICE = 3;
const int TR_OTHER = 4;

float sq(float x) { return x * x; }
float saturate(float x) { return clamp(x, 0.0, 1.0); }
vec3 saturate(vec3 x) { return clamp(x, 0.0, 1.0); }
float luminance(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
float maxOf(vec3 v) { return max(v.x, max(v.y, v.z)); }

vec2 screenSize() { return vec2(viewWidth, viewHeight); }
vec2 texelSize() { return 1.0 / vec2(viewWidth, viewHeight); }

// Interleaved gradient noise, animated per frame so TAA can resolve it.
float ign(vec2 p) {
    return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}
float ignAnimated(vec2 p) {
#ifdef TAA
    p += 5.588238 * float(frameCounter % 64);
#endif
    return ign(p);
}

float hashInt(int n) {
    uint x = uint(n) * 747796405u + 2891336453u;
    x = ((x >> ((x >> 28u) + 4u)) ^ x) * 277803737u;
    x = (x >> 22u) ^ x;
    return float(x) / 4294967295.0;
}

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}
vec2 hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

// Octahedral normal encoding into [0,1]^2
vec2 encodeNormal(vec3 n) {
    n /= abs(n.x) + abs(n.y) + abs(n.z);
    vec2 e = n.z >= 0.0 ? n.xy : (1.0 - abs(n.yx)) * vec2(n.x >= 0.0 ? 1.0 : -1.0, n.y >= 0.0 ? 1.0 : -1.0);
    return e * 0.5 + 0.5;
}
vec3 decodeNormal(vec2 e) {
    e = e * 2.0 - 1.0;
    vec3 n = vec3(e, 1.0 - abs(e.x) - abs(e.y));
    float t = max(-n.z, 0.0);
    n.x += n.x >= 0.0 ? -t : t;
    n.y += n.y >= 0.0 ? -t : t;
    return normalize(n);
}

vec3 projectAndDivide(mat4 m, vec3 p) {
    vec4 h = m * vec4(p, 1.0);
    return h.xyz / h.w;
}

vec3 screenToView(vec3 screenPos, mat4 projInv) {
    return projectAndDivide(projInv, screenPos * 2.0 - 1.0);
}
vec3 viewToScreen(vec3 viewPos, mat4 proj) {
    return projectAndDivide(proj, viewPos) * 0.5 + 0.5;
}

vec3 viewToPlayer(vec3 v) { return (gbufferModelViewInverse * vec4(v, 1.0)).xyz; }

vec3 sunDirWorld() { return normalize(mat3(gbufferModelViewInverse) * sunPosition); }
vec3 lightDirWorld() { return normalize(mat3(gbufferModelViewInverse) * shadowLightPosition); }

// 0 in caves, 1 under open sky (from the camera's point of view)
float eyeSkylight() { return saturate(float(eyeBrightnessSmooth.y) / 240.0); }

// TAA sub-pixel jitter (Halton 2,3)
vec2 taaOffset() {
    int i = frameCounter % 8;
    const vec2 h[8] = vec2[8](
        vec2(0.5, 0.333333), vec2(0.25, 0.666667), vec2(0.75, 0.111111), vec2(0.125, 0.444444),
        vec2(0.625, 0.777778), vec2(0.375, 0.222222), vec2(0.875, 0.555556), vec2(0.0625, 0.888889));
    return (h[i] * 2.0 - 1.0) / vec2(viewWidth, viewHeight);
}

vec4 jitterPosition(vec4 clip) {
#ifdef TAA
    clip.xy += taaOffset() * clip.w;
#endif
    return clip;
}

vec3 blackbody(float t) {
    // Approximation of a black body colour (1000K - 12000K), normalized
    t /= 100.0;
    vec3 c;
    c.r = t <= 66.0 ? 1.0 : saturate(1.29293618 * pow(t - 60.0, -0.1332047592));
    c.g = t <= 66.0 ? saturate(0.39008157 * log(t) - 0.63184144) : saturate(1.12989086 * pow(t - 60.0, -0.0755148492));
    c.b = t >= 66.0 ? 1.0 : (t <= 19.0 ? 0.0 : saturate(0.54320679 * log(t - 10.0) - 1.19625408));
    return pow(c, vec3(2.2));
}

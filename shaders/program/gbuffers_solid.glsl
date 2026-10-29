// Opaque geometry -> G-buffer (lit later in deferred1)
// Variants: TERRAIN, ENTITIES, BASIC, DAMAGED_BLOCK, SKY_TEXTURED, SKY_BASIC

#include "/lib/common.glsl"
#include "/lib/waving.glsl"

#ifdef VERTEX
// ============================================================== VERTEX
in vec4 mc_Entity;
in vec2 mc_midTexCoord;

out vec2 texcoord;
out vec2 lmcoord;
out vec4 tint;
out vec3 worldNormal;
flat out int blockId;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = clamp((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy * (33.05 / 32.0) - (1.05 / 32.0), 0.0, 1.0);
    tint = gl_Color;
    blockId = int(mc_Entity.x + 0.5);

    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
#if defined TERRAIN && (defined WAVING_PLANTS || defined WAVING_LEAVES)
    if (blockId >= ID_LEAVES && blockId <= ID_PLANT_FULL) {
        vec3 playerPos = (gbufferModelViewInverse * viewPos).xyz;
        float top = gl_MultiTexCoord0.y < mc_midTexCoord.y ? 1.0 : 0.0;
        vec3 worldPos = applyWaving(playerPos + cameraPosition, blockId, top, lmcoord.y);
        viewPos = gbufferModelView * vec4(worldPos - cameraPosition, 1.0);
    }
#endif

#if defined SKY_TEXTURED || defined SKY_BASIC
    gl_Position = gl_ProjectionMatrix * viewPos;
#else
    gl_Position = jitterPosition(gl_ProjectionMatrix * viewPos);
#endif
    worldNormal = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * gl_Normal);
}

#else
// ============================================================== FRAGMENT
in vec2 texcoord;
in vec2 lmcoord;
in vec4 tint;
in vec3 worldNormal;
flat in int blockId;

uniform sampler2D gtexture;
uniform vec4 entityColor;
uniform int renderStage;

#if defined DAMAGED_BLOCK
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outAlbedo;
#else
/* RENDERTARGETS: 0,1,2 */
layout(location = 0) out vec4 outAlbedo;
layout(location = 1) out vec4 outNormalLm;
layout(location = 2) out vec4 outMaterial;
#endif

void main() {
#ifdef SKY_BASIC
    // sky gradient + stars are rendered procedurally in deferred1
    discard;
#else
#ifdef BASIC
    vec4 albedo = tint;
#else
    vec4 albedo = texture(gtexture, texcoord) * tint;
#endif

#ifdef DAMAGED_BLOCK
    outAlbedo = albedo;
#elif defined SKY_TEXTURED
    // only keep the moon - the sun disk is procedural
    if (renderStage == MC_RENDER_STAGE_SUN) discard;
    outAlbedo = vec4(albedo.rgb * albedo.a, float(MAT_SKY_OBJECT) / 255.0);
    outNormalLm = vec4(0.0);
    outMaterial = vec4(0.0);
#else
    if (albedo.a < 0.1) discard;

    int mat = MAT_DEFAULT;
    float smoothness = 0.0, emission = 0.0, sss = 0.0, metal = 0.0;

#ifdef ENTITIES
    albedo.rgb = mix(albedo.rgb, entityColor.rgb, entityColor.a);
    mat = MAT_ENTITY;
#endif

#ifdef TERRAIN
    if (blockId == ID_LEAVES) {
        mat = MAT_FOLIAGE; sss = 0.8;
    } else if (blockId >= ID_PLANT_BOTTOM && blockId <= ID_PLANT_STILL) {
        mat = MAT_FOLIAGE; sss = 0.6;
    } else if (blockId == ID_EMISSIVE) {
        mat = MAT_EMISSIVE; emission = 0.6 + 0.4 * luminance(albedo.rgb);
    } else if (blockId == ID_EMISSIVE_PART) {
        mat = MAT_EMISSIVE;
        float l = maxOf(albedo.rgb);
        emission = smoothstep(0.55, 0.9, l) * smoothstep(0.1, 0.4, albedo.r - albedo.b * 0.5 + 0.3);
    } else if (blockId == ID_LAVA) {
        mat = MAT_LAVA; emission = 1.0;
    }
#ifdef BLOCK_REFLECTIONS
    else if (blockId == ID_METAL) {
        mat = MAT_METAL; smoothness = 0.75; metal = 1.0;
    } else if (blockId == ID_POLISHED) {
        mat = MAT_POLISHED; smoothness = 0.6;
    }
#endif
#endif

    vec3 n = normalize(worldNormal);
#ifdef BASIC
    n = vec3(0.0, 1.0, 0.0);
#endif

    outAlbedo = vec4(albedo.rgb, float(mat) / 255.0);
    outNormalLm = vec4(encodeNormal(n), lmcoord);
    outMaterial = vec4(smoothness, emission, sss, metal);
#endif
#endif
}
#endif

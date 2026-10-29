// Distant Horizons LOD terrain -> same G-buffer layout as vanilla terrain.

#include "/lib/common.glsl"

#ifdef VERTEX
out vec4 tint;
out vec2 lmcoord;
out vec3 worldNormal;
out vec3 playerPos;
flat out int dhMat;

void main() {
    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    playerPos = (gbufferModelViewInverse * viewPos).xyz;
    gl_Position = jitterPosition(dhProjection * viewPos);
    tint = gl_Color;
    lmcoord = clamp(((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy - 0.03125) * 1.06667, 0.0, 1.0);
    worldNormal = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * gl_Normal);
    dhMat = dhMaterialId;
}

#else
in vec4 tint;
in vec2 lmcoord;
in vec3 worldNormal;
in vec3 playerPos;
flat in int dhMat;

/* RENDERTARGETS: 0,1,2 */
layout(location = 0) out vec4 outAlbedo;
layout(location = 1) out vec4 outNormalLm;
layout(location = 2) out vec4 outMaterial;

void main() {
    // hand over to vanilla chunks close to the camera (dithered so the seam is invisible)
    float dist = length(playerPos.xz);
    float fade = smoothstep(far * 0.6, far * 0.8, dist);
    if (fade < ign(gl_FragCoord.xy)) discard;

    vec3 albedo = tint.rgb;
    // per-block brightness variation so LODs don't look like flat plastic
    vec3 worldPos = playerPos + cameraPosition;
    vec3 blockPos = floor(worldPos - worldNormal * 0.1);
    albedo *= 0.88 + 0.2 * hash12(blockPos.xz + blockPos.y * 17.3);

    int mat = MAT_DEFAULT;
    float emission = 0.0, sss = 0.0;
    if (dhMat == DH_BLOCK_LEAVES || dhMat == DH_BLOCK_GRASS) { mat = MAT_FOLIAGE; sss = 0.5; }
    else if (dhMat == DH_BLOCK_ILLUMINATED) { mat = MAT_EMISSIVE; emission = 0.6; }
    else if (dhMat == DH_BLOCK_LAVA) { mat = MAT_LAVA; emission = 1.0; }

    outAlbedo = vec4(albedo, float(mat) / 255.0);
    outNormalLm = vec4(encodeNormal(normalize(worldNormal)), lmcoord);
    outMaterial = vec4(0.0, emission, sss, 0.0);
}
#endif

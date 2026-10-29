// gbuffers_line (block outlines, leads...) - must be core profile on Iris/Oculus.
// Lines arrive as two vertices (position + direction in vaNormal); we expand them
// to a screen-space quad of constant pixel width.

#include "/lib/common.glsl"

#ifdef VERTEX
in vec3 vaPosition;
in vec4 vaColor;
in vec3 vaNormal;

uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;

out vec4 lineColor;

void main() {
    const float shrink = 1.0 - 1.0 / 256.0; // pull the line a hair towards the camera to avoid z-fighting
    vec4 a = projectionMatrix * (modelViewMatrix * vec4(vaPosition, 1.0) * vec4(vec3(shrink), 1.0));
    vec4 b = projectionMatrix * (modelViewMatrix * vec4(vaPosition + vaNormal, 1.0) * vec4(vec3(shrink), 1.0));
    vec3 ndcA = a.xyz / a.w;
    vec3 ndcB = b.xyz / b.w;
    vec2 screen = vec2(viewWidth, viewHeight);
    vec2 dir = normalize((ndcB.xy - ndcA.xy) * screen);
    vec2 offset = vec2(-dir.y, dir.x) * 2.0 / screen;
    if (offset.x < 0.0) offset = -offset;
    if (gl_VertexID % 2 == 1) offset = -offset;
    gl_Position = vec4((ndcA + vec3(offset, 0.0)) * a.w, a.w);
    gl_Position = jitterPosition(gl_Position);
    lineColor = vaColor;
}

#else
in vec4 lineColor;

/* RENDERTARGETS: 6 */
layout(location = 0) out vec4 outColor;

void main() {
    // outlines stay subtle and dark like a film set marker
    outColor = vec4(pow(lineColor.rgb, vec3(2.2)) * 0.5, lineColor.a);
}
#endif

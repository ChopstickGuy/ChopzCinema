// Fullscreen pass vertex shader: computes per-frame lighting colours once.
#include "/lib/atmosphere.glsl"

out vec2 texcoord;
flat out vec3 sunDir;
flat out vec3 lightDir;
flat out vec3 lightColor;
flat out vec3 skyAmbient;

void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    sunDir = sunDirWorld();
    lightDir = lightDirWorld();
    getFrameLighting(sunDir, lightColor, skyAmbient);
}

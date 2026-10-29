// Surface shading shared by the deferred pass and forward (translucent) passes.
// Requires common.glsl, atmosphere.glsl and (unless NO_SHADOWMAP) shadows.glsl.

vec3 blockLightColor() {
    return blackbody(float(BLOCKLIGHT_TEMP)) * BLOCKLIGHT_BRIGHTNESS;
}

vec3 blockLightAmount(float bl) {
    // smooth falloff that keeps torches punchy up close and lets light fade out softly
    float near = pow(bl, 5.0) * 2.2;
    float wide = pow(bl, 2.2) * 0.22;
    return blockLightColor() * (near + wide);
}

float ggxSpecular(vec3 n, vec3 v, vec3 l, float roughness, float f0) {
    vec3 h = normalize(v + l);
    float nh = saturate(dot(n, h));
    float nv = saturate(dot(n, v)) + 1e-4;
    float nl = saturate(dot(n, l));
    float vh = saturate(dot(v, h));
    float a = max(roughness * roughness, 0.002);
    float a2 = a * a;
    float d = a2 / (PI * sq(nh * nh * (a2 - 1.0) + 1.0));
    float k = a * 0.5;
    float vis = 1.0 / ((nl * (1.0 - k) + k) * (nv * (1.0 - k) + k));
    float f = f0 + (1.0 - f0) * pow(1.0 - vh, 5.0);
    return d * vis * f * nl * 0.25;
}

struct Surface {
    vec3 albedo;
    vec3 normal;      // world space
    vec2 lightmap;    // x: block, y: sky
    float smoothness;
    float emission;
    float sss;
    float metal;
    float ao;
};

// playerPos: camera-relative world position. useShadowMap: false for Distant Horizons LODs.
vec3 shadeSurface(Surface s, vec3 playerPos, vec3 lightDir, vec3 lightColor, vec3 skyAmbient,
                  float noise, bool useShadowMap) {
    vec3 n = s.normal;
    vec3 v = -normalize(playerPos);
    float nlRaw = dot(n, lightDir);
    float nl = saturate(nlRaw);
    if (s.sss > 0.0) nl = mix(nl, saturate(nlRaw * 0.5 + 0.5) * 0.8, s.sss * 0.6);

    float skyLm = s.lightmap.y;
#if defined DIM_NETHER || defined DIM_END
    skyLm = 1.0; // no sky light in these dimensions: ambient comes from everywhere
#endif
    float skyLm2 = skyLm * skyLm;

    // ---- direct sun / moon
    vec3 direct = vec3(0.0);
    vec3 lit = vec3(0.0);
    float lightLeak = smoothstep(0.0, 0.12, skyLm);
#if defined DIM_NETHER || defined DIM_END
    lightLeak = 0.0;
#endif
    if (lightLeak > 0.0 && (nl > 0.0 || s.sss > 0.0)) {
        vec3 vis = vec3(1.0);
#ifndef NO_SHADOWMAP
        if (useShadowMap) vis = getShadow(playerPos, n, nlRaw, noise, s.sss) * waterLightTransmit(playerPos, lightDir, 0.0);
        else
#endif
        vis = vec3(smoothstep(0.6, 0.95, skyLm));
        lit = lightColor * vis * lightLeak;

        vec3 diffuse = lit * nl * (1.0 - s.metal);
#ifdef SUBSURFACE_SCATTERING
        if (s.sss > 0.0) {
            // light shining through leaves / grass when looking towards the sun
            float back = saturate(-nlRaw);
            float vPhase = pow(saturate(dot(-v, lightDir)), 4.0);
            diffuse += lit * s.sss * (back * 0.2 + vPhase * 0.3) * s.albedo;
        }
#endif
        direct = diffuse;
    }

    // ---- sky ambient (from above, darker on downward faces)
    float upness = n.y * 0.35 + 0.65;
    vec3 ambient = skyAmbient * skyLm2 * upness;
    // bounce light from the ground tinted by the surface itself
    ambient += skyAmbient * skyLm2 * 0.12 * saturate(-n.y + 0.4) * s.albedo;

    // ---- block light
    vec3 block = blockLightAmount(s.lightmap.x);

    // ---- minimum light in caves
    vec3 minLight = vec3(0.55, 0.65, 0.8) * 0.004 * MIN_LIGHT * (1.0 - s.lightmap.y);
    minLight += vec3(0.6, 0.7, 0.6) * nightVision * 0.35;

    vec3 diffuseLight = (ambient + block + minLight) * s.ao;
    vec3 color = s.albedo * (diffuseLight + direct * mix(1.0, s.ao, 0.5)) * (1.0 - s.metal * 0.5);

#ifdef SPECULAR_HIGHLIGHTS
    if (s.smoothness > 0.05 && nl > 0.0) {
        float rough = 1.0 - s.smoothness;
        float f0 = mix(0.04, 0.9, s.metal);
        float spec = ggxSpecular(n, v, lightDir, rough, f0);
        vec3 specCol = mix(vec3(1.0), s.albedo, s.metal);
        color += specCol * spec * lit;
    }
#endif

    color += s.albedo * s.emission * 4.0;
    return color;
}

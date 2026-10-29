# Generates the per-dimension program wrappers (world0/world-1/world1).
import os
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "shaders")
DIMS = {"world0": "DIM_OVERWORLD", "world-1": "DIM_NETHER", "world1": "DIM_END"}
# program name -> (source file, extra defines)
PROGRAMS = {
    "shadow": ("shadow", []),
    "gbuffers_terrain": ("gbuffers_solid", ["TERRAIN"]),
    "gbuffers_block": ("gbuffers_solid", ["ENTITIES"]),
    "gbuffers_entities": ("gbuffers_solid", ["ENTITIES"]),
    "gbuffers_entities_glowing": ("gbuffers_solid", ["ENTITIES"]),
    "gbuffers_basic": ("gbuffers_solid", ["BASIC"]),
    "gbuffers_damagedblock": ("gbuffers_solid", ["DAMAGED_BLOCK"]),
    "gbuffers_skybasic": ("gbuffers_solid", ["SKY_BASIC"]),
    "gbuffers_skytextured": ("gbuffers_solid", ["SKY_TEXTURED"]),
    "dh_terrain": ("dh_terrain", []),
    "gbuffers_water": ("forward", ["WATER_PASS"]),
    "dh_water": ("forward", ["DH_WATER"]),
    "gbuffers_textured": ("forward", ["PARTICLES"]),
    "gbuffers_textured_lit": ("forward", ["PARTICLES"]),
    "gbuffers_weather": ("forward", ["WEATHER"]),
    "gbuffers_hand": ("forward", ["HAND"]),
    "gbuffers_hand_water": ("forward", ["HAND"]),
    "gbuffers_spidereyes": ("forward", ["EMISSIVE_ONLY"]),
    "gbuffers_beaconbeam": ("forward", ["EMISSIVE_ONLY"]),
    "gbuffers_armor_glint": ("forward", ["GLINT"]),
    "gbuffers_line": ("forward", ["LINE"]),
    "gbuffers_clouds": ("forward", ["CLOUDS"]),
    "deferred": ("deferred_clouds", []),
    "deferred1": ("deferred_lighting", []),
    "composite": ("composite_translucent", []),
    "composite1": ("composite_vl", []),
    "composite2": ("composite_fog", []),
    "composite3": ("composite_taa", []),
    "final": ("final", []),
}
for d, dimdef in DIMS.items():
    os.makedirs(os.path.join(ROOT, d), exist_ok=True)
    for prog, (src, defs) in PROGRAMS.items():
        for ext, stage in (("vsh", "VERTEX"), ("fsh", "FRAGMENT")):
            lines = ["#version 330 compatibility", "#define " + dimdef]
            lines += ["#define " + x for x in defs]
            if stage == "VERTEX":
                lines.append("#define VERTEX")
            lines.append('#include "/program/%s.glsl"' % src)
            with open(os.path.join(ROOT, d, prog + "." + ext), "w") as f:
                f.write("\n".join(lines) + "\n")
print("ok")

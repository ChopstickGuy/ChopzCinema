"""Builds both shader packs from the shared source:
   dist/ChopzCinema-<version>.zip        - the cinematic "Brand New Day" pack
   dist/ChopzCinema-Story-<version>.zip  - the painterly Ghost of Tsushima inspired pack
usage: python3 tools/build_packs.py <version> [--dirs]   (--dirs also keeps unpacked folders)"""
import os, re, shutil, sys, zipfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(REPO, "shaders")
DIST = os.path.join(REPO, "dist")

# default overrides for the Story pack (define name -> new default)
STORY_DEFAULTS = {
    "COLOR_GRADE": "5",
    "PAINTERLY": "1.0",
    "FALLING_LEAVES": True,
    "GOLDEN_ATMOSPHERE": True,
    "WAVING_STRENGTH": "1.75",
    "FOG_DENSITY": "1.25",
    "MORNING_MIST": "1.0",
    "VL_STRENGTH": "1.5",
    "BLOOM_STRENGTH": "1.75",
    "AMBIENT_BRIGHTNESS": "1.0",
    "VIGNETTE": "0.35",
    "FILM_GRAIN": "0.1",
    "DOF_STRENGTH": "0.75",
    "SUN_SIZE": "1.5",
    "MOON_SIZE": "1.25",
    "NIGHT_BRIGHTNESS": "1.5",
}

def apply_defaults(settings, overrides):
    for name, value in overrides.items():
        if value is True:
            new, n = re.subn(r"^//#define %s\s*$" % name, "#define %s" % name, settings, flags=re.M)
        else:
            new, n = re.subn(r"^(#define %s )\S+" % name, r"\g<1>%s" % value, settings, flags=re.M)
        if n == 0 and not re.search(r"^#define %s\b" % name, settings, re.M):
            raise SystemExit("define not found: " + name)
        settings = new
    return settings

def build(name, overrides, version, keep_dir):
    out_dir = os.path.join(DIST, name)
    shutil.rmtree(out_dir, ignore_errors=True)
    shutil.copytree(SRC, os.path.join(out_dir, "shaders"))
    if overrides:
        p = os.path.join(out_dir, "shaders", "lib", "settings.glsl")
        with open(p) as f:
            s = f.read()
        with open(p, "w") as f:
            f.write(apply_defaults(s, overrides))
    zpath = os.path.join(DIST, "%s-%s.zip" % (name, version))
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
        for root, _, files in os.walk(os.path.join(out_dir, "shaders")):
            for f in files:
                full = os.path.join(root, f)
                z.write(full, os.path.relpath(full, out_dir))
    if not keep_dir:
        shutil.rmtree(out_dir)
    print("built", zpath)

if __name__ == "__main__":
    version = sys.argv[1] if len(sys.argv) > 1 else "dev"
    keep = "--dirs" in sys.argv
    os.makedirs(DIST, exist_ok=True)
    build("ChopzCinema", {}, version, keep)
    build("ChopzCinema-Story", STORY_DEFAULTS, version, keep)

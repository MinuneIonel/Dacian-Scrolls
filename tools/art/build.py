#!/usr/bin/env python3
"""Regenerate every art asset and assets/manifest.json from tools/art/specs/*.json.

    python3 tools/art/build.py            # assets + manifest + docs/art-spike.png
    python3 tools/art/build.py --out DIR  # write into DIR instead of the repo root (used by tests)

Same input, same bytes: generators are seeded from the specs and PNGs carry no timestamps.
"""
import argparse
import glob
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ROOT = os.path.dirname(os.path.dirname(HERE))

import kit as K  # noqa: E402
import gen_tiles  # noqa: E402
import gen_chars  # noqa: E402
import gen_ui  # noqa: E402
import gen_cast  # noqa: E402
import gen_beasts  # noqa: E402
import gen_giants  # noqa: E402
import gen_terrain  # noqa: E402

GENERATORS = {}
GENERATORS.update(gen_tiles.GENERATORS)
GENERATORS.update(gen_ui.GENERATORS)
GENERATORS.update({"knight": gen_chars.knight, "grazi_thrall": gen_chars.grazi_thrall,
                   "giant_legs": gen_chars.giant_legs})
for _mod in (gen_cast, gen_beasts, gen_giants, gen_terrain):
    for _k, _v in _mod.GENERATORS.items():
        assert _k not in GENERATORS, _k
        GENERATORS[_k] = _v


def load_specs():
    specs = []
    for f in sorted(glob.glob(os.path.join(HERE, "specs", "*.json"))):
        with open(f) as fh:
            specs += json.load(fh)
    ids = [s["id"] for s in specs]
    assert len(ids) == len(set(ids)), "duplicate asset ids in specs"
    return specs


def anim_list(spec):
    """(name, frames, fps, loop) per sheet row: the character set (SE then NE), or the spec's own `anims`."""
    if "anims" in spec:
        return [tuple(a) for a in spec["anims"]]
    return [(name + suffix, n, fps, loop) for suffix in ("", "_ne") for name, n, fps, loop in gen_chars.ANIMS]


def frames_entry(spec, rows):
    fw, fh = spec["frame_size"]
    anims = {}
    for r, (name, n, fps, loop) in enumerate(anim_list(spec)):
        assert len(rows[r]) == n, (spec["id"], name, len(rows[r]))
        anims[name] = {"row": r, "frames": n, "fps": float(fps), "loop": loop}
    assert len(rows) == len(anims), (spec["id"], len(rows))
    entry = {"sheet": "res://" + spec["out"], "frame_size": [fw, fh], "anims": anims, "anchor": spec["anchor"]}
    if "footprint" in spec:
        entry["footprint"] = spec["footprint"]
    return entry


def build(out_root=ROOT, spike=True):
    specs = load_specs()
    textures, frames, images = {}, {}, {}
    for s in specs:
        gen = GENERATORS[s["gen"]]
        res = gen(s)
        path = os.path.join(out_root, s["out"])
        if s["type"] == "frames":
            fw, fh = s["frame_size"]
            sheet = K.pack_rows(res, fw, fh)
            K.save_png(sheet, path)
            frames[s["id"]] = frames_entry(s, res)
            images[s["id"]] = res
        else:
            K.save_png(res, path)
            textures[s["id"]] = "res://" + s["out"]
            images[s["id"]] = res
    man_path = os.path.join(out_root, "assets", "manifest.json")
    audio = {}
    existing = os.path.join(ROOT, "assets", "manifest.json")
    if os.path.exists(existing):
        with open(existing) as fh:
            audio = json.load(fh).get("audio", {})  # owned by the audio package; kept as is
    manifest = {"textures": textures, "frames": frames, "audio": audio}
    os.makedirs(os.path.dirname(man_path), exist_ok=True)
    with open(man_path, "w") as fh:
        json.dump(manifest, fh, indent=1, sort_keys=True)
        fh.write("\n")
    if spike:
        import spike as SP
        SP.compose(images, specs, os.path.join(out_root, "docs", "art-spike.png"))
    return manifest


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=ROOT)
    ap.add_argument("--no-spike", action="store_true")
    a = ap.parse_args()
    m = build(a.out, spike=not a.no_spike)
    print("built %d textures, %d sprite sheets" % (len(m["textures"]), len(m["frames"])))


if __name__ == "__main__":
    main()

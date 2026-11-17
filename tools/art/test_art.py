#!/usr/bin/env python3
"""Tests for the art pipeline. Plain python; exits non-zero on failure.

    python3 tools/art/test_art.py
"""
import glob
import hashlib
import json
import os
import sys
import tempfile

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ROOT = os.path.dirname(os.path.dirname(HERE))

import build  # noqa: E402
import palette as P  # noqa: E402

FAILS = []
ART_DIRS = ["assets/sprites", "assets/tiles", "assets/ui", "assets/fx", "assets/icons", "assets/portraits"]
REQUIRED_ANIMS = ["idle", "walk", "attack", "hit", "death"]
DACIAN = ["knight", "tile_grass", "tile_road", "tile_forest_floor", "tile_stone", "tile_wall", "ui_panel",
          "necromancer", "healer", "villager_1", "villager_2", "villager_3", "villager_4", "strigoi", "wolf", "roman_deserter",
          "bancul_recruit", "tile_dirt", "tile_cobble", "tile_andesite", "tile_sun_disc", "tile_wood_floor", "tile_door",
          "tile_water", "tile_bridge", "tile_flowers", "tile_cave_floor", "tile_bones", "tile_cave_water", "tile_mud", "tile_scree",
          "tile_snow", "tile_crate", "tile_barrel", "tile_table", "tile_altar", "tile_market_stall", "tile_fence", "tile_well",
          "tile_bush", "tile_stump", "tile_coffin", "tile_cart", "tile_milestone", "tile_boulder", "tile_murus_dacicus",
          "tile_timber_wall", "tile_house", "tile_cave_wall", "tile_cliff", "tile_andesite_pillar", "tile_limestone_pillar",
          "tile_tree", "tile_rock", "tile_stalagmite", "icon_iron_falx", "icon_sica", "icon_oak_staff", "icon_wolf_pelt",
          "icon_scale_mail", "icon_bread", "icon_healing_herbs", "icon_zalmoxis_amulet", "icon_draco_pennant",
          "portrait_knight", "portrait_healer", "portrait_necromancer", "portrait_dida", "portrait_mucapor", "portrait_bitus",
          "marker_town", "marker_cave", "prop_chest", "prop_barrel", "prop_bucket", "prop_scroll"]
REQUIRED_FX = ["fx_blood_splat_1", "fx_blood_splat_2", "fx_blood_splat_3", "fx_gib_1", "fx_gib_2", "fx_gib_3", "fx_gib_4",
               "fx_gib_5", "fx_gib_6", "fx_balloon_burst", "fx_heal_sparkle", "fx_tech_zap", "fx_magic_glyph", "fx_tractor_beam",
               "portrait_fanfi"]


def check(cond, msg):
    if not cond:
        FAILS.append(msg)


def tree_hashes(root):
    out = {}
    for rel in ART_DIRS + ["docs"]:
        for f in sorted(glob.glob(os.path.join(root, rel, "**", "*.png"), recursive=True)):
            out[os.path.relpath(f, root)] = hashlib.sha256(open(f, "rb").read()).hexdigest()
    m = os.path.join(root, "assets", "manifest.json")
    out["assets/manifest.json"] = hashlib.sha256(open(m, "rb").read()).hexdigest()
    return out


def res_path(p):
    assert p.startswith("res://"), p
    return os.path.join(ROOT, p[len("res://"):])


def load_rgba(path):
    return np.array(Image.open(path).convert("RGBA"))


def test_deterministic_and_committed():
    with tempfile.TemporaryDirectory() as a, tempfile.TemporaryDirectory() as b:
        build.build(a)
        build.build(b)
        ha, hb = tree_hashes(a), tree_hashes(b)
        check(ha == hb, "two builds differ: %s" % sorted(k for k in ha if ha.get(k) != hb.get(k)))
        committed = tree_hashes(ROOT)
        for k, v in ha.items():
            check(committed.get(k) == v, "%s is stale: run python3 tools/art/build.py" % k)


def test_palette_only():
    pal = np.array(P.RGB, dtype=np.int32)
    files = []
    for rel in ART_DIRS:
        files += glob.glob(os.path.join(ROOT, rel, "**", "*.png"), recursive=True)
    files.append(os.path.join(ROOT, "docs", "art-spike.png"))
    files += glob.glob(os.path.join(ROOT, "docs", "art-sheet-*.png"))
    check(len(files) >= 10, "expected the spike's PNGs, found %d" % len(files))
    for f in files:
        px = load_rgba(f).reshape(-1, 4).astype(np.int32)
        alpha = px[:, 3]
        check(np.all((alpha == 0) | (alpha == 255)), "%s has partial transparency" % f)
        rgb = px[alpha == 255][:, :3]
        key = rgb[:, 0] * 65536 + rgb[:, 1] * 256 + rgb[:, 2]
        allowed = pal[:, 0] * 65536 + pal[:, 1] * 256 + pal[:, 2]
        bad = np.unique(key[~np.isin(key, allowed)])
        check(bad.size == 0, "%s uses %d off-palette colours, e.g. #%06x" % (f, bad.size, bad[0] if bad.size else 0))


def test_manifest():
    m = json.load(open(os.path.join(ROOT, "assets", "manifest.json")))
    check(set(m.keys()) == {"textures", "frames", "audio"}, "manifest sections: %s" % sorted(m))
    for tid, p in m["textures"].items():
        check(isinstance(p, str) and os.path.exists(res_path(p)), "texture %s: missing %s" % (tid, p))
    for fid, e in m["frames"].items():
        path = res_path(e["sheet"])
        if not os.path.exists(path):
            check(False, "frames %s: missing %s" % (fid, e["sheet"]))
            continue
        img = load_rgba(path)
        h, w = img.shape[:2]
        fw, fh = e["frame_size"]
        rows = set()
        for suffix in ("", "_ne"):
            for a in REQUIRED_ANIMS:
                if e.get("kind") != "fx":
                    check(a + suffix in e["anims"], "frames %s lacks anim %s" % (fid, a + suffix))
        for name, a in e["anims"].items():
            rows.add(a["row"])
            check((a["row"] + 1) * fh <= h, "%s.%s: row %d outside sheet" % (fid, name, a["row"]))
            check(a["frames"] * fw <= w, "%s.%s: %d frames wider than sheet" % (fid, name, a["frames"]))
            for k in range(max(a["frames"], w // fw)):
                cell = img[a["row"] * fh:(a["row"] + 1) * fh, k * fw:(k + 1) * fw, 3]
                if k < a["frames"]:
                    check(cell.any(), "%s.%s frame %d is empty" % (fid, name, k))
                else:
                    check(not cell.any(), "%s.%s has pixels past its %d frames" % (fid, name, a["frames"]))
        check(h == len(rows) * fh and w % fw == 0, "%s: sheet %dx%d does not match %d rows of %dx%d" % (fid, w, h, len(rows), fw, fh))
        check(len(e.get("anchor", [])) == 2, "%s: anchor missing" % fid)


def test_dacian_assets_avoid_lobizi_colours():
    m = json.load(open(os.path.join(ROOT, "assets", "manifest.json")))
    lob = {P.RGB[P.IDX[n]] for n in P.LOBIZI}
    for aid in DACIAN:
        p = m["textures"].get(aid) or m["frames"].get(aid, {}).get("sheet")
        if not p:
            check(False, "missing asset %s" % aid)
            continue
        px = load_rgba(res_path(p)).reshape(-1, 4)
        cols = {tuple(c[:3]) for c in px[px[:, 3] == 255]}
        check(not (cols & lob), "%s uses colours reserved for Lobizi tech" % aid)


def test_tiles_shape():
    import kit as K
    d = K.diamond()
    check(int(d.sum()) == 64 * 32 // 2, "diamond area %d" % d.sum())
    # four neighbours on the lattice cover every pixel of a big patch exactly once
    cover = np.zeros((96, 192), int)
    for cx in range(-3, 6):
        for cy in range(-3, 6):
            x, y = K.cell_to_world(cx, cy)
            x, y = x + 64, y + 16
            if -64 < x < 192 and -32 < y < 96:
                sub = np.zeros_like(cover)
                ys, xs = np.nonzero(d)
                ok = (ys + y >= 0) & (ys + y < 96) & (xs + x >= 0) & (xs + x < 192)
                sub[ys[ok] + y, xs[ok] + x] = 1
                cover += sub
    check(np.all(cover[32:64, 64:128] == 1), "diamonds do not tile the plane exactly")
    for tid in ["tile_grass", "tile_road", "tile_forest_floor", "tile_stone"]:
        a = load_rgba(os.path.join(ROOT, "assets", "tiles", tid + ".png"))
        check(a.shape[:2] == (32, 64), "%s is %s" % (tid, a.shape[:2]))
        check(np.array_equal(a[:, :, 3] == 255, d), "%s does not fill the diamond exactly" % tid)
    w = load_rgba(os.path.join(ROOT, "assets", "tiles", "tile_wall.png"))
    check(w.shape[1] == 64 and w.shape[0] > 32, "tile_wall is %s" % (w.shape[:2],))


def test_every_data_art_id_exists():
    """Every sprite, icon, portrait and marker id under data/ is in the manifest, plus the fx set."""
    m = json.load(open(os.path.join(ROOT, "assets", "manifest.json")))
    have = set(m["textures"]) | set(m["frames"])
    want = set(REQUIRED_FX)
    for f in glob.glob(os.path.join(ROOT, "data", "**", "*.json"), recursive=True):
        if "/schemas/" in f:
            continue
        stack = [json.load(open(f))]
        while stack:
            o = stack.pop()
            if isinstance(o, dict):
                for k, v in o.items():
                    if k in ("sprite", "icon", "portrait", "marker") and isinstance(v, str):
                        want.add(v)
                    else:
                        stack.append(v)
            elif isinstance(o, list):
                stack += o
    missing = sorted(want - have)
    check(not missing, "art ids without assets: %s" % missing)


def main():
    tests = [v for k, v in sorted(globals().items()) if k.startswith("test_") and callable(v)]
    for t in tests:
        n = len(FAILS)
        t()
        print("%s %s" % ("ok  " if len(FAILS) == n else "FAIL", t.__name__))
    for f in FAILS:
        print("  - " + f)
    print("%d failures" % len(FAILS))
    sys.exit(1 if FAILS else 0)


if __name__ == "__main__":
    main()

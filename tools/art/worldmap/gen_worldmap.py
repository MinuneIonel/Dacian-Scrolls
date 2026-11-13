#!/usr/bin/env python3
"""World map art: a parchment map painted from data/world.json, plus markers and the party banner.

    python3 tools/art/worldmap/gen_worldmap.py            # writes assets/worldmap/*
    python3 tools/art/worldmap/gen_worldmap.py --out DIR  # into DIR/assets/worldmap instead

Deterministic (seeded numpy, no timestamps). Only the 32 palette colours plus full transparency.
Regenerate whenever world.json's terrain changes. The view reads manifest_worldmap.json.
"""
import argparse
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))

import kit as K  # noqa: E402
import palette as P  # noqa: E402

T = P.TRANSPARENT
C = 16  # cell size in pixels
I = P.IDX


def bayer(shape):
    return K.BAYER4_tile(shape)


def upsample(mask_cells, noise, rng):
    """Cell mask (H, W) of 0/1 -> pixel field in [0, 1], smooth across cell edges, with noise."""
    h, w = mask_cells.shape
    m = mask_cells.astype(float)
    pad = np.pad(m, 1, mode="edge")
    ys = (np.arange(h * C) + 0.5) / C + 0.5
    xs = (np.arange(w * C) + 0.5) / C + 0.5
    y0 = np.floor(ys - 0.5).astype(int); x0 = np.floor(xs - 0.5).astype(int)
    fy = (ys - 0.5 - y0)[:, None]; fx = (xs - 0.5 - x0)[None, :]
    a = pad[y0][:, x0]; b = pad[y0][:, x0 + 1]; c = pad[y0 + 1][:, x0]; d = pad[y0 + 1][:, x0 + 1]
    f = a * (1 - fx) * (1 - fy) + b * fx * (1 - fy) + c * (1 - fx) * fy + d * fx * fy
    if noise > 0:
        n = rng.random((h * 2 + 2, w * 2 + 2))
        n = np.repeat(np.repeat(n, C // 2, 0), C // 2, 1)[:h * C, :w * C]
        f = f + (n - 0.5) * noise
    return np.clip(f, 0, 1)


# ---------------------------------------------------------------- small sprites

def tree(variant):
    """A little conifer or round tree, ~9x11, outlined in deep forest ink."""
    w, h = 11, 13
    c = K.canvas(w, h)
    if variant % 2 == 0:  # fir
        body = K.poly(w, h, [(5, 0), (9, 9), (1, 9)])
        K.shade(c, body, [I["green0"], I["green1"], I["green2"]], light=(-1, -1))
        c[10, 5] = I["brown1"]; c[9, 5] = I["brown1"]
    else:  # round oak
        body = K.ellipse(w, h, (1, 1, 9, 8))
        K.shade(c, body, [I["green1"], I["green2"], I["green3"]], light=(-1, -1))
        c[9, 5] = I["brown1"]; c[10, 5] = I["brown1"]
    K.outline(c, I["green0"])
    return c


def peak(variant):
    """A mountain peak, lit from the west: light flank, shaded flank, snow on the tall ones."""
    w, h = 21, 16
    c = K.canvas(w, h)
    tall = variant % 3 == 0
    top = 1 if tall else 4
    apex = 10 + (variant % 2) - 0
    left = K.poly(w, h, [(apex, top), (apex, 14), (1, 14)])
    right = K.poly(w, h, [(apex, top), (19, 14), (apex, 14)])
    c[left] = I["grey3"]
    c[right] = I["brown2"]
    # strata lines on the dark side
    for k in range(3):
        y = 8 + k * 2
        for x in range(apex + 1, 19):
            if right[y, x] and (x + k) % 3 != 0:
                c[y, x] = I["brown1"]
    if tall:
        snow = K.poly(w, h, [(apex, top), (apex + 3, top + 4), (apex, top + 3), (apex - 3, top + 4)])
        c[snow & (left | right)] = I["white"]
    K.outline(c, I["brown0"])
    return c


def tuft():
    c = K.canvas(5, 3)
    for x, y in [(0, 1), (1, 2), (2, 0), (2, 1), (2, 2), (3, 2), (4, 1)]:
        c[y, x] = I["green3"]
    return c


# ---------------------------------------------------------------- the map

def paint_map(world):
    rng = np.random.default_rng(1953)
    W, H = world["size"]
    legend = world["legend"]
    rows = world["terrain"]
    terr = [[legend.get(rows[y][x], "") for x in range(W)] for y in range(H)]
    is_t = {t: np.array([[terr[y][x] == t for x in range(W)] for y in range(H)]) for t in
            ["road", "plains", "forest", "mountain", "river"]}
    PW, PH = W * C, H * C
    c = np.full((PH, PW), I["straw"], np.uint8)
    th = bayer((PH, PW))

    # Parchment: blotches of age and a few fibres.
    age = upsample((rng.random((H, W)) > 0.6).astype(float), 0.5, rng)
    c[(age * 0.55 > th) & (rng.random((PH, PW)) < 0.35)] = I["ochre"]
    speck = rng.random((PH, PW))
    c[speck < 0.004] = I["brown3"]

    # Ground tints with dithered, wobbly borders.
    forest_f = upsample(is_t["forest"], 0.35, rng)
    mount_f = upsample(is_t["mountain"], 0.35, rng)
    green = forest_f > 0.5
    K.dither_mix(c, green, I["green3"], I["green4"], (forest_f - 0.5) * 2.2)
    c[green & (forest_f > 0.85) & (th < 0.5)] = I["green2"]
    hill = mount_f > 0.5
    K.dither_mix(c, hill, I["straw"], I["brown3"], (mount_f - 0.5) * 2.4)

    # Plains: grass tufts and stipple.
    tf = tuft()
    for y in range(H):
        for x in range(W):
            if terr[y][x] == "plains":
                for _ in range(2):
                    if rng.random() < 0.55:
                        K.stamp(c, tf, x * C + int(rng.integers(0, 12)), y * C + int(rng.integers(0, 13)))
                for _ in range(3):
                    px, py = x * C + int(rng.integers(0, C)), y * C + int(rng.integers(0, C))
                    c[py, px] = I["brown3"]

    # Water: the river and the shallow crossings beneath other terrain.
    river = is_t["river"]
    def riv(x, y):
        return 0 <= x < W and 0 <= y < H and river[y, x]
    wet = np.zeros((PH, PW), bool)
    shallow = np.zeros((PH, PW), bool)
    for y in range(H):
        for x in range(W):
            x0, y0 = x * C, y * C
            if river[y, x]:
                m = np.zeros((C, C), bool)
                m[3:13, 3:13] = True
                if riv(x, y - 1) or y == 0: m[0:3, 3:13] = True
                if riv(x, y + 1) or y == H - 1: m[13:16, 3:13] = True
                if riv(x - 1, y): m[3:13, 0:3] = True
                if riv(x + 1, y): m[3:13, 13:16] = True
                wet[y0:y0 + C, x0:x0 + C] |= m
            elif (riv(x, y - 1) and riv(x, y + 1)) or (riv(x - 1, y) and riv(x + 1, y)):
                m = np.zeros((C, C), bool)
                if riv(x, y - 1): m[:, 4:12] = True
                else: m[4:12, :] = True
                shallow[y0:y0 + C, x0:x0 + C] |= m
    # Round inner corners where two river cells meet diagonally-adjacent turns.
    for y in range(H):
        for x in range(W):
            if river[y, x]:
                for dx, dy in [(1, 1), (-1, 1), (1, -1), (-1, -1)]:
                    if riv(x + dx, y) and riv(x, y + dy):
                        cx = x * C + (13 if dx > 0 else 0); cy = y * C + (13 if dy > 0 else 0)
                        wet[cy:cy + 3, cx:cx + 3] = True
    bank = K.grow(wet, True) & ~wet
    c[K.grow(bank) & ~wet] = I["brown3"]
    c[wet] = I["blue1"]
    c[bank] = I["blue0"]
    # Flow lines: short wavy dashes along the stream.
    for y in range(H):
        for x in range(W):
            if not river[y, x]:
                continue
            vertical = riv(x, y - 1) or riv(x, y + 1)
            for k in range(2):
                ox = x * C + 4 + int(rng.integers(0, 6)); oy = y * C + 3 + int(rng.integers(0, 8))
                for t in range(4):
                    px = ox + (t % 2 if vertical else t); py = oy + (t if vertical else t % 2)
                    if 0 <= px < PW and 0 <= py < PH and wet[py, px]:
                        c[py, px] = I["blue2"]
    K.dither_mix(c, shallow, I["blue1"], I["blue2"], 0.5)

    # Trees, back to front, a few per forest cell, jittered.
    trees = [tree(v) for v in range(4)]
    spots = []
    for y in range(H):
        for x in range(W):
            if terr[y][x] == "forest":
                for (sx, sy) in [(0, 0), (8, 1), (4, 7), (11, 8)]:
                    if rng.random() < 0.85:
                        spots.append((y * C + sy + int(rng.integers(-1, 3)) - 3,
                                      x * C + sx + int(rng.integers(-1, 2)) - 1,
                                      int(rng.integers(0, 4))))
    for py, px, v in sorted(spots):
        K.stamp(c, trees[v], px, py)

    # Mountains: one or two peaks per cell, back to front.
    peaks = [peak(v) for v in range(6)]
    spots = []
    for y in range(H):
        for x in range(W):
            if terr[y][x] == "mountain":
                spots.append((y * C - 4 + int(rng.integers(0, 3)), x * C - 3 + int(rng.integers(-1, 3)),
                              int(rng.integers(0, 6))))
                if rng.random() < 0.3:
                    spots.append((y * C + 2, x * C + 4 + int(rng.integers(-2, 3)), 1 + 3 * int(rng.integers(0, 2)) % 6))
    for py, px, v in sorted(spots):
        K.stamp(c, peaks[v], px, py)

    # Roads: a packed-earth band between cell centres, edged, with paving ticks; bridges over water.
    locs = {tuple(l["cell"]) for l in world.get("locations", [])}
    def roadish(x, y):
        return 0 <= x < W and 0 <= y < H and (terr[y][x] == "road" or (x, y) in locs)
    band = np.zeros((PH, PW), bool)
    for y in range(H):
        for x in range(W):
            if terr[y][x] != "road":
                continue
            cx, cy = x * C + 7, y * C + 7
            band[cy - 2:cy + 4, cx - 2:cx + 4] = True
            for dx, dy in [(1, 0), (0, 1), (-1, 0), (0, -1)]:
                if roadish(x + dx, y + dy):
                    x0, x1 = sorted([cx, cx + dx * C]); y0, y1 = sorted([cy, cy + dy * C])
                    band[y0 - 2:y1 + 4, x0 - 2:x1 + 4] = True
    edge = K.border(band)
    c[band] = I["brown3"]
    c[edge] = I["brown1"]
    tick = band & ~edge & (((np.arange(PW)[None, :] + np.arange(PH)[:, None]) % 4) == 0)
    c[tick] = I["brown2"]
    bridge = band & K.grow(wet | shallow, True)
    c[K.grow(bridge, True) & band] = I["brown2"]
    for y in range(H):
        for x in range(W):
            if terr[y][x] == "road" and riv(x, y - 1) and riv(x, y + 1):
                x0, y0 = x * C, y * C
                c[y0:y0 + C, x0 + 4] = I["brown0"]; c[y0:y0 + C, x0 + 11] = I["brown0"]
                c[y0:y0 + C, x0 + 5:x0 + 11] = I["brown2"]
                c[y0 + 1:y0 + C:3, x0 + 5:x0 + 11] = I["brown1"]

    # A compass rose in the empty south-east plains.
    rose = compass()
    K.stamp(c, rose, 44 * C - rose.shape[1] // 2, 23 * C - rose.shape[0] // 2)

    # A worn ink frame.
    c[0:2, :] = I["brown0"]; c[-2:, :] = I["brown0"]; c[:, 0:2] = I["brown0"]; c[:, -2:] = I["brown0"]
    c[3, 3:-3] = I["brown1"]; c[-4, 3:-3] = I["brown1"]; c[3:-3, 3] = I["brown1"]; c[3:-3, -4] = I["brown1"]
    return c


def compass():
    w = h = 41
    c = K.canvas(w, h)
    m = w // 2
    ring = K.ellipse(w, h, (6, 6, 34, 34)) & ~K.ellipse(w, h, (8, 8, 32, 32))
    c[ring] = I["brown1"]
    for (dx, dy, long) in [(0, -1, 1), (1, 0, 0), (0, 1, 0), (-1, 0, 0)]:
        L = 20 if long else 15
        tip = (m + dx * L, m + dy * L)
        px, py = -dy, dx
        a = (m + px * 4, m + py * 4); b = (m - px * 4, m - py * 4)
        left = K.poly(w, h, [tip, a, (m, m)])
        right = K.poly(w, h, [tip, b, (m, m)])
        c[left] = I["red1"] if long else I["brown3"]
        c[right] = I["red0"] if long else I["brown1"]
    for dx, dy in [(1, 1), (1, -1), (-1, 1), (-1, -1)]:
        diag = K.poly(w, h, [(m + dx * 10, m + dy * 10), (m + 2, m), (m, m + 2), (m - 2, m), (m, m - 2)])
        c[diag & (c == T)] = I["brown2"]
    c[m - 1:m + 2, m - 1:m + 2] = I["straw"]
    K.outline(c, I["brown0"])
    return c


# ---------------------------------------------------------------- markers and the party

def marker_town():
    w, h = 26, 22
    c = K.canvas(w, h)
    mound = K.ellipse(w, h, (1, 11, 24, 21))
    K.shade(c, mound, [I["brown1"], I["brown2"], I["brown3"]], light=(-1, -1))
    wall = K.rect(w, h, 4, 9, 21, 15)
    K.shade(c, wall, [I["grey1"], I["grey2"], I["grey3"]], light=(-1, 0))
    for x in range(4, 22, 3):
        c[8, x] = I["grey3"]; c[8, x + 1] = I["grey2"]
    for x in range(5, 21, 4):
        c[11:13, x] = I["grey0"]
    c[12:16, 12:14] = I["brown0"]  # gate
    tower = K.rect(w, h, 10, 3, 15, 9)
    K.shade(c, tower, [I["brown1"], I["brown2"], I["brown3"]], light=(-1, 0))
    roof = K.poly(w, h, [(12.5, -1), (17, 4), (8, 4)])
    c[roof] = I["red1"]
    c[K.border(roof) & K.shift(roof, 1, 0)] = I["red0"]
    c[1, 12:14] = I["ochre"]
    K.outline(c)
    return c


def marker_cave():
    w, h = 24, 18
    c = K.canvas(w, h)
    rock = K.ellipse(w, h, (1, 2, 22, 22))
    rock &= K.rect(w, h, 0, 0, w - 1, 16)
    K.shade(c, rock, [I["grey0"], I["grey1"], I["grey2"], I["grey3"]], light=(-1, -1))
    mouth = K.ellipse(w, h, (7, 7, 16, 22)) & K.rect(w, h, 0, 0, w - 1, 16)
    c[mouth] = I["outline"]
    c[K.border(mouth) & ~K.shift(mouth, 0, -1)] = I["brown0"]
    for x, y in [(5, 9), (17, 6), (19, 11), (4, 13)]:
        c[y, x] = I["green2"]
    K.outline(c)
    return c


def marker_crash():
    """A saucer nose-down in a scorched crater. Alien, so the reserved cyan is allowed."""
    w, h = 28, 20
    c = K.canvas(w, h)
    crater = K.ellipse(w, h, (1, 12, 26, 19))
    c[crater] = I["brown0"]
    c[K.ellipse(w, h, (4, 13, 23, 18))] = I["outline"]
    disc = K.poly(w, h, [(3, 9), (14, 4), (26, 8), (24, 12), (13, 16), (4, 13)])
    K.shade(c, disc, [I["grey1"], I["grey2"], I["grey3"], I["grey4"]], light=(-1, -1))
    dome = K.ellipse(w, h, (10, 3, 19, 10)) & ~K.shift(disc, 0, 0) | (K.ellipse(w, h, (10, 3, 19, 10)) & K.rect(w, h, 0, 0, w, 6))
    c[dome] = I["teal"]
    c[K.ellipse(w, h, (12, 4, 15, 6))] = I["cyan"]
    for x in range(6, 24, 4):
        y = int(round(12 - (x - 6) * 0.05))
        if 0 <= y < h and c[y, x] != T:
            c[y, x] = I["cyan"]
    for x, y in [(22, 2), (23, 1), (21, 0), (24, 3)]:
        c[y, x] = I["grey2"]  # smoke
    K.outline(c)
    return c


def party_banner():
    """The Draco: a wolf-headed silver standard trailing a red cloth tube, on a pole."""
    w, h = 20, 24
    c = K.canvas(w, h)
    c[4:23, 4] = I["brown1"]
    c[4:23, 5] = I["brown2"]
    head = K.poly(w, h, [(3, 3), (9, 1), (12, 3), (10, 6), (3, 6)])
    K.shade(c, head, [I["grey2"], I["grey3"], I["grey4"]], light=(0, -1))
    c[2, 9] = I["grey4"]; c[3, 11] = I["white"]
    c[4, 11] = I["blood"]  # tongue
    c[3, 7] = I["outline"]  # eye
    tail = np.zeros((h, w), bool)
    for x in range(9, 18):
        y = 5 + int(round(1.6 * np.sin((x - 9) * 0.8)))
        th = 5 if x < 13 else (4 if x < 16 else 3)
        tail[y:y + th, x] = True
    tail &= ~head
    c[tail] = I["red1"]
    c[tail & ~K.shift(tail, 0, 1)] = I["red0"]
    c[22:24, 2:8] = I["brown0"]  # base shadow
    K.outline(c)
    return c


GENERATED = {
    "marker_town": marker_town,
    "marker_cave": marker_cave,
    "marker_crash": marker_crash,
    "worldmap_party": party_banner,
}


def build(out_root=ROOT):
    world = json.load(open(os.path.join(ROOT, "data", "world.json")))
    out_dir = os.path.join(out_root, "assets", "worldmap")
    textures = {}
    K.save_png(paint_map(world), os.path.join(out_dir, "worldmap_terrain.png"))
    textures["worldmap_terrain"] = "res://assets/worldmap/worldmap_terrain.png"
    for name, fn in GENERATED.items():
        K.save_png(fn(), os.path.join(out_dir, name + ".png"))
        textures[name] = "res://assets/worldmap/%s.png" % name
    manifest = {"cell": C, "textures": textures}
    with open(os.path.join(out_dir, "manifest_worldmap.json"), "w") as f:
        json.dump(manifest, f, indent=1, sort_keys=True)
        f.write("\n")
    return textures


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=ROOT)
    a = ap.parse_args()
    for k, v in sorted(build(a.out).items()):
        print(k, v)

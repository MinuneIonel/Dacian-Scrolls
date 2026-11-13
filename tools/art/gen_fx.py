"""Effects: gore decals and chunks, the giant water-balloon pop, heal sparkle, tech zap, magic glyph
and the UFO tractor beam. Splatter comedy: bright, round, cartoonish, never anatomical.

Decals are iso-flattened (2:1) and centred on their texture; animated effects are frames entries
with their own `anims` and `"kind": "fx"`, anchored at their centre (beam: top centre).
"""
import math

import numpy as np

import kit as K
import palette as P
import rig as R
from rig import poly, oval, path, dots, line

I = P.IDX
E = I["outline"]


def rr(*names):
    return [I[n] for n in names]


BLOOD = rr("red0", "red1", "blood")
BLOOD_WET = rr("red1", "blood")


def outline_keep(shapes, w, h, outline=True):
    c = R.render(shapes, w, h, outline=False)
    return K.outline(c) if outline else c


def splat_shapes(seed, cx, cy, rx, ry, blobs=7, drops=9):
    rnd = K.rng(seed)
    S = [oval(cx, cy, rx, ry, BLOOD_WET)]
    for _ in range(blobs):
        a = rnd.uniform(0, 2 * math.pi)
        d = rnd.uniform(0.6, 1.0)
        r = rnd.uniform(0.25, 0.45)
        S.append(oval(cx + math.cos(a) * rx * d, cy + math.sin(a) * ry * d, rx * r, ry * r, BLOOD_WET))
    for _ in range(drops):
        a = rnd.uniform(0, 2 * math.pi)
        d = rnd.uniform(1.15, 1.7)
        r = rnd.uniform(0.8, 1.8)
        S.append(oval(cx + math.cos(a) * rx * d, cy + math.sin(a) * ry * d, r, r * 0.6, BLOOD_WET))
    S.append(dots([(cx - rx * 0.4, cy - ry * 0.4), (cx - rx * 0.3, cy - ry * 0.5)], I["blood"]))
    return S


def blood_splat(spec):
    """A flat decal for the ground, 32x16, no outline (it is paint, not an object)."""
    w, h = spec.get("size", [32, 16])
    c = R.render(splat_shapes(spec["seed"], w / 2, h / 2, w * 0.28, h * 0.28), w, h, outline=False)
    return c


GIBS = {
    # 12x12 chunks: cartoon meat, a bone, a tooth, an eyeball, a sandal, a steak with a bone
    "meat": lambda: [oval(6, 6, 4.4, 3.4, rr("red0", "red1", "blood")), dots([(4, 5), (5, 4)], I["skin2"])],
    "bone": lambda: [path([(3, 8), (9, 4)], 1.0, rr("grey3", "grey4", "white")),
                     oval(2.4, 7.4, 1.6, 1.6, rr("grey3", "grey4")), oval(3.6, 9.2, 1.6, 1.6, rr("grey3", "grey4")),
                     oval(8.4, 2.8, 1.6, 1.6, rr("grey3", "grey4")), oval(9.6, 4.6, 1.6, 1.6, rr("grey3", "grey4"))],
    "tooth": lambda: [poly([(3, 3), (9, 3), (8, 7), (7, 10), (6, 7), (5, 10), (4, 7)], rr("grey3", "grey4", "white"))],
    "eye": lambda: [oval(6, 6, 4, 4, rr("grey3", "grey4", "white")), oval(7, 6, 1.8, 1.8, rr("blue0", "blue1")), dots([(7, 6)], E),
                    dots([(5, 4)], I["white"]), path([(2, 8), (0, 10)], 0.6, rr("red0", "red1"))],
    "sandal": lambda: [poly([(1, 7), (4, 4), (10, 3), (11, 5), (8, 8), (2, 9)], rr("brown1", "brown2", "brown3")),
                       line([(4, 4), (6, 8)], I["ochre"]), line([(7, 3), (9, 7)], I["ochre"])],
    "steak": lambda: [oval(6, 7, 4.6, 3.4, rr("red0", "red1", "blood")), oval(6, 6.6, 2.4, 1.6, rr("skin1", "skin2")),
                      path([(8, 4), (11, 1)], 0.8, rr("grey3", "grey4", "white"))],
}


def gib(spec):
    return outline_keep(GIBS[spec["glyph"]](), 12, 12)


def balloon_burst(spec):
    """A giant pops like a water balloon: wobble, bulge, POP, a ring of splash, droplets, a puddle."""
    w, h = spec["frame_size"]
    cx, cy = w / 2, h / 2
    frames = []
    # 0: the wobble (a pale silk blob squashing)
    frames.append(outline_keep([oval(cx, cy, 18, 22, rr("silk0", "grey4", "white"), dither=True),
                                dots([(cx - 6, cy - 10), (cx - 5, cy - 11)], I["white"])], w, h))
    # 1: bulge, red showing through the seams
    frames.append(outline_keep([oval(cx, cy, 24, 20, rr("silk0", "grey4", "white"), dither=True),
                                path([(cx - 14, cy - 4), (cx - 4, cy + 2), (cx + 8, cy - 3), (cx + 16, cy + 4)], 1.0, BLOOD),
                                path([(cx - 6, cy - 14), (cx, cy - 6), (cx + 4, cy - 12)], 0.8, BLOOD)], w, h))
    # 2: POP: a jagged star of blood with a white flash core
    star = []
    for k in range(16):
        a = 2 * math.pi * k / 16
        r = 40 if k % 2 == 0 else 22
        star.append((cx + math.cos(a) * r, cy + math.sin(a) * r * 0.8))
    frames.append(outline_keep([poly(star, BLOOD), oval(cx, cy, 14, 11, rr("straw", "white")), oval(cx, cy, 7, 6, [I["white"]])], w, h))
    # 3..4: the splash ring flies out, droplets everywhere, scraps of robe
    for f, rad in ((3, 34), (4, 42)):
        rnd = K.rng(spec["seed"] + f)
        S = []
        for k in range(14):
            a = 2 * math.pi * k / 14 + rnd.uniform(-0.1, 0.1)
            r = rad * rnd.uniform(0.8, 1.05)
            s = 5 - f + rnd.uniform(0, 2.5)
            S.append(oval(cx + math.cos(a) * r, cy + math.sin(a) * r * 0.7, s, s * 0.8, BLOOD_WET))
        for k in range(10):
            a = rnd.uniform(0, 2 * math.pi)
            r = rad * rnd.uniform(0.3, 0.7)
            S.append(oval(cx + math.cos(a) * r, cy + math.sin(a) * r * 0.7, 2, 1.6, BLOOD_WET))
        S.append(poly([(cx - 10, cy + 4 - f), (cx - 2, cy - f), (cx - 4, cy + 6)], rr("silk0", "grey4", "white")))
        S.append(poly([(cx + 8, cy - 6 + f), (cx + 16, cy - 8 + f), (cx + 12, cy - 2)], rr("blue0", "blue1")))
        frames.append(outline_keep(S, w, h))
    # 5: it rains down into a puddle on the ground
    frames.append(R.render(splat_shapes(spec["seed"], cx, cy + h * 0.25, 30, 12, blobs=9, drops=14), w, h, outline=False))
    return [frames]


def heal_sparkle(spec):
    w, h = spec["frame_size"]
    frames = []
    pts = [(10, 26), (20, 22), (15, 14), (24, 30), (8, 18), (22, 10)]
    for f in range(4):
        S = []
        for k, (x, y) in enumerate(pts):
            yy = y - f * 3 - (k % 2) * 2
            if yy < 2:
                continue
            big = (k + f) % 3 == 0
            col = [I["white"], I["straw"], I["green4"]][(k + f) % 3]
            S.append(line([(x - (2 if big else 1), yy), (x + (2 if big else 1), yy)], col))
            S.append(line([(x, yy - (2 if big else 1)), (x, yy + (2 if big else 1))], col))
            S.append(dots([(x, yy)], I["white"]))
        frames.append(R.render(S, w, h, outline=False))
    return [frames]


def tech_zap(spec):
    w, h = spec["frame_size"]
    frames = []
    for f in range(4):
        rnd = K.rng(spec["seed"] + f)
        S = []
        for arc in range(2):
            x, y = w / 2 + rnd.uniform(-3, 3), 2
            pts = [(x, y)]
            while y < h - 4:
                y += rnd.uniform(3, 6)
                x += rnd.uniform(-5, 5)
                pts.append((x, min(y, h - 3)))
            S.append(path(pts, 0.9 if arc == 0 else 0.5, rr("teal", "cyan") if arc == 0 else rr("acid", "acid")))
            S.append(line(pts, I["white"] if arc == 0 else I["acid"]))
        S.append(oval(w / 2, h - 4, 5 - f, 2, rr("cyan", "white")))
        frames.append(R.render(S, w, h, outline=False))
    return [frames]


def magic_glyph(spec):
    """A bronze ring of runes on the ground (iso-flattened), pulsing."""
    w, h = spec["frame_size"]
    cx, cy = w / 2, h / 2
    frames = []
    for f in range(4):
        col = [I["ochre"], I["straw"], I["white"], I["straw"]][f]
        S = []
        for r, n in ((w / 2 - 2, 40), (w / 2 - 7, 32)):
            pts = R.circle_pts(cx, cy, r, r / 2, n)
            S.append(R.Shape("line", pts + [pts[0]], [col]))
        for k in range(8):
            a = 2 * math.pi * k / 8 + f * 0.1
            x, y = cx + math.cos(a) * (w / 2 - 4.5), cy + math.sin(a) * (w / 4 - 2.2)
            S.append(line([(x - 1, y - 1), (x + 1, y + 1)], col))
            S.append(dots([(x + 1, y - 1)], col))
        # the sun sign of Zalmoxis in the middle
        S.append(oval(cx, cy, 4, 2, rr("ochre", "straw")))
        S.append(line([(cx - 8, cy), (cx + 8, cy)], col))
        S.append(line([(cx, cy - 4), (cx, cy + 4)], col))
        frames.append(R.render(S, w, h, outline=False))
    return [frames]


def tractor_beam(spec):
    """A cone of cyan light from the saucer's belly (top centre) to the ground, rings sliding down."""
    w, h = spec["frame_size"]
    cx = w / 2
    frames = []
    ys, xs = np.mgrid[0:h, 0:w]
    half = 4 + (w / 2 - 6) * ys / (h - 1)
    cone = np.abs(xs - cx + 0.5) < half
    th = K.BAYER4_tile((h, w))
    for f in range(4):
        c = K.canvas(w, h)
        # sparse dither: mostly see-through, denser at the core and the edges
        edge = np.abs(np.abs(xs - cx + 0.5) - half) < 1.2
        core = np.abs(xs - cx + 0.5) < half * 0.35
        c[cone & (th < 0.22)] = I["teal"]
        c[cone & core & (th < 0.38)] = I["cyan"]
        c[cone & edge] = I["cyan"]
        ring_y = ((ys + f * 8) % 32) < 2
        c[cone & ring_y & (th < 0.75)] = I["cyan"]
        c[cone & ring_y & (th < 0.3)] = I["white"]
        # a pool of light where it meets the ground
        pool = ((xs - cx) / (w / 2 - 2)) ** 2 + ((ys - (h - 6)) / 5.0) ** 2 < 1
        c[pool & (th < 0.5)] = I["cyan"]
        c[pool & (th < 0.15)] = I["white"]
        frames.append(c)
    return [frames]


GENERATORS = {"blood_splat": blood_splat, "gib": gib, "balloon_burst": balloon_burst, "heal_sparkle": heal_sparkle,
              "tech_zap": tech_zap, "magic_glyph": magic_glyph, "tractor_beam": tractor_beam}

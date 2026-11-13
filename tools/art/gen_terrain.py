"""Every tile id in data/tiles.json beyond the spike set, plus world-map terrain.

Three shapes, all 64 px wide with the 64x32 diamond as the bottom 32 rows:
- flat ground (64x32): fills the diamond exactly and tiles seamlessly (cell_uv patterns repeat
  every cell; scattered details wrap on the lattice);
- low props (64 x 32+h, not "tall" in tiles.json): drawn in the map's ground layer, so they carry
  their own ground diamond and stay short;
- tall tiles (64 x 32+h, "tall"): walls, trees, pillars, tanks. The diamond is filled with the
  ground they stand on, so nothing of the fallback floor shows.
Light from the top-left: left faces lit, right faces dark, light rims on top edges.
"""
import math

import numpy as np

import kit as K
import palette as P
import rig as R
import gen_tiles as GT
from rig import poly, oval, path, dots, line

I = P.IDX
E = I["outline"]
W, H = K.TILE_W, K.TILE_H
X = (32, 16)    # one cell along +x on screen
Y = (-32, 16)   # one cell along +y


def rr(*names):
    return [I[n] for n in names]


# ------------------------------------------------------------------ helpers

def scatter(t, rnd, count, draw):
    GT._scatter(t, rnd, count, draw)


def noise_ground(seed, levels, cuts, f1=6, f2=3, amp2=0.5):
    return GT._base(seed, levels, cuts, f1, f2, amp2)


def finish(t):
    t[~K.diamond()] = K.T
    return t


def uv():
    return K.cell_uv()


def frac(a):
    return a - np.floor(a)


def ground(name, seed):
    """A ground diamond by tile name (for the base of props and tall tiles)."""
    fn = FLAT.get(name) or GT.GENERATORS[name]
    return fn({"seed": seed})


def on_ground(base, height):
    """A 64 x (32+height) canvas with the ground diamond at the bottom."""
    c = K.canvas(W, H + height)
    K.stamp(c, base, 0, height)
    return c


def contact_shadow(c, cx, cy, rx, ry):
    h, w = c.shape
    m = K.ellipse(w, h, (cx - rx, cy - ry, cx + rx - 1, cy + ry - 1)) & (c != K.T)
    K.darken(c, m)


def put(c, shapes, outline=True):
    """Render rig shapes on the tile canvas size and stamp them (outlined) over c."""
    h, w = c.shape
    top = R.render(shapes, w, h, outline=outline)
    K.stamp(c, top, 0, 0)
    return c


def iso_pt(c, a, b, up=0.0):
    """Screen point at a cells along x and b along y from the ground point c, raised by `up` px."""
    return (c[0] + a * X[0] + b * Y[0], c[1] + a * X[1] + b * Y[1] - up)


def box(c, ha, hb, h, top, lit, dark, z=0.0, edge=True):
    """An iso box centred on ground point c: half-sizes in cells, height in px. Returns shapes."""
    n0, e0, s0, w0 = iso_pt(c, -ha, -hb, z), iso_pt(c, ha, -hb, z), iso_pt(c, ha, hb, z), iso_pt(c, -ha, hb, z)
    up = lambda p: (p[0], p[1] - h)
    S = [poly([w0, s0, up(s0), up(w0)], lit),
         poly([s0, e0, up(e0), up(s0)], dark),
         poly([up(n0), up(e0), up(s0), up(w0)], top)]
    if edge:
        S.append(line([up(w0), up(s0), up(e0)], top[-1] if len(top) > 1 else top[0]))
        S.append(line([s0, up(s0)], lit[-1]))
    return S


def cylinder(cx, base_y, r, h, body, top, ry=None, light=(-1, 0)):
    ry = ry if ry is not None else r / 2
    top_y = base_y - h
    S = [poly([(cx - r, top_y)] + [(cx + r * math.cos(t), base_y + ry * math.sin(t)) for t in np.linspace(math.pi, 0, 13)] + [(cx + r, top_y)],
              body, light=light),
         oval(cx, top_y, r, ry, top)]
    return S


def face_coords(hgt):
    Ht = H + hgt
    ys, xs = np.mgrid[0:Ht, 0:W]
    vL = ys - 16 - np.floor(xs / 2)
    vR = ys - 16 - np.floor((W - 1 - xs) / 2)
    return xs, ys, vL, vR


def wall_tile(hgt, paint_face, top_tex, rim=True, rim_cols=("grey4", "grey3")):
    """A prism tile: paint_face(t, mask, u, v, lit) paints each side, top_tex is a 64x32 diamond canvas."""
    top, left, right = K.prism(hgt)
    t = K.canvas(W, H + hgt)
    xs, ys, vL, vR = face_coords(hgt)
    paint_face(t, left, xs, vL, True)
    paint_face(t, right, W - 1 - xs, vR, False)
    tt = top_tex.copy()
    dm = K.diamond()
    if rim:
        b = K.border(dm)
        tt[b] = I[rim_cols[0]]
        tt[b & (np.arange(W)[None, :] >= W // 2) & (np.arange(H)[:, None] >= H // 2 - 1)] = I[rim_cols[1]]
    t[:H][top[:H]] = tt[top[:H]]
    sil = K.border(top | left | right) & ~top
    t[sil & left] = I["grey1"] if rim else t[sil & left]
    return t


# ------------------------------------------------------------------ flat ground

def tile_dirt(spec):
    rnd = K.rng(spec["seed"])
    t, d = noise_ground(spec["seed"], [I["brown1"], I["brown2"], I["brown2"]], [0.22, 0.85], f1=6, f2=6, amp2=0.8)
    scatter(t, rnd, 8, lambda r: [(0, 0, I["brown3"]), (1, 0, I["brown1"]), (0, 1, I["brown0"])])
    scatter(t, rnd, 30, lambda r: [(0, 0, I["brown1"] if r.random() < 0.7 else I["brown3"])])
    scatter(t, rnd, 5, lambda r: [(0, 0, I["green2"]), (1, -1, I["green3"])])
    return finish(t)


def tile_cobble(spec):
    rnd = K.rng(spec["seed"])
    cx, cy = uv()
    n = 4
    u, v = cx * n, cy * n
    row = np.floor(v).astype(int)
    u2 = u + np.where(row % 2 == 1, 0.5, 0.0)
    fu, fv = frac(u2), frac(v)
    sid = (np.floor(u2).astype(int) % n) * 7 + (row % n) * 3
    d = ((fu - 0.5) / 0.46) ** 2 + ((fv - 0.5) / 0.44) ** 2
    t = K.canvas(W, H)
    dm = K.diamond()
    t[dm] = I["brown1"]
    stone = dm & (d < 1)
    base = np.where(sid % 3 == 0, I["grey3"], I["grey2"])
    t[stone] = base[stone]
    t[stone & (fu < 0.32) & (d < 0.8)] = I["grey4"]
    t[stone & ((fu > 0.7) | (fv > 0.78))] = I["grey1"]
    t[dm & (d >= 1) & (d < 1.25) & (fu > 0.5)] = I["brown0"]
    scatter(t, rnd, 6, lambda r: [(0, 0, I["green2"])])
    return finish(t)


def slab_floor(seed, rows, cols, shades, joint, lit, wear, chips=5):
    rnd = K.rng(seed)
    cx, cy = uv()
    d = K.diamond()
    t = K.canvas(W, H)
    rowi = np.floor(cy * rows).astype(int) % rows
    off = np.where(rowi % 2 == 1, 0.5 / cols, 0.0)
    stone_id = (np.floor((cx + off) * cols).astype(int) % cols) + cols * rowi
    noise = K.periodic_noise(seed, cx, cy, terms=6, max_freq=4)
    th = K.BAYER4_tile(d.shape)
    for s in range(rows * cols):
        m = d & (stone_id == s)
        t[m] = shades[(s * 5 + 1) % len(shades)]
        t[m & ((noise * 0.5 + 0.5) * 0.55 > th + 0.2)] = wear
    jm = np.zeros_like(d)
    for dx, dy in [(1, 0), (0, 1)]:
        jm |= (K.shift(stone_id, -dx, -dy) != stone_id)
    jm &= d
    lm = np.zeros_like(d)
    for dx, dy in [(-1, 0), (0, -1)]:
        lm |= (K.shift(stone_id, -dx, -dy) != stone_id)
    lm &= d & ~jm
    t[lm] = lit
    t[jm] = joint
    scatter(t, rnd, chips, lambda r: [(0, 0, joint), (1, 0, lit)])
    return t


def tile_andesite(spec):
    """Dark andesite slabs of the sanctuary terrace, bigger and darker than tile_stone."""
    t = slab_floor(spec["seed"], 2, 2, [I["grey1"], I["grey2"], I["grey1"]], I["grey0"], I["grey3"], I["grey1"])
    return finish(t)


def tile_sun_disc(spec):
    """The Andesite Sun: a ring of carved wedges round a disc, on andesite."""
    t = tile_andesite(spec)
    ys, xs = np.mgrid[0:H, 0:W]
    dx, dy = (xs - 31.5) / 26.0, (ys - 15.5) / 13.0
    r = np.sqrt(dx * dx + dy * dy)
    ang = np.arctan2(dy, dx)
    d = K.diamond()
    ring = d & (r > 0.62) & (r < 0.98)
    wedge = ring & (np.cos(ang * 10) > 0.15)
    t[ring] = I["grey1"]
    t[wedge] = I["grey3"]
    t[wedge & (dy < -0.2) & (dx < 0.4)] = I["grey4"]
    t[d & (np.abs(r - 0.6) < 0.05)] = I["grey0"]
    t[d & (r < 0.36)] = I["grey3"]
    t[d & (r < 0.36) & (dx + dy < -0.25)] = I["grey4"]
    t[d & (np.abs(r - 0.37) < 0.05)] = I["grey0"]
    return finish(t)


def planks(seed, n, cols, seam, light, along_x=False, ends=True):
    rnd = K.rng(seed)
    cx, cy = uv()
    a, b = (cy, cx) if along_x else (cx, cy)
    k = a * n
    pid = np.floor(k).astype(int) % n
    t = K.canvas(W, H)
    d = K.diamond()
    for p in range(n):
        t[d & (pid == p)] = cols[(p * 3 + 1) % len(cols)]
    fk = frac(k)
    t[d & (fk < 1.0 / (64 / n / 2))] = light
    t[d & (fk > 1 - 1.4 / (64 / n / 2))] = seam
    if ends:
        endpos = frac(b + pid * 0.37)
        t[d & (endpos < 0.03)] = seam
        t[d & (np.abs(endpos - 0.5) < 0.015) & (fk > 0.3) & (fk < 0.4)] = I["outline"]  # nails
    scatter(t, rnd, 10, lambda r: [(0, 0, cols[0]), (1, 0, cols[0])])
    return t


def tile_wood_floor(spec):
    return finish(planks(spec["seed"], 4, [I["brown2"], I["brown2"], I["brown1"]], I["brown0"], I["brown3"]))


def tile_door(spec):
    """A threshold: worn planks across the doorway, a stone sill on each side, a straw mat."""
    t = planks(spec["seed"], 4, [I["brown1"], I["brown2"]], I["brown0"], I["brown3"], along_x=True, ends=False)
    cx, cy = uv()
    d = K.diamond()
    sill = d & ((cx < 0.14) | (cx > 0.86))
    t[sill] = I["grey3"]
    t[sill & (cx > 0.86)] = I["grey2"]
    t[d & (np.abs(cx - 0.14) < 0.02)] = I["grey1"]
    t[d & (np.abs(cx - 0.86) < 0.02)] = I["grey4"]
    mat = d & (cx > 0.3) & (cx < 0.7) & (cy > 0.25) & (cy < 0.75)
    t[mat] = I["ochre"]
    t[mat & (((np.floor(cy * 40)).astype(int) % 2) == 0)] = I["straw"]
    t[mat & ((np.abs(cx - 0.3) < 0.02) | (np.abs(cy - 0.75) < 0.02))] = I["brown2"]
    return finish(t)


def water(seed, deep, mid, light, hi, count=10):
    rnd = K.rng(seed)
    t, d = noise_ground(seed, [deep, mid, mid], [0.3, 0.9], f1=6, f2=4, amp2=0.6)

    def ripple(r):
        n = int(r.integers(3, 6))
        return [(k, 0, light) for k in range(n)] + [(1, -1, hi)]
    scatter(t, rnd, count, ripple)
    scatter(t, rnd, 6, lambda r: [(0, 0, hi)])
    return finish(t)


def tile_water(spec):
    return water(spec["seed"], I["blue0"], I["blue1"], I["blue2"], I["white"])


def tile_cave_water(spec):
    return water(spec["seed"], I["outline"], I["blue0"], I["blue1"], I["blue2"], count=6)


def tile_bridge(spec):
    """Planks across a river: dark water in the gaps, a log beam along each side."""
    t = planks(spec["seed"], 6, [I["brown2"], I["brown1"], I["brown2"]], I["blue0"], I["brown3"], along_x=True, ends=False)
    cx, cy = uv()
    d = K.diamond()
    beam = d & ((cx < 0.1) | (cx > 0.9))
    t[beam] = I["brown1"]
    t[d & (cx < 0.05)] = I["brown3"]
    t[d & (cx > 0.95)] = I["brown0"]
    return finish(t)


def tile_flowers(spec):
    rnd = K.rng(spec["seed"] + 7)
    t = GT.tile_grass({"seed": spec["seed"]})

    def cluster(r):
        col = [I["red1"], I["straw"], I["white"], I["blue2"], I["ochre"]][int(r.integers(0, 5))]
        return [(0, 0, col), (2, 0, col), (1, -1, col), (1, 1, I["green1"]), (1, 0, I["straw"] if col != I["straw"] else I["ochre"])]
    scatter(t, rnd, 14, cluster)
    return finish(t)


def tile_cave_floor(spec):
    rnd = K.rng(spec["seed"])
    t, d = noise_ground(spec["seed"], [I["grey0"], I["grey1"], I["brown0"]], [0.35, 0.82], f1=6, f2=6, amp2=0.8)
    scatter(t, rnd, 10, lambda r: [(0, 0, I["grey2"]), (1, 0, I["grey1"]), (1, 1, I["outline"])])
    scatter(t, rnd, 20, lambda r: [(0, 0, I["outline"] if r.random() < 0.5 else I["grey2"])])

    def crack(r):
        n = int(r.integers(3, 7))
        return [(k, (k // 2) * (1 if r.random() < 0.5 else -1), I["outline"]) for k in range(n)]
    scatter(t, rnd, 3, crack)
    return finish(t)


def tile_bones(spec):
    """Cave floor with old bones. A skull with a slightly embarrassed grin."""
    t = tile_cave_floor(spec)
    rnd = K.rng(spec["seed"] + 3)

    def bone(r):
        horiz = r.random() < 0.5
        pts = [(k, 0) if horiz else (k, k // 2) for k in range(5)]
        out = [(x, y, I["grey4"]) for x, y in pts] + [(x, y + 1, I["grey2"]) for x, y in pts]
        out += [(-1, -1, I["grey4"]), (-1, 1, I["grey4"]), (5, -1 + pts[-1][1], I["grey4"]), (5, 1 + pts[-1][1], I["grey4"])]
        return out
    scatter(t, rnd, 4, bone)
    # skull near the middle
    for x, y, col in [(30, 13, "grey4"), (31, 13, "grey4"), (32, 13, "grey4"), (29, 14, "grey4"), (30, 14, "outline"), (31, 14, "grey4"),
                      (32, 14, "outline"), (33, 14, "grey3"), (29, 15, "grey4"), (30, 15, "grey4"), (31, 15, "grey3"), (32, 15, "grey4"),
                      (33, 15, "grey2"), (30, 16, "grey3"), (31, 16, "outline"), (32, 16, "grey2"), (30, 17, "grey1"), (31, 17, "grey1"), (32, 17, "grey1")]:
        t[y, x] = I[col]
    return finish(t)


def tile_mud(spec):
    rnd = K.rng(spec["seed"])
    t, d = noise_ground(spec["seed"], [I["brown0"], I["brown1"], I["brown1"]], [0.4, 0.9], f1=6, f2=5, amp2=0.7)

    def puddle(r):
        return [(0, 0, I["grey0"]), (1, 0, I["grey0"]), (2, 0, I["grey0"]), (1, 1, I["grey0"]), (0, 0, I["grey2"])][1:] + [(0, 0, I["grey3"])]
    scatter(t, rnd, 5, puddle)
    scatter(t, rnd, 12, lambda r: [(0, 0, I["brown2"]), (1, 0, I["brown0"])])

    def track(r):  # boot prints
        return [(0, 0, I["outline"]), (1, 0, I["outline"]), (0, 1, I["brown0"]), (1, 1, I["brown0"]), (4, -2, I["outline"]), (5, -2, I["outline"])]
    scatter(t, rnd, 3, track)
    return finish(t)


def tile_scorched_earth(spec):
    rnd = K.rng(spec["seed"])
    t, d = noise_ground(spec["seed"], [I["outline"], I["grey0"], I["brown0"]], [0.3, 0.78], f1=6, f2=6, amp2=0.9)
    scatter(t, rnd, 16, lambda r: [(0, 0, I["grey2"]), (1, 0, I["grey1"])])
    scatter(t, rnd, 5, lambda r: [(0, 0, I["ochre"]), (1, 0, I["red1"])])
    scatter(t, rnd, 4, lambda r: [(0, 0, I["green1"]), (0, -1, I["green2"])])
    return finish(t)


def tile_scree(spec):
    rnd = K.rng(spec["seed"])
    t, d = noise_ground(spec["seed"], [I["brown1"], I["grey1"], I["grey2"]], [0.3, 0.7], f1=6, f2=6, amp2=0.9)

    def stone(r):
        big = r.random() < 0.4
        out = [(0, 0, I["grey4"]), (1, 0, I["grey3"]), (0, 1, I["grey3"]), (1, 1, I["grey2"]), (2, 1, I["grey0"]), (1, 2, I["grey0"])]
        if big:
            out += [(2, 0, I["grey3"]), (2, 2, I["grey0"]), (3, 1, I["grey0"]), (0, 2, I["grey2"])]
        return out
    scatter(t, rnd, 22, stone)
    return finish(t)


def tile_snow(spec):
    rnd = K.rng(spec["seed"])
    t, d = noise_ground(spec["seed"], [I["grey4"], I["white"], I["white"]], [0.3, 0.6], f1=6, f2=4, amp2=0.6)
    scatter(t, rnd, 10, lambda r: [(0, 0, I["blue2"]), (1, 0, I["grey4"])])
    scatter(t, rnd, 4, lambda r: [(0, 0, I["grey2"]), (1, 0, I["grey3"]), (0, -1, I["white"])])
    return finish(t)


def tile_saucer_floor(spec):
    """Lobizi deck plating: 2x2 plates per cell, rivets, cyan light seams on one axis."""
    cx, cy = uv()
    d = K.diamond()
    t = K.canvas(W, H)
    fu, fv = frac(cx * 2), frac(cy * 2)
    t[d] = I["grey2"]
    t[d & ((fu + fv) < 0.5)] = I["grey3"]
    t[d & ((fu + fv) > 1.55)] = I["grey1"]
    t[d & (fu < 0.04)] = I["grey4"]
    t[d & (fv < 0.04)] = I["grey4"]
    t[d & (fu > 0.95)] = I["grey0"]
    t[d & (fv > 0.95)] = I["grey0"]
    t[d & (np.abs(frac(cx) - 0.5) < 0.012)] = I["teal"]
    t[d & (np.abs(frac(cx) - 0.5) < 0.012) & (np.abs(frac(cy * 4) - 0.5) < 0.18)] = I["cyan"]
    riv = d & (np.abs(fu - 0.2) < 0.04) & (np.abs(fv - 0.2) < 0.04)
    t[riv] = I["silk0"]
    return finish(t)


def tile_saucer_grate(spec):
    cx, cy = uv()
    d = K.diamond()
    t = K.canvas(W, H)
    t[d] = I["outline"]
    glow = K.periodic_noise(spec["seed"], cx, cy, terms=4, max_freq=2)
    t[d & (glow > 0.2)] = I["teal"]
    t[d & (glow > 0.65)] = I["cyan"]
    bars = d & (frac(cx * 8) < 0.35)
    t[bars] = I["grey2"]
    t[bars & (frac(cx * 8) < 0.12)] = I["grey3"]
    cross = d & (frac(cy * 2) < 0.08)
    t[cross] = I["grey1"]
    rim = d & ((cx < 0.04) | (cy < 0.04) | (cx > 0.96) | (cy > 0.96))
    t[rim] = I["grey3"]
    t[rim & ((cx > 0.96) | (cy > 0.96))] = I["grey1"]
    return finish(t)


def tile_operating_table(spec):
    """The vast padded top of the operating table: quilted silk, buttons, a strap now and then."""
    cx, cy = uv()
    d = K.diamond()
    t = K.canvas(W, H)
    fu, fv = frac(cx * 2), frac(cy * 2)
    q = np.abs(fu - 0.5) + np.abs(fv - 0.5)
    t[d] = I["grey4"]
    t[d & (q > 0.46)] = I["silk0"]
    t[d & (q < 0.12) & ((fu + fv) < 0.9)] = I["white"]
    t[d & (q < 0.05)] = I["teal"]
    strap = d & (np.abs(cy - 0.5) < 0.05)
    t[strap] = I["grey1"]
    t[strap & (np.abs(cy - 0.5) < 0.02)] = I["grey2"]
    t[strap & (np.abs(cx - 0.5) < 0.04)] = I["silk0"]
    return finish(t)


# ------------------------------------------------------------------ low props (ground layer)

def prop(base_name, seed, height, shapes_fn, shadow=None):
    c = on_ground(ground(base_name, seed), height)
    gx, gy = 32, height + 16                # ground centre of the cell in this canvas
    if shadow:
        contact_shadow(c, gx + 2, gy + 2, *shadow)
    put(c, shapes_fn(gx, gy))
    return c


WOOD = rr("brown1", "brown2", "brown3")
WOOD_D = rr("brown0", "brown1")
WOOD_L = rr("brown2", "brown3")


def tile_crate(spec):
    def shapes(gx, gy):
        S = box((gx, gy), 0.32, 0.32, 18, rr("brown2", "brown3"), WOOD_L, WOOD_D)
        a = iso_pt((gx, gy), -0.32, 0.32)
        b = iso_pt((gx, gy), 0.32, 0.32)
        S += [line([(a[0] + 1, a[1] - 1), (b[0] - 1, b[1] - 17)], I["brown1"]),
              line([(a[0] + 1, a[1] - 17), (b[0] - 1, b[1] - 1)], I["brown1"]),
              line([(b[0] + 2, b[1] - 9), (iso_pt((gx, gy), 0.32, -0.32)[0] - 2, iso_pt((gx, gy), 0.32, -0.32)[1] - 9)], I["brown0"])]
        return S
    return prop(spec.get("ground", "tile_dirt"), spec["seed"], 20, shapes, shadow=(16, 6))


def tile_barrel(spec):
    def shapes(gx, gy):
        S = cylinder(gx, gy, 9, 20, rr("brown0", "brown1", "brown2"), rr("brown1", "brown2", "brown3"), ry=4.5)
        for yy in (gy - 4, gy - 16):
            S.append(path([(gx - 9, yy), (gx, yy + 3.5), (gx + 9, yy)], 0.6, rr("grey1", "grey2")))
        S.append(oval(gx, gy - 20, 6, 2.6, rr("brown1", "brown2")))
        S.append(line([(gx - 4, gy - 21), (gx + 4, gy - 19)], I["brown0"]))
        return S
    return prop(spec.get("ground", "tile_cobble"), spec["seed"], 26, shapes, shadow=(12, 5))


def tile_table(spec):
    def shapes(gx, gy):
        S = []
        for a, b in ((-0.3, -0.18), (0.3, -0.18), (-0.3, 0.18), (0.3, 0.18)):
            p = iso_pt((gx, gy), a, b)
            S.append(path([p, (p[0], p[1] - 12)], 1.0, WOOD_D))
        S += box((gx, gy), 0.36, 0.24, 3, rr("brown2", "brown3"), WOOD_L, WOOD_D, z=12)
        S += [oval(gx - 6, gy - 16, 4, 2, rr("brown0", "red1")), dots([(gx - 7, gy - 17)], I["straw"]),   # a bowl of something
              path([(gx + 6, gy - 16), (gx + 6, gy - 22)], 2.2, rr("brown1", "ochre", "straw")),           # a clay jug
              dots([(gx + 7, gy - 23)], I["brown0"])]
        return S
    return prop(spec.get("ground", "tile_wood_floor"), spec["seed"], 26, shapes, shadow=(18, 6))


def tile_altar(spec):
    def shapes(gx, gy):
        S = box((gx, gy), 0.34, 0.3, 16, rr("grey2", "grey3"), rr("grey2", "grey3"), rr("grey1", "grey2"))
        S += [line([iso_pt((gx, gy), -0.34, 0.3, 6), iso_pt((gx, gy), 0.34, 0.3, 6)], I["grey1"]),
              oval(gx, gy - 18, 6, 2.6, rr("brown1", "ochre", "straw")),                          # a bronze offering bowl
              poly([(gx - 2, gy - 19), (gx, gy - 27), (gx + 2.5, gy - 19)], rr("red1", "ochre", "straw")),  # the fire
              dots([(gx, gy - 22)], I["white"])]
        return S
    return prop(spec.get("ground", "tile_andesite"), spec["seed"], 28, shapes, shadow=(18, 6))


def tile_market_stall(spec):
    def shapes(gx, gy):
        S = []
        for a, b in ((-0.36, -0.2), (0.36, -0.2), (-0.36, 0.2), (0.36, 0.2)):
            p = iso_pt((gx, gy), a, b)
            S.append(path([p, (p[0], p[1] - 26)], 0.9, WOOD_D))
        S += box((gx, gy), 0.36, 0.2, 10, rr("brown2", "brown3"), WOOD_L, WOOD_D)
        # produce: cabbages, apples, a suspicious amount of cheese
        S += [oval(gx - 8, gy - 12, 3, 2, rr("green2", "green3", "green4")), oval(gx - 2, gy - 12, 2.6, 1.8, rr("red0", "red1")),
              oval(gx + 4, gy - 12, 2.6, 1.8, rr("red0", "red1")), oval(gx + 9, gy - 11, 3, 2, rr("ochre", "straw"))]
        # striped awning, sloping toward the front
        n0, e0 = iso_pt((gx, gy), -0.44, -0.26, 30), iso_pt((gx, gy), 0.44, -0.26, 30)
        s0, w0 = iso_pt((gx, gy), 0.44, 0.3, 24), iso_pt((gx, gy), -0.44, 0.3, 24)

        def stripes(c, m):
            h, w = c.shape
            ys, xs = np.mgrid[0:h, 0:w]
            c[m & (((xs + ys * 2) // 6) % 2 == 0)] = I["straw"]
        S.append(poly([n0, e0, s0, w0], rr("red0", "red1"), post=stripes))
        S.append(line([w0, s0], I["red0"]))
        return S
    return prop(spec.get("ground", "tile_cobble"), spec["seed"], 34, shapes, shadow=(20, 6))


def tile_fence(spec):
    """Wattle fence along the cell's x axis: posts and woven withies."""
    def shapes(gx, gy):
        S = []
        a, b = iso_pt((gx, gy), -0.5, 0), iso_pt((gx, gy), 0.5, 0)
        for k in range(5):
            t = k / 4
            p = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
            S.append(path([p, (p[0], p[1] - 18)], 1.0, WOOD_D))
            S.append(dots([(p[0], p[1] - 19)], I["brown2"]))
        for yy, col in ((4, WOOD), (7, WOOD_L), (10, WOOD), (13, WOOD_L), (16, WOOD)):
            S.append(path([(a[0], a[1] - yy), (b[0], b[1] - yy)], 1.2, col))
        return S
    return prop(spec.get("ground", "tile_grass"), spec["seed"], 22, shapes)


def tile_well(spec):
    def shapes(gx, gy):
        S = cylinder(gx, gy, 13, 10, rr("grey1", "grey2", "grey3"), rr("grey2", "grey3", "grey4"), ry=6.5)
        S.append(oval(gx, gy - 10, 9.5, 4.5, rr("outline", "blue0")))
        S.append(dots([(gx + 2, gy - 9)], I["blue2"]))
        for x in (gx - 11, gx + 11):
            S.append(path([(x, gy - 8), (x, gy - 30)], 1.0, WOOD_D))
        S.append(path([(gx - 12, gy - 28), (gx + 12, gy - 28)], 1.0, WOOD))
        S.append(line([(gx + 1, gy - 28), (gx + 1, gy - 18)], I["brown3"]))
        S.append(poly([(gx - 2, gy - 18), (gx + 4, gy - 18), (gx + 3.5, gy - 14), (gx - 1.5, gy - 14)], WOOD, edge=E))   # bucket
        S.append(poly([(gx - 15, gy - 28), (gx, gy - 37), (gx + 15, gy - 28), (gx, gy - 30)], rr("brown2", "ochre", "straw")))  # little roof
        return S
    return prop(spec.get("ground", "tile_cobble"), spec["seed"], 40, shapes, shadow=(16, 7))


def tile_bush(spec):
    def shapes(gx, gy):
        leaf = rr("green1", "green2", "green3")
        S = [oval(gx - 6, gy - 7, 8, 7, leaf), oval(gx + 6, gy - 6, 8, 6.5, leaf), oval(gx, gy - 12, 9, 7.5, rr("green1", "green2", "green3", "green4"))]
        S.append(dots([(gx - 3, gy - 15), (gx + 4, gy - 13), (gx - 8, gy - 9), (gx + 9, gy - 8)], I["green4"]))
        S.append(dots([(gx + 2, gy - 6), (gx - 4, gy - 4)], I["red1"]))        # berries; do not eat
        return S
    return prop(spec.get("ground", "tile_grass"), spec["seed"], 20, shapes, shadow=(16, 6))


def tile_stump(spec):
    def shapes(gx, gy):
        S = cylinder(gx, gy, 9, 8, rr("brown0", "brown1", "brown2"), rr("brown3", "ochre", "straw"), ry=4.5)
        S += [path([(gx - 9, gy), (gx - 13, gy + 2)], 1.4, WOOD_D), path([(gx + 7, gy + 2), (gx + 11, gy + 4)], 1.4, WOOD_D)]
        S.append(Ring(gx, gy - 8, 5.5, 2.5, I["brown2"]))
        S.append(Ring(gx, gy - 8, 2.5, 1.0, I["brown2"]))
        S += [path([(gx + 2, gy - 9), (gx + 6, gy - 17)], 0.6, rr("brown1", "brown3")),       # an axe left in it
              poly([(gx + 4, gy - 18), (gx + 9, gy - 17), (gx + 8, gy - 14)], rr("grey2", "grey4"), edge=E)]
        return S
    return prop(spec.get("ground", "tile_forest_floor"), spec["seed"], 20, shapes, shadow=(13, 5))


def Ring(cx, cy, rx, ry, col):
    pts = R.circle_pts(cx, cy, rx, ry, 16)
    return R.Shape("line", pts + [pts[0]], [col])


def tile_coffin(spec):
    """Boier Duras's coffin. The lid is open a crack. He is late, not gone."""
    def shapes(gx, gy):
        S = box((gx, gy), 0.42, 0.2, 9, rr("brown1", "brown2"), WOOD, WOOD_D)
        n0, e0 = iso_pt((gx, gy), -0.46, -0.24, 13), iso_pt((gx, gy), 0.4, -0.24, 11)
        s0, w0 = iso_pt((gx, gy), 0.4, 0.2, 11), iso_pt((gx, gy), -0.46, 0.2, 13)
        S.append(poly([(n0[0] - 3, n0[1]), e0, s0, (w0[0] - 3, w0[1])], rr("brown0", "brown1", "brown2"), edge=E))  # the lid, ajar
        c0 = (gx - 3, gy - 12)
        S += [line([(c0[0] - 2, c0[1] + 1), (c0[0] + 3, c0[1] - 1.5)], I["ochre"]), line([(c0[0], c0[1] - 2), (c0[0] + 1, c0[1] + 2)], I["ochre"])]
        S += [dots([(s0[0] - 6, s0[1] + 2)], I["blood"])]                                        # two red eyes in the gap
        S += [dots([(s0[0] - 4, s0[1] + 2)], I["blood"])]
        return S
    return prop(spec.get("ground", "tile_cave_floor"), spec["seed"], 20, shapes, shadow=(20, 6))


def tile_cart(spec):
    def shapes(gx, gy):
        S = box((gx, gy), 0.4, 0.22, 7, rr("brown2", "brown3"), WOOD_L, WOOD_D, z=7)
        S += [oval(gx - 4, gy - 16, 8, 3.4, rr("ochre", "straw")), oval(gx + 5, gy - 15, 6, 3, rr("brown3", "ochre", "straw"))]  # hay
        w = iso_pt((gx, gy), -0.1, 0.26)
        S += [oval(w[0], w[1] - 5, 3.2, 5.6, rr("brown0", "brown1", "brown2")), oval(w[0], w[1] - 5, 1.2, 1.8, rr("brown0", "brown1"))]
        S.append(path([iso_pt((gx, gy), 0.4, 0, 9), iso_pt((gx, gy), 0.62, 0, 4)], 0.8, WOOD_D))   # the shafts
        return S
    return prop(spec.get("ground", "tile_road"), spec["seed"], 26, shapes, shadow=(20, 6))


def tile_milestone(spec):
    def shapes(gx, gy):
        S = cylinder(gx, gy, 4.5, 20, rr("grey2", "grey3", "grey4"), rr("grey3", "grey4"), ry=2.2)
        S += [line([(gx - 2, gy - 15), (gx + 2, gy - 15)], I["grey1"]), line([(gx - 2, gy - 12), (gx + 2, gy - 12)], I["grey1"]),
              line([(gx - 2, gy - 9), (gx + 1, gy - 9)], I["grey1"])]
        return S
    return prop(spec.get("ground", "tile_grass"), spec["seed"], 26, shapes, shadow=(8, 3))


def tile_wreck_debris(spec):
    def shapes(gx, gy):
        S = [poly([(gx - 14, gy + 2), (gx - 10, gy - 10), (gx + 2, gy - 13), (gx + 4, gy - 2)], rr("silk0", "grey4", "white"), edge=E),
             poly([(gx + 2, gy + 3), (gx + 6, gy - 8), (gx + 14, gy - 4), (gx + 12, gy + 4)], rr("grey1", "grey2", "grey3"), edge=E),
             line([(gx - 11, gy - 6), (gx + 1, gy - 9)], I["teal"]),
             dots([(gx - 8, gy - 7), (gx - 4, gy - 8)], I["cyan"]),
             path([(gx + 7, gy - 7), (gx + 9, gy - 15), (gx + 12, gy - 16)], 0.6, rr("grey1", "grey3")),
             dots([(gx + 12, gy - 17), (gx + 13, gy - 16)], I["acid"]), dots([(gx + 11, gy - 18)], I["white"])]
        return S
    return prop(spec.get("ground", "tile_scorched_earth"), spec["seed"], 20, shapes, shadow=(16, 5))


def rock_shapes(gx, gy, s=1.0, ramp=None):
    ramp = ramp or rr("grey1", "grey2", "grey3", "grey4")
    k = s
    return [poly([(gx - 13 * k, gy + 2), (gx - 12 * k, gy - 8 * k), (gx - 5 * k, gy - 15 * k), (gx + 4 * k, gy - 14 * k),
                  (gx + 12 * k, gy - 7 * k), (gx + 13 * k, gy + 1), (gx + 4 * k, gy + 5), (gx - 6 * k, gy + 5)], ramp),
            line([(gx - 4 * k, gy - 13 * k), (gx - 1 * k, gy - 5 * k), (gx + 6 * k, gy - 2 * k)], ramp[0]),
            dots([(gx - 7 * k, gy - 9 * k), (gx - 6 * k, gy - 10 * k)], ramp[-1])]


def tile_boulder(spec):
    return prop(spec.get("ground", "tile_scree"), spec["seed"], 22, lambda gx, gy: rock_shapes(gx, gy, 1.25), shadow=(18, 6))


def tile_console(spec):
    """A Lobizi console: a slanted desk of buttons nobody is allowed to press."""
    def shapes(gx, gy):
        S = box((gx, gy), 0.34, 0.22, 12, rr("grey2", "grey3"), rr("grey2", "grey3"), rr("grey1", "grey2"))
        n0, e0 = iso_pt((gx, gy), -0.34, -0.22, 22), iso_pt((gx, gy), 0.34, -0.22, 22)
        s0, w0 = iso_pt((gx, gy), 0.34, 0.06, 12), iso_pt((gx, gy), -0.34, 0.06, 12)
        S.append(poly([n0, e0, s0, w0], rr("grey0", "grey1"), edge=E))
        for k, col in enumerate(("magenta", "acid", "cyan", "magenta", "acid", "cyan")):
            u, v = -0.24 + 0.1 * k, -0.1 + 0.08 * (k % 2)
            S.append(dots([iso_pt((gx, gy), u, v, 18)], I[col]))
        # a screen on top showing a small diagram of you
        S += box((gx, gy), 0.16, 0.05, 10, rr("grey1", "grey2"), rr("teal", "cyan"), rr("grey0", "grey1"), z=22, edge=False)
        return S
    return prop(spec.get("ground", "tile_saucer_floor"), spec["seed"], 34, shapes, shadow=(16, 6))


# ------------------------------------------------------------------ tall tiles

def tile_murus_dacicus(spec):
    return GT.tile_wall({**spec, "height": spec.get("height", 48)})


def tile_timber_wall(spec):
    """A palisade of upright logs, lashed with two rails; the top shows the sawn log ends."""
    hgt = spec.get("height", 48)
    rnd = K.rng(spec["seed"])

    def face(t, m, u, v, lit):
        k = u % 6
        a, b, c0 = (I["brown2"], I["brown3"], I["brown1"]) if lit else (I["brown1"], I["brown2"], I["brown0"])
        t[m] = a
        t[m & (k <= 1)] = b
        t[m & (k == 5)] = c0
        t[m & (k == 5) & (v < 3)] = K.T if False else c0
        rail = m & (((v >= 10) & (v <= 12)) | ((v >= 32) & (v <= 34)))
        t[rail] = I["ochre"] if lit else I["brown2"]
        t[rail & ((v == 12) | (v == 34))] = I["brown0"]
        t[m & (v >= hgt - 3)] = I["brown0"]

    cx, cy = uv()
    tt = K.canvas(W, H)
    dm = K.diamond()
    fu, fv = frac(cx * 5), frac(cy * 5)
    d = (fu - 0.5) ** 2 + (fv - 0.5) ** 2
    tt[dm] = I["brown0"]
    tt[dm & (d < 0.2)] = I["brown3"]
    tt[dm & (d < 0.2) & (fu + fv > 1.15)] = I["brown2"]
    tt[dm & (np.abs(d - 0.07) < 0.02)] = I["brown2"]
    tt[dm & (d < 0.012)] = I["ochre"]
    tt[~dm] = K.T
    return wall_tile(hgt, face, tt, rim=False)


def tile_house(spec):
    """Wattle and daub under thatch. Joined houses read as one roof: the top has no rim."""
    hgt = spec.get("height", 44)
    rnd = K.rng(spec["seed"])
    eave = 14

    def face(t, m, u, v, lit):
        thatch = v < eave
        t[m & thatch] = I["ochre"] if lit else I["brown2"]
        t[m & thatch & (((u + v) % 3) == 0)] = I["straw"] if lit else I["brown3"]
        t[m & thatch & (v == eave - 1)] = I["brown1"] if lit else I["brown0"]
        wall = m & ~thatch
        t[wall] = I["straw"] if lit else I["brown3"]
        t[wall & (((u * 7 + v * 3) % 23) == 0)] = I["brown3"] if lit else I["brown2"]
        # timber frame: posts every 16 px, a sill beam at the bottom
        t[wall & ((u % 16) < 2)] = I["brown1"] if lit else I["brown0"]
        t[wall & (v >= hgt - 4)] = I["brown1"] if lit else I["brown0"]
        # small shuttered window
        win = wall & ((u % 32) >= 8) & ((u % 32) <= 12) & (v >= eave + 6) & (v <= eave + 11)
        t[win] = I["brown0"] if lit else I["outline"]
        t[win & (v == eave + 6)] = I["brown2"]

    cx, cy = uv()
    tt = K.canvas(W, H)
    dm = K.diamond()
    tt[dm] = I["ochre"]
    th = frac(cx * 8 + 0.2 * np.sin(cy * 6.283 * 3))
    tt[dm & (th < 0.3)] = I["straw"]
    tt[dm & (th > 0.8)] = I["brown2"]
    scatter(tt, rnd, 12, lambda r: [(0, 0, I["brown3"]), (1, 1, I["brown2"])])
    tt[~dm] = K.T
    return wall_tile(hgt, face, tt, rim=False)


def tile_cave_wall(spec):
    hgt = spec.get("height", 40)
    rnd = K.rng(spec["seed"])
    noise_cache = {}

    def face(t, m, u, v, lit):
        ys, xs = np.mgrid[0:t.shape[0], 0:W]
        n = np.sin(u * 0.7 + v * 0.31) + np.sin(u * 0.23 - v * 0.9) + 0.6 * np.sin(u * 1.7 + v * 1.3)
        cols = (I["grey1"], I["grey2"], I["brown1"]) if lit else (I["grey0"], I["grey1"], I["brown0"])
        t[m] = cols[0]
        t[m & (n > 0.6)] = cols[1]
        t[m & (n < -1.2)] = cols[2]
        t[m & (np.abs(n - 0.6) < 0.08)] = I["outline"]
        t[m & (v < 2)] = I["grey2"] if lit else I["grey1"]

    tt, d = noise_ground(spec["seed"], [I["outline"], I["outline"], I["grey0"]], [0.5, 0.88], f1=6, f2=6, amp2=0.8)
    scatter(tt, rnd, 6, lambda r: [(0, 0, I["grey1"]), (1, 0, I["grey0"])])
    tt[~d] = K.T
    return wall_tile(hgt, face, tt, rim=False)


def tile_cliff(spec):
    hgt = spec.get("height", 48)
    rnd = K.rng(spec["seed"])

    def face(t, m, u, v, lit):
        n = np.sin(u * 0.45 + v * 0.12) + np.sin(u * 0.17 - v * 0.6) + 0.5 * np.sin(u * 1.3 + v * 0.9)
        cols = (I["grey2"], I["grey3"], I["brown2"]) if lit else (I["grey1"], I["grey2"], I["brown1"])
        t[m] = cols[0]
        t[m & (n > 0.5)] = cols[1]
        t[m & (n < -1.1)] = cols[2]
        strata = m & ((v % 11) == 0)
        t[strata] = I["grey1"] if lit else I["grey0"]
        t[m & (v < 3)] = I["white"] if lit else I["grey4"]   # snow on the lip

    tt = tile_snow({"seed": spec["seed"]})
    scatter(tt, rnd, 10, lambda r: [(0, 0, I["grey3"]), (1, 0, I["grey2"]), (0, 1, I["grey2"])])
    tt[~K.diamond()] = K.T
    return wall_tile(hgt, face, tt, rim=True, rim_cols=("white", "grey3"))


def tile_saucer_wall(spec):
    hgt = spec.get("height", 48)

    def face(t, m, u, v, lit):
        a, b, cc = (I["grey3"], I["grey4"], I["grey2"]) if lit else (I["grey1"], I["grey2"], I["grey0"])
        t[m] = a
        t[m & ((v % 16) < 2)] = b
        t[m & ((v % 16) == 15)] = cc
        t[m & ((u % 32) == 0)] = cc
        t[m & ((u % 32) == 1)] = b
        strip = m & (v >= 20) & (v <= 22)
        t[strip] = I["teal"]
        t[strip & (v == 21) & ((u % 6) < 3)] = I["cyan"]
        t[m & ((u % 32) == 16) & (v == 8)] = I["magenta"]
        t[m & ((u % 32) == 18) & (v == 8)] = I["acid"]
        t[m & (v >= hgt - 2)] = I["grey0"]

    cx, cy = uv()
    tt = K.canvas(W, H)
    dm = K.diamond()
    tt[dm] = I["grey2"]
    tt[dm & (cx + cy < 0.9)] = I["grey3"]
    tt[dm & (np.abs(frac(cx) - 0.5) < 0.015)] = I["teal"]
    tt[~dm] = K.T
    return wall_tile(hgt, face, tt, rim=True, rim_cols=("white", "grey3"))


def tile_andesite_pillar(spec):
    """The low andesite drums of the sanctuaries, in rows."""
    hgt = spec.get("height", 30)
    c = on_ground(ground("tile_andesite", spec["seed"]), hgt)
    gx, gy = 32, hgt + 16
    contact_shadow(c, gx + 2, gy + 2, 16, 6)
    S = cylinder(gx, gy, 13, 20, rr("grey0", "grey1", "grey2"), rr("grey1", "grey2", "grey3"), ry=6.5)
    S.append(Ring(gx, gy - 20, 9, 4, I["grey1"]))
    S.append(line([(gx - 12, gy - 6), (gx, gy - 1), (gx + 12, gy - 6)], I["grey0"]))
    return put(c, S)


def tile_limestone_pillar(spec):
    """Tall limestone column drums, pale against the andesite."""
    hgt = spec.get("height", 64)
    c = on_ground(ground("tile_andesite", spec["seed"]), hgt)
    gx, gy = 32, hgt + 16
    contact_shadow(c, gx + 2, gy + 2, 14, 6)
    S = cylinder(gx, gy, 9, 56, rr("grey2", "grey3", "grey4"), rr("grey3", "grey4", "white"), ry=4.5)
    for yy in (gy - 18, gy - 37):
        S.append(path([(gx - 9, yy), (gx, yy + 4), (gx + 9, yy)], 0.4, [I["grey2"]]))
    S += cylinder(gx, gy - 56, 11, 4, rr("grey2", "grey3", "grey4"), rr("grey3", "grey4", "white"), ry=5)
    return put(c, S)


def tree_shapes(gx, gy, s=1.0, seed=0, autumn=False):
    rnd = K.rng(seed)
    leaf = rr("green0", "green1", "green2", "green3")
    leaf_hi = rr("green1", "green2", "green3", "green4")
    S = [path([(gx, gy), (gx, gy - 26 * s)], 3.6 * s, rr("brown0", "brown1", "brown2")),
         path([(gx - 1, gy - 18 * s), (gx - 8 * s, gy - 28 * s)], 1.6 * s, rr("brown0", "brown1")),
         path([(gx + 2, gy - 22 * s), (gx + 9 * s, gy - 30 * s)], 1.6 * s, rr("brown0", "brown1")),
         path([(gx - 4, gy + 1), (gx - 8, gy + 3)], 1.4, rr("brown0", "brown1")),
         path([(gx + 3, gy + 1), (gx + 7, gy + 3)], 1.4, rr("brown0", "brown1"))]
    blobs = [(-12, -34, 12, 10), (12, -36, 12, 10), (0, -30, 14, 10), (-6, -48, 13, 11), (8, -50, 12, 10), (0, -60, 11, 9)]
    for k, (dx, dy, rx, ry) in enumerate(blobs):
        jx, jy = rnd.uniform(-1.5, 1.5), rnd.uniform(-1.5, 1.5)
        S.append(oval(gx + (dx + jx) * s, gy + (dy + jy) * s, rx * s, ry * s, leaf_hi if k >= 3 else leaf, edge=E if k in (2, 3, 4) else None))
    for _ in range(14):
        x, y = gx + rnd.uniform(-18, 14) * s, gy + rnd.uniform(-64, -32) * s
        S.append(dots([(x, y), (x + 1, y)], I["green4"]))
    for _ in range(8):
        x, y = gx + rnd.uniform(-14, 18) * s, gy + rnd.uniform(-44, -26) * s
        S.append(dots([(x, y)], I["green0"]))
    return S


def tile_tree(spec):
    hgt = spec.get("height", 64)
    c = on_ground(ground("tile_forest_floor", spec["seed"]), hgt)
    gx, gy = 32, hgt + 16
    contact_shadow(c, gx + 3, gy + 2, 20, 7)
    return put(c, tree_shapes(gx, gy, 1.0, spec["seed"]))


def tile_rock(spec):
    hgt = spec.get("height", 32)
    c = on_ground(ground("tile_forest_floor", spec["seed"]), hgt)
    gx, gy = 32, hgt + 16
    contact_shadow(c, gx + 3, gy + 2, 22, 7)
    S = rock_shapes(gx + 4, gy + 1, 1.2) + rock_shapes(gx - 5, gy - 2, 1.75)
    S.append(dots([(gx - 14, gy - 10), (gx - 13, gy - 11), (gx - 12, gy - 10)], I["green3"]))   # moss
    return put(c, S)


def tile_stalagmite(spec):
    hgt = spec.get("height", 40)
    c = on_ground(ground("tile_cave_floor", spec["seed"]), hgt)
    gx, gy = 32, hgt + 16
    contact_shadow(c, gx + 2, gy + 2, 14, 5)
    ramp = rr("grey0", "grey1", "grey2", "grey3")
    S = [poly([(gx - 10, gy + 2), (gx - 3, gy - 34), (gx + 1, gy - 38), (gx + 10, gy + 2), (gx, gy + 5)], ramp),
         poly([(gx + 6, gy + 3), (gx + 11, gy - 14), (gx + 15, gy + 3)], ramp),
         poly([(gx - 15, gy + 3), (gx - 12, gy - 10), (gx - 8, gy + 3)], ramp),
         line([(gx - 2, gy - 30), (gx - 4, gy - 10)], I["grey3"]), dots([(gx, gy - 36)], I["blue2"])]   # a drip
    return put(c, S)


def tile_wreck_hull(spec):
    """A slab of crashed saucer: curved hull plates, a porthole, lights still blinking out of spite."""
    hgt = spec.get("height", 44)
    c = on_ground(ground("tile_scorched_earth", spec["seed"]), hgt)
    gx, gy = 32, hgt + 16
    contact_shadow(c, gx + 2, gy + 2, 28, 8)

    def plates(cv, m):
        h, w = cv.shape
        ys, xs = np.mgrid[0:h, 0:w]
        cv[m & (((xs + ys // 2) % 12) == 0)] = I["silk0"]
    S = [poly([(gx - 28, gy + 2), (gx - 26, gy - 20), (gx - 14, gy - 38), (gx + 4, gy - 44), (gx + 22, gy - 36), (gx + 28, gy - 16),
               (gx + 26, gy + 4), (gx, gy + 12)], rr("silk0", "grey4", "white"), post=plates, dither=True),
         path([(gx - 27, gy - 8), (gx - 8, gy - 2), (gx + 14, gy - 4), (gx + 27, gy - 12)], 1.4, rr("teal", "cyan")),
         oval(gx - 2, gy - 22, 6, 5, rr("grey1", "grey2"), edge=E), oval(gx - 2, gy - 22, 4.2, 3.4, rr("teal", "cyan")),
         dots([(gx - 4, gy - 24)], I["white"]),
         dots([(gx - 18, gy - 6), (gx + 6, gy - 3), (gx + 20, gy - 9)], I["magenta"]),
         poly([(gx + 10, gy - 40), (gx + 14, gy - 50), (gx + 17, gy - 39)], rr("grey1", "grey3")),   # snapped antenna
         path([(gx - 26, gy - 18), (gx - 32, gy - 22)], 0.8, rr("grey1", "grey2")),
         dots([(gx + 18, gy - 26), (gx + 19, gy - 27)], I["outline"])]
    return put(c, S)


def tile_specimen_tank(spec):
    """A glass tank of glowing fluid with a very surprised cow in it."""
    hgt = spec.get("height", 56)
    c = on_ground(ground("tile_saucer_floor", spec["seed"]), hgt)
    gx, gy = 32, hgt + 16
    contact_shadow(c, gx + 2, gy + 2, 16, 6)
    S = cylinder(gx, gy, 13, 6, rr("grey1", "grey2", "grey3"), rr("grey2", "grey3"), ry=6)
    S += cylinder(gx, gy - 6, 11, 40, rr("teal", "cyan"), rr("teal", "cyan"), ry=5.5, light=(-1, 0))
    # the cow: white, black spots, legs out, deeply unbothered
    cy = gy - 26
    S += [oval(gx, cy, 6, 3.6, rr("grey4", "white")), oval(gx + 6, cy - 2, 2.6, 2.2, rr("grey4", "white")),
          dots([(gx - 2, cy - 1), (gx + 2, cy + 1), (gx - 4, cy + 1)], E), dots([(gx + 7, cy - 2)], E),
          dots([(gx + 8, cy - 1)], I["skin1"]),
          line([(gx - 4, cy + 3), (gx - 5, cy + 6)], I["grey3"]), line([(gx + 3, cy + 3), (gx + 4, cy + 6)], I["grey3"])]
    S += [dots([(gx - 6, gy - 14), (gx - 5, gy - 34), (gx + 5, gy - 40), (gx + 7, gy - 20)], I["white"])]  # bubbles
    S += [line([(gx - 9, gy - 44), (gx - 9, gy - 10)], I["white"])]                                       # glass glint
    S += cylinder(gx, gy - 46, 12, 5, rr("grey1", "grey2", "grey3"), rr("grey2", "grey3", "grey4"), ry=5.8)
    S += [dots([(gx - 4, gy - 49)], I["magenta"]), dots([(gx + 3, gy - 49)], I["acid"])]
    return put(c, S)


# ------------------------------------------------------------------ world-map terrain

def tile_plains(spec):
    rnd = K.rng(spec["seed"])
    t, d = noise_ground(spec["seed"], [I["green2"], I["green3"], I["green4"]], [0.3, 0.82], f1=6, f2=5, amp2=0.8)
    scatter(t, rnd, 10, lambda r: [(0, 0, I["green4"]), (1, -1, I["straw"])])
    scatter(t, rnd, 6, lambda r: [(0, 0, I["green1"]), (1, 0, I["green1"])])
    return finish(t)


def tile_river(spec):
    return water(spec["seed"], I["blue0"], I["blue1"], I["blue2"], I["white"], count=14)


def tile_forest(spec):
    """World map forest: a clump of small trees on one cell (tall, 64x64)."""
    hgt = 32
    c = on_ground(ground("tile_forest_floor", spec["seed"]), hgt)
    gx, gy = 32, hgt + 16
    S = []
    for k, (dx, dy) in enumerate(((-14, -2), (12, -3), (0, -8), (-4, 6), (14, 6))):
        S += small_pine(gx + dx, gy + dy, 0.9 if k != 2 else 1.1)
    return put(c, S)


def small_pine(x, y, s):
    return [path([(x, y), (x, y - 4 * s)], 1.0, rr("brown0", "brown1")),
            poly([(x - 8 * s, y - 3 * s), (x, y - 22 * s), (x + 8 * s, y - 3 * s)], rr("green0", "green1", "green2", "green3")),
            poly([(x - 6 * s, y - 11 * s), (x, y - 26 * s), (x + 6 * s, y - 11 * s)], rr("green1", "green2", "green3", "green4"))]


def tile_mountain(spec):
    hgt = 40
    c = on_ground(ground("tile_scree", spec["seed"]), hgt)
    gx, gy = 32, hgt + 16
    ramp = rr("grey1", "grey2", "grey3", "grey4")
    S = [poly([(gx - 30, gy + 2), (gx - 6, gy - 40), (gx + 2, gy - 34), (gx + 8, gy - 38), (gx + 30, gy + 2), (gx, gy + 14)], ramp),
         poly([(gx - 11, gy - 30), (gx - 6, gy - 40), (gx + 2, gy - 34), (gx + 8, gy - 38), (gx + 13, gy - 29), (gx + 6, gy - 30), (gx, gy - 26), (gx - 5, gy - 30)], rr("grey4", "white")),
         line([(gx - 6, gy - 38), (gx - 2, gy - 18), (gx + 4, gy - 6)], I["grey1"])]
    return put(c, S)


FLAT = {
    "tile_dirt": tile_dirt, "tile_cobble": tile_cobble, "tile_andesite": tile_andesite, "tile_sun_disc": tile_sun_disc,
    "tile_wood_floor": tile_wood_floor, "tile_door": tile_door, "tile_water": tile_water, "tile_bridge": tile_bridge,
    "tile_flowers": tile_flowers, "tile_cave_floor": tile_cave_floor, "tile_bones": tile_bones, "tile_cave_water": tile_cave_water,
    "tile_mud": tile_mud, "tile_scorched_earth": tile_scorched_earth, "tile_scree": tile_scree, "tile_snow": tile_snow,
    "tile_saucer_floor": tile_saucer_floor, "tile_saucer_grate": tile_saucer_grate, "tile_operating_table": tile_operating_table,
    "tile_plains": tile_plains, "tile_river": tile_river,
}
PROPS = {
    "tile_crate": tile_crate, "tile_barrel": tile_barrel, "tile_table": tile_table, "tile_altar": tile_altar,
    "tile_market_stall": tile_market_stall, "tile_fence": tile_fence, "tile_well": tile_well, "tile_bush": tile_bush,
    "tile_stump": tile_stump, "tile_coffin": tile_coffin, "tile_cart": tile_cart, "tile_milestone": tile_milestone,
    "tile_wreck_debris": tile_wreck_debris, "tile_boulder": tile_boulder, "tile_console": tile_console,
}
TALL = {
    "tile_murus_dacicus": tile_murus_dacicus, "tile_timber_wall": tile_timber_wall, "tile_house": tile_house,
    "tile_cave_wall": tile_cave_wall, "tile_cliff": tile_cliff, "tile_saucer_wall": tile_saucer_wall,
    "tile_andesite_pillar": tile_andesite_pillar, "tile_limestone_pillar": tile_limestone_pillar, "tile_tree": tile_tree,
    "tile_rock": tile_rock, "tile_stalagmite": tile_stalagmite, "tile_wreck_hull": tile_wreck_hull,
    "tile_specimen_tank": tile_specimen_tank, "tile_forest": tile_forest, "tile_mountain": tile_mountain,
}
GENERATORS = {**FLAT, **PROPS, **TALL}

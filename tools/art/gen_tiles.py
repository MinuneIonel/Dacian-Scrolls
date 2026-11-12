"""Ground tiles (64x32 diamonds) and tall tiles (walls). Light from the top-left."""
import numpy as np

import kit as K
import palette as P

I = P.IDX
W, H = K.TILE_W, K.TILE_H


def _scatter(t, rnd, count, draw):
    """Place `count` small features at random points; each pixel wraps on the lattice so tiles stay seamless."""
    for _ in range(count):
        x, y = int(rnd.integers(0, W)), int(rnd.integers(0, H))
        for dx, dy, col in draw(rnd):
            wx, wy = K.lattice_wrap(x + dx, y + dy)
            if 0 <= wy < H and 0 <= wx < W:
                t[wy, wx] = col


def _base(seed, levels, cuts, f1=6, f2=3, amp2=0.5):
    """Dithered multi-level noise field over the diamond."""
    cx, cy = K.cell_uv()
    n = K.periodic_noise(seed, cx, cy, terms=f1, max_freq=2) + amp2 * K.periodic_noise(seed + 1, cx, cy, terms=f2, max_freq=5)
    n = (n - n.min()) / (n.max() - n.min() + 1e-9)
    th = K.BAYER4_tile(n.shape)
    t = K.canvas(W, H)
    d = K.diamond()
    lvl = np.zeros(n.shape, int)
    for c in cuts:
        # dither only in a narrow band around each cut
        lvl += (n + (th - 0.5) * 0.10) > c
    for k, col in enumerate(levels):
        t[d & (lvl == k)] = col
    return t, d


def tile_grass(spec):
    rnd = K.rng(spec["seed"])
    t, d = _base(spec["seed"], [I["green1"], I["green2"], I["green3"]], [0.12, 0.74], f1=8, f2=8, amp2=1.0)

    def tuft(r):
        # a blade pair: light tip upper-left, shadow root below right
        return [(0, 0, I["green4"]), (1, -1, I["green3"]), (0, 1, I["green2"]), (1, 1, I["green1"]), (-1, 1, I["green3"])]

    def dark(r):
        return [(0, 0, I["green1"]), (1, 0, I["green1"])]

    def flower(r):
        c = [I["straw"], I["white"], I["ochre"]][int(r.integers(0, 3))]
        return [(0, 0, c), (0, 1, I["green1"])]
    _scatter(t, rnd, 26, tuft)
    _scatter(t, rnd, 18, dark)
    _scatter(t, rnd, 3, flower)
    t[~d] = K.T
    return t


def tile_road(spec):
    rnd = K.rng(spec["seed"])
    t, d = _base(spec["seed"], [I["brown2"], I["brown3"], I["brown3"]], [0.28, 0.8])

    def pebble(r):
        return [(0, 0, I["grey3"]), (1, 0, I["grey2"]), (0, 1, I["grey2"]), (1, 1, I["brown1"]), (2, 1, I["brown2"])]

    def grit(r):
        return [(0, 0, I["brown1"])] if r.random() < 0.6 else [(0, 0, I["straw"])]

    def rut(r):
        n = int(r.integers(3, 6))
        return [(k * 2 + j, k, I["brown2"]) for k in range(n) for j in (0, 1)]
    _scatter(t, rnd, 4, rut)
    _scatter(t, rnd, 9, pebble)
    _scatter(t, rnd, 40, grit)
    t[~d] = K.T
    return t


def tile_forest_floor(spec):
    rnd = K.rng(spec["seed"])
    t, d = _base(spec["seed"], [I["green0"], I["green1"], I["green2"]], [0.25, 0.8], f1=8, f2=6, amp2=0.8)

    def leaf(r):
        c = [I["brown2"], I["ochre"], I["red0"], I["brown3"]][int(r.integers(0, 4))]
        return [(0, 0, c), (1, 0, c), (1, 1, I["green0"])]

    def moss(r):
        return [(0, 0, I["green3"]), (1, 0, I["green2"]), (0, 1, I["green2"]), (-1, 0, I["green2"])]

    def twig(r):
        n = int(r.integers(3, 6))
        return [(k, k // 2, I["brown3"] if k == 0 else I["brown2"]) for k in range(n)] + [(k, k // 2 + 1, I["green0"]) for k in range(n)]
    _scatter(t, rnd, 9, moss)
    _scatter(t, rnd, 22, leaf)
    _scatter(t, rnd, 3, twig)
    t[~d] = K.T
    return t


def tile_stone(spec):
    """Andesite paving in iso courses, like the sacred terrace at Sarmizegetusa."""
    rnd = K.rng(spec["seed"])
    cx, cy = K.cell_uv()
    d = K.diamond()
    t = K.canvas(W, H)
    rows = 3
    # stones run along cx in rows of cy; alternate rows offset by half a stone
    rowi = np.floor(cy * rows).astype(int) % rows
    off = np.where(rowi % 2 == 1, 0.25, 0.0)
    cols = 2
    u = (cx + off) * cols
    stone_id = (np.floor(u).astype(int) % cols) + cols * rowi
    shades = [I["grey2"], I["grey3"], I["grey2"], I["grey3"], I["grey2"], I["grey3"]]
    # per-stone base with a dithered blend for wear
    noise = K.periodic_noise(spec["seed"], cx, cy, terms=6, max_freq=4)
    th = K.BAYER4_tile(d.shape)
    for s in range(rows * cols):
        m = d & (stone_id == s)
        base = shades[(s * 5 + 1) % len(shades)]
        alt = I["grey2"] if base == I["grey3"] else I["grey1"]
        t[m] = base
        t[m & ((noise * 0.5 + 0.5) * 0.55 > th + 0.18)] = alt
    # joints: a pixel is a joint where the stone id changes toward the lower right (shadow) side
    joint = np.zeros_like(d)
    for dx, dy in [(1, 0), (0, 1)]:
        joint |= (K.shift(stone_id, -dx, -dy) != stone_id)
    joint &= d
    lit = np.zeros_like(d)
    for dx, dy in [(-1, 0), (0, -1)]:
        lit |= (K.shift(stone_id, -dx, -dy) != stone_id)
    lit &= d & ~joint
    t[lit] = I["grey4"]
    t[joint] = I["grey0"]
    # the diamond edge belongs to the neighbour's joint on two sides: draw the lower-right edges as joint
    # only where the lattice puts them, so the edge is not doubled
    def chip(r):
        return [(0, 0, I["grey1"]), (1, 0, I["grey4"])]
    _scatter(t, rnd, 5, chip)
    t[~d] = K.T
    return t


def tile_wall(spec):
    """Murus dacicus: limestone ashlar courses tied by timber, earth and planks on top."""
    hgt = spec.get("height", 48)
    top, left, right = K.prism(hgt)
    Ht = H + hgt
    t = K.canvas(W, Ht)
    ys, xs = np.mgrid[0:Ht, 0:W]
    # face-local coordinates: u along the face, v down from the face's top edge (2:1 stair steps)
    vL = ys - 16 - np.floor(xs / 2)
    vR = ys - 16 - np.floor((W - 1 - xs) / 2)
    beam_h = 6
    course = 10

    def face(mask, v, u, lit):
        stone = [I["grey3"], I["grey4"]] if lit else [I["grey1"], I["grey2"]]
        grout = I["grey1"] if lit else I["grey0"]
        wood = [I["brown2"], I["brown3"]] if lit else [I["brown1"], I["brown2"]]
        # timber band at the top
        beam = mask & (v < beam_h)
        t[beam] = wood[0]
        t[beam & (v == 0)] = wood[1]
        t[beam & (v == beam_h - 1)] = I["brown0"]
        # beam ends (the timber ties) every 16 px
        ends = beam & (((u + 4) % 16) < 3) & (v >= 1) & (v <= beam_h - 2)
        t[ends] = I["straw"] if lit else I["brown3"]
        t[beam & (((u + 4) % 16) == 3) & (v >= 1)] = I["brown0"]
        st = mask & (v >= beam_h)
        vv = v - beam_h
        row = np.floor(vv / course).astype(int)
        uu = u + np.where(row % 2 == 1, 8, 0)
        block_len = 16
        bid = np.floor(uu / block_len).astype(int) * 7 + row * 3
        t[st] = stone[0]
        # lighter top-left of each block, dithered wear
        inb_v = vv % course; inb_u = uu % block_len
        t[st & ((inb_v <= 1) | (inb_u <= 1))] = stone[1]
        # a few chips, deterministic per block
        chip = st & (inb_v == 3 + (bid % 4)) & (inb_u == 4 + (bid * 3) % 9)
        t[chip] = grout
        # joints
        t[st & ((inb_v == course - 1) | (inb_u == block_len - 1))] = grout
        # timber tie ends between the courses, every other block (the murus dacicus ties)
        tie = st & (row == 1) & (inb_v >= 3) & (inb_v <= 6) & (inb_u >= 6) & (inb_u <= 9) & (np.floor(uu / block_len).astype(int) % 2 == 0)
        t[tie] = wood[0]
        t[tie & (inb_v == 3)] = wood[1]
        t[tie & ((inb_v == 6) | (inb_u == 9))] = I["brown0"]

    face(left, vL, xs, True)
    face(right, vR, W - 1 - xs, False)
    # top: earth fill with timber planks crossing it, lit
    cx, cy = K.cell_uv()
    tt = K.canvas(W, H)
    dm = K.diamond()
    tt[dm] = I["brown2"]
    plank = dm & ((np.floor(cy * 4).astype(int) % 2) == 0) & (cx > 0.12) & (cx < 0.88)
    tt[plank] = I["brown3"]
    pl_edge = dm & plank & ~K.shift(plank, 0, -1)
    tt[pl_edge] = I["brown1"]
    tt[dm & plank & ~K.shift(plank, 0, 1)] = I["straw"]
    rim = K.border(dm)
    tt[rim] = I["grey4"]
    tt[rim & (np.arange(W)[None, :] >= W // 2) & (np.arange(H)[:, None] >= H // 2 - 1)] = I["grey3"]
    t[:H][top[:H]] = tt[top[:H]]
    # crisp corner: lit edge on the front vertical
    col = (xs == W // 2 - 1) & left
    t[col] = I["grey4"]
    # silhouette line on the bottom and sides so walls read against grass
    sil = K.border(top | left | right)
    lower = sil & ~top
    t[lower & left] = I["grey1"]
    t[lower & right] = I["grey0"]
    return t


GENERATORS = {
    "tile_grass": tile_grass, "tile_road": tile_road, "tile_forest_floor": tile_forest_floor,
    "tile_stone": tile_stone, "tile_wall": tile_wall,
}

"""Drawing kit: palette-indexed canvases, shapes, shading, outlines, dithering, iso tiles, packing.

A canvas is a numpy uint8 array of palette indices (H, W); 255 is transparent.
Everything here is deterministic. Randomness only through `rng(seed)`.
"""
import os
import numpy as np
from PIL import Image, ImageDraw

import palette as P

T = P.TRANSPARENT
TILE_W, TILE_H = 64, 32
BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 + 1 / 32.0


def rng(seed: int) -> np.random.Generator:
    return np.random.default_rng(seed)


def canvas(w: int, h: int) -> np.ndarray:
    return np.full((h, w), T, dtype=np.uint8)


# ---------------------------------------------------------------- masks

def _mask_draw(w, h, fn):
    im = Image.new("1", (w, h), 0)
    fn(ImageDraw.Draw(im))
    return np.array(im, dtype=bool)


def poly(w, h, pts):
    return _mask_draw(w, h, lambda d: d.polygon([tuple(map(float, p)) for p in pts], fill=1, outline=1))


def ellipse(w, h, box):
    """box = (x0, y0, x1, y1), inclusive pixel bounds."""
    return _mask_draw(w, h, lambda d: d.ellipse([float(v) for v in box], fill=1))


def rect(w, h, x0, y0, x1, y1):
    m = np.zeros((h, w), bool)
    m[max(0, y0):max(0, y1 + 1), max(0, x0):max(0, x1 + 1)] = True
    return m


def line(w, h, pts, width=1):
    return _mask_draw(w, h, lambda d: d.line([tuple(map(float, p)) for p in pts], fill=1, width=width))


def thick_path(w, h, pts, r):
    """Union of discs along a polyline: limbs, blades, straps."""
    m = np.zeros((h, w), bool)
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
        for t in np.linspace(0, 1, n):
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            m |= ellipse(w, h, (x - r, y - r, x + r, y + r)) if r >= 1 else _dot(w, h, x, y)
    return m


def _dot(w, h, x, y):
    m = np.zeros((h, w), bool)
    xi, yi = int(round(x)), int(round(y))
    if 0 <= xi < w and 0 <= yi < h:
        m[yi, xi] = True
    return m


def shift(m, dx, dy, fill=False):
    out = np.full_like(m, fill)
    h, w = m.shape
    ys = slice(max(0, dy), h + min(0, dy)); yd = slice(max(0, -dy), h + min(0, -dy))
    xs = slice(max(0, dx), w + min(0, dx)); xd = slice(max(0, -dx), w + min(0, -dx))
    out[ys, xs] = m[yd, xd]
    return out


def border(m, diag=False):
    """Pixels of m with a 4-neighbour (or 8) outside m."""
    inner = m.copy()
    offs = [(1, 0), (-1, 0), (0, 1), (0, -1)] + ([(1, 1), (-1, -1), (1, -1), (-1, 1)] if diag else [])
    for dx, dy in offs:
        inner &= shift(m, dx, dy)
    return m & ~inner


def grow(m, diag=False):
    out = m.copy()
    offs = [(1, 0), (-1, 0), (0, 1), (0, -1)] + ([(1, 1), (-1, -1), (1, -1), (-1, 1)] if diag else [])
    for dx, dy in offs:
        out |= shift(m, dx, dy)
    return out


# ---------------------------------------------------------------- painting

def fill(c, m, idx):
    c[m] = idx


def tone_map(m, light=(-1, -1), steps=40):
    """0 at the lit edge (toward `light`), 1 at the far edge, per pixel of mask m."""
    lx, ly = light
    d1 = np.zeros(m.shape, float); d2 = np.zeros(m.shape, float)
    open1 = m.copy(); open2 = m.copy()
    for k in range(1, steps):
        open1 &= shift(m, -lx * k, -ly * k)  # pixel k steps toward the light is still inside
        open2 &= shift(m, lx * k, ly * k)
        d1 += open1; d2 += open2
        if not open1.any() and not open2.any():
            break
    t = (d1 + 0.5) / (d1 + d2 + 1.0)
    return np.where(m, t, 0.0)


def shade(c, m, rmp, light=(-1, -1), cuts=None, dither=False):
    """Paint mask m with a ramp (dark..light) lit from `light` (pixel direction toward the light).

    2-tone ramp: [shadow, base]; 3-tone: [shadow, base, light]; 4-tone adds a deep shadow first.
    """
    t = tone_map(m, light)
    n = len(rmp)
    if cuts is None:
        cuts = {2: [0.62], 3: [0.28, 0.66], 4: [0.25, 0.6, 0.85]}[n]
    # level: 0 = lightest
    lvl = np.zeros(m.shape, int)
    for ct in cuts:
        if dither:
            lvl += (t + (BAYER4_tile(m.shape) - 0.5) * 0.16) > ct
        else:
            lvl += t > ct
    order = list(reversed(rmp))  # lightest first
    for k, idx in enumerate(order):
        c[m & (lvl == k)] = idx


def BAYER4_tile(shape):
    h, w = shape
    return np.tile(BAYER4, (h // 4 + 1, w // 4 + 1))[:h, :w]


def dither_mix(c, m, a, b, t):
    """Ordered dither between colours a (t=0) and b (t=1). t: float or array over the canvas."""
    th = BAYER4_tile(c.shape)
    t = np.broadcast_to(np.asarray(t, float), c.shape)
    c[m & (t <= th)] = a
    c[m & (t > th)] = b


def outline(c, idx=P.IDX["outline"], diag=False):
    """Outer outline: transparent pixels touching the silhouette."""
    solid = c != T
    ring = grow(solid, diag) & ~solid
    c[ring] = idx
    return c


def edge_against(c, m, idx):
    """Where part m borders already-painted pixels, paint m's border dark (selective inner line)."""
    solid = c != T
    b = border(m)
    touching = np.zeros_like(m)
    for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
        touching |= shift(solid & ~m, dx, dy)
    c[b & touching] = idx


def clean_orphans(c, keep=()):
    """Remove single opaque pixels with no opaque 4-neighbour."""
    solid = c != T
    n = sum(shift(solid, dx, dy).astype(int) for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)])
    lone = solid & (n == 0)
    for k in keep:
        lone &= c != k
    c[lone] = T


def stamp(dst, src, x, y):
    """Copy opaque pixels of src onto dst with src's top-left at (x, y). Clips."""
    h, w = src.shape
    H, W = dst.shape
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(W, x + w), min(H, y + h)
    if x0 >= x1 or y0 >= y1:
        return
    s = src[y0 - y:y1 - y, x0 - x:x1 - x]
    d = dst[y0:y1, x0:x1]
    d[s != T] = s[s != T]


def darken(c, m):
    """Replace colours under mask m with the next darker palette colour (palette-safe shadow)."""
    lut = np.array(P.DARKER_IDX + [T] * (256 - 32), dtype=np.uint8)
    c[m] = lut[c[m]]


def mirror(c):
    """Flip horizontally: SE <-> SW, NE <-> NW."""
    return c[:, ::-1].copy()


# ---------------------------------------------------------------- iso

def cell_to_world(cx, cy):
    """The game's projection (docs/CONTRACTS.md section 10)."""
    return ((cx - cy) * 32, (cx + cy) * 16)


def diamond(w=TILE_W, h=TILE_H, ox=0, oy=0, W=None, H=None):
    """Mask of an iso diamond that tiles exactly on the 64x32 lattice.

    Top half row y spans [w/2-2-2y, w/2+2+2y); bottom rows shrink by 2 per row; the last row is empty.
    """
    W = W or w; H = H or h
    m = np.zeros((H, W), bool)
    half = h // 2
    for y in range(h):
        hw = 2 + 2 * y if y < half else 2 * (h - 1 - y)
        if hw <= 0:
            continue
        x0, x1 = w // 2 - hw, w // 2 + hw
        yy = oy + y
        if 0 <= yy < H:
            m[yy, max(0, ox + x0):max(0, min(W, ox + x1))] = True
    return m


def lattice_wrap(x, y):
    """Map any pixel into the 64x32 tile at origin (diamond top vertex at (32, 0)) by lattice moves.

    Lets tile textures place details anywhere and still tile seamlessly.
    """
    # cell coordinates of the pixel relative to the tile's top vertex at (32, 0)
    fx = (x - 32) + 0.5; fy = y + 0.5
    cx = (fx / 32 + fy / 16) / 2
    cy = (fy / 16 - fx / 32) / 2
    kx, ky = np.floor(cx), np.floor(cy)
    wx, wy = cell_to_world(kx, ky)
    return (np.asarray(x - wx)).astype(int), (np.asarray(y - wy)).astype(int)


def prism(height, w=TILE_W, h=TILE_H):
    """Tall tile masks (top, left face, right face) for a block `height` px tall; image is w x (h+height)."""
    H = h + height
    top = diamond(w, h, 0, 0, w, H)
    allm = np.zeros((H, w), bool)
    for d in range(height + 1):
        allm |= diamond(w, h, 0, d, w, H)
    sides = allm & ~top
    xs = np.arange(w)[None, :]
    return top, sides & (xs < w // 2), sides & (xs >= w // 2)


def cell_uv(w=TILE_W, h=TILE_H):
    """Per-pixel fractional cell coordinates (cx, cy) inside a tile (top vertex at (w/2, 0))."""
    ys, xs = np.mgrid[0:h, 0:w]
    fx = xs - w / 2 + 0.5; fy = ys + 0.5
    return (fx / 32 + fy / 16) / 2, (fy / 16 - fx / 32) / 2


def periodic_noise(seed, cx, cy, terms=6, max_freq=3):
    """Smooth noise that repeats every cell: tiles stay seamless. Range about -1..1."""
    r = rng(seed)
    out = np.zeros_like(cx)
    tot = 0.0
    for _ in range(terms):
        m, n = r.integers(-max_freq, max_freq + 1, 2)
        if m == 0 and n == 0:
            m = 1
        a = 1.0 / np.hypot(m, n)
        out += a * np.cos(2 * np.pi * (m * cx + n * cy) + r.uniform(0, 2 * np.pi))
        tot += a
    return out / tot


# ---------------------------------------------------------------- sheets and files

def pack_rows(rows, fw, fh):
    """rows: list of lists of frame canvases -> sheet, one row per animation, left aligned."""
    cols = max(len(r) for r in rows)
    sheet = canvas(cols * fw, len(rows) * fh)
    for ry, r in enumerate(rows):
        for fx, f in enumerate(r):
            assert f.shape == (fh, fw), f.shape
            sheet[ry * fh:(ry + 1) * fh, fx * fw:(fx + 1) * fw] = f
    return sheet


LUT_RGBA = np.zeros((256, 4), np.uint8)
for _k, (_r, _g, _b) in enumerate(P.RGB):
    LUT_RGBA[_k] = (_r, _g, _b, 255)


def to_rgba(c):
    return LUT_RGBA[c]


def save_png(c, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img = Image.fromarray(to_rgba(c), "RGBA")
    img.save(path, format="PNG", optimize=False, compress_level=9)


def scale(c, k):
    return np.repeat(np.repeat(c, k, axis=0), k, axis=1)

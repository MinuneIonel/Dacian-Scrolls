"""A tiny 2D rig: characters are lists of shapes in frame coordinates, rasterised after an optional
affine transform (used for falls). Shapes are painted back to front with ramp shading lit from the
top-left, a dark line where a part overlaps earlier parts, then one black outline around everything.
"""
import math
import numpy as np

import kit as K
import palette as P

I = P.IDX
LIGHT = (-1, -1)


class Shape:
    def __init__(self, kind, pts, ramp, r=0.0, edge=None, light=LIGHT, post=None, cuts=None, tag="", dither=False):
        self.kind, self.pts, self.ramp, self.r = kind, pts, ramp, r
        self.edge, self.light, self.post, self.cuts, self.tag, self.dither = edge, light, post, cuts, tag, dither


def circle_pts(cx, cy, rx, ry=None, n=20):
    ry = rx if ry is None else ry
    return [(cx + rx * math.cos(2 * math.pi * k / n), cy + ry * math.sin(2 * math.pi * k / n)) for k in range(n)]


def poly(pts, ramp, **kw):
    return Shape("poly", pts, ramp, **kw)


def oval(cx, cy, rx, ry, ramp, **kw):
    return Shape("poly", circle_pts(cx, cy, rx, ry), ramp, **kw)


def path(pts, r, ramp, **kw):
    return Shape("path", pts, ramp, r=r, **kw)


def dots(pts, col, **kw):
    return Shape("px", pts, [col], **kw)


def line(pts, col, **kw):
    return Shape("line", pts, [col], **kw)


class Affine:
    """p' = o + M (p - pivot)"""
    def __init__(self, pivot=(0, 0), m=((1, 0), (0, 1)), o=None):
        self.pivot, self.m = pivot, m
        self.o = pivot if o is None else o

    def __call__(self, p):
        x, y = p[0] - self.pivot[0], p[1] - self.pivot[1]
        (a, b), (c, d) = self.m
        return (self.o[0] + a * x + b * y, self.o[1] + c * x + d * y)

    def scale_r(self, r):
        (a, b), (c, d) = self.m
        return r * math.sqrt(abs(a * d - b * c))


def render(shapes, w, h, xf=None, outline=True):
    c = K.canvas(w, h)
    for s in shapes:
        pts = [xf(p) for p in s.pts] if xf else s.pts
        r = xf.scale_r(s.r) if xf else s.r
        if s.kind == "poly":
            m = K.poly(w, h, pts)
        elif s.kind == "path":
            m = K.thick_path(w, h, pts, r)
        elif s.kind == "line":
            m = K.line(w, h, pts, 1)
        else:  # px
            m = np.zeros((h, w), bool)
            for x, y in pts:
                xi, yi = int(math.floor(x)), int(math.floor(y))
                if 0 <= xi < w and 0 <= yi < h:
                    m[yi, xi] = True
        if not m.any():
            continue
        if len(s.ramp) == 1:
            c[m] = s.ramp[0]
        else:
            K.shade(c, m, s.ramp, light=s.light, cuts=s.cuts, dither=s.dither)
        if s.edge is not None:
            before = c.copy()
            before[m] = K.T
            # dark line only where the part sits over something painted earlier
            solid = before != K.T
            b = K.border(m)
            touch = np.zeros_like(m)
            for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
                touch |= K.shift(solid, dx, dy)
            c[b & touch] = s.edge
        if s.post:
            s.post(c, m)
    if outline:
        K.clean_orphans(c)
        K.outline(c)
    return c


# ------------------------------------------------------------------ textures (post hooks)

def scales(dark, light):
    """Scale armour: staggered little arcs."""
    def f(c, m):
        h, w = c.shape
        ys, xs = np.mgrid[0:h, 0:w]
        inner = m & ~K.border(m)
        row = ys // 2
        arc = inner & (((xs + row) % 3) == 0) & (ys % 2 == 1)
        c[arc] = dark
        hi = inner & (((xs + row) % 3) == 1) & (ys % 2 == 0) & (c != dark)
        c[hi & (c == light)] = light
    return f


def stripes(col, every=3, phase=0, vertical=False):
    def f(c, m):
        h, w = c.shape
        ys, xs = np.mgrid[0:h, 0:w]
        k = xs if vertical else ys
        c[m & ~K.border(m) & ((k + phase) % every == 0)] = col
    return f

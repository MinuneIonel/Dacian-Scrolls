"""UI pieces. ui_panel: 48x48, 9-slice with 12 px margins; edges are uniform along their length."""
import numpy as np

import kit as K
import palette as P

I = P.IDX


def ui_panel(spec):
    n = spec.get("size", 48)
    c = K.canvas(n, n)
    ys, xs = np.mgrid[0:n, 0:n]
    d = np.minimum(np.minimum(xs, ys), np.minimum(n - 1 - xs, n - 1 - ys))  # distance to the edge
    # carved oak frame: bevel lit from the top-left
    c[:, :] = I["brown1"]
    # the top and left sides catch the light
    lit = (d == xs) & (xs <= n - 1 - xs) | (d == ys) & (ys <= n - 1 - ys)
    shadow_side = ~lit
    c[(d >= 2) & (d <= 7) & lit] = I["brown2"]
    c[(d >= 2) & (d <= 7) & shadow_side] = I["brown1"]
    # carved groove along the middle of the frame
    c[(d == 5) & lit] = I["brown0"]
    c[(d == 5) & shadow_side] = I["brown0"]
    c[(d == 6) & lit] = I["brown3"]
    c[(d == 6) & shadow_side] = I["brown2"]
    # thin bronze border: outer
    c[(d == 1) & lit] = I["straw"]
    c[(d == 1) & shadow_side] = I["ochre"]
    c[d == 0] = I["outline"]
    # inner bronze line and parchment
    c[(d == 8) & lit] = I["brown2"]
    c[(d == 8) & shadow_side] = I["ochre"]
    c[(d == 9)] = I["brown0"]
    inner = d >= 10
    c[inner] = I["straw"]
    # a soft inner shadow under the top and left frame edges
    c[(d == 10) & lit] = I["ochre"]
    # bronze studs in the corners (inside the 12 px margin, so they never stretch)
    for cx, cy in ((4, 4), (n - 5, 4), (4, n - 5), (n - 5, n - 5)):
        c[cy - 1:cy + 2, cx - 1:cx + 2] = I["ochre"]
        c[cy - 1, cx - 1] = I["straw"]
        c[cy + 1, cx + 1] = I["brown1"]
        c[cy - 1, cx + 1] = I["brown2"]; c[cy + 1, cx - 1] = I["brown2"]
        c[cy, cx] = I["straw"]
    return c


GENERATORS = {"ui_panel": ui_panel}

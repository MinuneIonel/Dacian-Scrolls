#!/usr/bin/env python3
"""Generates the scroll-mode parchment (WP-24): assets/screens/parchment.png.

A horizontal sheet between two wooden rollers, with a burnt wavy edge and dithered stains.
Only colours from tools/art/palette.py. Read directly by src/modes/scroll (not in the manifest).

    python3 tools/art/parchment/gen_parchment.py
"""
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
import palette as P  # noqa: E402

W, H = 608, 336
ROLLER = 14       # roller width
KNOB = 6          # knob overhang above and below the sheet
OUT = os.path.join(ROOT, "assets", "screens", "parchment.png")
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def noise(rng, w, h, cells):
    """Smooth value noise in 0..1 from a coarse random grid, bilinear upsampled."""
    gx, gy = cells, max(2, int(cells * h / w))
    g = rng.random((gy + 2, gx + 2))
    ys = np.linspace(0, gy, h)
    xs = np.linspace(0, gx, w)
    y0 = ys.astype(int); x0 = xs.astype(int)
    fy = (ys - y0)[:, None]; fx = (xs - x0)[None, :]
    fy = fy * fy * (3 - 2 * fy); fx = fx * fx * (3 - 2 * fx)
    a = g[y0][:, x0]; b = g[y0][:, x0 + 1]; c = g[y0 + 1][:, x0]; d = g[y0 + 1][:, x0 + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def main() -> None:
    rng = np.random.default_rng(1953)
    idx = np.full((H, W), P.TRANSPARENT, dtype=np.uint8)
    yy, xx = np.mgrid[0:H, 0:W]
    bay = BAYER[yy % 4, xx % 4]

    # Sheet: between the rollers, wavy top and bottom edges.
    left, right = ROLLER - 2, W - ROLLER + 2
    top = KNOB + 2 + np.round(2.0 * noise(rng, W, 1, 24)[0] + 1.2 * np.sin(xx[0] / 23.0)).astype(int)
    bot = H - KNOB - 3 - np.round(2.0 * noise(rng, W, 1, 24)[0] + 1.2 * np.cos(xx[0] / 19.0)).astype(int)
    sheet = (xx >= left) & (xx < right) & (yy >= top[None, :]) & (yy <= bot[None, :])

    # Distance to the sheet edge (cheap: vertical distance to the wavy edges, horizontal to rollers).
    dist = np.minimum.reduce([yy - top[None, :], bot[None, :] - yy, xx - left, right - 1 - xx]).astype(float)
    stain = 0.65 * noise(rng, W, H, 9) + 0.35 * noise(rng, W, H, 31)
    burn = dist + 6.0 * (noise(rng, W, H, 40) - 0.5)

    tone = np.zeros((H, W))            # 0 light .. 1 dark
    tone += np.clip((stain - 0.58) * 1.6, 0, 1) * 0.38
    tone += np.clip((10 - burn) / 10.0, 0, 1) * 0.9
    ramp = [P.i("straw"), P.i("ochre"), P.i("brown3"), P.i("brown2")]
    level = tone * (len(ramp) - 1)
    lo = np.floor(level).astype(int)
    frac = level - lo
    pick = np.where(frac > bay, np.minimum(lo + 1, len(ramp) - 1), lo)
    sheet_idx = np.array(ramp, dtype=np.uint8)[pick]
    # Sparse fibres: short light flecks.
    fleck = (rng.random((H, W)) < 0.004) & (tone < 0.2)
    sheet_idx[fleck] = P.i("white")
    idx[sheet] = sheet_idx[sheet]
    # Outline the sheet.
    edge = sheet & ~(np.roll(sheet, 1, 0) & np.roll(sheet, -1, 0) & np.roll(sheet, 1, 1) & np.roll(sheet, -1, 1))
    idx[edge] = P.i("brown1")
    # Fold creases: faint vertical lines at thirds.
    for cx in (left + (right - left) // 3, left + 2 * (right - left) // 3):
        col = sheet[:, cx] & (bay[:, cx] < 0.5)
        idx[col, cx] = np.where(idx[col, cx] == P.i("straw"), P.i("ochre"), idx[col, cx])

    # Rollers: a wooden dowel each side with bronze knobs.
    for x0 in (0, W - ROLLER):
        for x in range(ROLLER):
            t = x / (ROLLER - 1)
            shade = "brown2" if 0.2 < t < 0.45 else ("brown1" if 0.08 < t < 0.85 else "brown0")
            idx[KNOB:H - KNOB, x0 + x] = P.i(shade)
        idx[KNOB:H - KNOB, x0 + 3] = P.i("brown3")
        idx[KNOB:H - KNOB, x0] = P.i("outline")
        idx[KNOB:H - KNOB, x0 + ROLLER - 1] = P.i("outline")
        # wood grain
        for gy in range(KNOB + 5, H - KNOB, 11):
            idx[gy, x0 + 2:x0 + ROLLER - 2] = P.i("brown0")
        for ky in (0, H - KNOB - 2):
            for y in range(KNOB + 2):
                for x in range(-1, ROLLER + 1):
                    xx_ = x0 + x
                    if 0 <= xx_ < W:
                        t = (x + 1) / (ROLLER + 1)
                        c = "straw" if 0.25 < t < 0.4 else ("ochre" if 0.1 < t < 0.8 else "brown2")
                        idx[ky + y, xx_] = P.i(c)
            idx[ky, max(0, x0 - 1):x0 + ROLLER + 1] = P.i("outline")
            idx[ky + KNOB + 1, max(0, x0 - 1):x0 + ROLLER + 1] = P.i("outline")

    pal = []
    for r, g, b in P.RGB:
        pal += [r, g, b]
    pal += [0, 0, 0] * (256 - len(P.RGB))
    rgba = np.zeros((H, W, 4), dtype=np.uint8)
    solid = idx != P.TRANSPARENT
    rgb = np.array(P.RGB, dtype=np.uint8)
    rgba[solid, :3] = rgb[idx[solid]]
    rgba[solid, 3] = 255
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    Image.fromarray(rgba, "RGBA").save(OUT, optimize=True)
    print(OUT)


if __name__ == "__main__":
    main()

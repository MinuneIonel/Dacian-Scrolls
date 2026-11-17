"""Contact sheets at 3x for review: docs/art-sheet-characters.png, -tiles.png, -icons.png.
Built by build.py from the same in-memory images, so they are always current."""
import numpy as np

import kit as K
import palette as P
import gen_chars as C

I = P.IDX
BG = I["grey0"]
SCALE = 3
GAP = 6


def _canvas(blocks, width):
    """blocks: list of (canvas) laid out left to right, wrapping at `width`."""
    x, y, rowh = GAP, GAP, 0
    placed = []
    for b in blocks:
        h, w = b.shape
        if x + w + GAP > width and x > GAP:
            x, y, rowh = GAP, y + rowh + GAP, 0
        placed.append((b, x, y))
        x += w + GAP
        rowh = max(rowh, h)
    out = np.full((y + rowh + GAP, width), BG, np.uint8)
    for b, bx, by in placed:
        out[by:by + b.shape[0], bx:bx + b.shape[1]] = b
    return out


def _swatch(img, ground=I["grey1"], foot=None):
    """A frame on a background, with a ground band under the feet so outlines read."""
    h, w = img.shape
    c = np.full((h, w), BG, np.uint8)
    if foot is not None:
        c[foot - 3:foot + 3, :] = ground
    K.stamp(c, img, 0, 0)
    return c


def characters(images, specs, path):
    blocks = []
    n_anim = len(C.ANIMS)
    for s in specs:
        if s["type"] != "frames" or s.get("kind") == "fx":
            continue
        rows = images[s["id"]]
        fw, fh = s["frame_size"]
        foot = s["anchor"][1]
        if fw <= 48:
            se = [f for r in rows[:n_anim] for f in r]
            ne = [f for r in rows[n_anim:] for f in r]
            strip = K.pack_rows([se, ne], fw, fh)
            band = np.full(strip.shape, BG, np.uint8)
            for r in range(2):
                band[r * fh + foot - 2:r * fh + foot + 3, :] = I["grey1"]
            K.stamp(band, strip, 0, 0)
            blocks.append(band)
        else:
            pick = [(0, 0), (1, 0), (1, 2), (2, 0), (2, 1), (3, 0), (4, 1), (4, 2)]
            se = [rows[r][k] for r, k in pick]
            ne = [rows[n_anim + r][k] for r, k in pick]
            strip = K.pack_rows([se, ne], fw, fh)
            band = np.full(strip.shape, BG, np.uint8)
            for r in range(2):
                band[r * fh + foot - 4:r * fh + foot + 8, :] = I["grey1"]
            K.stamp(band, strip, 0, 0)
            blocks.append(band)
    K.save_png(K.scale(_canvas(blocks, 1100), SCALE), path)


def tiles(images, specs, path):
    ts = [s for s in specs if s["id"].startswith("tile_")]
    cw = 68
    tallest = max(images[s["id"]].shape[0] for s in ts)
    blocks = []
    for s in ts:
        im = images[s["id"]]
        cell = np.full((tallest, cw), BG, np.uint8)
        K.stamp(cell, im, 2, tallest - im.shape[0])
        blocks.append(cell)
    sheet = _canvas(blocks, 12 * (cw + GAP) + GAP)
    # a small patch of each ground set tiled 3x3, to show the seams are invisible
    grounds = [s["id"] for s in ts if images[s["id"]].shape == (32, 64)]
    patches = []
    for gid in grounds:
        p = np.full((32 * 3 + 2, 64 * 3 + 2), BG, np.uint8)
        for cx in range(3):
            for cy in range(3):
                x, y = K.cell_to_world(cx, cy)
                K.stamp(p, images[gid], int(x + 65), int(y + 1))
        patches.append(p)
    patch_sheet = _canvas(patches, sheet.shape[1])
    K.save_png(K.scale(np.vstack([sheet, patch_sheet]), SCALE), path)


def icons(images, specs, path):
    groups = []
    for prefix in ("icon_", "portrait_", "prop_", "marker_", "fx_"):
        blocks = []
        for s in specs:
            if not s["id"].startswith(prefix):
                continue
            im = images[s["id"]]
            if isinstance(im, list):
                im = K.pack_rows([[f for r in im for f in r]], *s["frame_size"])
            cell = np.full((im.shape[0], im.shape[1]), I["grey1"] if prefix in ("prop_", "marker_", "fx_") else BG, np.uint8)
            K.stamp(cell, im, 0, 0)
            blocks.append(cell)
        groups.append(_canvas(blocks, 700))
    K.save_png(K.scale(np.vstack(groups), SCALE), path)


def compose(images, specs, root):
    import os
    characters(images, specs, os.path.join(root, "docs", "art-sheet-characters.png"))
    tiles(images, specs, os.path.join(root, "docs", "art-sheet-tiles.png"))
    icons(images, specs, os.path.join(root, "docs", "art-sheet-icons.png"))

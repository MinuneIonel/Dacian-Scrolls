"""docs/art-spike.png: a small scene, every knight frame, the UI panel, at 3x nearest-neighbour."""
import numpy as np

import kit as K
import palette as P

I = P.IDX
BG = I["grey0"]
SCALE = 3

MAP = [  # cy rows, cx columns: S stone, R road, G grass, F forest floor
    "SSSRGG",
    "SSSRGF",
    "GGRRGF",
    "GRRGFF",
    "RRGGFF",
    "RGGFFF",
]
TILE = {"S": "tile_stone", "R": "tile_road", "G": "tile_grass", "F": "tile_forest_floor"}
WALLS = [(0, 0), (1, 0), (2, 0), (0, 1)]


def frame(images, sid, anim_row, i):
    return images[sid][anim_row][i]


def shadow(c, x, y, rx, ry):
    """Palette-safe drop shadow: darken whatever is under an ellipse."""
    h, w = c.shape
    m = K.ellipse(w, h, (x - rx, y - ry, x + rx - 1, y + ry - 1)) & (c != K.T)
    K.darken(c, m)
    core = K.ellipse(w, h, (x - rx + 2, y - ry + 1, x + rx - 3, y + ry - 2)) & (c != K.T)
    K.darken(c, core)


def nine_slice(src, w, h, m):
    """Stretch a 9-slice texture the way Godot's NinePatchRect does (tile mode would look the same here)."""
    sh, sw = src.shape
    xs = np.concatenate([np.arange(m), m + (np.arange(w - 2 * m) % (sw - 2 * m)), np.arange(sw - m, sw)])
    ys = np.concatenate([np.arange(m), m + (np.arange(h - 2 * m) % (sh - 2 * m)), np.arange(sh - m, sh)])
    return src[np.ix_(ys, xs)]


def scene(images):
    W, H = 460, 266
    c = np.full((H, W), BG, np.uint8)
    ox, oy = 232, 80  # world origin (centre of cell 0,0); the giant's waist meets the top edge

    def pos(cx, cy):
        x, y = K.cell_to_world(cx, cy)
        return ox + x, oy + y

    for s in range(11):
        for cy in range(6):
            cx = s - cy
            if 0 <= cx < 6:
                x, y = pos(cx, cy)
                K.stamp(c, images[TILE[MAP[cy][cx]]], int(x - 32), int(y - 16))
    objs = []
    wall = images["tile_wall"]
    for cx, cy in WALLS:
        x, y = pos(cx, cy)
        objs.append((cx + cy, 0, lambda x=x, y=y: K.stamp(c, wall, int(x - 32), int(y - 16 - (wall.shape[0] - 32)))))

    def put(sid, cx, cy, row, i, flip=False, anchor=(16, 44), sh=(10, 4)):
        x, y = pos(cx, cy)
        f = frame(images, sid, row, i)
        if flip:
            f = K.mirror(f)
        ax = f.shape[1] - 1 - anchor[0] if flip else anchor[0]

        def draw():
            shadow(c, int(x) + 1, int(y) + 1, sh[0], sh[1])
            K.stamp(c, f, int(x - ax), int(y - anchor[1]))
        objs.append((cx + cy, 1, draw))

    # rows: 0 idle, 1 walk, 2 attack, 3 hit, 4 death, then the same +5 for north-east
    put("knight", 2, 3, 6, 1)                       # walking north-east, toward the ankles
    put("grazi_thrall", 3, 2, 0, 0, flip=True)    # south-west, facing the knight
    put("giant_legs", 4.5, 0.5, 0, 0, anchor=(64, 160), sh=(56, 22))
    for _, _, fn in sorted(objs, key=lambda o: (o[0], o[1])):
        fn()
    return c


def compose(images, specs, path):
    sc = scene(images)
    # strip of every knight frame, SE row then NE row, grouped by animation
    import gen_chars as C
    gap = 8
    strip_w = sum(n for _, n, _, _ in C.ANIMS) * 32 + gap * (len(C.ANIMS) - 1)
    strip = np.full((48 * 2 + 4, strip_w), BG, np.uint8)
    for half in range(2):
        x = 0
        for a, (_, n, _, _) in enumerate(C.ANIMS):
            for i in range(n):
                f = images["knight"][half * len(C.ANIMS) + a][i]
                # a ground swatch under each frame so the outline reads on something
                base = strip[half * 52:half * 52 + 48, x:x + 32]
                base[40:48, :] = I["grey1"]
                K.stamp(strip, f, x, half * 52)
                x += 32
            x += gap
    panel = images["ui_panel"]
    big = nine_slice(panel, 176, 64, 12)
    # a party card inside the stretched panel: the knight and the thrall, idle
    card = big.copy()
    K.stamp(card, images["knight"][0][0], 14, 8)
    K.stamp(card, images["grazi_thrall"][0][0], 48, 8)
    W = max(sc.shape[1], strip_w + 16)
    H = sc.shape[0] + strip.shape[0] + 16 + 64 + 16
    out = np.full((H, W), BG, np.uint8)
    out[:sc.shape[0], (W - sc.shape[1]) // 2:(W - sc.shape[1]) // 2 + sc.shape[1]] = sc
    y = sc.shape[0] + 8
    K.stamp(out, strip, (W - strip_w) // 2, y)
    y += strip.shape[0] + 8
    K.stamp(out, panel, 16, y + 8)
    K.stamp(out, card, 16 + 48 + 16, y)
    # palette swatch
    for k in range(32):
        out[y + 4 + (k // 8) * 10:y + 12 + (k // 8) * 10, W - 16 - 8 * 10 + (k % 8) * 10:W - 16 - 8 * 10 + (k % 8) * 10 + 8] = k
    K.save_png(K.scale(out, SCALE), path)

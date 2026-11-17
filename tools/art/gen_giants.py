"""Size-2 giants, waist down, on the same 128x192 frame and [64, 160] anchor as giant_legs:
the bancul recruit (hairy, feral, barefoot, a fur loincloth and a gnawed bone) and the Lobizi
surgeon (white cis robe, teal surgical apron, glass-and-buttons tools, a gloved hand with a
scalpel the length of a canoe).
"""
import math

import numpy as np

import kit as K
import palette as P
import rig as R
import gen_chars as C
from rig import poly, oval, path, dots, line

I = P.IDX
E = I["outline"]
GW, GH = C.GW, C.GH
SKIN = C.SKIN
ROBE = C.ROBE


def rr(*names):
    return [I[n] for n in names]


def hairy(dark, mid):
    """Short diagonal hair strokes over a limb (lit side keeps fewer)."""
    def f(c, m):
        h, w = c.shape
        ys, xs = np.mgrid[0:h, 0:w]
        inner = m & ~K.border(m)
        stroke = inner & (((xs * 3 + ys * 5) % 9) == 0)
        c[stroke] = dark
        c[K.shift(stroke, 1, 1) & inner & (c != dark)] = mid
    return f


def bare_foot(cx, cy, fwd, lift=0, se=True, sole_up=False, ramp=None):
    """A giant bare foot. (cx, cy) = middle of the sole on the ground."""
    ramp = ramp or SKIN
    cy -= lift
    S = []
    L, Wd = 38, 18
    fx, fy = fwd
    side = (fx, -fy)
    if sole_up:
        S.append(poly(C.ground_oval(cx, cy, fwd, L, Wd), rr("skin0", "skin1"), edge=E))
        S.append(poly(C.ground_oval(cx - fx * 4, cy - fy * 4, fwd, L - 14, Wd - 8), rr("brown1", "brown2")))  # dirty sole
        return S
    S.append(poly([(x, y + 2) for x, y in C.ground_oval(cx, cy, fwd, L, Wd)], rr("skin0", "skin0")))
    S.append(poly(C.ground_oval(cx, cy - 3, fwd, L, Wd - 2), ramp, edge=E))
    if se:
        for k, off in enumerate((-6, -2.8, 0.2, 3, 5.6)):
            r = 3.0 if k == 0 else 2.2
            tx = cx + fx * (L / 2 - 2) + side[0] * off
            ty = cy - 3 + fy * (L / 2 - 2) + side[1] * off
            S.append(oval(tx, ty, r + 0.6, r, ramp, edge=E))
            S.append(dots([(tx + 0.5, ty - 0.6)], I["brown1"] if k % 2 == 0 else I["straw"]))  # toenails of uneven hygiene
        S.append(path([(cx - fx * 6 - side[0] * 5, cy - 6), (cx + fx * 4 - side[0] * 5, cy - 6 + fy * 4)], 0.6, [I["skin0"]]))
    else:
        hx, hy = cx - fx * (L / 2 - 6), cy - 6 - fy * (L / 2 - 6)
        S.append(oval(hx, hy, 6, 4, ramp, edge=E))
    return S


def bootie(cx, cy, fwd, lift=0, se=True, sole_up=False):
    """Surgical shoe covers: silk, gathered at the ankle with a teal band."""
    cy -= lift
    S = []
    L, Wd = 40, 18
    if sole_up:
        S.append(poly(C.ground_oval(cx, cy, fwd, L, Wd), rr("grey1", "grey2", "grey3"), edge=E))
        S.append(dots([(cx - 4, cy), (cx + 4, cy - 2), (cx, cy + 2)], I["grey1"]))
        return S
    S.append(poly([(x, y + 3) for x, y in C.ground_oval(cx, cy, fwd, L + 2, Wd + 2)], rr("grey0", "grey1")))
    S.append(poly(C.ground_oval(cx, cy - 2, fwd, L + 2, Wd + 2), ROBE, edge=E, dither=True))
    S.append(poly(C.ground_oval(cx - fwd[0] * 6, cy - 8 - fwd[1] * 6, fwd, L - 16, Wd - 4), ROBE, edge=E, dither=True))
    S.append(line([(cx - 10, cy - 10 - fwd[1] * 6), (cx - 2, cy - 12 - fwd[1] * 6)], I["teal"]))
    return S


def build_giant(kind, facing, p):
    se = facing == "se"
    surgeon = kind == "surgeon"
    dx = p.get("dx", 0)
    hem = (122 if surgeon else 92) + p.get("drop", 0)
    sway = p.get("sway", 0)
    fwd = (0.89, 0.45) if se else (0.89, -0.45)
    nfx, nfy = (44 + dx, 176) if se else (76 + dx, 178)
    ffx, ffy = (84 + dx, 164) if se else (44 + dx, 164)
    nl, fl = p.get("nlift", 0), p.get("flift", 0)
    nfx += p.get("nfx", 0); ffx += p.get("ffx", 0)
    crouch = p.get("crouch", 0)
    leg_ramp = rr("blue0", "teal", "blue1") if surgeon else SKIN
    leg_post = None if surgeon else hairy(I["brown1"], I["skin0"])
    foot = bootie if surgeon else bare_foot

    def leg(fx, fy, lift, r, near):
        knee_x = fx + (6 if se else -6) * (crouch / 20)
        top = (fx - (4 if se else -4) + crouch * (0.6 if near else -0.6), hem - 24)
        ankle = (fx - fwd[0] * 10, fy - lift - 12 - fwd[1] * 10)
        knee = (knee_x + crouch * 0.4, (top[1] + ankle[1]) / 2)
        S = [path([top, knee, ankle], r, leg_ramp, edge=E if near else None, post=leg_post)]
        if not surgeon:
            S.append(oval(knee[0] + 1, knee[1], r * 0.8, r * 0.6, SKIN, post=hairy(I["brown1"], I["skin0"])))  # knobbly knee
        return S

    near = leg(nfx, nfy, nl, 11.5 if not surgeon else 8.5, True) + foot(nfx, nfy, fwd, nl, se, sole_up=p.get("sole", False))
    far = leg(ffx, ffy, fl, 11 if not surgeon else 8, False) + foot(ffx, ffy, fwd, fl, se)
    cxr = 64 + dx
    ty = -2
    S = far + near
    if surgeon:
        S += surgeon_robe(cxr, ty, hem, sway, se, p)
    else:
        S += bancul_loincloth(cxr, ty, hem, sway, se, p)
    return S


def ragged_hem(cxr, hem, w, sway, n=11, amp=6, seed=0):
    out = []
    for k in range(n + 1):
        x = cxr - w + sway + k * (2 * w) / n
        jag = [0, amp, 2, amp + 3, 1, amp - 1, 3, amp + 2, 0, amp, 2, amp][(k + seed) % 12]
        out.append((x, hem - 4 + jag + sway * (k - n / 2) / 10))
    return out


def bancul_loincloth(cxr, ty, hem, sway, se, p):
    fur = rr("brown0", "brown1", "brown2")
    S = []
    # bare hairy belly at the top edge, a rope belt, then the pelt
    S.append(poly([(cxr - 40, ty), (cxr + 40, ty), (cxr + 42, ty + 14), (cxr - 42, ty + 14)], SKIN, edge=E, post=hairy(I["brown1"], I["skin0"])))
    if se:
        S.append(dots([(cxr + 2, ty + 7)], I["skin0"]))                           # navel
    pts = [(cxr - 44, ty + 12), (cxr + 44, ty + 12), (cxr + 52 + sway, hem - 4)] + list(reversed(ragged_hem(cxr, hem, 52, sway))) + [(cxr - 52 + sway, hem - 4)]
    S.append(poly(pts, fur, edge=E, post=pelt_tufts(), light=(-2, -1)))
    S.append(path([(cxr - 44, ty + 14), (cxr - 10, ty + 18), (cxr + 20, ty + 16), (cxr + 44, ty + 13)], 2.0, rr("brown2", "brown3", "straw"), edge=E))
    if se:
        # a gnawed bone tucked in the rope: lunch, or a friend
        S.append(path([(cxr + 14, ty + 10), (cxr + 26, ty + 30)], 2.4, rr("grey3", "grey4", "white"), edge=E))
        S.append(oval(cxr + 13, ty + 9, 3.4, 2.6, rr("grey3", "grey4", "white"), edge=E))
        S.append(oval(cxr + 27, ty + 31, 3.4, 2.6, rr("grey3", "grey4", "white"), edge=E))
        S.append(dots([(cxr + 20, ty + 20), (cxr + 21, ty + 21)], I["blood"]))
    # a hairy hand hanging at the side, knuckles nearly dragging
    hand_y = 70 + p.get("hand", 0) + p.get("drop", 0) // 2
    hx = cxr - 52 if se else cxr + 50
    S.append(path([(hx + (2 if se else -2), -4), (hx, hand_y - 10)], 9, SKIN, edge=E, post=hairy(I["brown1"], I["skin0"])))
    S.append(oval(hx, hand_y, 10, 9, SKIN, edge=E))
    for k in range(4):
        fx = hx - 6 + k * 4 if se else hx - 6 + k * 4
        S.append(oval(fx, hand_y + 8, 2.4, 2.8, SKIN, edge=E))
    S.append(oval(hx + (8 if se else -8), hand_y - 2, 3, 4, SKIN, edge=E))  # thumb
    return S


def pelt_tufts():
    def f(c, m):
        h, w = c.shape
        ys, xs = np.mgrid[0:h, 0:w]
        inner = m & ~K.border(m)
        t = inner & (((xs * 2 + ys * 3) % 11) == 0)
        t |= K.shift(t, 0, 1) & inner
        t |= K.shift(t, 1, 1) & inner
        lit = t & (c == I["brown2"])
        mid = t & (c == I["brown1"])
        c[lit] = I["brown3"]
        c[mid] = I["brown0"]
        c[K.shift(lit, 0, 1) & inner & (c == I["brown2"])] = I["brown1"]
        c[K.shift(mid, -1, 1) & inner & (c == I["brown1"])] = I["brown2"]
    return f


def surgeon_robe(cxr, ty, hem, sway, se, p):
    S = []
    top_w, hem_w = 36, 54
    wav = []
    for k in range(13):
        x = cxr - hem_w + sway + k * (2 * hem_w) / 12
        wav.append((x, hem + (3 if k % 2 else -1) + sway * (k - 6) / 10))
    robe_pts = [(cxr - top_w, ty), (cxr - hem_w + sway, hem - 4)] + wav + [(cxr + hem_w + sway, hem - 4), (cxr + top_w, ty)]

    def folds(c, m):
        h, w = c.shape
        ys, xs = np.mgrid[0:h, 0:w]
        for k, fx0 in enumerate((-24, -12, 14, 26)):
            fx = cxr + fx0 * (0.8 + 0.4 * ys / max(hem, 1)) + sway * ys / max(hem, 1)
            sh = m & (np.abs(xs - fx) < 0.7 + ys / max(hem, 1)) & (ys > 6)
            c[sh & (c != I["white"])] = I["silk0"]
            c[sh & (c == I["white"])] = I["grey4"]
    S.append(poly(robe_pts, ROBE, edge=E, post=folds, light=(-2, -1), dither=True, cuts=[0.34, 0.74]))
    if se:
        # teal surgical apron down the front, tied with a cord, a few tasteful splashes
        ap = [(cxr - 14, ty), (cxr + 16, ty), (cxr + 22 + sway, hem - 8), (cxr - 18 + sway, hem - 6)]
        S.append(poly(ap, rr("blue0", "teal", "blue1"), edge=E, post=R.stripes(I["blue0"], 6, vertical=True)))
        S.append(dots([(cxr + 8, 70), (cxr + 9, 71), (cxr + 10, 70), (cxr - 6, 96), (cxr - 5, 97)], I["blood"]))
        S.append(poly([(cxr - 6, 40), (cxr + 10, 40), (cxr + 10, 54), (cxr - 6, 54)], rr("blue0", "teal"), edge=E))   # pocket
        S.append(path([(cxr - 2, 42), (cxr - 1, 30)], 1.6, rr("teal", "cyan"), edge=E))                                # syringe in the pocket
        S.append(path([(cxr + 5, 42), (cxr + 7, 32)], 1.2, rr("grey2", "grey4"), edge=E))
    else:
        S.append(path([(cxr - 20, ty + 4), (cxr - 4, ty + 10), (cxr + 4, ty + 6)], 1.6, rr("blue0", "teal"), edge=E))  # apron ties
        S.append(path([(cxr - 3, ty + 10), (cxr - 6, ty + 34)], 1.4, rr("blue0", "teal")))
        S.append(path([(cxr + 1, ty + 10), (cxr + 4, ty + 30)], 1.4, rr("blue0", "teal")))
    # a belt of glass instruments with buttons
    S.append(poly([(cxr - 37, ty), (cxr + 37, ty), (cxr + 38, ty + 12), (cxr - 38, ty + 12)], rr("grey0", "grey1", "grey2"), edge=E))
    for k, col in enumerate(("cyan", "magenta", "acid", "cyan", "magenta")):
        bx = cxr - 28 + k * 14
        S.append(oval(bx, ty + 6, 2.2, 2.2, [I["teal"], I[col]] if col != "magenta" else [I["red1"], I["magenta"]], edge=E))
    # the gloved hand with the scalpel: hanging, raised, or jabbing
    jab = p.get("jab", 0)
    hx = (cxr + 48) if se else (cxr - 48)
    hy = 64 + p.get("hand", 0) + p.get("drop", 0) // 2
    S.append(path([(hx - (4 if se else -4), -4), (hx, hy - 10)], 8, ROBE, edge=E, dither=True))
    S.append(path([(hx, hy - 12), (hx, hy - 6)], 6.5, rr("teal", "cyan"), edge=E))                     # cuff
    S.append(oval(hx, hy, 8, 8, rr("grey3", "grey4", "white"), edge=E))                                 # glove
    ang = {0: 170, 1: 20, 2: 135}[jab]
    a = math.radians(ang)
    d = (math.sin(a), -math.cos(a))
    b0 = (hx + d[0] * 6, hy + d[1] * 6)
    b1 = (hx + d[0] * 18, hy + d[1] * 18)
    b2 = (hx + d[0] * 58, hy + d[1] * 58)
    S.append(path([b0, b1], 2.6, rr("grey1", "grey2", "grey3"), edge=E))                                 # handle
    S.append(dots([(b0[0] + d[0] * 4, b0[1] + d[1] * 4), (b0[0] + d[0] * 8, b0[1] + d[1] * 8)], I["magenta"]))
    S.append(dots([(b0[0] + d[0] * 6, b0[1] + d[1] * 6)], I["acid"]))
    n = (math.cos(a), math.sin(a))
    S.append(poly([(b1[0] - n[0] * 2, b1[1] - n[1] * 2), (b1[0] + n[0] * 4.5, b1[1] + n[1] * 4.5), (b2[0] + n[0] * 1.5, b2[1] + n[1] * 1.5), b2],
                  rr("teal", "cyan", "white"), edge=E))                                                  # glass blade
    S.append(oval(hx + (6 if se else -6), hy - 3, 3, 3.6, rr("grey3", "grey4", "white"), edge=E))      # thumb
    return S


def bancul_pile(se, dx):
    cx = 64 + dx
    S = bare_foot(24 + dx, 176, (0.89, 0.45), 0, True) + bare_foot(104 + dx, 170, (0.89, -0.45), 0, True, sole_up=True)
    pile = [(cx - 46, 178), (cx - 40, 160), (cx - 24, 150), (cx - 6, 146), (cx + 12, 150), (cx + 32, 148), (cx + 44, 162),
            (cx + 46, 178), (cx + 22, 186), (cx, 183), (cx - 24, 187)]
    S.append(poly(pile, rr("brown0", "brown1", "brown2"), edge=E, post=pelt_tufts(), light=(-2, -1)))
    S.append(path([(cx - 34, 160), (cx, 154), (cx + 34, 158)], 2.0, rr("brown2", "brown3", "straw"), edge=E))
    S.append(path([(cx + 6, 168), (cx + 24, 176)], 2.4, rr("grey3", "grey4", "white"), edge=E))
    S.append(oval(cx + 5, 167, 3.4, 2.6, rr("grey3", "grey4", "white"), edge=E))
    S.append(oval(cx + 25, 177, 3.4, 2.6, rr("grey3", "grey4", "white"), edge=E))
    return S


def surgeon_pile(se, dx):
    cx = 64 + dx
    S = bootie(22 + dx, 176, (0.89, 0.45), 0, True) + bootie(106 + dx, 170, (0.89, -0.45), 0, True, sole_up=True)
    pile = [(cx - 44, 178), (cx - 38, 160), (cx - 22, 150), (cx - 6, 144), (cx + 12, 149), (cx + 30, 147), (cx + 42, 162),
            (cx + 44, 178), (cx + 22, 186), (cx, 183), (cx - 24, 187)]
    S.append(poly(pile, ROBE, edge=E, light=(-2, -1), dither=True, cuts=[0.3, 0.62]))
    S.append(poly([(cx - 16, 152), (cx + 18, 150), (cx + 24, 172), (cx - 20, 176)], rr("blue0", "teal", "blue1"), edge=E))
    S.append(poly([(cx - 22, 148), (cx + 26, 148), (cx + 28, 156), (cx - 24, 156)], rr("grey0", "grey1", "grey2"), edge=E))
    S.append(oval(cx - 8, 152, 2.2, 2.2, [I["red1"], I["magenta"]], edge=E))
    S.append(oval(cx + 8, 152, 2.2, 2.2, [I["teal"], I["acid"]], edge=E))
    # the dropped scalpel
    S.append(poly([(cx + 30, 182), (cx + 58, 178), (cx + 59, 181), (cx + 32, 186)], rr("teal", "cyan", "white"), edge=E))
    S.append(path([(cx + 18, 186), (cx + 30, 184)], 2.4, rr("grey1", "grey2", "grey3"), edge=E))
    return S


POSES = {
    "idle": [dict(), dict(sway=1, drop=1, hand=1)],
    "walk": [dict(nlift=12, nfx=4, sway=-2, hand=-2), dict(sway=0), dict(flift=12, ffx=4, sway=2, hand=2), dict(sway=0)],
    "attack": [dict(nlift=30, nfx=-2, sway=-3, sole=True, hand=-20, jab=1),
               dict(nlift=0, nfx=6, sway=3, drop=2, hand=14, jab=2),
               dict(sway=1, drop=1, hand=6, jab=2)],
    "hit": [dict(dx=-4, sway=4, drop=2, hand=-4)],
    "death": [dict(crouch=10, drop=14, sway=2), dict(crouch=20, drop=44, sway=-3), dict(pile=True)],
}


def make(kind):
    def gen(spec):
        rows = []
        for facing in ("se", "ne"):
            for name, n, _, _ in C.ANIMS:
                row = []
                for p in POSES[name]:
                    if p.get("pile"):
                        shapes = surgeon_pile(facing == "se", 0) if kind == "surgeon" else bancul_pile(facing == "se", 0)
                    else:
                        shapes = build_giant(kind, facing, p)
                    row.append(R.render(shapes, GW, GH))
                rows.append(row)
        return rows
    return gen


GENERATORS = {"bancul_recruit": make("bancul"), "lobizi_surgeon": make("surgeon")}

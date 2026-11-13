"""Non-humanoid units on the shape rig: the wolf (48x48, feet at [24, 44]) and the Lobizi probe
drone (48x48, hovers above [24, 44], with a dithered ground shadow so the height reads).
Rows like every character: idle 2, walk 4, attack 3, hit 1, death 3, SE then NE.
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
BW, BH = 48, 48
GROUND = 44


def rr(*names):
    return [I[n] for n in names]


def rot(cx, cy, deg, ox=0.0, oy=0.0):
    a = math.radians(deg)
    return R.Affine(pivot=(cx, cy), m=((math.cos(a), -math.sin(a)), (math.sin(a), math.cos(a))), o=(cx + ox, cy + oy))


def ground_shadow(c, cx, cy, rx, ry):
    """Checkered outline-colour ellipse on empty pixels: reads as a shadow over any ground."""
    h, w = c.shape
    m = K.ellipse(w, h, (cx - rx, cy - ry, cx + rx - 1, cy + ry - 1))
    ys, xs = np.mgrid[0:h, 0:w]
    c[m & (c == K.T) & ((xs + ys) % 2 == 0)] = E


# ------------------------------------------------------------------ wolf

FUR = rr("grey1", "grey2", "grey3")
FUR_DARK = rr("grey0", "grey1", "grey2")


def wolf_shapes(facing, p):
    se = facing == "se"
    bx, by = 21 + p.get("dx", 0), 31 + p.get("dy", 0)
    hd = p.get("head", (0, 0))
    S = []
    legs = p.get("legs", [(0, 0)] * 4)  # foot offsets: far hind, far front, near hind, near front
    hips = [(bx - 6, by + 1), (bx + 6, by + 1), (bx - 7, by + 2), (bx + 5, by + 2)]
    for k, ((hx, hy), (fx, fy)) in enumerate(zip(hips, legs)):
        far = k < 2
        foot = (hx + fx + (1 if k % 2 else -1), GROUND - (1 if far else 0) + fy)
        knee = ((hx + foot[0]) / 2 + (-1.5 if k % 2 == 0 else 1), (hy + foot[1]) / 2)
        S.append(path([(hx, hy), knee, foot], 1.6 if not far else 1.4, FUR_DARK if far else FUR, edge=None if far else E))
        S.append(oval(foot[0] + 1, foot[1] - 0.5, 1.8, 1.0, rr("grey0", "grey1")))
    tail = p.get("tail", 0)
    S.insert(0 if se else len(S), path([(bx - 9, by - 2), (bx - 13, by + 0 - tail * 0.4), (bx - 16, by + 3 - tail)], 2.8, FUR))
    S.append(oval(bx, by, 10.5, 5.4, FUR))                       # body
    S.append(oval(bx + 2, by + 3.4, 6, 1.8, rr("grey2", "grey3", "grey4")))  # pale belly
    S.append(line([(bx - 7, by - 4.5), (bx + 5, by - 5)], I["grey1"]))       # dark saddle
    S.append(poly([(bx + 5, by - 5), (bx + 10, by - 8 + hd[1]), (bx + 14, by - 2 + hd[1]), (bx + 11, by + 2), (bx + 7, by + 4)], FUR, post=R.stripes(I["grey1"], 3, 1)))  # neck ruff
    hx, hy = bx + 13 + hd[0], by - 6 + hd[1]
    if se:
        jaw = p.get("jaw", 0)
        S.append(poly([(hx - 2, hy - 4), (hx - 0.5, hy - 9), (hx + 1.5, hy - 4)], FUR, edge=E))     # far ear
        S.append(oval(hx, hy, 5.2, 4.5, FUR))
        S.append(poly([(hx + 2, hy - 1.5), (hx + 9, hy + 0.5), (hx + 9, hy + 2.5), (hx + 2, hy + 2.5)], rr("grey2", "grey3", "grey4")))  # snout
        if jaw:
            S.append(poly([(hx + 1, hy + 2.5), (hx + 8, hy + 3 + jaw), (hx + 7, hy + 4.5 + jaw), (hx + 1, hy + 4)], rr("grey1", "grey2"), edge=E))
            S.append(line([(hx + 3, hy + 2.6), (hx + 8, hy + 2.6)], I["red1"]))
            S.append(dots([(hx + 4, hy + 2.4), (hx + 6.5, hy + 2.4), (hx + 5, hy + 3.4 + jaw)], I["white"]))
        S.append(dots([(hx + 9, hy + 0.5)], E))                                                       # nose
        S.append(poly([(hx - 4, hy - 2), (hx - 3.2, hy - 8), (hx - 0.8, hy - 3)], FUR, edge=E))       # near ear
        S.append(dots([(hx - 2.8, hy - 5)], I["skin1"]))
        if p.get("dead_eye"):
            S.append(dots([(hx + 1.5, hy - 1.5), (hx + 2.5, hy - 0.5), (hx + 2.5, hy - 1.5), (hx + 1.5, hy - 0.5)], E))
        elif p.get("wince"):
            S.append(line([(hx + 1, hy - 1), (hx + 3, hy - 1)], E))
        else:
            S.append(dots([(hx + 2, hy - 1)], I["straw"]))
            S.append(dots([(hx + 3, hy - 1)], E))
    else:
        S.append(oval(hx - 1, hy - 1, 4.4, 4.0, FUR))
        S.append(poly([(hx + 1, hy - 3), (hx + 6, hy - 6), (hx + 5, hy - 2)], rr("grey2", "grey3")))  # snout tip seen past the head
        S.append(poly([(hx - 5, hy - 2), (hx - 4, hy - 8), (hx - 1.5, hy - 3)], FUR, edge=E))
        S.append(poly([(hx - 1, hy - 3), (hx + 1, hy - 8.5), (hx + 2.5, hy - 2.5)], FUR, edge=E))
        S.append(line([(hx - 4, hy + 1), (hx - 1, hy + 3)], I["grey1"]))
    return S


WOLF_POSES = {
    "idle": [dict(), dict(dy=1, head=(0, 1), tail=1)],
    "walk": [dict(legs=[(2, 0), (-2, 0), (-2, 0), (2, 0)], dy=0),
             dict(legs=[(0, -1), (0, 0), (0, 0), (0, -1)], dy=-1),
             dict(legs=[(-2, 0), (2, 0), (2, 0), (-2, 0)], dy=0),
             dict(legs=[(0, 0), (0, -1), (0, -1), (0, 0)], dy=-1)],
    "attack": [dict(dx=-2, dy=1, head=(-1, 2), jaw=1, legs=[(1, 0), (-1, 0), (1, 0), (-1, 0)]),
               dict(dx=4, dy=-2, head=(2, 1), jaw=3, tail=3, legs=[(-3, -1), (5, -2), (-3, 0), (5, -1)]),
               dict(dx=3, dy=0, head=(2, 3), jaw=0, legs=[(-2, 0), (3, 0), (-2, 0), (3, 0)])],
    "hit": [dict(dx=-3, dy=-1, head=(-2, -1), wince=True, legs=[(2, 0), (0, 0), (2, 0), (0, 0)], tail=-2)],
}


def wolf_frames(spec):
    rows = []
    for facing in ("se", "ne"):
        for name, n, _, _ in C.ANIMS:
            row = []
            if name == "death":
                row.append(R.render(wolf_shapes(facing, dict(dx=-2, head=(-1, 2), wince=True)), BW, BH))
                row.append(R.render(wolf_shapes(facing, dict(head=(0, 2), wince=True)), BW, BH, xf=rot(22, GROUND, 25, 0, 0)))
                # on its back, legs in the air, tongue out: the classic
                f = R.render(wolf_shapes("se", dict(dead_eye=True, jaw=1, legs=[(0, -2), (0, -2), (0, -2), (0, -2)])), BW, BH,
                             xf=R.Affine(pivot=(22, 31), m=((1, 0), (0, -1)), o=(22, 36)))
                row.append(f)
            else:
                for p in WOLF_POSES[name]:
                    row.append(R.render(wolf_shapes(facing, p), BW, BH))
            rows.append(row)
    return rows


# ------------------------------------------------------------------ probe drone

HULL = rr("grey1", "grey2", "grey3", "grey4")


def drone_shapes(facing, p):
    se = facing == "se"
    cx, cy = 24, 21 + p.get("dy", 0)
    S = []
    arm = p.get("arm", 0)       # 0 tucked, 1..2 reaching forward
    # the probe arm hangs under the hull: a jointed cattle prod
    a0 = (cx + (2 if se else 3), cy + 3)
    a1 = (cx + 4 + arm * 3, cy + 9 - arm)
    a2 = (cx + 7 + arm * 5, cy + 13 - arm * 2)
    arm_shapes = [path([a0, a1], 0.9, rr("grey1", "grey3")), oval(a1[0], a1[1], 1.3, 1.3, rr("teal", "cyan")),
                  path([a1, a2], 0.8, rr("grey1", "grey3")),
                  line([(a2[0] - 1, a2[1] + 1), (a2[0] - 1, a2[1] + 3)], I["grey4"]),
                  line([(a2[0] + 1, a2[1]), (a2[0] + 2, a2[1] + 2)], I["grey4"])]
    if not se:
        S += arm_shapes
    # antenna with a light
    S.append(line([(cx - 3, cy - 6), (cx - 5, cy - 11)], I["grey2"]))
    S.append(dots([(cx - 5, cy - 12)], I["magenta"] if p.get("blink") else I["red1"]))
    # hull: a squat disc with a skirt, a glass dome on top
    S.append(oval(cx, cy + 1.5, 12, 4.6, rr("grey0", "grey1", "grey2")))
    S.append(oval(cx, cy, 12, 4.2, HULL, cuts=[0.3, 0.55, 0.8]))
    S.append(oval(cx - 0.5, cy - 3.5, 5.8, 3.8, rr("teal", "cyan"), cuts=[0.6]))
    S.append(dots([(cx - 3, cy - 5), (cx - 2, cy - 6)], I["white"]))
    if se:
        # the eye inside the dome looks at you (or at your cattle)
        S.append(oval(cx + 1.2, cy - 3.2, 1.4, 1.4, [I["white"]]))
        S.append(dots([(cx + 1.7, cy - 3)], E))
    lights = ["magenta", "acid", "cyan", "magenta", "acid"]
    for k, col in enumerate(lights):
        t = math.pi * (0.15 + 0.7 * k / (len(lights) - 1))
        S.append(dots([(cx - 11 * math.cos(t), cy + 2 + 1.6 * math.sin(t))], I[col if not p.get("dark") else "grey1"]))
    if se:
        # the cow decal: one per confirmed cow
        S.append(dots([(cx + 6, cy), (cx + 7, cy), (cx + 8, cy)], I["white"]))
        S.append(dots([(cx + 7, cy)], E))
        S.append(dots([(cx + 6, cy + 1), (cx + 8, cy + 1)], I["white"]))
        S += arm_shapes
    if p.get("zap"):
        z = (a2[0] + 1, a2[1] + 3)
        S.append(line([z, (z[0] + 3, z[1] - 2), (z[0] + 2, z[1] + 1), (z[0] + 6, z[1] + 0)], I["acid"]))
        S.append(line([(z[0], z[1] + 1), (z[0] + 1, z[1] + 4), (z[0] + 4, z[1] + 3)], I["cyan"]))
    return S


DRONE_POSES = {
    "idle": [dict(), dict(dy=-1, blink=True)],
    "walk": [dict(tilt=6), dict(tilt=6, dy=-1), dict(tilt=6, dy=-2, blink=True), dict(tilt=6, dy=-1)],
    "attack": [dict(arm=1, tilt=-4), dict(arm=2, tilt=10, zap=True, blink=True), dict(arm=1, tilt=4)],
    "hit": [dict(tilt=-14, dy=-2, spark=True, dark=True)],
}


def _sparks(c, pts, cols):
    for (x, y), col in zip(pts, cols):
        if 0 <= y < BH and 0 <= x < BW:
            c[y, x] = col


def drone_frames(spec):
    rows = []
    for facing in ("se", "ne"):
        for name, n, _, _ in C.ANIMS:
            row = []
            if name == "death":
                plist = [dict(tilt=-20, dy=2, dark=True, spark=True), dict(tilt=35, dy=12, dark=True), "crash"]
            else:
                plist = DRONE_POSES[name]
            for p in plist:
                if p == "crash":
                    f = R.render(drone_shapes(facing, dict(dark=True)), BW, BH, xf=rot(24, 21, 18, 0, 17))
                    # a cracked dome and a little smoke
                    _sparks(f, [(21, 32), (22, 33), (23, 32)], [E, E, E])
                    smoke = R.render([oval(30, 26, 3, 2.4, rr("grey2", "grey3", "grey4")), oval(33, 21, 2.2, 1.8, rr("grey2", "grey3", "grey4"))], BW, BH)
                    m = (smoke != K.T) & (f == K.T)
                    f[m] = smoke[m]
                    ground_shadow(f, 24, GROUND - 1, 12, 3)
                else:
                    f = R.render(drone_shapes(facing, p), BW, BH, xf=rot(24, 21, p.get("tilt", 0)) if p.get("tilt") else None)
                    if p.get("spark"):
                        _sparks(f, [(15, 13), (14, 12), (33, 15), (34, 14), (16, 15)], [I["white"], I["cyan"], I["white"], I["acid"], I["cyan"]])
                    shadow_r = 8 if p.get("dy", 0) < 8 else 10
                    ground_shadow(f, 24, GROUND - 1, shadow_r, 2.5)
                row.append(f)
            rows.append(row)
    return rows


GENERATORS = {"wolf": wolf_frames, "probe_drone": drone_frames}

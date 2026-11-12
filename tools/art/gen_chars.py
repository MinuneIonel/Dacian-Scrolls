"""Characters: a humanoid rig (32x48 frames) dressed by a gear spec, and the giant's legs (128x192).

Drawn facing south-east (front three-quarter) and north-east (back three-quarter) only.
Sheet rows (manifest "frames"): idle 2, walk 4, attack 3, hit 1, death 3, first SE then NE (`*_ne`).
"""
import math

import kit as K
import palette as P
import rig as R
from rig import poly, oval, path, dots, line

I = P.IDX
FW, FH = 32, 48
GROUND = 44

ANIMS = [  # name, frames, fps, loop
    ("idle", 2, 2.0, True),
    ("walk", 4, 8.0, True),
    ("attack", 3, 10.0, False),
    ("hit", 1, 6.0, False),
    ("death", 3, 6.0, False),
]

# ------------------------------------------------------------------ poses
# bob: upper body dy; lean: shoulders dx; hip: hips dy; nf/ff: near/far foot offsets;
# wa: weapon hand offset from the near shoulder; wang: blade angle, 0 = up, 90 = forward;
# sh: shield offset; nk/fk: knee overrides (absolute offsets from the hip joint) for kneeling.
BASE = dict(bob=0, lean=0, hip=0, nf=(0, 0), ff=(0, 0), wa=(-3, 9), wang=-8, sh=(0, 0), head=(0, 0),
            nk=None, fk=None, farm=(0, 0), weapon=True)


def poses(kind):
    """kind: 'blade' (falx and shield) or 'spear'."""
    blade = kind == "blade"
    idle = [dict(), dict(bob=1, wa=(-3, 10), sh=(0, 1))]
    walk = [
        dict(nf=(2, 1), ff=(-2, -1), lean=1, wa=(-2, 9), wang=-4),
        dict(hip=-1, bob=0, nf=(0, 0), ff=(0, 0), lean=1, wang=-8),
        dict(nf=(-2, -1), ff=(2, 1), lean=1, wa=(-4, 9), wang=-12),
        dict(hip=-1, bob=0, nf=(0, 0), ff=(0, 0), lean=1, wang=-8),
    ]
    if blade:
        attack = [
            dict(lean=-1, wa=(-2, -6), wang=-40, sh=(1, -1), nf=(-1, 0)),
            dict(lean=2, hip=1, wa=(7, 4), wang=115, sh=(1, 0), nf=(2, 1), ff=(-2, -1)),
            dict(lean=1, hip=1, wa=(4, 9), wang=150, sh=(0, 1), nf=(2, 1), ff=(-2, -1)),
        ]
    else:
        attack = [
            dict(lean=-1, wa=(-4, 6), wang=60, nf=(-1, 0)),
            dict(lean=2, wa=(5, 6), wang=80, nf=(2, 1), ff=(-2, -1)),
            dict(lean=1, wa=(2, 7), wang=72, nf=(2, 1), ff=(-2, -1)),
        ]
    hit = [dict(lean=-2, head=(-1, 0), wa=(-4, 7), wang=-10, sh=(-1, -1), nf=(-1, 0), ff=(-1, 0))]
    death = [
        dict(lean=-2, hip=2, head=(-1, 1), wa=(-5, 8), wang=-30, sh=(-1, 1)),
        dict(lean=1, hip=8, bob=1, head=(1, 1), wa=(-2, 6), wang=120, sh=(0, 2),
             nk=(3, 6), fk=(5, 5), nf=(0, 0), ff=(1, 0)),
        "lying",
    ]
    out = {}
    for name, lst in (("idle", idle), ("walk", walk), ("attack", attack), ("hit", hit), ("death", death)):
        out[name] = [p if p == "lying" else {**BASE, **p} for p in lst]
    return out


# ------------------------------------------------------------------ humanoid

def humanoid(g, facing, p):
    """Shapes for one frame. g = gear spec dict, facing 'se' or 'ne', p = pose dict."""
    se = facing == "se"
    near = -1 if se else 1          # screen side of the weapon arm
    fwd = 1                          # both facings move to screen-right
    hx = 16
    hy = 30 + p["hip"]
    sx = hx + p["lean"]
    sy = 19 + p["hip"] + p["bob"]
    E = I["outline"]
    S = []

    trousers = g["trousers"]; boots = g["boots"]; sleeve = g["sleeve"]

    def leg(side, foot_off, knee_override, far):
        hipj = (hx + 2 * side, hy + (0 if far else 1))
        foot = (hx + 3 * side + foot_off[0], GROUND - (1 if far else 0) + foot_off[1])
        if knee_override is not None:
            knee = (hipj[0] + knee_override[0], hipj[1] + knee_override[1])
            foot = (knee[0] - 1 + foot_off[0], min(GROUND, knee[1] + 2) + foot_off[1])
            ankle = (knee[0] - 3, knee[1] + 1)
            toe = (ankle[0] - 2, ankle[1])
        else:
            knee = ((hipj[0] + foot[0]) / 2 + 1 * fwd, (hipj[1] + foot[1]) / 2)
            ankle = (foot[0], foot[1] - 2)
            toe = (foot[0] + 2 * fwd, foot[1])
        r = []
        r.append(path([hipj, knee, ankle], 1.5, trousers, edge=E if not far else None))
        r.append(path([ankle, (foot[0], foot[1]), toe], 1.2, boots))
        if g.get("wraps"):
            r.append(line([(ankle[0] - 1, ankle[1] - 1), (ankle[0] + 1, ankle[1] - 2)], g["wraps"]))
        return r

    far_leg = leg(-near, p["ff"], p["fk"], True)
    near_leg = leg(near, p["nf"], p["nk"], False)

    # torso
    torso = poly([(sx - 5, sy), (sx + 5, sy), (sx + 6, sy + 2), (hx + 4, hy - 1), (hx - 4, hy - 1), (sx - 6, sy + 2)],
                 g["armour"], post=g.get("armour_post"))
    belt = poly([(hx - 5, hy - 3), (hx + 5, hy - 3), (hx + 5, hy - 1), (hx - 5, hy - 1)], g["belt"], edge=E)
    skirt = poly([(hx - 5, hy - 1), (hx + 5, hy - 1), (hx + 6, hy + 4), (hx - 6, hy + 4)], g["skirt"],
                 post=R.stripes(g["skirt"][0], 3, vertical=True))

    # head
    hcx = sx + (1 if se else -1) + p["head"][0]
    hcy = sy - 6 + p["head"][1]
    head = list(g["helm_under"](hcx, hcy, se)) if g.get("helm_under") else []
    hr = g.get("head_r", (3.6, 4.2))
    if se:
        head.append(oval(hcx, hcy, hr[0], hr[1], g["skin"]))
        if g.get("beard"):
            head.append(poly([(hcx - 1, hcy + 2), (hcx + 3.5, hcy + 2), (hcx + 2.5, hcy + 5), (hcx, hcy + 5)], g["beard"]))
        head.append(dots([(hcx + 2, hcy - 1)], g.get("eye", E)))
        if g.get("eye2"):
            head.append(dots([(hcx - 1, hcy - 1)], g["eye2"]))
    else:
        head.append(oval(hcx, hcy, hr[0], hr[1], g["skin"]))
        if g.get("beard"):
            head.append(poly([(hcx + 1, hcy + 1), (hcx + 4, hcy + 1), (hcx + 3, hcy + 4)], g["beard"]))
    head += g["helm"](hcx, hcy, se)

    # arms
    nsh = (sx + 4 * near, sy + 1)
    hand = (nsh[0] + p["wa"][0] * (1 if se else 1) + (0 if se else 4), nsh[1] + p["wa"][1])
    elbow = ((nsh[0] + hand[0]) / 2 + near * 1.5, (nsh[1] + hand[1]) / 2)
    near_arm = [path([nsh, elbow], 1.4, sleeve, edge=E),
                path([elbow, hand], 1.3, g["forearm"], edge=E),
                oval(hand[0], hand[1], 1.3, 1.3, g["skin"])]
    fsh = (sx - 4 * near, sy + 1)
    fhand = (fsh[0] - near * 1 + p["farm"][0], fsh[1] + 8 + p["farm"][1])
    far_arm = [path([fsh, ((fsh[0] + fhand[0]) / 2 - near, (fsh[1] + fhand[1]) / 2), fhand], 1.3, sleeve),
               oval(fhand[0], fhand[1], 1.2, 1.2, g["skin"])]

    weapon = g["weapon"](hand, p["wang"], se) if p["weapon"] else []
    shield = g["shield"](fhand[0] + p["sh"][0], fhand[1] + p["sh"][1] - 1, se) if g.get("shield") else []

    back = g["back"](sx, sy, hx, hy, se) if g.get("back") else []
    over = g["over"](sx, sy, hx, hy, se) if g.get("over") else []

    if se:
        S += back + far_arm[:0]
        S += far_leg + near_leg
        S += far_arm + [skirt, torso, belt] + over + head + shield + near_arm + weapon
    else:
        # back view: shield (held forward) is beyond the body, weapon arm in front
        S += shield + far_arm + far_leg + near_leg + [skirt, torso, belt] + head + back + over + near_arm + weapon
    return S


def lying_xf(facing):
    if facing == "se":   # fell back toward north-west: head upper-left
        return R.Affine(pivot=(16, GROUND), m=((0.72, 0.66), (-0.36, 0.30)), o=(25, 42))
    return R.Affine(pivot=(16, GROUND), m=((0.72, 0.66), (-0.36, -0.29)), o=(28, 33))


def human_frames(g):
    ps = poses(g["kind"])
    rows = []
    for facing in ("se", "ne"):
        for name, n, _, _ in ANIMS:
            row = []
            for p in ps[name]:
                if p == "lying":
                    q = {**BASE, "weapon": False, "wa": (-3, 7), "wang": 0}
                    shapes = humanoid(g, "se", q)
                    f = R.render(shapes, FW, FH, xf=lying_xf(facing))
                    if g.get("dropped"):
                        g["dropped"](f, facing)
                else:
                    f = R.render(humanoid(g, facing, p), FW, FH)
                row.append(f)
            rows.append(row)
    return rows


# ------------------------------------------------------------------ gear pieces

def falx(hand, ang, se):
    a = math.radians(ang)
    d = (math.sin(a), -math.cos(a))
    n = (math.cos(a), math.sin(a))      # forward side, where the falx curves to

    def at(t, k):
        return (hand[0] + d[0] * t + n[0] * k, hand[1] + d[1] * t + n[1] * k)
    grip = path([at(-3, 0), at(0.5, 0)], 0.8, [I["brown0"], I["brown2"]])
    guard = dots([at(1, 0)], I["ochre"])
    blade = path([at(1.5, 0), at(5, -0.6), at(9, -0.2), at(12, 1.4), at(13.5, 3.8)], 1.0,
                 [I["grey2"], I["grey4"]], cuts=[0.55])
    edge = line([at(5, 0.4), at(9, 0.8), at(11.5, 2.4)], I["white"])
    return [grip, blade, edge, guard]


def spear(hand, ang, se):
    a = math.radians(ang)
    d = (math.sin(a), -math.cos(a))

    def at(t):
        return (hand[0] + d[0] * t, hand[1] + d[1] * t)
    shaft = path([at(-9), at(15)], 0.6, [I["grey1"], I["silk0"]])
    bands = dots([at(-4), at(8)], I["magenta"])
    head = oval(*at(18), 1.8, 1.8, [I["teal"], I["cyan"]])
    glint = dots([at(18.6)], I["white"])
    return [shaft, bands, head, glint]


def round_shield(cx, cy, se):
    if se:
        return [oval(cx + 1, cy, 5.2, 6.0, [I["ochre"], I["straw"]], edge=I["outline"], cuts=[0.6]),
                oval(cx + 1, cy, 4.0, 4.8, [I["blue0"], I["blue1"], I["blue2"]]),
                Rring(cx + 1, cy, 2.6, 3.2, I["ochre"]),
                oval(cx + 1, cy, 1.2, 1.4, [I["brown2"], I["straw"]])]
    # seen from behind: the rim and the wooden back, mostly hidden by the body
    return [oval(cx - 1, cy - 1, 5.2, 6.0, [I["ochre"], I["straw"]], cuts=[0.6]),
            oval(cx - 1, cy - 1, 4.0, 4.8, [I["brown0"], I["brown1"], I["brown2"]]),
            line([(cx - 4, cy - 1), (cx + 2, cy - 1)], I["brown0"])]


def Rring(cx, cy, rx, ry, col):
    return R.Shape("line", R.circle_pts(cx, cy, rx, ry, 14) + [R.circle_pts(cx, cy, rx, ry, 14)[0]], [col])


def wolf_helm(hcx, hcy, se):
    """Bronze cap under a wolf-head hood: ears up, snout over the brow (the Draco wolf, worn)."""
    pelt = [I["grey1"], I["grey2"], I["grey3"]]
    bronze = [I["brown2"], I["ochre"], I["straw"]]
    E = I["outline"]
    if se:
        return [
            # hood falling behind the head
            poly([(hcx - 4.5, hcy - 4), (hcx - 1, hcy - 4), (hcx - 2, hcy + 2), (hcx - 4, hcy + 4), (hcx - 5.5, hcy + 1)], pelt),
            # bronze brow band
            poly([(hcx - 3.5, hcy - 4), (hcx + 4, hcy - 4), (hcx + 4, hcy - 2), (hcx - 3.5, hcy - 2)], bronze, edge=E),
            # wolf skull, ears, snout
            oval(hcx - 0.5, hcy - 5.5, 3.6, 2.0, pelt),
            poly([(hcx - 3.5, hcy - 6), (hcx - 3, hcy - 10), (hcx - 1, hcy - 6.5)], pelt),
            poly([(hcx - 0.5, hcy - 6.5), (hcx + 1, hcy - 9.5), (hcx + 2, hcy - 5.5)], pelt),
            poly([(hcx + 1, hcy - 6.5), (hcx + 6.5, hcy - 5), (hcx + 6, hcy - 3.5), (hcx + 1, hcy - 4)], pelt),
            dots([(hcx + 6, hcy - 5)], E),             # nose
            dots([(hcx + 2, hcy - 6)], I["ochre"]),    # wolf eye
        ]
    return [
        oval(hcx, hcy - 1, 4.0, 4.6, pelt),
        poly([(hcx - 2, hcy + 2), (hcx + 2, hcy + 2), (hcx + 1, hcy + 6), (hcx - 1, hcy + 6)], pelt),
        poly([(hcx - 3.5, hcy - 4), (hcx - 3, hcy - 9), (hcx - 0.5, hcy - 5)], pelt),
        poly([(hcx + 0.5, hcy - 5), (hcx + 2.5, hcy - 9), (hcx + 3.5, hcy - 4)], pelt),
        dots([(hcx - 1, hcy), (hcx + 1, hcy + 2), (hcx, hcy - 2)], I["grey1"]),
        poly([(hcx + 2, hcy - 5), (hcx + 6, hcy - 7), (hcx + 5.5, hcy - 5), (hcx + 3, hcy - 3)], pelt),
        dots([(hcx + 4, hcy + 1)], I["skin1"]),
    ]


def pelt_cape(sx, sy, hx, hy, se):
    pelt = [I["grey1"], I["grey2"], I["grey3"]]
    if se:
        return [poly([(sx - 5, sy - 1), (sx - 1, sy), (hx - 3, hy + 2), (hx - 6, hy + 5), (hx - 8, hy + 3)], [I["red0"], I["red1"]])]
    return []


def pelt_over(sx, sy, hx, hy, se):
    pelt = [I["grey1"], I["grey2"], I["grey3"]]
    E = I["outline"]
    if se:
        return [poly([(sx - 6, sy - 1), (sx + 3, sy - 1), (sx + 2, sy + 2), (sx - 3, sy + 3), (sx - 7, sy + 2)], pelt),
                dots([(sx - 4, sy + 3), (sx + 1, sy + 2)], I["grey1"])]
    # back view: red cloak with the pelt over the shoulders
    return [poly([(sx - 6, sy), (sx + 6, sy), (hx + 5, hy + 3), (hx + 1, hy + 5), (hx - 5, hy + 4)], [I["red0"], I["red1"]],
                 edge=E, post=R.stripes(I["red0"], 3, vertical=True)),
            poly([(sx - 6, sy - 1), (sx + 6, sy - 1), (sx + 5, sy + 3), (sx, sy + 4), (sx - 5, sy + 3)], pelt),
            dots([(sx - 2, sy + 2), (sx + 3, sy + 1)], I["grey1"])]


def falx_dropped(f, facing):
    # the falx lies beside the body
    sh = [path([(4, 45), (8, 44)], 0.6, [I["brown0"], I["brown2"]]),
          path([(8, 44), (13, 44), (17, 43), (19, 41)], 0.7, [I["grey2"], I["grey4"]])]
    top = R.render(sh, FW, FH, outline=False)
    m = (top != K.T) & (f == K.T)
    f[m] = top[m]
    K.outline(f)


def bubble_under(hcx, hcy, se):
    # the glass bowl, drawn behind the head: pale glass, cyan rim
    return [oval(hcx, hcy - 0.5, 5.4, 5.6, [I["blue1"], I["blue2"]], cuts=[0.8]),
            R.Shape("line", R.circle_pts(hcx, hcy - 0.5, 5.4, 5.6, 24) + [R.circle_pts(hcx, hcy - 0.5, 5.4, 5.6, 24)[0]], [I["cyan"]])]


def bubble_helm(hcx, hcy, se):
    E = I["outline"]
    pts = R.circle_pts(hcx, hcy - 0.5, 5.4, 5.6, 24)
    return [
        R.Shape("line", pts[14:19], [I["white"]]),     # glint, upper left
        dots([(hcx - 3, hcy - 2)], I["white"]),
        # collar ring that seals the bowl
        poly([(hcx - 4.5, hcy + 4), (hcx + 4.5, hcy + 4), (hcx + 3.5, hcy + 6), (hcx - 3.5, hcy + 6)], [I["grey1"], I["grey2"], I["grey3"]], edge=E),
        dots([(hcx + (1 if se else -1), hcy + 5)], I["acid"]),
    ]


def thrall_back(sx, sy, hx, hy, se):
    if se:
        return []
    # back view: an air tank with a glowing tube to the helmet
    return [poly([(sx - 3, sy + 1), (sx + 3, sy + 1), (sx + 3, sy + 8), (sx - 3, sy + 8)], [I["grey1"], I["grey2"], I["grey3"]], edge=I["outline"]),
            dots([(sx - 1, sy + 3), (sx + 1, sy + 3)], I["magenta"]),
            line([(sx, sy + 1), (sx, sy - 2)], I["cyan"])]


def thrall_over(sx, sy, hx, hy, se):
    if not se:
        return []
    # chest box with buttons
    return [poly([(sx, sy + 3), (sx + 4, sy + 3), (sx + 4, sy + 7), (sx, sy + 7)], [I["grey1"], I["grey2"], I["grey3"]], edge=I["outline"]),
            dots([(sx + 1, sy + 4)], I["magenta"]), dots([(sx + 3, sy + 4)], I["acid"]), dots([(sx + 2, sy + 6)], I["cyan"])]


def spear_dropped(f, facing):
    sh = [path([(3, 45), (18, 42)], 0.5, [I["grey1"], I["silk0"]]), oval(21, 41.5, 1.6, 1.6, [I["teal"], I["cyan"]])]
    top = R.render(sh, FW, FH, outline=False)
    m = (top != K.T) & (f == K.T)
    f[m] = top[m]
    K.outline(f)


GEAR = {
    "knight": dict(
        kind="blade", shield=True,
        skin=[I["skin0"], I["skin1"], I["skin2"]], beard=[I["brown0"], I["brown1"]],
        trousers=[I["brown0"], I["brown1"], I["brown2"]], boots=[I["outline"], I["brown0"], I["brown1"]],
        wraps=I["brown3"],
        sleeve=[I["red0"], I["red1"]], forearm=[I["brown0"], I["brown1"], I["ochre"]],
        armour=[I["brown2"], I["ochre"], I["straw"]], armour_post=R.scales(I["brown1"], I["straw"]),
        belt=[I["brown0"], I["brown1"], I["brown2"]], skirt=[I["red0"], I["red1"]],
        helm=wolf_helm, weapon=falx, back=pelt_cape, over=pelt_over, dropped=falx_dropped,
    ),
    "grazi_thrall": dict(
        kind="spear", shield=False,
        skin=[I["skin0"], I["skin1"], I["skin2"]], eye=I["cyan"], eye2=I["cyan"],
        trousers=[I["blue0"], I["blue1"], I["blue2"]], boots=[I["outline"], I["grey0"], I["grey1"]],
        sleeve=[I["silk0"], I["white"]], forearm=[I["skin0"], I["skin1"], I["skin2"]],
        armour=[I["silk0"], I["white"]], armour_post=R.stripes(I["silk0"], 3, vertical=True),
        belt=[I["teal"], I["cyan"]], skirt=[I["silk0"], I["white"]],
        helm=bubble_helm, helm_under=bubble_under, head_r=(3.0, 3.6), weapon=spear, back=thrall_back, over=thrall_over, dropped=spear_dropped,
    ),
}
GEAR["knight"]["shield"] = round_shield


def knight(spec):
    return human_frames(GEAR["knight"])


def grazi_thrall(spec):
    return human_frames(GEAR["grazi_thrall"])


# ------------------------------------------------------------------ the giant, waist down

GW, GH = 128, 192
ROBE = [I["silk0"], I["grey4"], I["white"]]
SKIN = [I["skin0"], I["skin1"], I["skin2"]]


def ground_oval(cx, cy, fwd, length, width, n=24):
    """Ellipse lying on the iso ground plane: fwd is a unit screen vector along the ground."""
    side = (fwd[0], -fwd[1])  # the other ground axis
    pts = []
    for k in range(n):
        t = 2 * math.pi * k / n
        a, b = math.cos(t) * length / 2, math.sin(t) * width / 2
        pts.append((cx + fwd[0] * a + side[0] * b, cy + fwd[1] * a + side[1] * b))
    return pts


def sandal(cx, cy, fwd, lift=0, se=True, sole_up=False):
    """A huge sandal with a foot in it. (cx, cy) = middle of the sole on the ground."""
    E = I["outline"]
    cy -= lift
    S = []
    L, Wd = 40, 17
    S.append(poly([(x, y + 3) for x, y in ground_oval(cx, cy, fwd, L + 4, Wd + 3)], [I["brown0"], I["brown1"]], cuts=[0.5]))
    S.append(poly(ground_oval(cx, cy, fwd, L + 4, Wd + 3), [I["brown1"], I["brown2"], I["brown3"]]))
    if sole_up:
        return S
    foot = ground_oval(cx - fwd[0] * 1, cy - 4 - fwd[1] * 1, fwd, L - 2, Wd - 3)
    S.append(poly(foot, SKIN, edge=E))
    fx, fy = fwd
    side = (fx, -fy)
    if se:
        # toes along the front edge
        for k, off in enumerate((-5.5, -2.8, 0, 2.6, 5.0)):
            r = 2.4 if k == 0 else 1.9
            tx = cx + fx * (L / 2 - 4) + side[0] * off
            ty = cy - 4 + fy * (L / 2 - 4) + side[1] * off
            S.append(oval(tx, ty, r + 0.6, r, SKIN, edge=E))
            S.append(dots([(tx - 0.5, ty - 0.8)], I["white"]))
        # straps
        for t in (-2, 8):
            a = (cx + fx * t - side[0] * 8, cy - 5 + fy * t - side[1] * 8)
            b = (cx + fx * t + side[0] * 8, cy - 5 + fy * t + side[1] * 8)
            S.append(path([a, b], 1.4, [I["brown2"], I["ochre"], I["straw"]], edge=E))
    else:
        # back view: heel strap and the laces up the calf
        hx, hy = cx - fx * (L / 2 - 6), cy - 6 - fy * (L / 2 - 6)
        S.append(path([(hx - 7, hy - 1), (hx, hy + 2), (hx + 7, hy - 1)], 1.4, [I["brown2"], I["ochre"], I["straw"]], edge=E))
    return S


def giant_shapes(facing, p):
    se = facing == "se"
    E = I["outline"]
    S = []
    dx = p.get("dx", 0)
    hem = 118 + p.get("drop", 0)
    sway = p.get("sway", 0)
    fwd = (0.89, 0.45) if se else (0.89, -0.45)
    # foot positions (on the ground), legs from under the robe
    nfx, nfy = (44 + dx, 176) if se else (76 + dx, 178)
    ffx, ffy = (84 + dx, 164) if se else (44 + dx, 164)
    nl, fl = p.get("nlift", 0), p.get("flift", 0)
    nfx += p.get("nfx", 0); ffx += p.get("ffx", 0)
    crouch = p.get("crouch", 0)

    def leg(fx, fy, lift, r, near):
        knee_x = fx + (6 if se else -6) * (crouch / 20)
        top = (fx - (4 if se else -4) + crouch * (0.6 if near else -0.6), hem - 20)
        ankle = (fx - fwd[0] * 10, fy - lift - 12 - fwd[1] * 10)
        return [path([top, (knee_x + crouch * 0.4, (top[1] + ankle[1]) / 2), ankle], r, SKIN, edge=E if near else None)]

    near = leg(nfx, nfy, nl, 8.5, True) + sandal(nfx, nfy, fwd, nl, se, sole_up=p.get("sole", False))
    far = leg(ffx, ffy, fl, 8, False) + sandal(ffx, ffy, fwd, fl, se)
    # robe: waist off the top, flaring to a wavy hem
    top_w = 36
    hem_w = 56
    cxr = 64 + dx
    ty = -2
    left = [(cxr - top_w, ty), (cxr - hem_w + sway, hem - 4)]
    wav = []
    for k in range(13):
        x = cxr - hem_w + sway + k * (2 * hem_w) / 12
        y = hem + (3 if k % 2 else -1) + (sway * (k - 6) / 10)
        wav.append((x, y))
    right = [(cxr + hem_w + sway, hem - 4), (cxr + top_w, ty)]
    robe_pts = left + wav + right

    def folds(c, m):
        h, w = c.shape
        import numpy as np
        ys, xs = np.mgrid[0:h, 0:w]
        # long vertical folds: shadow lines that widen downward, with a lit seam beside each
        for k, fx0 in enumerate((-22, -9, 4, 17, 30)):
            spread = (ys / max(hem, 1)) * (1.5 + 0.6 * k)
            fx = cxr + fx0 * (0.8 + 0.5 * ys / max(hem, 1)) + sway * ys / max(hem, 1)
            shadow = m & (np.abs(xs - fx) < 0.6 + spread * 0.25) & (ys > 6)
            c[shadow & (c != I["white"])] = I["silk0"]
            c[shadow & (c == I["white"])] = I["grey4"]
            lit = m & (np.abs(xs - (fx - 2 - spread * 0.3)) < 0.5) & (ys > 10)
            c[lit & (c == I["grey4"])] = I["white"]
        # trim band near the hem: teal line with cyan studs
        band = m & (ys > hem - 12) & (ys < hem - 8)
        c[band] = I["teal"]
        c[band & ((xs + ys) % 6 == 0)] = I["cyan"]
    robe = poly(robe_pts, ROBE, edge=E, post=folds, light=(-2, -1), dither=True, cuts=[0.34, 0.74])
    # sash at the waist, glass buttons
    sash = []
    d0 = p.get("drop", 0)
    if se:
        sash.append(poly([(cxr - 37, ty), (cxr + 37, ty), (cxr + 38, ty + 14), (cxr - 38, ty + 14)], [I["blue0"], I["blue1"], I["blue2"]], edge=E))
        for k, col in enumerate(("magenta", "acid", "cyan", "magenta")):
            bx = cxr - 12 + k * 8
            sash.append(oval(bx, ty + 7, 2.4, 2.4, [I["teal"], I[col]] if col != "magenta" else [I["red1"], I["magenta"]], edge=E))
            sash.append(dots([(bx - 1, ty + 6)], I["white"]))
        # a dangling remote on a cord
        sash.append(line([(cxr + 22, ty + 14), (cxr + 24, ty + 36)], I["grey1"]))
        sash.append(poly([(cxr + 21, ty + 36), (cxr + 28, ty + 36), (cxr + 28, ty + 46), (cxr + 21, ty + 46)], [I["grey1"], I["grey2"], I["grey3"]], edge=E))
        sash.append(dots([(cxr + 23, ty + 39), (cxr + 26, ty + 39)], I["acid"]))
        sash.append(dots([(cxr + 24, ty + 43)], I["magenta"]))
    else:
        sash.append(poly([(cxr - 37, ty), (cxr + 37, ty), (cxr + 38, ty + 14), (cxr - 38, ty + 14)], [I["blue0"], I["blue1"], I["blue2"]], edge=E))
        # bow and ribbons at the back
        sash.append(oval(cxr - 4, ty + 9, 6, 4, [I["blue0"], I["blue1"], I["blue2"]], edge=E))
        sash.append(path([(cxr - 6, ty + 12), (cxr - 10, ty + 42), (cxr - 8, ty + 54)], 2.0, [I["blue0"], I["blue1"], I["blue2"]], edge=E))
        sash.append(path([(cxr - 1, ty + 12), (cxr + 3, ty + 38), (cxr + 1, ty + 48)], 2.0, [I["blue0"], I["blue1"], I["blue2"]], edge=E))
    if p.get("pile"):
        return giant_pile(se, dx)
    return far + near + [robe] + sash if se else near[:0] + far + near + [robe] + sash


def giant_pile(se, dx):
    """Death, last frame: the robe has come down, sandals stick out."""
    E = I["outline"]
    cx = 64 + dx
    fwd = (0.89, 0.45) if se else (0.89, -0.45)
    S = sandal(22 + dx, 176, fwd, 0, se) + sandal(106 + dx, 170, (0.89, -0.45), 0, True, sole_up=True)
    pile = [(cx - 44, 178), (cx - 38, 160), (cx - 22, 150), (cx - 6, 144), (cx + 12, 149), (cx + 30, 147), (cx + 42, 162),
            (cx + 44, 178), (cx + 22, 186), (cx, 183), (cx - 24, 187)]
    S.append(poly(pile, ROBE, edge=E, light=(-2, -1), dither=True, cuts=[0.3, 0.62]))
    S.append(path([(cx - 28, 162), (cx - 8, 156), (cx + 16, 160), (cx + 34, 158)], 0.6, [I["silk0"]]))
    S.append(path([(cx - 32, 174), (cx - 6, 168), (cx + 26, 174)], 0.6, [I["silk0"]]))
    S.append(poly([(cx - 20, 150), (cx + 24, 150), (cx + 26, 158), (cx - 22, 158)], [I["blue0"], I["blue1"], I["blue2"]], edge=E))
    S.append(oval(cx - 6, 154, 2.4, 2.4, [I["red1"], I["magenta"]], edge=E))
    S.append(oval(cx + 6, 154, 2.4, 2.4, [I["teal"], I["acid"]], edge=E))
    return S


GIANT_POSES = {
    "idle": [dict(), dict(sway=1, drop=1)],
    "walk": [dict(nlift=12, nfx=4, sway=-2), dict(sway=0), dict(flift=12, ffx=4, sway=2), dict(sway=0)],
    "attack": [dict(nlift=34, nfx=-2, sway=-3, sole=True), dict(nlift=0, nfx=6, sway=3, drop=2), dict(sway=1, drop=1)],
    "hit": [dict(dx=-4, sway=4, drop=2)],
    "death": [dict(crouch=10, drop=14, sway=2), dict(crouch=20, drop=44, sway=-3), dict(pile=True)],
}


def giant_legs(spec):
    rows = []
    for facing in ("se", "ne"):
        for name, n, _, _ in ANIMS:
            row = []
            for p in GIANT_POSES[name]:
                row.append(R.render(giant_shapes(facing, p), GW, GH))
            rows.append(row)
    return rows

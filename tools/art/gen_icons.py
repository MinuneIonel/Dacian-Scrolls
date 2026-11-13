"""Icons (24x24), container props (32x32) and world-map markers (32x32).

Ability icons sit on a bevelled badge coloured by source: steel (iron rim, oxblood field),
magic (bronze rim, night-blue field), tech (steel rim, Lobizi teal field). Item icons are the
object alone on transparency. Props and markers stand on a ground point at (16, 26).
"""
import math

import numpy as np

import kit as K
import palette as P
import rig as R
from rig import poly, oval, path, dots, line

I = P.IDX
E = I["outline"]
S24 = 24


def rr(*names):
    return [I[n] for n in names]


STEEL = rr("grey1", "grey3", "grey4")
BRONZE = rr("brown2", "ochre", "straw")
WOOD = rr("brown0", "brown1", "brown2")
BONE = rr("grey3", "grey4", "white")
GLASS = rr("teal", "cyan", "white")


def Ring(cx, cy, rx, ry, col, n=18):
    pts = R.circle_pts(cx, cy, rx, ry, n)
    return R.Shape("line", pts + [pts[0]], [col])


BADGES = {
    "steel": dict(rim=("grey1", "grey3", "grey4"), field=("red0", "red1")),
    "magic": dict(rim=("brown1", "ochre", "straw"), field=("blue0", "blue1")),
    "tech": dict(rim=("grey1", "grey2", "grey3"), field=("outline", "teal")),
}


def badge(source):
    b = BADGES[source]
    n = S24
    c = K.canvas(n, n)
    ys, xs = np.mgrid[0:n, 0:n]
    d = np.minimum(np.minimum(xs, ys), np.minimum(n - 1 - xs, n - 1 - ys))
    lit = (xs + ys) < n - 1
    c[:, :] = I[b["field"][0]]
    # the field brightens toward the top-left
    c[(d >= 3) & ((xs + ys) < 18)] = I[b["field"][1]]
    c[(d == 1) | (d == 2)] = I[b["rim"][1]]
    c[((d == 1) | (d == 2)) & lit] = I[b["rim"][2]]
    c[((d == 2)) & ~lit] = I[b["rim"][0]]
    c[d == 0] = E
    c[(d == 3)] = I[b["field"][0]] if source != "tech" else E
    for x, y in ((1, 1), (n - 2, 1), (1, n - 2), (n - 2, n - 2)):
        c[y, x] = E
    return c


def glyph(shapes, n=S24):
    """Like rig.render, but keeps lone diagonal pixels: at 24 px a thin shaft is a diagonal line."""
    c = R.render(shapes, n, n, outline=False)
    return K.outline(c)


def on_badge(source, shapes):
    c = badge(source)
    g = glyph(shapes)
    # keep the badge's rim clear: glyph pixels only inside
    inner = np.zeros_like(c, bool)
    inner[3:-3, 3:-3] = True
    g[~inner] = K.T
    K.stamp(c, g, 0, 0)
    return c


# ------------------------------------------------------------------ reusable glyph parts

def falx_blade(x0, y0, x1, y1, ramp=None, edge_col=None):
    """A falx from the grip (x0, y0) to the tip (x1, y1), curving forward at the tip."""
    ramp = ramp or rr("grey2", "grey4")
    dx, dy = x1 - x0, y1 - y0
    L = math.hypot(dx, dy)
    ux, uy = dx / L, dy / L
    nx, ny = uy, -ux

    def at(t, k):
        return (x0 + ux * t * L + nx * k, y0 + uy * t * L + ny * k)
    S = [path([at(-0.05, 0), at(0.28, 0)], 1.0, WOOD),
         dots([at(0.3, 0)], I["ochre"]),
         path([at(0.33, 0), at(0.6, -0.4), at(0.85, 0.6), at(0.98, 2.6)], 1.3, ramp, cuts=[0.55])]
    S.append(line([at(0.45, 1.0), at(0.75, 1.4), at(0.9, 2.4)], edge_col if edge_col is not None else I["white"]))
    return S


def bone(x0, y0, x1, y1, r=1.2):
    return [path([(x0, y0), (x1, y1)], r, BONE),
            oval(x0 - 0.8, y0 - 1, 1.6, 1.6, BONE), oval(x0 + 0.8, y0 + 1, 1.6, 1.6, BONE),
            oval(x1 - 0.8, y1 - 1, 1.6, 1.6, BONE), oval(x1 + 0.8, y1 + 1, 1.6, 1.6, BONE)]


def staff(x0, y0, x1, y1):
    return [path([(x0, y0), (x1, y1)], 1.2, rr("brown1", "brown2", "brown3")),
            oval(x1, y1, 2.2, 2.2, rr("brown1", "brown2", "brown3")),
            dots([((x0 + x1) / 2, (y0 + y1) / 2)], I["brown0"])]


def star(cx, cy, r, col=I["white"], col2=I["straw"]):
    return [line([(cx - r, cy), (cx + r, cy)], col2), line([(cx, cy - r), (cx, cy + r)], col2),
            line([(cx - r * 0.6, cy - r * 0.6), (cx + r * 0.6, cy + r * 0.6)], col2), dots([(cx, cy)], col)]


def drone(cx, cy, s=1.0):
    return [oval(cx, cy + 1 * s, 8 * s, 3 * s, rr("grey0", "grey1", "grey2")),
            oval(cx, cy, 8 * s, 2.8 * s, rr("grey1", "grey2", "grey3", "grey4")),
            oval(cx - 0.5, cy - 2.5 * s, 4 * s, 2.6 * s, rr("teal", "cyan")),
            dots([(cx - 2 * s, cy - 3.5 * s)], I["white"]),
            dots([(cx - 6 * s, cy + 1), (cx, cy + 2.4 * s), (cx + 6 * s, cy + 1)], I["magenta"])]


def wolf_head(cx, cy, s=1.0):
    fur = rr("grey1", "grey2", "grey3")
    return [poly([(cx - 4 * s, cy - 2 * s), (cx - 3 * s, cy - 8 * s), (cx - 0.5 * s, cy - 3 * s)], fur),
            poly([(cx, cy - 3 * s), (cx + 2 * s, cy - 8 * s), (cx + 3 * s, cy - 2 * s)], fur),
            oval(cx, cy, 4.5 * s, 4 * s, fur),
            poly([(cx + 2 * s, cy - 1 * s), (cx + 9 * s, cy + 1 * s), (cx + 8.5 * s, cy + 3 * s), (cx + 2 * s, cy + 3 * s)], rr("grey2", "grey3", "grey4")),
            dots([(cx + 9 * s, cy + 1 * s)], E), dots([(cx + 1.5 * s, cy - 1 * s)], I["ochre"])]


def specimen_tank(cx, cy):
    return [oval(cx, cy + 7, 5.6, 2.4, rr("grey1", "grey2", "grey3")),
            poly([(cx - 4.6, cy - 6), (cx + 4.6, cy - 6), (cx + 4.6, cy + 6), (cx - 4.6, cy + 6)], rr("teal", "cyan"), light=(-1, 0)),
            oval(cx, cy - 1, 2.6, 1.6, rr("grey4", "white")), dots([(cx - 1, cy - 1), (cx + 1, cy)], E),
            oval(cx, cy - 7, 5.6, 2.4, rr("grey1", "grey2", "grey3")),
            line([(cx - 3, cy - 4), (cx - 3, cy + 3)], I["white"])]


def herbs(cx, cy):
    leaf = rr("green1", "green2", "green3", "green4")
    return [path([(cx - 1, cy + 7), (cx - 4, cy - 4)], 0.6, rr("green1", "green2")),
            path([(cx, cy + 7), (cx + 1, cy - 6)], 0.6, rr("green1", "green2")),
            path([(cx + 1, cy + 7), (cx + 5, cy - 3)], 0.6, rr("green1", "green2")),
            oval(cx - 5, cy - 5, 2.6, 1.8, leaf), oval(cx + 1, cy - 7, 2.2, 2.6, leaf), oval(cx + 6, cy - 4, 2.6, 1.8, leaf),
            oval(cx - 2, cy - 1, 2.2, 1.6, leaf), oval(cx + 3, cy, 2.2, 1.6, leaf),
            dots([(cx + 1, cy - 8), (cx - 5, cy - 6)], I["straw"]),
            path([(cx - 2, cy + 4), (cx + 2.5, cy + 4)], 0.8, rr("brown1", "brown3"))]


def jaws(cx, cy, s=1.0, blood=False):
    S = [poly([(cx - 8 * s, cy - 1), (cx, cy - 7 * s), (cx + 8 * s, cy - 1), (cx, cy - 3 * s)], rr("red0", "red1")),
         poly([(cx - 8 * s, cy + 1), (cx, cy + 6 * s), (cx + 8 * s, cy + 1), (cx, cy + 3 * s)], rr("red0", "red1"))]
    for k in range(5):
        x = cx - 6 * s + k * 3 * s
        yt = cy - 1 - (4 * s - abs(k - 2) * 1.5 * s)
        yb = cy + 1 + (3.5 * s - abs(k - 2) * 1.3 * s)
        S.append(poly([(x - 1, yt), (x + 1, yt), (x, yt + 2.4)], BONE))
        S.append(poly([(x - 1, yb), (x + 1, yb), (x, yb - 2.4)], BONE))
    if blood:
        S.append(oval(cx + 2, cy + 7 * s, 1.4, 2, rr("red1", "blood")))
    return S


# ------------------------------------------------------------------ ability glyphs

ABILITY = {
    "falx_strike": lambda: falx_blade(5, 19, 17, 5),
    "falx_sweep": lambda: falx_blade(6, 18, 16, 6) + [path([(4, 10), (8, 5), (14, 4), (19, 7)], 0.6, rr("grey4", "white")),
                                                     path([(5, 14), (10, 8), (17, 7)], 0.4, [I["grey4"]])],
    "dracos_ward": lambda: [path([(6, 21), (8, 6)], 0.7, WOOD)] + wolf_head(9, 8, 0.8) +
                           [path([(10, 11), (14, 13), (18, 11), (20, 14)], 1.4, rr("red0", "red1")),
                            path([(10, 13), (15, 16), (19, 15)], 1.0, rr("red0", "red1"))],
    "plasma_falx": lambda: falx_blade(5, 19, 17, 5, ramp=rr("teal", "cyan"), edge_col=I["white"]) +
                           [dots([(18, 9), (19, 11), (14, 4)], I["acid"]), dots([(20, 7)], I["white"])],
    "bone_dart": lambda: bone(8, 15, 16, 8) + [line([(3, 18), (6, 16)], I["grey4"]), line([(4, 21), (8, 18)], I["grey3"])],
    "bone_chill": lambda: bone(6, 16, 15, 8) + star(17, 15, 3, I["white"], I["blue2"]) + star(8, 6, 2, I["white"], I["blue2"]),
    "raise_strigoi": lambda: [oval(12, 18, 8, 3, rr("brown0", "brown1", "brown2")),
                              path([(12, 18), (12, 10)], 1.8, rr("green2", "grey3", "grey4")),
                              path([(10, 10), (9, 5)], 0.6, rr("grey3", "grey4")), path([(12, 9), (12, 4)], 0.6, rr("grey3", "grey4")),
                              path([(14, 10), (15, 5)], 0.6, rr("grey3", "grey4")), path([(13, 13), (16, 11)], 0.6, rr("grey3", "grey4")),
                              dots([(6, 17), (17, 19)], I["grey3"])],
    "reanimate_drone": lambda: drone(12, 13) + bone(14, 8, 18, 4, 0.8) + star(6, 6, 2, I["white"], I["grey4"]),
    "staff_smack": lambda: staff(6, 20, 15, 8) + star(17, 6, 3) + [dots([(19, 11), (12, 4)], I["straw"])],
    "blessing_of_zalmoxis": lambda: [oval(12, 12, 4.5, 4.5, BRONZE, edge=E), dots([(11, 11)], I["white"])] +
                                    [line([(12 + 6 * math.cos(a), 12 + 6 * math.sin(a)), (12 + 8.5 * math.cos(a), 12 + 8.5 * math.sin(a))], I["straw"])
                                     for a in np.linspace(0, 2 * math.pi, 9)[:-1]],
    "med_gel_field": lambda: [oval(12, 15, 8, 4, rr("green2", "green3", "acid")), oval(8, 10, 2, 2.4, rr("green3", "acid")),
                              oval(16, 8, 1.6, 2, rr("green3", "acid")), path([(12, 9), (12, 17)], 1.0, rr("teal", "cyan")),
                              path([(8, 13), (16, 13)], 1.0, rr("teal", "cyan")), dots([(6, 13)], I["white"])],
    "herb_poultice": lambda: herbs(12, 12),
    "wolf_bite": lambda: jaws(12, 12),
    "gladius_stab": lambda: [path([(5, 19), (8, 16)], 1.0, WOOD), line([(7, 14), (10, 17)], I["ochre"]),
                             path([(9, 15), (18, 6)], 1.4, rr("grey2", "grey4"), cuts=[0.5]), dots([(19, 5)], I["grey4"]),
                             dots([(4, 20)], I["ochre"])],
    "pilum_throw": lambda: [path([(3, 21), (15, 9)], 1.0, WOOD), path([(15, 9), (18, 6), (20, 6)], 0.6, rr("grey2", "grey4")),
                            line([(5, 14), (9, 11)], I["grey4"]), line([(10, 19), (13, 16)], I["grey3"])],
    "thrall_spear": lambda: [path([(4, 20), (16, 8)], 1.0, rr("grey1", "silk0")), oval(18, 6, 2.6, 2.6, rr("teal", "cyan")),
                             dots([(17, 5)], I["white"]), dots([(8, 16), (12, 12)], I["magenta"])],
    "strigoi_claw": lambda: [path([(6, 5), (10, 18)], 0.8, rr("red0", "blood")), path([(11, 4), (14, 18)], 0.8, rr("red0", "blood")),
                             path([(16, 5), (18, 17)], 0.8, rr("red0", "blood")), dots([(10, 20), (17, 19)], I["blood"])],
    "bancul_bite": lambda: jaws(12, 11, 1.1, blood=True),
    "probe_zap": lambda: [path([(4, 20), (12, 12)], 0.8, rr("grey1", "grey3")), line([(12, 12), (16, 10)], I["grey4"]), line([(12, 12), (14, 8)], I["grey4"]),
                          line([(16, 9), (19, 10), (17, 13), (20, 15)], I["acid"]), line([(14, 7), (16, 4), (18, 6)], I["cyan"])],
    "surgeon_scalpel": lambda: [path([(4, 20), (9, 15)], 1.4, rr("grey1", "grey2", "grey3")), dots([(6, 18)], I["magenta"]),
                                poly([(9, 14), (11, 16), (20, 4), (19, 4)], GLASS)],
    "surgeon_specimen_tank": lambda: specimen_tank(12, 12),
    "surgeon_gravity_well": lambda: [Ring(12, 15, 8, 3, I["magenta"]), Ring(12, 15, 5, 1.8, I["cyan"]), Ring(12, 15, 2, 0.8, I["white"]),
                                     oval(12, 7, 2.2, 2.2, rr("grey2", "grey3", "grey4")), dots([(7, 5), (17, 4)], I["white"])],
    "surgeon_anesthetic": lambda: [oval(10, 14, 6, 4.5, rr("green2", "green3", "green4")), oval(15, 12, 5, 4, rr("green2", "green3", "green4")),
                                   oval(12, 9, 4, 3, rr("green3", "green4")),
                                   line([(15, 3), (18, 3), (15, 6), (18, 6)], I["white"]), line([(19, 7), (21, 7), (19, 9), (21, 9)], I["white"])],
    "surgeon_call_drone": lambda: drone(10, 15, 0.9) + [R.Shape("line", R.circle_pts(15, 8, 3, 3, 16)[12:16], [I["cyan"]]),
                                                       R.Shape("line", R.circle_pts(15, 8, 6, 6, 20)[15:20], [I["cyan"]])],
}


# ------------------------------------------------------------------ item glyphs

def shirt(ramp, post=None, extra=()):
    S = [poly([(6, 6), (10, 4), (14, 4), (18, 6), (21, 11), (18, 12), (17, 10), (17, 20), (7, 20), (7, 10), (6, 12), (3, 11)], ramp, post=post)]
    S += list(extra)
    return S


def scales_post(dark, light):
    def f(c, m):
        h, w = c.shape
        ys, xs = np.mgrid[0:h, 0:w]
        inner = m & ~K.border(m)
        c[inner & (((xs + (ys // 2)) % 3) == 0) & (ys % 2 == 1)] = dark
    return f


def bands_post(c, m):
    h, w = c.shape
    ys, xs = np.mgrid[0:h, 0:w]
    inner = m & ~K.border(m)
    c[inner & (ys % 3 == 0)] = I["grey1"]
    c[inner & (ys % 3 == 1) & (xs < 12)] = I["grey4"]


ITEM = {
    "iron_falx": lambda: falx_blade(4, 20, 18, 4),
    "sica": lambda: [path([(6, 19), (9, 16)], 1.0, WOOD), line([(8, 14), (11, 17)], I["ochre"]),
                     path([(10, 15), (14, 10), (16, 9), (18, 10)], 1.1, rr("grey2", "grey4"), cuts=[0.5]), dots([(5, 20)], I["ochre"])],
    "oak_staff": lambda: staff(5, 21, 18, 4) + [oval(9, 15, 1.4, 1.4, rr("green2", "green3"))],
    "wolf_pelt": lambda: [poly([(5, 9), (10, 7), (16, 8), (20, 12), (19, 18), (14, 21), (8, 20), (4, 16)], rr("grey1", "grey2", "grey3"),
                               post=scales_post(I["grey1"], I["grey3"]))] + wolf_head(9, 8, 0.6) + [path([(19, 17), (22, 21)], 1.2, rr("grey1", "grey2"))],
    "scale_mail": lambda: shirt(BRONZE, post=scales_post(I["brown2"], I["straw"])),
    "roman_lorica": lambda: shirt(STEEL, post=bands_post, extra=[dots([(12, 8), (12, 14)], I["ochre"])]),
    "decoy_charm": lambda: [oval(12, 13, 6, 3.6, rr("brown2", "brown3", "straw")), oval(18, 9, 2.6, 2.4, rr("brown2", "brown3", "straw")),
                            path([(8, 15), (8, 21)], 0.7, rr("brown2", "brown3")), path([(15, 15), (15, 21)], 0.7, rr("brown2", "brown3")),
                            path([(7, 9), (7, 3)], 0.7, rr("brown2", "brown3")),   # very tall cow: the legs are the joke
                            dots([(10, 12), (14, 14)], I["brown1"]), dots([(19, 8)], E), line([(17, 6), (16, 5)], I["straw"])],
    "draco_pennant": lambda: [path([(6, 22), (6, 6)], 0.6, WOOD)] + wolf_head(8, 7, 0.65) +
                             [path([(9, 10), (13, 12), (17, 10), (20, 13)], 1.2, rr("red0", "red1"))],
    "zalmoxis_amulet": lambda: [path([(6, 3), (12, 11), (18, 3)], 0.4, [I["brown1"]]), oval(12, 15, 5, 5, BRONZE, edge=E),
                                line([(12, 12), (12, 18)], I["brown1"]), line([(9, 15), (15, 15)], I["brown1"]), dots([(10, 13)], I["white"])],
    "bread": lambda: [oval(12, 14, 8.5, 6, rr("brown1", "brown3", "ochre", "straw")),
                      line([(8, 12), (11, 10)], I["brown1"]), line([(11, 15), (15, 12)], I["brown1"]), line([(14, 18), (17, 15)], I["brown1"])],
    "healing_herbs": lambda: herbs(12, 12),
    "power_cell": lambda: [poly([(8, 6), (16, 6), (16, 20), (8, 20)], rr("grey1", "grey2", "grey3"), light=(-1, 0)),
                           poly([(10, 4), (14, 4), (14, 6), (10, 6)], rr("grey2", "grey4")),
                           poly([(8, 11), (16, 11), (16, 15), (8, 15)], rr("teal", "cyan"), light=(-1, 0)),
                           dots([(10, 8)], I["acid"]), dots([(13, 17)], I["magenta"])],
    "lobizi_scalpel": lambda: [path([(3, 21), (8, 16)], 1.5, rr("grey1", "grey2", "grey3")), dots([(5, 19)], I["magenta"]), dots([(7, 17)], I["acid"]),
                               poly([(8, 15), (10, 17), (21, 4), (20, 3)], GLASS)],
    "gravity_coil": lambda: [path([(7 + 10 * (k % 2), 6 + k * 2.6), (17 - 10 * (k % 2), 7.3 + k * 2.6)], 0.8, rr("red1", "magenta")) for k in range(5)] +
                            [oval(12, 21, 6, 1.5, rr("teal", "teal")), dots([(5, 4), (19, 3)], I["cyan"])],
    "med_gel_canister": lambda: [poly([(9, 5), (15, 5), (15, 20), (9, 20)], rr("teal", "cyan", "white"), light=(-1, 0)),
                                 poly([(10, 9), (14, 9), (14, 19), (10, 19)], rr("green3", "acid"), light=(-1, 0)),
                                 poly([(8, 3), (16, 3), (16, 6), (8, 6)], rr("grey1", "grey3")), poly([(8, 19), (16, 19), (16, 21), (8, 21)], rr("grey1", "grey3")),
                                 dots([(11, 12), (12, 15)], I["white"])],
    "surgeon_logbook": lambda: [poly([(5, 5), (18, 3), (20, 18), (7, 21)], rr("grey1", "silk0", "grey4"), edge=E),
                                poly([(7, 20), (20, 17), (20, 19), (7, 22)], rr("grey4", "white")),
                                oval(13, 11, 2.2, 2.2, rr("teal", "cyan")), dots([(10, 16), (16, 15)], I["magenta"])],
    "oglinda_shard": lambda: [poly([(8, 3), (18, 7), (15, 21), (6, 17)], rr("blue1", "blue2", "white")),
                              line([(9, 6), (11, 15)], I["white"]), dots([(14, 10), (15, 11)], I["cyan"]), dots([(12, 17)], I["magenta"])],
    "deserters_diary": lambda: [poly([(4, 6), (20, 6), (20, 19), (4, 19)], WOOD, edge=E), poly([(6, 8), (18, 8), (18, 17), (6, 17)], rr("outline", "brown0")),
                                line([(7, 10), (15, 10)], I["brown2"]), line([(7, 12), (17, 12)], I["brown2"]), line([(7, 14), (12, 14)], I["brown2"]),
                                path([(16, 15), (21, 3)], 0.5, rr("grey2", "grey4"))],
    "strigoi_taxes": lambda: [oval(11, 14, 7, 6, rr("brown0", "brown1", "brown2")), poly([(8, 8), (14, 8), (13, 6), (9, 6)], rr("brown1", "brown2")),
                              path([(8, 8), (14, 8)], 0.6, rr("red0", "red1")),
                              oval(17, 19, 3, 2, BRONZE, edge=E), oval(13, 21, 3, 1.8, BRONZE, edge=E), dots([(16, 18)], I["white"]),
                              dots([(6, 12), (7, 17)], I["green3"])],   # coins slightly damp: a little mould
    "lobizi_parcel": lambda: [poly([(4, 9), (12, 5), (20, 9), (20, 17), (12, 21), (4, 17)], rr("silk0", "grey4", "white")),
                              line([(4, 9), (12, 13), (20, 9)], I["silk0"]), line([(12, 13), (12, 21)], I["silk0"]),
                              path([(8, 7), (16, 11), (16, 19)], 0.8, rr("red1", "magenta")),
                              dots([(7, 14), (8, 15), (9, 14)], I["teal"])],
}


def ability_icon(spec):
    return on_badge(spec["source"], ABILITY[spec["glyph"]]())


def item_icon(spec):
    return glyph(ITEM[spec["glyph"]]())


# ------------------------------------------------------------------ props (32x32, ground point (16, 26))

PG = (16, 26)


def ground_shadow(c, cx, cy, rx, ry):
    h, w = c.shape
    m = K.ellipse(w, h, (cx - rx, cy - ry, cx + rx - 1, cy + ry - 1))
    ys, xs = np.mgrid[0:h, 0:w]
    c[m & (c == K.T) & ((xs + ys) % 2 == 0)] = E


def iso_box(cx, cy, hw, hd, h, top, lit, dark):
    """A small 2:1 iso box standing on its front corner (cx, cy): hw px along the right edge, hd along the left."""
    up = lambda p: (p[0], p[1] - h)
    A = (cx - hd, cy - hd / 2)                  # west
    B = (cx, cy)                                # south, the front corner
    C = (cx + hw, cy - hw / 2)                  # east
    D = (cx + hw - hd, cy - hw / 2 - hd / 2)    # north
    return [poly([A, B, up(B), up(A)], lit), poly([B, C, up(C), up(B)], dark), poly([up(A), up(B), up(C), up(D)], top)]


def prop_canvas(shapes, shadow=(8, 3)):
    c = K.outline(R.render(shapes, 32, 32, outline=False))
    ground_shadow(c, PG[0] + 1, PG[1], *shadow)
    return c


PROP = {
    "chest": lambda: iso_box(17, 28, 10, 7, 8, rr("brown1", "brown2", "brown3"), rr("brown1", "brown2", "brown3"), rr("brown0", "brown1")) +
                     [poly([(10, 16), (17, 20), (27, 15), (20, 11)], rr("brown1", "brown2", "brown3")),
                      path([(13, 21), (13, 27)], 0.6, STEEL), path([(23, 18), (23, 24)], 0.6, STEEL),
                      poly([(16, 21), (18, 21), (18, 24), (16, 24)], BRONZE), dots([(17, 23)], E)],
    "barrel": lambda: [poly([(9, 12), (23, 12), (23, 25), (16, 28), (9, 25)], rr("brown0", "brown1", "brown2"), light=(-1, 0)),
                       oval(16, 12, 7, 3, rr("brown1", "brown2", "brown3")),
                       path([(9, 15), (16, 18), (23, 15)], 0.5, rr("grey1", "grey2")), path([(9, 22), (16, 25), (23, 22)], 0.5, rr("grey1", "grey2"))],
    "bucket": lambda: [poly([(10, 16), (22, 16), (20, 27), (12, 27)], rr("brown1", "brown2", "brown3"), light=(-1, 0)),
                       oval(16, 16, 6, 2.4, rr("blue0", "blue1")), dots([(14, 16)], I["blue2"]),
                       path([(10, 16), (16, 8), (22, 16)], 0.4, [I["grey2"]]),
                       path([(11, 20), (21, 20)], 0.4, rr("grey1", "grey2"))],
    "scroll": lambda: [poly([(8, 20), (22, 14), (25, 18), (11, 24)], rr("brown3", "straw")),
                       oval(9.5, 22, 2.4, 2.8, rr("brown3", "ochre", "straw")), oval(23.5, 16, 2.4, 2.8, rr("brown3", "ochre", "straw")),
                       path([(15, 17), (17, 21)], 0.6, rr("red0", "red1")), dots([(16, 19)], I["red1"])],
    "tax_purse": lambda: [oval(16, 21, 7, 6, rr("brown0", "brown1", "brown2")), poly([(12, 15), (20, 15), (19, 12), (13, 12)], rr("brown1", "brown2")),
                          path([(12, 15), (20, 15)], 0.6, rr("red0", "red1")),
                          oval(23, 26, 2.6, 1.5, BRONZE, edge=E), oval(9, 26, 2.4, 1.4, BRONZE, edge=E), dots([(22, 25)], I["white"])],
    "parcel": lambda: iso_box(17, 28, 10, 8, 12, rr("grey4", "white"), rr("grey4", "white"), rr("silk0", "grey4")) +
                      [path([(13, 24), (13, 14), (21, 9)], 0.7, rr("red1", "magenta")), dots([(20, 20), (21, 21), (22, 20)], I["teal"])],
    "black_box": lambda: iso_box(17, 27, 8, 6, 9, rr("grey1", "grey2"), rr("grey0", "grey1"), rr("outline", "grey0")) +
                         [poly([(12, 22), (16, 24), (16, 20), (12, 18)], rr("red0", "red1")),     # it is orange in every universe, except this palette
                          dots([(20, 17)], I["cyan"]), dots([(22, 16)], I["magenta"])],
}


def prop_sprite(spec):
    return prop_canvas(PROP[spec["glyph"]](), shadow=tuple(spec.get("shadow", (9, 3))))


# ------------------------------------------------------------------ world markers (32x32, ground point (16, 26))

MARKER = {
    # a walled hill town under the Draco
    "town": lambda: [poly([(3, 27), (8, 18), (16, 15), (24, 18), (29, 27), (16, 31)], rr("green1", "green2", "green3")),
                     poly([(7, 20), (25, 20), (25, 24), (7, 24)], rr("grey2", "grey3", "grey4")),
                     line([(7, 22), (25, 22)], I["brown1"]),
                     poly([(10, 14), (14, 10), (18, 14), (18, 20), (10, 20)], rr("brown2", "straw")),
                     poly([(9, 14), (14, 8), (19, 14)], rr("brown2", "ochre", "straw")),
                     poly([(18, 16), (22, 13), (26, 16), (26, 20), (18, 20)], rr("brown2", "straw")),
                     path([(21, 13), (21, 2)], 0.5, WOOD)] + wolf_head(23, 4, 0.45) +
                    [path([(23, 6), (27, 7), (29, 5)], 0.8, rr("red0", "red1"))],
    "cave": lambda: [poly([(2, 28), (6, 14), (13, 7), (20, 8), (27, 14), (30, 28), (16, 31)], rr("grey1", "grey2", "grey3")),
                     poly([(10, 28), (11, 20), (16, 16), (21, 20), (22, 28)], rr("outline", "outline")),
                     dots([(14, 22), (18, 22)], I["blood"]),
                     dots([(8, 12), (9, 11)], I["green3"]), line([(20, 10), (24, 15)], I["grey1"])],
    "crash": lambda: [oval(16, 26, 13, 4, rr("outline", "grey0", "brown0")),
                      poly([(5, 25), (8, 19), (18, 15), (26, 18), (27, 24), (16, 28)], rr("silk0", "grey4", "white"), dither=True),
                      oval(15, 18, 5, 3, rr("teal", "cyan")), dots([(13, 17)], I["white"]),
                      dots([(9, 23), (16, 25), (23, 23)], I["magenta"]),
                      oval(23, 10, 3, 2.4, rr("grey2", "grey3", "grey4")), oval(26, 5, 2.4, 2, rr("grey2", "grey3", "grey4")),
                      dots([(20, 14), (21, 13)], I["acid"])],
    "party": lambda: [path([(15, 28), (15, 6)], 0.6, WOOD)] + wolf_head(17, 8, 0.6) +
                     [path([(18, 11), (23, 13), (27, 10), (30, 13)], 1.4, rr("red0", "red1")),
                      path([(18, 14), (24, 17), (28, 15)], 1.0, rr("red0", "red1"))],
    "ufo": lambda: [oval(16, 16, 14, 5, rr("grey0", "grey1", "grey2")), oval(16, 15, 14, 4.5, rr("grey1", "grey2", "grey3", "grey4")),
                    oval(15.5, 11, 6.5, 4.5, rr("teal", "cyan")), dots([(13, 9), (12, 10)], I["white"]),
                    dots([(5, 17), (10, 19), (16, 20), (22, 19), (27, 17)], I["magenta"]), dots([(8, 18), (19, 20), (25, 18)], I["acid"])],
}


def marker_sprite(spec):
    c = K.outline(R.render(MARKER[spec["glyph"]](), 32, 32, outline=False))
    if spec["glyph"] in ("party", "ufo"):
        ground_shadow(c, 16, 29, 7 if spec["glyph"] == "party" else 10, 2)
    return c


GENERATORS = {"ability_icon": ability_icon, "item_icon": item_icon, "prop_sprite": prop_sprite, "marker_sprite": marker_sprite}

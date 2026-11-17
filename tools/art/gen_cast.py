"""The rest of the human-sized cast on the WP-14 humanoid rig (gen_chars.humanoid): classes,
villagers, the Roman deserter and the strigoi. Each one is a gear dict; poses come from
gen_chars.poses (blade: overhead swing, spear: forward thrust, also used for staffs and tools).
"""
import math

import kit as K
import palette as P
import rig as R
import gen_chars as C
from rig import poly, oval, path, dots, line

I = P.IDX
E = I["outline"]
SKIN = [I["skin0"], I["skin1"], I["skin2"]]
SKIN_DARK = [I["brown0"], I["skin0"], I["skin1"]]
SKIN_DEAD = [I["green2"], I["grey3"], I["grey4"]]   # strigoi: pale, a little mouldy


def rr(*names):
    return [I[n] for n in names]


# ------------------------------------------------------------------ heads: hair, hoods, hats

def hair(ramp, long=0, fringe=True):
    """Hair over the top and back of the head; `long` px past the jaw at the back."""
    def f(hcx, hcy, se):
        if se:
            out = [oval(hcx - 0.3, hcy - 3.2, 4.0, 1.7, ramp),
                   poly([(hcx - 4.2, hcy - 3.5), (hcx - 0.5, hcy - 3.5), (hcx - 1.5, hcy + 1.5 + long * 0.3),
                         (hcx - 3.0, hcy + 2.5 + long), (hcx - 4.6, hcy + 1.5 + long)], ramp)]
            if fringe:
                out.append(dots([(hcx + 1, hcy - 2), (hcx + 2.6, hcy - 2.4)], ramp[0]))
            return out
        return [oval(hcx, hcy - 0.6, 4.0, 4.5, ramp),
                poly([(hcx - 3.5, hcy), (hcx + 3.5, hcy), (hcx + 3, hcy + 2.5 + long), (hcx - 3, hcy + 2.5 + long)], ramp),
                dots([(hcx - 1, hcy + 1), (hcx + 1, hcy - 1)], ramp[0])]
    return f


def headscarf(cloth, hair_ramp=None, knot=True):
    """Woman's headscarf (basma) tied at the nape, a lock of hair at the brow."""
    def f(hcx, hcy, se):
        if se:
            out = [poly([(hcx - 4.5, hcy - 3), (hcx - 1, hcy - 5.4), (hcx + 3.5, hcy - 4.6), (hcx + 3.8, hcy - 2.5),
                         (hcx - 0.5, hcy - 2.2), (hcx - 1.6, hcy + 3), (hcx - 4.6, hcy + 3)], cloth, post=R.stripes(cloth[0], 3, 1, vertical=True)),
                   dots([(hcx + 1.5, hcy - 3.6), (hcx - 2.5, hcy - 1)], I["straw"])]
            if hair_ramp:
                out.append(dots([(hcx + 0.5, hcy - 2), (hcx + 1.5, hcy - 2)], hair_ramp[0]))
            if knot:
                out += [poly([(hcx - 4.6, hcy + 2), (hcx - 6.5, hcy + 5), (hcx - 4.5, hcy + 5.5)], cloth)]
            return out
        out = [oval(hcx, hcy - 0.8, 4.2, 4.6, cloth),
               poly([(hcx - 3.8, hcy), (hcx + 3.8, hcy), (hcx + 3.2, hcy + 4), (hcx - 3.2, hcy + 4)], cloth,
                    post=R.stripes(cloth[0], 3, vertical=True)),
               dots([(hcx - 2, hcy - 3), (hcx + 2, hcy)], I["straw"])]
        if knot:
            out += [oval(hcx, hcy + 3.5, 1.6, 1.3, cloth), poly([(hcx - 1, hcy + 4), (hcx - 3, hcy + 8), (hcx, hcy + 6)], cloth)]
        return out
    return f


def hood(cloth, lining=None):
    """Deep hood: the back part behind the head, the rim over the brow."""
    lining = lining or [I["outline"], I["grey0"]]

    def under(hcx, hcy, se):
        if se:
            return [oval(hcx - 0.8, hcy - 0.6, 5.2, 5.6, cloth),
                    poly([(hcx - 6, hcy), (hcx - 1, hcy + 1), (hcx - 1, hcy + 6), (hcx - 6.5, hcy + 6)], cloth),
                    oval(hcx + 0.6, hcy + 0.3, 3.7, 4.2, lining)]
        return []

    def over(hcx, hcy, se):
        if se:
            return [poly([(hcx - 5.5, hcy - 2.5), (hcx - 2.5, hcy - 6.2), (hcx + 2.5, hcy - 5.8), (hcx + 4.6, hcy - 2.6),
                          (hcx + 3.8, hcy - 1.8), (hcx + 0, hcy - 3.0), (hcx - 3, hcy - 1)], cloth, edge=E)]
        return [oval(hcx, hcy - 0.5, 5.0, 5.4, cloth),
                poly([(hcx - 4, hcy + 1), (hcx + 4, hcy + 1), (hcx + 5, hcy + 6), (hcx - 5, hcy + 6)], cloth),
                poly([(hcx - 1, hcy - 5.5), (hcx + 1, hcy - 7.5), (hcx + 2.5, hcy - 5)], cloth),
                line([(hcx, hcy - 4), (hcx, hcy + 5)], cloth[0])]
    return under, over


def pileus(felt, hair_ramp):
    """The tall Dacian felt cap of the tarabostes and the priests, tip bent forward."""
    h = hair(hair_ramp, long=3, fringe=False)

    def f(hcx, hcy, se):
        out = h(hcx, hcy, se)
        out += [poly([(hcx - 4.2, hcy - 2.2), (hcx + 3.8, hcy - 2.2), (hcx + 3.0, hcy - 6.5), (hcx + 4.6, hcy - 10),
                      (hcx + 1.4, hcy - 9.4), (hcx - 2.2, hcy - 7.4), (hcx - 4.0, hcy - 5)], felt, edge=E),
                line([(hcx - 4, hcy - 2.6), (hcx + 3.6, hcy - 2.6)], felt[0])]
        return out
    return f


def galea(dented=True):
    """Roman legionary helmet: iron bowl, brow ridge, neck guard and cheek pieces. No crest (deserted)."""
    steel = rr("grey1", "grey3", "grey4")

    def f(hcx, hcy, se):
        if se:
            out = [oval(hcx - 0.3, hcy - 2.6, 4.3, 3.2, steel, edge=E),
                   poly([(hcx - 5, hcy - 1.5), (hcx - 2, hcy - 1.5), (hcx - 3, hcy + 1.5), (hcx - 6.2, hcy + 1)], steel, edge=E),
                   line([(hcx - 3.5, hcy - 1.2), (hcx + 4.4, hcy - 1.6)], I["ochre"]),
                   poly([(hcx - 0.6, hcy - 1), (hcx + 1.2, hcy - 1), (hcx + 1.0, hcy + 3), (hcx - 0.4, hcy + 3)], steel),
                   dots([(hcx - 0.2, hcy - 5.4)], I["ochre"])]
            if dented:
                out.append(dots([(hcx + 1, hcy - 4), (hcx + 2, hcy - 3.6)], I["grey1"]))
            return out
        return [oval(hcx, hcy - 1.5, 4.4, 3.8, steel, edge=E),
                poly([(hcx - 5.5, hcy + 0.5), (hcx + 5.5, hcy + 0.5), (hcx + 6, hcy + 2.5), (hcx - 6, hcy + 2.5)], steel, edge=E),
                dots([(hcx, hcy - 5)], I["ochre"]),
                line([(hcx - 3, hcy - 3), (hcx + 2, hcy - 4.5)], I["grey1"])]
    return f


def kucsma(fur, hair_ramp=None):
    """A boier's tall fur hat, gone slightly off in the grave. Big ears stick out under it."""
    def f(hcx, hcy, se):
        out = []
        if se:
            out.append(poly([(hcx - 3.6, hcy), (hcx - 5.6, hcy - 2.5), (hcx - 4.6, hcy + 1.4)], SKIN_DEAD, edge=E))  # ear
        out += [poly([(hcx - 4.6, hcy - 2.4), (hcx + 4.2, hcy - 2.4), (hcx + 4.6, hcy - 10.5), (hcx + 2, hcy - 11.5),
                      (hcx - 2.5, hcy - 11.2), (hcx - 5, hcy - 10)], fur, edge=E, post=R.stripes(fur[0], 2, vertical=True)),
                line([(hcx - 4.6, hcy - 3), (hcx + 4.2, hcy - 3)], fur[0]),
                dots([(hcx + 1, hcy - 8)], I["ochre"])]                       # a tarnished brooch
        if not se:
            out += [poly([(hcx - 4, hcy - 2), (hcx - 6, hcy - 4), (hcx - 4.5, hcy + 0.5)], SKIN_DEAD, edge=E),
                    poly([(hcx + 4, hcy - 2), (hcx + 6, hcy - 4), (hcx + 4.5, hcy + 0.5)], SKIN_DEAD, edge=E)]
        return out
    return f


def fangs(hcx, hcy, se):
    if not se:
        return []
    return [line([(hcx + 0.5, hcy + 2), (hcx + 3, hcy + 2)], E), dots([(hcx + 1, hcy + 2.5), (hcx + 2.5, hcy + 2.5)], I["white"])]


def old_man_hair(hcx, hcy, se):
    """Bald on top, white tufts at the sides (the tax collector)."""
    w = rr("grey3", "grey4")
    if se:
        return [poly([(hcx - 4, hcy - 2), (hcx - 2, hcy - 2), (hcx - 2, hcy + 1.5), (hcx - 4.4, hcy + 1.5)], w),
                dots([(hcx + 0.5, hcy - 3.6)], I["white"])]
    return [poly([(hcx - 4, hcy - 1), (hcx + 4, hcy - 1), (hcx + 3.6, hcy + 2.5), (hcx - 3.6, hcy + 2.5)], w),
            dots([(hcx - 1, hcy - 3)], I["white"])]


def with_extra(base, extra):
    def f(hcx, hcy, se):
        return base(hcx, hcy, se) + extra(hcx, hcy, se)
    return f


# ------------------------------------------------------------------ bodies

def long_robe(ramp, trim=None, flare=7.0, hem=C.GROUND - 1.5, post=None, open_front=None):
    """A robe from the waist to the ankles, drawn over the legs; feet show under the hem."""
    def f(sx, sy, hx, hy, se):
        top = hy - 2
        k = flare
        pts = [(hx - 5.5, top), (hx + 5.5, top), (hx + k, hem - 0.5), (hx + k * 0.4, hem + 0.6),
               (hx - k * 0.3, hem), (hx - k, hem - 0.6)]
        out = [poly(pts, ramp, post=post or R.stripes(ramp[0], 3, 1, vertical=True))]
        if trim is not None:
            out.append(line([(hx - k + 0.5, hem - 1.2), (hx - k * 0.3, hem - 0.6), (hx + k * 0.4, hem - 0.2), (hx + k - 0.5, hem - 1.2)], trim))
        if open_front is not None and se:
            out.append(poly([(hx + 1, top), (hx + 3, top), (hx + 3.5, hem - 1), (hx + 1.5, hem - 0.5)], open_front))
        return out
    return f


def chain(*fns):
    def f(*a):
        out = []
        for fn in fns:
            out += fn(*a)
        return out
    return f


def nothing(*a):
    return []


def apron(cloth):
    def f(sx, sy, hx, hy, se):
        if not se:
            return [line([(sx - 5, sy + 6), (sx + 5, sy + 6)], cloth[0])]
        return [poly([(hx - 2, hy - 4), (hx + 5, hy - 4), (hx + 5.5, hy + 9), (hx - 1.5, hy + 9.5)], cloth, edge=E)]
    return f


def sash(col_ramp, dy=0):
    def f(sx, sy, hx, hy, se):
        if se:
            return [path([(sx - 5, sy + 1), (hx + 4, hy - 3 + dy)], 1.0, col_ramp, edge=E)]
        return [path([(sx + 5, sy + 1), (hx - 4, hy - 3 + dy)], 1.0, col_ramp)]
    return f


def bone_necklace(sx, sy, hx, hy, se):
    if not se:
        return []
    return [dots([(sx - 2, sy + 2), (sx - 1, sy + 3), (sx + 1, sy + 3), (sx + 2.4, sy + 2)], I["grey4"]),
            dots([(sx, sy + 4)], I["white"])]


def mantle(ramp):
    """A short shoulder cape, both views."""
    def f(sx, sy, hx, hy, se):
        if se:
            return [poly([(sx - 6.5, sy - 0.5), (sx + 3, sy - 1), (sx + 2, sy + 3), (sx - 3, sy + 4), (sx - 7.5, sy + 3)], ramp)]
        return [poly([(sx - 6.5, sy - 0.5), (sx + 6.5, sy - 0.5), (sx + 7, sy + 6), (sx, sy + 7.5), (sx - 7, sy + 6)], ramp, edge=E,
                     post=R.stripes(ramp[0], 3, vertical=True))]
    return f


def cape_back(ramp, length=13):
    def f(sx, sy, hx, hy, se):
        if se:
            return [poly([(sx - 5, sy - 1), (sx - 1, sy), (hx - 3, hy + length - 12), (hx - 7, hy + length - 9), (hx - 8.5, hy + length - 11)], ramp)]
        return []
    return f


def cape_ne(ramp, length=13):
    def f(sx, sy, hx, hy, se):
        if se:
            return []
        return [poly([(sx - 6, sy), (sx + 6, sy), (hx + 6, hy + length - 10), (hx + 1, hy + length - 8), (hx - 6, hy + length - 9)], ramp,
                     edge=E, post=R.stripes(ramp[0], 3, vertical=True))]
    return f


def segmentata(sx, sy, hx, hy, se):
    """Lorica segmentata bands over the red tunic (both views)."""
    steel = rr("grey1", "grey3", "grey4")
    out = []
    for k in range(4):
        y = sy + 1 + k * 2.4
        out.append(poly([(sx - 6, y), (sx + 6, y), (sx + 6 - k * 0.2, y + 1.8), (sx - 6 + k * 0.2, y + 1.8)], steel))
    if se:
        out.append(poly([(sx - 7, sy - 1), (sx - 2, sy - 1.5), (sx - 2, sy + 2), (sx - 7.5, sy + 2)], steel, edge=E))
        out.append(dots([(sx + 1, sy + 3.5), (sx + 1, sy + 6)], I["ochre"]))
    else:
        out.append(line([(sx, sy + 1), (sx, sy + 9)], I["grey1"]))
    return out


def kaftan_over(sx, sy, hx, hy, se):
    """The strigoi's once-grand boier coat: long, red, moth-eaten, gold frogging."""
    red = rr("red0", "red1")
    out = [poly([(sx - 6, sy), (sx + 6, sy), (hx + 7.5, C.GROUND - 3), (hx + 2, C.GROUND - 2), (hx - 3, C.GROUND - 1.5), (hx - 7.5, C.GROUND - 3)],
                red, post=R.stripes(I["red0"], 3, vertical=True))]
    if se:
        out += [line([(sx + 1, sy + 1), (hx + 2, C.GROUND - 3)], I["outline"]),
                dots([(sx - 1, sy + 3), (sx + 2, sy + 3), (sx - 1, sy + 6), (sx + 2, sy + 6), (sx - 1, sy + 9)], I["ochre"]),
                dots([(hx - 4, hy + 6), (hx + 4, hy + 9)], I["outline"]),             # moth holes
                poly([(sx - 6.5, sy - 1), (sx + 4, sy - 1), (sx + 3, sy + 1.5), (sx - 6, sy + 2)], rr("brown0", "brown1"))]  # fur collar
    else:
        out += [poly([(sx - 6.5, sy - 1), (sx + 6.5, sy - 1), (sx + 6, sy + 2), (sx - 6, sy + 2)], rr("brown0", "brown1")),
                dots([(hx + 3, hy + 4), (hx - 2, hy + 10)], I["outline"])]
    return out


# ------------------------------------------------------------------ weapons and tools

def _axis(hand, ang):
    a = math.radians(ang)
    d = (math.sin(a), -math.cos(a))
    n = (math.cos(a), math.sin(a))

    def at(t, k=0.0):
        return (hand[0] + d[0] * t + n[0] * k, hand[1] + d[1] * t + n[1] * k)
    return at


def skull_staff(hand, ang, se):
    at = _axis(hand, ang)
    return [path([at(-8), at(16)], 0.6, rr("brown0", "brown2")),
            line([at(13, -1.5), at(15, 0), at(13, 1.5)], I["grey3"]),
            oval(*at(18), 2.4, 2.2, rr("grey2", "grey4", "white")),
            dots([at(18.4, -0.9), at(18.4, 0.9)], E),
            dots([at(16.8)], I["grey2"])]


def sun_staff(hand, ang, se):
    """Oak staff with a bronze sun disc: Zalmoxis, via the priests' best guess."""
    at = _axis(hand, ang)
    return [path([at(-9), at(16)], 0.6, rr("brown1", "brown3")),
            oval(*at(18.5), 2.8, 2.8, rr("brown2", "ochre", "straw"), edge=E),
            dots([at(18.5)], I["white"]),
            dots([at(18.5, 3.6), at(18.5, -3.6), at(22.1), at(14.9, 2.6), at(14.9, -2.6)], I["ochre"])]


def gladius(hand, ang, se):
    at = _axis(hand, ang)
    return [path([at(-2.5), at(0.5)], 0.7, rr("brown0", "brown2")),
            line([at(1, -1.5), at(1, 1.5)], I["ochre"]),
            path([at(2), at(8.5)], 0.9, rr("grey2", "grey4"), cuts=[0.55]),
            dots([at(9.5)], I["grey4"]),
            dots([at(-3)], I["ochre"])]


def scutum(cx, cy, se):
    red = rr("red0", "red1")
    if se:
        return [poly([(cx - 3, cy - 7), (cx + 4.5, cy - 6), (cx + 5, cy + 6), (cx - 2.5, cy + 7)], red, edge=E, cuts=[0.55]),
                line([(cx - 2.5, cy - 6.4), (cx + 4.6, cy - 5.4)], I["ochre"]),
                line([(cx + 0.8, cy - 6), (cx + 1.2, cy + 6.5)], I["ochre"]),
                oval(cx + 1, cy, 1.6, 1.8, rr("grey2", "grey4")),
                dots([(cx - 1, cy + 4)], I["grey1"]), dots([(cx + 3.5, cy - 3)], I["red0"])]  # a chip: it has seen things
    return [poly([(cx - 5, cy - 7), (cx + 2, cy - 7), (cx + 2.5, cy + 6), (cx - 5, cy + 6)], rr("brown0", "brown1", "brown2"), cuts=[0.4, 0.8]),
            line([(cx - 5, cy - 0.5), (cx + 2.4, cy - 0.5)], I["brown0"])]


def club(col=("brown0", "brown1", "brown2"), length=8):
    def f(hand, ang, se):
        at = _axis(hand, ang)
        return [path([at(-2), at(length)], 0.9, rr(*col)), oval(*at(length + 1), 1.6, 1.6, rr(*col))]
    return f


def ladle(hand, ang, se):
    at = _axis(hand, ang)
    return [path([at(-2), at(8)], 0.6, rr("brown1", "brown3")),
            oval(*at(10, 0.8), 2.4, 2.0, rr("brown1", "brown2", "brown3"), edge=E),
            dots([at(10.5, 0.5)], I["brown0"])]


def tax_scroll(hand, ang, se):
    at = _axis(hand, ang)
    return [path([at(-2), at(7)], 1.4, rr("brown3", "straw"), cuts=[0.5]),
            line([at(-2.5, -1.4), at(-2.5, 1.4)], I["red1"]),
            dots([at(2.5)], I["red1"])]


def pitchfork(hand, ang, se):
    at = _axis(hand, ang)
    return [path([at(-9), at(14)], 0.55, rr("brown1", "brown3")),
            line([at(14, -2), at(14, 2)], I["grey2"]),
            line([at(14, -2), at(17.5, -2)], I["grey3"]),
            line([at(14, 0), at(18, 0)], I["grey4"]),
            line([at(14, 2), at(17.5, 2)], I["grey3"])]


def claws(hand, ang, se):
    """Strigoi fingernails: long, grey, recently in a grave."""
    at = _axis(hand, ang)
    return [line([at(1, -1.4), at(4, -1.8)], I["grey4"]),
            line([at(1.4, 0), at(4.6, 0)], I["white"]),
            line([at(1, 1.4), at(4, 1.8)], I["grey4"])]


def drop(shapes):
    """A 'dropped' hook: the weapon lies on the ground beside the fallen body."""
    def f(fr, facing):
        top = R.render(shapes, C.FW, C.FH, outline=False)
        m = (top != K.T) & (fr == K.T)
        fr[m] = top[m]
        K.outline(fr)
    return f


DROP_STAFF_SKULL = drop([path([(3, 45), (16, 43)], 0.5, rr("brown0", "brown2")), oval(19, 42.5, 2.2, 2.0, rr("grey2", "grey4"))])
DROP_STAFF_SUN = drop([path([(3, 45), (16, 43)], 0.5, rr("brown1", "brown3")), oval(19.5, 42.5, 2.4, 2.4, rr("brown2", "ochre", "straw"))])
DROP_GLADIUS = drop([path([(6, 45), (8, 45)], 0.6, rr("brown0", "brown2")), path([(9, 45), (15, 44)], 0.7, rr("grey2", "grey4"))])
DROP_PITCHFORK = drop([path([(3, 45), (17, 43)], 0.5, rr("brown1", "brown3")), line([(17, 41), (20, 41)], I["grey3"]), line([(17, 44), (21, 43)], I["grey3"])])

# ------------------------------------------------------------------ the cast

GEAR = {
    "necromancer": dict(
        kind="spear", shield=False,
        skin=[I["skin0"], I["skin1"], I["skin2"]], eye=I["outline"],
        trousers=rr("grey0", "grey1"), boots=rr("outline", "brown0", "brown1"),
        sleeve=rr("blue0", "grey0", "grey1"), forearm=rr("blue0", "grey0", "grey1"),
        armour=rr("blue0", "grey0", "grey1"), armour_post=R.stripes(I["blue0"], 3, vertical=True),
        belt=rr("red0", "red1"), skirt=rr("blue0", "grey0"),
        helm_under=hood(rr("blue0", "grey0", "grey1"))[0], helm=hood(rr("blue0", "grey0", "grey1"))[1],
        weapon=skull_staff,
        over=chain(long_robe(rr("blue0", "grey0", "grey1"), trim=I["grey3"]), bone_necklace, sash(rr("red0", "red1"))),
        dropped=DROP_STAFF_SKULL,
    ),
    "healer": dict(
        kind="spear", shield=False,
        skin=SKIN, beard=rr("grey3", "grey4"),
        trousers=rr("grey3", "grey4"), boots=rr("outline", "brown0", "brown1"),
        sleeve=rr("grey3", "grey4", "white"), forearm=rr("grey3", "grey4", "white"),
        armour=rr("grey3", "grey4", "white"), belt=rr("brown1", "ochre"), skirt=rr("grey3", "white"),
        helm=pileus(rr("brown2", "brown3", "straw"), rr("grey3", "grey4")),
        weapon=sun_staff,
        back=cape_back(rr("blue0", "blue1")),
        over=chain(long_robe(rr("grey3", "grey4", "white"), trim=I["blue1"]), sash(rr("blue1", "blue2")), cape_ne(rr("blue0", "blue1", "blue2"))),
        dropped=DROP_STAFF_SUN,
    ),
    "roman_deserter": dict(
        kind="blade", shield=scutum,
        skin=SKIN, beard=rr("brown0", "brown1"),             # has not shaved since Dacia
        trousers=rr("skin0", "skin1"), boots=rr("outline", "brown0", "brown2"), wraps=I["brown1"],
        sleeve=rr("red0", "red1"), forearm=SKIN,
        armour=rr("red0", "red1"), belt=rr("brown0", "brown1", "ochre"), skirt=rr("red0", "red1"),
        helm=galea(), weapon=gladius, over=segmentata, back=cape_back(rr("red0", "red1"), 10), dropped=DROP_GLADIUS,
    ),
    "strigoi": dict(
        kind="blade", shield=False,
        skin=SKIN_DEAD, eye=I["blood"], eye2=I["blood"],
        trousers=rr("grey0", "grey1"), boots=rr("outline", "red0", "red1"),
        sleeve=rr("red0", "red1"), forearm=rr("red0", "red1"),
        armour=rr("red0", "red1"), belt=rr("ochre", "straw"), skirt=rr("red0", "red1"),
        helm=with_extra(with_extra(hair(rr("grey0", "grey1"), long=2, fringe=False), kucsma(rr("outline", "brown0", "brown1"))), fangs), weapon=claws, over=kaftan_over,
    ),
    # Dida the trader: headscarf, embroidered blouse, a long skirt and an apron, a ladle for haggling
    "villager_1": dict(
        kind="blade", shield=False,
        skin=SKIN, trousers=rr("brown1", "brown2"), boots=rr("outline", "brown0", "brown1"),
        sleeve=rr("grey4", "white"), forearm=SKIN,
        armour=rr("grey4", "white"), armour_post=R.stripes(I["red1"], 4, 1),
        belt=rr("red0", "red1"), skirt=rr("blue0", "blue1"),
        helm=headscarf(rr("red0", "red1"), rr("brown0", "brown1")), weapon=ladle,
        over=chain(long_robe(rr("blue0", "blue1"), trim=I["red1"], flare=6.5), apron(rr("grey3", "grey4", "white"))),
    ),
    # a young townsfolk: green tunic, straw hair, a stick
    "villager_2": dict(
        kind="blade", shield=False,
        skin=SKIN, trousers=rr("brown0", "brown1", "brown2"), boots=rr("outline", "brown0", "brown1"), wraps=I["brown3"],
        sleeve=rr("green1", "green2", "green3"), forearm=SKIN,
        armour=rr("green1", "green2", "green3"), belt=rr("brown0", "brown2"), skirt=rr("green1", "green2"),
        helm=hair(rr("brown0", "brown1", "brown2")), weapon=club(),
    ),
    # Mucapor the tax collector: bald, white tufts, tall red-trimmed robe, a tax scroll for bonking
    "villager_3": dict(
        kind="blade", shield=False,
        skin=SKIN, beard=rr("grey3", "grey4"),
        trousers=rr("brown1", "brown2"), boots=rr("outline", "brown0", "brown1"),
        sleeve=rr("ochre", "straw"), forearm=rr("ochre", "straw"),
        armour=rr("brown2", "ochre", "straw"), belt=rr("red0", "red1"), skirt=rr("brown2", "ochre"),
        helm=old_man_hair, weapon=tax_scroll,
        over=chain(long_robe(rr("brown2", "ochre", "straw"), trim=I["red1"]), sash(rr("red0", "red1")),
                   cape_ne(rr("red0", "red1"), 10)),
        back=cape_back(rr("red0", "red1"), 10),
    ),
    # Tsinna: dark braid, blue blouse, straw skirt, a pitchfork she knows how to use
    "villager_4": dict(
        kind="spear", shield=False,
        skin=SKIN_DARK, trousers=rr("brown1", "brown2"), boots=rr("outline", "brown0", "brown1"),
        sleeve=rr("blue1", "blue2"), forearm=SKIN_DARK,
        armour=rr("blue0", "blue1", "blue2"), belt=rr("ochre", "straw"), skirt=rr("brown2", "brown3"),
        helm=hair(rr("outline", "brown0"), long=6), weapon=pitchfork,
        over=long_robe(rr("brown1", "brown2", "brown3"), trim=I["ochre"], flare=6.5), dropped=DROP_PITCHFORK,
    ),
}


def make(cid):
    def gen(spec):
        return C.human_frames(GEAR[cid])
    return gen


GENERATORS = {cid: make(cid) for cid in GEAR}

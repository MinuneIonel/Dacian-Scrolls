"""Portraits, 48x48: head and shoulders in three-quarter view facing right, on a framed backdrop
coloured per character. Same palette, outline and top-left light as the sprites, just bigger.
portrait_fanfi is the narrator: a smug, translucent Atlantean giant in séance smoke.
"""
import math

import numpy as np

import kit as K
import palette as P
import rig as R
from rig import poly, oval, path, dots, line

I = P.IDX
E = I["outline"]
N = 48


def rr(*names):
    return [I[n] for n in names]


SKIN = rr("skin0", "skin1", "skin2")
SKIN_DARK = rr("brown0", "skin0", "skin1")
SKIN_DEAD = rr("green2", "grey3", "grey4")


def backdrop(ramp):
    """Framed panel: a dithered vertical gradient, a bronze-and-black frame."""
    c = K.canvas(N, N)
    ys, xs = np.mgrid[0:N, 0:N]
    t = ys / (N - 1) * 0.9 + (xs / (N - 1)) * 0.2
    K.dither_mix(c, np.ones((N, N), bool), I[ramp[1]], I[ramp[0]], t)
    d = np.minimum(np.minimum(xs, ys), np.minimum(N - 1 - xs, N - 1 - ys))
    c[d == 1] = I["ochre"]
    c[(d == 1) & ((xs > N - 3) | (ys > N - 3))] = I["brown2"]
    c[d == 0] = E
    c[d == 2] = E
    return c


def face(skin, eye=None, brow=None, mouth="flat", nose=True, blush=False, eyes_closed=False, dx=0, dy=0):
    """A three-quarter face. (24+dx, 23+dy) is the middle of the head."""
    cx, cy = 24 + dx, 23 + dy
    eye = eye if eye is not None else E
    S = [poly([(cx - 4, cy + 8), (cx + 4, cy + 8), (cx + 5, cy + 16), (cx - 5, cy + 16)], skin),          # neck
         oval(cx - 9, cy + 1, 2.4, 3.2, skin, edge=E),                                                      # ear
         oval(cx, cy, 9.5, 11, skin)]
    S.append(poly([(cx + 7, cy + 3), (cx + 9.5, cy - 2), (cx + 9.5, cy + 5)], skin))                        # cheek toward the light side
    if brow is not None:
        S += [line([(cx - 1, cy - 4), (cx + 3, cy - 5)], brow), line([(cx + 5.5, cy - 5), (cx + 8.5, cy - 4)], brow)]
    if eyes_closed:
        S += [line([(cx, cy - 1), (cx + 3, cy - 1)], E), line([(cx + 6, cy - 1), (cx + 8, cy - 1)], E)]
    else:
        S += [poly([(cx - 0.5, cy - 2.5), (cx + 3.5, cy - 2.5), (cx + 3.5, cy), (cx - 0.5, cy)], [I["white"]]),
              poly([(cx + 5.5, cy - 2.5), (cx + 8.5, cy - 2.5), (cx + 8.5, cy), (cx + 5.5, cy)], [I["white"]]),
              dots([(cx + 2, cy - 2), (cx + 2, cy - 1), (cx + 7, cy - 2), (cx + 7, cy - 1)], eye)]
    if nose:
        S += [line([(cx + 5, cy), (cx + 6, cy + 4)], skin[0]), dots([(cx + 4, cy + 4), (cx + 5, cy + 5)], skin[0])]
    if mouth == "flat":
        S.append(line([(cx + 1, cy + 7), (cx + 6, cy + 7)], skin[0] if skin[0] != E else E))
    elif mouth == "smile":
        S += [line([(cx + 1, cy + 6), (cx + 2, cy + 7), (cx + 6, cy + 7), (cx + 7, cy + 6)], E)]
    elif mouth == "smirk":
        S += [line([(cx + 1, cy + 7), (cx + 5, cy + 7), (cx + 7, cy + 5)], E)]
    elif mouth == "grin":
        S += [poly([(cx + 1, cy + 6), (cx + 7, cy + 6), (cx + 6, cy + 9), (cx + 2, cy + 9)], [E]),
              line([(cx + 2, cy + 6.5), (cx + 6, cy + 6.5)], I["white"])]
    elif mouth == "fangs":
        S += [line([(cx + 1, cy + 7), (cx + 7, cy + 7)], E), dots([(cx + 2, cy + 8), (cx + 6, cy + 8)], I["white"])]
    if blush:
        S.append(dots([(cx + 0, cy + 3), (cx + 1, cy + 3), (cx + 8, cy + 3)], I["red1"] if skin is not SKIN_DEAD else I["green3"]))
    return S


def shoulders(ramp, collar=None, post=None):
    S = [poly([(3, 48), (5, 40), (14, 35), (34, 35), (43, 40), (45, 48)], ramp, post=post)]
    if collar:
        S.append(poly([(18, 35), (30, 35), (28, 40), (24, 42), (20, 40)], collar))
    return S


def hair_back(ramp, long=0):
    return [oval(23, 20, 11, 11, ramp), poly([(12, 20), (19, 22), (17, 36 + long), (11, 34 + long)], ramp)]


def hair_top(ramp, fringe=True):
    S = [poly([(13, 18), (16, 12), (24, 10), (32, 12), (34, 17), (28, 15), (22, 17), (17, 21)], ramp)]
    if fringe:
        S.append(poly([(24, 14), (30, 14), (28, 18)], ramp))
    return S


def beard(ramp, long=6):
    return [poly([(16, 26), (21, 30), (30, 30), (33, 25), (33, 30), (29, 36 + long), (22, 37 + long), (17, 32)], ramp),
            line([(25, 30), (30, 30)], E)]


def compose(bg, shapes):
    c = backdrop(bg)
    fig = R.render(shapes, N, N)
    inner = np.zeros((N, N), bool)
    inner[3:N - 3, 3:N - 3] = True
    fig[~inner] = K.T
    K.stamp(c, fig, 0, 0)
    return c


# ------------------------------------------------------------------ the people

def p_knight():
    pelt = rr("grey1", "grey2", "grey3")
    return (("red0", "red1"),
            shoulders(rr("brown2", "ochre", "straw"), post=R.scales(I["brown1"], I["straw"])) +
            [poly([(4, 42), (14, 34), (34, 34), (44, 42), (40, 46), (8, 46)], pelt)] +
            face(SKIN, brow=I["brown0"], mouth="flat") + beard(rr("brown0", "brown1"), 2) +
            [poly([(12, 16), (16, 8), (30, 8), (36, 14), (36, 17), (12, 18)], rr("brown2", "ochre", "straw"), edge=E),   # bronze cap
             oval(22, 8, 11, 5, pelt), poly([(13, 6), (15, -2), (20, 5)], pelt), poly([(22, 4), (26, -2), (29, 5)], pelt),
             poly([(26, 6), (42, 9), (41, 13), (28, 12)], rr("grey2", "grey3", "grey4")), dots([(41, 10)], E), dots([(30, 7)], I["ochre"]),
             poly([(10, 12), (14, 10), (14, 34), (8, 36)], pelt)])


def p_necromancer():
    robe = rr("blue0", "grey0", "grey1")
    return (("outline", "blue0"),
            shoulders(robe) + [poly([(6, 22), (14, 6), (30, 4), (40, 14), (40, 30), (36, 38), (10, 40)], robe)] +
            [oval(25, 23, 10, 12, rr("outline", "grey0"))] +
            face(SKIN, eye=I["outline"], brow=I["outline"], mouth="smirk", dx=1) +
            [poly([(13, 18), (18, 8), (28, 6), (36, 12), (38, 20), (34, 15), (24, 12), (16, 22)], robe, edge=E),
             dots([(20, 38), (23, 39), (26, 39), (29, 38)], I["grey4"]), oval(24.5, 41, 2.4, 2.2, rr("grey3", "grey4")),
             dots([(23.5, 40.5), (25.5, 40.5)], E)])


def p_healer():
    return (("blue0", "blue1"),
            shoulders(rr("grey3", "grey4", "white"), collar=rr("blue1", "blue2")) +
            hair_back(rr("grey3", "grey4"), 4) + face(SKIN, brow=I["grey4"], mouth="smile") + beard(rr("grey3", "grey4", "white"), 8) +
            [poly([(12, 16), (36, 16), (34, 9), (37, 1), (30, 2), (20, 4), (13, 10)], rr("brown2", "brown3", "straw"), edge=E),
             line([(12, 15), (36, 15)], I["brown2"]),
             oval(9, 40, 3, 3, rr("brown2", "ochre", "straw"), edge=E), dots([(9, 40)], I["white"])])


def p_dida():
    scarf = rr("red0", "red1")
    return (("brown1", "brown2"),
            shoulders(rr("grey4", "white"), post=R.stripes(I["red1"], 4, 2)) +
            [poly([(10, 20), (16, 8), (30, 6), (38, 14), (38, 22), (34, 16), (24, 13), (16, 24), (16, 38), (9, 36)], scarf)] +
            face(SKIN, brow=I["brown0"], mouth="smile", blush=True) +
            [poly([(13, 16), (17, 9), (30, 7), (37, 13), (36, 17), (28, 13), (20, 15), (15, 22)], scarf, edge=E,
                  post=R.stripes(I["red0"], 3, 1, vertical=True)),
             dots([(22, 10), (28, 9), (33, 13)], I["straw"]),
             oval(38, 42, 3.4, 2.4, BRONZE_RAMP), oval(41, 44, 3.4, 2.4, BRONZE_RAMP)])   # coins: she is a trader


BRONZE_RAMP = rr("brown2", "ochre", "straw")


def p_zia():
    hair = rr("brown0", "brown1", "brown2")
    return (("brown0", "red0"),
            shoulders(rr("green1", "green2", "green3"), collar=rr("grey4", "white")) +
            hair_back(hair, 6) + face(SKIN, brow=I["brown0"], mouth="smirk") + hair_top(hair) +
            [path([(12, 24), (10, 34), (12, 42)], 2.0, hair),                                               # braid
             oval(12, 43, 2, 2, rr("red0", "red1")),
             path([(38, 46), (38, 36)], 3.6, rr("brown1", "brown2", "brown3")), oval(38, 35, 4, 1.6, rr("grey4", "white")),   # a mug
             path([(42, 38), (43, 43)], 1.0, rr("brown1", "brown2"))])


def p_mucapor():
    return (("ochre", "straw"),
            shoulders(rr("brown2", "ochre", "straw"), collar=rr("red0", "red1")) +
            face(SKIN, brow=I["grey4"], mouth="smirk") +
            [poly([(12, 18), (15, 14), (16, 26), (12, 28)], rr("grey3", "grey4")), dots([(26, 12), (27, 12)], I["white"]),
             poly([(18, 30), (32, 30), (30, 34), (20, 34)], rr("grey3", "grey4", "white")),                  # a tidy grey beard
             path([(6, 46), (12, 34)], 2.6, rr("brown3", "straw")), line([(5, 44), (9, 45)], I["red1"]),     # a tax scroll
             oval(29, 21.5, 2.6, 2.4, rr("grey1", "grey3")), dots([(29, 21)], I["white"])])                  # monocle, obviously


def p_tsinna():
    hair = rr("outline", "brown0")
    return (("green0", "green1"),
            shoulders(rr("blue0", "blue1", "blue2")) +
            hair_back(hair, 10) + face(SKIN_DARK, eye=E, brow=E, mouth="flat") + hair_top(hair, fringe=False) +
            [path([(42, 46), (40, 20)], 1.0, rr("brown1", "brown3")), line([(37, 20), (43, 20)], I["grey3"]),
             line([(37, 20), (37, 15)], I["grey3"]), line([(40, 20), (40, 14)], I["grey4"]), line([(43, 20), (43, 15)], I["grey3"])])


def p_rholes():
    steel = rr("grey1", "grey3", "grey4")
    return (("grey0", "grey1"),
            shoulders(rr("red0", "red1")) + [poly([(4, 44), (14, 36), (34, 36), (44, 44)], rr("brown1", "brown2"))] +
            face(SKIN, brow=I["brown0"], mouth="flat") +
            [path([(19, 30), (24, 29), (31, 30)], 1.0, rr("brown0", "brown1")),                             # moustache of authority
             poly([(12, 18), (14, 9), (22, 3), (32, 7), (37, 17)], steel, edge=E),                           # conical helmet
             line([(12, 17), (37, 17)], I["ochre"]), dots([(22, 4)], I["ochre"]),
             path([(41, 47), (41, 4)], 1.0, rr("brown0", "brown2")), poly([(39, 4), (41, -1), (43, 4)], steel)])


def p_bitus():
    hair = rr("brown1", "brown2", "brown3")
    return (("green1", "green2"),
            [poly([(8, 48), (10, 42), (16, 38), (32, 38), (38, 42), (40, 48)], rr("green1", "green2", "green3"))] +
            face(SKIN, brow=I["brown1"], mouth="grin", blush=True, dy=2) +
            [poly([(13, 20), (14, 12), (19, 9), (22, 11), (25, 7), (28, 11), (32, 9), (35, 15), (36, 20), (30, 15), (22, 17), (16, 23)], hair, edge=E),
             dots([(23, 27), (25, 28), (31, 27)], I["skin0"])])                                              # freckles


def p_duras():
    fur = rr("outline", "brown0", "brown1")
    return (("outline", "red0"),
            shoulders(rr("red0", "red1"), collar=rr("brown0", "brown1")) +
            [dots([(20, 40), (20, 43), (28, 40), (28, 43)], I["ochre"])] +
            face(SKIN_DEAD, eye=I["blood"], brow=I["grey1"], mouth="fangs") +
            [poly([(12, 18), (36, 18), (37, 2), (32, -1), (18, -1), (11, 2)], fur, edge=E, post=R.stripes(I["outline"], 2, vertical=True)),
             line([(12, 17), (36, 17)], I["brown0"]), oval(26, 9, 1.6, 1.6, BRONZE_RAMP),
             poly([(14, 21), (9, 15), (12, 26)], SKIN_DEAD, edge=E),
             dots([(17, 27), (18, 28)], I["green2"])])


def p_ozo():
    return (("grey0", "teal"),
            shoulders(rr("silk0", "white"), collar=rr("teal", "cyan"), post=R.stripes(I["silk0"], 3, vertical=True)) +
            face(SKIN, eye=I["cyan"], brow=I["brown0"], mouth="flat") +
            [R.Shape("line", R.circle_pts(24, 22, 15, 15, 32) + [R.circle_pts(24, 22, 15, 15, 32)[0]], [I["cyan"]]),
             R.Shape("line", R.circle_pts(24, 22, 15, 15, 32)[18:24], [I["white"]]),
             dots([(14, 15), (15, 14)], I["white"]),
             poly([(11, 34), (37, 34), (35, 38), (13, 38)], rr("grey1", "grey2", "grey3"), edge=E),
             dots([(18, 36)], I["acid"]), dots([(30, 36)], I["magenta"])])


def p_fanfi():
    """The narrator: a vast, smug, see-through Atlantean, rising out of séance smoke."""
    ghost = rr("silk0", "grey4", "white")
    smoke = rr("grey1", "silk0", "grey4")
    S = [oval(10, 44, 12, 6, smoke), oval(38, 45, 12, 5, smoke), oval(24, 47, 14, 4, smoke)]
    S += [poly([(6, 48), (10, 38), (24, 34), (38, 38), (42, 48)], ghost, dither=True)]
    S += [oval(24, 21, 11, 13, ghost, dither=True)]
    S += [poly([(13, 18), (16, 10), (24, 7), (32, 10), (35, 18), (30, 13), (24, 12), (18, 13)], rr("grey3", "grey4", "white"))]
    # a glass circlet with a Lobizi stone: Atlantean royalty, deceased
    S += [path([(13, 14), (24, 11), (35, 14)], 1.0, rr("teal", "cyan")), oval(24, 11, 2.2, 2.2, rr("red1", "magenta")), dots([(23, 10)], I["white"])]
    # half-lidded, extremely pleased with himself
    S += [line([(17, 19), (22, 18)], I["silk0"]), line([(26, 18), (31, 19)], I["silk0"]),
          poly([(17, 20), (22, 20), (22, 22), (17, 22)], [I["white"]]), poly([(26, 20), (31, 20), (31, 22), (26, 22)], [I["white"]]),
          line([(17, 20), (22, 20)], I["silk0"]), line([(26, 20), (31, 20)], I["silk0"]),
          dots([(20, 21), (29, 21)], I["cyan"]),
          line([(24, 22), (25, 27)], I["silk0"]),
          line([(19, 30), (23, 31), (28, 30), (30, 28)], I["outline"])]
    S += [poly([(16, 29), (20, 34), (28, 34), (32, 29), (32, 36), (24, 44), (16, 36)], rr("silk0", "grey4", "white"), dither=True),
          line([(19, 30), (23, 31), (28, 30), (30, 28)], I["outline"])]
    # smoke curls up the sides
    S += [path([(5, 40), (4, 30), (8, 24), (6, 16)], 1.2, smoke), path([(43, 40), (44, 32), (40, 26), (43, 18)], 1.2, smoke),
          dots([(7, 12), (41, 14), (10, 8)], I["silk0"])]
    return (("outline", "blue0"), S)


PEOPLE = {
    "knight": p_knight, "necromancer": p_necromancer, "healer": p_healer, "vezina": p_healer,
    "dida": p_dida, "zia": p_zia, "mucapor": p_mucapor, "tsinna": p_tsinna, "rholes": p_rholes,
    "bitus": p_bitus, "duras": p_duras, "ozo": p_ozo, "fanfi": p_fanfi,
}


def portrait(spec):
    bg, shapes = PEOPLE[spec["who"]]()
    return compose(bg, shapes)


GENERATORS = {"portrait": portrait}

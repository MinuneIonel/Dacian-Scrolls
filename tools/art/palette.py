"""The locked 32-colour palette. Every generated PNG uses only these colours plus full transparency.

Index order is part of the contract: art code refers to colours by name, tests by RGB.
Do not add, remove or reorder entries without updating docs/art-style.md.
"""

# name, hex. Ramps run dark -> light.
COLOURS = [
    ("outline",   "#1a1218"),  # 0  black outline, warm
    # earth and wood
    ("brown0",    "#3a2318"),  # 1  dark wood, shadow of earth
    ("brown1",    "#5e3b25"),  # 2  wood, leather
    ("brown2",    "#8a5a34"),  # 3  light wood, packed earth
    ("brown3",    "#b88550"),  # 4  tan, road dust
    ("ochre",     "#d6a043"),  # 5  ochre, bronze, gold
    ("straw",     "#efd391"),  # 6  straw, parchment light, bronze highlight
    # stone and steel
    ("grey0",     "#2c2c35"),  # 7  slate shadow
    ("grey1",     "#4d4e58"),  # 8
    ("grey2",     "#77787e"),  # 9
    ("grey3",     "#a6a59f"),  # 10
    ("grey4",     "#d5d2c6"),  # 11 bone, light stone, steel shine
    # forest
    ("green0",    "#1b2d22"),  # 12 deep forest shadow
    ("green1",    "#2c4a2b"),  # 13
    ("green2",    "#466a32"),  # 14
    ("green3",    "#71913f"),  # 15
    ("green4",    "#a5b95a"),  # 16 sunlit grass
    # skin
    ("skin0",     "#7e4c37"),  # 17
    ("skin1",     "#c08463"),  # 18
    ("skin2",     "#efc39c"),  # 19
    # cloth
    ("red0",      "#5a1d22"),  # 20
    ("red1",      "#963131"),  # 21
    ("blue0",     "#1e2847"),  # 22
    ("blue1",     "#344f86"),  # 23
    ("blue2",     "#6f8ebe"),  # 24
    # silk of the Lobizi robes, also a cold highlight
    ("silk0",     "#8e83ad"),  # 25
    ("white",     "#f4efe2"),  # 26 ivory, silk light, specular
    # Lobizi tech: reserved, never on Dacian things
    ("teal",      "#1d5c66"),  # 27 dark glass, shadow under cyan
    ("cyan",      "#3fe3ea"),  # 28
    ("magenta",   "#ea40c6"),  # 29
    ("acid",      "#aaf23a"),  # 30
    # gore
    ("blood",     "#c40e2c"),  # 31
]

assert len(COLOURS) == 32
assert len({h for _, h in COLOURS}) == 32

NAMES = [n for n, _ in COLOURS]
IDX = {n: i for i, n in enumerate(NAMES)}
TRANSPARENT = 255


def _rgb(h: str) -> tuple:
    return (int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16))


RGB = [_rgb(h) for _, h in COLOURS]
RGB_SET = set(RGB)

# Colours reserved for Lobizi tech. Dacian assets must not use them.
LOBIZI = {"teal", "cyan", "magenta", "acid"}


def i(name: str) -> int:
    """Palette index by name."""
    return IDX[name]


def ramp(*names: str) -> list:
    return [IDX[n] for n in names]


# One step darker for each colour: drop shadows and tinting in compositions.
DARKER = {
    "outline": "outline", "brown0": "outline", "brown1": "brown0", "brown2": "brown1",
    "brown3": "brown2", "ochre": "brown2", "straw": "ochre", "grey0": "outline",
    "grey1": "grey0", "grey2": "grey1", "grey3": "grey2", "grey4": "grey3",
    "green0": "outline", "green1": "green0", "green2": "green1", "green3": "green2",
    "green4": "green3", "skin0": "brown0", "skin1": "skin0", "skin2": "skin1",
    "red0": "brown0", "red1": "red0", "blue0": "outline", "blue1": "blue0",
    "blue2": "blue1", "silk0": "grey1", "white": "grey3", "teal": "blue0",
    "cyan": "teal", "magenta": "red1", "acid": "green3", "blood": "red0",
}
DARKER_IDX = [IDX[DARKER[n]] for n in NAMES]

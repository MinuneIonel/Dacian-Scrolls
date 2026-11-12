#!/usr/bin/env python3
"""Builds the Dacian Scrolls pixel font: a hand-drawn 5x7 bitmap font.

Writes assets/fonts/dacian.png + dacian.fnt (BMFont text format, 11 px line) and a 2x copy
assets/fonts/dacian_title.png + dacian_title.fnt for titles. Glyphs are white on transparent;
Godot tints them with the theme's font colour.

Cell layout, top to bottom (11 rows): 2 rows for accents over capitals, 7 rows of cap height
(baseline under row 8), 2 rows of descender. Glyphs below are written in the 7 + 2 row space;
capital accents go in the two rows above.

Usage: python3 tools/font/build_font.py
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "assets", "fonts")
CELL_H = 11
TOP = 2          # rows reserved above the cap height for capital accents
BASE = 9         # baseline, counted from the top of the cell
LINE_H = 11

# Each glyph: list of rows, '#' = ink. Rows 0..6 sit above the baseline, rows 7..8 hang below.
G = {}

def glyph(chars, rows):
    for c in chars:
        G[c] = [r for r in rows]

S = str.split
glyph("A", S(".###. #...# #...# ##### #...# #...# #...#"))
glyph("B", S("####. #...# #...# ####. #...# #...# ####."))
glyph("C", S(".###. #...# #.... #.... #.... #...# .###."))
glyph("D", S("####. #...# #...# #...# #...# #...# ####."))
glyph("E", S("##### #.... #.... ####. #.... #.... #####"))
glyph("F", S("##### #.... #.... ####. #.... #.... #...."))
glyph("G", S(".###. #...# #.... #.### #...# #...# .####"))
glyph("H", S("#...# #...# #...# ##### #...# #...# #...#"))
glyph("I", S("### .#. .#. .#. .#. .#. ###"))
glyph("J", S("..### ...#. ...#. ...#. ...#. #..#. .##.."))
glyph("K", S("#...# #..#. #.#.. ##... #.#.. #..#. #...#"))
glyph("L", S("#.... #.... #.... #.... #.... #.... #####"))
glyph("M", S("#...# ##.## #.#.# #.#.# #...# #...# #...#"))
glyph("N", S("#...# #...# ##..# #.#.# #..## #...# #...#"))
glyph("O", S(".###. #...# #...# #...# #...# #...# .###."))
glyph("P", S("####. #...# #...# ####. #.... #.... #...."))
glyph("Q", S(".###. #...# #...# #...# #.#.# #..#. .##.#"))
glyph("R", S("####. #...# #...# ####. #.#.. #..#. #...#"))
glyph("S", S(".###. #...# #.... .###. ....# #...# .###."))
glyph("T", S("##### ..#.. ..#.. ..#.. ..#.. ..#.. ..#.."))
glyph("U", S("#...# #...# #...# #...# #...# #...# .###."))
glyph("V", S("#...# #...# #...# #...# #...# .#.#. ..#.."))
glyph("W", S("#...# #...# #...# #.#.# #.#.# ##.## #...#"))
glyph("X", S("#...# #...# .#.#. ..#.. .#.#. #...# #...#"))
glyph("Y", S("#...# #...# .#.#. ..#.. ..#.. ..#.. ..#.."))
glyph("Z", S("##### ....# ...#. ..#.. .#... #.... #####"))

glyph("a", S("..... ..... .###. ....# .#### #...# .####"))
glyph("b", S("#.... #.... ####. #...# #...# #...# ####."))
glyph("c", S(".... .... .### #... #... #... .###"))
glyph("d", S("....# ....# .#### #...# #...# #...# .####"))
glyph("e", S("..... ..... .###. #...# ##### #.... .###."))
glyph("f", S("..## .#.. #### .#.. .#.. .#.. .#.."))
glyph("g", S("..... ..... .#### #...# #...# #...# .#### ....# .###."))
glyph("h", S("#.... #.... ####. #...# #...# #...# #...#"))
glyph("i", S(".#. ... ##. .#. .#. .#. ###"))
glyph("j", S("..# ... .## ..# ..# ..# ..# ..# ##."))
glyph("k", S("#... #... #..# #.#. ##.. #.#. #..#"))
glyph("l", S("##. .#. .#. .#. .#. .#. ###"))
glyph("m", S("..... ..... ##.#. #.#.# #.#.# #.#.# #...#"))
glyph("n", S("..... ..... ####. #...# #...# #...# #...#"))
glyph("o", S("..... ..... .###. #...# #...# #...# .###."))
glyph("p", S("..... ..... ####. #...# #...# #...# ####. #.... #...."))
glyph("q", S("..... ..... .#### #...# #...# #...# .#### ....# ....#"))
glyph("r", S(".... .... #.## ##.. #... #... #..."))
glyph("s", S(".... .... .### #... .##. ...# ###."))
glyph("t", S(".#.. .#.. #### .#.. .#.. .#.. ..##"))
glyph("u", S("..... ..... #...# #...# #...# #..## .##.#"))
glyph("v", S("..... ..... #...# #...# #...# .#.#. ..#.."))
glyph("w", S("..... ..... #...# #...# #.#.# #.#.# .#.#."))
glyph("x", S("..... ..... #...# .#.#. ..#.. .#.#. #...#"))
glyph("y", S("..... ..... #...# #...# #...# #...# .#### ....# .###."))
glyph("z", S("..... ..... ##### ...#. ..#.. .#... #####"))

glyph("0", S(".###. #...# #..## #.#.# ##..# #...# .###."))
glyph("1", S("..#.. .##.. ..#.. ..#.. ..#.. ..#.. .###."))
glyph("2", S(".###. #...# ....# ...#. ..#.. .#... #####"))
glyph("3", S(".###. #...# ....# ..##. ....# #...# .###."))
glyph("4", S("...#. ..##. .#.#. #..#. ##### ...#. ...#."))
glyph("5", S("##### #.... ####. ....# ....# #...# .###."))
glyph("6", S("..##. .#... #.... ####. #...# #...# .###."))
glyph("7", S("##### ....# ...#. ..#.. .#... .#... .#..."))
glyph("8", S(".###. #...# #...# .###. #...# #...# .###."))
glyph("9", S(".###. #...# #...# .#### ....# ...#. .##.."))

glyph("!", S("# # # # # . #"))
glyph('"', S("#.# #.# ... ... ... ... ..."))
glyph("#", S(".#.#. .#.#. ##### .#.#. ##### .#.#. .#.#."))
glyph("$", S("..#.. .#### #.#.. .###. ..#.# ####. ..#.."))
glyph("%", S("##..# ##..# ...#. ..#.. .#... #..## #..##"))
glyph("&", S(".##.. #..#. #.#.. .#... #.#.# #..#. .##.#"))
glyph("'", S("# # . . . . ."))
glyph("(", S(".# #. #. #. #. #. .#"))
glyph(")", S("#. .# .# .# .# .# #."))
glyph("*", S("..... ..#.. #.#.# .###. #.#.# ..#.. ....."))
glyph("+", S("..... ..#.. ..#.. ##### ..#.. ..#.. ....."))
glyph(",", S(".. .. .. .. .. .. .# #."))
glyph("-", S(".... .... .... #### .... .... ...."))
glyph(".", S(". . . . . . #"))
glyph("/", S("....# ....# ...#. ..#.. .#... #.... #...."))
glyph(":", S(". . # . . . #"))
glyph(";", S(".. .. .# .. .. .. .# #."))
glyph("<", S("...# ..#. .#.. #... .#.. ..#. ...#"))
glyph("=", S(".... .... #### .... #### .... ...."))
glyph(">", S("#... .#.. ..#. ...# ..#. .#.. #..."))
glyph("?", S(".###. #...# ....# ...#. ..#.. ..... ..#.."))
glyph("@", S(".###. #...# #.### #.#.# #.### #.... .###."))
glyph("[", S("## #. #. #. #. #. ##"))
glyph("\\", S("#.... #.... .#... ..#.. ...#. ....# ....#"))
glyph("]", S("## .# .# .# .# .# ##"))
glyph("^", S("..#.. .#.#. #...# ..... ..... ..... ....."))
glyph("_", S("..... ..... ..... ..... ..... ..... ..... #####"))
glyph("`", S("#. .# .. .. .. .. .."))
glyph("{", S("..# .#. .#. #.. .#. .#. ..#"))
glyph("|", S("# # # # # # # #"))
glyph("}", S("#.. .#. .#. ..# .#. .#. #.."))
glyph("~", S("..... ..... .#... #.#.# ...#. ..... ....."))
glyph("…", S("..... ..... ..... ..... ..... ..... #.#.#"))   # …
glyph("–", S("..... ..... ..... ##### ..... ..... ....."))   # –
glyph("—", S("....... ....... ....... ####### ....... ....... ......."))  # —
glyph("’", S(".# .# #. .. .. .. .."))   # ’
glyph("‘", S(".# #. ## .. .. .. .."))   # ‘
glyph("“", S(".#.# #.#. ##.# .... .... .... ...."))   # “
glyph("”", S(".#.# .#.# #.#. .... .... .... ...."))   # ”
glyph("·", S(". . . # . . ."))          # ·

BREVE = ["#.#", ".#."]
CIRC = [".#.", "#.#"]
ACUTE = ["..#", ".#."]
GRAVE = ["#..", ".#."]
UML = ["#.#", "..."]
COMMA = [".#", "#."]

def compose(base_ch, new_ch, accent, below=False):
    """New glyph = base + accent. Lowercase accents sit in rows 0-1 (above the x-height),
    capital accents in the two reserved rows above the cell, commas in the descender."""
    rows = [r for r in G[base_ch]] + []
    w = len(rows[0])
    rows += ["." * w] * (9 - len(rows))
    aw = len(accent[0])
    pad = (w - aw + 1) // 2
    placed = ["." * pad + a + "." * (w - aw - pad) for a in accent]
    if below:
        rows[7], rows[8] = placed
        G[new_ch] = rows
    elif base_ch.isupper():
        G[new_ch] = (placed, rows)   # tuple: extra rows above the cap height
    else:
        rows[0], rows[1] = placed
        G[new_ch] = rows

compose("a", "ă", BREVE); compose("A", "Ă", BREVE)     # ă Ă
compose("a", "â", CIRC);  compose("A", "Â", CIRC)      # â Â
compose("I", "Î", CIRC)                                     # Î
G["î"] = S(".#. #.# ##. .#. .#. .#. ###")                   # î (circumflex replaces dot)
compose("s", "ș", COMMA, below=True); compose("S", "Ș", COMMA, below=True)  # ș Ș
compose("t", "ț", COMMA, below=True); compose("T", "Ț", COMMA, below=True)  # ț Ț
G["ş"] = G["ș"]; G["Ş"] = G["Ș"]             # ş Ş (cedilla forms)
G["ţ"] = G["ț"]; G["Ţ"] = G["Ț"]             # ţ Ţ
compose("e", "é", ACUTE); compose("E", "É", ACUTE)     # é É
compose("e", "è", GRAVE)                                    # è
compose("u", "ü", UML); compose("o", "ö", UML); compose("a", "ä", UML)

SPACE_ADVANCE = 4


def cell(ch):
    """Returns the glyph as an 11-row list of strings."""
    g = G[ch]
    above = ["", ""]
    if isinstance(g, tuple):
        above, g = g
    w = len(g[0])
    for r in g:
        assert len(r) == w, "glyph %r has uneven rows" % ch
    body = list(g) + ["." * w] * (9 - len(g))
    assert len(body) == 9, "glyph %r has %d rows" % (ch, len(g))
    top = [a if a else "." * w for a in above]
    return top + body


def build(scale, name):
    chars = sorted(G.keys(), key=ord)
    cols = 16
    cw = max(len(cell(c)[0]) for c in chars) + 1
    ch_h = CELL_H + 1
    rows = (len(chars) + cols - 1) // cols
    w, h = cols * cw * scale, rows * ch_h * scale
    tw = 1
    while tw < w: tw *= 2
    th = 1
    while th < h: th *= 2
    img = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    px = img.load()
    lines = []
    for i, c in enumerate(chars):
        gx, gy = (i % cols) * cw, (i // cols) * ch_h
        grid = cell(c)
        gw = len(grid[0])
        for y, row in enumerate(grid):
            for x, v in enumerate(row):
                if v == "#":
                    for sy in range(scale):
                        for sx in range(scale):
                            px[(gx + x) * scale + sx, (gy + y) * scale + sy] = (255, 255, 255, 255)
        lines.append("char id=%d x=%d y=%d width=%d height=%d xoffset=0 yoffset=0 xadvance=%d page=0 chnl=15"
                     % (ord(c), gx * scale, gy * scale, gw * scale, CELL_H * scale, (gw + 1) * scale))
    lines.insert(0, "char id=32 x=0 y=0 width=0 height=0 xoffset=0 yoffset=0 xadvance=%d page=0 chnl=15"
                 % (SPACE_ADVANCE * scale))
    png = name + ".png"
    img.save(os.path.join(OUT_DIR, png))
    head = [
        'info face="Dacian" size=%d bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1 outline=0'
        % (LINE_H * scale),
        "common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0 alphaChnl=0 redChnl=4 greenChnl=4 blueChnl=4"
        % (LINE_H * scale, BASE * scale, tw, th),
        'page id=0 file="%s"' % png,
        "chars count=%d" % (len(lines)),
    ]
    with open(os.path.join(OUT_DIR, name + ".fnt"), "w", newline="\n") as f:
        f.write("\n".join(head + lines) + "\n")
    return len(lines)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    n = build(1, "dacian")
    build(2, "dacian_title")
    print("built %d glyphs into %s" % (n, os.path.relpath(OUT_DIR, ROOT)))


if __name__ == "__main__":
    main()

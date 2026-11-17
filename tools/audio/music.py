"""The two music tracks, as loop-aligned stems.

sarmizegetusa: 96 BPM, 32 bars of 4/4, D Dorian with a raised fourth (D E F G# A B C).
  Form A (1-8) A' (9-16) B (17-24) A'' (25-32). Stems: explore, combat, lobizi.
saucer: 96 BPM, 16 bars. The Lobizi material alone with a detuned tulnic. Stems: lobizi, combat.
"""
from __future__ import annotations

import numpy as np

import synth as s
from synth import SR, Bus

BPM = 96
SCALE = [0, 2, 3, 6, 7, 9, 10]      # D Dorian #4 in semitones above D
NAI_BASE = 74                        # D5
COBZA_BASE = 62                      # D4

# Chord per bar: root midi (bass register) and voicing (cobza / pad register).
CHORDS = {
    "Dm": (38, [50, 57, 62, 65]),
    "Am": (33, [45, 52, 57, 60]),
    "E": (40, [52, 56, 59, 64]),
    "F": (41, [53, 57, 60, 65]),
}
FIFTH = {"Dm": 45, "Am": 40, "E": 47, "F": 48}
SECTION_A = ["Dm", "Am", "Dm", "Dm", "Dm", "Am", "E", "Dm"]
SECTION_B = ["F", "Am", "Dm", "E", "Dm", "Am", "E", "E"]
PROGRESSION = SECTION_A + SECTION_A + SECTION_B + SECTION_A

# Melody: one list of (scale degree or None for a rest, length in eighths) per bar.
A = [
    [(4, 3), (3, 1), (4, 2), (7, 2)],
    [(6, 2), (5, 1), (4, 1), (3, 2), (4, 2)],
    [(2, 2), (3, 1), (2, 1), (1, 2), (2, 2)],
    [(1, 2), (0, 6)],
    [(4, 3), (3, 1), (4, 2), (7, 2)],
    [(8, 2), (7, 1), (6, 1), (5, 2), (6, 1), (5, 1)],
    [(4, 2), (3, 1), (2, 1), (3, 2), (1, 2)],
    [(0, 6), (None, 2)],
]
A2 = [  # rhythmic variation, climbs to F in the answer
    [(4, 2), (5, 1), (4, 1), (3, 1), (4, 1), (7, 2)],
    [(6, 1), (7, 1), (6, 1), (5, 1), (4, 1), (3, 1), (4, 2)],
    [(2, 2), (3, 1), (2, 1), (1, 1), (2, 1), (3, 2)],
    [(1, 2), (0, 4), (None, 2)],
    [(4, 3), (3, 1), (4, 2), (9, 2)],
    [(8, 3), (7, 1), (6, 1), (5, 1), (6, 2)],
    [(4, 2), (3, 1), (2, 1), (3, 1), (2, 1), (1, 2)],
    [(0, 8)],
]
B = [  # the high register, over F and E
    [(9, 4), (8, 2), (7, 2)],
    [(6, 3), (7, 1), (8, 4)],
    [(9, 2), (10, 2), (9, 1), (8, 1), (7, 2)],
    [(8, 6), (None, 2)],
    [(7, 2), (6, 2), (5, 2), (6, 2)],
    [(4, 3), (5, 1), (6, 2), (4, 2)],
    [(3, 2), (2, 2), (3, 2), (1, 2)],
    [(1, 6), (None, 2)],
]
COUNTER = [  # nai holds a slow line while the cobza takes the tune (bars 25-28)
    [(7, 8)], [(6, 8)], [(5, 4), (3, 4)], [(4, 6), (None, 2)],
]
ENDING = [A[4], A[5], A[6], [(0, 6), (None, 2)]]


def deg_midi(d: int, base: int) -> int:
    return base + 12 * (d // 7) + SCALE[d % 7]


class Song:
    def __init__(self, bars: int, bpm: int = BPM):
        self.bars = bars
        self.spb = 60.0 / bpm * SR          # samples per beat
        L = bars * 4 * self.spb
        assert abs(L - round(L)) < 1e-6, "loop length must be a whole number of samples"
        self.L = int(round(L))
        self.beat_s = 60.0 / bpm

    def at(self, beat: float) -> int:
        return int(round(beat * self.spb))

    def bus(self) -> Bus:
        return Bus(self.L, loop=True)


def phrase_events(bars: list, first_bar: int, base: int) -> list[tuple[float, float, int]]:
    """(start beat, length in beats, midi) for a list of bars."""
    out = []
    for i, bar in enumerate(bars):
        beat = (first_bar + i) * 4.0
        for d, eighths in bar:
            if d is not None:
                out.append((beat, eighths / 2.0, deg_midi(d, base)))
            beat += eighths / 2.0
    return out


def ornament(events: list, rng: np.random.Generator, base: int, prob: float = 0.6) -> list:
    """Folk ornaments on long notes: a grace note from above, or a quick mordent.
    Returns events with an extra 'grace' field: list of (offset beats, midi)."""
    out = []
    for (b, ln, m) in events:
        graces = []
        if ln >= 1.0 and rng.random() < prob:
            upper = next(deg_midi(d, base) for d in range(30) if deg_midi(d, base) > m)
            if rng.random() < 0.55:
                graces = [(-0.09, upper)]
            else:
                lower = max(deg_midi(d, base) for d in range(30) if deg_midi(d, base) < m) \
                    if m > base else m - 2
                graces = [(0.0, m), (0.07, upper if rng.random() < 0.5 else lower)]
        out.append((b, ln, m, graces))
    return out


def play_nai(bus: Bus, song: Song, evs: list, rng: np.random.Generator, gain: float = 1.0,
             pan: float = -0.15) -> None:
    for e in evs:
        b, ln, m = e[0], e[1], e[2]
        graces = e[3] if len(e) > 3 else []
        dur = ln * song.beat_s * 0.94
        start = song.at(b)
        main_off = 0.0
        for off, gm in graces:
            g = s.nai(s.hz(gm), 0.06, rng, amp=0.7, scoop=0.0, release=0.03)
            bus.add(g, start + s.n_of(off), pan, gain)   # negative offsets wrap on the loop
            if off >= 0:
                main_off = max(main_off, off + 0.06)
        n = s.nai(s.hz(m), max(0.08, dur - main_off), rng, amp=1.0,
                  scoop=0.0 if main_off else 0.35)
        bus.add(n, start + s.n_of(main_off), pan, gain)


def strum(bus: Bus, song: Song, beat: float, notes: list, rng: np.random.Generator,
          dur: float, gain: float, pan: float, down: bool = True, spread: float = 0.012) -> None:
    order = notes if down else notes[::-1]
    for i, m in enumerate(order):
        x = s.cobza(s.hz(m), dur, rng, amp=1.0 - 0.08 * i, bright=0.55 + 0.1 * rng.random())
        bus.add(x, song.at(beat) + s.n_of(i * spread), pan, gain)


# ================================================================= sarmizegetusa

def sarmizegetusa_explore(song: Song, rng: np.random.Generator) -> np.ndarray:
    nai_bus, cob_bus = song.bus(), song.bus()
    # melody
    evs = phrase_events(A, 0, NAI_BASE)
    evs = [(b, ln, m, []) for b, ln, m in evs]
    evs += ornament(phrase_events(A2, 8, NAI_BASE), rng, NAI_BASE, 0.55)
    evs += ornament(phrase_events(B, 16, NAI_BASE), rng, NAI_BASE, 0.4)
    evs += [(b, ln, m, []) for b, ln, m in phrase_events(COUNTER, 24, NAI_BASE - 12)]
    evs += ornament(phrase_events(ENDING, 28, NAI_BASE), rng, NAI_BASE, 0.7)
    play_nai(nai_bus, song, evs, rng, 1.0, -0.15)

    # cobza
    bl = song.beat_s
    for bar, ch in enumerate(PROGRESSION):
        root, voicing = CHORDS[ch]
        b0 = bar * 4.0
        low = root + 12
        if bar < 8:          # sparse: root on 1, strum on 3
            strum(cob_bus, song, b0, [low], rng, 1.8 * bl, 0.9, 0.25)
            strum(cob_bus, song, b0 + 2, voicing, rng, 1.8 * bl, 0.55, 0.3)
            if bar % 2 == 1:
                strum(cob_bus, song, b0 + 3.5, voicing[1:], rng, 0.45 * bl, 0.35, 0.3, False)
        elif 24 <= bar < 28:  # the cobza takes the tune with tremolo picking, an octave down
            strum(cob_bus, song, b0, [low], rng, 1.8 * bl, 0.8, 0.25)
            strum(cob_bus, song, b0 + 2, [FIFTH[ch] + 12], rng, 1.8 * bl, 0.6, 0.25)
        else:                # tiitura: roots on 1 and 3, offbeat chords
            for beat in range(4):
                if beat % 2 == 0:
                    m = low if beat == 0 else FIFTH[ch] + 12
                    strum(cob_bus, song, b0 + beat, [m], rng, 0.45 * bl, 0.85, 0.2)
                strum(cob_bus, song, b0 + beat + 0.5, voicing[1:], rng, 0.4 * bl, 0.42, 0.35,
                      down=beat % 2 == 0, spread=0.008)
    for b, ln, m in phrase_events(A[:4], 24, COBZA_BASE):
        n16 = max(1, int(round(ln * 4)))
        for k in range(n16):
            x = s.cobza(s.hz(m), 0.25 * bl * 1.2, rng, amp=0.95 if k == 0 else 0.6,
                        bright=0.7, t60=1.2)
            cob_bus.add(x, song.at(b + 0.25 * k), 0.1, 0.75)

    # drone: D2 A2 D3, breathing over four bars
    drone = s.drone_loop(song.L, [38, 45, 50], rng, amp=1.0, swell_period=song.at(16))

    out = song.bus()
    out.mix(nai_bus, 1.0)
    out.mix(cob_bus, 0.9)
    s.reverb(out, rng, t60=2.2, wet=0.28)
    out.buf += 0.16 * drone
    return s.master(out.buf, rms_db=-20.0)


def sarmizegetusa_combat(song: Song, rng: np.random.Generator) -> np.ndarray:
    dr, bass, cob = song.bus(), song.bus(), song.bus()
    toba_a = [1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0]
    toba_b = [1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 0, 1, 0]
    # dairea: D=dum, T=accented tek, t=soft tek, .=rest
    dairea = "D.t.T.tD.Dt.T.tt"
    for bar, ch in enumerate(PROGRESSION):
        b0 = bar * 4.0
        in_b = 16 <= bar < 24
        fill = bar % 8 == 7
        toba = toba_b if in_b else toba_a
        for st in range(16):
            beat = b0 + st * 0.25
            if fill and st >= 8:
                dr.add(s.frame_drum(rng, "tek", 0.35 + 0.05 * (st - 8)), song.at(beat), 0.2)
                if st in (8, 11, 14):
                    dr.add(s.low_drum(rng, 0.9), song.at(beat), 0.0)
                continue
            if toba[st]:
                dr.add(s.low_drum(rng, 1.0 if st % 8 == 0 else 0.7), song.at(beat), 0.0)
            c = dairea[st]
            if c == "D":
                dr.add(s.frame_drum(rng, "dum", 0.8), song.at(beat), 0.2)
            elif c == "T":
                dr.add(s.frame_drum(rng, "tek", 0.7), song.at(beat), 0.2)
            elif c == "t":
                dr.add(s.frame_drum(rng, "tek", 0.35), song.at(beat), 0.2)
            elif in_b:
                dr.add(s.frame_drum(rng, "jingle", 0.25), song.at(beat), 0.25)
        # bass: root . root fifth root . octave fifth
        root = CHORDS[ch][0]
        pat = [root, None, root, FIFTH[ch] - 12, root, None, root + 12, FIFTH[ch] - 12]
        for k, m in enumerate(pat):
            if m is None:
                continue
            x = s.cobza(s.hz(m), 0.42 * song.beat_s, rng, amp=1.0, bright=0.45, t60=1.0)
            x = x + 0.6 * s.fft_filter(x, s.lp(180, 2))
            e = s.env(0.42 * song.beat_s, a=0.005, d=0.15, s=0.5, r=0.05)
            sub = np.sin(s.TAU * s.hz(m) * np.arange(len(e)) / SR) * e
            n = min(len(x), len(sub))
            bass.add(x[:n] + 0.7 * sub[:n], song.at(b0 + k * 0.5), 0.0)
        # fast cobza: 16th arpeggios of the chord, mid register
        v = [m + 12 for m in CHORDS[ch][1]]
        idx = [0, 1, 2, 1, 3, 2, 1, 2] if not in_b else [0, 1, 2, 3, 2, 1, 2, 3]
        for st in range(16):
            m = v[idx[st % 8]]
            acc = 0.9 if st % 4 == 0 else 0.55
            x = s.cobza(s.hz(m), 0.22 * song.beat_s, rng, amp=acc, bright=0.75, t60=0.9)
            cob.add(x, song.at(b0 + st * 0.25), -0.45)
    out = song.bus()
    out.mix(dr, 1.0)
    out.mix(bass, 0.55)
    out.mix(cob, 0.4)
    s.reverb(out, rng, t60=1.4, wet=0.14)
    return s.master(out.buf, rms_db=-19.0)


def lobizi_layer(song: Song, rng: np.random.Generator, progression: list[str],
                 sweep_bars: int, lo: float, hi: float, detune: float, arp_rate: float,
                 arp_oct: int, dense_bars: set[int]) -> Bus:
    pad, arp, subb = song.bus(), song.bus(), song.bus()
    # pad: merge repeated chords into one long note
    runs = []
    for bar, ch in enumerate(progression):
        if runs and runs[-1][0] == ch:
            runs[-1][2] += 1
        else:
            runs.append([ch, bar, 1])
    for ch, bar, nb in runs:
        dur = nb * 4 * song.beat_s
        x = s.saw_pad(CHORDS[ch][1], dur, rng, detune=detune)
        pad.add(x, song.at(bar * 4.0))
    period = sweep_bars * 4 * song.beat_s
    s.sweep_filter(pad, lambda t: lo * (hi / lo) ** ((1 - np.cos(s.TAU * t / period)) / 2), q=1.4)
    # arpeggio: chord tones over two octaves
    pattern = [0, 1, 2, 3, 4, 3, 2, 1]
    for bar, ch in enumerate(progression):
        v = CHORDS[ch][1]
        tones = [m + 12 * arp_oct for m in v[:3]] + [m + 12 * (arp_oct + 1) for m in v[:3]]
        steps = int(4 / arp_rate)
        dense = bar in dense_bars
        for st in range(steps):
            if not dense and st % 2 == 1:
                continue
            m = tones[pattern[st % 8] % len(tones)]
            cut = 1400 + 1600 * (0.5 + 0.5 * np.sin(s.TAU * (bar * steps + st) / (steps * 8)))
            x = s.arp_pluck(s.hz(m), arp_rate * song.beat_s, rng, amp=1.0 if st % 4 == 0 else 0.7,
                            cutoff=cut)
            arp.add(x, song.at(bar * 4.0 + st * arp_rate), 0.3 if st % 2 else -0.3)
    s.delay(arp, 0.75 * song.beat_s, feedback=0.45, wet=0.35)
    # sub throb on the root
    for bar, ch in enumerate(progression):
        f = s.hz(CHORDS[ch][0])
        n = s.n_of(4 * song.beat_s + 0.3)
        t = np.arange(n) / SR
        x = np.sin(s.TAU * f * t) * s.env(4 * song.beat_s, a=0.3, d=1.0, s=0.8, r=0.3)[:n]
        subb.add(x, song.at(bar * 4.0))
    out = song.bus()
    out.mix(pad, 1.0)
    out.mix(arp, 0.18)
    out.mix(subb, 0.12)
    return out


def sarmizegetusa_lobizi(song: Song, rng: np.random.Generator) -> np.ndarray:
    dense = set(range(16, 24)) | {6, 7, 14, 15, 30, 31}
    out = lobizi_layer(song, rng, PROGRESSION, sweep_bars=8, lo=260.0, hi=3400.0, detune=11.0,
                       arp_rate=0.25, arp_oct=1, dense_bars=dense)
    s.reverb(out, rng, t60=3.0, wet=0.35, dark=2500)
    return s.master(out.buf, rms_db=-21.0)


# ================================================================= saucer

SAUCER_PROG = ["Dm", "Dm", "E", "E", "F", "F", "E", "E"] * 2
D2 = s.hz(38)


def saucer_lobizi(song: Song, rng: np.random.Generator) -> np.ndarray:
    out = lobizi_layer(song, rng, SAUCER_PROG, sweep_bars=16, lo=200.0, hi=1900.0, detune=19.0,
                       arp_rate=0.5, arp_oct=0, dense_bars=set(range(4, 8)) | set(range(12, 16)))
    # detuned tulnic duo on the natural harmonics of D2: 5 (F# a bit flat) and 7 (C very flat)
    tul = song.bus()
    calls = [  # (bar, length in bars, harmonic, glide to harmonic or None, droop cents)
        (0, 3.0, 4, None, -60), (4, 2.0, 6, 5, 0), (8, 3.0, 5, None, -120), (12, 2.5, 7, 6, -200),
    ]
    for bar, nb, h, g, droop in calls:
        dur = nb * 4 * song.beat_s
        for pan, det, lag in ((-0.6, -21.0, 0.0), (0.6, 17.0, 0.09)):
            f = D2 * h * s.cents(det)
            x = s.tulnic(f, dur, rng, bend=-70, swell=1.2, droop=droop, release=1.2,
                         glide_to=(D2 * g * s.cents(det)) if g else None, vib=0.006)
            tul.add(x, song.at(bar * 4.0) + s.n_of(lag), pan, 0.5)
    out.mix(tul, 0.5)
    s.reverb(out, rng, t60=3.6, wet=0.42, dark=2000)
    return s.master(out.buf, rms_db=-21.0)


def saucer_combat(song: Song, rng: np.random.Generator) -> np.ndarray:
    dr, bass = song.bus(), song.bus()
    kick_p = [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0]
    for bar, ch in enumerate(SAUCER_PROG):
        b0 = bar * 4.0
        fill = bar % 8 == 7
        for st in range(16):
            beat = b0 + st * 0.25
            if kick_p[st]:
                dr.add(s.kick(rng, 1.0), song.at(beat))
            if st in (4, 12) or (fill and st >= 12):
                dr.add(s.snare(rng, 0.8 if not fill else 0.5 + 0.1 * (st - 12)), song.at(beat), 0.1)
            dr.add(s.hat(rng, 0.7 if st % 2 == 0 else 0.4, open_=st == 14), song.at(beat), 0.35)
        root = CHORDS[ch][0]
        for st in range(16):
            if st % 4 == 3:
                continue
            m = root + (12 if st % 8 == 6 else 0)
            cut = 450 + 900 * (st % 4 == 0)
            bass.add(s.bass_synth(s.hz(m), 0.2 * song.beat_s, rng, cutoff=cut),
                     song.at(b0 + st * 0.25))
    out = song.bus()
    out.mix(dr, 1.0)
    out.mix(bass, 0.6)
    s.reverb(out, rng, t60=1.2, wet=0.12)
    return s.master(out.buf, rms_db=-19.0)


TRACKS = {
    "sarmizegetusa": (32, {
        "explore": sarmizegetusa_explore,
        "combat": sarmizegetusa_combat,
        "lobizi": sarmizegetusa_lobizi,
    }),
    "saucer": (16, {
        "lobizi": saucer_lobizi,
        "combat": saucer_combat,
    }),
}


def render_track(name: str, seed: int = 101) -> dict[str, np.ndarray]:
    bars, stems = TRACKS[name]
    song = Song(bars)
    out = {}
    for i, (layer, fn) in enumerate(stems.items()):
        out[layer] = fn(song, np.random.default_rng(seed * 100 + i + len(name)))
    return out

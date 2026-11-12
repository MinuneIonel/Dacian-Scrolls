"""Stingers and sound effects. Each function takes a numpy Generator and returns a mono or
stereo float array; build.py normalises the peak to the level listed in SFX / STINGERS."""
from __future__ import annotations

import numpy as np

import synth as s
from synth import SR, TAU, Bus

BEAT = 60.0 / 96


def _t(n: int) -> np.ndarray:
    return np.arange(n) / SR


def _bus() -> Bus:
    return Bus(1, loop=False)


# ---------------------------------------------------------------- stingers

def abduction(rng: np.random.Generator) -> np.ndarray:
    """Tractor beam grabs you: a rising warble, a pad chord swelling and a detuned tulnic that
    falls away as the ground does."""
    b = _bus()
    n = s.n_of(3.6)
    t = _t(n)
    f = 110 * 2 ** (3.2 * (t / 3.6) ** 1.5)
    warble = 1 + 0.03 * np.sin(TAU * 9 * t)
    x = s.saw(1.0, n, f_mult=f * warble)
    x = s.fft_filter(x, s.chain(s.lp(2500, 2), s.hp(120)))
    e = s.raised(n) ** 0.5 * (1 - s.raised(n) ** 6)
    b.add(x * e, 0, 0.0, 0.35)
    pad = s.saw_pad([50, 56, 63], 2.2, rng, detune=24, attack=1.2, release=1.2, sub=False)
    b.add(s.fft_filter(pad, s.lp(1600, 2)), 0, 0.0, 1.2)
    for pan, det in ((-0.5, -25.0), (0.5, 20.0)):
        tu = s.tulnic(s.hz(57) * s.cents(det), 1.4, rng, bend=-30, swell=0.2, droop=-700, release=0.8)
        b.add(tu, s.n_of(0.5), pan, 0.45)
    b.add(s.low_drum(rng, 1.0, pitch=40), 0, 0.0, 0.8)
    s.reverb(b, rng, t60=2.5, wet=0.35)
    return b.buf


def page_found(rng: np.random.Generator) -> np.ndarray:
    """A cobza flourish up the mode and a nai answer landing on a bright D major."""
    b = _bus()
    run = [62, 64, 65, 68, 69, 74]
    for i, m in enumerate(run):
        b.add(s.cobza(s.hz(m), 0.6, rng, bright=0.75), s.n_of(i * 0.07), 0.2, 0.8)
    for i, m in enumerate([50, 57, 62, 66, 69]):
        b.add(s.cobza(s.hz(m), 1.4, rng, bright=0.6), s.n_of(0.45 + i * 0.015), 0.2, 0.6)
    b.add(s.nai(s.hz(81), 0.18, rng), s.n_of(0.45), -0.2, 0.7)
    b.add(s.nai(s.hz(78), 0.12, rng, scoop=0), s.n_of(0.65), -0.2, 0.6)
    b.add(s.nai(s.hz(86), 1.0, rng), s.n_of(0.8), -0.2, 0.75)
    s.reverb(b, rng, t60=2.0, wet=0.3)
    return b.buf


def level_up(rng: np.random.Generator) -> np.ndarray:
    """Tulnic call D-A-D over a frame drum roll and a final strum."""
    b = _bus()
    for i, (m, d) in enumerate(((50, 0.3), (57, 0.3), (62, 1.3))):
        b.add(s.tulnic(s.hz(m), d, rng, bend=-35, swell=0.06, release=0.5), s.n_of(i * 0.32), -0.1, 0.8)
    for k in range(12):
        b.add(s.frame_drum(rng, "tek", 0.2 + 0.04 * k), s.n_of(k * 0.055), 0.3)
    b.add(s.frame_drum(rng, "dum", 1.0), s.n_of(0.64), 0.2)
    b.add(s.low_drum(rng, 0.9), s.n_of(0.64), 0.0)
    for i, m in enumerate([50, 57, 62, 66, 69, 74]):
        b.add(s.cobza(s.hz(m), 1.5, rng, bright=0.7), s.n_of(0.64 + i * 0.012), 0.3, 0.55)
    s.reverb(b, rng, t60=2.0, wet=0.28)
    return b.buf


def defeat(rng: np.random.Generator) -> np.ndarray:
    """A tulnic sad-trombone: three falling notes and a long droop, with a lonely drum."""
    b = _bus()
    notes = [(57, 0.42, 0), (56, 0.42, 0), (55, 0.42, 0), (54, 1.6, -260)]
    t0 = 0.0
    for m, d, droop in notes:
        b.add(s.tulnic(s.hz(m - 12), d, rng, bend=-25, swell=0.05, droop=droop, release=0.25,
                       vib=0.02 if d > 1 else 0.0), s.n_of(t0), 0.0, 0.9)
        t0 += d + 0.08
    b.add(s.low_drum(rng, 0.8, pitch=44), s.n_of(t0 - 1.6), 0.0, 0.6)
    s.reverb(b, rng, t60=1.8, wet=0.25)
    return b.buf


STINGERS = {"abduction": (abduction, -3.0), "page_found": (page_found, -3.0),
            "level_up": (level_up, -3.0), "defeat": (defeat, -3.0)}


# ---------------------------------------------------------------- sfx

def step(rng: np.random.Generator) -> np.ndarray:
    n = s.n_of(0.12)
    t = _t(n)
    grit = s.fft_filter(s.noise(n, rng), s.chain(s.lp(1800, 2), s.hp(150)))
    grit /= np.std(grit) + 1e-9
    knock = np.sin(TAU * (90 + 60 * np.exp(-t / 0.01)) * t)
    return (0.5 * grit * np.exp(-t / 0.025) + knock * np.exp(-t / 0.03))


def hit(rng: np.random.Generator) -> np.ndarray:
    n = s.n_of(0.3)
    t = _t(n)
    thump = np.sin(s.phase_from_freq(70 + 160 * np.exp(-t / 0.02))) * np.exp(-t / 0.08)
    crack = s.fft_filter(s.noise(n, rng), s.bp(1800, 0.7))
    crack /= np.std(crack) + 1e-9
    return s.fade_edges(np.tanh(1.5 * (thump + 0.45 * crack * np.exp(-t / 0.02))), 0, 0.05)[0]


def miss(rng: np.random.Generator) -> np.ndarray:
    """Whoosh: noise through a band that sweeps up then down."""
    b = Bus(s.n_of(0.4), loop=False)
    n = s.n_of(0.4)
    t = _t(n)
    b.add(s.noise(n, rng) * np.sin(np.pi * t / 0.4) ** 2, 0)
    s.sweep_filter(b, lambda tt: 500 + 2500 * np.sin(np.pi * np.clip(tt / 0.4, 0, 1)), q=3.0)
    return b.buf


def crit(rng: np.random.Generator) -> np.ndarray:
    n = s.n_of(0.7)
    t = _t(n)
    h = np.concatenate([hit(rng), np.zeros(n - s.n_of(0.3))])
    ring = sum(np.sin(TAU * f * t + rng.uniform(0, TAU)) * np.exp(-t / d)
               for f, d in ((1240, 0.25), (1975, 0.18), (3110, 0.12), (4430, 0.08)))
    sub = np.sin(s.phase_from_freq(50 + 120 * np.exp(-t / 0.03))) * np.exp(-t / 0.15)
    return 1.2 * h + 0.25 * ring + 0.6 * sub


def gib(rng: np.random.Generator) -> np.ndarray:
    """Splatter comedy: a wet squelch, a slap, then little cartoon droplets plopping down."""
    b = _bus()
    n = s.n_of(0.35)
    t = _t(n)
    wob = 1 + 0.6 * np.sin(TAU * 23 * t)
    sq = s.Bus(n, loop=False)
    sq.add(s.noise(n, rng) * np.exp(-t / 0.09) * wob * (1 - s.raised(n) ** 4), 0)
    s.sweep_filter(sq, lambda tt: 1400 * np.exp(-np.clip(tt, 0, 1) / 0.12) + 200, q=4.0)
    b.add(sq.buf, 0, 0.0, 1.0)
    slap = s.fft_filter(s.noise(s.n_of(0.06), rng), s.bp(900, 0.8)) * np.exp(-_t(s.n_of(0.06)) / 0.012)
    b.add(slap, 0, 0.0, 0.8)
    b.add(np.sin(s.phase_from_freq(60 + 100 * np.exp(-t / 0.02))) * np.exp(-t / 0.07), 0, 0, 0.7)
    for i in range(6):
        dn = s.n_of(0.07)
        dt = _t(dn)
        f0 = rng.uniform(500, 1100)
        drop = np.sin(s.phase_from_freq(f0 * 2 ** (1.4 * dt / 0.07))) * np.exp(-dt / 0.03)
        drop = s.fade_edges(drop, 0.003, 0.02)[0]
        b.add(drop, s.n_of(0.18 + i * rng.uniform(0.06, 0.11)), rng.uniform(-0.7, 0.7),
              0.35 * (1 - i * 0.1))
    return b.buf


def heal(rng: np.random.Generator) -> np.ndarray:
    b = _bus()
    for i, m in enumerate([74, 78, 81, 86, 90]):
        n = s.n_of(0.7)
        t = _t(n)
        x = sum(np.sin(TAU * s.hz(m) * s.cents(d) * t) for d in (-6, 6)) * np.exp(-t / 0.25)
        x = s.fade_edges(x, 0.01, 0.1)[0]
        b.add(x, s.n_of(i * 0.07), -0.4 + 0.2 * i, 0.3)
    sp = s.fft_filter(s.noise(s.n_of(0.9), rng), s.hp(6000))
    b.add(sp * s.raised(len(sp))[::-1] * 0.15, 0, 0.0)
    s.reverb(b, rng, t60=1.2, wet=0.3)
    return b.buf


def summon(rng: np.random.Generator) -> np.ndarray:
    b = _bus()
    n = s.n_of(1.3)
    t = _t(n)
    f = 55 * 2 ** (1.5 * t / 1.3)
    e = s.raised(n) * (1 - s.raised(n) ** 8)
    for d in (-15, 0, 15):
        b.add(s.fft_filter(s.saw(1.0, n, rng.uniform(), f * s.cents(d)), s.lp(900, 2)) * e, 0,
              d / 30, 0.35)
    rev = s.fft_filter(s.noise(n, rng), s.bp(1200, 1.0)) * (t / 1.3) ** 3
    b.add(rev, 0, 0, 0.12)
    b.add(s.low_drum(rng, 1.0, pitch=38), n - s.n_of(0.05), 0.0, 0.7)
    s.reverb(b, rng, t60=1.6, wet=0.3)
    return b.buf


def ui_click(rng: np.random.Generator) -> np.ndarray:
    n = s.n_of(0.05)
    t = _t(n)
    return np.sin(TAU * 1900 * t) * np.exp(-t / 0.006) + 0.2 * s.noise(n, rng) * np.exp(-t / 0.002)


def ui_back(rng: np.random.Generator) -> np.ndarray:
    out = []
    for f in (1300, 870):
        n = s.n_of(0.06)
        t = _t(n)
        out.append(s.fade_edges(np.sin(TAU * f * t) * np.exp(-t / 0.02), 0.002, 0.01)[0])
    return np.concatenate(out)


def coin(rng: np.random.Generator) -> np.ndarray:
    n1, n2 = s.n_of(0.07), s.n_of(0.4)

    def ping(f, n):
        t = _t(n)
        return sum(a * np.sin(TAU * f * r * t) for r, a in ((1, 1), (2.76, 0.4), (5.4, 0.2))) \
            * np.exp(-t / (n / SR / 3)) * s.fade_edges(np.ones(n), 0.001, 0.008)[0]
    return np.concatenate([ping(s.hz(83), n1), ping(s.hz(88), n2)])


def door(rng: np.random.Generator) -> np.ndarray:
    """Old wooden door: a creak (stick-slip pulses at a wobbly rate) and a thud."""
    b = _bus()
    n = s.n_of(0.8)
    t = _t(n)
    wander = s.fft_filter(s.noise(n, rng), s.lp(8, 1))
    rate = 55 + 25 * np.sin(TAU * 1.3 * t) + 15 * wander / (np.std(wander) + 1e-9)
    ph = np.cumsum(np.clip(rate, 20, 200)) / SR
    pulses = (np.diff(np.floor(ph), prepend=0) > 0).astype(float)
    creak = s.fft_filter(pulses, s.chain(s.bp(1100, 0.6), s.peak(2300, 6, 0.3)))
    b.add(creak * np.sin(np.pi * t / 0.8) ** 0.5, 0, -0.2, 1.0)
    th = s.low_drum(rng, 0.8, pitch=70)
    b.add(s.fft_filter(th, s.lp(600)), s.n_of(0.75), 0.0, 1.0)
    s.reverb(b, rng, t60=0.9, wet=0.2)
    return b.buf


def beam(rng: np.random.Generator) -> np.ndarray:
    b = _bus()
    n = s.n_of(1.5)
    t = _t(n)
    f = 220 * (1 + 0.08 * np.sin(TAU * 7 * t)) * 2 ** (t / 1.5)
    x = s.saw(1.0, n, 0.0, f) + s.saw(1.0, n, 0.3, f * 1.502)
    x = s.fft_filter(x, s.chain(s.lp(2000, 2), s.hp(150)))
    e = np.minimum(t / 0.08, 1) * (1 - s.raised(n) ** 6)
    b.add(x * e, 0, 0.0, 0.4)
    hum = np.sin(TAU * 58 * t) * e
    b.add(hum, 0, 0, 0.4)
    s.delay(b, 0.11, feedback=0.4, wet=0.3, taps=4)
    return b.buf


def alarm(rng: np.random.Generator) -> np.ndarray:
    n = s.n_of(1.6)
    t = _t(n)
    sel = (np.floor(t / 0.2) % 2).astype(bool)
    f = np.where(sel, 660.0, 880.0)
    f = s.fft_filter(f, s.lp(60, 1))
    ph = np.cumsum(f) / SR % 1.0
    x = np.where(ph < 0.5, 1.0, -1.0)
    x = s.fft_filter(x, s.chain(s.lp(3000, 2), s.hp(200)))
    return x * np.minimum(t / 0.01, 1) * (1 - s.raised(n) ** 10)


SFX = {
    "step": (step, -9.0), "hit": (hit, -3.0), "miss": (miss, -5.0), "crit": (crit, -3.0),
    "gib": (gib, -3.0), "heal": (heal, -4.0), "summon": (summon, -4.0),
    "ui_click": (ui_click, -9.0), "ui_back": (ui_back, -9.0), "coin": (coin, -6.0),
    "door": (door, -5.0), "beam": (beam, -4.0), "alarm": (alarm, -6.0),
}

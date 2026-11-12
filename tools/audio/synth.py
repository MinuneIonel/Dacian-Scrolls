"""Numpy synth kit for Dacian Scrolls.

Every voice returns a mono float64 array that starts at the note onset. Randomness only comes
from the numpy Generator passed in, so a build is reproducible. Effects that work on a whole
loop (reverb, delay, the sweeping filter) wrap around the end of the buffer, so a loop rendered
with them has no seam.
"""
from __future__ import annotations

import numpy as np

SR = 44100
TAU = 2.0 * np.pi


# ---------------------------------------------------------------- helpers

def hz(midi: float) -> float:
    return 440.0 * 2.0 ** ((float(midi) - 69.0) / 12.0)


def cents(c: float) -> float:
    return 2.0 ** (c / 1200.0)


def n_of(seconds: float) -> int:
    return int(round(seconds * SR))


def db(x: float) -> float:
    return 10.0 ** (x / 20.0)


def lp(fc: float, order: int = 2):
    return lambda f: 1.0 / np.sqrt(1.0 + (f / fc) ** (2 * order))


def hp(fc: float, order: int = 2):
    return lambda f: 1.0 / np.sqrt(1.0 + (fc / np.maximum(f, 1e-3)) ** (2 * order))


def bp(fc: float, width_oct: float = 1.0):
    """Gaussian band in log frequency, width in octaves (standard deviation)."""
    return lambda f: np.exp(-0.5 * (np.log2(np.maximum(f, 1e-3) / fc) / width_oct) ** 2)


def peak(fc: float, gain_db: float, width_oct: float = 0.5):
    g = db(gain_db) - 1.0
    return lambda f: 1.0 + g * np.exp(-0.5 * (np.log2(np.maximum(f, 1e-3) / fc) / width_oct) ** 2)


def chain(*resps):
    def r(f):
        out = np.ones_like(f)
        for x in resps:
            out = out * x(f)
        return out
    return r


def fft_filter(x: np.ndarray, resp, pad: int = 4096, circular: bool = False) -> np.ndarray:
    """Static zero-phase filter. Linear (zero padded) unless circular."""
    x = np.asarray(x, float)
    if x.ndim == 2:
        return np.stack([fft_filter(c, resp, pad, circular) for c in x])
    n = len(x)
    m = n if circular else n + pad
    spec = np.fft.rfft(x, m)
    f = np.fft.rfftfreq(m, 1.0 / SR)
    return np.fft.irfft(spec * resp(f), m)[:n]


def raised(n: int) -> np.ndarray:
    """0 to 1 raised-cosine ramp of n samples."""
    if n <= 0:
        return np.zeros(0)
    return 0.5 - 0.5 * np.cos(np.linspace(0.0, np.pi, n))


def env(dur: float, a: float = 0.01, d: float = 0.1, s: float = 0.7, r: float = 0.2,
        curve: float = 4.0) -> np.ndarray:
    """ADSR. Length is dur + r seconds; the release starts at dur."""
    n_hold = max(1, n_of(dur))
    n_r = max(1, n_of(r))
    out = np.empty(n_hold + n_r)
    na = min(n_of(a), n_hold)
    out[:na] = raised(na)
    rest = n_hold - na
    if rest > 0:
        t = np.arange(rest) / SR
        out[na:n_hold] = s + (1.0 - s) * np.exp(-t * curve / max(d, 1e-4))
    level = out[n_hold - 1]
    out[n_hold:] = level * (1.0 - raised(n_r))
    return out


def noise(n: int, rng: np.random.Generator) -> np.ndarray:
    return rng.standard_normal(n)


def phase_from_freq(f_inst: np.ndarray, phase0: float = 0.0) -> np.ndarray:
    return phase0 + TAU * np.cumsum(f_inst) / SR


# ---------------------------------------------------------------- folk voices

def nai(freq: float, dur: float, rng: np.random.Generator, amp: float = 1.0,
        scoop: float = 0.35, vib_depth: float = 0.0055, vib_rate: float = 5.3,
        breath: float = 0.14, release: float = 0.22) -> np.ndarray:
    """Pan flute: near-sine tone, breathy band noise, a chiff, a scoop up into pitch and
    delayed vibrato."""
    e = env(dur, a=0.045, d=0.35, s=0.78, r=release, curve=2.0)
    n = len(e)
    t = np.arange(n) / SR
    vib_env = np.clip((t - 0.22) / 0.45, 0.0, 1.0)
    vib = 1.0 + vib_depth * vib_env * np.sin(TAU * vib_rate * t + rng.uniform(0, TAU))
    sc = 2.0 ** (-(scoop / 12.0) * np.exp(-t / 0.035))
    ph = phase_from_freq(freq * vib * sc, rng.uniform(0, TAU))
    tone = np.sin(ph) + 0.10 * np.sin(2 * ph + 0.3) + 0.045 * np.sin(3 * ph + 1.1)
    wn = noise(n, rng)
    band = fft_filter(wn, bp(freq, 0.18))
    band /= (np.std(band) + 1e-9)
    hiss = fft_filter(wn, chain(hp(2500), lp(7000)))
    hiss /= (np.std(hiss) + 1e-9)
    chiff_env = np.exp(-t / 0.018) * (t < 0.12)
    chiff = fft_filter(noise(n, rng), bp(freq * 2.5, 0.6))
    chiff /= (np.std(chiff) + 1e-9)
    # breath noise gets louder with breath pressure, a little at the start
    out = tone * e + breath * (0.55 * band + 0.18 * hiss) * e * (0.7 + 0.3 * vib_env[::-1])
    out += 0.25 * chiff * chiff_env
    return amp * fft_filter(out, lp(5200, 1))


def ks(freq: float, n_out: int, rng: np.random.Generator, bright: float = 0.6,
       t60: float = 2.0, pos: float = 0.17) -> np.ndarray:
    """Karplus-Strong, block vectorised, with exact tuning by resampling."""
    p_exact = SR / freq
    P = int(np.ceil(p_exact - 0.5))
    P = max(P, 2)
    ratio = (P + 0.5) / p_exact
    n_int = int(n_out * ratio) + 2
    nblocks = n_int // P + 2
    exc = rng.uniform(-1.0, 1.0, P)
    for _ in range(int(round((1.0 - bright) * 6))):
        exc = 0.5 * (exc + np.roll(exc, 1))
    d = max(1, int(P * pos))
    exc = exc - np.roll(exc, d)
    exc -= exc.mean()
    exc /= (np.max(np.abs(exc)) + 1e-9)
    g = 10.0 ** (-3.0 * P / (SR * t60))
    y = np.zeros(nblocks * P)
    y[:P] = exc
    last = 0.0
    for b in range(1, nblocks):
        prev = y[(b - 1) * P: b * P]
        sh = np.empty(P)
        sh[0] = last
        sh[1:] = prev[:-1]
        last = prev[-1]
        y[b * P:(b + 1) * P] = g * 0.5 * (prev + sh)
    idx = np.arange(n_out) * ratio
    return np.interp(idx, np.arange(len(y)), y)


def cobza(freq: float, dur: float, rng: np.random.Generator, amp: float = 1.0,
          bright: float = 0.6, t60: float = 1.8, damp: float = 0.06) -> np.ndarray:
    """Short-necked lute: a double course (two slightly detuned strings) through a body
    resonance. Damped after dur seconds."""
    n = n_of(dur + damp)
    a = ks(freq * cents(-2.5), n, rng, bright, t60)
    b = ks(freq * cents(2.5), n, rng, bright * 0.9, t60 * 0.9)
    x = a + 0.8 * b
    nd = n_of(damp)
    x[-nd:] *= 1.0 - raised(nd)
    # pick attack click
    na = min(n, 120)
    x[:na] += 0.15 * noise(na, rng) * np.exp(-np.arange(na) / 25.0)
    body = chain(peak(260, 5, 0.4), peak(950, 3, 0.5), peak(2700, 2, 0.6), hp(90), lp(7500, 1))
    return amp * 0.5 * fft_filter(x, body)


def drone_loop(L: int, midis: list[float], rng: np.random.Generator, amp: float = 1.0,
               bright: float = 0.35, swell_period: int | None = None) -> np.ndarray:
    """A reedy sustained drone, exactly periodic over L samples (integer cycles), stereo."""
    secs = L / SR
    t = np.arange(L) / SR
    out = np.zeros((2, L))
    for m in midis:
        for ch, det in ((0, -3.0), (1, 3.5)):
            f = hz(m) * cents(det)
            f = round(f * secs) / secs
            ph = TAU * f * t + rng.uniform(0, TAU)
            for k in range(1, 14):
                if f * k > 6000:
                    break
                out[ch] += (bright ** (k - 1)) / k ** 0.6 * np.sin(k * ph + rng.uniform(0, TAU))
    if swell_period:
        out *= 0.82 + 0.18 * np.sin(TAU * np.arange(L) / swell_period)[None, :]
    out /= np.max(np.abs(out)) + 1e-9
    return amp * fft_filter(out, chain(lp(1800, 2), hp(40)), circular=True)


def frame_drum(rng: np.random.Generator, kind: str = "dum", amp: float = 1.0) -> np.ndarray:
    """Dairea (frame drum with jingles). kind: dum (centre), tek (rim), jingle."""
    dur = 0.45 if kind == "dum" else 0.25
    n = n_of(dur)
    t = np.arange(n) / SR
    out = np.zeros(n)
    if kind == "dum":
        f = 95.0 + 70.0 * np.exp(-t / 0.02)
        out += np.sin(phase_from_freq(f)) * np.exp(-t / 0.16)
        out += 0.3 * fft_filter(noise(n, rng), bp(400, 0.6)) * np.exp(-t / 0.03)
    if kind in ("tek", "dum"):
        tk = fft_filter(noise(n, rng), bp(2200 if kind == "tek" else 900, 0.5))
        tk /= np.std(tk) + 1e-9
        out += (0.5 if kind == "tek" else 0.15) * tk * np.exp(-t / 0.015)
        out += (0.4 if kind == "tek" else 0.1) * np.sin(TAU * 330 * t) * np.exp(-t / 0.04)
    # jingles: little inharmonic metal partials with a rattle
    jn = np.zeros(n)
    for p in (5300, 6900, 8400, 9800):
        jn += np.sin(TAU * p * cents(rng.uniform(-30, 30)) * t + rng.uniform(0, TAU))
    rattle = 0.6 + 0.4 * np.sign(np.sin(TAU * 38 * t + rng.uniform(0, TAU)))
    jl = (0.45 if kind != "dum" else 0.25) * jn / 4.0 * rattle * np.exp(-t / 0.09)
    jl += 0.12 * fft_filter(noise(n, rng), hp(6000)) * np.exp(-t / 0.06)
    out += jl
    return amp * out


def low_drum(rng: np.random.Generator, amp: float = 1.0, pitch: float = 52.0) -> np.ndarray:
    """Toba mare: big low drum, pitch drop, beater click."""
    n = n_of(0.9)
    t = np.arange(n) / SR
    f = pitch + 70.0 * np.exp(-t / 0.035)
    body = np.sin(phase_from_freq(f)) * np.exp(-t / 0.32)
    body += 0.25 * np.sin(phase_from_freq(f * 1.5)) * np.exp(-t / 0.12)
    click = fft_filter(noise(n, rng), bp(1500, 0.8)) * np.exp(-t / 0.006)
    thud = fft_filter(noise(n, rng), lp(250, 2)) * np.exp(-t / 0.08)
    thud /= np.std(thud[: n_of(0.05)]) + 1e-9
    out = body + 0.35 * click + 0.25 * thud
    return amp * out / (np.max(np.abs(out)) + 1e-9)


def tulnic(freq: float, dur: float, rng: np.random.Generator, amp: float = 1.0,
           bend: float = -45.0, swell: float = 0.7, droop: float = 0.0,
           release: float = 0.5, glide_to: float | None = None, vib: float = 0.003) -> np.ndarray:
    """Long wooden horn: brassy additive tone whose brightness follows loudness, a slow swell,
    a bend up into the pitch and an optional droop (cents) or glide at the end."""
    e = env(dur, a=swell, d=0.6, s=0.85, r=release, curve=1.5)
    n = len(e)
    t = np.arange(n) / SR
    pitch = cents(bend * np.exp(-t / 0.18))
    end = n_of(dur)
    if droop:
        x = np.clip((t - dur * 0.75) / (dur * 0.25 + release), 0.0, 1.0)
        pitch = pitch * cents(droop * x * x)
    if glide_to is not None:
        x = np.clip((t - dur * 0.6) / (dur * 0.3), 0.0, 1.0)
        pitch = pitch * (glide_to / freq) ** raised_curve(x)
    pitch = pitch * (1.0 + vib * np.clip(t - 0.5, 0, 1) * np.sin(TAU * 4.6 * t + rng.uniform(0, TAU)))
    ph = phase_from_freq(freq * pitch, rng.uniform(0, TAU))
    bright = 0.25 + 0.6 * e
    out = np.zeros(n)
    for k in range(1, 18):
        if freq * k > 9000:
            break
        out += (bright ** (k - 1)) / k ** 0.5 * np.sin(k * ph)
    out *= e
    out += 0.05 * fft_filter(noise(n, rng), bp(freq * 3, 0.8)) * e
    out /= np.max(np.abs(out)) + 1e-9
    _ = end
    return amp * fft_filter(out, chain(peak(650, 3, 0.6), lp(4500, 1)))


def raised_curve(x: np.ndarray) -> np.ndarray:
    return 0.5 - 0.5 * np.cos(np.pi * np.clip(x, 0.0, 1.0))


# ---------------------------------------------------------------- analogue voices

def saw(freq: float, n: int, phase0: float = 0.0, f_mult: np.ndarray | None = None) -> np.ndarray:
    """Saw with a polyBLEP correction against aliasing."""
    f = freq if f_mult is None else freq * f_mult
    inc = np.broadcast_to(np.asarray(f / SR, float), (n,))
    ph = (phase0 + np.cumsum(inc)) % 1.0
    y = 2.0 * ph - 1.0
    dt = inc
    m1 = ph < dt
    x = ph[m1] / dt[m1]
    y[m1] -= x + x - x * x - 1.0
    m2 = ph > 1.0 - dt
    x = (ph[m2] - 1.0) / dt[m2]
    y[m2] -= x * x + x + x + 1.0
    return y


def pulse(freq: float, n: int, width: float = 0.5, phase0: float = 0.0) -> np.ndarray:
    return 0.5 * (saw(freq, n, phase0) - saw(freq, n, (phase0 + width) % 1.0))


def saw_pad(midis: list[float], dur: float, rng: np.random.Generator, amp: float = 1.0,
            detune: float = 11.0, attack: float = 0.9, release: float = 1.6,
            sub: bool = True) -> np.ndarray:
    """Detuned saw chord, stereo, unfiltered (the sweeping filter runs on the bus)."""
    e = env(dur, a=attack, d=1.0, s=0.9, r=release, curve=1.0)
    n = len(e)
    out = np.zeros((2, n))
    for m in midis:
        f = hz(m)
        for ch in (0, 1):
            for d in (-detune, 0.0, detune):
                dd = d + rng.uniform(-2.5, 2.5) + (1.5 if ch else -1.5)
                out[ch] += saw(f * cents(dd), n, rng.uniform())
    if sub:
        f = hz(min(midis) - 12)
        s = np.sin(TAU * f * np.arange(n) / SR)
        out += 1.2 * s[None, :]
    return amp * out * e[None, :] / (3.0 * len(midis))


def arp_pluck(freq: float, dur: float, rng: np.random.Generator, amp: float = 1.0,
              width: float = 0.3, cutoff: float = 2400.0, decay: float = 0.16) -> np.ndarray:
    n = n_of(dur + 0.25)
    t = np.arange(n) / SR
    x = 0.6 * pulse(freq, n, width, rng.uniform()) + 0.4 * saw(freq * cents(7), n, rng.uniform())
    e = np.minimum(t / 0.003, 1.0) * np.exp(-t / decay)
    x = fft_filter(x * e, chain(lp(cutoff, 2), peak(cutoff * 0.8, 6, 0.25), hp(150)))
    return amp * x


def kick(rng: np.random.Generator, amp: float = 1.0) -> np.ndarray:
    n = n_of(0.5)
    t = np.arange(n) / SR
    f = 45.0 + 110.0 * np.exp(-t / 0.04)
    out = np.sin(phase_from_freq(f)) * np.exp(-t / 0.22)
    out += 0.2 * fft_filter(noise(n, rng), bp(3000, 0.5)) * np.exp(-t / 0.004)
    return amp * np.tanh(1.6 * out)


def snare(rng: np.random.Generator, amp: float = 1.0) -> np.ndarray:
    n = n_of(0.35)
    t = np.arange(n) / SR
    nz = fft_filter(noise(n, rng), chain(hp(1200), lp(9000, 1), peak(4500, 4, 0.6)))
    nz /= np.std(nz) + 1e-9
    body = np.sin(phase_from_freq(180 + 60 * np.exp(-t / 0.01))) * np.exp(-t / 0.06)
    return amp * (0.35 * nz * np.exp(-t / 0.08) + 0.6 * body)


def hat(rng: np.random.Generator, amp: float = 1.0, open_: bool = False) -> np.ndarray:
    n = n_of(0.3 if open_ else 0.08)
    t = np.arange(n) / SR
    nz = fft_filter(noise(n, rng), chain(hp(7000), lp(14000, 1)))
    nz /= np.std(nz) + 1e-9
    return amp * 0.3 * nz * np.exp(-t / (0.09 if open_ else 0.018))


def bass_synth(freq: float, dur: float, rng: np.random.Generator, amp: float = 1.0,
               cutoff: float = 700.0) -> np.ndarray:
    n = n_of(dur + 0.05)
    t = np.arange(n) / SR
    x = saw(freq, n, rng.uniform()) + 0.5 * saw(freq * cents(-8), n, rng.uniform())
    x += 0.8 * np.sin(TAU * freq * t)
    e = np.minimum(t / 0.004, 1) * (0.4 + 0.6 * np.exp(-t / 0.12))
    nd = n_of(0.03)
    e[-nd:] *= 1 - raised(nd)
    return amp * fft_filter(x * e, chain(lp(cutoff, 2), peak(cutoff * 0.9, 5, 0.3)))


# ---------------------------------------------------------------- mixing

def pan_gains(pan: float) -> tuple[float, float]:
    a = (np.clip(pan, -1.0, 1.0) + 1.0) * np.pi / 4.0
    return float(np.cos(a)), float(np.sin(a))


class Bus:
    """Stereo buffer. A loop bus wraps anything that runs past its end back to the start
    (the "tail wrap"), and its effects are circular."""

    def __init__(self, length: int, loop: bool = True):
        self.L = length
        self.loop = loop
        self.buf = np.zeros((2, length))

    def _grow(self, need: int) -> None:
        if need > self.buf.shape[1]:
            self.buf = np.concatenate([self.buf, np.zeros((2, need - self.buf.shape[1]))], axis=1)

    def add(self, sig: np.ndarray, start: int, pan: float = 0.0, gain: float = 1.0) -> None:
        sig = np.asarray(sig, float)
        if sig.ndim == 1:
            gl, gr = pan_gains(pan)
            st = np.stack([sig * gl, sig * gr])
        else:
            st = sig
        st = st * gain
        n = st.shape[1]
        if not self.loop:
            self._grow(start + n)
            self.buf[:, start:start + n] += st
            return
        L = self.L
        pos = start % L
        i = 0
        while i < n:
            k = min(n - i, L - pos)
            self.buf[:, pos:pos + k] += st[:, i:i + k]
            i += k
            pos = 0

    def mix(self, other: "Bus", gain: float = 1.0) -> None:
        self._grow(other.buf.shape[1])
        self.buf[:, :other.buf.shape[1]] += gain * other.buf


def _conv(x: np.ndarray, ir: np.ndarray, circular: bool) -> np.ndarray:
    n = x.shape[-1]
    m = n if circular else n + ir.shape[-1]
    y = np.fft.irfft(np.fft.rfft(x, m) * np.fft.rfft(ir, m), m)
    return y


def reverb(bus: Bus, rng: np.random.Generator, t60: float = 1.8, wet: float = 0.2,
           predelay: float = 0.018, dark: float = 3500.0) -> None:
    """Convolution with a synthetic stereo room: decaying noise, darker as it decays."""
    n = n_of(min(t60 * 1.2, 4.0))
    t = np.arange(n) / SR
    irs = []
    for _ in range(2):
        bright = fft_filter(noise(n, rng), lp(dark * 2, 1)) * np.exp(-6.9 * t / (t60 * 0.5))
        darkp = fft_filter(noise(n, rng), lp(dark * 0.5, 1)) * np.exp(-6.9 * t / t60)
        ir = 0.6 * bright + darkp
        ir[: n_of(0.004)] *= raised(n_of(0.004))
        ir = np.concatenate([np.zeros(n_of(predelay)), ir])
        irs.append(ir / np.sqrt(np.sum(ir ** 2)))
    ir = np.stack(irs)
    if bus.loop and n > bus.L:
        ir = ir[:, :bus.L]
    x = bus.buf
    if not bus.loop:
        x = np.concatenate([x, np.zeros((2, ir.shape[1]))], axis=1)
    y = np.stack([_conv(x[c], ir[c], True) for c in range(2)])
    bus.buf = x + wet * y


def delay(bus: Bus, time_s: float, feedback: float = 0.4, wet: float = 0.3,
          pingpong: bool = True, taps: int = 6, tone: float = 3000.0) -> None:
    d = n_of(time_s)
    x = bus.buf
    if not bus.loop:
        x = np.concatenate([x, np.zeros((2, d * taps))], axis=1)
    out = x.copy()
    src = fft_filter(x, lp(tone, 1), circular=bus.loop)
    for k in range(1, taps + 1):
        sh = np.roll(src, d * k, axis=1)
        if pingpong and k % 2 == 1:
            sh = sh[::-1]
        out += wet * feedback ** (k - 1) * sh
    bus.buf = out


def sweep_filter(bus: Bus, fc_of_t, q: float = 1.2, N: int = 1764, hop: int = 441) -> None:
    """Time-varying resonant 4-pole low-pass by STFT overlap-add, circular on a loop bus.
    fc_of_t maps an array of times in seconds to cutoff frequencies."""
    x = bus.buf
    n0 = x.shape[1]
    if not bus.loop:   # two windows of silence so nothing wraps from the start into the kept tail
        x = np.concatenate([x, np.zeros((2, 2 * N))], axis=1)
    n = x.shape[1]
    padn = (-n) % hop
    if padn:
        x = np.concatenate([x, np.zeros((2, padn))], axis=1)
        n += padn
    w = 0.5 - 0.5 * np.cos(TAU * np.arange(N) / N)
    K = n // hop
    freqs = np.fft.rfftfreq(N, 1.0 / SR)
    out = np.zeros((2, n))
    for k0 in range(0, K, 512):
        ks_ = np.arange(k0, min(K, k0 + 512))
        idx = (ks_[:, None] * hop + np.arange(N)[None, :]) % n
        times = ((ks_ * hop + N / 2) % n) / SR
        fc = np.asarray(fc_of_t(times), float)[:, None]
        r = freqs[None, :] / fc
        h = 1.0 / np.sqrt((1 - r ** 2) ** 2 + (r / q) ** 2)
        g = h * h
        for c in range(2):
            fr = x[c][idx] * w
            y = np.fft.irfft(np.fft.rfft(fr, axis=1) * g, N, axis=1) * w
            out[c] += np.bincount(idx.ravel(), weights=y.ravel(), minlength=n)
    out /= 1.5
    if not bus.loop:
        out = out[:, :n0 + N]
    else:
        out = out[:, :n0]
    bus.buf = out


def master(buf: np.ndarray, rms_db: float | None = -20.0, ceiling_db: float = -3.0,
           knee: float = 0.8) -> np.ndarray:
    """Level to a target RMS, soft-limit with tanh above the knee, then keep the peak under
    the ceiling. Memoryless, so a seamless loop stays seamless."""
    x = np.asarray(buf, float)
    if rms_db is not None:
        r = np.sqrt(np.mean(x ** 2)) + 1e-12
        x = x * db(rms_db) / r
    c = db(ceiling_db) * knee
    a = np.abs(x)
    over = a > c
    head = db(ceiling_db) * 1.0 - c
    x = np.where(over, np.sign(x) * (c + head * np.tanh((a - c) / head)), x)
    pk = np.max(np.abs(x)) + 1e-12
    if pk > db(ceiling_db):
        x *= db(ceiling_db) / pk
    return x


def fade_edges(x: np.ndarray, fade_in: float = 0.002, fade_out: float = 0.02) -> np.ndarray:
    x = np.array(x, float)
    ni, no = n_of(fade_in), n_of(fade_out)
    if x.ndim == 1:
        x = x[None, :]
    if ni:
        x[:, :ni] *= raised(ni)
    if no:
        x[:, -no:] *= 1.0 - raised(no)
    return x


def trim_silence(x: np.ndarray, thresh_db: float = -70.0) -> np.ndarray:
    a = np.max(np.abs(x), axis=0)
    idx = np.nonzero(a > db(thresh_db) * a.max())[0]
    end = idx[-1] + 1 if len(idx) else x.shape[1]
    return x[:, :end]

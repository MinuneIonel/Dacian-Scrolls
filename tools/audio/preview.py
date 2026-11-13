#!/usr/bin/env python3
"""Look at audio without ears. Usage:

    python3 tools/audio/preview.py [files.ogg ...]     default: every OGG under assets/audio

For each file: a spectrogram PNG (log frequency, 30 Hz to 16 kHz, 80 dB range) written to
build/audio_preview/, RMS and peak, RMS per 4-bar block for music, and a loop seam check that
compares the jump across the loop point with ordinary sample-to-sample steps and the last 50 ms
with the first 50 ms.
"""
from __future__ import annotations

import glob
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from audio_io import decode, peak_dbfs, rms_dbfs  # noqa: E402
from synth import SR  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "build", "audio_preview")


def colour(v: np.ndarray) -> np.ndarray:
    """0..1 to an inferno-like ramp."""
    stops = np.array([[0, 0, 4], [40, 11, 84], [101, 21, 110], [159, 42, 99],
                      [212, 72, 66], [245, 125, 21], [250, 193, 39], [252, 255, 164]], float)
    x = np.clip(v, 0, 1) * (len(stops) - 1)
    i = np.minimum(x.astype(int), len(stops) - 2)
    f = (x - i)[..., None]
    return (stops[i] * (1 - f) + stops[i + 1] * f).astype(np.uint8)


def spectrogram(x: np.ndarray, path: str, width: int = 1200, height: int = 360,
                bar_s: float | None = None) -> None:
    mono = x.mean(axis=0)
    N = 4096 if len(mono) > 4 * SR else 512
    hop = max(256, (len(mono) - N) // width) if len(mono) > N else 64
    if len(mono) < N:
        mono = np.concatenate([mono, np.zeros(N - len(mono))])
    frames = np.lib.stride_tricks.sliding_window_view(mono, N)[::hop]
    w = np.hanning(N)
    spec = np.abs(np.fft.rfft(frames * w, axis=1)) + 1e-9
    freqs = np.fft.rfftfreq(N, 1 / SR)
    logf = np.geomspace(30, 16000, height)
    rows = np.stack([np.interp(logf, freqs, s) for s in spec])          # (T, H)
    dbv = 20 * np.log10(rows / rows.max())
    img = colour((dbv + 80) / 80).transpose(1, 0, 2)[::-1]
    im = Image.fromarray(img).resize((width, height), Image.NEAREST)
    d = ImageDraw.Draw(im)
    for f in (100, 1000, 10000):
        y = height - 1 - int(np.searchsorted(logf, f) * 1.0)
        d.line([(0, y), (14, y)], fill=(255, 255, 255))
        d.text((16, y - 6), f"{f}Hz", fill=(255, 255, 255))
    if bar_s:
        dur = x.shape[1] / SR
        b = 0
        while b * bar_s < dur:
            xx = int(b * bar_s / dur * width)
            d.line([(xx, height - 6 if b % 8 else 0), (xx, height)], fill=(120, 200, 255))
            b += 1
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path)


def seam_report(x: np.ndarray) -> str:
    """A loop is click-free when the step across the seam is no bigger than normal steps."""
    steps = np.abs(np.diff(x, axis=1))
    typical = np.percentile(steps, 99.9)
    seam = np.max(np.abs(x[:, 0] - x[:, -1]))
    n = int(0.05 * SR)
    last, first = rms_dbfs(x[:, -n:]), rms_dbfs(x[:, :n])
    # spectral match of the 50 ms either side of the seam
    a = np.abs(np.fft.rfft(x[:, -n:].mean(0) * np.hanning(n)))
    b = np.abs(np.fft.rfft(x[:, :n].mean(0) * np.hanning(n)))
    corr = float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b) + 1e-12))
    ok = "OK" if seam <= typical else "CHECK"
    return (f"seam step {seam:.4f} vs p99.9 step {typical:.4f} [{ok}], last/first 50ms rms "
            f"{last:.1f}/{first:.1f} dBFS, spectral similarity {corr:.2f}")


def main(paths: list[str]) -> None:
    if not paths:
        paths = sorted(glob.glob(os.path.join(ROOT, "assets", "audio", "**", "*.ogg"),
                                 recursive=True))
    for p in paths:
        x = decode(p).astype(float)
        name = os.path.splitext(os.path.basename(p))[0]
        is_music = os.sep + "music" + os.sep in p
        bar_s = 2.5 if is_music else None
        png = os.path.join(OUT, name + ".png")
        spectrogram(x, png, bar_s=bar_s)
        print(f"{name}: {x.shape[1]} samples ({x.shape[1] / SR:.2f}s), rms {rms_dbfs(x):.1f}, "
              f"peak {peak_dbfs(x):.1f} dBFS -> {png}")
        if is_music:
            block = int(4 * 2.5 * SR)
            r = [rms_dbfs(x[:, i:i + block]) for i in range(0, x.shape[1], block)]
            print("  rms per 4 bars: " + " ".join(f"{v:.0f}" for v in r))
            print("  " + seam_report(x))


if __name__ == "__main__":
    main(sys.argv[1:])

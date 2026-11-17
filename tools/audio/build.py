#!/usr/bin/env python3
"""Renders every OGG under assets/audio/. Usage:

    python3 tools/audio/build.py              everything
    python3 tools/audio/build.py sfx gib      only some groups (music, stingers, sfx) or ids

Deterministic: same code, same files. Checks before encoding that all stems of a track have
the same length in samples, and after encoding that no decoded file peaks above -1 dBFS.
"""
from __future__ import annotations

import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import music  # noqa: E402
import sfx  # noqa: E402
import synth as s  # noqa: E402
from audio_io import decode, encode_ogg, peak_dbfs, rms_dbfs  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "assets", "audio")
PEAK_LIMIT_DB = -1.0
SEED = 101


def _check_peak(path: str) -> None:
    pk = peak_dbfs(decode(path))
    if pk > PEAK_LIMIT_DB:
        raise SystemExit(f"{path}: decoded peak {pk:.2f} dBFS is above {PEAK_LIMIT_DB} dBFS")


def build_music(only: set[str]) -> None:
    os.makedirs(os.path.join(OUT, "music"), exist_ok=True)
    for name in music.TRACKS:
        if only and name not in only and "music" not in only:
            continue
        stems = music.render_track(name, SEED)
        lengths = {k: v.shape[1] for k, v in stems.items()}
        if len(set(lengths.values())) != 1:
            raise SystemExit(f"{name}: stem lengths differ {lengths}")
        for layer, x in stems.items():
            path = os.path.join(OUT, "music", f"{name}_{layer}.ogg")
            encode_ogg(x, path, quality=4)
            d = decode(path)
            if d.shape[1] != x.shape[1]:
                raise SystemExit(f"{path}: decoded {d.shape[1]} samples, rendered {x.shape[1]}")
            _check_peak(path)
            seam = np.max(np.abs(x[:, 0] - x[:, -1]))
            print(f"{path}: {x.shape[1]} samples, rms {rms_dbfs(x):.1f} dBFS, "
                  f"peak {peak_dbfs(d):.1f} dBFS, seam jump {seam:.4f}, "
                  f"{os.path.getsize(path) // 1024} KiB")


def build_oneshots(group: str, table: dict, only: set[str], salt: int) -> None:
    os.makedirs(os.path.join(OUT, group), exist_ok=True)
    for i, (sid, (fn, peak_db)) in enumerate(table.items()):
        if only and sid not in only and group not in only:
            continue
        x = np.atleast_2d(fn(np.random.default_rng(SEED * 1000 + salt + i)))
        x = s.trim_silence(x)
        x = s.fade_edges(x, 0.0005, 0.01)
        if x.shape[0] == 1 and group == "stingers":
            x = np.concatenate([x, x])
        x *= s.db(peak_db) / (np.max(np.abs(x)) + 1e-12)
        path = os.path.join(OUT, group, f"{sid}.ogg")
        encode_ogg(x, path, quality=4)
        _check_peak(path)
        print(f"{path}: {x.shape[1] / s.SR:.2f}s, {x.shape[0]}ch, "
              f"{os.path.getsize(path) // 1024} KiB")


def main(argv: list[str]) -> None:
    only = set(argv)
    build_music(only)
    build_oneshots("stingers", sfx.STINGERS, only, 1)
    build_oneshots("sfx", sfx.SFX, only, 2)


if __name__ == "__main__":
    main(sys.argv[1:])

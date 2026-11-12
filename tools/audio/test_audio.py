#!/usr/bin/env python3
"""Checks the encoded audio: every id exists, stems of a track have identical sample counts,
nothing peaks above -1 dBFS, loops have no seam click, total size stays small.
Run: python3 tools/audio/test_audio.py"""
from __future__ import annotations

import os
import sys
import unittest

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from audio_io import decode, peak_dbfs  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
AUDIO = os.path.join(ROOT, "assets", "audio")
TRACKS = {"sarmizegetusa": ["explore", "combat", "lobizi"], "saucer": ["lobizi", "combat"]}
STINGERS = ["abduction", "page_found", "level_up", "defeat"]
SFX = ["step", "hit", "miss", "crit", "gib", "heal", "summon", "ui_click", "ui_back", "coin",
       "door", "beam", "alarm"]


def all_files() -> list[str]:
    out = [os.path.join(AUDIO, "music", f"{t}_{l}.ogg") for t, ls in TRACKS.items() for l in ls]
    out += [os.path.join(AUDIO, "stingers", f"{i}.ogg") for i in STINGERS]
    out += [os.path.join(AUDIO, "sfx", f"{i}.ogg") for i in SFX]
    return out


class AudioAssets(unittest.TestCase):
    _cache: dict = {}

    def pcm(self, path: str) -> np.ndarray:
        if path not in self._cache:
            self._cache[path] = decode(path)
        return self._cache[path]

    def test_every_id_exists(self):
        for p in all_files():
            self.assertTrue(os.path.isfile(p), p)

    def test_stems_have_identical_length(self):
        for t, layers in TRACKS.items():
            lens = {l: self.pcm(os.path.join(AUDIO, "music", f"{t}_{l}.ogg")).shape[1]
                    for l in layers}
            self.assertEqual(len(set(lens.values())), 1, f"{t}: {lens}")
        self.assertEqual(self.pcm(os.path.join(AUDIO, "music", "sarmizegetusa_explore.ogg"))
                         .shape[1], 32 * 4 * 60 * 44100 // 96)

    def test_no_file_peaks_above_minus_1_dbfs(self):
        for p in all_files():
            self.assertLessEqual(peak_dbfs(self.pcm(p)), -1.0, p)

    def test_loop_seams_are_click_free(self):
        for t, layers in TRACKS.items():
            for l in layers:
                x = self.pcm(os.path.join(AUDIO, "music", f"{t}_{l}.ogg")).astype(float)
                typical = np.percentile(np.abs(np.diff(x, axis=1)), 99.9)
                seam = np.max(np.abs(x[:, 0] - x[:, -1]))
                self.assertLessEqual(seam, typical, f"{t}_{l}")

    def test_total_size_under_8_mb(self):
        total = sum(os.path.getsize(p) for p in all_files())
        self.assertLess(total, 8 * 1024 * 1024)


if __name__ == "__main__":
    unittest.main()

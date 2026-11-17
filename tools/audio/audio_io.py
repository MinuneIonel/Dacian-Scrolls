"""OGG Vorbis encode/decode through ffmpeg (raw float32 over pipes, no temp files)."""
from __future__ import annotations

import subprocess

import numpy as np

from synth import SR

FFMPEG = "ffmpeg"


def encode_ogg(x: np.ndarray, path: str, quality: float = 4.0) -> None:
    """x: (channels, samples) float in [-1, 1]. Bit-exact flags keep rebuilds byte-stable."""
    x = np.atleast_2d(np.asarray(x, np.float32))
    ch = x.shape[0]
    raw = np.ascontiguousarray(x.T).tobytes()
    cmd = [FFMPEG, "-hide_banner", "-loglevel", "error", "-y",
           "-f", "f32le", "-ar", str(SR), "-ac", str(ch), "-i", "-",
           "-c:a", "libvorbis", "-q:a", str(quality),
           "-fflags", "+bitexact", "-flags:a", "+bitexact", "-map_metadata", "-1", path]
    subprocess.run(cmd, input=raw, check=True)


def decode(path: str, channels: int | None = None) -> np.ndarray:
    """Returns (channels, samples) float32 at the file's own channel count."""
    if channels is None:
        probe = subprocess.run(
            ["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries",
             "stream=channels", "-of", "csv=p=0", path], capture_output=True, text=True, check=True)
        channels = int(probe.stdout.strip().split(",")[0])
    out = subprocess.run([FFMPEG, "-hide_banner", "-loglevel", "error", "-i", path,
                          "-f", "f32le", "-ar", str(SR), "-ac", str(channels), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(out, np.float32).reshape(-1, channels).T.copy()


def peak_dbfs(x: np.ndarray) -> float:
    return float(20 * np.log10(np.max(np.abs(x)) + 1e-12))


def rms_dbfs(x: np.ndarray) -> float:
    return float(20 * np.log10(np.sqrt(np.mean(np.asarray(x, float) ** 2)) + 1e-12))

"""Placeholder movement audio: footsteps and order-acknowledgement barks.

These are scaffolding, not craft. They exist so the timing rules in `GameSFX`,
`FootstepPlayer` and the bark frequency ladder can be heard and tuned before
anyone books a session or a voice.

Footsteps are honest to synthesise — a footfall on a hard floor really is a
filtered noise burst with a fast decay, so band-limited noise through an
envelope lands somewhere usable. Barks are not: a line of dialogue cannot be
faked from arithmetic, so those go through `say`, which is unmistakably
temporary. That is the point; nobody will mistake it for a keeper.

Deterministic, and safe to re-run: same seed, same bytes, so a rebake diffs
clean. That needs help — the M4A container stamps a creation time, so two
bakes of identical audio otherwise differ in six bytes. Real recordings drop in over the same filenames.

    python3 ArtSource/Processing/generate_movement_sfx_v01.py

Writes .m4a into `RainShadow Shared/Resources/Audio/SFX/`, matching the format
the shipped ambience and VO already use.
"""

from __future__ import annotations

import shutil
import struct
import subprocess
import sys
import tempfile
import wave
from dataclasses import dataclass
from pathlib import Path

import numpy as np

REPO = Path(__file__).resolve().parents[2]
OUT_DIR = REPO / "RainShadow Shared" / "Resources" / "Audio" / "SFX"
SAMPLE_RATE = 44_100

# One seed for the whole bake so the set is reproducible as a set.
SEED = 0x5241494E  # "RAIN"


@dataclass(frozen=True)
class Surface:
    """A footstep character.

    `centre_hz`/`width` shape the band the footfall sits in; `decay` is how fast
    it dies. Floorboards ring a little and sit low; wet stone is brighter and
    shorter, with a thin splash on top.
    """

    name: str
    centre_hz: float
    width: float
    decay: float
    splash: float
    variants: int = 4


SURFACES = (
    Surface("floorboard", centre_hz=220.0, width=1.4, decay=26.0, splash=0.0),
    Surface("wet_stone", centre_hz=520.0, width=1.1, decay=42.0, splash=0.28),
)

# The acknowledgement lines. Deliberately dry — Voss is not enthusiastic.
COMMAND_LINES = (
    ("command_01", "Right."),
    ("command_02", "On my way."),
    ("command_03", "Sure."),
    ("command_04", "If you say so."),
)
SELECTION_LINES = (
    ("selection_01", "Listening."),
    ("selection_02", "What."),
    ("selection_03", "Yeah?"),
)
# BG drops a "rare select" line about 5% of the time; this is the slot for it.
RARE_SELECTION_LINES = (("selection_rare_01", "It never does stop raining, does it."),)


def band_limited_noise(rng: np.random.Generator, samples: int, centre_hz: float, width: float) -> np.ndarray:
    """Noise shaped by a log-normal bump around `centre_hz` in the frequency domain."""
    spectrum = rng.normal(size=samples) + 1j * rng.normal(size=samples)
    freqs = np.fft.fftfreq(samples, d=1.0 / SAMPLE_RATE)
    magnitude = np.abs(freqs)
    # Avoid log(0) at DC.
    magnitude[0] = 1.0
    shape = np.exp(-((np.log(magnitude / centre_hz)) ** 2) / (2 * width**2))
    shape[0] = 0.0
    return np.real(np.fft.ifft(spectrum * shape))


def footstep(rng: np.random.Generator, surface: Surface) -> np.ndarray:
    # Just under the stride, deliberately.
    #
    # A footfall lands every 0.2667s (one 8-frame cycle at 15Hz carries two
    # steps), and the cadence gate is only sampled on logic ticks — so a clip
    # *over* the stride rounds the next step up to five ticks and the footsteps
    # drift 25% slower than the legs. Staying under it lets the stride floor
    # govern and the two land exactly together.
    duration = 0.26
    samples = int(SAMPLE_RATE * duration)
    t = np.arange(samples) / SAMPLE_RATE

    body = band_limited_noise(rng, samples, surface.centre_hz, surface.width)
    # Fast attack, exponential decay — a heel landing, not a fade-in.
    attack = np.clip(t / 0.004, 0.0, 1.0)
    envelope = attack * np.exp(-surface.decay * t)
    signal = body * envelope

    if surface.splash > 0:
        # A thin high band on top, decaying faster than the body.
        spray = band_limited_noise(rng, samples, 3_800.0, 0.9)
        signal += surface.splash * spray * attack * np.exp(-surface.decay * 2.4 * t)

    # Slight per-variant level and a touch of low thump for weight.
    thump = np.sin(2 * np.pi * 62.0 * t) * np.exp(-58.0 * t)
    signal += 0.18 * thump

    peak = np.max(np.abs(signal))
    if peak > 0:
        signal = signal / peak
    # Leave headroom: several of these can overlap with rain and dialogue.
    return signal * rng.uniform(0.46, 0.58)


# `mvhd`, `tkhd` and `mdhd` each carry a creation and a modification time, so two
# bakes of identical audio differ in exactly six bytes. Zeroing them (a legal
# "unknown", 1904-01-01) is what makes the set diffable, which matters because a
# change meant to be inert has to come back byte-identical.
TIMESTAMPED_ATOMS = (b"mvhd", b"tkhd", b"mdhd")


def normalise_mp4_timestamps(path: Path) -> None:
    data = bytearray(path.read_bytes())
    for atom in TIMESTAMPED_ATOMS:
        start = 0
        while True:
            found = data.find(atom, start)
            if found < 0:
                break
            # Atom body follows the 4-byte type; first 4 bytes are version/flags,
            # then creation_time and modification_time. Version 1 widens both to
            # 64-bit, which afconvert does not emit — assert rather than guess.
            body = found + len(atom)
            version = data[body]
            if version == 0:
                data[body + 4 : body + 12] = b"\x00" * 8
            start = found + 1
    path.write_bytes(bytes(data))

def write_wav(path: Path, signal: np.ndarray) -> None:
    clipped = np.clip(signal, -1.0, 1.0)
    pcm = (clipped * 32_767.0).astype("<i2")
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(pcm.tobytes())


def to_m4a(wav: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        # `aac@44100` rather than bare `aac`: `say` emits 22.05 kHz and the
        # converter refuses to configure AAC for it ('!dat'). Pinning the output
        # rate resamples on the way through and matches the shipped audio.
        [
            "afconvert",
            "-f", "m4af",
            "-d", f"aac@{SAMPLE_RATE}",
            "-b", "96000",
            str(wav),
            str(destination),
        ],
        check=True,
        capture_output=True,
    )
    normalise_mp4_timestamps(destination)


def say_to_m4a(text: str, destination: Path) -> None:
    """Placeholder voice via `say`. Obviously synthetic, and meant to be."""
    with tempfile.TemporaryDirectory() as tmp:
        aiff = Path(tmp) / "line.aiff"
        subprocess.run(
            ["say", "-v", "Daniel", "-r", "168", "-o", str(aiff), text],
            check=True,
            capture_output=True,
        )
        to_m4a(aiff, destination)


def main() -> int:
    if shutil.which("afconvert") is None:
        print("afconvert not found; this script needs macOS.", file=sys.stderr)
        return 1

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(SEED)
    written: list[str] = []

    with tempfile.TemporaryDirectory() as tmp:
        for surface in SURFACES:
            for index in range(surface.variants):
                name = f"sfx_footstep_{surface.name}_{index + 1:02d}.m4a"
                wav = Path(tmp) / f"{surface.name}_{index}.wav"
                write_wav(wav, footstep(rng, surface))
                to_m4a(wav, OUT_DIR / name)
                written.append(name)

    if shutil.which("say") is None:
        print("say not found; skipping placeholder barks.", file=sys.stderr)
    else:
        for group in (COMMAND_LINES, SELECTION_LINES, RARE_SELECTION_LINES):
            for stem, text in group:
                name = f"vo_voss_{stem}.m4a"
                say_to_m4a(text, OUT_DIR / name)
                written.append(name)

    print(f"wrote {len(written)} files to {OUT_DIR.relative_to(REPO)}")
    for name in written:
        print(f"  {name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

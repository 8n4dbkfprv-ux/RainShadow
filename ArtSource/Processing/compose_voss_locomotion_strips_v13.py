#!/usr/bin/env python3
"""Compose Voss idle strips and walk cycles from PreRendered3DV12 Frames."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))

from compose_chroma_strip_v11 import compose  # noqa: E402

V12 = ROOT / "ArtSource/Generated/Characters/Detective/PreRendered3DV12"
FRAMES = V12 / "Frames"
DIRECTIONS = ("s", "ssw", "sw", "wsw", "w", "wnw", "nw", "nnw", "n")


def main() -> None:
    for d in DIRECTIONS:
        walk = [FRAMES / f"voss_walk_{d}_{i:02d}_chroma_v12.png" for i in range(8)]
        for path in walk:
            if not path.is_file():
                raise FileNotFoundError(path)
        compose(walk, V12 / f"voss_walk_{d}_cycle_chroma_v12.png", columns=8, rows=1)

        idle = [FRAMES / f"voss_idle_{d}_{i:02d}_chroma_v12.png" for i in range(4)]
        for path in idle:
            if not path.is_file():
                raise FileNotFoundError(path)
        compose(idle, V12 / f"voss_idle_{d}_strip_chroma_v12.png", columns=4, rows=1)

    print("Composed all V13 locomotion chroma strips/cycles")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Grade a fog-of-war capture against the BG:EE indoor contract.

BG:EE indoor fog is a hard, room-shaped black cutout (32×32 autotiled overlay
clipped by walls). RainShadow used to draw a linearly-filtered disc inside the
office. This tool measures three things a screenshot can actually answer:

    1. Edge width — how many pixels from void to lit floor.
    2. Circularity of the lit region — a disc scores near 1, isometric room
       diamonds and wall-clipped rooms score much lower.
    3. Mean unexplored luma — void must be near-black, not a grey wash.

    python3 ArtSource/Processing/qa_fog_edge.py --reference
    python3 ArtSource/Processing/qa_fog_edge.py <capture.png>

Exit code is non-zero when a capture misses the contract, so this can gate a
fog install the way `qa_plate_projection.py` gates a plate.
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
REFERENCE_DIR = ROOT / "Documentation/Captures/FogBGEEIndoor"

# Pixels at or below this luma are void / fog, not lit floor.
VOID_LUMA = 18
# Lit floor is well above void; used to locate the far side of an edge.
LIT_LUMA = 40
# Indoor BG:EE clips in a few pixels. Horizontal scans cross isometric edges
# at ~36.9°, so a 3 px true clip reads as ~5–8 px here; 192 px close-ups of
# those diagonals run a little wider. A quarter-fog-cell linear ramp is still
# much fatter than this band.
MAX_EDGE_PX = 14
# Circles score ~0.9+. Three isometric diamonds or a wall-clipped room sit
# well below 0.75. 0.82 still fails a spotlight while passing the inn.
MAX_CIRCULARITY = 0.82
# Unexplored void is opaque black, not remembered grey (128) over the whole
# frame. A little UI chrome is allowed; the mean of void pixels must stay low.
MAX_VOID_MEAN = 8.0


def luma(rgb: np.ndarray) -> np.ndarray:
    r = rgb[..., 0].astype(np.float32)
    g = rgb[..., 1].astype(np.float32)
    b = rgb[..., 2].astype(np.float32)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def edge_widths(y: np.ndarray, void: float, lit: float) -> list[int]:
    """Horizontal scans: pixels from last void to first lit, and the reverse."""
    widths: list[int] = []
    rows, cols = y.shape
    for row in range(0, rows, max(1, rows // 64)):
        line = y[row]
        void_idx = np.flatnonzero(line <= void)
        lit_idx = np.flatnonzero(line >= lit)
        if void_idx.size == 0 or lit_idx.size == 0:
            continue
        # Left void → lit
        first_lit = int(lit_idx[0])
        left_void = void_idx[void_idx < first_lit]
        if left_void.size:
            widths.append(first_lit - int(left_void[-1]))
        # Right lit → void
        last_lit = int(lit_idx[-1])
        right_void = void_idx[void_idx > last_lit]
        if right_void.size:
            widths.append(int(right_void[0]) - last_lit)
    return widths


def circularity(mask: np.ndarray) -> float:
    """4π area / perimeter² of the lit region. 1 is a circle.

    Downsamples first so a 4K capture does not walk a million-pixel flood in
    Python. Shape is what we need, not pixel-exact area.
    """
    h, w = mask.shape
    scale = max(1, max(h, w) // 160)
    small = mask[::scale, ::scale]
    if not small.any():
        return 0.0
    area = int(small.sum())
    # Perimeter: lit pixels that touch void on a 4-neighbour. Pad so the
    # frame edge counts as void — a disc clipped by the crop still scores high.
    padded = np.pad(small, 1, mode="constant", constant_values=False)
    up = padded[:-2, 1:-1]
    down = padded[2:, 1:-1]
    left = padded[1:-1, :-2]
    right = padded[1:-1, 2:]
    border = small & ~(up & down & left & right)
    perim = int(border.sum())
    if perim <= 0:
        return 0.0
    return float(4.0 * math.pi * area / (perim * perim))


def grade(path: Path) -> list[str]:
    image = Image.open(path).convert("RGB")
    rgb = np.asarray(image)
    y = luma(rgb)
    void_mask = y <= VOID_LUMA
    lit_mask = y >= LIT_LUMA
    failures: list[str] = []

    widths = edge_widths(y, VOID_LUMA, LIT_LUMA)
    if not widths:
        failures.append("no void/lit edge found")
    else:
        median_w = float(np.median(widths))
        if median_w > MAX_EDGE_PX:
            failures.append(
                f"edge {median_w:.1f} px wide (max {MAX_EDGE_PX}) — linear-filter blob"
            )

    circ = circularity(lit_mask)
    if circ > MAX_CIRCULARITY:
        failures.append(
            f"lit circularity {circ:.3f} (max {MAX_CIRCULARITY}) — circular pool"
        )

    if void_mask.any():
        void_mean = float(y[void_mask].mean())
        if void_mean > MAX_VOID_MEAN:
            failures.append(
                f"void luma {void_mean:.1f} (max {MAX_VOID_MEAN}) — not opaque black"
            )
    else:
        failures.append("no void pixels — fog is missing")

    return failures


def reference_paths() -> list[Path]:
    names = [
        "bgee_inn_rooms_wide.png",
        "bgee_inn_floor_diamond_edge.png",
        "bgee_inn_floor_diamond_tip.png",
        "bgee_inn_wall_gap.png",
    ]
    return [REFERENCE_DIR / name for name in names]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "images",
        nargs="*",
        type=Path,
        help="captures to grade (PNG)",
    )
    parser.add_argument(
        "--reference",
        action="store_true",
        help="grade the checked-in BG:EE indoor crops",
    )
    args = parser.parse_args(argv)

    paths = list(args.images)
    if args.reference:
        paths.extend(reference_paths())
    if not paths:
        parser.error("pass image paths or --reference")

    failed = 0
    for path in paths:
        if not path.is_file():
            print(f"FAIL {path}: missing")
            failed += 1
            continue
        issues = grade(path)
        if issues:
            print(f"FAIL {path.name}: {'; '.join(issues)}")
            failed += 1
        else:
            print(f"PASS {path.name}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())

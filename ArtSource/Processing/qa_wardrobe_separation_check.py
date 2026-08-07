#!/usr/bin/env python3
"""Pass/fail a character master on material separation.

Voss reads as one tan mass because every band of him is the same hue at a
different brightness — R:G:B sits at 1 : 0.68 : 0.39 from hat to shoes. A BG:EE
avatar separates materials by hue as well as value.

The check clusters a figure's colours and measures the spread of the cluster
centroids on two axes:

    value spread  max-min of centroid luma
    hue spread    largest pairwise distance in (G/R, B/R) space, counting only
                  clusters covering >= 8% of the figure

Measured on the repo's BG:EE reference avatars: value spread 34-148, hue spread
0.178 (green_robe, a monk in one robe) to 1.966 (mage circle robes), with
red_tunic at 0.948 and townsfolk at 0.485.

Voss ships at value 66-113 (fine) and hue **0.040-0.052** — roughly 4x below even
the weakest reference. Lila ships at 0.165, also under the floor. So hue spread is
the discriminator: 0.18 is the floor, 0.45 is what a character with a real
multi-garment wardrobe should reach.

Usage:
    python3 qa_wardrobe_separation_check.py <image> [<image> ...]
    python3 qa_wardrobe_separation_check.py --shipped     # the current atlases
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ATLASES = ROOT / "RainShadow Shared/Resources/Art/Atlases"

HUE_SPREAD_MIN = 0.18   # weakest BG:EE reference (green_robe 0.178)
HUE_SPREAD_TARGET = 0.45  # townsfolk 0.485, red tunic 0.948
CLUSTERS = 6


def figure_pixels(path: Path) -> np.ndarray:
    """Opaque body pixels, chroma-keyed if the master is still on green."""
    image = Image.open(path)
    if image.mode == "RGBA":
        rgba = np.asarray(image)
        pixels = rgba[..., :3][rgba[..., 3] >= 128]
    else:
        rgb = np.asarray(image.convert("RGB")).reshape(-1, 3).astype(np.int16)
        r, g, b = rgb[:, 0], rgb[:, 1], rgb[:, 2]
        green = (g > 140) & (g > r + 40) & (g > b + 40)
        pixels = rgb[~green]
    # Drop near-black: backdrop and deep shadow carry no material identity.
    return pixels[pixels.mean(1) > 25].astype(np.float64)


def centroids(pixels: np.ndarray, k: int = CLUSTERS, iterations: int = 30) -> tuple[np.ndarray, np.ndarray]:
    if len(pixels) < k:
        return pixels, np.ones(len(pixels)) / max(1, len(pixels))
    rng = np.random.default_rng(0)
    seeds = pixels[rng.choice(len(pixels), k, replace=False)]
    labels = np.zeros(len(pixels), dtype=int)
    for _ in range(iterations):
        labels = ((pixels[:, None, :] - seeds[None]) ** 2).sum(2).argmin(1)
        for index in range(k):
            if (labels == index).any():
                seeds[index] = pixels[labels == index].mean(0)
    weights = np.array([(labels == i).mean() for i in range(len(seeds))])
    order = np.argsort(seeds.mean(1))
    return seeds[order], weights[order]


def measure(path: Path) -> tuple[float, float, np.ndarray, np.ndarray]:
    pixels = figure_pixels(path)
    if len(pixels) < 64:
        raise RuntimeError(f"{path.name}: too few body pixels to judge")
    sample = pixels[:: max(1, len(pixels) // 20000)]
    seeds, weights = centroids(sample)
    luma = seeds.mean(1)

    # Only clusters that actually cover the figure count. A handful of deep
    # shadow pixels sit near black, where G/R and B/R are numerically unstable,
    # and one such outlier used to carry a monochrome frame over the bar.
    solid = weights >= 0.08
    if solid.sum() < 2:
        solid = weights >= weights.max() * 0.5
    hue = np.stack([seeds[:, 1] / np.maximum(seeds[:, 0], 1),
                    seeds[:, 2] / np.maximum(seeds[:, 0], 1)], axis=1)[solid]
    spread = max(
        float(np.linalg.norm(hue[i] - hue[j]))
        for i in range(len(hue))
        for j in range(len(hue))
    )
    return float(luma.max() - luma.min()), spread, seeds, weights


def report(path: Path) -> bool:
    value_spread, hue_spread, seeds, weights = measure(path)
    ok = hue_spread >= HUE_SPREAD_MIN
    verdict = "PASS" if ok else "FAIL"
    grade = "" if hue_spread >= HUE_SPREAD_TARGET else "  (above the floor but below target 0.45)"
    print(f"\n{path.name}")
    print(f"  value spread {value_spread:6.1f}   hue spread {hue_spread:6.3f}   [{verdict}]{grade if ok else ''}")
    print("  material ladder, darkest first (share = fraction of the figure):")
    for seed, weight in zip(seeds, weights):
        r, g, b = seed
        mark = " " if weight >= 0.08 else "·"  # · = too small to count toward hue spread
        print(f"   {mark}RGB {seed.round(0)}  luma {seed.mean():5.1f}  G/R {g/max(r,1):.3f}  B/R {b/max(r,1):.3f}  share {weight*100:4.1f}%")
    if not ok:
        print(f"  → needs hue spread >= {HUE_SPREAD_MIN} (target {HUE_SPREAD_TARGET}); materials are the same hue at different brightnesses.")
    return ok


def main() -> int:
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        return 2

    if args == ["--shipped"]:
        paths = [
            ATLASES / "VossIdle.atlas/voss_standing_idle_s_00.png",
            ATLASES / "VossIdle.atlas/voss_standing_idle_sw_00.png",
            ATLASES / "VossSeatedIdle.atlas/voss_seated_idle_ne_00.png",
            ATLASES / "LilaArrival.atlas/lila_arrival_sw_08.png",
        ]
    else:
        paths = [Path(a) for a in args]

    results = [report(p) for p in paths if p.exists()]
    missing = [p for p in paths if not p.exists()]
    for p in missing:
        print(f"\n{p}: missing")
    print()
    return 0 if results and all(results) else 1


if __name__ == "__main__":
    raise SystemExit(main())

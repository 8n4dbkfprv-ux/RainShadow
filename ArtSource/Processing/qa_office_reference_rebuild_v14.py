#!/usr/bin/env python3
"""Grade the V14 ImageGen room envelope and registered office assets."""

from __future__ import annotations

import json
import math
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

import generate_office_reference_rebuild_v14 as generator
import qa_plate_projection


ROOT = Path(__file__).resolve().parents[2]
STAGE = generator.STAGE
PLATE = STAGE / generator.FILENAMES["plate"]
ARCHITECTURE = STAGE / generator.FILENAMES["architectureMask"]
GLASS = STAGE / generator.FILENAMES["glassMask"]
HOVER = STAGE / generator.FILENAMES["nearHover"]
METRICS = STAGE / generator.FILENAMES["metrics"]


def _vector(start: list[float], end: list[float]) -> tuple[float, float]:
    return end[0] - start[0], end[1] - start[1]


def main() -> int:
    required = [
        generator.RAW_SOURCE,
        generator.SOURCE,
        generator.TARGET_REFERENCE,
        PLATE,
        ARCHITECTURE,
        GLASS,
        HOVER,
        METRICS,
    ]
    missing = [str(path.relative_to(ROOT)) for path in required if not path.exists()]
    if missing:
        print("FAIL missing V14 files: " + ", ".join(missing))
        return 1

    metrics = json.loads(METRICS.read_text(encoding="utf-8"))
    source = Image.open(generator.SOURCE).convert("RGB")
    plate = Image.open(PLATE).convert("RGB")
    architecture = np.asarray(Image.open(ARCHITECTURE).convert("L"), dtype=np.uint8)
    glass = np.asarray(Image.open(GLASS).convert("RGBA"), dtype=np.uint8)
    hover = np.asarray(Image.open(HOVER).convert("RGBA"), dtype=np.uint8)
    checks: list[tuple[str, bool, str]] = []

    checks.append((
        "source and plate canvases",
        source.size == (1408, 1117) and plate.size == (4096, 2304),
        f"source={source.size}; plate={plate.size}",
    ))
    checks.append((
        "frozen ImageGen and reference identities",
        metrics["imageGeneration"]["rawSourceSha256"]
        == generator.v12.sha256(generator.RAW_SOURCE)
        and metrics["imageGeneration"]["geometryReferenceSha256"]
        == generator.v12.sha256(generator.TARGET_REFERENCE)
        and metrics["source"]["sha256"] == generator.v12.sha256(generator.SOURCE),
        f"raw={generator.v12.sha256(generator.RAW_SOURCE)[:12]} "
        f"reference={generator.v12.sha256(generator.TARGET_REFERENCE)[:12]} "
        f"source={generator.v12.sha256(generator.SOURCE)[:12]}",
    ))

    floor = generator.SOURCE_PLANES["floor"]
    rear, west, near, east = floor
    axis_nw = _vector(rear, west)
    axis_ne = _vector(rear, east)
    near_nw = _vector(west, near)
    near_ne = _vector(east, near)
    closure = (
        west[0] + east[0] - rear[0] - near[0],
        west[1] + east[1] - rear[1] - near[1],
    )
    slope_nw = axis_nw[1] / axis_nw[0]
    slope_ne = axis_ne[1] / axis_ne[0]
    near_slope_nw = near_nw[1] / near_nw[0]
    near_slope_ne = near_ne[1] / near_ne[0]
    ratio = math.hypot(*axis_nw) / math.hypot(*axis_ne)
    checks.append((
        "reference-guided tapered visible floor envelope",
        abs(closure[0] + 97.0) <= 1e-6
        and abs(closure[1] - 54.0) <= 1e-6
        and abs(slope_nw + 0.7041) <= 0.001
        and abs(slope_ne - 0.7343) <= 0.001
        and abs(near_slope_nw - 0.4962) <= 0.001
        and abs(near_slope_ne + 0.7267) <= 0.001
        and 1.66 <= ratio <= 1.70,
        f"closure=({closure[0]:.3f},{closure[1]:.3f}) "
        f"rear={slope_nw:+.3f}/{slope_ne:+.3f} "
        f"near={near_slope_nw:+.3f}/{near_slope_ne:+.3f} ratio={ratio:.3f}",
    ))
    near_margin = (source.height - near[1]) / source.height
    top_margin = min(
        point[1] for plane in generator.SOURCE_PLANES.values() for point in plane
    ) / source.height
    left_margin = min(point[0] for plane in generator.SOURCE_PLANES.values() for point in plane) / source.width
    right_margin = (
        source.width
        - max(point[0] for plane in generator.SOURCE_PLANES.values() for point in plane)
    ) / source.width
    checks.append((
        "uncropped room framing",
        0.06 <= near_margin <= 0.09
        and 0.12 <= top_margin <= 0.15
        and left_margin >= 0.08
        and right_margin >= 0.08,
        f"top={top_margin:.1%} near={near_margin:.1%} "
        f"left={left_margin:.1%} right={right_margin:.1%}",
    ))

    wall_heights = []
    crown_slopes = []
    seam_slopes = []
    for key in ("NW", "NE"):
        crown_rear, crown_end, base_end, base_rear = generator.SOURCE_PLANES[key]
        wall_heights.extend([
            base_rear[1] - crown_rear[1],
            base_end[1] - crown_end[1],
        ])
        crown_slopes.append(
            (crown_end[1] - crown_rear[1]) / (crown_end[0] - crown_rear[0])
        )
        seam_slopes.append(
            (base_end[1] - base_rear[1]) / (base_end[0] - base_rear[0])
        )
    checks.append((
        "ImageGen wall-height and crown profile",
        all(
            abs(actual - expected) <= 1e-6
            for actual, expected in zip(wall_heights, [111.0, 119.0, 111.0, 124.0])
        )
        and abs(crown_slopes[0] + 0.6875) <= 0.001
        and abs(crown_slopes[1] - 0.6943) <= 0.001,
        f"heights={'/'.join(f'{v:.1f}' for v in wall_heights)} "
        f"crown={'/'.join(f'{v:+.3f}' for v in crown_slopes)} "
        f"seam={'/'.join(f'{v:+.3f}' for v in seam_slopes)}",
    ))

    source_pixels = np.asarray(source, dtype=np.uint8)
    source_mask = np.zeros((source.height, source.width), dtype=bool)
    from PIL import ImageDraw

    mask_image = Image.new("L", source.size, 0)
    draw = ImageDraw.Draw(mask_image)
    for polygon in generator.SOURCE_PLANES.values():
        draw.polygon([tuple(point) for point in polygon], fill=255)
    source_mask = np.asarray(mask_image, dtype=np.uint8) > 0
    exterior_pixels = int(np.count_nonzero(np.any(source_pixels > 3, axis=2) & ~source_mask))
    checks.append((
        "bounded ImageGen trim overhang",
        exterior_pixels <= 10_000,
        f"{exterior_pixels} trim/antialias pixels outside measured planes",
    ))

    outside_plate = int(np.count_nonzero(
        np.any(np.asarray(plate, dtype=np.uint8) != 0, axis=2) & (architecture == 0)
    ))
    checks.append((
        "pure-black registered plate exterior",
        outside_plate == 0,
        f"{outside_plate} pixels",
    ))
    projection = qa_plate_projection.grade(PLATE)
    checks.append((
        "BG:EE texture projection lock",
        projection["worst_delta"] <= 2.5,
        f"{projection['peak_pos']:+.2f}/{projection['peak_neg']:+.2f}; "
        f"delta={projection['worst_delta']:.2f}°",
    ))
    checks.append((
        "registered two-window rain and near-hover masks",
        len(generator.SOURCE_WINDOWS) == 2
        and all(len(window["glass"]) == 6 for window in generator.SOURCE_WINDOWS)
        and int(np.count_nonzero(glass[:, :, 3])) > 0
        and int(np.count_nonzero(hover[:, :, 3])) > 0,
        f"glass={int(np.count_nonzero(glass[:, :, 3]))} "
        f"hover={int(np.count_nonzero(hover[:, :, 3]))}",
    ))
    ratio_fireplace = float(
        metrics["fireplace"]["visualScaleLock"]["fireplaceToAdultRatio"]
    )
    checks.append((
        "human-relative fireplace scale",
        1.15 <= ratio_fireplace <= 1.35,
        f"{ratio_fireplace:.3f} adults",
    ))

    with tempfile.TemporaryDirectory(prefix="rainshadow-v14-reproduce-") as temp_name:
        reproduced = generator.write_assets(Path(temp_name))
        compared = ["plate", "architectureMask", "glassMask", "nearHover", "metrics"]
        mismatches = [
            key
            for key in compared
            if generator.v12.sha256(STAGE / generator.FILENAMES[key])
            != generator.v12.sha256(reproduced[key])
        ]
    checks.append((
        "deterministic regeneration",
        not mismatches,
        "identical" if not mismatches else ", ".join(mismatches),
    ))

    for name, passed, detail in checks:
        print(f"{'PASS' if passed else 'FAIL'}  {name}: {detail}")
    ok = all(passed for _, passed, _ in checks)
    print(f"\nALL_PASS={ok}")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())

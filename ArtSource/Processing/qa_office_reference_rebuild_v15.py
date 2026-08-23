#!/usr/bin/env python3
"""Grade the V15 room against the AR0809 silhouette and BG:EE camera lock."""

from __future__ import annotations

import json
import math
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

import generate_office_reference_rebuild_v15 as generator
import qa_plate_projection


ROOT = Path(__file__).resolve().parents[2]
STAGE = generator.STAGE
PLATE = STAGE / generator.FILENAMES["plate"]
ARCHITECTURE = STAGE / generator.FILENAMES["architectureMask"]
GLASS = STAGE / generator.FILENAMES["glassMask"]
HOVER = STAGE / generator.FILENAMES["nearHover"]
METRICS = STAGE / generator.FILENAMES["metrics"]


def main() -> int:
    required = [generator.SOURCE, generator.REFERENCE, PLATE, ARCHITECTURE, GLASS, HOVER, METRICS]
    missing = [str(path.relative_to(ROOT)) for path in required if not path.exists()]
    if missing:
        print("FAIL missing V15 files: " + ", ".join(missing))
        return 1

    source = Image.open(generator.SOURCE).convert("RGB")
    plate = Image.open(PLATE).convert("RGB")
    architecture = np.asarray(Image.open(ARCHITECTURE).convert("L"), dtype=np.uint8)
    glass = np.asarray(Image.open(GLASS).convert("RGBA"), dtype=np.uint8)
    hover = np.asarray(Image.open(HOVER).convert("RGBA"), dtype=np.uint8)
    metrics = json.loads(METRICS.read_text(encoding="utf-8"))
    checks: list[tuple[str, bool, str]] = []

    checks.append((
        "source and registered canvases",
        source.size == generator.SOURCE_SIZE and plate.size == generator.CANVAS,
        f"source={source.size}; plate={plate.size}",
    ))
    checks.append((
        "frozen ImageGen and AR0809 identities",
        metrics["source"]["sha256"] == generator.sha256(generator.SOURCE)
        and metrics["targetReference"]["sha256"] == generator.sha256(generator.REFERENCE),
        f"imagegen={generator.sha256(generator.SOURCE)[:12]} reference={generator.sha256(generator.REFERENCE)[:12]}",
    ))

    floor = generator.SOURCE_PLANES["floor"]
    long_axis = (floor[1][0] - floor[0][0], floor[1][1] - floor[0][1])
    short_axis = (floor[3][0] - floor[0][0], floor[3][1] - floor[0][1])
    ratio = math.hypot(*long_axis) / math.hypot(*short_axis)
    checks.append((
        "AR0809 long-room proportion",
        1.55 <= ratio <= 1.70,
        f"long/short ground axis={ratio:.3f}",
    ))

    rear_height = generator.SOURCE_PLANES["NW"][3][1] - generator.SOURCE_PLANES["NW"][0][1]
    left_tip = generator.SOURCE_PLANES["NW"][2][1] - generator.SOURCE_PLANES["NW"][1][1]
    right_tip = generator.SOURCE_PLANES["NE"][2][1] - generator.SOURCE_PLANES["NE"][1][1]
    left_inward = generator.SOURCE_PLANES["NW"][2][0] > generator.SOURCE_PLANES["NW"][1][0]
    right_inward = generator.SOURCE_PLANES["NE"][2][0] < generator.SOURCE_PLANES["NE"][1][0]
    checks.append((
        "AR0809 tapered point-cutaway walls",
        rear_height >= 100
        and left_tip <= rear_height * 0.20
        and right_tip <= rear_height * 0.20,
        f"rear={rear_height:.0f}px leftTip={left_tip:.0f}px rightTip={right_tip:.0f}px "
        f"inward={left_inward}/{right_inward}",
    ))

    foreground = np.max(np.asarray(source, dtype=np.uint8), axis=2) > 8
    ys, xs = np.where(foreground)
    margins = (int(xs.min()), int(ys.min()), source.width - 1 - int(xs.max()), source.height - 1 - int(ys.max()))
    checks.append((
        "uncropped ImageGen room framing",
        min(margins) >= 50,
        f"left/top/right/bottom={margins}",
    ))

    outside = int(np.count_nonzero(np.max(np.asarray(plate), axis=2) & (architecture == 0)))
    checks.append(("pure-black registered exterior", outside == 0, f"{outside} pixels"))

    projection = qa_plate_projection.grade(PLATE)
    checks.append((
        "BG:EE texture projection lock",
        projection["worst_delta"] <= 2.5,
        f"{projection['peak_pos']:+.2f}/{projection['peak_neg']:+.2f}; delta={projection['worst_delta']:.2f}°",
    ))

    checks.append((
        "two six-pane windows and hover overlay",
        len(generator.SOURCE_WINDOWS) == 2
        and all(len(window["glass"]) == 6 for window in generator.SOURCE_WINDOWS)
        and int(np.count_nonzero(glass[:, :, 3])) > 0
        and int(np.count_nonzero(hover[:, :, 3])) > 0,
        f"glass={int(np.count_nonzero(glass[:, :, 3]))} hover={int(np.count_nonzero(hover[:, :, 3]))}",
    ))

    with tempfile.TemporaryDirectory(prefix="rainshadow-v15-reproduce-") as temp_name:
        reproduced = generator.write_assets(Path(temp_name))
        compared = ["plate", "architectureMask", "glassMask", "nearHover", "metrics"]
        mismatches = [
            key for key in compared
            if generator.sha256(STAGE / generator.FILENAMES[key]) != generator.sha256(reproduced[key])
        ]
    checks.append(("deterministic regeneration", not mismatches, "identical" if not mismatches else ", ".join(mismatches)))

    for name, passed, detail in checks:
        print(f"{'PASS' if passed else 'FAIL'}  {name}: {detail}")
    ok = all(passed for _, passed, _ in checks)
    print(f"\nALL_PASS={ok}")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())

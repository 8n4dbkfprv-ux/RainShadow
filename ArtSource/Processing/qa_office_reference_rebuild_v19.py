#!/usr/bin/env python3
"""Grade the V19 baked-door shell and its deterministic registration."""

from __future__ import annotations

import json
import math
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

import generate_office_reference_rebuild_v17 as v17
import generate_office_reference_rebuild_v18 as v18
import generate_office_reference_rebuild_v19 as generator
import qa_plate_projection


ROOT = generator.ROOT
STAGE = generator.STAGE


def main() -> int:
    paths = {key: STAGE / name for key, name in generator.FILENAMES.items()}
    required = [generator.SOURCE, *paths.values()]
    missing = [str(path.relative_to(ROOT)) for path in required if not path.exists()]
    if missing:
        print("FAIL missing V19 files: " + ", ".join(missing))
        return 1

    plate = Image.open(paths["plate"]).convert("RGB")
    architecture = np.asarray(Image.open(paths["architectureMask"]).convert("L"))
    rgb = np.asarray(plate)
    metrics = json.loads(paths["metrics"].read_text(encoding="utf-8"))
    checks: list[tuple[str, bool, str]] = []

    checks.append((
        "exact V17 AR0809 envelope retained",
        all(
            np.array_equal(
                np.asarray(metrics["registration"]["targetPlanes"][plane]),
                np.asarray(v17.TARGET_PLANES[plane]),
            )
            for plane in ("floor", "NW", "NE")
        )
        and plate.size == v17.CANVAS,
        f"canvas={plate.size}",
    ))
    outside_nonblack = int(np.count_nonzero(np.max(rgb, axis=2)[architecture == 0]))
    checks.append((
        "pure-black exterior outside room and baked door",
        outside_nonblack == 0,
        f"nonblackOutside={outside_nonblack}",
    ))
    v18_plate_path = v18.STAGE / v18.FILENAMES["plate"]
    v18_plate = np.asarray(Image.open(v18_plate_path).convert("RGB"))
    v18_architecture = np.asarray(
        Image.open(v18.STAGE / v18.FILENAMES["architectureMask"]).convert("L")
    )
    door_only = (architecture > 0) & (v18_architecture == 0)
    checks.append((
        "every non-door room pixel is byte-identical to V18",
        np.array_equal(rgb[~door_only], v18_plate[~door_only]),
        f"doorOnlyPixels={int(np.count_nonzero(door_only))}",
    ))

    # The exact door texture follows the near-edge diagonal and could
    # become the estimator's strongest positive peak. Grade the byte-identical
    # underlying room rather than pretending the intended new pixels are floor.
    projection = qa_plate_projection.grade(v18_plate_path)
    reference = qa_plate_projection.grade(v17.STAGE / v17.FILENAMES["plate"])
    projection_delta = max(
        abs(projection["peak_pos"] - reference["peak_pos"]),
        abs(projection["peak_neg"] - reference["peak_neg"]),
    )
    checks.append((
        "underlying AR0809 directional-depth signature retained",
        projection_delta <= 0.20,
        f"v19={projection['peak_pos']:+.2f}/{projection['peak_neg']:+.2f} "
        f"v17={reference['peak_pos']:+.2f}/{reference['peak_neg']:+.2f} "
        f"delta={projection_delta:.2f}deg",
    ))

    door = metrics["door"]
    visible_door = np.max(np.abs(rgb.astype(int) - v18_plate.astype(int)), axis=2) > 2
    door_ys, door_xs = np.nonzero(visible_door)
    visible_points = np.column_stack((door_xs, door_ys)).astype(float)
    visible_points -= np.mean(visible_points, axis=0)
    eigenvalues, eigenvectors = np.linalg.eigh(np.cov(visible_points, rowvar=False))
    visible_axis = eigenvectors[:, int(np.argmax(eigenvalues))]
    if visible_axis[0] < 0:
        visible_axis = -visible_axis
    visible_angle = math.degrees(
        math.atan2(float(visible_axis[1]), float(visible_axis[0]))
    )
    edge_vector = (
        np.asarray(v17.TARGET_FLOOR[3]) - np.asarray(v17.TARGET_FLOOR[2])
    )
    edge_length = float(np.linalg.norm(edge_vector))
    edge_unit = edge_vector / edge_length
    normal_unit = np.asarray((-edge_unit[1], edge_unit[0]))
    visible_length_fraction = float(np.ptp(visible_points @ edge_unit)) / edge_length
    visible_thickness_fraction = (
        float(np.ptp(visible_points @ normal_unit)) / edge_length
    )
    checks.append((
        "baked door is straight and parallel to the cutaway edge",
        abs(visible_angle - door["targetEdgeDegrees"]) <= 0.05,
        f"door={visible_angle:+.2f}deg "
        f"edge={door['targetEdgeDegrees']:+.2f}deg",
    ))
    checks.append((
        "door uses the approved 70% perceptual-reference scale",
        0.124 <= visible_length_fraction <= 0.128
        and abs(door["referenceScaleFactor"] - 0.70) <= 1e-12,
        f"door={visible_length_fraction * 100:.2f}% of edge "
        f"scale={door['referenceScaleFactor']:.2f}",
    ))
    checks.append((
        "door thickness matches AR0809 without stretching its texture",
        0.0150 <= visible_thickness_fraction <= 0.0165
        and door["perpendicularBackingEdgePixelsPerSide"] == 4,
        f"thickness={visible_thickness_fraction * 100:.2f}% of edge "
        f"backing={door['perpendicularBackingEdgePixelsPerSide']}px/side",
    ))
    checks.append((
        "door is baked and has no runtime texture",
        metrics["doorPixelsBakedIntoPlate"] is True
        and door["runtimeVisualTexture"] is None
        and door["logicalDoorRetained"] is True,
        f"construction={door['construction']}",
    ))
    area = json.loads(
        (ROOT / "RainShadow Shared/Resources/Areas/office_suite.area.json").read_text()
    )["area"]
    area_door = next(item for item in area["doors"] if item["id"] == "office.door")
    checks.append((
        "area keeps logical door without visual registration",
        "visual" not in area_door and "textureName" not in area_door,
        f"keys={sorted(area_door)}",
    ))

    with tempfile.TemporaryDirectory(prefix="rainshadow-v19-reproduce-") as temp_name:
        reproduced = generator.write_assets(Path(temp_name))
        mismatches = [
            key for key in generator.FILENAMES
            if v17.sha256(paths[key]) != v17.sha256(reproduced[key])
        ]
    checks.append((
        "deterministic regeneration",
        not mismatches,
        "identical" if not mismatches else ", ".join(mismatches),
    ))

    for name, passed, detail in checks:
        print(f"{'PASS' if passed else 'FAIL'}  {name}: {detail}")
    passed = all(ok for _, ok, _ in checks)
    print(f"\nALL_PASS={passed}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())

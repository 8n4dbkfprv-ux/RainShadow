#!/usr/bin/env python3
"""Grade the V17 shell against the exact AR0809 geometry authority."""

from __future__ import annotations

import json
import math
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

import generate_office_reference_rebuild_v17 as generator
import qa_plate_projection


ROOT = generator.ROOT
STAGE = generator.STAGE


def main() -> int:
    paths = {
        key: STAGE / filename for key, filename in generator.FILENAMES.items()
    }
    required = [generator.SOURCE, generator.REFERENCE, generator.REFERENCE_GUIDE, *paths.values()]
    missing = [str(path.relative_to(ROOT)) for path in required if not path.exists()]
    if missing:
        print("FAIL missing V17 files: " + ", ".join(missing))
        return 1

    plate = Image.open(paths["plate"]).convert("RGB")
    architecture = np.asarray(Image.open(paths["architectureMask"]).convert("L"))
    metrics = json.loads(paths["metrics"].read_text(encoding="utf-8"))
    checks: list[tuple[str, bool, str]] = []

    checks.append((
        "source, reference and canvas identities",
        metrics["source"]["sha256"] == generator.sha256(generator.SOURCE)
        and metrics["targetReference"]["sha256"] == generator.sha256(generator.REFERENCE)
        and metrics["targetReference"]["guideSha256"] == generator.sha256(generator.REFERENCE_GUIDE)
        and plate.size == generator.CANVAS,
        f"source={generator.sha256(generator.SOURCE)[:12]} reference={generator.sha256(generator.REFERENCE)[:12]} canvas={plate.size}",
    ))

    expected_floor = np.asarray(generator.TARGET_FLOOR)
    actual_floor = np.asarray(metrics["registration"]["targetPlanes"]["floor"])
    expected_crown = np.asarray(generator.TARGET_CROWN)
    actual_crown = np.asarray(metrics["registration"]["targetPlanes"]["NW"][0])
    control_error = max(
        float(np.max(np.abs(expected_floor - actual_floor))),
        float(np.max(np.abs(expected_crown - actual_crown))),
    )
    checks.append((
        "exact uniformly-scaled AR0809 control points",
        control_error <= 1e-9,
        f"maxError={control_error:.9f}px floor={actual_floor.tolist()} crown={actual_crown.tolist()}",
    ))

    depth_ratio = float(metrics["registration"]["floorDepthToWidth"])
    reference_depth_ratio = float(metrics["registration"]["referenceFloorDepthToWidth"])
    checks.append((
        "AR0809 perceived floor depth",
        abs(depth_ratio - reference_depth_ratio) <= 1e-12,
        f"plate={depth_ratio:.6f} reference={reference_depth_ratio:.6f}",
    ))

    rear, left, _, right = actual_floor
    long_short = float(np.linalg.norm(left - rear) / np.linalg.norm(right - rear))
    reference = np.asarray(generator.GUIDE_FLOOR)
    reference_long_short = float(
        np.linalg.norm(reference[1] - reference[0])
        / np.linalg.norm(reference[3] - reference[0])
    )
    checks.append((
        "AR0809 long-room proportion",
        abs(long_short - reference_long_short) <= 1e-12,
        f"plate={long_short:.6f} reference={reference_long_short:.6f}",
    ))

    rgb = np.asarray(plate)
    outside_nonblack = int(np.count_nonzero(np.max(rgb, axis=2)[architecture == 0]))
    checks.append((
        "pure-black registered exterior",
        outside_nonblack == 0,
        f"nonblackOutside={outside_nonblack}",
    ))

    plate_projection = qa_plate_projection.grade(paths["plate"])
    reference_projection = qa_plate_projection.grade(generator.REFERENCE)
    projection_delta = max(
        abs(plate_projection["peak_pos"] - reference_projection["peak_pos"]),
        abs(plate_projection["peak_neg"] - reference_projection["peak_neg"]),
    )
    checks.append((
        "AR0809 directional-depth signature",
        projection_delta <= 3.5,
        f"plate={plate_projection['peak_pos']:+.2f}/{plate_projection['peak_neg']:+.2f} "
        f"reference={reference_projection['peak_pos']:+.2f}/{reference_projection['peak_neg']:+.2f} "
        f"delta={projection_delta:.2f}deg",
    ))

    with tempfile.TemporaryDirectory(prefix="rainshadow-v17-reproduce-") as temp_name:
        reproduced = generator.write_assets(Path(temp_name))
        mismatches = [
            key for key in generator.FILENAMES
            if generator.sha256(paths[key]) != generator.sha256(reproduced[key])
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

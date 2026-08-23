#!/usr/bin/env python3
"""Grade the V18 baked-radiator shell and its deterministic registration."""

from __future__ import annotations

import json
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

import generate_office_reference_rebuild_v17 as v17
import generate_office_reference_rebuild_v18 as generator
import qa_plate_projection


ROOT = generator.ROOT
STAGE = generator.STAGE


def main() -> int:
    paths = {key: STAGE / name for key, name in generator.FILENAMES.items()}
    required = [generator.SOURCE, *paths.values()]
    missing = [str(path.relative_to(ROOT)) for path in required if not path.exists()]
    if missing:
        print("FAIL missing V18 files: " + ", ".join(missing))
        return 1

    plate = Image.open(paths["plate"]).convert("RGB")
    architecture = np.asarray(Image.open(paths["architectureMask"]).convert("L"))
    rgb = np.asarray(plate)
    metrics = json.loads(paths["metrics"].read_text(encoding="utf-8"))
    checks: list[tuple[str, bool, str]] = []

    checks.append((
        "exact V17 AR0809 envelope retained",
        np.array_equal(
            np.asarray(metrics["registration"]["targetPlanes"]["floor"]),
            np.asarray(v17.TARGET_PLANES["floor"]),
        )
        and np.array_equal(
            np.asarray(metrics["registration"]["targetPlanes"]["NW"]),
            np.asarray(v17.TARGET_PLANES["NW"]),
        )
        and np.array_equal(
            np.asarray(metrics["registration"]["targetPlanes"]["NE"]),
            np.asarray(v17.TARGET_PLANES["NE"]),
        )
        and plate.size == v17.CANVAS,
        f"canvas={plate.size}",
    ))
    outside_nonblack = int(np.count_nonzero(np.max(rgb, axis=2)[architecture == 0]))
    checks.append((
        "pure-black registered exterior",
        outside_nonblack == 0,
        f"nonblackOutside={outside_nonblack}",
    ))
    v18_projection = qa_plate_projection.grade(paths["plate"])
    v17_projection = qa_plate_projection.grade(
        v17.STAGE / v17.FILENAMES["plate"]
    )
    projection_delta = max(
        abs(v18_projection["peak_pos"] - v17_projection["peak_pos"]),
        abs(v18_projection["peak_neg"] - v17_projection["peak_neg"]),
    )
    checks.append((
        "V17 AR0809 directional-depth signature retained",
        projection_delta <= 0.20,
        f"v18={v18_projection['peak_pos']:+.2f}/{v18_projection['peak_neg']:+.2f} "
        f"v17={v17_projection['peak_pos']:+.2f}/{v17_projection['peak_neg']:+.2f} "
        f"delta={projection_delta:.2f}deg",
    ))
    checks.append((
        "fireplace runtime authority retired",
        metrics["fireplace"]["state"] == "removed"
        and all(not value for value in metrics["fireplace"]["collisionAndCoverAuthority"].values())
        and metrics["flameOrEmberPixelsAuthored"] is False,
        f"state={metrics['fireplace']['state']} flame={metrics['flameOrEmberPixelsAuthored']}",
    ))
    radiators = metrics["radiators"]
    checks.append((
        "two radiators are plate pixels",
        radiators["count"] == 2
        and "no runtime texture" in radiators["construction"]
        and "no separate obstacle" in radiators["collision"],
        f"count={radiators['count']} construction={radiators['construction']}",
    ))
    area = json.loads(
        (ROOT / "RainShadow Shared/Resources/Areas/office_suite.area.json").read_text()
    )["area"]
    props = json.loads(
        (ROOT / "ArtSource/Generated/Office/office_props_v01.json").read_text()
    )["props"]
    checks.append((
        "no radiator sprite or fireplace cover remains authored",
        not area.get("wallPolygons")
        and not any("radiator" in prop["id"] for prop in area.get("props", []))
        and not any("radiator" in prop["id"] for prop in props),
        f"areaProps={len(area.get('props', []))} wallPolygons={len(area.get('wallPolygons', []))}",
    ))

    with tempfile.TemporaryDirectory(prefix="rainshadow-v18-reproduce-") as temp_name:
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

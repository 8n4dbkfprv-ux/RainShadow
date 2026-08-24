#!/usr/bin/env python3
"""Allowlisted install of the V1 IE city-ward rebuild.

    python3 ArtSource/Processing/install_city_ward_rebuild_v01.py
    python3 ArtSource/Processing/install_city_ward_rebuild_v01.py --install
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STAGE = ROOT / "ArtSource/Generated/CityDistrict/V2/WardRebuild"
ART = ROOT / "RainShadow Shared/Resources/Art/Areas/CityDistrict/V2"
MAPS = ROOT / "RainShadow Shared/Resources/Art/UI/Map"
AREAS = ROOT / "RainShadow Shared/Resources/Areas"
PROC = ROOT / "ArtSource/Processing"

DISTRICTS = (
    "sable_row",
    "wharf_ladder",
    "riverside",
    "harborpoint_pd",
    "lila_street",
    "civic_records",
)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--install", action="store_true")
    args = ap.parse_args()
    generate = [
        sys.executable,
        str(PROC / "generate_city_ward_rebuild_v01.py"),
        *DISTRICTS,
    ]
    if args.install:
        generate.append("--install")
    subprocess.run(generate, cwd=ROOT, check=True)
    qa = [
        sys.executable,
        str(PROC / "qa_plate_projection.py"),
        "--shipped",
    ]
    result = subprocess.run(qa, cwd=ROOT)
    bundle = subprocess.run(
        [sys.executable, str(PROC / "qa_area_bundle.py")], cwd=ROOT
    )
    metrics = json.loads((STAGE / "rebuild_metrics.json").read_text())
    print(f"rebuild {len(metrics)} districts; projection qa={result.returncode} bundle qa={bundle.returncode}")
    return result.returncode or bundle.returncode


if __name__ == "__main__":
    raise SystemExit(main())

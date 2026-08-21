#!/usr/bin/env python3
"""Preflight and install the BG:EE-locked V08 open-plan office art."""

from __future__ import annotations

import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

import office_layout_plan as layout
import office_room_plan as room

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "ArtSource/Generated/Office/BGEEOpenPlanV08"
SOURCE_PROPS = SOURCE / "Props"
AREA_ART = ROOT / "RainShadow Shared/Resources/Art/Areas/DetectiveOffice"
RUNTIME_PROPS = ROOT / "RainShadow Shared/Resources/Art/Props/Office"
GENERATED_OFFICE = ROOT / "ArtSource/Generated/Office"

PLATE = SOURCE / "office_open_plan_plate_v08.png"
METRICS = SOURCE / "office_open_plan_metrics_v08.json"
DOOR_FAMILY = SOURCE_PROPS / "office_door_family_v08.json"

DOOR_INSTALLS = {
    "office_door_leaf_closed_v08.png": "office_door_leaf.png",
    "office_door_leaf_closed_hover_v08.png": "office_door_leaf_hover.png",
    "office_door_leaf_mid_v08.png": "office_door_leaf_mid.png",
    "office_door_leaf_open_v08.png": "office_door_leaf_open.png",
    "office_door_leaf_open_hover_v08.png": "office_door_leaf_open_hover.png",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def open_state_black_fraction() -> float:
    """Fraction of the displayed open sliver landing on pure-black cutaway."""
    with Image.open(SOURCE_PROPS / "office_door_leaf_open_v08.png") as source:
        factor = 0.175 / room.SUITE_PLATE_SCALE
        door = source.convert("RGBA").resize(
            (round(source.width * factor), round(source.height * factor)),
            Image.Resampling.LANCZOS,
        )
    alpha = np.asarray(door)[:, :, 3]
    ys, xs = np.where(alpha > 16)
    authored_x, authored_y = layout.exterior_leaf_anchor_authored()
    image_y = room.ART_H - authored_y
    left = round(authored_x - door.width * 0.953125)
    top = round(image_y - door.height * (1.0 - 0.83125))
    with Image.open(PLATE) as image:
        plate = np.asarray(image.convert("RGB"))
    underneath = plate[ys + top, xs + left].max(axis=1)
    return float((underneath < 8).mean())


def preflight() -> dict:
    required = [PLATE, METRICS, DOOR_FAMILY]
    required += [SOURCE_PROPS / name for name in DOOR_INSTALLS]
    missing = [str(path.relative_to(ROOT)) for path in required if not path.exists()]
    if missing:
        raise RuntimeError("missing V08 inputs: " + ", ".join(missing))

    with Image.open(PLATE) as image:
        if image.size != (4096, 2304) or image.mode != "RGB":
            raise RuntimeError(f"plate must be 4096x2304 RGB, got {image.size} {image.mode}")

    subprocess.run(
        [
            sys.executable,
            str(ROOT / "ArtSource/Processing/qa_plate_projection.py"),
            str(PLATE),
            "--tolerance",
            "1.5",
        ],
        cwd=ROOT,
        check=True,
    )

    # A 4096 px office plate displayed at 4096*0.395 world units is 2.53 px/unit.
    density = 4096.0 / (4096.0 * 0.395)
    if density < 2.0:
        raise RuntimeError(f"plate density {density:.3f} px/unit is below 2.0")

    family = json.loads(DOOR_FAMILY.read_text())
    if family.get("canvas") != [512, 320]:
        raise RuntimeError("door family canvas is not the registered 512x320 canvas")
    if family.get("anchorFromBottomLeft") != [0.953125, 0.83125]:
        raise RuntimeError("door family hinge registration drifted")

    for source_name in DOOR_INSTALLS:
        with Image.open(SOURCE_PROPS / source_name) as image:
            if image.size != (512, 320) or image.mode != "RGBA":
                raise RuntimeError(
                    f"{source_name} must be 512x320 RGBA, got {image.size} {image.mode}"
                )
            alpha = image.getchannel("A")
            if alpha.getbbox() is None:
                raise RuntimeError(f"{source_name} has no visible silhouette")

    open_bounds = family["states"]["open"]["opaqueBounds"]
    dx = open_bounds[2] - open_bounds[0]
    dy = open_bounds[3] - open_bounds[1]
    diagonal = (dx * dx + dy * dy) ** 0.5
    adult_world_height = 70.3125
    ratio = diagonal * 0.175 / adult_world_height
    if not 1.10 <= ratio <= 1.30:
        raise RuntimeError(f"open leaf/adult ratio {ratio:.3f} outside 1.10-1.30")

    metrics = json.loads(METRICS.read_text())
    if metrics["door"]["edge"] != "camera-near-right/b=1":
        raise RuntimeError("sole entrance is not registered on the near-right cutaway")

    black_fraction = open_state_black_fraction()
    if black_fraction < 0.55:
        raise RuntimeError(
            f"open edge silhouette has only {black_fraction:.1%} over black; expected >=55%"
        )

    return {
        "plateDensityPixelsPerWorldUnit": density,
        "openLeafToAdultRatio": ratio,
        "openLeafBlackSilhouetteFraction": black_fraction,
        "inputs": {
            str(path.relative_to(ROOT)): sha256(path)
            for path in required
        },
    }


def main() -> None:
    provenance = preflight()

    plate_targets = [
        AREA_ART / "office_suite_plate.png",
        AREA_ART / "office_shell_base.png",
        GENERATED_OFFICE / "office_suite_plate.png",
        GENERATED_OFFICE / "office_shell_base.png",
        GENERATED_OFFICE / "office_suite_plate_bgee_v08_installed.png",
    ]
    for target in plate_targets:
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(PLATE, target)

    for source_name, target_name in DOOR_INSTALLS.items():
        target = RUNTIME_PROPS / target_name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(SOURCE_PROPS / source_name, target)

    provenance["installed"] = {
        "plateTargets": [str(path.relative_to(ROOT)) for path in plate_targets],
        "doorTargets": [
            str((RUNTIME_PROPS / target).relative_to(ROOT))
            for target in DOOR_INSTALLS.values()
        ],
    }
    out = SOURCE / "office_open_plan_install_v08.json"
    out.write_text(json.dumps(provenance, indent=2, sort_keys=True) + "\n")
    print(f"preflight passed; installed {len(plate_targets)} plate copies")
    print(f"installed {len(DOOR_INSTALLS)} registered door-state textures")
    print(f"wrote {out.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

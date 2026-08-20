#!/usr/bin/env python3
"""Preflight and atomically install the BG:EE-locked V10 tavern office."""

from __future__ import annotations

import hashlib
import argparse
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
SOURCE = ROOT / "ArtSource/Generated/Office/BGEETavernV10"
SOURCE_PROPS = SOURCE / "Props"
AREA_ART = ROOT / "RainShadow Shared/Resources/Art/Areas/DetectiveOffice"
RUNTIME_PROPS = ROOT / "RainShadow Shared/Resources/Art/Props/Office"
GENERATED_OFFICE = ROOT / "ArtSource/Generated/Office"

PLATE = SOURCE / "office_tavern_plate_v10.png"
MASK = SOURCE / "office_tavern_architecture_mask_v10.png"
METRICS = SOURCE / "office_tavern_metrics_v10.json"
GEOMETRY = SOURCE / "office_v10_geometry.json"
DOOR_FAMILY = SOURCE_PROPS / "office_door_family_v10.json"

DOOR_INSTALLS = {
    "office_door_leaf_closed_v10.png": "office_door_leaf.png",
    "office_door_leaf_closed_hover_v10.png": "office_door_leaf_hover.png",
    "office_door_leaf_mid_v10.png": "office_door_leaf_mid.png",
    "office_door_leaf_open_v10.png": "office_door_leaf_open.png",
    "office_door_leaf_open_hover_v10.png": "office_door_leaf_open_hover.png",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def open_state_black_fraction() -> float:
    with Image.open(SOURCE_PROPS / "office_door_leaf_open_v10.png") as source:
        factor = 0.175 / room.ENVIRONMENT_SCALE
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
    required = [PLATE, MASK, METRICS, GEOMETRY, DOOR_FAMILY]
    required += [SOURCE_PROPS / name for name in DOOR_INSTALLS]
    missing = [str(path.relative_to(ROOT)) for path in required if not path.exists()]
    if missing:
        raise RuntimeError("missing V10 inputs: " + ", ".join(missing))

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

    density = 4096.0 / (4096.0 * 0.395)
    if density < 2.53:
        raise RuntimeError(f"plate density {density:.3f} px/unit is below 2.53")

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

    for state in ("closed", "open"):
        base = np.asarray(Image.open(SOURCE_PROPS / f"office_door_leaf_{state}_v10.png"))
        hover = np.asarray(Image.open(SOURCE_PROPS / f"office_door_leaf_{state}_hover_v10.png"))
        if not np.array_equal(base[:, :, 3], hover[:, :, 3]):
            raise RuntimeError(f"{state} hover alpha/geometry drifted")

    open_bounds = family["states"]["open"]["opaqueBounds"]
    dx = open_bounds[2] - open_bounds[0]
    dy = open_bounds[3] - open_bounds[1]
    diagonal = (dx * dx + dy * dy) ** 0.5
    adult_world_height = 70.3125
    ratio = diagonal * 0.175 / adult_world_height
    if not 1.10 <= ratio <= 1.30:
        raise RuntimeError(f"open leaf/adult ratio {ratio:.3f} outside 1.10-1.30")

    metrics = json.loads(METRICS.read_text())
    geometry = json.loads(GEOMETRY.read_text())
    if metrics.get("geometryManifest") != GEOMETRY.name:
        raise RuntimeError("candidate does not name the V10 geometry manifest")
    if geometry["door"]["openingPixels"] != metrics["door"]["openingPixels"]:
        raise RuntimeError("baked aperture and navigation manifest disagree")
    if geometry["door"]["openingPixels"] != [125.0, 198.0]:
        raise RuntimeError("door opening was enlarged past the close-up lock")
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


def _atomic_copy(source: Path, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_name(target.name + ".v10-installing")
    shutil.copy2(source, temporary)
    temporary.replace(target)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--install", action="store_true", help="replace runtime aliases")
    args = parser.parse_args()
    provenance = preflight()

    if not args.install:
        print("V10 preflight passed; no runtime files changed (use --install)")
        return

    plate_targets = [
        AREA_ART / "office_suite_plate.png",
        AREA_ART / "office_shell_base.png",
        GENERATED_OFFICE / "office_suite_plate.png",
        GENERATED_OFFICE / "office_shell_base.png",
        GENERATED_OFFICE / "office_suite_plate_bgee_v10_installed.png",
    ]
    for target in plate_targets:
        _atomic_copy(PLATE, target)

    for source_name, target_name in DOOR_INSTALLS.items():
        target = RUNTIME_PROPS / target_name
        _atomic_copy(SOURCE_PROPS / source_name, target)

    provenance["installed"] = {
        "plateTargets": [str(path.relative_to(ROOT)) for path in plate_targets],
        "doorTargets": [
            str((RUNTIME_PROPS / target).relative_to(ROOT))
            for target in DOOR_INSTALLS.values()
        ],
    }
    out = SOURCE / "office_tavern_install_v10.json"
    out.write_text(json.dumps(provenance, indent=2, sort_keys=True) + "\n")
    print(f"preflight passed; installed {len(plate_targets)} plate copies")
    print(f"installed {len(DOOR_INSTALLS)} registered door-state textures")
    print(f"wrote {out.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

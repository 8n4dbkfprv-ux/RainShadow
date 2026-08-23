#!/usr/bin/env python3
"""Register the V18 radiator edit on the exact V17 AR0809 room envelope.

ImageGen owns the repaired brick/floor pixels and the two period radiators.
V17 continues to own the accepted plane control points, so this revision cannot
move the room, windows, camera or black-canvas framing.
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

import generate_office_reference_rebuild_v17 as base


ROOT = base.ROOT
STAGE = ROOT / "ArtSource/Generated/Office/BGEEReferenceV18"
SOURCE = STAGE / "office_room_envelope_imagegen_raw_v18.png"
FILENAMES = {
    "plate": "office_reference_rebuild_plate_v18.png",
    "architectureMask": "office_reference_rebuild_architecture_mask_v18.png",
    "glassMask": "office_window_glass_mask_v18.png",
    "nearHover": "office_window_near_hover_overlay_v18.png",
    "metrics": "office_reference_rebuild_metrics_v18.json",
}

# The precise edit preserved V17's planes but its returned canvas trimmed two
# border pixels: the crown moved down/right by one pixel and the near floor tip
# moved up by one. These are measured non-black silhouette vertices in the V18
# source, not new target geometry.
SOURCE_CROWN = (851.0, 113.0)
SOURCE_FLOOR = (
    (852.0, 239.0),
    (207.0, 581.0),
    (700.0, 920.0),
    (1325.0, 433.0),
)


def _configure_registration() -> None:
    base.SOURCE = SOURCE
    base.SOURCE_CROWN = SOURCE_CROWN
    base.SOURCE_FLOOR = SOURCE_FLOOR
    base.SOURCE_PLANES = {
        "NW": [SOURCE_CROWN, SOURCE_FLOOR[1], SOURCE_FLOOR[1], SOURCE_FLOOR[0]],
        "NE": [SOURCE_CROWN, SOURCE_FLOOR[3], SOURCE_FLOOR[3], SOURCE_FLOOR[0]],
        "floor": list(SOURCE_FLOOR),
    }
    base.NW_FORWARD = base._affine_forward(
        (SOURCE_CROWN, SOURCE_FLOOR[1], SOURCE_FLOOR[0]),
        (base.TARGET_CROWN, base.TARGET_FLOOR[1], base.TARGET_FLOOR[0]),
    )
    base.NE_FORWARD = base._affine_forward(
        (SOURCE_CROWN, SOURCE_FLOOR[0], SOURCE_FLOOR[3]),
        (base.TARGET_CROWN, base.TARGET_FLOOR[0], base.TARGET_FLOOR[3]),
    )
    base.FLOOR_FORWARD = base._homography_forward(SOURCE_FLOOR, base.TARGET_FLOOR)


def build_assets() -> dict[str, Image.Image | dict[str, object]]:
    # The edit retained V17's exact accepted control points. Reuse the locked
    # three-plane registration rather than re-measuring and introducing drift.
    _configure_registration()
    assets = base.build_assets()
    metrics = assets["metrics"]
    assert isinstance(metrics, dict)
    metrics["version"] = "BGEEReferenceV18"
    metrics["source"]["file"] = SOURCE.name
    metrics["source"]["role"] = (
        "built-in ImageGen repaired architecture and baked radiator authority"
    )
    metrics["fireplace"] = {
        "state": "removed",
        "collisionAndCoverAuthority": {
            "targetFloorFootprint": [],
            "targetObstaclePolygon": [],
            "targetWallPolygon": [],
            "targetCoverPolygon": [],
            "targetHearthSpillSample": [],
        },
    }
    metrics["radiators"] = {
        "period": "1950s",
        "count": 2,
        "construction": "painted into the architecture plate; no runtime texture",
        "placement": "low on the long NW wall, flanking the two existing windows",
        "collision": "covered by the existing wall boundary; no separate obstacle",
    }
    metrics["imageGeneration"] = {
        "tool": "built-in image_gen.imagegen",
        "useCase": "precise-object-edit",
        "rawSource": str(SOURCE.relative_to(ROOT)),
        "rawSourceSha256": base.sha256(SOURCE),
        "invariants": "V17 AR0809 planes, windows, sconces and black exterior",
    }
    metrics["flameOrEmberPixelsAuthored"] = False
    return assets


def write_assets(output_dir: Path = STAGE) -> dict[str, Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    assets = build_assets()
    paths: dict[str, Path] = {}
    for key in ("plate", "architectureMask", "glassMask", "nearHover"):
        image = assets[key]
        assert isinstance(image, Image.Image)
        path = output_dir / FILENAMES[key]
        image.save(path, format="PNG", optimize=False)
        paths[key] = path
    metrics = assets["metrics"]
    assert isinstance(metrics, dict)
    metrics_path = output_dir / FILENAMES["metrics"]
    metrics_path.write_text(json.dumps(metrics, indent=2, sort_keys=True) + "\n")
    paths["metrics"] = metrics_path
    return paths


def main() -> None:
    paths = write_assets()
    for path in paths.values():
        print(f"wrote {path.relative_to(ROOT)}")
    print("fireplace=removed radiators=2 baked=True")


if __name__ == "__main__":
    main()

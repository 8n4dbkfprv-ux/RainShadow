#!/usr/bin/env python3
"""Register the AR0809-shaped ImageGen office as the V15 area shell.

The ImageGen source owns every visible pixel.  This stage applies one uniform
scale and translation, keeps the painted tapered silhouette, and emits
interaction masks plus geometry metrics.  In particular, it does not restore
the rectangular wall end-caps retired by the AR0809 point-cutaway silhouette.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage


ROOT = Path(__file__).resolve().parents[2]
STAGE = ROOT / "ArtSource/Generated/Office/BGEEReferenceV15"
SOURCE = STAGE / "office_room_envelope_imagegen_raw_v15.png"
REFERENCE = ROOT / "ArtSource/Reference/Office/V15/AR0809_geometry_reference.png"

FILENAMES = {
    "plate": "office_reference_rebuild_plate_v15.png",
    "architectureMask": "office_reference_rebuild_architecture_mask_v15.png",
    "glassMask": "office_window_glass_mask_v15.png",
    "nearHover": "office_window_near_hover_overlay_v15.png",
    "metrics": "office_reference_rebuild_metrics_v15.json",
}

SOURCE_SIZE = (1536, 1024)
CANVAS = (4096, 2304)
SCALE = 2.0
TRANSLATE = (512.0, 90.0)
ENVIRONMENT_SCALE = 0.395

# Painted walls keep AR0809's point-cutaway silhouette. The floor used for
# navigation is a ±0.75 parallelogram inscribed in that paint — the outer
# tips are a cutaway treatment, not the ground camera.
SOURCE_PLANES = {
    "NW": [[893.0, 81.0], [222.0, 604.0], [222.0, 605.0], [893.0, 227.0]],
    "NE": [[893.0, 81.0], [1312.0, 406.0], [1312.0, 411.0], [893.0, 227.0]],
    "floor": [[893.0, 227.0], [222.0, 605.0], [745.0, 961.0], [1312.0, 411.0]],
}


def _bilinear_point(polygon: list[list[float]], u: float, v: float) -> list[float]:
    tl, tr, br, bl = (np.asarray(point, dtype=np.float64) for point in polygon)
    point = (
        (1.0 - u) * (1.0 - v) * tl
        + u * (1.0 - v) * tr
        + u * v * br
        + (1.0 - u) * v * bl
    )
    return [float(point[0]), float(point[1])]


def _window(identifier: str, aperture: list[list[float]]) -> dict[str, object]:
    panes = []
    for left, right in ((0.08, 0.46), (0.54, 0.92)):
        for top, bottom in ((0.05, 0.30), (0.36, 0.62), (0.68, 0.95)):
            panes.append([
                _bilinear_point(aperture, left, top),
                _bilinear_point(aperture, right, top),
                _bilinear_point(aperture, right, bottom),
                _bilinear_point(aperture, left, bottom),
            ])
    return {"id": identifier, "aperture": aperture, "glass": panes}


SOURCE_WINDOWS = [
    _window("far", [[560.0, 318.0], [598.0, 290.0], [598.0, 350.0], [560.0, 378.0]]),
    _window("near", [[448.0, 428.0], [486.0, 400.0], [486.0, 460.0], [448.0, 488.0]]),
]

SOURCE_FIREPLACE_FLOOR_FOOTPRINT = [
    [1073.0, 362.0], [1213.0, 467.0], [1181.0, 491.0], [1041.0, 386.0]
]
SOURCE_FIREPLACE_COVER = [
    [1070.0, 290.0], [1210.0, 395.0], [1210.0, 428.0], [1070.0, 323.0]
]
SOURCE_HEARTH_SPILL_SAMPLE = [
    [1035.0, 365.0], [1230.0, 460.0], [1185.0, 500.0], [990.0, 405.0]
]
SOURCE_FIREPLACE_UPRIGHT_HEIGHT = 143.0


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def transform_point(point: list[float]) -> list[float]:
    return [
        point[0] * SCALE + TRANSLATE[0],
        point[1] * SCALE + TRANSLATE[1],
    ]


def transform_polygon(polygon: list[list[float]]) -> list[list[float]]:
    return [transform_point(point) for point in polygon]


def transformed_windows() -> list[dict[str, object]]:
    return [
        {
            "id": window["id"],
            "aperture": transform_polygon(window["aperture"]),
            "glass": [transform_polygon(pane) for pane in window["glass"]],
        }
        for window in SOURCE_WINDOWS
    ]


def _room_mask(planes: dict[str, list[list[float]]]) -> Image.Image:
    mask = Image.new("L", CANVAS, 0)
    draw = ImageDraw.Draw(mask)
    for polygon in planes.values():
        draw.polygon([tuple(point) for point in polygon], fill=255)
    return mask


def _registered_source_silhouette(source: Image.Image) -> Image.Image:
    """Keep the complete connected painted shell, including fixture overhangs."""
    pixels = np.asarray(source, dtype=np.uint8)
    foreground = np.max(pixels, axis=2) > 8
    labels, count = ndimage.label(foreground)
    if count == 0:
        raise RuntimeError("V15 ImageGen source has no connected room silhouette")
    areas = np.bincount(labels.ravel())
    areas[0] = 0
    room = ndimage.binary_fill_holes(labels == int(np.argmax(areas)))
    source_mask = Image.fromarray(room.astype(np.uint8) * 255, "L")
    resized = source_mask.resize(
        (round(source.width * SCALE), round(source.height * SCALE)),
        Image.Resampling.LANCZOS,
    )
    registered = Image.new("L", CANVAS, 0)
    registered.paste(resized, (round(TRANSLATE[0]), round(TRANSLATE[1])))
    return registered


def _glass_mask(windows: list[dict[str, object]]) -> Image.Image:
    image = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image, "RGBA")
    for window in windows:
        for pane in window["glass"]:
            draw.polygon([tuple(point) for point in pane], fill=(115, 155, 175, 126))
    return image


def _near_hover(windows: list[dict[str, object]]) -> Image.Image:
    image = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image, "RGBA")
    near = next(window for window in windows if window["id"] == "near")
    polygon = [tuple(point) for point in near["aperture"]]
    draw.polygon(polygon, fill=(24, 172, 184, 34))
    draw.line(polygon + [polygon[0]], fill=(43, 231, 238, 164), width=6, joint="curve")
    return image


def build_assets() -> dict[str, Image.Image | dict[str, object]]:
    source = Image.open(SOURCE).convert("RGB")
    if source.size != SOURCE_SIZE:
        raise RuntimeError(f"unexpected V15 ImageGen source size: {source.size}")

    resized = source.resize(
        (round(source.width * SCALE), round(source.height * SCALE)),
        Image.Resampling.LANCZOS,
    )
    registered = Image.new("RGB", CANVAS, (0, 0, 0))
    registered.paste(resized, (round(TRANSLATE[0]), round(TRANSLATE[1])))

    planes = {key: transform_polygon(value) for key, value in SOURCE_PLANES.items()}
    architecture = _registered_source_silhouette(source)
    plate = Image.composite(registered, Image.new("RGB", CANVAS, (0, 0, 0)), architecture)
    windows = transformed_windows()

    long_axis = np.asarray(SOURCE_PLANES["floor"][1]) - np.asarray(SOURCE_PLANES["floor"][0])
    short_axis = np.asarray(SOURCE_PLANES["floor"][3]) - np.asarray(SOURCE_PLANES["floor"][0])
    wall_rear_height = SOURCE_PLANES["NW"][3][1] - SOURCE_PLANES["NW"][0][1]
    wall_left_height = SOURCE_PLANES["NW"][2][1] - SOURCE_PLANES["NW"][1][1]
    wall_right_height = SOURCE_PLANES["NE"][2][1] - SOURCE_PLANES["NE"][1][1]

    fixture_height = SOURCE_FIREPLACE_UPRIGHT_HEIGHT * SCALE
    metrics: dict[str, object] = {
        "version": "BGEEReferenceV15",
        "canvas": list(CANVAS),
        "environmentScale": ENVIRONMENT_SCALE,
        "geometryAuthority": "AR0809 outer silhouette and V15 ImageGen tapered-wall redraw",
        "source": {
            "file": SOURCE.name,
            "size": list(source.size),
            "sha256": sha256(SOURCE),
            "role": "ImageGen visual, material, lighting, fixture and room-envelope authority",
        },
        "targetReference": {
            "file": str(REFERENCE),
            "sha256": sha256(REFERENCE),
            "role": "user-supplied floor proportion and tapered wall-cutaway authority",
        },
        "registration": {
            "sourcePlanes": SOURCE_PLANES,
            "targetPlanes": planes,
            "uniformScale": SCALE,
            "uniformTranslation": list(TRANSLATE),
            "longShortGroundAxisRatio": float(np.linalg.norm(long_axis) / np.linalg.norm(short_axis)),
            "wallRearHeightSourcePixels": wall_rear_height,
            "wallLeftTipHeightSourcePixels": wall_left_height,
            "wallRightTipHeightSourcePixels": wall_right_height,
            "visualSilhouetteAuthority": "V15 tapered ImageGen shell",
            "navigationGeometryAuthority": "V15 targetPlanes",
            "anisotropicWholePlateResize": False,
        },
        "windows": windows,
        "walls": {
            "visualScaleLock": {
                "sourceRearHeightPixels": wall_rear_height,
                "plateRearHeightPixels": wall_rear_height * SCALE,
                "standingAdultWorldHeight": 70.3125,
                "worldRearHeight": wall_rear_height * SCALE * ENVIRONMENT_SCALE,
                "wallToAdultRatio": wall_rear_height * SCALE * ENVIRONMENT_SCALE / 70.3125,
            }
        },
        "fireplace": {
            "state": "lit",
            "collisionAndCoverAuthority": {
                "targetFloorFootprint": transform_polygon(SOURCE_FIREPLACE_FLOOR_FOOTPRINT),
                "targetObstaclePolygon": transform_polygon(SOURCE_FIREPLACE_FLOOR_FOOTPRINT),
                "targetCoverPolygon": transform_polygon(SOURCE_FIREPLACE_COVER),
                "targetHearthSpillSample": transform_polygon(SOURCE_HEARTH_SPILL_SAMPLE),
            },
            "visualScaleLock": {
                "sourceUprightHeightPixels": SOURCE_FIREPLACE_UPRIGHT_HEIGHT,
                "plateFixtureHeightPixels": fixture_height,
                "standingAdultWorldHeight": 70.3125,
                "worldFixtureHeight": fixture_height * ENVIRONMENT_SCALE,
                "fireplaceToAdultRatio": fixture_height * ENVIRONMENT_SCALE / 70.3125,
            },
        },
        "imageGeneration": {
            "tool": "built-in image_gen.imagegen",
            "rawSource": str(SOURCE.relative_to(ROOT)),
            "rawSourceSha256": sha256(SOURCE),
            "geometryReference": str(REFERENCE),
            "geometryReferenceSha256": sha256(REFERENCE),
            "role": "ImageGen supplies all visible art; deterministic processing applies only one uniform scale and translation",
        },
        "doorPixelsBakedIntoPlate": False,
        "flameOrEmberPixelsAuthored": True,
    }
    return {
        "plate": plate,
        "architectureMask": architecture,
        "glassMask": _glass_mask(windows),
        "nearHover": _near_hover(windows),
        "metrics": metrics,
    }


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
    metrics["outputHashes"] = {path.name: sha256(path) for path in paths.values()}
    metrics_path = output_dir / FILENAMES["metrics"]
    metrics_path.write_text(json.dumps(metrics, indent=2) + "\n", encoding="utf-8")
    paths["metrics"] = metrics_path
    return paths


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, default=STAGE)
    args = parser.parse_args()
    for path in write_assets(args.output_dir.resolve()).values():
        print(f"wrote {path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

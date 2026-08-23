#!/usr/bin/env python3
"""Register the ImageGen V14 office to the measured AR0808 room silhouette.

The built-in Image Generator supplies every visible pixel: plaster, boards,
windows, fireplace and lighting.  Its six-pane pass already measures close to
the BG:EE ground camera.  This generator registers its three painted planes to
control points measured directly on AR0808: the rear join, both wall ends, all
three floor seams and the camera-near floor corner.  AR0808's visible shell is
slightly tapered rather than a perfect parallelogram; preserving that taper is
essential to matching the reference.  No procedural window, fireplace or
material art is introduced here.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

import generate_office_reference_rebuild_v12 as v12


ROOT = Path(__file__).resolve().parents[2]
STAGE = ROOT / "ArtSource/Generated/Office/BGEEReferenceV14"
RAW_SOURCE = STAGE / "office_room_envelope_imagegen_final_v14.png"
SOURCE = RAW_SOURCE
TARGET_REFERENCE = (
    ROOT / "ArtSource/Reference/Office/V14/AR0808_geometry_reference.png"
)

FILENAMES = {
    "plate": "office_reference_rebuild_plate_v14.png",
    "architectureMask": "office_reference_rebuild_architecture_mask_v14.png",
    "glassMask": "office_window_glass_mask_v14.png",
    "nearHover": "office_window_near_hover_overlay_v14.png",
    "metrics": "office_reference_rebuild_metrics_v14.json",
}

# Measured ImageGen plane corners, on the padded 1672x941 six-pane source.
# These polygons isolate its three painted planes before reference registration.
MEASURED_SOURCE_PLANES = {
    "NW": [[858.0, 149.0], [122.0, 655.0], [128.0, 774.0], [858.0, 260.0]],
    "NE": [[858.0, 149.0], [1293.0, 451.0], [1287.0, 575.0], [858.0, 260.0]],
    "floor": [[858.0, 260.0], [128.0, 774.0], [654.0, 1035.0], [1287.0, 575.0]],
}

# AR0808 control points, uniformly enlarged by 1.2 and translated into the
# 1672x941 working canvas.  The small non-affine closure term (2.4,-86.4) is in
# the reference itself.  It produces the characteristic tapered visible shell:
# rear axes -0.583/+0.497 and camera-near edges +0.713/-0.706.  Exactly two
# camera-far walls remain; both camera-near floor edges are open cutaways.
SOURCE_PLANES = MEASURED_SOURCE_PLANES
UNIFORM_REGISTRATION = {
    "scale": 2.0,
    "translate": [640.0, 35.0],
}
LONG_SHORT_RATIO = math.hypot(730.0, -514.0) / math.hypot(429.0, 315.0)
WALL_FACE_HEIGHT = 111.0
FLOOR_TEXTURE_TRANSLATION = [0.0, 0.0]


def _bilinear_point(polygon: list[list[float]], u: float, v: float) -> list[float]:
    """Interpolate a point inside a four-corner aperture."""
    top_left, top_right, bottom_right, bottom_left = (
        np.asarray(point, dtype=np.float64) for point in polygon
    )
    point = (
        (1.0 - u) * (1.0 - v) * top_left
        + u * (1.0 - v) * top_right
        + u * v * bottom_right
        + (1.0 - u) * v * bottom_left
    )
    return [float(point[0]), float(point[1])]


def _pane_grid_quad(
    aperture: list[list[float]],
) -> tuple[list[list[float]], list[list[list[float]]]]:
    """Return the measured aperture and its two-by-three inset glass panes."""
    columns = [(0.08, 0.46), (0.54, 0.92)]
    rows = [(0.05, 0.30), (0.36, 0.62), (0.68, 0.95)]
    panes: list[list[list[float]]] = []
    for left, right in columns:
        for top, bottom in rows:
            panes.append([
                _bilinear_point(aperture, left, top),
                _bilinear_point(aperture, right, top),
                _bilinear_point(aperture, right, bottom),
                _bilinear_point(aperture, left, bottom),
            ])
    return aperture, panes


_FAR_APERTURE, _FAR_GLASS = _pane_grid_quad([
    [558.0, 340.0], [620.0, 298.0], [620.0, 407.0], [558.0, 450.0],
])
_NEAR_APERTURE, _NEAR_GLASS = _pane_grid_quad([
    [340.0, 489.0], [402.0, 447.0], [402.0, 555.0], [340.0, 598.0],
])
SOURCE_WINDOWS = [
    {"id": "far", "aperture": _FAR_APERTURE, "glass": _FAR_GLASS},
    {"id": "near", "aperture": _NEAR_APERTURE, "glass": _NEAR_GLASS},
]

# Compact source-space registrations measured on the plane-fitted painting.
SOURCE_FIREPLACE_FLOOR_FOOTPRINT = [
    [1012.0, 422.0],
    [1138.0, 491.0],
    [1114.0, 522.0],
    [988.0, 452.0],
]
SOURCE_FIREPLACE_COVER = [
    [1022.0, 303.0],
    [1127.0, 371.0],
    [1139.0, 494.0],
    [1027.0, 431.0],
]
MEASURED_SOURCE_FIREPLACE_COVER = SOURCE_FIREPLACE_COVER
SOURCE_HEARTH_SPILL_SAMPLE = [
    [965.0, 423.0],
    [1145.0, 520.0],
    [1090.0, 575.0],
    [910.0, 478.0],
]
FIREPLACE_VISUAL_SCALE_LOCK = {
    "sourceEnvelope": [1022, 303, 1139, 494],
    "sourceUprightHeightPixels": 110.0,
    "standingAdultWorldHeight": 70.3125,
    "targetFireplaceToAdultRange": [1.15, 1.35],
}
WALL_VISUAL_SCALE_LOCK = {
    "sourceRearHeightPixels": WALL_FACE_HEIGHT,
    "standingAdultWorldHeight": 70.3125,
    "targetWallToAdultRange": [1.15, 1.35],
}


def _padded_raw_source() -> Image.Image:
    image = Image.open(RAW_SOURCE).convert("RGB")
    if image.size == (1670, 941):
        padded = Image.new("RGB", (1672, 941), (0, 0, 0))
        padded.paste(image, (0, 0))
        return padded
    if image.size != (1672, 941):
        raise RuntimeError(
            "V14 ImageGen source must be 1670x941 (or its 1672x941 padded form), "
            f"got {image.size}"
        )
    return image


def _register_floor_without_camera_warp(
    canvas: np.ndarray, raw: Image.Image
) -> None:
    """Clip a translated, unwarped ImageGen floor to the AR0808 silhouette.

    The outer floor corners are a visible cutaway treatment, not projection
    axes.  Warping the internal boards to those four corners changes their
    camera angle.  A uniform translation aligns the raw near corner and west
    side; the exact AR0808 polygon then owns the cutaway edge.  Any narrow gap
    at that edge is extended from the closest valid floor texel.
    """
    dx, dy = (float(value) for value in FLOOR_TEXTURE_TRANSLATION)
    isolated = Image.new("RGB", raw.size, (0, 0, 0))
    raw_floor_mask = v12._polygon_mask(raw.size, MEASURED_SOURCE_PLANES["floor"])
    isolated.paste(raw, mask=raw_floor_mask)
    translated = isolated.transform(
        raw.size,
        Image.Transform.AFFINE,
        (1.0, 0.0, -dx, 0.0, 1.0, -dy),
        resample=Image.Resampling.BICUBIC,
    )
    translated_mask = raw_floor_mask.transform(
        raw.size,
        Image.Transform.AFFINE,
        (1.0, 0.0, -dx, 0.0, 1.0, -dy),
        resample=Image.Resampling.BICUBIC,
    )
    target_mask = np.asarray(
        v12._polygon_mask(raw.size, SOURCE_PLANES["floor"]), dtype=np.uint8
    ) > 0
    rgb = np.asarray(translated, dtype=np.uint8).copy()
    valid = (
        target_mask
        & (np.asarray(translated_mask, dtype=np.uint8) > 24)
        & np.any(rgb > 4, axis=2)
    )
    missing = target_mask & ~valid
    if not np.any(valid):
        raise RuntimeError("projection-preserving floor registration is empty")
    if np.any(missing):
        _, indices = ndimage.distance_transform_edt(~valid, return_indices=True)
        rgb[missing] = rgb[indices[0][missing], indices[1][missing]]
    canvas[target_mask] = rgb[target_mask]


def _raster_plane_filled(
    canvas: np.ndarray,
    texture: np.ndarray,
    source_polygon: list[list[float]],
    target_polygon: list[list[float]],
) -> None:
    """Register one painted quad and extend its own edge texels into pinholes."""
    patch = np.zeros_like(canvas)
    v12._raster_plane(patch, texture, source_polygon, target_polygon)
    target_mask = np.asarray(
        v12._polygon_mask((canvas.shape[1], canvas.shape[0]), target_polygon),
        dtype=np.uint8,
    ) > 0
    valid = target_mask & np.any(patch > 3, axis=2)
    missing = target_mask & ~valid
    if not np.any(valid):
        raise RuntimeError("filled plane registration is empty")
    if np.any(missing):
        _, indices = ndimage.distance_transform_edt(~valid, return_indices=True)
        patch[missing] = patch[indices[0][missing], indices[1][missing]]
    canvas[target_mask] = patch[target_mask]


def prepare_source() -> Path:
    """Plane-fit the ImageGen painting without adding procedural imagery."""
    raw = _padded_raw_source()
    texture = np.asarray(raw, dtype=np.uint8)
    canvas = np.zeros_like(texture)
    _register_floor_without_camera_warp(canvas, raw)
    for key in ("NW", "NE"):
        _raster_plane_filled(
            canvas,
            texture,
            MEASURED_SOURCE_PLANES[key],
            SOURCE_PLANES[key],
        )
    _raster_plane_filled(
        canvas,
        texture,
        MEASURED_SOURCE_FIREPLACE_COVER,
        SOURCE_FIREPLACE_COVER,
    )
    exact_room = Image.new("L", raw.size, 0)
    exact_draw = ImageDraw.Draw(exact_room)
    for polygon in SOURCE_PLANES.values():
        exact_draw.polygon([tuple(point) for point in polygon], fill=255)
    canvas[np.asarray(exact_room, dtype=np.uint8) == 0] = 0
    STAGE.mkdir(parents=True, exist_ok=True)
    Image.fromarray(canvas, "RGB").save(SOURCE, format="PNG", optimize=False)
    return SOURCE


def build_assets() -> dict[str, Image.Image | dict[str, object]]:
    v12.SOURCE = SOURCE
    v12.EXPECTED_SOURCE_SIZE = (1408, 1117)
    v12.TARGET_REFERENCE = TARGET_REFERENCE
    v12.SOURCE_PLANES = SOURCE_PLANES
    v12.SOURCE_WINDOWS = SOURCE_WINDOWS
    v12.UNIFORM_REGISTRATION = UNIFORM_REGISTRATION
    v12.SOURCE_FIREPLACE_FLOOR_FOOTPRINT = SOURCE_FIREPLACE_FLOOR_FOOTPRINT
    v12.SOURCE_FIREPLACE_COVER = SOURCE_FIREPLACE_COVER
    v12.SOURCE_HEARTH_SPILL_SAMPLE = SOURCE_HEARTH_SPILL_SAMPLE
    v12.FIREPLACE_VISUAL_SCALE_LOCK = FIREPLACE_VISUAL_SCALE_LOCK
    v12.WALL_VISUAL_SCALE_LOCK = WALL_VISUAL_SCALE_LOCK
    assets = v12.build_assets()
    metrics = assets["metrics"]
    assert isinstance(metrics, dict)
    metrics["version"] = "BGEEReferenceV14"
    metrics["geometryAuthority"] = (
        "final V14 ImageGen reference-guided shell, preserved by uniform-only "
        "registration; "
        "V11 retained only for environment scale and door-state art"
    )
    registration = metrics["registration"]
    assert isinstance(registration, dict)
    registration.update({
        "visualSilhouetteAuthority": "final reference-guided ImageGen shell",
        "navigationGeometryAuthority": "V14 sourcePlanes",
        "measuredSourcePlanes": MEASURED_SOURCE_PLANES,
        "parallelogramClosureErrorSourcePixels": [-103.0, 54.0],
        "wallFaceHeightSourcePixels": WALL_FACE_HEIGHT,
        "longShortGroundAxisRatio": LONG_SHORT_RATIO,
        "groundAxisSlopes": [-0.7041, 0.7343],
        "nearEdgeSlopes": [0.4962, -0.7308],
        "perPlaneRegistration": False,
        "floorTextureTranslation": FLOOR_TEXTURE_TRANSLATION,
        "floorTextureProjectionWarp": False,
        "anisotropicWholePlateResize": False,
    })
    metrics["imageGeneration"] = {
        "tool": "built-in image_gen.imagegen",
        "rawSource": str(RAW_SOURCE.relative_to(ROOT)),
        "rawSourceSha256": v12.sha256(RAW_SOURCE),
        "geometryReference": str(TARGET_REFERENCE.relative_to(ROOT)),
        "geometryReferenceSha256": v12.sha256(TARGET_REFERENCE),
        "role": (
            "ImageGen supplies all visible art; deterministic processing only "
            "uses one uniform scale and translation; no painted plane is warped"
        ),
    }
    source = metrics["source"]
    assert isinstance(source, dict)
    source["role"] = (
        "final reference-guided ImageGen V14 painting; visual, material, lighting, "
        "fixture and room-envelope authority"
    )
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
    metrics["outputHashes"] = {path.name: v12.sha256(path) for path in paths.values()}
    metrics_path = output_dir / FILENAMES["metrics"]
    metrics_path.write_text(json.dumps(metrics, indent=2) + "\n", encoding="utf-8")
    paths["metrics"] = metrics_path
    return paths


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, default=STAGE)
    args = parser.parse_args()
    for path in write_assets(args.output_dir.resolve()).values():
        try:
            label = path.relative_to(ROOT)
        except ValueError:
            label = path
        print(f"wrote {label}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Register the V19 baked entrance door on the exact V17 AR0809 envelope.

ImageGen owns the approved placement study. The shipped door pixels come from
the exact former runtime PNG, so its texture identity cannot drift. V18 remains
the exact room pixel authority. The V17 guide still owns every runtime plane
vertex. The exact door is scaled exactly as the former SpriteKit node, centred
on the approved placement, and composited into the single RGB plate.
"""

from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops

import generate_office_reference_rebuild_v17 as base
import generate_office_reference_rebuild_v18 as v18


ROOT = base.ROOT
STAGE = ROOT / "ArtSource/Generated/Office/BGEEReferenceV19"
SOURCE = STAGE / "office_room_envelope_imagegen_raw_v19.png"
DOOR_TEXTURE = (
    STAGE / "office_door_leaf_exact_source_v19.png"
)
FILENAMES = {
    "plate": "office_reference_rebuild_plate_v19.png",
    "architectureMask": "office_reference_rebuild_architecture_mask_v19.png",
    "glassMask": "office_window_glass_mask_v19.png",
    "nearHover": "office_window_near_hover_overlay_v19.png",
    "metrics": "office_reference_rebuild_metrics_v19.json",
}

# Measured silhouette vertices in the accepted built-in ImageGen result.
SOURCE_CROWN = (856.0, 118.0)
SOURCE_FLOOR = (
    (856.0, 245.0),
    (209.0, 588.0),
    (704.0, 928.0),
    (1331.0, 438.0),
)

# The only pixels permitted outside the floor quadrilateral: the short timber
# edge and its metal cap.  The inner side overlaps the floor mask; the outer side
# follows the generated silhouette instead of being clipped to the diamond.
SOURCE_DOOR_POLYGON = (
    (898.0, 769.0),
    (1018.0, 675.0),
    (1023.0, 689.0),
    (909.0, 784.0),
)

# Measured runtime gap. The right cutaway runs up-right, so its outward normal
# points down-right. This 30px vector reads clearly at native size without the
# large detached float produced by the rejected ImageGen spacing pass.
DOOR_TARGET_OFFSET = (18.0, 24.0)
FORMER_DOOR_RUNTIME_SCALE = 0.28
# AR0809's visible leaf spans about 12% of its near-right edge; the first V19
# bake spanned about 18%. A literal 65% reduction matched the measured span but
# read too small because its thickness and caps shrank as well. The user chose
# 70% as the perceptual match, still preserving the supplied proportions.
DOOR_REFERENCE_SCALE_FACTOR = 0.70
DOOR_BAKED_SCALE = FORMER_DOOR_RUNTIME_SCALE * DOOR_REFERENCE_SCALE_FACTOR
# Add visual mass as a narrow backing edge, not by stretching the source. Four
# pixels on each long side raises the normalized thickness from ~1.18% to the
# AR0809 reference's ~1.58% while every original door pixel stays untouched.
DOOR_EDGE_EXPANSION_PX = 4
ENVIRONMENT_SCALE = 0.395


def _principal_alpha_angle(image: Image.Image) -> float:
    """Return the long-axis angle in y-down image coordinates."""
    alpha = np.asarray(image.getchannel("A"))
    ys, xs = np.nonzero(alpha > 20)
    points = np.column_stack((xs, ys)).astype(float)
    points -= np.mean(points, axis=0)
    eigenvalues, eigenvectors = np.linalg.eigh(np.cov(points, rowvar=False))
    axis = eigenvectors[:, int(np.argmax(eigenvalues))]
    if axis[0] < 0:
        axis = -axis
    return math.degrees(math.atan2(float(axis[1]), float(axis[0])))


def _add_perpendicular_backing_edge(
    image: Image.Image,
    long_axis_degrees: float,
    radius: int,
) -> tuple[Image.Image, tuple[int, int, int]]:
    """Thicken only the silhouette sides without stretching source pixels."""
    pad = radius + 2
    padded = Image.new("RGBA", (image.width + 2 * pad, image.height + 2 * pad))
    padded.paste(image, (pad, pad))
    alpha = padded.getchannel("A")
    expanded = Image.new("L", padded.size, 0)
    theta = math.radians(long_axis_degrees)
    normal = np.asarray((-math.sin(theta), math.cos(theta)))
    for offset in range(-radius, radius + 1):
        delta = np.rint(normal * offset).astype(int)
        shifted = Image.new("L", padded.size, 0)
        shifted.paste(alpha, (int(delta[0]), int(delta[1])))
        expanded = ImageChops.lighter(expanded, shifted)

    rgba = np.asarray(padded)
    rgb = rgba[:, :, :3]
    opaque = rgba[:, :, 3] > 128
    luminance = np.mean(rgb, axis=2)
    dark_wood = rgb[opaque & (luminance < 110)]
    if not dark_wood.size:
        raise RuntimeError("door texture has no dark timber pixels for its backing edge")
    median_wood = np.median(dark_wood, axis=0)
    backing_color = tuple(int(round(value * 0.62)) for value in median_wood)
    backing = Image.new("RGBA", padded.size, (*backing_color, 0))
    backing.putalpha(expanded)
    backing.alpha_composite(padded)
    return backing, backing_color


def build_assets() -> dict[str, Image.Image | dict[str, object]]:
    # Rebuild V18 first so the room, window masks and all non-door pixels are
    # byte-for-byte the accepted room rather than another ImageGen repaint.
    assets = v18.build_assets()

    plate = assets["plate"]
    architecture = assets["architectureMask"]
    assert isinstance(plate, Image.Image)
    assert isinstance(architecture, Image.Image)

    door_forward = base._homography_forward(SOURCE_FLOOR, base.TARGET_FLOOR)
    registered_door = [base._map_point(door_forward, p) for p in SOURCE_DOOR_POLYGON]
    target_door = [
        [point[0] + DOOR_TARGET_OFFSET[0], point[1] + DOOR_TARGET_OFFSET[1]]
        for point in registered_door
    ]
    # Preserve the current door exactly. Its former SpriteKit scale is in world
    # units while the plate is authored at ENVIRONMENT_SCALE world/plate pixel.
    # The texture already contains the final edge-on perspective, so it needs no
    # warp or repaint—only the same uniform scale and an alpha composite.
    door = Image.open(DOOR_TEXTURE).convert("RGBA")
    plate_scale = DOOR_BAKED_SCALE / ENVIRONMENT_SCALE
    door_size = (
        round(door.width * plate_scale),
        round(door.height * plate_scale),
    )
    # SpriteKit displayed the former live node with `.linear` filtering. Use
    # bilinear resampling here so baking changes placement, not texture response.
    door = door.resize(door_size, Image.Resampling.BILINEAR)
    source_angle = _principal_alpha_angle(door)
    edge_vector = np.asarray(base.TARGET_FLOOR[3]) - np.asarray(base.TARGET_FLOOR[2])
    edge_angle = math.degrees(math.atan2(float(edge_vector[1]), float(edge_vector[0])))
    # Pillow's rotation sign is opposite the y-down angle delta. Rotate the
    # complete supplied image rigidly until its long axis is parallel to the
    # camera-near right cutaway, instead of allowing the leaf to sit crooked.
    door_rotation = source_angle - edge_angle
    door = door.rotate(
        door_rotation,
        resample=Image.Resampling.BILINEAR,
        expand=True,
    )
    rigid_canvas_size = door.size
    door, backing_color = _add_perpendicular_backing_edge(
        door,
        edge_angle,
        DOOR_EDGE_EXPANSION_PX,
    )
    alpha_bbox = door.getbbox()
    if alpha_bbox is None:
        raise RuntimeError("exact runtime door texture is empty")
    target_center = np.mean(np.asarray(target_door), axis=0)
    alpha_center = np.asarray(
        ((alpha_bbox[0] + alpha_bbox[2]) / 2.0, (alpha_bbox[1] + alpha_bbox[3]) / 2.0)
    )
    door_origin = np.rint(target_center - alpha_center).astype(int)
    plate.paste(door, tuple(door_origin), door)

    door_mask = Image.new("L", base.CANVAS, 0)
    door_mask.paste(door.getchannel("A"), tuple(door_origin))
    architecture = Image.fromarray(
        np.maximum(np.asarray(architecture), np.asarray(door_mask)).astype(np.uint8),
        "L",
    )
    assets["plate"] = plate
    assets["architectureMask"] = architecture

    metrics = assets["metrics"]
    assert isinstance(metrics, dict)
    metrics["version"] = "BGEEReferenceV19"
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
    metrics["door"] = {
        "id": "office.door",
        "construction": "exact former runtime PNG baked into the RGB area plate",
        "sourcePolygon": [list(point) for point in SOURCE_DOOR_POLYGON],
        "registeredPolygonBeforeGap": registered_door,
        "targetPolygon": target_door,
        "targetGapOffset": list(DOOR_TARGET_OFFSET),
        "targetGapPixels": float(np.linalg.norm(DOOR_TARGET_OFFSET)),
        "textureSource": str(DOOR_TEXTURE.relative_to(ROOT)),
        "textureSourceSha256": base.sha256(DOOR_TEXTURE),
        "textureSourceSize": list(Image.open(DOOR_TEXTURE).size),
        "bakedCanvasOrigin": [int(value) for value in door_origin],
        "bakedCanvasSize": list(door_size),
        "bakedRotatedCanvasSize": list(door.size),
        "bakedRigidCanvasSize": list(rigid_canvas_size),
        "bakedAlphaBBox": list(alpha_bbox),
        "uniformPlateScale": plate_scale,
        "formerRuntimeScale": FORMER_DOOR_RUNTIME_SCALE,
        "referenceScaleFactor": DOOR_REFERENCE_SCALE_FACTOR,
        "bakedRuntimeEquivalentScale": DOOR_BAKED_SCALE,
        "perpendicularBackingEdgePixelsPerSide": DOOR_EDGE_EXPANSION_PX,
        "perpendicularBackingColorRGB": list(backing_color),
        "sourceLongAxisDegrees": source_angle,
        "targetEdgeDegrees": edge_angle,
        "rigidRotationDegrees": door_rotation,
        "runtimeVisualTexture": None,
        "logicalDoorRetained": True,
    }
    metrics["imageGeneration"] = {
        "tool": "built-in image_gen.imagegen",
        "useCase": "precise-object-edit",
        "rawSource": str(SOURCE.relative_to(ROOT)),
        "rawSourceSha256": base.sha256(SOURCE),
        "role": "placement study only; not the shipped door texture source",
        "invariants": "V17 AR0809 planes; V18 room pixels; exact runtime door PNG",
    }
    metrics["doorPixelsBakedIntoPlate"] = True
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
    print("door=office.door baked=True runtimeVisualTexture=None")


if __name__ == "__main__":
    main()

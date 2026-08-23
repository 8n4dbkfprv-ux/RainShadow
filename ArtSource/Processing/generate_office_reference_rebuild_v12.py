#!/usr/bin/env python3
"""Build the V12 office plate from the approved visual-reference redraw.

The ImageGen redraw is the colour, lighting, fixture, silhouette, and camera
authority.  One uniform scale/translation fits it to the V11 runtime frame;
independent x/y scaling and per-plane warps are forbidden.  The residual fit is
bounded below two runtime search cells, while the interactive window stays
within half a cell.  Output-resolution material grain restores local density
without borrowing any old fixture or wall pixels.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage


ROOT = Path(__file__).resolve().parents[2]
STAGE = ROOT / "ArtSource/Generated/Office/BGEEReferenceV12"
SOURCE = STAGE / "office_reference_rebuild_source_v12.png"
TARGET_REFERENCE = ROOT / "ArtSource/Reference/Office/V12/office_target_reference.png"
V11_STAGE = ROOT / "ArtSource/Generated/Office/BGEE1950sV11"
V11_GEOMETRY = V11_STAGE / "office_v11_geometry.json"
FLOOR_DETAIL = V11_STAGE / "floor_material_source_v11.png"
WALL_DETAIL = V11_STAGE / "wall_material_source_v11.png"

FILENAMES = {
    "plate": "office_reference_rebuild_plate_v12.png",
    "architectureMask": "office_reference_rebuild_architecture_mask_v12.png",
    "glassMask": "office_window_glass_mask_v12.png",
    "nearHover": "office_window_near_hover_overlay_v12.png",
    "metrics": "office_reference_rebuild_metrics_v12.json",
}
EXPECTED_SOURCE_SIZE = (1672, 941)

# Pixel registrations measured on the frozen 1672x941 redraw.  Points are a
# few antialiasing pixels inside the black cutaway edge on purpose: the target
# polygons, not the redraw's almost-black fringe, own the final silhouette.
SOURCE_PLANES = {
    "NW": [[848.0, 111.0], [386.0, 457.5], [386.0, 512.0], [848.0, 231.0]],
    "NE": [[848.0, 111.0], [1285.0, 438.75], [1357.0, 473.0], [848.0, 231.0]],
    "floor": [[848.0, 231.0], [386.0, 512.0], [795.0, 876.0], [1357.0, 473.0]],
}

# The redraw uses three columns by two rows per window.  Six inset pane
# quadrilaterals are the rain/glass authority; the frame and muntins stay opaque.
SOURCE_WINDOWS = [
    {
        "id": "far",
        "aperture": [[669.0, 274.0], [716.0, 240.0], [716.0, 278.0], [669.0, 314.0]],
        "glass": [
            [[676.0, 276.0], [686.0, 269.0], [686.0, 283.0], [676.0, 290.0]],
            [[676.0, 293.0], [686.0, 286.0], [686.0, 297.0], [676.0, 304.0]],
            [[689.0, 266.0], [699.0, 259.0], [699.0, 273.0], [689.0, 280.0]],
            [[689.0, 283.0], [699.0, 276.0], [699.0, 287.0], [689.0, 294.0]],
            [[702.0, 256.0], [712.0, 249.0], [712.0, 263.0], [702.0, 270.0]],
            [[702.0, 273.0], [712.0, 266.0], [712.0, 277.0], [702.0, 284.0]],
        ],
    },
    {
        "id": "near",
        "aperture": [[394.0, 456.0], [446.0, 421.0], [446.0, 471.0], [394.0, 504.0]],
        "glass": [
            [[401.0, 459.0], [411.0, 452.0], [411.0, 465.0], [401.0, 472.0]],
            [[401.0, 476.0], [411.0, 469.0], [411.0, 482.0], [401.0, 489.0]],
            [[415.0, 449.0], [425.0, 442.0], [425.0, 455.0], [415.0, 462.0]],
            [[415.0, 466.0], [425.0, 459.0], [425.0, 472.0], [415.0, 479.0]],
            [[429.0, 439.0], [439.0, 432.0], [439.0, 445.0], [429.0, 452.0]],
            [[429.0, 456.0], [439.0, 449.0], [439.0, 462.0], [429.0, 469.0]],
        ],
    },
]

# Least-squares uniform registration across the redraw's seven room control
# points and their V11 counterparts.  No rotation or independent x/y scaling
# is admitted, so the source's measured +/-36-degree ground axes are inert.
UNIFORM_REGISTRATION = {
    "scale": 2.410423422725852,
    "translate": [-18.977005846854127, 3.184540846076839],
}

# V12 architecture correction, measured on the frozen 1672x941 source. A
# fireplace painted onto an isometric wall cannot be graded by its axis-aligned
# box: that box includes the +0.75 descent across the mantel and encouraged the
# previous replacement to be flattened into a shelf. Compare the longest local
# upright stone span with the standing actor while separately locking the full
# silhouette envelope, so both jambs, mantel and hearth must survive.
FIREPLACE_VISUAL_SCALE_LOCK = {
    "sourceEnvelope": [983, 276, 1069, 401],
    "sourceUprightHeightPixels": 85.0,
    "standingAdultWorldHeight": 70.3125,
    "targetFireplaceToAdultRange": [1.05, 1.25],
}
WALL_VISUAL_SCALE_LOCK = {
    "sourceRearHeightPixels": 120.0,
    "standingAdultWorldHeight": 70.3125,
    "targetWallToAdultRange": [1.50, 1.75],
}

# Small floor-space and occlusion envelopes for the corrected fireplace.  They
# deliberately follow the compact source fixture instead of inheriting the V11
# collision prism, which was almost six source adults wide.
SOURCE_FIREPLACE_FLOOR_FOOTPRINT = [
    [985.0, 357.0],
    [1057.0, 391.0],
    [1072.0, 402.0],
    [1000.0, 368.0],
]
SOURCE_FIREPLACE_COVER = [
    [976.0, 263.0],
    [1060.0, 326.0],
    [1075.0, 413.0],
    [991.0, 350.0],
]
# A floor-only sample camera-near of the hearth.  Keep this separate from the
# thin collision footprint: the latter contains masonry and cannot prove that
# the authored firelight actually reaches the floor.
SOURCE_HEARTH_SPILL_SAMPLE = [
    [806.7, 396.6],
    [1022.7, 498.6],
    [1067.7, 531.6],
    [851.7, 429.6],
]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _geometry() -> dict[str, object]:
    payload = json.loads(V11_GEOMETRY.read_text(encoding="utf-8"))
    if payload.get("version") != "BGEE1950sV11":
        raise RuntimeError("V12 requires the registered V11 geometry manifest")
    return payload


def _triangle_coordinates(
    canvas_shape: tuple[int, int, int], points: np.ndarray
) -> tuple[slice, slice, np.ndarray, np.ndarray, np.ndarray, np.ndarray] | None:
    height, width = canvas_shape[:2]
    x0 = max(0, int(np.floor(points[:, 0].min())))
    x1 = min(width, int(np.ceil(points[:, 0].max())) + 1)
    y0 = max(0, int(np.floor(points[:, 1].min())))
    y1 = min(height, int(np.ceil(points[:, 1].max())) + 1)
    if x1 <= x0 or y1 <= y0:
        return None
    v0 = points[1] - points[0]
    v1 = points[2] - points[0]
    denominator = float(v0[0] * v1[1] - v1[0] * v0[1])
    if abs(denominator) < 1e-8:
        return None
    yy, xx = np.mgrid[y0:y1, x0:x1]
    dx = xx.astype(np.float32) - points[0, 0]
    dy = yy.astype(np.float32) - points[0, 1]
    w1 = (dx * v1[1] - v1[0] * dy) / denominator
    w2 = (v0[0] * dy - dx * v0[1]) / denominator
    w0 = 1.0 - w1 - w2
    mask = (w0 >= -0.001) & (w1 >= -0.001) & (w2 >= -0.001)
    return slice(y0, y1), slice(x0, x1), w0, w1, w2, mask


def _bilinear(texture: np.ndarray, u: np.ndarray, v: np.ndarray) -> np.ndarray:
    height, width = texture.shape[:2]
    x = np.clip(u, 0.0, 1.0) * (width - 1)
    y = np.clip(v, 0.0, 1.0) * (height - 1)
    x0 = np.floor(x).astype(np.int32)
    y0 = np.floor(y).astype(np.int32)
    x1 = np.minimum(x0 + 1, width - 1)
    y1 = np.minimum(y0 + 1, height - 1)
    fx = (x - x0)[..., None]
    fy = (y - y0)[..., None]
    top = texture[y0, x0] * (1.0 - fx) + texture[y0, x1] * fx
    bottom = texture[y1, x0] * (1.0 - fx) + texture[y1, x1] * fx
    return top * (1.0 - fy) + bottom * fy


def _raster_triangle(
    canvas: np.ndarray,
    target: np.ndarray,
    texture: np.ndarray,
    source_uv: np.ndarray,
) -> None:
    coordinates = _triangle_coordinates(canvas.shape, target)
    if coordinates is None:
        return
    sy, sx, w0, w1, w2, mask = coordinates
    u = w0 * source_uv[0, 0] + w1 * source_uv[1, 0] + w2 * source_uv[2, 0]
    v = w0 * source_uv[0, 1] + w1 * source_uv[1, 1] + w2 * source_uv[2, 1]
    sampled = _bilinear(texture, u, v)
    patch = canvas[sy, sx]
    patch[mask] = np.clip(sampled[mask], 0, 255).astype(np.uint8)


def _raster_plane(
    canvas: np.ndarray,
    texture: np.ndarray,
    source: list[list[float]],
    target: list[list[float]],
) -> None:
    source_points = np.asarray(source, dtype=np.float32)
    target_points = np.asarray(target, dtype=np.float32)
    source_uv = source_points / np.asarray(
        [texture.shape[1] - 1, texture.shape[0] - 1], dtype=np.float32
    )
    for indices in ([0, 1, 2], [0, 2, 3]):
        _raster_triangle(
            canvas,
            target_points[indices],
            texture,
            source_uv[indices],
        )


def _barycentric(point: np.ndarray, triangle: np.ndarray) -> np.ndarray | None:
    matrix = np.column_stack((triangle[1] - triangle[0], triangle[2] - triangle[0]))
    try:
        weights = np.linalg.solve(matrix, point - triangle[0])
    except np.linalg.LinAlgError:
        return None
    result = np.asarray([1.0 - weights.sum(), weights[0], weights[1]])
    # The camera-near sill projects a few pixels past the measured wall face.
    # Permit that small, intentional extrapolation while still rejecting a
    # point registered to the wrong plane.
    return result if result.min() >= -0.12 else None


def _map_wall_point(point: list[float], target_wall: list[list[float]]) -> list[float]:
    del target_wall  # Kept in the signature to make the geometry authority explicit.
    scale = float(UNIFORM_REGISTRATION["scale"])
    tx, ty = (float(value) for value in UNIFORM_REGISTRATION["translate"])
    return [point[0] * scale + tx, point[1] * scale + ty]


def _architecture_mask(size: tuple[int, int], room: dict[str, object]) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.polygon([tuple(point) for point in room["floorPolygon"]], fill=255)
    for polygon in room["wallPolygons"].values():
        draw.polygon([tuple(point) for point in polygon], fill=255)
    return mask


def _polygon_mask(size: tuple[int, int], polygon: list[list[float]]) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).polygon([tuple(point) for point in polygon], fill=255)
    return mask


def _uniform_plane(
    source: Image.Image,
    source_polygon: list[list[float]],
    target_polygon: list[list[float]],
    target_size: tuple[int, int],
) -> tuple[np.ndarray, np.ndarray]:
    """Register one painted plane without changing its line angles.

    The approved redraw and the shipping geometry differ by at most 60 target
    pixels at their clipped outer tips.  Pixels missing after the single
    uniform transform are extended from the nearest valid pixel on the same
    plane; they are never borrowed across a floor/wall boundary.
    """
    source_mask = _polygon_mask(source.size, source_polygon)
    isolated = Image.new("RGB", source.size, (0, 0, 0))
    isolated.paste(source, mask=source_mask)
    scale = float(UNIFORM_REGISTRATION["scale"])
    tx, ty = (float(value) for value in UNIFORM_REGISTRATION["translate"])
    affine = (1.0 / scale, 0.0, -tx / scale, 0.0, 1.0 / scale, -ty / scale)
    registered = isolated.transform(
        target_size,
        Image.Transform.AFFINE,
        affine,
        resample=Image.Resampling.BICUBIC,
    )
    registered_mask = source_mask.transform(
        target_size,
        Image.Transform.AFFINE,
        affine,
        resample=Image.Resampling.BICUBIC,
    )
    target_mask = np.asarray(_polygon_mask(target_size, target_polygon)) > 0
    rgb = np.asarray(registered, dtype=np.uint8).copy()
    valid = target_mask & (np.asarray(registered_mask) > 24) & np.any(rgb > 4, axis=2)
    missing = target_mask & ~valid
    if not np.any(valid):
        raise RuntimeError("uniform plane registration produced no valid pixels")
    if np.any(missing):
        _, indices = ndimage.distance_transform_edt(~valid, return_indices=True)
        rgb[missing] = rgb[indices[0][missing], indices[1][missing]]
    rgb[~target_mask] = 0
    return rgb, target_mask


def _registered_windows(room: dict[str, object]) -> list[dict[str, object]]:
    target_wall = room["wallPolygons"]["NW"]
    return [
        {
            "id": window["id"],
            "aperture": [_map_wall_point(point, target_wall) for point in window["aperture"]],
            "glass": [
                [_map_wall_point(point, target_wall) for point in polygon]
                for polygon in window["glass"]
            ],
        }
        for window in SOURCE_WINDOWS
    ]


def _glass_mask(
    size: tuple[int, int], windows: list[dict[str, object]]
) -> Image.Image:
    alpha = Image.new("L", size, 0)
    draw = ImageDraw.Draw(alpha)
    for window in windows:
        for polygon in window["glass"]:
            draw.polygon([tuple(point) for point in polygon], fill=255)
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.65))
    rgba = Image.new("RGBA", size, (255, 255, 255, 0))
    rgba.putalpha(alpha)
    return rgba


def _near_hover(
    size: tuple[int, int], windows: list[dict[str, object]]
) -> Image.Image:
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image, "RGBA")
    near = next(window for window in windows if window["id"] == "near")
    polygon = [tuple(point) for point in near["aperture"]]
    draw.polygon(polygon, fill=(24, 172, 184, 34))
    draw.line(polygon + [polygon[0]], fill=(43, 231, 238, 164), width=4, joint="curve")
    return image


def _tiled_high_pass(path: Path, size: tuple[int, int]) -> np.ndarray:
    source = Image.open(path).convert("RGB")
    tiled = Image.new("RGB", size)
    for y in range(0, size[1], source.height):
        for x in range(0, size[0], source.width):
            tiled.paste(source, (x, y))
    smooth = tiled.filter(ImageFilter.GaussianBlur(3.0))
    return np.asarray(tiled, dtype=np.float32) - np.asarray(smooth, dtype=np.float32)


def _projection_lock_floor_seams(
    plate: Image.Image, room: dict[str, object], floor_mask: Image.Image
) -> Image.Image:
    """Reassert both BG:EE board families without making a square grid.

    The target floor's painted west/east tips are deliberately clipped and are
    not themselves projection axes.  Without authored seams the structure
    tensor can lock onto that +32-degree silhouette instead of the +36.87-degree
    boards.  Each family is restrained to one overlapping-free half of the
    floor, avoiding cross-hatch tensor bias and retaining a plank-floor read.
    """
    rear = np.asarray(room["rear"], dtype=np.float64)
    axis_nw = np.asarray(room["axisNW"], dtype=np.float64)
    axis_ne = np.asarray(room["axisNE"], dtype=np.float64)
    axis_nw_locked = np.asarray([axis_nw[0], -axis_nw[0] * 0.75])

    positive = plate.convert("RGBA")
    positive_draw = ImageDraw.Draw(positive, "RGBA")
    for index in range(1, 136):
        b = index / 136.0
        start = rear + axis_ne * b
        end = start + axis_nw_locked
        positive_draw.line(
            [tuple(start), tuple(end)],
            fill=(13, 10, 8, 255),
            width=5,
        )
    positive_mask = floor_mask.copy()
    ImageDraw.Draw(positive_mask).rectangle(
        (plate.width // 2 + 300, 0, plate.width, plate.height), fill=0
    )
    locked = Image.composite(positive.convert("RGB"), plate.convert("RGB"), positive_mask)

    negative = locked.convert("RGBA")
    negative_draw = ImageDraw.Draw(negative, "RGBA")
    for index in range(1, 36):
        a = index / 36.0
        start = rear + axis_nw * a
        end = start + axis_ne
        negative_draw.line(
            [tuple(start), tuple(end)],
            fill=(13, 10, 8, 132),
            width=3,
        )
    negative_mask = floor_mask.copy()
    ImageDraw.Draw(negative_mask).rectangle(
        (0, 0, plate.width // 2 - 300, plate.height), fill=0
    )
    return Image.composite(negative.convert("RGB"), locked, negative_mask)


def build_assets() -> dict[str, Image.Image | dict[str, object]]:
    geometry = _geometry()
    room = geometry["room"]
    size = tuple(int(value) for value in geometry["canvas"])
    if size != (4096, 2304):
        raise RuntimeError(f"unexpected registered canvas: {size}")
    source_image = Image.open(SOURCE).convert("RGB")
    if source_image.size != EXPECTED_SOURCE_SIZE:
        raise RuntimeError(f"unexpected V12 redraw size: {source_image.size}")
    scale = float(UNIFORM_REGISTRATION["scale"])
    tx, ty = (float(value) for value in UNIFORM_REGISTRATION["translate"])
    affine = (1.0 / scale, 0.0, -tx / scale, 0.0, 1.0 / scale, -ty / scale)
    registered_source = source_image.transform(
        size,
        Image.Transform.AFFINE,
        affine,
        resample=Image.Resampling.BICUBIC,
    )
    canvas = np.asarray(registered_source, dtype=np.uint8).copy()

    source_architecture = Image.new("L", source_image.size, 0)
    source_architecture_pixels = np.asarray(source_image, dtype=np.uint8)
    source_architecture.putdata(
        (np.any(source_architecture_pixels > 7, axis=2).astype(np.uint8) * 255).ravel()
    )
    architecture = source_architecture.transform(
        size,
        Image.Transform.AFFINE,
        affine,
        resample=Image.Resampling.BICUBIC,
    )
    architecture_array = np.asarray(architecture, dtype=np.uint8)
    floor_mask = _polygon_mask(source_image.size, SOURCE_PLANES["floor"]).transform(
        size,
        Image.Transform.AFFINE,
        affine,
        resample=Image.Resampling.BICUBIC,
    )
    floor_pixels = np.asarray(floor_mask, dtype=np.uint8) > 0
    wall_mask = Image.new("L", source_image.size, 0)
    wall_draw = ImageDraw.Draw(wall_mask)
    wall_draw.polygon([tuple(point) for point in SOURCE_PLANES["NW"]], fill=255)
    wall_draw.polygon([tuple(point) for point in SOURCE_PLANES["NE"]], fill=255)
    wall_mask = wall_mask.transform(
        size,
        Image.Transform.AFFINE,
        affine,
        resample=Image.Resampling.BICUBIC,
    )
    wall_pixels = np.asarray(wall_mask, dtype=np.uint8) > 0

    # Add only output-scale high frequencies; colour, value, seams, fixtures,
    # fire, and macro lighting continue to come entirely from the approved V12
    # redraw.  This avoids a 1672px source being merely enlarged to 4096px.
    detailed = canvas.astype(np.float32)
    floor_high = _tiled_high_pass(FLOOR_DETAIL, size)
    wall_high = _tiled_high_pass(WALL_DETAIL, size)
    detailed[floor_pixels] += floor_high[floor_pixels] * 0.12
    detailed[wall_pixels] += wall_high[wall_pixels] * 0.09
    detailed[architecture_array == 0] = 0
    plate = Image.fromarray(np.clip(detailed, 0, 255).astype(np.uint8), "RGB")

    windows = _registered_windows(room)
    registered_planes = {
        key: [_map_wall_point(point, []) for point in polygon]
        for key, polygon in SOURCE_PLANES.items()
    }
    fireplace_floor = [
        _map_wall_point(point, []) for point in SOURCE_FIREPLACE_FLOOR_FOOTPRINT
    ]
    fireplace_cover = [
        _map_wall_point(point, []) for point in SOURCE_FIREPLACE_COVER
    ]
    hearth_spill_sample = [
        _map_wall_point(point, []) for point in SOURCE_HEARTH_SPILL_SAMPLE
    ]
    metrics = {
        "version": "BGEEReferenceV12",
        "canvas": list(size),
        "environmentScale": geometry["environmentScale"],
        "geometryAuthority": (
            f"{V11_GEOMETRY.relative_to(ROOT)} for floor/door; "
            "V12 registered source for walls/windows/fireplace"
        ),
        "source": {
            "file": SOURCE.name,
            "size": list(source_image.size),
            "sha256": sha256(SOURCE),
            "role": "ImageGen redraw; visual, material, lighting, and fixture authority",
        },
        "targetReference": {
            "file": str(TARGET_REFERENCE.relative_to(ROOT)),
            "sha256": sha256(TARGET_REFERENCE),
            "role": "user-supplied visual target",
        },
        "registration": {
            "sourcePlanes": SOURCE_PLANES,
            "targetPlanes": registered_planes,
            "uniformScale": UNIFORM_REGISTRATION["scale"],
            "uniformTranslation": UNIFORM_REGISTRATION["translate"],
            "visualSilhouetteAuthority": "uniformly transformed V12 redraw",
            "navigationGeometryAuthority": "V11 floor/door; V12 walls/windows/fireplace; maximum floor control-point delta is 59.73 pixels (23.59 world units)",
            "anisotropicWholePlateResize": False,
        },
        "windows": windows,
        "walls": {
            "visualScaleLock": {
                **WALL_VISUAL_SCALE_LOCK,
                "plateRearHeightPixels": (
                    WALL_VISUAL_SCALE_LOCK["sourceRearHeightPixels"] * scale
                ),
                "worldRearHeight": (
                    WALL_VISUAL_SCALE_LOCK["sourceRearHeightPixels"]
                    * scale
                    * float(geometry["environmentScale"])
                ),
                "wallToAdultRatio": (
                    WALL_VISUAL_SCALE_LOCK["sourceRearHeightPixels"]
                    * scale
                    * float(geometry["environmentScale"])
                    / WALL_VISUAL_SCALE_LOCK["standingAdultWorldHeight"]
                ),
                "measurement": "rear wall-floor seam to rear crown on the complete painted face",
            },
        },
        "fireplace": {
            "state": "lit",
            "collisionAndCoverAuthority": {
                "targetFloorFootprint": fireplace_floor,
                "targetObstaclePolygon": fireplace_floor,
                "targetCoverPolygon": fireplace_cover,
                "targetHearthSpillSample": hearth_spill_sample,
            },
            "visualScaleLock": {
                **FIREPLACE_VISUAL_SCALE_LOCK,
                "plateFixtureHeightPixels": (
                    FIREPLACE_VISUAL_SCALE_LOCK["sourceUprightHeightPixels"] * scale
                ),
                "worldFixtureHeight": (
                    FIREPLACE_VISUAL_SCALE_LOCK["sourceUprightHeightPixels"]
                    * scale
                    * float(geometry["environmentScale"])
                ),
                "fireplaceToAdultRatio": (
                    FIREPLACE_VISUAL_SCALE_LOCK["sourceUprightHeightPixels"]
                    * scale
                    * float(geometry["environmentScale"])
                    / FIREPLACE_VISUAL_SCALE_LOCK["standingAdultWorldHeight"]
                ),
                "measurement": "maximum local upright span of the connected stone fixture; the full isometric envelope is locked separately",
            },
        },
        "densityRestoration": {
            "floorDetailSource": FLOOR_DETAIL.name,
            "floorDetailSha256": sha256(FLOOR_DETAIL),
            "floorHighPassMix": 0.12,
            "wallDetailSource": WALL_DETAIL.name,
            "wallDetailSha256": sha256(WALL_DETAIL),
            "wallHighPassMix": 0.09,
        },
        "doorPixelsBakedIntoPlate": False,
        "flameOrEmberPixelsAuthored": True,
    }
    return {
        "plate": plate,
        "architectureMask": architecture,
        "glassMask": _glass_mask(size, windows),
        "nearHover": _near_hover(size, windows),
        "metrics": metrics,
    }


def write_assets(output_dir: Path = STAGE) -> dict[str, Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    assets = build_assets()
    paths: dict[str, Path] = {}
    for key in ("plate", "architectureMask", "glassMask", "nearHover"):
        path = output_dir / FILENAMES[key]
        image = assets[key]
        assert isinstance(image, Image.Image)
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
        try:
            label = path.relative_to(ROOT)
        except ValueError:
            label = path
        print(f"wrote {label}")


if __name__ == "__main__":
    main()

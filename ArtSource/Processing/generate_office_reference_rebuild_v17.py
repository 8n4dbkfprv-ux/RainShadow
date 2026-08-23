#!/usr/bin/env python3
"""Register the AR0809-exact V17 ImageGen office on the runtime canvas.

The V17 ImageGen source owns the visible materials, fixtures and lighting.  The
AR0809 plane guide owns the room envelope.  Registration is plane-local: one
projective floor transform and one affine transform for each tapered wall.
There is no whole-image anisotropic resize, and all five reference control
points land exactly on the 4096x2304 plate.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
STAGE = ROOT / "ArtSource/Generated/Office/BGEEReferenceV17"
SOURCE = STAGE / "office_room_envelope_imagegen_raw_v17.png"
REFERENCE = ROOT / "ArtSource/Reference/Office/V15/AR0809_geometry_reference.png"
REFERENCE_GUIDE = (
    ROOT
    / "ArtSource/Generated/Office/BGEEReferenceV15"
    / "office_ar0809_plane_guide_v15.png"
)

CANVAS = (4096, 2304)
GUIDE_SIZE = (1600, 900)
ENVIRONMENT_SCALE = 0.395

FILENAMES = {
    "plate": "office_reference_rebuild_plate_v17.png",
    "architectureMask": "office_reference_rebuild_architecture_mask_v17.png",
    "glassMask": "office_window_glass_mask_v17.png",
    "nearHover": "office_window_near_hover_overlay_v17.png",
    "metrics": "office_reference_rebuild_metrics_v17.json",
}

# Measured control points in the accepted built-in ImageGen result (y down).
# Order is significant: rear floor, left tip, near tip, right tip.
SOURCE_CROWN = (852.0, 112.0)
SOURCE_FLOOR = (
    (852.0, 239.0),
    (207.0, 581.0),
    (700.0, 921.0),
    (1325.0, 433.0),
)

# Exact vertices of office_ar0809_plane_guide_v15.png.  They are scaled
# uniformly by 4096/1600 == 2304/900, preserving the reference framing.
GUIDE_CROWN = (944.0, 82.0)
GUIDE_FLOOR = (
    (944.0, 204.0),
    (272.0, 497.0),
    (660.0, 812.0),
    (1328.0, 394.0),
)


def _guide_to_plate(point: tuple[float, float]) -> tuple[float, float]:
    scale_x = CANVAS[0] / GUIDE_SIZE[0]
    scale_y = CANVAS[1] / GUIDE_SIZE[1]
    if abs(scale_x - scale_y) > 1e-12:
        raise RuntimeError("AR0809 guide and runtime canvas are not uniform-scale compatible")
    return point[0] * scale_x, point[1] * scale_y


TARGET_CROWN = _guide_to_plate(GUIDE_CROWN)
TARGET_FLOOR = tuple(_guide_to_plate(point) for point in GUIDE_FLOOR)

SOURCE_PLANES = {
    "NW": [SOURCE_CROWN, SOURCE_FLOOR[1], SOURCE_FLOOR[1], SOURCE_FLOOR[0]],
    "NE": [SOURCE_CROWN, SOURCE_FLOOR[3], SOURCE_FLOOR[3], SOURCE_FLOOR[0]],
    "floor": list(SOURCE_FLOOR),
}
TARGET_PLANES = {
    "NW": [TARGET_CROWN, TARGET_FLOOR[1], TARGET_FLOOR[1], TARGET_FLOOR[0]],
    "NE": [TARGET_CROWN, TARGET_FLOOR[3], TARGET_FLOOR[3], TARGET_FLOOR[0]],
    "floor": list(TARGET_FLOOR),
}

# Painted window apertures in the V17 ImageGen source, rear-most first.
SOURCE_WINDOWS = (
    ("far", ((532.0, 346.0), (560.0, 329.0), (560.0, 385.0), (532.0, 402.0))),
    ("near", ((437.0, 407.0), (463.0, 392.0), (463.0, 448.0), (437.0, 463.0))),
)

# Conservative floor contact around the ImageGen fireplace and hearth.
SOURCE_FIREPLACE_FLOOR = (
    (992.0, 365.0),
    (1127.0, 419.0),
    (1088.0, 466.0),
    (953.0, 412.0),
)
SOURCE_FIREPLACE_COVER = (
    (1005.0, 266.0),
    # Parallel to the source NE wall base, so the registered facade follows
    # AR0809's exact right-wall course instead of the retired ±0.75 guide.
    (1118.0, 312.35940803382664),
    (1118.0, 422.35940803382664),
    (1005.0, 376.0),
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _affine_forward(
    source: tuple[tuple[float, float], ...],
    target: tuple[tuple[float, float], ...],
) -> np.ndarray:
    """Return a 3x3 affine matrix mapping three source points to target."""
    design = np.array([[x, y, 1.0] for x, y in source], dtype=np.float64)
    target_array = np.asarray(target, dtype=np.float64)
    coefficients = np.linalg.solve(design, target_array)
    return np.array(
        [
            [coefficients[0, 0], coefficients[1, 0], coefficients[2, 0]],
            [coefficients[0, 1], coefficients[1, 1], coefficients[2, 1]],
            [0.0, 0.0, 1.0],
        ],
        dtype=np.float64,
    )


def _homography_forward(
    source: tuple[tuple[float, float], ...],
    target: tuple[tuple[float, float], ...],
) -> np.ndarray:
    """Return a 3x3 homography mapping four source points to target."""
    rows: list[list[float]] = []
    values: list[float] = []
    for (x, y), (u, v) in zip(source, target):
        rows.extend(
            (
                [x, y, 1.0, 0.0, 0.0, 0.0, -u * x, -u * y],
                [0.0, 0.0, 0.0, x, y, 1.0, -v * x, -v * y],
            )
        )
        values.extend((u, v))
    h = np.linalg.solve(np.asarray(rows), np.asarray(values))
    return np.array(
        [[h[0], h[1], h[2]], [h[3], h[4], h[5]], [h[6], h[7], 1.0]],
        dtype=np.float64,
    )


NW_FORWARD = _affine_forward(
    (SOURCE_CROWN, SOURCE_FLOOR[1], SOURCE_FLOOR[0]),
    (TARGET_CROWN, TARGET_FLOOR[1], TARGET_FLOOR[0]),
)
NE_FORWARD = _affine_forward(
    (SOURCE_CROWN, SOURCE_FLOOR[0], SOURCE_FLOOR[3]),
    (TARGET_CROWN, TARGET_FLOOR[0], TARGET_FLOOR[3]),
)
FLOOR_FORWARD = _homography_forward(SOURCE_FLOOR, TARGET_FLOOR)


def _map_point(matrix: np.ndarray, point: tuple[float, float]) -> list[float]:
    mapped = matrix @ np.array([point[0], point[1], 1.0], dtype=np.float64)
    return [float(mapped[0] / mapped[2]), float(mapped[1] / mapped[2])]


def _pil_inverse_coefficients(matrix: np.ndarray, perspective: bool) -> tuple[float, ...]:
    inverse = np.linalg.inv(matrix)
    inverse /= inverse[2, 2]
    if perspective:
        return (
            float(inverse[0, 0]),
            float(inverse[0, 1]),
            float(inverse[0, 2]),
            float(inverse[1, 0]),
            float(inverse[1, 1]),
            float(inverse[1, 2]),
            float(inverse[2, 0]),
            float(inverse[2, 1]),
        )
    return (
        float(inverse[0, 0]),
        float(inverse[0, 1]),
        float(inverse[0, 2]),
        float(inverse[1, 0]),
        float(inverse[1, 1]),
        float(inverse[1, 2]),
    )


def _antialiased_polygon(points: list[list[float]], supersample: int = 4) -> Image.Image:
    mask = Image.new("L", (CANVAS[0] * supersample, CANVAS[1] * supersample), 0)
    draw = ImageDraw.Draw(mask)
    draw.polygon(
        [(round(x * supersample), round(y * supersample)) for x, y in points],
        fill=255,
    )
    return mask.resize(CANVAS, Image.Resampling.LANCZOS)


def _warp_plane(
    source: Image.Image,
    matrix: np.ndarray,
    target_polygon: list[list[float]],
    perspective: bool,
) -> tuple[Image.Image, Image.Image]:
    method = Image.Transform.PERSPECTIVE if perspective else Image.Transform.AFFINE
    warped = source.transform(
        CANVAS,
        method,
        _pil_inverse_coefficients(matrix, perspective),
        resample=Image.Resampling.BICUBIC,
    )
    return warped, _antialiased_polygon(target_polygon)


def _window(identifier: str, aperture: tuple[tuple[float, float], ...]) -> dict[str, object]:
    target = [_map_point(NW_FORWARD, point) for point in aperture]
    panes: list[list[list[float]]] = []
    tl, tr, br, bl = (np.asarray(point) for point in target)
    for left, right in ((0.08, 0.46), (0.54, 0.92)):
        for top, bottom in ((0.06, 0.30), (0.36, 0.62), (0.68, 0.94)):
            pane = []
            for u, v in ((left, top), (right, top), (right, bottom), (left, bottom)):
                point = (
                    (1.0 - u) * (1.0 - v) * tl
                    + u * (1.0 - v) * tr
                    + u * v * br
                    + (1.0 - u) * v * bl
                )
                pane.append([float(point[0]), float(point[1])])
            panes.append(pane)
    return {"id": identifier, "aperture": target, "glass": panes}


def build_assets() -> dict[str, Image.Image | dict[str, object]]:
    source = Image.open(SOURCE).convert("RGB")
    plate = Image.new("RGB", CANVAS, (0, 0, 0))

    plane_specs = (
        (NW_FORWARD, TARGET_PLANES["NW"], False),
        (NE_FORWARD, TARGET_PLANES["NE"], False),
        (FLOOR_FORWARD, TARGET_PLANES["floor"], True),
    )
    architecture = Image.new("L", CANVAS, 0)
    for matrix, polygon, perspective in plane_specs:
        target_polygon = [[float(x), float(y)] for x, y in polygon]
        warped, mask = _warp_plane(source, matrix, target_polygon, perspective)
        plate = Image.composite(warped, plate, mask)
        architecture = Image.fromarray(
            np.maximum(np.asarray(architecture), np.asarray(mask)).astype(np.uint8),
            "L",
        )

    # Force exact black away from the registered silhouette, including any
    # faint ImageGen/C2PA exterior pixels resampled by the plane transforms.
    plate = Image.composite(plate, Image.new("RGB", CANVAS, (0, 0, 0)), architecture)

    windows = [_window(identifier, aperture) for identifier, aperture in SOURCE_WINDOWS]
    glass = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    glass_draw = ImageDraw.Draw(glass, "RGBA")
    for window in windows:
        for pane in window["glass"]:
            glass_draw.polygon([tuple(point) for point in pane], fill=(115, 155, 175, 126))

    hover = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    hover_draw = ImageDraw.Draw(hover, "RGBA")
    near = next(window for window in windows if window["id"] == "near")
    near_polygon = [tuple(point) for point in near["aperture"]]
    hover_draw.polygon(near_polygon, fill=(24, 172, 184, 34))
    hover_draw.line(
        near_polygon + [near_polygon[0]],
        fill=(43, 231, 238, 164),
        width=6,
        joint="curve",
    )

    long_axis = np.asarray(TARGET_FLOOR[1]) - np.asarray(TARGET_FLOOR[0])
    short_axis = np.asarray(TARGET_FLOOR[3]) - np.asarray(TARGET_FLOOR[0])
    rear_height = TARGET_FLOOR[0][1] - TARGET_CROWN[1]
    floor_height = TARGET_FLOOR[2][1] - TARGET_FLOOR[0][1]
    floor_width = max(point[0] for point in TARGET_FLOOR) - min(
        point[0] for point in TARGET_FLOOR
    )
    fireplace_floor = [
        _map_point(FLOOR_FORWARD, point) for point in SOURCE_FIREPLACE_FLOOR
    ]
    fireplace_cover = [
        _map_point(NE_FORWARD, point) for point in SOURCE_FIREPLACE_COVER
    ]

    metrics: dict[str, object] = {
        "version": "BGEEReferenceV17",
        "canvas": list(CANVAS),
        "environmentScale": ENVIRONMENT_SCALE,
        "geometryAuthority": "AR0809 guide vertices uniformly mapped to the runtime canvas",
        "source": {
            "file": SOURCE.name,
            "size": list(source.size),
            "sha256": sha256(SOURCE),
            "role": "built-in ImageGen visual, material, lighting and fixture authority",
        },
        "targetReference": {
            "file": str(REFERENCE),
            "sha256": sha256(REFERENCE),
            "guide": str(REFERENCE_GUIDE.relative_to(ROOT)),
            "guideSha256": sha256(REFERENCE_GUIDE),
            "role": "exact room geometry, size, framing and perceived-depth authority",
        },
        "registration": {
            "sourcePlanes": SOURCE_PLANES,
            "targetPlanes": TARGET_PLANES,
            "method": "projective floor plus affine tapered wall planes",
            "anisotropicWholePlateResize": False,
            "longShortGroundAxisRatio": float(np.linalg.norm(long_axis) / np.linalg.norm(short_axis)),
            "floorDepthToWidth": float(floor_height / floor_width),
            "referenceFloorDepthToWidth": float((812.0 - 204.0) / (1328.0 - 272.0)),
            "controlPointMaxErrorPixels": 0.0,
        },
        "windows": windows,
        "walls": {
            "visualScaleLock": {
                "plateRearHeightPixels": rear_height,
                "standingAdultWorldHeight": 70.3125,
                "worldRearHeight": rear_height * ENVIRONMENT_SCALE,
                "wallToAdultRatio": rear_height * ENVIRONMENT_SCALE / 70.3125,
            }
        },
        "fireplace": {
            "state": "lit",
            "collisionAndCoverAuthority": {
                "targetFloorFootprint": fireplace_floor,
                "targetObstaclePolygon": fireplace_floor,
                "targetWallPolygon": fireplace_cover,
                "targetCoverPolygon": fireplace_cover,
                "targetHearthSpillSample": fireplace_floor,
            },
            "visualScaleLock": {
                "plateFixtureHeightPixels": 420.0,
            },
        },
        "imageGeneration": {
            "tool": "built-in image_gen.imagegen",
            "useCase": "precise-object-edit",
            "rawSource": str(SOURCE.relative_to(ROOT)),
            "rawSourceSha256": sha256(SOURCE),
        },
        "doorPixelsBakedIntoPlate": False,
        "flameOrEmberPixelsAuthored": True,
    }
    return {
        "plate": plate,
        "architectureMask": architecture,
        "glassMask": glass,
        "nearHover": hover,
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
    metrics_path = output_dir / FILENAMES["metrics"]
    metrics_path.write_text(json.dumps(metrics, indent=2, sort_keys=True) + "\n")
    paths["metrics"] = metrics_path
    return paths


def main() -> None:
    paths = write_assets()
    for path in paths.values():
        print(f"wrote {path.relative_to(ROOT)}")
    floor = TARGET_PLANES["floor"]
    print(f"floor={floor}")
    print(f"crown={TARGET_CROWN}")


if __name__ == "__main__":
    main()

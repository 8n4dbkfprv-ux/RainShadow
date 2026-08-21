#!/usr/bin/env python3
"""Build the frozen BG:EE V11 1950s detective-office architecture.

Generated images are treated as flat material and fixture sources.  Room,
window, fireplace, mask, and hover pixels are projected here from the V11
geometry manifest, so rerunning the script cannot move a registered system.
The separately registered door is deliberately absent from every plate layer.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[2]
STAGE = ROOT / "ArtSource/Generated/Office/BGEE1950sV11"
GEOMETRY_PATH = STAGE / "office_v11_geometry.json"
FLOOR_SOURCE = STAGE / "floor_material_source_v11.png"
WALL_SOURCE = STAGE / "wall_material_source_v11.png"
WINDOW_SOURCE = STAGE / "steel_window_reference_scale_fixture_v11.png"
FIREPLACE_SOURCE = STAGE / "cold_fireplace_reference_scale_fixture_v11.png"

FILENAMES = {
    "plate": "office_1950s_plate_v11.png",
    "graybox": "office_1950s_graybox_v11.png",
    "architectureMask": "office_1950s_architecture_mask_v11.png",
    "glassMask": "office_window_glass_mask_v11.png",
    "nearHover": "office_window_near_hover_overlay_v11.png",
    "metrics": "office_1950s_metrics_v11.json",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_geometry() -> dict[str, object]:
    geometry = json.loads(GEOMETRY_PATH.read_text(encoding="utf-8"))
    if geometry.get("version") != "BGEE1950sV11":
        raise RuntimeError("office_v11_geometry.json has the wrong version")
    transform = geometry["referenceTransform"]
    if transform.get("anisotropicScalingAllowed") is not False:
        raise RuntimeError("V11 reference transform must forbid anisotropic scaling")
    return geometry


def _soft_source(path: Path, width: int = 1254) -> np.ndarray:
    image = Image.open(path).convert("RGB")
    if image.width != width:
        height = max(1, round(image.height * width / image.width))
        image = image.resize((width, height), Image.Resampling.LANCZOS)
    image = image.filter(ImageFilter.GaussianBlur(0.22))
    return np.asarray(image, dtype=np.float32)


def _fixture_source(path: Path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGBA"), dtype=np.float32)


def _locked_relief(path: Path, target_slope: float, target_height: int) -> Image.Image:
    """Camera-lock an already dimensional fixture with one vertical shear.

    ImageGen supplies visible top/return planes, inset shadows, and projecting
    sills/hearths.  A vertical shear changes only the course slope: jambs stay
    vertical and the whole fixture is then uniformly scaled.  This avoids the
    four-corner facade warp that made V11's first fixtures read as wallpaper.
    """
    image = Image.open(path).convert("RGBA")
    alpha = np.asarray(image.getchannel("A"), dtype=np.uint8)
    ys, xs = np.where(alpha > 128)
    if len(xs) < 100:
        raise ValueError(f"no relief silhouette found in {path}")
    top: list[tuple[float, float]] = []
    for x in range(int(xs.min()), int(xs.max()) + 1):
        column = np.where(alpha[:, x] > 128)[0]
        if len(column):
            top.append((float(x), float(column.min())))
    envelope = np.asarray(top, dtype=np.float64)
    lo = float(xs.min()) + (float(xs.max()) - float(xs.min())) * 0.12
    hi = float(xs.min()) + (float(xs.max()) - float(xs.min())) * 0.88
    middle = (envelope[:, 0] >= lo) & (envelope[:, 0] <= hi)
    source_slope = float(np.polyfit(envelope[middle, 0], envelope[middle, 1], 1)[0])
    delta = target_slope - source_slope

    width, height = image.size
    minimum = min(0.0, delta * (width - 1))
    maximum = max(0.0, delta * (width - 1))
    out_height = int(np.ceil(height + maximum - minimum)) + 2
    offset = -minimum + 1.0
    sheared = image.transform(
        (width, out_height),
        Image.Transform.AFFINE,
        (1.0, 0.0, 0.0, -delta, 1.0, -offset),
        resample=Image.Resampling.BICUBIC,
    )
    bbox = sheared.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError(f"camera lock erased {path}")
    sheared = sheared.crop(bbox)
    scale = target_height / sheared.height
    size = (
        max(1, round(sheared.width * scale)),
        target_height,
    )
    return sheared.resize(size, Image.Resampling.LANCZOS)


def _composite_centered(
    image: Image.Image,
    fixture: Image.Image,
    center: tuple[float, float],
) -> None:
    position = (
        round(center[0] - fixture.width / 2.0),
        round(center[1] - fixture.height / 2.0),
    )
    image.alpha_composite(fixture, position)


def _mirror(value: np.ndarray) -> np.ndarray:
    phase = np.mod(value, 2.0)
    return np.where(phase <= 1.0, phase, 2.0 - phase)


def _bilinear(texture: np.ndarray, u: np.ndarray, v: np.ndarray) -> np.ndarray:
    h, w = texture.shape[:2]
    x = np.clip(u, 0.0, 1.0) * (w - 1)
    y = np.clip(v, 0.0, 1.0) * (h - 1)
    x0 = np.floor(x).astype(np.int32)
    y0 = np.floor(y).astype(np.int32)
    x1 = np.minimum(x0 + 1, w - 1)
    y1 = np.minimum(y0 + 1, h - 1)
    fx = (x - x0)[..., None]
    fy = (y - y0)[..., None]
    top = texture[y0, x0] * (1.0 - fx) + texture[y0, x1] * fx
    bottom = texture[y1, x0] * (1.0 - fx) + texture[y1, x1] * fx
    return top * (1.0 - fy) + bottom * fy


class Geometry:
    def __init__(self, manifest: dict[str, object]):
        self.manifest = manifest
        self.width, self.height = (int(v) for v in manifest["canvas"])
        room = manifest["room"]
        self.rear = np.asarray(room["rear"], dtype=np.float32)
        self.rear_floor = np.asarray(room["rearFloor"], dtype=np.float32)
        self.axis_nw = np.asarray(room["axisNW"], dtype=np.float32)
        self.axis_ne = np.asarray(room["axisNE"], dtype=np.float32)
        self.wall_h = float(room["wallFaceHeight"])
        self.cutaway_h = float(room["cutawayHeight"])
        self.floor_polygon = [
            [float(value) for value in point] for point in room["floorPolygon"]
        ]
        self.wall_polygons = {
            name: [[float(value) for value in point] for point in polygon]
            for name, polygon in room["wallPolygons"].items()
        }

    def plan(self, a: float, b: float) -> tuple[float, float]:
        point = self.rear + self.axis_nw * a + self.axis_ne * b
        return float(point[0]), float(point[1])

    def plan_arrays(self, xs: np.ndarray, ys: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
        matrix = np.column_stack((self.axis_nw, self.axis_ne))
        determinant = float(np.linalg.det(matrix))
        dx = xs - self.rear[0]
        dy = ys - self.rear[1]
        a = (dx * matrix[1, 1] - matrix[0, 1] * dy) / determinant
        b = (matrix[0, 0] * dy - dx * matrix[1, 0]) / determinant
        return a, b


def _paint_floor(canvas: np.ndarray, texture: np.ndarray, geo: Geometry) -> None:
    corners = [tuple(point) for point in geo.floor_polygon]
    x0 = max(0, int(min(p[0] for p in corners)) - 3)
    x1 = min(geo.width, int(max(p[0] for p in corners)) + 4)
    y0 = max(0, int(min(p[1] for p in corners)) - 3)
    y1 = min(geo.height, int(max(p[1] for p in corners)) + 4)
    yy, xx = np.mgrid[y0:y1, x0:x1]
    a, b = geo.plan_arrays(xx.astype(np.float32), yy.astype(np.float32))
    polygon_mask = Image.new("L", (x1 - x0, y1 - y0), 0)
    ImageDraw.Draw(polygon_mask).polygon(
        [(point[0] - x0, point[1] - y0) for point in corners], fill=255
    )
    mask = np.asarray(polygon_mask, dtype=np.uint8) > 0

    # The source is sampled without independent x/y resizing.  Both floor axes
    # stay in manifest plan space and therefore land at the BG:EE ±0.75 lock.
    u = _mirror(b * 2.15)
    v = _mirror(a * 2.85)
    rgb = _bilinear(texture, u, v)
    edge = np.minimum.reduce([a, 1.0 - a, b, 1.0 - b])
    vignette = np.clip(edge / 0.18, 0.0, 1.0)
    rgb *= (0.72 + 0.20 * vignette)[..., None]
    rgb += np.array([1.0, 2.0, 4.0], dtype=np.float32)
    patch = canvas[y0:y1, x0:x1]
    patch[mask] = np.clip(rgb[mask], 0, 255).astype(np.uint8)


def _paint_wall(
    canvas: np.ndarray,
    texture: np.ndarray,
    polygon: list[list[float]],
    tint: tuple[float, float, float],
) -> None:
    # Wall faces are four-corner strips.  The earlier triangular faces tapered
    # to zero at each cutaway end and made the walls read as pieces of floor.
    # Raster the plaster through the measured crown/base quadrilateral instead.
    alpha = np.full(texture.shape[:2] + (1,), 255.0, dtype=np.float32)
    rgba = np.concatenate((texture, alpha), axis=2)
    _raster_rgba_quad(
        canvas,
        polygon,
        rgba,
        tint,
        uv_quad=[(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)],
    )


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


def _raster_rgba_triangle(
    canvas: np.ndarray,
    points: np.ndarray,
    texture: np.ndarray,
    uvs: np.ndarray,
    shade: tuple[float, float, float],
) -> None:
    coordinates = _triangle_coordinates(canvas.shape, points)
    if coordinates is None:
        return
    sy, sx, w0, w1, w2, mask = coordinates
    if not np.any(mask):
        return
    u = w0 * uvs[0, 0] + w1 * uvs[1, 0] + w2 * uvs[2, 0]
    v = w0 * uvs[0, 1] + w1 * uvs[1, 1] + w2 * uvs[2, 1]
    rgba = _bilinear(texture, u, v)
    rgb = rgba[:, :, :3] * np.asarray(shade, dtype=np.float32)
    alpha = np.clip(rgba[:, :, 3] / 255.0, 0.0, 1.0)
    alpha = np.where(mask, alpha, 0.0)
    patch = canvas[sy, sx].astype(np.float32)
    composed = rgb * alpha[..., None] + patch * (1.0 - alpha[..., None])
    canvas[sy, sx] = np.clip(composed, 0, 255).astype(np.uint8)


def _raster_rgba_quad(
    canvas: np.ndarray,
    quad: list[list[float]],
    texture: np.ndarray,
    shade: tuple[float, float, float],
    uv_quad: list[tuple[float, float]] | None = None,
) -> None:
    points = np.asarray(quad, dtype=np.float32)
    uvs = np.asarray(
        uv_quad or [(0, 0), (1, 0), (1, 1), (0, 1)],
        dtype=np.float32,
    )
    _raster_rgba_triangle(canvas, points[[0, 1, 2]], texture, uvs[[0, 1, 2]], shade)
    _raster_rgba_triangle(canvas, points[[0, 2, 3]], texture, uvs[[0, 2, 3]], shade)


def _draw_floor_grid(image: Image.Image, geo: Geometry) -> None:
    draw = ImageDraw.Draw(image, "RGBA")
    # Long plank seams follow one locked axis. Staggered board ends contribute
    # the other axis without turning the detective's floor into a square grid.
    rows = 40
    for index in range(1, rows):
        a = index / rows
        draw.line([geo.plan(a, 0), geo.plan(a, 1)], fill=(18, 18, 20, 94), width=2)
        if index % 3 == 0:
            draw.line([geo.plan(a, 0), geo.plan(a, 1)], fill=(107, 84, 59, 20), width=1)
    for row in range(rows):
        a0 = row / rows
        a1 = (row + 1) / rows
        joints = (0.19 + (row % 5) * 0.13, 0.78 - (row % 4) * 0.11)
        for b in joints:
            draw.line([geo.plan(a0, b), geo.plan(a1, b)], fill=(17, 17, 18, 115), width=2)


def _draw_wall_details(image: Image.Image, geo: Geometry) -> None:
    draw = ImageDraw.Draw(image, "RGBA")
    for polygon in geo.wall_polygons.values():
        crown0, crown1, base1, base0 = (tuple(point) for point in polygon)
        draw.line([crown0, crown1], fill=(22, 25, 27, 220), width=5)
        draw.line([base0, base1], fill=(18, 17, 18, 220), width=6)
        # 1950s institutional dado line, kept on the wall projection.
        dado0 = tuple(
            float(crown0[index] * 0.28 + base0[index] * 0.72)
            for index in range(2)
        )
        dado1 = base1
        draw.line([dado0, dado1], fill=(58, 62, 61, 150), width=4)


def _draw_fireplace_hearth(
    image: Image.Image,
    manifest: dict[str, object],
    *,
    fill: bool,
) -> None:
    draw = ImageDraw.Draw(image, "RGBA")
    footprint = [tuple(point) for point in manifest["fireplace"]["targetFloorFootprint"]]
    if fill:
        draw.polygon(footprint, fill=(33, 34, 34, 255))
    draw.line(footprint + [footprint[0]], fill=(82, 83, 79, 190), width=3)
    # Cold stone joints only: deliberately neutral, with no orange component.
    mid0 = tuple((np.asarray(footprint[0]) + np.asarray(footprint[3])) * 0.5)
    mid1 = tuple((np.asarray(footprint[1]) + np.asarray(footprint[2])) * 0.5)
    draw.line([mid0, mid1], fill=(18, 19, 19, 180), width=2)


def _graybox(manifest: dict[str, object], geo: Geometry) -> Image.Image:
    image = Image.new("RGB", (geo.width, geo.height), (0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.polygon([tuple(point) for point in geo.floor_polygon], fill=(68, 66, 64))
    for name, color in (("NW", (91, 97, 98)), ("NE", (82, 88, 90))):
        draw.polygon(
            [tuple(point) for point in geo.wall_polygons[name]], fill=color
        )
    _draw_fireplace_hearth(image, manifest, fill=True)
    return image


def _architecture_mask(graybox: Image.Image) -> Image.Image:
    rgb = np.asarray(graybox.convert("RGB"), dtype=np.uint8)
    return Image.fromarray(np.any(rgb != 0, axis=2).astype(np.uint8) * 255, "L")


def _glass_mask(manifest: dict[str, object], geo: Geometry) -> Image.Image:
    mask = Image.new("L", (geo.width, geo.height), 0)
    draw = ImageDraw.Draw(mask)
    for window in manifest["windows"]:
        for polygon in window["targetGlassPolygons"]:
            draw.polygon([tuple(point) for point in polygon], fill=255)
    alpha = np.asarray(mask.filter(ImageFilter.GaussianBlur(0.65)), dtype=np.uint8)
    rgba = np.zeros((geo.height, geo.width, 4), dtype=np.uint8)
    rgba[:, :, :3] = np.where(alpha[:, :, None] > 0, 255, 0)
    rgba[:, :, 3] = alpha
    return Image.fromarray(rgba, "RGBA")


def _near_hover(manifest: dict[str, object], geo: Geometry) -> Image.Image:
    overlay = Image.new("RGBA", (geo.width, geo.height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay, "RGBA")
    near = next(window for window in manifest["windows"] if window["id"] == "near")
    polygon = [tuple(point) for point in near["targetAperturePolygon"]]
    draw.polygon(polygon, fill=(24, 172, 184, 34))
    draw.line(polygon + [polygon[0]], fill=(43, 231, 238, 164), width=4, joint="curve")
    return overlay


def build_assets() -> dict[str, Image.Image]:
    manifest = load_geometry()
    geo = Geometry(manifest)
    required = (FLOOR_SOURCE, WALL_SOURCE, WINDOW_SOURCE, FIREPLACE_SOURCE)
    missing = [path.name for path in required if not path.exists()]
    if missing:
        raise RuntimeError(
            "missing normalized V11 sources: "
            + ", ".join(missing)
            + "; run ingest_office_1950s_sources_v11.py --install"
        )
    floor = _soft_source(FLOOR_SOURCE)
    wall = _soft_source(WALL_SOURCE)
    window = _locked_relief(WINDOW_SOURCE, target_slope=-0.75, target_height=297)
    fireplace = _locked_relief(
        FIREPLACE_SOURCE,
        target_slope=0.75,
        target_height=int(manifest["fireplace"]["reliefTargetHeight"]),
    )

    canvas = np.zeros((geo.height, geo.width, 3), dtype=np.uint8)
    _paint_floor(canvas, floor, geo)
    floor_image = Image.fromarray(canvas, "RGB").convert("RGBA")
    _draw_floor_grid(floor_image, geo)
    canvas = np.asarray(floor_image.convert("RGB"), dtype=np.uint8).copy()
    _paint_wall(canvas, wall, geo.wall_polygons["NW"], (0.84, 0.88, 0.88))
    _paint_wall(canvas, wall, geo.wall_polygons["NE"], (0.76, 0.80, 0.81))
    image = Image.fromarray(canvas, "RGB").convert("RGBA")
    _draw_wall_details(image, geo)
    # Relief fixtures arrive with their own reveals, top/return planes,
    # contact shadows, sills, and hearth.  They are camera-locked by affine
    # shear + uniform scale and composited as coherent objects; no facade quad
    # can flatten those depth cues back into the plaster.
    for fixture in manifest["windows"]:
        aperture = np.asarray(fixture["targetAperturePolygon"], dtype=np.float64)
        _composite_centered(image, window, tuple(aperture.mean(axis=0)))

    fireplace_points = np.asarray(
        manifest["fireplace"]["targetCoverPolygon"], dtype=np.float64
    )
    _composite_centered(image, fireplace, tuple(fireplace_points.mean(axis=0)))

    graybox = _graybox(manifest, geo)
    architecture_mask = _architecture_mask(graybox)
    final = np.asarray(image.convert("RGB"), dtype=np.uint8).copy()
    final[np.asarray(architecture_mask) == 0] = 0
    plate = Image.fromarray(final, "RGB")

    return {
        "plate": plate,
        "graybox": graybox,
        "architectureMask": architecture_mask,
        "glassMask": _glass_mask(manifest, geo),
        "nearHover": _near_hover(manifest, geo),
    }


def write_assets(output_dir: Path = STAGE) -> dict[str, Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    images = build_assets()
    paths: dict[str, Path] = {}
    for key, image in images.items():
        path = output_dir / FILENAMES[key]
        image.save(path, format="PNG", optimize=False)
        paths[key] = path

    manifest = load_geometry()
    metrics = {
        "version": "BGEE1950sV11",
        "geometryManifest": GEOMETRY_PATH.name,
        "canvas": manifest["canvas"],
        "environmentScale": manifest["environmentScale"],
        "referenceTransform": manifest["referenceTransform"],
        "room": manifest["room"],
        "windows": [
            {
                "id": window["id"],
                "role": window["role"],
                "aperture": window["targetAperturePolygon"],
                "glassPolygonCount": len(window["targetGlassPolygons"]),
            }
            for window in manifest["windows"]
        ],
        "fireplace": {
            "role": manifest["fireplace"]["role"],
            "projectionPolicy": manifest["fireplace"]["projectionPolicy"],
            "wallPlanRange": manifest["fireplace"]["wallPlanRange"],
            "facadeHeight": manifest["fireplace"]["facadeHeight"],
            "sourceFixtureAspect": manifest["fireplace"]["sourceFixtureAspect"],
            "reliefSourceAspect": manifest["fireplace"]["reliefSourceAspect"],
            "reliefTargetHeight": manifest["fireplace"]["reliefTargetHeight"],
            "wallPolygon": manifest["fireplace"]["targetWallPolygon"],
            "floorFootprint": manifest["fireplace"]["targetFloorFootprint"],
            "obstaclePolygon": manifest["fireplace"]["targetObstaclePolygon"],
            "coverPolygon": manifest["fireplace"]["targetCoverPolygon"],
        },
        "doorPixelsBakedIntoPlate": False,
        "flameOrEmberPixelsAuthored": False,
        "sourcePolicy": "original V11 sources only; reference screenshot contributes zero pixels",
        "sourceHashes": {
            path.name: sha256(path)
            for path in (FLOOR_SOURCE, WALL_SOURCE, WINDOW_SOURCE, FIREPLACE_SOURCE)
        },
        "outputHashes": {path.name: sha256(path) for path in paths.values()},
    }
    metrics_path = output_dir / FILENAMES["metrics"]
    metrics_path.write_text(json.dumps(metrics, indent=2) + "\n", encoding="utf-8")
    paths["metrics"] = metrics_path
    return paths


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, default=STAGE)
    args = parser.parse_args()
    paths = write_assets(args.output_dir.resolve())
    for path in paths.values():
        try:
            label = path.relative_to(ROOT)
        except ValueError:
            label = path
        print(f"wrote {label}")


if __name__ == "__main__":
    main()

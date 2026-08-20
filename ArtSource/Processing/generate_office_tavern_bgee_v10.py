"""Build the reference-locked V10 tavern-hall detective-office architecture.

Image generation supplies only flat material sources.  Every floor, wall,
pillar, stair and door-frame pixel is projected here so a generative pass
cannot change the camera, invent another room, or enlarge the sole entrance.
"""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import office_room_plan as rp


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "ArtSource/Generated/Office/BGEETavernV10"
OUT = SOURCE / "office_tavern_plate_v10.png"
GRAYBOX = SOURCE / "office_tavern_graybox_v10.png"
ARCHITECTURE_MASK = SOURCE / "office_tavern_architecture_mask_v10.png"
METRICS = SOURCE / "office_tavern_metrics_v10.json"
GEOMETRY = SOURCE / "office_v10_geometry.json"
FLOOR_SOURCE = SOURCE / "floor_material_source_v10.png"
WALL_SOURCE = SOURCE / "wall_material_source_v10.png"
COLUMN_SOURCE = SOURCE / "column_material_source_v10.png"

ART_W, ART_H = rp.ART_W, rp.ART_H
DOOR_CENTER_A = float(rp._DOOR["centerPlan"][0])
DOOR_OPENING_A = rp.BAKED_DOORWAY_W / rp.AXIS_NW_LEN
DOOR_A0 = DOOR_CENTER_A - DOOR_OPENING_A / 2.0
DOOR_A1 = DOOR_CENTER_A + DOOR_OPENING_A / 2.0
CUTAWAY_H = float(rp._ROOM["cutawayHeight"])
PILLARS = rp._PILLARS
STAIRS = rp._STAIRS


def _soft_source(path: Path, width: int = 960) -> np.ndarray:
    image = Image.open(path).convert("RGB")
    height = max(1, round(image.height * width / image.width))
    image = image.resize((width, height), Image.Resampling.LANCZOS)
    image = image.filter(ImageFilter.GaussianBlur(0.35))
    return np.asarray(image, dtype=np.float32)


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


def _plan_arrays(xs: np.ndarray, ys: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    m00, m10 = rp.AXIS_NW
    m01, m11 = rp.AXIS_NE
    det = m00 * m11 - m01 * m10
    dx = xs - rp.REAR[0]
    dy = ys - rp.REAR[1]
    a = (dx * m11 - m01 * dy) / det
    b = (m00 * dy - dx * m10) / det
    return a, b


def _paint_floor(canvas: np.ndarray, source: np.ndarray) -> None:
    corners = [rp.plan(0, 0), rp.plan(1, 0), rp.plan(1, 1), rp.plan(0, 1)]
    x0 = max(0, int(min(p[0] for p in corners)) - 2)
    x1 = min(ART_W, int(max(p[0] for p in corners)) + 3)
    y0 = max(0, int(min(p[1] for p in corners)) - 2)
    y1 = min(ART_H, int(max(p[1] for p in corners)) + 3)
    yy, xx = np.mgrid[y0:y1, x0:x1]
    a, b = _plan_arrays(xx.astype(np.float32), yy.astype(np.float32))
    mask = (a >= 0.0) & (a <= 1.0) & (b >= 0.0) & (b <= 1.0)

    u = _mirror(b * 2.35)
    v = _mirror(a * 3.40)
    rgb = _bilinear(source, u, v)

    edge = np.minimum.reduce([a, 1.0 - a, b, 1.0 - b])
    vignette = np.clip(edge / 0.22, 0.0, 1.0)
    rgb *= (0.82 + 0.18 * vignette)[..., None]
    rgb += np.array([10.0, 5.0, 0.0])
    patch = canvas[y0:y1, x0:x1]
    patch[mask] = np.clip(rgb[mask], 0, 255).astype(np.uint8)


def _paint_wall(
    canvas: np.ndarray,
    source: np.ndarray,
    axis: tuple[float, float],
    tint: tuple[float, float, float],
) -> None:
    rear_x, rear_y = rp.REAR
    end_x, end_y = rear_x + axis[0], rear_y + axis[1]
    x0 = max(0, int(min(rear_x, end_x)) - 2)
    x1 = min(ART_W, int(max(rear_x, end_x)) + 3)
    y0 = max(0, int(min(rear_y, end_y) - rp.WALL_FACE_H) - 2)
    y1 = min(ART_H, int(max(rear_y, end_y)) + 3)
    yy, xx = np.mgrid[y0:y1, x0:x1]
    if abs(axis[0]) < 1e-6:
        raise ValueError("wall axis must have a screen-x component")
    t = (xx - rear_x) / axis[0]
    base_y = rear_y + t * axis[1]
    z = base_y - yy
    mask = (t >= 0.0) & (t <= 1.0) & (z >= 0.0) & (z <= rp.WALL_FACE_H)
    u = _mirror(t * 1.55)
    v = np.clip(1.0 - z / rp.WALL_FACE_H, 0.0, 1.0)
    rgb = _bilinear(source, u, v)
    rgb *= np.array(tint, dtype=np.float32)
    rgb *= (0.74 + 0.20 * v)[..., None]
    patch = canvas[y0:y1, x0:x1]
    patch[mask] = np.clip(rgb[mask], 0, 255).astype(np.uint8)


def _draw_floor_seams(image: Image.Image) -> None:
    draw = ImageDraw.Draw(image, "RGBA")
    for row in range(1, 41):
        a = row / 41.0
        p0 = rp.plan(a, 0.0)
        p1 = rp.plan(a, 1.0)
        draw.line([p0, p1], fill=(10, 8, 7, 86), width=2)
        if row % 3 == 0:
            draw.line([p0, p1], fill=(121, 81, 42, 18), width=1)
    for row in range(40):
        a0 = row / 41.0
        a1 = (row + 1) / 41.0
        for joint in (0.24 + (row % 4) * 0.11, 0.73 - (row % 3) * 0.09):
            draw.line(
                [rp.plan(a0, joint), rp.plan(a1, joint)],
                fill=(13, 10, 8, 92),
                width=2,
            )


def _raster_triangle(
    canvas: np.ndarray,
    pts: np.ndarray,
    texture: np.ndarray,
    uvs: np.ndarray,
    shade: tuple[float, float, float],
) -> None:
    pts = np.asarray(pts, dtype=np.float32)
    uvs = np.asarray(uvs, dtype=np.float32)
    x0 = max(0, int(np.floor(pts[:, 0].min())))
    x1 = min(canvas.shape[1], int(np.ceil(pts[:, 0].max())) + 1)
    y0 = max(0, int(np.floor(pts[:, 1].min())))
    y1 = min(canvas.shape[0], int(np.ceil(pts[:, 1].max())) + 1)
    if x1 <= x0 or y1 <= y0:
        return
    v0 = pts[1] - pts[0]
    v1 = pts[2] - pts[0]
    den = float(v0[0] * v1[1] - v1[0] * v0[1])
    if abs(den) < 1e-6:
        return
    yy, xx = np.mgrid[y0:y1, x0:x1]
    v2x = xx.astype(np.float32) - pts[0, 0]
    v2y = yy.astype(np.float32) - pts[0, 1]
    w1 = (v2x * v1[1] - v1[0] * v2y) / den
    w2 = (v0[0] * v2y - v2x * v0[1]) / den
    w0 = 1.0 - w1 - w2
    mask = (w0 >= -0.001) & (w1 >= -0.001) & (w2 >= -0.001)
    if not np.any(mask):
        return
    u = np.clip(w0 * uvs[0, 0] + w1 * uvs[1, 0] + w2 * uvs[2, 0], 0.0, 1.0)
    v = np.clip(w0 * uvs[0, 1] + w1 * uvs[1, 1] + w2 * uvs[2, 1], 0.0, 1.0)
    rgb = _bilinear(texture, u, v) * np.array(shade, dtype=np.float32)
    patch = canvas[y0:y1, x0:x1]
    patch[mask] = np.clip(rgb[mask], 0, 255).astype(np.uint8)


def _raster_quad(
    canvas: np.ndarray,
    quad: list[tuple[float, float]],
    texture: np.ndarray,
    uv_quad: list[tuple[float, float]],
    shade: tuple[float, float, float],
) -> None:
    pts = np.asarray(quad, dtype=np.float32)
    uvs = np.asarray(uv_quad, dtype=np.float32)
    _raster_triangle(canvas, pts[[0, 1, 2]], texture, uvs[[0, 1, 2]], shade)
    _raster_triangle(canvas, pts[[0, 2, 3]], texture, uvs[[0, 2, 3]], shade)


def _paint_cutaway_segment(
    canvas: np.ndarray,
    wall: np.ndarray,
    start: tuple[float, float],
    end: tuple[float, float],
    u0: float,
    u1: float,
) -> None:
    top0 = (start[0], start[1] - CUTAWAY_H)
    top1 = (end[0], end[1] - CUTAWAY_H)
    _raster_quad(
        canvas,
        [start, end, top1, top0],
        wall,
        [(u0, 1.0), (u1, 1.0), (u1, 0.82), (u0, 0.82)],
        (0.62, 0.55, 0.46),
    )


def _paint_cutaways(canvas: np.ndarray, wall: np.ndarray) -> None:
    _paint_cutaway_segment(canvas, wall, rp.plan(1.0, 0.0), rp.plan(1.0, 1.0), 0.02, 0.98)
    _paint_cutaway_segment(canvas, wall, rp.plan(0.0, 1.0), rp.plan(DOOR_A0, 1.0), 0.04, 0.42)
    _paint_cutaway_segment(canvas, wall, rp.plan(DOOR_A1, 1.0), rp.plan(1.0, 1.0), 0.58, 0.96)


def _cutaway_segment(
    draw: ImageDraw.ImageDraw,
    start: tuple[float, float],
    end: tuple[float, float],
) -> None:
    top0 = (start[0], start[1] - CUTAWAY_H)
    top1 = (end[0], end[1] - CUTAWAY_H)
    draw.polygon([start, end, top1, top0], fill=(35, 27, 22, 255))
    draw.line([top0, top1], fill=(92, 63, 39, 230), width=4)
    draw.line([start, end], fill=(7, 6, 6, 230), width=3)


def _draw_cutaways_and_threshold(image: Image.Image) -> None:
    draw = ImageDraw.Draw(image, "RGBA")
    _cutaway_segment(draw, rp.plan(1.0, 0.0), rp.plan(1.0, 1.0))
    _cutaway_segment(draw, rp.plan(0.0, 1.0), rp.plan(DOOR_A0, 1.0))
    _cutaway_segment(draw, rp.plan(DOOR_A1, 1.0), rp.plan(1.0, 1.0))
    _draw_threshold(draw)


def _draw_threshold(draw: ImageDraw.ImageDraw) -> None:
    hinge = rp.plan(DOOR_A0, 1.0)
    latch = rp.plan(DOOR_A1, 1.0)
    draw.line([hinge, latch], fill=(39, 27, 20, 255), width=8)
    draw.line([hinge, latch], fill=(148, 96, 52, 160), width=2)
    hx, hy = hinge
    draw.polygon(
        [(hx - 4, hy + 1), (hx + 5, hy - 5), (hx + 5, hy - 18), (hx - 4, hy - 12)],
        fill=(48, 32, 22, 255),
    )


def _pillar_quad(a: float, b: float, ha: float, hb: float) -> list[tuple[float, float]]:
    return [
        rp.plan(a - ha, b - hb),
        rp.plan(a + ha, b - hb),
        rp.plan(a + ha, b + hb),
        rp.plan(a - ha, b + hb),
    ]


def _draw_box(
    draw: ImageDraw.ImageDraw,
    a: float,
    b: float,
    ha: float,
    hb: float,
    height: float,
    face: tuple[int, int, int, int],
    side: tuple[int, int, int, int],
    top: tuple[int, int, int, int],
) -> None:
    floor = _pillar_quad(a, b, ha, hb)
    crown = [(x, y - height) for x, y in floor]
    # Visible faces: NE (east) and NW (west-near) in painter's order.
    ne = [floor[2], floor[1], crown[1], crown[2]]
    nw = [floor[3], floor[2], crown[2], crown[3]]
    draw.polygon(ne, fill=side)
    draw.polygon(nw, fill=face)
    draw.polygon(crown, fill=top)


def _paint_box(
    canvas: np.ndarray,
    texture: np.ndarray,
    a: float,
    b: float,
    ha: float,
    hb: float,
    height: float,
    u_origin: float,
) -> None:
    floor = _pillar_quad(a, b, ha, hb)
    crown = [(x, y - height) for x, y in floor]
    ne = [floor[2], floor[1], crown[1], crown[2]]
    nw = [floor[3], floor[2], crown[2], crown[3]]
    u0 = u_origin % 1.0
    _raster_quad(
        canvas,
        ne,
        texture,
        [(u0, 1.0), (u0 + 0.18, 1.0), (u0 + 0.18, 0.0), (u0, 0.0)],
        (0.70, 0.62, 0.52),
    )
    _raster_quad(
        canvas,
        nw,
        texture,
        [(u0 + 0.22, 1.0), (u0 + 0.40, 1.0), (u0 + 0.40, 0.0), (u0 + 0.22, 0.0)],
        (1.05, 0.96, 0.82),
    )
    _raster_quad(
        canvas,
        crown,
        texture,
        [(u0, 0.08), (u0 + 0.22, 0.08), (u0 + 0.22, 0.28), (u0, 0.28)],
        (1.18, 1.08, 0.90),
    )


def _paint_pillars(canvas: np.ndarray, column: np.ndarray) -> None:
    ordered = sorted(PILLARS, key=lambda p: p["plan"][0] + p["plan"][1])
    for index, pillar in enumerate(ordered):
        a, b = pillar["plan"]
        ha, hb = pillar["half"]
        _paint_box(
            canvas,
            column,
            a,
            b,
            ha,
            hb,
            float(pillar["height"]),
            0.07 * index,
        )


def _paint_stairs(canvas: np.ndarray, floor: np.ndarray, wall: np.ndarray) -> None:
    a0, b0, a1, b1 = STAIRS["planBox"]
    steps = int(STAIRS["steps"])
    rise = float(STAIRS["rise"])
    for i in range(steps):
        t0 = i / steps
        t1 = (i + 1) / steps
        aa0 = a0 + (a1 - a0) * t0
        aa1 = a0 + (a1 - a0) * t1
        height = rise * (i + 1)
        quad = [
            rp.plan(aa0, b0),
            rp.plan(aa1, b0),
            rp.plan(aa1, b1),
            rp.plan(aa0, b1),
        ]
        lifted = [(x, y - height) for x, y in quad]
        riser = [quad[0], quad[3], lifted[3], lifted[0]]
        _raster_quad(
            canvas,
            riser,
            wall,
            [(t0, 1.0), (t1, 1.0), (t1, 0.55), (t0, 0.55)],
            (0.70, 0.62, 0.50),
        )
        near_side = [quad[3], quad[2], lifted[2], lifted[3]]
        _raster_quad(
            canvas,
            near_side,
            wall,
            [(0.08, 1.0), (0.40, 1.0), (0.40, 0.40), (0.08, 0.40)],
            (0.88, 0.78, 0.62),
        )
        _raster_quad(
            canvas,
            lifted,
            floor,
            [(t0, 0.12), (t1, 0.12), (t1, 0.42), (t0, 0.42)],
            (1.02, 0.92, 0.74),
        )


def _draw_pillars(image: Image.Image) -> None:
    draw = ImageDraw.Draw(image, "RGBA")
    ordered = sorted(PILLARS, key=lambda p: p["plan"][0] + p["plan"][1])
    for pillar in ordered:
        a, b = pillar["plan"]
        ha, hb = pillar["half"]
        _draw_box(
            draw,
            a,
            b,
            ha,
            hb,
            float(pillar["height"]),
            face=(78, 64, 48, 255),
            side=(58, 46, 36, 255),
            top=(96, 80, 60, 255),
        )


def _draw_stairs(image: Image.Image) -> None:
    draw = ImageDraw.Draw(image, "RGBA")
    a0, b0, a1, b1 = STAIRS["planBox"]
    steps = int(STAIRS["steps"])
    rise = float(STAIRS["rise"])
    for i in range(steps):
        t0 = i / steps
        t1 = (i + 1) / steps
        aa0 = a0 + (a1 - a0) * t0
        aa1 = a0 + (a1 - a0) * t1
        height = rise * (i + 1)
        quad = [
            rp.plan(aa0, b0),
            rp.plan(aa1, b0),
            rp.plan(aa1, b1),
            rp.plan(aa0, b1),
        ]
        lifted = [(x, y - height) for x, y in quad]
        riser = [quad[0], quad[3], lifted[3], lifted[0]]
        draw.polygon(riser, fill=(52, 38, 28, 255))
        draw.polygon(lifted, fill=(92, 70, 48, 255))
        draw.line([lifted[0], lifted[1]], fill=(28, 20, 14, 220), width=2)
    rail0 = rp.plan(a0, b1)
    rail1 = rp.plan(a1, b1)
    draw.line(
        [(rail0[0], rail0[1] - rise), (rail1[0], rail1[1] - rise * steps)],
        fill=(118, 92, 64, 240),
        width=3,
    )


def _draw_stair_rail(image: Image.Image) -> None:
    draw = ImageDraw.Draw(image, "RGBA")
    a0, b0, a1, b1 = STAIRS["planBox"]
    rise = float(STAIRS["rise"])
    steps = int(STAIRS["steps"])
    rail0 = rp.plan(a0, b1)
    rail1 = rp.plan(a1, b1)
    draw.line(
        [(rail0[0], rail0[1] - rise), (rail1[0], rail1[1] - rise * steps)],
        fill=(118, 92, 64, 210),
        width=3,
    )


def _graybox() -> Image.Image:
    image = Image.new("RGBA", (ART_W, ART_H), (0, 0, 0, 255))
    draw = ImageDraw.Draw(image, "RGBA")
    floor = [rp.plan(0, 0), rp.plan(1, 0), rp.plan(1, 1), rp.plan(0, 1)]
    draw.polygon(floor, fill=(68, 58, 50, 255))
    for axis, color in ((rp.AXIS_NW, (78, 96, 104, 255)), (rp.AXIS_NE, (96, 87, 72, 255))):
        end = (rp.REAR[0] + axis[0], rp.REAR[1] + axis[1])
        draw.polygon(
            [rp.REAR, end, (end[0], end[1] - rp.WALL_FACE_H), (rp.REAR[0], rp.REAR[1] - rp.WALL_FACE_H)],
            fill=color,
        )
    for i in range(9):
        t = i / 8
        draw.line([rp.plan(t, 0), rp.plan(t, 1)], fill=(126, 141, 154, 180), width=2)
        draw.line([rp.plan(0, t), rp.plan(1, t)], fill=(126, 141, 154, 180), width=2)
    _draw_pillars(image)
    _draw_stairs(image)
    _draw_cutaways_and_threshold(image)
    return image


def _architecture_mask(graybox: Image.Image) -> Image.Image:
    rgb = np.asarray(graybox.convert("RGB"), dtype=np.uint8)
    mask = np.any(rgb != 0, axis=2).astype(np.uint8) * 255
    return Image.fromarray(mask, "L")


def main() -> None:
    missing = [path.name for path in (FLOOR_SOURCE, WALL_SOURCE, COLUMN_SOURCE) if not path.exists()]
    if missing:
        raise SystemExit("missing material sources for V10: " + ", ".join(missing))
    SOURCE.mkdir(parents=True, exist_ok=True)
    floor = _soft_source(FLOOR_SOURCE)
    wall = _soft_source(WALL_SOURCE)
    column = np.clip(_soft_source(COLUMN_SOURCE) * 1.55 + 28.0, 0, 255)

    canvas = np.zeros((ART_H, ART_W, 3), dtype=np.uint8)
    _paint_floor(canvas, floor)
    _paint_wall(canvas, wall, rp.AXIS_NW, (0.88, 0.82, 0.74))
    _paint_wall(canvas, wall, rp.AXIS_NE, (1.02, 0.92, 0.78))
    _paint_stairs(canvas, floor, wall)
    _paint_pillars(canvas, column)
    _paint_cutaways(canvas, wall)
    image = Image.fromarray(canvas, "RGB").convert("RGBA")
    _draw_stair_rail(image)
    _draw_threshold(ImageDraw.Draw(image, "RGBA"))
    image = image.convert("RGB")
    graybox = _graybox()
    mask = _architecture_mask(graybox)
    final = np.asarray(image.convert("RGB"), dtype=np.uint8).copy()
    final[np.asarray(mask) == 0] = 0
    Image.fromarray(final, "RGB").save(OUT)
    graybox.convert("RGB").save(GRAYBOX)
    mask.save(ARCHITECTURE_MASK)

    metrics = {
        "version": "BGEETavernV10",
        "geometryManifest": GEOMETRY.name,
        "canvas": [ART_W, ART_H],
        "rear": list(rp.REAR),
        "axisNW": list(rp.AXIS_NW),
        "axisNE": list(rp.AXIS_NE),
        "axisAnglesDegrees": [-36.86989765, 36.86989765],
        "wallFaceHeight": rp.WALL_FACE_H,
        "door": {
            "edge": "camera-near-right/b=1",
            "centerA": DOOR_CENTER_A,
            "openingA": DOOR_OPENING_A,
            "openingPixels": [rp.BAKED_DOORWAY_W, rp.BAKED_DOORWAY_H],
            "threshold0": list(rp.plan(DOOR_A0, 1.0)),
            "threshold1": list(rp.plan(DOOR_A1, 1.0)),
        },
        "architectureMask": ARCHITECTURE_MASK.name,
        "imageGenSources": [FLOOR_SOURCE.name, WALL_SOURCE.name, COLUMN_SOURCE.name],
        "sourcePolicy": "original materials only; no reference screenshot pixels",
    }
    METRICS.write_text(json.dumps(metrics, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)}")
    print(f"wrote {GRAYBOX.relative_to(ROOT)}")
    print(f"wrote {ARCHITECTURE_MASK.relative_to(ROOT)}")
    print(f"wrote {METRICS.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

"""Build the open-plan detective-office plate on the BG:EE projection lock.

Image generation supplies only flat material sources.  Every floor, wall and
door-frame pixel is projected here so a generative pass cannot change the
camera, invent another room, or move the sole entrance.
"""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import office_room_plan as rp


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "ArtSource/Generated/Office/BGEEOpenPlanV08"
OUT = SOURCE / "office_open_plan_plate_v08.png"
GRAYBOX = SOURCE / "office_open_plan_graybox_v08.png"
METRICS = SOURCE / "office_open_plan_metrics_v08.json"
FLOOR_SOURCE = SOURCE / "floor_material_source_v08.png"
WALL_SOURCE = SOURCE / "wall_material_source_v08.png"

ART_W, ART_H = rp.ART_W, rp.ART_H
DOOR_CENTER_A = 0.180
DOOR_OPENING_A = rp.BAKED_DOORWAY_W / rp.AXIS_NW_LEN
DOOR_A0 = DOOR_CENTER_A - DOOR_OPENING_A / 2.0
DOOR_A1 = DOOR_CENTER_A + DOOR_OPENING_A / 2.0
DOOR_H = rp.BAKED_DOORWAY_H
CUTAWAY_H = 24.0


def _soft_source(path: Path, width: int = 640) -> np.ndarray:
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

    # The source is flat.  Map it into plan space and repeat/mirror it so the
    # finished board scale stays close to the actor sprites instead of reading
    # as a magnified texture photograph.
    u = _mirror(b * 2.15)
    v = _mirror(a * 3.10)
    rgb = _bilinear(source, u, v)

    # Localised noir light is also authored in plan space, so it cannot skew
    # the projection lines.
    warm = np.exp(-(((a - 0.57) / 0.30) ** 2 + ((b - 0.40) / 0.23) ** 2))
    cool = np.exp(-(((a - 0.62) / 0.28) ** 2 + ((b - 0.05) / 0.22) ** 2))
    edge = np.minimum.reduce([a, 1.0 - a, b, 1.0 - b])
    vignette = np.clip(edge / 0.16, 0.0, 1.0)
    rgb *= (0.56 + 0.34 * vignette)[..., None]
    rgb += warm[..., None] * np.array([35.0, 22.0, 7.0])
    rgb += cool[..., None] * np.array([2.0, 14.0, 28.0])
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
    # Upper corners stay subdued; wall shoes receive a small reflected lift.
    rgb *= (0.74 + 0.20 * v)[..., None]
    patch = canvas[y0:y1, x0:x1]
    patch[mask] = np.clip(rgb[mask], 0, 255).astype(np.uint8)


def _draw_floor_seams(image: Image.Image) -> None:
    draw = ImageDraw.Draw(image, "RGBA")
    # Long seams follow AXIS_NE exactly (+36.87 degrees).
    for row in range(1, 37):
        a = row / 37.0
        p0 = rp.plan(a, 0.0)
        p1 = rp.plan(a, 1.0)
        draw.line([p0, p1], fill=(10, 8, 7, 86), width=2)
        if row % 3 == 0:
            draw.line([p0, p1], fill=(121, 81, 42, 18), width=1)
    # Staggered butt joints follow AXIS_NW exactly (-36.87 degrees).
    for row in range(36):
        a0 = row / 37.0
        a1 = (row + 1) / 37.0
        for joint in (0.24 + (row % 4) * 0.11, 0.73 - (row % 3) * 0.09):
            draw.line(
                [rp.plan(a0, joint), rp.plan(a1, joint)],
                fill=(13, 10, 8, 92),
                width=2,
            )


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
    # Camera-near west edge remains a low uninterrupted cutaway.
    _cutaway_segment(draw, rp.plan(1.0, 0.0), rp.plan(1.0, 1.0))
    # Camera-near right edge is interrupted only by the sole exterior opening.
    _cutaway_segment(draw, rp.plan(0.0, 1.0), rp.plan(DOOR_A0, 1.0))
    _cutaway_segment(draw, rp.plan(DOOR_A1, 1.0), rp.plan(1.0, 1.0))

    hinge = rp.plan(DOOR_A0, 1.0)
    latch = rp.plan(DOOR_A1, 1.0)
    # The BG:EE reference does not read as a freestanding door-shaped frame.
    # The cutaway break, worn sill and one low hinge block are the entire baked
    # architectural cue; the upright open leaf is a separate live sprite.
    draw.line([hinge, latch], fill=(39, 27, 20, 255), width=12)
    draw.line([hinge, latch], fill=(116, 72, 36, 205), width=3)
    hx, hy = hinge
    draw.polygon(
        [(hx - 6, hy + 2), (hx + 7, hy - 7), (hx + 7, hy - 28), (hx - 6, hy - 19)],
        fill=(45, 30, 22, 255),
    )
    draw.line([(hx - 5, hy - 19), (hx + 7, hy - 28)], fill=(113, 72, 39, 220), width=2)

    # A thin hall glow lies outside the threshold; it is not a second room.
    outer0 = rp.plan(DOOR_A0 + 0.012, 1.0)
    outer1 = rp.plan(DOOR_A1 - 0.012, 1.0)
    far0 = (outer0[0] + 52.0, outer0[1] + 39.0)
    far1 = (outer1[0] + 52.0, outer1[1] + 39.0)
    glow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow, "RGBA")
    glow_draw.polygon([outer0, outer1, far1, far0], fill=(156, 91, 31, 78))
    glow = glow.filter(ImageFilter.GaussianBlur(8.0))
    image.alpha_composite(glow)


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
    _draw_cutaways_and_threshold(image)
    return image


def main() -> None:
    if not FLOOR_SOURCE.exists() or not WALL_SOURCE.exists():
        raise SystemExit("missing ImageGen material sources for V08")
    SOURCE.mkdir(parents=True, exist_ok=True)
    floor = _soft_source(FLOOR_SOURCE)
    wall = _soft_source(WALL_SOURCE)

    canvas = np.zeros((ART_H, ART_W, 3), dtype=np.uint8)
    _paint_floor(canvas, floor)
    _paint_wall(canvas, wall, rp.AXIS_NW, (0.76, 0.82, 0.88))
    _paint_wall(canvas, wall, rp.AXIS_NE, (0.91, 0.82, 0.72))
    image = Image.fromarray(canvas, "RGB").convert("RGBA")
    _draw_floor_seams(image)
    _draw_cutaways_and_threshold(image)
    image = image.convert("RGB")
    image.save(OUT)
    _graybox().convert("RGB").save(GRAYBOX)

    metrics = {
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
        "imageGenSources": [FLOOR_SOURCE.name, WALL_SOURCE.name],
    }
    METRICS.write_text(json.dumps(metrics, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)}")
    print(f"wrote {GRAYBOX.relative_to(ROOT)}")
    print(f"wrote {METRICS.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

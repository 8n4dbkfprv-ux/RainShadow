#!/usr/bin/env python3
"""Pixel- and relationship-level QA for the furnished V13 office."""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import office_layout_plan as layout
import office_room_plan as room


ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "RainShadow Shared/Resources/Art"
STAGE = ROOT / "ArtSource/Generated/Office/BGEEReferenceV13"
BASE_PLATE = STAGE / "office_reference_rebuild_plate_v13.png"
METRICS = STAGE / "office_reference_rebuild_metrics_v13.json"
PROPS = ROOT / "ArtSource/Generated/Office/office_props_v01.json"

CRITICAL_WALL_AND_SUPPORT_PROPS = {
    "office_wall_photos",
    "office_case_board",
    "office_wall_city_map",
    "office_framed_licence",
    "office_radiator",
    "office_bookshelf",
    "office_filing_cabinet_open",
    "office_filing_cabinet",
    "office_safe",
    "office_archive_box_b",
    "office_archive_stack",
    "office_personal_sideboard",
    "office_hidden_bottle",
    "office_personal_glass",
    "office_personal_fan",
}

SUPPORT_PAIRS = (
    ("office_filing_cabinet", "office_archive_box_b"),
    ("office_filing_cabinet_open", "office_archive_stack"),
    ("office_personal_sideboard", "office_hidden_bottle"),
    ("office_personal_sideboard", "office_personal_glass"),
    ("office_waiting_table", "office_newspaper"),
    ("office_waiting_table", "office_waiting_ashtray"),
)


def _texture(name: str) -> Path:
    matches = list(ART.rglob(f"{name}.png"))
    if len(matches) != 1:
        raise RuntimeError(f"expected one texture for {name}, found {len(matches)}")
    return matches[0]


def _rendered_alpha(prop: dict) -> tuple[np.ndarray, int, int]:
    image = Image.open(_texture(prop["textureName"])).convert("RGBA")
    scale_x = float(prop.get("scaleX", prop.get("scale", 1.0))) / room.ENVIRONMENT_SCALE
    scale_y = float(prop.get("scaleY", prop.get("scale", 1.0))) / room.ENVIRONMENT_SCALE
    width = max(1, round(image.width * scale_x))
    height = max(1, round(image.height * scale_y))
    alpha = np.asarray(
        image.resize((width, height), Image.Resampling.LANCZOS)
    )[:, :, 3]

    point = prop["groundPoint"]
    authored_x = 2_048 + (float(point["x"]) - 2_048) / room.ENVIRONMENT_SCALE
    authored_y = 1_152 + (float(point["y"]) - 1_152) / room.ENVIRONMENT_SCALE
    left = round(authored_x - width * float(prop.get("anchorX", 0.5)))
    top = round(
        room.ART_H
        - authored_y
        - height * (1.0 - float(prop["anchorY"]))
    )
    return alpha, left, top


def _opaque_bbox(prop: dict) -> tuple[int, int, int, int]:
    alpha, left, top = _rendered_alpha(prop)
    ys, xs = np.where(alpha > 16)
    return (
        left + int(xs.min()),
        top + int(ys.min()),
        left + int(xs.max()) + 1,
        top + int(ys.max()) + 1,
    )


def _outside_and_window_pixels(
    prop: dict,
    exterior: np.ndarray,
    windows: np.ndarray,
) -> tuple[int, int]:
    alpha, left, top = _rendered_alpha(prop)
    height, width = alpha.shape
    x0, y0 = max(0, left), max(0, top)
    x1, y1 = min(room.ART_W, left + width), min(room.ART_H, top + height)
    opaque_total = int(np.count_nonzero(alpha > 16))
    if x1 <= x0 or y1 <= y0:
        return opaque_total, 0
    opaque = alpha[y0 - top : y1 - top, x0 - left : x1 - left] > 16
    clipped = opaque_total - int(np.count_nonzero(opaque))
    outside = clipped + int(np.count_nonzero(opaque & exterior[y0:y1, x0:x1]))
    window = int(np.count_nonzero(opaque & windows[y0:y1, x0:x1]))
    return outside, window


def main() -> int:
    metrics = json.loads(METRICS.read_text(encoding="utf-8"))
    room_image = Image.new("1", (room.ART_W, room.ART_H), 0)
    room_draw = ImageDraw.Draw(room_image)
    for polygon in metrics["registration"]["targetPlanes"].values():
        room_draw.polygon([tuple(point) for point in polygon], fill=1)
    exterior = ~np.asarray(room_image, dtype=bool)
    window_image = Image.new("1", (room.ART_W, room.ART_H), 0)
    window_draw = ImageDraw.Draw(window_image)
    for window in metrics["windows"]:
        window_draw.polygon([tuple(point) for point in window["aperture"]], fill=1)
    windows = np.asarray(window_image, dtype=bool)

    props = json.loads(PROPS.read_text(encoding="utf-8"))["props"]
    by_id = {prop["id"]: prop for prop in props}
    missing = CRITICAL_WALL_AND_SUPPORT_PROPS - set(by_id)
    if missing:
        raise RuntimeError(f"critical V13 props missing: {sorted(missing)}")

    outside_total = 0
    window_total = 0
    for prop_id in sorted(CRITICAL_WALL_AND_SUPPORT_PROPS):
        outside, window = _outside_and_window_pixels(
            by_id[prop_id], exterior, windows
        )
        outside_total += outside
        window_total += window

    raster_ok = outside_total == 0 and window_total == 0
    print(
        f"{'PASS' if raster_ok else 'FAIL'}  static props stay on painted room and clear windows: "
        f"outside={outside_total} apertureOverlap={window_total}"
    )

    support_ok = True
    worst_gap = 0
    for parent_id, child_id in SUPPORT_PAIRS:
        parent = _opaque_bbox(by_id[parent_id])
        child = _opaque_bbox(by_id[child_id])
        gap = child[3] - parent[1]
        horizontal_overlap = min(parent[2], child[2]) - max(parent[0], child[0])
        support_ok &= abs(gap) <= 1 and horizontal_overlap > 0
        worst_gap = max(worst_gap, abs(gap))
    print(
        f"{'PASS' if support_ok else 'FAIL'}  surface props contact their supports: "
        f"worstOpaqueEdgeGap={worst_gap}px"
    )

    desk = layout.PROP_BY_KEY["deskEnsemble"].obstacle_rect
    chair = layout.PROP_BY_KEY["deskChair"].obstacle_rect
    dx, dy, dw, dh = desk
    cx, cy, cw, ch = chair
    chair_clear = not (
        dx < cx + cw and cx < dx + dw and dy < cy + ch and cy < dy + dh
    )
    print(
        f"{'PASS' if chair_clear else 'FAIL'}  Voss chair clears desk footprint"
    )

    passed = raster_ok and support_ok and chair_clear
    print(f"\nALL_PASS={passed}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())

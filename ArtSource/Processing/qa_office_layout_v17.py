#!/usr/bin/env python3
"""Raster QA for props registered onto the AR0809-exact V17 shell."""

from __future__ import annotations

import json

import numpy as np
from PIL import Image, ImageDraw

import office_layout_plan as layout
import qa_office_layout_v14 as shared


ROOT = shared.ROOT
STAGE = ROOT / "ArtSource/Generated/Office/BGEEReferenceV17"
ARCHITECTURE = STAGE / "office_reference_rebuild_architecture_mask_v17.png"
METRICS = STAGE / "office_reference_rebuild_metrics_v17.json"
PROPS = ROOT / "ArtSource/Generated/Office/office_props_v01.json"


def main() -> int:
    architecture = np.asarray(Image.open(ARCHITECTURE).convert("L")) > 0
    exterior = ~architecture
    metrics = json.loads(METRICS.read_text(encoding="utf-8"))
    window_image = Image.new("1", (shared.room.ART_W, shared.room.ART_H), 0)
    window_draw = ImageDraw.Draw(window_image)
    for window in metrics["windows"]:
        window_draw.polygon([tuple(point) for point in window["aperture"]], fill=1)
    windows = np.asarray(window_image, dtype=bool)

    props = json.loads(PROPS.read_text(encoding="utf-8"))["props"]
    by_id = {prop["id"]: prop for prop in props}
    missing = shared.CRITICAL_WALL_AND_SUPPORT_PROPS - set(by_id)
    if missing:
        raise RuntimeError(f"critical V17 props missing: {sorted(missing)}")

    outside_total = 0
    window_total = 0
    for prop_id in sorted(shared.CRITICAL_WALL_AND_SUPPORT_PROPS):
        outside, window = shared._outside_and_window_pixels(by_id[prop_id], exterior, windows)
        outside_total += outside
        window_total += window
    raster_ok = outside_total <= 64 and window_total == 0
    print(
        f"{'PASS' if raster_ok else 'FAIL'}  static props stay on AR0809 room and clear windows: "
        f"outsideFringe={outside_total} apertureOverlap={window_total}"
    )

    support_ok = True
    worst_gap = 0
    for parent_id, child_id in shared.SUPPORT_PAIRS:
        parent = shared._opaque_bbox(by_id[parent_id])
        child = shared._opaque_bbox(by_id[child_id])
        gap = child[3] - parent[1]
        overlap = min(parent[2], child[2]) - max(parent[0], child[0])
        support_ok &= abs(gap) <= 1 and overlap > 0
        worst_gap = max(worst_gap, abs(gap))
    print(
        f"{'PASS' if support_ok else 'FAIL'}  surface props contact supports: "
        f"worstOpaqueEdgeGap={worst_gap}px"
    )

    desk = layout.PROP_BY_KEY["deskEnsemble"].obstacle_rect
    chair = layout.PROP_BY_KEY["deskChair"].obstacle_rect
    dx, dy, dw, dh = desk
    cx, cy, cw, ch = chair
    chair_clear = not (dx < cx + cw and cx < dx + dw and dy < cy + ch and cy < dy + dh)
    print(f"{'PASS' if chair_clear else 'FAIL'}  Voss chair clears desk footprint")

    passed = raster_ok and support_ok and chair_clear
    print(f"\nALL_PASS={passed}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())

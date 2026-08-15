#!/usr/bin/env python3
"""Proportion-lock the on-lock V5 office: same floor, human-scale walls.

V5 is on the Baldur's Gate: EE camera (3.81°) but the painted wall face at
the exterior door column is a warehouse: 369 px wall, 198 px clear opening,
171 px of blank plaster above the lintel (door/wall 54%, implied ceiling
3.78 m). New generated plates that shortened the walls missed the 4° ground
lock because the generator copied the cathedral height.

This installer re-places the V5 master (uniform 3:2 contain, same as
`install_office_bgee_v05.py`) and compresses only the plaster band above a
fixed lintel plane. Floorboards, wainscot, door openings, and wall shoes
stay put, so the ground axes stay on lock. Target at the door column:

    door / wall ≈ 73%
    plaster above lintel ≈ 73 px (one head, not a whole extra adult)

Does not flip `ie_projection.ACTIVE` and does not write Swift. Floor
diamond is unchanged; update `WALL_FACE_H` / `BAKED_DOORWAY_H` in
`office_room_plan.py` after the overlay is accepted.

Usage:
    python3 ArtSource/Processing/install_office_bgee_v07.py
    python3 ArtSource/Processing/install_office_bgee_v07.py --scale 0.60
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import office_room_plan as rp
import qa_plate_projection as qa
from install_office_bgee_v05 import (
    AREAS,
    ART_H,
    ART_W,
    GEN,
    SRC,
    draw_overlay,
    measure_openings,
    place_plate,
    room_bbox,
)

# Floor diamond is the V5 shoe fit. Compressing the plaster band must not
# re-solve it from the new silhouette — that pulls REAR onto the dropped crown.
V5_DIAMOND = {
    "REAR": [1934.3, 389.2],
    "AXIS_NW": [-863.2, 647.4],
    "AXIS_NE": [1028.8, 771.6],
    "west": [1071.1, 1036.6],
    "east": [2963.1, 1160.8],
    "near": [2099.9, 1808.2],
}

ROOT = Path(__file__).resolve().parents[2]

# Measured on the V5 install at the exterior door column (x≈2820):
# wall face 369, clear opening 198, plaster above lintel 166–171.
# Door stays; plaster band compresses so door/wall ≈ 73%.
V5_PLASTER_ABOVE = 166
V5_CLEAR_OPENING = 198
TARGET_DOOR_WALL = 0.73
TARGET_PLASTER_ABOVE = int(round(V5_CLEAR_OPENING / TARGET_DOOR_WALL - V5_CLEAR_OPENING))


def compress_plaster_band(
    rgb: np.ndarray,
    *,
    old_above: int = V5_PLASTER_ABOVE,
    new_above: int = TARGET_PLASTER_ABOVE,
) -> np.ndarray:
    """Shorten the wall crown. Never write into a detected door opening."""
    h, w = rgb.shape[:2]
    lum = rgb.mean(2)
    painted = lum > 14
    out = rgb.copy()
    drop = old_above - new_above
    if drop <= 0:
        return out

    for x in range(w):
        ys = np.where(painted[:, x])[0]
        if len(ys) < 20:
            continue
        y0 = int(ys[0])
        src_hi = y0 + old_above
        if src_hi >= h - 2:
            continue
        band = lum[y0:src_hi, x]
        if (band > 14).mean() < 0.12:
            continue

        # Lintel: first tall dark run that starts inside the plaster band.
        sl = lum[y0:, x]
        dark = sl < 28
        lintel = None
        run = 0
        run_s = 0
        for i, is_dark in enumerate(dark):
            if is_dark:
                if run == 0:
                    run_s = i
                run += 1
                if run >= 80 and 20 <= run_s <= old_above + 10:
                    lintel = y0 + run_s
                    break
            else:
                run = 0

        new_crown = y0 + drop
        dest_hi = src_hi if lintel is None else min(src_hi, lintel)
        dest_h = dest_hi - new_crown
        if dest_h <= 1:
            continue
        src_h = src_hi - y0
        src_ys = y0 + (np.arange(dest_h) + 0.5) * src_h / dest_h
        src_ys = np.clip(src_ys, 0, h - 1.001)
        y0s = np.floor(src_ys).astype(np.int32)
        t = (src_ys - y0s)[:, None]
        y1s = np.minimum(y0s + 1, h - 1)
        sampled = (
            rgb[y0s, x].astype(np.float32) * (1.0 - t)
            + rgb[y1s, x].astype(np.float32) * t
        )
        out[new_crown:dest_hi, x] = sampled.astype(np.uint8)
        out[y0:new_crown, x] = 0

    # Isolated rear-corner spikes that failed the band test keep the old
    # warehouse crown in the opaque bbox. Drop anything above the new
    # full-height wall-top (median of compressed crowns, ±0.75).
    lum2 = out.mean(2)
    crowns = []
    for x in range(w):
        ys = np.where(lum2[:, x] > 14)[0]
        if len(ys) >= 20:
            crowns.append((x, int(ys[0])))
    if len(crowns) > 40:
        ys = np.array([c[1] for c in crowns], dtype=np.float32)
        med = float(np.median(ys))
        for x, y0 in crowns:
            if y0 < med - 40:
                out[: int(med - 20), x] = 0
    return out


def measure_door_column(rgb: np.ndarray, x: int = 2820) -> dict:
    """Clear opening and wall face at the exterior door column."""
    lum = rgb.mean(2)[:, x]
    ys = np.where(lum > 14)[0]
    if len(ys) < 20:
        return {"x": x}
    y0 = int(ys[0])
    sl = lum[y0 : y0 + 400]
    dark = sl < 28
    longest = 0
    run = 0
    run_s = 0
    best = (0, 0, 0)
    for i, is_dark in enumerate(dark):
        if is_dark:
            if run == 0:
                run_s = i
            run += 1
            if run > longest:
                longest = run
                best = (run_s, i, run)
        else:
            run = 0
    wall = best[1] + 1
    return {
        "x": x,
        "crown": y0,
        "clear_opening": longest,
        "plaster_above": best[0],
        "wall_face": wall,
        "door_wall": (longest / wall) if wall else None,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--scale", type=float, default=rp.SUITE_PLATE_SCALE)
    parser.add_argument("--skip-install", action="store_true")
    args = parser.parse_args()

    if not SRC.exists():
        raise SystemExit(f"missing {SRC}")

    master = Image.open(SRC).convert("RGB")
    placed, place = place_plate(master, args.scale)
    rgb = compress_plaster_band(np.asarray(placed))
    plate = Image.fromarray(rgb)
    bbox = room_bbox(rgb)
    door_col = measure_door_column(rgb)
    diamond = {
        **V5_DIAMOND,
        "WALL_FACE_H": float(door_col.get("wall_face") or rp.WALL_FACE_H),
    }
    openings = measure_openings(rgb, diamond)

    GEN.mkdir(parents=True, exist_ok=True)
    (GEN / "review").mkdir(parents=True, exist_ok=True)
    AREAS.mkdir(parents=True, exist_ok=True)

    if not args.skip_install:
        runtime = AREAS / "office_suite_plate.png"
        plate.save(runtime)
        plate.save(GEN / "office_suite_plate.png")
        plate.save(GEN / "office_suite_plate_bgee_v07_installed.png")
        cand = (
            ROOT
            / "ArtSource/Generated/BGEEProjectionCandidates"
            / "office_suite_plate_bgee_v07_candidate.png"
        )
        plate.save(cand)
        shell = AREAS / "office_shell_base.png"
        plate.save(shell)
        plate.save(GEN / "office_shell_base.png")

    half = GEN / "review/office_suite_plate_bgee_v07_half.png"
    plate.resize((ART_W // 2, ART_H // 2), Image.Resampling.LANCZOS).save(half)
    draw_overlay(plate, diamond, GEN / "review/office_bgee_v07_diamond_half.png")

    x0, y0, x1, y1 = bbox
    painted_y_up = {
        "x": x0,
        "y": ART_H - (y1 + 1),
        "width": x1 - x0 + 1,
        "height": y1 - y0 + 1,
    }
    metrics = {
        "plate_size": [ART_W, ART_H],
        "source": str(SRC.relative_to(ROOT)),
        "proportion_lock": {
            "old_plaster_above": V5_PLASTER_ABOVE,
            "target_plaster_above": TARGET_PLASTER_ABOVE,
            "target_door_wall": TARGET_DOOR_WALL,
        },
        **place,
        "room_bbox_ydown": [x0, y0, x1, y1],
        "paintedRoomSourceRect_yup": painted_y_up,
        **diamond,
        **openings,
        "door_column": door_col,
        "BODY_PLATE_H": rp.BODY_PLATE_H,
        "door_to_body": (
            door_col["clear_opening"] / rp.BODY_PLATE_H
            if door_col.get("clear_opening")
            else None
        ),
        "note": (
            "V5 place + plaster-band compress. Floor diamond unchanged. "
            "Copy WALL_FACE_H / BAKED_DOORWAY_H from door_column."
        ),
    }
    (GEN / "bgee_v07_metrics.json").write_text(json.dumps(metrics, indent=2) + "\n")

    r = qa.grade(AREAS / "office_suite_plate.png")
    tag = "PASS" if r["passes"] else "FAIL"
    print(f"placed scale={args.scale} paste={place['paste_xywh']} room={x1-x0+1}x{y1-y0+1}")
    print(f"REAR={diamond['REAR']} AXIS_NW={diamond['AXIS_NW']} AXIS_NE={diamond['AXIS_NE']}")
    print(f"WALL_FACE_H={diamond['WALL_FACE_H']} openings={openings}")
    print(f"door_column {door_col}")
    print(f"paintedRoomSourceRect {painted_y_up}")
    print(
        f"installed plate axes {r['peak_pos']:+.2f} / {r['peak_neg']:+.2f}  "
        f"worst {r['worst_delta']:.2f}  {tag}"
    )
    ratio = door_col.get("door_wall") or 0.0
    if ratio < 0.68 or door_col.get("plaster_above", 999) > 100:
        print("proportion lock missed the 73% door/wall target")
        return 1
    return 0 if r["passes"] else 1


if __name__ == "__main__":
    raise SystemExit(main())

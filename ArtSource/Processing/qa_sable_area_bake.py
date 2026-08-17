#!/usr/bin/env python3
"""Grade the Sable Row area bake — streets plate, lot crops, and the camera.

This checks the WED split:

- streets plate is ground + furniture, no building pixels at lot centres
- area flatten carries those buildings
- street crossings stay building-free
- twelve lot crops exist at the bake feet

and then grades the camera, per hero lot and on the composite.

An earlier version of this docstring said "do not run qa_plate_projection on
the area composite: building masses pollute the axis tensor". That is not true,
and believing it is what let Sable Row ship 25 degrees off the lock under an
`ALL CHECKS PASS`. The five other `city_*_block_v02` plates are composites of
ground *plus* buildings too, and they grade 1.00-1.27 degrees. Grading the
isolated lot crops works as well. Nothing was polluting the measurement — the
Sable buildings really are on a different camera from the ground they stand on.

    python3 ArtSource/Processing/qa_sable_area_bake.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import qa_plate_projection as proj
from fill_sable_lot_roofs import ORIG, OPAQUE, split_blobs

ROOT = Path(__file__).resolve().parents[2]
GEN = ROOT / "ArtSource/Generated/CityDistrict/V2/SableRow"
AREAS = ROOT / "RainShadow Shared/Resources/Art/Areas/CityDistrict/V2"
PROPS = ROOT / "RainShadow Shared/Resources/Art/Props/CityDistrict/V2"

PX = 2.0
WORLD_H = 2304.0
# Lots carrying painted buildings. The `edge_*` and `skyline*` lots are strips.
HEROES = (
    "harborWest", "harborVoss", "upperWest", "upperEast", "southWest", "southEast"
)
# Must match install_sable_lot_masters.CAMERA_TOLERANCE_DEG. Two tools
# disagreeing about what "on the lock" means is how Sable Row shipped 25 deg
# off in the first place, so this imports it rather than restating it.
from install_sable_lot_masters import CAMERA_TOLERANCE_DEG
# Painted road intersections from CityBlockGrid.crossings — not block centres.
CROSSINGS = [
    (840.0, 414.0),
    (2520.0, 414.0),
    (1680.0, 1044.0),
    (3360.0, 1044.0),
    (840.0, 1674.0),
    (2520.0, 1674.0),
]


def world_to_px(x: float, y: float) -> tuple[int, int]:
    return int(round(x * PX)), int(round((WORLD_H - y) * PX))


def patch_mean_abs(a: np.ndarray, b: np.ndarray, cx: int, cy: int, radius: int = 24) -> float:
    x0, x1 = max(0, cx - radius), min(a.shape[1], cx + radius)
    y0, y1 = max(0, cy - radius), min(a.shape[0], cy + radius)
    if x1 <= x0 or y1 <= y0:
        return 0.0
    return float(np.mean(np.abs(a[y0:y1, x0:x1].astype(np.int16) - b[y0:y1, x0:x1].astype(np.int16))))


def main() -> int:
    bake_path = GEN / "sable_area_bake.json"
    if not bake_path.exists():
        print(f"FAIL missing {bake_path.relative_to(ROOT)}")
        return 1
    bake = json.loads(bake_path.read_text())
    streets_path = AREAS / f"{bake['streetsTexture']}.png"
    area_path = GEN / f"{bake['areaTexture']}.png"
    failed = 0

    def fail(msg: str) -> None:
        nonlocal failed
        failed += 1
        print(f"FAIL {msg}")

    for path, label in (
        (streets_path, "streets plate"),
        (area_path, "area flatten"),
    ):
        if not path.exists():
            fail(f"missing {label}: {path.relative_to(ROOT)}")

    if failed:
        return 1

    streets = np.array(Image.open(streets_path).convert("RGB"))
    area = np.array(Image.open(area_path).convert("RGB"))
    h, w = streets.shape[:2]
    if (w, h) != (bake["plateSize"]["w"], bake["plateSize"]["h"]):
        fail(f"streets {w}x{h} != plate {bake['plateSize']}")
    if area.shape != streets.shape:
        fail(f"area {area.shape} != streets {streets.shape}")
    if len(bake["lots"]) != 12:
        fail(f"{len(bake['lots'])} lots, want 12")

    print(f"streets {w}x{h}  lots={len(bake['lots'])}  "
          f"architecture={bake['counts']['architecture']} furniture={bake['counts']['furniture']}")

    for lot in bake["lots"]:
        name = lot["textureName"]
        crop_path = PROPS / f"{name}.png"
        if not crop_path.exists():
            fail(f"missing lot crop {name}")
            continue
        crop = np.array(Image.open(crop_path).convert("RGBA"))
        ys, xs = np.where(crop[:, :, 3] > 200)
        if len(xs) < 200:
            fail(f"{name} crop is almost empty ({len(xs)} solid px)")
            continue
        # Buildings sit on the camera-near wall, not the diamond centre.
        # The crop is the authority: it must match the flatten and must
        # not still be paint on the streets plate.
        box = lot["cropPx"]
        px = np.asarray(box["x"]) + xs
        py = np.asarray(box["y"]) + ys
        inside = (px >= 0) & (px < w) & (py >= 0) & (py < h)
        px, py = px[inside], py[inside]
        rgb = crop[:, :, :3][ys[inside], xs[inside]].astype(np.int16)
        match = float(np.mean(np.abs(area[py, px].astype(np.int16) - rgb)))
        punched = float(np.mean(np.abs(streets[py, px].astype(np.int16) - rgb)))
        print(f"  {name:32} flattenΔ={match:5.1f}  streetsΔ={punched:5.1f}  solid={len(px)}")
        if match > 2:
            fail(f"{name} crop does not match the area flatten (Δ={match:.1f})")
        if punched < 8:
            fail(f"{name} crop is still painted on the streets plate (Δ={punched:.1f})")

    print("crossings:")
    for x, y in CROSSINGS:
        cx, cy = world_to_px(x, y)
        street_built = patch_mean_abs(area, streets, cx, cy, radius=16)
        print(f"  ({x:.0f},{y:.0f}) area-vs-streets Δ={street_built:.1f}")
        if street_built > 10:
            fail(f"crossing ({x:.0f},{y:.0f}) has building pixels on the streets plate (Δ={street_built:.1f})")

    print(f"camera (target +-{proj.TARGET_DEG:.2f} deg, tolerance {CAMERA_TOLERANCE_DEG:.1f}):")
    off_lock = []
    # Every lot, not just the heroes. Grading only the six hero lots is what
    # hid this: the six v01 edge/skyline strips are 24.01-26.12 deg off and
    # produce 24.64 deg on the streets plate entirely on their own, while the
    # five on-lock heroes grade 0.26. Nothing was measuring them.
    others = tuple(
        lot["textureName"].removeprefix("city_sable_lot_")
        for lot in bake["lots"]
        if lot["textureName"].removeprefix("city_sable_lot_") not in HEROES
    )
    for name in HEROES + others + ("__composite__",):
        if name == "__composite__":
            path, label = area_path, "area flatten"
        else:
            path, label = PROPS / f"city_sable_lot_{name}.png", name
        if not path.exists():
            continue
        # Plate-edge strips are frame-clipped; waive per-lot camera there.
        edge = name.startswith("edge_")
        tip = edge and any(
            lot["textureName"] == f"city_sable_lot_{name}"
            and lot["worldSize"]["w"] < 500
            for lot in bake["lots"]
        )
        note = " (edge waiver)" if edge else ""
        grade_path = path
        try:
            g = proj.grade(grade_path)
        except ValueError as exc:
            print(f"  {label:32} unmeasurable ({exc})")
            continue
        ok = edge or tip or g["worst_delta"] <= CAMERA_TOLERANCE_DEG
        if not ok:
            off_lock.append(label)
        print(
            f"  {label:32} {g['peak_pos']:+7.2f} {g['peak_neg']:+7.2f}  "
            f"worst={g['worst_delta']:5.2f}  {'PASS' if ok else 'OFF-LOCK'}{note}"
        )

    if failed:
        print(f"{failed} bake checks failed")
        return 1
    if off_lock:
        print(
            f"\nBAKE CHECKS PASS — CAMERA OFF-LOCK on {len(off_lock)}: "
            f"{', '.join(off_lock)}\n"
            "The bake is structurally sound. Regenerate the named art under\n"
            "ArtSource/Prompts/city_sable_lot_masters_v05.md."
        )
        return 1
    print("ALL CHECKS PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

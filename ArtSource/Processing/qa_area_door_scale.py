#!/usr/bin/env python3
"""Gate painted city-door height against the standing adult.

Infinity Engine areas keep sprites and background in one px/world scale. RainShadow
locks the adult at 70.3125 world units (200 px on a 512 canvas over a 180-unit
node). Outdoor doors must clear that adult at 1.05–1.35× (target 1.15×).

This tool maps each exterior ARE door onto its installed plate, measures the
upright painted aperture (threshold → lintel) in plate pixels, and fails if the
multiple sits outside the band. Checked-in measurements live in
`ArtSource/Generated/CityDistrict/V2/DoorScale/apertures.json`.

    python3 ArtSource/Processing/qa_area_door_scale.py
    python3 ArtSource/Processing/qa_area_door_scale.py --measure
    python3 ArtSource/Processing/qa_area_door_scale.py --write-measurements

`--measure` re-estimates from the paint. `--write-measurements` records those
estimates. Without flags the tool grades the checked-in JSON against the band.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
AREAS = ROOT / "RainShadow Shared/Resources/Areas"
ART = ROOT / "RainShadow Shared/Resources/Art/Areas/CityDistrict/V2"
OUT = ROOT / "ArtSource/Generated/CityDistrict/V2/DoorScale"

ADULT_WU = 70.3125
WORLD = (4096.0, 3072.0)
BAND = (1.05, 1.35)
TARGET = 1.15
EXTERIOR_PREFIX = "city_"

DISTRICTS = (
    "sable_row",
    "wharf_ladder",
    "riverside",
    "harborpoint_pd",
    "lila_street",
    "civic_records",
)

# Where the *painted* entrance actually sits when it differs from the authored
# ARE geometry. Sable Row's portal region was authored against the retired
# modular facade; the plate paints the entrance on the corner stoop ~180 wu
# away, which is the door the player sees. World units, y-up, at the threshold.
PAINTED_ANCHORS: dict[tuple[str, str], tuple[float, float]] = {
    ("city_sable_row", "portal.office"): (2540.0, 774.5),
}


def adult_px(plate_w: int) -> float:
    return ADULT_WU * plate_w / WORLD[0]


def world_to_plate(x: float, y: float, plate_w: int, plate_h: int) -> tuple[float, float]:
    return x * plate_w / WORLD[0], plate_h - y * plate_h / WORLD[1]


def plate_to_world(px: float, py: float, plate_w: int, plate_h: int) -> tuple[float, float]:
    return px * WORLD[0] / plate_w, (plate_h - py) * WORLD[1] / plate_h


def load_area(slug: str) -> dict:
    return json.loads((AREAS / f"city_{slug}.area.json").read_text())["area"]


def plate_path(area: dict) -> Path:
    name = area["plateTextureName"]
    if not name.endswith(".png"):
        name = f"{name}.png"
    return ART / name


def door_anchor(area: dict, door: dict) -> tuple[float, float]:
    """World-space point at the painted threshold, y-up."""
    override = PAINTED_ANCHORS.get((area["id"], door["id"]))
    if override:
        return override
    regions = {region["id"]: region for region in area.get("regions", [])}
    region = regions.get(door["id"])
    if region and region.get("polygon"):
        xs = [p["x"] for p in region["polygon"]]
        ys = [p["y"] for p in region["polygon"]]
        return sum(xs) / len(xs), min(ys)
    obstacle = door["closedObstacle"]
    return obstacle["x"] + obstacle["w"] / 2, obstacle["y"]


def measure_opening(plate: Image.Image, cx: float, cy: float) -> dict:
    """Full painted doorway, including lit glass above a mid-rail.

    The first contrast step on a shop door is a panel rail at ~1 adult. Grading
    and seating both need the top of the opening or a 3×-adult leaf passes.
    """
    array = np.asarray(plate.convert("RGB"), dtype=np.float32)
    y = 0.2126 * array[:, :, 0] + 0.7152 * array[:, :, 1] + 0.0722 * array[:, :, 2]
    h, w = y.shape
    cx_i = int(np.clip(round(cx), 12, w - 13))
    cy_i = int(np.clip(round(cy), 12, h - 13))
    adult = adult_px(plate.width)
    column = np.median(y[:, cx_i - 10 : cx_i + 11], axis=1)
    left_w = np.median(y[:, max(0, cx_i - 90) : max(8, cx_i - 50)], axis=1)
    right_w = np.median(y[:, min(w, cx_i + 50) : min(w, cx_i + 90)], axis=1)
    wall = np.minimum(left_w, right_w)
    last = cy_i
    glow_top = None
    top_limit = max(8, cy_i - int(round(adult * 3.6)))
    for row in range(cy_i - int(round(adult * 0.6)), top_limit, -1):
        if float(column[row]) > float(wall[row]) + 18:
            glow_top = row
    if glow_top is not None:
        last = glow_top
    else:
        seen = False
        for row in range(cy_i - 4, top_limit, -1):
            c = float(column[row])
            wlum = float(wall[row])
            if c < min(wlum - 4, 40):
                seen = True
                last = row
            elif seen:
                break
    left = max(0, int(cx_i - adult * 1.4))
    right = min(w, int(cx_i + adult * 1.4))
    top = max(0, int(cy_i - adult * 4.2))
    bottom = min(h, int(cy_i + adult * 0.6))
    return {
        "heightPx": float(max(1, cy_i - last)),
        "thresholdPx": [float(cx_i), float(cy_i)],
        "lintelPx": [float(cx_i), float(last)],
        "crop": [left, top, right, bottom],
    }


def estimate_aperture(plate: Image.Image, cx: float, cy: float) -> dict:
    """Find a dark vertical opening standing on (cx, cy) plate pixels."""
    array = np.asarray(plate.convert("RGB"), dtype=np.float32)
    height, width = array.shape[:2]
    adult = adult_px(width)
    left = max(0, int(cx - adult * 1.4))
    right = min(width, int(cx + adult * 1.4))
    top = max(0, int(cy - adult * 4.2))
    bottom = min(height, int(cy + adult * 0.6))
    crop = array[top:bottom, left:right]
    if crop.size == 0:
        raise RuntimeError(f"empty crop at ({cx:.1f},{cy:.1f})")

    luma = 0.2126 * crop[:, :, 0] + 0.7152 * crop[:, :, 1] + 0.0722 * crop[:, :, 2]
    local_cx = int(round(cx)) - left
    local_cy = int(round(cy)) - top
    local_cx = min(max(local_cx, 2), crop.shape[1] - 3)
    local_cy = min(max(local_cy, 2), crop.shape[0] - 3)

    col_band = slice(max(0, local_cx - 10), min(crop.shape[1], local_cx + 11))
    column = np.median(luma[:, col_band], axis=1)
    pavement = column[max(0, local_cy - 8) : min(len(column), local_cy + 12)]
    pavement_luma = float(np.median(pavement)) if pavement.size else float(np.median(column))
    dark = min(pavement_luma - 18.0, float(np.percentile(column, 35)))

    threshold = local_cy
    # The search must be able to *fail*: scan well past the band (to 4.5 adults)
    # and report the first bright lintel it meets. A search clamped to the band
    # cannot return an out-of-band height, which is how a 3x-adult Sable door
    # graded as 1.05x PASS.
    min_h = max(4, int(round(adult * 0.5)))
    max_h = int(round(adult * 4.5))
    lintel = None
    # A lintel is a sustained band (the stamp paints 7 rows) that is markedly
    # brighter than the leaf just below it. An absolute threshold fails both
    # ways: 1-2 px trim lines count, and in deep-shadow alleys the whole
    # wooden leaf clears `dark + 28` and the scan stops at its first row.
    for row in range(threshold - min_h, max(10, threshold - max_h - 1), -1):
        band = float(column[row - 3 : row + 1].mean())
        below = float(column[row + 4 : row + 10].mean())
        if band > below + 25 and band > dark + 28:
            lintel = row
            break
    if lintel is None:
        lo = max(0, threshold - max_h)
        hi = max(lo + 1, threshold - min_h)
        band = column[lo:hi]
        lintel = lo + int(np.argmax(band)) if band.size else max(0, threshold - min_h)

    height_px = float(max(1, threshold - lintel))
    aperture_cx = left + local_cx
    return {
        "heightPx": height_px,
        "thresholdPx": [aperture_cx, top + threshold],
        "lintelPx": [aperture_cx, top + lintel],
        "crop": [left, top, right, bottom],
    }


def annotate(plate: Image.Image, record: dict) -> Image.Image:
    left, top, right, bottom = (int(v) for v in record["crop"])
    crop = plate.crop((left, top, right, bottom)).convert("RGBA")
    draw = ImageDraw.Draw(crop)
    adult = adult_px(plate.width)
    target = adult * TARGET
    base_x = 28
    base_y = int(record["thresholdPx"][1] - top)
    draw.line([(base_x, base_y), (base_x, base_y - adult)], fill=(0, 220, 70, 255), width=5)
    draw.line([(base_x + 18, base_y), (base_x + 18, base_y - target)], fill=(255, 210, 0, 255), width=5)
    tx, ty = record["thresholdPx"]
    lx, ly = record["lintelPx"]
    draw.line(
        [(tx - left, ty - top), (lx - left, ly - top)],
        fill=(255, 70, 70, 255),
        width=4,
    )
    label = (
        f"{record['id']}  {record['heightPx']:.0f}px  "
        f"{record['multiple']:.2f}x  {'PASS' if record['passes'] else 'FAIL'}"
    )
    try:
        font = ImageFont.load_default()
    except OSError:
        font = None
    draw.rectangle((8, 8, 8 + 8 * len(label), 28), fill=(0, 0, 0, 180))
    draw.text((12, 10), label, fill=(255, 255, 255, 255), font=font)
    return crop


def grade_door(area: dict, door: dict, plate: Image.Image, measured: dict | None) -> dict:
    wx, wy = door_anchor(area, door)
    cx, cy = world_to_plate(wx, wy, plate.width, plate.height)
    estimate = measured if measured else measure_opening(plate, cx, cy)
    height_px = float(estimate["heightPx"])
    height_wu = height_px * WORLD[0] / plate.width
    multiple = height_wu / ADULT_WU
    passes = BAND[0] <= multiple <= BAND[1]
    tx, ty = estimate["thresholdPx"]
    lx, ly = estimate["lintelPx"]
    world_x, world_y = plate_to_world(tx, ty, plate.width, plate.height)
    _, lintel_y = plate_to_world(lx, ly, plate.width, plate.height)
    record = {
        "area": area["id"],
        "id": door["id"],
        "heightPx": height_px,
        "heightWU": height_wu,
        "multiple": multiple,
        "passes": passes,
        "thresholdPx": [float(tx), float(ty)],
        "lintelPx": [float(lx), float(ly)],
        "paintedAperture": {
            "x": world_x - 8,
            "y": world_y,
            "w": 16,
            "h": lintel_y - world_y if lintel_y > world_y else height_wu,
        },
        "crop": estimate.get("crop", [0, 0, plate.width, plate.height]),
    }
    return record


def load_measurements() -> dict[tuple[str, str], dict]:
    path = OUT / "apertures.json"
    if not path.exists():
        return {}
    payload = json.loads(path.read_text())
    return {(item["area"], item["id"]): item for item in payload.get("doors", [])}


def write_measurements(records: list[dict]) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    payload = {
        "adultWU": ADULT_WU,
        "world": list(WORLD),
        "pxPerUnit": 2.0,
        "targetMultiple": TARGET,
        "band": list(BAND),
        "doors": [
            {k: v for k, v in record.items() if k != "crop"}
            for record in records
        ],
    }
    (OUT / "apertures.json").write_text(json.dumps(payload, indent=2) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--measure", action="store_true", help="re-estimate from paint")
    parser.add_argument("--write-measurements", action="store_true")
    parser.add_argument("districts", nargs="*", default=list(DISTRICTS))
    args = parser.parse_args()

    stored = {} if args.measure else load_measurements()
    records: list[dict] = []
    crops_dir = OUT / "crops"
    crops_dir.mkdir(parents=True, exist_ok=True)

    print(
        f"adult {ADULT_WU} wu; target {TARGET:.2f}x; "
        f"band {BAND[0]:.2f}…{BAND[1]:.2f}x"
    )
    print(f"{'area':22} {'door':28} {'px':>6} {'wu':>7} {'x adult':>8}  verdict")

    failed = 0
    for slug in args.districts:
        area = load_area(slug)
        plate = Image.open(plate_path(area))
        for door in area.get("doors", []):
            key = (area["id"], door["id"])
            measured = stored.get(key)
            record = grade_door(area, door, plate, measured)
            records.append(record)
            annotate(plate, record).save(
                crops_dir / f"{area['id']}_{door['id'].replace('.', '_')}.png"
            )
            verdict = "PASS" if record["passes"] else "FAIL"
            if not record["passes"]:
                failed += 1
            print(
                f"{area['id']:22} {door['id']:28} {record['heightPx']:6.0f} "
                f"{record['heightWU']:7.1f} {record['multiple']:8.2f}  {verdict}"
            )

    if args.write_measurements:
        write_measurements(records)
        print(f"wrote {OUT / 'apertures.json'}")

    if failed:
        print(f"{failed} door(s) outside {BAND[0]:.2f}…{BAND[1]:.2f}x adult")
        return 1
    print("ALL CHECKS PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

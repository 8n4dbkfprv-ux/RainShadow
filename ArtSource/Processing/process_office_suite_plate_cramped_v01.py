"""Ship the cramped Image Generator suite plate to runtime.

Places `office_suite_plate_cramped_v03.png` onto the 4096×2304 canvas at
`SUITE_PLATE_SCALE` (default 0.80) so modular props at unchanged body scale
fill the floor. Archives the previous suite plate and writes metrics.

Usage:
    python3 ArtSource/Processing/process_office_suite_plate_cramped_v01.py
    python3 ArtSource/Processing/process_office_suite_plate_cramped_v01.py --scale 0.80
"""

from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.spatial import ConvexHull

import office_room_plan as rp

ROOT = Path(__file__).resolve().parents[2]
GEN = ROOT / "ArtSource/Generated/Office"
RUNTIME = (
    ROOT
    / "RainShadow Shared/Resources/Art/Areas/DetectiveOffice/office_suite_plate.png"
)
MASTERS = (
    GEN / "office_suite_plate_cramped_v03.png",
    Path.home()
    / ".cursor/projects/Users-laurensvanoorschot-Desktop-RainShadow/assets"
    / "office_suite_plate_cramped_v03.png",
)
ART_W, ART_H = 4096, 2304


def find_master() -> Path:
    for path in MASTERS:
        if path.exists():
            return path
    raise SystemExit("No cramped suite master found")


def place_plate(master: Image.Image, scale: float) -> tuple[Image.Image, tuple[int, int, int, int]]:
    full = master.resize((ART_W, ART_H), Image.Resampling.LANCZOS)
    mw = int(round(ART_W * scale))
    mh = int(round(ART_H * scale))
    small = full.resize((mw, mh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", (ART_W, ART_H), (0, 0, 0))
    px = (ART_W - mw) // 2
    py = int((ART_H - mh) * 0.30)
    canvas.paste(small, (px, py))
    return canvas, (px, py, mw, mh)


def fit_axes(rgb: np.ndarray) -> dict[str, list[float]]:
    """Silhouette hull of the lower bright room mass — QA only, NOT placement.

    Wall-shoe / floor-diamond constants live in `office_room_plan.py`. The hull
    here tracks architecture mass (often the plaster crown or full room blob) and
    will disagree with floor contact; metrics note that so it is never copy-pasted
    into the room plan as REAR/AXIS_*.
    """
    lum = rgb.mean(2)
    room = lum > 18
    ys, xs = np.where(room)
    y0, y1 = int(ys.min()), int(ys.max())
    band0 = int(y0 + 0.45 * (y1 - y0))
    lower = room.copy()
    lower[:band0] = False
    pts = np.column_stack(
        [np.where(lower)[1].astype(float), np.where(lower)[0].astype(float)]
    )
    h = pts[ConvexHull(pts).vertices]
    west = h[np.argmin(h[:, 0])]
    east = h[np.argmax(h[:, 0])]
    near = h[np.argmax(h[:, 1])]
    rear = west + east - near
    axis_nw = west - rear
    axis_ne = east - rear
    return {
        "silhouette_REAR": [float(rear[0]), float(rear[1])],
        "silhouette_AXIS_NW": [float(axis_nw[0]), float(axis_nw[1])],
        "silhouette_AXIS_NE": [float(axis_ne[0]), float(axis_ne[1])],
        "silhouette_west": [float(west[0]), float(west[1])],
        "silhouette_east": [float(east[0]), float(east[1])],
        "silhouette_near": [float(near[0]), float(near[1])],
        # Authoritative floor diamond (must match office_room_plan).
        "REAR": [float(rp.REAR[0]), float(rp.REAR[1])],
        "AXIS_NW": [float(rp.AXIS_NW[0]), float(rp.AXIS_NW[1])],
        "AXIS_NE": [float(rp.AXIS_NE[0]), float(rp.AXIS_NE[1])],
        "west": [
            float(rp.REAR[0] + rp.AXIS_NW[0]),
            float(rp.REAR[1] + rp.AXIS_NW[1]),
        ],
        "east": [
            float(rp.REAR[0] + rp.AXIS_NE[0]),
            float(rp.REAR[1] + rp.AXIS_NE[1]),
        ],
        "near": [
            float(rp.REAR[0] + rp.AXIS_NW[0] + rp.AXIS_NE[0]),
            float(rp.REAR[1] + rp.AXIS_NW[1] + rp.AXIS_NE[1]),
        ],
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--scale",
        type=float,
        default=getattr(rp, "SUITE_PLATE_SCALE", 0.80),
        help="Architecture scale vs full-bleed 4096×2304 (props stay body-scaled)",
    )
    args = parser.parse_args()

    master_path = find_master()
    master = Image.open(master_path).convert("RGB")
    plate, box = place_plate(master, args.scale)
    axes = fit_axes(np.asarray(plate))

    GEN.mkdir(parents=True, exist_ok=True)
    (GEN / "review").mkdir(parents=True, exist_ok=True)
    RUNTIME.parent.mkdir(parents=True, exist_ok=True)

    archive = GEN / "office_suite_plate_pre_tight_v01.png"
    if RUNTIME.exists() and not archive.exists():
        shutil.copy2(RUNTIME, archive)

    plate.save(RUNTIME)
    plate.save(GEN / "office_suite_plate.png")
    plate.save(GEN / "office_suite_plate_cramped_tight_v01.png")
    plate.resize((ART_W // 2, ART_H // 2), Image.Resampling.LANCZOS).save(
        GEN / "review/office_suite_plate_cramped_tight_shipped_half.png"
    )

    metrics = {
        "plate_size": [ART_W, ART_H],
        "source": f"ig_cramped_tight:{master_path.name}",
        "scale_of_fullbleed": args.scale,
        "paste_xywh": list(box),
        **axes,
        "note": (
            "Empty cramped architecture at SUITE_PLATE_SCALE so modular props at "
            "unchanged body scale fill the floor. REAR/AXIS_* are copied from "
            "office_room_plan (painted wall-shoe diamond). silhouette_* is the "
            "legacy bright-mass hull and must not be used for prop placement."
        ),
    }
    (GEN / "cramped_tight_metrics.json").write_text(json.dumps(metrics, indent=2) + "\n")
    (GEN / "office_suite_opening.json").write_text(json.dumps(metrics, indent=2) + "\n")
    print(f"shipped {RUNTIME} {plate.size} scale={args.scale} from {master_path.name}")
    print(f"floor REAR={axes['REAR']} AXIS_NW={axes['AXIS_NW']} AXIS_NE={axes['AXIS_NE']}")
    print(
        f"silhouette REAR={axes['silhouette_REAR']} "
        f"(not for placement; room plan is authoritative)"
    )


if __name__ == "__main__":
    main()

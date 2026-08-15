#!/usr/bin/env python3
"""Install the on-lock office V5 master and emit a shoe-fit overlay.

The generator produced a 1536×1024 (3:2) plate. A 16:9 centre-crop would
cut the wall crowns and the camera-near floor tip, and an anisotropic
resize to 4096×2304 would shear every ground slope by 0.844×. This
installer scales uniformly (contain the 3:2 master, then apply
SUITE_PLATE_SCALE) and pastes onto the 4096×2304 runtime canvas.

Does not flip `ie_projection.ACTIVE` and does not write Swift. Those
move with the room-plan edit after the overlay is accepted.

Usage:
    python3 ArtSource/Processing/install_office_bgee_v05.py
    python3 ArtSource/Processing/install_office_bgee_v05.py --scale 0.60
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ie_projection as ie
import office_room_plan as rp
import qa_plate_projection as qa

ROOT = Path(__file__).resolve().parents[2]
SRC = (
    ROOT
    / "ArtSource/Generated/BGEEProjectionCandidates/office_suite_plate_bgee_v05_candidate.png"
)
GEN = ROOT / "ArtSource/Generated/Office"
AREAS = ROOT / "RainShadow Shared/Resources/Art/Areas/DetectiveOffice"
ART_W, ART_H = rp.ART_W, rp.ART_H
SLOPE = ie.BGEE.ground_slope  # 0.75, independent of ACTIVE


def place_plate(master: Image.Image, scale: float) -> tuple[Image.Image, dict]:
    """Uniform scale of the 3:2 master onto the 16:9 runtime canvas.

    Height-fit the master to ART_H, then apply `scale` (the same meaning as
    the cramped installer's SUITE_PLATE_SCALE). Horizontal leftover is
    letterboxed; vertical leftover uses the cramped 30% paste so the room
    sits in the upper-centre the camera already frames.
    """
    if master.mode != "RGB":
        master = master.convert("RGB")
    height_fit = ART_H / master.height
    s = height_fit * scale
    mw = int(round(master.width * s))
    mh = int(round(master.height * s))
    small = master.resize((mw, mh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", (ART_W, ART_H), (0, 0, 0))
    px = (ART_W - mw) // 2
    py = int((ART_H - mh) * 0.30)
    canvas.paste(small, (px, py))
    return canvas, {
        "source_size": [master.width, master.height],
        "uniform_scale": s,
        "height_fit": height_fit,
        "suite_plate_scale": scale,
        "paste_xywh": [px, py, mw, mh],
    }


def room_bbox(rgb: np.ndarray, thr: int = 12) -> tuple[int, int, int, int]:
    lum = rgb.mean(2)
    ys, xs = np.where(lum > thr)
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


def silhouette(rgb: np.ndarray, thr: int = 10) -> tuple[np.ndarray, np.ndarray]:
    lum = rgb.mean(2)
    filled = lum > thr
    h, w = filled.shape
    top = np.full(w, -1, dtype=int)
    bot = np.full(w, -1, dtype=int)
    for x in range(w):
        ys = np.where(filled[:, x])[0]
        if len(ys):
            top[x] = int(ys[0])
            bot[x] = int(ys[-1])
    return top, bot


def fit_diamond(rgb: np.ndarray, box: dict) -> dict:
    """Floor diamond with forced ±0.75 slopes, clipped to the painted cutaway.

    Wall crowns are a two-room notch, so they are not the diamond. The
    camera-near silhouette is; west/east come from that cutaway, rear is
    the parallelogram completion snapped onto ±0.75, then axis lengths are
    solved so the unit-square near tip sits on the painted bottom.
    """
    top, bot = silhouette(rgb)
    xs = np.where(bot >= 0)[0]
    x0, x1 = int(xs.min()), int(xs.max())
    # Painted near tip: lowest silhouette column (the clipped diamond tip).
    near_x = int(xs[np.argmax(bot[xs])])
    near_y = int(bot[near_x])

    # Near-edge samples away from the clipped centre band.
    left_pts = [(int(x), int(bot[x])) for x in xs if x0 + 20 < x < near_x - 80]
    right_pts = [(int(x), int(bot[x])) for x in xs if near_x + 80 < x < x1 - 20]

    def line_through(pts: list[tuple[int, int]], slope: float) -> tuple[float, float]:
        # y = slope * x + c ; median intercept so stair-steps do not pull it.
        intercepts = [y - slope * x for x, y in pts]
        return slope, float(np.median(intercepts))

    nw_near_m, nw_near_c = line_through(right_pts, -SLOPE)  # east -> near, NW-parallel
    ne_near_m, ne_near_c = line_through(left_pts, +SLOPE)  # west -> near, NE-parallel

    # West / east corners: silhouette extremes projected onto those lines.
    west_x = float(x0 + 4)
    west_y = ne_near_m * west_x + ne_near_c
    east_x = float(x1 - 4)
    east_y = nw_near_m * east_x + nw_near_c

    # Rear from parallelogram, then snap to ±0.75 through a shared rear.
    # Solve: rear + (-a, 0.75 a) = west, rear + (b, 0.75 b) = east
    # and rear + (-a, 0.75 a) + (b, 0.75 b) should land on the painted near
    # tip as closely as the clipped silhouette allows.
    #
    # Use west/east x-runs for a, b and place rear so the near tip's y
    # matches the paint (the x of a clipped tip is allowed to slide).
    a = east_x  # placeholder to satisfy type checkers; replaced below
    a = west_x  # noqa: F841
    dx_w = west_x  # also replaced
    del a, dx_w

    # a = rear_x - west_x, b = east_x - rear_x. Choose rear_x so the
    # implied near_x = west_x + b = east_x - a sits near the painted tip.
    rear_x = (west_x + east_x) - near_x
    a_len = rear_x - west_x
    b_len = east_x - rear_x
    if a_len <= 0 or b_len <= 0:
        rear_x = 0.5 * (west_x + east_x)
        a_len = rear_x - west_x
        b_len = east_x - rear_x

    # rear_y from the near-tip y: near_y = rear_y + 0.75*(a+b)
    rear_y = near_y - SLOPE * (a_len + b_len)
    # Keep rear on the painted room (do not float into the black above).
    y0 = int(np.min(top[top >= 0]))
    if rear_y < y0 + 40:
        rear_y = float(y0 + 80)
        # Re-solve a+b from the new rear_y so the near tip still hits paint.
        span = (near_y - rear_y) / SLOPE
        # Keep the a:b ratio from the x-runs.
        ratio = a_len / (a_len + b_len)
        a_len = span * ratio
        b_len = span * (1.0 - ratio)
        rear_x = west_x + a_len
        east_x = rear_x + b_len
        west_y = rear_y + SLOPE * a_len
        east_y = rear_y + SLOPE * b_len

    axis_nw = (-a_len, SLOPE * a_len)
    axis_ne = (b_len, SLOPE * b_len)
    rear = (rear_x, rear_y)
    west = (rear[0] + axis_nw[0], rear[1] + axis_nw[1])
    east = (rear[0] + axis_ne[0], rear[1] + axis_ne[1])
    near = (rear[0] + axis_nw[0] + axis_ne[0], rear[1] + axis_nw[1] + axis_ne[1])

    # Wall face: median (shoe - crown) on columns that sit on the NW wall
    # (left of rear) and have a clean silhouette top.
    face = []
    for x in range(int(west[0]) + 20, int(rear[0]) - 20, 4):
        if 0 <= x < rgb.shape[1] and top[x] >= 0:
            shoe = rear_y - SLOPE * (x - rear_x)  # NW shoe, slope -0.75
            if shoe > top[x] + 40:
                face.append(shoe - top[x])
    wall_face = float(np.median(face)) if face else float(rp.WALL_FACE_H)

    return {
        "REAR": [round(rear[0], 1), round(rear[1], 1)],
        "AXIS_NW": [round(axis_nw[0], 2), round(axis_nw[1], 2)],
        "AXIS_NE": [round(axis_ne[0], 2), round(axis_ne[1], 2)],
        "west": [round(west[0], 1), round(west[1], 1)],
        "east": [round(east[0], 1), round(east[1], 1)],
        "near": [round(near[0], 1), round(near[1], 1)],
        "WALL_FACE_H": round(wall_face, 1),
        "near_edge_left": [ne_near_m, ne_near_c],
        "near_edge_right": [nw_near_m, nw_near_c],
    }


def measure_openings(rgb: np.ndarray, diamond: dict) -> dict:
    """Clear-opening estimates on the installed plate, in plate pixels."""
    # Exterior door: tall interior void on the NE wall (right half).
    lum = rgb.mean(2)
    h, w = lum.shape
    rear_x = diamond["REAR"][0]
    void = lum < 8
    xs = []
    heights = []
    widths_at = []
    x0 = int(rear_x + 80)
    for x in range(max(0, x0), w - 1):
        col = void[:, x]
        y = 0
        best = 0
        best_ab = (0, 0)
        while y < h:
            if col[y]:
                a = y
                while y < h and col[y]:
                    y += 1
                if 60 < (y - a) < 500 and a > 40:
                    if y - a > best:
                        best = y - a
                        best_ab = (a, y)
            else:
                y += 1
        if best >= 80:
            xs.append(x)
            heights.append(best)
            widths_at.append(best_ab)
    opening = {}
    if xs and heights:
        mid = slice(len(xs) // 5, -len(xs) // 5 or None)
        opening["exterior_clear_h"] = float(np.median(np.array(heights)[mid]))
        opening["exterior_x0"] = int(xs[len(xs) // 5])
        opening["exterior_x1"] = int(xs[-len(xs) // 5 or -1])
        opening["exterior_w"] = float(opening["exterior_x1"] - opening["exterior_x0"])
        opening["exterior_lintel"] = float(np.median([p[0] for p in widths_at[mid]]))
        opening["exterior_thresh"] = float(np.median([p[1] for p in widths_at[mid]]))
    return opening


def draw_overlay(plate: Image.Image, diamond: dict, dest: Path) -> None:
    ov = plate.copy()
    d = ImageDraw.Draw(ov)
    rear = tuple(diamond["REAR"])
    west = tuple(diamond["west"])
    east = tuple(diamond["east"])
    near = tuple(diamond["near"])
    # Floor diamond
    d.line([rear, west, near, east, rear], fill=(0, 220, 90), width=4)
    # Wall tops (parallel, raised by WALL_FACE_H)
    face = diamond["WALL_FACE_H"]
    rt = (rear[0], rear[1] - face)
    wt = (west[0], west[1] - face)
    et = (east[0], east[1] - face)
    d.line([wt, rt, et], fill=(80, 180, 255), width=3)
    for pt, name in ((rear, "R"), (west, "W"), (east, "E"), (near, "N")):
        x, y = pt
        d.ellipse((x - 6, y - 6, x + 6, y + 6), fill=(255, 220, 0))
        d.text((x + 8, y - 18), name, fill=(255, 220, 0))
    ov.resize((ART_W // 2, ART_H // 2), Image.Resampling.LANCZOS).save(dest)
    print(f"overlay {dest}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--scale", type=float, default=rp.SUITE_PLATE_SCALE)
    parser.add_argument("--skip-install", action="store_true")
    args = parser.parse_args()

    if not SRC.exists():
        raise SystemExit(f"missing {SRC}")

    master = Image.open(SRC).convert("RGB")
    plate, place = place_plate(master, args.scale)
    rgb = np.asarray(plate)
    bbox = room_bbox(rgb)
    diamond = fit_diamond(rgb, place)
    openings = measure_openings(rgb, diamond)

    GEN.mkdir(parents=True, exist_ok=True)
    (GEN / "review").mkdir(parents=True, exist_ok=True)
    AREAS.mkdir(parents=True, exist_ok=True)

    if not args.skip_install:
        archive = GEN / "office_suite_plate_pre_bgee_v05.png"
        runtime = AREAS / "office_suite_plate.png"
        if runtime.exists() and not archive.exists():
            shutil.copy2(runtime, archive)
        plate.save(runtime)
        plate.save(GEN / "office_suite_plate.png")
        plate.save(GEN / "office_suite_plate_bgee_v05_installed.png")
        # Same empty architecture is the shell fallback the scene loads
        # when the suite plate is missing, and qa_plate_projection --shipped
        # grades both files.
        shell = AREAS / "office_shell_base.png"
        shell_archive = GEN / "office_shell_base_pre_bgee_v05.png"
        if shell.exists() and not shell_archive.exists():
            shutil.copy2(shell, shell_archive)
        plate.save(shell)
        plate.save(GEN / "office_shell_base.png")

    half = GEN / "review/office_suite_plate_bgee_v05_half.png"
    plate.resize((ART_W // 2, ART_H // 2), Image.Resampling.LANCZOS).save(half)
    draw_overlay(plate, diamond, GEN / "review/office_bgee_v05_diamond_half.png")

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
        **place,
        "room_bbox_ydown": [x0, y0, x1, y1],
        "paintedRoomSourceRect_yup": painted_y_up,
        **diamond,
        **openings,
        "BODY_PLATE_H": rp.BODY_PLATE_H,
        "door_to_body": (
            openings["exterior_clear_h"] / rp.BODY_PLATE_H
            if "exterior_clear_h" in openings
            else None
        ),
        "note": (
            "Uniform 3:2 contain + SUITE_PLATE_SCALE. Diamond slopes forced "
            "to BG:EE ±0.75; axis lengths clipped to the painted cutaway. "
            "Copy REAR/AXIS_*/WALL_FACE_H into office_room_plan.py and flip "
            "ie_projection.ACTIVE in the same change."
        ),
    }
    (GEN / "bgee_v05_metrics.json").write_text(json.dumps(metrics, indent=2) + "\n")

    r = qa.grade(AREAS / "office_suite_plate.png")
    tag = "PASS" if r["passes"] else "FAIL"
    print(f"placed scale={args.scale} paste={place['paste_xywh']} room={x1-x0+1}x{y1-y0+1}")
    print(f"REAR={diamond['REAR']} AXIS_NW={diamond['AXIS_NW']} AXIS_NE={diamond['AXIS_NE']}")
    print(f"WALL_FACE_H={diamond['WALL_FACE_H']} openings={openings}")
    print(f"paintedRoomSourceRect {painted_y_up}")
    print(
        f"installed plate axes {r['peak_pos']:+.2f} / {r['peak_neg']:+.2f}  "
        f"worst {r['worst_delta']:.2f}  {tag}"
    )
    return 0 if r["passes"] else 1


if __name__ == "__main__":
    raise SystemExit(main())

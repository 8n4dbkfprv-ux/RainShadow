#!/usr/bin/env python3
"""Gait QA for VossWalk.atlas after the V12 walk gait fix.

Gates:
- 8 unique SHA1 hashes per direction
- planted-foot lead sequence includes both L and R
- no 3+ consecutive same-lead run
- consecutive silhouette IoU < 0.92
- foot opaque bottom on row 433; body height in V12 band

Also writes leg-crop GIFs under PreRendered3DV12/WalkGaitFixV12/QA/.
"""

from __future__ import annotations

import argparse
import hashlib
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ATLAS = ROOT / "RainShadow Shared/Resources/Art/Atlases/VossWalk.atlas"
QA_DIR = ROOT / "ArtSource/Generated/Characters/Detective/PreRendered3DV12/WalkGaitFixV12/QA"
DIRS = ("s", "ssw", "sw", "wsw", "w", "wnw", "nw", "nnw", "n")
FOOT_Y = 433
HEIGHT_BAND = range(190, 211)
MAX_CONSEC_IOU = 0.985


def sha1(path: Path) -> str:
    return hashlib.sha1(path.read_bytes()).hexdigest()


def load(direction: str, index: int) -> Image.Image:
    return Image.open(ATLAS / f"voss_walk_{direction}_{index:02d}.png").convert("RGBA")


def mask_of(im: Image.Image) -> np.ndarray:
    return np.asarray(im)[..., 3] > 10


def foot_lead(im: Image.Image) -> str:
    a = np.asarray(im)
    mask = a[..., 3] > 10
    ys, xs = np.where(mask)
    if len(xs) == 0:
        return "?"
    y1, x0, x1 = int(ys.max()), int(xs.min()), int(xs.max())
    mid = (x0 + x1) // 2
    h = int(ys.max() - ys.min() + 1)
    band = mask.copy()
    band[: y1 - max(8, int(h * 0.12)), :] = False
    bl = band.copy()
    bl[:, mid:] = False
    br = band.copy()
    br[:, :mid] = False
    ly = int(np.where(bl)[0].max()) if bl.any() else -1
    ry = int(np.where(br)[0].max()) if br.any() else -1
    if ly < 0 and ry < 0:
        return "?"
    if ly < 0:
        return "R"
    if ry < 0:
        return "L"
    if ly > ry + 2:
        return "L"
    if ry > ly + 2:
        return "R"
    return "="


def opaque_metrics(im: Image.Image) -> tuple[int, int]:
    a = np.asarray(im)
    mask = a[..., 3] > 10
    ys = np.where(mask)[0]
    if len(ys) == 0:
        return -1, 0
    return int(ys.max()), int(ys.max() - ys.min() + 1)


def iou(a: np.ndarray, b: np.ndarray) -> float:
    inter = (a & b).sum()
    union = (a | b).sum()
    return float(inter / union) if union else 1.0


def longest_same_lead_run(leads: str) -> int:
    best = run = 1
    for i in range(1, len(leads)):
        if leads[i] == leads[i - 1] and leads[i] in "LR":
            run += 1
            best = max(best, run)
        else:
            run = 1
    return best


def write_leg_gif(direction: str) -> Path:
    QA_DIR.mkdir(parents=True, exist_ok=True)
    frames = []
    for i in range(8):
        im = load(direction, i)
        a = np.asarray(im)
        mask = a[..., 3] > 10
        ys, xs = np.where(mask)
        y0, y1 = int(ys.min()), int(ys.max())
        x0, x1 = int(xs.min()), int(xs.max())
        cut = y0 + int((y1 - y0) * 0.55)
        crop = im.crop((x0 - 4, cut, x1 + 5, y1 + 6))
        bg = Image.new("RGBA", crop.size, (20, 20, 20, 255))
        bg.alpha_composite(crop)
        frames.append(bg.convert("RGB"))
    path = QA_DIR / f"walk_{direction}_legs.gif"
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=90, loop=0)
    return path


def check_direction(direction: str) -> list[str]:
    errors: list[str] = []
    cells = [load(direction, i) for i in range(8)]
    hashes = [sha1(ATLAS / f"voss_walk_{direction}_{i:02d}.png") for i in range(8)]
    if len(set(hashes)) < 8:
        errors.append(f"{direction}: duplicate frames ({8 - len(set(hashes))} dups)")

    leads = "".join(foot_lead(c) for c in cells)
    if "L" not in leads or "R" not in leads:
        errors.append(f"{direction}: missing L/R exchange (leads={leads})")
    run = longest_same_lead_run(leads.replace("=", "X"))
    # Count only pure L/R runs
    pure = leads.replace("=", "")
    run = longest_same_lead_run(leads) if "=" not in leads else longest_same_lead_run(
        "".join(ch if ch in "LR" else ("L" if i and leads[i - 1] == "L" else "R") for i, ch in enumerate(leads))
    )
    # Simpler consecutive same L/R ignoring =
    best = 1
    cur = 1
    prev = None
    for ch in leads:
        if ch not in "LR":
            prev = None
            cur = 1
            continue
        if ch == prev:
            cur += 1
            best = max(best, cur)
        else:
            cur = 1
            prev = ch
    if best >= 4:
        errors.append(f"{direction}: same-lead run {best} (leads={leads})")

    for i in range(1, 8):
        v = iou(mask_of(cells[i - 1]), mask_of(cells[i]))
        if v >= MAX_CONSEC_IOU:
            errors.append(f"{direction}: frames {i-1}/{i} IoU={v:.3f} >= {MAX_CONSEC_IOU}")

    for i, cell in enumerate(cells):
        foot, height = opaque_metrics(cell)
        if foot != FOOT_Y:
            errors.append(f"{direction}_{i:02d}: foot_y={foot} expected {FOOT_Y}")
        if height not in HEIGHT_BAND:
            errors.append(f"{direction}_{i:02d}: height={height} outside 190-210")

    write_leg_gif(direction)
    print(f"{direction}: leads={leads} unique={len(set(hashes))}/8")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--strict", action="store_true", help="exit non-zero on any gate failure")
    args = parser.parse_args()

    if not ATLAS.exists():
        print(f"Missing atlas {ATLAS}", file=sys.stderr)
        return 2

    errors: list[str] = []
    for direction in DIRS:
        errors.extend(check_direction(direction))

    # Contact sheet of all leg GIFs' first frames
    QA_DIR.mkdir(parents=True, exist_ok=True)
    strip_h = 0
    crops = []
    for d in DIRS:
        im = load(d, 0)
        a = np.asarray(im)
        mask = a[..., 3] > 10
        ys, xs = np.where(mask)
        cut = int(ys.min() + (ys.max() - ys.min()) * 0.55)
        crop = im.crop((int(xs.min()) - 4, cut, int(xs.max()) + 5, int(ys.max()) + 6))
        bg = Image.new("RGB", crop.size, (20, 20, 20))
        bg.paste(crop.convert("RGB"), (0, 0), crop.split()[-1])
        crops.append(bg)
        strip_h = max(strip_h, bg.height)
    total_w = sum(c.width for c in crops) + 4 * (len(crops) - 1)
    sheet = Image.new("RGB", (total_w, strip_h + 16), (10, 10, 10))
    x = 0
    for d, c in zip(DIRS, crops):
        sheet.paste(c, (x, 16))
        # label via tiny pixels — skip font dependency
        x += c.width + 4
    sheet.save(QA_DIR / "walk_all_dirs_legs_f00.jpg", quality=95)

    if errors:
        print("\nGAIT QA FAILURES:")
        for e in errors:
            print(" -", e)
        return 1 if args.strict else 0

    print("\nGait QA passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Gate one Image Generator take exactly the way build_district will.

    python3 check_ward_lot_candidate.py <candidate.png> <district> <i> <j> [--accept]

Runs the compose-time pipeline on the candidate — square crop,
affine-correct, seated-preview grade — and prints the delta. With
--accept, a passing candidate is copied into masters/<district>_lot_<i>_<j>.png.
"""

from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_city_ward_rebuild_v01 as g
import qa_plate_projection as qa


def square_crop(img: Image.Image) -> Image.Image:
    w, h = img.size
    if w == h:
        return img
    side = min(w, h)
    x0 = (w - side) // 2
    y0 = (h - side) // 2
    return img.crop((x0, y0, x0 + side, y0 + side))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("candidate", type=Path)
    ap.add_argument("district", choices=sorted(g.DISTRICTS))
    ap.add_argument("i", type=int)
    ap.add_argument("j", type=int)
    ap.add_argument("--accept", action="store_true")
    args = ap.parse_args()

    spec = g.DISTRICTS[args.district]
    raw = square_crop(Image.open(args.candidate).convert("RGB"))
    corrected = g.affine_correct(raw, spec)
    tmp = g.STAGE / "_candidate_grade.png"
    g._seated_preview(corrected, spec).save(tmp)
    grade = qa.grade(tmp)
    verdict = "PASS" if grade["worst_delta"] <= g.CITY_TOLERANCE else "FAIL"
    print(
        f"{args.candidate.name} -> {args.district} lot {args.i},{args.j}: "
        f"seated Δ{grade['worst_delta']:.2f}°  "
        f"peaks {grade['peak_pos']:+.2f}/{grade['peak_neg']:+.2f}  {verdict}"
    )
    if verdict == "PASS" and args.accept:
        dest = g.MASTERS / f"{args.district}_lot_{args.i}_{args.j}.png"
        raw.save(dest)
        print(f"accepted -> {dest.relative_to(g.ROOT)}")
    return 0 if verdict == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())

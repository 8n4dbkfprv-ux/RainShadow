#!/usr/bin/env python3
"""QA: Baldur's Gate: EE projection constants and round-trips.

Run: python3 ArtSource/Processing/qa_ie_projection.py
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ie_projection as ie
import office_room_plan as rp
import office_layout_plan as ol


def main() -> int:
    errors: list[str] = []

    if abs(ie.GROUND_FORESHORTEN - 0.75) > 1e-15:
        errors.append("GROUND_FORESHORTEN")
    if abs(ie.HEIGHT_FORESHORTEN - math.sqrt(1 - 0.75**2)) > 1e-12:
        errors.append("HEIGHT_FORESHORTEN")
    if ie.DIAMOND_W != 128 or ie.DIAMOND_H != 96:
        errors.append("diamond size")
    if ie.DIAMOND_W / ie.ELLIPSE_A != ie.DIAMOND_H / ie.ELLIPSE_B:
        errors.append("diamond does not span 8×8 search cells")
    if ie.HALF_STEP_X != 64 or ie.HALF_STEP_Y != 48:
        errors.append("half-steps")

    for c, r in ((0, 0), (1, 0), (0, 1), (3, 5), (-2, 4)):
        p = ie.cell_to_authored(c, r, origin_y=100.0)
        back = ie.authored_to_cell(*p, origin_y=100.0)
        if back != (c, r):
            errors.append(f"round-trip {(c, r)} -> {p} -> {back}")

    if abs(abs(rp.NW_TOP_SLOPE) - ie.GROUND_SLOPE) > 1e-12:
        errors.append(f"AXIS_NW slope {rp.NW_TOP_SLOPE}")
    if abs(abs(rp.NE_TOP_SLOPE) - ie.GROUND_SLOPE) > 1e-12:
        errors.append(f"AXIS_NE slope {rp.NE_TOP_SLOPE}")

    if ol.CELL_RECT != ie.CELL_RECT:
        errors.append("layout CELL_RECT drift")
    if ol.PARTITION_CELL_RECT != ie.PARTITION_CELL_RECT:
        errors.append("layout PARTITION_CELL_RECT drift")

    # Planner report must stay green after projection adoption.
    if not ol.report():
        errors.append("office_layout_plan.report() failed")

    if errors:
        print("FAIL:")
        for e in errors:
            print(" ", e)
        return 1
    print("qa_ie_projection PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

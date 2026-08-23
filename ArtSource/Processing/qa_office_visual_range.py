#!/usr/bin/env python3
"""Grade whether the office floor diamond fits Infinity Engine visual range.

Baldur's Gate indoor fog looks like room diamonds because each enclosure is
smaller than creature stat #262 (default 14 search cells, diameter 28). This
measures the painted floor quad from `office_room_plan` in search-cell space,
the same metric `SearchMap.visibleCells` uses.

    python3 ArtSource/Processing/qa_office_visual_range.py

Exit non-zero when the floor's cell-grid diameter exceeds 28. Do not drop
`fillsEnclosedRooms` on the office until this passes after a V16 install.
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import office_room_plan as rp

DEFAULT_RANGE = 14
FOCUS = (2048.0, 1152.0)
CELL = (16.0, 12.0)


def world(plate: tuple[float, float]) -> tuple[float, float]:
    env = rp.ENVIRONMENT_SCALE
    return (
        FOCUS[0] + (plate[0] - FOCUS[0]) * env,
        FOCUS[1] + (plate[1] - FOCUS[1]) * env,
    )


def cell(plate: tuple[float, float]) -> tuple[float, float]:
    origin = world((0.0, 0.0))
    x, y = world(plate)
    return ((x - origin[0]) / CELL[0], (y - origin[1]) / CELL[1])


def floor_corners() -> list[tuple[float, float]]:
    rear = rp.REAR
    west = (rear[0] + rp.AXIS_NW[0], rear[1] + rp.AXIS_NW[1])
    east = (rear[0] + rp.AXIS_NE[0], rear[1] + rp.AXIS_NE[1])
    near = rp.NEAR
    return [rear, west, near, east]


def diameter_cells(points: list[tuple[float, float]]) -> float:
    cells = [cell(p) for p in points]
    dmax = 0.0
    for i, (c0, r0) in enumerate(cells):
        for c1, r1 in cells[i + 1 :]:
            dmax = max(dmax, math.hypot(c1 - c0, r1 - r0))
    return dmax


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--max-diameter",
        type=float,
        default=float(2 * DEFAULT_RANGE),
        help="maximum cell-grid diameter (default 28 = 2× visual range 14)",
    )
    args = parser.parse_args(argv)

    corners = floor_corners()
    diam = diameter_cells(corners)
    nw = math.hypot(rp.AXIS_NW[0], rp.AXIS_NW[1]) * rp.ENVIRONMENT_SCALE
    ne = math.hypot(rp.AXIS_NE[0], rp.AXIS_NE[1]) * rp.ENVIRONMENT_SCALE
    status = "PASS" if diam <= args.max_diameter else "FAIL"
    print(f"office floor axes world: NW {nw:.1f}  NE {ne:.1f}")
    print(f"{status} floor cell-grid diameter {diam:.1f} (max {args.max_diameter:.0f})")
    if status == "FAIL":
        print(
            "Keep indoor room-flood until V16 shrinks or splits this diamond. "
            "See ArtSource/Prompts/office_reference_rebuild_v16.md."
        )
        return 1
    print("ALL_PASS=True")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

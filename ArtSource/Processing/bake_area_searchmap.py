#!/usr/bin/env python3
"""Bake an Infinity Engine style search map for every shipped area.

An IE area ships an ``SR.BMP`` at one pixel per search cell, whose palette index
says whether a creature can walk there, whether sight and projectiles cross, and
what the ground sounds like underfoot. RainShadow's search map used to be a
single passable bit rasterised from axis-aligned rectangles, so a wooden floor,
a wet cobble street and a stretch of harbour water were the same cell and the
footstep sound had to be a per-scene constant.

This writes that raster:

    RainShadow Shared/Resources/Areas/<area>.sr.png   8-bit grey, value = index
    ArtSource/Generated/Areas/<area>.sr_review.png    BG's own palette, for eyes

**The bake is derived from authored world-space geometry, not traced off a
painted plate.** ``ie_projection.ACTIVE`` is still ``LEGACY_V2`` and every
shipped plate currently fails ``qa_plate_projection.py``, so tracing walkability
off the art would bake today's camera error into navigation. Reading the same
obstacle rectangles the runtime reads keeps this independent of the projection
migration.

Consequently this bake **reproduces** current walkability rather than improving
it: the same rectangles in, the same open cells out, plus a terrain type. In
particular it does not invent the office's missing walls — the office rasterises
as walkable across nearly its whole painted rect, and fixing that means fitting
a floor diamond in ``office_room_plan.py``, not painting over it here.

Usage:
    python3 ArtSource/Processing/bake_area_searchmap.py            # all areas
    python3 ArtSource/Processing/bake_area_searchmap.py office_suite
"""

from __future__ import annotations

import json
import math
import pathlib
import sys

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
AREAS = ROOT / "RainShadow Shared" / "Resources" / "Areas"
REVIEW = ROOT / "ArtSource" / "Generated" / "Areas"

# Must match `SearchMap.defaultCellSize` — GemRB's 16x12 search cell, which is
# also the 16:12 ground ellipse the whole projection lock is built on.
CELL_W, CELL_H = 16.0, 12.0

# Must match `SearchMapTerrain`. Index is the byte written into the raster.
TERRAIN_INDEX = {
    "obstacle": 0,
    "sand": 1,
    "wood": 2,
    "wood-creaking": 3,
    "stone-echoey": 4,
    "grass": 5,
    "water": 6,
    "stone": 7,
    "obstacle-see-through": 8,
    "wood-creaking-alt": 9,
    "wall": 10,
    "water-shallow": 11,
    "water-impassable": 12,
    "roof": 13,
    "worldmap-exit": 14,
    "grass-alt": 15,
}

# `SearchMapTerrain.reviewColor`, kept in step by `qa_area_searchmap.py`.
REVIEW_COLOR = {
    0: (0, 0, 0),
    1: (128, 0, 32),
    2: (0, 100, 0),
    3: (139, 105, 20),
    4: (0, 0, 139),
    5: (128, 0, 128),
    6: (64, 224, 208),
    7: (192, 192, 192),
    8: (64, 64, 64),
    9: (255, 0, 0),
    10: (0, 255, 0),
    11: (255, 255, 0),
    12: (0, 0, 255),
    13: (255, 0, 255),
    14: (0, 255, 255),
    15: (255, 255, 255),
}

WALKABLE = {1, 2, 3, 4, 5, 6, 7, 9, 11, 15}


def rects_equal(a: dict, b: dict, eps: float = 0.001) -> bool:
    return (
        abs(a["x"] - b["x"]) < eps
        and abs(a["y"] - b["y"]) < eps
        and abs(a["w"] - b["w"]) < eps
        and abs(a["h"] - b["h"]) < eps
    )


def bake(area: dict) -> tuple[Image.Image, Image.Image, dict]:
    """Rasterise one area exactly the way ``SearchMap`` does.

    ``rasterizeStaticObstacles`` tests the **cell centre** against each obstacle
    with ``CGRect.contains``, which is half-open: ``minX <= x < maxX``. Both
    details matter. Testing corners instead would eat floor at every boundary
    cell, and a closed interval would block one extra column and row per
    rectangle — across ~750 office obstacles that is a visibly different room.
    """
    origin_x = area.get("worldOrigin", {}).get("x", 0.0)
    origin_y = area.get("worldOrigin", {}).get("y", 0.0)
    width = area["worldSize"]["w"]
    height = area["worldSize"]["h"]

    columns = max(1, math.ceil(width / CELL_W))
    rows = max(1, math.ceil(height / CELL_H))

    default = TERRAIN_INDEX[area.get("defaultTerrain", "stone")]

    # Door leaves are stamped at runtime so they can open; they are authored in
    # `obstacles` too, and baking them solid would weld the door shut.
    doors = [d["closedObstacle"] for d in area.get("doors", [])]
    obstacles = [
        o
        for o in area.get("obstacles", [])
        if not any(rects_equal(o, d) for d in doors)
    ]

    # Index 8 blocks movement and passes sight; index 0 blocks both. Every
    # rectangle used to bake as 0, which was invisible while fog was a disc and
    # wrong the moment fog started reading the search map: the office desk
    # shadowed the far wall. Walkability is identical either way — both indices
    # are outside `WALKABLE` — so this changes sight and nothing else.
    permeable = area.get("sightPermeableObstacles", [])
    solid_index = TERRAIN_INDEX["obstacle"]
    permeable_index = TERRAIN_INDEX["obstacle-see-through"]

    def obstacle_index(rect: dict) -> int:
        return (
            permeable_index
            if any(rects_equal(rect, p) for p in permeable)
            else solid_index
        )

    # Bucket obstacles by cell column range so a 750-rect office does not cost
    # 750 tests per cell.
    buckets: dict[int, list[dict]] = {}
    for rect in obstacles:
        rect = dict(rect, _index=obstacle_index(rect))
        first = max(0, int((rect["x"] - origin_x) // CELL_W))
        last = min(columns - 1, int((rect["x"] + rect["w"] - origin_x) // CELL_W))
        for column in range(first, last + 1):
            buckets.setdefault(column, []).append(rect)

    # `ceil` can leave a final partial column or row whose *centre* falls
    # outside the world — the office is 1617.92 wide, so column 101 of 102 is
    # centred 6.08 units past the east edge. `rasterizeStaticObstacles` blocks
    # those (`!contains(point)`), and a bake that does not reproduce it opens a
    # one-cell strip of phantom floor down the far edge of every area whose size
    # is not a whole number of cells.
    eps = 0.001
    max_x = origin_x + width
    max_y = origin_y + height

    indices = bytearray(columns * rows)
    blocked_cells = 0
    for row in range(rows):
        cy = origin_y + (row + 0.5) * CELL_H
        outside_row = not (origin_y - eps <= cy <= max_y + eps)
        for column in range(columns):
            cx = origin_x + (column + 0.5) * CELL_W
            solid = outside_row or not (origin_x - eps <= cx <= max_x + eps)
            # Outside the world reads as index 0, matching `!contains(point)`.
            value = solid_index if solid else None
            if not solid:
                for rect in buckets.get(column, ()):
                    if (
                        rect["x"] <= cx < rect["x"] + rect["w"]
                        and rect["y"] <= cy < rect["y"] + rect["h"]
                    ):
                        # First rectangle wins, and a solid one is authored
                        # before any permeable one, so a desk pushed against a
                        # wall does not punch a window through it.
                        value = rect["_index"]
                        solid = True
                        break
            if value is None:
                value = default
            indices[row * columns + column] = value
            if solid:
                blocked_cells += 1

    # World rows run bottom-up, PNG rows run top-down.
    flipped = bytearray(columns * rows)
    for row in range(rows):
        src = row * columns
        dst = (rows - 1 - row) * columns
        flipped[dst : dst + columns] = indices[src : src + columns]

    grey = Image.frombytes("L", (columns, rows), bytes(flipped))
    review = Image.new("RGB", (columns, rows))
    review.putdata([REVIEW_COLOR[v] for v in flipped])

    total = columns * rows
    stats = {
        "columns": columns,
        "rows": rows,
        "cells": total,
        "blocked": blocked_cells,
        "sightPermeable": sum(1 for v in indices if v == permeable_index),
        "walkableFraction": (total - blocked_cells) / total,
    }
    return grey, review, stats


def main(argv: list[str]) -> int:
    wanted = set(argv[1:])
    files = sorted(AREAS.glob("*.area.json"))
    if not files:
        print(f"no area files under {AREAS}", file=sys.stderr)
        return 1

    REVIEW.mkdir(parents=True, exist_ok=True)
    for path in files:
        area = json.loads(path.read_text())["area"]
        area_id = area["id"]
        if wanted and area_id not in wanted:
            continue
        # A cinematic backdrop has no navigable floor; baking one would assert
        # a walkable street where the scene never lets you walk.
        if not area.get("obstacles"):
            print(f"{area_id:22} skipped (no authored obstacles)")
            continue

        grey, review, stats = bake(area)
        grey.save(AREAS / f"{area_id}.sr.png", optimize=True)
        review.resize((review.width * 2, review.height * 2), Image.NEAREST).save(
            REVIEW / f"{area_id}.sr_review.png"
        )
        print(
            f"{area_id:22} {stats['columns']:>4}x{stats['rows']:<4} "
            f"walkable {stats['walkableFraction'] * 100:5.1f}%  "
            f"({stats['cells'] - stats['blocked']}/{stats['cells']} cells)"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

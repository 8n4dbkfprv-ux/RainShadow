#!/usr/bin/env python3
"""Grade the baked area search maps.

`bake_area_searchmap.py` writes them; this measures them. Three questions, in
the order they can go wrong:

1. **Is the colour table still in step?** The Python side carries its own copy
   of `SearchMapTerrain.reviewColor` and `SearchMapTerrain`'s index names. A
   drift there is silent — the bake keeps running, the raster keeps loading, and
   only the review renders lie. This greps the Swift enum and compares.

2. **Is the floor one connected space?** `AGENTS.md` records three shipped bugs
   where it was not: the office sealed to 174 of 4,694 cells, Harborpoint PD
   with 1 of 5,795 reachable, and an office door with no exact path. A flood
   fill from the area's default entrance answers this the honest way.

3. **Is the open fraction plausible for the kind of area it is?** Baldur's Gate
   outdoor areas run roughly 30–45% open. A number far above that usually means
   the obstacles do not model the architecture — which is exactly the state the
   office is in, and is reported rather than treated as a pass.

Exit status is non-zero when a raster is unreadable, disconnected, or disagrees
with the Swift table, so this can gate an install. A merely surprising open
fraction is reported and does not fail: the office is knowingly permissive and
failing on it would make the gate useless until that is fixed.

Usage:
    python3 ArtSource/Processing/qa_area_searchmap.py
    python3 ArtSource/Processing/qa_area_searchmap.py city_sable_row
"""

from __future__ import annotations

import collections
import json
import math
import pathlib
import re
import sys

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
AREAS = ROOT / "RainShadow Shared" / "Resources" / "Areas"
TERRAIN_SWIFT = (
    ROOT / "RainShadow Shared" / "Gameplay" / "Navigation" / "SearchMapTerrain.swift"
)

CELL_W, CELL_H = 16.0, 12.0

# Infinity Engine outdoor areas sit roughly here. Interiors are legitimately
# more open, so the band is advisory for them.
IE_OUTDOOR_BAND = (0.30, 0.45)

WALKABLE = {1, 2, 3, 4, 5, 6, 7, 9, 11, 15}
NAMES = {
    0: "obstacle", 1: "sand", 2: "wood", 3: "wood-creaking", 4: "stone-echoey",
    5: "grass", 6: "water", 7: "stone", 8: "obstacle-see-through",
    9: "wood-creaking-alt", 10: "wall", 11: "water-shallow",
    12: "water-impassable", 13: "roof", 14: "worldmap-exit", 15: "grass-alt",
}


def swift_review_colors() -> dict[int, tuple[int, int, int]]:
    """Parse `reviewColor` out of the Swift enum, so it stays the one authority."""
    text = TERRAIN_SWIFT.read_text()
    order = [
        "obstacle", "sand", "wood", "woodCreaking", "stoneEchoey", "grass",
        "water", "stone", "obstacleSeeThrough", "woodCreakingAlt", "wall",
        "waterShallow", "waterImpassable", "roof", "worldMapExit", "grassAlt",
    ]
    body = text.split("var reviewColor", 1)[1]
    found: dict[str, tuple[int, int, int]] = {}
    for case, r, g, b in re.findall(
        r"case \.(\w+):\s*\((\d+),\s*(\d+),\s*(\d+)\)", body
    ):
        found[case] = (int(r), int(g), int(b))
    return {order.index(k): v for k, v in found.items() if k in order}


def flood(indices: bytes, columns: int, rows: int, start: int) -> int:
    """Four-way flood over walkable cells, matching the runtime's own fill."""
    if indices[start] not in WALKABLE:
        return 0
    seen = bytearray(columns * rows)
    seen[start] = 1
    queue = collections.deque([start])
    count = 0
    while queue:
        cell = queue.popleft()
        count += 1
        column, row = cell % columns, cell // columns
        for dc, dr in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            c, r = column + dc, row + dr
            if not (0 <= c < columns and 0 <= r < rows):
                continue
            nxt = r * columns + c
            if seen[nxt] or indices[nxt] not in WALKABLE:
                continue
            seen[nxt] = 1
            queue.append(nxt)
    return count


def main(argv: list[str]) -> int:
    wanted = set(argv[1:])
    failures: list[str] = []

    expected_colors = swift_review_colors()
    if len(expected_colors) != 16:
        print(
            f"FAIL  could not parse all 16 reviewColor entries from "
            f"{TERRAIN_SWIFT.name} (got {len(expected_colors)})"
        )
        return 1

    import bake_area_searchmap as bake  # same directory

    if bake.REVIEW_COLOR != expected_colors:
        for index in sorted(set(bake.REVIEW_COLOR) | set(expected_colors)):
            mine = bake.REVIEW_COLOR.get(index)
            theirs = expected_colors.get(index)
            if mine != theirs:
                failures.append(
                    f"review colour {index} ({NAMES[index]}): bake {mine} != Swift {theirs}"
                )
    if bake.TERRAIN_INDEX != {v: k for k, v in NAMES.items()}:
        failures.append("bake TERRAIN_INDEX disagrees with the terrain name table")

    for path in sorted(AREAS.glob("*.area.json")):
        area = json.loads(path.read_text())["area"]
        area_id = area["id"]
        if wanted and area_id not in wanted:
            continue
        name = area.get("searchMapName")
        if not name:
            print(f"{area_id:22} no search map authored")
            continue

        raster_path = AREAS / f"{name}.png"
        if not raster_path.exists():
            failures.append(f"{area_id}: {raster_path.name} is missing")
            continue

        image = Image.open(raster_path).convert("L")
        columns, rows = image.size
        expected_cols = max(1, math.ceil(area["worldSize"]["w"] / CELL_W))
        expected_rows = max(1, math.ceil(area["worldSize"]["h"] / CELL_H))
        if (columns, rows) != (expected_cols, expected_rows):
            failures.append(
                f"{area_id}: raster is {columns}x{rows}, area needs "
                f"{expected_cols}x{expected_rows}"
            )
            continue

        # PNG rows are top-down; flip to world order so a cell index matches the
        # runtime's (column, row).
        raw = image.tobytes()
        indices = bytearray(columns * rows)
        for row in range(rows):
            src = (rows - 1 - row) * columns
            indices[row * columns : (row + 1) * columns] = raw[src : src + columns]

        unknown = {v for v in set(indices) if v not in NAMES}
        if unknown:
            failures.append(f"{area_id}: raster carries unknown indices {sorted(unknown)}")

        origin_x = area.get("worldOrigin", {}).get("x", 0.0)
        origin_y = area.get("worldOrigin", {}).get("y", 0.0)
        entrances = {e["name"]: e["point"] for e in area.get("entrances", [])}
        default = entrances.get("default") or next(iter(entrances.values()), None)
        if default is None:
            failures.append(f"{area_id}: authors no entrance to flood from")
            continue

        column = int((default["x"] - origin_x) // CELL_W)
        row = int((default["y"] - origin_y) // CELL_H)
        start = row * columns + column
        reached = flood(bytes(indices), columns, rows, start)

        total = columns * rows
        walkable = sum(1 for v in indices if v in WALKABLE)
        open_fraction = walkable / total
        connected = reached / walkable if walkable else 0.0

        histogram = collections.Counter(indices)
        surfaces = ", ".join(
            f"{NAMES[i]} {n * 100 // total}%"
            for i, n in histogram.most_common(4)
        )

        note = ""
        if reached == 0:
            failures.append(f"{area_id}: default entrance is not on walkable ground")
            note = "  <- ENTRANCE NOT STANDABLE"
        elif connected < 0.90:
            failures.append(
                f"{area_id}: floor is fragmented — the entrance reaches "
                f"{reached} of {walkable} walkable cells ({connected:.1%})"
            )
            note = "  <- FRAGMENTED"
        elif not IE_OUTDOOR_BAND[0] <= open_fraction <= IE_OUTDOOR_BAND[1]:
            note = f"  <- outside the IE {IE_OUTDOOR_BAND[0]:.0%}-{IE_OUTDOOR_BAND[1]:.0%} band"

        print(
            f"{area_id:22} {columns:>4}x{rows:<4} open {open_fraction:6.1%} "
            f"connected {connected:6.1%}  [{surfaces}]{note}"
        )

    if failures:
        print()
        for failure in failures:
            print(f"FAIL  {failure}")
        return 1
    print("\nALL CHECKS PASS")
    return 0


if __name__ == "__main__":
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
    raise SystemExit(main(sys.argv))

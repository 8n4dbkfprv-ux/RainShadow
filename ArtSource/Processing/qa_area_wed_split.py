#!/usr/bin/env python3
"""Decide which of an area's placed sprites can be baked into its plate.

The Infinity Engine has no props. Static scenery is painted into the tileset;
an area separates out only wall polygons (occlusion, carrying no art), `.ARE`
animations, door tile-cells, and interactive polygons. Sable Row already follows
that shape — a streets plate plus one occlusion crop per occupied diamond, what
`city_sable_row_area_v02.md` calls the WED split. The office does not: it places
55 sprites at runtime and depth-sorts 36 of them.

Baking a sprite into the plate is only safe when the player can never stand
**behind** it. Depth sort puts a lower world-Y actor in front, so an actor at a
higher world Y than a prop draws behind it — and a baked prop, being background,
would then be drawn over by the actor that should be hidden by it. Anything the
player can get behind has to stay a separate object, or become an occlusion crop.

The test is therefore: within the sprite's rendered x-span, is there any
*reachable* floor further from the camera than its ground point?

Reachable, not merely walkable. The office rasterises 90.6% walkable because its
plate is letterboxed and only a band around the floor is sealed, so asking
"is anything walkable behind this" answers yes for almost every object and the
split comes out meaningless. Flooding from the area's first authored entrance
asks the question that matters.

Input is a runtime dump rather than parsed Swift, because the scene graph knows
the numbers the renderer actually used:

    RAINSHADOW_SKIP_INTRO=1 RAINSHADOW_START_SCENE=office \\
    RAINSHADOW_DUMP_PROPS=1 <RainShadow binary> 2>dump.txt

    python3 ArtSource/Processing/qa_area_wed_split.py office_suite dump.txt

Note `SKSpriteNode.size` already includes the node's scale; multiplying by
`xScale` again shrinks a bookshelf to nine world units and every object then
looks bakeable.
"""

from __future__ import annotations

import collections
import json
import pathlib
import sys

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
AREAS = ROOT / "RainShadow Shared" / "Resources" / "Areas"

CELL_W, CELL_H = 16.0, 12.0
WALKABLE = {1, 2, 3, 4, 5, 6, 7, 9, 11, 15}

# Layers drawn beneath every actor. Nothing can be behind them in the sense that
# matters, so they bake unconditionally.
ALWAYS_UNDER = {"floorEffects", "rearFixtures"}


def load_reachable(area: dict) -> tuple[set[int], int, int, float, float]:
    ox = area.get("worldOrigin", {}).get("x", 0.0)
    oy = area.get("worldOrigin", {}).get("y", 0.0)
    name = area.get("searchMapName")
    if not name:
        raise SystemExit(f"{area['id']} has no search map to flood")

    image = Image.open(AREAS / f"{name}.png").convert("L")
    columns, rows = image.size
    raw = image.tobytes()
    indices = bytearray(columns * rows)
    for row in range(rows):
        src = (rows - 1 - row) * columns
        indices[row * columns : (row + 1) * columns] = raw[src : src + columns]

    entrances = area.get("entrances", [])
    if not entrances:
        raise SystemExit(f"{area['id']} authors no entrance to flood from")
    point = entrances[0]["point"]
    start = int((point["y"] - oy) // CELL_H) * columns + int((point["x"] - ox) // CELL_W)

    seen = bytearray(columns * rows)
    seen[start] = 1
    queue = collections.deque([start])
    reachable = {start}
    while queue:
        cell = queue.popleft()
        reachable.add(cell)
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
    return reachable, columns, rows, ox, oy


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(__doc__)
        return 2
    area_id, dump_path = argv[1], pathlib.Path(argv[2])
    area = json.loads((AREAS / f"{area_id}.area.json").read_text())["area"]
    reachable, columns, rows, ox, oy = load_reachable(area)

    def can_stand_behind(px: float, py: float, half_w: float) -> bool:
        c0 = max(0, int((px - half_w - ox) // CELL_W))
        c1 = min(columns - 1, int((px + half_w - ox) // CELL_W))
        r0 = max(0, int((py + CELL_H - oy) // CELL_H))
        for row in range(r0, rows):
            for column in range(c0, c1 + 1):
                if row * columns + column in reachable:
                    return True
        return False

    text = dump_path.read_text()
    if "RAINSHADOW_PROPS_BEGIN" in text:
        text = text.split("RAINSHADOW_PROPS_BEGIN", 1)[1].split("RAINSHADOW_PROPS_END", 1)[0]

    bake: list[tuple[str, str, float]] = []
    keep: list[tuple[str, float, float, float]] = []
    for line in text.strip().splitlines():
        fields = line.split("\t")
        if len(fields) < 10:
            continue
        layer, name = fields[0], fields[1]
        px, py, width = float(fields[2]), float(fields[3]), float(fields[8])
        if layer in ALWAYS_UNDER:
            bake.append((layer, name, width))
        elif can_stand_behind(px, py, width / 2):
            keep.append((name, px, py, width))
        else:
            bake.append((layer, name, width))

    print(f"{area_id}: {len(reachable)} reachable floor cells\n")
    print(f"BAKE INTO THE PLATE  {len(bake)}")
    for layer, name, width in sorted(bake):
        print(f"  {name:34} [{layer}] width {width:6.1f}")
    print(f"\nKEEP AS OCCLUDING OBJECTS  {len(keep)}")
    for name, px, py, width in sorted(keep):
        print(f"  {name:34} ground({px:7.1f},{py:7.1f}) width {width:6.1f}")

    print(
        f"\n{len(bake)} of {len(bake) + len(keep)} sprites can be painted into the plate; "
        f"{len(keep)} need occlusion."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

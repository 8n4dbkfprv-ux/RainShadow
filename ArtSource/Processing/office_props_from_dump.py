#!/usr/bin/env python3
"""Turn a runtime sprite dump into authored `AreaProp` data.

The office places its scenery imperatively — texture names as string literals at
roughly sixty call sites inside `buildScene` — which is why its area record has
shipped with `props: []` since the record existed. This converts what the
renderer actually did into the data that should have described it.

Reading the scene graph rather than parsing Swift is the point. Placement runs
through `OfficeInteriorScale.mapPoint`, prop-relative scale tables and several
inline constructions; re-deriving that in a parser means re-implementing it and
hoping the two agree. The dump is what was drawn.

Four fields are recovered rather than copied:

* **depthBias.** The dump reports final `zPosition`. `BaseGameScene.updateDepth`
  computes it as `layerBase + (artHeight - y) * 0.5 + bias`, so the bias is what
  is left after removing the part that follows from position. Storing raw z
  instead would freeze the sort order against today's coordinates and break the
  moment a prop moved.
* **scale, not size.** Every office prop was placed by scaling a texture-sized
  sprite, so scale is what the scene meant and size is the consequence. The two
  are not interchangeable at runtime: `SKSpriteNode.size` and `xScale` multiply,
  and the entrance leaf animates its scale on every fall and every restore. A
  leaf rebuilt at an absolute size with `xScale` left at 1 renders at an eighth
  of itself the first time it stands back up.
* **texture identity.** A node's name is not its art: `office_worn_rug` draws
  `office_worn_rug_burgundy`. `GameArt` records the file each texture came from
  and the dump carries it.
* **warp.** The window is warped so its rails rise with the painted wall trim
  while both jambs stay vertical. Nothing else in the room is warped, and
  rebuilding it flat leaves a square window on a leaning wall.

Usage:
    RAINSHADOW_SKIP_INTRO=1 RAINSHADOW_START_SCENE=office \\
    RAINSHADOW_DUMP_PROPS=1 <binary> 2>dump.txt
    python3 ArtSource/Processing/office_props_from_dump.py dump.txt
"""

from __future__ import annotations

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "ArtSource" / "Generated" / "Office" / "office_props_v01.json"

# `SceneLayer`, and the scene's own art height, which `updateDepth` measures
# the sort key from. `OfficeInteriorScale.sourceArtSize.height`.
LAYER_Z = {
    "floorEffects": -9_000.0,
    "rearFixtures": -5_000.0,
    "depthWorld": 1_000.0,
    "occlusion": 5_000.0,
}
ART_HEIGHT = 2_304.0


def parse_warp(field: str) -> dict:
    """`<cols>x<rows>:x,y;x,y;...` -> the four named corners.

    Only the 1x1 grid is expressible as corners, and it is the only one the
    scene builds. Anything denser is a real subdivision and would need its own
    representation rather than being silently flattened into four points.
    """
    grid, _, points = field.partition(":")
    if grid != "1x1":
        raise SystemExit(f"unsupported warp grid {grid!r}: only 1x1 is expressible")
    corners = [tuple(float(n) for n in pair.split(",")) for pair in points.split(";")]
    if len(corners) != 4:
        raise SystemExit(f"1x1 warp with {len(corners)} corners, expected 4")
    # SpriteKit orders a 1x1 destination grid bottom row first, left to right.
    names = ["bottomLeft", "bottomRight", "topLeft", "topRight"]
    return {
        name: {"x": round(c[0], 6), "y": round(c[1], 6)}
        for name, c in zip(names, corners)
    }


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2
    text = pathlib.Path(argv[1]).read_text()
    if "RAINSHADOW_PROPS_BEGIN" in text:
        text = text.split("RAINSHADOW_PROPS_BEGIN", 1)[1].split("RAINSHADOW_PROPS_END", 1)[0]

    props = []
    # Node names are not unique — the office places two sprites both called
    # `office_visitor_armchair`. A record keyed on id has to tell them apart, so
    # repeats are numbered in placement order. The scene's own name is kept for
    # the first, so nothing that already refers to it by name has to change.
    seen: dict[str, int] = {}
    for line in text.strip().splitlines():
        f = line.split("\t")
        if len(f) < 23:
            continue
        layer, name = f[0], f[1]
        x, y = float(f[2]), float(f[3])
        scale_x, scale_y = float(f[4]), float(f[5])
        anchor_x, anchor_y = float(f[6]), float(f[7])
        z, alpha, blend = float(f[10]), float(f[11]), f[12]
        rotation, texture, warp = float(f[13]), f[20], f[22]

        # Only the depth layer sorts by position; elsewhere z is authored flat.
        if layer == "depthWorld":
            bias = z - (LAYER_Z[layer] + (ART_HEIGHT - y) * 0.5)
        else:
            bias = z - LAYER_Z[layer]

        seen[name] = seen.get(name, 0) + 1
        unique_id = name if seen[name] == 1 else f"{name}_{seen[name]}"

        prop = {
            "id": unique_id,
            "textureName": texture,
            "layer": layer,
            "groundPoint": {"x": round(x, 4), "y": round(y, 4)},
            # Six places, not four. The entrance leaf's anchor is 0.08903, and
            # rounding it to 0.089 moves the door by a fraction of a pixel — too
            # small to see and too easy to write off, which is exactly why it is
            # kept: the record should reproduce the scene, not approximate it.
            "anchorX": round(anchor_x, 6),
            "anchorY": round(anchor_y, 6),
            "depthBias": round(bias, 4),
            "alpha": round(alpha, 4),
            "blend": blend,
            "rotation": round(rotation, 6),
        }
        # `scale` is the shorthand for the uniform case, which is all of the
        # room but the window. Emitting both axes there too would just be noise
        # in a file people read.
        if round(scale_x, 6) == round(scale_y, 6):
            prop["scale"] = round(scale_x, 6)
        else:
            prop["scaleX"] = round(scale_x, 6)
            prop["scaleY"] = round(scale_y, 6)
        if warp != "-":
            prop["warp"] = parse_warp(warp)
        props.append(prop)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"props": props}, indent=2, sort_keys=True) + "\n")

    by_layer: dict[str, int] = {}
    for prop in props:
        by_layer[prop["layer"]] = by_layer.get(prop["layer"], 0) + 1
    print(f"wrote {OUT.relative_to(ROOT)}")
    print(f"  {len(props)} props: " + ", ".join(f"{k} {v}" for k, v in sorted(by_layer.items())))
    duplicates = [p["id"] for p in props if p["id"] != p["textureName"] and p["id"][-2:-1] == "_"
                  and p["id"][-1].isdigit()]
    if duplicates:
        print(f"  {len(duplicates)} numbered for a repeated node name: " + ", ".join(duplicates))
    renamed = [p for p in props if p["id"] != p["textureName"]]
    print(f"  {len(renamed)} whose node name differs from their art: "
          + ", ".join(p["id"] for p in renamed))
    blended = [p for p in props if p["blend"] != "alpha"]
    print(f"  {len(blended)} non-alpha blends: " + ", ".join(p["id"] for p in blended))
    warped = [p for p in props if "warp" in p]
    print(f"  {len(warped)} warped: " + ", ".join(p["id"] for p in warped))
    stretched = [p for p in props if "scaleX" in p]
    print(f"  {len(stretched)} non-uniform scale: " + ", ".join(p["id"] for p in stretched))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

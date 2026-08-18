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

Three fields are recovered rather than copied:

* **depthBias.** The dump reports final `zPosition`. `BaseGameScene.updateDepth`
  computes it as `layerBase + (artHeight - y) * 0.5 + bias`, so the bias is what
  is left after removing the part that follows from position. Storing raw z
  instead would freeze the sort order against today's coordinates and break the
  moment a prop moved.
* **worldSize.** `SKSpriteNode.size` already includes the node's scale, so it is
  the rendered world size directly. Multiplying by `xScale` again is the error
  that made a bookshelf nine units wide.
* **texture identity.** A node's name is not its art: `office_worn_rug` draws
  `office_worn_rug_burgundy`. `GameArt` records the file each texture came from
  and the dump carries it.

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
        if len(f) < 21:
            continue
        layer, name = f[0], f[1]
        x, y = float(f[2]), float(f[3])
        anchor_x, anchor_y = float(f[6]), float(f[7])
        w, h = float(f[8]), float(f[9])
        z, alpha, blend = float(f[10]), float(f[11]), f[12]
        rotation, texture = float(f[13]), f[20]

        # Only the depth layer sorts by position; elsewhere z is authored flat.
        if layer == "depthWorld":
            bias = z - (LAYER_Z[layer] + (ART_HEIGHT - y) * 0.5)
        else:
            bias = z - LAYER_Z[layer]

        seen[name] = seen.get(name, 0) + 1
        unique_id = name if seen[name] == 1 else f"{name}_{seen[name]}"

        props.append(
            {
                "id": unique_id,
                "textureName": texture,
                "layer": layer,
                "groundPoint": {"x": round(x, 4), "y": round(y, 4)},
                "anchorX": round(anchor_x, 4),
                "anchorY": round(anchor_y, 4),
                "worldSize": {"w": round(w, 4), "h": round(h, 4)},
                "depthBias": round(bias, 4),
                "alpha": round(alpha, 4),
                "blend": blend,
                "rotation": round(rotation, 6),
            }
        )

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
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

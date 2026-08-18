#!/usr/bin/env python3
"""Composite the office's scenery sprites into its area plate.

The Infinity Engine paints static scenery into the tileset and keeps only wall
polygons, animations, door tile-cells and interactive outlines separate. Sable
Row already works that way. The office does not: it places 55 sprites at
runtime. This bakes the ones that are genuinely scenery into
`office_suite_plate`, so the room becomes a painting with outlines over it
rather than a pile of depth-sorted sprites.

The composite happens here rather than by rendering the scene offscreen because
of density. The plate is 4096x2304 over 1617.92 world units — 2.53 px per unit,
which `qa_plate_density.py` gates. An `SKView` render tops out at the view's
backing scale, about 2 px/unit, and `AGENTS.md` is explicit that a plate is
never upscaled to reach `PLATE_SIZE`. So the sources are composited at native
resolution instead.

Faithfulness comes from the runtime dump, not from re-deriving placement:

    RAINSHADOW_SKIP_INTRO=1 RAINSHADOW_START_SCENE=office \\
    RAINSHADOW_DUMP_PROPS=1 <binary> 2>dump.txt

Every sprite reports the world position, size, anchor, alpha, blend mode and
rotation the renderer actually used. Two of those are not decoration: five of
the office's sprites are **additive** light casts, and their alphas run 0.28 to
0.68. Compositing them as plain alpha would wash the room out — a mistake that
reads as a lighting change rather than as a bug.

WHY THIS IS NOT INSTALLED
-------------------------
It measures its own blocker and refuses. The office's props are authored at a
**median 8.33 source pixels per world unit**; the plate holds **2.53**. Baking
therefore discards roughly 3.3x of their resolution — every one of the 55 is
downscaled, by 3.4x to 5.6x. An A/B against the live renderer showed the cost
plainly: the composited room matches to a mean of 1.33/765 per pixel, but the
window and the near furniture come back visibly softer.

That is not a flaw in the compositing, it is what baking *means* at this plate
density, and it is why the frozen decision in `Documentation/README.md` keeps
world props as separate runtime assets. Baldur's Gate can paint a desk into the
tileset because there the tileset *is* the native art. RainShadow's props are
3x denser than its plates, which makes them closer to BG's `.ARE` animations —
separate objects at their own fidelity — than to tileset pixels.

This becomes viable if the plate is ever regenerated at prop density (~13,500 px
across for the office, against today's 4,096), and `AGENTS.md` already notes the
office masters need regen under the V5 projection lock. Until then the script
stands as the measurement, and `--force` will write anyway for experiments.

WHAT WOULD NOT BE BAKED EVEN THEN
---------------------------------
The desk cluster. `deskFrontOccluder.zPosition = detective.zPosition + bias` is
recomputed every frame: the apron has to rise between the desk and a *seated*
actor's torso, which is a relationship with a moving object and not a fact about
the room. Baking it would weld the seated pose into the floor. The desk, its
occluders, its chair and the items on it therefore stay sprites, and the room
goes from 55 placed objects to roughly a dozen.

That is the same distinction the engine draws. A BG desk is tileset pixels
because nothing about it moves; anything that must sort against a creature per
frame is not scenery.
"""

from __future__ import annotations

import math
import pathlib
import sys

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
ART = ROOT / "RainShadow Shared" / "Resources" / "Art"
PLATE = ART / "Areas" / "DetectiveOffice" / "office_suite_plate.png"
OUT_DIR = ROOT / "ArtSource" / "Generated" / "Office" / "PlateBake"

# World rect the plate is drawn over: `OfficeNavigationLayout.navigationWorldBounds`.
WORLD_ORIGIN = (1239.04, 696.96)
WORLD_SIZE = (1617.92, 910.08)

# Layer roots, as `SceneLayer`. Effective draw order is this base plus the
# sprite's own zPosition, because the view sets `ignoresSiblingOrder`.
LAYER_Z = {
    "floorEffects": -9_000.0,
    "rearFixtures": -5_000.0,
    "depthWorld": 1_000.0,
    "occlusion": 5_000.0,
}

# Sprites that are not scenery. See the module docstring: the desk apron sorts
# against the seated actor every frame, so the whole cluster stays live.
NEVER_BAKE = {
    "office_desk_bare",
    "office_desk_chair",
    "office_desk_actor_occluder",
    "office_desk_front_occluder_v04",
    "office_desk_top_occluder",
    "office_desk_lamp",
    "office_desk_phone",
    "office_desk_typewriter",
    "office_desk_notebook",
    "office_desk_papers",
    "office_desk_ashtray",
    "office_desk_files",
}

def find_texture(name: str) -> pathlib.Path | None:
    matches = list(ART.rglob(f"{name}.png"))
    return matches[0] if matches else None


def parse(dump: pathlib.Path) -> list[dict]:
    text = dump.read_text()
    if "RAINSHADOW_PROPS_BEGIN" in text:
        text = text.split("RAINSHADOW_PROPS_BEGIN", 1)[1].split("RAINSHADOW_PROPS_END", 1)[0]
    sprites = []
    for line in text.strip().splitlines():
        f = line.split("\t")
        if len(f) < 21:
            continue
        sprites.append(
            {
                "layer": f[0],
                "name": f[1],
                "x": float(f[2]),
                "y": float(f[3]),
                "anchorX": float(f[6]),
                "anchorY": float(f[7]),
                "w": float(f[8]),
                "h": float(f[9]),
                "z": float(f[10]),
                "alpha": float(f[11]),
                "blend": f[12],
                "rotation": float(f[13]),
                "hidden": f[18] == "true",
                # The file the renderer actually drew, recorded by `GameArt`.
                # Two office nodes are named differently from their art — the rug
                # node draws `office_worn_rug_burgundy` — and resolving by node
                # name composited the wrong picture into a plate that then looked
                # almost right.
                "texture": f[20] if len(f) > 20 else f[1],
            }
        )
    return sprites


def composite(base: np.ndarray, sprite: dict, px_per_unit: float, plate_h: int) -> None:
    """Draw one sprite onto the float32 RGB plate, in place."""
    path = find_texture(sprite["texture"])
    if path is None:
        raise SystemExit(f"no texture {sprite['texture']} for node {sprite['name']}")

    dest_w = max(1, int(round(sprite["w"] * px_per_unit)))
    dest_h = max(1, int(round(sprite["h"] * px_per_unit)))
    art = Image.open(path).convert("RGBA").resize((dest_w, dest_h), Image.LANCZOS)
    if abs(sprite["rotation"]) > 1e-6:
        # SpriteKit rotates counter-clockwise about the anchor; PIL's `rotate`
        # is counter-clockwise too, and expand keeps the corners.
        art = art.rotate(math.degrees(sprite["rotation"]), resample=Image.BICUBIC, expand=True)
        dest_w, dest_h = art.size

    # World rect of the sprite, from its anchor.
    min_x = sprite["x"] - sprite["anchorX"] * sprite["w"]
    max_y = sprite["y"] + (1.0 - sprite["anchorY"]) * sprite["h"]
    left = int(round((min_x - WORLD_ORIGIN[0]) * px_per_unit))
    # World y is up, image y is down.
    top = int(round(plate_h - (max_y - WORLD_ORIGIN[1]) * px_per_unit))
    if abs(sprite["rotation"]) > 1e-6:
        left -= (dest_w - int(round(sprite["w"] * px_per_unit))) // 2
        top -= (dest_h - int(round(sprite["h"] * px_per_unit))) // 2

    # Clip to the plate.
    x0, y0 = max(0, left), max(0, top)
    x1 = min(base.shape[1], left + dest_w)
    y1 = min(base.shape[0], top + dest_h)
    if x0 >= x1 or y0 >= y1:
        return

    patch = np.asarray(art, dtype=np.float32)[y0 - top : y1 - top, x0 - left : x1 - left] / 255.0
    rgb, alpha = patch[..., :3], patch[..., 3:4] * sprite["alpha"]
    target = base[y0:y1, x0:x1]

    if sprite["blend"] == "add":
        # SpriteKit `.add`: source premultiplied by its alpha, added to the
        # destination. The five light casts in this room are all this.
        base[y0:y1, x0:x1] = np.clip(target + rgb * alpha, 0.0, 1.0)
    else:
        base[y0:y1, x0:x1] = rgb * alpha + target * (1.0 - alpha)


def density_report(sprites: list[dict], px_per_unit: float) -> tuple[float, int]:
    """Source pixels per world unit for each prop, against the plate's."""
    ratios = []
    for sprite in sprites:
        path = find_texture(sprite["texture"])
        if path is None or sprite["w"] <= 0:
            continue
        with Image.open(path) as art:
            ratios.append(art.size[0] / sprite["w"])
    if not ratios:
        return 0.0, 0
    ratios.sort()
    median = ratios[len(ratios) // 2]
    downscaled = sum(1 for r in ratios if r > px_per_unit * 1.05)
    return median, downscaled


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2
    force = "--force" in argv
    dump = pathlib.Path(argv[1])
    sprites = [s for s in parse(dump) if not s["hidden"]]

    plate = Image.open(PLATE).convert("RGB")
    plate_w, plate_h = plate.size
    px_per_unit = plate_w / WORLD_SIZE[0]
    base = np.asarray(plate, dtype=np.float32) / 255.0

    baked = [s for s in sprites if s["name"] not in NEVER_BAKE]
    kept = [s for s in sprites if s["name"] in NEVER_BAKE]
    baked.sort(key=lambda s: (LAYER_Z[s["layer"]] + s["z"]))

    median, downscaled = density_report(baked, px_per_unit)
    print(f"plate density      {px_per_unit:.2f} px/unit")
    print(f"prop density       {median:.2f} px/unit (median)")
    print(f"downscaled by bake {downscaled} of {len(baked)}")
    if median > px_per_unit * 1.25 and not force:
        print(
            f"\nREFUSING: baking would discard {median / px_per_unit:.1f}x of the props'"
            f" resolution.\nThe plate would need ~{int(median * WORLD_SIZE[0]):,} px across to"
            f" hold them. Pass --force to write anyway."
        )
        return 1

    for sprite in baked:
        composite(base, sprite, px_per_unit, plate_h)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out = OUT_DIR / "office_suite_plate_baked_v01.png"
    Image.fromarray((np.clip(base, 0, 1) * 255).round().astype(np.uint8)).save(out)

    print(f"plate      {plate_w}x{plate_h} at {px_per_unit:.3f} px/unit")
    print(f"baked in   {len(baked)} sprites")
    print(f"kept live  {len(kept)}: {', '.join(sorted(s['name'] for s in kept))}")
    print(f"wrote      {out.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

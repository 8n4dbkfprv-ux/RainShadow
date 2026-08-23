#!/usr/bin/env python3
"""Composite the office's static scenery sprites into its area plate.

The Infinity Engine paints static scenery into the tileset and keeps only wall
polygons, animations, door tile-cells and interactive outlines separate. Sable
Row already works that way. The office used to place 51 props at runtime. This
bakes the curated V03 noir scenery into `office_suite_plate`, so the room
becomes a painting with outlines over it rather than a pile of depth-sorted
sprites.

The composite happens here rather than by rendering the scene offscreen because
of density. The plate is 4096x2304 over 1617.92 world units — 2.53 px per unit,
which `qa_plate_density.py` gates. An `SKView` render tops out at the view's
backing scale, about 2 px/unit, and `AGENTS.md` is explicit that a plate is
never upscaled to reach `PLATE_SIZE`. So the sources are composited at native
resolution instead.

The checked-in prop manifest is the authority. It is itself recovered from a
runtime dump and then moved by `migrate_office_layout_v17.py`, so the bake
uses the same texture, scale, anchor, alpha, blend and ground point the runtime
would have used:

    python3 ArtSource/Processing/migrate_office_layout_v17.py
    python3 ArtSource/Processing/bake_office_plate.py --install

The props are denser than the plate (median 8.33 source pixels/world unit versus
2.53 plate pixels/world unit), so this is an intentional art-direction tradeoff:
the room gains the coherent, plate-first Infinity Engine construction at the
cost of downsampling static furniture to the area master's pixel density. The
script reports that cost and records the split instead of silently pretending
the source density survived.

WHAT IS NOT BAKED
-----------------
The desk cluster and its chairs. `deskFrontOccluder.zPosition = detective.zPosition + bias`
is recomputed every frame: the apron has to rise between the desk and a
*seated* actor's torso. Baking the desk would weld the seated pose into the
floor. The lamp, telephone, typewriter and paper props also remain live so the
scene can keep them above the live writing surface. The two visitor chairs stay
live because actors can pass both in front of and behind them.

That is the same distinction the engine draws. A BG desk is tileset pixels
because nothing about it moves; anything that must sort against a creature per
frame is not scenery.
"""

from __future__ import annotations

import hashlib
import json
import math
import pathlib
import shutil
import sys

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
ART = ROOT / "RainShadow Shared" / "Resources" / "Art"
PLATE = ART / "Areas" / "DetectiveOffice" / "office_suite_plate.png"
BASE_PLATE = (
    ROOT
    / "ArtSource"
    / "Generated"
    / "Office"
    / "BGEEReferenceV19"
    / "office_reference_rebuild_plate_v19.png"
)
PROPS = ROOT / "ArtSource" / "Generated" / "Office" / "office_props_v01.json"
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

# The shipping plate is the V19 shell with the two period radiators and the
# edge-on entrance door painted into the architecture. V03's restrained noir
# set keeps only furniture that must sort against actors as live SpriteKit
# nodes. Everything in BAKED_PROP_IDS below becomes area pixels.
LIVE_PROP_IDS = {
    "office_desk_bare",
    "office_desk_chair",
    "office_visitor_armchair",
    "office_visitor_armchair_2",
    "office_desk_lamp",
    "office_desk_phone",
    "office_desk_typewriter",
    "office_desk_notebook",
    "office_desk_papers",
    "office_desk_ashtray",
    "office_desk_files",
    "office_desk_actor_occluder",
    "office_desk_front_occluder_v04",
    "office_desk_top_occluder",
}

# Approved V03 production set: useful work surfaces and evidence, one compact
# records run, and a few lived-in accents. The former waiting-room suite,
# domestic sideboard, safe, second cabinet and ceiling-fan shadow are omitted to
# preserve the concept's negative space.
BAKED_PROP_IDS = {
    "office_floor_wear_decal",
    "office_light_window_spill",
    "office_light_blind_stripes",
    "office_light_blind_stripes_wall",
    "office_light_lamp_pool",
    "office_worn_rug",
    "office_desk_floor_shadow",
    "office_cabinet_floor_shadow",
    "office_case_board",
    "office_wall_city_map",
    "office_framed_licence",
    "office_floor_trash_a",
    "office_bookshelf",
    "office_filing_cabinet",
    "office_archive_box_b",
    "office_archive_box_a",
    "office_coat_rack",
    "office_umbrella_stand",
    "office_wastebasket",
}
BAKE_SCENERY = True

# The recovered runtime dump predates the AR0809 scale pass and would make the
# rug 1,106 px wide on this plate. The approved/reference-calibrated layout uses
# `0.22 * RUG_FACTOR / ENVIRONMENT`, which is 0.345316 plate pixels per source
# pixel: 503 px wide. Express that as a plate-space override so it remains exact
# even if WORLD_SIZE changes.
PLATE_SCALE_OVERRIDES = {
    "office_worn_rug": 0.22 * 0.62 / 0.395,
}

# V17 deliberately retired these casts for the empty-shell rebuild. V03 brings
# them back at restrained opacity: enough cool window structure to read as noir
# without bleaching the warm practical lighting already painted into the room.
ALPHA_OVERRIDES = {
    "office_light_window_spill": 0.20,
    "office_light_blind_stripes": 0.15,
    "office_light_blind_stripes_wall": 0.10,
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


def parse_manifest(path: pathlib.Path) -> list[dict]:
    """Resolve `AreaProp` records to the rendered geometry SpriteKit uses."""
    document = json.loads(path.read_text())
    sprites = []
    for order, prop in enumerate(document["props"]):
        texture = find_texture(prop["textureName"])
        if texture is None:
            raise SystemExit(f"no texture {prop['textureName']} for prop {prop['id']}")
        with Image.open(texture) as art:
            natural_w, natural_h = art.size
        scale_x = prop.get("scaleX", prop.get("scale", 1.0))
        scale_y = prop.get("scaleY", prop.get("scale", 1.0))
        if "worldSize" in prop:
            width = prop["worldSize"].get("width", prop["worldSize"].get("w"))
            height = prop["worldSize"].get("height", prop["worldSize"].get("h"))
            if width is None or height is None:
                raise SystemExit(f"invalid worldSize for prop {prop['id']}")
        else:
            width = natural_w * scale_x
            height = natural_h * scale_y

        layer = prop.get("layer", "depthWorld")
        point = prop["groundPoint"]
        depth_bias = prop.get("depthBias", 0.0)
        ordering = order * 0.001  # `BaseGameScene.propOrderStep`
        if layer == "depthWorld":
            local_z = LAYER_Z[layer] + (2304.0 - point["y"]) * 0.5 + depth_bias + ordering
        else:
            local_z = LAYER_Z[layer] + depth_bias + ordering
        sprites.append(
            {
                "layer": layer,
                "name": prop["id"],
                "x": point["x"],
                "y": point["y"],
                "anchorX": prop.get("anchorX", 0.5),
                "anchorY": prop["anchorY"],
                "w": width,
                "h": height,
                "z": local_z,
                "alpha": prop.get("alpha", 1.0),
                "blend": prop.get("blend", "alpha"),
                "rotation": prop.get("rotation", 0.0),
                "hidden": prop.get("alpha", 1.0) <= 0,
                "texture": prop["textureName"],
                "order": order,
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


def sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def apply_noir_grade(
    pixels: np.ndarray,
    room_mask: np.ndarray,
    *,
    focal_point: tuple[float, float],
) -> None:
    """Apply V03's cool, low-key perimeter without changing the shell geometry."""
    height, width = pixels.shape[:2]
    yy, xx = np.mgrid[0:height, 0:width]
    focal_x, focal_y = focal_point
    distance = ((xx - focal_x) / (width * 0.47)) ** 2
    distance += ((yy - focal_y) / (height * 0.56)) ** 2
    vignette = 0.70 + 0.30 * np.exp(-1.55 * distance)

    luminance = (
        pixels[..., 0:1] * 0.2126
        + pixels[..., 1:2] * 0.7152
        + pixels[..., 2:3] * 0.0722
    )
    desaturated = luminance + (pixels - luminance) * 0.78
    graded = np.power(np.clip(desaturated, 0.0, 1.0), 1.06)
    graded *= vignette[..., None] * 0.82

    # Slightly cool the shadows while preserving the amber practical lamps.
    shadow = np.clip((0.34 - luminance) / 0.34, 0.0, 1.0)
    graded[..., 0:1] *= 1.0 - shadow * 0.045
    graded[..., 2:3] *= 1.0 + shadow * 0.075
    pixels[room_mask] = np.clip(graded[room_mask], 0.0, 1.0)
    pixels[~room_mask] = 0.0


def main(argv: list[str]) -> int:
    install = "--install" in argv
    preview_live = "--preview-live" in argv
    positional = [arg for arg in argv[1:] if not arg.startswith("--")]
    source = pathlib.Path(positional[0]) if positional else PROPS
    sprites = parse_manifest(source) if source.suffix == ".json" else parse(source)
    for sprite in sprites:
        if sprite["name"] in ALPHA_OVERRIDES:
            sprite["alpha"] = ALPHA_OVERRIDES[sprite["name"]]
            sprite["hidden"] = False
    visible = [sprite for sprite in sprites if not sprite["hidden"]]

    # Never read the installed result: doing so would bake every static prop
    # into itself again on the next invocation.
    plate = Image.open(BASE_PLATE).convert("RGB")
    plate_w, plate_h = plate.size
    px_per_unit = plate_w / WORLD_SIZE[0]
    base = np.asarray(plate, dtype=np.float32) / 255.0
    room_mask = np.max(base, axis=2) > 0.0

    for sprite in visible:
        plate_scale = PLATE_SCALE_OVERRIDES.get(sprite["name"])
        if plate_scale is None:
            continue
        texture = find_texture(sprite["texture"])
        if texture is None:
            raise SystemExit(f"no texture {sprite['texture']} for node {sprite['name']}")
        with Image.open(texture) as art:
            natural_w, natural_h = art.size
        sprite["w"] = natural_w * plate_scale / px_per_unit
        sprite["h"] = natural_h * plate_scale / px_per_unit

    kept = [s for s in visible if s["name"] in LIVE_PROP_IDS]
    if BAKE_SCENERY:
        baked = [s for s in visible if s["name"] in BAKED_PROP_IDS]
        baked.sort(key=lambda s: (LAYER_Z[s["layer"]] + s["z"]))
        median, downscaled = density_report(baked, px_per_unit)
        print(f"plate density      {px_per_unit:.2f} px/unit")
        print(f"prop density       {median:.2f} px/unit (median)")
        print(f"downscaled by bake {downscaled} of {len(baked)}")
        print(f"static downsample  {median / px_per_unit:.1f}x (intentional plate-first tradeoff)")
        for sprite in baked:
            composite(base, sprite, px_per_unit, plate_h)
        desk_x = (2015.7322035200002 - WORLD_ORIGIN[0]) * px_per_unit
        desk_y = plate_h - (1162.476032 - WORLD_ORIGIN[1]) * px_per_unit
        apply_noir_grade(base, room_mask, focal_point=(desk_x, desk_y))
    else:
        baked = []
        print(f"plate density      {px_per_unit:.2f} px/unit")
        print("bake scenery      off (V19 shell already owns radiators and door)")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out = OUT_DIR / "office_suite_plate_baked_v19.png"
    Image.fromarray((np.clip(base, 0, 1) * 255).round().astype(np.uint8)).save(out)

    preview = None
    if preview_live:
        preview_base = base.copy()
        preview_sprites = sorted(kept, key=lambda s: (LAYER_Z[s["layer"]] + s["z"]))
        for sprite in preview_sprites:
            composite(preview_base, sprite, px_per_unit, plate_h)
        preview = OUT_DIR / "office_suite_runtime_preview_v19.png"
        Image.fromarray(
            (np.clip(preview_base, 0, 1) * 255).round().astype(np.uint8)
        ).save(preview)

    split = {
        "version": 19,
        "construction": (
            "V19 baked-radiator-and-door shell plus live desk/chair"
            if not BAKE_SCENERY
            else "approved V03 sparse noir plate plus registered live overlays"
        ),
        "basePlate": str(BASE_PLATE.relative_to(ROOT)),
        "basePlateSHA256": sha256(BASE_PLATE),
        "bakedPlate": str(out.relative_to(ROOT)),
        "bakedPlateSHA256": sha256(out),
        "bakedPropIDs": sorted(sprite["name"] for sprite in baked),
        "livePropIDs": sorted(sprite["name"] for sprite in kept),
        "retiredPropIDs": sorted(
            {
                sprite["name"]
                for sprite in sprites
                if sprite["name"] not in LIVE_PROP_IDS
                and sprite["name"] not in BAKED_PROP_IDS
            }
        ),
        "logicalDoorID": "office.door",
        "doorVisual": "baked into plate",
    }
    split_path = OUT_DIR / "office_plate_bake_manifest_v19.json"
    split_path.write_text(json.dumps(split, indent=2, sort_keys=True) + "\n")

    if install:
        shutil.copyfile(out, PLATE)

    print(f"plate      {plate_w}x{plate_h} at {px_per_unit:.3f} px/unit")
    print(f"baked in   {len(baked)} sprites")
    print(f"kept live  {len(kept)}: {', '.join(sorted(s['name'] for s in kept))}")
    print(f"wrote      {out.relative_to(ROOT)}")
    print(f"wrote      {split_path.relative_to(ROOT)}")
    if preview is not None:
        print(f"preview    {preview.relative_to(ROOT)}")
    if install:
        print(f"installed  {PLATE.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

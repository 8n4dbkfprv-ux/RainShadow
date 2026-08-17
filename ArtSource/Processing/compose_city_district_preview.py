#!/usr/bin/env python3
"""Render a city district offline, the way CityDistrictScene composes it.

There is no way to run SpriteKit on the art pipeline's machine, so a district
layout used to be unreviewable until someone opened Xcode. This renders the
same scene graph with Pillow: ground plate, then modular sprites depth-sorted
by ground Y.

It reads `ArtSource/Generated/CityDistrict/V2/city_layout.json`, which
`CityLayoutDumpTests` writes straight out of `CityDistrictCatalog`. The
previous version of this script re-declared every sprite in Python under a
"keep in step when it moves" comment; it did not stay in step, and by the time
anyone looked it was reviewing a 2048x1152 world that had not shipped for two
refactors. Reading the dump is what keeps this honest.

    swift test --scratch-path /tmp/RainShadowSwiftPM --filter CityLayoutDump
    python3 ArtSource/Processing/compose_city_district_preview.py --all
    python3 ArtSource/Processing/compose_city_district_preview.py riverside --nav
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
DUMP = ROOT / "ArtSource/Generated/CityDistrict/V2/city_layout.json"
AREAS = ROOT / "RainShadow Shared/Resources/Art/Areas/CityDistrict/V2"
PROPS = ROOT / "RainShadow Shared/Resources/Art/Props/CityDistrict/V2"
OUT = ROOT / "ArtSource/Generated/CityDistrict/V2/LayoutPreview"

# BaseGameScene.updateDepth: zPosition = (artHeight - y) * 0.5 + bias.
DEPTH_Y_FACTOR = 0.5


def load():
    if not DUMP.exists():
        sys.exit(
            f"missing {DUMP.relative_to(ROOT)}\n"
            "run: swift test --scratch-path /tmp/RainShadowSwiftPM --filter CityLayoutDump"
        )
    return json.loads(DUMP.read_text())


def texture(name: str) -> Image.Image | None:
    path = PROPS / f"{name}.png"
    if not path.exists():
        return None
    return Image.open(path).convert("RGBA")


def compose(layout: dict, district: dict, scale: float, nav: bool) -> Image.Image:
    world_w = layout["worldSize"]["w"]
    world_h = layout["worldSize"]["h"]
    px = lambda x: int(round(x * scale))
    py = lambda y: int(round((world_h - y) * scale))

    plate = AREAS / f"{district['groundTextureName']}.png"
    if plate.exists():
        canvas = Image.open(plate).convert("RGBA").resize(
            (px(world_w), px(world_h)), Image.LANCZOS
        )
    else:
        canvas = Image.new("RGBA", (px(world_w), px(world_h)), (26, 28, 32, 255))

    drawn = 0
    missing: set[str] = set()
    ordered = sorted(
        district["sprites"],
        key=lambda s: -((world_h - s["groundPoint"]["y"]) * DEPTH_Y_FACTOR + s["depthBias"]),
    )
    for sprite in ordered:
        art = texture(sprite["textureName"])
        if art is None:
            missing.add(sprite["textureName"])
            continue
        if "worldSize" in sprite:
            # SKSpriteNode(texture:size:) — draw at the authored world size.
            w = sprite["worldSize"]["w"] * scale
            h = sprite["worldSize"]["h"] * scale
        else:
            w = art.width * sprite["scale"] * scale
            h = art.height * sprite["scale"] * scale
        w, h = max(1, int(round(w))), max(1, int(round(h)))
        resized = art.resize((w, h), Image.LANCZOS)
        # anchorPoint = (0.5, anchorY), position = groundPoint.
        left = px(sprite["groundPoint"]["x"]) - w // 2
        top = py(sprite["groundPoint"]["y"]) - int(round(h * (1 - sprite["anchorY"])))
        canvas.alpha_composite(resized, (left, top))
        drawn += 1

    if nav:
        overlay = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        pen = ImageDraw.Draw(overlay)
        for rect in district["obstacles"]:
            pen.rectangle(
                [px(rect["x"]), py(rect["y"] + rect["h"]),
                 px(rect["x"] + rect["w"]), py(rect["y"])],
                fill=(255, 40, 40, 70),
            )
        for block in layout["blockGrid"]["blocks"]:
            pen.polygon(
                [(px(v["x"]), py(v["y"])) for v in block["vertices"]],
                outline=(90, 220, 255, 220),
            )
        canvas.alpha_composite(overlay)
        pen = ImageDraw.Draw(canvas)
        marks = [("start", district["actorStart"], (255, 235, 60))]
        marks += [(k, v, (120, 255, 140)) for k, v in district["spawns"].items()]
        marks += [(p["label"], p["approachPoint"], (255, 140, 220)) for p in district["portals"]]
        for label, pt, colour in marks:
            x, y = px(pt["x"]), py(pt["y"])
            pen.ellipse([x - 5, y - 5, x + 5, y + 5], fill=colour)
            pen.text((x + 8, y - 5), label, fill=colour)

    if missing:
        print(f"    missing textures: {', '.join(sorted(missing))}")
    print(f"    {drawn} sprites, {len(district['obstacles'])} obstacle rects")
    return canvas


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("slug", nargs="?", help="district slug, e.g. wharf_ladder")
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--nav", action="store_true", help="overlay obstacles, blocks and spawns")
    parser.add_argument("--scale", type=float, default=0.25)
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()

    layout = load()
    districts = layout["districts"]
    if args.all:
        chosen = districts
    elif args.slug:
        chosen = [d for d in districts if d["slug"] == args.slug or d["id"] == args.slug]
        if not chosen:
            sys.exit(f"unknown district {args.slug!r}; have {[d['slug'] for d in districts]}")
    else:
        sys.exit("pass a district slug or --all")

    OUT.mkdir(parents=True, exist_ok=True)
    for district in chosen:
        print(f"{district['slug']}:")
        image = compose(layout, district, args.scale, args.nav)
        suffix = "_nav" if args.nav else ""
        path = args.out or OUT / f"{district['slug']}{suffix}.png"
        image.convert("RGB").save(path)
        print(f"    -> {path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

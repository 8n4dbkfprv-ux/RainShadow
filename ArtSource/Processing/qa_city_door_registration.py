#!/usr/bin/env python3
"""Composite each city district the way the scene does, to check door registration.

City door leaves are no longer hand-placed: `CityDistrictLayout.doorLeaf` derives
each leaf's `groundPoint` from its facade's measured aperture. This renders what
that produces — ground plate, then every sprite in the scene's depth order — and
marks each facade's aperture and each leaf's painted foot, so a leaf that has
drifted onto a roof or out into the street is obvious at a glance.

    python3 ArtSource/Processing/qa_city_door_registration.py

Writes to ArtSource/Generated/CityDistrict/V2/DoorRegistrationQA/.
"""
from __future__ import annotations

import re
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
PROPS = ROOT / "RainShadow Shared/Resources/Art/Props/CityDistrict/V2"
AREAS = ROOT / "RainShadow Shared/Resources/Art/Areas/CityDistrict/V2"
NAV = ROOT / "RainShadow Shared/Gameplay/Navigation"
OUT = ROOT / "ArtSource/Generated/CityDistrict/V2/DoorRegistrationQA"

WORLD = (2048, 1152)
BUILDING_CANVAS = (512, 640)
DOOR_CANVAS = (256, 384)
DOOR_FOOT_INSET = 4
# OfficeInteriorScale.renderedStandingDetectiveBodyHeight
ADULT = 200 / 512 * 180
TARGET_DOOR_BODY_MULTIPLE = 1.15


def _round2(v: float) -> float:
    return round(v * 100) / 100


def door_anchored_scale(leaf: float) -> float:
    return _round2(TARGET_DOOR_BODY_MULTIPLE * ADULT / leaf)


def facade_anchored_scale(h: float, multiple: float = 7.0) -> float:
    return _round2(multiple * ADULT / h)


def load_layout() -> tuple[dict[str, tuple[int, int, int]], dict[str, float]]:
    src = (NAV / "CityDistrictLayout.swift").read_text()
    apertures = {
        n: (int(cx), int(ty), int(lh))
        for n, cx, ty, lh in re.findall(
            r"static let (\w+)\s*= Self\(centreX:\s*(\d+), thresholdY:\s*(\d+), leafHeight:\s*(\d+)\)", src)
    }
    scales: dict[str, float] = {}
    block = re.search(r"enum BuildingDisplayScale \{(.*?)\n    \}", src, re.S).group(1)
    for n, arg in re.findall(r"static let (\w+) = doorAnchoredScale\(doorLeaf: SourceDoorLeafHeight\.(\w+)\)", block):
        scales["BuildingDisplayScale." + n] = door_anchored_scale(apertures[arg][2])
    for n, h in re.findall(r"static let (\w+) = facadeAnchoredScale\(contentHeight: ([\d.]+)\)", block):
        scales["BuildingDisplayScale." + n] = facade_anchored_scale(float(h))
    for n in ("standard", "wide"):
        scales["DoorDisplayScale." + n] = door_anchored_scale(275)
    prop = re.search(r"enum PropDisplayScale \{(.*?)\n    \}", src, re.S).group(1)
    for n, v in re.findall(r"static let (\w+): CGFloat = ([\d.]+)", prop):
        scales["PropDisplayScale." + n] = float(v)
    return apertures, scales


APERTURES, SCALES = load_layout()

_content: dict[str, tuple[int, int, int, int]] = {}


def content(tex: str) -> tuple[int, int, int, int]:
    """Opaque bbox (x0, x1, y0, y1) inclusive, in canvas pixels."""
    if tex not in _content:
        a = np.array(Image.open(PROPS / f"{tex}.png").convert("RGBA").split()[-1])
        ys, xs = np.where(a > 28)
        _content[tex] = (int(xs.min()), int(xs.max()), int(ys.min()), int(ys.max()))
    return _content[tex]


def world_point(pixel: tuple[float, float], canvas: tuple[int, int], sprite: dict) -> tuple[float, float]:
    """Mirrors CityDistrictLayout.worldPoint(canvasPixel:canvas:sprite:)."""
    cw, ch = canvas
    bottom = sprite["y"] - sprite["anchorY"] * ch * sprite["scale"]
    return (sprite["x"] + (pixel[0] - cw / 2) * sprite["scale"],
            bottom + (ch - pixel[1]) * sprite["scale"])


def parse_catalog() -> dict[str, dict]:
    src = (NAV / "CityDistrictCatalog.swift").read_text()
    facades = {
        n: {"tex": tex, "x": float(x), "y": float(y), "scale": SCALES[sc], "anchorY": float(ay),
            "bias": float(db)}
        for n, tex, x, y, sc, ay, db in re.findall(
            r'private static let (\w+) = CityDistrictDefinition\.VisualSprite\(\s*'
            r'textureName: "([^"]+)", groundPoint: CGPoint\(x: ([\d.-]+), y: ([\d.-]+)\),\s*'
            r'scale: CityDistrictLayout\.([\w.]+), anchorY: ([\d.]+), depthBias: ([\d.]+)\s*\)', src)
    }
    districts: dict[str, dict] = {}
    for name, body in re.findall(
            r"static let (\w+) = CityDistrictDefinition\(.*?\n        visualSprites: \[\n(.*?)\n        \],\n", src, re.S):
        ground = re.search(r'static let %s = CityDistrictDefinition\(.*?groundTextureName: "([^"]+)"' % name, src, re.S).group(1)
        sprites, pairs = [], []
        for raw in re.findall(r"^\s+(?:\.init\(.*?\)|CityDistrictLayout\.doorLeaf\((?:[^()]|\([^()]*\))*\)|\w+),?$",
                              body, re.M | re.S):
            raw = raw.strip().rstrip(",")
            if raw in facades:
                sprites.append(dict(facades[raw])); continue
            m = re.match(r'\.init\(textureName: "([^"]+)", groundPoint: CGPoint\(x: ([\d.-]+), y: ([\d.-]+)\), '
                         r'scale: CityDistrictLayout\.([\w.]+), anchorY: ([\d.]+), depthBias: ([\d.]+)\)', raw)
            if m:
                tex, x, y, sc, ay, db = m.groups()
                sprites.append({"tex": tex, "x": float(x), "y": float(y), "scale": SCALES[sc],
                                "anchorY": float(ay), "bias": float(db)})
                continue
            if "doorLeaf" in raw:
                tex = re.search(r'textureName: "([^"]+)"', raw).group(1)
                owner = facades[re.search(r"on: (\w+)", raw).group(1)]
                ap = APERTURES[re.search(r"aperture: \.(\w+)", raw).group(1)]
                wide = "DoorDisplayScale.wide" in raw
                ahead = re.search(r"ahead: ([\d.]+)", raw)
                pt = world_point((ap[0], ap[1]), BUILDING_CANVAS, owner)
                # Mirrors CityDistrictLayout.doorLeaf: cancel the leaf's y offset from
                # its facade so it sorts exactly `ahead` in front, wherever it sits.
                bias = (owner["bias"] + (pt[1] - owner["y"]) * 0.5
                        + (float(ahead.group(1)) if ahead else 1.0))
                leaf = {"tex": tex, "x": pt[0], "y": pt[1],
                        "scale": SCALES["DoorDisplayScale." + ("wide" if wide else "standard")],
                        "anchorY": DOOR_FOOT_INSET / DOOR_CANVAS[1],
                        "bias": bias}
                sprites.append(leaf)
                pairs.append((owner, leaf, pt))
        districts[name] = {"ground": ground, "sprites": sprites, "pairs": pairs}
    return districts


def canvas_for(tex: str) -> tuple[int, int]:
    return DOOR_CANVAS if tex.startswith("city_door_") else BUILDING_CANVAS


def render(district: str, data: dict) -> Image.Image:
    plate = Image.new("RGBA", WORLD, (18, 18, 24, 255))
    g = AREAS / f"{data['ground']}.png"
    if g.exists():
        plate.alpha_composite(Image.open(g).convert("RGBA").resize(WORLD))
    # BaseGameScene.updateDepth: (artHeight - y) * 0.5 + bias
    for sp in sorted(data["sprites"], key=lambda s: (WORLD[1] - s["y"]) * 0.5 + s["bias"]):
        im = Image.open(PROPS / f"{sp['tex']}.png").convert("RGBA")
        nw, nh = max(1, round(im.width * sp["scale"])), max(1, round(im.height * sp["scale"]))
        im = im.resize((nw, nh), Image.Resampling.LANCZOS)
        left = round(sp["x"] - nw / 2)
        bottom = sp["y"] - sp["anchorY"] * nh
        plate.alpha_composite(im, (left, round(WORLD[1] - (bottom + nh))), )
    d = ImageDraw.Draw(plate)
    for owner, leaf, pt in data["pairs"]:
        cx, ch = canvas_for(leaf["tex"])
        lx0, lx1, ly0, ly1 = content(leaf["tex"])
        foot = world_point(((lx0 + lx1 + 1) / 2, ly1 + 1), (cx, ch), leaf)
        d.line([(pt[0] - 26, WORLD[1] - pt[1]), (pt[0] + 26, WORLD[1] - pt[1])], fill=(80, 240, 255, 255), width=3)
        d.ellipse([foot[0] - 5, WORLD[1] - foot[1] - 5, foot[0] + 5, WORLD[1] - foot[1] + 5],
                  outline=(255, 60, 200, 255), width=3)
    d.text((14, 12), f"{district} — cyan: measured aperture   magenta: leaf painted foot",
           fill=(255, 240, 190, 255))
    return plate


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    districts = parse_catalog()
    total = 0
    for name, data in districts.items():
        render(name, data).convert("RGB").save(OUT / f"{name}.png")
        total += len(data["pairs"])
        print(f"{name}: {len(data['sprites'])} sprites, {len(data['pairs'])} leaves")
    print(f"wrote {len(districts)} composites ({total} leaves) to {OUT}")


if __name__ == "__main__":
    main()

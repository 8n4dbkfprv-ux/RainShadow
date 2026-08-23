"""Compose an authored-space preview of the detective office layout.

Mirrors `OfficeNavigationLayout.AuthoredPlacement` + `OfficeInteriorScale` so
prop placement can be iterated visually without launching the game. Keep the
AUTHORED dict below in sync with the Swift constants (authored space is the
4096x2304 shell plate, SpriteKit y-up; this script converts to image y-down).

Usage:
    python3 ArtSource/Processing/compose_office_layout_preview.py [--annotate]

Outputs:
    ArtSource/Generated/Office/office_layout_preview.png       (full res)
    ArtSource/Generated/Office/office_layout_preview_half.png  (half res)
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import office_layout_plan as ol
import office_room_plan as rp

ROOT = Path(__file__).resolve().parents[2]
PROPS = ROOT / "RainShadow Shared" / "Resources" / "Art" / "Props" / "Office"
AREAS = ROOT / "RainShadow Shared" / "Resources" / "Art" / "Areas" / "DetectiveOffice"
OUT_DIR = ROOT / "ArtSource" / "Generated" / "Office"
PROP_MANIFEST = (
    ROOT
    / "ArtSource"
    / "Generated"
    / "Office"
    / "BGEEReferenceV14"
    / "office_props_source_v14.json"
)

ART_W, ART_H = 4096, 2304
ENVIRONMENT = 0.395

_MANIFEST_PROPS = {
    prop["id"]: prop for prop in json.loads(PROP_MANIFEST.read_text())["props"]
}


def relative_scale(prop_id: str) -> float:
    """Authored-space multiplier from the exact AreaProp shipping scale."""
    prop = _MANIFEST_PROPS[prop_id]
    return float(prop.get("scale", prop.get("scaleX", 1.0))) / ENVIRONMENT


# PropRelativeScale (authored-space sprite multiplier = displayScale / environment).
REL_DESK = relative_scale("office_desk_bare")
REL_DESK_CHAIR = relative_scale("office_desk_chair")
# Matches OfficeInteriorScale.ActorDisplay.seatedDeskNudge (world units).
SEATED_DESK_NUDGE = (0.0, 16.0)
REL_SMALL = relative_scale("office_safe")
REL_POCKET = relative_scale("office_newspaper")

GROUND_ANCHOR = (0.5, 0.04)
CENTER_ANCHOR = (0.5, 0.5)

# Planner-authored points (SK y-up). Wall art / decals stay on the plate plane.
AUTHORED: dict[str, tuple[float, float]] = {
    p.key: p.authored for p in ol.PROPS
}
AUTHORED.update({
    "wornRug": rp.authored(*ol.RUG),
    "floorTrashA": (ol.FLOOR_DECALS["floorTrashA"][0], ART_H - ol.FLOOR_DECALS["floorTrashA"][1]),
    "floorWear": rp.authored(0.62, 0.24),
    "windowSpill": (ol.FLOOR_DECALS["windowSpill"][0], ART_H - ol.FLOOR_DECALS["windowSpill"][1]),
    "blindStripes": (ol.FLOOR_DECALS["blindStripes"][0], ART_H - ol.FLOOR_DECALS["blindStripes"][1]),
    "hallwayLight": (ol.FLOOR_DECALS["hallwayLight"][0], ART_H - ol.FLOOR_DECALS["hallwayLight"][1]),
    "window": ol.window_anchor_authored(),
    "doorLeaf": ol.exterior_leaf_anchor_authored(),
    "caseBoard": (
        ol.WALL_ART["caseBoard"].plate[0],
        ART_H - ol.WALL_ART["caseBoard"].plate[1],
    ),
    "wallCityMap": (
        ol.WALL_ART["wallCityMap"].plate[0],
        ART_H - ol.WALL_ART["wallCityMap"].plate[1],
    ),
    "wallPhotos": (
        ol.WALL_ART["wallPhotos"].plate[0],
        ART_H - ol.WALL_ART["wallPhotos"].plate[1],
    ),
})
LAMP_POOL = AUTHORED["deskEnsemble"]

# Desktop clutter is neither live nor baked (it would sit under the live desk
# sprite). The shipping preview only overlays the desk, chair, and door.


def to_img(pt: tuple[float, float]) -> tuple[float, float]:
    return pt[0], ART_H - pt[1]


def load(name: str) -> Image.Image:
    return Image.open(PROPS / f"{name}.png").convert("RGBA")


def scaled(im: Image.Image, rel: float) -> Image.Image:
    return im.resize(
        (max(1, round(im.width * rel)), max(1, round(im.height * rel))),
        Image.Resampling.LANCZOS,
    )


def paste_anchored(
    canvas: Image.Image,
    im: Image.Image,
    authored_pt: tuple[float, float],
    anchor: tuple[float, float],
    alpha: float = 1.0,
) -> None:
    x, y = to_img(authored_pt)
    # SK anchor is fraction from bottom-left of the sprite; image space is y-down.
    left = round(x - im.width * anchor[0])
    top = round(y - im.height * (1 - anchor[1]))
    if alpha < 1.0:
        im = im.copy()
        a = im.getchannel("A").point(lambda v: int(v * alpha))
        im.putalpha(a)
    canvas.alpha_composite(im, (left, top))


def additive(canvas: Image.Image, im: Image.Image, authored_pt: tuple[float, float], alpha: float) -> None:
    """Approximate SpriteKit .add blend for light pools/spills."""
    x, y = to_img(authored_pt)
    left = round(x - im.width / 2)
    top = round(y - im.height / 2)
    base = np.asarray(canvas, dtype=np.int16)
    layer = np.asarray(im, dtype=np.float32)
    x0, y0 = max(0, left), max(0, top)
    x1, y1 = min(canvas.width, left + im.width), min(canvas.height, top + im.height)
    if x1 <= x0 or y1 <= y0:
        return
    sub = layer[y0 - top : y1 - top, x0 - left : x1 - left]
    add_rgb = sub[:, :, :3] * (sub[:, :, 3:4] / 255.0) * alpha
    region = base[y0:y1, x0:x1, :3] + add_rgb.astype(np.int16)
    base[y0:y1, x0:x1, :3] = np.clip(region, 0, 255)
    result = Image.fromarray(base.astype(np.uint8), "RGBA")
    canvas.paste(result)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--annotate", action="store_true")
    parser.add_argument(
        "--plate",
        type=Path,
        default=AREAS / "office_suite_plate.png",
        help="non-destructive plate override for candidate review",
    )
    parser.add_argument(
        "--out-prefix",
        default="office_layout_preview",
        help="output stem under ArtSource/Generated/Office",
    )
    args = parser.parse_args()
    annotate = args.annotate
    canvas = Image.open(args.plate).convert("RGBA")
    if canvas.size != (ART_W, ART_H):
        canvas = canvas.resize((ART_W, ART_H), Image.Resampling.LANCZOS)

    # Shipping plate already has static scenery. Overlay only the live
    # Infinity-Engine split: registered door states, the desk that sorts
    # against a seated actor, and the chair that remains when he stands.
    paste_anchored(
        canvas,
        scaled(load("office_door_leaf"), ol.DOOR_DISPLAY_SCALE / ENVIRONMENT),
        AUTHORED["doorLeaf"],
        (0.953125, 0.94375),
    )
    paste_anchored(
        canvas,
        scaled(load("office_visitor_armchair"), REL_DESK_CHAIR),
        (
            AUTHORED["deskChair"][0] + SEATED_DESK_NUDGE[0] / ENVIRONMENT,
            AUTHORED["deskChair"][1] + SEATED_DESK_NUDGE[1] / ENVIRONMENT,
        ),
        GROUND_ANCHOR,
    )
    paste_anchored(
        canvas,
        scaled(load("office_desk_bare"), REL_DESK),
        AUTHORED["deskEnsemble"],
        GROUND_ANCHOR,
    )

    if annotate:
        draw = ImageDraw.Draw(canvas)
        for key, pt in AUTHORED.items():
            x, y = to_img(pt)
            draw.line([(x - 14, y), (x + 14, y)], fill=(255, 60, 60, 255), width=3)
            draw.line([(x, y - 14), (x, y + 14)], fill=(255, 60, 60, 255), width=3)
            draw.text((x + 16, y - 26), key, fill=(255, 220, 90, 255))

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    full = OUT_DIR / f"{args.out_prefix}.png"
    canvas.save(full)
    half = canvas.resize((ART_W // 2, ART_H // 2), Image.Resampling.LANCZOS)
    half.save(OUT_DIR / f"{args.out_prefix}_half.png")
    print(f"wrote {full}")


if __name__ == "__main__":
    main()

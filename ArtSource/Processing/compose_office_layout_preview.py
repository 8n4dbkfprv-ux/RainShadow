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

import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import office_layout_plan as ol
import office_room_plan as rp

ROOT = Path(__file__).resolve().parents[2]
PROPS = ROOT / "RainShadow Shared" / "Resources" / "Art" / "Props" / "Office"
AREAS = ROOT / "RainShadow Shared" / "Resources" / "Art" / "Areas" / "DetectiveOffice"
OUT_DIR = ROOT / "ArtSource" / "Generated" / "Office"

ART_W, ART_H = 4096, 2304
ENVIRONMENT = 0.395

# PropRelativeScale (authored-space sprite multiplier = displayScale / environment).
REL_STANDARD = 0.22 / ENVIRONMENT
REL_DESK = 0.12 / ENVIRONMENT
REL_SEATING = 0.17 / ENVIRONMENT
REL_DESK_CHAIR = 0.135 / ENVIRONMENT
# Matches OfficeInteriorScale.ActorDisplay.seatedDeskNudge (world units).
SEATED_DESK_NUDGE = (0.0, 16.0)
REL_WINDOW = 0.24 / ENVIRONMENT
REL_FLOOR_DECAL = 0.22 / ENVIRONMENT
REL_SMALL = 0.12 / ENVIRONMENT
REL_POCKET = 0.10 / ENVIRONMENT
REL_WALL = REL_STANDARD * 0.72

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
    "doorLeaf": ol.exterior_door_threshold_authored(),
    "caseBoard": (ol.WALL_ART["caseBoard"][0], ART_H - ol.WALL_ART["caseBoard"][1]),
    "wallCityMap": (ol.WALL_ART["wallCityMap"][0], ART_H - ol.WALL_ART["wallCityMap"][1]),
    "wallPhotos": (ol.WALL_ART["wallPhotos"][0], ART_H - ol.WALL_ART["wallPhotos"][1]),
})
WINDOW_ROTATION = -0.105  # SK radians
LAMP_POOL = AUTHORED["deskEnsemble"]

# Desk item canvas centres on the 932x780 bare-desk plate (image y-down),
# mirrored from DetectiveOfficeScene.addDeskItems.
DESK_CANVAS = (932, 780)
DESK_ITEMS: list[tuple[str, tuple[float, float]]] = [
    ("office_desk_lamp", (280, 190)),
    ("office_desk_typewriter", (360, 230)),
    ("office_desk_phone", (430, 255)),
    ("office_desk_notebook", (500, 300)),
    ("office_desk_papers", (540, 250)),
    ("office_pencil_tray", (580, 310)),
    ("office_desk_mug", (480, 330)),
    ("office_desk_ashtray", (600, 325)),
    ("office_desk_files", (680, 265)),
    ("office_framed_photo", (720, 195)),
]


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
    annotate = "--annotate" in sys.argv
    canvas = Image.open(AREAS / "office_suite_plate.png").convert("RGBA")
    if canvas.size != (ART_W, ART_H):
        canvas = canvas.resize((ART_W, ART_H), Image.Resampling.LANCZOS)

    # --- floorEffectRoot (painted in add order; all center-anchored) ---
    wear = scaled(load("office_floor_wear_decal"), REL_FLOOR_DECAL * 1.35)
    paste_anchored(canvas, wear, AUTHORED["floorWear"], CENTER_ANCHOR, alpha=0.55)
    additive(canvas, scaled(load("office_light_window_spill"), REL_FLOOR_DECAL * 1.1), AUTHORED["windowSpill"], 0.32)
    additive(canvas, scaled(load("office_light_blind_stripes"), REL_FLOOR_DECAL * 1.05), AUTHORED["blindStripes"], 0.50)
    additive(canvas, scaled(load("office_light_hallway"), REL_FLOOR_DECAL * 0.85), AUTHORED["hallwayLight"], 0.42)
    additive(canvas, scaled(load("office_light_lamp_pool"), REL_FLOOR_DECAL * 0.95), LAMP_POOL, 0.58)
    cab_shadow = scaled(load("office_cabinet_floor_shadow"), REL_STANDARD)
    paste_anchored(canvas, cab_shadow, AUTHORED["filingCabinet"], CENTER_ANCHOR, alpha=0.55)
    desk_shadow = scaled(load("office_desk_floor_shadow"), REL_DESK * 1.15)
    paste_anchored(canvas, desk_shadow, AUTHORED["deskEnsemble"], CENTER_ANCHOR, alpha=0.55)
    rug = scaled(load("office_worn_rug"), REL_FLOOR_DECAL * 1.35)
    paste_anchored(canvas, rug, AUTHORED["wornRug"], CENTER_ANCHOR)

    # --- rearFixtureRoot ---
    paste_anchored(canvas, scaled(load("office_radiator"), REL_STANDARD), AUTHORED["radiator"], GROUND_ANCHOR)
    paste_anchored(canvas, scaled(load("office_door_leaf"), REL_STANDARD), AUTHORED["doorLeaf"], GROUND_ANCHOR)
    for name, key in [
        ("office_case_board", "caseBoard"),
        ("office_wall_city_map", "wallCityMap"),
        ("office_wall_photos", "wallPhotos"),
    ]:
        paste_anchored(canvas, scaled(load(name), REL_WALL), AUTHORED[key], CENTER_ANCHOR)
    window = scaled(load("office_window"), REL_WINDOW)
    window = window.rotate(math.degrees(WINDOW_ROTATION), expand=True, resample=Image.Resampling.BICUBIC)
    paste_anchored(canvas, window, AUTHORED["window"], CENTER_ANCHOR)
    blinds = scaled(load("office_window_blinds"), REL_WINDOW * 0.92)
    blinds = blinds.rotate(math.degrees(WINDOW_ROTATION), expand=True, resample=Image.Resampling.BICUBIC)
    paste_anchored(canvas, blinds, AUTHORED["window"], CENTER_ANCHOR, alpha=0.88)

    # --- depthWorldRoot: z = 1000 + (artHeight - worldY) * 0.5 + bias ---
    def world_y(authored_y: float) -> float:
        return 1_152 + (authored_y - 1_152) * ENVIRONMENT

    depth_props: list[tuple[float, str, tuple[float, float], float, tuple[float, float]]] = [
        # (bias, texture, authored point, relative scale, anchor)
        (0, "office_bookshelf", AUTHORED["bookshelf"], REL_STANDARD, GROUND_ANCHOR),
        (0, "office_filing_cabinet", AUTHORED["filingCabinet"], REL_STANDARD, GROUND_ANCHOR),
        (0, "office_filing_cabinet", AUTHORED["filingCabinetB"], REL_STANDARD * 0.96, GROUND_ANCHOR),
        (0, "office_safe", AUTHORED["safe"], REL_SMALL, GROUND_ANCHOR),
        (0, "office_archive_box_a", AUTHORED["archiveBoxA"], REL_SMALL, GROUND_ANCHOR),
        (40, "office_archive_box_b", AUTHORED["archiveBoxOnCabinet"], REL_SMALL * 0.9, GROUND_ANCHOR),
        (0, "office_coat_rack", AUTHORED["coatRack"], REL_STANDARD, GROUND_ANCHOR),
        (0, "office_umbrella_stand", AUTHORED["umbrellaStand"], REL_SMALL, GROUND_ANCHOR),
        (0, "office_visitor_armchair", AUTHORED["visitorArmchair"], REL_SEATING, GROUND_ANCHOR),
        (0, "office_visitor_armchair", AUTHORED["visitorArmchairB"], REL_SEATING * 0.96, GROUND_ANCHOR),
        (0, "office_waiting_chair_a", AUTHORED["waitingChairA"], REL_SEATING * 0.88, GROUND_ANCHOR),
        (0, "office_waiting_table", AUTHORED["waitingTable"], REL_SMALL, GROUND_ANCHOR),
        (-20, "office_newspaper", AUTHORED["newspaper"], REL_POCKET, GROUND_ANCHOR),
        (-15, "office_waiting_ashtray", AUTHORED["waitingAshtray"], REL_POCKET, GROUND_ANCHOR),
        # Empty chair uses baseline + seated desk nudge (world), same as runtime.
        (-40, "office_desk_chair", (
            AUTHORED["deskChair"][0] + SEATED_DESK_NUDGE[0] / ENVIRONMENT,
            AUTHORED["deskChair"][1] + SEATED_DESK_NUDGE[1] / ENVIRONMENT,
        ), REL_DESK_CHAIR, GROUND_ANCHOR),
        (0, "office_wastebasket", AUTHORED["wastebasket"], REL_SMALL, GROUND_ANCHOR),
        (-40, "office_floor_trash_a", AUTHORED["floorTrashA"], REL_SMALL, GROUND_ANCHOR),
        (-500, "office_desk_bare", AUTHORED["deskEnsemble"], REL_DESK, GROUND_ANCHOR),
        (-20, "office_hidden_bottle", AUTHORED["personalBottle"], REL_POCKET, GROUND_ANCHOR),
    ]

    # Desk items ride the bare-desk canvas (default center anchor, desk scale).
    desk = AUTHORED["deskEnsemble"]
    for name, (cx, cy) in DESK_ITEMS:
        ax = desk[0] + (cx - DESK_CANVAS[0] * GROUND_ANCHOR[0]) * REL_DESK
        ay = desk[1] + (DESK_CANVAS[1] * (1 - GROUND_ANCHOR[1]) - cy) * REL_DESK
        depth_props.append((0, name, (ax, ay), REL_DESK, CENTER_ANCHOR))

    def z_of(entry) -> float:
        bias, _, pt, _, _ = entry
        return 1_000 + (ART_H - world_y(pt[1])) * 0.5 + bias

    for entry in sorted(depth_props, key=z_of):
        bias, name, pt, rel, anchor = entry
        paste_anchored(canvas, scaled(load(name), rel), pt, anchor)

    if annotate:
        draw = ImageDraw.Draw(canvas)
        for key, pt in AUTHORED.items():
            x, y = to_img(pt)
            draw.line([(x - 14, y), (x + 14, y)], fill=(255, 60, 60, 255), width=3)
            draw.line([(x, y - 14), (x, y + 14)], fill=(255, 60, 60, 255), width=3)
            draw.text((x + 16, y - 26), key, fill=(255, 220, 90, 255))

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    full = OUT_DIR / "office_layout_preview.png"
    canvas.save(full)
    half = canvas.resize((ART_W // 2, ART_H // 2), Image.Resampling.LANCZOS)
    half.save(OUT_DIR / "office_layout_preview_half.png")
    print(f"wrote {full}")


if __name__ == "__main__":
    main()

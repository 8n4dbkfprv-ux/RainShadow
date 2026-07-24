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

ROOT = Path(__file__).resolve().parents[2]
PROPS = ROOT / "RainShadow Shared" / "Resources" / "Art" / "Props" / "Office"
AREAS = ROOT / "RainShadow Shared" / "Resources" / "Art" / "Areas" / "DetectiveOffice"
OUT_DIR = ROOT / "ArtSource" / "Generated" / "Office"

ART_W, ART_H = 4096, 2304
ENVIRONMENT = 0.395

# PropRelativeScale (authored-space sprite multiplier = displayScale / environment).
REL_STANDARD = 0.22 / ENVIRONMENT
REL_DESK = 0.14 / ENVIRONMENT
REL_SEATING = 0.17 / ENVIRONMENT
REL_WINDOW = 0.24 / ENVIRONMENT
REL_FLOOR_DECAL = 0.22 / ENVIRONMENT
REL_SMALL = 0.12 / ENVIRONMENT
REL_POCKET = 0.10 / ENVIRONMENT

GROUND_ANCHOR = (0.5, 0.04)
CENTER_ANCHOR = (0.5, 0.5)

# ---------------------------------------------------------------------------
# Mirror of OfficeNavigationLayout.AuthoredPlacement (SK y-up authored space).
# ---------------------------------------------------------------------------
AUTHORED: dict[str, tuple[float, float]] = {
    "radiator": (1_050, 1_640),
    "doorLeaf": (3_114, 1_554),
    "deskChair": (2_070, 955),
    "filingCabinet": (1_620, 1_530),
    "archiveBoxA": (1_730, 1_485),
    "archiveBoxB": (1_690, 1_425),
    "wastebasket": (1_820, 1_000),
    "wornRug": (2_420, 1_100),
    "floorTrashA": (1_780, 940),
    "floorTrashB": (2_210, 1_010),
    "floorTrashC": (2_920, 1_420),
    "hiddenBottle": (1_940, 890),
    "bookshelf": (1_380, 1_415),
    "archiveStack": (2_770, 1_490),
    "floorWear": (2_100, 980),
    "windowSpill": (1_290, 1_580),
    "coatRack": (3_000, 1_400),
    "visitorArmchair": (2_360, 1_100),
    "deskEnsemble": (2_100, 980),
    "window": (1_220, 1_812),
}
WINDOW_ROTATION = -0.105  # SK radians
LAMP_POOL = (2_100, 1_020)

# Desk item canvas centres on the 932x780 bare-desk plate (image y-down),
# mirrored from DetectiveOfficeScene.addDeskItems.
DESK_CANVAS = (932, 780)
DESK_ITEMS: list[tuple[str, tuple[float, float]]] = [
    ("office_desk_papers", (450, 240)),
    ("office_desk_files", (280, 290)),
    ("office_desk_lamp", (680, 150)),
    ("office_desk_phone", (620, 230)),
    ("office_desk_mug", (400, 300)),
    ("office_desk_ashtray", (510, 310)),
    ("office_framed_photo", (300, 220)),
    ("office_pencil_tray", (480, 295)),
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
    canvas = Image.open(AREAS / "office_shell_base.png").convert("RGBA")
    if canvas.size != (ART_W, ART_H):
        canvas = canvas.resize((ART_W, ART_H), Image.Resampling.LANCZOS)

    # --- floorEffectRoot (painted in add order; all center-anchored) ---
    wear = scaled(load("office_floor_wear_decal"), REL_FLOOR_DECAL * 1.35)
    paste_anchored(canvas, wear, AUTHORED["floorWear"], CENTER_ANCHOR, alpha=0.55)
    additive(canvas, scaled(load("office_light_window_spill"), REL_FLOOR_DECAL * 1.1), AUTHORED["windowSpill"], 0.45)
    additive(canvas, scaled(load("office_light_lamp_pool"), REL_FLOOR_DECAL * 0.95), LAMP_POOL, 0.55)
    cab_shadow = scaled(load("office_cabinet_floor_shadow"), REL_STANDARD)
    paste_anchored(canvas, cab_shadow, AUTHORED["filingCabinet"], CENTER_ANCHOR, alpha=0.55)
    desk_shadow = scaled(load("office_desk_floor_shadow"), REL_DESK * 1.15)
    paste_anchored(canvas, desk_shadow, AUTHORED["deskEnsemble"], CENTER_ANCHOR, alpha=0.55)
    rug = scaled(load("office_worn_rug"), REL_FLOOR_DECAL)
    paste_anchored(canvas, rug, AUTHORED["wornRug"], CENTER_ANCHOR)

    # --- rearFixtureRoot ---
    paste_anchored(canvas, scaled(load("office_radiator"), REL_STANDARD), AUTHORED["radiator"], GROUND_ANCHOR)
    paste_anchored(canvas, scaled(load("office_door_leaf"), REL_STANDARD), AUTHORED["doorLeaf"], GROUND_ANCHOR)
    window = scaled(load("office_window"), REL_WINDOW)
    window = window.rotate(math.degrees(WINDOW_ROTATION), expand=True, resample=Image.Resampling.BICUBIC)
    paste_anchored(canvas, window, AUTHORED["window"], CENTER_ANCHOR)

    # --- depthWorldRoot: z = 1000 + (artHeight - worldY) * 0.5 + bias ---
    def world_y(authored_y: float) -> float:
        return 1_152 + (authored_y - 1_152) * ENVIRONMENT

    depth_props: list[tuple[float, str, tuple[float, float], float, tuple[float, float]]] = [
        # (bias, texture, authored point, relative scale, anchor)
        (0, "office_bookshelf", AUTHORED["bookshelf"], REL_STANDARD, GROUND_ANCHOR),
        (0, "office_filing_cabinet", AUTHORED["filingCabinet"], REL_STANDARD, GROUND_ANCHOR),
        (0, "office_archive_box_a", AUTHORED["archiveBoxA"], REL_SMALL, GROUND_ANCHOR),
        (0, "office_archive_box_b", AUTHORED["archiveBoxB"], REL_SMALL, GROUND_ANCHOR),
        (0, "office_archive_stack", AUTHORED["archiveStack"], REL_SMALL, GROUND_ANCHOR),
        (0, "office_coat_rack", AUTHORED["coatRack"], REL_STANDARD, GROUND_ANCHOR),
        (0, "office_visitor_armchair", AUTHORED["visitorArmchair"], REL_SEATING, GROUND_ANCHOR),
        (0, "office_wastebasket", AUTHORED["wastebasket"], REL_SMALL, GROUND_ANCHOR),
        (-40, "office_floor_trash_a", AUTHORED["floorTrashA"], REL_SMALL, GROUND_ANCHOR),
        (-40, "office_floor_trash_b", AUTHORED["floorTrashB"], REL_SMALL, GROUND_ANCHOR),
        (-40, "office_floor_trash_c", AUTHORED["floorTrashC"], REL_SMALL, GROUND_ANCHOR),
        (-500, "office_desk_bare", AUTHORED["deskEnsemble"], REL_DESK, GROUND_ANCHOR),
        (-120, "office_hidden_bottle", AUTHORED["hiddenBottle"], REL_POCKET, GROUND_ANCHOR),
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

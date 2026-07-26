"""Partitioned detective-suite graybox previews (clean + debug).

Usage:
    python3 ArtSource/Processing/compose_office_graybox_preview.py
"""

from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
PROPS = ROOT / "RainShadow Shared" / "Resources" / "Art" / "Props" / "Office"
AREAS = ROOT / "RainShadow Shared" / "Resources" / "Art" / "Areas" / "DetectiveOffice"
OUT_DIR = ROOT / "ArtSource" / "Generated" / "Office"

ART_W, ART_H = 4096, 2304
ENVIRONMENT = 0.395
REL_STANDARD = 0.22 / ENVIRONMENT
REL_DESK = 0.12 / ENVIRONMENT
REL_SEATING = 0.17 / ENVIRONMENT
REL_DESK_CHAIR = 0.135 / ENVIRONMENT
REL_WINDOW = 0.24 / ENVIRONMENT
REL_FLOOR_DECAL = 0.22 / ENVIRONMENT
REL_SMALL = 0.12 / ENVIRONMENT
REL_POCKET = 0.10 / ENVIRONMENT
REL_WALL = REL_STANDARD * 0.72
SEATED_DESK_NUDGE = (0.0, 16.0)
GROUND_ANCHOR = (0.5, 0.04)
CENTER_ANCHOR = (0.5, 0.5)
WINDOW_ROTATION = -0.105

AUTHORED = {
    "radiator": (1_050, 1_640),
    "doorLeaf": (3_114, 1_554),
    "internalDoorLeaf": (2_600, 1_275),
    "deskChair": (1_665, 1_205),
    "filingCabinet": (1_620, 1_530),
    "filingCabinetB": (1_780, 1_610),
    "safe": (1_920, 1_680),
    "archiveBoxA": (1_740, 1_560),
    "archiveBoxOnCabinet": (1_700, 1_630),
    "wastebasket": (1_480, 1_170),
    "wornRug": (1_920, 1_260),
    "floorTrashA": (1_520, 1_140),
    "bookshelf": (1_380, 1_410),
    "floorWear": (1_680, 1_240),
    "windowSpill": (1_290, 1_580),
    "blindStripes": (1_360, 1_520),
    "hallwayLight": (3_060, 1_520),
    "coatRack": (3_100, 1_480),
    "umbrellaStand": (3_140, 1_440),
    "visitorArmchair": (2_000, 1_260),
    "visitorArmchairB": (2_140, 1_220),
    "waitingChairA": (2_960, 1_410),
    "waitingTable": (2_920, 1_370),
    "newspaper": (2_920, 1_390),
    "waitingAshtray": (2_940, 1_380),
    "deskEnsemble": (1_680, 1_240),
    "window": (1_220, 1_812),
    "caseBoard": (1_680, 1_720),
    "wallCityMap": (1_840, 1_740),
    "wallPhotos": (1_760, 1_680),
    "personalSideboard": (1_120, 1_320),
    "personalBottle": (1_140, 1_350),
    "personalGlass": (1_180, 1_340),
    "personalFan": (1_180, 1_280),
    "personalWashbasin": (1_060, 1_340),
}
LAMP_POOL = (1_680, 1_280)

OBSTACLES = [
    ("fg", (1_100, 400, 2_100, 200)),
    ("partS", (2_480, 650, 100, 450)),
    ("partN", (2_480, 1_450, 100, 270)),
    ("desk", (1_480, 1_100, 400, 220)),
    ("clientA", (1_920, 1_200, 160, 110)),
    ("clientB", (2_060, 1_160, 140, 100)),
    ("cabinet", (1_530, 1_470, 190, 120)),
    ("cabinetB", (1_690, 1_550, 180, 115)),
    ("safe", (1_860, 1_620, 130, 100)),
    ("boxA", (1_680, 1_520, 120, 90)),
    ("waste", (1_440, 1_140, 110, 90)),
    ("radiator", (880, 1_580, 340, 110)),
    ("bookshelf", (1_300, 1_375, 160, 90)),
    ("coat", (3_020, 1_420, 180, 110)),
    ("umbrella", (3_100, 1_400, 80, 60)),
    ("waitChair", (2_900, 1_360, 140, 100)),
    ("waitTable", (2_860, 1_320, 100, 70)),
    ("personal", (1_040, 1_260, 200, 130)),
    ("door", (3_029, 1_539, 170, 140)),
]

EXT_TO_INT = [(3_000, 1_500), (2_780, 1_420), (2_680, 1_300)]
INT_TO_CLIENT = [(2_420, 1_380), (2_360, 1_380)]
DESK_TO_RECORDS = [(1_665, 1_413), (1_820, 1_480), (1_780, 1_560)]

DESK_ITEMS = [
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
DESK_CANVAS = (932, 780)


def to_img(pt):
    return pt[0], ART_H - pt[1]


def load(name: str) -> Image.Image:
    return Image.open(PROPS / f"{name}.png").convert("RGBA")


def scaled(im: Image.Image, rel: float) -> Image.Image:
    return im.resize(
        (max(1, round(im.width * rel)), max(1, round(im.height * rel))),
        Image.Resampling.LANCZOS,
    )


def paste_anchored(canvas, im, authored_pt, anchor, alpha=1.0):
    x, y = to_img(authored_pt)
    left = round(x - im.width * anchor[0])
    top = round(y - im.height * (1 - anchor[1]))
    if alpha < 1.0:
        im = im.copy()
        a = im.getchannel("A").point(lambda v: int(v * alpha))
        im.putalpha(a)
    canvas.alpha_composite(im, (left, top))


def additive(canvas, im, authored_pt, alpha):
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
    canvas.paste(Image.fromarray(base.astype(np.uint8), "RGBA"))


def draw_sk_rect(draw, rect, outline, width=3):
    x, y, w, h = rect
    pts = [to_img((x, y)), to_img((x + w, y)), to_img((x + w, y + h)), to_img((x, y + h))]
    draw.polygon(pts, outline=outline, width=width)


def draw_route(draw, points, color):
    img_pts = [to_img(p) for p in points]
    if len(img_pts) >= 2:
        draw.line(img_pts, fill=color, width=6)
    for p in img_pts:
        draw.ellipse((p[0] - 8, p[1] - 8, p[0] + 8, p[1] + 8), fill=color)


def compose_scene() -> Image.Image:
    canvas = Image.open(AREAS / "office_shell_base.png").convert("RGBA")
    if canvas.size != (ART_W, ART_H):
        canvas = canvas.resize((ART_W, ART_H), Image.Resampling.LANCZOS)

    wear = scaled(load("office_floor_wear_decal"), REL_FLOOR_DECAL * 1.35)
    paste_anchored(canvas, wear, AUTHORED["floorWear"], CENTER_ANCHOR, alpha=0.55)
    additive(canvas, scaled(load("office_light_window_spill"), REL_FLOOR_DECAL * 1.1), AUTHORED["windowSpill"], 0.32)
    additive(canvas, scaled(load("office_light_blind_stripes"), REL_FLOOR_DECAL * 1.05), AUTHORED["blindStripes"], 0.50)
    additive(canvas, scaled(load("office_light_hallway"), REL_FLOOR_DECAL * 0.85), AUTHORED["hallwayLight"], 0.42)
    additive(canvas, scaled(load("office_light_lamp_pool"), REL_FLOOR_DECAL * 0.95), LAMP_POOL, 0.58)
    paste_anchored(canvas, scaled(load("office_cabinet_floor_shadow"), REL_STANDARD), AUTHORED["filingCabinet"], CENTER_ANCHOR, alpha=0.55)
    paste_anchored(canvas, scaled(load("office_desk_floor_shadow"), REL_DESK * 1.15), AUTHORED["deskEnsemble"], CENTER_ANCHOR, alpha=0.55)
    paste_anchored(canvas, scaled(load("office_worn_rug"), REL_FLOOR_DECAL * 1.45), AUTHORED["wornRug"], CENTER_ANCHOR)

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

    def world_y(ay):
        return 1_152 + (ay - 1_152) * ENVIRONMENT

    depth_props = [
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
        (-40, "office_desk_chair", (
            AUTHORED["deskChair"][0] + SEATED_DESK_NUDGE[0] / ENVIRONMENT,
            AUTHORED["deskChair"][1] + SEATED_DESK_NUDGE[1] / ENVIRONMENT,
        ), REL_DESK_CHAIR, GROUND_ANCHOR),
        (0, "office_wastebasket", AUTHORED["wastebasket"], REL_SMALL, GROUND_ANCHOR),
        (-40, "office_floor_trash_a", AUTHORED["floorTrashA"], REL_SMALL, GROUND_ANCHOR),
        (-500, "office_desk_bare", AUTHORED["deskEnsemble"], REL_DESK, GROUND_ANCHOR),
        (-20, "office_hidden_bottle", AUTHORED["personalBottle"], REL_POCKET, GROUND_ANCHOR),
        # Internal door leaf is painted into office_suite_architecture_graybox (same plane).
    ]
    desk = AUTHORED["deskEnsemble"]
    for name, (cx, cy) in DESK_ITEMS:
        ax = desk[0] + (cx - DESK_CANVAS[0] * GROUND_ANCHOR[0]) * REL_DESK
        ay = desk[1] + (DESK_CANVAS[1] * (1 - GROUND_ANCHOR[1]) - cy) * REL_DESK
        depth_props.append((0, name, (ax, ay), REL_DESK, CENTER_ANCHOR))

    for entry in sorted(depth_props, key=lambda e: 1_000 + (ART_H - world_y(e[2][1])) * 0.5 + e[0]):
        _, name, pt, rel, anchor = entry
        paste_anchored(canvas, scaled(load(name), rel), pt, anchor)

    arch_path = PROPS / "office_suite_architecture.png"
    if not arch_path.exists():
        arch_path = PROPS / "office_suite_architecture_graybox.png"
    arch = Image.open(arch_path).convert("RGBA")
    if arch.size != (ART_W, ART_H):
        arch = arch.resize((ART_W, ART_H), Image.Resampling.LANCZOS)
    canvas.alpha_composite(arch)

    # Pass B personal props + internal door (after architecture so leaf reads in doorway)
    for name, key, rel, anchor in [
        ("office_personal_washbasin", "personalWashbasin", REL_STANDARD * 0.82, GROUND_ANCHOR),
        ("office_personal_sideboard", "personalSideboard", REL_STANDARD * 0.92, GROUND_ANCHOR),
        ("office_personal_fan", "personalFan", REL_STANDARD * 0.78, GROUND_ANCHOR),
        ("office_personal_glass", "personalGlass", REL_POCKET, GROUND_ANCHOR),
        ("office_internal_door_leaf", "internalDoorLeaf", REL_STANDARD * 0.70, GROUND_ANCHOR),
    ]:
        path = PROPS / f"{name}.png"
        if not path.exists():
            continue
        paste_anchored(canvas, scaled(load(name), rel), AUTHORED[key], anchor)

    return canvas


def annotate_debug(canvas: Image.Image) -> Image.Image:
    out = canvas.copy()
    draw = ImageDraw.Draw(out)
    for name, rect in OBSTACLES:
        if name.startswith("part") or name == "fg":
            col, width = (255, 60, 60, 220), 5
        else:
            col, width = (80, 200, 255, 200), 3
        draw_sk_rect(draw, rect, col, width=width)

    draw_route(draw, EXT_TO_INT, (80, 255, 140, 255))
    draw_route(draw, INT_TO_CLIENT, (120, 220, 255, 255))
    draw_route(draw, DESK_TO_RECORDS, (255, 180, 60, 255))

    chair_pt = to_img(AUTHORED["deskChair"])
    door_pt = to_img(AUTHORED["internalDoorLeaf"])
    draw.line([chair_pt, door_pt], fill=(255, 255, 80, 255), width=4)
    draw.text((chair_pt[0] + 20, chair_pt[1] - 40), "sightline → internal door", fill=(255, 255, 120, 255))

    draw.text(to_img((1_650, 1_100)), "PRIVATE OFFICE", fill=(255, 240, 180, 255))
    draw.text(to_img((2_850, 1_150)), "WAITING", fill=(220, 240, 255, 255))

    draw.text((120, 80), "SUITE GRAYBOX CORRECTION — debug (camera unchanged)", fill=(255, 240, 160, 255))
    draw.text((120, 130), "Red: partition + FG | Cyan: props | Green: exterior→door | Cyan: door→clients | Orange: desk→records", fill=(220, 220, 220, 255))
    draw.text((120, 180), "Desk tightened to records | personal on west wall | doorway lane clear of rug", fill=(220, 220, 220, 255))
    return out


def save(canvas: Image.Image, stem: str) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    full = OUT_DIR / f"{stem}.png"
    canvas.save(full)
    half = canvas.resize((ART_W // 2, ART_H // 2), Image.Resampling.LANCZOS)
    half.save(OUT_DIR / f"{stem}_half.png")
    print(f"wrote {full}")


def main() -> None:
    clean = compose_scene()
    save(clean, "office_graybox_preview_clean")
    save(clean, "office_graybox_preview")
    debug = annotate_debug(clean)
    save(debug, "office_graybox_preview_debug")


if __name__ == "__main__":
    main()

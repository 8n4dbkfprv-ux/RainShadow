"""Offline preview of the four-cluster office layout.

Unlike the older compose scripts, this one imports `office_layout_plan`
directly, so the preview can never drift from the Swift emit. It composites the
shell, partition, floor rug, every prop from `PROPS`, the wall art and the
foreground cutaway at plate resolution, then writes a half-size review PNG.

Usage:
    python3 ArtSource/Processing/compose_office_redesign_preview.py
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

import office_layout_plan as lp
import office_room_plan as rp

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "RainShadow Shared/Resources/Art/Props/Office"
AREAS = ROOT / "RainShadow Shared/Resources/Art/Areas/DetectiveOffice"
OUT = ROOT / "ArtSource/Generated/Office/review"

ENV = lp.ENV
ANCHOR = (0.5, 0.04)  # matches addDepthProp / addRearFixture in the scene

# Preview factor for the burgundy rug relative to floorDecalDisplayScale; the
# scene must use the same number (see addWornRug).
RUG_ART = "office_worn_rug_burgundy.png"
RUG_FACTOR = lp.RUG_FACTOR

WALL_ART_SCALE = 0.22 * 0.72 / ENV  # standardPropDisplayScale * 0.72 in plate px


def load(name: str) -> Image.Image:
    return Image.open(ART / name).convert("RGBA")


def content_box(im: Image.Image) -> tuple[int, int, int, int]:
    alpha = np.asarray(im)[:, :, 3]
    ys, xs = np.where(alpha > 16)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def paste_scaled(
    canvas: Image.Image,
    im: Image.Image,
    plate_scale: float,
    anchor_plate: tuple[float, float],
    *,
    crop_content: bool = True,
    anchor: tuple[float, float] = ANCHOR,
    plate_scale_x: float | None = None,
    plate_scale_y: float | None = None,
) -> None:
    """Paste `im` so UV `anchor` lands on `anchor_plate` (plate y-down).

    Default matches addDepthProp (content crop, anchor 0.5/0.04). Exterior
    leaf/frame use the full texture + Architecture entrance* anchors so the
    preview matches DetectiveOfficeScene. Optional independent X/Y scales fill
    a near-square painted aperture from a tall sheared master.
    """
    if crop_content:
        x0, y0, x1, y1 = content_box(im)
        src = im.crop((x0, y0, x1, y1))
    else:
        src = im
    sx = plate_scale_x if plate_scale_x is not None else plate_scale
    sy = plate_scale_y if plate_scale_y is not None else plate_scale
    w = max(1, int(round(src.width * sx)))
    h = max(1, int(round(src.height * sy)))
    src = src.resize((w, h), Image.Resampling.LANCZOS)
    px = int(round(anchor_plate[0] - w * anchor[0]))
    py = int(round(anchor_plate[1] - h * (1.0 - anchor[1])))
    canvas.alpha_composite(src, (px, py))


def plate_point(authored: tuple[float, float]) -> tuple[float, float]:
    return (authored[0], rp.ART_H - authored[1])


def main() -> None:
    for prop in lp.PROPS:
        prop.measure()

    # Cramped suite plate already includes partition + cutaway architecture.
    suite = AREAS / "office_suite_plate.png"
    shell = AREAS / "office_shell_base.png"
    canvas = Image.open(suite if suite.exists() else shell).convert("RGBA")
    if canvas.size != (rp.ART_W, rp.ART_H):
        canvas = canvas.resize((rp.ART_W, rp.ART_H), Image.Resampling.LANCZOS)

    # Rug first: floor decal under everything.
    rug = load(RUG_ART)
    rug_plate = plate_point(rp.authored(*lp.RUG))
    x0, y0, x1, y1 = content_box(rug)
    content = rug.crop((x0, y0, x1, y1))
    scale = 0.22 * RUG_FACTOR / ENV
    w, h = int(content.width * scale), int(content.height * scale)
    content = content.resize((w, h), Image.Resampling.LANCZOS)
    canvas.alpha_composite(content, (int(rug_plate[0] - w / 2), int(rug_plate[1] - h / 2)))

    # Wall art on the north-west wall face.
    wall_art_files = {
        "caseBoard": "office_case_board.png",
        "wallCityMap": "office_wall_city_map.png",
        "wallPhotos": "office_wall_photos.png",
        "framedLicence": "office_framed_licence.png",
    }
    for key, mount in lp.WALL_ART.items():
        art_name = wall_art_files.get(key)
        if art_name is None:
            continue
        px, py = mount.plate
        im = load(art_name)
        bx0, by0, bx1, by1 = content_box(im)
        content = im.crop((bx0, by0, bx1, by1))
        w = max(1, int(content.width * WALL_ART_SCALE))
        h = max(1, int(content.height * WALL_ART_SCALE))
        content = content.resize((w, h), Image.Resampling.LANCZOS)
        canvas.alpha_composite(content, (int(px - w / 2), int(py - h / 2)))

    # Depth props sorted far-to-near on their plate ground line.
    # Skip retired domestic fixtures that are no longer spawned in-scene.
    retired = {"personalWashbasin"}
    entries = []
    for prop in lp.PROPS:
        if prop.key in retired:
            continue
        plate = plate_point(prop.authored)
        entries.append((plate[1], prop))
    for _, prop in sorted(entries, key=lambda e: e[0]):
        paste_scaled(
            canvas,
            load(f"{prop.art}.png"),
            prop.display_scale / ENV,
            plate_point(prop.authored),
        )

    # Exterior frame + leaf: same absolute X/Y scales + anchors as the scene.
    thr = plate_point(lp.exterior_door_threshold_authored())
    door_leaf_pt = plate_point(lp.exterior_leaf_anchor_authored())
    frame_path = ART / "office_door_frame.png"
    if frame_path.exists():
        paste_scaled(
            canvas,
            load("office_door_frame.png"),
            1.0,
            thr,
            crop_content=False,
            anchor=(lp.exterior_frame_anchor_x(), lp.exterior_frame_anchor_y()),
            plate_scale_x=lp.exterior_frame_scale_x() / ENV,
            plate_scale_y=lp.exterior_frame_scale_y() / ENV,
        )
    paste_scaled(
        canvas,
        load("office_door_leaf.png"),
        1.0,
        door_leaf_pt,
        crop_content=False,
        anchor=(0.5, lp.exterior_leaf_anchor_y()),
        plate_scale_x=lp.exterior_leaf_scale_x() / ENV,
        plate_scale_y=lp.exterior_leaf_scale_y() / ENV,
    )
    # Internal open leaf still uses depth-prop anchor (0.5, 0.04).
    paste_scaled(
        canvas,
        load("office_internal_door_leaf.png"),
        lp.internal_leaf_scale() / ENV,
        plate_point(lp.internal_door_leaf_anchor()),
    )

    # Desk clutter matches DetectiveOfficeScene.addDeskItems (932×780 canvas).
    desk_prop = lp.PROP_BY_KEY["deskEnsemble"]
    desk_plate = plate_point(desk_prop.authored)
    desk_scale = desk_prop.display_scale / ENV
    desk_canvas = (932.0, 780.0)
    desk_anchor = (0.5, 0.04)
    for name, cx, cy in (
        ("office_desk_lamp", 245.0, 185.0),
        ("office_desk_phone", 340.0, 260.0),
        ("office_desk_typewriter", 475.0, 215.0),
        ("office_desk_notebook", 520.0, 310.0),
        ("office_desk_papers", 600.0, 270.0),
        ("office_desk_ashtray", 655.0, 325.0),
        ("office_desk_files", 735.0, 245.0),
    ):
        path = ART / f"{name}.png"
        if not path.exists():
            continue
        item = Image.open(path).convert("RGBA")
        w = max(1, int(round(item.width * desk_scale)))
        h = max(1, int(round(item.height * desk_scale)))
        item = item.resize((w, h), Image.Resampling.LANCZOS)
        # Scene: x = desk.x + (cx - canvas.w * ax) * scale
        #         y = desk.y + (canvas.h * (1-ay) - cy) * scale  (SpriteKit y-up)
        # Plate y-down paste uses the same offsets once desk_plate is y-flipped.
        px = desk_plate[0] + (cx - desk_canvas[0] * desk_anchor[0]) * desk_scale - w / 2
        # Convert scene y-up offset into plate y-down: scene +dy moves toward
        # camera-near / higher authored y / lower plate y after flip.
        scene_dy = (desk_canvas[1] * (1.0 - desk_anchor[1]) - cy) * desk_scale
        py = desk_plate[1] - scene_dy - h / 2
        canvas.alpha_composite(item, (int(round(px)), int(round(py))))

    OUT.mkdir(parents=True, exist_ok=True)
    canvas.save(OUT / "redesign_preview.png")
    canvas.resize((rp.ART_W // 3, rp.ART_H // 3), Image.Resampling.LANCZOS).save(
        OUT / "redesign_preview_third.png"
    )
    print(f"wrote {OUT / 'redesign_preview_third.png'}")


if __name__ == "__main__":
    main()

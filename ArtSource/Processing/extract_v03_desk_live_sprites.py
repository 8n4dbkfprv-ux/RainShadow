#!/usr/bin/env python3
"""Lift the V03 desk chair off the plate and copy desk occluder pixels.

The approved noir plate paints the detective's chair. A chairless seated
atlas cannot sit *in* that painting, so this script:

- extracts the camera-near desk chair as `office_desk_chair.png`
- inpaints that footprint with neighbouring rug/floor so the plate is chairless
- copies the writing surface and camera-near apron as occluder overlays
  (left on the plate; the copies sort in front of seated Voss)
"""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
BASE = (
    ROOT
    / "ArtSource/Generated/Office/NoirConceptV03/office_shell_noir_atmosphere_v03.png"
)
PROPS = ROOT / "ArtSource/Generated/Office/office_props_v01.json"
OFFICE = ROOT / "RainShadow Shared/Resources/Art/Props/Office"
PLATE_H = 2304
ENV = 0.395
FOCUS = (2048.0, 1152.0)

# Authored (y-up) seat of the camera-near V03 desk chair.
CHAIR_SEAT = (2178.0, 920.0)


def png_xy(authored_x: float, authored_y: float) -> tuple[int, int]:
    return int(round(authored_x)), int(round(PLATE_H - authored_y))


def map_point(x: float, y: float) -> tuple[float, float]:
    return FOCUS[0] + (x - FOCUS[0]) * ENV, FOCUS[1] + (y - FOCUS[1]) * ENV


def inpaint(rgb: np.ndarray, mask: np.ndarray, radius: int = 6, passes: int = 18) -> np.ndarray:
    """Fill mask from unmasked neighbours (iterative mean)."""
    out = rgb.copy()
    work = mask.copy()
    h, w = work.shape
    kernel = np.ones((radius * 2 + 1, radius * 2 + 1), dtype=np.float32)
    for _ in range(passes):
        if not work.any():
            break
        known = (~work).astype(np.float32)
        for c in range(3):
            num = Image.fromarray(out[..., c]).filter(ImageFilter.BoxBlur(radius))
            den = Image.fromarray((known * 255).astype(np.uint8)).filter(
                ImageFilter.BoxBlur(radius)
            )
            den_a = np.maximum(np.asarray(den, dtype=np.float32) / 255.0, 1e-4)
            filled = np.asarray(num, dtype=np.float32) / den_a
            out[..., c] = np.where(work, filled, out[..., c])
        # Shrink the hole from the border.
        eroded = Image.fromarray((work.astype(np.uint8) * 255)).filter(
            ImageFilter.MinFilter(3)
        )
        work = np.asarray(eroded) > 127
    return out.clip(0, 255).astype(np.uint8)


def ellipse_mask(size: tuple[int, int], cx: int, cy: int, rx: int, ry: int) -> np.ndarray:
    yy, xx = np.ogrid[: size[1], : size[0]]
    return ((xx - cx) / max(1, rx)) ** 2 + ((yy - cy) / max(1, ry)) ** 2 <= 1.0


def main() -> None:
    plate = Image.open(BASE).convert("RGB")
    rgb = np.asarray(plate, dtype=np.float32)
    sx, sy = png_xy(*CHAIR_SEAT)

    # Chair footprint: tall back + seat, camera-near of the kneehole.
    chair_mask = ellipse_mask(plate.size, sx, sy - 18, 52, 70)
    chair_mask |= ellipse_mask(plate.size, sx - 8, sy + 10, 48, 38)

    chair_rgba = np.zeros((plate.size[1], plate.size[0], 4), dtype=np.uint8)
    chair_rgba[..., :3] = np.asarray(plate)
    chair_rgba[..., 3] = np.where(chair_mask, 255, 0)
    ys, xs = np.where(chair_mask)
    pad = 8
    box = (
        max(0, int(xs.min()) - pad),
        max(0, int(ys.min()) - pad),
        min(plate.size[0], int(xs.max()) + 1 + pad),
        min(plate.size[1], int(ys.max()) + 1 + pad),
    )
    chair_img = Image.fromarray(chair_rgba, "RGBA").crop(box)
    OFFICE.mkdir(parents=True, exist_ok=True)
    chair_path = OFFICE / "office_desk_chair.png"
    chair_img.save(chair_path)

    seat_in_crop = (sx - box[0], sy - box[1])
    anchor_x = seat_in_crop[0] / chair_img.width
    # SpriteKit anchorY is from the bottom of the texture.
    anchor_y = 1.0 - (seat_in_crop[1] / chair_img.height)

    filled = inpaint(np.asarray(plate, dtype=np.float32), chair_mask)
    chairless = Image.fromarray(filled, "RGB")
    # Soften the seam.
    blur = chairless.filter(ImageFilter.GaussianBlur(1.2))
    mask_img = Image.fromarray((chair_mask.astype(np.uint8) * 255)).filter(
        ImageFilter.GaussianBlur(2)
    )
    chairless = Image.composite(blur, chairless, mask_img)
    BASE.parent.joinpath("office_shell_noir_atmosphere_v03_chairless.png").parent.mkdir(
        parents=True, exist_ok=True
    )
    chairless_path = BASE.parent / "office_shell_noir_atmosphere_v03_chairless.png"
    chairless.save(chairless_path)
    # The installer reads BASE_PLATE; replace the concept with the chairless plate.
    chairless.save(BASE)

    # Occluders: copy plate pixels (desk remains in the plate).
    def overlay_from_mask(mask: np.ndarray, path: Path) -> None:
        rgba = np.zeros((plate.size[1], plate.size[0], 4), dtype=np.uint8)
        rgba[..., :3] = np.asarray(plate)
        rgba[..., 3] = np.where(mask, 255, 0)
        Image.fromarray(rgba, "RGBA").save(path)

    desk_top = ellipse_mask(plate.size, *png_xy(1966, 1178), 210, 95)
    desk_front = ellipse_mask(plate.size, *png_xy(2010, 1080), 190, 70)
    overlay_from_mask(desk_top, OFFICE / "office_desk_top_occluder.png")
    overlay_from_mask(desk_front, OFFICE / "office_desk_front_occluder_v04.png")
    overlay_from_mask(desk_front | desk_top, OFFICE / "office_desk_actor_occluder.png")

    world_chair = map_point(*CHAIR_SEAT)
    origin = map_point(0, 0)
    document = json.loads(PROPS.read_text())
    by_id = {prop["id"]: prop for prop in document["props"]}
    by_id["office_desk_chair"].update(
        {
            "textureName": "office_desk_chair",
            "groundPoint": {"x": world_chair[0], "y": world_chair[1]},
            "anchorX": anchor_x,
            "anchorY": anchor_y,
            "scale": ENV,
        }
    )
    for occluder_id in (
        "office_desk_top_occluder",
        "office_desk_front_occluder_v04",
        "office_desk_actor_occluder",
    ):
        by_id[occluder_id].update(
            {
                "groundPoint": {"x": origin[0], "y": origin[1]},
                "anchorX": 0.0,
                "anchorY": 0.0,
                "scale": ENV,
            }
        )
    PROPS.write_text(json.dumps(document, indent=2, sort_keys=True) + "\n")
    print(f"chair crop {chair_img.size} anchor=({anchor_x:.4f},{anchor_y:.4f}) -> {chair_path}")
    print(f"chairless plate -> {chairless_path} and {BASE}")
    print(f"chair world {world_chair}")


if __name__ == "__main__":
    main()

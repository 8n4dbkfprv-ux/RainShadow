#!/usr/bin/env python3
"""Build large, read-only pose plates from the best existing pose authorities.

V11 contains larger authored animation masters for locomotion, while the V16 frame
inventory records the authoritative V12 source for every required body master.
The larger V11 idle/walk master is preferred when it exists; seated and transition
poses fall back to the inventory source.  Each figure is cropped, enlarged, and
centred on a 1024-square green plate without changing its pose or facing.
"""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image


PROCESSING_DIR = Path(__file__).resolve().parent
ROOT = PROCESSING_DIR.parents[1]
INVENTORY = (
    ROOT
    / "ArtSource/Generated/Characters/Detective/PreRendered3DV16/frame_inventory_v16.json"
)
OUTPUT = (
    ROOT
    / "ArtSource/Generated/Characters/Detective/PreRendered3DV17/PoseAuthorities"
)
V11_FRAMES = (
    ROOT
    / "ArtSource/Generated/Characters/Detective/PreRendered3DV11/Frames"
)
CANVAS = 1024
TARGET_HEIGHT = 900
GREEN = (0, 255, 0)


def subject_mask(image: Image.Image) -> np.ndarray:
    rgba = np.asarray(image.convert("RGBA"))
    rgb = rgba[..., :3].astype(np.int16)
    alpha = rgba[..., 3]
    red, green, blue = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    chroma = (green > 90) & (green > red + 25) & (green > blue + 25)
    return (alpha >= 16) & ~chroma


def make_plate(source: Path) -> Image.Image:
    with Image.open(source) as opened:
        image = opened.convert("RGBA")
    mask = subject_mask(image)
    ys, xs = np.where(mask)
    if not len(xs):
        raise ValueError(f"No non-chroma figure in {source}")

    x0, x1 = int(xs.min()), int(xs.max())
    y0, y1 = int(ys.min()), int(ys.max())
    width, height = x1 - x0 + 1, y1 - y0 + 1
    padding = max(4, round(max(width, height) * 0.08))
    crop = image.crop(
        (
            max(0, x0 - padding),
            max(0, y0 - padding),
            min(image.width, x1 + padding + 1),
            min(image.height, y1 + padding + 1),
        )
    )
    scale = TARGET_HEIGHT / crop.height
    resized = crop.resize(
        (max(1, round(crop.width * scale)), TARGET_HEIGHT),
        Image.Resampling.NEAREST,
    )
    if resized.width > CANVAS - 40:
        scale = (CANVAS - 40) / resized.width
        resized = resized.resize(
            (CANVAS - 40, max(1, round(resized.height * scale))),
            Image.Resampling.NEAREST,
        )

    plate = Image.new("RGB", (CANVAS, CANVAS), GREEN)
    rgb = Image.new("RGB", resized.size, GREEN)
    rgb.paste(resized.convert("RGB"), mask=resized.getchannel("A"))
    plate.paste(rgb, ((CANVAS - resized.width) // 2, (CANVAS - resized.height) // 2))
    return plate


def main() -> None:
    inventory = json.loads(INVENTORY.read_text(encoding="utf-8"))
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for call in inventory["generated_calls"]:
        v11_source = V11_FRAMES / f"voss_{call['id']}_chroma_v11.png"
        source = v11_source if v11_source.is_file() else ROOT / call["pose_source"]["path"]
        destination = OUTPUT / f"{call['id']}_pose_v17.png"
        make_plate(source).save(destination, format="PNG", optimize=True)
    print(f"Wrote {len(inventory['generated_calls'])} pose plates to {OUTPUT}")


if __name__ == "__main__":
    main()

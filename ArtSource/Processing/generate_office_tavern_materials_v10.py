#!/usr/bin/env python3
"""Paint original flat floor and wall materials for the V10 tavern office.

These are original procedural paintings, not crops of AR3351 or any other
Infinity Engine tileset. The generator projects them into the frozen room
diamond so ImageGen cannot move the camera or the door.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "ArtSource/Generated/Office/BGEETavernV10"
SIZE = 1024


def _boards() -> Image.Image:
    rng = np.random.default_rng(10)
    y = np.linspace(0.0, 1.0, SIZE)[:, None]
    x = np.linspace(0.0, 1.0, SIZE)[None, :]
    grain = 0.55 + 0.45 * rng.random((SIZE, SIZE))
    grain = Image.fromarray((grain * 255).astype(np.uint8), "L")
    grain = np.asarray(grain.filter(ImageFilter.GaussianBlur(1.1)), dtype=np.float32) / 255.0
    board = np.mod(y * 28.0 + 0.08 * np.sin(x * 18.0), 1.0)
    seam = np.clip(1.0 - np.abs(board - 0.04) / 0.04, 0.0, 1.0)
    dirt = 0.18 * np.abs(np.sin(x * 9.0 + y * 4.0))
    r = 86 + 48 * grain - 22 * seam - 18 * dirt
    g = 58 + 28 * grain - 16 * seam - 14 * dirt
    b = 32 + 14 * grain - 10 * seam - 8 * dirt
    rgb = np.clip(np.dstack([r, g, b]), 0, 255).astype(np.uint8)
    image = Image.fromarray(rgb, "RGB")
    return image.filter(ImageFilter.GaussianBlur(0.35))


def _paneling() -> Image.Image:
    rng = np.random.default_rng(11)
    y = np.linspace(0.0, 1.0, SIZE)[:, None]
    x = np.linspace(0.0, 1.0, SIZE)[None, :]
    noise = rng.random((SIZE, SIZE))
    noise = Image.fromarray((noise * 255).astype(np.uint8), "L")
    noise = np.asarray(noise.filter(ImageFilter.GaussianBlur(1.4)), dtype=np.float32) / 255.0
    panel = np.mod(x * 7.0, 1.0)
    stile = np.clip(1.0 - np.abs(panel - 0.06) / 0.05, 0.0, 1.0)
    rail = np.clip(1.0 - np.abs(np.mod(y * 5.0, 1.0) - 0.08) / 0.06, 0.0, 1.0)
    stain = 0.22 * np.clip(y - 0.35, 0.0, 1.0)
    r = 62 + 36 * noise - 18 * stile - 10 * rail - 16 * stain
    g = 46 + 22 * noise - 12 * stile - 8 * rail - 8 * stain
    b = 32 + 12 * noise - 8 * stile - 6 * rail - 4 * stain
    rgb = np.clip(np.dstack([r, g, b]), 0, 255).astype(np.uint8)
    image = Image.fromarray(rgb, "RGB")
    return image.filter(ImageFilter.GaussianBlur(0.4))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    floor = OUT / "floor_material_source_v10.png"
    wall = OUT / "wall_material_source_v10.png"
    if floor.exists() or wall.exists():
        raise SystemExit(
            "refusing to overwrite ImageGen V10 materials; delete them first if you "
            "intentionally want the procedural fallback"
        )
    _boards().save(floor)
    _paneling().save(wall)
    print(f"wrote {floor.relative_to(ROOT)}")
    print(f"wrote {wall.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Crop keyed ImageGen masters to the exact RainShadow UI runtime contracts.

Run the built-in ImageGen chroma-removal helper first to produce the two
``*_keyed_full.png`` inputs. This stage removes the transparent generator
padding, resamples the painted chrome to its authored SpriteKit size, and
writes both the review master and runtime resource without copying xattrs.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import shutil

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]


@dataclass(frozen=True)
class Asset:
    keyed_full: Path
    keyed: Path
    runtime: Path
    size: tuple[int, int]


ASSETS = (
    Asset(
        keyed_full=ROOT / "ArtSource/Generated/UI/HUD/hud_loot_container_panel_v01_keyed_full.png",
        keyed=ROOT / "ArtSource/Generated/UI/HUD/hud_loot_container_panel_v01_keyed.png",
        runtime=ROOT / "RainShadow Shared/Resources/Art/UI/HUD/hud_loot_container_panel_v01.png",
        size=(1536, 256),
    ),
    Asset(
        keyed_full=ROOT / "ArtSource/Generated/UI/Inventory/inventory_section_bag_v06_keyed_full.png",
        keyed=ROOT / "ArtSource/Generated/UI/Inventory/inventory_section_bag_v06_keyed.png",
        runtime=ROOT / "RainShadow Shared/Resources/Art/UI/Inventory/inventory_section_bag_v06.png",
        size=(1680, 190),
    ),
)


def process(asset: Asset) -> None:
    image = Image.open(asset.keyed_full).convert("RGBA")
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        raise RuntimeError(f"No opaque chrome found in {asset.keyed_full}")

    cropped = image.crop(bounds)
    # A two-pixel transparent sentinel keeps antialiasing from turning the
    # tightly cropped outer corners opaque after the exact-size resample.
    inner_size = (asset.size[0] - 4, asset.size[1] - 4)
    resized = cropped.resize(inner_size, Image.Resampling.LANCZOS)
    output = Image.new("RGBA", asset.size, (0, 0, 0, 0))
    output.alpha_composite(resized, (2, 2))

    asset.keyed.parent.mkdir(parents=True, exist_ok=True)
    asset.runtime.parent.mkdir(parents=True, exist_ok=True)
    output.save(asset.keyed, format="PNG", optimize=True)
    shutil.copyfile(asset.keyed, asset.runtime)

    corners = (
        output.getpixel((0, 0))[3],
        output.getpixel((output.width - 1, 0))[3],
        output.getpixel((0, output.height - 1))[3],
        output.getpixel((output.width - 1, output.height - 1))[3],
    )
    if any(alpha > 16 for alpha in corners):
        raise RuntimeError(f"Opaque corner after crop for {asset.keyed}: {corners}")

    opaque_green = 0
    for red, green, blue, alpha in output.get_flattened_data():
        if alpha > 16 and green > 240 and red < 32 and blue < 32:
            opaque_green += 1
    if opaque_green:
        raise RuntimeError(f"Residual chroma in {asset.keyed}: {opaque_green} pixels")

    print(
        f"wrote {asset.keyed.relative_to(ROOT)} and "
        f"{asset.runtime.relative_to(ROOT)} at {output.width}x{output.height}; "
        f"corner alpha={corners}"
    )


def main() -> None:
    for asset in ASSETS:
        process(asset)


if __name__ == "__main__":
    main()

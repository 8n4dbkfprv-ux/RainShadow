#!/usr/bin/env python3
"""Install the corrected classic-layout loot panel and its bulk-take control."""

from __future__ import annotations

from pathlib import Path
import shutil

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
ASSETS = (
    (
        ROOT / "ArtSource/Generated/UI/HUD/hud_loot_container_panel_v02_keyed_full.png",
        ROOT / "ArtSource/Generated/UI/HUD/hud_loot_container_panel_v02_keyed.png",
        ROOT / "RainShadow Shared/Resources/Art/UI/HUD/hud_loot_container_panel_v02.png",
        (1600, 320),
    ),
    (
        ROOT / "ArtSource/Generated/UI/HUD/hud_loot_take_all_v03_keyed_full.png",
        ROOT / "ArtSource/Generated/UI/HUD/hud_loot_take_all_v03_keyed.png",
        ROOT / "RainShadow Shared/Resources/Art/UI/HUD/hud_loot_take_all_v03.png",
        (256, 256),
    ),
)


def install(source: Path, keyed: Path, runtime: Path, runtime_size: tuple[int, int]) -> None:
    image = Image.open(source).convert("RGBA")
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        raise RuntimeError(f"No opaque art found in {source}")

    cropped = image.crop(bounds)
    inner_size = (runtime_size[0] - 4, runtime_size[1] - 4)
    resized = cropped.resize(inner_size, Image.Resampling.LANCZOS)
    output = Image.new("RGBA", runtime_size, (0, 0, 0, 0))
    output.alpha_composite(resized, (2, 2))

    keyed.parent.mkdir(parents=True, exist_ok=True)
    runtime.parent.mkdir(parents=True, exist_ok=True)
    output.save(keyed, format="PNG", optimize=True)
    shutil.copyfile(keyed, runtime)

    corners = (
        output.getpixel((0, 0))[3],
        output.getpixel((output.width - 1, 0))[3],
        output.getpixel((0, output.height - 1))[3],
        output.getpixel((output.width - 1, output.height - 1))[3],
    )
    if any(alpha > 16 for alpha in corners):
        raise RuntimeError(f"Opaque corner after processing {keyed}: {corners}")

    residual_chroma = sum(
        1
        for red, green, blue, alpha in output.get_flattened_data()
        if alpha > 16 and green > 240 and red < 32 and blue < 32
    )
    if residual_chroma:
        raise RuntimeError(f"Residual chroma in {keyed}: {residual_chroma} pixels")

    print(
        f"wrote {keyed.relative_to(ROOT)} and {runtime.relative_to(ROOT)} "
        f"at {output.width}x{output.height}; corner alpha={corners}"
    )


def main() -> None:
    for source, keyed, runtime, runtime_size in ASSETS:
        install(source, keyed, runtime, runtime_size)


if __name__ == "__main__":
    main()

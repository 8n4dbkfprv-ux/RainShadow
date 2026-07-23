#!/usr/bin/env python3
"""A/B pixelation study: rebake the V6 Voss SE key through harsher raster
parameter sets without regenerating art, and stage comparison sheets against
the BGEE references.

Each variant keeps the runtime contract (200 px texture body registered at
FOOT_Y on a 512 canvas, displayed at 256 with nearest filtering) so the
character stays the same size on screen; only the native raster density,
palette, downsample filter, and edge hardness change.
"""

from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
KEY_RGBA = ROOT / "ArtSource/Generated/Characters/Detective/PreRendered3DV6/voss_key_se_rgba_v06.png"
OFFICE_PLATE = ROOT / "ArtSource/References/UI/Map/office_runtime_clean_v02.png"
BGEE_REFS = ROOT / "ArtSource/References/BGEE"
OUTPUT = ROOT / "ArtSource/Generated/Characters/Detective/PixelationAB"

FRAME_SIZE = 512
TEXTURE_BODY_HEIGHT = 200  # contract: 100 px native * 2x storage
FOOT_Y = 434


@dataclass(frozen=True)
class Variant:
    label: str
    native_height: int
    colors: int
    resample: Image.Resampling
    hard_alpha: bool = False


VARIANTS = [
    Variant("A current 100/96 lanczos", 100, 96, Image.Resampling.LANCZOS),
    Variant("B 80/96 lanczos", 80, 96, Image.Resampling.LANCZOS),
    Variant("C 80/64 lanczos", 80, 64, Image.Resampling.LANCZOS),
    Variant("D 72/64 lanczos", 72, 64, Image.Resampling.LANCZOS),
    Variant("E 80/64 box", 80, 64, Image.Resampling.BOX),
    Variant("F 80/48 hard-alpha", 80, 48, Image.Resampling.LANCZOS, hard_alpha=True),
]


def premultiplied_resize(
    image: Image.Image, size: tuple[int, int], resample: Image.Resampling
) -> Image.Image:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.float32) / 255.0
    rgba[..., :3] *= rgba[..., 3:4]
    channels = []
    for channel in range(4):
        source = Image.fromarray(np.round(rgba[..., channel] * 255).astype(np.uint8), "L")
        channels.append(np.asarray(source.resize(size, resample), dtype=np.float32) / 255.0)
    alpha = channels[3]
    rgb = np.stack(channels[:3], axis=2)
    np.divide(rgb, alpha[..., None], out=rgb, where=alpha[..., None] > 0)
    result = np.concatenate((np.clip(rgb, 0, 1), alpha[..., None]), axis=2)
    return Image.fromarray(np.round(result * 255).astype(np.uint8), "RGBA")


def pixelize_variant(figure: Image.Image, variant: Variant) -> Image.Image:
    """V3 pixelize_figure generalized over raster density/palette/filter."""
    pixels = np.asarray(figure.convert("RGBA")).copy()
    pixels[pixels[..., 3] < 16] = 0
    figure = Image.fromarray(pixels, "RGBA")
    bbox = figure.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError("Figure has no opaque subject")
    figure = figure.crop(bbox)

    native_width = max(1, round(figure.width * variant.native_height / figure.height))
    native = premultiplied_resize(figure, (native_width, variant.native_height), variant.resample)

    alpha = native.getchannel("A")
    if variant.hard_alpha:
        alpha = alpha.point(lambda value: 255 if value >= 128 else 0)
    limited_rgb = native.convert("RGB").quantize(
        colors=variant.colors,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    ).convert("RGB")
    native = Image.merge("RGBA", (*limited_rgb.split(), alpha))

    # Snap back to the 200 px texture body so on-screen size is unchanged.
    texture_width = max(1, round(native_width * TEXTURE_BODY_HEIGHT / variant.native_height))
    return native.resize((texture_width, TEXTURE_BODY_HEIGHT), Image.Resampling.NEAREST)


def register(figure: Image.Image) -> Image.Image:
    canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE))
    canvas.alpha_composite(
        figure, ((FRAME_SIZE - figure.width) // 2, FOOT_Y - TEXTURE_BODY_HEIGHT)
    )
    return canvas


def office_tile(frame: Image.Image, plate: Image.Image, tile_size: int = 260) -> Image.Image:
    """Play-scale composite matching process_character_key_v6 preview math."""
    root_x, root_y = 790, 800
    tile = plate.crop(
        (root_x - tile_size // 2, root_y - 190, root_x + tile_size // 2, root_y + tile_size - 190)
    ).convert("RGBA")
    center_x, center_y = tile_size // 2, 190
    shadow = Image.new("RGBA", tile.size)
    ImageDraw.Draw(shadow).ellipse(
        (center_x - 27, center_y - 10, center_x + 27, center_y + 10), fill=(0, 0, 0, 88)
    )
    tile.alpha_composite(shadow)
    display = frame.resize((256, 256), Image.Resampling.NEAREST)
    tile.alpha_composite(display, (center_x - 128, center_y - 217))
    return tile


def labeled(tile: Image.Image, text: str, label_height: int = 26) -> Image.Image:
    block = Image.new("RGBA", (tile.width, tile.height + label_height), (18, 18, 18, 255))
    block.alpha_composite(tile, (0, 0))
    ImageDraw.Draw(block).text((6, tile.height + 6), text, fill=(230, 230, 230, 255))
    return block


def zoom_tile(frame: Image.Image, zoom: int = 3) -> Image.Image:
    """Sprite-only nearest zoom of the upper body for pixel-structure reading."""
    display = frame.resize((256, 256), Image.Resampling.NEAREST)
    bbox = display.getchannel("A").getbbox()
    crop = display.crop(bbox)
    crop = crop.resize((crop.width * zoom, crop.height * zoom), Image.Resampling.NEAREST)
    tile = Image.new("RGBA", (crop.width + 20, crop.height + 20), (30, 30, 34, 255))
    tile.alpha_composite(crop, (10, 10))
    return tile


def grid(tiles: list[Image.Image], columns: int) -> Image.Image:
    width = max(tile.width for tile in tiles)
    height = max(tile.height for tile in tiles)
    rows = (len(tiles) + columns - 1) // columns
    sheet = Image.new("RGBA", (width * columns, height * rows), (18, 18, 18, 255))
    for index, tile in enumerate(tiles):
        x = (index % columns) * width + (width - tile.width) // 2
        y = (index // columns) * height
        sheet.alpha_composite(tile, (x, y))
    return sheet


def bgee_reference_tiles(target_body_height: int = 105) -> list[Image.Image]:
    tiles = []
    for name in ("bgee_avatar_green_robe.png", "bgee_avatar_red_tunic_fighter.png"):
        ref = Image.open(BGEE_REFS / name).convert("RGBA")
        # These are tight zoom crops; scaling the full crop so its height is a
        # bit above the target body height puts the figure near play scale.
        scale = (target_body_height * 1.25) / ref.height
        ref = ref.resize((round(ref.width * scale), round(ref.height * scale)), Image.Resampling.LANCZOS)
        tile = Image.new("RGBA", (260, 260), (25, 25, 28, 255))
        tile.alpha_composite(ref, ((260 - ref.width) // 2, (260 - ref.height) // 2))
        tiles.append(labeled(tile, f"BGEE ref {name.split('_')[2]}"))
    return tiles


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    source = Image.open(KEY_RGBA).convert("RGBA")
    plate = Image.open(OFFICE_PLATE).convert("RGBA")

    play_tiles: list[Image.Image] = []
    zoom_tiles: list[Image.Image] = []
    for variant in VARIANTS:
        frame = register(pixelize_variant(source, variant))
        stem = variant.label.split()[0].lower()
        frame.save(OUTPUT / f"voss_key_se_variant_{stem}.png", optimize=True)
        play_tiles.append(labeled(office_tile(frame, plate), variant.label))
        zoom_tiles.append(labeled(zoom_tile(frame), variant.label))
    play_tiles.extend(bgee_reference_tiles())

    play_sheet = grid(play_tiles, columns=4)
    play_sheet.convert("RGB").save(OUTPUT / "qa_playscale_sheet_v01.png", optimize=True)
    zoom_sheet = grid(zoom_tiles, columns=3)
    zoom_sheet.convert("RGB").save(OUTPUT / "qa_zoom_sheet_v01.png", optimize=True)
    print(f"Wrote {OUTPUT.relative_to(ROOT)}: {len(VARIANTS)} variants + 2 sheets")


if __name__ == "__main__":
    main()

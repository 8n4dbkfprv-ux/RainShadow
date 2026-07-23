#!/usr/bin/env python3
"""V7 BGEE pixelation crunch: rebake every V6 Voss/March gameplay cell with a
denser raster, without regenerating any art.

Selected via the A/B study in `qa_pixelation_ab_v01.py` (variant C):

- native body drops from 100 px to 80 px
- palette drops from 96 to 64 colors (still no dithering), and the palette is
  now derived from the figure's opaque pixels only, so transparent canvas and
  dominant coat tones no longer squeeze skin/shirt hues out of the ramp
- the native raster is nearest-upscaled back to the contract's 200 px texture
  body (2.5x), so registration (`FOOT_Y = 434`, 512 canvas), display size, and
  all runtime scale code stay untouched

Everything else reuses the V6 flow verbatim: the same chroma masters, slicing,
mirroring, arm-layer derivation, and atlas names. Portraits and paperdoll keep
their hand-readable pass and are not reprocessed.
"""

from pathlib import Path
import shutil

import numpy as np
from PIL import Image, ImageDraw

import process_pre_rendered_characters_v3 as raster
import process_pre_rendered_characters_v6 as v6


ROOT = Path(__file__).resolve().parents[2]
ATLASES = ROOT / "RainShadow Shared/Resources/Art/Atlases"
BACKUP = ROOT / "ArtSource/Generated/Characters/RuntimeBackupPreRendered3DV6"

NATIVE_BODY_HEIGHT = 80
PALETTE_COLORS = 64
TEXTURE_BODY_HEIGHT = 200  # unchanged runtime contract


def pixelize_figure_v7(figure: Image.Image, crop_to_alpha: bool = True) -> Image.Image:
    """V3 pixelize_figure with the V7 crunch parameters."""
    pixels = np.asarray(figure.convert("RGBA")).copy()
    pixels[pixels[..., 3] < 16] = 0
    figure = Image.fromarray(pixels, "RGBA")
    if crop_to_alpha:
        bbox = figure.getchannel("A").getbbox()
        if bbox is None:
            raise RuntimeError("Generated figure has no opaque subject")
        figure = figure.crop(bbox)
    native_width = max(1, round(figure.width * NATIVE_BODY_HEIGHT / figure.height))
    native = raster.premultiplied_resize(figure, (native_width, NATIVE_BODY_HEIGHT))
    alpha = native.getchannel("A")

    # Build the 64-color ramp from opaque figure pixels only; quantizing the
    # whole canvas lets the transparent-black field waste palette entries and
    # collapse minority hues (skin, shirt) into the dominant coat colors.
    pixels = np.asarray(native)
    opaque = pixels[pixels[..., 3] > 0][:, :3]
    palette_source = Image.fromarray(opaque.reshape((1, -1, 3)), "RGB")
    palette = palette_source.quantize(
        colors=PALETTE_COLORS,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    )
    limited_rgb = native.convert("RGB").quantize(
        palette=palette, dither=Image.Dither.NONE
    ).convert("RGB")
    native = Image.merge("RGBA", (*limited_rgb.split(), alpha))
    texture_width = max(1, round(native_width * TEXTURE_BODY_HEIGHT / NATIVE_BODY_HEIGHT))
    return native.resize((texture_width, TEXTURE_BODY_HEIGHT), Image.Resampling.NEAREST)


def save_frame_v7(frame: Image.Image, atlas_name: str, filename: str, source_dir: Path) -> None:
    """As v6.save_frame, but registered masters land in Registered_v07."""
    registered_dir = source_dir / "Registered_v07"
    registered_dir.mkdir(parents=True, exist_ok=True)
    atlas = ATLASES / atlas_name
    atlas.mkdir(parents=True, exist_ok=True)
    path = registered_dir / filename
    frame.save(path, optimize=True)
    shutil.copy2(path, atlas / filename)


def backup_v6_runtime() -> None:
    if BACKUP.exists():
        return
    BACKUP.mkdir(parents=True)
    for atlas_name in v6.NEW_ATLASES:
        source = ATLASES / atlas_name
        if not source.exists():
            continue
        destination = BACKUP / atlas_name
        destination.mkdir()
        for path in source.glob("*.png"):
            shutil.copy2(path, destination / path.name)


def make_previews_v7() -> None:
    frame_size = raster.FRAME_SIZE
    specs = [
        (v6.DETECTIVE_SOURCE, "preview_walk_v07.png", "VossWalk.atlas",
         [f"voss_walk_{d}_{i:02d}.png" for d in v6.DIRECTIONS for i in range(8)], 8),
        (v6.DETECTIVE_SOURCE, "preview_idle_v07.png", "VossIdle.atlas",
         [f"voss_standing_idle_{d}_{i:02d}.png" for d in v6.DIRECTIONS for i in range(4)], 4),
        (v6.DETECTIVE_SOURCE, "preview_seat_transitions_v07.png", "VossSeatTransitions.atlas",
         [f"voss_stand_up_se_{i:02d}.png" for i in range(12)]
         + [f"voss_sit_down_se_{i:02d}.png" for i in range(12)], 6),
        (v6.CLIENT_SOURCE, "preview_lila_v07.png", "LilaArrival.atlas",
         [f"lila_arrival_sw_{i:02d}.png" for i in range(9)]
         + [f"lila_departure_ne_{i:02d}.png" for i in range(8)], 9),
    ]
    for source_dir, filename, atlas_name, names, columns in specs:
        rows = (len(names) + columns - 1) // columns
        preview = Image.new("RGBA", (frame_size * columns, frame_size * rows), (24, 28, 31, 255))
        for index, name in enumerate(names):
            frame = Image.open(ATLASES / atlas_name / name).convert("RGBA")
            preview.alpha_composite(frame, ((index % columns) * frame_size, (index // columns) * frame_size))
        preview.save(source_dir / filename, optimize=True)

    office = Image.open(ROOT / "ArtSource/References/UI/Map/office_runtime_clean_v02.png").convert("RGBA")
    actors = [
        (790, 800, ATLASES / "VossIdle.atlas/voss_standing_idle_se_00.png", 54, 20),
        (1450, 800, ATLASES / "LilaArrival.atlas/lila_arrival_sw_08.png", 44, 15),
    ]
    shadow_layer = Image.new("RGBA", office.size)
    shadow_draw = ImageDraw.Draw(shadow_layer)
    for root_x, root_y, _, shadow_w, shadow_h in actors:
        shadow_draw.ellipse(
            (root_x - shadow_w // 2, root_y - shadow_h // 2, root_x + shadow_w // 2, root_y + shadow_h // 2),
            fill=(0, 0, 0, 88),
        )
    office.alpha_composite(shadow_layer)
    for root_x, root_y, path, _, _ in actors:
        frame = Image.open(path).convert("RGBA").resize((256, 256), Image.Resampling.NEAREST)
        office.alpha_composite(frame, (root_x - 128, root_y - 217))
    office.convert("RGB").save(
        ROOT / "ArtSource/Generated/Characters/preview_characters_in_office_v07.png",
        optimize=True,
    )


def main() -> None:
    backup_v6_runtime()
    raster.pixelize_figure = pixelize_figure_v7
    v6.save_frame = save_frame_v7
    v6.process_voss_locomotion()
    v6.process_voss_desk_chain()
    v6.process_lila()
    make_previews_v7()
    cells = 9 * 8 + 9 * 4 + 4 + 8 + 8 + 24 + 17
    print(
        f"Rebaked {cells} atlas cells at {NATIVE_BODY_HEIGHT}px native / "
        f"{PALETTE_COLORS} colors (V7 crunch); V6 runtime backed up to {BACKUP.name}"
    )


if __name__ == "__main__":
    main()

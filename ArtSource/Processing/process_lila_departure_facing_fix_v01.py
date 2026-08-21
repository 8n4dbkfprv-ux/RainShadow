#!/usr/bin/env python3
"""Install the NE-facing Lila departure strip and rebake only those atlas cells.

Uses the active V7/BGEE crunch and matches the approved facing master's emerald
garment to the installed V11 arrival strip. Arrival frames are untouched.
"""

from pathlib import Path
import shutil

from PIL import Image
import numpy as np

import process_pre_rendered_characters_v3 as raster
import process_pre_rendered_characters_v6 as v6
import process_pre_rendered_characters_v7 as v7
from process_character_gait_v5 import remove_green_screen


ROOT = Path(__file__).resolve().parents[2]
CLIENT = ROOT / "ArtSource/Generated/Characters/Client/PreRendered3DV6"
FIX = CLIENT / "DepartureFacingFixV1"
ATLASES = ROOT / "RainShadow Shared/Resources/Art/Atlases"

CHROMA_MASTER = CLIENT / "lila_departure_ne_strip_chroma_v06.png"
RGBA_MASTER = CLIENT / "lila_departure_ne_strip_rgba_v06.png"
COMBINED_SOURCE = FIX / "lila_departure_ne_strip_combined_gen.png"


def coat_green_minus_red(image: Image.Image) -> float | None:
    """Mirror the shipped Swift garment measurement."""
    pixels = np.asarray(image.convert("RGBA")).astype(np.int16)
    red, green, blue, alpha = (pixels[..., channel] for channel in range(4))
    coat = (
        (alpha > 80)
        & (green > 30)
        & (green < 160)
        & (green > red)
        & (green > blue)
    )
    if int(coat.sum()) <= 30:
        return None
    return float((green[coat] - red[coat]).mean())


def arrival_emerald_delta() -> float:
    """Use the installed arrival cells as wardrobe authority for departure."""
    atlas = ATLASES / "LilaArrival.atlas"
    values: list[float] = []
    for index in range(9):
        with Image.open(atlas / f"lila_arrival_sw_{index:02d}.png") as opened:
            value = coat_green_minus_red(opened.convert("RGBA"))
        if value is None:
            raise RuntimeError(f"Arrival phase {index} has no measurable emerald garment")
        values.append(value)
    return float(np.mean(values))


def match_arrival_emerald(image: Image.Image, target_delta: float) -> Image.Image:
    """Match green/red chroma without changing geometry, alpha, or colour count."""
    current = coat_green_minus_red(image)
    if current is None:
        raise RuntimeError("Departure frame has no measurable emerald garment")
    shift = int(round(target_delta - current))
    pixels = np.asarray(image.convert("RGBA")).copy()
    red = pixels[..., 0].astype(np.int16)
    green = pixels[..., 1].astype(np.int16)
    blue = pixels[..., 2].astype(np.int16)
    alpha = pixels[..., 3]
    coat = (
        (alpha > 80)
        & (green > 30)
        & (green < 160)
        & (green > red)
        & (green > blue)
    )
    pixels[..., 0][coat] = np.clip(red[coat] - shift, 0, 255).astype(np.uint8)
    return Image.fromarray(pixels, "RGBA")


def save_departure_frame(
    frame: Image.Image, filename: str, target_delta: float
) -> None:
    """Finalise once, then apply the palette-preserving wardrobe match."""
    frame = v7.crunch_mod.finalise(frame)
    frame = match_arrival_emerald(frame, target_delta)
    registered = CLIENT / "Registered_v07"
    registered.mkdir(parents=True, exist_ok=True)
    atlas = ATLASES / "LilaArrival.atlas"
    atlas.mkdir(parents=True, exist_ok=True)
    path = registered / filename
    frame.save(path, optimize=True)
    shutil.copy2(path, atlas / filename)


def install_master() -> None:
    if not COMBINED_SOURCE.exists():
        raise FileNotFoundError(f"Missing approved NE strip: {COMBINED_SOURCE}")
    # Provenance copies of rejected NW masters live in DepartureFacingFixV1/.
    shutil.copy2(COMBINED_SOURCE, CHROMA_MASTER)
    print(f"Installed chroma master from {COMBINED_SOURCE.name}")


def process_departure() -> None:
    remove_green_screen(CHROMA_MASTER, RGBA_MASTER)
    figures = raster.crop_components(RGBA_MASTER, 8, 1)
    if len(figures) != 8:
        raise RuntimeError(f"Expected 8 departure figures, found {len(figures)}")

    raster.pixelize_figure = v7.pixelize_figure_v7
    target_delta = arrival_emerald_delta()
    for index, figure in enumerate(figures):
        frame = raster.register(figure)
        save_departure_frame(
            frame, f"lila_departure_ne_{index:02d}.png", target_delta
        )
    print(f"Wrote 8 V7 departure cells to Registered_v07/ and LilaArrival.atlas")


def refresh_preview() -> None:
    frame_size = raster.FRAME_SIZE
    names = [f"lila_arrival_sw_{i:02d}.png" for i in range(9)] + [
        f"lila_departure_ne_{i:02d}.png" for i in range(8)
    ]
    columns = 9
    rows = (len(names) + columns - 1) // columns
    preview = Image.new("RGBA", (frame_size * columns, frame_size * rows), (24, 28, 31, 255))
    atlas = ATLASES / "LilaArrival.atlas"
    for index, name in enumerate(names):
        frame = Image.open(atlas / name).convert("RGBA")
        preview.alpha_composite(
            frame,
            ((index % columns) * frame_size, (index // columns) * frame_size),
        )
    out = CLIENT / "preview_lila_v07.png"
    preview.save(out, optimize=True)
    print(f"Refreshed {out.name}")


def main() -> None:
    install_master()
    process_departure()
    refresh_preview()


if __name__ == "__main__":
    main()

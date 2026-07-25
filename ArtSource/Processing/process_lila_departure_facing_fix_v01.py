#!/usr/bin/env python3
"""Install the NE-facing Lila departure strip and rebake only those atlas cells.

Uses the V7 pixelation crunch (80px native / 64-color opaque ramp / 200px texture
body) so runtime stays on the shipping contract. Arrival frames are untouched.
"""

from pathlib import Path
import shutil

from PIL import Image

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
    for index, figure in enumerate(figures):
        frame = raster.register(figure)
        v7.save_frame_v7(
            frame,
            "LilaArrival.atlas",
            f"lila_departure_ne_{index:02d}.png",
            CLIENT,
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

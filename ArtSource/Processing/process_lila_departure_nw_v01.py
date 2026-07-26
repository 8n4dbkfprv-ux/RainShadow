#!/usr/bin/env python3
"""Install the NW-facing Lila departure strip and rebake those atlas cells.

Chair→internal-door exit travel is northwest; NE-only sprites read as wrong-facing
on that segment. Uses the same V7 crunch as the NE facing-fix processor.
Arrival and NE departure cells are untouched.
"""

from pathlib import Path
import shutil

from PIL import Image

import process_pre_rendered_characters_v3 as raster
import process_pre_rendered_characters_v7 as v7
from process_character_gait_v5 import remove_green_screen


ROOT = Path(__file__).resolve().parents[2]
CLIENT = ROOT / "ArtSource/Generated/Characters/Client/PreRendered3DV6"
FIX = CLIENT / "DepartureFacingFixV1"
NW = FIX / "DepartureNW"
ATLASES = ROOT / "RainShadow Shared/Resources/Art/Atlases"

CHROMA_MASTER = CLIENT / "lila_departure_nw_strip_chroma_v01.png"
RGBA_MASTER = CLIENT / "lila_departure_nw_strip_rgba_v01.png"
COMBINED_SOURCE = NW / "lila_departure_nw_strip_combined_gen.png"


def install_master() -> None:
    if not COMBINED_SOURCE.exists():
        raise FileNotFoundError(f"Missing approved NW strip: {COMBINED_SOURCE}")
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
            f"lila_departure_nw_{index:02d}.png",
            CLIENT,
        )
    print("Wrote 8 V7 NW departure cells to Registered_v07/ and LilaArrival.atlas")


def refresh_preview() -> None:
    frame_size = raster.FRAME_SIZE
    names = (
        [f"lila_arrival_sw_{i:02d}.png" for i in range(9)]
        + [f"lila_departure_ne_{i:02d}.png" for i in range(8)]
        + [f"lila_departure_nw_{i:02d}.png" for i in range(8)]
    )
    columns = 9
    rows = (len(names) + columns - 1) // columns
    preview = Image.new("RGBA", (frame_size * columns, frame_size * rows), (24, 28, 31, 255))
    atlas = ATLASES / "LilaArrival.atlas"
    for index, name in enumerate(names):
        path = atlas / name
        if not path.exists():
            continue
        frame = Image.open(path).convert("RGBA")
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

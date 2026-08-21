#!/usr/bin/env python3
"""Rebake every V6 Voss/March gameplay cell through the crunch, without
regenerating any art.

`pixelize_figure_v7` is now a thin wrapper over `crunch.crunch`. Six scripts
import this name, so it stays; the parameters moved to `crunch.CrunchSpec` when
V14 first replaced V7's 80px/64-colour global median cut with a 56px 1-bit-alpha
raster and per-material shade ramps. The active BGEE_V1 recipe now uses a
measured 64px/64-colour BAM-like craft grid. See `crunch.py` for the reasoning
and `qa_pixelation_ab_v03.py` for the play-scale comparison.

Everything else reuses the V6 flow verbatim: the same chroma masters, slicing,
mirroring, arm-layer derivation, and atlas names. Portraits and paperdoll keep
their hand-readable pass and are not reprocessed.
"""

from pathlib import Path
import shutil

import numpy as np
from PIL import Image, ImageDraw

import crunch as crunch_mod
import process_pre_rendered_characters_v3 as raster
import process_pre_rendered_characters_v6 as v6


ROOT = Path(__file__).resolve().parents[2]
ATLASES = ROOT / "RainShadow Shared/Resources/Art/Atlases"
BACKUP = ROOT / "ArtSource/Generated/Characters/RuntimeBackupPreRendered3DV6"

NATIVE_BODY_HEIGHT = crunch_mod.ACTIVE.native_rows
PALETTE_COLORS = crunch_mod.ACTIVE.colors
TEXTURE_BODY_HEIGHT = crunch_mod.TEXTURE_BODY_HEIGHT  # unchanged runtime contract


def pixelize_figure_v7(figure: Image.Image, crop_to_alpha: bool = True) -> Image.Image:
    """The crunch every installer monkey-patches onto `raster.pixelize_figure`.

    Kept under this name because six scripts import it; the implementation now
    lives in `crunch.py` and follows whatever `crunch.ACTIVE` is (BGEE_V1 today).
    """
    return crunch_mod.crunch(figure, crop_to_alpha=crop_to_alpha)


def save_frame_v7(frame: Image.Image, atlas_name: str, filename: str, source_dir: Path) -> None:
    """As v6.save_frame, but registered masters land in Registered_v07."""
    # Palette last: see crunch.finalise.
    frame = crunch_mod.finalise(frame)
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

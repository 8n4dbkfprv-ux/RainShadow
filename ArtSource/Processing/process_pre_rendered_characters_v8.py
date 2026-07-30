#!/usr/bin/env python3
"""V8 Harlan Voss identity refresh: process PreRendered3DV8 masters with V7 crunch.

Reuses V6 slicing/mirroring/registration and V7 pixelization (80px / 64 colors /
nearest → 200px). Lila March is not regenerated. Portraits/paperdoll are installed
separately (hand-readable; no nearest-pixelize).
"""

from pathlib import Path
import shutil

from PIL import Image, ImageDraw

import process_pre_rendered_characters_v3 as raster
import process_pre_rendered_characters_v6 as v6
from process_pre_rendered_characters_v7 import pixelize_figure_v7
from process_character_gait_v5 import remove_green_screen


ROOT = Path(__file__).resolve().parents[2]
DETECTIVE_SOURCE = ROOT / "ArtSource/Generated/Characters/Detective/PreRendered3DV8"
ATLASES = ROOT / "RainShadow Shared/Resources/Art/Atlases"
BACKUP = ROOT / "ArtSource/Generated/Characters/RuntimeBackupPreRendered3DV7"

VOSS_ATLASES = (
    "VossWalk.atlas",
    "VossIdle.atlas",
    "VossSeatedIdle.atlas",
    "VossSeatedArms.atlas",
    "VossSeatTransitions.atlas",
)


def keyed(source_dir: Path, stem: str) -> Path:
    chroma = source_dir / f"{stem}_chroma_v08.png"
    rgba = source_dir / f"{stem}_rgba_v08.png"
    remove_green_screen(chroma, rgba)
    return rgba


def save_frame_v8(frame: Image.Image, atlas_name: str, filename: str, source_dir: Path) -> None:
    registered_dir = source_dir / "Registered_v08"
    registered_dir.mkdir(parents=True, exist_ok=True)
    atlas = ATLASES / atlas_name
    atlas.mkdir(parents=True, exist_ok=True)
    path = registered_dir / filename
    frame.save(path, optimize=True)
    shutil.copy2(path, atlas / filename)


def backup_v7_runtime() -> None:
    if BACKUP.exists():
        return
    BACKUP.mkdir(parents=True)
    for atlas_name in VOSS_ATLASES:
        source = ATLASES / atlas_name
        if not source.exists():
            continue
        destination = BACKUP / atlas_name
        destination.mkdir()
        for path in source.glob("*.png"):
            shutil.copy2(path, destination / path.name)
    ui = BACKUP / "UI"
    ui.mkdir(exist_ok=True)
    for rel in (
        "RainShadow Shared/Resources/Art/UI/Dialogue/dialogue_portrait_harlan_voss_v01.png",
        "RainShadow Shared/Resources/Art/UI/Inventory/voss_paperdoll_front_rgba_v01.png",
    ):
        path = ROOT / rel
        if path.exists():
            shutil.copy2(path, ui / path.name)


def process_voss_locomotion() -> None:
    for direction in v6.DIRECTIONS:
        rgba = keyed(DETECTIVE_SOURCE, f"voss_walk_{direction}_cycle")
        for phase, figure in enumerate(raster.crop_components(rgba, 8, 1)):
            save_frame_v8(
                raster.register(figure),
                "VossWalk.atlas",
                f"voss_walk_{direction}_{phase:02d}.png",
                DETECTIVE_SOURCE,
            )

    southwest_idle: list[Image.Image] = []
    for direction in v6.DIRECTIONS:
        rgba = keyed(DETECTIVE_SOURCE, f"voss_idle_{direction}_strip")
        for phase, figure in enumerate(raster.crop_components(rgba, 4, 1)):
            frame = raster.register(figure)
            if direction == "sw":
                southwest_idle.append(frame)
            save_frame_v8(
                frame,
                "VossIdle.atlas",
                f"voss_standing_idle_{direction}_{phase:02d}.png",
                DETECTIVE_SOURCE,
            )

    for phase, frame in enumerate(southwest_idle):
        save_frame_v8(
            v6.flipped(frame),
            "VossIdle.atlas",
            f"voss_standing_idle_se_{phase:02d}.png",
            DETECTIVE_SOURCE,
        )


def process_voss_desk_chain() -> None:
    rgba = keyed(DETECTIVE_SOURCE, "voss_seated_idle_strip")
    for index, figure in enumerate(raster.crop_components(rgba, 8, 1)):
        figure = v6.flipped(figure)
        save_frame_v8(
            raster.register(figure),
            "VossSeatedIdle.atlas",
            f"voss_seated_idle_se_{index:02d}.png",
            DETECTIVE_SOURCE,
        )
        save_frame_v8(
            raster.register(raster.arm_layer(figure), crop_to_alpha=False),
            "VossSeatedArms.atlas",
            f"voss_seated_arms_se_{index:02d}.png",
            DETECTIVE_SOURCE,
        )

    for stem, clip in (("voss_stand_up_sheet", "voss_stand_up_se"), ("voss_sit_down_sheet", "voss_sit_down_se")):
        rgba = keyed(DETECTIVE_SOURCE, stem)
        for index, figure in enumerate(raster.crop_components(rgba, 4, 3)):
            save_frame_v8(
                raster.register(v6.flipped(figure)),
                "VossSeatTransitions.atlas",
                f"{clip}_{index:02d}.png",
                DETECTIVE_SOURCE,
            )


def make_previews_v8() -> None:
    frame_size = raster.FRAME_SIZE
    specs = [
        (DETECTIVE_SOURCE, "preview_walk_v08.png", "VossWalk.atlas",
         [f"voss_walk_{d}_{i:02d}.png" for d in v6.DIRECTIONS for i in range(8)], 8),
        (DETECTIVE_SOURCE, "preview_idle_v08.png", "VossIdle.atlas",
         [f"voss_standing_idle_{d}_{i:02d}.png" for d in v6.DIRECTIONS for i in range(4)], 4),
        (DETECTIVE_SOURCE, "preview_seat_transitions_v08.png", "VossSeatTransitions.atlas",
         [f"voss_stand_up_se_{i:02d}.png" for i in range(12)]
         + [f"voss_sit_down_se_{i:02d}.png" for i in range(12)], 6),
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
        ROOT / "ArtSource/Generated/Characters/preview_characters_in_office_v08.png",
        optimize=True,
    )


def main() -> None:
    backup_v7_runtime()
    raster.pixelize_figure = pixelize_figure_v7
    process_voss_locomotion()
    process_voss_desk_chain()
    make_previews_v8()
    cells = 9 * 8 + 9 * 4 + 4 + 8 + 8 + 24
    print(
        f"Registered {cells} V8 Voss atlas cells (V7 crunch) from {DETECTIVE_SOURCE.name}; "
        f"V7 runtime backed up to {BACKUP.name}"
    )


if __name__ == "__main__":
    main()

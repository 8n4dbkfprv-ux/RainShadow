#!/usr/bin/env python3
"""Register the V6 BGEE-style Voss/March masters as the full-density runtime atlases.

V6 replaces every V4 character cell with new identities (Harlan Voss / Lila March)
at AssetManifest full animation density:

- Voss walk: 9 stored directions x 8 frames
- Voss standing idle: 9 directions x 4 frames (+ mirrored SE copies for the desk chain)
- Voss seated idle 8 + derived arm layer 8 + stand-up 12 + sit-down 12 (SE)
- Lila arrival SW 8 walk + 1 idle; departure NE 8

Masters are flat #00ff00 chroma sheets. Each figure is keyed, reduced to a
100 px native body, quantized to 96 colors, scaled 2x with nearest sampling,
and registered on a 512x512 canvas with the shared FOOT_Y pivot — the same
contract as V3/V4, which is what reintroduces the BGEE pixel-stepped edge.
"""

from pathlib import Path
import shutil

from PIL import Image, ImageDraw

import process_pre_rendered_characters_v3 as raster
from process_character_gait_v5 import remove_green_screen


ROOT = Path(__file__).resolve().parents[2]
DETECTIVE_SOURCE = ROOT / "ArtSource/Generated/Characters/Detective/PreRendered3DV6"
CLIENT_SOURCE = ROOT / "ArtSource/Generated/Characters/Client/PreRendered3DV6"
PAPERDOLL_SOURCE = ROOT / "ArtSource/Generated/Characters/Detective/Paperdoll"
PORTRAIT_SOURCE = ROOT / "ArtSource/Generated/UI/Dialogue"
ATLASES = ROOT / "RainShadow Shared/Resources/Art/Atlases"
DIALOGUE_UI = ROOT / "RainShadow Shared/Resources/Art/UI/Dialogue"
INVENTORY_UI = ROOT / "RainShadow Shared/Resources/Art/UI/Inventory"
BACKUP = ROOT / "ArtSource/Generated/Characters/RuntimeBackupPreRendered3DV4Final"

DIRECTIONS = ["s", "ssw", "sw", "wsw", "w", "wnw", "nw", "nnw", "n"]

OLD_ATLASES = (
    "DetectiveWalk.atlas",
    "DetectiveIdle.atlas",
    "DetectiveSeatedIdle.atlas",
    "DetectiveSeatedArms.atlas",
    "DetectiveStandUp.atlas",
    "ClientArrival.atlas",
)

NEW_ATLASES = (
    "VossWalk.atlas",
    "VossIdle.atlas",
    "VossSeatedIdle.atlas",
    "VossSeatedArms.atlas",
    "VossSeatTransitions.atlas",
    "LilaArrival.atlas",
)

OLD_UI_FILES = (
    DIALOGUE_UI / "dialogue_portrait_elias_vale_v01.png",
    DIALOGUE_UI / "dialogue_portrait_vivian_hart_v01.png",
    INVENTORY_UI / "det_paperdoll_front_rgba_v01.png",
    INVENTORY_UI / "det_paperdoll_front_rgba_v02.png",
)


def flipped(figure: Image.Image) -> Image.Image:
    return figure.transpose(Image.Transpose.FLIP_LEFT_RIGHT)


def keyed(source_dir: Path, stem: str) -> Path:
    """Key a chroma master to its RGBA twin, returning the RGBA path."""
    chroma = source_dir / f"{stem}_chroma_v06.png"
    rgba = source_dir / f"{stem}_rgba_v06.png"
    remove_green_screen(chroma, rgba)
    return rgba


def save_frame(frame: Image.Image, atlas_name: str, filename: str, source_dir: Path) -> None:
    registered_dir = source_dir / "Registered_v06"
    registered_dir.mkdir(parents=True, exist_ok=True)
    atlas = ATLASES / atlas_name
    atlas.mkdir(parents=True, exist_ok=True)
    path = registered_dir / filename
    frame.save(path, optimize=True)
    shutil.copy2(path, atlas / filename)


def backup_and_remove_old_runtime() -> None:
    if not BACKUP.exists():
        BACKUP.mkdir(parents=True)
        for atlas_name in OLD_ATLASES:
            source = ATLASES / atlas_name
            if not source.exists():
                continue
            destination = BACKUP / atlas_name
            destination.mkdir()
            for path in source.glob("*.png"):
                shutil.copy2(path, destination / path.name)
        ui_backup = BACKUP / "UI"
        ui_backup.mkdir()
        for path in OLD_UI_FILES:
            if path.exists():
                shutil.copy2(path, ui_backup / path.name)

    # Old V4 atlases (including Finder "* 2.png" duplicates) leave the bundle wholesale.
    for atlas_name in OLD_ATLASES:
        shutil.rmtree(ATLASES / atlas_name, ignore_errors=True)
    for atlas_name in NEW_ATLASES:
        shutil.rmtree(ATLASES / atlas_name, ignore_errors=True)
    for path in OLD_UI_FILES:
        path.unlink(missing_ok=True)


def process_voss_locomotion() -> None:
    for direction in DIRECTIONS:
        rgba = keyed(DETECTIVE_SOURCE, f"voss_walk_{direction}_cycle")
        for phase, figure in enumerate(raster.crop_components(rgba, 8, 1)):
            save_frame(
                raster.register(figure),
                "VossWalk.atlas",
                f"voss_walk_{direction}_{phase:02d}.png",
                DETECTIVE_SOURCE,
            )

    southwest_idle: list[Image.Image] = []
    for direction in DIRECTIONS:
        rgba = keyed(DETECTIVE_SOURCE, f"voss_idle_{direction}_strip")
        for phase, figure in enumerate(raster.crop_components(rgba, 4, 1)):
            frame = raster.register(figure)
            if direction == "sw":
                southwest_idle.append(frame)
            save_frame(
                frame,
                "VossIdle.atlas",
                f"voss_standing_idle_{direction}_{phase:02d}.png",
                DETECTIVE_SOURCE,
            )

    # The desk chain faces SE; stand-up lands on a stored SE idle exactly like V3/V4.
    for phase, frame in enumerate(southwest_idle):
        save_frame(
            flipped(frame),
            "VossIdle.atlas",
            f"voss_standing_idle_se_{phase:02d}.png",
            DETECTIVE_SOURCE,
        )


def process_voss_desk_chain() -> None:
    # Generated SE sheets face lower-left; flip to the runtime lower-right SE convention.
    rgba = keyed(DETECTIVE_SOURCE, "voss_seated_idle_strip")
    for index, figure in enumerate(raster.crop_components(rgba, 8, 1)):
        figure = flipped(figure)
        save_frame(
            raster.register(figure),
            "VossSeatedIdle.atlas",
            f"voss_seated_idle_se_{index:02d}.png",
            DETECTIVE_SOURCE,
        )
        save_frame(
            raster.register(raster.arm_layer(figure), crop_to_alpha=False),
            "VossSeatedArms.atlas",
            f"voss_seated_arms_se_{index:02d}.png",
            DETECTIVE_SOURCE,
        )

    for stem, clip in (("voss_stand_up_sheet", "voss_stand_up_se"), ("voss_sit_down_sheet", "voss_sit_down_se")):
        rgba = keyed(DETECTIVE_SOURCE, stem)
        for index, figure in enumerate(raster.crop_components(rgba, 4, 3)):
            save_frame(
                raster.register(flipped(figure)),
                "VossSeatTransitions.atlas",
                f"{clip}_{index:02d}.png",
                DETECTIVE_SOURCE,
            )


def process_lila() -> None:
    rgba = keyed(CLIENT_SOURCE, "lila_arrival_sw_strip")
    for index, figure in enumerate(raster.crop_components(rgba, 9, 1)):
        save_frame(
            raster.register(figure),
            "LilaArrival.atlas",
            f"lila_arrival_sw_{index:02d}.png",
            CLIENT_SOURCE,
        )
    rgba = keyed(CLIENT_SOURCE, "lila_departure_ne_strip")
    for index, figure in enumerate(raster.crop_components(rgba, 8, 1)):
        save_frame(
            raster.register(figure),
            "LilaArrival.atlas",
            f"lila_departure_ne_{index:02d}.png",
            CLIENT_SOURCE,
        )


def process_character_ui() -> None:
    """Portraits/paperdoll stay hand-readable: no nearest-pixelize gameplay pass."""
    for master, target in (
        ("dialogue_portrait_harlan_voss_v01_master.png", "dialogue_portrait_harlan_voss_v01.png"),
        ("dialogue_portrait_lila_march_v01_master.png", "dialogue_portrait_lila_march_v01.png"),
    ):
        portrait = Image.open(PORTRAIT_SOURCE / master).convert("RGB")
        portrait = portrait.resize((512, 512), Image.Resampling.LANCZOS)
        DIALOGUE_UI.mkdir(parents=True, exist_ok=True)
        portrait.save(DIALOGUE_UI / target, optimize=True)

    chroma = PAPERDOLL_SOURCE / "voss_paperdoll_front_chroma_v06.png"
    rgba_path = PAPERDOLL_SOURCE / "voss_paperdoll_front_rgba_v06.png"
    remove_green_screen(chroma, rgba_path)
    figure = Image.open(rgba_path).convert("RGBA")
    bbox = figure.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError("Paperdoll master has no opaque subject")
    figure = figure.crop(bbox)
    canvas_size = (1024, 1536)
    margin = 0.94
    scale = min(
        canvas_size[0] * margin / figure.width,
        canvas_size[1] * margin / figure.height,
    )
    resized = raster.premultiplied_resize(
        figure, (round(figure.width * scale), round(figure.height * scale))
    )
    canvas = Image.new("RGBA", canvas_size)
    canvas.alpha_composite(
        resized,
        ((canvas_size[0] - resized.width) // 2, (canvas_size[1] - resized.height) // 2),
    )
    INVENTORY_UI.mkdir(parents=True, exist_ok=True)
    canvas.save(INVENTORY_UI / "voss_paperdoll_front_rgba_v01.png", optimize=True)


def make_previews() -> None:
    frame_size = raster.FRAME_SIZE
    specs = [
        (DETECTIVE_SOURCE, "preview_walk_v06.png", "VossWalk.atlas",
         [f"voss_walk_{d}_{i:02d}.png" for d in DIRECTIONS for i in range(8)], 8),
        (DETECTIVE_SOURCE, "preview_idle_v06.png", "VossIdle.atlas",
         [f"voss_standing_idle_{d}_{i:02d}.png" for d in DIRECTIONS for i in range(4)], 4),
        (DETECTIVE_SOURCE, "preview_seated_v06.png", "VossSeatedIdle.atlas",
         [f"voss_seated_idle_se_{i:02d}.png" for i in range(8)], 8),
        (DETECTIVE_SOURCE, "preview_seat_transitions_v06.png", "VossSeatTransitions.atlas",
         [f"voss_stand_up_se_{i:02d}.png" for i in range(12)]
         + [f"voss_sit_down_se_{i:02d}.png" for i in range(12)], 6),
        (CLIENT_SOURCE, "preview_lila_v06.png", "LilaArrival.atlas",
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
        ROOT / "ArtSource/Generated/Characters/preview_characters_in_office_v06.png",
        optimize=True,
    )


def main() -> None:
    backup_and_remove_old_runtime()
    process_voss_locomotion()
    process_voss_desk_chain()
    process_lila()
    process_character_ui()
    make_previews()
    cells = 9 * 8 + 9 * 4 + 4 + 8 + 8 + 24 + 17
    print(f"Registered {cells} V6 BGEE-style Voss/March atlas cells plus portraits, paperdoll, and previews")


if __name__ == "__main__":
    main()

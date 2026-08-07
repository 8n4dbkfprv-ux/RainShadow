#!/usr/bin/env python3
"""V11 paperdoll-driven Voss + Lila wardrobe/hair refresh with V7 BGEE crunch.

Harlan Voss: PreRendered3DV11 masters locked to inventory paperdoll V11 identity
(bare-headed). Lila March: PreRendered3DV11 masters with chin-grazing blunt bob
and fitted 1940s emerald day dress.

Reuses V6 slicing/mirroring/registration and V7 pixelization (80px / 64 colors /
nearest → 200px). Portraits install via Lanczos (no nearest-pixelize). Paperdoll
is not reprocessed.
"""

from pathlib import Path
import shutil

import numpy as np
from PIL import Image, ImageDraw

import crunch as crunch_mod
import process_pre_rendered_characters_v3 as raster
import process_pre_rendered_characters_v6 as v6
from process_pre_rendered_characters_v7 import pixelize_figure_v7
from process_character_gait_v5 import remove_green_screen


ROOT = Path(__file__).resolve().parents[2]
DETECTIVE_SOURCE = ROOT / "ArtSource/Generated/Characters/Detective/PreRendered3DV11"
CLIENT_SOURCE = ROOT / "ArtSource/Generated/Characters/Client/PreRendered3DV11"
PORTRAIT_SOURCE = ROOT / "ArtSource/Generated/UI/Dialogue"
DIALOGUE_UI = ROOT / "RainShadow Shared/Resources/Art/UI/Dialogue"
ATLASES = ROOT / "RainShadow Shared/Resources/Art/Atlases"
BACKUP = ROOT / "ArtSource/Generated/Characters/RuntimeBackupPreRendered3DV11Prior"

VOSS_ATLASES = (
    "VossWalk.atlas",
    "VossIdle.atlas",
    "VossSeatedIdle.atlas",
    "VossSeatedArms.atlas",
    "VossSeatTransitions.atlas",
)
LILA_ATLAS = "LilaArrival.atlas"


def keyed(source_dir: Path, stem: str) -> Path:
    chroma = source_dir / f"{stem}_chroma_v11.png"
    rgba = source_dir / f"{stem}_rgba_v11.png"
    remove_green_screen(chroma, rgba)
    return rgba


def despill_lila(figure: Image.Image) -> Image.Image:
    """Kill chroma fringe and gently pull deep-emerald dress mid-tones."""
    pixels = np.asarray(figure.convert("RGBA")).copy()
    rgb = pixels[..., :3].astype(np.float32)
    red, green, blue = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    alpha = pixels[..., 3].astype(np.float32)

    pure = (alpha > 40) & (green > 150) & (green > red + 40) & (green > blue + 40)
    alpha[pure] = 0

    other = np.maximum(red, blue)
    dominance = green - other
    spill = (alpha > 4) & (dominance > 28) & (green > 90)
    green = np.where(spill, np.minimum(green, other * 1.08 + 8.0), green)

    dress = (
        (alpha > 80)
        & (green > 30)
        & (green < 160)
        & (green > red)
        & (green > blue)
        & ((green - red) > 14)
    )
    green = np.where(dress, green - np.minimum(green - red - 12.0, 6.0), green)

    pixels[..., 0] = np.clip(red, 0, 255).astype(np.uint8)
    pixels[..., 1] = np.clip(green, 0, 255).astype(np.uint8)
    pixels[..., 2] = np.clip(blue, 0, 255).astype(np.uint8)
    pixels[..., 3] = np.clip(alpha, 0, 255).astype(np.uint8)
    pixels[pixels[..., 3] < 4] = 0
    return Image.fromarray(pixels, "RGBA")


def save_frame_v11(frame: Image.Image, atlas_name: str, filename: str, source_dir: Path) -> None:
    # Palette last: see crunch.finalise.
    frame = crunch_mod.finalise(frame)
    registered_dir = source_dir / "Registered_v11"
    registered_dir.mkdir(parents=True, exist_ok=True)
    atlas = ATLASES / atlas_name
    atlas.mkdir(parents=True, exist_ok=True)
    path = registered_dir / filename
    frame.save(path, optimize=True)
    shutil.copy2(path, atlas / filename)


def backup_prior_runtime() -> None:
    if BACKUP.exists():
        return
    BACKUP.mkdir(parents=True)
    for atlas_name in (*VOSS_ATLASES, LILA_ATLAS):
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
        "RainShadow Shared/Resources/Art/UI/Dialogue/dialogue_portrait_lila_march_v02.png",
        "RainShadow Shared/Resources/Art/UI/Inventory/voss_paperdoll_front_rgba_v01.png",
    ):
        path = ROOT / rel
        if path.exists():
            shutil.copy2(path, ui / path.name)


def process_voss_locomotion() -> None:
    for direction in v6.DIRECTIONS:
        rgba = keyed(DETECTIVE_SOURCE, f"voss_walk_{direction}_cycle")
        for phase, figure in enumerate(raster.crop_components(rgba, 8, 1)):
            save_frame_v11(
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
            save_frame_v11(
                frame,
                "VossIdle.atlas",
                f"voss_standing_idle_{direction}_{phase:02d}.png",
                DETECTIVE_SOURCE,
            )

    for phase, frame in enumerate(southwest_idle):
        save_frame_v11(
            v6.flipped(frame),
            "VossIdle.atlas",
            f"voss_standing_idle_se_{phase:02d}.png",
            DETECTIVE_SOURCE,
        )


def process_voss_desk_chain() -> None:
    rgba = keyed(DETECTIVE_SOURCE, "voss_seated_idle_strip")
    for index, figure in enumerate(raster.crop_components(rgba, 8, 1)):
        figure = v6.flipped(figure)
        save_frame_v11(
            raster.register(figure),
            "VossSeatedIdle.atlas",
            f"voss_seated_idle_se_{index:02d}.png",
            DETECTIVE_SOURCE,
        )
        save_frame_v11(
            raster.register(raster.arm_layer(figure), crop_to_alpha=False),
            "VossSeatedArms.atlas",
            f"voss_seated_arms_se_{index:02d}.png",
            DETECTIVE_SOURCE,
        )

    for stem, clip in (
        ("voss_stand_up_sheet", "voss_stand_up_se"),
        ("voss_sit_down_sheet", "voss_sit_down_se"),
    ):
        rgba = keyed(DETECTIVE_SOURCE, stem)
        for index, figure in enumerate(raster.crop_components(rgba, 4, 3)):
            save_frame_v11(
                raster.register(v6.flipped(figure)),
                "VossSeatTransitions.atlas",
                f"{clip}_{index:02d}.png",
                DETECTIVE_SOURCE,
            )


def process_lila() -> None:
    rgba = keyed(CLIENT_SOURCE, "lila_arrival_sw_strip")
    figures = raster.crop_components(rgba, 9, 1)
    if len(figures) != 9:
        raise RuntimeError(f"Expected 9 arrival figures, found {len(figures)}")
    for index, figure in enumerate(figures):
        cleaned = despill_lila(figure)
        save_frame_v11(
            despill_lila(raster.register(cleaned)),
            LILA_ATLAS,
            f"lila_arrival_sw_{index:02d}.png",
            CLIENT_SOURCE,
        )

    rgba = keyed(CLIENT_SOURCE, "lila_departure_ne_strip")
    figures = raster.crop_components(rgba, 8, 1)
    if len(figures) != 8:
        raise RuntimeError(f"Expected 8 NE departure figures, found {len(figures)}")
    ne_frames: list[Image.Image] = []
    for index, figure in enumerate(figures):
        frame = despill_lila(raster.register(despill_lila(figure)))
        ne_frames.append(frame)
        save_frame_v11(
            frame,
            LILA_ATLAS,
            f"lila_departure_ne_{index:02d}.png",
            CLIENT_SOURCE,
        )

    for index, frame in enumerate(ne_frames):
        save_frame_v11(
            frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT),
            LILA_ATLAS,
            f"lila_departure_nw_{index:02d}.png",
            CLIENT_SOURCE,
        )


def install_portrait(master_names: tuple[str, ...], runtime_name: str) -> None:
    master = None
    for name in master_names:
        candidate = PORTRAIT_SOURCE / name
        if candidate.exists():
            master = candidate
            break
    if master is None:
        raise FileNotFoundError(f"Missing portrait master; tried {master_names}")
    portrait = Image.open(master).convert("RGB")
    portrait = portrait.resize((512, 512), Image.Resampling.LANCZOS)
    DIALOGUE_UI.mkdir(parents=True, exist_ok=True)
    portrait.save(DIALOGUE_UI / runtime_name, optimize=True)


def process_portraits() -> None:
    install_portrait(
        ("dialogue_portrait_harlan_voss_v01_master.png",),
        "dialogue_portrait_harlan_voss_v01.png",
    )
    install_portrait(
        (
            "dialogue_portrait_lila_march_v02_master.png",
            "dialogue_portrait_lila_march_v01_master.png",
        ),
        "dialogue_portrait_lila_march_v02.png",
    )


def make_previews_v11() -> None:
    frame_size = raster.FRAME_SIZE
    specs = [
        (
            DETECTIVE_SOURCE,
            "preview_walk_v11.png",
            "VossWalk.atlas",
            [f"voss_walk_{d}_{i:02d}.png" for d in v6.DIRECTIONS for i in range(8)],
            8,
        ),
        (
            DETECTIVE_SOURCE,
            "preview_idle_v11.png",
            "VossIdle.atlas",
            [f"voss_standing_idle_{d}_{i:02d}.png" for d in v6.DIRECTIONS for i in range(4)],
            4,
        ),
        (
            DETECTIVE_SOURCE,
            "preview_seat_transitions_v11.png",
            "VossSeatTransitions.atlas",
            [f"voss_stand_up_se_{i:02d}.png" for i in range(12)]
            + [f"voss_sit_down_se_{i:02d}.png" for i in range(12)],
            6,
        ),
    ]
    for source_dir, filename, atlas_name, names, columns in specs:
        rows = (len(names) + columns - 1) // columns
        preview = Image.new("RGBA", (frame_size * columns, frame_size * rows), (24, 28, 31, 255))
        for index, name in enumerate(names):
            frame = Image.open(ATLASES / atlas_name / name).convert("RGBA")
            preview.alpha_composite(
                frame,
                ((index % columns) * frame_size, (index // columns) * frame_size),
            )
        preview.save(source_dir / filename, optimize=True)

    lila_names = (
        [f"lila_arrival_sw_{i:02d}.png" for i in range(9)]
        + [f"lila_departure_ne_{i:02d}.png" for i in range(8)]
        + [f"lila_departure_nw_{i:02d}.png" for i in range(8)]
    )
    columns = 9
    rows = (len(lila_names) + columns - 1) // columns
    preview = Image.new("RGBA", (frame_size * columns, frame_size * rows), (24, 28, 31, 255))
    for index, name in enumerate(lila_names):
        frame = Image.open(ATLASES / LILA_ATLAS / name).convert("RGBA")
        preview.alpha_composite(
            frame,
            ((index % columns) * frame_size, (index // columns) * frame_size),
        )
    preview.save(CLIENT_SOURCE / "preview_lila_v11.png", optimize=True)

    office = Image.open(ROOT / "ArtSource/References/UI/Map/office_runtime_clean_v02.png").convert("RGBA")
    actors = [
        (790, 800, ATLASES / "VossIdle.atlas/voss_standing_idle_se_00.png", 54, 20),
        (1450, 800, ATLASES / LILA_ATLAS / "lila_arrival_sw_08.png", 44, 15),
    ]
    shadow_layer = Image.new("RGBA", office.size)
    shadow_draw = ImageDraw.Draw(shadow_layer)
    for root_x, root_y, _, shadow_w, shadow_h in actors:
        shadow_draw.ellipse(
            (
                root_x - shadow_w // 2,
                root_y - shadow_h // 2,
                root_x + shadow_w // 2,
                root_y + shadow_h // 2,
            ),
            fill=(0, 0, 0, 88),
        )
    office.alpha_composite(shadow_layer)
    for root_x, root_y, path, _, _ in actors:
        frame = Image.open(path).convert("RGBA").resize((256, 256), Image.Resampling.NEAREST)
        office.alpha_composite(frame, (root_x - 128, root_y - 217))
    office.convert("RGB").save(
        ROOT / "ArtSource/Generated/Characters/preview_characters_in_office_v11.png",
        optimize=True,
    )


def main() -> None:
    for path in (DETECTIVE_SOURCE, CLIENT_SOURCE):
        if not path.exists():
            raise FileNotFoundError(
                f"Missing V11 master directory {path}. Generate chroma sheets first "
                f"(see ArtSource/Prompts/character_prerendered_3d_v11.md)."
            )

    backup_prior_runtime()
    raster.pixelize_figure = pixelize_figure_v7
    process_voss_locomotion()
    process_voss_desk_chain()
    process_lila()
    process_portraits()
    make_previews_v11()
    voss_cells = 9 * 8 + 9 * 4 + 4 + 8 + 8 + 24
    lila_cells = 9 + 8 + 8
    print(
        f"Registered {voss_cells} Voss + {lila_cells} Lila V11 atlas cells "
        f"(V7 crunch) from PreRendered3DV11; prior runtime backed up to {BACKUP.name}"
    )


if __name__ == "__main__":
    main()

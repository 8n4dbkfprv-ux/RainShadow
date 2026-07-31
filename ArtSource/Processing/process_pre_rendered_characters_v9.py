#!/usr/bin/env python3
"""V9 Lila March identity refresh: process PreRendered3DV9 masters with V7 crunch.

Reuses V6 slicing/registration and V7 pixelization (80px / 64 colors / nearest →
200px). Harlan Voss is not regenerated. Installs the hand-readable dialogue
portrait (Lanczos → 512×512; no nearest-pixelize).

NW departure cells are horizontal flips of the approved NE cells (no re-crunch)
so face-peek and emerald coat stay on the structural test contract.
"""

from pathlib import Path
import shutil

import numpy as np
from PIL import Image, ImageDraw

import process_pre_rendered_characters_v3 as raster
from process_pre_rendered_characters_v7 import pixelize_figure_v7
from process_character_gait_v5 import remove_green_screen


ROOT = Path(__file__).resolve().parents[2]
CLIENT_SOURCE = ROOT / "ArtSource/Generated/Characters/Client/PreRendered3DV9"
PORTRAIT_SOURCE = ROOT / "ArtSource/Generated/UI/Dialogue"
DIALOGUE_UI = ROOT / "RainShadow Shared/Resources/Art/UI/Dialogue"
ATLASES = ROOT / "RainShadow Shared/Resources/Art/Atlases"
BACKUP = ROOT / "ArtSource/Generated/Characters/RuntimeBackupLilaPreRendered3DV7"

LILA_ATLAS = "LilaArrival.atlas"


def keyed(source_dir: Path, stem: str) -> Path:
    chroma = source_dir / f"{stem}_chroma_v09.png"
    rgba = source_dir / f"{stem}_rgba_v09.png"
    remove_green_screen(chroma, rgba)
    return rgba


def despill_figure(figure: Image.Image) -> Image.Image:
    """Kill leftover chroma fringe and pull coat G−R toward the V7 emerald band."""
    pixels = np.asarray(figure.convert("RGBA")).copy()
    rgb = pixels[..., :3].astype(np.float32)
    red, green, blue = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    alpha = pixels[..., 3].astype(np.float32)

    # Near-pure #00ff00 leftovers → transparent.
    pure = (alpha > 40) & (green > 150) & (green > red + 40) & (green > blue + 40)
    alpha[pure] = 0

    # Soft fringe despill where green still dominates the other channels heavily.
    other = np.maximum(red, blue)
    dominance = green - other
    spill = (alpha > 4) & (dominance > 28) & (green > 90)
    green = np.where(spill, np.minimum(green, other * 1.08 + 8.0), green)

    # Mild coat pull: deep emerald mid-tones with G−R still high after keying.
    coat = (
        (alpha > 80)
        & (green > 30)
        & (green < 160)
        & (green > red)
        & (green > blue)
        & ((green - red) > 14)
    )
    green = np.where(coat, green - np.minimum(green - red - 12.0, 6.0), green)

    pixels[..., 0] = np.clip(red, 0, 255).astype(np.uint8)
    pixels[..., 1] = np.clip(green, 0, 255).astype(np.uint8)
    pixels[..., 2] = np.clip(blue, 0, 255).astype(np.uint8)
    pixels[..., 3] = np.clip(alpha, 0, 255).astype(np.uint8)
    pixels[pixels[..., 3] < 4] = 0
    return Image.fromarray(pixels, "RGBA")


def save_frame_v9(frame: Image.Image, atlas_name: str, filename: str, source_dir: Path) -> None:
    registered_dir = source_dir / "Registered_v09"
    registered_dir.mkdir(parents=True, exist_ok=True)
    atlas = ATLASES / atlas_name
    atlas.mkdir(parents=True, exist_ok=True)
    path = registered_dir / filename
    frame.save(path, optimize=True)
    shutil.copy2(path, atlas / filename)


def backup_lila_runtime() -> None:
    if BACKUP.exists():
        return
    BACKUP.mkdir(parents=True)
    source = ATLASES / LILA_ATLAS
    if source.exists():
        destination = BACKUP / LILA_ATLAS
        destination.mkdir()
        for path in source.glob("*.png"):
            shutil.copy2(path, destination / path.name)
    ui = BACKUP / "UI"
    ui.mkdir(exist_ok=True)
    portrait = DIALOGUE_UI / "dialogue_portrait_lila_march_v01.png"
    if portrait.exists():
        shutil.copy2(portrait, ui / portrait.name)


def process_lila() -> None:
    rgba = keyed(CLIENT_SOURCE, "lila_arrival_sw_strip")
    figures = raster.crop_components(rgba, 9, 1)
    if len(figures) != 9:
        raise RuntimeError(f"Expected 9 arrival figures, found {len(figures)}")
    for index, figure in enumerate(figures):
        save_frame_v9(
            despill_figure(raster.register(despill_figure(figure))),
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
        frame = despill_figure(raster.register(despill_figure(figure)))
        ne_frames.append(frame)
        save_frame_v9(
            frame,
            LILA_ATLAS,
            f"lila_departure_ne_{index:02d}.png",
            CLIENT_SOURCE,
        )

    # NW rear is the horizontal flip of approved NE cells: face peek moves to
    # viewer-left, and anatomical-left handbag lands screen-right (correct for NW).
    # Avoids generator NW/NE collapse and keeps coat emerald identical (no re-crunch).
    for index, frame in enumerate(ne_frames):
        save_frame_v9(
            frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT),
            LILA_ATLAS,
            f"lila_departure_nw_{index:02d}.png",
            CLIENT_SOURCE,
        )


def process_lila_portrait() -> None:
    master = PORTRAIT_SOURCE / "dialogue_portrait_lila_march_v01_master.png"
    if not master.exists():
        raise FileNotFoundError(master)
    portrait = Image.open(master).convert("RGB")
    portrait = portrait.resize((512, 512), Image.Resampling.LANCZOS)
    DIALOGUE_UI.mkdir(parents=True, exist_ok=True)
    portrait.save(DIALOGUE_UI / "dialogue_portrait_lila_march_v01.png", optimize=True)


def make_previews_v9() -> None:
    frame_size = raster.FRAME_SIZE
    names = (
        [f"lila_arrival_sw_{i:02d}.png" for i in range(9)]
        + [f"lila_departure_ne_{i:02d}.png" for i in range(8)]
        + [f"lila_departure_nw_{i:02d}.png" for i in range(8)]
    )
    columns = 9
    rows = (len(names) + columns - 1) // columns
    preview = Image.new("RGBA", (frame_size * columns, frame_size * rows), (24, 28, 31, 255))
    atlas = ATLASES / LILA_ATLAS
    for index, name in enumerate(names):
        frame = Image.open(atlas / name).convert("RGBA")
        preview.alpha_composite(
            frame,
            ((index % columns) * frame_size, (index // columns) * frame_size),
        )
    out = CLIENT_SOURCE / "preview_lila_v09.png"
    preview.save(out, optimize=True)

    office = Image.open(ROOT / "ArtSource/References/UI/Map/office_runtime_clean_v02.png").convert("RGBA")
    actors = [
        (790, 800, ATLASES / "VossIdle.atlas/voss_standing_idle_se_00.png", 54, 20),
        (1450, 800, atlas / "lila_arrival_sw_08.png", 44, 15),
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
        ROOT / "ArtSource/Generated/Characters/preview_characters_in_office_v09.png",
        optimize=True,
    )


def main() -> None:
    backup_lila_runtime()
    raster.pixelize_figure = pixelize_figure_v7
    process_lila()
    process_lila_portrait()
    make_previews_v9()
    cells = 9 + 8 + 8
    print(
        f"Registered {cells} V9 Lila atlas cells (V7 crunch) from {CLIENT_SOURCE.name}; "
        f"portrait installed; prior Lila runtime backed up to {BACKUP.name}"
    )


if __name__ == "__main__":
    main()

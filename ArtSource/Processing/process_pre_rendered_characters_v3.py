#!/usr/bin/env python3
"""Register V3 low-poly renders as lightly pixelated runtime atlases."""

from pathlib import Path
import shutil

import numpy as np
from PIL import Image, ImageDraw

from process_pre_rendered_characters_v2 import (
    arm_layer,
    crop_components,
    crop_grid,
    premultiplied_resize,
)


ROOT = Path(__file__).resolve().parents[2]
DETECTIVE_SOURCE = ROOT / "ArtSource/Generated/Characters/Detective/PreRendered3DV3"
CLIENT_SOURCE = ROOT / "ArtSource/Generated/Characters/Client/PreRendered3DV3"
ATLASES = ROOT / "RainShadow Shared/Resources/Art/Atlases"
BACKUP = ROOT / "ArtSource/Generated/Characters/RuntimeBackupPreRendered3DV3"

FRAME_SIZE = 512
NATIVE_BODY_HEIGHT = 100
TEXTURE_SCALE = 2
BODY_HEIGHT = NATIVE_BODY_HEIGHT * TEXTURE_SCALE
FOOT_Y = 434
PALETTE_COLORS = 96


def pixelize_figure(figure: Image.Image, crop_to_alpha: bool = True) -> Image.Image:
    """Build the final sprite from a small native raster, not a pixel-art filter."""
    pixels = np.asarray(figure.convert("RGBA")).copy()
    pixels[pixels[..., 3] < 16] = 0
    figure = Image.fromarray(pixels, "RGBA")
    if crop_to_alpha:
        bbox = figure.getchannel("A").getbbox()
        if bbox is None:
            raise RuntimeError("Generated figure has no opaque subject")
        figure = figure.crop(bbox)
    native_width = max(1, round(figure.width * NATIVE_BODY_HEIGHT / figure.height))
    native = premultiplied_resize(figure, (native_width, NATIVE_BODY_HEIGHT))
    alpha = native.getchannel("A")
    limited_rgb = native.convert("RGB").quantize(
        colors=PALETTE_COLORS,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    ).convert("RGB")
    native = Image.merge("RGBA", (*limited_rgb.split(), alpha))
    return native.resize(
        (native_width * TEXTURE_SCALE, BODY_HEIGHT), Image.Resampling.NEAREST
    )


def lock_atlas_canvas(canvas: Image.Image) -> Image.Image:
    """Near-invisible corner sentinels so Xcode .atlas trim keeps the 512 canvas."""
    for x, y in (
        (0, 0),
        (FRAME_SIZE - 1, 0),
        (0, FRAME_SIZE - 1),
        (FRAME_SIZE - 1, FRAME_SIZE - 1),
    ):
        canvas.putpixel((x, y), (0, 0, 0, 1))
    return canvas


def register(figure: Image.Image, crop_to_alpha: bool = True) -> Image.Image:
    figure = pixelize_figure(figure, crop_to_alpha=crop_to_alpha)
    canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE))
    canvas.alpha_composite(figure, ((FRAME_SIZE - figure.width) // 2, FOOT_Y - BODY_HEIGHT))
    return lock_atlas_canvas(canvas)


def save_frame(frame: Image.Image, atlas_name: str, filename: str, source_dir: Path) -> None:
    registered_dir = source_dir / "Registered_v03"
    registered_dir.mkdir(parents=True, exist_ok=True)
    atlas = ATLASES / atlas_name
    atlas.mkdir(parents=True, exist_ok=True)
    path = registered_dir / filename
    frame.save(path, optimize=True)
    shutil.copy2(path, atlas / filename)


def backup_runtime() -> None:
    if BACKUP.exists():
        return
    BACKUP.mkdir(parents=True)
    for atlas_name in (
        "DetectiveWalk.atlas",
        "DetectiveIdle.atlas",
        "DetectiveSeatedIdle.atlas",
        "DetectiveSeatedArms.atlas",
        "DetectiveStandUp.atlas",
        "ClientArrival.atlas",
    ):
        source = ATLASES / atlas_name
        destination = BACKUP / atlas_name
        destination.mkdir()
        for path in source.glob("*.png"):
            shutil.copy2(path, destination / path.name)


def process_detective() -> None:
    directions = ["s", "sw", "w", "nw", "n"]
    walk = crop_components(DETECTIVE_SOURCE / "det_walk_5dir_4frame_rgba_v03.png", 4, 5)
    for direction_index, direction in enumerate(directions):
        for phase in range(4):
            save_frame(
                register(walk[direction_index * 4 + phase]),
                "DetectiveWalk.atlas",
                f"det_walk_{direction}_{phase:02d}.png",
                DETECTIVE_SOURCE,
            )

    idle = crop_grid(DETECTIVE_SOURCE / "det_standing_idle_5dir_rgba_v03.png", 5, 1)
    registered_idle: dict[str, Image.Image] = {}
    for direction, figure in zip(directions, idle, strict=True):
        frame = register(figure)
        registered_idle[direction] = frame
        save_frame(
            frame,
            "DetectiveIdle.atlas",
            f"det_standing_idle_{direction}_00.png",
            DETECTIVE_SOURCE,
        )
    save_frame(
        registered_idle["sw"].transpose(Image.Transpose.FLIP_LEFT_RIGHT),
        "DetectiveIdle.atlas",
        "det_standing_idle_se_00.png",
        DETECTIVE_SOURCE,
    )

    seated = crop_components(DETECTIVE_SOURCE / "det_seated_idle_strip_rgba_v03.png", 4, 1)
    for index, figure in enumerate(seated):
        save_frame(
            register(figure),
            "DetectiveSeatedIdle.atlas",
            f"det_seated_idle_se_{index:02d}.png",
            DETECTIVE_SOURCE,
        )
        save_frame(
            register(arm_layer(figure), crop_to_alpha=False),
            "DetectiveSeatedArms.atlas",
            f"det_seated_arms_se_{index:02d}.png",
            DETECTIVE_SOURCE,
        )

    stand_up = crop_components(DETECTIVE_SOURCE / "det_stand_up_sheet_rgba_v03.png", 4, 3)
    for index, figure in enumerate(stand_up):
        save_frame(
            register(figure),
            "DetectiveStandUp.atlas",
            f"det_stand_up_se_{index:02d}.png",
            DETECTIVE_SOURCE,
        )


def process_client() -> None:
    arrival = crop_grid(CLIENT_SOURCE / "client_arrival_sw_strip_rgba_v03.png", 5, 1)
    for index, figure in enumerate(arrival):
        save_frame(
            register(figure),
            "ClientArrival.atlas",
            f"client_arrival_sw_{index:02d}.png",
            CLIENT_SOURCE,
        )
    departure = crop_grid(CLIENT_SOURCE / "client_departure_ne_strip_rgba_v03.png", 4, 1)
    for index, figure in enumerate(departure):
        save_frame(
            register(figure),
            "ClientArrival.atlas",
            f"client_departure_ne_{index:02d}.png",
            CLIENT_SOURCE,
        )


def make_previews() -> None:
    specs = [
        (DETECTIVE_SOURCE, "preview_walk_v03.png", "DetectiveWalk.atlas", [f"det_walk_{d}_{i:02d}.png" for d in ("s", "sw", "w", "nw", "n") for i in range(4)], 4),
        (DETECTIVE_SOURCE, "preview_idle_v03.png", "DetectiveIdle.atlas", [f"det_standing_idle_{d}_00.png" for d in ("s", "sw", "w", "nw", "n")], 5),
        (DETECTIVE_SOURCE, "preview_seated_v03.png", "DetectiveSeatedIdle.atlas", [f"det_seated_idle_se_{i:02d}.png" for i in range(4)], 4),
        (DETECTIVE_SOURCE, "preview_stand_up_v03.png", "DetectiveStandUp.atlas", [f"det_stand_up_se_{i:02d}.png" for i in range(12)], 6),
        (CLIENT_SOURCE, "preview_client_v03.png", "ClientArrival.atlas", [f"client_arrival_sw_{i:02d}.png" for i in range(5)] + [f"client_departure_ne_{i:02d}.png" for i in range(4)], 5),
    ]
    for source_dir, filename, atlas_name, names, columns in specs:
        rows = (len(names) + columns - 1) // columns
        preview = Image.new("RGBA", (FRAME_SIZE * columns, FRAME_SIZE * rows), (24, 28, 31, 255))
        for index, name in enumerate(names):
            frame = Image.open(ATLASES / atlas_name / name).convert("RGBA")
            preview.alpha_composite(frame, ((index % columns) * FRAME_SIZE, (index // columns) * FRAME_SIZE))
        preview.save(source_dir / filename, optimize=True)

    office = Image.open(ROOT / "ArtSource/References/UI/Map/office_runtime_clean_v02.png").convert("RGBA")
    actors = [
        (790, 800, ATLASES / "DetectiveIdle.atlas/det_standing_idle_se_00.png", 54, 20),
        (1450, 800, ATLASES / "ClientArrival.atlas/client_arrival_sw_04.png", 44, 15),
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
        ROOT / "ArtSource/Generated/Characters/preview_characters_in_office_v03.png",
        optimize=True,
    )


def main() -> None:
    backup_runtime()
    process_detective()
    process_client()
    make_previews()
    print("Registered 55 lightly pixelated V3 character atlas cells and previews")


if __name__ == "__main__":
    main()

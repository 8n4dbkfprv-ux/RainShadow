#!/usr/bin/env python3
"""Register V4 crude 1998-era 3D renders as lightly rasterized atlases."""

from pathlib import Path
import shutil

from PIL import Image, ImageDraw

import process_pre_rendered_characters_v3 as base


ROOT = Path(__file__).resolve().parents[2]
DETECTIVE_SOURCE = ROOT / "ArtSource/Generated/Characters/Detective/PreRendered3DV4"
CLIENT_SOURCE = ROOT / "ArtSource/Generated/Characters/Client/PreRendered3DV4"
ATLASES = ROOT / "RainShadow Shared/Resources/Art/Atlases"
BACKUP = ROOT / "ArtSource/Generated/Characters/RuntimeBackupPreRendered3DV4"


def save_frame(frame: Image.Image, atlas_name: str, filename: str, source_dir: Path) -> None:
    registered_dir = source_dir / "Registered_v04"
    registered_dir.mkdir(parents=True, exist_ok=True)
    atlas = ATLASES / atlas_name
    atlas.mkdir(parents=True, exist_ok=True)
    path = registered_dir / filename
    frame.save(path, optimize=True)
    shutil.copy2(path, atlas / filename)


def configure_base() -> None:
    """Reuse the validated V3 slicer while pointing it at the V4 masters."""
    base.DETECTIVE_SOURCE = DETECTIVE_SOURCE
    base.CLIENT_SOURCE = CLIENT_SOURCE
    base.ATLASES = ATLASES
    base.BACKUP = BACKUP
    base.save_frame = save_frame


def process_detective() -> None:
    directions = ["s", "sw", "w", "nw", "n"]
    walk = base.crop_components(DETECTIVE_SOURCE / "det_walk_5dir_4frame_rgba_v04.png", 4, 5)
    for direction_index, direction in enumerate(directions):
        for phase in range(4):
            save_frame(
                base.register(walk[direction_index * 4 + phase]),
                "DetectiveWalk.atlas",
                f"det_walk_{direction}_{phase:02d}.png",
                DETECTIVE_SOURCE,
            )

    idle = base.crop_grid(DETECTIVE_SOURCE / "det_standing_idle_5dir_rgba_v04.png", 5, 1)
    registered_idle: dict[str, Image.Image] = {}
    for direction, figure in zip(directions, idle, strict=True):
        frame = base.register(figure)
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

    seated = base.crop_components(DETECTIVE_SOURCE / "det_seated_idle_strip_rgba_v04.png", 4, 1)
    for index, figure in enumerate(seated):
        save_frame(
            base.register(figure),
            "DetectiveSeatedIdle.atlas",
            f"det_seated_idle_se_{index:02d}.png",
            DETECTIVE_SOURCE,
        )
        save_frame(
            base.register(base.arm_layer(figure), crop_to_alpha=False),
            "DetectiveSeatedArms.atlas",
            f"det_seated_arms_se_{index:02d}.png",
            DETECTIVE_SOURCE,
        )

    stand_up = base.crop_components(DETECTIVE_SOURCE / "det_stand_up_sheet_rgba_v04.png", 4, 3)
    for index, figure in enumerate(stand_up):
        save_frame(
            base.register(figure),
            "DetectiveStandUp.atlas",
            f"det_stand_up_se_{index:02d}.png",
            DETECTIVE_SOURCE,
        )


def process_client() -> None:
    arrival = base.crop_grid(CLIENT_SOURCE / "client_arrival_sw_strip_rgba_v04.png", 5, 1)
    for index, figure in enumerate(arrival):
        save_frame(
            base.register(figure),
            "ClientArrival.atlas",
            f"client_arrival_sw_{index:02d}.png",
            CLIENT_SOURCE,
        )
    departure = base.crop_grid(CLIENT_SOURCE / "client_departure_ne_strip_rgba_v04.png", 4, 1)
    for index, figure in enumerate(departure):
        save_frame(
            base.register(figure),
            "ClientArrival.atlas",
            f"client_departure_ne_{index:02d}.png",
            CLIENT_SOURCE,
        )


def make_previews() -> None:
    specs = [
        (DETECTIVE_SOURCE, "preview_walk_v04.png", "DetectiveWalk.atlas", [f"det_walk_{d}_{i:02d}.png" for d in ("s", "sw", "w", "nw", "n") for i in range(4)], 4),
        (DETECTIVE_SOURCE, "preview_idle_v04.png", "DetectiveIdle.atlas", [f"det_standing_idle_{d}_00.png" for d in ("s", "sw", "w", "nw", "n")], 5),
        (DETECTIVE_SOURCE, "preview_seated_v04.png", "DetectiveSeatedIdle.atlas", [f"det_seated_idle_se_{i:02d}.png" for i in range(4)], 4),
        (DETECTIVE_SOURCE, "preview_stand_up_v04.png", "DetectiveStandUp.atlas", [f"det_stand_up_se_{i:02d}.png" for i in range(12)], 6),
        (CLIENT_SOURCE, "preview_client_v04.png", "ClientArrival.atlas", [f"client_arrival_sw_{i:02d}.png" for i in range(5)] + [f"client_departure_ne_{i:02d}.png" for i in range(4)], 5),
    ]
    for source_dir, filename, atlas_name, names, columns in specs:
        rows = (len(names) + columns - 1) // columns
        preview = Image.new("RGBA", (base.FRAME_SIZE * columns, base.FRAME_SIZE * rows), (24, 28, 31, 255))
        for index, name in enumerate(names):
            frame = Image.open(ATLASES / atlas_name / name).convert("RGBA")
            preview.alpha_composite(frame, ((index % columns) * base.FRAME_SIZE, (index // columns) * base.FRAME_SIZE))
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
        ROOT / "ArtSource/Generated/Characters/preview_characters_in_office_v04.png",
        optimize=True,
    )


def main() -> None:
    configure_base()
    base.backup_runtime()
    process_detective()
    process_client()
    make_previews()
    print("Registered 55 crude pre-rendered V4 character atlas cells and previews")


if __name__ == "__main__":
    main()

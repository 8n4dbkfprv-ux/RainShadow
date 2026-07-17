#!/usr/bin/env python3
"""Build Vivian's defect-corrected northeast departure cycle."""

from pathlib import Path

from PIL import Image, ImageDraw

from process_client_departure_v1 import (
    FOOT_PIVOT_Y,
    FRAME_SIZE,
    ROOT,
    align_upper_bodies,
    alpha_bbox,
    register_pose,
)


V1_SOURCE_DIR = ROOT / "ArtSource/Generated/Characters/Client/DepartureNEV1"
V2_SOURCE_DIR = ROOT / "ArtSource/Generated/Characters/Client/DepartureNEV2"
SOURCE_DIR = ROOT / "ArtSource/Generated/Characters/Client/DepartureNEV3"
MASTER_DIR = SOURCE_DIR / "Registered_v03"
RUNTIME_DIR = ROOT / "RainShadow Shared/Resources/Art/Atlases/ClientArrival.atlas"
PREVIEW = SOURCE_DIR / "preview_client_departure_ne_v03_registered.png"
ANIMATED_PREVIEW = SOURCE_DIR / "preview_client_departure_ne_v03.gif"


def load_pose(path: Path) -> Image.Image:
    pose = Image.open(path).convert("RGBA")
    alpha_bbox(pose)
    return pose


def main() -> None:
    poses = [
        load_pose(V1_SOURCE_DIR / "client_departure_ne_contact_a_rgba_v01.png"),
        load_pose(V1_SOURCE_DIR / "client_departure_ne_pass_a_rgba_v01.png"),
        load_pose(SOURCE_DIR / "client_departure_ne_contact_b_rgba_v03.png"),
        load_pose(V2_SOURCE_DIR / "client_departure_ne_pass_b_rgba_v02.png"),
    ]
    frames = align_upper_bodies([register_pose(pose) for pose in poses])

    MASTER_DIR.mkdir(parents=True, exist_ok=True)
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    for index, frame in enumerate(frames):
        name = f"client_departure_ne_{index:02d}.png"
        frame.save(MASTER_DIR / name, optimize=True)
        frame.save(RUNTIME_DIR / name, optimize=True)

    preview = Image.new(
        "RGBA",
        (FRAME_SIZE * len(frames), FRAME_SIZE),
        (20, 24, 29, 255),
    )
    draw = ImageDraw.Draw(preview)
    for index, frame in enumerate(frames):
        x = index * FRAME_SIZE
        preview.alpha_composite(frame, (x, 0))
        draw.line(
            (x, FOOT_PIVOT_Y, x + FRAME_SIZE - 1, FOOT_PIVOT_Y),
            fill=(170, 54, 54, 255),
            width=1,
        )
    preview.save(PREVIEW, optimize=True)

    animation: list[Image.Image] = []
    for frame in frames:
        canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (20, 24, 29, 255))
        canvas.alpha_composite(frame)
        animation.append(
            canvas.resize((512, 512), Image.Resampling.NEAREST).convert("RGB")
        )
    animation[0].save(
        ANIMATED_PREVIEW,
        save_all=True,
        append_images=animation[1:],
        duration=150,
        loop=0,
        optimize=False,
    )


if __name__ == "__main__":
    main()

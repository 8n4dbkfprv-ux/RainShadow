#!/usr/bin/env python3
"""Register the five generated client-arrival poses to RainShadow actor frames."""

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "ArtSource/Generated/Characters/Client/ArrivalV1/client_arrival_sw_sheet_rgba_v01.png"
MASTER_DIR = ROOT / "ArtSource/Generated/Characters/Client/ArrivalV1/Registered_v01"
RUNTIME_DIR = ROOT / "RainShadow Shared/Resources/Art/Atlases/ClientArrival.atlas"
PREVIEW = ROOT / "ArtSource/Generated/Characters/Client/ArrivalV1/preview_client_arrival_v01_registered.png"

FRAME_SIZE = 256
POSE_COUNT = 5
BODY_HEIGHT = 100
FOOT_PIVOT_Y = 217
ALPHA_CROP_THRESHOLD = 12


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = image.getchannel("A").point(
        lambda value: 255 if value > ALPHA_CROP_THRESHOLD else 0
    )
    bbox = alpha.getbbox()
    if bbox is None:
        raise RuntimeError("Generated pose contains no opaque pixels")
    return bbox


def register_pose(pose: Image.Image) -> Image.Image:
    subject = pose.crop(alpha_bbox(pose))
    scale = BODY_HEIGHT / subject.height
    width = max(1, round(subject.width * scale))
    subject = subject.resize((width, BODY_HEIGHT), Image.Resampling.LANCZOS)

    frame = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    x = (FRAME_SIZE - subject.width) // 2
    y = FOOT_PIVOT_Y - subject.height
    frame.alpha_composite(subject, (x, y))
    return frame


def main() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    MASTER_DIR.mkdir(parents=True, exist_ok=True)
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)

    frames: list[Image.Image] = []
    for index in range(POSE_COUNT):
        left = round(index * source.width / POSE_COUNT)
        right = round((index + 1) * source.width / POSE_COUNT)
        pose = source.crop((left, 0, right, source.height))
        frame = register_pose(pose)
        frames.append(frame)

        name = f"client_arrival_sw_{index:02d}.png"
        frame.save(MASTER_DIR / name, optimize=True)
        frame.save(RUNTIME_DIR / name, optimize=True)

    preview = Image.new("RGBA", (FRAME_SIZE * POSE_COUNT, FRAME_SIZE), (20, 24, 29, 255))
    draw = ImageDraw.Draw(preview)
    for index, frame in enumerate(frames):
        x = index * FRAME_SIZE
        preview.alpha_composite(frame, (x, 0))
        draw.line((x, FOOT_PIVOT_Y, x + FRAME_SIZE - 1, FOOT_PIVOT_Y), fill=(170, 54, 54, 255), width=1)
    preview.save(PREVIEW, optimize=True)


if __name__ == "__main__":
    main()

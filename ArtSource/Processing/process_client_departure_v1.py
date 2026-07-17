#!/usr/bin/env python3
"""Register Vivian's northeast/rear office-exit cycle."""

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / "ArtSource/Generated/Characters/Client/DepartureNEV1"
MASTER_DIR = SOURCE_DIR / "Registered_v01"
RUNTIME_DIR = ROOT / "RainShadow Shared/Resources/Art/Atlases/ClientArrival.atlas"
PREVIEW = SOURCE_DIR / "preview_client_departure_ne_v01_registered.png"
ANIMATED_PREVIEW = SOURCE_DIR / "preview_client_departure_ne_v01.gif"

FRAME_SIZE = 256
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
    frame.alpha_composite(
        subject,
        ((FRAME_SIZE - subject.width) // 2, FOOT_PIVOT_Y - subject.height),
    )
    return frame


def upper_body_centroid_x(frame: Image.Image) -> float:
    alpha = frame.getchannel("A")
    bbox = alpha_bbox(frame)
    bottom = min(FRAME_SIZE, bbox[1] + 59)
    weighted_x = 0
    total_alpha = 0
    for y in range(bbox[1], bottom):
        for x in range(FRAME_SIZE):
            value = alpha.getpixel((x, y))
            weighted_x += x * value
            total_alpha += value
    if total_alpha == 0:
        raise RuntimeError("Cannot align an empty upper body")
    return weighted_x / total_alpha


def align_upper_bodies(frames: list[Image.Image]) -> list[Image.Image]:
    target_x = upper_body_centroid_x(frames[0])
    aligned: list[Image.Image] = []
    for frame in frames:
        x_offset = round(target_x - upper_body_centroid_x(frame))
        canvas = Image.new("RGBA", frame.size, (0, 0, 0, 0))
        canvas.alpha_composite(frame, (x_offset, 0))
        aligned.append(canvas)
    return aligned


def main() -> None:
    source_names = [
        "client_departure_ne_contact_a_rgba_v01.png",
        "client_departure_ne_pass_a_rgba_v01.png",
        "client_departure_ne_contact_b_rgba_v01.png",
        "client_departure_ne_pass_b_rgba_v01.png",
    ]
    poses = [Image.open(SOURCE_DIR / name).convert("RGBA") for name in source_names]
    frames = align_upper_bodies([register_pose(pose) for pose in poses])

    MASTER_DIR.mkdir(parents=True, exist_ok=True)
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    for index, frame in enumerate(frames):
        name = f"client_departure_ne_{index:02d}.png"
        frame.save(MASTER_DIR / name, optimize=True)
        frame.save(RUNTIME_DIR / name, optimize=True)

    preview = Image.new("RGBA", (FRAME_SIZE * len(frames), FRAME_SIZE), (20, 24, 29, 255))
    draw = ImageDraw.Draw(preview)
    for index, frame in enumerate(frames):
        x = index * FRAME_SIZE
        preview.alpha_composite(frame, (x, 0))
        draw.line((x, FOOT_PIVOT_Y, x + FRAME_SIZE - 1, FOOT_PIVOT_Y), fill=(170, 54, 54, 255), width=1)
    preview.save(PREVIEW, optimize=True)

    animation: list[Image.Image] = []
    for frame in frames:
        canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (20, 24, 29, 255))
        canvas.alpha_composite(frame)
        animation.append(canvas.resize((512, 512), Image.Resampling.NEAREST).convert("RGB"))
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

#!/usr/bin/env python3
"""Build Vivian's corrected alternating-leg arrival cycle."""

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
V1_SHEET = ROOT / "ArtSource/Generated/Characters/Client/ArrivalV1/client_arrival_sw_sheet_rgba_v01.png"
SOURCE_DIR = ROOT / "ArtSource/Generated/Characters/Client/ArrivalV2"
MASTER_DIR = SOURCE_DIR / "Registered_v02"
RUNTIME_DIR = ROOT / "RainShadow Shared/Resources/Art/Atlases/ClientArrival.atlas"
PREVIEW = SOURCE_DIR / "preview_client_arrival_v02_registered.png"
ANIMATED_PREVIEW = SOURCE_DIR / "preview_client_arrival_v02.gif"

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


def v1_pose(index: int) -> Image.Image:
    sheet = Image.open(V1_SHEET).convert("RGBA")
    left = round(index * sheet.width / 5)
    right = round((index + 1) * sheet.width / 5)
    return sheet.crop((left, 0, right, sheet.height))


def main() -> None:
    poses = [
        v1_pose(0),
        Image.open(SOURCE_DIR / "client_arrival_sw_pass_left_rgba_v02.png").convert("RGBA"),
        Image.open(SOURCE_DIR / "client_arrival_sw_right_contact_rgba_v02.png").convert("RGBA"),
        Image.open(SOURCE_DIR / "client_arrival_sw_pass_right_rgba_v02.png").convert("RGBA"),
        v1_pose(4),
    ]

    MASTER_DIR.mkdir(parents=True, exist_ok=True)
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    frames = align_upper_bodies([register_pose(pose) for pose in poses])

    for index, frame in enumerate(frames):
        name = f"client_arrival_sw_{index:02d}.png"
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
    for frame in frames[:4]:
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

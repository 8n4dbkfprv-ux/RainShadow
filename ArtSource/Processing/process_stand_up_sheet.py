#!/usr/bin/env python3
"""Extract, register, and palette-limit the generated detective stand-up sheet."""

from pathlib import Path
import shutil

import numpy as np
from PIL import Image
from scipy import ndimage


ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / "ArtSource/Generated/Characters/Detective/StandUpV1"
SHEET_PATH = SOURCE_DIR / "det_stand_up_se_sheet_rgba_v01.png"
REGISTERED_DIR = SOURCE_DIR / "Registered_v01"
ATLAS_DIR = ROOT / "RainShadow Shared/Resources/Art/Atlases/DetectiveStandUp.atlas"
SEATED_ENDPOINT = (
    ROOT
    / "RainShadow Shared/Resources/Art/Atlases/DetectiveSeatedIdle.atlas"
    / "det_seated_idle_se_00.png"
)
STANDING_ENDPOINT = (
    ROOT
    / "RainShadow Shared/Resources/Art/Atlases/DetectiveIdle.atlas"
    / "det_standing_idle_se_00.png"
)

FRAME_SIZE = 256
BODY_HEIGHT = 100
FOOT_Y = 217
ALPHA_COMPONENT_THRESHOLD = 16
PALETTE_COLORS = 112


def premultiplied_resize(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.float32) / 255.0
    alpha = rgba[..., 3:4]
    premultiplied = np.concatenate((rgba[..., :3] * alpha, alpha), axis=2)

    channels = []
    for channel in range(4):
        source = Image.fromarray(
            np.clip(premultiplied[..., channel] * 255.0, 0, 255).astype(np.uint8),
            mode="L",
        )
        channels.append(
            np.asarray(source.resize(size, Image.Resampling.LANCZOS), dtype=np.float32) / 255.0
        )

    resized_alpha = channels[3]
    resized_rgb = np.stack(channels[:3], axis=2)
    nonzero = resized_alpha > 0
    resized_rgb[nonzero] /= resized_alpha[nonzero, None]
    result = np.concatenate((np.clip(resized_rgb, 0, 1), resized_alpha[..., None]), axis=2)
    return Image.fromarray(np.round(result * 255.0).astype(np.uint8), mode="RGBA")


def extract_figures(sheet: Image.Image) -> list[Image.Image]:
    pixels = np.asarray(sheet.convert("RGBA"))
    labels, _ = ndimage.label(pixels[..., 3] >= ALPHA_COMPONENT_THRESHOLD)
    objects = ndimage.find_objects(labels)
    components: list[tuple[int, tuple[int, int, int, int]]] = []

    for label_index, slices in enumerate(objects, start=1):
        if slices is None:
            continue
        area = int(np.count_nonzero(labels[slices] == label_index))
        if area < 1_000:
            continue
        y_slice, x_slice = slices
        components.append(
            (area, (x_slice.start, y_slice.start, x_slice.stop, y_slice.stop))
        )

    if len(components) != 12:
        raise RuntimeError(f"Expected 12 character components, found {len(components)}")

    def grid_position(item: tuple[int, tuple[int, int, int, int]]) -> tuple[int, int]:
        _, (left, top, _, bottom) = item
        center_y = (top + bottom) / 2
        row = min(2, int(center_y * 3 / sheet.height))
        return row, left

    ordered = sorted(components, key=grid_position)
    figures: list[Image.Image] = []
    for _, (left, top, right, bottom) in ordered:
        padding = 2
        crop = sheet.crop(
            (
                max(0, left - padding),
                max(0, top - padding),
                min(sheet.width, right + padding),
                min(sheet.height, bottom + padding),
            )
        )
        alpha_bbox = crop.getchannel("A").getbbox()
        if alpha_bbox is None:
            raise RuntimeError("Extracted an empty stand-up frame")
        figures.append(crop.crop(alpha_bbox))
    return figures


def register(figure: Image.Image) -> Image.Image:
    width = max(1, round(figure.width * BODY_HEIGHT / figure.height))
    resized = premultiplied_resize(figure, (width, BODY_HEIGHT))
    canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    canvas.alpha_composite(resized, ((FRAME_SIZE - width) // 2, FOOT_Y - BODY_HEIGHT))
    limited = canvas.quantize(
        colors=PALETTE_COLORS,
        method=Image.Quantize.FASTOCTREE,
        dither=Image.Dither.NONE,
    )
    return limited.convert("RGBA")


def make_preview(frames: list[Image.Image]) -> Image.Image:
    preview = Image.new("RGBA", (FRAME_SIZE * len(frames), FRAME_SIZE), (48, 48, 48, 255))
    for index, frame in enumerate(frames):
        preview.alpha_composite(frame, (index * FRAME_SIZE, 0))
    return preview


def main() -> None:
    REGISTERED_DIR.mkdir(parents=True, exist_ok=True)
    ATLAS_DIR.mkdir(parents=True, exist_ok=True)

    sheet = Image.open(SHEET_PATH).convert("RGBA")
    generated = extract_figures(sheet)

    frames = [Image.open(SEATED_ENDPOINT).convert("RGBA")]
    frames.extend(register(figure) for figure in generated[1:11])
    frames.append(Image.open(STANDING_ENDPOINT).convert("RGBA"))

    for index, frame in enumerate(frames):
        filename = f"det_stand_up_se_{index:02d}.png"
        source_path = REGISTERED_DIR / filename
        frame.save(source_path, optimize=True)
        shutil.copy2(source_path, ATLAS_DIR / filename)

    make_preview(frames).save(SOURCE_DIR / "preview_stand_up_v01_registered.png", optimize=True)


if __name__ == "__main__":
    main()

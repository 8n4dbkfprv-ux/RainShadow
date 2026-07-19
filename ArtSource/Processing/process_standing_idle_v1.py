#!/usr/bin/env python3
"""Extract and register the five generated detective standing-idle views."""

from pathlib import Path
import shutil

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage


ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / "ArtSource/Generated/Characters/Detective/StandingIdleV1"
SHEET_PATH = SOURCE_DIR / "det_standing_idle_5dir_rgba_v01.png"
REGISTERED_DIR = SOURCE_DIR / "Registered_v01"
ATLAS_DIR = ROOT / "RainShadow Shared/Resources/Art/Atlases/DetectiveIdle.atlas"
PREVIEW_PATH = SOURCE_DIR / "preview_standing_idle_v01_registered.png"

DIRECTIONS = ("s", "sw", "w", "nw", "n")
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
            np.asarray(source.resize(size, Image.Resampling.LANCZOS), dtype=np.float32)
            / 255.0
        )

    resized_alpha = channels[3]
    resized_rgb = np.stack(channels[:3], axis=2)
    nonzero = resized_alpha > 0
    resized_rgb[nonzero] /= resized_alpha[nonzero, None]
    result = np.concatenate(
        (np.clip(resized_rgb, 0, 1), resized_alpha[..., None]), axis=2
    )
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
        if area < 5_000:
            continue
        y_slice, x_slice = slices
        components.append(
            (area, (x_slice.start, y_slice.start, x_slice.stop, y_slice.stop))
        )

    if len(components) != len(DIRECTIONS):
        raise RuntimeError(
            f"Expected {len(DIRECTIONS)} character components, found {len(components)}"
        )

    figures: list[Image.Image] = []
    for _, (left, top, right, bottom) in sorted(components, key=lambda item: item[1][0]):
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
            raise RuntimeError("Extracted an empty standing-idle view")
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
    preview = Image.new(
        "RGBA", (FRAME_SIZE * len(frames), FRAME_SIZE), (20, 24, 29, 255)
    )
    draw = ImageDraw.Draw(preview)
    for index, frame in enumerate(frames):
        x = index * FRAME_SIZE
        preview.alpha_composite(frame, (x, 0))
        draw.line(
            (x, FOOT_Y, x + FRAME_SIZE - 1, FOOT_Y),
            fill=(170, 54, 54, 255),
            width=1,
        )
    return preview


def main() -> None:
    REGISTERED_DIR.mkdir(parents=True, exist_ok=True)
    ATLAS_DIR.mkdir(parents=True, exist_ok=True)

    sheet = Image.open(SHEET_PATH).convert("RGBA")
    frames = [register(figure) for figure in extract_figures(sheet)]

    for direction, frame in zip(DIRECTIONS, frames, strict=True):
        filename = f"det_standing_idle_{direction}_00.png"
        source_path = REGISTERED_DIR / filename
        frame.save(source_path, optimize=True)
        shutil.copy2(source_path, ATLAS_DIR / filename)

    make_preview(frames).save(PREVIEW_PATH, optimize=True)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Register the V5 seated idle and derive clean high-resolution arm overlays."""

from pathlib import Path
import shutil

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage


ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / "ArtSource/Generated/Characters/Detective/SeatedDeskV5"
SHEET_PATH = SOURCE_DIR / "det_seated_idle_desk_arms_strip_rgba_v05.png"
REGISTERED_DIR = SOURCE_DIR / "Registered_v05"
BACKUP_DIR = SOURCE_DIR / "Runtime_backup_v04"
SEATED_ATLAS = ROOT / "RainShadow Shared/Resources/Art/Atlases/DetectiveSeatedIdle.atlas"
ARMS_ATLAS = ROOT / "RainShadow Shared/Resources/Art/Atlases/DetectiveSeatedArms.atlas"
OFFICE_PROPS = ROOT / "RainShadow Shared/Resources/Art/Props/Office"
BARE_DESK_PATH = OFFICE_PROPS / "office_desk_bare.png"
ACTOR_OCCLUDER_PATH = OFFICE_PROPS / "office_desk_actor_occluder.png"
ACTOR_OCCLUDER_BACKUP = (
    ROOT
    / "ArtSource/Generated/Office/Props/office_desk_actor_occluder_pre_alpha_constraint_v05.png"
)

FRAME_SIZE = 256
BODY_HEIGHT = 100
FOOT_Y = 217
PALETTE_COLORS = 112
ALPHA_COMPONENT_THRESHOLD = 16

# Polygons are normalized against the first extracted 345x598 source figure.
# They follow complete connected sleeves through both hands while excluding the
# shirt, tie, lap, trousers, and all background pixels.
REFERENCE_SIZE = (345, 598)
ARM_POLYGONS = [
    [(15, 135), (60, 135), (85, 205), (85, 235), (125, 250),
     (175, 255), (215, 265), (230, 285), (225, 310), (210, 322),
     (180, 320), (160, 305), (125, 295), (95, 275), (65, 255),
     (40, 225), (20, 190)],
    [(185, 155), (220, 160), (235, 205), (250, 230), (285, 242),
     (315, 255), (325, 270), (325, 292), (315, 305), (295, 305),
     (280, 295), (265, 275), (235, 265), (215, 245), (200, 215)],
]


def premultiplied_resize(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.float32) / 255.0
    alpha = rgba[..., 3:4]
    premultiplied = np.concatenate((rgba[..., :3] * alpha, alpha), axis=2)
    channels = []
    for channel in range(4):
        source = Image.fromarray(
            np.clip(premultiplied[..., channel] * 255, 0, 255).astype(np.uint8),
            mode="L",
        )
        channels.append(
            np.asarray(source.resize(size, Image.Resampling.LANCZOS), dtype=np.float32) / 255
        )
    resized_alpha = channels[3]
    resized_rgb = np.stack(channels[:3], axis=2)
    nonzero = resized_alpha > 0
    resized_rgb[nonzero] /= resized_alpha[nonzero, None]
    result = np.concatenate((np.clip(resized_rgb, 0, 1), resized_alpha[..., None]), axis=2)
    return Image.fromarray(np.round(result * 255).astype(np.uint8), mode="RGBA")


def extract_figures(sheet: Image.Image) -> list[Image.Image]:
    pixels = np.asarray(sheet.convert("RGBA"))
    labels, _ = ndimage.label(pixels[..., 3] >= ALPHA_COMPONENT_THRESHOLD)
    objects = ndimage.find_objects(labels)
    components = []
    for label_index, slices in enumerate(objects, start=1):
        if slices is None:
            continue
        area = int(np.count_nonzero(labels[slices] == label_index))
        if area < 10_000:
            continue
        y_slice, x_slice = slices
        components.append((x_slice.start, y_slice.start, x_slice.stop, y_slice.stop))
    if len(components) != 4:
        raise RuntimeError(f"Expected four seated figures, found {len(components)}")
    return [sheet.crop(box) for box in sorted(components)]


def arm_layer(figure: Image.Image) -> Image.Image:
    mask = Image.new("L", figure.size, 0)
    draw = ImageDraw.Draw(mask)
    scale_x = figure.width / REFERENCE_SIZE[0]
    scale_y = figure.height / REFERENCE_SIZE[1]
    for polygon in ARM_POLYGONS:
        scaled = [(round(x * scale_x), round(y * scale_y)) for x, y in polygon]
        draw.polygon(scaled, fill=255)

    pixels = np.asarray(figure.convert("RGBA")).copy()
    selected = np.asarray(mask) > 0
    pixels[~selected] = 0
    return Image.fromarray(pixels, mode="RGBA")


def register(image: Image.Image, width: int) -> Image.Image:
    resized = premultiplied_resize(image, (width, BODY_HEIGHT))
    canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    canvas.alpha_composite(resized, ((FRAME_SIZE - width) // 2, FOOT_Y - BODY_HEIGHT))
    limited = canvas.quantize(
        colors=PALETTE_COLORS,
        method=Image.Quantize.FASTOCTREE,
        dither=Image.Dither.NONE,
    )
    return limited.convert("RGBA")


def remove_detached_islands(image: Image.Image, minimum_area: int = 100) -> Image.Image:
    """Keep complete forearms and discard resize/quantization specks."""
    pixels = np.asarray(image.convert("RGBA")).copy()
    structure = np.ones((3, 3), dtype=np.uint8)
    labels, count = ndimage.label(pixels[..., 3] > 0, structure=structure)
    areas = ndimage.sum(labels > 0, labels, range(1, count + 1))
    kept_labels = np.flatnonzero(areas >= minimum_area) + 1
    pixels[~np.isin(labels, kept_labels)] = 0
    return Image.fromarray(pixels, mode="RGBA")


def backup_runtime() -> None:
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    for atlas in (SEATED_ATLAS, ARMS_ATLAS):
        for source in atlas.glob("*.png"):
            destination = BACKUP_DIR / f"{atlas.stem}_{source.name}"
            if not destination.exists():
                shutil.copy2(source, destination)


def constrain_actor_occluder_to_desk_alpha() -> None:
    """Prevent the body mask from making transparent desk RGB visible."""
    if not ACTOR_OCCLUDER_BACKUP.exists():
        ACTOR_OCCLUDER_BACKUP.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ACTOR_OCCLUDER_PATH, ACTOR_OCCLUDER_BACKUP)

    desk = np.asarray(Image.open(BARE_DESK_PATH).convert("RGBA"))
    occluder = np.asarray(Image.open(ACTOR_OCCLUDER_PATH).convert("RGBA")).copy()
    if desk.shape != occluder.shape:
        raise RuntimeError(
            f"Desk/occluder size mismatch: {desk.shape} vs {occluder.shape}"
        )

    occluder[..., 3] = np.minimum(occluder[..., 3], desk[..., 3])
    occluder[occluder[..., 3] == 0] = 0
    Image.fromarray(occluder, mode="RGBA").save(ACTOR_OCCLUDER_PATH, optimize=True)


def main() -> None:
    REGISTERED_DIR.mkdir(parents=True, exist_ok=True)
    SEATED_ATLAS.mkdir(parents=True, exist_ok=True)
    ARMS_ATLAS.mkdir(parents=True, exist_ok=True)
    backup_runtime()
    constrain_actor_occluder_to_desk_alpha()

    figures = extract_figures(Image.open(SHEET_PATH).convert("RGBA"))
    preview = Image.new("RGBA", (FRAME_SIZE * 4, FRAME_SIZE), (48, 48, 48, 255))

    for index, figure in enumerate(figures):
        width = max(1, round(figure.width * BODY_HEIGHT / figure.height))
        body = remove_detached_islands(register(figure, width))
        arms = remove_detached_islands(register(arm_layer(figure), width))

        body_name = f"det_seated_idle_se_{index:02d}.png"
        arms_name = f"det_seated_arms_se_{index:02d}.png"
        body.save(REGISTERED_DIR / body_name, optimize=True)
        arms.save(REGISTERED_DIR / arms_name, optimize=True)
        shutil.copy2(REGISTERED_DIR / body_name, SEATED_ATLAS / body_name)
        shutil.copy2(REGISTERED_DIR / arms_name, ARMS_ATLAS / arms_name)
        preview.alpha_composite(body, (index * FRAME_SIZE, 0))

    preview.save(SOURCE_DIR / "preview_seated_desk_v05_registered.png", optimize=True)


if __name__ == "__main__":
    main()

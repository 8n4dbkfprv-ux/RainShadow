#!/usr/bin/env python3
"""Build the HUD map from the final furnished V14 office plate."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = (
    ROOT
    / "ArtSource/Generated/Office/PlateBake"
    / "office_suite_plate_baked_v14.png"
)
GENERATED = ROOT / "ArtSource/Generated/UI/Map/map_detective_office_v14.png"
TARGET = (1847, 1040)


def fit_to_aspect(image: Image.Image, target: tuple[int, int]) -> Image.Image:
    """Centre-crop, then resize uniformly; never shear a projected plate."""
    target_aspect = target[0] / target[1]
    source_aspect = image.width / image.height
    if source_aspect > target_aspect:
        crop_width = round(image.height * target_aspect)
        left = (image.width - crop_width) // 2
        image = image.crop((left, 0, left + crop_width, image.height))
    elif source_aspect < target_aspect:
        crop_height = round(image.width / target_aspect)
        top = (image.height - crop_height) // 2
        image = image.crop((0, top, image.width, top + crop_height))
    return image.resize(target, Image.Resampling.LANCZOS)


def main() -> None:
    image = Image.open(SOURCE).convert("RGB")
    if image.size != (4096, 2304):
        raise RuntimeError(f"expected registered 4096x2304 V14 plate, got {image.size}")
    mapped = fit_to_aspect(image, TARGET)
    GENERATED.parent.mkdir(parents=True, exist_ok=True)
    mapped.save(GENERATED, optimize=True)
    print(f"wrote {GENERATED.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

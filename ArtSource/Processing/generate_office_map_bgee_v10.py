#!/usr/bin/env python3
"""Build the V10 HUD map from the registered tavern-office plate."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "ArtSource/Generated/Office/BGEETavernV10/office_tavern_plate_v10.png"
GENERATED = ROOT / "ArtSource/Generated/UI/Map/map_detective_office_v10.png"
RUNTIME = ROOT / "RainShadow Shared/Resources/Art/UI/Map/map_detective_office_v08.png"
TARGET = (1847, 1040)


def fit_to_aspect(image: Image.Image, target: tuple[int, int]) -> Image.Image:
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


def nonblack_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    rgb = image.convert("RGB")
    mask = Image.new("1", rgb.size)
    mask.putdata([max(pixel) > 7 for pixel in rgb.getdata()])
    bbox = mask.getbbox()
    if bbox is None:
        raise RuntimeError("HUD map has no non-black room pixels")
    return bbox


def main() -> None:
    image = Image.open(SOURCE).convert("RGB")
    if image.size != (4096, 2304):
        raise RuntimeError(f"expected registered 4096x2304 plate, got {image.size}")
    mapped = fit_to_aspect(image, TARGET)
    bbox = nonblack_bbox(mapped)
    GENERATED.parent.mkdir(parents=True, exist_ok=True)
    RUNTIME.parent.mkdir(parents=True, exist_ok=True)
    mapped.save(GENERATED, optimize=True)
    mapped.save(RUNTIME, optimize=True)
    x0, y0, x1, y1 = bbox
    print(f"wrote {GENERATED}")
    print(f"wrote {RUNTIME}")
    print(f"content bbox y-down={bbox}")
    print(
        "SK UV="
        f"({x0 / TARGET[0]:.4f}, {(TARGET[1] - y1) / TARGET[1]:.4f}, "
        f"{(x1 - x0) / TARGET[0]:.4f}, {(y1 - y0) / TARGET[1]:.4f})"
    )


if __name__ == "__main__":
    main()

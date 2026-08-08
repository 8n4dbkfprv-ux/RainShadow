"""Prepare ImageGen world-map markers for SpriteKit.

The retained masters use a flat green background.  This pass keys that green,
trims the empty canvas, normalises every marker to 256 px, and produces the
oxblood hover treatment seen in the world-map interaction reference.
"""

from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "ArtSource" / "Generated" / "UI" / "Map" / "WorldMarkers" / "Chroma"
GENERATED = ROOT / "ArtSource" / "Generated" / "UI" / "Map" / "WorldMarkers"
RUNTIME = ROOT / "RainShadow Shared" / "Resources" / "Art" / "UI" / "Map"
SLUGS = (
    "sable_row",
    "wharf_ladder",
    "riverside",
    "harborpoint_pd",
    "lila_street",
    "civic_records",
)


def keyed_marker(path: Path) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    pixels = np.asarray(image).copy()
    rgb = pixels[:, :, :3].astype(np.int16)
    # ImageGen's nominally flat key varies slightly across the canvas.
    green_score = rgb[:, :, 1] - np.maximum(rgb[:, :, 0], rgb[:, :, 2])
    alpha = np.clip((70 - green_score) * 5, 0, 255).astype(np.uint8)
    pixels[:, :, 3] = alpha

    keyed = Image.fromarray(pixels, "RGBA")
    bbox = keyed.getchannel("A").point(lambda value: 255 if value > 24 else 0).getbbox()
    if bbox is None:
        raise RuntimeError(f"No foreground survived chroma key: {path}")
    keyed = keyed.crop(bbox)

    target = 228
    scale = min(target / keyed.width, target / keyed.height)
    size = (max(1, round(keyed.width * scale)), max(1, round(keyed.height * scale)))
    keyed = keyed.resize(size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    canvas.alpha_composite(keyed, ((256 - size[0]) // 2, (256 - size[1]) // 2))
    return canvas


def hover_marker(normal: Image.Image) -> Image.Image:
    pixels = np.asarray(normal).copy()
    rgb = pixels[:, :, :3].astype(np.float32)
    luminance = rgb[:, :, 0] * 0.24 + rgb[:, :, 1] * 0.60 + rgb[:, :, 2] * 0.16
    # Deep red body with hot vermilion highlights, retaining painted shading.
    pixels[:, :, 0] = np.clip(52 + luminance * 1.28, 0, 255).astype(np.uint8)
    pixels[:, :, 1] = np.clip(8 + luminance * 0.23, 0, 92).astype(np.uint8)
    pixels[:, :, 2] = np.clip(7 + luminance * 0.18, 0, 68).astype(np.uint8)
    pixels[pixels[:, :, 3] == 0, :3] = 0
    return Image.fromarray(pixels, "RGBA")


def main() -> None:
    GENERATED.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)
    for slug in SLUGS:
        stem = f"map_district_icon_{slug}_v01"
        normal = keyed_marker(SOURCE / f"{stem}_chroma.png")
        hover = hover_marker(normal)
        for suffix, image in (("", normal), ("_hover", hover)):
            filename = f"{stem}{suffix}.png"
            image.save(GENERATED / filename, optimize=True)
            image.save(RUNTIME / filename, optimize=True)
            print(filename)


if __name__ == "__main__":
    main()

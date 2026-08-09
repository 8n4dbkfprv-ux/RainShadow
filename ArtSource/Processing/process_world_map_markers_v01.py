"""Prepare ImageGen world-map markers for SpriteKit.

The retained masters use a flat green background.  This pass keys that green,
trims the empty canvas, normalises every marker to 256 px, and produces the
oxblood hover treatment seen in the world-map interaction reference.

V4 ships a clean sparse parchment base (`map_world_harborpoint_v04`).  Runtime
draws the painted normal stamps always (BG:EE Classic style); hover swaps to
the oxblood treatment.  Optional ink ghosts are still written for QA previews
but are not baked into the shipped plate.
"""

from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "ArtSource" / "Generated" / "UI" / "Map" / "WorldMarkers" / "Chroma"
GENERATED = ROOT / "ArtSource" / "Generated" / "UI" / "Map" / "WorldMarkers"
RUNTIME = ROOT / "RainShadow Shared" / "Resources" / "Art" / "UI" / "Map"
MAP_BASE = ROOT / "ArtSource" / "Generated" / "UI" / "Map" / "map_world_harborpoint_v04_base.png"
MAP_GENERATED = ROOT / "ArtSource" / "Generated" / "UI" / "Map" / "map_world_harborpoint_v04.png"
MAP_RUNTIME = RUNTIME / "map_world_harborpoint_v04.png"
SLUGS = (
    "sable_row",
    "wharf_ladder",
    "riverside",
    "harborpoint_pd",
    "lila_street",
    "civic_records",
)

# Marker centres in the 1536×1024 source map.  These mirror WorldMapOverlay's
# 1320×880 layout (icon +25 lift applied in the overlay, not here).
MAP_MARKER_CENTRES = {
    "civic_records": (768, 142),
    "wharf_ladder": (256, 483),
    "sable_row": (768, 483),
    "lila_street": (1280, 483),
    "riverside": (256, 824),
    "harborpoint_pd": (768, 738),
}


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


def inked_marker(normal: Image.Image) -> Image.Image:
    """Turn the painted icon into charcoal linework that shows map paper through."""
    pixels = np.asarray(normal).copy()
    rgb = pixels[:, :, :3].astype(np.float32)
    source_alpha = pixels[:, :, 3].astype(np.float32) / 255.0
    luminance = (rgb[:, :, 0] * 0.24 + rgb[:, :, 1] * 0.60 + rgb[:, :, 2] * 0.16) / 255.0
    darkness = 1.0 - luminance
    luminance_y, luminance_x = np.gradient(luminance)
    alpha_y, alpha_x = np.gradient(source_alpha)
    edge = np.clip(
        np.hypot(luminance_x, luminance_y) * 4.0
        + np.hypot(alpha_x, alpha_y) * 2.0,
        0,
        1,
    )
    ink_alpha = source_alpha * (0.05 + darkness * 0.22 + edge * 0.66)
    pixels[:, :, 0] = 35
    pixels[:, :, 1] = 34
    pixels[:, :, 2] = 33
    pixels[:, :, 3] = np.clip(ink_alpha * 255, 0, 255).astype(np.uint8)
    pixels[source_alpha == 0, :3] = 0
    return Image.fromarray(pixels, "RGBA")


def install_clean_map() -> None:
    """Ship the sparse parchment base with no baked landmarks."""
    if not MAP_BASE.exists():
        raise RuntimeError(f"Missing ImageGen v04 map base: {MAP_BASE}")
    world_map = Image.open(MAP_BASE).convert("RGBA")
    if world_map.size != (1536, 1024):
        raise RuntimeError(f"Expected 1536×1024 map base, got {world_map.size}")
    world_map.save(MAP_GENERATED, optimize=True)
    world_map.save(MAP_RUNTIME, optimize=True)
    print(MAP_RUNTIME.name)


def write_ink_previews(markers: dict[str, Image.Image]) -> None:
    """Optional ink ghosts for art QA only — not composited into the plate."""
    for slug, marker in markers.items():
        inked = inked_marker(marker)
        inked.save(GENERATED / f"map_district_icon_{slug}_v01_ink.png", optimize=True)


def main() -> None:
    GENERATED.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)
    markers: dict[str, Image.Image] = {}
    for slug in SLUGS:
        stem = f"map_district_icon_{slug}_v01"
        normal = keyed_marker(SOURCE / f"{stem}_chroma.png")
        markers[slug] = normal
        hover = hover_marker(normal)
        for suffix, image in (("", normal), ("_hover", hover)):
            filename = f"{stem}{suffix}.png"
            image.save(GENERATED / filename, optimize=True)
            image.save(RUNTIME / filename, optimize=True)
            print(filename)
    write_ink_previews(markers)
    install_clean_map()


if __name__ == "__main__":
    main()

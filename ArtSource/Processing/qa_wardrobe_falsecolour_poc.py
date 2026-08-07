#!/usr/bin/env python3
"""Proof of concept: give Voss his documented wardrobe back via false colour.

Diagnosis this comes from — every source in the chain is monochrome brown:

    paperdoll v11        G/R 0.66-0.76 across head, shirt, waistcoat, coat, trousers, shoes
    seated NE00          G/R 0.65-0.74   (the pipeline's colour authority)
    idle_s v5 master     G/R 0.58-0.65
    shipped V14 frame    G/R 0.67-0.70
    shipped V7 frame     G/R 0.65-0.73   (so this predates the V14 crunch)

Voss reads as one tan mass because he *is* one tan mass, at every stage. GDD §4.2
specifies an olive-brown overcoat, mustard waistcoat, cream shirt, dark green
tie, charcoal trousers and scuffed brown shoes; none of it was ever generated,
and `seated_authority_lock` then stamps a single chroma ratio across 10-86% of
the body, which locks the monochrome in.

By contrast a BG:EE avatar separates materials by *hue and value both* — sampled
off Abdel in the reference screenshot: near-black boots, maroon tunic, steel
skirt panels, skin limbs, a distinctly lighter bracer.

The Infinity Engine's own answer to this is false colour: a BAM stores what is
effectively one shaded ramp per material slot, and the engine substitutes a
gradient per slot. Our sprite is already a single-hue ramp, so luminance still
encodes the wardrobe structure — the shirt is the lightest thing on the torso,
the tie the darkest. That makes it recolourable without regenerating any art.

This is a PoC, not an installer: it writes a comparison sheet and touches no atlas.
"""

from __future__ import annotations

import numpy as np
from PIL import Image, ImageDraw

from qa_pixelation_ab_v02 import (
    OUTPUT,
    ROOT,
    SPRITE_SCREEN_PX,
    labelled,
    office_tile,
    screen_plate,
)

ATLASES = ROOT / "RainShadow Shared/Resources/Art/Atlases"

# GDD §4.2 wardrobe against the §5.3 noir palette.
WARDROBE = {
    "skin": (172, 126, 96),
    "hair": (58, 45, 37),
    "coat": (112, 94, 60),      # olive-brown belted overcoat
    "waistcoat": (156, 119, 47),  # mustard
    "shirt": (206, 195, 170),   # old-paper cream
    "tie": (54, 70, 54),        # loosened dark green
    "trousers": (58, 56, 62),   # charcoal
    "shoes": (78, 55, 37),      # scuffed brown
}


def segment(frame: Image.Image) -> dict[str, np.ndarray]:
    """Split a foot-registered figure into wardrobe regions.

    Bands give the vertical structure; luminance *within* the torso band gives
    the layering, because on a monochrome figure the shirt is still the lightest
    thing on the chest and the tie the darkest.
    """
    pixels = np.asarray(frame.convert("RGBA"))
    mask = pixels[..., 3] >= 128
    rgb = pixels[..., :3].astype(np.float32)
    lum = rgb.mean(axis=2)

    ys, xs = np.nonzero(mask)
    y0, y1 = int(ys.min()), int(ys.max())
    x0, x1 = int(xs.min()), int(xs.max())
    height = max(1, y1 - y0 + 1)
    width = max(1, x1 - x0 + 1)

    def band(lo: float, hi: float) -> np.ndarray:
        out = np.zeros_like(mask)
        out[y0 + int(height * lo) : y0 + int(height * hi)] = True
        return out & mask

    head = band(0.0, 0.15)
    torso = band(0.15, 0.62)
    legs = band(0.62, 0.93)
    feet = band(0.93, 1.0)

    regions: dict[str, np.ndarray] = {}
    regions["skin"] = head & (lum >= np.percentile(lum[head], 55)) if head.any() else head
    regions["hair"] = head & ~regions["skin"]

    # Centre column of the chest carries shirt placket and tie.
    centre = np.zeros_like(mask)
    centre[:, x0 + int(width * 0.32) : x0 + int(width * 0.68)] = True
    chest = torso & centre & band(0.15, 0.42)

    if chest.any():
        regions["shirt"] = chest & (lum >= np.percentile(lum[chest], 78))
        regions["tie"] = chest & (lum <= np.percentile(lum[chest], 18))
    else:
        regions["shirt"] = np.zeros_like(mask)
        regions["tie"] = np.zeros_like(mask)

    waist = torso & centre & band(0.34, 0.55)
    regions["waistcoat"] = waist & ~regions["shirt"] & ~regions["tie"]
    regions["coat"] = torso & ~regions["shirt"] & ~regions["tie"] & ~regions["waistcoat"]
    regions["trousers"] = legs
    regions["shoes"] = feet
    return regions


def recolour(frame: Image.Image) -> Image.Image:
    """Replace each region's hue with its wardrobe colour, keeping its shading.

    Every pixel keeps its luminance *relative to its own region*, so folds and
    the baked key light survive; only the chroma is substituted. This is the
    same move `_stamp_region_chroma` already makes for face and hair — it is
    just applied per material instead of stamping one ratio over the whole body.
    """
    pixels = np.asarray(frame.convert("RGBA")).copy()
    rgb = pixels[..., :3].astype(np.float32)
    lum = rgb.mean(axis=2)

    for name, region in segment(frame).items():
        if int(region.sum()) < 4:
            continue
        target = np.array(WARDROBE[name], dtype=np.float32)
        local = lum[region]
        # Normalise the region around its own mean, then rebuild on the target
        # hue with a little more range than the flat source carries.
        centred = (local - local.mean()) / max(local.std(), 1e-3)
        scale = np.clip(1.0 + centred * 0.34, 0.45, 1.75)
        pixels[region, :3] = np.clip(target[None, :] * scale[:, None], 0, 255).astype(np.uint8)

    return Image.fromarray(pixels, "RGBA")


def zoom(frame: Image.Image, factor: int = 4) -> Image.Image:
    display = frame.resize((SPRITE_SCREEN_PX, SPRITE_SCREEN_PX), Image.Resampling.NEAREST)
    box = display.getchannel("A").point(lambda v: 255 if v >= 16 else 0).getbbox()
    crop = display.crop(box)
    crop = crop.resize((crop.width * factor, crop.height * factor), Image.Resampling.NEAREST)
    tile = Image.new("RGBA", (crop.width + 24, crop.height + 24), (28, 28, 32, 255))
    tile.alpha_composite(crop, (12, 12))
    return tile


CELLS = [
    ("VossIdle.atlas", "voss_standing_idle_s_00.png", "idle S"),
    ("VossIdle.atlas", "voss_standing_idle_sw_00.png", "idle SW"),
    ("VossWalk.atlas", "voss_walk_sw_00.png", "walk SW"),
    ("VossSeatedIdle.atlas", "voss_seated_idle_ne_00.png", "seated NE"),
]


def main() -> None:
    plate = screen_plate()
    zoom_tiles: list[Image.Image] = []
    play_tiles: list[Image.Image] = []

    for atlas, name, label in CELLS:
        shipped = Image.open(ATLASES / atlas / name).convert("RGBA")
        fixed = recolour(shipped)
        zoom_tiles += [labelled(zoom(shipped), f"shipped  {label}"),
                       labelled(zoom(fixed), f"false-colour  {label}")]
        play_tiles += [labelled(office_tile(shipped, plate), f"shipped  {label}"),
                       labelled(office_tile(fixed, plate), f"false-colour  {label}")]

    def grid(tiles: list[Image.Image], columns: int) -> Image.Image:
        w = max(t.width for t in tiles)
        h = max(t.height for t in tiles)
        rows = (len(tiles) + columns - 1) // columns
        sheet = Image.new("RGBA", (w * columns, h * rows), (18, 18, 20, 255))
        for i, t in enumerate(tiles):
            sheet.alpha_composite(t, ((i % columns) * w + (w - t.width) // 2, (i // columns) * h))
        return sheet

    grid(zoom_tiles, 4).convert("RGB").save(OUTPUT / "qa_wardrobe_falsecolour_zoom.png", optimize=True)
    grid(play_tiles, 4).convert("RGB").save(OUTPUT / "qa_wardrobe_falsecolour_playscale.png", optimize=True)
    print(f"Wrote {OUTPUT.relative_to(ROOT)}/qa_wardrobe_falsecolour_{{zoom,playscale}}.png")


if __name__ == "__main__":
    main()

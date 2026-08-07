#!/usr/bin/env python3
"""A/B pixelation study V02: pick the V14 crunch at the *current* camera.

`qa_pixelation_ab_v01.py` chose the shipped 80px/64-colour crunch, but it
composited its tiles at the camera of 2026-07-23 (9% body-to-visible-height).
The camera was reframed to 13% on 2026-08-06 (b1cc1a42, 7dfc838b) to match
original BG1 play density, so that study's "at play scale" verdict is stale.
v01 also quantized the whole canvas while the shipped V7 quantizes opaque
pixels only, so its approved variant was never quite what shipped.

This study fixes both, and adds the two axes the research turned up:

- **silhouette**: classic Infinity Engine BAM v1 stores no semi-transparent
  pixels — creature sprites are 1-bit alpha. Our shipped frames are only ~70%
  fully opaque; the rest is a soft fringe that nearest-upscaling smears.
- **palette structure**: BG character palettes are per-material shade ramps,
  not one global median cut. A global cut allocates entries by pixel area, so
  our coat gets ~102 colours and the head ~19.

Nothing here writes to an atlas. It bakes candidates and stages two sheets.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import process_pre_rendered_characters_v3 as raster
import process_pre_rendered_characters_v12 as v12
from install_voss_idle_walk_seated_match_v02 import extract_figure


ROOT = Path(__file__).resolve().parents[2]
STAGING = ROOT / "ArtSource/Generated/Characters/Detective/PreRendered3DV12/LocomotionV13Staging"
SUBJECT = STAGING / "voss_idle_sw_00_chroma_v13.png"
OFFICE_PLATE = ROOT / "RainShadow Shared/Resources/Art/Areas/DetectiveOffice/office_suite_plate.png"
BGEE_REFS = ROOT / "ArtSource/References/BGEE"
OUTPUT = ROOT / "ArtSource/Generated/Characters/Detective/PixelationAB"

# ---------------------------------------------------------------------------
# Play-scale geometry, derived from the Swift constants rather than guessed.
#   OfficeInteriorScale.ActorDisplay: 512 canvas, 200px body, 180pt node
#   OfficeInteriorScale.environment:  0.395 world units per plate pixel
#   DefaultPlayZoom.targetBodyToVisibleHeight: 0.13
#   TechnicalArchitecture §4.1: 16:9 viewport ~1789x1007
# ---------------------------------------------------------------------------
FRAME_SIZE = 512
TEXTURE_BODY_HEIGHT = 200
FOOT_Y = 434
SPRITE_DISPLAY_WORLD = 180.0
FOOT_ANCHOR = 40 / 256  # DetectiveActorNode body.anchorPoint.y
ENVIRONMENT = 0.395
TARGET_BODY_FRACTION = 0.13
VIEWPORT_HEIGHT = 1007

BODY_WORLD = TEXTURE_BODY_HEIGHT / FRAME_SIZE * SPRITE_DISPLAY_WORLD          # 70.31
CAMERA_VISIBLE_WORLD = BODY_WORLD / TARGET_BODY_FRACTION                      # 540.9
VISIBLE_PLATE_PX = CAMERA_VISIBLE_WORLD / ENVIRONMENT                         # 1369.4
PLATE_TO_SCREEN = VIEWPORT_HEIGHT / VISIBLE_PLATE_PX                          # 0.7354
SPRITE_SCREEN_PX = round(SPRITE_DISPLAY_WORLD / ENVIRONMENT * PLATE_TO_SCREEN)  # 335
BODY_SCREEN_PX = TEXTURE_BODY_HEIGHT / FRAME_SIZE * SPRITE_SCREEN_PX          # ~131

# Open floor near the plate centre (OfficeInteriorScale.layoutFocus is 2048,1152).
PLATE_ROOT = (2000, 1300)
TILE_SCREEN = 300

RAMP_STEPS = 12  # BG gradients carry 12 shades per material slot


@dataclass(frozen=True)
class Variant:
    key: str
    label: str
    native_rows: int
    hard_alpha: bool
    palette: str  # "medcut" | "ramps"
    contrast: float
    colors: int = 64


VARIANTS = [
    Variant("a", "A  80 soft  medcut64  c0.68  (shipped)", 80, False, "medcut", 0.68),
    Variant("b", "B  80 hard  medcut64  c0.68", 80, True, "medcut", 0.68),
    Variant("c", "C  80 hard  ramps     c1.00", 80, True, "ramps", 1.00),
    Variant("d", "D  64 hard  ramps     c1.00", 64, True, "ramps", 1.00),
    Variant("e", "E  56 hard  ramps     c1.00  (BG1 target)", 56, True, "ramps", 1.00),
    Variant("f", "F  48 hard  ramps     c1.00", 48, True, "ramps", 1.00),
]


# ---------------------------------------------------------------------------
# Crunch candidates
# ---------------------------------------------------------------------------


def soften(figure: Image.Image, contrast: float, radius: float = 3.4) -> Image.Image:
    """v12.soften_for_paperdoll_craft with the midtone pull as a parameter.

    The blur stays: it drops micro-detail the 3D masters carry that the era
    would not have. Only the contrast flattening is under study — at 0.68 our
    opaque luma std is 34.8 against 45.7 on a real BG paperdoll asset.
    """
    rgba = figure.convert("RGBA")
    rgb = Image.merge("RGB", rgba.split()[:3]).filter(ImageFilter.GaussianBlur(radius=radius))
    if contrast != 1.0:
        arr = np.asarray(rgb).astype(np.float32)
        mean = arr.mean(axis=(0, 1), keepdims=True)
        arr = mean + (arr - mean) * contrast
        rgb = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")
    return Image.merge("RGBA", (*rgb.split(), rgba.split()[-1]))


MATERIAL_OTHER, MATERIAL_COAT, MATERIAL_SKIN = 0, 1, 2


def material_coverage(figure: Image.Image) -> Image.Image:
    """Segment materials on the full-resolution master, not the native raster.

    `_coat_mask` / `_skin_mask` are tuned for master resolution, where the face
    is thousands of pixels. Run on an 80-row raster the skin mask collapses to
    single digits and its ramp dies, so segmentation has to happen up here and
    ride the downsample down.

    Returned as an RGB coverage image (R=other, G=coat, B=skin) so it can be
    area-resampled alongside the figure: point sampling a 4%-area region through
    a 17x reduction loses it entirely, area coverage plus argmax does not.
    """
    pixels = np.asarray(figure.convert("RGBA"))
    rgb = pixels[..., :3].astype(np.int16)
    alpha_mask = pixels[..., 3] > 0

    # `_coat_mask` is deliberately broad (it has to catch shaded folds), so on its
    # own it also swallows the face — warm skin satisfies every one of its terms.
    # v12 disambiguates the same way: pair each colour mask with its ROI band.
    # Skin wins inside the head band, coat takes the rest of the figure.
    skin = v12._skin_mask(rgb, alpha_mask) & v12._face_roi_mask(alpha_mask)
    coat = v12._coat_mask(rgb, alpha_mask) & ~skin
    other = alpha_mask & ~coat & ~skin

    coverage = np.zeros((*alpha_mask.shape, 3), dtype=np.uint8)
    coverage[..., MATERIAL_OTHER] = np.where(other, 255, 0)
    coverage[..., MATERIAL_COAT] = np.where(coat, 255, 0)
    coverage[..., MATERIAL_SKIN] = np.where(skin, 255, 0)
    return Image.fromarray(coverage, "RGB")


def _labels_from_coverage(coverage: Image.Image) -> np.ndarray:
    return np.asarray(coverage).argmax(axis=2).astype(np.uint8)


def _native(
    figure: Image.Image, coverage: Image.Image, rows: int, hard_alpha: bool, iterations: int = 4
) -> tuple[Image.Image, np.ndarray]:
    """Downsample figure and material labels together to a `rows`-tall body.

    With `hard_alpha`, binarising at 50% drops the alpha 16..127 fringe, which
    shrinks the body by roughly a pixel per side. The Swift gates measure the
    bbox at alpha >= 16 (VossSeatScaleTests alphaThreshold), so a naive binarise
    would fail the 198...202 standing-height and footY == 433 contracts by
    construction. Converge on the request height instead, so the *binarised*
    body is the thing normalised to `rows`.
    """
    request = float(rows)
    result: tuple[Image.Image, np.ndarray] | None = None

    for _ in range(iterations if hard_alpha else 1):
        height = max(1, round(request))
        width = max(1, round(figure.width * height / figure.height))
        native = raster.premultiplied_resize(figure, (width, height))
        scaled = coverage.resize((width, height), Image.Resampling.BOX)

        if not hard_alpha:
            return native, _labels_from_coverage(scaled)

        alpha = native.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
        bbox = alpha.getbbox()
        if bbox is None:
            raise RuntimeError("Binarised figure has no opaque subject")
        merged = Image.merge("RGBA", (*native.split()[:3], alpha)).crop(bbox)
        result = (merged, _labels_from_coverage(scaled.crop(bbox)))
        if merged.height == rows:
            return result
        request *= rows / merged.height

    assert result is not None
    return result


def _quantise_medcut(native: Image.Image, colors: int) -> Image.Image:
    """Shipped V7 behaviour: one global ramp from opaque figure pixels only."""
    alpha = native.getchannel("A")
    pixels = np.asarray(native)
    opaque = pixels[pixels[..., 3] > 0][:, :3]
    palette_source = Image.fromarray(opaque.reshape((1, -1, 3)), "RGB")
    palette = palette_source.quantize(
        colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE
    )
    limited = native.convert("RGB").quantize(
        palette=palette, dither=Image.Dither.NONE
    ).convert("RGB")
    return Image.merge("RGBA", (*limited.split(), alpha))


def _region_ramp(sample: np.ndarray, steps: int) -> np.ndarray:
    """A `steps`-entry ramp fitted to one material's own pixels."""
    source = Image.fromarray(sample.reshape((1, -1, 3)).astype(np.uint8), "RGB")
    quantised = source.quantize(
        colors=steps, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE
    )
    palette = np.asarray(quantised.getpalette(), dtype=np.int32).reshape(-1, 3)
    used = len(quantised.getcolors(steps * 4) or [])
    return palette[: max(1, min(steps, used or steps))]


def _quantise_ramps(native: Image.Image, labels: np.ndarray, colors: int) -> Image.Image:
    """Per-material shade ramps, the way Infinity Engine avatar palettes were built.

    Skin and coat each get their own 12-step ramp regardless of how little area
    they cover, so the face stops competing with the coat for palette entries.
    Everything else (hair, trousers, shoes) shares the remaining budget.
    """
    pixels = np.asarray(native).copy()
    alpha_mask = pixels[..., 3] > 0

    regions = [
        ("skin", alpha_mask & (labels == MATERIAL_SKIN), RAMP_STEPS),
        ("coat", alpha_mask & (labels == MATERIAL_COAT), RAMP_STEPS),
        ("other", alpha_mask & (labels == MATERIAL_OTHER), max(RAMP_STEPS, colors - 2 * RAMP_STEPS)),
    ]

    for name, mask, steps in regions:
        count = int(mask.sum())
        if count < 6:
            if name in ("skin", "coat"):
                raise RuntimeError(f"{name} region collapsed to {count} px — cannot build a ramp")
            continue
        sample = pixels[mask][:, :3]
        # A face only a few dozen native pixels wide cannot carry 12 distinct
        # shades; asking for more entries than pixels just wastes the budget.
        ramp = _region_ramp(sample, max(2, min(steps, count // 2)))
        # int32: a squared channel delta reaches 65025 and three of them 195075,
        # which silently wraps in int16 and scatters wide-range regions at random.
        distance = ((sample[:, None, :].astype(np.int32) - ramp[None, :, :]) ** 2).sum(axis=2)
        pixels[mask, :3] = ramp[distance.argmin(axis=1)].astype(np.uint8)

    return Image.fromarray(pixels, "RGBA")


def crunch_candidate(figure: Image.Image, variant: Variant) -> Image.Image:
    """One candidate V14 crunch, ending on the unchanged 200px texture body."""
    pixels = np.asarray(figure.convert("RGBA")).copy()
    pixels[pixels[..., 3] < 16] = 0
    figure = Image.fromarray(pixels, "RGBA")
    bbox = figure.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError("Figure has no opaque subject")
    figure = figure.crop(bbox)

    coverage = material_coverage(figure)
    native, native_labels = _native(figure, coverage, variant.native_rows, variant.hard_alpha)

    if variant.palette == "ramps":
        native = _quantise_ramps(native, native_labels, variant.colors)
    else:
        native = _quantise_medcut(native, variant.colors)

    texture_width = max(1, round(native.width * TEXTURE_BODY_HEIGHT / native.height))
    return native.resize((texture_width, TEXTURE_BODY_HEIGHT), Image.Resampling.NEAREST)


def register(figure: Image.Image) -> Image.Image:
    canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE))
    canvas.alpha_composite(
        figure, ((FRAME_SIZE - figure.width) // 2, FOOT_Y - TEXTURE_BODY_HEIGHT)
    )
    return canvas


# ---------------------------------------------------------------------------
# Sheets
# ---------------------------------------------------------------------------


def screen_plate() -> Image.Image:
    """The office plate scaled so one output pixel is one screen pixel at 13%."""
    plate = Image.open(OFFICE_PLATE).convert("RGBA")
    size = (round(plate.width * PLATE_TO_SCREEN), round(plate.height * PLATE_TO_SCREEN))
    # Backgrounds are .linear filtered at runtime (GameArt.swift), so LANCZOS here.
    return plate.resize(size, Image.Resampling.LANCZOS)


def office_tile(frame: Image.Image, plate: Image.Image) -> Image.Image:
    root_x = round(PLATE_ROOT[0] * PLATE_TO_SCREEN)
    root_y = round(PLATE_ROOT[1] * PLATE_TO_SCREEN)
    half = TILE_SCREEN // 2
    tile = plate.crop((root_x - half, root_y - half, root_x + half, root_y + half)).copy()

    centre_x, centre_y = half, half
    shadow = Image.new("RGBA", tile.size)
    shadow_w = round(SPRITE_SCREEN_PX * 0.105)
    shadow_h = round(SPRITE_SCREEN_PX * 0.039)
    ImageDraw.Draw(shadow).ellipse(
        (centre_x - shadow_w, centre_y - shadow_h, centre_x + shadow_w, centre_y + shadow_h),
        fill=(0, 0, 0, 88),
    )
    tile.alpha_composite(shadow)

    # Characters are .nearest filtered at runtime; foot pivot from the node anchor.
    display = frame.resize((SPRITE_SCREEN_PX, SPRITE_SCREEN_PX), Image.Resampling.NEAREST)
    top = centre_y - round(SPRITE_SCREEN_PX * (1 - FOOT_ANCHOR))
    tile.alpha_composite(display, (centre_x - SPRITE_SCREEN_PX // 2, top))
    return tile


def labelled(tile: Image.Image, text: str, label_height: int = 30) -> Image.Image:
    block = Image.new("RGBA", (tile.width, tile.height + label_height), (18, 18, 18, 255))
    block.alpha_composite(tile.convert("RGBA"), (0, 0))
    ImageDraw.Draw(block).text((6, tile.height + 9), text, fill=(230, 230, 230, 255))
    return block


def zoom_tile(frame: Image.Image, zoom: int = 3) -> Image.Image:
    display = frame.resize((SPRITE_SCREEN_PX, SPRITE_SCREEN_PX), Image.Resampling.NEAREST)
    # Threshold above the alpha-1 atlas corner sentinels, which otherwise make
    # the bbox the whole canvas on shipped frames.
    bbox = display.getchannel("A").point(lambda v: 255 if v >= 16 else 0).getbbox()
    crop = display.crop(bbox)
    crop = crop.resize((crop.width * zoom, crop.height * zoom), Image.Resampling.NEAREST)
    tile = Image.new("RGBA", (crop.width + 20, crop.height + 20), (30, 30, 34, 255))
    tile.alpha_composite(crop, (10, 10))
    return tile


def grid(tiles: list[Image.Image], columns: int) -> Image.Image:
    width = max(tile.width for tile in tiles)
    height = max(tile.height for tile in tiles)
    rows = (len(tiles) + columns - 1) // columns
    sheet = Image.new("RGBA", (width * columns, height * rows), (18, 18, 18, 255))
    for index, tile in enumerate(tiles):
        x = (index % columns) * width + (width - tile.width) // 2
        y = (index // columns) * height
        sheet.alpha_composite(tile, (x, y))
    return sheet


SHIPPED_FRAME = (
    ROOT / "RainShadow Shared/Resources/Art/Atlases/VossIdle.atlas/voss_standing_idle_sw_00.png"
)


def reference_tiles() -> list[Image.Image]:
    """BG:EE references staged at the same body height the variants render at."""
    tiles: list[Image.Image] = []

    # A real BG asset at native size and 1-bit alpha: the honest answer to
    # "how chunky is a BG sprite at play scale".
    native = Image.open(BGEE_REFS / "bgee_avatar_color_slots_paperdoll.png").convert("RGBA")
    scale = BODY_SCREEN_PX / native.height
    scaled = native.resize(
        (max(1, round(native.width * scale)), round(native.height * scale)),
        Image.Resampling.NEAREST,
    )
    tile = Image.new("RGBA", (TILE_SCREEN, TILE_SCREEN), (25, 25, 28, 255))
    tile.alpha_composite(scaled, ((TILE_SCREEN - scaled.width) // 2, (TILE_SCREEN - scaled.height) // 2))
    tiles.append(labelled(tile, "REF  native BG asset, 1-bit alpha, at play body height"))

    for name in ("bgee_avatar_green_robe.png", "bgee_avatar_red_tunic_fighter.png"):
        ref = Image.open(BGEE_REFS / name).convert("RGBA")
        # Tight zoom crops: scaling the crop a little above body height lands the
        # figure near play scale. Approximate — these are screenshots, not assets.
        scale = (BODY_SCREEN_PX * 1.25) / ref.height
        ref = ref.resize(
            (max(1, round(ref.width * scale)), max(1, round(ref.height * scale))),
            Image.Resampling.LANCZOS,
        )
        tile = Image.new("RGBA", (TILE_SCREEN, TILE_SCREEN), (25, 25, 28, 255))
        tile.alpha_composite(ref, ((TILE_SCREEN - ref.width) // 2, (TILE_SCREEN - ref.height) // 2))
        tiles.append(labelled(tile, f"REF  {name.split('_', 2)[2].replace('.png', '')}"))
    return tiles


# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------


def measure(frame: Image.Image) -> dict[str, float]:
    pixels = np.asarray(frame)
    alpha = pixels[..., 3]
    visible = alpha > 0
    gated = alpha >= 16  # the threshold the Swift gates use
    ys, xs = np.nonzero(gated)
    opaque = pixels[alpha == 255][:, :3]
    luma = opaque.mean(axis=1) if len(opaque) else np.array([0.0])

    head_rows = ys.min() + max(1, round((ys.max() - ys.min() + 1) * 0.15))
    head = pixels[ys.min():head_rows]
    head_opaque = head[head[..., 3] == 255][:, :3]

    return {
        "body_h": float(ys.max() - ys.min() + 1),
        "foot_y": float(ys.max()),
        "fully_opaque_pct": 100.0 * (alpha == 255).sum() / max(1, visible.sum()),
        "colours": float(len(np.unique(opaque, axis=0))) if len(opaque) else 0.0,
        "head_colours": float(len(np.unique(head_opaque, axis=0))) if len(head_opaque) else 0.0,
        "luma_std": float(luma.std()),
    }


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    print(
        f"Play scale: body {BODY_SCREEN_PX:.1f}px of a {VIEWPORT_HEIGHT}px viewport "
        f"({100 * BODY_SCREEN_PX / VIEWPORT_HEIGHT:.1f}%), sprite node {SPRITE_SCREEN_PX}px, "
        f"plate scaled {PLATE_TO_SCREEN:.4f}"
    )
    print(f"Subject: {SUBJECT.relative_to(ROOT)}\n")

    source = extract_figure(SUBJECT)
    plate = screen_plate()

    play_tiles: list[Image.Image] = []
    zoom_tiles: list[Image.Image] = []
    rows: list[tuple[str, dict[str, float]]] = []

    # The true control: what is on disk today. Variant A reruns the crunch on the
    # staging master and so skips v12's identity/wardrobe lock — close, but not
    # the shipped bake. Compare against this, not against A.
    shipped = Image.open(SHIPPED_FRAME).convert("RGBA")
    play_tiles.append(labelled(office_tile(shipped, plate), "SHIPPED  VossIdle sw_00 on disk"))
    zoom_tiles.append(labelled(zoom_tile(shipped), "SHIPPED  VossIdle sw_00 on disk"))
    rows.append(("SHIPPED  VossIdle sw_00 on disk", measure(shipped)))

    for variant in VARIANTS:
        prepared = soften(source, variant.contrast)
        # v12 order: soften -> register (crunch + place) -> identity lock. Applying
        # the lock here too holds face/coat grade constant across variants, so the
        # sheets compare raster density, edge and palette rather than colour drift.
        frame = v12.identity_wardrobe_lock(register(crunch_candidate(prepared, variant)))
        frame.save(OUTPUT / f"v02_variant_{variant.key}.png", optimize=True)
        play_tiles.append(labelled(office_tile(frame, plate), variant.label))
        zoom_tiles.append(labelled(zoom_tile(frame), variant.label))
        rows.append((variant.label, measure(frame)))

    play_tiles.extend(reference_tiles())

    grid(play_tiles, columns=3).convert("RGB").save(
        OUTPUT / "qa_playscale_sheet_v02.png", optimize=True
    )
    grid(zoom_tiles, columns=3).convert("RGB").save(
        OUTPUT / "qa_zoom_sheet_v02.png", optimize=True
    )

    header = f"{'variant':<40} {'body':>5} {'foot':>5} {'opaque%':>8} {'cols':>5} {'head':>5} {'luma sd':>8}"
    print(header)
    print("-" * len(header))
    for label, m in rows:
        print(
            f"{label:<40} {m['body_h']:>5.0f} {m['foot_y']:>5.0f} {m['fully_opaque_pct']:>8.1f} "
            f"{m['colours']:>5.0f} {m['head_colours']:>5.0f} {m['luma_std']:>8.1f}"
        )
    print(
        "\nGates: body must be 198...202, foot row must be 433."
        "\nReference: a real BG paperdoll asset measures 100% opaque, luma sd 45.7."
    )
    print(f"\nWrote {OUTPUT.relative_to(ROOT)}: {len(VARIANTS)} variants + 2 sheets")


if __name__ == "__main__":
    main()

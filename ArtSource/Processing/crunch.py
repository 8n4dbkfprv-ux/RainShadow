#!/usr/bin/env python3
"""The V14 BGEE crunch: one parameterised raster post-process for every installer.

Before this module the crunch existed five times — `pixelize_figure` (V3),
`pixelize_figure_v7`, `pixelize_shared` (desk NE, with its own fixed-scale
variant), and the A/B study's copy — monkey-patched onto
`process_pre_rendered_characters_v3.pixelize_figure` by each installer in turn.
Everything now routes through `crunch()`.

What V14 changes against V7, and why (see Documentation/PaperdollBGEESpriteRedoPlanV14.md):

1. **1-bit silhouette.** Classic Infinity Engine BAM v1 stores no semi-transparent
   pixels; BG:EE added palette alpha only for UI and spell icons, not creature
   animations. V7 frames were only ~70% fully opaque, and nearest-upscaling the
   soft remainder smeared a 2.5px haze around every figure.
2. **Per-material shade ramps.** BG avatar palettes are built as per-material
   gradients, not one global median cut. A global cut allocates entries by pixel
   area, which is why V7 spent ~108 colours on Voss's coat and 19 on his head.
   Skin now gets a protected ramp regardless of how little area it covers.
3. **56 native rows, not 80.** BG1 resolved a standing adult in ~50 rows at the
   same ~13% screen fraction the camera now targets, so V7 was sampling ~1.6x
   finer than the era it imitates.

Selected as variant E of `qa_pixelation_ab_v02.py`, which composites candidates
at the real 13% camera. The 200px texture body, FOOT_Y registration, 512 canvas
and every runtime scale constant are unchanged.
"""

from __future__ import annotations

import os
from dataclasses import dataclass

import numpy as np
from PIL import Image, ImageFilter

import process_pre_rendered_characters_v3 as raster


TEXTURE_BODY_HEIGHT = 200  # unchanged runtime contract

MATERIAL_OTHER, MATERIAL_COAT, MATERIAL_SKIN = 0, 1, 2
MIN_REGION_PX = 6


@dataclass(frozen=True)
class CrunchSpec:
    """One crunch recipe. `V14` is what ships; `V7` reproduces the old bake."""

    native_rows: int
    colors: int
    hard_alpha: bool
    ramp_palette: bool
    contrast: float
    ramp_steps: int = 12


V14 = CrunchSpec(native_rows=56, colors=64, hard_alpha=True, ramp_palette=True, contrast=1.00)
V7 = CrunchSpec(native_rows=80, colors=64, hard_alpha=False, ramp_palette=False, contrast=0.68)

ACTIVE = V14


# ---------------------------------------------------------------------------
# Pre-crunch soften
# ---------------------------------------------------------------------------


def soften(figure: Image.Image, radius: float = 3.4, contrast: float | None = None) -> Image.Image:
    """Drop micro-detail so the crunch matches seated/paperdoll craft density.

    The blur stays — AI-generated masters carry detail a 1998 mesh would not.
    The midtone pull does not: at V7's 0.68 our opaque luma std was 34.8 against
    45.7 on a real BG paperdoll asset, and washed-out value contrast is exactly
    what makes BG2-era avatars read as coloured blobs next to BG1's.
    """
    if contrast is None:
        contrast = ACTIVE.contrast
    rgba = figure.convert("RGBA")
    rgb = Image.merge("RGB", rgba.split()[:3]).filter(ImageFilter.GaussianBlur(radius=radius))
    if contrast != 1.0:
        arr = np.asarray(rgb).astype(np.float32)
        mean = arr.mean(axis=(0, 1), keepdims=True)
        arr = mean + (arr - mean) * contrast
        rgb = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")
    return Image.merge("RGBA", (*rgb.split(), rgba.split()[-1]))


# ---------------------------------------------------------------------------
# Material segmentation
#
# These live here rather than in the V12 installer because the palette needs
# them and V12 imports this module; keeping them here is what breaks the cycle.
# ---------------------------------------------------------------------------


def _opaque_body_box(alpha_mask: np.ndarray) -> tuple[int, int, int, int] | None:
    ys, xs = np.where(alpha_mask)
    if len(xs) == 0:
        return None
    return int(ys.min()), int(ys.max()), int(xs.min()), int(xs.max())


def _coat_mask(rgb: np.ndarray, alpha_mask: np.ndarray) -> np.ndarray:
    """Opaque brown wardrobe (coat/vest), including darker folds."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    lum = (r + g + b) / 3.0
    return (
        alpha_mask
        & (r > b + 4)
        & (r > 28)
        & (r < 210)
        & (lum > 22)
        & (lum < 175)
        & (g < r + 8)
        & ((r - g) > -2)
    )


def _skin_mask(rgb: np.ndarray, alpha_mask: np.ndarray) -> np.ndarray:
    """Face/hand skin: warm mid-high luminance, not coat brown."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    lum = (r + g + b) / 3.0
    return (
        alpha_mask
        & (r > g)
        & (g > b)
        & (r > 70)
        & (lum > 55)
        & (lum < 210)
        & ((r - b) > 18)
        & ((r - b) < 110)
        & ((r - g) < 55)
        & ~((lum < 95) & ((r - b) > 40) & (r < 130))
    )


def _face_roi_mask(alpha_mask: np.ndarray) -> np.ndarray:
    """Upper silhouette band where the head/face lives on foot-registered cells."""
    box = _opaque_body_box(alpha_mask)
    out = np.zeros_like(alpha_mask, dtype=bool)
    if box is None:
        return out
    y0, y1, x0, x1 = box
    h = max(1, y1 - y0 + 1)
    w = max(1, x1 - x0 + 1)
    fy1 = y0 + max(2, int(h * 0.30))
    fx0 = x0 + int(w * 0.15)
    fx1 = x0 + max(fx0 + 1, int(w * 0.85))
    out[y0:fy1, fx0:fx1] = alpha_mask[y0:fy1, fx0:fx1]
    return out


def _coat_roi_mask(alpha_mask: np.ndarray) -> np.ndarray:
    """Torso band used for play-scale coat measurement (excludes head/feet)."""
    box = _opaque_body_box(alpha_mask)
    out = np.zeros_like(alpha_mask, dtype=bool)
    if box is None:
        return out
    y0, y1, x0, x1 = box
    h = max(1, y1 - y0 + 1)
    w = max(1, x1 - x0 + 1)
    cy0 = y0 + int(h * 0.28)
    cy1 = y0 + max(cy0 + 1, int(h * 0.72))
    cx0 = x0 + int(w * 0.12)
    cx1 = x0 + max(cx0 + 1, int(w * 0.88))
    out[cy0:cy1, cx0:cx1] = alpha_mask[cy0:cy1, cx0:cx1]
    return out


def material_coverage(figure: Image.Image) -> Image.Image:
    """Segment materials at master resolution and return per-material coverage.

    Two things force this to happen up here rather than on the native raster:
    `_skin_mask` is tuned for master resolution and collapses to single digits on
    a 56-row figure, and `_coat_mask` is broad enough (it has to catch shaded
    folds) that warm skin satisfies every one of its terms — so skin is taken
    inside the head band first and the coat gets what is left, the same way V12
    pairs each colour mask with an ROI band.

    Returned as an RGB coverage image so it can be *area*-resampled alongside the
    figure; point-sampling a 4%-area region through a 20x reduction loses it.
    """
    pixels = np.asarray(figure.convert("RGBA"))
    rgb = pixels[..., :3].astype(np.int16)
    alpha_mask = pixels[..., 3] > 0

    skin = _skin_mask(rgb, alpha_mask) & _face_roi_mask(alpha_mask)
    coat = _coat_mask(rgb, alpha_mask) & ~skin
    other = alpha_mask & ~coat & ~skin

    coverage = np.zeros((*alpha_mask.shape, 3), dtype=np.uint8)
    coverage[..., MATERIAL_OTHER] = np.where(other, 255, 0)
    coverage[..., MATERIAL_COAT] = np.where(coat, 255, 0)
    coverage[..., MATERIAL_SKIN] = np.where(skin, 255, 0)
    return Image.fromarray(coverage, "RGB")


def _labels_from_coverage(coverage: Image.Image) -> np.ndarray:
    return np.asarray(coverage).argmax(axis=2).astype(np.uint8)


# ---------------------------------------------------------------------------
# Material separation
#
# A BG:EE avatar separates its materials by hue as well as value. Ours does not:
# every band of Voss sits at R:G:B ≈ 1 : 0.68 : 0.39, so he reads as one tan mass.
# The wardrobe locks are the reason it stays that way once a master lands, so they
# need a way to ask "does this frame actually have separation worth preserving?".
# ---------------------------------------------------------------------------

HUE_SPREAD_FLOOR = 0.18   # weakest BG:EE reference (green_robe, a monk in one robe)
HUE_SPREAD_TARGET = 0.45  # townsfolk 0.485; red tunic 0.948; mage robes 1.966

#: GDD §4.2 wardrobe against the §5.3 noir palette. Targets for per-material
#: grading, replacing the single seated-coat ratio the locks used to stamp.
WARDROBE = {
    "shirt": (206, 195, 170),      # old-paper cream
    "skin": (172, 126, 96),        # warm mid tan
    "waistcoat": (156, 119, 47),   # mustard ochre
    "coat": (112, 94, 60),         # olive-brown overcoat
    "tie": (54, 70, 54),           # muted forest green
    "shoes": (78, 55, 37),         # scuffed dark leather
    "trousers": (58, 56, 62),      # neutral charcoal
    "hair": (58, 45, 37),          # dark cool brown
}


def _colour_centroids(pixels: np.ndarray, k: int = 6, iterations: int = 15):
    if len(pixels) < k:
        return pixels, np.ones(max(1, len(pixels))) / max(1, len(pixels))
    rng = np.random.default_rng(0)
    seeds = pixels[rng.choice(len(pixels), k, replace=False)].astype(np.float64)
    labels = np.zeros(len(pixels), dtype=int)
    for _ in range(iterations):
        labels = ((pixels[:, None, :] - seeds[None]) ** 2).sum(2).argmin(1)
        for index in range(k):
            if (labels == index).any():
                seeds[index] = pixels[labels == index].mean(0)
    weights = np.array([(labels == i).mean() for i in range(len(seeds))])
    order = np.argsort(seeds.mean(1))
    return seeds[order], weights[order]


def material_hue_spread(image: Image.Image, sample_cap: int = 8000) -> float:
    """How far apart a figure's materials sit in hue, ignoring brightness.

    Clusters the body colours and returns the largest pairwise distance between
    cluster centroids in (G/R, B/R) space, counting only clusters covering at
    least 8% of the figure — a handful of deep-shadow pixels sit near black where
    those ratios are numerically unstable, and one such outlier is enough to make
    a monochrome frame look separated.

    Calibrated against `ArtSource/References/BGEE/bgee_avatar_*.png`: 0.178 to
    1.966. Voss's standing frames measure 0.04–0.05.
    """
    rgba = np.asarray(image.convert("RGBA"))
    pixels = rgba[..., :3][rgba[..., 3] >= 128].astype(np.float64)
    pixels = pixels[pixels.mean(1) > 25]
    if len(pixels) < 64:
        return 0.0
    pixels = pixels[:: max(1, len(pixels) // sample_cap)]
    seeds, weights = _colour_centroids(pixels)
    solid = weights >= 0.08
    if solid.sum() < 2:
        solid = weights >= weights.max() * 0.5
    hue = np.stack([seeds[:, 1] / np.maximum(seeds[:, 0], 1),
                    seeds[:, 2] / np.maximum(seeds[:, 0], 1)], axis=1)[solid]
    return max(
        float(np.linalg.norm(hue[i] - hue[j]))
        for i in range(len(hue))
        for j in range(len(hue))
    )


#: Arms wardrobe preservation in the colour locks. **Off by default and it must
#: stay off until separated masters actually land.** Today's masters are
#: monochrome, and letting the locks decide per frame is not safe on them: deep
#: shadow, the chair and keying noise push individual cells over the floor, which
#: silently diverged 86 of 233 frames when this was auto-detected. Flipping it is
#: a deliberate act that goes with a master regeneration.
#:
#: Set here, or export RAINSHADOW_PRESERVE_WARDROBE=1 for a one-off install.
PRESERVE_WARDROBE = os.environ.get("RAINSHADOW_PRESERVE_WARDROBE", "") not in ("", "0")


def has_material_separation(image: Image.Image) -> bool:
    """True when a frame carries wardrobe hue variety the locks must not flatten.

    Both conditions have to hold: preservation is armed, *and* this particular
    frame has something to preserve. The second half matters even once armed —
    a rear facing is legitimately all coat and trousers, and holding it to the
    seated grade is the right thing to do.
    """
    return PRESERVE_WARDROBE and material_hue_spread(image) >= HUE_SPREAD_FLOOR


def harden_alpha(image: Image.Image, threshold: int = 128) -> Image.Image:
    """Re-impose the 1-bit silhouette on a frame composed *after* the crunch.

    Anything that blends two crunched cells — the walk cycle's interpolated
    pass-position frames, for one — produces a weighted alpha along the band
    where the two silhouettes disagree, which puts the soft fringe straight back.
    Alpha below 16 is left alone so the alpha-1 atlas corner sentinels survive.
    """
    if not ACTIVE.hard_alpha:
        return image
    rgba = image.convert("RGBA")
    pixels = np.asarray(rgba).copy()
    alpha = pixels[..., 3]
    soft = alpha >= 16
    pixels[..., 3] = np.where(soft, np.where(alpha >= threshold, 255, 0), alpha)
    pixels[(alpha >= 16) & (alpha < threshold)] = 0
    return Image.fromarray(pixels, "RGBA")


# ---------------------------------------------------------------------------
# Palettes
# ---------------------------------------------------------------------------


def _quantise_medcut(native: Image.Image, colors: int) -> Image.Image:
    """V7 behaviour: one global ramp built from opaque figure pixels only."""
    alpha = native.getchannel("A")
    pixels = np.asarray(native)
    opaque = pixels[pixels[..., 3] > 0][:, :3]
    if len(opaque) == 0:
        return native
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


def _quantise_material_clusters(native: Image.Image, spec: CrunchSpec) -> Image.Image:
    """Per-material ramps with the materials found by colour, not by heuristic.

    `_coat_mask` was written for a Voss who was monochrome brown, so it is broad
    enough to swallow the whole figure: on a master that actually has a wardrobe
    it claims 87% of the body — coat, waistcoat, shirt, tie *and* trousers — and
    a single 12-step ramp fitted to that mass is dominated by the coat, which
    drags every other garment onto the coat's hue. Measured cost: hue spread
    0.460 down to 0.201 in this one step.

    Clustering the figure's own colours instead gives each material its own ramp
    by construction, whatever the character is wearing. This is nearer to what
    the Infinity Engine did anyway — a BAM carries one gradient per material slot,
    not one palette fitted to the whole avatar.
    """
    pixels = np.asarray(native).copy()
    opaque = pixels[..., 3] > 0
    body = pixels[opaque][:, :3].astype(np.float64)
    if len(body) < 32:
        return native

    groups = max(3, min(8, spec.colors // spec.ramp_steps + 2))
    seeds, _ = _colour_centroids(body, k=groups)
    assignment = ((body[:, None, :] - seeds[None]) ** 2).sum(2).argmin(1)
    steps = max(4, spec.colors // groups)

    out = body.copy()
    for index in range(len(seeds)):
        member = assignment == index
        if int(member.sum()) < MIN_REGION_PX:
            continue
        sample = body[member].astype(np.uint8)
        ramp = _region_ramp(sample, min(steps, max(2, int(member.sum()) // 2)))
        distance = ((sample[:, None, :].astype(np.int32) - ramp[None, :, :]) ** 2).sum(axis=2)
        out[member] = ramp[distance.argmin(axis=1)]

    pixels[opaque, :3] = out.astype(np.uint8)
    return Image.fromarray(pixels, "RGBA")


def _quantise_ramps(native: Image.Image, labels: np.ndarray, spec: CrunchSpec) -> Image.Image:
    """Per-material shade ramps, the way Infinity Engine avatar palettes were built.

    Skin gets a protected ramp however little area it covers — that is the whole
    point, since a global median cut starves the face. Regions that are absent
    degrade instead of failing: the coat mask is tuned for Voss's olive-brown
    overcoat and finds nothing on Lila's emerald dress, and no facing that shows
    the back of a head has any skin at all. Their budget folds into `other`.
    """
    # A figure with a real wardrobe needs materials found by colour; the mask
    # heuristics below only make sense on a monochrome one.
    if PRESERVE_WARDROBE and material_hue_spread(native) >= HUE_SPREAD_FLOOR:
        return _quantise_material_clusters(native, spec)

    pixels = np.asarray(native).copy()
    alpha_mask = pixels[..., 3] > 0
    if not alpha_mask.any():
        return native

    named = [
        ("skin", alpha_mask & (labels == MATERIAL_SKIN), spec.ramp_steps),
        ("coat", alpha_mask & (labels == MATERIAL_COAT), spec.ramp_steps),
    ]
    spent = 0
    applied: list[tuple[str, np.ndarray, int]] = []
    for name, mask, steps in named:
        count = int(mask.sum())
        if count < MIN_REGION_PX:
            continue
        # A face a few dozen native pixels across cannot carry 12 distinct
        # shades; asking for more entries than pixels just wastes the budget.
        applied.append((name, mask, max(2, min(steps, count // 2))))
        # Budget by the region's full allocation, not the reduced ask, so a small
        # face does not silently inflate `other` and change the approved look.
        spent += steps

    other = alpha_mask & (labels == MATERIAL_OTHER)
    if int(other.sum()) >= MIN_REGION_PX:
        applied.append(("other", other, max(spec.ramp_steps, spec.colors - spent)))

    for _name, mask, steps in applied:
        sample = pixels[mask][:, :3]
        ramp = _region_ramp(sample, steps)
        # int32: a squared channel delta reaches 65025 and three of them 195075,
        # which silently wraps in int16 and scatters wide-range regions at random.
        distance = ((sample[:, None, :].astype(np.int32) - ramp[None, :, :]) ** 2).sum(axis=2)
        pixels[mask, :3] = ramp[distance.argmin(axis=1)].astype(np.uint8)

    return Image.fromarray(pixels, "RGBA")


# ---------------------------------------------------------------------------
# The crunch
# ---------------------------------------------------------------------------


def _resize_pair(
    figure: Image.Image, coverage: Image.Image, height: int
) -> tuple[Image.Image, Image.Image]:
    width = max(1, round(figure.width * height / figure.height))
    native = raster.premultiplied_resize(figure, (width, height))
    return native, coverage.resize((width, height), Image.Resampling.BOX)


def _native(
    figure: Image.Image,
    coverage: Image.Image,
    target_rows: int,
    spec: CrunchSpec,
    *,
    crop: bool,
    iterations: int = 4,
) -> tuple[Image.Image, np.ndarray]:
    """Downsample figure and material coverage together to a `target_rows` body.

    Binarising at 50% drops the alpha 16..127 fringe, which shrinks the body by
    about a pixel per side. The Swift gates measure the bbox at alpha >= 16
    (VossSeatScaleTests.alphaThreshold), so a naive binarise would fail the
    198...202 standing-height and footY == 433 contracts by construction.

    Converge on the request height instead, so the *binarised* body is what gets
    normalised to `target_rows`. Each pass re-downsamples from the full-resolution
    figure rather than resampling the binarised raster — rescaling a 1-bit image
    drops rows and columns unevenly, which destabilises measurements taken over
    narrow bands (head width is only ~6 native pixels across).
    """
    if not spec.hard_alpha:
        native, scaled = _resize_pair(figure, coverage, target_rows)
        return native, _labels_from_coverage(scaled)

    request = float(target_rows)
    result: tuple[Image.Image, np.ndarray] | None = None
    for _ in range(iterations):
        native, scaled = _resize_pair(figure, coverage, max(1, round(request)))
        alpha = native.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
        merged = Image.merge("RGBA", (*native.split()[:3], alpha))
        bbox = alpha.getbbox()
        if bbox is None or not crop:
            # Fully transparent cells (the seated-arms compat frames) have nothing
            # to normalise, and arm-layer frames must keep their framing relative
            # to the body rather than be re-cropped onto their own bbox.
            return merged, _labels_from_coverage(scaled)
        result = (merged.crop(bbox), _labels_from_coverage(scaled.crop(bbox)))
        if result[0].height == target_rows:
            return result
        request *= target_rows / result[0].height

    assert result is not None
    return result


def finalise(frame: Image.Image) -> Image.Image:
    """Re-impose the palette *after* colour grading, and restore value contrast.

    In the Infinity Engine the palette is the sprite: a BAM carries its ramps and
    nothing regrades it afterwards. Our installers do the opposite — they crunch
    to 64 entries and then run `identity_wardrobe_lock` / `seated_authority_lock`
    over the result to hold every clip to the seated desk grade. Those are
    continuous multiplies, so the shipped frame came out with ~235 distinct
    colours instead of 64, and its value range compressed: a graded V14 idle
    measured luma sd 31.4 against 39.7 for the same frame straight out of the
    crunch.

    So the ramps are re-applied here, last, and the shipped frame really does
    carry a per-material 64-entry palette instead of a continuously graded one.

    This deliberately does *not* try to claw back the value contrast the grading
    costs. An earlier version expanded contrast about each region's mean first,
    which raised luma sd from ~31 to ~36 but pushed Voss's charcoal trousers into
    saturated navy and shifted Lila's emerald dress toward olive — the grading is
    where the contrast goes, and re-expanding afterwards is not the place to fix
    it. See PaperdollBGEESpriteRedoPlanV14.md for the measured numbers.
    """
    rgba = frame.convert("RGBA")
    pixels = np.asarray(rgba)
    if int((pixels[..., 3] >= 128).sum()) < 32:
        return frame  # transparent compat cells have no palette to impose

    labels = _labels_from_coverage(material_coverage(rgba))
    return _quantise_ramps(rgba, labels, ACTIVE)


def crunch(
    figure: Image.Image,
    spec: CrunchSpec | None = None,
    *,
    crop_to_alpha: bool = True,
    reference_height: int | None = None,
) -> Image.Image:
    """Crunch one figure to the 200px texture body.

    `reference_height` gives a clip a fixed source-to-native scale instead of
    normalising every frame to a full standing body — the desk chain needs it so
    crouched sit/stand cells stay shorter than the standing endpoint rather than
    each being blown up to full height.
    """
    if spec is None:
        spec = ACTIVE

    pixels = np.asarray(figure.convert("RGBA")).copy()
    pixels[pixels[..., 3] < 16] = 0
    figure = Image.fromarray(pixels, "RGBA")
    if crop_to_alpha:
        bbox = figure.getchannel("A").getbbox()
        if bbox is None:
            raise RuntimeError("Generated figure has no opaque subject")
        figure = figure.crop(bbox)

    if reference_height is not None:
        target_rows = max(1, round(figure.height * spec.native_rows / max(1, reference_height)))
    else:
        target_rows = spec.native_rows

    coverage = material_coverage(figure)
    native, labels = _native(figure, coverage, target_rows, spec, crop=crop_to_alpha)

    if spec.ramp_palette:
        native = _quantise_ramps(native, labels, spec)
    else:
        native = _quantise_medcut(native, spec.colors)

    # Nearest back up to the texture contract. With `reference_height` the body
    # is deliberately not `native_rows` tall, so scale by the same ratio rather
    # than snapping height to TEXTURE_BODY_HEIGHT.
    scale = TEXTURE_BODY_HEIGHT / spec.native_rows
    texture_width = max(1, round(native.width * scale))
    texture_height = max(1, round(native.height * scale))
    return native.resize((texture_width, texture_height), Image.Resampling.NEAREST)

#!/usr/bin/env python3
"""The BG:EE crunch: one parameterised raster post-process for every installer.
`ACTIVE` selects the shipped recipe. ``BGEE_V1`` resolves a standing humanoid
at 64 native rows before enlarging it back onto the unchanged 200px/512px
runtime registration. GemRB's IE-format CHMB1 walk avatar measures 52–60
crown-to-foot rows (median 55); 64 is the smallest nearby grid that preserves
Voss's authored planted-foot exchange in all nine directions. The texture
canvas and on-screen body size are deliberately independent from that craft
raster. V15, V14 and V7 remain so older bakes stay reproducible.

Before this module the crunch existed five times — `pixelize_figure` (V3),
`pixelize_figure_v7`, `pixelize_shared` (desk NE, with its own fixed-scale
variant), and the A/B study's copy — monkey-patched onto
`process_pre_rendered_characters_v3.pixelize_figure` by each installer in turn.
Everything now routes through `crunch()`.

The classic constraints retained by BGEE_V1 are:

1. **1-bit silhouette.** Classic Infinity Engine BAM v1 stores no semi-transparent
   pixels; BG:EE added palette alpha only for UI and spell icons, not creature
   animations. V7 frames were only ~70% fully opaque, and nearest-upscaling the
   soft remainder smeared a 2.5px haze around every figure.
2. **Per-material shade ramps.** BG avatar palettes are built as per-material
   gradients, not one global median cut. A global cut allocates entries by pixel
   area, which is why V7 spent ~108 colours on Voss's coat and 19 on his head.
   Skin now gets a protected ramp regardless of how little area it covers.
3. **64 native rows.** The measured CHMB1 walk body spans 52–60 rows from its
   ground anchor to crown (median 55). The four-row guard above that measured
   range preserves RainShadow's denser nine-direction gait; BG:EE zooms and
   filters these pixels rather than turning the source into a 200-row raster.
4. **64 visible colours per clip.** The same reference uses 44–59 nontransparent
   palette indices per frame. Sixty-four material-ramp entries retain that
   budget while leaving room for RainShadow's wardrobe separation.

The 200px texture body, FOOT_Y registration, 512 canvas and every runtime scale
constant are unchanged. They control registration and physical humanoid size;
``native_rows`` controls only the pre-rendered pixel craft.
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
    """One crunch recipe; historical variants remain available for comparisons."""

    native_rows: int
    colors: int
    hard_alpha: bool
    ramp_palette: bool
    contrast: float
    ramp_steps: int = 12
    #: Pre-crunch Gaussian radius. 3.4 was sized for the 56-row grid; a raster
    #: that keeps 200 rows needs far less or it just blurs detail the plate has.
    soften_radius: float = 3.4
    #: Post-raster, pre-palette value expansion about `value_pivot`. RGB is
    #: scaled proportionally to the luma gain, so chroma ratios — what every
    #: wardrobe hue gate measures — are preserved exactly.
    value_contrast: float = 1.0
    #: None pivots each body on its own median luma, so a dark costume widens
    #: about its own exposure instead of being crushed toward black. A fixed
    #: pivot of 120 turned Lila's emerald dress (median luma ~40) into an
    #: unreadable silhouette while leaving bright-shirted Voss looking right.
    value_pivot: float | None = None


#: BGEE_V1 — measured humanoid BAM craft with RainShadow registration unchanged.
#: 64 rows is the smallest stable grid above the measured 52–60-row CHMB1
#: range; 64 colours covers its 44–59 used indices per frame. A modest prefilter
#: removes ImageGen microdetail,
#: while the V15 highlight-only value expansion keeps the small sprite readable
#: without rotating wardrobe chroma. Runtime `.linear` filtering supplies the
#: same zoom softness as BG:EE.
BGEE_V1 = CrunchSpec(
    native_rows=64,
    colors=64,
    hard_alpha=True,
    ramp_palette=True,
    contrast=1.00,
    ramp_steps=12,
    soften_radius=1.8,
    value_contrast=1.35,
)

#: V15 — retired full-density experiment retained for deterministic old bakes.
V15 = CrunchSpec(
    native_rows=200,
    colors=128,
    hard_alpha=True,
    ramp_palette=True,
    contrast=1.00,
    ramp_steps=16,
    soften_radius=1.2,
    value_contrast=1.35,
)
V14 = CrunchSpec(native_rows=56, colors=64, hard_alpha=True, ramp_palette=True, contrast=1.00)
V7 = CrunchSpec(native_rows=80, colors=64, hard_alpha=False, ramp_palette=False, contrast=0.68)

ACTIVE_NAME = "BGEE_V1"
ACTIVE = BGEE_V1


@dataclass(frozen=True)
class ClipPalette:
    """One set of material ramps fitted once and reused by every frame of a clip.

    Without this the ramps are refitted per frame — `_colour_centroids` reseeds
    from that frame's own pixels and `_region_ramp` medium-cuts them — so no two
    frames of an animation can share a palette by construction. Small lighting
    differences between the masters then land on different entries and the
    wardrobe visibly shifts hue and value across a four-frame idle loop.

    Fitting once over the clip's pooled pixels also *suppresses* master drift
    rather than merely not adding to it: every frame snaps to the same entries,
    so a master that rendered a stop darker quantises back onto the clip's shade.
    """

    seeds: np.ndarray
    ramps: tuple[np.ndarray, ...]

    def apply(self, body: np.ndarray) -> np.ndarray:
        """Snap `body` (N,3 float) onto this clip's ramps, by nearest seed."""
        assignment = ((body[:, None, :] - self.seeds[None]) ** 2).sum(2).argmin(1)
        out = body.copy()
        for index, ramp in enumerate(self.ramps):
            member = assignment == index
            if not member.any():
                continue
            sample = body[member].astype(np.int32)
            distance = ((sample[:, None, :] - ramp[None, :, :].astype(np.int32)) ** 2).sum(axis=2)
            out[member] = ramp[distance.argmin(axis=1)]
        return out


# ---------------------------------------------------------------------------
# Pre-crunch soften
# ---------------------------------------------------------------------------


def soften(
    figure: Image.Image, radius: float | None = None, contrast: float | None = None
) -> Image.Image:
    """Drop micro-detail so the crunch matches seated/paperdoll craft density.

    The blur stays — AI-generated masters carry detail a 1998 mesh would not.
    Its radius follows the spec: BGEE_V1 uses 1.8 before the 64-row reduction;
    V14 used 3.4 and V15's full 200-row raster used 1.2.
    The midtone pull does not: at V7's 0.68 our opaque luma std was 34.8 against
    45.7 on a real BG paperdoll asset, and washed-out value contrast is exactly
    what makes BG2-era avatars read as coloured blobs next to BG1's.
    """
    if radius is None:
        radius = ACTIVE.soften_radius
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
    "waistcoat": (156, 119, 48),   # mustard ochre (#9C7730, V14/V16 lock)
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


def _graded_body(body: np.ndarray, spec: CrunchSpec) -> np.ndarray:
    """Expand the value range of (N,3) float body pixels about the spec pivot.

    Each pixel's RGB is scaled by one luma gain, so brightness-normalised RGB —
    what the Swift wardrobe gates and `material_hue_spread` measure — is
    untouched. The target luma is clamped away from 0/255 so per-channel
    clipping (which *would* shift a hue) stays rare.
    """
    if spec.value_contrast == 1.0:
        return body
    luma = body.mean(axis=1)
    pivot = float(np.median(luma)) if spec.value_pivot is None else spec.value_pivot
    # Highlights only. Symmetric expansion was tried twice and both directions
    # of the shadow side failed correctness gates that value moves through:
    # a fixed 120 pivot crushed Lila's dark emerald dress to silhouette, and a
    # median pivot walked charcoal trouser shadows down into the tie's luma
    # window on the rear key (the tie and trousers share near-neutral chroma;
    # only value separates them). The flat top end is also where the AI
    # masters actually lack range against a BG paperdoll, so this is the
    # honest half of the curve.
    expanded = np.minimum(pivot + (luma - pivot) * spec.value_contrast, 247.0)
    target = np.where(luma > pivot, expanded, luma)
    gain = target / np.maximum(luma, 1.0)
    # Cap the gain so no channel can clip at 255. A clipped channel rotates
    # the pixel's chroma — one clipped highlight entry (255,247,176) is what
    # put 24 rear-coat pixels inside the forbidden shirt window on idle N 02.
    # With the cap, post-grade chroma is mathematically identical to source.
    gain = np.minimum(gain, 255.0 / np.maximum(body.max(axis=1), 1.0))
    return np.clip(body * gain[:, None], 0.0, 255.0)


def _grade_value_contrast(native: Image.Image, spec: CrunchSpec) -> Image.Image:
    """Apply `_graded_body` to a native raster, before the palette is fitted.

    This is the "grading before palette" the V14 plan recorded as the missing
    piece: expanding contrast *after* the ramps are imposed either breaks the
    64-entry contract or (inside `finalise`) shifts hues. Here the ramps are
    fitted to the graded pixels, so the shipped palette carries the contrast.
    """
    if spec.value_contrast == 1.0:
        return native
    pixels = np.asarray(native).copy()
    opaque = pixels[..., 3] > 0
    if not opaque.any():
        return native
    body = pixels[opaque][:, :3].astype(np.float64)
    pixels[opaque, :3] = np.rint(_graded_body(body, spec)).astype(np.uint8)
    return Image.fromarray(pixels, "RGBA")


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


#: How far one frame's exposure may be moved to match its clip.
#:
#: Set where the correction stops asking for more: raising this past 0.25 changes
#: nothing, because what is left after that is local contrast rather than a level
#: shift. Across the 112 V20 idle and walk frames the median correction is 2.6%
#: and the 90th percentile 9.9%; only eight frames want more than 12%, and all
#: eight are walk masters that came back visibly mis-exposed against the rest of
#: their own gait (NNW phase 5 alone is 28% brighter than its neighbours).
CLIP_EXPOSURE_LIMIT = 0.25


def normalise_clip_exposure(
    frames: "list[Image.Image]", limit: float | None = None
) -> "tuple[list[Image.Image], list[float]]":
    """Hold every frame of a clip to the clip's own median body exposure.

    A shared palette stops each frame *inventing* its own colours, but it cannot
    stop a master that rendered a stop darker from landing on the darker entries
    of that shared ramp — the entries are common, the distribution over them is
    not. The V20 idle masters vary ~15% in mean value between phases of the same
    loop, which reads as the wardrobe pulsing.

    All three channels are scaled by one factor, so this is exposure only: it
    cannot move a hue, and the wardrobe stays where `PRESERVE_WARDROBE` put it.
    """
    if limit is None:
        limit = CLIP_EXPOSURE_LIMIT

    means: list[float] = []
    for frame in frames:
        rgba = np.asarray(frame.convert("RGBA"))
        body = rgba[..., :3][rgba[..., 3] >= 128]
        means.append(float(body.mean()) if len(body) else 0.0)

    lit = [mean for mean in means if mean > 0]
    if not lit:
        return list(frames), [1.0] * len(frames)
    median = float(np.median(lit))

    out: list[Image.Image] = []
    factors: list[float] = []
    for frame, mean in zip(frames, means):
        if mean <= 0:
            out.append(frame)
            factors.append(1.0)
            continue
        factor = min(1.0 + limit, max(1.0 - limit, median / mean))
        factors.append(factor)
        if factor == 1.0:
            out.append(frame)
            continue
        rgba = np.asarray(frame.convert("RGBA")).astype(np.float64)
        rgba[..., :3] = np.clip(rgba[..., :3] * factor, 0.0, 255.0)
        out.append(Image.fromarray(rgba.astype(np.uint8), "RGBA"))
    return out, factors


def build_clip_palette(
    frames: "list[Image.Image]", spec: CrunchSpec | None = None, sample_cap: int = 24000
) -> ClipPalette | None:
    """Fit one set of material ramps over every frame of a clip, at native scale.

    Sampling is done at `spec.native_rows` because that is the raster the ramps
    are actually imposed on; fitting at master resolution would weight the fit by
    detail the crunch is about to throw away. Returns None when the clip has too
    little body to fit, in which case callers fall back to the per-frame path.
    """
    if spec is None:
        spec = ACTIVE

    pooled: list[np.ndarray] = []
    for frame in frames:
        rgba = frame.convert("RGBA")
        bbox = rgba.getchannel("A").point(lambda value: 255 if value >= 16 else 0).getbbox()
        if bbox is None:
            continue
        cropped = rgba.crop(bbox)
        rows = max(1, spec.native_rows)
        width = max(1, round(cropped.width * rows / cropped.height))
        small = np.asarray(raster.premultiplied_resize(cropped, (width, rows)))
        body = small[..., :3][small[..., 3] >= 128]
        if len(body):
            pooled.append(body)
    if not pooled:
        return None

    body = np.concatenate(pooled).astype(np.float64)
    # Fit the ramps to *graded* pixels: the per-frame crunch grades before it
    # snaps to these entries, and ramps fitted to ungraded values would pull
    # the contrast right back out at the snap.
    body = _graded_body(body, spec)
    if len(body) < 32:
        return None
    if len(body) > sample_cap:
        body = body[:: max(1, len(body) // sample_cap)]

    groups = max(3, min(8, spec.colors // spec.ramp_steps + 2))
    seeds, _ = _colour_centroids(body, k=groups)
    assignment = ((body[:, None, :] - seeds[None]) ** 2).sum(2).argmin(1)
    steps = max(4, spec.colors // groups)

    ramps: list[np.ndarray] = []
    for index in range(len(seeds)):
        member = assignment == index
        count = int(member.sum())
        if count < MIN_REGION_PX:
            # Keep one entry per seed so `ClipPalette.apply` can index by seed:
            # a cluster that is negligible clip-wide still has to map somewhere.
            ramps.append(np.rint(seeds[index]).astype(np.int32).reshape(1, 3))
            continue
        sample = body[member].astype(np.uint8)
        ramps.append(_region_ramp(sample, min(steps, max(2, count // 2))))
    return ClipPalette(seeds=seeds, ramps=tuple(ramps))


def _quantise_material_clusters(
    native: Image.Image, spec: CrunchSpec, palette: ClipPalette | None = None
) -> Image.Image:
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

    if palette is not None:
        pixels[opaque, :3] = palette.apply(body).astype(np.uint8)
        return Image.fromarray(pixels, "RGBA")

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


def _quantise_ramps(
    native: Image.Image,
    labels: np.ndarray,
    spec: CrunchSpec,
    palette: ClipPalette | None = None,
) -> Image.Image:
    """Per-material shade ramps, the way Infinity Engine avatar palettes were built.

    Skin gets a protected ramp however little area it covers — that is the whole
    point, since a global median cut starves the face. Regions that are absent
    degrade instead of failing: the coat mask is tuned for Voss's olive-brown
    overcoat and finds nothing on Lila's emerald dress, and no facing that shows
    the back of a head has any skin at all. Their budget folds into `other`.
    """
    # A figure with a real wardrobe needs materials found by colour; the mask
    # heuristics below only make sense on a monochrome one.
    if palette is not None:
        return _quantise_material_clusters(native, spec, palette)
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


def finalise(frame: Image.Image, palette: ClipPalette | None = None) -> Image.Image:
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
    return _quantise_ramps(rgba, labels, ACTIVE, palette)


def crunch(
    figure: Image.Image,
    spec: CrunchSpec | None = None,
    *,
    crop_to_alpha: bool = True,
    reference_height: int | None = None,
    palette: ClipPalette | None = None,
) -> Image.Image:
    """Crunch one figure to the 200px texture body.

    `reference_height` gives a clip a fixed source-to-native scale instead of
    normalising every frame to a full standing body — the desk chain needs it so
    crouched sit/stand cells stay shorter than the standing endpoint rather than
    each being blown up to full height.

    `palette` holds every frame of a clip to one set of material ramps. Without
    it the ramps are refitted per frame and the wardrobe shifts across a loop;
    see `ClipPalette`.
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
    native = _grade_value_contrast(native, spec)

    if spec.ramp_palette:
        native = _quantise_ramps(native, labels, spec, palette)
    else:
        native = _quantise_medcut(native, spec.colors)

    # Nearest back up to the texture contract. With `reference_height` the body
    # is deliberately not `native_rows` tall, so scale by the same ratio rather
    # than snapping height to TEXTURE_BODY_HEIGHT.
    scale = TEXTURE_BODY_HEIGHT / spec.native_rows
    texture_width = max(1, round(native.width * scale))
    texture_height = max(1, round(native.height * scale))
    return native.resize((texture_width, texture_height), Image.Resampling.NEAREST)

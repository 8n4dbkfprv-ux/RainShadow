#!/usr/bin/env python3
"""Chroma-key and slice RainShadow BG-noir UI V03 masters into runtime PNGs."""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
ASSETS = Path.home() / ".cursor/projects/Users-laurensvanoorschot-Desktop-RainShadow/assets"
GEN = ROOT / "ArtSource/Generated/UI"
RUNTIME = ROOT / "RainShadow Shared/Resources/Art/UI"


def chroma_key(im: Image.Image, key=(0, 255, 0), tol=48.0, soft=16.0) -> Image.Image:
    rgba = np.array(im.convert("RGBA"), dtype=np.float32)
    rgb = rgba[:, :, :3]
    dist = np.linalg.norm(rgb - np.array(key, dtype=np.float32), axis=2)
    alpha = np.clip((dist - tol) / soft * 255.0, 0, 255)
    g, r, b = rgb[:, :, 1], rgb[:, :, 0], rgb[:, :, 2]
    greenish = (g > r + 18) & (g > b + 18) & (g > 40)
    mx, mn = rgb.max(axis=2), rgb.min(axis=2)
    green_dom = (g == mx) & ((g - mn) > 20) & (g > 35)
    alpha = np.where(greenish | green_dom, 0, alpha)
    spill = np.clip(1.0 - dist / (tol + soft + 40.0), 0, 1)
    lum = rgb.mean(axis=2, keepdims=True)
    rgb = rgb * (1.0 - spill[..., None] * 0.85) + lum * (spill[..., None] * 0.85)
    rgb = np.where(alpha[..., None] < 8, 0, rgb)
    return Image.fromarray(np.dstack([rgb, alpha]).astype(np.uint8), "RGBA")


def trim_alpha(im: Image.Image, threshold: int = 28, pad: int = 2) -> Image.Image:
    a = np.array(im.split()[-1])
    ys, xs = np.where(a > threshold)
    if len(xs) == 0:
        return im
    return im.crop(
        (
            max(0, int(xs.min()) - pad),
            max(0, int(ys.min()) - pad),
            min(im.width, int(xs.max()) + 1 + pad),
            min(im.height, int(ys.max()) + 1 + pad),
        )
    )


def fit_canvas(im: Image.Image, size: tuple[int, int]) -> Image.Image:
    cw, ch = size
    if im.width == 0 or im.height == 0:
        return Image.new("RGBA", size, (0, 0, 0, 0))
    scale = min(cw / im.width, ch / im.height)
    nw = max(1, int(round(im.width * scale)))
    nh = max(1, int(round(im.height * scale)))
    resized = im.resize((nw, nh), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    out.alpha_composite(resized, ((cw - nw) // 2, (ch - nh) // 2))
    return out


def slice_grid(sheet: Image.Image, cols: int, rows: int, inset: float = 0.04) -> list[Image.Image]:
    cw = sheet.width / cols
    rh = sheet.height / rows
    cells: list[Image.Image] = []
    for row in range(rows):
        for col in range(cols):
            x0 = int(col * cw + cw * inset)
            y0 = int(row * rh + rh * inset)
            x1 = int((col + 1) * cw - cw * inset)
            y1 = int((row + 1) * rh - rh * inset)
            cells.append(sheet.crop((x0, y0, x1, y1)))
    return cells


def punch_dark_wells(im: Image.Image, luma_max: float = 42.0) -> Image.Image:
    """Make near-black flat interior wells transparent for overlay frames."""
    rgba = np.array(im.convert("RGBA"), dtype=np.float32)
    rgb = rgba[:, :, :3]
    luma = rgb.mean(axis=2)
    dark = luma < luma_max
    try:
        from scipy import ndimage

        eroded = ndimage.binary_erosion(dark, iterations=2)
        dark = eroded | ((luma < luma_max * 0.55) & (rgba[:, :, 3] > 0))
    except Exception:
        pass
    rgba[:, :, 3] = np.where(dark, 0, rgba[:, :, 3])
    rgba[:, :, :3] = np.where(rgba[:, :, 3:4] < 8, 0, rgba[:, :, :3])
    return Image.fromarray(rgba.astype(np.uint8), "RGBA")


def punch_rect(im: Image.Image, frac: tuple[float, float, float, float]) -> Image.Image:
    """Punch a fractional rect (x, y, w, h) to transparent."""
    rgba = np.array(im.convert("RGBA"), dtype=np.uint8)
    x, y, w, h = frac
    x0 = int(x * im.width)
    y0 = int(y * im.height)
    x1 = int((x + w) * im.width)
    y1 = int((y + h) * im.height)
    rgba[y0:y1, x0:x1, 3] = 0
    rgba[y0:y1, x0:x1, :3] = 0
    return Image.fromarray(rgba, "RGBA")


def fill_rect(im: Image.Image, frac: tuple[float, float, float, float], color: tuple[int, int, int, int]) -> Image.Image:
    out = im.convert("RGBA").copy()
    draw = ImageDraw.Draw(out)
    x, y, w, h = frac
    box = (
        int(x * out.width),
        int(y * out.height),
        int((x + w) * out.width),
        int((y + h) * out.height),
    )
    draw.rectangle(box, fill=color)
    return out


def blank_button_interior(im: Image.Image) -> Image.Image:
    """Cover baked label with a clearly visible medium gunmetal face."""
    # Always use a lifted gunmetal so the plate reads under dark scene lighting.
    color = (92, 94, 98, 255)
    return fill_rect(im, (0.07, 0.20, 0.86, 0.60), color)


def force_grayscale(im: Image.Image) -> Image.Image:
    """Force cold monochrome so chrome matches the approved grayscale icon language."""
    rgba = np.array(im.convert("RGBA"), dtype=np.float32)
    alpha = rgba[:, :, 3:4]
    # Luma with a slight cool bias (favor blue channel) to kill warm parchment/brass.
    luma = 0.22 * rgba[:, :, 0] + 0.55 * rgba[:, :, 1] + 0.23 * rgba[:, :, 2]
    cool = np.clip(luma * 0.97, 0, 255)
    rgb = np.dstack([cool, cool, np.clip(cool * 1.02, 0, 255)])
    return Image.fromarray(np.dstack([rgb, alpha[:, :, 0]]).astype(np.uint8), "RGBA")


def blank_journal_copy(im: Image.Image) -> Image.Image:
    """Cover baked tab/footer copy with cool gray dossier tones (not warm parchment)."""
    out = force_grayscale(im.convert("RGBA"))
    gray_page = (72, 74, 76, 255)
    dark_metal = (28, 29, 31, 255)
    # Top tabs
    out = fill_rect(out, (0.10, 0.03, 0.28, 0.08), gray_page)
    out = fill_rect(out, (0.42, 0.03, 0.28, 0.08), gray_page)
    # Footer chapter band
    out = fill_rect(out, (0.28, 0.88, 0.44, 0.07), gray_page)
    # Close well
    out = fill_rect(out, (0.88, 0.06, 0.07, 0.06), dark_metal)
    return out


def blank_map_bar_copy(im: Image.Image) -> Image.Image:
    """Cover baked title / checkbox labels / WORLD MAP letters."""
    out = force_grayscale(im.convert("RGBA"))
    # Title area
    out = fill_rect(out, (0.02, 0.25, 0.16, 0.50), (8, 8, 10, 255))
    # Labels beside checkboxes
    out = fill_rect(out, (0.28, 0.28, 0.38, 0.44), (8, 8, 10, 255))
    # World map button interior (keep rim)
    out = fill_rect(out, (0.82, 0.22, 0.15, 0.56), (36, 36, 38, 255))
    return out


def finalize_left_rail(im: Image.Image, canvas: tuple[int, int] = (256, 2048)) -> Image.Image:
    """Stretch rail and clip to a uniform vertical silhouette (no black well slabs)."""
    out = stretch_to_canvas(im, canvas)
    a = np.array(out.convert("RGBA"), dtype=np.float32)
    luma = a[:, :, :3].mean(2)
    h, w = a.shape[:2]
    metal = (luma > 40) & (a[:, :, 3] > 100)
    if not metal.any():
        return out
    body = np.where(metal.mean(axis=0) > 0.08)[0]
    x0, x1 = int(body.min()), int(body.max())
    mask = np.zeros((h, w), dtype=np.float32)
    mask[:, x0 : x1 + 1] = 1.0
    inset = int(0.18 * (x1 - x0))
    xi0, xi1 = x0 + inset, x1 - inset
    well_dark = (luma < 28) & (a[:, :, 3] > 80)
    interior = np.zeros_like(well_dark)
    interior[:, xi0:xi1] = well_dark[:, xi0:xi1]
    row_luma = np.where(a[:, :, 3] > 80, luma, np.nan)
    for y in range(h):
        seg = row_luma[y, xi0:xi1]
        if np.nanmean(seg) > 45:
            interior[y, :] = False
    a[:, :, 3] *= mask
    a[:, :, 3] = np.where(interior, 0, a[:, :, 3])
    a[:, :, :3] = np.where(a[:, :, 3:4] < 8, 0, a[:, :, :3])
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def resolve_src(src_name: str) -> Path:
    src = ASSETS / src_name
    if src.exists():
        return src
    alt = ROOT / "assets" / src_name
    if alt.exists():
        return alt
    raise FileNotFoundError(f"Missing generator asset: {src_name}")


def copy_gen(src_name: str, dest: Path) -> Path:
    src = resolve_src(src_name)
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dest)
    return dest


def stretch_to_canvas(im: Image.Image, size: tuple[int, int]) -> Image.Image:
    """Non-uniform stretch so a short rail fills the authored runtime canvas."""
    cw, ch = size
    trimmed = trim_alpha(im)
    if trimmed.width == 0 or trimmed.height == 0:
        return Image.new("RGBA", size, (0, 0, 0, 0))
    resized = trimmed.resize((cw, ch), Image.Resampling.LANCZOS)
    return resized


def process_rail(
    src_name: str,
    gen_name: str,
    runtime_rel: str,
    canvas: tuple[int, int],
    punch_wells: bool = False,
) -> None:
    master = copy_gen(src_name, GEN / gen_name)
    keyed = force_grayscale(chroma_key(Image.open(master)))
    if punch_wells:
        # Left action rail: uniform silhouette + transparent well centers.
        out = finalize_left_rail(trim_alpha(keyed), canvas)
    else:
        out = stretch_to_canvas(keyed, canvas)
    runtime = RUNTIME / runtime_rel
    runtime.parent.mkdir(parents=True, exist_ok=True)
    out.save(runtime)
    print(f"wrote {runtime} ({out.size})")


def process_icon_sheet(
    src_name: str,
    gen_sheet: str,
    cols: int,
    rows: int,
    names: list[str],
    runtime_dir: str,
    canvas: tuple[int, int] = (128, 128),
    grayscale: bool = False,
) -> None:
    master = copy_gen(src_name, GEN / gen_sheet)
    sheet = chroma_key(Image.open(master))
    if grayscale:
        sheet = force_grayscale(sheet)
    cells = slice_grid(sheet, cols, rows)
    assert len(cells) == len(names), f"{src_name}: {len(cells)} != {len(names)}"
    out_dir = RUNTIME / runtime_dir
    out_dir.mkdir(parents=True, exist_ok=True)
    for cell, name in zip(cells, names, strict=True):
        keyed = trim_alpha(cell)
        out = fit_canvas(keyed, canvas)
        path = out_dir / f"{name}.png"
        out.save(path)
        print(f"wrote {path}")


def process_simple(
    src_name: str,
    gen_name: str,
    runtime_rel: str,
    canvas: tuple[int, int] | None = None,
    punch_wells: bool = False,
    post=None,
) -> None:
    master = copy_gen(src_name, GEN / gen_name)
    keyed = force_grayscale(chroma_key(Image.open(master)))
    if post is not None:
        keyed = post(keyed)
    if punch_wells:
        keyed = punch_dark_wells(keyed)
    trimmed = trim_alpha(keyed)
    out = fit_canvas(trimmed, canvas) if canvas else trimmed
    runtime = RUNTIME / runtime_rel
    runtime.parent.mkdir(parents=True, exist_ok=True)
    out.save(runtime)
    print(f"wrote {runtime} ({out.size})")


ACTION_ICONS = [
    "hud_action_menu_v03",
    "hud_action_map_v03",
    "hud_action_journal_v03",
    "hud_action_inventory_v03",
    "hud_action_character_v03",
    "hud_action_leads_v03",
    "hud_action_contacts_v03",
    "hud_action_settings_v03",
    "hud_action_rest_v03",
    "hud_action_help_v03",
    "hud_action_hide_ui_v03",
    "hud_action_clock_v03",
]

PARTY_ICONS = [
    "hud_party_search_v03",
    "hud_party_lantern_v03",
    "hud_party_select_v03",
]

SLOT_SILHOUETTES = [
    "inventory_slot_silhouette_hat_v03",
    "inventory_slot_silhouette_coat_v03",
    "inventory_slot_silhouette_hands_v03",
    "inventory_slot_silhouette_feet_v03",
    "inventory_slot_silhouette_ring_v03",
    "inventory_slot_silhouette_weapon_v03",
    "inventory_slot_silhouette_item_v03",
    "inventory_slot_silhouette_bag_v03",
]

SCROLL_PARTS = [
    ("dialogue_scroll_up_v03", (96, 96)),
    ("dialogue_scroll_down_v03", (96, 96)),
    ("dialogue_scroll_track_v03", (64, 320)),
    # The V03 source handle is compact and nearly square. Keep a tight runtime
    # texture so SpriteKit can scale it uniformly as a compact square handle.
    ("dialogue_scroll_thumb_v03", (72, 72)),
]

# Mac OS 9 Classic shapes + RainShadow noir metal (proportional thumb).
SCROLL_PARTS_V04 = [
    ("dialogue_scroll_up_v04", (96, 96)),
    ("dialogue_scroll_down_v04", (96, 96)),
    ("dialogue_scroll_track_v04", (64, 320)),
]

THUMB_BODY_V06 = ("dialogue_scroll_thumb_v06", (64, 160))
# The grip ships at its exact on-screen size: SpriteKit draws it 1:1 with nearest
# filtering, so the ridges stay crisp instead of blurring like the scaled V06 sheet.
THUMB_GRIP_V08 = "dialogue_scroll_thumb_grip_v08"
GRIP_WIDTH = 24
GRIP_PITCH = 4

# V05 restores the literal Platinum control grammar V04 drifted away from: flat matte
# faces, hard single-pixel bevels, solid (never engraved) triangles, and a plain
# recessed channel in place of the woven-leather track.
SCROLL_PARTS_V05 = [
    ("dialogue_scroll_up_v05", (96, 96)),
    ("dialogue_scroll_down_v05", (96, 96)),
    ("dialogue_scroll_track_v05", (64, 320)),
]
THUMB_BODY_V07 = ("dialogue_scroll_thumb_v07", (64, 160))
THUMB_GRIP_V09 = "dialogue_scroll_thumb_grip_v09"

# System 7 (not Platinum): outlined arrowheads with a light face and dark rim.
# Platinum replaced these with solid black filled triangles — do not draw those.
SCROLL_PARTS_V06 = [
    ("dialogue_scroll_up_v06", (96, 96)),
    ("dialogue_scroll_down_v06", (96, 96)),
    ("dialogue_scroll_up_pressed_v06", (96, 96)),
    ("dialogue_scroll_down_pressed_v06", (96, 96)),
]
SCROLL_BOX_V06 = ("dialogue_scroll_box_v06", (96, 96))
SCROLL_AREA_V06 = ("dialogue_scroll_area_v06", (30, 1024))
SCROLL_AREA_SOLID_V06 = ("dialogue_scroll_area_solid_v06", (30, 1024))
# Native 1× classic Mac glyph, traced from the reference bar; stamped
# nearest-neighbour onto the 96px button (×6). O = outline, F = fill.
# The arrow is an *outlined* head whose base flares into horizontal shoulder wings,
# then a short wide stem — not a Platinum solid triangle and not a narrow long stalk.
SYSTEM7_ARROW_UP = [
    "......O......",  # tip
    ".....OFO.....",
    "....OFFFO....",
    "...OFFFFFO...",
    "..OFFFFFFFO..",
    ".OFFFFFFFFFO.",
    "OOOOFFFFFOOOO",  # shoulder wings: head base flares out, stem carries on
    "...OFFFFFO...",  # stem / handle — 5 wide, 4 rows
    "...OFFFFFO...",
    "...OFFFFFO...",
    "...OOOOOOO...",  # stem base
]
ARROW_OUTLINE = (18, 18, 20, 255)
ARROW_FILL = (168, 170, 174, 255)
ARROW_OUTLINE_PRESSED = (210, 212, 216, 255)
ARROW_FILL_PRESSED = (28, 28, 30, 255)


def pixel_exact_grip(im: Image.Image) -> Image.Image:
    """Rebuild the painted grip so each ridge is one highlight row over one shadow row.

    The generator paints each ridge ~18px tall. Scaling that down to the ~20pt grip
    merges the highlight into the shadow, so the ridges read as smeared grooves. Here
    the brightest and darkest painted row of every ridge is kept verbatim and stacked
    at the runtime pitch, which preserves the generated look at its real size.
    """
    rgba = np.array(im.convert("RGBA"))
    alpha = rgba[:, :, 3]
    luma = rgba[:, :, 0].astype(np.float32)

    rows = np.where((alpha > 40).sum(axis=1) > rgba.shape[1] * 0.2)[0]
    if len(rows) == 0:
        raise ValueError("Grip master has no painted ridges")
    ridges: list[list[int]] = [[int(rows[0])]]
    for y in rows[1:]:
        if y - ridges[-1][-1] <= 2:
            ridges[-1].append(int(y))
        else:
            ridges.append([int(y)])

    columns = np.where((alpha > 40).any(axis=0))[0]
    x0, x1 = int(columns.min()), int(columns.max()) + 1

    height = (len(ridges) - 1) * GRIP_PITCH + 2
    out = np.zeros((height, GRIP_WIDTH, 4), dtype=np.uint8)
    for index, ridge in enumerate(ridges):
        means = np.array([luma[y][alpha[y] > 40].mean() for y in ridge])
        for offset, source_y in enumerate(
            (ridge[int(means.argmax())], ridge[int(means.argmin())])
        ):
            strip = Image.fromarray(rgba[source_y : source_y + 1, x0:x1]).resize(
                (GRIP_WIDTH, 1), Image.Resampling.LANCZOS
            )
            painted = np.array(strip)
            painted[:, :, 3] = 255
            out[index * GRIP_PITCH + offset] = painted
    return Image.fromarray(out, "RGBA")


def harden_rect_silhouette(im: Image.Image, alpha_threshold: int = 140) -> Image.Image:
    """Force a crisp rectangular chrome plate (Mac OS 9 scroller grammar)."""
    rgba = np.array(im.convert("RGBA"))
    mask = rgba[:, :, 3] >= alpha_threshold
    try:
        from scipy import ndimage

        mask = ndimage.binary_closing(mask, iterations=2)
        mask = ndimage.binary_fill_holes(mask)
    except Exception:
        pass
    ys, xs = np.where(mask)
    if len(xs) == 0:
        return im
    y0, y1 = int(ys.min()), int(ys.max()) + 1
    x0, x1 = int(xs.min()), int(xs.max()) + 1
    crop = rgba[y0:y1, x0:x1].copy()
    m = mask[y0:y1, x0:x1]
    crop[~m, 3] = 0
    crop[m, 3] = 255
    return Image.fromarray(crop, "RGBA")


def crop_square_button(im: Image.Image) -> Image.Image:
    """Keep the leading square of a button cell; drop sheet bleed below it."""
    trimmed = trim_alpha(im)
    side = min(trimmed.width, trimmed.height)
    return trimmed.crop((0, 0, side, side))


def _dialogue_v05p_keep_chrome(im: Image.Image) -> Image.Image:
    """Clear fully transparent pixels while preserving the generated soft matte."""
    out = np.array(im.convert("RGBA"))
    transparent = out[:, :, 3] < 8
    out[transparent] = 0
    return Image.fromarray(out, "RGBA")


def _trim_dark_canvas(im: Image.Image, luma_threshold: float = 8.0) -> Image.Image:
    """Trim an ImageGen RGB preview whose removable backdrop is near-black."""
    rgba = np.array(im.convert("RGBA"), dtype=np.float32)
    luma = rgba[:, :, :3].mean(axis=2)
    ys, xs = np.where(luma > luma_threshold)
    if len(xs) == 0:
        return im.convert("RGBA")
    return im.crop(
        (
            int(xs.min()),
            int(ys.min()),
            int(xs.max()) + 1,
            int(ys.max()) + 1,
        )
    ).convert("RGBA")


def _match_dialogue_to_sidebar_luma(im: Image.Image) -> Image.Image:
    """Histogram-match dialogue chrome to the shipped HUD rail material."""
    reference_path = RUNTIME / "HUD/hud_left_rail_plate_v03.png"
    if not reference_path.exists():
        raise FileNotFoundError(f"Missing dialogue material reference: {reference_path}")

    source = np.array(force_grayscale(im), dtype=np.float32)
    reference = np.array(force_grayscale(Image.open(reference_path)), dtype=np.float32)
    source_mask = source[:, :, 3] > 32
    reference_mask = reference[:, :, 3] > 32
    if not source_mask.any() or not reference_mask.any():
        return Image.fromarray(source.astype(np.uint8), "RGBA")

    source_luma = source[:, :, :3].mean(axis=2)
    reference_luma = reference[:, :, :3].mean(axis=2)
    quantiles = np.linspace(0.0, 1.0, 257)
    source_knots = np.quantile(source_luma[source_mask], quantiles)
    reference_knots = np.quantile(reference_luma[reference_mask], quantiles)
    source_knots, unique_indices = np.unique(source_knots, return_index=True)
    reference_knots = reference_knots[unique_indices]
    matched = np.interp(source_luma, source_knots, reference_knots)

    # The HUD art is cold grayscale. A tiny blue lift preserves that established
    # neutral-steel read while removing the generated burgundy/plum cast.
    source[:, :, 0] = matched * 0.98
    source[:, :, 1] = matched * 0.98
    source[:, :, 2] = np.clip(matched, 0, 255)
    source[:, :, :3] = np.clip(source[:, :, :3], 0, 255)
    return Image.fromarray(source.astype(np.uint8), "RGBA")


def _lock_dialogue_alpha(material: Image.Image, mask_source: Image.Image) -> Image.Image:
    """Preserve the approved frame/command alpha geometry byte-for-byte."""
    material_rgba = np.array(material.convert("RGBA"), dtype=np.uint8)
    alpha = np.array(mask_source.convert("RGBA"))[:, :, 3]
    if material_rgba.shape[:2] != alpha.shape:
        raise ValueError(
            "Dialogue material and alpha geometry must have identical dimensions: "
            f"{material_rgba.shape[:2]} vs {alpha.shape}"
        )
    material_rgba[:, :, 3] = alpha
    material_rgba[alpha < 8] = 0
    return Image.fromarray(material_rgba, "RGBA")


def _finish_sidebar_matched_dialogue(
    material: Image.Image,
    alpha_source: Image.Image,
    size: tuple[int, int],
) -> Image.Image:
    """Resize, reference-tone-match, sharpen, then restore the approved alpha."""
    resized = material.convert("RGBA").resize(size, Image.Resampling.LANCZOS)
    # Exclude ImageGen's baked preview backdrop/checkerboard from the histogram.
    # Only pixels surviving the approved geometry mask may influence tone matching.
    masked = _lock_dialogue_alpha(resized, alpha_source)
    # When ImageGen shifts an edge by a pixel or two, its preview backdrop can sit
    # beneath a still-opaque pixel in the approved mask. Restore that tiny sliver
    # from the prior material so checkerboard/black gaps never enter the runtime art.
    masked_rgba = np.array(masked, dtype=np.uint8)
    fallback_rgba = np.array(alpha_source.convert("RGBA"), dtype=np.uint8)
    masked_luma = masked_rgba[:, :, :3].mean(axis=2)
    fallback_luma = fallback_rgba[:, :, :3].mean(axis=2)
    missing_material = (
        (masked_rgba[:, :, 3] > 32)
        & (masked_luma < 12)
        & (fallback_luma >= 12)
    )
    masked_rgba[missing_material, :3] = fallback_rgba[missing_material, :3]
    masked = Image.fromarray(masked_rgba, "RGBA")
    matched = _match_dialogue_to_sidebar_luma(masked)
    rgb = matched.convert("RGB").filter(
        ImageFilter.UnsharpMask(radius=0.9, percent=85, threshold=2)
    )
    sharpened = rgb.convert("RGBA")
    return _lock_dialogue_alpha(sharpened, alpha_source)


def _apply_sidebar_well_texture_to_command(im: Image.Image) -> Image.Image:
    """Replace the command face micrograin with the HUD wells' exact texture scale."""
    reference = np.array(
        force_grayscale(Image.open(RUNTIME / "HUD/hud_left_rail_plate_v03.png")),
        dtype=np.uint8,
    )
    donor_boxes = (
        (101, 321, 165, 385),
        (95, 633, 159, 697),
        (98, 1100, 162, 1164),
        (100, 1715, 164, 1779),
    )
    donor_tiles: list[np.ndarray] = []
    donor_values: list[np.ndarray] = []
    for x0, y0, x1, y1 in donor_boxes:
        crop = reference[y0:y1, x0:x1]
        luma = crop[:, :, :3].mean(axis=2)
        valid = crop[:, :, 3] > 32
        if not valid.all():
            luma = np.where(valid, luma, np.median(luma[valid]))
        donor_values.append(luma[valid])
        donor_tiles.append(
            np.array(
                Image.fromarray(luma.astype(np.uint8), "L").resize(
                    (73, 73), Image.Resampling.LANCZOS
                ),
                dtype=np.float32,
            )
        )

    rgba = np.array(force_grayscale(im), dtype=np.uint8)
    x0, y0, x1, y1 = 20, 23, 1004, 94
    face_h, face_w = y1 - y0, x1 - x0
    pieces: list[np.ndarray] = []
    index = 0
    while sum(piece.shape[1] for piece in pieces) < face_w:
        tile = donor_tiles[index % len(donor_tiles)]
        if (index // len(donor_tiles)) % 2:
            tile = np.fliplr(tile)
        pieces.append(tile)
        index += 1
    field = np.concatenate(pieces, axis=1)[:face_h, :face_w]
    field_blur = np.array(
        Image.fromarray(field.astype(np.uint8), "L").filter(
            ImageFilter.GaussianBlur(radius=12)
        ),
        dtype=np.float32,
    )
    residual = field - field_blur
    rms = float(np.sqrt(np.mean(residual * residual)))
    if rms > 0:
        residual *= 13.0 / rms

    face = rgba[y0:y1, x0:x1]
    face_luma = face[:, :, :3].mean(axis=2)
    base = np.array(
        Image.fromarray(face_luma.astype(np.uint8), "L").filter(
            ImageFilter.GaussianBlur(radius=3)
        ),
        dtype=np.float32,
    )
    candidate = np.clip(base + residual, 0, 255)
    valid_face = face[:, :, 3] > 32
    reference_values = np.concatenate(donor_values)
    quantiles = np.linspace(0.0, 1.0, 257)
    source_knots = np.quantile(candidate[valid_face], quantiles)
    reference_knots = np.quantile(reference_values, quantiles)
    source_knots, unique_indices = np.unique(source_knots, return_index=True)
    reference_knots = reference_knots[unique_indices]
    matched = np.interp(candidate, source_knots, reference_knots)
    face[:, :, 0] = np.clip(matched, 0, 255).astype(np.uint8)
    face[:, :, 1] = np.clip(matched, 0, 255).astype(np.uint8)
    face[:, :, 2] = np.clip(matched + 1, 0, 255).astype(np.uint8)
    rgba[y0:y1, x0:x1] = face
    rgba[rgba[:, :, 3] < 8] = 0
    return Image.fromarray(rgba, "RGBA")


def process_dialogue_noir_v08() -> None:
    """Finish the complete sidebar-matched V08 dialogue frame redo."""
    frame_master = GEN / "Dialogue/dialogue_outer_frame_overlay_v08_gen.png"
    if not frame_master.exists():
        # Prefer the approved no-sunburst master when present.
        alt = GEN / "Dialogue/dialogue_outer_frame_overlay_v08b_gen.png"
        if alt.exists():
            frame_master = alt
        else:
            raise FileNotFoundError(f"Missing V08 dialogue frame master: {frame_master}")

    keyed = force_grayscale(chroma_key(Image.open(frame_master)))
    alpha = Image.fromarray(np.array(keyed)[:, :, 3]).filter(ImageFilter.MinFilter(3))
    rgba = np.array(keyed)
    rgba[:, :, 3] = np.array(alpha)
    rgba[rgba[:, :, 3] < 8] = 0
    trimmed = trim_alpha(Image.fromarray(rgba, "RGBA"), threshold=28, pad=2)
    frame = stretch_to_canvas(trimmed, (1720, 583))
    frame = _dialogue_v05p_keep_chrome(frame)
    frame = _match_dialogue_to_sidebar_luma(frame)
    rgb = frame.convert("RGB").filter(
        ImageFilter.UnsharpMask(radius=0.9, percent=85, threshold=2)
    )
    out = np.array(rgb.convert("RGBA"))
    out[:, :, 3] = np.array(stretch_to_canvas(trimmed, (1720, 583)))[:, :, 3]
    out[out[:, :, 3] < 8] = 0

    # Hard-clear the measured rectangular portrait space (no half-circle nibs).
    # Fractions match DialoguePanelLayout v08 portrait window constants.
    pl, pt, pw, ph = 146, 86, 207, 169
    out[pt : pt + ph, pl : pl + pw] = 0

    frame = Image.fromarray(out, "RGBA")
    frame = _dialogue_v05p_keep_chrome(frame)
    keyed_path = GEN / "Dialogue/dialogue_outer_frame_overlay_v08_keyed.png"
    runtime_path = RUNTIME / "Dialogue/dialogue_outer_frame_overlay_v08.png"
    frame.save(keyed_path)
    runtime_path.parent.mkdir(parents=True, exist_ok=True)
    frame.save(runtime_path)
    print(f"wrote {keyed_path} ({frame.size})")
    print(f"wrote {runtime_path} ({frame.size})")


def process_dialogue_noir_v07() -> None:
    """Build sidebar-material V07/V06 art on the approved V06/V05 geometry."""
    frame_master = GEN / "Dialogue/dialogue_outer_frame_overlay_v07_gen.png"
    frame_alpha_path = RUNTIME / "Dialogue/dialogue_outer_frame_overlay_v06.png"
    if not frame_master.exists() or not frame_alpha_path.exists():
        raise FileNotFoundError(
            f"Missing V07 dialogue frame input: {frame_master} or {frame_alpha_path}"
        )
    frame = _finish_sidebar_matched_dialogue(
        Image.open(frame_master),
        Image.open(frame_alpha_path),
        (1720, 583),
    )
    frame_keyed = GEN / "Dialogue/dialogue_outer_frame_overlay_v07_keyed.png"
    frame.save(frame_keyed)
    frame_runtime = RUNTIME / "Dialogue/dialogue_outer_frame_overlay_v07.png"
    frame_runtime.parent.mkdir(parents=True, exist_ok=True)
    frame.save(frame_runtime)
    print(f"wrote {frame_keyed} ({frame.size})")
    print(f"wrote {frame_runtime} ({frame.size})")

    command_master = GEN / "Dialogue/dialogue_command_button_plate_v06_gen.png"
    command_alpha_path = RUNTIME / "Dialogue/dialogue_command_button_plate_v05.png"
    if not command_master.exists() or not command_alpha_path.exists():
        raise FileNotFoundError(
            f"Missing V06 dialogue command input: {command_master} or {command_alpha_path}"
        )
    command_material = _trim_dark_canvas(Image.open(command_master))
    command = _finish_sidebar_matched_dialogue(
        command_material,
        Image.open(command_alpha_path),
        (1024, 116),
    )
    command = _apply_sidebar_well_texture_to_command(command)
    command_keyed = GEN / "Dialogue/dialogue_command_button_plate_v06_keyed.png"
    command.save(command_keyed)
    command_runtime = RUNTIME / "Dialogue/dialogue_command_button_plate_v06.png"
    command_runtime.parent.mkdir(parents=True, exist_ok=True)
    command.save(command_runtime)
    print(f"wrote {command_keyed} ({command.size})")
    print(f"wrote {command_runtime} ({command.size})")


def process_dialogue_noir_v06() -> None:
    """Build the sparse reference-shaped noir frame and its matching command bar."""
    frame_master = GEN / "Dialogue/dialogue_outer_frame_overlay_v06_keyed.png"
    if not frame_master.exists():
        raise FileNotFoundError(f"Missing keyed dialogue frame master: {frame_master}")
    frame = stretch_to_canvas(trim_alpha(Image.open(frame_master)), (1720, 583))
    frame = _dialogue_v05p_keep_chrome(frame)
    frame_runtime = RUNTIME / "Dialogue/dialogue_outer_frame_overlay_v06.png"
    frame_runtime.parent.mkdir(parents=True, exist_ok=True)
    frame.save(frame_runtime)
    print(f"wrote {frame_runtime} ({frame.size})")

    command_master = GEN / "Dialogue/dialogue_command_button_plate_v05_keyed.png"
    if not command_master.exists():
        raise FileNotFoundError(f"Missing keyed dialogue command master: {command_master}")
    command = stretch_to_canvas(trim_alpha(Image.open(command_master)), (1024, 116))
    command = _dialogue_v05p_keep_chrome(command)
    command_runtime = RUNTIME / "Dialogue/dialogue_command_button_plate_v05.png"
    command_runtime.parent.mkdir(parents=True, exist_ok=True)
    command.save(command_runtime)
    print(f"wrote {command_runtime} ({command.size})")


def process_dialogue() -> None:
    process_dialogue_noir_v08()
    process_dialogue_noir_v07()
    process_dialogue_noir_v06()

    # Overlay contract: metal rails stay opaque; portrait window + text well are
    # transparent so live portrait + SKLabel body text show through (code owns both).
    # V05q is rail-free on the right (no painted scrollbar channel) — continuous blank
    # well; live scroll controls overlay that gutter when needed. Its low 2.95:1 runtime
    # silhouette follows the supplied dialogue reference's geometry while the generated
    # blackened-steel finish remains original RainShadow artwork.
    master = GEN / "Dialogue/dialogue_outer_frame_overlay_v05q_gen.png"
    if not master.exists():
        master = copy_gen(
            "dialogue_outer_frame_overlay_v05q_gen.png",
            master,
        )
    keyed_master = GEN / "Dialogue/dialogue_outer_frame_overlay_v05q_keyed.png"
    keyed = Image.open(keyed_master) if keyed_master.exists() else chroma_key(Image.open(master))
    keyed = trim_alpha(keyed)
    out = stretch_to_canvas(keyed, (1720, 583))
    out = _dialogue_v05p_keep_chrome(out)
    runtime = RUNTIME / "Dialogue/dialogue_outer_frame_overlay_v05.png"
    runtime.parent.mkdir(parents=True, exist_ok=True)
    out.save(runtime)
    print(f"wrote {runtime} ({out.size})")

    # V04: matching noir CONTINUE/END plate; the generated source has no baked label.
    master = GEN / "Dialogue/dialogue_command_button_plate_v04_gen.png"
    if not master.exists():
        master = copy_gen(
            "dialogue_command_button_plate_v04_gen.png",
            master,
        )
    keyed_master = GEN / "Dialogue/dialogue_command_button_plate_v04_keyed.png"
    keyed = Image.open(keyed_master) if keyed_master.exists() else chroma_key(Image.open(master))
    keyed = trim_alpha(keyed)
    out = stretch_to_canvas(keyed, (512, 128))
    # Gently lift the leather face while keeping its generated grain under the live label.
    rgba = np.array(out)
    h, w = rgba.shape[:2]
    y0, y1 = int(0.16 * h), int(0.84 * h)
    x0, x1 = int(0.05 * w), int(0.95 * w)
    face = rgba[y0:y1, x0:x1]
    rgb = face[:, :, :3].astype(np.float32)
    face[:, :, :3] = np.clip(rgb * 0.78 + 52 * 0.22, 18, 130).astype(np.uint8)
    rgba[y0:y1, x0:x1] = face
    out = Image.fromarray(rgba, "RGBA")
    runtime = RUNTIME / "Dialogue/dialogue_command_button_plate_v04.png"
    out.save(runtime)
    print(f"wrote {runtime} ({out.size})")

    master = copy_gen(
        "dialogue_scroll_components_v03c_gen.png",
        GEN / "Dialogue/dialogue_scroll_components_v03_gen.png",
    )
    cells = slice_grid(force_grayscale(chroma_key(Image.open(master))), 2, 2)
    for cell, (name, canvas) in zip(cells, SCROLL_PARTS, strict=True):
        out = fit_canvas(trim_alpha(cell), canvas)
        path = RUNTIME / "Dialogue" / f"{name}.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        out.save(path)
        print(f"wrote {path}")

    master = copy_gen(
        "dialogue_scroll_components_macos9_v04_gen.png",
        GEN / "Dialogue/dialogue_scroll_components_macos9_v04_gen.png",
    )
    cells = slice_grid(force_grayscale(chroma_key(Image.open(master))), 2, 2, inset=0.06)
    # The sheet's 4th cell was a draft thumb; the shipped thumb comes from its own master.
    for idx, (cell, (name, canvas)) in enumerate(
        zip(cells[: len(SCROLL_PARTS_V04)], SCROLL_PARTS_V04, strict=True)
    ):
        if idx < 2:
            out = fit_canvas(crop_square_button(cell), canvas)
        else:
            out = stretch_to_canvas(trim_alpha(cell), canvas)
        path = RUNTIME / "Dialogue" / f"{name}.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        out.save(path)
        print(f"wrote {path}")

    # Thumb body (nine-slice) + fixed grip overlay (never stretched with thumb height).
    body_master = copy_gen(
        "dialogue_scroll_thumb_body_macos9_v05_gen.png",
        GEN / "Dialogue/dialogue_scroll_thumb_body_macos9_v05_gen.png",
    )
    body = harden_rect_silhouette(force_grayscale(chroma_key(Image.open(body_master))))
    body = stretch_to_canvas(body, THUMB_BODY_V06[1])
    arr = np.array(body)
    arr[:, :, 3] = np.where(arr[:, :, 3] >= 128, 255, 0).astype(np.uint8)
    body_path = RUNTIME / "Dialogue" / f"{THUMB_BODY_V06[0]}.png"
    Image.fromarray(arr, "RGBA").save(body_path)
    print(f"wrote {body_path}")

    grip_master = copy_gen(
        "dialogue_scroll_thumb_grip_macos9_v06b_gen.png",
        GEN / "Dialogue/dialogue_scroll_thumb_grip_macos9_v06b_gen.png",
    )
    grip = pixel_exact_grip(force_grayscale(chroma_key(Image.open(grip_master))))
    grip_path = RUNTIME / "Dialogue" / f"{THUMB_GRIP_V08}.png"
    grip.save(grip_path)
    print(f"wrote {grip_path} ({grip.size})")

    process_dialogue_scrollbar_v05()


def process_dialogue_scrollbar_v05() -> None:
    """Ship the V05 Platinum-grammar scrollbar suite."""
    # Style-lock only: the assembled bar is kept as the reference the parts must match.
    copy_gen(
        "dialogue_scrollbar_assembled_macos9_v05_gen.png",
        GEN / "Dialogue/Scrollbar/dialogue_scrollbar_assembled_macos9_v05_gen.png",
    )

    # The v05b pass replaced v05's thick mitred rims with true Platinum hairlines.
    master = copy_gen(
        "dialogue_scroll_components_macos9_v05b_gen.png",
        GEN / "Dialogue/dialogue_scroll_components_macos9_v05b_gen.png",
    )
    # A tight 2% inset: the V05 parts are drawn close to their cell edges, and the 6%
    # crop V04 needed would shave the track's top bevel off.
    cells = slice_grid(force_grayscale(chroma_key(Image.open(master))), 2, 2, inset=0.02)
    # Cell 4 is deliberately empty — the thumb ships from its own master.
    for cell, (name, canvas) in zip(cells[: len(SCROLL_PARTS_V05)], SCROLL_PARTS_V05, strict=True):
        # Every part is authored to fill its canvas edge to edge, so stretching keeps
        # the bevels flush instead of padding them away from the neighbouring part.
        out = stretch_to_canvas(cell, canvas)
        path = RUNTIME / "Dialogue" / f"{name}.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        out.save(path)
        print(f"wrote {path} ({out.size})")

    body_master = copy_gen(
        "dialogue_scroll_thumb_body_macos9_v05c_gen.png",
        GEN / "Dialogue/dialogue_scroll_thumb_body_macos9_v05c_gen.png",
    )
    body = harden_rect_silhouette(force_grayscale(chroma_key(Image.open(body_master))))
    body = stretch_to_canvas(body, THUMB_BODY_V07[1])
    arr = np.array(body)
    arr[:, :, 3] = np.where(arr[:, :, 3] >= 128, 255, 0).astype(np.uint8)
    body_path = RUNTIME / "Dialogue" / f"{THUMB_BODY_V07[0]}.png"
    Image.fromarray(arr, "RGBA").save(body_path)
    print(f"wrote {body_path} ({body.size})")

    grip_master = copy_gen(
        "dialogue_scroll_thumb_grip_macos9_v07_gen.png",
        GEN / "Dialogue/dialogue_scroll_thumb_grip_macos9_v07_gen.png",
    )
    grip = pixel_exact_grip(force_grayscale(chroma_key(Image.open(grip_master))))
    grip_path = RUNTIME / "Dialogue" / f"{THUMB_GRIP_V09}.png"
    grip.save(grip_path)
    print(f"wrote {grip_path} ({grip.size})")

    process_dialogue_scrollbar_system7_v06()


def system7_arrow_glyph(direction: str, scale: int, pressed: bool) -> Image.Image:
    """Build the System 7 outlined arrowhead (not a Platinum solid triangle)."""
    rows = SYSTEM7_ARROW_UP
    if direction == "down":
        rows = list(reversed(rows))
    outline = ARROW_OUTLINE_PRESSED if pressed else ARROW_OUTLINE
    fill = ARROW_FILL_PRESSED if pressed else ARROW_FILL
    h, w = len(rows), len(rows[0])
    native = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = native.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == "O":
                px[x, y] = outline
            elif ch == "F":
                px[x, y] = fill
    return native.resize((w * scale, h * scale), Image.Resampling.NEAREST)


def stamp_system7_arrow(button: Image.Image, direction: str, pressed: bool) -> Image.Image:
    """Stamp a pixel-exact System 7 arrow onto a blank raised/pressed button face."""
    out = button.convert("RGBA")
    # 96px button ≈ 16px System 7 cell × 6.
    scale = max(1, round(out.width / 16))
    glyph = system7_arrow_glyph(direction, scale, pressed)
    # Centred, then biased one native pixel toward the tip's end of the bar.
    x = (out.width - glyph.width) // 2
    centred = (out.height - glyph.height) // 2
    y = centred - scale if direction == "up" else centred + scale
    y = max(scale, min(out.height - glyph.height - scale, y))
    out.alpha_composite(glyph, (x, y))
    return out


def pixel_exact_dither(im: Image.Image, size: tuple[int, int] = (30, 1024)) -> Image.Image:
    """Rebuild the gray-area stipple at exact runtime scale (2pt checker cells).

    A painted dither scaled down merges the two gunmetal values into grey mush, the
    same failure mode as the grip ridges. Sample the two dominant painted values and
    restack them as a crisp checker on the shipped canvas.
    """
    rgba = np.array(force_grayscale(chroma_key(im)).convert("RGBA"))
    alpha = rgba[:, :, 3]
    opaque = alpha > 40
    if not opaque.any():
        raise ValueError("Gray-area master has no painted dither")
    luma = rgba[:, :, 0][opaque].astype(np.float32)
    # Two clusters: darker + lighter gunmetal of the 50% stipple.
    lo = float(np.percentile(luma, 20))
    hi = float(np.percentile(luma, 80))
    if hi - lo < 8:
        lo, hi = max(0, lo - 18), min(255, hi + 18)
    dark = (int(round(lo)),) * 3 + (255,)
    light = (int(round(hi)),) * 3 + (255,)
    w, h = size
    out = np.zeros((h, w, 4), dtype=np.uint8)
    for y in range(h):
        for x in range(w):
            # 2×2 checker cell matches System 7's gray-area pitch at 30pt width.
            cell = ((x // 2) + (y // 2)) & 1
            out[y, x] = light if cell else dark
    # Left/right near-black outlines only — buttons supply the horizontal joints.
    out[:, 0] = (12, 12, 14, 255)
    out[:, -1] = (12, 12, 14, 255)
    return Image.fromarray(out, "RGBA")


def pixel_exact_solid_area(im: Image.Image, size: tuple[int, int] = (30, 1024)) -> Image.Image:
    """Solid disabled gray area (System 7: no dither when content fits)."""
    rgba = np.array(force_grayscale(chroma_key(im)).convert("RGBA"))
    alpha = rgba[:, :, 3]
    opaque = alpha > 40
    if not opaque.any():
        mid = 72
    else:
        mid = int(round(float(rgba[:, :, 0][opaque].mean())))
    w, h = size
    out = np.full((h, w, 4), (mid, mid, mid, 255), dtype=np.uint8)
    out[:, 0] = (12, 12, 14, 255)
    out[:, -1] = (12, 12, 14, 255)
    return Image.fromarray(out, "RGBA")


def process_dialogue_scrollbar_system7_v06() -> None:
    """Ship the System 7 scrollbar suite: outlined arrows, fixed square box, dithered gray area."""
    copy_gen(
        "dialogue_scrollbar_assembled_system7_v06_gen.png",
        GEN / "Dialogue/Scrollbar/dialogue_scrollbar_assembled_system7_v06_gen.png",
    )

    master = copy_gen(
        "dialogue_scroll_components_system7_v06_gen.png",
        GEN / "Dialogue/dialogue_scroll_components_system7_v06_gen.png",
    )
    cells = slice_grid(force_grayscale(chroma_key(Image.open(master))), 2, 2, inset=0.04)
    # Sheet: TL normal, TR normal, BL pressed, BR pressed — blank faces; arrows stamped here.
    specs = [
        (0, "up", False, SCROLL_PARTS_V06[0]),
        (1, "down", False, SCROLL_PARTS_V06[1]),
        (2, "up", True, SCROLL_PARTS_V06[2]),
        (3, "down", True, SCROLL_PARTS_V06[3]),
    ]
    for idx, direction, pressed, (name, canvas) in specs:
        face = stretch_to_canvas(crop_square_button(cells[idx]), canvas)
        out = stamp_system7_arrow(face, direction, pressed)
        path = RUNTIME / "Dialogue" / f"{name}.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        out.save(path)
        print(f"wrote {path} ({out.size})")

    box_master = copy_gen(
        "dialogue_scroll_box_system7_v06_gen.png",
        GEN / "Dialogue/dialogue_scroll_box_system7_v06_gen.png",
    )
    box = harden_rect_silhouette(force_grayscale(chroma_key(Image.open(box_master))))
    box = stretch_to_canvas(box, SCROLL_BOX_V06[1])
    arr = np.array(box)
    arr[:, :, 3] = np.where(arr[:, :, 3] >= 128, 255, 0).astype(np.uint8)
    box_path = RUNTIME / "Dialogue" / f"{SCROLL_BOX_V06[0]}.png"
    Image.fromarray(arr, "RGBA").save(box_path)
    print(f"wrote {box_path} ({box.size})")

    area_master = copy_gen(
        "dialogue_scroll_area_system7_v06_gen.png",
        GEN / "Dialogue/dialogue_scroll_area_system7_v06_gen.png",
    )
    area_img = Image.open(area_master)
    # Left half = dither, right half = solid (generator sheet is side-by-side).
    mid = area_img.width // 2
    dither = pixel_exact_dither(area_img.crop((0, 0, mid, area_img.height)), SCROLL_AREA_V06[1])
    solid = pixel_exact_solid_area(
        area_img.crop((mid, 0, area_img.width, area_img.height)), SCROLL_AREA_SOLID_V06[1]
    )
    dither_path = RUNTIME / "Dialogue" / f"{SCROLL_AREA_V06[0]}.png"
    solid_path = RUNTIME / "Dialogue" / f"{SCROLL_AREA_SOLID_V06[0]}.png"
    dither.save(dither_path)
    solid.save(solid_path)
    print(f"wrote {dither_path} ({dither.size})")
    print(f"wrote {solid_path} ({solid.size})")


def process_hud() -> None:
    # Chrome plates only — keep approved action/party icon sheets untouched.
    process_rail(
        "hud_left_rail_plate_v03e_gen.png",
        "HUD/hud_left_rail_plate_v03_gen.png",
        "HUD/hud_left_rail_plate_v03.png",
        (256, 2048),
        punch_wells=True,
    )
    master = copy_gen(
        "hud_right_rail_plate_v03d_gen.png",
        GEN / "HUD/hud_right_rail_plate_v03_gen.png",
    )
    keyed = force_grayscale(chroma_key(Image.open(master)))
    out = fit_canvas(trim_alpha(keyed), (320, 2048))
    # Compact plate lives in the middle band (matches PortraitBarNode.plateContentRect).
    # Open the portrait well so the live detective photo under the plate shows through.
    # Content band (image y, top-origin): ~0.383–0.617; portrait ~top 4%–50% of content.
    content_top, content_h = 0.383, 0.234
    out = punch_rect(
        out,
        (
            0.10,
            content_top + 0.06 * content_h,
            0.80,
            0.40 * content_h,
        ),
    )
    runtime = RUNTIME / "HUD/hud_right_rail_plate_v03.png"
    runtime.parent.mkdir(parents=True, exist_ok=True)
    out.save(runtime)
    print(f"wrote {runtime} ({out.size})")
    process_simple(
        "hud_portrait_frame_v03c_gen.png",
        "HUD/hud_portrait_frame_v03_gen.png",
        "HUD/hud_portrait_frame_v03.png",
        (1086, 1448),
        punch_wells=True,
    )


def process_inventory() -> None:
    process_simple(
        "inventory_outer_frame_overlay_v03c_gen.png",
        "Inventory/inventory_outer_frame_overlay_v03_gen.png",
        "Inventory/inventory_outer_frame_overlay_v03.png",
        (1960, 1080),
        punch_wells=True,
    )
    process_icon_sheet(
        "inventory_slot_silhouettes_sheet_v03c_gen.png",
        "Inventory/inventory_slot_silhouettes_sheet_v03_gen.png",
        4,
        2,
        SLOT_SILHOUETTES,
        "Inventory",
        (256, 256),
        grayscale=True,
    )


def process_journal_map_common() -> None:
    process_simple(
        "journal_casebook_plate_v03d_gen.png",
        "Journal/journal_casebook_plate_v03_gen.png",
        "Journal/journal_casebook_plate_v03.png",
        (1400, 1600),
        post=blank_journal_copy,
    )
    process_simple(
        "journal_row_marker_v03c_gen.png",
        "Journal/journal_row_marker_v03_gen.png",
        "Journal/journal_row_marker_v03.png",
        (64, 64),
    )
    process_simple(
        "map_chrome_top_bar_v03c_gen.png",
        "Map/map_chrome_top_bar_v03_gen.png",
        "Map/map_chrome_top_bar_v03.png",
        (1920, 96),
        post=blank_map_bar_copy,
    )
    process_simple(
        "ui_close_box_noir_v03c_gen.png",
        "Common/ui_close_box_noir_v03_gen.png",
        "Common/ui_close_box_noir_v03.png",
        (128, 128),
    )


def main() -> None:
    targets = sys.argv[1:] or ["hud", "dialogue", "inventory", "journal"]
    if "hud" in targets:
        process_hud()
    if "dialogue" in targets:
        process_dialogue()
    if "dialogue-noir-v06" in targets:
        process_dialogue_noir_v06()
    if "dialogue-noir-v07" in targets:
        process_dialogue_noir_v07()
    if "dialogue-noir-v08" in targets:
        process_dialogue_noir_v08()
    if "scrollbar" in targets:
        process_dialogue_scrollbar_system7_v06()
    if "inventory" in targets:
        process_inventory()
    if "journal" in targets:
        process_journal_map_common()


if __name__ == "__main__":
    main()

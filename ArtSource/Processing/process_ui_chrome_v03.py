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
    ("dialogue_scroll_thumb_v03", (72, 256)),
]


def process_dialogue() -> None:
    # Overlay contract: metal rails stay opaque; portrait window + text well are
    # transparent so live portrait + SKLabel body text show through (code owns both).
    # Earlier builds left those wells opaque near-black, which buried speech entirely.
    master = copy_gen(
        "dialogue_outer_frame_overlay_v04e_gen.png",
        GEN / "Dialogue/dialogue_outer_frame_overlay_v04_gen.png",
    )
    keyed = force_grayscale(chroma_key(Image.open(master)))
    keyed = trim_alpha(keyed)
    # Flat black wells only (lum ~0–17). Do not use a high luma threshold — dark
    # gunmetal rails sit around 30–80 and must stay opaque as the frame.
    keyed = punch_dark_wells(keyed, luma_max=22.0)
    # Surgical opens for the painted portrait window + main text column (inset so
    # gold/metal rims are not eaten). Fractions match DialoguePanelLayout windows.
    keyed = punch_rect(keyed, (0.062, 0.22, 0.135, 0.50))
    keyed = punch_rect(keyed, (0.255, 0.14, 0.575, 0.72))
    out = stretch_to_canvas(keyed, (1720, 730))
    runtime = RUNTIME / "Dialogue/dialogue_outer_frame_overlay_v04.png"
    runtime.parent.mkdir(parents=True, exist_ok=True)
    out.save(runtime)
    print(f"wrote {runtime} ({out.size})")

    master = copy_gen(
        "dialogue_command_button_plate_v03d_gen.png",
        GEN / "Dialogue/dialogue_command_button_plate_v03_gen.png",
    )
    keyed = force_grayscale(chroma_key(Image.open(master)))
    keyed = blank_button_interior(trim_alpha(keyed))
    out = stretch_to_canvas(keyed, (512, 128))
    # Lift interior so CONTINUE plate reads under dark scene lighting.
    rgba = np.array(out)
    h, w = rgba.shape[:2]
    y0, y1 = int(0.18 * h), int(0.82 * h)
    x0, x1 = int(0.06 * w), int(0.94 * w)
    face = rgba[y0:y1, x0:x1]
    rgb = face[:, :, :3].astype(np.float32)
    face[:, :, :3] = np.clip(rgb * 0.55 + 95 * 0.45, 55, 160).astype(np.uint8)
    rgba[y0:y1, x0:x1] = face
    out = Image.fromarray(rgba, "RGBA")
    runtime = RUNTIME / "Dialogue/dialogue_command_button_plate_v03.png"
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
    if "inventory" in targets:
        process_inventory()
    if "journal" in targets:
        process_journal_map_common()


if __name__ == "__main__":
    main()

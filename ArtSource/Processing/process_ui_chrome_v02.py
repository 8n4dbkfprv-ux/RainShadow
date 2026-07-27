#!/usr/bin/env python3
"""Chroma-key and slice RainShadow BG-noir UI V02 masters into runtime PNGs."""

from __future__ import annotations

import shutil
from pathlib import Path

import numpy as np
from PIL import Image

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


def slice_grid(sheet: Image.Image, cols: int, rows: int, inset: float = 0.03) -> list[Image.Image]:
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


def copy_gen(src_name: str, dest: Path) -> Path:
    src = ASSETS / src_name
    if not src.exists():
        # Fallback: look next to this script's common asset drop zones
        alt = ROOT / "assets" / src_name
        src = alt if alt.exists() else src
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dest)
    return dest


def process_rail(src_name: str, gen_name: str, runtime_rel: str, canvas: tuple[int, int]) -> None:
    master = copy_gen(src_name, GEN / gen_name)
    keyed = chroma_key(Image.open(master))
    out = fit_canvas(trim_alpha(keyed), canvas)
    runtime = RUNTIME / runtime_rel
    runtime.parent.mkdir(parents=True, exist_ok=True)
    out.save(runtime)
    keyed.save(GEN / runtime_rel.replace("/", "_").replace(".png", "_rgba.png"))
    print(f"wrote {runtime} ({out.size})")


def process_icon_sheet(
    src_name: str,
    gen_sheet: str,
    cols: int,
    rows: int,
    names: list[str],
    runtime_dir: str,
    canvas: tuple[int, int] = (128, 128),
) -> None:
    master = copy_gen(src_name, GEN / gen_sheet)
    sheet = Image.open(master)
    cells = slice_grid(sheet, cols, rows)
    assert len(cells) == len(names), f"{src_name}: {len(cells)} != {len(names)}"
    out_dir = RUNTIME / runtime_dir
    out_dir.mkdir(parents=True, exist_ok=True)
    for cell, name in zip(cells, names, strict=True):
        keyed = trim_alpha(chroma_key(cell))
        out = fit_canvas(keyed, canvas)
        path = out_dir / f"{name}.png"
        out.save(path)
        print(f"wrote {path}")


def punch_dark_wells(im: Image.Image, luma_max: float = 38.0) -> Image.Image:
    """Make near-black flat interior wells transparent for overlay frames."""
    rgba = np.array(im.convert("RGBA"), dtype=np.float32)
    rgb = rgba[:, :, :3]
    luma = rgb.mean(axis=2)
    # Preserve bright metal edges; punch only dark recessed wells.
    dark = luma < luma_max
    # Avoid punching thin dark edge pixels that belong to engraving by requiring neighbors dark.
    from scipy import ndimage  # optional; fall back if missing

    try:
        dark = ndimage.binary_erosion(dark, iterations=1) | (
            (luma < luma_max * 0.7) & (rgba[:, :, 3] > 0)
        )
    except Exception:
        pass
    rgba[:, :, 3] = np.where(dark, 0, rgba[:, :, 3])
    rgba[:, :, :3] = np.where(rgba[:, :, 3:4] < 8, 0, rgba[:, :, :3])
    return Image.fromarray(rgba.astype(np.uint8), "RGBA")


def process_simple(
    src_name: str,
    gen_name: str,
    runtime_rel: str,
    canvas: tuple[int, int] | None = None,
    punch_wells: bool = False,
) -> None:
    master = copy_gen(src_name, GEN / gen_name)
    keyed = chroma_key(Image.open(master))
    if punch_wells:
        keyed = punch_dark_wells(keyed)
    trimmed = trim_alpha(keyed)
    out = fit_canvas(trimmed, canvas) if canvas else trimmed
    runtime = RUNTIME / runtime_rel
    runtime.parent.mkdir(parents=True, exist_ok=True)
    out.save(runtime)
    print(f"wrote {runtime} ({out.size})")


ACTION_ICONS = [
    "hud_action_menu_v02",
    "hud_action_map_v02",
    "hud_action_journal_v02",
    "hud_action_inventory_v02",
    "hud_action_character_v02",
    "hud_action_leads_v02",
    "hud_action_contacts_v02",
    "hud_action_settings_v02",
    "hud_action_rest_v02",
    "hud_action_help_v02",
    "hud_action_hide_ui_v02",
    "hud_action_clock_v02",
]

PARTY_ICONS = [
    "hud_party_search_v02",
    "hud_party_lantern_v02",
    "hud_party_select_v02",
]

SLOT_SILHOUETTES = [
    "inventory_slot_silhouette_hat_v02",
    "inventory_slot_silhouette_coat_v02",
    "inventory_slot_silhouette_hands_v02",
    "inventory_slot_silhouette_feet_v02",
    "inventory_slot_silhouette_ring_v02",
    "inventory_slot_silhouette_weapon_v02",
    "inventory_slot_silhouette_item_v02",
    "inventory_slot_silhouette_bag_v02",
]

SCROLL_PARTS = [
    ("dialogue_scroll_up_v02", (96, 96)),
    ("dialogue_scroll_down_v02", (96, 96)),
    ("dialogue_scroll_track_v02", (64, 320)),
    ("dialogue_scroll_thumb_v02", (72, 256)),
]


def process_hud() -> None:
    process_rail(
        "hud_left_rail_plate_v02_gen.png",
        "HUD/hud_left_rail_plate_v02_gen.png",
        "HUD/hud_left_rail_plate_v02.png",
        (256, 2048),
    )
    process_rail(
        "hud_right_rail_plate_v02_gen.png",
        "HUD/hud_right_rail_plate_v02_gen.png",
        "HUD/hud_right_rail_plate_v02.png",
        (320, 2048),
    )
    process_icon_sheet(
        "hud_action_icons_sheet_v02_gen.png",
        "HUD/hud_action_icons_sheet_v02_gen.png",
        3,
        4,
        ACTION_ICONS,
        "HUD",
    )
    process_icon_sheet(
        "hud_party_icons_sheet_v02_gen.png",
        "HUD/hud_party_icons_sheet_v02_gen.png",
        3,
        1,
        PARTY_ICONS,
        "HUD",
    )
    process_simple(
        "hud_portrait_frame_v02_gen.png",
        "HUD/hud_portrait_frame_v02_gen.png",
        "HUD/hud_portrait_frame_v02.png",
        (1086, 1448),
    )


def process_dialogue() -> None:
    process_simple(
        "dialogue_outer_frame_overlay_v03_gen.png",
        "Dialogue/dialogue_outer_frame_overlay_v03_gen.png",
        "Dialogue/dialogue_outer_frame_overlay_v03.png",
        (1720, 730),
        punch_wells=True,
    )
    process_simple(
        "dialogue_command_button_plate_v02_gen.png",
        "Dialogue/dialogue_command_button_plate_v02_gen.png",
        "Dialogue/dialogue_command_button_plate_v02.png",
        (512, 128),
    )
    # Scrollbar sheet 2x2: up, down, track, thumb
    master = copy_gen(
        "dialogue_scroll_components_v02_gen.png",
        GEN / "Dialogue/dialogue_scroll_components_v02_gen.png",
    )
    cells = slice_grid(Image.open(master), 2, 2)
    for cell, (name, canvas) in zip(cells, SCROLL_PARTS, strict=True):
        out = fit_canvas(trim_alpha(chroma_key(cell)), canvas)
        path = RUNTIME / "Dialogue" / f"{name}.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        out.save(path)
        print(f"wrote {path}")


def process_inventory() -> None:
    process_simple(
        "inventory_outer_frame_overlay_v02_gen.png",
        "Inventory/inventory_outer_frame_overlay_v02_gen.png",
        "Inventory/inventory_outer_frame_overlay_v02.png",
        (1960, 1080),
        punch_wells=True,
    )
    process_icon_sheet(
        "inventory_slot_silhouettes_sheet_v02_gen.png",
        "Inventory/inventory_slot_silhouettes_sheet_v02_gen.png",
        4,
        2,
        SLOT_SILHOUETTES,
        "Inventory",
        (256, 256),
    )


def process_journal_common() -> None:
    process_simple(
        "journal_casebook_plate_v02_gen.png",
        "Journal/journal_casebook_plate_v02_gen.png",
        "Journal/journal_casebook_plate_v02.png",
        (1400, 1600),
    )
    process_simple(
        "journal_row_marker_v02_gen.png",
        "Journal/journal_row_marker_v02_gen.png",
        "Journal/journal_row_marker_v02.png",
        (64, 64),
    )
    process_simple(
        "ui_close_box_noir_v02_gen.png",
        "Common/ui_close_box_noir_v02_gen.png",
        "Common/ui_close_box_noir_v02.png",
        (128, 128),
    )


def main() -> None:
    import sys

    targets = sys.argv[1:] or ["hud", "dialogue", "inventory", "journal"]
    if "hud" in targets:
        process_hud()
    if "dialogue" in targets:
        process_dialogue()
    if "inventory" in targets:
        process_inventory()
    if "journal" in targets:
        process_journal_common()


if __name__ == "__main__":
    main()

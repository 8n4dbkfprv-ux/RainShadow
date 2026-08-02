#!/usr/bin/env python3
"""Chroma-key and slice RainShadow inventory UI V04 masters into runtime PNGs."""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ASSETS = Path.home() / ".cursor/projects/Users-laurensvanoorschot-Desktop-RainShadow/assets"
GEN = ROOT / "ArtSource/Generated/UI"
RUNTIME = ROOT / "RainShadow Shared/Resources/Art/UI"

SLOT_SILHOUETTES = [
    "inventory_slot_silhouette_hat_v04",
    "inventory_slot_silhouette_coat_v04",
    "inventory_slot_silhouette_hands_v04",
    "inventory_slot_silhouette_feet_v04",
    "inventory_slot_silhouette_ring_v04",
    "inventory_slot_silhouette_weapon_v04",
    "inventory_slot_silhouette_item_v04",
    "inventory_slot_silhouette_bag_v04",
]

STAT_BADGES = [
    "inventory_stat_badge_defence_v04",
    "inventory_stat_badge_vitality_v04",
    "inventory_stat_badge_resolve_v04",
    "inventory_stat_badge_damage_v04",
]


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


def force_grayscale(im: Image.Image) -> Image.Image:
    rgba = np.array(im.convert("RGBA"), dtype=np.float32)
    alpha = rgba[:, :, 3:4]
    luma = 0.22 * rgba[:, :, 0] + 0.55 * rgba[:, :, 1] + 0.23 * rgba[:, :, 2]
    cool = np.clip(luma * 0.97, 0, 255)
    rgb = np.dstack([cool, cool, np.clip(cool * 1.02, 0, 255)])
    return Image.fromarray(np.dstack([rgb, alpha[:, :, 0]]).astype(np.uint8), "RGBA")


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


def punch_dark_wells(im: Image.Image, luma_max: float = 42.0) -> Image.Image:
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


def punch_badge_centers(im: Image.Image, luma_max: float = 55.0) -> Image.Image:
    """Keep metal ring, clear near-black / chroma interiors for live values."""
    return punch_dark_wells(im, luma_max=luma_max)


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


def scrub_green_spill(im: Image.Image) -> Image.Image:
    """Clear residual chroma without punching legitimate dark gunmetal."""
    rgba = np.array(im.convert("RGBA"), dtype=np.float32)
    g, r, b = rgba[:, :, 1], rgba[:, :, 0], rgba[:, :, 2]
    greenish = (g > r + 25) & (g > b + 25) & (g > 50)
    rgba[:, :, 3] = np.where(greenish, 0, rgba[:, :, 3])
    rgba[:, :, :3] = np.where(rgba[:, :, 3:4] < 8, 0, rgba[:, :, :3])
    return Image.fromarray(rgba.astype(np.uint8), "RGBA")


def process_plate() -> None:
    # Prefer the Metrics-aligned v04b master when present.
    # Wells are authored as chroma green — do not punch dark metal surfaces.
    src_candidates = [
        "inventory_outer_frame_overlay_v04b_gen.png",
        "inventory_outer_frame_overlay_v04_gen.png",
    ]
    src_name = next(name for name in src_candidates if (ASSETS / name).exists() or (ROOT / "assets" / name).exists())
    master = copy_gen(src_name, GEN / "Inventory/inventory_outer_frame_overlay_v04_gen.png")
    keyed = scrub_green_spill(force_grayscale(chroma_key(Image.open(master), tol=55.0, soft=20.0)))
    trimmed = trim_alpha(keyed)
    out = fit_canvas(trimmed, (1960, 1080))
    keyed_path = GEN / "Inventory/inventory_outer_frame_overlay_v04_keyed.png"
    keyed_path.parent.mkdir(parents=True, exist_ok=True)
    out.save(keyed_path)
    runtime = RUNTIME / "Inventory/inventory_outer_frame_overlay_v04.png"
    runtime.parent.mkdir(parents=True, exist_ok=True)
    out.save(runtime)
    print(f"wrote {runtime} ({out.size}) from {src_name}")


def process_slot_frame() -> None:
    master = copy_gen(
        "inventory_slot_frame_v04_gen.png",
        GEN / "Inventory/inventory_slot_frame_v04_gen.png",
    )
    keyed = force_grayscale(chroma_key(Image.open(master)))
    # Keep leather well opaque — only chroma outside the frame is transparent.
    out = fit_canvas(trim_alpha(keyed), (256, 256))
    runtime = RUNTIME / "Inventory/inventory_slot_frame_v04.png"
    out.save(runtime)
    print(f"wrote {runtime}")


def process_silhouettes() -> None:
    master = copy_gen(
        "inventory_slot_silhouettes_sheet_v04_gen.png",
        GEN / "Inventory/inventory_slot_silhouettes_sheet_v04_gen.png",
    )
    sheet = force_grayscale(chroma_key(Image.open(master)))
    cells = slice_grid(sheet, 4, 2, inset=0.05)
    assert len(cells) == len(SLOT_SILHOUETTES)
    out_dir = RUNTIME / "Inventory"
    out_dir.mkdir(parents=True, exist_ok=True)
    for cell, name in zip(cells, SLOT_SILHOUETTES, strict=True):
        out = fit_canvas(trim_alpha(cell), (256, 256))
        path = out_dir / f"{name}.png"
        out.save(path)
        print(f"wrote {path}")


def process_stat_badges() -> None:
    master = copy_gen(
        "inventory_stat_badges_sheet_v04_gen.png",
        GEN / "Inventory/inventory_stat_badges_sheet_v04_gen.png",
    )
    sheet = force_grayscale(chroma_key(Image.open(master)))
    # Sheet order: defence, vitality / resolve, damage
    cells = slice_grid(sheet, 2, 2, inset=0.06)
    assert len(cells) == len(STAT_BADGES)
    # Generator order was TL defence, TR vitality, BL resolve, BR damage — matches STAT_BADGES.
    out_dir = RUNTIME / "Inventory"
    out_dir.mkdir(parents=True, exist_ok=True)
    for cell, name in zip(cells, STAT_BADGES, strict=True):
        keyed = punch_badge_centers(trim_alpha(cell), luma_max=58.0)
        out = fit_canvas(keyed, (256, 256))
        path = out_dir / f"{name}.png"
        out.save(path)
        print(f"wrote {path}")


def main() -> None:
    targets = sys.argv[1:] or ["plate", "slot", "silhouettes", "badges"]
    if "plate" in targets:
        process_plate()
    if "slot" in targets:
        process_slot_frame()
    if "silhouettes" in targets:
        process_silhouettes()
    if "badges" in targets:
        process_stat_badges()


if __name__ == "__main__":
    main()

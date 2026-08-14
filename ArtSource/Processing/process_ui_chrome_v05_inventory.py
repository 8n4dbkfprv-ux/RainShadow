#!/usr/bin/env python3
"""Chroma-key and slice RainShadow modular inventory UI V05 masters into runtime PNGs."""

from __future__ import annotations

import shutil
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ASSET_DIRS = [
    Path.home() / ".cursor/projects/Users-laurensvanoorschot-RainShadow/assets",
    Path.home() / ".cursor/projects/Users-laurensvanoorschot-Desktop-RainShadow/assets",
    ROOT / "assets",
]
ASSETS = ASSET_DIRS[0]
GEN = ROOT / "ArtSource/Generated/UI/Inventory"
RUNTIME = ROOT / "RainShadow Shared/Resources/Art/UI/Inventory"
RUNTIME_COMMON = ROOT / "RainShadow Shared/Resources/Art/UI/Common"
GEN_COMMON = ROOT / "ArtSource/Generated/UI/Common"

SLOT_SILHOUETTES = [
    "inventory_slot_silhouette_hat_v05",
    "inventory_slot_silhouette_coat_v05",
    "inventory_slot_silhouette_hands_v05",
    "inventory_slot_silhouette_feet_v05",
    "inventory_slot_silhouette_ring_v05",
    "inventory_slot_silhouette_weapon_v05",
    "inventory_slot_silhouette_item_v05",
    "inventory_slot_silhouette_bag_v05",
]

# V06 4×3 sheet: BG:EE empty-slot roles + noir holster/revolver split.
SLOT_SILHOUETTES_V06 = [
    "inventory_slot_silhouette_hat_v06",
    "inventory_slot_silhouette_coat_v06",
    "inventory_slot_silhouette_hands_v06",
    "inventory_slot_silhouette_charm_v06",
    "inventory_slot_silhouette_cloak_v06",
    "inventory_slot_silhouette_belt_v06",
    "inventory_slot_silhouette_feet_v06",
    "inventory_slot_silhouette_ring_v06",
    "inventory_slot_silhouette_holster_v06",
    "inventory_slot_silhouette_weapon_v06",
    "inventory_slot_silhouette_item_v06",
    "inventory_slot_silhouette_bag_v06",
]

STAT_BADGES = [
    "inventory_stat_badge_defence_v05",
    "inventory_stat_badge_vitality_v05",
    "inventory_stat_badge_resolve_v05",
    "inventory_stat_badge_damage_v05",
]

# Prefer cooler HUD-matched remasters (b/c) over first warm passes.
SOURCE_MAP = {
    "outer_v16": [
        "inventory_outer_frame_v16d_gen.png",
        "inventory_outer_frame_v16c_gen.png",
        "inventory_outer_frame_v16b_gen.png",
        "inventory_outer_frame_v16a_gen.png",
    ],
    "outer_v15": [
        "inventory_outer_frame_v15c_gen.png",
        "inventory_outer_frame_v15b_gen.png",
        "inventory_outer_frame_v15a_gen.png",
    ],
    "outer_v14": [
        "inventory_outer_frame_v14b_gen.png",
        "inventory_outer_frame_v14_gen.png",
    ],
    "outer_v13": [
        "inventory_outer_frame_v13b_gen.png",
        "inventory_outer_frame_v13_gen.png",
    ],
    "outer_v12": [
        "inventory_outer_frame_v12_gen.png",
    ],
    "outer_v11": [
        "inventory_outer_frame_v11_gen.png",
    ],
    "outer_v10": [
        "inventory_outer_frame_v10_gen.png",
    ],
    "outer_v09": [
        "inventory_outer_frame_v09_gen.png",
    ],
    "outer_v08": [
        "inventory_outer_frame_v08_gen.png",
    ],
    "outer_v07": [
        "inventory_outer_frame_v07_gen.png",
    ],
    "outer_v06": [
        "inventory_outer_frame_v06b_gen.png",
        "inventory_outer_frame_v06_gen.png",
    ],
    "outer": [
        "inventory_outer_frame_v05c_gen.png",
        "inventory_outer_frame_v05b_gen.png",
        "inventory_outer_frame_v05_gen.png",
    ],
    "close_macos9": [
        "ui_close_box_macos9_noir_v04_gen.png",
    ],
    "close_inventory_macos9_v09": [
        "inventory_close_box_macos9_noir_v09_gen.png",
    ],
    "close_inventory_macos9_v10": [
        "inventory_close_box_macos9_noir_v10_gen.png",
    ],
    "close_inventory_macos9_v11": [
        "inventory_close_box_macos9_noir_v11_gen.png",
    ],
    "close_inventory_macos9_v12": [
        "inventory_close_box_macos9_noir_v12b_gen.png",
        "inventory_close_box_macos9_noir_v12_gen.png",
    ],
    "close_inventory_macos9_v15": [
        "inventory_close_box_macos9_noir_v15c_gen.png",
        "inventory_close_box_macos9_noir_v15b_gen.png",
        "inventory_close_box_macos9_noir_v15a_gen.png",
    ],
    "loadout": [
        "inventory_section_loadout_v05e_gen.png",
        "inventory_section_loadout_v05d_gen.png",
        "inventory_section_loadout_v05b_gen.png",
        "inventory_section_loadout_v05_gen.png",
    ],
    "paperdoll": ["inventory_section_paperdoll_v05b_gen.png", "inventory_section_paperdoll_v05_gen.png"],
    "stats": [
        "inventory_section_stats_v05d_gen.png",
        "inventory_section_stats_v05b_gen.png",
        "inventory_section_stats_v05_gen.png",
    ],
    "mid": ["inventory_section_mid_v05b_gen.png", "inventory_section_mid_v05_gen.png"],
    "bag": [
        "inventory_section_bag_v05d_gen.png",
        "inventory_section_bag_v05b_gen.png",
        "inventory_section_bag_v05_gen.png",
    ],
    "nearby": [
        "inventory_section_nearby_v05d_gen.png",
        "inventory_section_nearby_v05b_gen.png",
        "inventory_section_nearby_v05_gen.png",
    ],
    "slot": ["inventory_slot_frame_v05b_gen.png", "inventory_slot_frame_v05_gen.png"],
    "selection": ["inventory_selection_frame_v05b_gen.png", "inventory_selection_frame_v05_gen.png"],
    "silhouettes": ["inventory_slot_silhouettes_sheet_v05b_gen.png"],
    "silhouettes_v06": [
        "inventory_slot_silhouettes_sheet_v06_gen.png",
        "inventory_slot_silhouettes_sheet_v06a_gen.png",
    ],
    "badges": ["inventory_stat_badges_sheet_v05b_gen.png"],
    "arrows": ["inventory_page_arrow_sheet_v05b_gen.png"],
    "case_bag": ["inventory_case_bag_v05b_gen.png"],
    "coins": ["inventory_coin_stack_v05b_gen.png"],
}


def flood_key_near_black(im: Image.Image, luma_max: float = 8.0) -> Image.Image:
    """Punch connected near-black exterior and content well to alpha.

    V13's generator fill is black rather than chroma green. A luma punch would
    also eat the dark hairline gaps in the title bar, so only flood from the
    canvas border and the interior centre.
    """
    rgba = np.array(im.convert("RGBA"), dtype=np.float32)
    luma = rgba[:, :, :3].mean(axis=2)
    height, width = luma.shape
    visited = np.zeros((height, width), dtype=bool)
    queue: deque[tuple[int, int]] = deque()

    def seed(x: int, y: int) -> None:
        if 0 <= x < width and 0 <= y < height and not visited[y, x] and luma[y, x] <= luma_max:
            queue.append((x, y))

    for x in range(width):
        seed(x, 0)
        seed(x, height - 1)
    for y in range(height):
        seed(0, y)
        seed(width - 1, y)
    seed(width // 2, height // 2)
    seed(width // 2, int(height * 0.45))
    seed(width // 2, int(height * 0.70))

    while queue:
        x, y = queue.popleft()
        if visited[y, x] or luma[y, x] > luma_max:
            continue
        visited[y, x] = True
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < width and 0 <= ny < height and not visited[ny, nx] and luma[ny, nx] <= luma_max:
                queue.append((nx, ny))

    rgba[visited, 3] = 0
    rgba[visited, :3] = 0
    return Image.fromarray(rgba.astype(np.uint8), "RGBA")


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


def scrub_green_spill(im: Image.Image) -> Image.Image:
    rgba = np.array(im.convert("RGBA"), dtype=np.float32)
    g, r, b = rgba[:, :, 1], rgba[:, :, 0], rgba[:, :, 2]
    greenish = (g > r + 25) & (g > b + 25) & (g > 50)
    rgba[:, :, 3] = np.where(greenish, 0, rgba[:, :, 3])
    rgba[:, :, :3] = np.where(rgba[:, :, 3:4] < 8, 0, rgba[:, :, :3])
    return Image.fromarray(rgba.astype(np.uint8), "RGBA")


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


def mirrored_horizontal_fill(source: Image.Image, width: int) -> Image.Image:
    out = Image.new("RGBA", (width, source.height), (0, 0, 0, 0))
    tile_x = 0
    tile_index = 0
    while tile_x < width:
        tile = source if tile_index % 2 == 0 else source.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        tile_width = min(tile.width, width - tile_x)
        out.alpha_composite(tile.crop((0, 0, tile_width, source.height)), (tile_x, 0))
        tile_x += tile_width
        tile_index += 1
    # A light endpoint-preserving stretch breaks up obvious mirrored bands
    # while the tiled layer keeps pits and scratches from becoming long smears.
    stretched = source.resize((width, source.height), Image.Resampling.LANCZOS)
    return Image.blend(out, stretched, 0.28)


def expand_horizontal_seams(
    im: Image.Image,
    size: tuple[int, int],
    seams: tuple[tuple[float, float, float], ...],
) -> Image.Image:
    """Fill a wide chrome canvas without stretching its corners or side wells.

    Image generation produces only portrait or 3:2 masters, while several
    inventory plates are much wider.  Aspect-fitting those masters used to
    leave most of the runtime PNG transparent.  Resize to the authored height,
    then grow a featureless horizontal seam inside the plate so its outer
    bevels, badge seats, and side wells retain their proportions.
    """
    cw, ch = size
    trimmed = trim_alpha(im)
    if trimmed.width == 0 or trimmed.height == 0:
        return Image.new("RGBA", size, (0, 0, 0, 0))

    scale = ch / trimmed.height
    fitted_width = max(1, int(round(trimmed.width * scale)))
    fitted = trimmed.resize((fitted_width, ch), Image.Resampling.LANCZOS)
    if fitted_width >= cw:
        return fit_canvas(trimmed, size)

    resolved: list[tuple[int, int, float]] = []
    prior_end = 0
    for start_fraction, end_fraction, weight in seams:
        start = max(prior_end, min(fitted_width - 2, int(round(fitted_width * start_fraction))))
        end = max(start + 1, min(fitted_width - 1, int(round(fitted_width * end_fraction))))
        resolved.append((start, end, weight))
        prior_end = end

    extra_width = cw - fitted_width
    weight_total = sum(weight for _, _, weight in resolved)
    allocations = [int(round(extra_width * weight / weight_total)) for _, _, weight in resolved]
    allocations[-1] += extra_width - sum(allocations)

    out = Image.new("RGBA", size, (0, 0, 0, 0))
    source_x = 0
    destination_x = 0
    for (start, end, _), allocation in zip(resolved, allocations, strict=True):
        fixed = fitted.crop((source_x, 0, start, ch))
        out.alpha_composite(fixed, (destination_x, 0))
        destination_x += fixed.width

        seam_source = fitted.crop((start, 0, end, ch))
        expanded = mirrored_horizontal_fill(seam_source, seam_source.width + allocation)
        out.alpha_composite(expanded, (destination_x, 0))
        destination_x += expanded.width
        source_x = end

    tail = fitted.crop((source_x, 0, fitted_width, ch))
    out.alpha_composite(tail, (destination_x, 0))
    return out


def expand_horizontal_seam(
    im: Image.Image,
    size: tuple[int, int],
    seam: tuple[float, float],
) -> Image.Image:
    return expand_horizontal_seams(im, size, ((seam[0], seam[1], 1.0),))


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


def resolve_src(candidates: list[str]) -> Path:
    for name in candidates:
        for folder in ASSET_DIRS:
            src = folder / name
            if src.exists():
                return src
        for generated in (GEN / name, GEN_COMMON / name):
            if generated.exists():
                return generated
    raise FileNotFoundError(f"Missing generator asset; tried {candidates}")


def copy_gen(candidates: list[str], dest: Path) -> Path:
    src = resolve_src(candidates)
    dest.parent.mkdir(parents=True, exist_ok=True)
    if src.resolve() != dest.resolve():
        shutil.copy2(src, dest)
    return dest


def write_png(im: Image.Image, path: Path) -> None:
    """Write a clean PNG and strip Apple extended attributes for codesign."""
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, format="PNG")
    try:
        import subprocess

        subprocess.run(["xattr", "-c", str(path)], check=False, capture_output=True)
    except Exception:
        pass


def process_keyed(
    key: str,
    runtime_name: str,
    canvas: tuple[int, int],
    *,
    punch_interior: bool = False,
    punch_luma: float = 36.0,
    tol: float = 55.0,
    horizontal_seam: tuple[float, float] | None = None,
    horizontal_seams: tuple[tuple[float, float, float], ...] | None = None,
    clear_regions: tuple[tuple[int, int, int, int], ...] = (),
    exact_resize: bool = False,
) -> None:
    master = copy_gen(SOURCE_MAP[key], GEN / f"{runtime_name}_gen.png")
    source = Image.open(master)
    if exact_resize:
        # Resize the opaque chroma master first. Resizing straight-alpha art
        # after keying pulls hidden green RGB back into the antialiased rim.
        source = source.resize(canvas, Image.Resampling.LANCZOS)
    keyed = scrub_green_spill(force_grayscale(chroma_key(source, tol=tol, soft=20.0)))
    if punch_interior:
        keyed = punch_dark_wells(keyed, luma_max=punch_luma)
    if exact_resize:
        out = keyed
    elif horizontal_seams is not None:
        out = expand_horizontal_seams(keyed, canvas, horizontal_seams)
    elif horizontal_seam is None:
        out = fit_canvas(trim_alpha(keyed), canvas)
    else:
        out = expand_horizontal_seam(keyed, canvas, horizontal_seam)
    for region in clear_regions:
        out.paste((0, 0, 0, 0), region)
    GEN.mkdir(parents=True, exist_ok=True)
    write_png(out, GEN / f"{runtime_name}_keyed.png")
    runtime = RUNTIME / f"{runtime_name}.png"
    write_png(out, runtime)
    print(f"wrote {runtime} ({out.size[0]}x{out.size[1]}) from {master.name}")


def process_silhouettes() -> None:
    master = copy_gen(SOURCE_MAP["silhouettes"], GEN / "inventory_slot_silhouettes_sheet_v05_gen.png")
    sheet = force_grayscale(chroma_key(Image.open(master)))
    cells = slice_grid(sheet, 4, 2, inset=0.05)
    assert len(cells) == len(SLOT_SILHOUETTES)
    for cell, name in zip(cells, SLOT_SILHOUETTES, strict=True):
        out = fit_canvas(trim_alpha(cell), (256, 256))
        path = RUNTIME / f"{name}.png"
        write_png(out, path)
        print(f"wrote {path}")


def lighten_dark_strokes(im: Image.Image, target_luma: float = 186.0) -> Image.Image:
    """Map near-black generator strokes to the light-gray v05 empty-slot language.

    Dark wells hide black line art; shipped v05 silhouettes sit around luma 180.
    """
    arr = np.array(im.convert("RGBA"), dtype=np.float32)
    alpha = arr[..., 3]
    mask = alpha > 28.0
    if not np.any(mask):
        return im
    rgb = arr[..., :3]
    luma = 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]
    # Invert dark strokes toward the target light gray while keeping soft AA.
    lifted = np.clip(target_luma + (target_luma - luma) * 0.15, 120.0, 245.0)
    for c in range(3):
        channel = rgb[..., c]
        channel[mask] = lifted[mask]
        rgb[..., c] = channel
    arr[..., :3] = rgb
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def process_silhouettes_v06() -> None:
    master = copy_gen(
        SOURCE_MAP["silhouettes_v06"],
        GEN / "inventory_slot_silhouettes_sheet_v06_gen.png",
    )
    sheet = force_grayscale(chroma_key(Image.open(master), tol=56.0, soft=18.0))
    # Generator sometimes leaves a green gutter strip; trim to opaque content first.
    sheet = trim_alpha(sheet, threshold=20, pad=0)
    cells = slice_grid(sheet, 4, 3, inset=0.06)
    assert len(cells) == len(SLOT_SILHOUETTES_V06)
    for cell, name in zip(cells, SLOT_SILHOUETTES_V06, strict=True):
        keyed = lighten_dark_strokes(trim_alpha(cell, threshold=24, pad=2))
        out = fit_canvas(keyed, (256, 256))
        gen_path = GEN / f"{name}.png"
        write_png(out, gen_path)
        path = RUNTIME / f"{name}.png"
        write_png(out, path)
        print(f"wrote {path}")


def process_badges() -> None:
    master = copy_gen(SOURCE_MAP["badges"], GEN / "inventory_stat_badges_sheet_v05_gen.png")
    sheet = force_grayscale(chroma_key(Image.open(master)))
    cells = slice_grid(sheet, 2, 2, inset=0.06)
    assert len(cells) == len(STAT_BADGES)
    for cell, name in zip(cells, STAT_BADGES, strict=True):
        keyed = punch_dark_wells(trim_alpha(cell), luma_max=58.0)
        out = fit_canvas(keyed, (256, 256))
        path = RUNTIME / f"{name}.png"
        write_png(out, path)
        print(f"wrote {path}")


def process_arrows() -> None:
    master = copy_gen(SOURCE_MAP["arrows"], GEN / "inventory_page_arrow_sheet_v05_gen.png")
    sheet = force_grayscale(chroma_key(Image.open(master)))
    # Generator produced a 2×2 study; use top-left / top-right chevrons.
    cells = slice_grid(sheet, 2, 2, inset=0.08)
    for cell, name in ((cells[0], "inventory_page_arrow_prev_v05"), (cells[1], "inventory_page_arrow_next_v05")):
        out = fit_canvas(trim_alpha(cell), (128, 128))
        path = RUNTIME / f"{name}.png"
        write_png(out, path)
        print(f"wrote {path}")


def process_close_macos9() -> None:
    master = copy_gen(SOURCE_MAP["close_macos9"], GEN_COMMON / "ui_close_box_macos9_noir_v04_gen.png")
    keyed = scrub_green_spill(force_grayscale(chroma_key(Image.open(master), tol=48.0, soft=16.0)))
    out = fit_canvas(trim_alpha(keyed), (128, 128))
    write_png(out, GEN_COMMON / "ui_close_box_macos9_noir_v04_keyed.png")
    runtime = RUNTIME_COMMON / "ui_close_box_macos9_noir_v04.png"
    write_png(out, runtime)
    print(f"wrote {runtime} ({out.size[0]}x{out.size[1]}) from {master.name}")


def process_inventory_close_macos9_v09() -> None:
    master = copy_gen(
        SOURCE_MAP["close_inventory_macos9_v09"],
        GEN_COMMON / "inventory_close_box_macos9_noir_v09_gen.png",
    )
    keyed = scrub_green_spill(
        force_grayscale(chroma_key(Image.open(master), tol=48.0, soft=16.0))
    )
    # Leave transparent breathing room in the runtime texture so the complete
    # outer bevel is never clipped by SpriteKit's quad at small display sizes.
    fitted = fit_canvas(trim_alpha(keyed, threshold=28, pad=3), (116, 116))
    out = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    out.alpha_composite(fitted, (6, 6))
    write_png(out, GEN_COMMON / "inventory_close_box_macos9_noir_v09_keyed.png")
    runtime = RUNTIME_COMMON / "inventory_close_box_macos9_noir_v09.png"
    write_png(out, runtime)
    print(f"wrote {runtime} ({out.size[0]}x{out.size[1]}) from {master.name}")


def process_inventory_close_macos9_v10() -> None:
    master = copy_gen(
        SOURCE_MAP["close_inventory_macos9_v10"],
        GEN_COMMON / "inventory_close_box_macos9_noir_v10_gen.png",
    )
    keyed = scrub_green_spill(
        force_grayscale(chroma_key(Image.open(master), tol=48.0, soft=16.0))
    )
    fitted = fit_canvas(trim_alpha(keyed, threshold=28, pad=3), (116, 116))
    out = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    out.alpha_composite(fitted, (6, 6))
    write_png(out, GEN_COMMON / "inventory_close_box_macos9_noir_v10_keyed.png")
    runtime = RUNTIME_COMMON / "inventory_close_box_macos9_noir_v10.png"
    write_png(out, runtime)
    print(f"wrote {runtime} ({out.size[0]}x{out.size[1]}) from {master.name}")


def process_inventory_close_macos9_v11() -> None:
    master = copy_gen(
        SOURCE_MAP["close_inventory_macos9_v11"],
        GEN_COMMON / "inventory_close_box_macos9_noir_v11_gen.png",
    )
    keyed = scrub_green_spill(
        force_grayscale(chroma_key(Image.open(master), tol=48.0, soft=16.0))
    )
    fitted = fit_canvas(trim_alpha(keyed, threshold=28, pad=3), (116, 116))
    out = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    out.alpha_composite(fitted, (6, 6))
    write_png(out, GEN_COMMON / "inventory_close_box_macos9_noir_v11_keyed.png")
    runtime = RUNTIME_COMMON / "inventory_close_box_macos9_noir_v11.png"
    write_png(out, runtime)
    print(f"wrote {runtime} ({out.size[0]}x{out.size[1]}) from {master.name}")


def process_inventory_close_macos9_v12() -> None:
    master = copy_gen(
        SOURCE_MAP["close_inventory_macos9_v12"],
        GEN_COMMON / "inventory_close_box_macos9_noir_v12_gen.png",
    )
    keyed = scrub_green_spill(
        force_grayscale(chroma_key(Image.open(master), tol=48.0, soft=16.0))
    )
    # Tight pad: the live sprite must sit inside the title-bar stripe field at
    # roughly the OS 9 close-box height, not as a 64px nested picture frame.
    fitted = fit_canvas(trim_alpha(keyed, threshold=28, pad=2), (120, 120))
    out = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    out.alpha_composite(fitted, (4, 4))
    write_png(out, GEN_COMMON / "inventory_close_box_macos9_noir_v12_keyed.png")
    runtime = RUNTIME_COMMON / "inventory_close_box_macos9_noir_v12.png"
    write_png(out, runtime)
    print(f"wrote {runtime} ({out.size[0]}x{out.size[1]}) from {master.name}")


def process_outer_v06() -> None:
    # Chroma clears the live well; keep the painted TL rail seat recess opaque.
    process_keyed(
        "outer_v06",
        "inventory_outer_frame_v06",
        (1960, 1080),
        punch_interior=False,
        horizontal_seam=(0.25, 0.75),
    )


def process_outer_v07() -> None:
    # Slim noir rail with a compact Mac OS 9 close seat. Expand only the
    # unadorned horizontal runs so the mitres and close geometry stay intact.
    process_keyed(
        "outer_v07",
        "inventory_outer_frame_v07",
        (1960, 1080),
        punch_interior=False,
        horizontal_seam=(0.28, 0.72),
    )


def process_outer_v08() -> None:
    # The generated master already matches the 1960:1080 runtime aspect. An
    # exact resize preserves the centered title reserve and both groove banks;
    # seam expansion would pull those authored Mac-style features apart.
    process_keyed(
        "outer_v08",
        "inventory_outer_frame_v08",
        (1960, 1080),
        punch_interior=False,
        exact_resize=True,
    )


def process_outer_v09() -> None:
    # V09 keeps the V08 Platinum geometry but replaces the baked close control
    # with a quiet groove-free reserve for the separate live button sprite.
    process_keyed(
        "outer_v09",
        "inventory_outer_frame_v09",
        (1960, 1080),
        punch_interior=False,
        exact_resize=True,
    )


def process_outer_v10() -> None:
    # V10 also removes the bordered center plaque: the live title now sits in
    # a plain interruption of the stripes, with no box or bevel around it.
    process_keyed(
        "outer_v10",
        "inventory_outer_frame_v10",
        (1960, 1080),
        punch_interior=False,
        exact_resize=True,
    )


def process_outer_v11() -> None:
    # V11 locks both title-bar gaps: a compact, seamless unstriped end reserve
    # for the separate live close sprite and an unoutlined center text gap.
    process_keyed(
        "outer_v11",
        "inventory_outer_frame_v11",
        (1960, 1080),
        punch_interior=False,
        exact_resize=True,
    )


def process_outer_v12() -> None:
    # V12 rebuilds the Platinum window from Mac OS 9 geometry: 1px outline,
    # beveled slim rails, dense title pinstripes, flat center title gap, and
    # a frame-only far-left reserve for the separate live close sprite.
    process_keyed(
        "outer_v12",
        "inventory_outer_frame_v12",
        (1960, 1080),
        punch_interior=False,
        exact_resize=True,
    )


def _draw_os9_widget(arr: np.ndarray, x0: int, y0: int, size: int, kind: str) -> None:
    """Stamp an OS 9 close / zoom / windowshade in noir."""
    dark = (14, 14, 14)
    bevel_lt = (118, 118, 122)
    bevel_rb = (28, 28, 30)
    face_tl = (28, 28, 30)
    face_br = (118, 118, 122)
    mark = (176, 176, 180)
    x1, y1 = x0 + size, y0 + size
    arr[y0:y1, x0] = dark
    arr[y0:y1, x1 - 1] = dark
    arr[y0, x0:x1] = dark
    arr[y1 - 1, x0:x1] = dark
    if size >= 6:
        arr[y0 + 1, x0 + 1 : x1 - 1] = bevel_lt
        arr[y0 + 1 : y1 - 1, x0 + 1] = bevel_lt
        arr[y1 - 2, x0 + 1 : x1 - 1] = bevel_rb
        arr[y0 + 1 : y1 - 1, x1 - 2] = bevel_rb
        arr[y0 + 1, x0 + 1] = bevel_lt
        arr[y1 - 2, x1 - 2] = bevel_rb
    ix0, iy0, ix1, iy1 = x0 + 2, y0 + 2, x1 - 2, y1 - 2
    iw, ih = max(1, ix1 - ix0), max(1, iy1 - iy0)
    yy, xx = np.mgrid[0:ih, 0:iw]
    t = (xx + yy) / max(1, (iw - 1) + (ih - 1))
    face = np.stack(
        [
            face_tl[0] + (face_br[0] - face_tl[0]) * t,
            face_tl[1] + (face_br[1] - face_tl[1]) * t,
            face_tl[2] + (face_br[2] - face_tl[2]) * t,
        ],
        axis=-1,
    )
    arr[iy0:iy1, ix0:ix1] = face.astype(np.uint8)
    if kind == "close":
        return
    if kind == "zoom":
        inner_s = max(6, int(round(min(iw, ih) * 0.52)))
        zx0, zy0 = ix0 + 1, iy0 + 1
        zx1, zy1 = zx0 + inner_s, zy0 + inner_s
        arr[zy0:zy1, zx0] = mark
        arr[zy0:zy1, zx1 - 1] = mark
        arr[zy0, zx0:zx1] = mark
        arr[zy1 - 1, zx0:zx1] = mark
        return
    bar_h = max(2, ih // 6)
    gap = max(2, ih // 5)
    total = bar_h * 2 + gap
    sy = iy0 + max(1, (ih - total) // 2)
    for _ in range(2):
        arr[sy : sy + bar_h, ix0 + 2 : ix1 - 2] = mark
        sy += bar_h + gap


def _slim_body_rails(body: np.ndarray, thickness: int = 6) -> None:
    h, w, _ = body.shape
    luma = body.mean(axis=2)
    for y in range(h):
        xs = np.where(luma[y] > 8)[0]
        if len(xs) == 0:
            continue
        left, right = int(xs.min()), int(xs.max())
        if right - left < thickness * 2 + 4:
            continue
        body[y, left + thickness : right - thickness + 1] = 0
    for x in range(w):
        ys = np.where(luma[:, x] > 8)[0]
        if len(ys) == 0:
            continue
        if x < thickness or x >= w - thickness:
            continue
        bottom = int(ys.max())
        body[0 : max(0, bottom - thickness + 1), x] = 0
    gx, gy = w - thickness - 12, h - thickness - 10
    grip = (90, 90, 94)
    for i in range(3):
        x2, y2 = gx + 10, gy + i * 3
        for t in range(8):
            xx = min(w - 1, x2 - t)
            yy = min(h - 1, y2 + t)
            if 0 <= xx < w and 0 <= yy < h:
                body[yy, xx] = grip


def compose_inventory_outer_v14(source: Image.Image) -> tuple[Image.Image, dict]:
    """Lock Platinum title-bar proportions on a generated noir window.

    Generator passes keep emitting a ~70–100px bar and a bordered title pill.
    Keep V14b's noir rails/well, rebuild the top strip at 43px of 1080 with a
    snug rectangular unstriped gap and square stamped-in widgets.
    """
    src = np.array(source.convert("RGB"))
    luma = src.mean(axis=2)
    chrome = luma > 10
    ys, xs = np.where(chrome)
    x0, x1 = int(xs.min()), int(xs.max()) + 1
    y0, y1 = int(ys.min()), int(ys.max()) + 1
    mid_x = (x0 + x1) // 2
    title_end = y0
    for y in range(y0 + 8, y0 + 120):
        if luma[y, mid_x] < 6 and luma[y - 1, mid_x] >= 12:
            title_end = y
            break
    window = src[y0:y1, x0:x1]
    title_src = window[: title_end - y0]
    body_src = window[title_end - y0 :]

    canvas_w, canvas_h = 1960, 1080
    margin = 2
    title_h = 43
    gap_w = 240
    inner_w = canvas_w - 2 * margin
    inner_h = canvas_h - 2 * margin
    body_h = inner_h - title_h
    title = np.array(Image.fromarray(title_src).resize((inner_w, title_h), Image.Resampling.LANCZOS))
    body = np.array(Image.fromarray(body_src).resize((inner_w, body_h), Image.Resampling.LANCZOS))

    fy0, fy1 = 2, title_h - 2
    field_h = fy1 - fy0
    tw, th = title_src.shape[1], title_src.shape[0]
    sample = title_src[int(th * 0.18) : int(th * 0.82), int(tw * 0.22)]
    sample_luma = sample.mean(axis=1)
    field_color = np.median(sample[sample_luma > 20], axis=0).astype(np.uint8)
    hair = np.array((10, 10, 12), dtype=np.uint8)

    rail = 6
    fx0, fx1 = rail, inner_w - rail
    title[fy0:fy1, fx0:fx1] = field_color
    pad = 2
    span = max(5, field_h - 2 * pad - 1)
    for i in range(6):
        y = fy0 + pad + int(round(i * span / 5))
        if fy0 <= y < fy1:
            title[y, fx0:fx1] = hair

    gx0 = inner_w // 2 - gap_w // 2
    gx1 = gx0 + gap_w
    title[fy0:fy1, gx0:gx1] = field_color

    widget = field_h - 1
    wy = fy0 + (field_h - widget) // 2
    close_x = rail + 2
    shade_x = inner_w - rail - 2 - widget
    zoom_x = shade_x - 4 - widget
    _draw_os9_widget(title, close_x, wy, widget, "close")
    _draw_os9_widget(title, zoom_x, wy, widget, "zoom")
    _draw_os9_widget(title, shade_x, wy, widget, "shade")
    _slim_body_rails(body, thickness=6)

    canvas = np.zeros((canvas_h, canvas_w, 3), dtype=np.uint8)
    canvas[margin : margin + title_h, margin : margin + inner_w] = title
    canvas[margin + title_h : margin + title_h + body_h, margin : margin + inner_w] = body
    close_crop = (
        margin + close_x - 1,
        margin + wy - 1,
        margin + close_x + widget + 1,
        margin + wy + widget + 1,
    )
    metrics = {
        "title_h": title_h,
        "widget": widget,
        "close_crop": close_crop,
        "close_world": (
            margin + close_x + widget / 2 - canvas_w / 2,
            canvas_h / 2 - (margin + wy + widget / 2),
        ),
        "title_center_world": (0.0, canvas_h / 2 - (margin + title_h / 2)),
    }
    return Image.fromarray(canvas, "RGB"), metrics


def lock_rectangular_title_gap(rgb: np.ndarray, gap_w: int = 240) -> dict:
    """Paint a snug unstriped rectangle over residual gap borders.

    Generator passes keep leaving a 1–2px vertical stroke where the
    hairlines stop. OS 9 is just stripes terminating on a slightly
    lighter field — no capsule, no plaque.
    """
    h, w, _ = rgb.shape
    luma = rgb.mean(axis=2)
    sx = w // 4
    title_end = 8
    for y in range(8, min(160, h - 4)):
        if luma[y, sx] < 8 and luma[y - 1, sx] >= 14:
            title_end = y
            break
    # Inner stripe field: skip the 1px outline + slim top/bottom bevel.
    fy0 = 3
    fy1 = max(fy0 + 4, title_end - 2)
    sample = rgb[fy0:fy1, sx]
    sample_luma = sample.mean(axis=1)
    lit = sample[sample_luma > 20]
    field = (np.median(lit, axis=0) if len(lit) else np.array([40.0, 40.0, 42.0])).astype(np.float32)
    gap = np.clip(field + 12.0, 0, 255).astype(np.uint8)
    gx0 = w // 2 - gap_w // 2
    gx1 = gx0 + gap_w
    rgb[fy0:fy1, gx0:gx1] = gap
    return {
        "title_end": title_end,
        "fy0": fy0,
        "fy1": fy1,
        "gx0": gx0,
        "gx1": gx1,
        "title_center_world": (0.0, h / 2 - title_end / 2),
    }


def _crop_titlebar_close(keyed: Image.Image, title_end: int) -> tuple[Image.Image, tuple[float, float], int]:
    """Crop the stamped-in close widget from the left stripe field."""
    arr = np.array(keyed.convert("RGBA"))
    luma = arr[:, :, :3].mean(axis=2)
    fy0, fy1 = 6, max(8, title_end - 4)
    # Stay inside the left rail + close, well before the stripe run / title gap.
    x_hi = min(80, keyed.width // 20)
    band = luma[fy0:fy1, 8:x_hi]
    face = band > 100
    ys, xs = np.where(face)
    if len(xs) < 8:
        face = band > np.percentile(band, 88)
        ys, xs = np.where(face)
    x0, x1 = int(xs.min()) + 8, int(xs.max()) + 8 + 1
    y0, y1 = int(ys.min()) + fy0, int(ys.max()) + fy0 + 1
    pad = 2
    crop_box = (
        max(0, x0 - pad),
        max(0, y0 - pad),
        min(keyed.width, x1 + pad),
        min(keyed.height, y1 + pad),
    )
    widget = max(crop_box[2] - crop_box[0], crop_box[3] - crop_box[1])
    cx = (crop_box[0] + crop_box[2]) / 2
    cy = (crop_box[1] + crop_box[3]) / 2
    world = (cx - keyed.width / 2, keyed.height / 2 - cy)
    close_crop = keyed.crop(crop_box)
    # Pad to square with transparency so nearest-scale does not squash the box.
    side = max(close_crop.width, close_crop.height)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.alpha_composite(
        close_crop,
        ((side - close_crop.width) // 2, (side - close_crop.height) // 2),
    )
    fitted = square.resize((120, 120), Image.Resampling.NEAREST)
    close = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    close.alpha_composite(fitted, (4, 4))
    return close, world, widget


def _key_standalone_close(master: Path) -> Image.Image:
    keyed = scrub_green_spill(
        force_grayscale(chroma_key(Image.open(master), tol=48.0, soft=16.0))
    )
    return trim_alpha(keyed, threshold=28, pad=1)


def _stamp_close_into_titlebar(
    keyed: Image.Image, close_src: Image.Image, title_end: int
) -> tuple[Image.Image, tuple[float, float], int]:
    """Place close / zoom / shade with Platinum padding inside the title strip.

    OS 9 keeps a few pixels of unstriped field around each box: inset from the
    inner frame, a gutter before the hairlines, and a gap between Zoom and
    WindowShade. The generator (and the first V16 stamp) sat the widgets flush
    against the rails and stripes.
    """
    arr = np.array(keyed.convert("RGBA"))
    h, w, _ = arr.shape
    fy0, fy1 = 4, max(8, title_end - 3)
    field_h = fy1 - fy0
    # Native Platinum: 13px close in a 22px bar, ~4px of unstriped field on
    # every side plus a hairline gutter before the stripes. Scale that onto
    # this ~39px strip so the boxes are no longer flush with the rails.
    widget = max(16, field_h - 12)
    rail = 5
    outer_pad = 8
    stripe_gutter = 8
    inter = 5
    sample_x0 = min(w - 12, max(rail + 80, w // 5))
    sample = arr[fy0:fy1, sample_x0 : sample_x0 + 40, :3]
    flat = sample.reshape(-1, 3)
    if len(flat):
        sample_luma = flat.mean(axis=1)
        lit = flat[sample_luma > np.median(sample_luma)]
        field = np.median(lit if len(lit) else flat, axis=0).astype(np.uint8)
    else:
        field = np.array([48, 48, 50], dtype=np.uint8)

    close_x = rail + outer_pad
    close_y = fy0 + (field_h - widget) // 2
    shade_x = w - rail - outer_pad - widget
    zoom_x = shade_x - inter - widget
    wy = close_y

    left_clear = (rail, close_x + widget + stripe_gutter)
    right_clear = (zoom_x - stripe_gutter, w - rail)
    arr[fy0:fy1, left_clear[0] : left_clear[1], :3] = field
    arr[fy0:fy1, left_clear[0] : left_clear[1], 3] = 255
    arr[fy0:fy1, right_clear[0] : right_clear[1], :3] = field
    arr[fy0:fy1, right_clear[0] : right_clear[1], 3] = 255

    rgb = arr[:, :, :3]
    _draw_os9_widget(rgb, zoom_x, wy, widget, "zoom")
    _draw_os9_widget(rgb, shade_x, wy, widget, "shade")
    arr[:, :, :3] = rgb
    arr[wy : wy + widget, zoom_x : zoom_x + widget, 3] = 255
    arr[wy : wy + widget, shade_x : shade_x + widget, 3] = 255

    frame = Image.fromarray(arr, "RGBA")
    stamped = close_src.resize((widget, widget), Image.Resampling.LANCZOS)
    frame.alpha_composite(stamped, (close_x, close_y))
    world = (
        close_x + widget / 2 - keyed.width / 2,
        keyed.height / 2 - (close_y + widget / 2),
    )
    return frame, world, widget


def process_outer_v16() -> None:
    # V16d is the first generator pass that kept OS 9's ~4% strip while
    # restamping the nested-square close from the Platinum photographs.
    # Uniform-scale to 1080, expand stripe runs to 1960, lock a 240px
    # rectangular title gap, flood-key the well, then stamp the dedicated
    # nested-square close sprite into the left stripe field so the live
    # control matches the baked widget.
    master = copy_gen(SOURCE_MAP["outer_v16"], GEN / "inventory_outer_frame_v16d_gen.png")
    source = Image.open(master).convert("RGBA")
    scale = 1080 / source.height
    fitted = source.resize(
        (max(1, int(round(source.width * scale))), 1080),
        Image.Resampling.LANCZOS,
    )
    keyed = scrub_green_spill(force_grayscale(flood_key_near_black(fitted, luma_max=8.0)))
    stretched = expand_horizontal_seams(
        keyed,
        (1960, 1080),
        (
            (0.12, 0.40, 0.50),
            (0.60, 0.88, 0.50),
        ),
    )
    rgb = np.array(stretched.convert("RGB"))
    gap_metrics = lock_rectangular_title_gap(rgb, gap_w=240)
    alpha = np.array(stretched.split()[-1])
    keyed = Image.fromarray(np.dstack([rgb, alpha]).astype(np.uint8), "RGBA")

    close_master = copy_gen(
        SOURCE_MAP["close_inventory_macos9_v15"],
        GEN_COMMON / "inventory_close_box_macos9_noir_v15c_gen.png",
    )
    close_src = _key_standalone_close(close_master)
    keyed, close_world, widget = _stamp_close_into_titlebar(
        keyed, close_src, gap_metrics["title_end"]
    )

    GEN.mkdir(parents=True, exist_ok=True)
    write_png(keyed.convert("RGB").convert("RGBA"), GEN / "inventory_outer_frame_v16_gen.png")
    write_png(keyed, GEN / "inventory_outer_frame_v16_keyed.png")
    runtime = RUNTIME / "inventory_outer_frame_v16.png"
    write_png(keyed, runtime)
    print(
        f"wrote {runtime} ({keyed.size[0]}x{keyed.size[1]}) from {master.name} "
        f"+ nested-square close stamp title_h={gap_metrics['title_end']}px"
    )

    fitted_close = fit_canvas(close_src, (120, 120))
    close = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    close.alpha_composite(fitted_close, (4, 4))
    write_png(close, GEN_COMMON / "inventory_close_box_macos9_noir_v15_keyed.png")
    close_runtime = RUNTIME_COMMON / "inventory_close_box_macos9_noir_v15.png"
    write_png(close, close_runtime)
    print(
        f"wrote {close_runtime} ({close.size[0]}x{close.size[1]}) "
        f"from {close_master.name} stamped {widget}px @ {close_world}; "
        f"title_center_world={gap_metrics['title_center_world']}"
    )


def process_outer_v15() -> None:
    # V15c is the first generator pass that emitted a ~4% Platinum strip.
    # Uniform-scale to 1080 tall so close/Zoom/WindowShade stay square, expand
    # only the unadorned stripe runs to 1960, flood-key the black well, then
    # paint a snug rectangular unstriped title gap (no residual 1px strokes).
    master = copy_gen(SOURCE_MAP["outer_v15"], GEN / "inventory_outer_frame_v15c_gen.png")
    source = Image.open(master).convert("RGBA")
    scale = 1080 / source.height
    fitted = source.resize(
        (max(1, int(round(source.width * scale))), 1080),
        Image.Resampling.LANCZOS,
    )
    keyed = scrub_green_spill(force_grayscale(flood_key_near_black(fitted, luma_max=8.0)))
    stretched = expand_horizontal_seams(
        keyed,
        (1960, 1080),
        (
            (0.12, 0.40, 0.50),
            (0.60, 0.88, 0.50),
        ),
    )
    rgb = np.array(stretched.convert("RGB"))
    gap_metrics = lock_rectangular_title_gap(rgb, gap_w=240)
    alpha = np.array(stretched.split()[-1])
    keyed = Image.fromarray(np.dstack([rgb, alpha]).astype(np.uint8), "RGBA")
    GEN.mkdir(parents=True, exist_ok=True)
    write_png(Image.fromarray(rgb, "RGB").convert("RGBA"), GEN / "inventory_outer_frame_v15_gen.png")
    write_png(keyed, GEN / "inventory_outer_frame_v15_keyed.png")
    runtime = RUNTIME / "inventory_outer_frame_v15.png"
    write_png(keyed, runtime)
    print(
        f"wrote {runtime} ({keyed.size[0]}x{keyed.size[1]}) from {master.name} "
        f"+ rectangular gap lock title_h={gap_metrics['title_end']}px"
    )

    close, close_world, widget = _crop_titlebar_close(keyed, gap_metrics["title_end"])
    write_png(close, GEN_COMMON / "inventory_close_box_macos9_noir_v14_keyed.png")
    close_runtime = RUNTIME_COMMON / "inventory_close_box_macos9_noir_v14.png"
    write_png(close, close_runtime)
    print(
        f"wrote {close_runtime} ({close.size[0]}x{close.size[1]}) "
        f"cropped from V15 close widget {widget}px @ {close_world}; "
        f"title_center_world={gap_metrics['title_center_world']}"
    )


def process_outer_v14() -> None:
    # V14 locks literal Platinum proportions the generator would not emit:
    # 43px title strip on 1080 (~4%), snug rectangular unstriped title gap,
    # square close/zoom/windowshade stamped into six hairlines. Noir rails
    # come from the V14b window; the content well is black and flood-keyed.
    master = copy_gen(SOURCE_MAP["outer_v14"], GEN / "inventory_outer_frame_v14b_gen.png")
    composed, metrics = compose_inventory_outer_v14(Image.open(master))
    GEN.mkdir(parents=True, exist_ok=True)
    write_png(composed.convert("RGBA"), GEN / "inventory_outer_frame_v14_gen.png")
    keyed = scrub_green_spill(force_grayscale(flood_key_near_black(composed.convert("RGBA"), luma_max=8.0)))
    write_png(keyed, GEN / "inventory_outer_frame_v14_keyed.png")
    runtime = RUNTIME / "inventory_outer_frame_v14.png"
    write_png(keyed, runtime)
    print(f"wrote {runtime} ({keyed.size[0]}x{keyed.size[1]}) from {master.name} + V14 geometry lock")

    close_crop = keyed.crop(metrics["close_crop"])
    fitted = close_crop.resize((120, 120), Image.Resampling.NEAREST)
    close = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    close.alpha_composite(fitted, (4, 4))
    write_png(close, GEN_COMMON / "inventory_close_box_macos9_noir_v13_keyed.png")
    close_runtime = RUNTIME_COMMON / "inventory_close_box_macos9_noir_v13.png"
    write_png(close, close_runtime)
    print(
        f"wrote {close_runtime} ({close.size[0]}x{close.size[1]}) "
        f"cropped from V14 close widget {metrics['widget']}px @ {metrics['close_world']}"
    )


def process_outer_v13() -> None:
    # V13 copies Platinum title-bar grammar literally (thin top strip, six
    # hairlines, close/zoom/windowshade stamped into the stripe field) and
    # remaps only the palette to RainShadow noir. The generator fill is black,
    # so the content well is flooded rather than chroma-keyed. Horizontal seam
    # expansion keeps the left close and right widgets square while filling
    # 1960×1080.
    master = copy_gen(SOURCE_MAP["outer_v13"], GEN / "inventory_outer_frame_v13_gen.png")
    keyed = scrub_green_spill(force_grayscale(flood_key_near_black(Image.open(master), luma_max=8.0)))
    out = expand_horizontal_seams(
        keyed,
        (1960, 1080),
        (
            (0.10, 0.32, 0.50),
            (0.68, 0.88, 0.50),
        ),
    )
    GEN.mkdir(parents=True, exist_ok=True)
    write_png(out, GEN / "inventory_outer_frame_v13_keyed.png")
    runtime = RUNTIME / "inventory_outer_frame_v13.png"
    write_png(out, runtime)
    print(f"wrote {runtime} ({out.size[0]}x{out.size[1]}) from {master.name}")

    # The live close sprite is cropped from the stamped-in title-bar widget so
    # it matches the frame lighting and sits in the stripe field at OS 9 size.
    close_crop = out.crop((17, 17, 83, 83))
    fitted = close_crop.resize((120, 120), Image.Resampling.NEAREST)
    close = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    close.alpha_composite(fitted, (4, 4))
    write_png(close, GEN_COMMON / "inventory_close_box_macos9_noir_v12_keyed.png")
    close_runtime = RUNTIME_COMMON / "inventory_close_box_macos9_noir_v12.png"
    write_png(close, close_runtime)
    print(f"wrote {close_runtime} ({close.size[0]}x{close.size[1]}) cropped from V13 title bar")


def main() -> None:
    targets = sys.argv[1:] or ["all"]
    run_all = "all" in targets

    if run_all or "outer_v16" in targets:
        process_outer_v16()
    if run_all or "outer_v15" in targets:
        process_outer_v15()
    if run_all or "outer_v14" in targets:
        process_outer_v14()
    if run_all or "outer_v13" in targets:
        process_outer_v13()
    if run_all or "outer_v12" in targets:
        process_outer_v12()
    if run_all or "outer_v11" in targets:
        process_outer_v11()
    if run_all or "outer_v10" in targets:
        process_outer_v10()
    if run_all or "outer_v09" in targets:
        process_outer_v09()
    if run_all or "outer_v08" in targets:
        process_outer_v08()
    if run_all or "outer_v07" in targets:
        process_outer_v07()
    if run_all or "outer_v06" in targets:
        process_outer_v06()
    if run_all or "close_macos9" in targets:
        process_close_macos9()
    if run_all or "close_inventory_macos9_v09" in targets:
        process_inventory_close_macos9_v09()
    if run_all or "close_inventory_macos9_v10" in targets:
        process_inventory_close_macos9_v10()
    if run_all or "close_inventory_macos9_v12" in targets:
        process_inventory_close_macos9_v12()
    if run_all or "close_inventory_macos9_v11" in targets:
        process_inventory_close_macos9_v11()
    if run_all or "outer" in targets:
        process_keyed(
            "outer",
            "inventory_outer_frame_v05",
            (1960, 1080),
            punch_interior=True,
            punch_luma=40.0,
            horizontal_seam=(0.25, 0.75),
        )
    if run_all or "loadout" in targets:
        process_keyed(
            "loadout",
            "inventory_section_loadout_v05",
            (460, 520),
            horizontal_seam=(0.20, 0.80),
        )
    if run_all or "paperdoll" in targets:
        process_keyed(
            "paperdoll",
            "inventory_section_paperdoll_v05",
            (520, 520),
            punch_interior=True,
            punch_luma=38.0,
            horizontal_seam=(0.42, 0.58),
        )
    if run_all or "stats" in targets:
        process_keyed(
            "stats",
            "inventory_section_stats_v05",
            (650, 560),
            horizontal_seam=(0.34, 0.85),
        )
    if run_all or "mid" in targets:
        process_keyed(
            "mid",
            "inventory_section_mid_v05",
            (1680, 80),
            horizontal_seams=(
                (0.08, 0.20, 0.15),
                (0.28, 0.72, 0.70),
                (0.80, 0.92, 0.15),
            ),
        )
    if run_all or "bag" in targets:
        process_keyed(
            "bag",
            "inventory_section_bag_v05",
            (1130, 190),
            horizontal_seam=(0.32, 0.90),
        )
    if run_all or "nearby" in targets:
        process_keyed(
            "nearby",
            "inventory_section_nearby_v05",
            (525, 190),
            horizontal_seam=(0.42, 0.58),
        )
    if run_all or "slot" in targets:
        process_keyed("slot", "inventory_slot_frame_v05", (256, 256))
    if run_all or "selection" in targets:
        process_keyed("selection", "inventory_selection_frame_v05", (256, 256), punch_interior=True, punch_luma=70.0)
    if run_all or "silhouettes" in targets:
        process_silhouettes()
    if run_all or "silhouettes_v06" in targets:
        process_silhouettes_v06()
    if run_all or "badges" in targets:
        process_badges()
    if run_all or "arrows" in targets:
        process_arrows()
    if run_all or "case_bag" in targets:
        process_keyed("case_bag", "inventory_case_bag_v05", (512, 512), tol=48.0)
    if run_all or "coins" in targets:
        process_keyed("coins", "inventory_coin_stack_v05", (512, 512), tol=48.0)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Chroma-key and slice RainShadow modular inventory UI V05 masters into runtime PNGs."""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ASSETS = Path.home() / ".cursor/projects/Users-laurensvanoorschot-Desktop-RainShadow/assets"
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

STAT_BADGES = [
    "inventory_stat_badge_defence_v05",
    "inventory_stat_badge_vitality_v05",
    "inventory_stat_badge_resolve_v05",
    "inventory_stat_badge_damage_v05",
]

# Prefer cooler HUD-matched remasters (b/c) over first warm passes.
SOURCE_MAP = {
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
    "badges": ["inventory_stat_badges_sheet_v05b_gen.png"],
    "arrows": ["inventory_page_arrow_sheet_v05b_gen.png"],
    "case_bag": ["inventory_case_bag_v05b_gen.png"],
    "coins": ["inventory_coin_stack_v05b_gen.png"],
}


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
        src = ASSETS / name
        if src.exists():
            return src
        alt = ROOT / "assets" / name
        if alt.exists():
            return alt
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


def main() -> None:
    targets = sys.argv[1:] or ["all"]
    run_all = "all" in targets

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

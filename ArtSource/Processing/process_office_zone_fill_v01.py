"""Slice/chroma-key 3-zone office fill sheets into runtime prop canvases.

Replaces procedural Pillow placeholders from generate_office_zone_props_v01.py
with Image Generator masters (sheets A/B/C + light overlays).
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter


ROOT = Path(__file__).resolve().parents[2]
GEN = ROOT / "ArtSource" / "Generated" / "Office" / "Props"
RUNTIME = ROOT / "RainShadow Shared" / "Resources" / "Art" / "Props" / "Office"

SHEET_A = GEN / "office_zone_fill_sheet_a_chroma_v01.png"
SHEET_B = GEN / "office_zone_fill_sheet_b_chroma_v01.png"
SHEET_C = GEN / "office_zone_fill_sheet_c_chroma_v01.png"
LIGHTS = GEN / "office_zone_light_overlays_v01.png"

# Sheet A 2×2
SHEET_A_CELLS: list[tuple[str, tuple[int, int], bool]] = [
    ("office_desk_typewriter", (280, 200), True),
    ("office_desk_notebook", (160, 120), True),
    ("office_safe", (256, 280), True),
    ("office_window_blinds", (180, 220), False),  # wall/window insert; center bias
]

# Sheet B 2×3 (row-major)
SHEET_B_CELLS: list[tuple[str, tuple[int, int], bool]] = [
    ("office_case_board", (320, 280), False),
    ("office_wall_city_map", (280, 240), False),
    ("office_framed_licence", (160, 180), False),
    ("office_wall_photos", (220, 160), False),
    ("office_umbrella_stand", (160, 220), True),
    ("office_newspaper", (140, 100), True),
]

# Sheet C 2×2
SHEET_C_CELLS: list[tuple[str, tuple[int, int], bool]] = [
    ("office_waiting_chair_a", (220, 280), True),
    ("office_waiting_chair_b", (220, 280), True),
    ("office_waiting_table", (200, 160), True),
    ("office_entrance_runner", (768, 384), False),
]


def chroma_key(im: Image.Image, key=(0, 255, 0), tol=50.0, soft=18.0) -> Image.Image:
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


def trim_alpha(im: Image.Image, threshold: int = 40, pad: int = 2) -> Image.Image:
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


def fit_into_canvas(im: Image.Image, canvas: tuple[int, int], bottom_bias: bool = True) -> Image.Image:
    cw, ch = canvas
    if im.width == 0 or im.height == 0:
        return Image.new("RGBA", canvas, (0, 0, 0, 0))
    scale = min(cw / im.width, ch / im.height) * 0.94
    nw = max(1, int(round(im.width * scale)))
    nh = max(1, int(round(im.height * scale)))
    resized = im.resize((nw, nh), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", canvas, (0, 0, 0, 0))
    x = (cw - nw) // 2
    y = (ch - nh - 4) if bottom_bias else (ch - nh) // 2
    y = max(0, min(ch - nh, y))
    out.alpha_composite(resized, (x, y))
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


def process_sheet(
    path: Path,
    cols: int,
    rows: int,
    cells: list[tuple[str, tuple[int, int], bool]],
) -> None:
    sheet = Image.open(path)
    sliced = slice_grid(sheet, cols, rows)
    assert len(sliced) == len(cells), f"{path.name}: {len(sliced)} != {len(cells)}"
    for cell, (name, canvas, bottom) in zip(sliced, cells, strict=True):
        keyed = trim_alpha(chroma_key(cell))
        # Blinds cell includes a full window; keep sash/blinds, drop large green field.
        out = fit_into_canvas(keyed, canvas, bottom_bias=bottom)
        out.save(RUNTIME / f"{name}.png")
        keyed.save(GEN / f"{name}_rgba_v01.png")
        print(f"{name}: {canvas} from {path.name}")


def process_waiting_ashtray() -> None:
    """Light recolor of desk ashtray for the waiting table."""
    src = RUNTIME / "office_desk_ashtray.png"
    if not src.exists():
        return
    arr = np.array(Image.open(src).convert("RGBA"), dtype=np.float32)
    arr[:, :, 0] = np.clip(arr[:, :, 0] * 0.92, 0, 255)
    arr[:, :, 2] = np.clip(arr[:, :, 2] * 1.08, 0, 255)
    out = Image.fromarray(arr.astype(np.uint8), "RGBA")
    out.save(RUNTIME / "office_waiting_ashtray.png")
    out.save(GEN / "office_waiting_ashtray_rgba_v01.png")
    print("office_waiting_ashtray: derived from desk ashtray")


def process_lights() -> None:
    """Split light overlay plate into blind-stripe spill and hallway beam."""
    im = Image.open(LIGHTS).convert("RGBA")
    w, h = im.width, im.height
    left = im.crop((0, 0, w // 2, h))
    right = im.crop((w // 2, 0, w, h))

    def to_additive_light(cell: Image.Image, warm: bool) -> Image.Image:
        arr = np.array(cell.convert("RGBA"), dtype=np.float32)
        rgb, a = arr[:, :, :3], arr[:, :, 3]
        # Build alpha from luminance; kill near-black.
        lum = rgb.mean(axis=2)
        if warm:
            score = np.maximum(rgb[:, :, 0] * 0.9 + rgb[:, :, 1] * 0.45 - rgb[:, :, 2] * 0.25, 0)
        else:
            score = np.maximum(rgb[:, :, 2] * 0.85 + rgb[:, :, 1] * 0.35 - rgb[:, :, 0] * 0.15, 0)
        score = np.maximum(score, lum * 0.35)
        alpha = np.clip((score - 18.0) / 140.0 * 255.0, 0, 220)
        # Suppress solid dark furniture masses (low lum, high opacity in source).
        alpha = np.where(lum < 22, 0, alpha)
        out = np.dstack([rgb, alpha]).astype(np.uint8)
        return Image.fromarray(out, "RGBA").filter(ImageFilter.GaussianBlur(1.2))

    # Prefer lower spill region of left cell (below the painted window object).
    left_spill = left.crop((0, int(left.height * 0.42), left.width, left.height))
    blind = to_additive_light(left_spill, warm=False)
    blind = fit_into_canvas(trim_alpha(blind, threshold=8), (1536, 1024), bottom_bias=False)
    blind.save(RUNTIME / "office_light_blind_stripes.png")
    blind.save(GEN / "office_light_blind_stripes_rgba_v01.png")
    print("office_light_blind_stripes")

    hallway = to_additive_light(right, warm=True)
    hallway = fit_into_canvas(trim_alpha(hallway, threshold=8), (768, 512), bottom_bias=False)
    hallway.save(RUNTIME / "office_light_hallway.png")
    hallway.save(GEN / "office_light_hallway_rgba_v01.png")
    print("office_light_hallway")

    # Keep a soft fan shadow procedural — generator plate had no usable fan.
    # If a prior procedural fan exists, leave it; otherwise synthesize lightly.
    fan_path = RUNTIME / "office_shadow_ceiling_fan.png"
    if not fan_path.exists():
        fw, fh = 1536, 1024
        arr = np.zeros((fh, fw, 4), dtype=np.float32)
        yy, xx = np.mgrid[0:fh, 0:fw].astype(np.float32)
        cx, cy = fw * 0.5, fh * 0.48
        import math

        for angle in (0.2, 0.2 + math.pi / 2, 0.2 + math.pi, 0.2 + 3 * math.pi / 2):
            ca, sa = math.cos(angle), math.sin(angle)
            lx = ((xx - cx) * ca + (yy - cy) * sa) / (fw * 0.28)
            ly = (-(xx - cx) * sa + (yy - cy) * ca) / (fh * 0.08)
            blade = np.clip(1.0 - np.abs(ly), 0, 1) * np.clip(1.0 - np.abs(lx), 0, 1)
            arr[:, :, 3] = np.maximum(arr[:, :, 3], blade * blade * 90)
        arr[:, :, 0] = 12
        arr[:, :, 1] = 14
        arr[:, :, 2] = 20
        Image.fromarray(arr.astype(np.uint8), "RGBA").filter(ImageFilter.GaussianBlur(3)).save(fan_path)
        print("office_shadow_ceiling_fan (procedural fallback)")
    else:
        print("office_shadow_ceiling_fan: kept existing")


def main() -> None:
    RUNTIME.mkdir(parents=True, exist_ok=True)
    GEN.mkdir(parents=True, exist_ok=True)
    process_sheet(SHEET_A, 2, 2, SHEET_A_CELLS)
    process_sheet(SHEET_B, 3, 2, SHEET_B_CELLS)
    process_sheet(SHEET_C, 2, 2, SHEET_C_CELLS)
    process_waiting_ashtray()
    process_lights()
    print("done")


if __name__ == "__main__":
    main()

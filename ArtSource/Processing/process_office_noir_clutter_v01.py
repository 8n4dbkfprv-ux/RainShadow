"""Slice/chroma-key P1 noir clutter sheet + rug into runtime prop canvases."""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
GEN = ROOT / "ArtSource" / "Generated" / "Office" / "Props"
RUNTIME = ROOT / "RainShadow Shared" / "Resources" / "Art" / "Props" / "Office"

CLUTTER_SHEET = GEN / "office_noir_clutter_sheet_chroma_v01.png"
# Optional solo override: darker period metal bin (sheet cell kept as fallback).
WASTEBASKET_SOLO = GEN / "office_wastebasket_solo_chroma_v02.png"
RUG_SRC = GEN / "office_worn_rug_chroma_v01.png"

# 3×3 sheet cell order (row-major).
CLUTTER_CELLS: list[tuple[str, tuple[int, int]]] = [
    ("office_archive_box_a", (384, 384)),
    ("office_archive_box_b", (384, 384)),
    ("office_wastebasket", (256, 256)),
    ("office_floor_trash_a", (256, 192)),
    ("office_floor_trash_b", (256, 192)),
    ("office_floor_trash_c", (256, 192)),
    ("office_framed_photo", (256, 256)),
    ("office_hidden_bottle", (128, 256)),
    ("office_pencil_tray", (192, 96)),
]

RUG_CANVAS = (1024, 768)


def chroma_key(im: Image.Image, key=(0, 255, 0), tol=50.0, soft=18.0) -> Image.Image:
    """Hard green-screen key; also kills residual dark-green fringe."""
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
    """Scale prop to fit canvas; anchor near bottom-center for upright props."""
    cw, ch = canvas
    if im.width == 0 or im.height == 0:
        return Image.new("RGBA", canvas, (0, 0, 0, 0))
    scale = min(cw / im.width, ch / im.height)
    # Leave a tiny margin so soft edges aren't clipped.
    scale *= 0.94
    nw = max(1, int(round(im.width * scale)))
    nh = max(1, int(round(im.height * scale)))
    resized = im.resize((nw, nh), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", canvas, (0, 0, 0, 0))
    x = (cw - nw) // 2
    y = (ch - nh - 4) if bottom_bias else (ch - nh) // 2
    y = max(0, min(ch - nh, y))
    out.alpha_composite(resized, (x, y))
    return out


def slice_grid(sheet: Image.Image, cols: int = 3, rows: int = 3, inset: float = 0.04) -> list[Image.Image]:
    """Slice equal cells, inset slightly to avoid green grid gutters."""
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


def opaque_bbox(im: Image.Image, threshold: int = 40) -> tuple[int, int, int, int] | None:
    a = np.array(im.split()[-1])
    ys, xs = np.where(a > threshold)
    if len(xs) == 0:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def main() -> None:
    GEN.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)

    sheet = Image.open(CLUTTER_SHEET)
    cells = slice_grid(sheet)
    assert len(cells) == len(CLUTTER_CELLS)

    for cell, (name, canvas) in zip(cells, CLUTTER_CELLS, strict=True):
        if name == "office_wastebasket" and WASTEBASKET_SOLO.exists():
            keyed = trim_alpha(chroma_key(Image.open(WASTEBASKET_SOLO)))
            print(f"office_wastebasket: using solo override {WASTEBASKET_SOLO.name}")
        else:
            keyed = trim_alpha(chroma_key(cell))
        # Floor trash / pencil tray sit flatter; still bottom-bias for ground contact.
        bottom_bias = name != "office_pencil_tray"
        out = fit_into_canvas(keyed, canvas, bottom_bias=bottom_bias)
        out_path = RUNTIME / f"{name}.png"
        out.save(out_path)
        bbox = opaque_bbox(out)
        print(f"{name}: canvas={canvas} bbox={bbox} -> {out_path}")

        # Retain per-prop RGBA masters for provenance.
        master_suffix = "v02" if name == "office_wastebasket" and WASTEBASKET_SOLO.exists() else "v01"
        master = GEN / f"{name}_rgba_{master_suffix}.png"
        keyed.save(master)

    # Furniture V2 owns the runtime rug when present; do not clobber it with V1.
    rug_v02 = GEN / "office_worn_rug_chroma_v02.png"
    if rug_v02.exists():
        print(f"office_worn_rug: skipped (owned by {rug_v02.name})")
    else:
        rug_keyed = trim_alpha(chroma_key(Image.open(RUG_SRC)))
        rug = fit_into_canvas(rug_keyed, RUG_CANVAS, bottom_bias=False)
        rug_path = RUNTIME / "office_worn_rug.png"
        rug.save(rug_path)
        rug_keyed.save(GEN / "office_worn_rug_rgba_v01.png")
        print(f"office_worn_rug: canvas={RUG_CANVAS} bbox={opaque_bbox(rug)} -> {rug_path}")


if __name__ == "__main__":
    main()

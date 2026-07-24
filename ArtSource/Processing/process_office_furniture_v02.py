"""Slice/chroma-key furniture core V2 sheet + rug into runtime prop canvases."""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
GEN = ROOT / "ArtSource" / "Generated" / "Office" / "Props"
RUNTIME = ROOT / "RainShadow Shared" / "Resources" / "Art" / "Props" / "Office"

FURNITURE_SHEET = GEN / "office_furniture_core_sheet_chroma_v02.png"
# Optional solo override: matches NE seated bake (no swivel/casters).
DESK_CHAIR_SOLO = GEN / "office_desk_chair_solo_chroma_v02b.png"
RUG_SRC = GEN / "office_worn_rug_chroma_v02.png"

# 2×2 sheet cell order (row-major).
# target_content_h keeps BG body-multiple bands after seating/standard relative scales.
FURNITURE_CELLS: list[tuple[str, tuple[int, int], int]] = [
    ("office_desk_chair", (512, 768), 438),
    ("office_filing_cabinet", (512, 768), 549),
    ("office_visitor_armchair", (512, 512), 430),
    ("office_bookshelf", (512, 768), 700),
]

RUG_CANVAS = (1024, 768)
CABINET_SHADOW_CANVAS = (512, 384)


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


def fit_into_canvas(
    im: Image.Image,
    canvas: tuple[int, int],
    bottom_bias: bool = True,
    target_content_h: int | None = None,
) -> Image.Image:
    """Scale prop to fit canvas; optionally lock opaque height for scale bands."""
    cw, ch = canvas
    if im.width == 0 or im.height == 0:
        return Image.new("RGBA", canvas, (0, 0, 0, 0))
    src_h = opaque_content_height(im) or im.height
    if target_content_h and src_h > 0:
        scale = (target_content_h / src_h) * 0.98
        # Still must fit inside the canvas with a small margin.
        scale = min(scale, (cw * 0.94) / im.width, (ch * 0.94) / im.height)
    else:
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


def slice_grid(sheet: Image.Image, cols: int = 2, rows: int = 2, inset: float = 0.04) -> list[Image.Image]:
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


def opaque_content_height(im: Image.Image, threshold: int = 40) -> int:
    bbox = opaque_bbox(im, threshold)
    if bbox is None:
        return 0
    return bbox[3] - bbox[1]


def strip_soft_ground_shadow(im: Image.Image) -> Image.Image:
    """Remove dark soft ellipses under upright props (baked contact shadows)."""
    arr = np.array(im.convert("RGBA"), dtype=np.float32)
    rgb, a = arr[:, :, :3], arr[:, :, 3]
    lum = rgb.mean(axis=2)
    h = arr.shape[0]
    # Only consider lower third and very dark, low-chroma pixels.
    yy = np.arange(h)[:, None]
    in_lower = yy > (h * 0.62)
    dark = lum < 55
    chroma = rgb.max(axis=2) - rgb.min(axis=2)
    low_chroma = chroma < 28
    shadow = in_lower & dark & low_chroma & (a > 20)
    a = np.where(shadow, 0, a)
    rgb = np.where(a[..., None] < 8, 0, rgb)
    return Image.fromarray(np.dstack([rgb, a]).astype(np.uint8), "RGBA")


def make_cabinet_floor_shadow(cabinet: Image.Image) -> Image.Image:
    """Soft elliptical contact shadow sized from the cabinet footprint."""
    bbox = opaque_bbox(cabinet)
    if bbox is None:
        return Image.new("RGBA", CABINET_SHADOW_CANVAS, (0, 0, 0, 0))
    x0, _, x1, y1 = bbox
    foot_w = max(24, x1 - x0)
    # Dimetric floor ellipse under the cabinet base.
    cw, ch = CABINET_SHADOW_CANVAS
    yy, xx = np.mgrid[0:ch, 0:cw].astype(np.float32)
    cx, cy = (cw - 1) / 2.0, ch * 0.62
    rx = foot_w * 0.42
    ry = rx * 0.38
    r = np.sqrt(((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2)
    alpha = np.clip(1.0 - r, 0, 1)
    alpha = alpha * alpha * (3 - 2 * alpha)
    alpha = (alpha * 110).astype(np.uint8)
    rgb = np.zeros((ch, cw, 3), dtype=np.uint8)
    return Image.fromarray(np.dstack([rgb, alpha]), "RGBA")


def main() -> None:
    GEN.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)

    sheet = Image.open(FURNITURE_SHEET)
    cells = slice_grid(sheet)
    assert len(cells) == len(FURNITURE_CELLS)

    heights: dict[str, int] = {}
    cabinet_out: Image.Image | None = None

    for cell, (name, canvas, target_h) in zip(cells, FURNITURE_CELLS, strict=True):
        if name == "office_desk_chair" and DESK_CHAIR_SOLO.exists():
            keyed = trim_alpha(chroma_key(Image.open(DESK_CHAIR_SOLO)))
        else:
            keyed = trim_alpha(chroma_key(cell))
        keyed = strip_soft_ground_shadow(keyed)
        keyed = trim_alpha(keyed)
        out = fit_into_canvas(keyed, canvas, bottom_bias=True, target_content_h=target_h)
        out_path = RUNTIME / f"{name}.png"
        out.save(out_path)
        master = GEN / f"{name}_rgba_v02.png"
        keyed.save(master)
        bbox = opaque_bbox(out)
        h = opaque_content_height(out)
        heights[name] = h
        print(f"{name}: canvas={canvas} bbox={bbox} content_h={h} -> {out_path}")
        if name == "office_filing_cabinet":
            cabinet_out = out

    rug_keyed = trim_alpha(chroma_key(Image.open(RUG_SRC)))
    rug = fit_into_canvas(rug_keyed, RUG_CANVAS, bottom_bias=False)
    rug_path = RUNTIME / "office_worn_rug.png"
    rug.save(rug_path)
    rug_keyed.save(GEN / "office_worn_rug_rgba_v02.png")
    print(f"office_worn_rug: canvas={RUG_CANVAS} bbox={opaque_bbox(rug)} -> {rug_path}")

    if cabinet_out is not None:
        shadow = make_cabinet_floor_shadow(cabinet_out)
        shadow_path = RUNTIME / "office_cabinet_floor_shadow.png"
        shadow.save(shadow_path)
        shadow.save(GEN / "office_cabinet_floor_shadow_rgba_v02.png")
        print(f"office_cabinet_floor_shadow: canvas={CABINET_SHADOW_CANVAS} -> {shadow_path}")

    print("content_heights:", heights)


if __name__ == "__main__":
    main()

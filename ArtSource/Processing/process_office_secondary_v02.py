"""Re-slice coat rack + radiator from the secondary props sheet with safe keying.

The original secondary-props processor (now deleted) left semi-transparent
interiors on these two props. This re-export uses the shared chroma key only —
no shadow stripping — and preserves the shipped canvas sizes and opaque
content heights so in-game scale is unchanged.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
GEN = ROOT / "ArtSource" / "Generated" / "Office" / "Props"
RUNTIME = ROOT / "RainShadow Shared" / "Resources" / "Art" / "Props" / "Office"

SECONDARY_SHEET = GEN / "office_secondary_props_chroma_v01.png"

# 3x2 sheet: row 0 = swivel chair, filing cabinet, armchair (superseded by V2);
# row 1 = radiator, coat rack, door leaf. Only radiator + coat rack ship here.
# (name, (col, row), canvas, target opaque content height)
CELLS: list[tuple[str, tuple[int, int], tuple[int, int], int]] = [
    ("office_radiator", (0, 1), (322, 360), 338),
    ("office_coat_rack", (1, 1), (254, 570), 557),
]


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


def fit_into_canvas(im: Image.Image, canvas: tuple[int, int], target_content_h: int) -> Image.Image:
    """Scale so opaque content height matches the shipped asset, bottom-biased."""
    cw, ch = canvas
    src_h = opaque_content_height(im) or im.height
    scale = target_content_h / src_h
    scale = min(scale, cw / im.width, ch / im.height)
    nw = max(1, int(round(im.width * scale)))
    nh = max(1, int(round(im.height * scale)))
    resized = im.resize((nw, nh), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", canvas, (0, 0, 0, 0))
    x = (cw - nw) // 2
    y = max(0, ch - nh - 4)
    out.alpha_composite(resized, (x, y))
    return out


def main() -> None:
    sheet = Image.open(SECONDARY_SHEET)
    cw = sheet.width / 3
    rh = sheet.height / 2
    inset = 0.03

    for name, (col, row), canvas, target_h in CELLS:
        x0 = int(col * cw + cw * inset)
        y0 = int(row * rh + rh * inset)
        x1 = int((col + 1) * cw - cw * inset)
        y1 = int((row + 1) * rh - rh * inset)
        cell = sheet.crop((x0, y0, x1, y1))
        keyed = trim_alpha(chroma_key(cell))
        out = fit_into_canvas(keyed, canvas, target_h)
        out_path = RUNTIME / f"{name}.png"
        out.save(out_path)
        keyed.save(GEN / f"{name}_rgba_v02.png")
        print(f"{name}: canvas={canvas} bbox={opaque_bbox(out)} content_h={opaque_content_height(out)} -> {out_path}")


if __name__ == "__main__":
    main()

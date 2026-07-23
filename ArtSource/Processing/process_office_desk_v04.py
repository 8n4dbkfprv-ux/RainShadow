"""Normalize bare desk V4 (NE visitor face) + front occluder + floor shadow."""

from __future__ import annotations

import shutil
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
ASSETS = Path(
    "/Users/laurensvanoorschot/.cursor/projects/"
    "Users-laurensvanoorschot-Desktop-RainShadow/assets"
)
GEN = ROOT / "ArtSource" / "Generated" / "Office" / "Props"
RUNTIME = ROOT / "RainShadow Shared" / "Resources" / "Art" / "Props" / "Office"
CANVAS = (932, 780)


def chroma_key(im: Image.Image, key=(0, 255, 0), tol=48.0, soft=20.0) -> Image.Image:
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


def trim_alpha(im: Image.Image, threshold: int = 24, pad: int = 4) -> Image.Image:
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


def fit_canvas(im: Image.Image, canvas: tuple[int, int] = CANVAS) -> Image.Image:
    cw, ch = canvas
    scale = min(cw / im.width, ch / im.height) * 0.96
    nw = max(1, int(round(im.width * scale)))
    nh = max(1, int(round(im.height * scale)))
    resized = im.resize((nw, nh), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", canvas, (0, 0, 0, 0))
    # Ground-ish bias: bottom-center like other office props.
    x = (cw - nw) // 2
    y = max(0, ch - nh - 8)
    out.alpha_composite(resized, (x, y))
    return out


def front_occluder(bare: Image.Image) -> Image.Image:
    """Keep the camera-near / lower half of opaque desk as front occluder.

    For V4 the knee/detective side is camera-near (SW); visitor modesty is NE/far.
    Front occluder covers the near mass (legs + near top edge) for walk-past.
    """
    arr = np.array(bare, dtype=np.uint8)
    a = arr[:, :, 3]
    ys, xs = np.where(a > 40)
    if len(ys) == 0:
        return bare.copy()
    y0, y1 = int(ys.min()), int(ys.max())
    mid = y0 + int((y1 - y0) * 0.42)
    # Keep lower portion (near camera in this orientation) + a band of the top edge.
    keep = a.copy()
    keep[:mid, :] = 0
    # Also keep a thin silhouette rim of the whole desk for selection wash.
    out = arr.copy()
    out[:, :, 3] = keep
    return Image.fromarray(out, "RGBA")


def soft_desk_shadow(size=(1024, 512), strength=170) -> Image.Image:
    w, h = size
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    cx, cy = (w - 1) / 2, (h - 1) * 0.55
    nx = (xx - cx) / (w * 0.40)
    ny = (yy - cy) / (h * 0.28)
    r = np.sqrt(nx * nx + ny * ny)
    fall = np.clip(1 - r, 0, 1) ** 2
    alpha = (fall * strength).astype(np.uint8)
    rgb = np.zeros((h, w, 3), dtype=np.uint8)
    return Image.fromarray(np.dstack([rgb, alpha]), "RGBA")


def main() -> None:
    GEN.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)

    src = ASSETS / "office_desk_bare_v04b.png"
    if not src.exists():
        src = ASSETS / "office_desk_bare_v04.png"
    shutil.copy(src, GEN / "office_desk_bare_chroma_v04.png")

    bare = fit_canvas(trim_alpha(chroma_key(Image.open(src))))
    bare.save(GEN / "office_desk_bare_rgba_v04.png")
    bare.save(RUNTIME / "office_desk_bare.png")

    front = front_occluder(bare)
    front.save(GEN / "office_desk_front_occluder_rgba_v04.png")
    front.save(RUNTIME / "office_desk_front_occluder_v04.png")

    shadow = soft_desk_shadow()
    shadow.save(RUNTIME / "office_desk_floor_shadow.png")
    shadow.save(GEN / "office_desk_floor_shadow_rgba_v04.png")

    a = np.array(bare.split()[-1])
    ys = np.where(a > 40)[0]
    print("bare", bare.size, "content_h", int(ys.max() - ys.min() + 1) if len(ys) else 0)
    print("front opaque%", float((np.array(front)[:, :, 3] > 40).mean()))


if __name__ == "__main__":
    main()

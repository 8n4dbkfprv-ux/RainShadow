"""Chroma-key Pass B personal-corner props + internal door leaf into runtime canvases."""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
GEN = ROOT / "ArtSource" / "Generated" / "Office" / "Props"
RUNTIME = ROOT / "RainShadow Shared" / "Resources" / "Art" / "Props" / "Office"

# Prefer newest chroma masters when present.
SOURCES: list[tuple[str, Path, tuple[int, int], int | None]] = [
    ("office_personal_sideboard", GEN / "office_personal_sideboard_solo_chroma_v01.png", (384, 320), 220),
    ("office_personal_fan", GEN / "office_personal_fan_solo_chroma_v02.png", (256, 384), 300),
    ("office_personal_washbasin", GEN / "office_personal_washbasin_solo_chroma_v01.png", (280, 300), 210),
    ("office_personal_glass", GEN / "office_personal_glass_solo_chroma_v01.png", (96, 128), 70),
    # Canvas/target track partition opening (~394 px); prefer partition export for shear.
    ("office_internal_door_leaf", GEN / "office_internal_door_leaf_solo_chroma_v02.png", (320, 560), 394),
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


def opaque_content_height(im: Image.Image, threshold: int = 40) -> int:
    a = np.array(im.split()[-1])
    ys, _ = np.where(a > threshold)
    if len(ys) == 0:
        return 0
    return int(ys.max() - ys.min() + 1)


def fit_into_canvas(
    im: Image.Image,
    canvas: tuple[int, int],
    target_content_h: int | None = None,
) -> Image.Image:
    cw, ch = canvas
    if im.width == 0 or im.height == 0:
        return Image.new("RGBA", canvas, (0, 0, 0, 0))
    src_h = opaque_content_height(im) or im.height
    if target_content_h and src_h > 0:
        scale = (target_content_h / src_h) * 0.98
        scale = min(scale, (cw * 0.94) / im.width, (ch * 0.94) / im.height)
    else:
        scale = min(cw / im.width, ch / im.height) * 0.94
    nw = max(1, int(round(im.width * scale)))
    nh = max(1, int(round(im.height * scale)))
    resized = im.resize((nw, nh), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", canvas, (0, 0, 0, 0))
    x = (cw - nw) // 2
    y = max(0, min(ch - nh, ch - nh - 4))
    out.alpha_composite(resized, (x, y))
    return out


def strip_low_floor_ellipse(im: Image.Image) -> Image.Image:
    """Remove brown circular floor pads that sometimes bake under wash props."""
    arr = np.array(im.convert("RGBA"), dtype=np.float32)
    rgb, a = arr[:, :, :3], arr[:, :, 3]
    h = arr.shape[0]
    band = int(h * 0.22)
    y0 = h - band
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    brown = (r > 70) & (r < 170) & (g > 45) & (g < 130) & (b < g) & ((r - b) > 25)
    low = np.zeros_like(a, dtype=bool)
    low[y0:, :] = True
    kill = brown & low & (a > 20)
    # Keep opaque vertical object cores (high local vertical density)
    a[kill] = 0
    rgb[kill] = 0
    return Image.fromarray(np.dstack([rgb, a]).astype(np.uint8), "RGBA")


def blank_frosted_door_glass(im: Image.Image) -> Image.Image:
    """Overwrite any baked lettering with a blank frosted pane (deterministic, no IG text)."""
    arr = np.array(im.convert("RGBA"))
    a = arr[:, :, 3]
    ys, xs = np.where(a > 40)
    if len(xs) == 0:
        return im
    x0, x1 = int(xs.min()), int(xs.max())
    y0, y1 = int(ys.min()), int(ys.max())
    # Pane is the upper-central glass region of the leaf
    px0 = x0 + int((x1 - x0) * 0.18)
    px1 = x1 - int((x1 - x0) * 0.18)
    py0 = y0 + int((y1 - y0) * 0.10)
    py1 = y0 + int((y1 - y0) * 0.62)
    out = im.copy()
    draw = ImageDraw.Draw(out, "RGBA")
    # Soft frosted fill matching existing glass tone
    draw.rounded_rectangle(
        (px0, py0, px1, py1),
        radius=max(4, (px1 - px0) // 18),
        fill=(198, 206, 212, 210),
    )
    # Slight inner highlight band (blank — no glyphs)
    inset = max(3, (px1 - px0) // 20)
    draw.rounded_rectangle(
        (px0 + inset, py0 + inset, px1 - inset, py1 - inset),
        radius=max(3, (px1 - px0) // 22),
        fill=(214, 220, 224, 120),
    )
    return out.filter(ImageFilter.GaussianBlur(radius=0.35))


def main() -> None:
    RUNTIME.mkdir(parents=True, exist_ok=True)
    GEN.mkdir(parents=True, exist_ok=True)
    for name, src, canvas, target_h in SOURCES:
        if not src.exists():
            # Fan may still be v01 only
            alt = src.with_name(src.name.replace("_v02", "_v01"))
            if alt.exists():
                src = alt
            else:
                raise SystemExit(f"missing source {src}")
        keyed = trim_alpha(chroma_key(Image.open(src)))
        if "washbasin" in name:
            keyed = trim_alpha(strip_low_floor_ellipse(keyed))
        # Lettering is baked into IG door masters (H. VOSS). Do not blank glass.
        out = fit_into_canvas(keyed, canvas, target_content_h=target_h)
        dest = RUNTIME / f"{name}.png"
        master = GEN / f"{name}_rgba_v01.png"
        out.save(dest)
        out.save(master)
        print(f"wrote {dest.name} {out.size} contentH={opaque_content_height(out)}")


if __name__ == "__main__":
    main()


# Window texture sizing contract:
# Shell is drawn at size art*environment (0.395). The rectified window sprite
# uses yScale 0.32 (xScale remains 0.35).
# To match a recess of open_h art pixels: opaque_tex_h = open_h * 0.395 / 0.32
# Do NOT size as open_h/0.32 — that makes the prop ~2.5× too large in world space.
"""Normalize V5 door leaf + window insert (architecture stays in the shell plate)."""

from __future__ import annotations

import json
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
HINTS = ROOT / "tmp" / "imagegen" / "v06_layout_hints.json"
# Fallback for older runs that only wrote v05 hints.
HINTS_FALLBACK = ROOT / "tmp" / "imagegen" / "v05_layout_hints.json"


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
    return im.crop(
        (
            max(0, int(xs.min()) - pad),
            max(0, int(ys.min()) - pad),
            min(im.width, int(xs.max()) + 1 + pad),
            min(im.height, int(ys.max()) + 1 + pad),
        )
    )


def fit_height(im: Image.Image, target_h: int) -> Image.Image:
    a = np.array(im.split()[-1])
    ys = np.where(a > 40)[0]
    h = max(1, int(ys.max() - ys.min() + 1))
    scale = target_h / h
    return im.resize(
        (max(1, int(im.width * scale)), max(1, int(im.height * scale))),
        Image.Resampling.LANCZOS,
    )


def opaque_height(im: Image.Image) -> int:
    a = np.array(im.split()[-1])
    ys = np.where(a > 40)[0]
    return int(ys.max() - ys.min() + 1) if len(ys) else 0


def main() -> None:
    GEN.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)
    hints_path = HINTS if HINTS.exists() else HINTS_FALLBACK
    hints = json.loads(hints_path.read_text()) if hints_path.exists() else {}
    door_h = int(round(hints.get("doorOpeningH", 400) * 0.395 / 0.22))
    # Match the full raised recess (not only the clear glass) in world space.
    win_h = int(round(max(hints.get("windowOpeningH", 176), 100) * 0.395 / 0.32))

    leaf_src = ASSETS / "office_door_leaf_v05.png"
    win_src = ASSETS / "office_window_v05.png"
    for src in (leaf_src, win_src):
        if src.exists():
            shutil.copy(src, GEN / src.name)

    leaf = trim_alpha(fit_height(trim_alpha(chroma_key(Image.open(leaf_src))), door_h))
    leaf.save(RUNTIME / "office_door_leaf.png")
    closed = Image.new("RGBA", (512, 896), (0, 0, 0, 0))
    closed.alpha_composite(leaf, ((512 - leaf.width) // 2, max(0, 896 - leaf.height - 8)))
    closed.save(RUNTIME / "office_door_leaf_closed.png")

    win = trim_alpha(chroma_key(Image.open(win_src)))
    a = np.array(win.split()[-1])
    ys, xs = np.where(a > 100)
    if len(ys):
        win = win.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))
    win = trim_alpha(fit_height(win, win_h))
    win.save(RUNTIME / "office_window.png")

    print("door leaf", opaque_height(leaf), "multiple", opaque_height(leaf) * 0.22 / 82)
    print("window", opaque_height(win))


if __name__ == "__main__":
    main()

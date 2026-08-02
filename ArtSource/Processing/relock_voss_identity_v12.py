#!/usr/bin/env python3
"""Paperdoll-lock every Voss V11 pose frame into PreRendered3DV12 masters.

Pose/silhouette come from V11 per-frame chroma cells. Face/wardrobe/materials
are pulled toward the approved paperdoll V11 + SE key V12 identity lock via LAB
statistics transfer, selective coat/vest/skin pulls, and lower-hem smoothing
(removes the frayed-hem drift that landed in V11).

Outputs flat #00ff00 chroma frames under PreRendered3DV12/Frames/, then
composes the strip/cycle/sheet masters the V12 installer expects.
"""

from __future__ import annotations

from pathlib import Path
import re
import sys

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))

from compose_chroma_strip_v11 import compose  # noqa: E402

V11_FRAMES = ROOT / "ArtSource/Generated/Characters/Detective/PreRendered3DV11/Frames"
V12 = ROOT / "ArtSource/Generated/Characters/Detective/PreRendered3DV12"
V12_FRAMES = V12 / "Frames"
PAPERDOLL = ROOT / "ArtSource/Generated/Characters/Detective/Paperdoll/voss_paperdoll_front_chroma_v11.png"
KEY = V12 / "voss_key_se_chroma_v12.png"

GREEN = (0, 255, 0)
DIRECTIONS = ("s", "ssw", "sw", "wsw", "w", "wnw", "nw", "nnw", "n")


def is_chroma_green(rgb: np.ndarray) -> np.ndarray:
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return (g > 140) & (g > r + 40) & (g > b + 40)


def extract_figure_rgba(path: Path) -> Image.Image:
    im = Image.open(path).convert("RGBA")
    px = np.asarray(im).copy()
    green = is_chroma_green(px[..., :3].astype(np.int16))
    px[green, 3] = 0
    px[px[..., 3] < 8] = 0
    fig = Image.fromarray(px, "RGBA")
    bbox = fig.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError(f"No figure in {path}")
    return fig.crop(bbox)


def rgb_to_lab(rgb: np.ndarray) -> np.ndarray:
    """rgb uint8 HxWx3 -> LAB float."""
    arr = rgb.astype(np.float32) / 255.0
    mask = arr > 0.04045
    arr = np.where(mask, ((arr + 0.055) / 1.055) ** 2.4, arr / 12.92)
    m = np.array(
        [
            [0.4124564, 0.3575761, 0.1804375],
            [0.2126729, 0.7151522, 0.0721750],
            [0.0193339, 0.1191920, 0.9503041],
        ],
        dtype=np.float32,
    )
    xyz = arr @ m.T
    xyz[..., 0] /= 0.95047
    xyz[..., 2] /= 1.08883
    eps = 0.008856
    kappa = 903.3
    f = np.where(xyz > eps, np.cbrt(xyz), (kappa * xyz + 16.0) / 116.0)
    L = 116.0 * f[..., 1] - 16.0
    a = 500.0 * (f[..., 0] - f[..., 1])
    b = 200.0 * (f[..., 1] - f[..., 2])
    return np.stack([L, a, b], axis=-1)


def lab_to_rgb(lab: np.ndarray) -> np.ndarray:
    L, a, b = lab[..., 0], lab[..., 1], lab[..., 2]
    fy = (L + 16.0) / 116.0
    fx = a / 500.0 + fy
    fz = fy - b / 200.0
    eps = 0.008856
    kappa = 903.3

    def finv(t: np.ndarray) -> np.ndarray:
        t3 = t ** 3
        return np.where(t3 > eps, t3, (116.0 * t - 16.0) / kappa)

    xyz = np.stack([finv(fx) * 0.95047, finv(fy), finv(fz) * 1.08883], axis=-1)
    m = np.array(
        [
            [3.2404542, -1.5371385, -0.4985314],
            [-0.9692660, 1.8760108, 0.0415560],
            [0.0556434, -0.2040259, 1.0572252],
        ],
        dtype=np.float32,
    )
    rgb = xyz @ m.T
    mask = rgb > 0.0031308
    rgb = np.where(mask, 1.055 * np.power(np.clip(rgb, 0, None), 1 / 2.4) - 0.055, 12.92 * rgb)
    return (np.clip(rgb, 0, 1) * 255.0).astype(np.uint8)


def figure_stats(fig: Image.Image) -> tuple[np.ndarray, np.ndarray]:
    px = np.asarray(fig.convert("RGBA"))
    mask = px[..., 3] > 40
    lab = rgb_to_lab(px[..., :3])
    samples = lab[mask]
    return samples.mean(axis=0), samples.std(axis=0) + 1e-5


def region_means(fig: Image.Image) -> dict[str, np.ndarray]:
    """Heuristic region means in RGB from a standing paperdoll/key figure."""
    px = np.asarray(fig.convert("RGBA"))
    rgb = px[..., :3].astype(np.float32)
    a = px[..., 3] > 40
    h = px.shape[0]
    ys = np.where(a)[0]
    top, bot = int(ys.min()), int(ys.max())
    body_h = max(1, bot - top)

    def band(y0: float, y1: float) -> np.ndarray:
        y_lo = top + int(body_h * y0)
        y_hi = top + int(body_h * y1)
        m = a.copy()
        m[:y_lo] = False
        m[y_hi:] = False
        return rgb[m]

    head = band(0.00, 0.18)
    torso = band(0.18, 0.55)
    legs = band(0.55, 0.88)
    feet = band(0.88, 1.00)

    def mean_or(arr: np.ndarray, fallback: np.ndarray) -> np.ndarray:
        return arr.mean(axis=0) if len(arr) else fallback

    # Coat ≈ brown mid tones in torso (not mustard vest: higher G-B, higher L)
    coat_mask_vals = torso
    if len(coat_mask_vals):
        r, g, b = coat_mask_vals[:, 0], coat_mask_vals[:, 1], coat_mask_vals[:, 2]
        coat_sel = (r > g) & (r > b) & (r > 60) & (r < 180)
        coat = coat_mask_vals[coat_sel] if coat_sel.any() else coat_mask_vals
        vest_sel = (g > b + 5) & (r > 100) & (g > 90) & (r < 220)
        vest = coat_mask_vals[vest_sel] if vest_sel.any() else coat
    else:
        coat = vest = np.array([[120.0, 90.0, 55.0]])

    skin_sel = None
    if len(head):
        r, g, b = head[:, 0], head[:, 1], head[:, 2]
        skin_sel = (r > 90) & (g > 60) & (b > 40) & (r > b) & (r < 220) & ((r - b) > 15)
    skin = head[skin_sel] if skin_sel is not None and skin_sel.any() else head

    hair_sel = None
    if len(head):
        r, g, b = head[:, 0], head[:, 1], head[:, 2]
        hair_sel = (r < 90) & (g < 80) & (b < 70) & ((r + g + b) < 180)
    hair = head[hair_sel] if hair_sel is not None and hair_sel.any() else head

    trousers = legs
    shoes = feet
    fallback = rgb[a].mean(axis=0)
    return {
        "coat": mean_or(coat, fallback),
        "vest": mean_or(vest, fallback),
        "skin": mean_or(skin, fallback),
        "hair": mean_or(hair, fallback),
        "trousers": mean_or(trousers, fallback),
        "shoes": mean_or(shoes, fallback),
    }


def reinhard_transfer(
    src_rgb: np.ndarray, src_mask: np.ndarray, tgt_mean: np.ndarray, tgt_std: np.ndarray
) -> np.ndarray:
    lab = rgb_to_lab(src_rgb)
    samples = lab[src_mask]
    if len(samples) < 16:
        return src_rgb
    mean = samples.mean(axis=0)
    std = samples.std(axis=0) + 1e-5
    out = lab.copy()
    out[src_mask] = (lab[src_mask] - mean) * (tgt_std / std) + tgt_mean
    return lab_to_rgb(out)


def pull_regions(rgb: np.ndarray, mask: np.ndarray, targets: dict[str, np.ndarray], strength: float = 0.55) -> np.ndarray:
    """Blend classified pixels toward paperdoll region means."""
    out = rgb.astype(np.float32)
    r, g, b = out[..., 0], out[..., 1], out[..., 2]
    lum = 0.2126 * r + 0.7152 * g + 0.0722 * b

    coat = mask & (r > g) & (r > b) & (r > 55) & (r < 190) & (lum > 35) & (lum < 170)
    vest = mask & (g > b + 4) & (r > 95) & (g > 85) & (r < 230) & (lum > 80)
    skin = mask & (r > 95) & (g > 65) & (b > 45) & (r > b + 12) & (r < 225) & (lum > 70) & (lum < 200)
    hair = mask & (r < 95) & (g < 85) & (b < 75) & (lum < 95)
    trousers = mask & (lum < 85) & (np.abs(r.astype(np.int16) - g.astype(np.int16)) < 25) & (b <= g + 10)
    shoes = mask & (r > g) & (r > b) & (lum < 70) & (r > 40)

    def blend(sel: np.ndarray, target: np.ndarray, s: float) -> None:
        if not sel.any():
            return
        tgt = target.astype(np.float32)
        # Preserve local luminance ratio
        tl = 0.2126 * tgt[0] + 0.7152 * tgt[1] + 0.0722 * tgt[2] + 1e-5
        for c in range(3):
            channel = out[..., c]
            local = channel[sel]
            local_l = lum[sel] + 1e-5
            scaled = tgt[c] * (local_l / tl)
            channel[sel] = local * (1 - s) + scaled * s
            out[..., c] = channel

    blend(coat & ~vest, targets["coat"], strength)
    blend(vest, targets["vest"], strength * 0.85)
    blend(skin, targets["skin"], strength * 0.7)
    blend(hair, targets["hair"], strength * 0.65)
    blend(trousers & ~coat & ~shoes, targets["trousers"], strength * 0.75)
    blend(shoes, targets["shoes"], strength * 0.7)
    return np.clip(out, 0, 255).astype(np.uint8)


def smooth_lower_hem(rgba: Image.Image) -> Image.Image:
    """Reduce frayed jagged coat hem while keeping feet."""
    px = np.asarray(rgba.convert("RGBA")).copy()
    alpha = px[..., 3]
    ys, xs = np.where(alpha > 40)
    if len(ys) == 0:
        return rgba
    top, bot = int(ys.min()), int(ys.max())
    h = bot - top + 1
    # Lower third of body (coat hem zone), leave bottom-most feet band
    y0 = top + int(h * 0.62)
    y1 = top + int(h * 0.92)
    band = np.zeros_like(alpha, dtype=bool)
    band[y0:y1, :] = alpha[y0:y1, :] > 40
    # Morphological close on alpha in that band
    band_img = Image.fromarray((band.astype(np.uint8) * 255), "L")
    closed = band_img.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3))
    closed_a = np.asarray(closed)
    # Where closed fills small bites, inpaint from vertical neighbors
    fill = (closed_a > 128) & (alpha < 40) & (np.arange(alpha.shape[0])[:, None] >= y0) & (
        np.arange(alpha.shape[0])[:, None] < y1
    )
    if fill.any():
        # Sample color from nearest opaque above
        for y, x in zip(*np.where(fill)):
            src_y = y - 1
            while src_y >= top and alpha[src_y, x] < 40:
                src_y -= 1
            if src_y >= top and alpha[src_y, x] >= 40:
                px[y, x] = px[src_y, x]
                px[y, x, 3] = 200
    # Soft-erode tiny fringe spikes below closed silhouette
    spike = (alpha > 40) & (closed_a < 128) & (np.arange(alpha.shape[0])[:, None] >= y0) & (
        np.arange(alpha.shape[0])[:, None] < y1
    )
    # Only remove isolated spikes (low horizontal support)
    if spike.any():
        support = (
            np.pad(alpha > 40, ((0, 0), (1, 1)), constant_values=False)
        )
        horiz = support[:, 1:-1] & support[:, :-2] & support[:, 2:]
        kill = spike & ~horiz
        px[kill] = 0
    return Image.fromarray(px, "RGBA")


def relock_frame(pose_path: Path, tgt_mean: np.ndarray, tgt_std: np.ndarray, targets: dict[str, np.ndarray]) -> Image.Image:
    fig = extract_figure_rgba(pose_path)
    px = np.asarray(fig.convert("RGBA")).copy()
    mask = px[..., 3] > 40
    transferred = reinhard_transfer(px[..., :3], mask, tgt_mean, tgt_std)
    pulled = pull_regions(transferred, mask, targets, strength=0.58)
    px[..., :3] = pulled
    px[~mask, 3] = 0
    locked = Image.fromarray(px, "RGBA")
    locked = smooth_lower_hem(locked)
    # Paste onto generous chroma canvas matching common V11 frame sizes
    canvas_w = max(fig.width + 80, 512)
    canvas_h = max(fig.height + 80, 768)
    canvas = Image.new("RGB", (canvas_w, canvas_h), GREEN)
    # Keep alpha for paste
    locked_rgba = locked.convert("RGBA")
    x = (canvas_w - locked_rgba.width) // 2
    y = (canvas_h - locked_rgba.height) // 2
    canvas.paste(locked_rgba, (x, y), locked_rgba.split()[-1])
    # Force pure green elsewhere
    out = np.asarray(canvas.convert("RGBA")).copy()
    green = is_chroma_green(out[..., :3].astype(np.int16)) | (out[..., 3] < 8)
    # Re-read: canvas is RGB already green; ensure exact
    rgb = np.asarray(canvas).copy()
    # Where we pasted, keep; figure already composited. Ensure non-figure is pure green:
    # detect near-green leftover fringe and snap
    gmask = is_chroma_green(rgb.astype(np.int16))
    # Also treat very green-dominant fringe
    r, g, b = rgb[..., 0].astype(np.int16), rgb[..., 1].astype(np.int16), rgb[..., 2].astype(np.int16)
    fringe = (g > 120) & (g > r + 30) & (g > b + 30)
    rgb[gmask | fringe] = GREEN
    return Image.fromarray(rgb, "RGB")


def compose_all_strips() -> None:
    frames = V12_FRAMES
    # Walk cycles
    for d in DIRECTIONS:
        paths = [frames / f"voss_walk_{d}_{i:02d}_chroma_v12.png" for i in range(8)]
        compose(paths, V12 / f"voss_walk_{d}_cycle_chroma_v12.png", columns=8, rows=1)
    # Idle strips
    for d in DIRECTIONS:
        paths = [frames / f"voss_idle_{d}_{i:02d}_chroma_v12.png" for i in range(4)]
        compose(paths, V12 / f"voss_idle_{d}_strip_chroma_v12.png", columns=4, rows=1)
    # Seated
    paths = [frames / f"voss_seated_idle_{i:02d}_chroma_v12.png" for i in range(8)]
    compose(paths, V12 / "voss_seated_idle_strip_chroma_v12.png", columns=8, rows=1)
    # Transitions 4x3
    for stem in ("voss_stand_up", "voss_sit_down"):
        paths = [frames / f"{stem}_{i:02d}_chroma_v12.png" for i in range(12)]
        compose(paths, V12 / f"{stem}_sheet_chroma_v12.png", columns=4, rows=3)


def main() -> None:
    V12_FRAMES.mkdir(parents=True, exist_ok=True)
    paper = extract_figure_rgba(PAPERDOLL)
    key = extract_figure_rgba(KEY)
    # Blend stats: paperdoll dominant, key for dimetric lighting
    p_mean, p_std = figure_stats(paper)
    k_mean, k_std = figure_stats(key)
    tgt_mean = 0.7 * p_mean + 0.3 * k_mean
    tgt_std = 0.7 * p_std + 0.3 * k_std
    targets = region_means(paper)
    key_targets = region_means(key)
    for name in targets:
        targets[name] = 0.75 * targets[name] + 0.25 * key_targets[name]

    pose_paths = sorted(V11_FRAMES.glob("voss_*_chroma_v11.png"))
    if not pose_paths:
        raise FileNotFoundError(f"No V11 pose frames in {V11_FRAMES}")

    count = 0
    for path in pose_paths:
        name = path.name.replace("_chroma_v11.png", "_chroma_v12.png")
        dest = V12_FRAMES / name
        locked = relock_frame(path, tgt_mean, tgt_std, targets)
        locked.save(dest, optimize=True)
        count += 1
        if count % 20 == 0:
            print(f"relocked {count}/{len(pose_paths)}")

    print(f"Relocked {count} frames -> {V12_FRAMES}")
    compose_all_strips()
    print("Composed V12 chroma strips/sheets")


if __name__ == "__main__":
    main()

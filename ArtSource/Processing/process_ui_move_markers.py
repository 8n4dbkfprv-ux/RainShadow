#!/usr/bin/env python3
"""Chroma-key UI move-marker masters and derive the 8-frame converging loops.

Masters (green-key Image Generator outputs):
  ui_move_marker_master.png
  ui_move_marker_blocked_master.png
  ui_waypoint_pip_master.png

Writes keyed masters + runtime frames into ArtSource/Generated/UI/Common and
RainShadow Shared/Resources/Art/UI/Common.

Canvas sizes match the BG:EE nav diamond (128×96) and half-diamond pip.
"""

from __future__ import annotations

import shutil
from pathlib import Path

import numpy as np
from PIL import Image

import ie_projection as ie

ROOT = Path(__file__).resolve().parents[2]
ASSETS = Path.home() / ".cursor/projects/Users-laurensvanoorschot-Desktop-RainShadow/assets"
GEN = ROOT / "ArtSource/Generated/UI/Common"
RUNTIME = ROOT / "RainShadow Shared/Resources/Art/UI/Common"

FRAME_COUNT = 8
MARKER_SIZE = ie.RING_SIZE  # 128×96
PIP_SIZE = ie.PIP_SIZE  # 64×48


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


def fit_canvas(
    im: Image.Image, size: tuple[int, int], *, fill: float = 0.92
) -> Image.Image:
    cw, ch = size
    if im.width == 0 or im.height == 0:
        return Image.new("RGBA", size, (0, 0, 0, 0))
    scale = min(cw / im.width, ch / im.height) * fill
    nw = max(1, int(round(im.width * scale)))
    nh = max(1, int(round(im.height * scale)))
    resized = im.resize((nw, nh), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    out.alpha_composite(resized, ((cw - nw) // 2, (ch - nh) // 2))
    return out


def resolve_src(name: str) -> Path:
    candidates = [
        ASSETS / name,
        ROOT / "ArtSource/Generated/UI/Common" / name,
        ROOT / "ArtSource/Generated/UI" / name,
    ]
    for path in candidates:
        if path.exists():
            return path
    raise FileNotFoundError(f"Missing master: {name} (searched {candidates})")


def write_png(im: Image.Image, name: str, *, runtime: bool = True) -> None:
    GEN.mkdir(parents=True, exist_ok=True)
    gen_path = GEN / name
    im.save(gen_path, "PNG")
    if runtime:
        RUNTIME.mkdir(parents=True, exist_ok=True)
        runtime_path = RUNTIME / name
        shutil.copy2(gen_path, runtime_path)
        print(f"  wrote {runtime_path.relative_to(ROOT)}")
    else:
        print(f"  wrote {gen_path.relative_to(ROOT)} (generated only)")


def derive_frames(base: Image.Image, prefix: str) -> None:
    """Converging scale/alpha loop over FRAME_COUNT frames (BG:EE-style pulse).

    Classic IE destination feedback: large/faint → snap inward to solid →
    settle small while fading. Wider scale/alpha swing than the prior soft pulse
    so the motion reads at 48×24 display size.
    """
    for index in range(FRAME_COUNT):
        t = index / max(1, FRAME_COUNT - 1)
        if t < 0.28:
            # Snap-in: ease-out from oversized translucent to near-settled solid.
            local = t / 0.28
            ease = 1.0 - (1.0 - local) ** 2
            scale = 1.42 - 0.38 * ease  # 1.42 → ~1.04
            alpha = 0.28 + 0.72 * ease  # 0.28 → 1.00
        else:
            # Settle: ease-in contract + fade.
            local = (t - 0.28) / 0.72
            ease = local * local
            scale = 1.04 - 0.36 * ease  # 1.04 → 0.68
            alpha = 1.0 - 0.88 * ease   # 1.00 → 0.12

        cw, ch = base.size
        nw = max(1, int(round(cw * scale)))
        nh = max(1, int(round(ch * scale)))
        resized = base.resize((nw, nh), Image.Resampling.LANCZOS)
        rgba = np.array(resized.convert("RGBA"), dtype=np.float32)
        rgba[:, :, 3] = np.clip(rgba[:, :, 3] * alpha, 0, 255)
        resized = Image.fromarray(rgba.astype(np.uint8), "RGBA")

        frame = Image.new("RGBA", base.size, (0, 0, 0, 0))
        frame.alpha_composite(resized, ((cw - nw) // 2, (ch - nh) // 2))
        write_png(frame, f"{prefix}_{index:02d}.png")
        print(f"    {prefix}_{index:02d}: scale={scale:.3f} alpha={alpha:.3f}")


def process_marker(master_name: str, prefix: str, size: tuple[int, int]) -> Image.Image:
    src = resolve_src(master_name)
    print(f"processing {src.name} → {prefix}_*")
    keyed = chroma_key(Image.open(src))
    trimmed = trim_alpha(keyed)
    # Leave headroom so the 1.42× opening frame fits the canvas without clipping.
    fitted = fit_canvas(trimmed, size, fill=0.66)
    write_png(fitted, f"{prefix}_master_rgba.png", runtime=False)
    derive_frames(fitted, prefix)
    return fitted


def process_pip(master_name: str) -> None:
    src = resolve_src(master_name)
    print(f"processing {src.name} → ui_waypoint_pip")
    keyed = chroma_key(Image.open(src))
    trimmed = trim_alpha(keyed)
    fitted = fit_canvas(trimmed, PIP_SIZE)
    write_png(fitted, "ui_waypoint_pip.png")
    # Keep a copy of the keyed master for regeneration.
    write_png(fitted, "ui_waypoint_pip_master_rgba.png", runtime=False)


def main() -> None:
    process_marker("ui_move_marker_master.png", "ui_move_marker", MARKER_SIZE)
    process_marker(
        "ui_move_marker_blocked_master.png",
        "ui_move_marker_blocked",
        MARKER_SIZE,
    )
    # Also install a single-frame blocked fallback used by runtime.
    blocked_base = fit_canvas(
        trim_alpha(chroma_key(Image.open(resolve_src("ui_move_marker_blocked_master.png")))),
        MARKER_SIZE,
        fill=0.66,
    )
    write_png(blocked_base, "ui_move_marker_blocked.png")
    process_pip("ui_waypoint_pip_master.png")
    print("done.")


if __name__ == "__main__":
    main()

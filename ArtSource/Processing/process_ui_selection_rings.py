#!/usr/bin/env python3
"""Build painted underfoot selection rings (IE-style 16:12 ellipses).

Outputs:
  ui_selection_ring_party.png  — green PC/party ring
  ui_selection_ring_npc.png    — light gray/white NPC ring

If Image Generator masters exist (chroma green):
  ui_selection_ring_party_master.png
  ui_selection_ring_npc_master.png
they are keyed + fitted. Otherwise rings are synthesized procedurally.

Writes into ArtSource/Generated/UI/Common and
RainShadow Shared/Resources/Art/UI/Common.
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

RING_SIZE = ie.RING_SIZE  # 128×96 — one BG:EE nav diamond

# Classic IE selection green + light gray/white NPC.
PARTY_RGB = (32, 220, 48)
NPC_RGB = (220, 220, 220)


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


def resolve_src(name: str) -> Path | None:
    candidates = [
        ASSETS / name,
        ROOT / "ArtSource/Generated/UI/Common" / name,
        ROOT / "ArtSource/Generated/UI" / name,
    ]
    for path in candidates:
        if path.exists():
            return path
    return None


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


def synthesize_ring(
    rgb: tuple[int, int, int],
    size: tuple[int, int] = RING_SIZE,
    *,
    fill: float = 0.86,
) -> Image.Image:
    """Thin 16:12 IE selection ellipse with soft outer falloff."""
    return ie.synthesize_ground_ring(rgb, size, fill=fill)


def process_ring(name: str, master_name: str, rgb: tuple[int, int, int]) -> None:
    src = resolve_src(master_name)
    if src is not None:
        print(f"processing master {src.name} → {name}")
        keyed = chroma_key(Image.open(src))
        trimmed = trim_alpha(keyed)
        fitted = fit_canvas(trimmed, RING_SIZE, fill=0.88)
        write_png(fitted, f"{name}_master_rgba.png", runtime=False)
        write_png(fitted, f"{name}.png")
        return

    print(f"synthesizing {name} (no master {master_name})")
    ring = synthesize_ring(rgb)
    write_png(ring, f"{name}_master_rgba.png", runtime=False)
    write_png(ring, f"{name}.png")


def main() -> None:
    process_ring(
        "ui_selection_ring_party",
        "ui_selection_ring_party_master.png",
        PARTY_RGB,
    )
    process_ring(
        "ui_selection_ring_npc",
        "ui_selection_ring_npc_master.png",
        NPC_RGB,
    )
    print("done.")


if __name__ == "__main__":
    main()

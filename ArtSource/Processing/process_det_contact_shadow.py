#!/usr/bin/env python3
"""Build the soft underfoot actor contact shadow.

Runtime ID (AssetManifest §6):
  det_contact_shadow_soft  — 256×128 neutral soft floor ellipse with a slight
  directional cast tail; tinted/scaled at runtime by ContactShadowFactory.

Painted as grayscale alpha only (RGB black). Matches the office desk/cabinet
floor-shadow language: soft center, long outer falloff, mild upper-left key
bias so the lobe stretches lower-right.

Writes:
  ArtSource/Generated/Characters/det_contact_shadow_soft_rgba_v01.png
  RainShadow Shared/Resources/Art/UI/Common/det_contact_shadow_soft.png
"""

from __future__ import annotations

import shutil
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
GEN = ROOT / "ArtSource/Generated/Characters"
RUNTIME = ROOT / "RainShadow Shared/Resources/Art/UI/Common"

# AssetManifest canvas.
SIZE = (256, 128)


def paint_soft_contact_shadow(
    size: tuple[int, int] = SIZE,
    *,
    peak_alpha: float = 0.92,
) -> Image.Image:
    """Neutral soft floor ellipse + directional cast tail (upper-left key)."""
    w, h = size
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)

    # Primary contact disc — center nudged UL so the soft lobe reads SE.
    cx, cy = (w - 1) * 0.46, (h - 1) * 0.44
    rx, ry = w * 0.38, h * 0.32

    nx = (xx - cx) / rx
    ny = (yy - cy) / ry
    # Mild SE anisotropy (cast direction).
    cast_x = nx * 0.90 + 0.10
    cast_y = ny * 1.08 + 0.05
    r_core = np.sqrt(cast_x * cast_x + cast_y * cast_y)

    # Core contact: smoothstep with soft outer roll-off.
    t_core = np.clip(1.0 - r_core, 0.0, 1.0)
    t_core = t_core * t_core * (3.0 - 2.0 * t_core)
    t_core = np.power(t_core, 1.35)

    # Secondary longer cast tail toward lower-right (lamp/window key UL).
    cx2, cy2 = (w - 1) * 0.52, (h - 1) * 0.52
    rx2, ry2 = w * 0.48, h * 0.30
    nx2 = (xx - cx2) / rx2
    ny2 = (yy - cy2) / ry2
    r_tail = np.sqrt(nx2 * nx2 + ny2 * ny2)
    t_tail = np.clip(1.0 - r_tail, 0.0, 1.0)
    t_tail = t_tail * t_tail * (3.0 - 2.0 * t_tail)
    t_tail = np.power(t_tail, 1.8) * 0.38

    # Very soft outer haze so the edge dissolves into floorboards.
    rx3, ry3 = w * 0.52, h * 0.42
    nx3 = (xx - cx) / rx3
    ny3 = (yy - cy) / ry3
    r_haze = np.sqrt(nx3 * nx3 + ny3 * ny3)
    t_haze = np.clip(1.0 - r_haze, 0.0, 1.0)
    t_haze = np.power(t_haze, 2.4) * 0.22

    combined = np.clip(t_core + t_tail + t_haze, 0.0, 1.0)

    # Tiny low-frequency grain so it reads painted rather than perfect math.
    # Deterministic seed keeps regenerates pixel-stable.
    rng = np.random.default_rng(0xC0A7)
    grain = rng.normal(0.0, 0.012, size=(h, w)).astype(np.float32)
    g = np.pad(grain, 1, mode="edge")
    grain = (
        g[0:-2, 0:-2]
        + g[0:-2, 1:-1]
        + g[0:-2, 2:]
        + g[1:-1, 0:-2]
        + g[1:-1, 1:-1]
        + g[1:-1, 2:]
        + g[2:, 0:-2]
        + g[2:, 1:-1]
        + g[2:, 2:]
    ) / 9.0
    combined = np.clip(combined + grain * combined, 0.0, 1.0)

    alpha = (combined * peak_alpha * 255.0).astype(np.uint8)
    rgb = np.zeros((h, w, 3), dtype=np.uint8)
    return Image.fromarray(np.dstack([rgb, alpha]), "RGBA")


def main() -> None:
    GEN.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)

    shadow = paint_soft_contact_shadow()
    gen_path = GEN / "det_contact_shadow_soft_rgba_v01.png"
    runtime_path = RUNTIME / "det_contact_shadow_soft.png"
    shadow.save(gen_path, "PNG")
    shutil.copy2(gen_path, runtime_path)

    a = np.array(shadow.split()[-1])
    print(f"det_contact_shadow_soft: canvas={SIZE} peak_alpha={int(a.max())}")
    print(f"  generated: {gen_path.relative_to(ROOT)}")
    print(f"  runtime:   {runtime_path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

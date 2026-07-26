"""Key the four-cluster redesign masters into runtime sprites.

The Image Generator painted two chroma-green masters for the cramped-office
redesign:

  office_worn_rug_burgundy_chroma_v01.png   one large rug under the desk group
  office_filing_cabinet_open_chroma_v01.png records cabinet, one drawer open

This script keys the green, de-spills, trims to content and writes runtime
PNGs. Scale is left to the layout plan's body-multiple mechanism, so no
normalisation is needed here.

Usage:
    python3 ArtSource/Processing/process_office_redesign_props_v01.py
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
RUNTIME = ROOT / "RainShadow Shared/Resources/Art/Props/Office"
GENERATED = ROOT / "ArtSource/Generated/Office/Props"
MASTERS = Path.home() / ".cursor/projects/Users-laurensvanoorschot-Desktop-RainShadow/assets"

# (master, runtime, target content height in art px — None keeps native size).
# The open cabinet is normalised to the closed cabinet's 538 px content height
# so the scene's shared standardPropScale renders the pair at one size.
JOBS = (
    ("office_worn_rug_burgundy_chroma_v01.png", "office_worn_rug_burgundy.png", None),
    ("office_filing_cabinet_open_chroma_v01.png", "office_filing_cabinet_open.png", 538),
)


def key_chroma(path: Path, spill: float = 1.0) -> np.ndarray:
    """Generated master -> float RGBA with the green screen removed."""
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    greenness = g - np.maximum(r, b)
    alpha = np.clip(1.0 - (greenness - 8.0) / 46.0, 0.0, 1.0)
    ceiling = np.maximum(r, b) + 6.0
    over = np.maximum(g - ceiling, 0.0) * spill
    out = rgb.copy()
    out[..., 1] = g - over
    return np.dstack([out, alpha * 255.0])


def trim(rgba: np.ndarray, pad: int = 4, thresh: float = 24.0) -> np.ndarray:
    ys, xs = np.where(rgba[..., 3] > thresh)
    y0, y1 = max(ys.min() - pad, 0), min(ys.max() + 1 + pad, rgba.shape[0])
    x0, x1 = max(xs.min() - pad, 0), min(xs.max() + 1 + pad, rgba.shape[1])
    return rgba[y0:y1, x0:x1]


def main() -> None:
    RUNTIME.mkdir(parents=True, exist_ok=True)
    GENERATED.mkdir(parents=True, exist_ok=True)
    for master, runtime, target_h in JOBS:
        rgba = trim(key_chroma(MASTERS / master))
        image = Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8), "RGBA")
        if target_h is not None:
            factor = target_h / image.height
            image = image.resize(
                (max(1, round(image.width * factor)), target_h), Image.Resampling.LANCZOS
            )
        image.save(RUNTIME / runtime)
        image.save(GENERATED / runtime)
        a = np.asarray(image)[:, :, 3]
        print(f"wrote {runtime:36s} size={image.size} opaque={(a > 20).sum():,}")


if __name__ == "__main__":
    main()

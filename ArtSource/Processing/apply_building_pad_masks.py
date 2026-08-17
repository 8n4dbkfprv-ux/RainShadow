#!/usr/bin/env python3
"""Apply a pad-removed edit as a mask onto the original building sprite.

The edit is only used to decide which original pixels are ground-pad.
Building RGB and door pixels stay the authored art, so apertures hold.
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PROPS = ROOT / "RainShadow Shared" / "Resources" / "Art" / "Props" / "CityDistrict" / "V2"


def key_black(im: Image.Image, lum: float = 18.0) -> Image.Image:
    rgba = np.array(im.convert("RGBA"), dtype=np.float32)
    L = rgba[:, :, :3].mean(2)
    rgba[:, :, 3] = np.where(L < lum, 0, np.maximum(rgba[:, :, 3], 255))
    return Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8), "RGBA")


def apply_mask(original: Path, edited: Path) -> None:
    orig = np.array(Image.open(original).convert("RGBA"))
    eh, ew = orig.shape[0], orig.shape[1]
    edit = key_black(Image.open(edited).convert("RGBA"))
    edit_a = np.array(edit.resize((ew, eh), Image.Resampling.BILINEAR))[:, :, 3]
    oa = orig[:, :, 3]
    y = np.arange(eh)[:, None]
    # Pad is original paint the edit treated as background, in the lower half.
    pad = (oa > 36) & (edit_a < 24) & (y > int(eh * 0.52))
    orig[pad, :] = 0
    # Flatten remaining painted interior.
    painted = orig[:, :, 3] > 36
    orig[:, :, 3] = np.where(painted, 255, orig[:, :, 3])
    Image.fromarray(orig, "RGBA").save(original, "PNG", compress_level=4)
    print(f"masked {original.name}  erased {int(pad.mean()*100)}%")


def main() -> int:
    pairs = list(zip(sys.argv[1::2], sys.argv[2::2]))
    if not pairs:
        raise SystemExit("usage: apply_building_pad_masks.py orig edit [orig edit ...]")
    for o, e in pairs:
        apply_mask(Path(o), Path(e))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

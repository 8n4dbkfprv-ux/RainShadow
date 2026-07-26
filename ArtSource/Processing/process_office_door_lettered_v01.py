"""Ship Image Generator door leaves with baked H. VOSS glass lettering.

Sources (Cursor assets, prefer wide V8.1):
  office_internal_door_leaf_ig_v04_wide.png (fallback v03)
  office_door_leaf_ig_v07_wide.png (fallback v06)

Does NOT blank frosted glass — lettering is intentional.
Fits leaves into the partition/exterior opening without non-uniform stretch.
"""

from __future__ import annotations

import json
import shutil
from pathlib import Path

from PIL import Image

import process_office_partition_plate_v01 as part
from process_office_personal_corner_v01 import opaque_content_height
from process_office_window_door_v04 import chroma_key, fit_height, opaque_height, trim_alpha

ROOT = Path(__file__).resolve().parents[2]
ASSETS = Path.home() / ".cursor/projects/Users-laurensvanoorschot-Desktop-RainShadow/assets"
GEN = ROOT / "ArtSource/Generated/Office/Props"
RUNTIME = ROOT / "RainShadow Shared/Resources/Art/Props/Office"


def _first_existing(*names: str) -> Path:
    for name in names:
        path = ASSETS / name
        if path.exists():
            return path
    raise SystemExit(f"missing any of {names}")


def fit_cover(im: Image.Image, door_w: int, door_h: int) -> Image.Image:
    """Scale uniformly to cover the opening canvas (may crop edges slightly)."""
    body = trim_alpha(im)
    if body.width < 2 or body.height < 2:
        return Image.new("RGBA", (door_w, door_h), (0, 0, 0, 0))
    scale = max(door_w / body.width, door_h / body.height)
    nw = max(1, int(round(body.width * scale)))
    nh = max(1, int(round(body.height * scale)))
    resized = body.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (door_w, door_h), (0, 0, 0, 0))
    x = (door_w - nw) // 2
    y = (door_h - nh) // 2
    canvas.alpha_composite(resized, (x, y))
    return canvas


def ship_exterior() -> None:
    src = _first_existing("office_door_leaf_ig_v07_wide.png", "office_door_leaf_ig_v06.png")
    GEN.mkdir(parents=True, exist_ok=True)
    shutil.copy(src, GEN / src.name)
    # Classic ~2.2 H/W at 720 content height → ~327 wide (was ~235 skinny strip).
    door_h = 720
    door_w = int(round(door_h / 2.2))
    leaf = fit_cover(chroma_key(Image.open(src)), door_w, door_h)
    leaf.save(RUNTIME / "office_door_leaf.png")
    leaf.save(GEN / "office_door_leaf.png")
    closed = Image.new("RGBA", (512, 896), (0, 0, 0, 0))
    closed.alpha_composite(leaf, ((512 - leaf.width) // 2, max(0, 896 - leaf.height - 8)))
    closed.save(RUNTIME / "office_door_leaf_closed.png")
    print(
        "exterior",
        leaf.size,
        "contentH",
        opaque_height(leaf),
        f"H/W={opaque_height(leaf) / max(1, leaf.width):.2f}",
    )


def ship_internal() -> None:
    src = _first_existing(
        "office_internal_door_leaf_ig_v05_prop.png",
        "office_internal_door_leaf_ig_v04_wide.png",
        "office_internal_door_leaf_ig_v03.png",
    )
    shutil.copy(src, GEN / "office_internal_door_leaf_solo_chroma_v04.png")
    opening = json.loads((RUNTIME / "office_partition_opening.json").read_text(encoding="utf-8"))
    door_w = max(8, int(round(opening["opening_w_px"])))
    door_h = max(8, int(round(opening["opening_h_px"])))
    body = fit_cover(chroma_key(Image.open(src)), door_w, door_h)
    # export_leaf flips for hinge orientation — pre-flip so lettering reads correctly.
    body = body.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    master = GEN / "office_internal_door_leaf_lettered_master.png"
    body.save(master)
    leaf = part.export_leaf(opening, master)
    leaf.save(RUNTIME / "office_internal_door_leaf.png")
    leaf.save(GEN / "office_internal_door_leaf.png")
    print(
        "internal",
        leaf.size,
        "contentH",
        opaque_content_height(leaf),
        f"opening {door_w}x{door_h} H/W={door_h / door_w:.2f}",
    )


def main() -> None:
    RUNTIME.mkdir(parents=True, exist_ok=True)
    ship_exterior()
    ship_internal()
    print("NOTE: agency lettering is baked into PNGs; scene must not add SKLabelNodes.")


if __name__ == "__main__":
    main()

"""Ship Image Generator door leaves with baked H. VOSS glass lettering.

Sources (Cursor assets):
  office_internal_door_leaf_ig_v03.png
  office_door_leaf_ig_v06.png

Does NOT blank frosted glass — lettering is intentional.
"""

from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

from PIL import Image

import process_office_partition_plate_v01 as part
from process_office_personal_corner_v01 import opaque_content_height
from process_office_window_door_v04 import chroma_key, fit_height, opaque_height, trim_alpha

ROOT = Path(__file__).resolve().parents[2]
ASSETS = Path.home() / ".cursor/projects/Users-laurensvanoorschot-Desktop-RainShadow/assets"
GEN = ROOT / "ArtSource/Generated/Office/Props"
RUNTIME = ROOT / "RainShadow Shared/Resources/Art/Props/Office"


def ship_exterior() -> None:
    src = ASSETS / "office_door_leaf_ig_v06.png"
    if not src.exists():
        raise SystemExit(f"missing {src}")
    GEN.mkdir(parents=True, exist_ok=True)
    shutil.copy(src, GEN / src.name)
    leaf = fit_height(trim_alpha(chroma_key(Image.open(src))), 720)
    leaf.save(RUNTIME / "office_door_leaf.png")
    leaf.save(GEN / "office_door_leaf.png")
    closed = Image.new("RGBA", (512, 896), (0, 0, 0, 0))
    closed.alpha_composite(leaf, ((512 - leaf.width) // 2, max(0, 896 - leaf.height - 8)))
    closed.save(RUNTIME / "office_door_leaf_closed.png")
    print("exterior", leaf.size, "contentH", opaque_height(leaf))


def ship_internal() -> None:
    src = ASSETS / "office_internal_door_leaf_ig_v03.png"
    if not src.exists():
        raise SystemExit(f"missing {src}")
    shutil.copy(src, GEN / "office_internal_door_leaf_solo_chroma_v03.png")
    opening = json.loads((RUNTIME / "office_partition_opening.json").read_text(encoding="utf-8"))
    door_w = max(8, int(round(opening["opening_w_px"])))
    door_h = max(8, int(round(opening["opening_h_px"])))
    body = fit_height(trim_alpha(chroma_key(Image.open(src))), door_h)
    if body.width > door_w:
        s = door_w / body.width
        body = body.resize((door_w, max(1, int(body.height * s))), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (door_w, door_h), (0, 0, 0, 0))
    canvas.alpha_composite(body, ((door_w - body.width) // 2, max(0, door_h - body.height)))
    # export_leaf flips for hinge orientation — pre-flip so lettering reads correctly.
    canvas = canvas.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    master = GEN / "office_internal_door_leaf_lettered_master.png"
    canvas.save(master)
    leaf = part.export_leaf(opening, master)
    leaf.save(RUNTIME / "office_internal_door_leaf.png")
    leaf.save(GEN / "office_internal_door_leaf.png")
    print("internal", leaf.size, "contentH", opaque_content_height(leaf))


def main() -> None:
    RUNTIME.mkdir(parents=True, exist_ok=True)
    ship_exterior()
    ship_internal()
    print("NOTE: agency lettering is baked into PNGs; scene must not add SKLabelNodes.")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Frame-by-frame V7-vs-V14 strips for the chair clips.

`qa_crunch_v14_compare.py` shows one frame of each clip, which is not enough to
judge an animation — the things that go wrong in a sit/stand are crown-rise
smoothness, head-size pulsing and silhouette crawl across adjacent frames.

Every cell is cropped through the same foot-anchored window so the crown rise is
directly readable down the strip, and rows are stacked before/after.
Read-only apart from the sheet it writes.
"""

from __future__ import annotations

from PIL import Image, ImageDraw

from qa_pixelation_ab_v02 import OUTPUT, ROOT

ATLASES = ROOT / "RainShadow Shared/Resources/Art/Atlases"
BACKUP = ROOT / "ArtSource/Generated/Characters/RuntimeBackupPreRendered3DV13"

FOOT_Y = 434
WINDOW_TOP = FOOT_Y - 215
WINDOW_BOTTOM = FOOT_Y + 8
WINDOW_HALF_WIDTH = 60
ZOOM = 2

CLIPS = [
    ("VossSeatTransitions.atlas", "voss_stand_up_se", 12, "stand-up SE"),
    ("VossSeatTransitions.atlas", "voss_sit_down_se", 12, "sit-down SE"),
    ("VossSeatTransitions.atlas", "voss_stand_up_ne", 12, "stand-up NE"),
    ("VossSeatedIdle.atlas", "voss_seated_idle_ne", 8, "seated idle NE"),
]


def cell(base, atlas: str, name: str) -> Image.Image:
    """Foot-anchored crop, so every frame in a clip shares one reference frame."""
    frame = Image.open(base / atlas / name).convert("RGBA")
    centre = frame.width // 2
    crop = frame.crop(
        (centre - WINDOW_HALF_WIDTH, WINDOW_TOP, centre + WINDOW_HALF_WIDTH, WINDOW_BOTTOM)
    )
    return crop.resize((crop.width * ZOOM, crop.height * ZOOM), Image.Resampling.NEAREST)


def strip(base, atlas: str, stem: str, count: int, label: str) -> Image.Image:
    tiles = [cell(base, atlas, f"{stem}_{i:02d}.png") for i in range(count)]
    width, height = tiles[0].size
    band = 20
    sheet = Image.new("RGBA", (width * count, height + band), (18, 18, 20, 255))
    for index, tile in enumerate(tiles):
        sheet.alpha_composite(tile, (index * width, 0))
        ImageDraw.Draw(sheet).text((index * width + 4, height + 5), f"{index:02d}", fill=(150, 150, 150, 255))
    ImageDraw.Draw(sheet).text((6, height + 5), f"    {label}", fill=(235, 235, 235, 255))
    return sheet


def main() -> None:
    rows: list[Image.Image] = []
    for atlas, stem, count, label in CLIPS:
        rows.append(strip(BACKUP, atlas, stem, count, f"V7 before   {label}"))
        rows.append(strip(ATLASES, atlas, stem, count, f"V14 after   {label}"))
        rows.append(Image.new("RGBA", (rows[-1].width, 14), (10, 10, 12, 255)))

    width = max(row.width for row in rows)
    sheet = Image.new("RGBA", (width, sum(row.height for row in rows)), (10, 10, 12, 255))
    y = 0
    for row in rows:
        sheet.alpha_composite(row, (0, y))
        y += row.height

    out = OUTPUT / "qa_v14_seat_clips_before_after.png"
    sheet.convert("RGB").save(out, optimize=True)
    print(f"Wrote {out.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

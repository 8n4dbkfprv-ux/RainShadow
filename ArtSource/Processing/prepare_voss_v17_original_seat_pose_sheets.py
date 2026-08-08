#!/usr/bin/env python3
"""Build ordered contact sheets for V17 seated/stand-up ImageGen edits."""

from pathlib import Path

from PIL import Image


REPO = Path(__file__).resolve().parents[2]
V17 = REPO / "ArtSource/Generated/Characters/Detective/PreRendered3DV17"
POSES = V17 / "PoseAuthorities"
OUT = V17 / "OriginalSeat/PoseSheets"
GREEN = (0, 255, 0)


def make_sheet(clip: str, direction: str, count: int, columns: int, size: tuple[int, int]) -> Path:
    rows = (count + columns - 1) // columns
    sheet = Image.new("RGB", size, GREEN)
    for index in range(count):
        left = round((index % columns) * size[0] / columns)
        right = round((index % columns + 1) * size[0] / columns)
        top = round((index // columns) * size[1] / rows)
        bottom = round((index // columns + 1) * size[1] / rows)
        slot_w, slot_h = right - left, bottom - top
        source = Image.open(POSES / f"{clip}_{direction}_{index:02d}_pose_v17.png").convert("RGB")
        source.thumbnail((slot_w, slot_h), Image.Resampling.LANCZOS)
        x = left + (slot_w - source.width) // 2
        y = top + (slot_h - source.height) // 2
        sheet.paste(source, (x, y))
    OUT.mkdir(parents=True, exist_ok=True)
    destination = OUT / f"{clip}_{direction}_pose_sheet_v17.png"
    sheet.save(destination, optimize=True)
    return destination


def main() -> None:
    for direction in ("ne", "se"):
        print(make_sheet("seated_idle", direction, 8, 4, (1536, 1024)))
        print(make_sheet("stand_up", direction, 12, 3, (1024, 1536)))


if __name__ == "__main__":
    main()

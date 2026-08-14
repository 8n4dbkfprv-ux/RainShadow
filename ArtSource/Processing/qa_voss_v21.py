#!/usr/bin/env python3
"""Review strips and quarter-speed loops for V21 Voss. Never writes runtime art."""

from __future__ import annotations

import argparse
from pathlib import Path
import sys

from PIL import Image


PROCESSING_DIR = Path(__file__).resolve().parent
if str(PROCESSING_DIR) not in sys.path:
    sys.path.insert(0, str(PROCESSING_DIR))

import install_voss_v21 as v21  # noqa: E402
import qa_voss_v20 as qa20  # noqa: E402


def write_strip(cells: list[Image.Image], dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    width = sum(cell.width for cell in cells)
    height = max(cell.height for cell in cells)
    sheet = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    x = 0
    for cell in cells:
        sheet.alpha_composite(cell, (x, height - cell.height))
        x += cell.width
    sheet.save(dest)
    print(dest)


def write_gif(cells: list[Image.Image], dest: Path, duration_ms: int = 400) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    frames = [cell.convert("P", palette=Image.ADAPTIVE, colors=64) for cell in cells]
    frames[0].save(
        dest,
        save_all=True,
        append_images=frames[1:],
        duration=duration_ms,
        loop=0,
        disposal=2,
    )
    print(dest)


def load_stage_cells(atlas: str, stem: str, count: int) -> list[Image.Image]:
    stage = v21.V21_ROOT / "Staging"
    cells = []
    for phase in range(count):
        path = stage / atlas / f"{stem}_{phase:02d}.png"
        if not path.is_file():
            raise SystemExit(f"missing staged cell {path}")
        cells.append(Image.open(path).convert("RGBA"))
    return cells


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--direction", default="sw")
    args = parser.parse_args()
    qa = v21.V21_ROOT / "QA"
    qa.mkdir(parents=True, exist_ok=True)

    idle = load_stage_cells("VossIdle.atlas", f"voss_standing_idle_{args.direction}", 4)
    walk = load_stage_cells("VossWalk.atlas", f"voss_walk_{args.direction}", 8)
    write_strip(idle, qa / f"qa_v21_idle_{args.direction}_processed_strip.png")
    write_strip(walk, qa / f"qa_v21_walk_{args.direction}_processed_strip.png")
    write_gif(idle, qa / f"qa_v21_idle_{args.direction}_quarter_speed.gif", 400)
    write_gif(walk, qa / f"qa_v21_walk_{args.direction}_quarter_speed.gif", 200)

    western = {
        direction: Image.open(
            v21.V21_ROOT / "Staging" / "VossIdle.atlas" / f"voss_standing_idle_{direction}_00.png"
        ).convert("RGBA")
        for direction in v21.WESTERN_DIRECTIONS
        if (v21.V21_ROOT / "Staging" / "VossIdle.atlas" / f"voss_standing_idle_{direction}_00.png").is_file()
    }
    if len(western) == 9:
        facings = qa20.displayed_facings_from_western(western)
        qa20._write_facing_sheets(
            facings,
            qa,
            labelled_filename="qa_v21_16_facings_labelled.png",
            unlabelled_filename="qa_v21_16_facings_unlabelled.png",
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

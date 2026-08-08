#!/usr/bin/env python3
"""Render the rejected V17 SW ImageGen candidates as a strip and slow GIF."""

from __future__ import annotations

from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

PROCESSING_DIR = Path(__file__).resolve().parent
ROOT = PROCESSING_DIR.parents[1]
V17_ROOT = ROOT / "ArtSource/Generated/Characters/Detective/PreRendered3DV17"
SOURCE = V17_ROOT / "ProofCandidates/SWWalkV17"
OUTPUT = V17_ROOT / "QA"

if str(PROCESSING_DIR) not in sys.path:
    sys.path.insert(0, str(PROCESSING_DIR))
import install_voss_v17 as v17  # noqa: E402


def crop_keyed(path: Path) -> Image.Image:
    keyed = v17.key_chroma(v17.load_source(path))
    mask = v17.visible_mask(keyed)
    ys, xs = np.where(mask)
    if not len(xs):
        raise v17.V17ValidationError(f"candidate has no keyed figure: {path}")
    return keyed.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))


def fit(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    scale = min(size[0] / image.width, size[1] / image.height)
    resized = image.resize(
        (max(1, round(image.width * scale)), max(1, round(image.height * scale))),
        Image.Resampling.LANCZOS,
    )
    canvas = Image.new("RGBA", size, (38, 46, 54, 255))
    canvas.alpha_composite(resized, ((size[0] - resized.width) // 2, size[1] - resized.height - 18))
    return canvas


def contact_sheet(paths: list[Path], labels: list[str], destination: Path, columns: int) -> None:
    cells: list[Image.Image] = []
    font = ImageFont.load_default()
    for path, text in zip(paths, labels):
        cell = fit(crop_keyed(path), (260, 390))
        ImageDraw.Draw(cell).text((8, 8), text, fill=(232, 226, 212, 255), font=font)
        cells.append(cell)
    rows = (len(cells) + columns - 1) // columns
    sheet = Image.new("RGBA", (260 * columns, 390 * rows), (24, 28, 31, 255))
    for index, cell in enumerate(cells):
        sheet.alpha_composite(cell, ((index % columns) * 260, (index // columns) * 390))
    sheet.convert("RGB").save(destination, quality=96)


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    anchors = [
        V17_ROOT / "Anchors/voss_anchor_front_chroma_v17.png",
        V17_ROOT / "Anchors/voss_anchor_profile_w_chroma_v17.png",
        V17_ROOT / "Anchors/voss_anchor_back_chroma_v17.png",
        V17_ROOT / "Anchors/voss_anchor_dimetric_se_chroma_v17.png",
    ]
    contact_sheet(
        anchors,
        ["APPROVED FRONT", "APPROVED WEST PROFILE", "APPROVED BACK", "APPROVED DIMETRIC"],
        OUTPUT / "qa_v17_identity_anchors_approved.png",
        4,
    )
    directions = list(v17.WESTERN_DIRECTIONS)
    keys = [V17_ROOT / "Keys" / f"voss_key_{direction}_chroma_v17.png" for direction in directions]
    contact_sheet(
        keys,
        [f"APPROVED {direction.upper()} IDLE KEY" for direction in directions],
        OUTPUT / "qa_v17_nine_idle_keys_approved.png",
        5,
    )
    paths = [SOURCE / f"voss_walk_sw_{phase:02d}.png" for phase in range(8)]
    missing = [str(path) for path in paths if not path.is_file()]
    if missing:
        raise v17.V17ValidationError([f"missing proof candidate: {path}" for path in missing])
    frames = [fit(crop_keyed(path), (230, 360)) for path in paths]
    font = ImageFont.load_default()
    for phase, frame in enumerate(frames):
        draw = ImageDraw.Draw(frame)
        draw.text((8, 8), f"SW {phase:02d} - REJECTED PROOF", fill=(255, 218, 164, 255), font=font)
    strip = Image.new("RGBA", (230 * 8, 360), (24, 28, 31, 255))
    for phase, frame in enumerate(frames):
        strip.alpha_composite(frame, (phase * 230, 0))
    strip.convert("RGB").save(OUTPUT / "qa_v17_sw_walk_candidate_rejected.png", quality=96)
    rgb = [frame.convert("RGB") for frame in frames]
    rgb[0].save(
        OUTPUT / "qa_v17_sw_walk_candidate_rejected_quarter_speed.gif",
        save_all=True,
        append_images=rgb[1:],
        duration=360,
        loop=0,
        disposal=2,
    )
    print(f"Wrote approved gate sheets plus rejected proof strip/GIF under {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

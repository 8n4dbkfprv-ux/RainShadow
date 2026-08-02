#!/usr/bin/env python3
"""Compose per-frame chroma cells into a V8-compatible strip for V11 processing.

Expects frames named like ``{stem}_{00..N-1}_chroma_v11.png`` under a source
directory (or explicit paths). Writes ``{stem}_chroma_v11.png`` at 1536×1024
with figures centered in equal cells on #00ff00.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image


GREEN = (0, 255, 0, 255)
SHEET_SIZE = (1536, 1024)


def extract_figure(path: Path) -> Image.Image:
    im = Image.open(path).convert("RGBA")
    pixels = np.asarray(im)
    rgb = pixels[..., :3].astype(np.int16)
    green = (
        (rgb[..., 1] > 140)
        & (rgb[..., 1] > rgb[..., 0] + 40)
        & (rgb[..., 1] > rgb[..., 2] + 40)
    )
    alpha = np.where(green, 0, 255).astype(np.uint8)
    # Keep original RGB where opaque; zero keyed pixels.
    out = pixels.copy()
    out[..., 3] = alpha
    out[alpha == 0] = 0
    figure = Image.fromarray(out, "RGBA")
    bbox = figure.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError(f"No figure in {path}")
    return figure.crop(bbox)


def compose(frames: list[Path], dest: Path, columns: int | None = None, rows: int = 1) -> None:
    figures = [extract_figure(path) for path in frames]
    count = len(figures)
    if columns is None:
        columns = count if rows == 1 else max(1, -(-count // rows))
    if columns * rows < count:
        raise ValueError(f"grid {columns}x{rows} cannot hold {count} frames")

    sheet = Image.new("RGBA", SHEET_SIZE, GREEN)
    cell_w = SHEET_SIZE[0] // columns
    cell_h = SHEET_SIZE[1] // rows
    max_h = int(cell_h * 0.88)
    for index, figure in enumerate(figures):
        row, col = divmod(index, columns) if rows > 1 else (0, index)
        # Prefer row-major for multi-row sheets (stand-up 4x3).
        if rows > 1:
            row = index // columns
            col = index % columns
        scale = min(cell_w * 0.9 / figure.width, max_h / figure.height)
        size = (max(1, round(figure.width * scale)), max(1, round(figure.height * scale)))
        scaled = figure.resize(size, Image.Resampling.LANCZOS)
        x = col * cell_w + (cell_w - scaled.width) // 2
        y = row * cell_h + cell_h - scaled.height - int(cell_h * 0.06)
        sheet.alpha_composite(scaled, (x, y))

    dest.parent.mkdir(parents=True, exist_ok=True)
    # Flatten onto opaque green for chroma masters.
    flat = Image.new("RGB", SHEET_SIZE, (0, 255, 0))
    flat.paste(sheet, mask=sheet.split()[-1])
    flat.save(dest, optimize=True)
    print(f"wrote {dest} ({count} figures, {columns}x{rows})")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("dest", type=Path, help="Output chroma strip path")
    parser.add_argument("frames", nargs="+", type=Path, help="Ordered frame chroma paths")
    parser.add_argument("--columns", type=int, default=None)
    parser.add_argument("--rows", type=int, default=1)
    args = parser.parse_args()
    compose(args.frames, args.dest, columns=args.columns, rows=args.rows)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Key, crunch, and compose Voss V22 model-locked SW proof cells.

This script never writes runtime atlases. It runs the V16/V14 crunch
(``install_voss_v16`` + ``crunch.py``) against masters under
``PreRendered3DV22/``. Wardrobe hue is preserved — the 3D model lock
(open brown coat, brown waistcoat, maroon tie) must survive the raster.
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import sys
from typing import Sequence

import numpy as np
from PIL import Image

os.environ["RAINSHADOW_PRESERVE_WARDROBE"] = "1"

PROCESSING_DIR = Path(__file__).resolve().parent
ROOT = PROCESSING_DIR.parents[1]
if str(PROCESSING_DIR) not in sys.path:
    sys.path.insert(0, str(PROCESSING_DIR))

import crunch  # noqa: E402
import install_voss_v16 as core  # noqa: E402
import process_voss_character_strip_v21 as v21  # noqa: E402

crunch.PRESERVE_WARDROBE = True

V22_ROOT = ROOT / "ArtSource/Generated/Characters/Detective/PreRendered3DV22"
GREEN = (0, 255, 0, 255)
WESTERN_DIRECTIONS = core.WESTERN_DIRECTIONS
SEAT_DIRECTIONS = core.SEAT_DIRECTIONS
v21.V21_ROOT = V22_ROOT
v21.PROVENANCE_PATH = V22_ROOT / "imagegen_provenance_v22.json"


def _raw_paths(group: str, direction: str, count: int) -> list[Path]:
    stem = "idle" if group == "standing_idle" else group
    stills = V22_ROOT / "Stills"
    paths = [stills / f"voss_{stem}_{direction}_{phase:02d}_raw_v22.png" for phase in range(count)]
    missing = [path for path in paths if not path.is_file()]
    if missing:
        names = ", ".join(path.name for path in missing)
        raise SystemExit(f"missing raw stills: {names}")
    return paths


def _body_luma(image: Image.Image) -> np.ndarray:
    pixels = np.asarray(image.convert("RGBA"))
    body = pixels[..., :3][pixels[..., 3] >= 16].astype(np.float64)
    if len(body) == 0:
        return np.zeros(0)
    return 0.3 * body[:, 0] + 0.59 * body[:, 1] + 0.11 * body[:, 2]


def _match_idle_value(
    figure: Image.Image, target_mean: float, target_p90: float
) -> Image.Image:
    """Hold one idle phase to the clip's phase-00 exposure and highlight tail."""
    pixels = np.asarray(figure.convert("RGBA")).astype(np.float64)
    mask = pixels[..., 3] >= 16
    if not mask.any():
        return figure
    rgb = pixels[..., :3]
    luma = 0.3 * rgb[..., 0] + 0.59 * rgb[..., 1] + 0.11 * rgb[..., 2]
    mean = float(luma[mask].mean())
    rgb[mask] = np.clip(rgb[mask] * (target_mean / max(mean, 1e-6)), 0, 255)
    luma = 0.3 * rgb[..., 0] + 0.59 * rgb[..., 1] + 0.11 * rgb[..., 2]
    p90 = float(np.percentile(luma[mask], 90))
    median = float(np.median(luma[mask]))
    span = p90 - median
    new_span = target_p90 - median
    if span > 1.0 and new_span > 0 and abs(p90 - target_p90) > 1.0:
        hot = mask & (luma > median)
        rgb[hot] = np.clip(rgb[hot] * (new_span / span), 0, 255)
    pixels[..., :3] = rgb
    return Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8), "RGBA")


def match_cell_mean(cell: Image.Image, target_mean: float) -> Image.Image:
    """Scale one registered cell's body to a target mean luma. Highlights follow."""
    pixels = np.asarray(cell.convert("RGBA")).astype(np.float64)
    mask = pixels[..., 3] >= 16
    if mask.shape[0] == core.FRAME_SIZE and mask.shape[1] == core.FRAME_SIZE:
        mask = mask.copy()
        mask[0, 0] = False
        mask[0, -1] = False
        mask[-1, 0] = False
        mask[-1, -1] = False
    if not mask.any():
        return cell
    rgb = pixels[..., :3]
    luma = 0.3 * rgb[..., 0] + 0.59 * rgb[..., 1] + 0.11 * rgb[..., 2]
    mean = float(luma[mask].mean())
    rgb[mask] = np.clip(rgb[mask] * (target_mean / max(mean, 1e-6)), 0, 255)
    pixels[..., :3] = rgb
    return Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8), "RGBA")


def clip_cell_highlights(cell: Image.Image, target_p90: float) -> Image.Image:
    """Pull a registered cell's highlight tail down to a target without lifting the floor."""
    pixels = np.asarray(cell.convert("RGBA")).astype(np.float64)
    mask = pixels[..., 3] >= 16
    if mask.shape[0] == core.FRAME_SIZE and mask.shape[1] == core.FRAME_SIZE:
        mask = mask.copy()
        mask[0, 0] = False
        mask[0, -1] = False
        mask[-1, 0] = False
        mask[-1, -1] = False
    if not mask.any():
        return cell
    rgb = pixels[..., :3]
    luma = 0.3 * rgb[..., 0] + 0.59 * rgb[..., 1] + 0.11 * rgb[..., 2]
    p90 = float(np.percentile(luma[mask], 90))
    if p90 <= target_p90 + 1.0:
        return cell
    hot = mask & (luma > np.median(luma[mask]))
    rgb[hot] = np.clip(rgb[hot] * (target_p90 / max(p90, 1e-6)), 0, 255)
    pixels[..., :3] = rgb
    return Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8), "RGBA")


def ensure_minimum_head_width(cell: Image.Image, minimum: int = 19) -> Image.Image:
    """Widen a registered cell just enough for the seat head-width gate."""
    metrics = core.frame_metrics(cell)
    if metrics.head_width >= minimum:
        return cell
    x0, y0, x1, y1 = core.visible_bbox(cell)
    figure = cell.crop((x0, y0, x1 + 1, y1 + 1))
    new_width = max(
        figure.size[0] + 1,
        round(figure.size[0] * minimum / max(1, metrics.head_width)),
    )
    figure = figure.resize((new_width, figure.size[1]), Image.Resampling.NEAREST)
    return core.register_crunched(figure, body_axis=False)


def _temporal_smooth_standup(
    figures: Sequence[Image.Image], amount: float = 0.30
) -> list[Image.Image]:
    """Mix mid-rise colour with neighbours without changing the silhouette."""

    def resize_to(figure: Image.Image, size: tuple[int, int]) -> Image.Image:
        if figure.size == size:
            return figure
        return crunch.raster.premultiplied_resize(figure, size)

    smoothed = [figures[0]]
    for index in range(1, len(figures) - 1):
        current = figures[index]
        previous = resize_to(figures[index - 1], current.size)
        following = resize_to(figures[index + 1], current.size)
        current_px = np.asarray(current.convert("RGBA")).astype(np.float64)
        mixed = (
            current_px * (1.0 - amount)
            + np.asarray(previous.convert("RGBA")).astype(np.float64) * (0.5 * amount)
            + np.asarray(following.convert("RGBA")).astype(np.float64) * (0.5 * amount)
        )
        mixed[..., 3] = current_px[..., 3]
        mixed[current_px[..., 3] < 16] = 0
        smoothed.append(Image.fromarray(np.clip(mixed, 0, 255).astype(np.uint8), "RGBA"))
    smoothed.append(figures[-1])
    return smoothed


def stabilize_standup_figures(figures: Sequence[Image.Image]) -> list[Image.Image]:
    """Hold a 12-frame stand-up to a linear width and value ramp between endpoints.

    The restage already interpolates height so the rise is smooth. ImageGen
    frames still arrive with unrelated aspect ratios and highlight tails, so
    width and exposure pop even while the crown climbs one step per cell.
    Neighbour colour mixing damps a one-frame lighting flash without morphing
    the pose. Phase 00 and 11 keep their own size and value so the seated and
    standing handoffs stay put; sit-down is the reverse of the result.
    """
    if len(figures) != 12:
        raise ValueError(f"stand-up lock expects 12 cells, got {len(figures)}")
    first, last = figures[0], figures[-1]
    width_start, width_end = first.size[0], last.size[0]
    luma_start = _body_luma(first)
    luma_end = _body_luma(last)
    mean_start = float(luma_start.mean()) if len(luma_start) else 1.0
    mean_end = float(luma_end.mean()) if len(luma_end) else mean_start
    p90_start = float(np.percentile(luma_start, 90)) if len(luma_start) else mean_start
    p90_end = float(np.percentile(luma_end, 90)) if len(luma_end) else mean_end
    locked: list[Image.Image] = []
    for index, figure in enumerate(figures):
        t = index / 11
        target_width = max(1, round(width_start + t * (width_end - width_start)))
        target_height = max(1, figure.size[1])
        if figure.size != (target_width, target_height):
            figure = crunch.raster.premultiplied_resize(figure, (target_width, target_height))
        locked.append(figure)
    locked = _temporal_smooth_standup(locked)
    for index in range(1, 11):
        t = index / 11
        locked[index] = _match_idle_value(
            locked[index],
            mean_start + t * (mean_end - mean_start),
            p90_start + t * (p90_end - p90_start),
        )
    return locked


def stabilize_idle_keyed(frames: Sequence[Image.Image]) -> list[Image.Image]:
    """Lock idle phases to phase 00 scale, silhouette, and value so the loop cannot pop.

    ImageGen idle breaths come back a few percent taller, skinnier, or hotter
    than phase 00. V15 rasters at 200 native rows, so that source drift survives
    into the texture as a size pop and a highlight flicker. Seat and walk clips
    must keep their own proportions; this is idle-only.
    """
    if len(frames) < 2:
        return list(frames)
    authority = frames[0]
    x0, y0, x1, y1 = core.visible_bbox(authority)
    target_size = (x1 - x0 + 1, y1 - y0 + 1)
    authority_figure = authority.crop((x0, y0, x1 + 1, y1 + 1))
    luma = _body_luma(authority_figure)
    target_mean = float(luma.mean()) if len(luma) else 1.0
    target_p90 = float(np.percentile(luma, 90)) if len(luma) else target_mean
    locked = [authority]
    # Keep a readable breath (phase 02 is the apex) without letting ImageGen
    # replace the silhouette or the lighting.
    blends = {1: 0.34, 2: 0.42, 3: 0.34}
    auth_px = np.asarray(authority_figure.convert("RGBA")).astype(np.float64)
    for index, frame in enumerate(frames[1:], start=1):
        left, top, right, bottom = core.visible_bbox(frame)
        figure = frame.crop((left, top, right + 1, bottom + 1))
        figure = crunch.raster.premultiplied_resize(figure, target_size)
        other = np.asarray(figure.convert("RGBA")).astype(np.float64)
        amount = blends.get(index, 0.34)
        mixed = auth_px * (1.0 - amount) + other * amount
        # Phase 00 owns the silhouette. Unioning alphas re-widened hair and coat
        # hems — the pop this lock is meant to kill.
        mixed[..., 3] = auth_px[..., 3]
        mixed[auth_px[..., 3] < 16] = 0
        figure = Image.fromarray(np.clip(mixed, 0, 255).astype(np.uint8), "RGBA")
        figure = _match_idle_value(figure, target_mean, target_p90)
        locked.append(figure)
    return locked


def process_clip(
    group: str,
    direction: str,
    sources: Sequence[Path],
    dest_dir: Path,
    *,
    reference_height: int | None = None,
    body_axis: bool = True,
) -> list[Path]:
    """Crunch one clip with a shared exposure and shared palette."""
    keyed = [core.key_chroma(core.load_source(path)) for path in sources]
    if group == "standing_idle":
        keyed = stabilize_idle_keyed(keyed)
    levelled, factors = crunch.normalise_clip_exposure(keyed)
    palette = crunch.build_clip_palette(levelled)
    dest_dir.mkdir(parents=True, exist_ok=True)
    written: list[Path] = []
    stem = "idle" if group == "standing_idle" else group
    for phase, frame in enumerate(levelled):
        cell = core.process_keyed_figure(
            frame,
            palette=palette,
            body_axis=body_axis,
            reference_height=reference_height,
        )
        path = dest_dir / f"voss_{stem}_{direction}_{phase:02d}_processed_v22.png"
        core.save_png(cell, path)
        written.append(path)
    print(
        f"processed {group}:{direction} "
        f"({len(written)} cells, shared_palette={palette is not None}, "
        f"exposure={','.join(f'{factor:.3f}' for factor in factors)})"
    )
    return written


def compose_idle_walk_sheet(
    idle: Sequence[Path],
    walk: Sequence[Path],
    destination: Path,
    *,
    background: tuple[int, int, int, int] = GREEN,
) -> Path:
    """Tile processed 512 cells: idle on row 0 cols 0-3, walk on row 1."""
    if len(idle) != 4:
        raise SystemExit(f"idle sheet expects 4 cells, got {len(idle)}")
    if len(walk) != 8:
        raise SystemExit(f"walk sheet expects 8 cells, got {len(walk)}")
    cell = 512
    sheet = Image.new("RGBA", (cell * 8, cell * 2), background)
    for index, path in enumerate(idle):
        frame = Image.open(path).convert("RGBA")
        if frame.size != (cell, cell):
            raise SystemExit(f"{path.name} is {frame.size}, expected {cell}x{cell}")
        sheet.alpha_composite(frame, (index * cell, 0))
    for index, path in enumerate(walk):
        frame = Image.open(path).convert("RGBA")
        if frame.size != (cell, cell):
            raise SystemExit(f"{path.name} is {frame.size}, expected {cell}x{cell}")
        sheet.alpha_composite(frame, (index * cell, cell))
    destination.parent.mkdir(parents=True, exist_ok=True)
    if background[3] == 255 and background[:3] == (0, 255, 0):
        rgb = Image.new("RGB", sheet.size, (0, 255, 0))
        rgb.paste(sheet.convert("RGB"), mask=sheet.getchannel("A"))
        rgb.save(destination)
    else:
        sheet.save(destination)
    shown = destination
    try:
        shown = destination.relative_to(ROOT)
    except ValueError:
        pass
    print(f"wrote sheet {shown}")
    return destination


def _compose_chroma_proof_sheet(
    idle: Sequence[Path], walk: Sequence[Path], destination: Path
) -> Path:
    """Two-row chroma sprite sheet: 4 idle (left-aligned) over 8 walk."""
    figures: list[Image.Image] = []
    for path in list(idle) + list(walk):
        keyed = core.key_chroma(core.load_source(path))
        bbox = keyed.getchannel("A").getbbox()
        if bbox is None:
            raise SystemExit(f"no figure in {path}")
        figures.append(keyed.crop(bbox))
    max_w = max(figure.width for figure in figures)
    max_h = max(figure.height for figure in figures)
    cell_w = max_w + 24
    cell_h = max_h + 24
    sheet = Image.new("RGBA", (cell_w * 8, cell_h * 2), GREEN)
    for index, figure in enumerate(figures[:4]):
        left = index * cell_w + (cell_w - figure.width) // 2
        top = cell_h - figure.height - 8
        sheet.alpha_composite(figure, (left, top))
    for index, figure in enumerate(figures[4:]):
        left = index * cell_w + (cell_w - figure.width) // 2
        top = cell_h + cell_h - figure.height - 8
        sheet.alpha_composite(figure, (left, top))
    destination.parent.mkdir(parents=True, exist_ok=True)
    rgb = Image.new("RGB", sheet.size, (0, 255, 0))
    rgb.paste(sheet.convert("RGB"), mask=sheet.getchannel("A"))
    rgb.save(destination)
    shown = destination
    try:
        shown = destination.relative_to(ROOT)
    except ValueError:
        pass
    print(f"wrote sheet {shown}")
    return destination


def compose_stills_sheet(stills: Sequence[Path], destination: Path) -> Path:
    """Horizontal 9-facing chroma strip in western order."""
    if len(stills) != 9:
        raise SystemExit(f"stills sheet expects 9 cells, got {len(stills)}")
    return v21.compose_strip(stills, destination)


def _write_chroma_clip(group: str, direction: str, sources: Sequence[Path]) -> list[Path]:
    stem = "idle" if group == "standing_idle" else group
    dest_dir = V22_ROOT / "Frames"
    dest_dir.mkdir(parents=True, exist_ok=True)
    written: list[Path] = []
    for phase, source in enumerate(sources):
        dest = dest_dir / f"voss_{stem}_{direction}_{phase:02d}_chroma_v22.png"
        v21.write_chroma(source, dest)
        written.append(dest)
    print(f"wrote {len(written)} {group}:{direction} chroma masters")
    return written


def proof_facing(direction: str) -> int:
    """Chroma, crunch, and compose idle+walk for one western facing."""
    if direction not in WESTERN_DIRECTIONS:
        raise SystemExit(f"unknown facing {direction}")
    idle_raw = _raw_paths("standing_idle", direction, 4)
    walk_raw = _raw_paths("walk", direction, 8)
    processed = V22_ROOT / "Processed"
    sheets = V22_ROOT / "Sheets"
    for name in ("Frames", "Processed", "Sheets"):
        (V22_ROOT / name).mkdir(parents=True, exist_ok=True)
    idle_chroma = _write_chroma_clip("standing_idle", direction, idle_raw)
    walk_chroma = _write_chroma_clip("walk", direction, walk_raw)
    v21.compose_strip(idle_chroma, sheets / f"voss_idle_{direction}_strip_chroma_v22.png")
    v21.compose_strip(walk_chroma, sheets / f"voss_walk_{direction}_strip_chroma_v22.png")
    _compose_chroma_proof_sheet(
        idle_chroma,
        walk_chroma,
        sheets / f"voss_{direction}_idle_walk_chroma_sheet_v22.png",
    )
    idle_cells = process_clip("standing_idle", direction, idle_chroma, processed)
    walk_cells = process_clip("walk", direction, walk_chroma, processed)
    v21.compose_strip(idle_cells, sheets / f"voss_idle_{direction}_strip_processed_v22.png")
    v21.compose_strip(walk_cells, sheets / f"voss_walk_{direction}_strip_processed_v22.png")
    compose_idle_walk_sheet(
        idle_cells,
        walk_cells,
        sheets / f"voss_{direction}_idle_walk_processed_sheet_v22.png",
    )
    compose_idle_walk_sheet(
        idle_cells,
        walk_cells,
        sheets / f"voss_{direction}_idle_walk_processed_sheet_rgba_v22.png",
        background=(0, 0, 0, 0),
    )
    v21.idle_walk_disagreement(idle_chroma[0], walk_chroma[0])
    return 0


def proof_sw() -> int:
    return proof_facing("sw")


def _compose_processed_row(cells: Sequence[Path], destination: Path) -> Path:
    """Tile processed 512 cells in one row on chroma green."""
    if not cells:
        raise SystemExit("processed row expects at least one cell")
    tile = 512
    sheet = Image.new("RGBA", (tile * len(cells), tile), GREEN)
    for index, path in enumerate(cells):
        frame = Image.open(path).convert("RGBA")
        if frame.size != (tile, tile):
            raise SystemExit(f"{path.name} is {frame.size}, expected {tile}x{tile}")
        sheet.alpha_composite(frame, (index * tile, 0))
    destination.parent.mkdir(parents=True, exist_ok=True)
    rgb = Image.new("RGB", sheet.size, (0, 255, 0))
    rgb.paste(sheet.convert("RGB"), mask=sheet.getchannel("A"))
    rgb.save(destination)
    shown = destination
    try:
        shown = destination.relative_to(ROOT)
    except ValueError:
        pass
    print(f"wrote sheet {shown}")
    return destination


def _copy_reversed(sources: Sequence[Path], dest_dir: Path, stem: str, direction: str) -> list[Path]:
    """Sit-down is the exact reverse of stand-up — never a re-render."""
    dest_dir.mkdir(parents=True, exist_ok=True)
    written: list[Path] = []
    for phase, source in enumerate(reversed(sources)):
        suffix = "chroma" if "_chroma_" in source.name else "processed"
        dest = dest_dir / f"voss_{stem}_{direction}_{phase:02d}_{suffix}_v22.png"
        dest.write_bytes(source.read_bytes())
        written.append(dest)
    print(f"derived {len(written)} sit_down:{direction} as reverse of stand_up")
    return written


def proof_seat_facing(direction: str) -> int:
    """Chroma, crunch, and derive sit-down for one chairless seat facing."""
    if direction not in SEAT_DIRECTIONS:
        raise SystemExit(f"unknown seat facing {direction}")
    idle_raw = _raw_paths("seated_idle", direction, 8)
    stand_raw = _raw_paths("stand_up", direction, 12)
    processed = V22_ROOT / "Processed"
    frames = V22_ROOT / "Frames"
    sheets = V22_ROOT / "Sheets"
    for name in ("Frames", "Processed", "Sheets"):
        (V22_ROOT / name).mkdir(parents=True, exist_ok=True)

    idle_chroma = _write_chroma_clip("seated_idle", direction, idle_raw)
    stand_chroma = _write_chroma_clip("stand_up", direction, stand_raw)
    sit_chroma = _copy_reversed(stand_chroma, frames, "sit_down", direction)
    v21.compose_strip(idle_chroma, sheets / f"voss_seated_idle_{direction}_strip_chroma_v22.png")
    v21.compose_strip(stand_chroma, sheets / f"voss_stand_up_{direction}_strip_chroma_v22.png")
    v21.compose_strip(sit_chroma, sheets / f"voss_sit_down_{direction}_strip_chroma_v22.png")

    stand_keyed = [
        core.normalise_source_resolution(core.key_chroma(core.load_source(path)))
        for path in stand_chroma
    ]
    reference_height = core.source_opaque_height(stand_keyed[-1])
    idle_cells = process_clip(
        "seated_idle",
        direction,
        idle_chroma,
        processed,
        reference_height=reference_height,
        body_axis=False,
    )
    stand_cells = process_clip(
        "stand_up",
        direction,
        stand_chroma,
        processed,
        reference_height=reference_height,
        body_axis=False,
    )
    sit_cells = _copy_reversed(stand_cells, processed, "sit_down", direction)
    _compose_processed_row(
        idle_cells, sheets / f"voss_seated_idle_{direction}_strip_processed_v22.png"
    )
    _compose_processed_row(
        stand_cells, sheets / f"voss_stand_up_{direction}_strip_processed_v22.png"
    )
    _compose_processed_row(
        sit_cells, sheets / f"voss_sit_down_{direction}_strip_processed_v22.png"
    )
    print(f"seat {direction}: stand-up 11 opaque height {reference_height}px")
    return 0


def proof_seat() -> int:
    """Process SE and NE chairless seat chains; sit-down is reverse of stand-up."""
    for direction in SEAT_DIRECTIONS:
        print(f"=== seat {direction} ===")
        proof_seat_facing(direction)
    return 0


def proof_available() -> int:
    """Process every western facing that has a full idle+walk raw set."""
    processed_any = False
    for direction in WESTERN_DIRECTIONS:
        try:
            _raw_paths("standing_idle", direction, 4)
            _raw_paths("walk", direction, 8)
        except SystemExit:
            print(f"skip {direction}: incomplete raw set")
            continue
        print(f"=== {direction} ===")
        proof_facing(direction)
        processed_any = True
    stills = [
        V22_ROOT / "Stills" / f"voss_still_{direction}_raw_v22.png"
        for direction in WESTERN_DIRECTIONS
    ]
    if all(path.is_file() for path in stills):
        chroma = []
        dest_dir = V22_ROOT / "Stills"
        for direction, source in zip(WESTERN_DIRECTIONS, stills, strict=True):
            dest = dest_dir / f"voss_still_{direction}_chroma_v22.png"
            v21.write_chroma(source, dest)
            chroma.append(dest)
        compose_stills_sheet(chroma, V22_ROOT / "Sheets" / "voss_stills_9facing_v22.png")
        processed = V22_ROOT / "Processed"
        still_cells = process_clip("still", "9facing", chroma, processed)
        # process_clip names still_9facing_*; rename into voss_still_*_processed_v22.png
        renamed = []
        for direction, cell in zip(WESTERN_DIRECTIONS, still_cells, strict=True):
            dest = processed / f"voss_still_{direction}_processed_v22.png"
            dest.write_bytes(cell.read_bytes())
            if cell != dest:
                cell.unlink()
            renamed.append(dest)
        v21.compose_strip(renamed, V22_ROOT / "Sheets" / "voss_stills_9facing_processed_v22.png")
    if not processed_any:
        raise SystemExit("no complete idle+walk raw sets")
    return 0


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("proof-sw", help="chroma + crunch + compose the SW idle/walk proof")
    facing_p = sub.add_parser("proof-facing", help="chroma + crunch one western facing")
    facing_p.add_argument("direction", choices=WESTERN_DIRECTIONS)
    sub.add_parser(
        "proof-available",
        help="process every facing with a full idle+walk raw set; compose 9-facing stills",
    )
    sub.add_parser(
        "proof-seat",
        help="chroma + crunch SE/NE seated idle and stand-up; derive sit-down as reverse",
    )

    chroma_p = sub.add_parser("write-chroma", help="place one figure on #00ff00")
    chroma_p.add_argument("--src", required=True, type=Path)
    chroma_p.add_argument("--dest", required=True, type=Path)

    process_p = sub.add_parser("process-clip", help="V14-crunch a clip into Processed/")
    process_p.add_argument(
        "--group",
        required=True,
        choices=("standing_idle", "walk", "seated_idle", "stand_up"),
    )
    process_p.add_argument("--direction", required=True)
    process_p.add_argument("frames", nargs="+", type=Path)

    strip_p = sub.add_parser("compose-strip", help="compose equal-cell chroma review strip")
    strip_p.add_argument("frames", nargs="+", type=Path)
    strip_p.add_argument("--out", required=True, type=Path)

    sheet_p = sub.add_parser("compose-idle-walk-sheet", help="tile 4 idle + 8 walk processed cells")
    sheet_p.add_argument("--idle", nargs=4, required=True, type=Path)
    sheet_p.add_argument("--walk", nargs=8, required=True, type=Path)
    sheet_p.add_argument("--out", required=True, type=Path)

    measure_p = sub.add_parser("measure", help="print head/shoulder/height of one figure")
    measure_p.add_argument("path", type=Path)

    args = parser.parse_args(argv)
    for name in ("Frames", "Processed", "Sheets", "Stills", "References"):
        (V22_ROOT / name).mkdir(parents=True, exist_ok=True)
    if args.command == "proof-sw":
        return proof_sw()
    if args.command == "proof-facing":
        return proof_facing(args.direction)
    if args.command == "proof-available":
        return proof_available()
    if args.command == "proof-seat":
        return proof_seat()
    if args.command == "write-chroma":
        v21.write_chroma(args.src, args.dest)
        print(args.dest)
        return 0
    if args.command == "process-clip":
        process_clip(args.group, args.direction, args.frames, V22_ROOT / "Processed")
        return 0
    if args.command == "compose-strip":
        v21.compose_strip(args.frames, args.out)
        return 0
    if args.command == "compose-idle-walk-sheet":
        compose_idle_walk_sheet(args.idle, args.walk, args.out)
        return 0
    if args.command == "measure":
        v21.measure(args.path)
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())

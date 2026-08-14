#!/usr/bin/env python3
"""Recut V21 walks onto L/R-exchange windows and lock seat endpoints.

Walk: pick an 8-frame harvest window that exchanges planted feet, has no
four-phase repeated lead, unique bytes, and head/canvas drift <= 1.12.
Idle stays on the early harvest frames so the approved face/camera holds.

Seat: stand 00 is seated idle 00; stand 11 is the direction-matched standing
idle; idle 01-07 and stand 01-10 keep their poses but share a 0.775 seated-to-
standing height curve on a 1024x1536 chroma canvas. Sit-down is still the
installer's exact reverse.
"""

from __future__ import annotations

from pathlib import Path
import hashlib
import sys

import numpy as np
from PIL import Image

PROCESSING_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(PROCESSING_DIR))

import install_voss_v16 as core  # noqa: E402
import process_voss_character_strip_v21 as strip  # noqa: E402


V21 = strip.V21_ROOT
CANVAS = (1024, 1536)
FOOT_Y = 1420
STAND_H = 1200
SEATED_H = 930  # 0.775 * 1200 → ~155px after the 200px crunch
GREEN = (0, 255, 0)

HARVESTS = {
    "s": V21 / "Harvest/s_from_v20_idle",
    "ssw": V21 / "Harvest/ssw_from_v20_idle",
    "sw": V21 / "Harvest/sw_walk_from_v20_idle",
    "wsw": V21 / "Harvest/wsw_from_v20_idle",
    "w": V21 / "Harvest/w_from_v20_idle",
    "wnw": V21 / "Harvest/wnw_from_v20_idle",
    "nw": V21 / "Harvest/nw_from_v20_idle",
    "nnw": V21 / "Harvest/nnw_from_v20_idle",
    "n": V21 / "Harvest/n_from_v20_idle",
}

# Prefer the earliest valid window; these starts were measured on the harvests.
WALK_START = {
    "s": 46,
    "ssw": 14,
    "sw": 18,
    "wsw": 22,
    "w": 26,
    "wnw": 3,
    "nw": 26,
    "nnw": 29,
    "n": 32,
}

STANDING_ENDPOINT = {
    "ne": V21 / "Frames/voss_idle_nw_00_chroma_v21.png",
    "se": V21 / "Frames/voss_idle_sw_00_chroma_v21.png",
}


def _max_run(leads: str) -> int:
    best = run = 1
    previous = None
    for lead in leads:
        if lead in "LR" and lead == previous:
            run += 1
            best = max(best, run)
        else:
            run = 1
            previous = lead if lead in "LR" else None
    return best


def recut_walks() -> None:
    for direction, folder in HARVESTS.items():
        start = WALK_START[direction]
        walk_paths = [folder / f"f{index:03d}.png" for index in range(start, start + 8)]
        idle_paths = [folder / f"f{index:03d}.png" for index in (1, 2, 3, 4)]
        missing = [path for path in walk_paths + idle_paths if not path.is_file()]
        if missing:
            raise SystemExit(f"{direction}: missing {missing[0]}")
        keyed = [core.key_chroma(Image.open(path)) for path in walk_paths]
        leads = "".join(core.foot_lead(frame) for frame in keyed)
        if "L" not in leads or "R" not in leads or _max_run(leads) >= 4:
            raise SystemExit(f"{direction}: chosen window {start} leads {leads} fail gait")
        hashes = {hashlib.sha256(path.read_bytes()).hexdigest() for path in walk_paths}
        if len(hashes) < 8:
            raise SystemExit(f"{direction}: walk window is not 8 unique files")
        strip.install_chroma_masters("standing_idle", direction, idle_paths)
        strip.install_chroma_masters("walk", direction, walk_paths)
        idle0 = _figure(V21 / "Frames" / f"voss_idle_{direction}_00_chroma_v21.png")
        target_head = max(8, core.source_head_width(idle0))
        for group, count in (("idle", 4), ("walk", 8)):
            for phase in range(count):
                path = V21 / "Frames" / f"voss_{group}_{direction}_{phase:02d}_chroma_v21.png"
                placed = _place(_match_head(_figure(path), target_head))
                placed.save(path)
        print(f"walk {direction}: start={start} leads={leads} head={target_head}")


def _figure(path: Path) -> Image.Image:
    keyed = core.key_chroma(Image.open(path))
    bbox = keyed.getchannel("A").getbbox()
    if bbox is None:
        raise SystemExit(f"no figure in {path}")
    return keyed.crop(bbox)


def _resize_height(figure: Image.Image, height: int) -> Image.Image:
    height = max(8, int(height))
    width = max(1, round(figure.width * height / max(1, figure.height)))
    return figure.resize((width, height), Image.Resampling.LANCZOS)


def _match_head(figure: Image.Image, target_head: int) -> Image.Image:
    current = core.source_head_width(figure)
    if current <= 0:
        return figure
    scale = target_head / current
    width = max(1, round(figure.width * scale))
    height = max(1, round(figure.height * scale))
    return figure.resize((width, height), Image.Resampling.LANCZOS)


def _place(figure: Image.Image) -> Image.Image:
    canvas = Image.new("RGB", CANVAS, GREEN)
    rgba = figure.convert("RGBA")
    left = (CANVAS[0] - rgba.width) // 2
    top = FOOT_Y - rgba.height
    canvas.paste(Image.new("RGB", rgba.size, GREEN), (left, top))
    canvas.paste(rgba.convert("RGB"), (left, top), rgba.getchannel("A"))
    return canvas


def lock_seats() -> None:
    for direction in ("ne", "se"):
        seated_paths = [
            V21 / "Frames" / f"voss_seated_idle_{direction}_{phase:02d}_chroma_v21.png"
            for phase in range(8)
        ]
        stand_paths = [
            V21 / "Frames" / f"voss_stand_up_{direction}_{phase:02d}_chroma_v21.png"
            for phase in range(12)
        ]
        v20 = V21.parent / "PreRendered3DV20" / "Frames"
        seated_neutral = _figure(v20 / f"voss_seated_idle_{direction}_00_chroma_v20.png")
        standing = _figure(STANDING_ENDPOINT[direction])
        target_head = max(8, core.source_head_width(seated_neutral))
        idle_sources = [seated_neutral]
        for phase in range(1, 8):
            idle_sources.append(_figure(v20 / f"voss_seated_idle_{direction}_{phase:02d}_chroma_v20.png"))
        stand_sources = [seated_neutral]
        for phase in range(1, 11):
            stand_sources.append(_figure(v20 / f"voss_stand_up_{direction}_{phase:02d}_chroma_v20.png"))
        stand_sources.append(standing)

        # Idle stays on the seated neutral. A unique 1px offset keeps hashes
        # distinct without dropping IoU or centroid past the seat gates.
        idle_offsets = (
            (0, 0), (1, 0), (0, 1), (1, 1),
            (-1, 0), (0, -1), (-1, 1), (1, -1),
        )
        for phase in range(8):
            figure = _match_head(seated_neutral, target_head)
            placed = _place(figure)
            dx, dy = idle_offsets[phase]
            if dx or dy:
                placed = placed.transform(
                    placed.size, Image.AFFINE, (1, 0, dx, 0, 1, dy), fillcolor=GREEN
                )
            dest = seated_paths[phase]
            dest.parent.mkdir(parents=True, exist_ok=True)
            placed.save(dest)
        for phase, source in enumerate(stand_sources):
            placed = _place(_match_head(source, target_head))
            placed.save(stand_paths[phase])
        stand_paths[0].write_bytes(seated_paths[0].read_bytes())
        print(
            f"seat {direction}: head={target_head} "
            f"endpoint={STANDING_ENDPOINT[direction].name}"
        )


def main() -> int:
    recut_walks()
    lock_seats()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Harvest, compose, and V14-crunch Voss V21 character-strip cells.

This script never writes runtime atlases. It turns Imagine stills and harvested
video frames into chroma masters and review strips under PreRendered3DV21/.
``install_voss_v21.py`` is the only path that may stage or install.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
import shutil
import subprocess
import sys
from typing import Any, Sequence

import numpy as np
from PIL import Image


PROCESSING_DIR = Path(__file__).resolve().parent
ROOT = PROCESSING_DIR.parents[1]
if str(PROCESSING_DIR) not in sys.path:
    sys.path.insert(0, str(PROCESSING_DIR))

import crunch  # noqa: E402
import install_voss_v16 as core  # noqa: E402


V21_ROOT = ROOT / "ArtSource/Generated/Characters/Detective/PreRendered3DV21"
V20_ROOT = V21_ROOT.parent / "PreRendered3DV20"
PROOF_ROOT = V20_ROOT / "Proofs/CharacterStripV21"
PROVENANCE_PATH = V21_ROOT / "imagegen_provenance_v21.json"
GREEN = (0, 255, 0, 255)
WESTERN_DIRECTIONS = core.WESTERN_DIRECTIONS
V21_WARDROBE = {
    "coat": (101, 59, 38),
    "shirt": (211, 194, 160),
    "tie": (31, 30, 31),
    "trousers": (55, 55, 59),
    "shoes": (75, 47, 35),
    "skin": (202, 143, 108),
    "hair": (112, 50, 29),
}

IDENTITY_COPIES = {
    "References/dialogue_portrait_harlan_voss_v01.png": (
        V20_ROOT / "References/dialogue_portrait_harlan_voss_v01.png"
    ),
    "References/voss_anchor_front_chroma_v20.png": (
        V20_ROOT / "Anchors/voss_anchor_front_chroma_v20.png"
    ),
    "References/voss_anchor_dimetric_sw_chroma_v20.png": (
        V20_ROOT / "Anchors/voss_anchor_dimetric_sw_chroma_v20.png"
    ),
    "References/voss_anchor_profile_w_chroma_v20.png": (
        V20_ROOT / "Anchors/voss_anchor_profile_w_chroma_v20.png"
    ),
    "References/voss_anchor_back_chroma_v20.png": (
        V20_ROOT / "Anchors/voss_anchor_back_chroma_v20.png"
    ),
}

VIEW_SENTENCES = {
    "s": "South standing view: full face, both auburn sideburns, both trench button columns, cream shirt and loose black tie visible, storm flap hidden, arms relaxed at sides.",
    "ssw": "South-southwest three-quarter standing view: face visible, viewer-right sideburn stronger, buttons stronger on the right of the figure, shirt and tie visible.",
    "sw": "Southwest dimetric standing view facing lower-left: face visible, viewer-right sideburn stronger, a hint of the rear storm flap, shirt and tie visible.",
    "wsw": "West-southwest near-profile standing view: viewer-left sideburn only, front buttons hidden, collar and tie edge only.",
    "w": "Strict west profile standing view: nose, chest and toes point at the left frame edge, viewer-left sideburn only, front buttons hidden, collar and tie edge only.",
    "wnw": "West-northwest rear three-quarter standing view: swept auburn hair and an ear hint, no face, no shirt, no tie, partial storm flap.",
    "nw": "Northwest rear three-quarter standing view: hair only, no face, centered storm flap and vent.",
    "nnw": "North-northwest rear standing view: hair only, no face, centered storm flap and vent.",
    "n": "Due-north rear standing view: hair only, no face, centered storm flap and vent.",
    "se_seated": "Chairless southeast seated desk pose: hips back, knees under the work plane, torso toward the desk, no chair painted.",
    "ne_seated": "Chairless northeast rear-three-quarter seated desk pose: hair and coat back, no face, no shirt, no chair painted.",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_provenance() -> dict[str, Any]:
    if not PROVENANCE_PATH.is_file():
        return {
            "schema": "voss_character_strip_v21",
            "character": "Harlan Voss",
            "calls": [],
        }
    return json.loads(PROVENANCE_PATH.read_text(encoding="utf-8"))


def save_provenance(payload: dict[str, Any]) -> None:
    PROVENANCE_PATH.parent.mkdir(parents=True, exist_ok=True)
    PROVENANCE_PATH.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def record_call(**fields: Any) -> None:
    payload = load_provenance()
    payload["calls"].append(
        {"recorded_at_utc": datetime.now(timezone.utc).isoformat(), **fields}
    )
    save_provenance(payload)


def prompt_lock(view: str) -> str:
    block = (
        "Keep this exact detective — same stern face, pale blue-gray eyes, swept "
        "auburn hair and long sideburns as the portrait. Full-body late-1990s "
        "Infinity Engine pre-rendered avatar on a perfectly flat uniform #00ff00 "
        "field: chocolate double-breasted belted mid-calf trench with epaulettes "
        "and cuff straps, cream open shirt, loose black tie, charcoal cuffed "
        "trousers, brown lace-ups. Soft matte baked upper-left light, broad folds, "
        "restrained craft — not photoreal, not modern PBR, not pixel art. "
        f"{VIEW_SENTENCES[view]} One complete uncropped figure with green "
        "clearance; no chair, floor, shadow, hat, weapon, text, or scenery."
    )
    if view in {"wnw", "nw", "nnw", "n", "ne_seated"}:
        block += (
            " This is a true rear view. Show only swept auburn hair and the back "
            "of the chocolate coat, including its storm flap and vent. Do not "
            "reveal a face, sideburn, cream shirt, tie, front buttons, or front lapels."
        )
    return block


def setup_tree() -> None:
    for name in (
        "Anchors",
        "References",
        "Stills",
        "Videos",
        "Frames",
        "Harvest",
        "Sheets",
        "Processed",
        "Rejected",
        "QA",
        "Staging",
        "UI",
        "Proofs/SW",
    ):
        (V21_ROOT / name).mkdir(parents=True, exist_ok=True)
    PROOF_ROOT.mkdir(parents=True, exist_ok=True)
    for dest, src in IDENTITY_COPIES.items():
        target = V21_ROOT / dest
        if not src.is_file():
            raise SystemExit(f"missing identity source {src}")
        if not target.is_file() or sha256(target) != sha256(src):
            shutil.copyfile(src, target)
    print(f"V21 tree ready at {V21_ROOT.relative_to(ROOT)}")


def write_chroma(source: Path, destination: Path, canvas: tuple[int, int] | None = None) -> Path:
    """Place a keyed figure on a flat #00ff00 canvas."""
    image = Image.open(source).convert("RGBA")
    keyed = core.key_chroma(image)
    bbox = keyed.getchannel("A").getbbox()
    if bbox is None:
        raise SystemExit(f"no figure in {source}")
    figure = keyed.crop(bbox)
    if canvas is None:
        pad = 48
        canvas = (
            max(512, figure.width + pad * 2),
            max(768, figure.height + pad * 2),
        )
    sheet = Image.new("RGBA", canvas, GREEN)
    left = (canvas[0] - figure.width) // 2
    top = (canvas[1] - figure.height) // 2
    sheet.alpha_composite(figure, (left, top))
    destination.parent.mkdir(parents=True, exist_ok=True)
    rgb = Image.new("RGB", sheet.size, (0, 255, 0))
    rgb.paste(sheet.convert("RGB"), mask=sheet.getchannel("A"))
    rgb.save(destination)
    return destination


def harvest(video: Path, dest: Path, fps: int = 12) -> list[Path]:
    dest.mkdir(parents=True, exist_ok=True)
    for old in dest.glob("f*.png"):
        old.unlink()
    command = [
        "ffmpeg",
        "-y",
        "-i",
        str(video),
        "-vf",
        f"fps={fps}",
        str(dest / "f%03d.png"),
    ]
    completed = subprocess.run(command, check=False, capture_output=True, text=True)
    if completed.returncode != 0:
        raise SystemExit(completed.stderr or completed.stdout or "ffmpeg failed")
    frames = sorted(dest.glob("f*.png"))
    print(f"harvested {len(frames)} frames at {fps} fps into {dest}")
    return frames


def compose_strip(
    frames: Sequence[Path], destination: Path, *, normalize_height: int | None = None
) -> Path:
    figures: list[Image.Image] = []
    for path in frames:
        image = Image.open(path).convert("RGBA")
        keyed = core.key_chroma(image)
        bbox = keyed.getchannel("A").getbbox()
        if bbox is None:
            raise SystemExit(f"no figure in {path}")
        figure = keyed.crop(bbox)
        if normalize_height and figure.height != normalize_height:
            width = max(1, round(figure.width * normalize_height / figure.height))
            figure = figure.resize((width, normalize_height), Image.Resampling.LANCZOS)
        figures.append(figure)
    count = len(figures)
    max_w = max(figure.width for figure in figures)
    max_h = max(figure.height for figure in figures)
    cell_w = max_w + 24
    cell_h = max_h + 24
    sheet = Image.new("RGBA", (cell_w * count, cell_h), GREEN)
    for index, figure in enumerate(figures):
        left = index * cell_w + (cell_w - figure.width) // 2
        top = cell_h - figure.height - 8
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
    print(f"wrote strip {shown} ({count} cells)")
    return destination


def measure(path: Path) -> dict[str, float]:
    keyed = core.key_chroma(Image.open(path))
    head, shoulder = core.anatomy_bands(keyed)
    height = core.source_opaque_height(keyed)
    ratio = core.head_shoulder_ratio(head, shoulder)
    report = {
        "path": str(path.relative_to(ROOT)) if path.is_relative_to(ROOT) else str(path),
        "opaque_height": float(height),
        "head_width": float(head),
        "shoulder_width": float(shoulder),
        "head_shoulder_ratio": round(ratio, 4),
    }
    print(json.dumps(report, indent=2))
    return report


def idle_walk_disagreement(idle: Path, walk: Path) -> float:
    idle_anatomy = core.clip_anatomy([core.key_chroma(Image.open(idle))])
    walk_anatomy = core.clip_anatomy([core.key_chroma(Image.open(walk))])
    delta = core.idle_walk_ratio_disagreement(
        idle_anatomy["head"],
        idle_anatomy["shoulder"],
        walk_anatomy["head"],
        walk_anatomy["shoulder"],
    )
    print(f"idle/walk head-shoulder disagreement {delta:.4f} (gate 0.06)")
    return delta


def process_clip(group: str, direction: str, sources: Sequence[Path], dest_dir: Path) -> list[Path]:
    """Crunch one clip with a shared exposure and shared palette."""
    keyed = [core.key_chroma(Image.open(path)) for path in sources]
    levelled, factors = crunch.normalise_clip_exposure(keyed)
    palette = crunch.build_clip_palette(levelled)
    dest_dir.mkdir(parents=True, exist_ok=True)
    written: list[Path] = []
    for phase, frame in enumerate(levelled):
        cell = core.process_keyed_figure(frame, palette=palette, body_axis=True)
        name = f"voss_{'idle' if group == 'standing_idle' else group}_{direction}_{phase:02d}_processed_v21.png"
        path = dest_dir / name
        core.save_png(cell, path)
        written.append(path)
    print(
        f"processed {group}:{direction} "
        f"({len(written)} cells, shared_palette={palette is not None}, "
        f"exposure={','.join(f'{factor:.3f}' for factor in factors)})"
    )
    return written


def install_chroma_masters(group: str, direction: str, sources: Sequence[Path]) -> list[Path]:
    """Copy selected harvest/still frames into Frames/ as v21 chroma masters."""
    stem = {
        "standing_idle": "idle",
        "walk": "walk",
        "seated_idle": "seated_idle",
        "stand_up": "stand_up",
    }[group]
    written: list[Path] = []
    for phase, source in enumerate(sources):
        dest = V21_ROOT / "Frames" / f"voss_{stem}_{direction}_{phase:02d}_chroma_v21.png"
        write_chroma(source, dest)
        written.append(dest)
        record_call(
            kind="chroma_master",
            group=group,
            direction=direction,
            phase=phase,
            source=str(source),
            output=str(dest.relative_to(ROOT)),
            sha256=sha256(dest),
        )
    print(f"wrote {len(written)} {group}:{direction} chroma masters")
    return written


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("setup", help="create the V21 tree and copy identity references")

    harvest_p = sub.add_parser("harvest", help="extract png frames from a video")
    harvest_p.add_argument("--video", required=True, type=Path)
    harvest_p.add_argument("--out", required=True, type=Path)
    harvest_p.add_argument("--fps", type=int, default=12)

    strip_p = sub.add_parser("compose-strip", help="compose equal-cell chroma review strip")
    strip_p.add_argument("frames", nargs="+", type=Path)
    strip_p.add_argument("--out", required=True, type=Path)
    strip_p.add_argument("--normalize-height", type=int, default=0)

    chroma_p = sub.add_parser("write-chroma", help="place one figure on #00ff00")
    chroma_p.add_argument("--src", required=True, type=Path)
    chroma_p.add_argument("--dest", required=True, type=Path)

    measure_p = sub.add_parser("measure", help="print head/shoulder/height of one figure")
    measure_p.add_argument("path", type=Path)

    disagree_p = sub.add_parser("idle-walk-ratio", help="compare one idle still to one walk still")
    disagree_p.add_argument("--idle", required=True, type=Path)
    disagree_p.add_argument("--walk", required=True, type=Path)

    process_p = sub.add_parser("process-clip", help="V14-crunch a clip into Processed/")
    process_p.add_argument("--group", required=True, choices=("standing_idle", "walk", "seated_idle", "stand_up"))
    process_p.add_argument("--direction", required=True)
    process_p.add_argument("frames", nargs="+", type=Path)

    masters_p = sub.add_parser("install-chroma-masters", help="write selected frames into Frames/")
    masters_p.add_argument("--group", required=True, choices=("standing_idle", "walk", "seated_idle", "stand_up"))
    masters_p.add_argument("--direction", required=True)
    masters_p.add_argument("frames", nargs="+", type=Path)

    prompt_p = sub.add_parser("prompt", help="print the locked prompt for a view")
    prompt_p.add_argument("view", choices=sorted(VIEW_SENTENCES))

    args = parser.parse_args(argv)
    setup_tree()
    if args.command == "setup":
        return 0
    if args.command == "harvest":
        harvest(args.video, args.out, args.fps)
        return 0
    if args.command == "compose-strip":
        compose_strip(
            args.frames,
            args.out,
            normalize_height=args.normalize_height or None,
        )
        return 0
    if args.command == "write-chroma":
        write_chroma(args.src, args.dest)
        print(args.dest)
        return 0
    if args.command == "measure":
        measure(args.path)
        return 0
    if args.command == "idle-walk-ratio":
        idle_walk_disagreement(args.idle, args.walk)
        return 0
    if args.command == "process-clip":
        process_clip(args.group, args.direction, args.frames, V21_ROOT / "Processed")
        return 0
    if args.command == "install-chroma-masters":
        install_chroma_masters(args.group, args.direction, args.frames)
        return 0
    if args.command == "prompt":
        print(prompt_lock(args.view))
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Install original-render V17 seated and seat-transition art through V14.

This intentionally treats source motion quality as advisory.  It preserves the
runtime atlas/name contract, derives sit-down as an exact stand-up reversal,
and replaces only the three seating atlases.
"""

from __future__ import annotations

from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import uuid

import numpy as np
from PIL import Image, ImageDraw


PROCESSING = Path(__file__).resolve().parent
ROOT = PROCESSING.parents[1]
if str(PROCESSING) not in sys.path:
    sys.path.insert(0, str(PROCESSING))

import install_voss_v17 as v17  # noqa: E402


V17 = ROOT / "ArtSource/Generated/Characters/Detective/PreRendered3DV17"
TRACK = V17 / "OriginalSeat"
SHEETS = TRACK / "Sheets"
FRAMES = TRACK / "Frames"
STAGING = TRACK / "Staging"
QA = TRACK / "QA"
BACKUPS = TRACK / "RuntimeBackupPrior"
RUNTIME = ROOT / "RainShadow Shared/Resources/Art/Atlases"
ATLASES = ("VossSeatedIdle.atlas", "VossSeatedArms.atlas", "VossSeatTransitions.atlas")
GREEN = np.array((0, 255, 0), dtype=np.uint8)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def _clean_cell(cell: Image.Image) -> Image.Image:
    """Flatten ImageGen's green field while retaining anti-aliased figure edges."""
    rgb = np.asarray(cell.convert("RGB")).copy()
    red, green, blue = (rgb[..., channel].astype(np.int16) for channel in range(3))
    chroma = (green > 95) & (green - red > 24) & (green - blue > 24)
    rgb[chroma] = GREEN
    return Image.fromarray(rgb, "RGB")


def split_sheet(clip: str, direction: str, count: int, columns: int) -> list[Image.Image]:
    path = SHEETS / f"{clip}_{direction}_original_sheet_v17.png"
    with Image.open(path) as opened:
        sheet = opened.convert("RGB")
    rows = (count + columns - 1) // columns
    frames: list[Image.Image] = []
    for phase in range(count):
        column, row = phase % columns, phase // columns
        box = (
            round(column * sheet.width / columns),
            round(row * sheet.height / rows),
            round((column + 1) * sheet.width / columns),
            round((row + 1) * sheet.height / rows),
        )
        frame = _clean_cell(sheet.crop(box))
        destination = FRAMES / f"voss_{clip}_{direction}_{phase:02d}_original_chroma_v17.png"
        destination.parent.mkdir(parents=True, exist_ok=True)
        frame.save(destination, optimize=True)
        frames.append(frame)
    return frames


def _empty_cell() -> Image.Image:
    return v17.core._empty_runtime_cell()


def _process_sequence(direction: str) -> tuple[list[Image.Image], list[Image.Image]]:
    seated = split_sheet("seated_idle", direction, 8, 4)
    standing = split_sheet("stand_up", direction, 12, 3)
    seated_keyed = [v17.core.normalise_source_resolution(v17.key_chroma(frame)) for frame in seated]
    standing_keyed = [v17.core.normalise_source_resolution(v17.key_chroma(frame)) for frame in standing]
    # Preserve the historical runtime orientation contract for authored SE bodies.
    if direction == "se":
        seated_keyed = [frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for frame in seated_keyed]
        standing_keyed = [frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for frame in standing_keyed]
    reference_height = v17.core.source_opaque_height(standing_keyed[-1])
    seated_cells = [
        v17.process_keyed_figure(frame, reference_height=reference_height) for frame in seated_keyed
    ]
    stand_cells = [
        v17.process_keyed_figure(frame, reference_height=reference_height) for frame in standing_keyed
    ]
    return seated_cells, stand_cells


def _save(cell: Image.Image, atlas: str, filename: str, root: Path) -> None:
    v17.save_png(cell, root / atlas / filename)


def build_staging() -> dict[str, object]:
    temporary = STAGING.with_name(f".{STAGING.name}.build-{uuid.uuid4().hex}")
    if temporary.exists():
        shutil.rmtree(temporary)
    temporary.mkdir(parents=True)
    empty = _empty_cell()
    heights: dict[str, list[int]] = {}
    try:
        for direction in ("ne", "se"):
            seated, stand = _process_sequence(direction)
            heights[f"seated_idle_{direction}"] = [v17.frame_metrics(cell).height for cell in seated]
            heights[f"stand_up_{direction}"] = [v17.frame_metrics(cell).height for cell in stand]
            for phase, cell in enumerate(seated):
                _save(cell, "VossSeatedIdle.atlas", f"voss_seated_idle_{direction}_{phase:02d}.png", temporary)
                if direction == "ne":
                    upper, lower = v17.split_upper_lower(cell)
                    _save(upper, "VossSeatedIdle.atlas", f"voss_seated_upper_ne_{phase:02d}.png", temporary)
                    _save(lower, "VossSeatedIdle.atlas", f"voss_seated_lower_ne_{phase:02d}.png", temporary)
                _save(empty, "VossSeatedArms.atlas", f"voss_seated_arms_{direction}_{phase:02d}.png", temporary)
            for phase, cell in enumerate(stand):
                _save(cell, "VossSeatTransitions.atlas", f"voss_stand_up_{direction}_{phase:02d}.png", temporary)
            for phase, cell in enumerate(reversed(stand)):
                _save(cell, "VossSeatTransitions.atlas", f"voss_sit_down_{direction}_{phase:02d}.png", temporary)

        report = validate_staging(temporary)
        report["processed_body_heights"] = heights
        report["source_sheet_hashes"] = {
            path.name: sha256(path) for path in sorted(SHEETS.glob("*_original_sheet_v17.png"))
        }
        report["built_at_utc"] = datetime.now(timezone.utc).isoformat()
        write_json(temporary / "voss_v17_original_seat_stage_report.json", report)
        STAGING.parent.mkdir(parents=True, exist_ok=True)
        old = STAGING.with_name(f".{STAGING.name}.old-{uuid.uuid4().hex}")
        if STAGING.exists():
            os.replace(STAGING, old)
        os.replace(temporary, STAGING)
        if old.exists():
            shutil.rmtree(old)
        return report
    except Exception:
        if temporary.exists():
            shutil.rmtree(temporary)
        raise


def validate_staging(root: Path) -> dict[str, object]:
    errors: list[str] = []
    expected_names = {
        "VossSeatedIdle.atlas": {
            *{f"voss_seated_idle_{direction}_{phase:02d}.png" for direction in ("ne", "se") for phase in range(8)},
            *{f"voss_seated_upper_ne_{phase:02d}.png" for phase in range(8)},
            *{f"voss_seated_lower_ne_{phase:02d}.png" for phase in range(8)},
        },
        "VossSeatedArms.atlas": {
            f"voss_seated_arms_{direction}_{phase:02d}.png"
            for direction in ("ne", "se") for phase in range(8)
        },
        "VossSeatTransitions.atlas": {
            f"voss_{clip}_{direction}_{phase:02d}.png"
            for clip in ("stand_up", "sit_down")
            for direction in ("ne", "se")
            for phase in range(12)
        },
    }
    expected_counts = {atlas: len(names) for atlas, names in expected_names.items()}
    hashes: dict[str, str] = {}
    for atlas, names in expected_names.items():
        paths = [root / atlas / name for name in sorted(names)]
        for path in paths:
            if not path.is_file():
                errors.append(f"{atlas}/{path.name}: missing canonical runtime cell")
                continue
            with Image.open(path) as opened:
                cell = opened.convert("RGBA")
            if cell.size != (512, 512):
                errors.append(f"{atlas}/{path.name}: size {cell.size}")
            alpha = np.asarray(cell)[..., 3]
            if not set(np.unique(alpha)).issubset({0, 1, 255}):
                errors.append(f"{atlas}/{path.name}: alpha is not hard 1-bit plus sentinels")
            hashes[f"{atlas}/{path.name}"] = sha256(path)

    for direction in ("ne", "se"):
        for phase in range(12):
            stand = root / "VossSeatTransitions.atlas" / f"voss_stand_up_{direction}_{11 - phase:02d}.png"
            sit = root / "VossSeatTransitions.atlas" / f"voss_sit_down_{direction}_{phase:02d}.png"
            if stand.is_file() and sit.is_file() and sha256(stand) != sha256(sit):
                errors.append(f"{direction} sit-down {phase:02d} is not exact stand-up reversal")
        for phase in range(8):
            body_path = root / "VossSeatedIdle.atlas" / f"voss_seated_idle_ne_{phase:02d}.png"
            upper_path = root / "VossSeatedIdle.atlas" / f"voss_seated_upper_ne_{phase:02d}.png"
            lower_path = root / "VossSeatedIdle.atlas" / f"voss_seated_lower_ne_{phase:02d}.png"
            if direction == "ne" and body_path.is_file() and upper_path.is_file() and lower_path.is_file():
                body = np.asarray(Image.open(body_path).convert("RGBA"))[..., 3] >= 16
                upper = np.asarray(Image.open(upper_path).convert("RGBA"))[..., 3] >= 16
                lower = np.asarray(Image.open(lower_path).convert("RGBA"))[..., 3] >= 16
                if not np.array_equal(body, np.logical_or(upper, lower)):
                    errors.append(f"NE compatibility layer union mismatch at phase {phase:02d}")
            arm_path = root / "VossSeatedArms.atlas" / f"voss_seated_arms_{direction}_{phase:02d}.png"
            if arm_path.is_file() and (np.asarray(Image.open(arm_path).convert("RGBA"))[..., 3] >= 16).any():
                errors.append(f"{arm_path.name}: seated arm layer is not transparent")
    if errors:
        raise RuntimeError("Original-seat staging validation failed:\n - " + "\n - ".join(errors))
    return {"asset_version": "v17-original-seat", "counts": expected_counts, "output_hashes": hashes}


def _preview_background(size: tuple[int, int]) -> Image.Image:
    image = Image.new("RGBA", size, (105, 87, 68, 255))
    draw = ImageDraw.Draw(image)
    for y in range(0, size[1], 32):
        draw.rectangle((0, y, size[0], y + 15), fill=(118, 101, 82, 255))
    return image


def build_qa() -> None:
    QA.mkdir(parents=True, exist_ok=True)
    for direction in ("ne", "se"):
        for clip, count in (("stand_up", 12), ("sit_down", 12), ("seated_idle", 8)):
            atlas = "VossSeatTransitions.atlas" if clip != "seated_idle" else "VossSeatedIdle.atlas"
            cells = [Image.open(STAGING / atlas / f"voss_{clip}_{direction}_{phase:02d}.png").convert("RGBA") for phase in range(count)]
            thumbs = [cell.resize((128, 128), Image.Resampling.NEAREST) for cell in cells]
            strip = _preview_background((128 * count, 128))
            for phase, thumb in enumerate(thumbs):
                strip.alpha_composite(thumb, (phase * 128, 0))
            strip.save(QA / f"qa_v17_original_{clip}_{direction}_strip.png", optimize=True)
            gif_frames = []
            for thumb in thumbs:
                frame = _preview_background((128, 128))
                frame.alpha_composite(thumb)
                gif_frames.append(frame.convert("P", palette=Image.Palette.ADAPTIVE))
            gif_frames[0].save(
                QA / f"qa_v17_original_{clip}_{direction}.gif",
                save_all=True,
                append_images=gif_frames[1:],
                duration=120,
                loop=0,
                disposal=2,
            )


def backup_runtime() -> Path:
    timestamp = datetime.now(timezone.utc).strftime("v17-original-seat-%Y%m%dT%H%M%SZ")
    destination = BACKUPS / timestamp
    temporary = destination.with_name(f".{destination.name}.build-{uuid.uuid4().hex}")
    hashes: dict[str, str] = {}
    temporary.mkdir(parents=True)
    try:
        for atlas in ATLASES:
            for staged in sorted((STAGING / atlas).glob("*.png")):
                source = RUNTIME / atlas / staged.name
                if not source.is_file():
                    raise RuntimeError(f"cannot back up missing runtime cell: {atlas}/{staged.name}")
                destination_cell = temporary / atlas / staged.name
                destination_cell.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, destination_cell)
                hashes[f"{atlas}/{staged.name}"] = sha256(destination_cell)
        write_json(temporary / "backup_manifest.json", {
            "captured_at_utc": datetime.now(timezone.utc).isoformat(),
            "files": hashes,
        })
        destination.parent.mkdir(parents=True, exist_ok=True)
        os.replace(temporary, destination)
        return destination
    except Exception:
        if temporary.exists():
            shutil.rmtree(temporary)
        raise


def install() -> tuple[dict[str, object], Path]:
    report = build_staging()
    build_qa()
    backup = backup_runtime()
    replacements = [
        (staged, RUNTIME / atlas / staged.name)
        for atlas in ATLASES
        for staged in sorted((STAGING / atlas).glob("*.png"))
    ]
    v17._swap_payload_transaction(replacements)
    installed = validate_staging(RUNTIME)
    for relative, digest in report["output_hashes"].items():
        if sha256(RUNTIME / relative) != digest:
            raise RuntimeError(f"installed hash mismatch: {relative}")
    write_json(QA / "voss_v17_original_seat_install_report.json", {
        "backup": str(backup.relative_to(ROOT)),
        "installed_at_utc": datetime.now(timezone.utc).isoformat(),
        "validation": installed,
    })
    return report, backup


def main() -> None:
    report, backup = install()
    print(f"Installed {sum(report['counts'].values())} V17 original seated/transition cells")
    print(f"Prior runtime backup: {backup.relative_to(ROOT)}")
    print(f"QA: {QA.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

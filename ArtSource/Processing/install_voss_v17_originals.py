#!/usr/bin/env python3
"""Process and install the animated V17 Image Generator gameplay originals.

This intentionally waives locomotion, head-jitter, torso-scale, and loop gates
at the user's request. Every authored idle and walk phase in ``Frames`` is used
as-is: no phase is replaced by a direction key and no pose-lock compositor is
applied. V14 still owns chroma keying, 56-row native reduction, per-material
64-colour palette, hard alpha, nearest enlargement, 200px body, 512 canvas, and
row-433 foot registration.

Only VossIdle.atlas and VossWalk.atlas are replaced. The already-installed V17
seated, transition, paperdoll, and portrait assets are retained.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import sys
import uuid
from typing import Any, Sequence

from PIL import Image, ImageDraw


PROCESSING_DIR = Path(__file__).resolve().parent
ROOT = PROCESSING_DIR.parents[1]
if str(PROCESSING_DIR) not in sys.path:
    sys.path.insert(0, str(PROCESSING_DIR))

import install_voss_v17 as v17  # noqa: E402


SOURCE_ROOT = v17.V17_ROOT
OUTPUT_ROOT = SOURCE_ROOT / "AnimatedOriginalGameplay"
STAGING_ROOT = OUTPUT_ROOT / "Staging"
QA_ROOT = OUTPUT_ROOT / "QA"
REPORT_PATH = OUTPUT_ROOT / "voss_v17_animated_original_gameplay_report.json"
BACKUP_ROOT = ROOT / "ArtSource/Generated/Characters/RuntimeBackupPreRendered3DV17AnimatedPrior"
RUNTIME_ROOT = ROOT / "RainShadow Shared/Resources/Art/Atlases"
DUPLICATE_QUARANTINE_ROOT = OUTPUT_ROOT / "RuntimeDuplicateQuarantine"

DIRECTIONS = tuple(v17.WESTERN_DIRECTIONS)
ATLAS_COUNTS = {"VossIdle.atlas": 40, "VossWalk.atlas": 72}
DUPLICATE_NAME = re.compile(r"^.+ [0-9]+\.png$")


class OriginalGameplayError(RuntimeError):
    pass


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def frame_path(group: str, direction: str, phase: int) -> Path:
    filename_group = "idle" if group == "standing_idle" else "walk"
    return SOURCE_ROOT / "Frames" / (
        f"voss_{filename_group}_{direction}_{phase:02d}_chroma_v17.png"
    )


def source_contract() -> dict[str, str]:
    paths = [
        frame_path("standing_idle", direction, phase)
        for direction in DIRECTIONS
        for phase in range(4)
    ]
    paths.extend(
        frame_path("walk", direction, phase)
        for direction in DIRECTIONS
        for phase in range(8)
    )
    missing = [str(path.relative_to(ROOT)) for path in paths if not path.is_file()]
    if missing:
        raise OriginalGameplayError("Missing original V17 sources: " + ", ".join(missing))
    return {str(path.relative_to(ROOT)): sha256(path) for path in paths}


def save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=True)


def _processed(path: Path) -> Image.Image:
    return v17.process_figure(v17.load_source(path))


def _build_contents(stage: Path) -> None:
    southwest_idle: dict[int, Image.Image] = {}
    for direction in DIRECTIONS:
        for phase in range(4):
            cell = _processed(frame_path("standing_idle", direction, phase))
            save_png(
                cell,
                stage / "VossIdle.atlas" / f"voss_standing_idle_{direction}_{phase:02d}.png",
            )
            if direction == "sw":
                southwest_idle[phase] = cell
    for phase in range(4):
        save_png(
            southwest_idle[phase].transpose(Image.Transpose.FLIP_LEFT_RIGHT),
            stage / "VossIdle.atlas" / f"voss_standing_idle_se_{phase:02d}.png",
        )

    for direction in DIRECTIONS:
        for phase in range(8):
            cell = _processed(frame_path("walk", direction, phase))
            save_png(
                cell,
                stage / "VossWalk.atlas" / f"voss_walk_{direction}_{phase:02d}.png",
            )


def _expected_names() -> dict[str, set[str]]:
    idle = {
        f"voss_standing_idle_{direction}_{phase:02d}.png"
        for direction in (*DIRECTIONS, "se")
        for phase in range(4)
    }
    walk = {
        f"voss_walk_{direction}_{phase:02d}.png"
        for direction in DIRECTIONS
        for phase in range(8)
    }
    return {"VossIdle.atlas": idle, "VossWalk.atlas": walk}


def validate_stage(stage: Path) -> dict[str, Any]:
    errors: list[str] = []
    output_hashes: dict[str, str] = {}
    metrics: dict[str, dict[str, float]] = {}
    distinct_phases: dict[str, int] = {}
    for atlas, names in _expected_names().items():
        present = {path.name for path in (stage / atlas).glob("*.png")}
        if present != names:
            errors.append(f"{atlas}: expected {len(names)} exact names, found {len(present)}")
        for name in sorted(names & present):
            path = stage / atlas / name
            cell_errors, frame = v17._validate_raster_cell(path)
            errors.extend(f"{name}: {error}" for error in cell_errors)
            if frame is not None:
                if not 198 <= frame.height <= 202:
                    errors.append(f"{name}: body height {frame.height}, expected 198...202")
                if frame.foot_y != 433:
                    errors.append(f"{name}: foot row {frame.foot_y}, expected 433")
                if abs(frame.center_x - 255.5) > 2:
                    errors.append(f"{name}: body centre {frame.center_x:.1f}, expected within 2px")
                metrics[f"{atlas}/{name}"] = {
                    "height": frame.height,
                    "width": frame.width,
                    "center_x": frame.center_x,
                    "head_center_x": frame.head_center_x,
                }
            output_hashes[f"{atlas}/{name}"] = sha256(path)
    for direction in DIRECTIONS:
        idle_hashes = {
            output_hashes[f"VossIdle.atlas/voss_standing_idle_{direction}_{phase:02d}.png"]
            for phase in range(4)
        }
        walk_hashes = {
            output_hashes[f"VossWalk.atlas/voss_walk_{direction}_{phase:02d}.png"]
            for phase in range(8)
        }
        distinct_phases[f"idle_{direction}"] = len(idle_hashes)
        distinct_phases[f"walk_{direction}"] = len(walk_hashes)
        if len(idle_hashes) < 2:
            errors.append(f"idle {direction}: phases collapsed to one raster")
        if len(walk_hashes) < 4:
            errors.append(f"walk {direction}: fewer than four distinct processed phases")
    if errors:
        raise OriginalGameplayError("Original-gameplay staging failed:\n - " + "\n - ".join(errors))
    return {
        "status": "passed-animated-with-motion-quality-waiver",
        "counts": ATLAS_COUNTS,
        "output_hashes": output_hashes,
        "frame_metrics": metrics,
        "distinct_processed_phases": distinct_phases,
        "waived_gates": [
            "planted-foot exchange",
            "walk head jitter",
            "walk head scale",
            "walk torso scale",
            "walk loop closure",
        ],
    }


def _replace_directory(build: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        retired = destination.with_name(f".{destination.name}.retired-{uuid.uuid4().hex}")
        os.replace(destination, retired)
        os.replace(build, destination)
        shutil.rmtree(retired)
    else:
        os.replace(build, destination)


def build_stage() -> dict[str, Any]:
    sources = source_contract()
    temporary = STAGING_ROOT.with_name(f".{STAGING_ROOT.name}.build-{uuid.uuid4().hex}")
    temporary.mkdir(parents=True, exist_ok=False)
    try:
        _build_contents(temporary)
        report = validate_stage(temporary)
        report.update(
            {
                "asset_version": "v17-animated-original-imagegen-gameplay",
                "source_hashes": sources,
                "built_at_utc": datetime.now(timezone.utc).isoformat(),
            }
        )
        (temporary / "stage_report.json").write_text(
            json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
        _replace_directory(temporary, STAGING_ROOT)
    except Exception:
        if temporary.exists():
            shutil.rmtree(temporary)
        raise
    return report


def _crop_actor(cell: Image.Image, size: int = 240) -> Image.Image:
    return cell.resize((size, size), Image.Resampling.NEAREST)


def generate_qa(report: dict[str, Any]) -> None:
    QA_ROOT.mkdir(parents=True, exist_ok=True)
    cell_size = 240
    facing = Image.new("RGBA", (5 * cell_size, 2 * cell_size), (36, 42, 47, 255))
    for index, direction in enumerate(DIRECTIONS):
        with Image.open(
            STAGING_ROOT / "VossIdle.atlas" / f"voss_standing_idle_{direction}_00.png"
        ) as opened:
            cell = _crop_actor(opened.convert("RGBA"), cell_size)
        facing.alpha_composite(cell, ((index % 5) * cell_size, (index // 5) * cell_size))
        ImageDraw.Draw(facing).text(
            ((index % 5) * cell_size + 8, (index // 5) * cell_size + 8),
            direction.upper(), fill=(255, 255, 255, 255)
        )
    facing.convert("RGB").save(QA_ROOT / "qa_v17_original_direction_keys_v14.png")

    for direction in DIRECTIONS:
        walk = Image.new("RGBA", (8 * cell_size, cell_size), (36, 42, 47, 255))
        frames: list[Image.Image] = []
        for phase in range(8):
            with Image.open(
                STAGING_ROOT / "VossWalk.atlas" / f"voss_walk_{direction}_{phase:02d}.png"
            ) as opened:
                cell = _crop_actor(opened.convert("RGBA"), cell_size)
            walk.alpha_composite(cell, (phase * cell_size, 0))
            frames.append(cell.convert("RGBA"))
        walk.convert("RGB").save(QA_ROOT / f"qa_v17_animated_walk_{direction}_v14.png")
        frames[0].save(
            QA_ROOT / f"qa_v17_animated_walk_{direction}_quarter_speed.gif",
            save_all=True,
            append_images=frames[1:],
            duration=400,
            loop=0,
            disposal=2,
        )
    (QA_ROOT / "qa_report.json").write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )


def backup_runtime() -> Path:
    timestamp = datetime.now(timezone.utc).strftime("v17-animated-%Y%m%dT%H%M%SZ")
    destination = BACKUP_ROOT / timestamp
    destination.mkdir(parents=True, exist_ok=False)
    hashes: dict[str, str] = {}
    expected = _expected_names()
    for atlas, names in expected.items():
        source = RUNTIME_ROOT / atlas
        if not source.is_dir():
            raise OriginalGameplayError(f"Missing runtime atlas {source}")
        target = destination / atlas
        target.mkdir(parents=True, exist_ok=True)
        for name in sorted(names):
            source_path = source / name
            if not source_path.is_file():
                raise OriginalGameplayError(f"Missing canonical runtime texture {source_path}")
            target_path = target / name
            shutil.copyfile(source_path, target_path)
            hashes[f"{atlas}/{name}"] = sha256(target_path)
    (destination / "backup_manifest.json").write_text(
        json.dumps(
            {"captured_at_utc": datetime.now(timezone.utc).isoformat(), "files": hashes},
            indent=2,
            sort_keys=True,
        ) + "\n",
        encoding="utf-8",
    )
    return destination


def quarantine_runtime_duplicates() -> Path | None:
    duplicates = [
        path
        for atlas in ATLAS_COUNTS
        for path in (RUNTIME_ROOT / atlas).glob("*.png")
        if DUPLICATE_NAME.fullmatch(path.name)
    ]
    if not duplicates:
        return None
    timestamp = datetime.now(timezone.utc).strftime("duplicates-%Y%m%dT%H%M%SZ")
    destination = DUPLICATE_QUARANTINE_ROOT / timestamp
    if destination.exists():
        destination = DUPLICATE_QUARANTINE_ROOT / f"{timestamp}-{uuid.uuid4().hex[:8]}"
    for source in duplicates:
        target = destination / source.parent.name / source.name
        target.parent.mkdir(parents=True, exist_ok=True)
        os.replace(source, target)
    return destination


def install(report: dict[str, Any]) -> tuple[Path, Path | None]:
    validate_stage(STAGING_ROOT)
    backup = backup_runtime()
    quarantine = quarantine_runtime_duplicates()
    expected = _expected_names()
    replacements = [
        (STAGING_ROOT / atlas / name, RUNTIME_ROOT / atlas / name)
        for atlas, names in expected.items()
        for name in sorted(names)
    ]
    v17._swap_payload_transaction(replacements)
    installed = {
        f"{atlas}/{name}": sha256(RUNTIME_ROOT / atlas / name)
        for atlas, names in expected.items()
        for name in sorted(names)
    }
    if installed != report["output_hashes"]:
        raise OriginalGameplayError("Installed original-gameplay hashes differ from staging")
    unexpected = [
        path
        for atlas, names in expected.items()
        for path in (RUNTIME_ROOT / atlas).glob("*.png")
        if path.name not in names
    ]
    if unexpected:
        raise OriginalGameplayError(
            "Unexpected runtime atlas PNGs after install: "
            + ", ".join(str(path.relative_to(ROOT)) for path in unexpected)
        )
    return backup, quarantine


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("stage", "install"))
    parser.add_argument("--confirm-runtime-replace", metavar="ANIMATED")
    args = parser.parse_args(argv)
    report = build_stage()
    generate_qa(report)
    if args.command == "stage":
        print("Animated original V17 staging passed: 40 idle + 72 walk cells; motion-quality gates waived")
        return 0
    if args.confirm_runtime_replace != "ANIMATED":
        parser.error("install requires --confirm-runtime-replace ANIMATED")
    backup, quarantine = install(report)
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(
        json.dumps(
            {
                **report,
                "runtime_backup": str(backup.relative_to(ROOT)),
                "duplicate_quarantine": (
                    str(quarantine.relative_to(ROOT)) if quarantine is not None else None
                ),
            },
            indent=2,
            sort_keys=True,
        ) + "\n",
        encoding="utf-8",
    )
    print(f"Animated original V17 idle/walk installed; prior atlases backed up at {backup.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

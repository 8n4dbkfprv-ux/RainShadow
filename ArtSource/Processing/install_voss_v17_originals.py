#!/usr/bin/env python3
"""Process and install the untouched V17 Image Generator gameplay originals.

This intentionally waives locomotion, head-jitter, torso-scale, and uniqueness
gates at the user's request. The nine approved direction keys own idle and the
eight directions that never received an original walk batch. The rejected but
visually approved-quality SW Image Generator proof owns the complete SW walk.
V14 still owns chroma keying, 56-row native reduction, per-material 64-colour
palette, hard alpha, nearest enlargement, 200px body, 512 canvas, and row-433
foot registration.

Only VossIdle.atlas and VossWalk.atlas are replaced. No original V17 seated or
transition batch exists, so those atlases and both smooth UI assets are retained.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
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
OUTPUT_ROOT = SOURCE_ROOT / "OriginalGameplay"
STAGING_ROOT = OUTPUT_ROOT / "Staging"
QA_ROOT = OUTPUT_ROOT / "QA"
REPORT_PATH = OUTPUT_ROOT / "voss_v17_original_gameplay_report.json"
BACKUP_ROOT = ROOT / "ArtSource/Generated/Characters/RuntimeBackupPreRendered3DV17OriginalsPrior"
RUNTIME_ROOT = ROOT / "RainShadow Shared/Resources/Art/Atlases"

DIRECTIONS = tuple(v17.WESTERN_DIRECTIONS)
ATLAS_COUNTS = {"VossIdle.atlas": 40, "VossWalk.atlas": 72}


class OriginalGameplayError(RuntimeError):
    pass


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def key_path(direction: str) -> Path:
    return SOURCE_ROOT / "Keys" / f"voss_key_{direction}_chroma_v17.png"


def sw_walk_path(phase: int) -> Path:
    return (
        SOURCE_ROOT
        / "ProofCandidates/SWWalkV17Alternating"
        / f"voss_walk_sw_{phase:02d}.png"
    )


def source_contract() -> dict[str, str]:
    paths = [key_path(direction) for direction in DIRECTIONS]
    paths.extend(sw_walk_path(phase) for phase in range(8))
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
    idle: dict[str, Image.Image] = {
        direction: _processed(key_path(direction)) for direction in DIRECTIONS
    }
    for direction, cell in idle.items():
        for phase in range(4):
            save_png(
                cell,
                stage / "VossIdle.atlas" / f"voss_standing_idle_{direction}_{phase:02d}.png",
            )
    for phase in range(4):
        save_png(
            idle["sw"].transpose(Image.Transpose.FLIP_LEFT_RIGHT),
            stage / "VossIdle.atlas" / f"voss_standing_idle_se_{phase:02d}.png",
        )

    for direction in DIRECTIONS:
        for phase in range(8):
            source = sw_walk_path(phase) if direction == "sw" else key_path(direction)
            cell = _processed(source) if direction == "sw" else idle[direction]
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
    if errors:
        raise OriginalGameplayError("Original-gameplay staging failed:\n - " + "\n - ".join(errors))
    return {
        "status": "passed-with-motion-waiver",
        "counts": ATLAS_COUNTS,
        "output_hashes": output_hashes,
        "frame_metrics": metrics,
        "waived_gates": [
            "walk source uniqueness outside SW",
            "planted-foot exchange outside SW",
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
                "asset_version": "v17-original-imagegen-gameplay",
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

    walk = Image.new("RGBA", (8 * cell_size, cell_size), (36, 42, 47, 255))
    frames: list[Image.Image] = []
    for phase in range(8):
        with Image.open(
            STAGING_ROOT / "VossWalk.atlas" / f"voss_walk_sw_{phase:02d}.png"
        ) as opened:
            cell = _crop_actor(opened.convert("RGBA"), cell_size)
        walk.alpha_composite(cell, (phase * cell_size, 0))
        frames.append(cell.convert("RGBA"))
    walk.convert("RGB").save(QA_ROOT / "qa_v17_original_sw_walk_v14.png")
    frames[0].save(
        QA_ROOT / "qa_v17_original_sw_walk_quarter_speed.gif",
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
    timestamp = datetime.now(timezone.utc).strftime("v17-originals-%Y%m%dT%H%M%SZ")
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


def install(report: dict[str, Any]) -> Path:
    validate_stage(STAGING_ROOT)
    backup = backup_runtime()
    replacements = [
        (STAGING_ROOT / atlas, RUNTIME_ROOT / atlas) for atlas in ATLAS_COUNTS
    ]
    v17._swap_payload_transaction(replacements)
    installed = {
        f"{atlas}/{path.name}": sha256(path)
        for atlas in ATLAS_COUNTS
        for path in sorted((RUNTIME_ROOT / atlas).glob("*.png"))
    }
    if installed != report["output_hashes"]:
        raise OriginalGameplayError("Installed original-gameplay hashes differ from staging")
    return backup


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("stage", "install"))
    parser.add_argument("--confirm-runtime-replace", metavar="ORIGINALS")
    args = parser.parse_args(argv)
    report = build_stage()
    generate_qa(report)
    if args.command == "stage":
        print("Original V17 gameplay staging passed: 40 idle + 72 walk cells; motion gates waived")
        return 0
    if args.confirm_runtime_replace != "ORIGINALS":
        parser.error("install requires --confirm-runtime-replace ORIGINALS")
    backup = install(report)
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(
        json.dumps(
            {**report, "runtime_backup": str(backup.relative_to(ROOT))},
            indent=2,
            sort_keys=True,
        ) + "\n",
        encoding="utf-8",
    )
    print(f"Original V17 idle/walk installed; prior atlases backed up at {backup.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

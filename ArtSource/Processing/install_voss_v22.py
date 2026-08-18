#!/usr/bin/env python3
"""Validate, stage, and install the V22 Voss character-strip art.

V22 reuses the V16/V14 raster engine (`install_voss_v16` + `crunch.py`).
Masters live under PreRendered3DV22/; this script is the only path that may
replace runtime atlases. Wardrobe hue is preserved so the 3D-model lock
(open brown coat, brown waistcoat, maroon tie) survives the raster.
"""

from __future__ import annotations

import argparse
from contextlib import contextmanager
from copy import deepcopy
import json
import os
from pathlib import Path
import sys
from typing import Any, Iterator

PROCESSING_DIR = Path(__file__).resolve().parent
ROOT = PROCESSING_DIR.parents[1]
if str(PROCESSING_DIR) not in sys.path:
    sys.path.insert(0, str(PROCESSING_DIR))

import install_voss_v16 as core  # noqa: E402


V22_ROOT = ROOT / "ArtSource/Generated/Characters/Detective/PreRendered3DV22"
MANIFEST_PATH = V22_ROOT / "voss_v22_manifest.json"
RUNTIME_ATLASES = ROOT / "RainShadow Shared/Resources/Art/Atlases"
BACKUP_ROOT = ROOT / "ArtSource/Generated/Characters/RuntimeBackupPreRendered3DV22Prior"
PAPERDOLL_RELATIVE = Path("Inventory/voss_paperdoll_front_rgba_v01.png")
PORTRAIT_SHA256 = "13a5f349a2c08fb7517ae9cbb8a1b3953489458e654286ae3e29631782e8ec1d"

# Identity lock from the supplied 3D turnaround. PRESERVE_WARDROBE keeps these
# hues; the numbers are the V16 material-match targets, not a flatten stamp.
V22_WARDROBE = {
    "coat": (101, 59, 38),
    "shirt": (211, 194, 160),
    "tie": (128, 36, 42),
    "trousers": (70, 48, 32),
    "shoes": (40, 30, 22),
    "skin": (202, 143, 108),
    "hair": (140, 90, 48),
}

WESTERN_DIRECTIONS = core.WESTERN_DIRECTIONS
SEAT_DIRECTIONS = core.SEAT_DIRECTIONS
RUNTIME_ATLAS_ORDER = core.RUNTIME_ATLAS_ORDER
V22ValidationError = core.V16ValidationError


@contextmanager
def _v22_core_context(manifest_path: Path | None = None) -> Iterator[None]:
    attributes = {
        "V16_ROOT": core.V16_ROOT,
        "MANIFEST_PATH": core.MANIFEST_PATH,
        "RUNTIME_ATLASES": core.RUNTIME_ATLASES,
        "BACKUP_ROOT": core.BACKUP_ROOT,
    }
    wardrobe = dict(core.crunch.WARDROBE)
    preserve = core.crunch.PRESERVE_WARDROBE
    environment = os.environ.get("RAINSHADOW_PRESERVE_WARDROBE")
    original_scale_errors = core._source_sequence_scale_errors
    original_process_clip = core._process_clip

    def _v22_source_scale_errors(label, keyed, *, maximum_ratio=1.12):
        # Stand-up masters change pose (and therefore head/canvas ratio) by
        # design. Locomotion clips get a small ImageGen margin over V16's 1.12.
        if str(label).startswith("stand_up"):
            maximum_ratio = 1.50
        else:
            maximum_ratio = max(maximum_ratio, 1.16)
        return original_scale_errors(label, keyed, maximum_ratio=maximum_ratio)

    def _v22_process_clip(keyed, label, report):
        frames = list(keyed)
        if str(label).startswith("standing_idle:"):
            from process_voss_character_strip_v22 import stabilize_idle_keyed

            frames = stabilize_idle_keyed(frames)
        return original_process_clip(frames, label, report)

    try:
        core.V16_ROOT = V22_ROOT
        core.RUNTIME_ATLASES = RUNTIME_ATLASES
        core.BACKUP_ROOT = BACKUP_ROOT
        core.crunch.WARDROBE = V22_WARDROBE
        core.crunch.PRESERVE_WARDROBE = True
        core._source_sequence_scale_errors = _v22_source_scale_errors
        core._process_clip = _v22_process_clip
        os.environ["RAINSHADOW_PRESERVE_WARDROBE"] = "1"
        if manifest_path is not None:
            core.MANIFEST_PATH = Path(manifest_path)
        yield
    finally:
        for name, value in attributes.items():
            setattr(core, name, value)
        core.crunch.WARDROBE = wardrobe
        core.crunch.PRESERVE_WARDROBE = preserve
        core._source_sequence_scale_errors = original_scale_errors
        core._process_clip = original_process_clip
        if environment is None:
            os.environ.pop("RAINSHADOW_PRESERVE_WARDROBE", None)
        else:
            os.environ["RAINSHADOW_PRESERVE_WARDROBE"] = environment


def _wardrobe_hex() -> dict[str, str]:
    return {
        name: "#" + "".join(f"{channel:02X}" for channel in rgb)
        for name, rgb in V22_WARDROBE.items()
    }


def _compat_manifest(manifest: dict[str, Any]) -> dict[str, Any]:
    compatible = deepcopy(manifest)
    compatible["schema_version"] = 1
    compatible["asset_version"] = "v16"
    compatible["counts"] = {
        "imagegen_body_masters": int(manifest["counts"]["authored_gameplay_masters"]),
        "primary_body_presentations": int(manifest["counts"]["primary_body_presentations"]),
        "runtime_pngs": int(manifest["counts"]["runtime_pngs"]),
    }
    compatible["wardrobe"] = _wardrobe_hex()
    compatible.setdefault("gates", {})
    compatible["gates"].setdefault("processed_front_hue_spread_min", 0)
    compatible["gates"].setdefault("anchor_width_height_ratio", [0.4, 0.43])
    compatible["runtime"] = {
        "VossIdle.atlas": 40,
        "VossWalk.atlas": 72,
        "VossSeatedIdle.atlas": 32,
        "VossSeatedArms.atlas": 16,
        "VossSeatTransitions.atlas": 48,
    }
    compatible.setdefault("processing", {})
    compatible["processing"].update(
        {
            "processor": "V15",
            "native_body_rows": core.crunch.ACTIVE.native_rows,
            "texture_body_height": 200,
            "canvas": [512, 512],
            "foot_row": 433,
            "corner_sentinel_alpha": 1,
            "palette_colors": core.crunch.ACTIVE.colors,
            "dither": False,
            "hard_alpha": core.crunch.ACTIVE.hard_alpha,
            "preserve_wardrobe": True,
            "seated_se_source_mirror_x": True,
            "forbidden_legacy_locks": [
                "seated_authority_lock",
                "identity_wardrobe_lock",
                "relock_voss_identity_v12",
            ],
        }
    )
    return compatible


def load_manifest() -> dict[str, Any]:
    if not MANIFEST_PATH.is_file():
        raise V22ValidationError(f"Missing V22 manifest: {MANIFEST_PATH}")
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    if manifest.get("schema_version") != 4 or manifest.get("asset_version") != "v22":
        raise V22ValidationError("manifest must declare schema_version=4 and asset_version=v22")
    with _v22_core_context():
        core.validate_manifest_contract(_compat_manifest(manifest))
    return manifest


def _portrait_errors() -> list[str]:
    portrait = V22_ROOT / "References/dialogue_portrait_harlan_voss_v01.png"
    if not portrait.is_file():
        return [f"missing immutable portrait {portrait}"]
    digest = core.sha256(portrait)
    if digest != PORTRAIT_SHA256:
        return [f"portrait hash {digest} != locked {PORTRAIT_SHA256}"]
    return []


def validate_sources(manifest: dict[str, Any], *, include_all: bool) -> dict[str, Any]:
    errors = _portrait_errors()
    if errors:
        raise V22ValidationError(errors)
    with _v22_core_context():
        return core.validate_sources(_compat_manifest(manifest), include_all=include_all)


def _scale_keyed(source, target_height: int):
    from PIL import Image as PILImage

    del PILImage
    x0, y0, x1, y1 = core.visible_bbox(source)
    figure = source.crop((x0, y0, x1 + 1, y1 + 1))
    height = max(1, figure.height)
    width = max(1, round(figure.width * target_height / height))
    return core.crunch.raster.premultiplied_resize(figure, (width, target_height))


def _restage_seats(stage_root: Path, manifest: dict[str, Any]) -> None:
    """Force seated/standing endpoint scale the way V21 does after the V14 crunch."""
    compatible = _compat_manifest(manifest)
    sources, _ = core._load_keyed_body_sources(compatible)
    empty = core._empty_runtime_cell()
    for direction in SEAT_DIRECTIONS:
        from PIL import Image as PILImage

        stand_sources = [sources[("stand_up", direction, phase)] for phase in range(12)]
        idle_sources = [sources[("seated_idle", direction, phase)] for phase in range(8)]
        # V16 restages SE because those masters were authored lower-left.
        # V22 SE chroma is already the runtime lower-right view; mirroring it
        # again sits him facing the room instead of the desk. NE is the office
        # authority, and V22's NE chain was authored as true-NE — opposite the
        # V21 desk view — so the last stand-up cell cannot hand off to NW idle
        # mirrored at runtime. Flip NE only.
        if direction == "ne":
            stand_sources = [
                source.transpose(PILImage.Transpose.FLIP_LEFT_RIGHT)
                for source in stand_sources
            ]
            idle_sources = [
                source.transpose(PILImage.Transpose.FLIP_LEFT_RIGHT)
                for source in idle_sources
            ]
        stand_sources = [core.normalise_source_resolution(source) for source in stand_sources]
        idle_sources = [core.normalise_source_resolution(source) for source in idle_sources]
        reference_height = core.source_opaque_height(stand_sources[-1])
        target_seated = max(1, round(reference_height * 155 / 200))
        seated_height = target_seated
        idle_cells = [
            core.process_keyed_figure(
                _scale_keyed(source, seated_height),
                reference_height=reference_height,
            )
            for source in idle_sources
        ]
        stand_heights = [
            round(seated_height + phase * (reference_height - seated_height) / 11)
            for phase in range(12)
        ]
        stand_cells = [
            core.process_keyed_figure(
                _scale_keyed(source, stand_heights[phase]),
                reference_height=reference_height,
            )
            for phase, source in enumerate(stand_sources)
        ]
        sit_cells = list(reversed(stand_cells))
        for phase, cell in enumerate(idle_cells):
            core._save_atlas_cell(
                stage_root,
                "VossSeatedIdle.atlas",
                f"voss_seated_idle_{direction}_{phase:02d}.png",
                cell,
            )
            if direction == "ne":
                upper, lower = core.split_upper_lower(cell)
                core._save_atlas_cell(
                    stage_root,
                    "VossSeatedIdle.atlas",
                    f"voss_seated_upper_ne_{phase:02d}.png",
                    upper,
                )
                core._save_atlas_cell(
                    stage_root,
                    "VossSeatedIdle.atlas",
                    f"voss_seated_lower_ne_{phase:02d}.png",
                    lower,
                )
            core._save_atlas_cell(
                stage_root,
                "VossSeatedArms.atlas",
                f"voss_seated_arms_{direction}_{phase:02d}.png",
                empty,
            )
        for phase, cell in enumerate(stand_cells):
            core._save_atlas_cell(
                stage_root,
                "VossSeatTransitions.atlas",
                f"voss_stand_up_{direction}_{phase:02d}.png",
                cell,
            )
        for phase, cell in enumerate(sit_cells):
            core._save_atlas_cell(
                stage_root,
                "VossSeatTransitions.atlas",
                f"voss_sit_down_{direction}_{phase:02d}.png",
                cell,
            )


def stage(manifest: dict[str, Any]) -> tuple[Path, dict[str, Any]]:
    from datetime import datetime, timezone
    import uuid
    import shutil

    compatible = _compat_manifest(manifest)
    with _v22_core_context():
        source_report = core.validate_sources(compatible, include_all=True)
        staging = V22_ROOT / compatible["staging_root"]
        temporary = staging.with_name(f".{staging.name}.build-{uuid.uuid4().hex}")
        temporary.mkdir(parents=True, exist_ok=False)
        try:
            core.build_stage_contents(compatible, temporary)
            _restage_seats(temporary, manifest)
            gate_report = core.validate_staging(temporary, compatible)
            report = {
                **gate_report,
                "manifest_sha256": core.sha256(MANIFEST_PATH),
                "source": source_report,
                "built_at_utc": datetime.now(timezone.utc).isoformat(),
            }
            core.write_json(temporary / "voss_v22_stage_report.json", report)
            core._copy_file_without_metadata(MANIFEST_PATH, temporary / "voss_v22_manifest.json")
            core.replace_directory_transactionally(temporary, staging)
        except Exception:
            if temporary.exists():
                shutil.rmtree(temporary)
            raise
    paperdoll = V22_ROOT / "UI" / PAPERDOLL_RELATIVE.name
    if paperdoll.is_file():
        dest = staging / "UI" / PAPERDOLL_RELATIVE
        dest.parent.mkdir(parents=True, exist_ok=True)
        core._copy_file_without_metadata(paperdoll, dest)
    return staging, report


def install(manifest: dict[str, Any]) -> Path:
    staging, report = stage(manifest)
    compatible = _compat_manifest(manifest)
    with _v22_core_context():
        previous = core.load_manifest
        core.load_manifest = lambda path=None, _manifest=compatible: _manifest
        try:
            return core.install_runtime_transaction(staging, report)
        finally:
            core.load_manifest = previous


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("validate-proof", help="validate SW idle+walk masters when present")
    sub.add_parser("validate", help="validate all present V22 chroma masters")
    sub.add_parser("stage", help="crunch masters into PreRendered3DV22/Staging")
    install_p = sub.add_parser("install", help="transactionally replace runtime Voss art")
    install_p.add_argument("--confirm-runtime-replace", metavar="V22")
    args = parser.parse_args(argv)

    try:
        manifest = load_manifest()
        if args.command == "validate-proof":
            report = validate_sources(manifest, include_all=False)
            print(
                f"V22 proof inputs passed: {report.get('masters_validated', 0)} masters; "
                "runtime untouched"
            )
        elif args.command == "validate":
            report = validate_sources(manifest, include_all=True)
            print(
                f"V22 source validation passed: {report.get('masters_validated', 0)} body masters; "
                "runtime untouched"
            )
        elif args.command == "stage":
            staging, report = stage(manifest)
            print(
                f"V22 staging passed: {report.get('counts', {}).get('runtime_pngs', '?')} PNGs at "
                f"{staging.relative_to(ROOT)}; runtime untouched"
            )
        elif args.command == "install":
            if args.confirm_runtime_replace != "V22":
                parser.error("install requires --confirm-runtime-replace V22")
            backup = install(manifest)
            print(f"V22 installed; prior runtime saved at {backup}")
    except V22ValidationError as error:
        core._print_validation_error(error)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

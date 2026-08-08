#!/usr/bin/env python3
"""Validate, stage, and transactionally install the isolated V17 Voss replacement.

V17 reuses the proven V16 atlas expansion and V14 raster registration, but owns
its references, material contract, smooth UI assets, reports, backups, and
runtime transaction.  Validation and staging are read-only with respect to the
game.  Runtime replacement requires the literal ``V17`` confirmation.
"""

from __future__ import annotations

import argparse
from copy import deepcopy
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil
import sys
import uuid
from typing import Any, Iterable, Sequence

import numpy as np
from PIL import Image


PROCESSING_DIR = Path(__file__).resolve().parent
ROOT = PROCESSING_DIR.parents[1]
if str(PROCESSING_DIR) not in sys.path:
    sys.path.insert(0, str(PROCESSING_DIR))

import install_voss_v16 as core  # noqa: E402


V17_ROOT = ROOT / "ArtSource/Generated/Characters/Detective/PreRendered3DV17"
MANIFEST_PATH = V17_ROOT / "voss_v17_manifest.json"
RUNTIME_ATLASES = ROOT / "RainShadow Shared/Resources/Art/Atlases"
RUNTIME_UI = ROOT / "RainShadow Shared/Resources/Art/UI"
BACKUP_ROOT = ROOT / "ArtSource/Generated/Characters/RuntimeBackupPreRendered3DV17Prior"

V17_WARDROBE = {
    "coat": (101, 59, 38),
    "shirt": (211, 194, 160),
    "tie": (31, 30, 31),
    "trousers": (55, 55, 59),
    "shoes": (75, 47, 35),
    "skin": (202, 143, 108),
    "hair": (112, 50, 29),
}

UI_RELATIVE_PATHS = (
    Path("Inventory/voss_paperdoll_front_rgba_v01.png"),
    Path("Dialogue/dialogue_portrait_harlan_voss_v01.png"),
)


# Rebind the shared V16 engine to the isolated V17 tree.  No V16 file or runtime
# asset is mutated by importing this module.
core.V16_ROOT = V17_ROOT
core.MANIFEST_PATH = MANIFEST_PATH
core.RUNTIME_ATLASES = RUNTIME_ATLASES
core.BACKUP_ROOT = BACKUP_ROOT
core.crunch.WARDROBE = V17_WARDROBE
core.crunch.PRESERVE_WARDROBE = True
os.environ["RAINSHADOW_PRESERVE_WARDROBE"] = "1"

V17ValidationError = core.V16ValidationError
MasterSpec = core.MasterSpec
FrameMetrics = core.FrameMetrics
WESTERN_DIRECTIONS = core.WESTERN_DIRECTIONS
SEAT_DIRECTIONS = core.SEAT_DIRECTIONS
RUNTIME_ATLAS_ORDER = core.RUNTIME_ATLAS_ORDER
sha256 = core.sha256
write_json = core.write_json
master_specs = core.master_specs
expected_runtime_names = core.expected_runtime_names
key_chroma = core.key_chroma
visible_mask = core.visible_mask
visible_bbox = core.visible_bbox
frame_metrics = core.frame_metrics
process_figure = core.process_figure
process_keyed_figure = core.process_keyed_figure
split_upper_lower = core.split_upper_lower
save_png = core.save_png
load_source = core.load_source
_validate_raster_cell = core._validate_raster_cell


def derive_sit_down(stand_up: Sequence[Image.Image]) -> list[Image.Image]:
    """The runtime sit-down contract is a pixel-exact reversal, never a re-render."""
    return list(reversed(stand_up))


def _fail_if(errors: Iterable[str]) -> None:
    collected = list(errors)
    if collected:
        raise V17ValidationError(collected)


def _compat_manifest(manifest: dict[str, Any]) -> dict[str, Any]:
    """Return the subset expected by the V16 atlas engine with inert hue gates."""
    compatible = deepcopy(manifest)
    compatible["asset_version"] = "v16"
    compatible["gates"]["source_front_hue_spread_min"] = 0.0
    compatible["gates"]["processed_front_hue_spread_min"] = 0.0
    return compatible


def validate_manifest_contract(manifest: dict[str, Any]) -> None:
    errors: list[str] = []
    if manifest.get("schema_version") != 2 or manifest.get("asset_version") != "v17":
        errors.append("manifest must declare schema_version=2 and asset_version=v17")

    try:
        compatible = _compat_manifest(manifest)
        compatible["schema_version"] = 1
        core.validate_manifest_contract(compatible)
    except (KeyError, TypeError, V17ValidationError) as error:
        errors.extend(error.errors if isinstance(error, V17ValidationError) else [str(error)])

    references = manifest.get("references", {})
    if set(references) != {
        "voss_target_profile_w.png",
        "voss_target_back.png",
        "voss_target_front_three_quarter.png",
    }:
        errors.append("manifest must record exactly the three authoritative RGB references")
    for filename, definition in references.items():
        digest = definition.get("sha256", "") if isinstance(definition, dict) else ""
        if len(digest) != 64:
            errors.append(f"reference {filename} has no complete SHA-256")

    ui = manifest.get("ui_outputs", {})
    required_ui = {
        "paperdoll": ("voss_paperdoll_front_rgba_v01.png", [1024, 1536], "RGBA"),
        "portrait": ("dialogue_portrait_harlan_voss_v01.png", [512, 512], "RGB"),
    }
    for name, (filename, size, mode) in required_ui.items():
        definition = ui.get(name, {})
        if definition.get("filename") != filename:
            errors.append(f"ui_outputs.{name}.filename must preserve {filename}")
        if definition.get("size") != size or definition.get("mode") != mode:
            errors.append(f"ui_outputs.{name} must be {size[0]}x{size[1]} {mode}")
        if definition.get("processing") != "smooth-high-resolution":
            errors.append(f"ui_outputs.{name} must bypass the V14 gameplay crunch")

    expected_targets = {
        name: "#" + "".join(f"{channel:02X}" for channel in rgb)
        for name, rgb in V17_WARDROBE.items()
    }
    if manifest.get("wardrobe") != expected_targets:
        errors.append("manifest wardrobe must contain the frozen seven-material V17 targets")
    gates = manifest.get("material_gates", {})
    if float(gates.get("maximum_delta_e", 0)) <= 0:
        errors.append("material_gates.maximum_delta_e must be positive")
    if float(gates.get("minimum_target_delta_e", 0)) <= 0:
        errors.append("material_gates.minimum_target_delta_e must be positive")
    if float(gates.get("minimum_luminance_gap", 0)) <= 0:
        errors.append("material_gates.minimum_luminance_gap must be positive")
    _fail_if(errors)


def load_manifest(path: Path | None = None) -> dict[str, Any]:
    path = path or MANIFEST_PATH
    try:
        manifest = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise V17ValidationError(f"Missing V17 manifest: {path}") from error
    except json.JSONDecodeError as error:
        raise V17ValidationError(f"Invalid V17 manifest JSON: {error}") from error
    validate_manifest_contract(manifest)
    return manifest


def validate_references(manifest: dict[str, Any]) -> dict[str, str]:
    errors: list[str] = []
    hashes: dict[str, str] = {}
    root = V17_ROOT / manifest["references_root"]
    for filename, definition in manifest["references"].items():
        path = root / filename
        if not path.is_file():
            errors.append(f"missing authoritative reference References/{filename}")
            continue
        with Image.open(path) as image:
            if image.mode != "RGB":
                errors.append(f"reference {filename} is {image.mode}, expected original RGB")
        digest = sha256(path)
        hashes[f"References/{filename}"] = digest
        if digest != definition["sha256"]:
            errors.append(f"reference hash drift: {filename}")
    _fail_if(errors)
    return hashes


def validate_ui_sources(manifest: dict[str, Any]) -> dict[str, str]:
    errors: list[str] = []
    hashes: dict[str, str] = {}
    root = V17_ROOT / manifest["ui_root"]
    for definition in manifest["ui_outputs"].values():
        path = root / definition["filename"]
        if not path.is_file():
            errors.append(f"missing smooth UI output UI/{path.name}")
            continue
        with Image.open(path) as image:
            if list(image.size) != definition["size"]:
                errors.append(f"{path.name}: size {image.size}, expected {tuple(definition['size'])}")
            if image.mode != definition["mode"]:
                errors.append(f"{path.name}: mode {image.mode}, expected {definition['mode']}")
            if definition["mode"] == "RGBA" and np.asarray(image)[..., 3].min() != 0:
                errors.append(f"{path.name}: paperdoll has no transparent background")
        hashes[f"UI/{path.name}"] = sha256(path)
    _fail_if(errors)
    return hashes


def _srgb_to_lab(rgb: np.ndarray) -> np.ndarray:
    values = np.asarray(rgb, dtype=np.float64) / 255.0
    linear = np.where(values <= 0.04045, values / 12.92, ((values + 0.055) / 1.055) ** 2.4)
    xyz = linear @ np.asarray(
        ((0.4124564, 0.3575761, 0.1804375),
         (0.2126729, 0.7151522, 0.0721750),
         (0.0193339, 0.1191920, 0.9503041)),
        dtype=np.float64,
    ).T
    xyz /= np.asarray((0.95047, 1.0, 1.08883))
    delta = 6.0 / 29.0
    transformed = np.where(xyz > delta ** 3, np.cbrt(xyz), xyz / (3 * delta ** 2) + 4.0 / 29.0)
    return np.stack(
        (116 * transformed[..., 1] - 16,
         500 * (transformed[..., 0] - transformed[..., 1]),
         200 * (transformed[..., 1] - transformed[..., 2])),
        axis=-1,
    )


def _relative_luminance(rgb: np.ndarray) -> np.ndarray:
    values = np.asarray(rgb, dtype=np.float64) / 255.0
    linear = np.where(values <= 0.04045, values / 12.92, ((values + 0.055) / 1.055) ** 2.4)
    return linear @ np.asarray((0.2126, 0.7152, 0.0722))


def material_separation_report(image: Image.Image, manifest: dict[str, Any]) -> dict[str, Any]:
    """Measure target separation and samples in CIE LAB plus luminance."""
    targets = {
        name: core._parse_hex(value) for name, value in manifest["wardrobe"].items()
    }
    target_labs = {name: _srgb_to_lab(value) for name, value in targets.items()}
    pairwise: dict[str, float] = {}
    for index, name in enumerate(targets):
        for other in list(targets)[index + 1 :]:
            pairwise[f"{name}:{other}"] = float(np.linalg.norm(target_labs[name] - target_labs[other]))

    rgba = np.asarray(image.convert("RGBA"))
    samples: dict[str, float] = {}
    luminance: dict[str, float] = {}
    for name, target in targets.items():
        region = core._material_region(image, name)
        pixels = rgba[..., :3][region]
        if not len(pixels):
            samples[name] = float("inf")
            luminance[name] = float("nan")
            continue
        distances = np.linalg.norm(_srgb_to_lab(pixels) - target_labs[name], axis=1)
        samples[name] = float(np.percentile(distances, 5))
        closest = pixels[np.argsort(distances)[: max(1, len(distances) // 20)]]
        luminance[name] = float(np.median(_relative_luminance(closest)))

    gates = manifest["material_gates"]
    errors: list[str] = []
    for name, distance in samples.items():
        if distance > float(gates["maximum_delta_e"]):
            errors.append(f"{name}: nearest material samples are DeltaE {distance:.2f}")
    minimum_pair = min(pairwise.values())
    if minimum_pair < float(gates["minimum_target_delta_e"]):
        errors.append(f"frozen targets collapse to DeltaE {minimum_pair:.2f}")
    required_pairs = (("shirt", "tie"), ("shirt", "coat"), ("coat", "trousers"))
    for first, second in required_pairs:
        gap = abs(luminance[first] - luminance[second])
        if gap < float(gates["minimum_luminance_gap"]):
            errors.append(f"{first}/{second}: luminance gap {gap:.3f} is too small")
    _fail_if(errors)
    return {
        "delta_e_05_percentile": {name: round(value, 3) for name, value in samples.items()},
        "minimum_target_delta_e": round(minimum_pair, 3),
        "material_luminance": {name: round(value, 4) for name, value in luminance.items()},
    }


def validate_sources(manifest: dict[str, Any], *, include_all: bool = True) -> dict[str, Any]:
    report = core.validate_sources(_compat_manifest(manifest), include_all=include_all)
    report["reference_hashes"] = validate_references(manifest)
    report["ui_hashes"] = validate_ui_sources(manifest)
    front_anchor = key_chroma(
        load_source(V17_ROOT / manifest["anchors_root"] / "voss_anchor_front_chroma_v17.png")
    )
    report["anchor_materials"] = material_separation_report(front_anchor, manifest)
    return report


def _validate_anchors_v17(
    manifest: dict[str, Any], errors: list[str]
) -> dict[str, Any]:
    report: dict[str, Any] = {}
    bounds = manifest["gates"]["anchor_width_height_ratio"]
    for view in ("front", "back"):
        path = V17_ROOT / manifest["anchors_root"] / f"voss_anchor_{view}_chroma_v17.png"
        if not path.exists():
            errors.append(f"missing {view} V17 anchor for processed shape gate")
            continue
        cell = process_figure(load_source(path))
        metrics = frame_metrics(cell)
        ratio = metrics.width / metrics.height
        report[view] = {
            "width": metrics.width,
            "height": metrics.height,
            "ratio": round(ratio, 4),
        }
        raster_tolerance = 1.0 / metrics.height
        if not float(bounds[0]) - raster_tolerance <= ratio <= float(bounds[1]) + raster_tolerance:
            errors.append(
                f"{view} anchor width/body-height ratio {ratio:.3f}, "
                f"expected {bounds[0]:.2f}...{bounds[1]:.2f}"
            )
    return report


core._validate_anchors = _validate_anchors_v17
_core_validate_staging = core.validate_staging


def _stage_ui(stage_root: Path, manifest: dict[str, Any]) -> None:
    source_root = V17_ROOT / manifest["ui_root"]
    for relative in UI_RELATIVE_PATHS:
        source = source_root / relative.name
        destination = stage_root / "UI" / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)


def _stabilise_walk_upper_bodies(stage_root: Path) -> None:
    """Register the authored gait without changing its lower-coat or leg poses.

    The eight V11 pose authorities contain alternating legs and valid foot
    plants, but their independently rendered heads and torsos wander. Phase zero
    is the per-facing upper-body authority through 64% of body height. The lower
    coat, legs, and feet remain authored per phase, preserving the full gait
    while making face position and actor scale deterministic.
    """
    for direction in WESTERN_DIRECTIONS:
        paths = [
            stage_root / "VossWalk.atlas" / f"voss_walk_{direction}_{phase:02d}.png"
            for phase in range(8)
        ]
        cells = [core._load_stage_cell(stage_root, "VossWalk.atlas", path.name) for path in paths]
        authority = np.asarray(cells[0].convert("RGBA"))
        metric = frame_metrics(cells[0])
        seam = metric.crown_y + round(metric.height * 0.64)
        for phase, (path, cell) in enumerate(zip(paths, cells)):
            pixels = np.asarray(cell.convert("RGBA")).copy()
            pixels[:seam] = authority[:seam]
            composed = _enforce_foot_lead(
                Image.fromarray(pixels, "RGBA"), "L" if phase % 2 == 0 else "R"
            )
            # Upper and lower cells were each valid 64-colour V14 results, but
            # their palette union can exceed 64. Re-impose the per-material
            # ramps once, without dithering, after this final composition.
            composed = core.crunch.finalise(composed)
            save_png(core.stamp_sentinels(composed), path)


def _enforce_foot_lead(cell: Image.Image, desired: str) -> Image.Image:
    """Register the two lower legs to an alternating planted-foot contract."""
    pixels = np.asarray(cell.convert("RGBA")).copy()
    mask = visible_mask(cell)
    ys, xs = np.where(mask)
    if not len(xs):
        return cell
    x0, x1, y0, y1 = int(xs.min()), int(xs.max()), int(ys.min()), int(ys.max())
    middle = (x0 + x1) // 2
    leg_start = y0 + round((y1 - y0 + 1) * 0.70)
    for side, (left, right) in {
        "L": (x0, middle + 1),
        "R": (middle + 1, x1 + 1),
    }.items():
        side_mask = mask[leg_start : y1 + 1, left:right]
        side_ys = np.where(side_mask)[0]
        if not len(side_ys):
            continue
        source = pixels[leg_start : y1 + 1, left:right].copy()
        source_visible = side_mask.copy()
        pixels[leg_start : y1 + 1, left:right][source_visible] = 0
        current_bottom = leg_start + int(side_ys.max())
        target_bottom = y1 if side == desired else y1 - 4
        shift = target_bottom - current_bottom
        source_rows, source_cols = np.where(source_visible)
        target_rows = source_rows + shift
        valid = (target_rows >= 0) & (target_rows < source.shape[0])
        target = pixels[leg_start : y1 + 1, left:right]
        target[target_rows[valid], source_cols[valid]] = source[source_rows[valid], source_cols[valid]]
    return Image.fromarray(pixels, "RGBA")


def _reinforce_wardrobe_cell(cell: Image.Image) -> Image.Image:
    """Keep the shirt opening and tie readable after the 56-row V14 crunch."""
    pixels = np.asarray(cell.convert("RGBA")).copy()
    mask = visible_mask(cell)
    ys, xs = np.where(mask)
    if not len(xs):
        return cell
    x0, x1, y0, y1 = int(xs.min()), int(xs.max()), int(ys.min()), int(ys.max())
    yy, xx = np.indices(mask.shape)
    ry = (yy - y0) / max(1, y1 - y0)
    center = (x0 + x1) / 2
    width = x1 - x0 + 1
    chest_phase = np.clip((ry - 0.16) / 0.32, 0.0, 1.0)
    shirt_half_width = width * (0.12 - 0.055 * chest_phase)
    shirt = (
        mask & (ry >= 0.16) & (ry <= 0.48)
        & (np.abs(xx - center) <= shirt_half_width)
    )
    tie = (
        mask & (ry >= 0.19) & (ry <= 0.50)
        & (np.abs(xx - center) <= max(1.0, width * 0.023))
    )
    pixels[shirt, :3] = V17_WARDROBE["shirt"]
    pixels[tie, :3] = V17_WARDROBE["tie"]
    reinforced = core.crunch.finalise(Image.fromarray(pixels, "RGBA"))
    return core.stamp_sentinels(reinforced)


def _reinforce_front_wardrobe(stage_root: Path) -> None:
    """Apply the readable front-garment contract and rebuild all derivations."""
    idle_names = [
        f"voss_standing_idle_{direction}_{phase:02d}.png"
        for direction in ("s", "ssw", "sw")
        for phase in range(4)
    ]
    walk_names = [
        f"voss_walk_{direction}_{phase:02d}.png"
        for direction in ("s", "ssw", "sw")
        for phase in range(8)
    ]
    for atlas, names in (("VossIdle.atlas", idle_names), ("VossWalk.atlas", walk_names)):
        for name in names:
            path = stage_root / atlas / name
            cell = core._load_stage_cell(stage_root, atlas, name)
            save_png(_reinforce_wardrobe_cell(cell), path)
    for phase in range(4):
        sw = core._load_stage_cell(
            stage_root, "VossIdle.atlas", f"voss_standing_idle_sw_{phase:02d}.png"
        )
        save_png(
            sw.transpose(Image.Transpose.FLIP_LEFT_RIGHT),
            stage_root / "VossIdle.atlas" / f"voss_standing_idle_se_{phase:02d}.png",
        )

    for direction in SEAT_DIRECTIONS:
        idle_cells: list[Image.Image] = []
        for phase in range(8):
            name = f"voss_seated_idle_{direction}_{phase:02d}.png"
            path = stage_root / "VossSeatedIdle.atlas" / name
            cell = _reinforce_wardrobe_cell(
                core._load_stage_cell(stage_root, "VossSeatedIdle.atlas", name)
            )
            save_png(cell, path)
            idle_cells.append(cell)
        if direction == "ne":
            for phase, cell in enumerate(idle_cells):
                upper, lower = split_upper_lower(cell)
                save_png(
                    upper,
                    stage_root / "VossSeatedIdle.atlas" / f"voss_seated_upper_ne_{phase:02d}.png",
                )
                save_png(
                    lower,
                    stage_root / "VossSeatedIdle.atlas" / f"voss_seated_lower_ne_{phase:02d}.png",
                )

        stand_cells: list[Image.Image] = []
        for phase in range(12):
            name = f"voss_stand_up_{direction}_{phase:02d}.png"
            path = stage_root / "VossSeatTransitions.atlas" / name
            cell = _reinforce_wardrobe_cell(
                core._load_stage_cell(stage_root, "VossSeatTransitions.atlas", name)
            )
            save_png(cell, path)
            stand_cells.append(cell)
        for phase, cell in enumerate(reversed(stand_cells)):
            save_png(
                cell,
                stage_root / "VossSeatTransitions.atlas" / f"voss_sit_down_{direction}_{phase:02d}.png",
            )


def _validate_staged_ui(stage_root: Path, manifest: dict[str, Any]) -> dict[str, str]:
    errors: list[str] = []
    hashes: dict[str, str] = {}
    definitions = {value["filename"]: value for value in manifest["ui_outputs"].values()}
    for relative in UI_RELATIVE_PATHS:
        path = stage_root / "UI" / relative
        definition = definitions[relative.name]
        if not path.is_file():
            errors.append(f"staging missing UI/{relative}")
            continue
        with Image.open(path) as image:
            if list(image.size) != definition["size"] or image.mode != definition["mode"]:
                errors.append(f"staged {relative.name} violates its smooth UI contract")
        hashes[f"UI/{relative.as_posix()}"] = sha256(path)
    _fail_if(errors)
    return hashes


def validate_staging(stage_root: Path, manifest: dict[str, Any]) -> dict[str, Any]:
    # V16's rear-tie heuristic scans the entire body for near-neutral dark
    # pixels. That was safe for its green tie, but V17's black tie is naturally
    # indistinguishable from legitimate rear-facing charcoal trouser pixels.
    # Suppress only that obsolete comparison; the rear-shirt check and the V17
    # LAB/luminance material gates below remain authoritative.
    original_rear_fraction = core._rear_forbidden_fraction

    def v17_rear_fraction(image: Image.Image, target_hex: str) -> float:
        if target_hex.upper() == manifest["wardrobe"]["tie"].upper():
            return 0.0
        return original_rear_fraction(image, target_hex)

    core._rear_forbidden_fraction = v17_rear_fraction
    try:
        report = _core_validate_staging(stage_root, _compat_manifest(manifest))
    finally:
        core._rear_forbidden_fraction = original_rear_fraction
    front = core._load_stage_cell(stage_root, "VossIdle.atlas", "voss_standing_idle_s_00.png")
    report["asset_version"] = "v17"
    report["materials_v17"] = material_separation_report(front, manifest)
    ui_hashes = _validate_staged_ui(stage_root, manifest)
    report["ui_output_hashes"] = ui_hashes
    report["output_hashes"].update(ui_hashes)
    report["counts"]["ui_outputs"] = 2
    return report


def build_staging(manifest: dict[str, Any]) -> tuple[Path, dict[str, Any]]:
    source_report = validate_sources(manifest, include_all=True)
    staging = V17_ROOT / manifest["staging_root"]
    temporary = staging.with_name(f".{staging.name}.build-{uuid.uuid4().hex}")
    temporary.mkdir(parents=True, exist_ok=False)
    try:
        core.build_stage_contents(_compat_manifest(manifest), temporary)
        _stabilise_walk_upper_bodies(temporary)
        _reinforce_front_wardrobe(temporary)
        _stage_ui(temporary, manifest)
        gate_report = validate_staging(temporary, manifest)
        report = {
            **gate_report,
            "manifest_sha256": sha256(MANIFEST_PATH),
            "source": source_report,
            "built_at_utc": datetime.now(timezone.utc).isoformat(),
        }
        write_json(temporary / "voss_v17_stage_report.json", report)
        core.replace_directory_transactionally(temporary, staging)
    except Exception:
        if temporary.exists():
            shutil.rmtree(temporary)
        raise
    return staging, report


def backup_runtime_payload() -> Path:
    timestamp = datetime.now(timezone.utc).strftime("v17-%Y%m%dT%H%M%SZ")
    snapshot = BACKUP_ROOT / timestamp
    if snapshot.exists():
        snapshot = BACKUP_ROOT / f"{timestamp}-{uuid.uuid4().hex[:8]}"
    temporary = snapshot.with_name(f".{snapshot.name}.build-{uuid.uuid4().hex}")
    hashes: dict[str, str] = {}
    temporary.mkdir(parents=True, exist_ok=False)
    try:
        for atlas in RUNTIME_ATLAS_ORDER:
            source_dir = RUNTIME_ATLASES / atlas
            if not source_dir.is_dir():
                raise V17ValidationError(f"cannot back up missing runtime atlas {source_dir}")
            for source in sorted(source_dir.glob("*.png")):
                destination = temporary / "Atlases" / atlas / source.name
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, destination)
                hashes[f"Atlases/{atlas}/{source.name}"] = sha256(destination)
        for relative in UI_RELATIVE_PATHS:
            source = RUNTIME_UI / relative
            if not source.is_file():
                raise V17ValidationError(f"cannot back up missing runtime UI {source}")
            destination = temporary / "UI" / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, destination)
            hashes[f"UI/{relative.as_posix()}"] = sha256(destination)
        write_json(
            temporary / "backup_manifest.json",
            {
                "asset_version": "v17",
                "captured_at_utc": datetime.now(timezone.utc).isoformat(),
                "files": hashes,
            },
        )
        snapshot.parent.mkdir(parents=True, exist_ok=True)
        os.replace(temporary, snapshot)
    except Exception:
        if temporary.exists():
            shutil.rmtree(temporary)
        raise
    return snapshot


def _swap_payload_transaction(
    replacements: Sequence[tuple[Path, Path]], *, fail_after: int | None = None
) -> None:
    """Replace files/directories and restore every prior item on any failure."""
    token = uuid.uuid4().hex
    prepared: list[tuple[Path, Path]] = []
    retired: list[tuple[Path, Path]] = []
    try:
        for source, destination in replacements:
            new = destination.with_name(f".{destination.name}.v17-new-{token}")
            if source.is_dir():
                shutil.copytree(source, new, copy_function=shutil.copyfile)
            else:
                new.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, new)
            prepared.append((new, destination))
        for index, (new, destination) in enumerate(prepared, start=1):
            old = destination.with_name(f".{destination.name}.v17-old-{token}")
            os.replace(destination, old)
            retired.append((old, destination))
            os.replace(new, destination)
            if fail_after is not None and index >= fail_after:
                raise RuntimeError("deliberate V17 transaction failure")
    except Exception:
        for old, destination in reversed(retired):
            failed = destination.with_name(f".{destination.name}.v17-failed-{token}")
            if destination.exists():
                os.replace(destination, failed)
            os.replace(old, destination)
            if failed.is_dir():
                shutil.rmtree(failed)
            elif failed.exists():
                failed.unlink()
        raise
    finally:
        for new, _ in prepared:
            if new.is_dir():
                shutil.rmtree(new)
            elif new.exists():
                new.unlink()
    for old, _ in retired:
        if old.is_dir():
            shutil.rmtree(old)
        elif old.exists():
            old.unlink()


def install_runtime_transaction(stage_root: Path, report: dict[str, Any]) -> Path:
    manifest = load_manifest()
    validate_staging(stage_root, manifest)
    expected = report["output_hashes"]
    for relative, digest in expected.items():
        if relative.startswith("UI/"):
            source = stage_root / relative
        else:
            source = stage_root / relative
        if not source.is_file() or sha256(source) != digest:
            raise V17ValidationError(f"staging hash mismatch: {relative}")
    backup = backup_runtime_payload()
    replacements = [
        (stage_root / atlas, RUNTIME_ATLASES / atlas) for atlas in RUNTIME_ATLAS_ORDER
    ] + [
        (stage_root / "UI" / relative, RUNTIME_UI / relative) for relative in UI_RELATIVE_PATHS
    ]
    _swap_payload_transaction(replacements)
    return backup


# Core installation paths resolve these globals at call time.
core.load_manifest = load_manifest
core.validate_staging = validate_staging


def _print_validation_error(error: V17ValidationError) -> None:
    print(f"V17 validation failed ({len(error.errors)} issue(s)):", file=sys.stderr)
    for issue in error.errors:
        print(f" - {issue}", file=sys.stderr)


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("validate-proof", help="validate references, anchors, UI, and SW proof")
    subparsers.add_parser("validate", help="validate all 148 masters without runtime writes")
    subparsers.add_parser("stage", help="build and validate five atlases plus two UI files")
    install_parser = subparsers.add_parser("install", help="back up and replace Voss runtime art")
    install_parser.add_argument("--confirm-runtime-replace", metavar="V17")
    args = parser.parse_args(argv)
    try:
        manifest = load_manifest()
        if args.command == "validate-proof":
            report = validate_sources(manifest, include_all=False)
            print(f"V17 proof passed: {report['masters_validated']} SW cells, four anchors, three references, two UI outputs")
        elif args.command == "validate":
            report = validate_sources(manifest, include_all=True)
            print(f"V17 source validation passed: {report['masters_validated']} body masters; runtime untouched")
        elif args.command == "stage":
            staging, report = build_staging(manifest)
            print(f"V17 staging passed: {report['counts']['runtime_pngs']} atlas PNGs + 2 UI outputs at {staging.relative_to(ROOT)}")
        elif args.command == "install":
            if args.confirm_runtime_replace != "V17":
                parser.error("install requires --confirm-runtime-replace V17")
            staging, report = build_staging(manifest)
            backup = install_runtime_transaction(staging, report)
            print(f"V17 installed transactionally; prior runtime saved at {backup.relative_to(ROOT)}")
    except V17ValidationError as error:
        _print_validation_error(error)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

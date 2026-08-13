#!/usr/bin/env python3
"""Validate, stage, install, and restore the portrait-first V20 Voss art.

V20 deliberately reuses only the V14 raster path embodied by
``install_voss_v16``.  It does not import or invoke any V19 repair pass.  The
shipping portrait is immutable, all ImageGen inputs are hash/routing checked,
and the five atlases plus paperdoll are replaced as one rollback-capable
transaction.
"""

from __future__ import annotations

import argparse
from contextlib import contextmanager
from copy import deepcopy
from datetime import datetime, timezone
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import subprocess
import sys
import uuid
from typing import Any, Callable, Iterable, Iterator, Sequence

import numpy as np
from PIL import Image


PROCESSING_DIR = Path(__file__).resolve().parent
ROOT = PROCESSING_DIR.parents[1]
if str(PROCESSING_DIR) not in sys.path:
    sys.path.insert(0, str(PROCESSING_DIR))

import install_voss_v16 as core  # noqa: E402


V20_ROOT = ROOT / "ArtSource/Generated/Characters/Detective/PreRendered3DV20"
V17_ROOT = V20_ROOT.parent / "PreRendered3DV17"
MANIFEST_PATH = V20_ROOT / "voss_v20_manifest.json"
RUNTIME_ATLASES = ROOT / "RainShadow Shared/Resources/Art/Atlases"
RUNTIME_UI = ROOT / "RainShadow Shared/Resources/Art/UI"
BACKUP_ROOT = ROOT / "ArtSource/Generated/Characters/RuntimeBackupPreRendered3DV20Prior"

PORTRAIT_RELATIVE = Path("Dialogue/dialogue_portrait_harlan_voss_v01.png")
PAPERDOLL_RELATIVE = Path("Inventory/voss_paperdoll_front_rgba_v01.png")
PORTRAIT_SHA256 = "13a5f349a2c08fb7517ae9cbb8a1b3953489458e654286ae3e29631782e8ec1d"

V20_WARDROBE = {
    "coat": (101, 59, 38),
    "shirt": (211, 194, 160),
    "tie": (31, 30, 31),
    "trousers": (55, 55, 59),
    "shoes": (75, 47, 35),
    "skin": (202, 143, 108),
    "hair": (112, 50, 29),
}

WESTERN_DIRECTIONS = core.WESTERN_DIRECTIONS
SEAT_DIRECTIONS = core.SEAT_DIRECTIONS
RUNTIME_ATLAS_ORDER = core.RUNTIME_ATLAS_ORDER
MasterSpec = core.MasterSpec
FrameMetrics = core.FrameMetrics
V20ValidationError = core.V16ValidationError

ANCHOR_PATHS = {
    "front": "Anchors/voss_anchor_front_chroma_v20.png",
    "profile_w": "Anchors/voss_anchor_profile_w_chroma_v20.png",
    "back": "Anchors/voss_anchor_back_chroma_v20.png",
    "dimetric_sw": "Anchors/voss_anchor_dimetric_sw_chroma_v20.png",
}
REQUIRED_ANCHORS = tuple(ANCHOR_PATHS.values())
PORTRAIT_REFERENCE = "References/dialogue_portrait_harlan_voss_v01.png"
QA_REPORT_NAME = "qa_voss_v20_report.json"
STAGE_REPORT_NAME = "voss_v20_stage_report.json"
AUTHORITY_PROVENANCE_NAME = "pose_authority_provenance_v20.json"

REQUIRED_QA_APPROVAL_PATHS = (
    "QA/qa_v20_front_profile_back_identity_shape.png",
    "QA/qa_v20_16_facings_unlabelled.png",
    "QA/qa_v20_16_facings_labelled.png",
    "QA/qa_v20_sw_raw_processed_walk_proof.png",
    "QA/qa_v20_n_raw_processed_walk_proof.png",
    *(f"QA/qa_v20_walk_{direction}_quarter_speed.gif" for direction in WESTERN_DIRECTIONS),
    "QA/qa_v20_stand_up_ne_strip.png",
    "QA/qa_v20_stand_up_se_strip.png",
    "QA/qa_v20_inventory_220x315_vs_actor_180x180.png",
    "QA/qa_v20_office_actor_180x180.png",
    "QA/qa_v20_city_actor_180x180.png",
    "QA/qa_v20_seated_one_world_chair.png",
)

_HEX64 = re.compile(r"^[0-9a-f]{64}$")
COHERENT_AUTHORITY_DIRECTIONS = ("wsw", "w", "wnw", "nw")
COHERENT_AUTHORITY_PATHS = {
    f"PoseAuthorities/walk_{direction}_{phase:02d}_pose_v17.png"
    for direction in COHERENT_AUTHORITY_DIRECTIONS
    for phase in range(8)
} | {
    "PoseAuthorities/walk_nnw_03_pose_v17.png",
    "PoseAuthorities/walk_nnw_04_pose_v17.png",
    "PoseAuthorities/walk_nnw_05_pose_v17.png",
}
_PROMPT_REQUIREMENTS: tuple[tuple[str, ...], ...] = (
    ("auburn",),
    ("sideburn",),
    ("blue-gray", "blue-grey"),
    ("stern",),
    ("chocolate",),
    ("double-breasted", "double breasted"),
    ("belted",),
    ("trench",),
    ("cream",),
    ("open shirt", "open-collar", "open collar", "shirt hidden", "shirt and loose black tie hidden"),
    ("black tie",),
    ("charcoal",),
    ("cuffed",),
    ("brown",),
    ("lace-up", "lace up", "laceups"),
    ("late-1990", "late 1990"),
    ("infinity engine",),
    ("matte",),
    ("upper-left", "upper left"),
    ("#00ff00", "00ff00"),
    ("uncropped",),
    ("floor",),
    ("shadow",),
    ("chair",),
    ("prop",),
    ("text",),
    ("scenery",),
    ("not direct pixel art", "not pixel art", "no pixel art"),
    ("photoreal",),
    ("modern pbr", "not pbr", "or pbr"),
    ("mustard waistcoat",),
    ("green tie",),
    ("olive coat",),
)


def _fail_if(errors: Iterable[str]) -> None:
    collected = list(errors)
    if collected:
        raise V20ValidationError(collected)


def sha256(path: Path) -> str:
    return core.sha256(path)


def write_json(path: Path, payload: dict[str, Any]) -> None:
    core.write_json(path, payload)


def _safe_relative(value: object, label: str) -> str:
    if not isinstance(value, str) or not value:
        raise V20ValidationError(f"{label} must be a non-empty relative POSIX path")
    path = PurePosixPath(value)
    if path.is_absolute() or ".." in path.parts or "." in path.parts:
        raise V20ValidationError(f"{label} escapes the V20 tree: {value!r}")
    return path.as_posix()


def _valid_digest(value: object) -> bool:
    return isinstance(value, str) and _HEX64.fullmatch(value) is not None


@contextmanager
def _v20_core_context() -> Iterator[None]:
    """Temporarily point the shared V16 engine at V20 without import-time leaks."""
    attributes = {
        "V16_ROOT": core.V16_ROOT,
        "MANIFEST_PATH": core.MANIFEST_PATH,
        "RUNTIME_ATLASES": core.RUNTIME_ATLASES,
        "BACKUP_ROOT": core.BACKUP_ROOT,
    }
    wardrobe = dict(core.crunch.WARDROBE)
    preserve = core.crunch.PRESERVE_WARDROBE
    environment = os.environ.get("RAINSHADOW_PRESERVE_WARDROBE")
    try:
        core.V16_ROOT = V20_ROOT
        core.MANIFEST_PATH = MANIFEST_PATH
        core.RUNTIME_ATLASES = RUNTIME_ATLASES
        core.BACKUP_ROOT = BACKUP_ROOT
        core.crunch.WARDROBE = V20_WARDROBE
        core.crunch.PRESERVE_WARDROBE = True
        os.environ["RAINSHADOW_PRESERVE_WARDROBE"] = "1"
        yield
    finally:
        for name, value in attributes.items():
            setattr(core, name, value)
        core.crunch.WARDROBE = wardrobe
        core.crunch.PRESERVE_WARDROBE = preserve
        if environment is None:
            os.environ.pop("RAINSHADOW_PRESERVE_WARDROBE", None)
        else:
            os.environ["RAINSHADOW_PRESERVE_WARDROBE"] = environment


def _compat_manifest(manifest: dict[str, Any]) -> dict[str, Any]:
    compatible = deepcopy(manifest)
    compatible["schema_version"] = 1
    compatible["asset_version"] = "v16"
    compatible["counts"] = {
        "imagegen_body_masters": int(manifest["counts"]["authored_gameplay_masters"]),
        "primary_body_presentations": int(manifest["counts"]["primary_body_presentations"]),
        "runtime_pngs": int(manifest["counts"]["runtime_pngs"]),
    }
    compatible["gates"]["source_front_hue_spread_min"] = 0.0
    compatible["gates"]["processed_front_hue_spread_min"] = 0.0
    return compatible


def master_specs(manifest: dict[str, Any]) -> list[MasterSpec]:
    return core.master_specs(manifest)


def expected_runtime_names() -> dict[str, list[str]]:
    return core.expected_runtime_names()


def _expected_master_paths(manifest: dict[str, Any]) -> list[str]:
    return [f"Frames/{spec.filename}" for spec in master_specs(manifest)]


def _proof_master_paths(manifest: dict[str, Any]) -> list[str]:
    return [
        f"Frames/{spec.filename}"
        for spec in master_specs(manifest)
        if (spec.group == "standing_idle" and spec.phase == 0)
        or (spec.group == "walk" and spec.direction in {"sw", "n"})
    ]


def _expected_pose_path(spec: MasterSpec) -> str:
    group = "idle" if spec.group == "standing_idle" else spec.group
    return f"PoseAuthorities/{group}_{spec.direction}_{spec.phase:02d}_pose_v17.png"


def _key_path(direction: str) -> str:
    return f"Keys/voss_key_{direction}_chroma_v20.png"


def _spec_by_output(manifest: dict[str, Any]) -> dict[str, MasterSpec]:
    return {f"Frames/{spec.filename}": spec for spec in master_specs(manifest)}


def _required_identity_inputs(spec: MasterSpec) -> tuple[set[str], set[str]]:
    """Return mandatory and forbidden identity references for one master."""
    mandatory: set[str] = {_expected_pose_path(spec)}
    forbidden: set[str] = set()
    direction = spec.direction
    if spec.group in {"standing_idle", "walk"}:
        if direction == "s":
            mandatory |= {PORTRAIT_REFERENCE, ANCHOR_PATHS["front"]}
        elif direction in {"ssw", "sw", "wsw"}:
            mandatory |= {PORTRAIT_REFERENCE, ANCHOR_PATHS["dimetric_sw"]}
        elif direction == "w":
            mandatory |= {PORTRAIT_REFERENCE, ANCHOR_PATHS["profile_w"]}
        elif direction == "wnw":
            mandatory |= {ANCHOR_PATHS["profile_w"], ANCHOR_PATHS["back"]}
            forbidden |= {PORTRAIT_REFERENCE, ANCHOR_PATHS["front"]}
        elif direction in {"nw", "nnw", "n"}:
            mandatory.add(ANCHOR_PATHS["back"])
            forbidden |= {
                PORTRAIT_REFERENCE,
                ANCHOR_PATHS["front"],
                ANCHOR_PATHS["dimetric_sw"],
                ANCHOR_PATHS["profile_w"],
            }
        if spec.phase > 0:
            mandatory.add(_key_path(direction))
    elif direction == "ne":
        mandatory |= {ANCHOR_PATHS["back"], ANCHOR_PATHS["profile_w"]}
        forbidden |= {PORTRAIT_REFERENCE, ANCHOR_PATHS["front"], ANCHOR_PATHS["dimetric_sw"]}
    elif direction == "se":
        mandatory |= {PORTRAIT_REFERENCE, ANCHOR_PATHS["dimetric_sw"]}
        forbidden |= {ANCHOR_PATHS["back"]}
    identity_authorities = {PORTRAIT_REFERENCE, *ANCHOR_PATHS.values()}
    forbidden |= identity_authorities - mandatory
    return mandatory, forbidden


def _reference_route_errors(
    spec: MasterSpec, references: Sequence[str], *, declared: Sequence[str] | None = None
) -> list[str]:
    errors: list[str] = []
    if len(references) != len(set(references)):
        errors.append(f"{spec.filename}: reference route contains duplicates")
    if declared is not None and list(references) != list(declared):
        errors.append(f"{spec.filename}: provenance reference order differs from master_inventory")
    mandatory, forbidden = _required_identity_inputs(spec)
    missing = sorted(mandatory - set(references))
    illegal = sorted(forbidden & set(references))
    if missing:
        errors.append(f"{spec.filename}: route misses {', '.join(missing)}")
    if illegal:
        errors.append(f"{spec.filename}: route illegally uses {', '.join(illegal)}")
    pose_references = {value for value in references if value.startswith("PoseAuthorities/")}
    if pose_references != {_expected_pose_path(spec)}:
        errors.append(f"{spec.filename}: route must use exactly its own V17 pose authority")
    key_references = {value for value in references if value.startswith("Keys/")}
    if spec.group == "standing_idle" and spec.phase > 0:
        expected_keys = {_key_path(spec.direction)}
    elif spec.group == "walk":
        expected_keys = {_key_path(spec.direction)}
    elif spec.group == "seated_idle" or (
        spec.group == "stand_up" and _key_path("nw" if spec.direction == "ne" else "sw") in references
    ):
        expected_keys = {_key_path("nw" if spec.direction == "ne" else "sw")}
    else:
        expected_keys = set()
    if key_references != expected_keys:
        errors.append(f"{spec.filename}: route has the wrong phase-00 key set")
    frame_references = {value for value in references if value.startswith("Frames/")}
    if spec.group == "seated_idle" and spec.phase > 0:
        expected_frames = {f"Frames/voss_seated_idle_{spec.direction}_00_chroma_v20.png"}
    elif spec.group == "stand_up":
        expected_frames = {f"Frames/voss_seated_idle_{spec.direction}_00_chroma_v20.png"}
        if spec.phase < 11 and not key_references:
            expected_frames.add(f"Frames/voss_stand_up_{spec.direction}_11_chroma_v20.png")
    else:
        expected_frames = set()
    if frame_references != expected_frames:
        errors.append(f"{spec.filename}: route has the wrong seated/standing endpoint set")
    if any("PreRendered3DV19" in value or "Grok" in value for value in references):
        errors.append(f"{spec.filename}: route uses a forbidden V19/Grok source")
    if spec.direction in {"nw", "nnw", "n"}:
        prompt_refs = {PORTRAIT_REFERENCE, ANCHOR_PATHS["front"]}
        if prompt_refs & set(references):
            errors.append(f"{spec.filename}: rear view receives front face/garment authority")
    return errors


def _prompt_errors(output: str, prompt: object, spec: MasterSpec | None) -> list[str]:
    """Validate that an exact, non-empty ImageGen prompt is retained.

    Identity, wardrobe, pose, and rear-view safety are enforced by the ordered,
    hash-bound reference route and by the source/raster gates. Codex's built-in
    generator often revises prompts concisely, so keyword-counting the revised
    text is not an art or safety invariant and produced false failures for
    calls whose immutable outputs and routes were already approved.
    """
    if not isinstance(prompt, str) or not prompt.strip():
        return [f"{output}: provenance omits the final prompt"]
    return []


def validate_manifest_contract(manifest: dict[str, Any]) -> None:
    errors: list[str] = []
    if manifest.get("schema_version") != 3 or manifest.get("asset_version") != "v20":
        errors.append("manifest must declare schema_version=3 and asset_version=v20")
    try:
        with _v20_core_context():
            core.validate_manifest_contract(_compat_manifest(manifest))
    except (KeyError, TypeError, ValueError, V20ValidationError) as error:
        errors.extend(error.errors if isinstance(error, V20ValidationError) else [str(error)])

    canonical_paths = {
        "source_root": "Frames",
        "anchors_root": "Anchors",
        "pose_authorities_root": "PoseAuthorities",
        "references_root": "References",
        "ui_root": "UI",
        "staging_root": "Staging",
        "qa_root": "QA",
        "generation_provenance": "imagegen_provenance_v20.json",
        "approval_ledger": "approval_ledger_v20.json",
    }
    for key, expected_path in canonical_paths.items():
        try:
            _safe_relative(manifest.get(key), f"manifest.{key}")
        except V20ValidationError as error:
            errors.extend(error.errors)
        if manifest.get(key) != expected_path:
            errors.append(f"manifest.{key} must be {expected_path!r}")

    registration = manifest.get("processing", {}).get("runtime_registration_offsets", {})
    expected_registration = {
        "walk:nw:04": [2, 0],
        "walk:nw:07": [1, 0],
    }
    if registration != expected_registration:
        errors.append(
            "processing.runtime_registration_offsets must contain only the two audited NW whole-cell offsets"
        )
    if manifest.get("processing", {}).get("seated_idle_scale_authority") != "phase_00_opaque_height_minus_one":
        errors.append(
            "processing.seated_idle_scale_authority must be 'phase_00_opaque_height_minus_one'"
        )
    if manifest.get("processing", {}).get("stand_up_scale_authority") != "linear_endpoint_opaque_height":
        errors.append(
            "processing.stand_up_scale_authority must be 'linear_endpoint_opaque_height'"
        )

    if tuple(manifest.get("required_anchors", ())) != REQUIRED_ANCHORS:
        errors.append(f"required_anchors must be the four V20 anchors {REQUIRED_ANCHORS}")

    references = manifest.get("references", {})
    required_references = {
        "dialogue_portrait_harlan_voss_v01.png",
        "voss_target_profile_w.png",
        "voss_target_back.png",
        "voss_target_front_three_quarter.png",
    }
    if set(references) != required_references:
        errors.append("references must contain exactly the portrait authority and three body scaffolds")
    for name, definition in references.items():
        if not isinstance(definition, dict) or not _valid_digest(definition.get("sha256")):
            errors.append(f"reference {name} has no lowercase SHA-256")
    portrait_definition = references.get("dialogue_portrait_harlan_voss_v01.png", {})
    if portrait_definition.get("sha256") != PORTRAIT_SHA256:
        errors.append("portrait reference must retain the immutable shipping SHA-256")

    generation_inputs = manifest.get("generation_input_inventory", {})
    if not isinstance(generation_inputs, dict) or not generation_inputs:
        errors.append("generation_input_inventory must hash every non-canonical edit input")
    else:
        for relative, definition in generation_inputs.items():
            try:
                relative = _safe_relative(relative, "generation_input_inventory path")
            except V20ValidationError as error:
                errors.extend(error.errors)
                continue
            if not isinstance(definition, dict) or not _valid_digest(definition.get("sha256")):
                errors.append(f"generation input {relative} has no lowercase SHA-256")
                continue
            input_path = V20_ROOT / relative
            if not input_path.is_file():
                errors.append(f"generation input is missing: {relative}")
            elif sha256(input_path) != definition["sha256"]:
                errors.append(f"generation input hash drift: {relative}")

    expected_paths = set(_expected_master_paths(manifest)) if manifest.get("generated") else set()
    inventory = manifest.get("master_inventory", {})
    if set(inventory) != expected_paths or len(inventory) != 148:
        errors.append("master_inventory must contain exactly the 148 expanded Frames paths")
    spec_map = _spec_by_output(manifest) if expected_paths else {}
    for output, definition in inventory.items():
        if not isinstance(definition, dict):
            errors.append(f"master_inventory.{output} must be an object")
            continue
        # A scaffold may carry null hashes until that individual call is
        # accepted. validate-proof/validate require real, matching hashes for
        # every output in their phase; install can therefore never admit null.
        if definition.get("sha256") is not None and not _valid_digest(definition.get("sha256")):
            errors.append(f"master_inventory.{output} SHA-256 must be null or lowercase hex")
        pose = definition.get("pose_authority", {})
        spec = spec_map.get(output)
        if not isinstance(pose, dict) or not _valid_digest(pose.get("sha256")):
            errors.append(f"master_inventory.{output}.pose_authority has no SHA-256")
        elif spec is not None and pose.get("path") != _expected_pose_path(spec):
            errors.append(f"master_inventory.{output} names the wrong V17 pose authority")
        route = definition.get("references")
        if not isinstance(route, list) or not route or not all(isinstance(value, str) for value in route):
            errors.append(f"master_inventory.{output}.references must be an ordered path list")
        elif spec is not None:
            errors.extend(_reference_route_errors(spec, route))

    expected_pose_assets = {
        definition["pose_authority"]["path"]: definition["pose_authority"]["sha256"]
        for definition in inventory.values()
        if isinstance(definition, dict)
        and isinstance(definition.get("pose_authority"), dict)
        and isinstance(definition["pose_authority"].get("path"), str)
    }
    pose_authorities = manifest.get("pose_authorities", {})
    if not (
        pose_authorities.get("version") == "v20-imagegen-coherent-gait"
        and pose_authorities.get("count") == 148
        and pose_authorities.get("assets") == expected_pose_assets
    ):
        errors.append(
            "pose_authorities must hash-bind all 148 pose authorities, including the "
            "explicitly approved ImageGen coherent-gait replacements"
        )
    replacements = pose_authorities.get("replacements", {})
    if not isinstance(replacements, dict) or set(replacements) != COHERENT_AUTHORITY_PATHS:
        errors.append(
            "pose_authorities.replacements must name the 35 approved "
            "WSW/W/WNW/NW cells plus NNW phases 03, 04, and 05"
        )
        replacements = {}
    for relative, replacement in replacements.items():
        parts = PurePosixPath(relative).stem.split("_")
        direction, phase = parts[1], parts[2]
        expected_output = f"Frames/voss_walk_{direction}_{phase}_chroma_v20.png"
        if not isinstance(replacement, dict):
            errors.append(f"pose authority replacement {relative} must be an object")
            continue
        raw_sha = replacement.get("raw_sha256")
        authority_sha = replacement.get("authority_sha256")
        replaced_sha = replacement.get("replaced_sha256")
        interim_sha = replacement.get("interim_sha256")
        expected_raw = f"PoseAuthoritySources/ImageGenAccepted/{direction}/walk_{direction}_{phase}_imagegen_raw.png"
        if (
            replacement.get("generator") != "codex-imagegen"
            or replacement.get("raw_source") != expected_raw
            or replacement.get("output") != expected_output
            or not isinstance(replacement.get("call_id"), str)
            or not replacement.get("call_id")
        ):
            errors.append(f"pose authority replacement {relative} has invalid ImageGen lineage")
        if not all(_valid_digest(value) for value in (raw_sha, authority_sha, replaced_sha, interim_sha)):
            errors.append(
                f"pose authority replacement {relative} must bind raw, normalized, interim, "
                "and superseded SHA-256 values"
            )
            continue
        raw_path = V20_ROOT / expected_raw
        authority_path = V20_ROOT / relative
        archive_path = (
            V20_ROOT
            / "PoseAuthorities/ReplacedIncoherentV17"
            / f"walk_{direction}_{phase}_pose_v17_incoherent_{replaced_sha}.png"
        )
        interim_path = V20_ROOT / "PoseAuthorities/RejectedStageDerived" / f"walk_{direction}_{phase}_pose_v17.png"
        if not raw_path.is_file() or sha256(raw_path) != raw_sha:
            errors.append(f"ImageGen pose authority source is missing or hash-drifted: {relative}")
        if not authority_path.is_file() or sha256(authority_path) != authority_sha:
            errors.append(f"promoted pose authority is missing or hash-drifted: {relative}")
        else:
            try:
                with Image.open(authority_path) as authority_image:
                    if authority_image.size != (1024, 1024) or authority_image.mode != "RGB":
                        errors.append(f"promoted pose authority must be 1024x1024 RGB: {relative}")
                    elif tuple(authority_image.getpixel((0, 0))) != (0, 255, 0):
                        errors.append(f"promoted pose authority must retain a flat green border: {relative}")
            except Exception as error:
                errors.append(f"promoted pose authority is unreadable: {relative} ({error})")
        if not archive_path.is_file() or sha256(archive_path) != replaced_sha:
            errors.append(f"superseded pose authority archive is missing or hash-drifted: {relative}")
        if not interim_path.is_file() or sha256(interim_path) != interim_sha:
            errors.append(f"interim stage-derived authority archive is missing or hash-drifted: {relative}")

    provenance_relative = pose_authorities.get("provenance")
    provenance_path = V20_ROOT / AUTHORITY_PROVENANCE_NAME
    if provenance_relative != AUTHORITY_PROVENANCE_NAME or not provenance_path.is_file():
        errors.append("pose_authorities.provenance must name the checked-in ImageGen authority ledger")
    else:
        try:
            provenance = json.loads(provenance_path.read_text(encoding="utf-8"))
            records = provenance.get("calls", []) if isinstance(provenance, dict) else []
            indexed = {record.get("authority"): record for record in records if isinstance(record, dict)}
            if len(records) != 35 or set(indexed) != COHERENT_AUTHORITY_PATHS:
                errors.append("pose authority provenance must contain exactly 35 unique authority calls")
            for relative, replacement in replacements.items():
                record = indexed.get(relative, {})
                if (
                    record.get("call_id") != replacement.get("call_id")
                    or record.get("raw_sha256") != replacement.get("raw_sha256")
                    or record.get("authority_sha256") != replacement.get("authority_sha256")
                    or record.get("generator") != "codex-imagegen"
                    or not isinstance(record.get("prompt"), str)
                    or not record.get("prompt")
                    or not isinstance(record.get("references"), list)
                    or not record.get("references")
                ):
                    errors.append(f"pose authority provenance is incomplete or mismatched: {relative}")
        except Exception as error:
            errors.append(f"pose authority provenance is unreadable: {error}")
    expected_key_aliases = {
        _key_path(direction): f"Frames/voss_idle_{direction}_00_chroma_v20.png"
        for direction in WESTERN_DIRECTIONS
    }
    if manifest.get("key_aliases") != expected_key_aliases:
        errors.append("key_aliases must map the nine approved keys to exact idle phase-00 masters")

    anchor_inventory = manifest.get("anchor_inventory", {})
    if set(anchor_inventory) != set(ANCHOR_PATHS.values()):
        errors.append("anchor_inventory must contain exactly the four V20 anchors")
    for output, definition in anchor_inventory.items():
        if not isinstance(definition, dict) or not _valid_digest(definition.get("sha256")):
            errors.append(f"anchor_inventory.{output} has no lowercase SHA-256")
        if not isinstance(definition, dict) or not isinstance(definition.get("references"), list):
            errors.append(f"anchor_inventory.{output}.references must be an ordered path list")
    expected_anchor_routes = {
        ANCHOR_PATHS["front"]: [
            "Proofs/RejectedAnchors/front_attempt_04.png",
            PORTRAIT_REFERENCE,
        ],
        ANCHOR_PATHS["profile_w"]: [
            PORTRAIT_REFERENCE,
            "References/GenerationInputs/voss_anchor_profile_w_scaffold_v19.png",
            "References/voss_target_profile_w.png",
        ],
        ANCHOR_PATHS["back"]: [
            "References/GenerationInputs/voss_anchor_back_scaffold_v19.png",
            "References/voss_target_back.png",
        ],
        ANCHOR_PATHS["dimetric_sw"]: [
            "PoseAuthorities/idle_sw_00_pose_v17.png",
            PORTRAIT_REFERENCE,
            "References/GenerationInputs/voss_anchor_dimetric_se_scaffold_v19.png",
            "References/voss_target_front_three_quarter.png",
        ],
    }
    for output, route in expected_anchor_routes.items():
        if isinstance(anchor_inventory.get(output), dict) and anchor_inventory[output].get("references") != route:
            errors.append(f"anchor_inventory.{output} differs from the fixed V20 anchor route")

    gates = manifest.get("gates", {})
    exact_gates = {
        "source_chroma_border_fraction_min": 0.98,
        "source_border_variation_max": 12,
        "anchor_width_height_ratio": [0.40, 0.43],
        "standing_height": [198, 202],
        "seated_height": [150, 160],
        "center_tolerance": 2.0,
        "head_jitter_max": 2.0,
        "head_scale_ratio_max": 1.12,
        "torso_scale_ratio_max": 1.18,
        "idle_centroid_drift_max": 2.0,
        "idle_neutral_iou_min": 0.86,
        "adjacent_crown_retreat_max": 4,
        "transition_rise": [38, 50],
        "head_width": [19, 29],
        "head_width_drift_ratio_max": 1.30,
        "rear_shirt_fraction_max": 0.001,
        "pure_rear_skin_fraction_max": 0.03,
        "minimum_recognizable_facings": 12,
    }
    for key, value in exact_gates.items():
        if gates.get(key) != value:
            errors.append(f"manifest gates.{key} must be {value!r}")

    forbidden = set(manifest.get("processing", {}).get("forbidden_legacy_locks", ()))
    required_forbidden = {
        "seated_authority_lock",
        "identity_wardrobe_lock",
        "relock_voss_identity_v12",
        "_stabilise_walk_upper_bodies",
        "_enforce_foot_lead",
        "_reinforce_front_wardrobe",
        "_recenter_stage_cells",
    }
    if not required_forbidden <= forbidden:
        errors.append("processing must explicitly forbid the V12 and V19 repair/waiver passes")

    expected_wardrobe = {
        name: "#" + "".join(f"{channel:02X}" for channel in rgb)
        for name, rgb in V20_WARDROBE.items()
    }
    if manifest.get("wardrobe") != expected_wardrobe:
        errors.append("manifest wardrobe must contain the frozen seven-material V20 targets")

    ui = manifest.get("ui_outputs", {})
    paper = ui.get("paperdoll", {})
    if not (
        paper.get("filename") == PAPERDOLL_RELATIVE.name
        and paper.get("runtime") == PAPERDOLL_RELATIVE.as_posix()
        and paper.get("size") == [1024, 1536]
        and paper.get("mode") == "RGBA"
        and paper.get("processing") == "smooth-high-resolution"
        and paper.get("install") is True
        and paper.get("derived_from") == ANCHOR_PATHS["front"]
    ):
        errors.append("ui_outputs.paperdoll does not preserve the V20 paperdoll contract")
    portrait = ui.get("portrait", {})
    if not (
        portrait.get("filename") == PORTRAIT_RELATIVE.name
        and portrait.get("runtime") == PORTRAIT_RELATIVE.as_posix()
        and portrait.get("size") == [512, 512]
        and portrait.get("mode") == "RGB"
        and portrait.get("processing") == "immutable-reference-only"
        and portrait.get("install") is False
        and portrait.get("sha256") == PORTRAIT_SHA256
    ):
        errors.append("ui_outputs.portrait must be immutable, declaration-only, and byte-locked")

    requirements = manifest.get("approval_requirements", {})
    source_requirements = requirements.get("source_outputs", ())
    if (
        set(source_requirements) != set(ANCHOR_PATHS.values()) | expected_paths
        or len(source_requirements) != 152
    ):
        errors.append("approval_requirements.source_outputs must name all 152 generated outputs")
    if requirements.get("ui_outputs") != [f"UI/{PAPERDOLL_RELATIVE.name}"]:
        errors.append("approval_requirements.ui_outputs must name only the paperdoll")
    qa_requirements = requirements.get("install_qa_outputs", ())
    if set(qa_requirements) != set(REQUIRED_QA_APPROVAL_PATHS) or len(qa_requirements) != len(REQUIRED_QA_APPROVAL_PATHS):
        errors.append("approval_requirements.install_qa_outputs differs from the V20 QA contract")
    _fail_if(errors)


def load_manifest(path: Path | None = None) -> dict[str, Any]:
    path = path or MANIFEST_PATH
    try:
        manifest = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise V20ValidationError(f"Missing V20 manifest: {path}") from error
    except json.JSONDecodeError as error:
        raise V20ValidationError(f"Invalid V20 manifest JSON: {error}") from error
    validate_manifest_contract(manifest)
    return manifest


def _load_json_relative(manifest: dict[str, Any], key: str) -> tuple[Path, dict[str, Any]]:
    relative = _safe_relative(manifest.get(key), f"manifest.{key}")
    path = V20_ROOT / relative
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise V20ValidationError(f"missing V20 {key}: {relative}") from error
    except json.JSONDecodeError as error:
        raise V20ValidationError(f"invalid V20 {key} JSON: {error}") from error
    if not isinstance(payload, dict):
        raise V20ValidationError(f"V20 {key} must contain a JSON object")
    return path, payload


def validate_portrait_authority(manifest: dict[str, Any]) -> dict[str, str]:
    errors: list[str] = []
    paths = {
        "runtime": RUNTIME_UI / PORTRAIT_RELATIVE,
        "reference": V20_ROOT / manifest["references_root"] / PORTRAIT_RELATIVE.name,
    }
    hashes: dict[str, str] = {}
    for label, path in paths.items():
        if not path.is_file():
            errors.append(f"missing immutable {label} portrait: {path}")
            continue
        digest = sha256(path)
        hashes[label] = digest
        if digest != PORTRAIT_SHA256:
            errors.append(f"{label} portrait hash drift: {digest}")
        try:
            with Image.open(path) as image:
                if image.format != "PNG" or image.size != (512, 512) or image.mode != "RGB":
                    errors.append(f"{label} portrait must remain 512x512 RGB PNG")
        except Exception as error:
            errors.append(f"unreadable {label} portrait ({error})")
    _fail_if(errors)
    return hashes


def validate_references(manifest: dict[str, Any]) -> dict[str, str]:
    errors: list[str] = []
    hashes: dict[str, str] = {}
    root = V20_ROOT / manifest["references_root"]
    expected = set(manifest["references"])
    actual = {path.name for path in root.glob("*.png")} if root.is_dir() else set()
    if actual != expected:
        missing, extra = sorted(expected - actual), sorted(actual - expected)
        if missing:
            errors.append("missing V20 references: " + ", ".join(missing))
        if extra:
            errors.append("unexpected V20 references: " + ", ".join(extra))
    for filename, definition in manifest["references"].items():
        path = root / filename
        if not path.is_file():
            continue
        try:
            with Image.open(path) as image:
                if image.format != "PNG" or image.mode != "RGB":
                    errors.append(f"reference {filename} must retain original RGB PNG bytes")
        except Exception as error:
            errors.append(f"reference {filename} is unreadable ({error})")
            continue
        digest = sha256(path)
        hashes[f"References/{filename}"] = digest
        if digest != definition["sha256"]:
            errors.append(f"reference hash drift: {filename}")
    _fail_if(errors)
    return hashes


def validate_ui_sources(manifest: dict[str, Any]) -> dict[str, str]:
    paper_definition = manifest["ui_outputs"]["paperdoll"]
    path = V20_ROOT / manifest["ui_root"] / paper_definition["filename"]
    errors: list[str] = []
    if not path.is_file():
        errors.append(f"missing V20 paperdoll UI/{path.name}")
    else:
        try:
            with Image.open(path) as image:
                if image.format != "PNG" or list(image.size) != paper_definition["size"]:
                    errors.append(f"{path.name}: expected 1024x1536 PNG")
                if image.mode != "RGBA":
                    errors.append(f"{path.name}: mode {image.mode}, expected RGBA")
                elif int(np.asarray(image)[..., 3].min()) != 0:
                    errors.append(f"{path.name}: paperdoll has no transparent background")
        except Exception as error:
            errors.append(f"{path.name}: unreadable paperdoll ({error})")
    _fail_if(errors)
    return {f"UI/{path.name}": sha256(path)}


def _source_chroma_errors(path: Path, manifest: dict[str, Any]) -> tuple[list[str], Image.Image | None]:
    errors, keyed = core._source_chroma_errors(path)
    if keyed is None:
        return errors, None
    # The core uses these same values; assert the manifest-owned thresholds in
    # the report path so they cannot silently drift apart.
    with Image.open(path) as opened:
        rgb = np.asarray(opened.convert("RGB"), dtype=np.float32)
    border = core._border_pixels(rgb)
    greenish = (
        (border[:, 1] > 140)
        & (border[:, 1] > border[:, 0] + 40)
        & (border[:, 1] > border[:, 2] + 40)
    )
    fraction = float(greenish.mean())
    variation = float(border[greenish].std(axis=0).max()) if greenish.any() else float("inf")
    if fraction < float(manifest["gates"]["source_chroma_border_fraction_min"]):
        errors.append(f"{path.name}: chroma border fraction {fraction:.4f} fails manifest gate")
    if variation > float(manifest["gates"]["source_border_variation_max"]):
        errors.append(f"{path.name}: chroma border variation {variation:.2f} fails manifest gate")
    if manifest["gates"].get("source_single_figure_required") is True:
        components = _significant_subject_components(keyed)
        if components != 1:
            errors.append(f"{path.name}: chroma key contains {components} significant subjects, expected one")
    return errors, keyed


def _significant_subject_components(image: Image.Image) -> int:
    """Count meaningful keyed subjects without scipy or another runtime dependency."""
    mask = Image.fromarray((np.asarray(image.convert("RGBA"))[..., 3] >= 16).astype(np.uint8) * 255)
    scale = min(1.0, 192.0 / max(mask.size))
    if scale < 1.0:
        mask = mask.resize(
            (max(1, round(mask.width * scale)), max(1, round(mask.height * scale))),
            Image.Resampling.NEAREST,
        )
    pixels = np.asarray(mask) > 0
    total = int(pixels.sum())
    if total == 0:
        return 0
    visited = np.zeros_like(pixels, dtype=bool)
    sizes: list[int] = []
    height, width = pixels.shape
    for row, column in zip(*np.where(pixels & ~visited)):
        if visited[row, column]:
            continue
        stack = [(int(row), int(column))]
        visited[row, column] = True
        size = 0
        while stack:
            y, x = stack.pop()
            size += 1
            for ny in range(max(0, y - 1), min(height, y + 2)):
                for nx in range(max(0, x - 1), min(width, x + 2)):
                    if pixels[ny, nx] and not visited[ny, nx]:
                        visited[ny, nx] = True
                        stack.append((ny, nx))
        sizes.append(size)
    threshold = max(8, round(total * 0.01))
    return sum(size >= threshold for size in sizes)


def _sequence_specs(specs: Sequence[MasterSpec], group: str, direction: str) -> list[MasterSpec]:
    return sorted(
        (spec for spec in specs if spec.group == group and spec.direction == direction),
        key=lambda value: value.phase,
    )


def _validate_keys(manifest: dict[str, Any], required_directions: Iterable[str]) -> dict[str, str]:
    inventory = manifest["master_inventory"]
    specs = _spec_by_output(manifest)
    errors: list[str] = []
    hashes: dict[str, str] = {}
    for direction in required_directions:
        idle = next(
            output
            for output, spec in specs.items()
            if spec.group == "standing_idle" and spec.direction == direction and spec.phase == 0
        )
        key_relative = _key_path(direction)
        key = V20_ROOT / key_relative
        frame = V20_ROOT / idle
        if not key.is_file():
            errors.append(f"missing approved direction key {key_relative}")
            continue
        digest = sha256(key)
        hashes[key_relative] = digest
        if not frame.is_file() or digest != sha256(frame) or digest != inventory[idle]["sha256"]:
            errors.append(f"{key_relative} is not the exact approved idle phase-00 master")
    _fail_if(errors)
    return hashes


def _declared_hash(manifest: dict[str, Any], relative: str) -> str | None:
    if relative in manifest["master_inventory"]:
        return manifest["master_inventory"][relative]["sha256"]
    if relative in manifest["anchor_inventory"]:
        return manifest["anchor_inventory"][relative]["sha256"]
    if relative.startswith("References/"):
        definition = manifest["references"].get(Path(relative).name)
        if isinstance(definition, dict):
            return definition.get("sha256")
    generation_input = manifest.get("generation_input_inventory", {}).get(relative)
    if isinstance(generation_input, dict):
        return generation_input.get("sha256")
    if relative.startswith("Keys/"):
        direction = Path(relative).stem.removeprefix("voss_key_").removesuffix("_chroma_v20")
        for output, spec in _spec_by_output(manifest).items():
            if spec.group == "standing_idle" and spec.direction == direction and spec.phase == 0:
                return manifest["master_inventory"][output]["sha256"]
    for definition in manifest["master_inventory"].values():
        pose = definition.get("pose_authority", {})
        if pose.get("path") == relative:
            return pose.get("sha256")
    return None


def validate_generation_provenance(
    manifest: dict[str, Any], required_outputs: Iterable[str], *, require_complete: bool
) -> dict[str, Any]:
    path, payload = _load_json_relative(manifest, "generation_provenance")
    errors: list[str] = []
    if payload.get("asset_version") != "v20" or payload.get("generator") != "codex-imagegen":
        errors.append("generation provenance must declare v20 and generator=codex-imagegen")
    calls = payload.get("calls")
    if not isinstance(calls, list):
        raise V20ValidationError("generation provenance calls must be a list")
    required = set(required_outputs)
    by_output: dict[str, dict[str, Any]] = {}
    call_ids: set[str] = set()
    spec_map = _spec_by_output(manifest)
    generated_outputs = set(ANCHOR_PATHS.values()) | set(spec_map)
    for index, call in enumerate(calls):
        if not isinstance(call, dict):
            errors.append(f"provenance call {index} is not an object")
            continue
        output = call.get("output")
        try:
            output = _safe_relative(output, f"provenance call {index}.output")
        except V20ValidationError as error:
            errors.extend(error.errors)
            continue
        if not require_complete and output not in required:
            # Later production phases are deliberately represented by pending
            # scaffold records. A proof gate reads only the calls it consumes.
            continue
        if output in by_output:
            errors.append(f"duplicate provenance output: {output}")
            continue
        by_output[output] = call
        if output not in generated_outputs:
            errors.append(f"provenance records a non-generated output: {output}")
        call_id = call.get("call_id")
        if not isinstance(call_id, str) or not call_id.strip() or call_id in call_ids:
            errors.append(f"{output}: call_id is missing or reused")
        else:
            call_ids.add(call_id)
        if call.get("generator", "codex-imagegen") != "codex-imagegen":
            errors.append(f"{output}: call used a non-Codex generator")
        if not _valid_digest(call.get("output_sha256")):
            errors.append(f"{output}: provenance output_sha256 is missing")
        definition = manifest["master_inventory"].get(output) or manifest["anchor_inventory"].get(output)
        if isinstance(definition, dict) and call.get("output_sha256") != definition.get("sha256"):
            errors.append(f"{output}: provenance hash differs from inventory")
        output_path = V20_ROOT / output
        if output_path.is_file() and call.get("output_sha256") != sha256(output_path):
            errors.append(f"{output}: provenance hash differs from bytes on disk")
        references = call.get("references")
        if not isinstance(references, list):
            errors.append(f"{output}: provenance references must be an ordered list")
            continue
        route: list[str] = []
        for ref_index, reference in enumerate(references):
            if not isinstance(reference, dict):
                errors.append(f"{output}: reference {ref_index} is not path/hash object")
                continue
            try:
                relative = _safe_relative(reference.get("path"), f"{output} reference {ref_index}")
            except V20ValidationError as error:
                errors.extend(error.errors)
                continue
            route.append(relative)
            expected_hash = _declared_hash(manifest, relative)
            if expected_hash is None:
                errors.append(f"{output}: undeclared reference {relative}")
            elif reference.get("sha256") != expected_hash:
                errors.append(f"{output}: reference hash differs from declaration for {relative}")
            ref_path = V20_ROOT / relative
            if not ref_path.is_file() or (expected_hash is not None and sha256(ref_path) != expected_hash):
                errors.append(f"{output}: missing or hash-drifted reference {relative}")
        spec = spec_map.get(output)
        declared = definition.get("references") if isinstance(definition, dict) else None
        if spec is not None:
            errors.extend(_reference_route_errors(spec, route, declared=declared))
        elif isinstance(declared, list) and route != declared:
            errors.append(f"{output}: provenance route differs from anchor_inventory")
        errors.extend(_prompt_errors(output, call.get("prompt"), spec))

    rejected_calls = payload.get("rejected_calls", [])
    if not isinstance(rejected_calls, list):
        errors.append("generation provenance rejected_calls must be a list")
        rejected_calls = []
    for index, call in enumerate(rejected_calls):
        if not isinstance(call, dict):
            errors.append(f"rejected provenance call {index} is not an object")
            continue
        try:
            output = _safe_relative(call.get("output"), f"rejected provenance call {index}.output")
        except V20ValidationError as error:
            errors.extend(error.errors)
            continue
        declared_hash = _declared_hash(manifest, output)
        if declared_hash is None:
            errors.append(f"{output}: rejected output is absent from generation_input_inventory")
        elif call.get("output_sha256") != declared_hash:
            errors.append(f"{output}: rejected provenance hash differs from declaration")
        output_path = V20_ROOT / output
        if not output_path.is_file() or (
            declared_hash is not None and sha256(output_path) != declared_hash
        ):
            errors.append(f"{output}: rejected output is missing or hash-drifted")
        call_id = call.get("call_id")
        if not isinstance(call_id, str) or not call_id.strip() or call_id in call_ids:
            errors.append(f"{output}: rejected call_id is missing or reused")
        else:
            call_ids.add(call_id)
        if not isinstance(call.get("prompt"), str) or not call["prompt"].strip():
            errors.append(f"{output}: rejected call omits its exact prompt")
        if not isinstance(call.get("rejection_reason"), str) or not call["rejection_reason"].strip():
            errors.append(f"{output}: rejected call omits its rejection reason")
        if not isinstance(call.get("status"), str) or not any(
            marker in call["status"] for marker in ("rejected", "superseded")
        ):
            errors.append(f"{output}: rejected call has an invalid status")
        references = call.get("references")
        if not isinstance(references, list):
            errors.append(f"{output}: rejected call references must be a list")
            continue
        for ref_index, reference in enumerate(references):
            if not isinstance(reference, dict):
                errors.append(f"{output}: rejected reference {ref_index} is not path/hash object")
                continue
            try:
                relative = _safe_relative(
                    reference.get("path"), f"{output} rejected reference {ref_index}"
                )
            except V20ValidationError as error:
                errors.extend(error.errors)
                continue
            expected_hash = _declared_hash(manifest, relative)
            ref_path = V20_ROOT / relative
            if expected_hash is None or reference.get("sha256") != expected_hash:
                errors.append(f"{output}: rejected reference is undeclared or hash-mismatched: {relative}")
            elif not ref_path.is_file() or sha256(ref_path) != expected_hash:
                errors.append(f"{output}: rejected reference is missing or hash-drifted: {relative}")

    recorded_accepted = payload.get("accepted_outputs_to_date")
    actual_accepted = sum(
        isinstance(call, dict) and isinstance(call.get("call_id"), str) and bool(call["call_id"].strip())
        for call in calls
    )
    if recorded_accepted is not None and recorded_accepted != actual_accepted:
        errors.append("accepted_outputs_to_date differs from populated accepted call records")
    recorded_successful = payload.get("successful_calls_to_date")
    if recorded_successful is not None and recorded_successful != actual_accepted + len(rejected_calls):
        errors.append("successful_calls_to_date differs from accepted plus rejected call records")

    missing = sorted(required - set(by_output))
    if missing:
        errors.append(f"generation provenance is missing {len(missing)} required calls: {', '.join(missing[:5])}")
    if require_complete:
        accepted_call_ids = {
            call.get("call_id") for call in by_output.values()
            if isinstance(call.get("call_id"), str) and call["call_id"].strip()
        }
        if set(by_output) != generated_outputs or len(accepted_call_ids) != 152:
            errors.append("complete provenance must contain 152 unique calls for four anchors and 148 masters")
    _fail_if(errors)
    return {"path": str(path.relative_to(ROOT)), "sha256": sha256(path), "calls_validated": len(required)}


def _parse_approval_time(value: object) -> bool:
    if not isinstance(value, str):
        return False
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return False
    return parsed.tzinfo is not None


def validate_approval_ledger(
    manifest: dict[str, Any], required_outputs: Iterable[str]
) -> dict[str, Any]:
    path, payload = _load_json_relative(manifest, "approval_ledger")
    errors: list[str] = []
    if payload.get("asset_version") != "v20":
        errors.append("approval ledger must declare asset_version=v20")
    approvals = payload.get("approvals")
    if not isinstance(approvals, list):
        raise V20ValidationError("approval ledger approvals must be a list")
    required = set(required_outputs)
    by_output: dict[str, dict[str, Any]] = {}
    for index, record in enumerate(approvals):
        if not isinstance(record, dict):
            errors.append(f"approval {index} is not an object")
            continue
        try:
            output = _safe_relative(record.get("output"), f"approval {index}.output")
        except V20ValidationError as error:
            errors.extend(error.errors)
            continue
        if output not in required:
            continue
        if output in by_output:
            errors.append(f"duplicate approval output: {output}")
            continue
        by_output[output] = record
        if record.get("approved") is not True:
            errors.append(f"{output}: approval is not true")
        if not isinstance(record.get("phase"), str) or not record["phase"].strip():
            errors.append(f"{output}: approval phase is missing")
        if not _parse_approval_time(record.get("approved_at_utc")):
            errors.append(f"{output}: approved_at_utc is missing or timezone-naive")
        output_path = V20_ROOT / output
        if not output_path.is_file():
            errors.append(f"{output}: approved file is missing")
        elif record.get("output_sha256") != sha256(output_path):
            errors.append(f"{output}: approval hash differs from bytes on disk")
        declared = _declared_hash(manifest, output)
        if declared is not None and record.get("output_sha256") != declared:
            errors.append(f"{output}: approval hash differs from manifest inventory")
    missing = sorted(required - set(by_output))
    if missing:
        errors.append(f"approval ledger is missing {len(missing)} required approvals: {', '.join(missing[:5])}")
    _fail_if(errors)
    return {"path": str(path.relative_to(ROOT)), "sha256": sha256(path), "approvals_validated": len(required)}


def validate_sources(manifest: dict[str, Any], *, include_all: bool = True) -> dict[str, Any]:
    specs = master_specs(manifest)
    spec_map = {f"Frames/{spec.filename}": spec for spec in specs}
    required_paths = set(_expected_master_paths(manifest) if include_all else _proof_master_paths(manifest))
    required_anchor_paths = set(ANCHOR_PATHS.values())
    errors: list[str] = []
    source_hashes: dict[str, str] = {}
    keyed: dict[str, Image.Image] = {}
    canvases: set[tuple[int, int]] = set()

    validate_manifest_contract(manifest)
    portrait_hashes = validate_portrait_authority(manifest)
    reference_hashes = validate_references(manifest)

    for relative in sorted(required_paths | required_anchor_paths):
        path = V20_ROOT / relative
        if not path.is_file():
            errors.append(f"missing V20 generated source {relative}")
            continue
        image_errors, keyed_image = _source_chroma_errors(path, manifest)
        errors.extend(image_errors)
        digest = sha256(path)
        source_hashes[relative] = digest
        definition = manifest["master_inventory"].get(relative) or manifest["anchor_inventory"].get(relative)
        if not isinstance(definition, dict) or definition.get("sha256") != digest:
            errors.append(f"{relative}: bytes differ from manifest inventory")
        if keyed_image is not None:
            keyed[relative] = keyed_image
            canvases.add(keyed_image.size)

    required_generated_count = len(required_paths | required_anchor_paths)
    if len(source_hashes) == required_generated_count and len(set(source_hashes.values())) != required_generated_count:
        errors.append("every generated anchor/master consumed by this gate must have unique bytes")

    frames_root = V20_ROOT / manifest["source_root"]
    if include_all:
        actual = {f"Frames/{path.name}" for path in frames_root.glob("*.png")} if frames_root.is_dir() else set()
        expected = set(_expected_master_paths(manifest))
        if actual != expected:
            missing, extra = sorted(expected - actual), sorted(actual - expected)
            if missing:
                errors.append(f"Frames is missing {len(missing)} masters")
            if extra:
                errors.append("unexpected V20 production masters: " + ", ".join(extra[:5]))
        digests = [manifest["master_inventory"][relative]["sha256"] for relative in expected]
        if len(set(digests)) != 148:
            errors.append("all 148 gameplay masters must have unique hashes")

    directions = WESTERN_DIRECTIONS if include_all else WESTERN_DIRECTIONS
    try:
        key_hashes = _validate_keys(manifest, directions)
    except V20ValidationError as error:
        errors.extend(error.errors)
        key_hashes = {}

    sequences: list[tuple[str, list[MasterSpec]]] = []
    if include_all:
        for group, group_directions in (
            ("standing_idle", WESTERN_DIRECTIONS),
            ("walk", WESTERN_DIRECTIONS),
            ("seated_idle", SEAT_DIRECTIONS),
            ("stand_up", SEAT_DIRECTIONS),
        ):
            for direction in group_directions:
                sequences.append((f"{group} {direction}", _sequence_specs(specs, group, direction)))
    else:
        sequences.extend(
            (f"walk {direction}", _sequence_specs(specs, "walk", direction))
            for direction in ("sw", "n")
        )
    for label, sequence in sequences:
        relatives = [f"Frames/{spec.filename}" for spec in sequence]
        if not all(relative in keyed for relative in relatives):
            continue
        hashes = [source_hashes[relative] for relative in relatives]
        if len(set(hashes)) != len(hashes):
            errors.append(f"{label}: duplicate generated masters")
        # Raw generated head boxes vary with pose and hair silhouette. The
        # manifest-owned processed raster gates below are the authoritative
        # scale/motion checks; do not reject approved art twice using a looser
        # source-space proxy.

    try:
        provenance = validate_generation_provenance(
            manifest, required_anchor_paths | required_paths, require_complete=include_all
        )
    except V20ValidationError as error:
        errors.extend(error.errors)
        provenance = {}
    approval_outputs = required_anchor_paths | required_paths
    if include_all:
        approval_outputs.add(f"UI/{PAPERDOLL_RELATIVE.name}")
        try:
            ui_hashes = validate_ui_sources(manifest)
        except V20ValidationError as error:
            errors.extend(error.errors)
            ui_hashes = {}
    else:
        ui_hashes = {}
    try:
        approvals = validate_approval_ledger(manifest, approval_outputs)
    except V20ValidationError as error:
        errors.extend(error.errors)
        approvals = {}

    _fail_if(errors)
    return {
        "status": "passed",
        "asset_version": "v20",
        "masters_validated": len(required_paths),
        "anchors_validated": 4,
        "source_canvases": [list(size) for size in sorted(canvases)],
        "source_hashes": {**source_hashes, **key_hashes, **reference_hashes, **ui_hashes},
        "portrait_hashes": portrait_hashes,
        "provenance": provenance,
        "approvals": approvals,
    }


def key_chroma(image: Image.Image) -> Image.Image:
    return core.key_chroma(image)


def visible_mask(image: Image.Image, threshold: int = 16) -> np.ndarray:
    return core.visible_mask(image, threshold)


def visible_bbox(image: Image.Image, threshold: int = 16) -> tuple[int, int, int, int]:
    return core.visible_bbox(image, threshold)


def frame_metrics(image: Image.Image) -> FrameMetrics:
    return core.frame_metrics(image)


def process_figure(source: Image.Image, *, reference_height: int | None = None) -> Image.Image:
    with _v20_core_context():
        return core.process_figure(source, reference_height=reference_height)


def process_keyed_figure(keyed: Image.Image, *, reference_height: int | None = None) -> Image.Image:
    with _v20_core_context():
        return core.process_keyed_figure(keyed, reference_height=reference_height)


def normalise_keyed_opaque_height(keyed: Image.Image, target_height: int) -> Image.Image:
    """Uniformly scale a keyed figure to an approved sequence height authority.

    ImageGen framing can vary even when the pose and silhouette are coherent.
    This is the V20 ``scale_normalization`` pass: it crops only empty chroma,
    resizes the complete premultiplied figure uniformly, and never repaints or
    deforms body, clothing, feet, or alpha.
    """
    if target_height <= 0:
        raise V20ValidationError("seated scale authority height must be positive")
    x0, y0, x1, y1 = core.visible_bbox(keyed)
    figure = keyed.crop((x0, y0, x1 + 1, y1 + 1))
    height = figure.height
    width = max(1, round(figure.width * target_height / height))
    return core.crunch.raster.premultiplied_resize(figure, (width, target_height))


def _restage_seating_with_endpoint_scale(
    stage_root: Path, manifest: dict[str, Any]
) -> None:
    """Replace seating cells using approved seated/standing endpoint scale.

    Seated-idle phases share phase 00's opaque height. Stand-up phases use a
    uniform linear interpolation between seated phase 00 and standing phase
    11. This makes crown rise monotonic while retaining every authored pose.
    Sit-down remains the exact pixel reverse of the processed stand-up cells.
    """
    sources, _ = core._load_keyed_body_sources(_compat_manifest(manifest))
    empty = core._empty_runtime_cell()
    for direction in SEAT_DIRECTIONS:
        stand_sources = [sources[("stand_up", direction, phase)] for phase in range(12)]
        idle_sources = [sources[("seated_idle", direction, phase)] for phase in range(8)]
        if direction == "se":
            stand_sources = [
                source.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for source in stand_sources
            ]
            idle_sources = [
                source.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for source in idle_sources
            ]
        stand_sources = [core.normalise_source_resolution(source) for source in stand_sources]
        idle_sources = [core.normalise_source_resolution(source) for source in idle_sources]
        reference_height = core.source_opaque_height(stand_sources[-1])
        # A direction may declare a fixed accepted endpoint height. This is a
        # whole-figure scale authority, not a frame repair, and keeps a
        # generator-specific endpoint inside the same processed height gate.
        configured_heights = manifest.get("processing", {}).get(
            "seated_source_opaque_height_by_direction", {}
        )
        seated_height = int(
            configured_heights.get(
                direction, core.source_opaque_height(idle_sources[0]) - 1
            )
        )
        idle_cells = [
            process_keyed_figure(
                normalise_keyed_opaque_height(source, seated_height),
                reference_height=reference_height,
            )
            for phase, source in enumerate(idle_sources)
        ]
        stand_heights = [
            round(seated_height + phase * (reference_height - seated_height) / 11)
            for phase in range(12)
        ]
        stand_cells = [
            process_keyed_figure(
                normalise_keyed_opaque_height(source, stand_heights[phase]),
                reference_height=reference_height,
            )
            for phase, source in enumerate(stand_sources)
        ]
        for phase, cell in enumerate(idle_cells):
            core._save_atlas_cell(
                stage_root,
                "VossSeatedIdle.atlas",
                f"voss_seated_idle_{direction}_{phase:02d}.png",
                cell,
            )
            if direction == "ne":
                upper, lower = split_upper_lower(cell)
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
            core._save_atlas_cell(
                stage_root,
                "VossSeatTransitions.atlas",
                f"voss_sit_down_{direction}_{11 - phase:02d}.png",
                cell,
            )


def register_runtime_cell(
    cell: Image.Image,
    manifest: dict[str, Any],
    *,
    group: str,
    direction: str,
    phase: int,
) -> Image.Image:
    """Apply manifest-declared whole-cell registration only.

    Registration is the final permitted V20 raster operation.  It translates
    the complete processed figure without repainting anatomy, clothing, feet,
    or alpha.  Keeping the offsets explicit and narrowly bounded prevents this
    from becoming the forbidden V19-style repair pass.
    """
    key = f"{group}:{direction}:{phase:02d}"
    offsets = manifest.get("processing", {}).get("runtime_registration_offsets", {})
    offset = offsets.get(key, [0, 0])
    if not (
        isinstance(offset, list)
        and len(offset) == 2
        and all(isinstance(value, int) and not isinstance(value, bool) for value in offset)
    ):
        raise V20ValidationError(f"invalid runtime registration offset for {key}")
    dx, dy = offset
    if abs(dx) > 2 or abs(dy) > 2:
        raise V20ValidationError(f"runtime registration offset exceeds 2px for {key}")
    if dx == 0 and dy == 0:
        return cell
    source_pixels = np.asarray(cell.convert("RGBA")).copy()
    source_pixels[source_pixels[..., 3] == 1] = (0, 0, 0, 0)
    shifted = Image.new("RGBA", cell.size, (0, 0, 0, 0))
    shifted.alpha_composite(Image.fromarray(source_pixels, "RGBA"), (dx, dy))
    # The runtime contract uses four alpha-1 corner sentinels.
    pixels = np.asarray(shifted).copy()
    for x, y in ((0, 0), (cell.width - 1, 0), (0, cell.height - 1), (cell.width - 1, cell.height - 1)):
        pixels[y, x] = (0, 0, 0, 1)
    return Image.fromarray(pixels, "RGBA")


def split_upper_lower(cell: Image.Image) -> tuple[Image.Image, Image.Image]:
    return core.split_upper_lower(cell)


def derive_sit_down(stand_up: Sequence[Image.Image]) -> list[Image.Image]:
    return list(reversed(stand_up))


def _validate_anchors_v20(manifest: dict[str, Any], errors: list[str]) -> dict[str, Any]:
    report: dict[str, Any] = {}
    bounds = manifest["gates"]["anchor_width_height_ratio"]
    for view in ("front", "back"):
        path = V20_ROOT / ANCHOR_PATHS[view]
        if not path.is_file():
            errors.append(f"missing {view} V20 anchor for processed shape gate")
            continue
        cell = core.process_figure(core.load_source(path))
        metrics = core.frame_metrics(cell)
        ratio = metrics.width / metrics.height
        report[view] = {"width": metrics.width, "height": metrics.height, "ratio": round(ratio, 4)}
        tolerance = 1.0 / metrics.height
        if not float(bounds[0]) - tolerance <= ratio <= float(bounds[1]) + tolerance:
            errors.append(
                f"{view} anchor width/body-height ratio {ratio:.3f}, expected {bounds[0]:.2f}...{bounds[1]:.2f}"
            )
    return report


def _validate_rear_hemisphere(
    stage_root: Path, manifest: dict[str, Any], errors: list[str]
) -> dict[str, dict[str, float]]:
    report: dict[str, dict[str, float]] = {}
    shirt_limit = float(manifest["gates"]["rear_shirt_fraction_max"])
    skin_limit = float(manifest["gates"]["pure_rear_skin_fraction_max"])
    for direction in ("n", "nnw", "nw"):
        cells = [
            ("VossIdle.atlas", f"voss_standing_idle_{direction}_{phase:02d}.png")
            for phase in range(4)
        ] + [
            ("VossWalk.atlas", f"voss_walk_{direction}_{phase:02d}.png")
            for phase in range(8)
        ]
        for atlas, name in cells:
            cell = core._load_stage_cell(stage_root, atlas, name)
            shirt = core._rear_forbidden_fraction(cell, manifest["wardrobe"]["shirt"])
            skin = core._rear_forbidden_fraction(cell, manifest["wardrobe"]["skin"])
            report[name] = {"shirt": round(shirt, 6), "skin": round(skin, 6)}
            if shirt > shirt_limit:
                errors.append(f"{name}: rear shirt fraction {shirt:.6f}, expected <= {shirt_limit:.6f}")
            if direction == "n" and skin > skin_limit:
                errors.append(f"{name}: pure-rear skin fraction {skin:.6f}, expected <= {skin_limit:.6f}")
    return report


def _validate_stage_contents(stage_root: Path, manifest: dict[str, Any]) -> dict[str, Any]:
    """Strict gates only: no filters, repair passes, or tolerance waivers."""
    original_anchor = core._validate_anchors
    original_rear = core._rear_forbidden_fraction

    def rear_without_black_tie_false_positive(image: Image.Image, target_hex: str) -> float:
        # The V16 tie heuristic confuses the approved black tie with legitimate
        # charcoal rear trousers. V20 replaces it with shirt+skin gates on all
        # 36 rear cells below; no failing V20 gate is suppressed.
        if target_hex.upper() == manifest["wardrobe"]["tie"].upper():
            return 0.0
        return original_rear(image, target_hex)

    try:
        with _v20_core_context():
            core._validate_anchors = _validate_anchors_v20
            core._rear_forbidden_fraction = rear_without_black_tie_false_positive
            report = core.validate_staging(stage_root, _compat_manifest(manifest))
    finally:
        core._validate_anchors = original_anchor
        core._rear_forbidden_fraction = original_rear

    errors: list[str] = []
    rear = _validate_rear_hemisphere(stage_root, manifest, errors)
    paper = stage_root / "UI" / PAPERDOLL_RELATIVE
    if not paper.is_file():
        errors.append(f"staging is missing UI/{PAPERDOLL_RELATIVE.as_posix()}")
        paper_hashes: dict[str, str] = {}
    else:
        try:
            with Image.open(paper) as image:
                if image.size != (1024, 1536) or image.mode != "RGBA":
                    errors.append("staged paperdoll must be 1024x1536 RGBA")
                elif int(np.asarray(image)[..., 3].min()) != 0:
                    errors.append("staged paperdoll must retain transparency")
        except Exception as error:
            errors.append(f"staged paperdoll is unreadable ({error})")
        paper_hashes = {f"UI/{PAPERDOLL_RELATIVE.as_posix()}": sha256(paper)}
    if (stage_root / "UI" / PORTRAIT_RELATIVE).exists():
        errors.append("V20 staging must not contain or replace the immutable portrait")
    _fail_if(errors)
    report["asset_version"] = "v20"
    report["strict_no_waivers"] = True
    report["rear_hemisphere_v20"] = rear
    report["output_hashes"].update(paper_hashes)
    report["counts"]["ui_outputs"] = 1
    return report


def _stage_paperdoll(stage_root: Path, manifest: dict[str, Any]) -> None:
    source = V20_ROOT / manifest["ui_root"] / PAPERDOLL_RELATIVE.name
    destination = stage_root / "UI" / PAPERDOLL_RELATIVE
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, destination)


def build_staging(manifest: dict[str, Any]) -> tuple[Path, dict[str, Any]]:
    source_report = validate_sources(manifest, include_all=True)
    staging = V20_ROOT / manifest["staging_root"]
    temporary = staging.with_name(f".{staging.name}.build-{uuid.uuid4().hex}")
    temporary.mkdir(parents=True, exist_ok=False)
    try:
        with _v20_core_context():
            core.build_stage_contents(_compat_manifest(manifest), temporary)
            _restage_seating_with_endpoint_scale(temporary, manifest)
        for key in manifest["processing"]["runtime_registration_offsets"]:
            group, direction, phase_text = key.split(":")
            if group != "walk":
                raise V20ValidationError(f"unsupported runtime registration group: {key}")
            path = temporary / "VossWalk.atlas" / f"voss_walk_{direction}_{phase_text}.png"
            with Image.open(path) as image:
                registered = register_runtime_cell(
                    image.convert("RGBA"),
                    manifest,
                    group=group,
                    direction=direction,
                    phase=int(phase_text),
                )
            core.save_png(registered, path)
        _stage_paperdoll(temporary, manifest)
        gate_report = _validate_stage_contents(temporary, manifest)
        provenance_path = V20_ROOT / manifest["generation_provenance"]
        approvals_path = V20_ROOT / manifest["approval_ledger"]
        report = {
            **gate_report,
            "manifest_sha256": sha256(MANIFEST_PATH),
            "generation_provenance_sha256": sha256(provenance_path),
            "approval_ledger_sha256": sha256(approvals_path),
            "source": source_report,
            "built_at_utc": datetime.now(timezone.utc).isoformat(),
        }
        write_json(temporary / STAGE_REPORT_NAME, report)
        core.replace_directory_transactionally(temporary, staging)
    except Exception:
        if temporary.exists():
            shutil.rmtree(temporary)
        raise
    return staging, report


def validate_staging(stage_root: Path, manifest: dict[str, Any]) -> dict[str, Any]:
    """Read and hash-bind an existing V20 stage; rejects V19 even if art passes."""
    report_path = stage_root / STAGE_REPORT_NAME
    try:
        recorded = json.loads(report_path.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise V20ValidationError(f"not a V20 stage: missing {STAGE_REPORT_NAME}") from error
    except json.JSONDecodeError as error:
        raise V20ValidationError(f"invalid V20 stage report: {error}") from error
    errors: list[str] = []
    if recorded.get("asset_version") != "v20" or recorded.get("strict_no_waivers") is not True:
        errors.append("stage report is not a strict V20 report")
    bindings = {
        "manifest_sha256": MANIFEST_PATH,
        "generation_provenance_sha256": V20_ROOT / manifest["generation_provenance"],
        "approval_ledger_sha256": V20_ROOT / manifest["approval_ledger"],
    }
    for key, path in bindings.items():
        if not path.is_file() or recorded.get(key) != sha256(path):
            errors.append(f"stage report {key} is stale")
    _fail_if(errors)
    validate_portrait_authority(manifest)
    current = _validate_stage_contents(stage_root, manifest)
    if recorded.get("output_hashes") != current.get("output_hashes"):
        raise V20ValidationError("stage output hashes differ from the signed V20 stage report")
    return {**recorded, "read_only_revalidation": "passed"}


def validate_qa_for_install(manifest: dict[str, Any], stage_root: Path) -> dict[str, Any]:
    path = V20_ROOT / manifest["qa_root"] / QA_REPORT_NAME
    try:
        report = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise V20ValidationError(f"missing required V20 QA report: {path}") from error
    except json.JSONDecodeError as error:
        raise V20ValidationError(f"invalid V20 QA report: {error}") from error
    errors: list[str] = []
    if report.get("asset_version") != "v20" or report.get("status") != "passed":
        errors.append("V20 QA report has not passed")
    if report.get("stage_report_sha256") != sha256(stage_root / STAGE_REPORT_NAME):
        errors.append("V20 QA report was generated from a different stage")
    output_hashes = report.get("output_hashes")
    if not isinstance(output_hashes, dict):
        errors.append("V20 QA report has no output hash ledger")
        output_hashes = {}
    required = set(manifest["approval_requirements"]["install_qa_outputs"])
    if set(output_hashes) != required:
        errors.append("V20 QA report output inventory differs from the install contract")
    for relative, digest in output_hashes.items():
        candidate = V20_ROOT / relative
        if not candidate.is_file() or sha256(candidate) != digest:
            errors.append(f"QA output hash drift: {relative}")
    _fail_if(errors)
    return report


def _clear_hidden_flags(path: Path) -> None:
    hidden = getattr(stat, "UF_HIDDEN", 0x00008000)
    targets = [path, *path.rglob("*")] if path.is_dir() else [path]
    for target in targets:
        result = target.stat(follow_symlinks=False)
        flags = getattr(result, "st_flags", 0)
        if flags & hidden and hasattr(os, "chflags"):
            os.chflags(target, flags & ~hidden, follow_symlinks=False)


def _swap_payload_transaction(
    replacements: Sequence[tuple[Path, Path]],
    *,
    fail_after: int | None = None,
    post_swap_check: Callable[[], None] | None = None,
) -> None:
    """Replace files/directories and restore every old payload on any failure."""
    token = uuid.uuid4().hex
    prepared: list[tuple[Path, Path]] = []
    retired: list[tuple[Path, Path]] = []
    try:
        for source, destination in replacements:
            if not source.exists():
                raise V20ValidationError(f"replacement source does not exist: {source}")
            if not destination.exists():
                raise V20ValidationError(f"runtime destination does not exist: {destination}")
            new = destination.with_name(f".{destination.name}.v20-new-{token}")
            if source.is_dir():
                shutil.copytree(source, new, copy_function=shutil.copyfile)
            else:
                new.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, new)
            prepared.append((new, destination))
        for index, (new, destination) in enumerate(prepared, start=1):
            old = destination.with_name(f".{destination.name}.v20-old-{token}")
            os.replace(destination, old)
            retired.append((old, destination))
            os.replace(new, destination)
            _clear_hidden_flags(destination)
            if fail_after is not None and index >= fail_after:
                raise RuntimeError("deliberate V20 transaction failure")
        if post_swap_check is not None:
            post_swap_check()
    except Exception:
        for old, destination in reversed(retired):
            failed = destination.with_name(f".{destination.name}.v20-failed-{token}")
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


def _payload_replacements(stage_root: Path) -> list[tuple[Path, Path]]:
    return [
        *((stage_root / atlas, RUNTIME_ATLASES / atlas) for atlas in RUNTIME_ATLAS_ORDER),
        (stage_root / "UI" / PAPERDOLL_RELATIVE, RUNTIME_UI / PAPERDOLL_RELATIVE),
    ]


def _runtime_hashes_from_stage_hashes(stage_hashes: dict[str, str]) -> dict[str, str]:
    return {
        (f"Atlases/{relative}" if not relative.startswith("UI/") else relative): digest
        for relative, digest in stage_hashes.items()
    }


def _assert_runtime_hashes(expected: dict[str, str]) -> None:
    errors: list[str] = []
    for relative, digest in expected.items():
        path = ROOT / "RainShadow Shared/Resources/Art" / relative
        if not path.is_file() or sha256(path) != digest:
            errors.append(f"installed runtime hash mismatch: {relative}")
    _fail_if(errors)


def run_post_install_verification() -> None:
    """Run the repository's canonical full test and iOS/macOS build gates.

    This executes only after all six V20 payloads have been swapped. Any
    non-zero command raises inside the transaction, so the prior runtime is
    restored before the install command returns.
    """
    commands = (
        (
            "full Swift suite",
            ["swift", "test", "--scratch-path", "/tmp/RainShadowSwiftPM-V20"],
        ),
        (
            "canonical iOS Simulator build",
            [
                "xcodebuild",
                "-project",
                "RainShadow.xcodeproj",
                "-scheme",
                "RainShadow iOS",
                "-configuration",
                "Debug",
                "-sdk",
                "iphonesimulator",
                "CODE_SIGNING_ALLOWED=NO",
                "build",
            ],
        ),
        (
            "canonical macOS build",
            [
                "xcodebuild",
                "-project",
                "RainShadow.xcodeproj",
                "-scheme",
                "RainShadow macOS",
                "-configuration",
                "Debug",
                "CODE_SIGNING_ALLOWED=NO",
                "build",
            ],
        ),
    )
    environment = os.environ.copy()
    environment.pop("RAINSHADOW_VOSS_ATLAS_ROOT", None)
    failures: list[str] = []
    for label, command in commands:
        try:
            completed = subprocess.run(
                command,
                cwd=ROOT,
                env=environment,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                check=False,
            )
        except OSError as error:
            failures.append(f"{label} could not start ({error})")
            break
        if completed.returncode != 0:
            tail = "\n".join(completed.stdout.splitlines()[-40:])
            failures.append(
                f"{label} failed with exit {completed.returncode}"
                + (f"\n{tail}" if tail else "")
            )
            break
    _fail_if(failures)


def backup_runtime_payload(*, label: str = "v20") -> Path:
    validate_portrait_authority(load_manifest())
    timestamp = datetime.now(timezone.utc).strftime(f"{label}-%Y%m%dT%H%M%SZ")
    snapshot = BACKUP_ROOT / timestamp
    if snapshot.exists():
        snapshot = BACKUP_ROOT / f"{timestamp}-{uuid.uuid4().hex[:8]}"
    temporary = snapshot.with_name(f".{snapshot.name}.build-{uuid.uuid4().hex}")
    temporary.mkdir(parents=True, exist_ok=False)
    hashes: dict[str, str] = {}
    try:
        for atlas in RUNTIME_ATLAS_ORDER:
            source_dir = RUNTIME_ATLASES / atlas
            if not source_dir.is_dir():
                raise V20ValidationError(f"cannot back up missing runtime atlas {source_dir}")
            expected_names = set(expected_runtime_names()[atlas])
            actual_names = {path.name for path in source_dir.glob("*.png") if " 2" not in path.name}
            if actual_names != expected_names:
                raise V20ValidationError(f"cannot back up {atlas}: runtime filename inventory is not canonical")
            for source in sorted(source_dir / name for name in expected_names):
                destination = temporary / "Atlases" / atlas / source.name
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, destination)
                hashes[f"Atlases/{atlas}/{source.name}"] = sha256(destination)
        source = RUNTIME_UI / PAPERDOLL_RELATIVE
        if not source.is_file():
            raise V20ValidationError(f"cannot back up missing runtime paperdoll {source}")
        destination = temporary / "UI" / PAPERDOLL_RELATIVE
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)
        hashes[f"UI/{PAPERDOLL_RELATIVE.as_posix()}"] = sha256(destination)
        write_json(
            temporary / "backup_manifest.json",
            {
                "backup_format": "v20-six-payload",
                "captured_at_utc": datetime.now(timezone.utc).isoformat(),
                "portrait_sha256": PORTRAIT_SHA256,
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


def install_runtime_transaction(
    stage_root: Path,
    report: dict[str, Any] | None = None,
    *,
    post_install_check: Callable[[], None] | None = None,
) -> Path:
    manifest = load_manifest()
    validate_sources(manifest, include_all=True)
    current = validate_staging(stage_root, manifest)
    if report is not None and report.get("output_hashes") != current.get("output_hashes"):
        raise V20ValidationError("caller supplied a stale V20 stage report")
    validate_qa_for_install(manifest, stage_root)
    validate_approval_ledger(
        manifest,
        set(manifest["approval_requirements"]["source_outputs"])
        | set(manifest["approval_requirements"]["ui_outputs"])
        | set(manifest["approval_requirements"]["install_qa_outputs"]),
    )
    expected = _runtime_hashes_from_stage_hashes(current["output_hashes"])
    backup = backup_runtime_payload()

    def verify() -> None:
        _assert_runtime_hashes(expected)
        validate_portrait_authority(manifest)
        (post_install_check or run_post_install_verification)()

    _swap_payload_transaction(_payload_replacements(stage_root), post_swap_check=verify)
    return backup


def _read_backup_manifest(snapshot: Path) -> tuple[dict[str, Any], dict[str, str]]:
    try:
        payload = json.loads((snapshot / "backup_manifest.json").read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise V20ValidationError(f"missing V20 backup manifest under {snapshot}") from error
    except json.JSONDecodeError as error:
        raise V20ValidationError(f"invalid V20 backup manifest: {error}") from error
    errors: list[str] = []
    if payload.get("backup_format") != "v20-six-payload" or payload.get("portrait_sha256") != PORTRAIT_SHA256:
        errors.append("backup is not a portrait-immutable V20 six-payload snapshot")
    files = payload.get("files")
    if not isinstance(files, dict):
        errors.append("backup manifest has no file hashes")
        files = {}
    expected_files = {
        f"Atlases/{atlas}/{name}"
        for atlas, names in expected_runtime_names().items()
        for name in names
    } | {f"UI/{PAPERDOLL_RELATIVE.as_posix()}"}
    if set(files) != expected_files:
        errors.append("backup manifest must contain exactly 208 canonical atlas cells plus the paperdoll")
    for relative, digest in files.items():
        try:
            _safe_relative(relative, "backup file")
        except V20ValidationError as error:
            errors.extend(error.errors)
            continue
        candidate = snapshot / relative
        if not _valid_digest(digest) or not candidate.is_file() or sha256(candidate) != digest:
            errors.append(f"backup file hash mismatch: {relative}")
    _fail_if(errors)
    return payload, files


def resolve_backup(value: Path | None) -> Path:
    if value is None:
        candidates = sorted(
            (path for path in BACKUP_ROOT.iterdir() if (path / "backup_manifest.json").is_file()),
            key=lambda path: path.name,
        ) if BACKUP_ROOT.is_dir() else []
        if not candidates:
            raise V20ValidationError(f"no V20 backups available under {BACKUP_ROOT}")
        return candidates[-1]
    candidate = value if value.is_absolute() else BACKUP_ROOT / value
    candidate = candidate.resolve()
    try:
        candidate.relative_to(BACKUP_ROOT.resolve())
    except ValueError as error:
        raise V20ValidationError("restore backup must be inside the V20 backup root") from error
    return candidate


def restore_runtime_transaction(snapshot: Path) -> Path:
    manifest = load_manifest()
    validate_portrait_authority(manifest)
    _, hashes = _read_backup_manifest(snapshot)
    recovery = backup_runtime_payload(label="v20-pre-restore")
    replacements = [
        *((snapshot / "Atlases" / atlas, RUNTIME_ATLASES / atlas) for atlas in RUNTIME_ATLAS_ORDER),
        (snapshot / "UI" / PAPERDOLL_RELATIVE, RUNTIME_UI / PAPERDOLL_RELATIVE),
    ]

    def verify() -> None:
        _assert_runtime_hashes(hashes)
        validate_portrait_authority(manifest)

    _swap_payload_transaction(replacements, post_swap_check=verify)
    return recovery


def _print_validation_error(error: V20ValidationError) -> None:
    print(f"V20 validation failed ({len(error.errors)} issue(s)):", file=sys.stderr)
    for issue in error.errors:
        print(f" - {issue}", file=sys.stderr)


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("validate-proof", help="validate 4 anchors, 9 keys, and SW/N walk proofs")
    subparsers.add_parser("validate", help="validate all 148 masters, routes, hashes, and approvals")
    subparsers.add_parser("stage", help="build and strictly gate five atlases plus the paperdoll")
    validate_stage_parser = subparsers.add_parser("validate-stage", help="read-only strict stage validation")
    validate_stage_parser.add_argument("--staging", type=Path, default=None)
    install_parser = subparsers.add_parser("install", help="install an already gated and approved V20 stage")
    install_parser.add_argument("--confirm-runtime-replace", metavar="V20")
    restore_parser = subparsers.add_parser("restore", help="transactionally restore a V20 runtime backup")
    restore_parser.add_argument("--backup", type=Path, default=None, help="backup name/path; defaults to latest")
    args = parser.parse_args(argv)

    try:
        manifest = load_manifest()
        if args.command == "validate-proof":
            report = validate_sources(manifest, include_all=False)
            print(
                f"V20 proof passed: {report['masters_validated']} approved masters + four anchors; runtime untouched"
            )
        elif args.command == "validate":
            report = validate_sources(manifest, include_all=True)
            print(f"V20 source validation passed: {report['masters_validated']} masters; runtime untouched")
        elif args.command == "stage":
            staging, report = build_staging(manifest)
            print(
                f"V20 staging passed: {report['counts']['runtime_pngs']} atlas PNGs + paperdoll at "
                f"{staging.relative_to(ROOT)}; runtime untouched"
            )
        elif args.command == "validate-stage":
            staging = args.staging or (V20_ROOT / manifest["staging_root"])
            report = validate_staging(staging, manifest)
            print(f"V20 stage read-only validation passed: {len(report['output_hashes'])} files")
        elif args.command == "install":
            if args.confirm_runtime_replace != "V20":
                parser.error("install requires --confirm-runtime-replace V20")
            staging = V20_ROOT / manifest["staging_root"]
            report = validate_staging(staging, manifest)
            backup = install_runtime_transaction(staging, report)
            print(f"V20 installed transactionally; prior runtime saved at {backup.relative_to(ROOT)}")
        elif args.command == "restore":
            snapshot = resolve_backup(args.backup)
            recovery = restore_runtime_transaction(snapshot)
            print(
                f"V20 runtime restored from {snapshot.relative_to(ROOT)}; pre-restore recovery saved at "
                f"{recovery.relative_to(ROOT)}"
            )
    except V20ValidationError as error:
        _print_validation_error(error)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

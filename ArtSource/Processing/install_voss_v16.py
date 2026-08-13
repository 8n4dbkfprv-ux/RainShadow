#!/usr/bin/env python3
"""Validate, stage, QA, and transactionally install the V16 Voss atlases.

This is deliberately separate from every V12/V13 installer.  V16 consumes 148
individual Image Generator masters and never calls the legacy colour locks: the
masters already carry the eight-material wardrobe, and stamping the old seated
brown ratio over them would destroy it.

Safe workflow::

    python3 install_voss_v16.py validate-proof
    python3 install_voss_v16.py validate
    python3 install_voss_v16.py stage
    python3 qa_voss_v16.py
    python3 install_voss_v16.py install --confirm-runtime-replace V16

``validate`` and ``stage`` never write runtime assets.  ``install`` rebuilds and
revalidates staging, snapshots the five current Voss atlases, prepares five
sibling replacement directories, then swaps them as one rollback-capable
transaction.  It never uses ``shutil.copy2`` so Finder/iCloud xattrs cannot be
carried into an Xcode atlas.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from datetime import datetime, timezone
import hashlib
import json
import math
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

# crunch.py reads this switch at import time.  V16 is the deliberate wardrobe
# regeneration that the switch was waiting for, so a caller cannot accidentally
# disable it with a stale shell environment.
os.environ["RAINSHADOW_PRESERVE_WARDROBE"] = "1"
import crunch  # noqa: E402

crunch.PRESERVE_WARDROBE = True


V16_ROOT = ROOT / "ArtSource/Generated/Characters/Detective/PreRendered3DV16"
MANIFEST_PATH = V16_ROOT / "voss_v16_manifest.json"
RUNTIME_ATLASES = ROOT / "RainShadow Shared/Resources/Art/Atlases"
BACKUP_ROOT = ROOT / "ArtSource/Generated/Characters/RuntimeBackupPreRendered3DV16Prior"

FRAME_SIZE = 512
FOOT_Y = 434
VISIBLE_FOOT_ROW = FOOT_Y - 1
SENTINEL_ALPHA = 1

WESTERN_DIRECTIONS = ("s", "ssw", "sw", "wsw", "w", "wnw", "nw", "nnw", "n")
SEAT_DIRECTIONS = ("ne", "se")
RUNTIME_ATLAS_ORDER = (
    "VossIdle.atlas",
    "VossWalk.atlas",
    "VossSeatedIdle.atlas",
    "VossSeatedArms.atlas",
    "VossSeatTransitions.atlas",
)


class V16ValidationError(RuntimeError):
    """One or more V16 contract gates failed."""

    def __init__(self, errors: str | Iterable[str]):
        if isinstance(errors, str):
            self.errors = [errors]
        else:
            self.errors = list(errors)
        super().__init__("\n".join(self.errors))


@dataclass(frozen=True)
class MasterSpec:
    group: str
    direction: str
    phase: int
    filename: str


@dataclass(frozen=True)
class FrameMetrics:
    width: int
    height: int
    crown_y: int
    foot_y: int
    center_x: float
    centroid_x: float
    centroid_y: float
    head_width: int
    head_center_x: float
    torso_width: int


def _fail_if(errors: Sequence[str]) -> None:
    if errors:
        raise V16ValidationError(errors)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
    temporary.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def load_manifest(path: Path = MANIFEST_PATH) -> dict[str, Any]:
    try:
        manifest = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise V16ValidationError(f"Missing V16 manifest: {path}") from error
    except json.JSONDecodeError as error:
        raise V16ValidationError(f"Invalid V16 manifest JSON: {error}") from error
    validate_manifest_contract(manifest)
    return manifest


def master_specs(manifest: dict[str, Any]) -> list[MasterSpec]:
    specs: list[MasterSpec] = []
    for group, definition in manifest["generated"].items():
        for direction in definition["directions"]:
            for phase in range(int(definition["phases"])):
                specs.append(
                    MasterSpec(
                        group=group,
                        direction=direction,
                        phase=phase,
                        filename=definition["pattern"].format(
                            direction=direction, phase=phase
                        ),
                    )
                )
    return specs


def expected_runtime_names() -> dict[str, list[str]]:
    idle = [
        f"voss_standing_idle_{direction}_{phase:02d}.png"
        for direction in WESTERN_DIRECTIONS
        for phase in range(4)
    ] + [f"voss_standing_idle_se_{phase:02d}.png" for phase in range(4)]
    walk = [
        f"voss_walk_{direction}_{phase:02d}.png"
        for direction in WESTERN_DIRECTIONS
        for phase in range(8)
    ]
    seated = [
        f"voss_seated_idle_{direction}_{phase:02d}.png"
        for direction in SEAT_DIRECTIONS
        for phase in range(8)
    ] + [
        f"voss_seated_{layer}_ne_{phase:02d}.png"
        for layer in ("upper", "lower")
        for phase in range(8)
    ]
    arms = [
        f"voss_seated_arms_{direction}_{phase:02d}.png"
        for direction in SEAT_DIRECTIONS
        for phase in range(8)
    ]
    transitions = [
        f"voss_{motion}_{direction}_{phase:02d}.png"
        for motion in ("stand_up", "sit_down")
        for direction in SEAT_DIRECTIONS
        for phase in range(12)
    ]
    return {
        "VossIdle.atlas": idle,
        "VossWalk.atlas": walk,
        "VossSeatedIdle.atlas": seated,
        "VossSeatedArms.atlas": arms,
        "VossSeatTransitions.atlas": transitions,
    }


def validate_manifest_contract(manifest: dict[str, Any]) -> None:
    errors: list[str] = []
    if manifest.get("schema_version") != 1 or manifest.get("asset_version") != "v16":
        errors.append("manifest must declare schema_version=1 and asset_version=v16")

    generated = manifest.get("generated", {})
    expected_groups = {
        "standing_idle": (WESTERN_DIRECTIONS, 4),
        "walk": (WESTERN_DIRECTIONS, 8),
        "seated_idle": (SEAT_DIRECTIONS, 8),
        "stand_up": (SEAT_DIRECTIONS, 12),
    }
    for name, (directions, phases) in expected_groups.items():
        definition = generated.get(name, {})
        if tuple(definition.get("directions", ())) != directions:
            errors.append(f"manifest {name} directions do not match the V16 contract")
        if definition.get("phases") != phases:
            errors.append(f"manifest {name} phases must be {phases}")

    try:
        specs = master_specs(manifest)
    except (KeyError, TypeError, ValueError) as error:
        errors.append(f"manifest generated patterns cannot be expanded: {error}")
        specs = []
    if len(specs) != 148 or len({spec.filename for spec in specs}) != 148:
        errors.append(
            f"manifest must expand to 148 unique ImageGen body masters, got {len(specs)}"
        )

    inventory_path = V16_ROOT / "frame_inventory_v16.json"
    if inventory_path.exists():
        try:
            inventory = json.loads(inventory_path.read_text(encoding="utf-8"))
            inventory_names = {
                Path(call["selected_master"]).name for call in inventory["generated_calls"]
            }
            manifest_names = {spec.filename for spec in specs}
            if inventory_names != manifest_names or len(inventory["generated_calls"]) != 148:
                errors.append(
                    "voss_v16_manifest.json production names drift from frame_inventory_v16.json"
                )
        except (KeyError, TypeError, json.JSONDecodeError) as error:
            errors.append(f"frame_inventory_v16.json cannot be cross-validated: {error}")

    runtime = expected_runtime_names()
    runtime_counts = {name: len(names) for name, names in runtime.items()}
    if runtime_counts != manifest.get("runtime"):
        errors.append(f"runtime counts must be {runtime_counts}, got {manifest.get('runtime')}")
    if sum(runtime_counts.values()) != 208:
        errors.append("internal V16 runtime name expansion is not 208 files")
    counts = manifest.get("counts", {})
    if counts != {
        "imagegen_body_masters": 148,
        "primary_body_presentations": 176,
        "runtime_pngs": 208,
    }:
        errors.append("manifest count contract must be 148 generated / 176 primary / 208 runtime")

    processing = manifest.get("processing", {})
    required_processing = {
        "processor": "V14",
        "native_body_rows": 56,
        "texture_body_height": 200,
        "canvas": [512, 512],
        "foot_row": 433,
        "corner_sentinel_alpha": 1,
        "palette_colors": 64,
        "dither": False,
        "hard_alpha": True,
        "preserve_wardrobe": True,
        "seated_se_source_mirror_x": True,
    }
    for key, value in required_processing.items():
        if processing.get(key) != value:
            errors.append(f"manifest processing.{key} must be {value!r}")

    expected_wardrobe = {
        name: "#" + "".join(f"{channel:02X}" for channel in rgb)
        for name, rgb in crunch.WARDROBE.items()
    }
    if manifest.get("wardrobe") != expected_wardrobe:
        errors.append("manifest wardrobe palette differs from crunch.WARDROBE")

    if not crunch.PRESERVE_WARDROBE or os.environ.get("RAINSHADOW_PRESERVE_WARDROBE") != "1":
        errors.append("V16 installer failed to arm RAINSHADOW_PRESERVE_WARDROBE=1")
    active = crunch.ACTIVE
    if not (
        active.native_rows == 56
        and active.colors == 64
        and active.hard_alpha
        and active.ramp_palette
        and crunch.TEXTURE_BODY_HEIGHT == 200
    ):
        errors.append("crunch.ACTIVE is not the approved V14 raster recipe")

    forbidden = set(processing.get("forbidden_legacy_locks", []))
    if not {"seated_authority_lock", "identity_wardrobe_lock", "relock_voss_identity_v12"} <= forbidden:
        errors.append("manifest must explicitly forbid all legacy Voss flattening/relock passes")
    _fail_if(errors)


def _border_pixels(rgb: np.ndarray) -> np.ndarray:
    return np.concatenate((rgb[0], rgb[-1], rgb[1:-1, 0], rgb[1:-1, -1]), axis=0)


def key_chroma(image: Image.Image) -> Image.Image:
    """Key/despill uniform ImageGen green without deleting Voss's #364636 tie."""
    pixels = np.asarray(image.convert("RGBA")).copy()
    rgb = pixels[..., :3].astype(np.float32)
    red, green, blue = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    other = np.maximum(red, blue)
    dominance = green - other
    key = np.clip((dominance - 20.0) / 90.0, 0.0, 1.0)
    key *= (green > 80) & (green > other * 1.18)
    alpha = pixels[..., 3].astype(np.float32) * (1.0 - key)
    pixels[..., 3] = np.clip(alpha, 0, 255).astype(np.uint8)
    spill = key > 0
    pixels[..., 1][spill] = np.minimum(
        pixels[..., 1][spill],
        np.clip(other[spill] * 1.06, 0, 255).astype(np.uint8),
    )
    pixels[pixels[..., 3] < 4] = 0
    return Image.fromarray(pixels, "RGBA")


def visible_mask(image: Image.Image, threshold: int = 16) -> np.ndarray:
    mask = np.asarray(image.convert("RGBA"))[..., 3] >= threshold
    if mask.shape == (FRAME_SIZE, FRAME_SIZE):
        mask = mask.copy()
        mask[0, 0] = False
        mask[0, -1] = False
        mask[-1, 0] = False
        mask[-1, -1] = False
    return mask


def visible_bbox(image: Image.Image, threshold: int = 16) -> tuple[int, int, int, int]:
    mask = visible_mask(image, threshold)
    ys, xs = np.where(mask)
    if len(xs) == 0:
        raise V16ValidationError("image has no visible subject")
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


def source_opaque_height(image: Image.Image) -> int:
    x0, y0, x1, y1 = visible_bbox(image)
    del x0, x1
    return y1 - y0 + 1


def source_head_width(image: Image.Image) -> int:
    return anatomy_bands(image)[0]


#: Shoulder band that reproduces the V20 clip-coherence audit's shipped
#: widths (s 71→67, wsw 64→56, nnw 66→56 on the 200px cells). Head stays the
#: top 10% of the figure; this band is the next ~19% below the crown.
SHOULDER_BAND = (0.10, 0.29)


def anatomy_bands(image: Image.Image) -> tuple[int, int]:
    """Return (head width, shoulder width) on a keyed figure.

    Scale-free head/shoulder ratio is the idle↔walk identity metric: a uniform
    resize cannot reconcile a head and a shoulder that disagree by 30%, and at
    56 native rows a few percent of correction cannot survive the raster.
    """
    mask = visible_mask(image)
    ys, xs = np.where(mask)
    if not len(xs):
        return 0, 0
    y0, y1 = int(ys.min()), int(ys.max())
    height = y1 - y0 + 1
    head_band = max(1, height * 10 // 100)
    head_xs = np.where(mask[y0 : y0 + head_band].any(axis=0))[0]
    head = int(head_xs.max() - head_xs.min() + 1) if len(head_xs) else 0
    shoulder_y0 = y0 + round(height * SHOULDER_BAND[0])
    shoulder_y1 = y0 + round(height * SHOULDER_BAND[1])
    if shoulder_y1 <= shoulder_y0:
        return head, 0
    shoulder_xs = np.where(mask[shoulder_y0:shoulder_y1].any(axis=0))[0]
    shoulder = int(shoulder_xs.max() - shoulder_xs.min() + 1) if len(shoulder_xs) else 0
    return head, shoulder


def median_number(values: Sequence[float]) -> float:
    items = sorted(float(value) for value in values)
    if not items:
        return 0.0
    middle = len(items) // 2
    if len(items) % 2:
        return items[middle]
    return 0.5 * (items[middle - 1] + items[middle])


def head_shoulder_ratio(head: float, shoulder: float) -> float:
    if shoulder <= 0:
        return 0.0
    return float(head) / float(shoulder)


def idle_walk_ratio_disagreement(
    idle_head: float, idle_shoulder: float, walk_head: float, walk_shoulder: float
) -> float:
    """(walk_ratio - idle_ratio) / idle_ratio. Same character is near 0."""
    idle_ratio = head_shoulder_ratio(idle_head, idle_shoulder)
    walk_ratio = head_shoulder_ratio(walk_head, walk_shoulder)
    if idle_ratio <= 0:
        return math.inf
    return (walk_ratio - idle_ratio) / idle_ratio


def clip_anatomy(frames: Sequence[Image.Image]) -> dict[str, float]:
    bands = [anatomy_bands(frame) for frame in frames]
    heads = [head for head, _ in bands]
    shoulders = [shoulder for _, shoulder in bands]
    head = median_number(heads)
    shoulder = median_number(shoulders)
    return {
        "head": head,
        "shoulder": shoulder,
        "ratio": head_shoulder_ratio(head, shoulder),
    }


def _source_chroma_errors(path: Path) -> tuple[list[str], Image.Image | None]:
    errors: list[str] = []
    try:
        with Image.open(path) as opened:
            if opened.format != "PNG":
                errors.append(f"{path.name}: source is not a PNG")
            source = opened.convert("RGBA").copy()
    except Exception as error:  # Pillow raises several format-specific classes.
        return [f"{path.name}: unreadable image ({error})"], None
    if source.width < 256 or source.height < 256:
        errors.append(f"{path.name}: source canvas {source.size} is smaller than 256px")
        return errors, source

    rgb = np.asarray(source)[..., :3].astype(np.float32)
    border = _border_pixels(rgb)
    greenish = (
        (border[:, 1] > 140)
        & (border[:, 1] > border[:, 0] + 40)
        & (border[:, 1] > border[:, 2] + 40)
    )
    if float(greenish.mean()) < 0.98:
        errors.append(
            f"{path.name}: only {greenish.mean() * 100:.1f}% of the border is flat chroma green"
        )
    green_border = border[greenish]
    if len(green_border) and float(green_border.std(axis=0).max()) > 12.0:
        errors.append(
            f"{path.name}: chroma border varies too much ({green_border.std(axis=0).round(1).tolist()})"
        )
    keyed = key_chroma(source)
    try:
        x0, y0, x1, y1 = visible_bbox(keyed)
    except V16ValidationError:
        errors.append(f"{path.name}: chroma key leaves no Voss figure")
        return errors, keyed
    if x0 <= 1 or y0 <= 1 or x1 >= source.width - 2 or y1 >= source.height - 2:
        errors.append(f"{path.name}: subject touches the source border")
    return errors, keyed


def _sequence_specs(specs: Sequence[MasterSpec], group: str, direction: str) -> list[MasterSpec]:
    return sorted(
        (spec for spec in specs if spec.group == group and spec.direction == direction),
        key=lambda spec: spec.phase,
    )


def _source_sequence_scale_errors(
    label: str, keyed: Sequence[Image.Image], *, maximum_ratio: float = 1.12
) -> list[str]:
    # Default ImageGen can return the same constrained edit on different output
    # canvas resolutions/aspects.  Camera scale is therefore measured in
    # canvas-height units, not raw source pixels.
    widths = [source_head_width(image) / image.height for image in keyed]
    if not widths or min(widths) <= 0:
        return [f"{label}: cannot measure every source head"]
    ratio = max(widths) / min(widths)
    return (
        [
            f"{label}: source head scale drifts {ratio:.3f} (> {maximum_ratio:.2f}); "
            f"normalised widths={[round(value, 4) for value in widths]}"
        ]
        if ratio > maximum_ratio
        else []
    )


def validate_sources(
    manifest: dict[str, Any], *, include_all: bool = True
) -> dict[str, Any]:
    """Validate all selected inputs before any staged or runtime output is written."""
    frames_root = V16_ROOT / manifest["source_root"]
    anchors_root = V16_ROOT / manifest["anchors_root"]
    specs = master_specs(manifest)
    errors: list[str] = []
    keyed: dict[str, Image.Image] = {}
    source_sizes: set[tuple[int, int]] = set()
    source_hashes: dict[str, str] = {}

    required_specs = specs if include_all else _sequence_specs(specs, "walk", "sw")
    for spec in required_specs:
        path = frames_root / spec.filename
        if not path.is_file():
            errors.append(f"missing master Frames/{spec.filename}")
            continue
        image_errors, keyed_image = _source_chroma_errors(path)
        errors.extend(image_errors)
        if keyed_image is not None:
            keyed[spec.filename] = keyed_image
            source_sizes.add(keyed_image.size)
        source_hashes[f"Frames/{spec.filename}"] = sha256(path)

    anchor_hashes: dict[str, str] = {}
    for filename in manifest["required_anchors"]:
        path = anchors_root / filename
        if not path.is_file():
            errors.append(f"missing anchor Anchors/{filename}")
            continue
        image_errors, keyed_image = _source_chroma_errors(path)
        errors.extend(image_errors)
        if keyed_image is not None:
            keyed[f"Anchors/{filename}"] = keyed_image
        anchor_hashes[f"Anchors/{filename}"] = sha256(path)

    if include_all and frames_root.exists():
        expected = {spec.filename for spec in specs}
        actual = {path.name for path in frames_root.glob("*_chroma_v16.png")}
        unexpected = sorted(actual - expected)
        if unexpected:
            errors.append("unexpected V16 production masters: " + ", ".join(unexpected))

    # The complete SW cycle is the production proof and must be eight genuinely
    # separate edits, not repeated placeholders.
    sw_specs = _sequence_specs(specs, "walk", "sw")
    sw_present = [spec for spec in sw_specs if spec.filename in keyed]
    if len(sw_present) == 8:
        sw_digests = [source_hashes[f"Frames/{spec.filename}"] for spec in sw_specs]
        if len(set(sw_digests)) != 8:
            errors.append("SW walk proof must contain eight unique ImageGen masters")
        errors.extend(
            _source_sequence_scale_errors(
                "SW walk proof", [keyed[spec.filename] for spec in sw_specs]
            )
        )

    if include_all and all(spec.filename in keyed for spec in specs):
        for group, directions in (
            ("standing_idle", WESTERN_DIRECTIONS),
            ("walk", WESTERN_DIRECTIONS),
            ("seated_idle", SEAT_DIRECTIONS),
            ("stand_up", SEAT_DIRECTIONS),
        ):
            for direction in directions:
                sequence = _sequence_specs(specs, group, direction)
                images = [keyed[spec.filename] for spec in sequence]
                digests = [source_hashes[f"Frames/{spec.filename}"] for spec in sequence]
                if len(set(digests)) != len(sequence):
                    errors.append(f"{group} {direction}: duplicate source masters")
                errors.extend(_source_sequence_scale_errors(f"{group} {direction}", images))

        front_name = "voss_idle_s_00_chroma_v16.png"
        if front_name in keyed:
            spread = crunch.material_hue_spread(keyed[front_name])
            minimum = float(manifest["gates"]["source_front_hue_spread_min"])
            if spread < minimum:
                errors.append(
                    f"source front key hue spread {spread:.3f}, expected >= {minimum:.2f}"
                )

    _fail_if(errors)
    return {
        "masters_validated": len(required_specs),
        "anchors_validated": len(manifest["required_anchors"]),
        "source_canvases": [list(size) for size in sorted(source_sizes)],
        "source_hashes": {**source_hashes, **anchor_hashes},
    }


def stamp_sentinels(canvas: Image.Image) -> Image.Image:
    for xy in ((0, 0), (FRAME_SIZE - 1, 0), (0, FRAME_SIZE - 1), (FRAME_SIZE - 1, FRAME_SIZE - 1)):
        canvas.putpixel(xy, (0, 0, 0, SENTINEL_ALPHA))
    return canvas


#: How far body-axis registration may move a cell off bbox-centre. A frame that
#: wants more than this has a silhouette problem the anchor cannot fix, and
#: sliding it further would hide that instead of failing the gate.
#: Set at the point where mass centring stops buying anything: worst walk
#: centroid drift falls 4.95px -> 0.91px as this rises to 6 and is flat after.
MAX_BODY_AXIS_SHIFT = 6

#: How far a mass-registered cell's *bbox* may sit off canvas centre. Not a
#: registration target — a bound on how lopsided a silhouette is allowed to be
#: before it is treated as broken rather than as a pose.
BODY_AXIS_BBOX_TOLERANCE = 8.0


def body_axis_x(figure: Image.Image, threshold: int = 16) -> float | None:
    """The x a frame should be registered on: the centroid of its own mass.

    Registering on the silhouette bbox instead — `(FRAME_SIZE - width) // 2` —
    lets anything that widens one side push the whole body the other way, because
    the bbox is exactly as wide as the furthest-out pixel. A swinging arm or a
    flaring coat hem then translates the body frame to frame, which reads as the
    character sliding or yawing on the spot.

    Chosen by measurement against bbox, torso-band, hip-band and foot-band
    anchors, scored on how *still* the result is (mean IoU between adjacent
    frames) rather than on any one landmark. The mass centroid wins the walk on
    stillness and is level with bbox on the idle, while holding the body far
    steadier: worst centroid drift 1.91px -> 0.91px on the idles and 4.95px ->
    0.85px on the walks.

    It does move the *head's* bbox midpoint around more (worst 4.0px -> 5.0px on
    the walks), and that is the honest trade: the old number was low because the
    old registration pinned the bbox the head sits at the top of, not because the
    head was steady. `_validate_motion` gates the centroid for this reason.
    """
    mask = np.asarray(figure.convert("RGBA"))[..., 3] >= threshold
    _, xs = np.where(mask)
    if not len(xs):
        return None
    return float(xs.mean())


def register_crunched(figure: Image.Image, body_axis: bool = False) -> Image.Image:
    """Place a crunched figure on the runtime canvas, feet on FOOT_Y.

    `body_axis` opts into mass-centroid registration. It is off by default so the
    seat chain and every older installer keep the bbox centring they were graded
    against — the seated cells are gated on bbox centre, and a chair is not a
    body whose mass should be centred.
    """
    figure = crunch.harden_alpha(figure.convert("RGBA"))
    if figure.width > FRAME_SIZE or figure.height > FOOT_Y:
        raise V16ValidationError(
            f"processed figure {figure.size} cannot fit 512px canvas at FOOT_Y={FOOT_Y}"
        )
    centred = (FRAME_SIZE - figure.width) // 2
    axis = body_axis_x(figure) if body_axis else None
    if axis is None:
        left = centred
    else:
        # Put the body axis on the canvas centre, then hold the result within
        # MAX_BODY_AXIS_SHIFT of where bbox-centring would have put it.
        wanted = round(FRAME_SIZE / 2 - axis)
        left = max(centred - MAX_BODY_AXIS_SHIFT, min(centred + MAX_BODY_AXIS_SHIFT, wanted))
        left = max(0, min(FRAME_SIZE - figure.width, left))
    canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    canvas.alpha_composite(figure, (left, FOOT_Y - figure.height))
    return stamp_sentinels(canvas)


def process_keyed_figure(
    keyed: Image.Image,
    *,
    reference_height: int | None = None,
    palette: "crunch.ClipPalette | None" = None,
    body_axis: bool = False,
) -> Image.Image:
    prepared = crunch.soften(keyed)
    crunched = crunch.crunch(prepared, reference_height=reference_height, palette=palette)
    # No grade runs between crunch and finalise in V16, but the final pass is kept
    # explicit so any future safe exposure adjustment cannot leave >64 colours.
    # `finalise` re-imposes the palette, so it has to be given the *same* clip
    # ramps — refitting here would undo the shared fit one pass later.
    crunched = crunch.finalise(crunched, palette)
    return register_crunched(crunched, body_axis)


def process_figure(
    source: Image.Image,
    *,
    reference_height: int | None = None,
    palette: "crunch.ClipPalette | None" = None,
) -> Image.Image:
    return process_keyed_figure(
        key_chroma(source), reference_height=reference_height, palette=palette
    )


def normalise_source_resolution(source: Image.Image, canvas_height: int = 1536) -> Image.Image:
    """Uniformly normalise ImageGen canvas resolution before shared-scale clips.

    This never changes pose proportions or framing.  It only makes a body height
    measured on an 887x1774 result comparable with one measured on a 1024x1536
    result, which is essential when the whole seated/stand chain shares a single
    source-to-native scale.
    """
    keyed = key_chroma(source)
    if keyed.height == canvas_height:
        return keyed
    width = max(1, round(keyed.width * canvas_height / keyed.height))
    return crunch.raster.premultiplied_resize(keyed, (width, canvas_height))


def load_source(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=True)


def _empty_runtime_cell() -> Image.Image:
    return stamp_sentinels(Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0)))


def split_upper_lower(cell: Image.Image, lap_fraction: float = 0.78) -> tuple[Image.Image, Image.Image]:
    """Derive the 16 NE compatibility layers without changing full-body art."""
    pixels = np.asarray(cell.convert("RGBA")).copy()
    alpha = pixels[..., 3]
    rows = np.where((alpha >= 16).any(axis=1))[0]
    if not len(rows):
        empty = _empty_runtime_cell()
        return empty.copy(), empty.copy()
    seam = int(rows.min()) + round((int(rows.max()) - int(rows.min())) * lap_fraction)
    upper = pixels.copy()
    upper[seam:, :, :] = 0
    lower = pixels.copy()
    lower[:seam, :, :] = 0
    upper_image = crunch.harden_alpha(Image.fromarray(upper, "RGBA"))
    lower_image = crunch.harden_alpha(Image.fromarray(lower, "RGBA"))
    return stamp_sentinels(upper_image), stamp_sentinels(lower_image)


def _load_keyed_body_sources(
    manifest: dict[str, Any]
) -> tuple[dict[tuple[str, str, int], Image.Image], list[MasterSpec]]:
    frames_root = V16_ROOT / manifest["source_root"]
    specs = master_specs(manifest)
    sources = {
        (spec.group, spec.direction, spec.phase): load_source(frames_root / spec.filename)
        for spec in specs
    }
    return sources, specs


def _save_atlas_cell(stage_root: Path, atlas: str, name: str, image: Image.Image) -> None:
    save_png(image, stage_root / atlas / name)


def _process_clip(
    keyed: Sequence[Image.Image], label: str, report: dict[str, Any]
) -> list[Image.Image]:
    """Process one animation against a single palette and a single exposure.

    A clip is the unit that has to be coherent: the frames are shown in sequence,
    so anything refitted per frame becomes visible motion. The ramps were refitted
    per frame, which is why a four-frame idle loop shipped 210 distinct colours
    instead of 64 and the wardrobe pulsed through it.

    Scale is deliberately *not* shared here. It was tried, both within a clip and
    across the idle/walk boundary, and measured worse: at 56 native rows the head
    is about six pixels across, so a correction of a few percent cannot survive
    quantisation — it rounds to the same six pixels, or to the wrong five. See
    `body_axis_x` for the registration half of the same resolution limit.
    """
    levelled, factors = crunch.normalise_clip_exposure(list(keyed))
    palette = crunch.build_clip_palette(levelled)
    report[label] = {
        "exposure_factors": [round(factor, 4) for factor in factors],
        "shared_palette": palette is not None,
    }
    return [
        process_keyed_figure(frame, palette=palette, body_axis=True) for frame in levelled
    ]


def build_stage_contents(manifest: dict[str, Any], stage_root: Path) -> dict[str, Any]:
    """Build all 208 files under a new, otherwise empty staging directory.

    Returns the per-clip scale report, whose `clamped_phases` name the masters
    that came back proportioned differently from the rest of their clip.
    """
    sources, _ = _load_keyed_body_sources(manifest)
    clip_report: dict[str, Any] = {}

    southwest_idle: dict[int, Image.Image] = {}
    for direction in WESTERN_DIRECTIONS:
        keyed = [
            key_chroma(sources[("standing_idle", direction, phase)]) for phase in range(4)
        ]
        cells = _process_clip(keyed, f"standing_idle:{direction}", clip_report)
        for phase, cell in enumerate(cells):
            _save_atlas_cell(
                stage_root,
                "VossIdle.atlas",
                f"voss_standing_idle_{direction}_{phase:02d}.png",
                cell,
            )
            if direction == "sw":
                southwest_idle[phase] = cell
    for phase, sw_cell in southwest_idle.items():
        se_cell = sw_cell.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        _save_atlas_cell(
            stage_root,
            "VossIdle.atlas",
            f"voss_standing_idle_se_{phase:02d}.png",
            se_cell,
        )

    for direction in WESTERN_DIRECTIONS:
        keyed = [key_chroma(sources[("walk", direction, phase)]) for phase in range(8)]
        cells = _process_clip(keyed, f"walk:{direction}", clip_report)
        for phase, cell in enumerate(cells):
            _save_atlas_cell(
                stage_root,
                "VossWalk.atlas",
                f"voss_walk_{direction}_{phase:02d}.png",
                cell,
            )

    empty = _empty_runtime_cell()
    for direction in SEAT_DIRECTIONS:
        stand_sources = [sources[("stand_up", direction, phase)] for phase in range(12)]
        idle_sources = [sources[("seated_idle", direction, phase)] for phase in range(8)]
        # The historical SE authoring cells face screen lower-left; the runtime
        # SE atlas is lower-right.  Mirror the authored chairless bodies before
        # the shared-scale crunch.  Standing idle SE is derived separately from
        # SW above and must never receive this second mirror.
        if direction == "se":
            stand_sources = [
                source.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for source in stand_sources
            ]
            idle_sources = [
                source.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for source in idle_sources
            ]
        stand_sources = [normalise_source_resolution(source) for source in stand_sources]
        idle_sources = [normalise_source_resolution(source) for source in idle_sources]
        stand_reference_height = source_opaque_height(stand_sources[-1])
        idle_cells = [
            process_keyed_figure(
                source,
                reference_height=stand_reference_height,
            )
            for source in idle_sources
        ]
        stand_cells = [
            process_keyed_figure(source, reference_height=stand_reference_height)
            for source in stand_sources
        ]
        sit_cells = list(reversed(stand_cells))

        for phase, cell in enumerate(idle_cells):
            _save_atlas_cell(
                stage_root,
                "VossSeatedIdle.atlas",
                f"voss_seated_idle_{direction}_{phase:02d}.png",
                cell,
            )
            if direction == "ne":
                upper, lower = split_upper_lower(cell)
                _save_atlas_cell(
                    stage_root,
                    "VossSeatedIdle.atlas",
                    f"voss_seated_upper_ne_{phase:02d}.png",
                    upper,
                )
                _save_atlas_cell(
                    stage_root,
                    "VossSeatedIdle.atlas",
                    f"voss_seated_lower_ne_{phase:02d}.png",
                    lower,
                )
            _save_atlas_cell(
                stage_root,
                "VossSeatedArms.atlas",
                f"voss_seated_arms_{direction}_{phase:02d}.png",
                empty,
            )

        for phase, cell in enumerate(stand_cells):
            _save_atlas_cell(
                stage_root,
                "VossSeatTransitions.atlas",
                f"voss_stand_up_{direction}_{phase:02d}.png",
                cell,
            )
        for phase, cell in enumerate(sit_cells):
            _save_atlas_cell(
                stage_root,
                "VossSeatTransitions.atlas",
                f"voss_sit_down_{direction}_{phase:02d}.png",
                cell,
            )

    return clip_report


def frame_metrics(image: Image.Image) -> FrameMetrics:
    mask = visible_mask(image)
    ys, xs = np.where(mask)
    if not len(xs):
        raise V16ValidationError("runtime frame contains no visible Voss pixels")
    x0, x1, y0, y1 = int(xs.min()), int(xs.max()), int(ys.min()), int(ys.max())
    height = y1 - y0 + 1
    head_rows = mask[y0 : y0 + max(1, height * 10 // 100)]
    head_xs = np.where(head_rows.any(axis=0))[0]
    if not len(head_xs):
        raise V16ValidationError("runtime frame has no measurable head band")
    torso_y0 = y0 + round(height * 0.28)
    torso_y1 = y0 + round(height * 0.62)
    torso_xs = np.where(mask[torso_y0:torso_y1].any(axis=0))[0]
    return FrameMetrics(
        width=x1 - x0 + 1,
        height=height,
        crown_y=y0,
        foot_y=y1,
        center_x=(x0 + x1) / 2,
        centroid_x=float(xs.mean()),
        centroid_y=float(ys.mean()),
        head_width=int(head_xs.max() - head_xs.min() + 1),
        head_center_x=float((head_xs.min() + head_xs.max()) / 2),
        torso_width=int(torso_xs.max() - torso_xs.min() + 1) if len(torso_xs) else 0,
    )


def intersection_over_union(first: Image.Image, second: Image.Image) -> float:
    first_mask, second_mask = visible_mask(first), visible_mask(second)
    union = int(np.logical_or(first_mask, second_mask).sum())
    return float(np.logical_and(first_mask, second_mask).sum() / max(1, union))


def foot_lead(image: Image.Image) -> str:
    """Screen-left/right planted-foot lead used by the existing V12 gait gate."""
    mask = visible_mask(image)
    ys, xs = np.where(mask)
    if not len(xs):
        return "?"
    y1, x0, x1 = int(ys.max()), int(xs.min()), int(xs.max())
    middle = (x0 + x1) // 2
    height = y1 - int(ys.min()) + 1
    band = mask.copy()
    band[: y1 - max(8, round(height * 0.12)), :] = False
    left, right = band.copy(), band.copy()
    left[:, middle:] = False
    right[:, :middle] = False
    left_y = int(np.where(left)[0].max()) if left.any() else -1
    right_y = int(np.where(right)[0].max()) if right.any() else -1
    if left_y < 0 and right_y < 0:
        return "?"
    if left_y < 0:
        return "R"
    if right_y < 0:
        return "L"
    if left_y > right_y + 2:
        return "L"
    if right_y > left_y + 2:
        return "R"
    return "="


def _load_stage_cell(stage_root: Path, atlas: str, name: str) -> Image.Image:
    with Image.open(stage_root / atlas / name) as image:
        return image.convert("RGBA").copy()


def _validate_raster_cell(path: Path, *, allow_empty: bool = False) -> tuple[list[str], FrameMetrics | None]:
    errors: list[str] = []
    try:
        with Image.open(path) as opened:
            mode = opened.mode
            image = opened.convert("RGBA").copy()
    except Exception as error:
        return [f"{path.name}: unreadable staged PNG ({error})"], None
    if mode != "RGBA":
        errors.append(f"{path.name}: mode {mode}, expected RGBA")
    if image.size != (FRAME_SIZE, FRAME_SIZE):
        errors.append(f"{path.name}: canvas {image.size}, expected 512x512")
        return errors, None
    alpha = np.asarray(image)[..., 3]
    corners = [int(alpha[0, 0]), int(alpha[0, -1]), int(alpha[-1, 0]), int(alpha[-1, -1])]
    if corners != [SENTINEL_ALPHA] * 4:
        errors.append(f"{path.name}: corner alpha {corners}, expected four alpha-1 sentinels")
    unexpected_alpha = sorted(set(np.unique(alpha).tolist()) - {0, 1, 255})
    if unexpected_alpha:
        errors.append(f"{path.name}: partial-alpha fringe values {unexpected_alpha[:12]}")
    mask = visible_mask(image)
    if not mask.any():
        if not allow_empty:
            errors.append(f"{path.name}: contains no visible body")
        return errors, None
    rgb = np.asarray(image)[..., :3][mask]
    colors = len(np.unique(rgb, axis=0))
    if colors > 64:
        errors.append(f"{path.name}: {colors} opaque colours, expected <=64 with no dithering")
    try:
        return errors, frame_metrics(image)
    except V16ValidationError as error:
        errors.extend(error.errors)
        return errors, None


def _parse_hex(value: str) -> np.ndarray:
    return np.asarray([int(value[index : index + 2], 16) for index in (1, 3, 5)], dtype=np.float64)


def _material_region(image: Image.Image, name: str) -> np.ndarray:
    mask = visible_mask(image)
    ys, xs = np.where(mask)
    y0, y1, x0, x1 = int(ys.min()), int(ys.max()), int(xs.min()), int(xs.max())
    yy, xx = np.indices(mask.shape)
    ry = (yy - y0) / max(1, y1 - y0)
    rx = (xx - x0) / max(1, x1 - x0)
    regions = {
        "hair": (ry <= 0.16) & (rx >= 0.20) & (rx <= 0.80),
        "skin": (ry <= 0.30) & (rx >= 0.12) & (rx <= 0.88),
        "shirt": (ry >= 0.16) & (ry <= 0.48) & (rx >= 0.26) & (rx <= 0.74),
        "tie": (ry >= 0.17) & (ry <= 0.53) & (rx >= 0.40) & (rx <= 0.60),
        "waistcoat": (ry >= 0.20) & (ry <= 0.60) & (rx >= 0.20) & (rx <= 0.80),
        "coat": (ry >= 0.18) & (ry <= 0.78),
        "trousers": (ry >= 0.55) & (ry <= 0.90),
        "shoes": ry >= 0.82,
    }
    return mask & regions[name]


def material_match_scores(image: Image.Image, wardrobe: dict[str, str]) -> dict[str, float]:
    pixels = np.asarray(image.convert("RGBA"))[..., :3].astype(np.float64)
    scores: dict[str, float] = {}
    for name, value in wardrobe.items():
        region = _material_region(image, name)
        sample = pixels[region]
        if not len(sample):
            scores[name] = math.inf
            continue
        target = _parse_hex(value)
        sample_chroma = sample / np.maximum(sample.sum(axis=1, keepdims=True), 1.0)
        target_chroma = target / target.sum()
        chroma = np.linalg.norm(sample_chroma - target_chroma, axis=1)
        value_delta = np.abs(np.log(np.maximum(sample.mean(axis=1), 1.0) / target.mean()))
        scores[name] = float(np.min(chroma + value_delta * 0.10))
    return scores


def _rear_forbidden_fraction(image: Image.Image, target_hex: str) -> float:
    pixels = np.asarray(image.convert("RGBA"))[..., :3].astype(np.float64)
    sample = pixels[visible_mask(image)]
    target = _parse_hex(target_hex)
    chroma = sample / np.maximum(sample.sum(axis=1, keepdims=True), 1.0)
    target_chroma = target / target.sum()
    close = np.linalg.norm(chroma - target_chroma, axis=1) < 0.035
    value_close = np.abs(np.log(np.maximum(sample.mean(axis=1), 1.0) / target.mean())) < 0.30
    return float((close & value_close).mean())


#: Clips whose frame-to-frame coherence is gated. The standing idle was absent
#: for four asset versions: the only thing measured about it was that every cell
#: was 198..202px tall, which the raster forces and so cannot fail.
#: Registration moved from the silhouette bbox to the body's mass centroid, so
#: the head's bbox midpoint is no longer pinned by construction and the honest
#: jitter is 5px rather than the 2px the old registration reported. The gate that
#: now carries the weight is CENTROID_DRIFT_MAX, which the same change took from
#: 4.95px to 0.85px on the walks. See `body_axis_x`.
HEAD_JITTER_MAX = 6.0
CENTROID_DRIFT_MAX = 2.0
HEAD_SCALE_RATIO_MAX = 1.12
TORSO_SCALE_RATIO_MAX = 1.18
CLIP_PALETTE_COLORS = 64

MOTION_CLIPS = (
    ("walk", "VossWalk.atlas", "voss_walk", 8),
    ("idle", "VossIdle.atlas", "voss_standing_idle", 4),
)


def _validate_motion(stage_root: Path, errors: list[str]) -> dict[str, Any]:
    report: dict[str, Any] = {}
    for group, atlas, stem, phases in MOTION_CLIPS:
        for direction in WESTERN_DIRECTIONS:
            cells = [
                _load_stage_cell(stage_root, atlas, f"{stem}_{direction}_{phase:02d}.png")
                for phase in range(phases)
            ]
            metrics = [frame_metrics(cell) for cell in cells]
            digests = [
                sha256(stage_root / atlas / f"{stem}_{direction}_{phase:02d}.png")
                for phase in range(phases)
            ]
            if len(set(digests)) != phases:
                errors.append(f"{group} {direction}: {phases} processed cells are not unique")
            head_jitter = max(metric.head_center_x for metric in metrics) - min(
                metric.head_center_x for metric in metrics
            )
            if head_jitter > HEAD_JITTER_MAX:
                errors.append(
                    f"{group} {direction}: head jitter {head_jitter:.1f}px, "
                    f"expected <={HEAD_JITTER_MAX}px"
                )
            centroid_drift = max(metric.centroid_x for metric in metrics) - min(
                metric.centroid_x for metric in metrics
            )
            if centroid_drift > CENTROID_DRIFT_MAX:
                errors.append(
                    f"{group} {direction}: body centroid drifts {centroid_drift:.2f}px, "
                    f"expected <={CENTROID_DRIFT_MAX}px"
                )
            head_scale = max(metric.head_width for metric in metrics) / min(
                metric.head_width for metric in metrics
            )
            if head_scale > HEAD_SCALE_RATIO_MAX:
                errors.append(
                    f"{group} {direction}: head scale pulses {head_scale:.3f}x "
                    f"(>{HEAD_SCALE_RATIO_MAX}x)"
                )
            torso_widths = [metric.torso_width for metric in metrics if metric.torso_width > 0]
            torso_scale = max(torso_widths) / min(torso_widths) if torso_widths else math.inf
            if torso_scale > TORSO_SCALE_RATIO_MAX:
                errors.append(
                    f"{group} {direction}: torso scale pulses {torso_scale:.3f}x "
                    f"(>{TORSO_SCALE_RATIO_MAX}x)"
                )

            # One palette per clip is the whole point of the shared fit: a loop that
            # carries more distinct colours than the palette has entries is one whose
            # frames were quantised apart, which is what made the wardrobe shift.
            clip_colours = set()
            for cell in cells:
                pixels = np.asarray(cell.convert("RGBA"))
                body = pixels[..., :3][pixels[..., 3] >= 128]
                if len(body):
                    clip_colours.update(map(tuple, np.unique(body.reshape(-1, 3), axis=0)))
            if len(clip_colours) > CLIP_PALETTE_COLORS:
                errors.append(
                    f"{group} {direction}: clip carries {len(clip_colours)} distinct colours "
                    f"across {phases} frames, expected <={CLIP_PALETTE_COLORS}"
                )

            adjacent = [
                intersection_over_union(cells[index], cells[(index + 1) % phases])
                for index in range(phases)
            ]
            entry: dict[str, Any] = {
                "head_jitter_px": round(head_jitter, 3),
                "centroid_drift_px": round(centroid_drift, 3),
                "head_scale_ratio": round(head_scale, 4),
                "torso_scale_ratio": round(torso_scale, 4),
                "clip_colours": len(clip_colours),
                "adjacent_iou": [round(value, 4) for value in adjacent],
            }

            if group == "walk":
                leads = "".join(foot_lead(cell) for cell in cells)
                if "L" not in leads or "R" not in leads:
                    errors.append(
                        f"walk {direction}: planted-foot sequence does not exchange L/R ({leads})"
                    )
                longest_run = 1
                run = 1
                previous: str | None = None
                for lead in leads:
                    if lead not in "LR":
                        previous = None
                        run = 1
                    elif lead == previous:
                        run += 1
                        longest_run = max(longest_run, run)
                    else:
                        previous = lead
                        run = 1
                if longest_run >= 4:
                    errors.append(
                        f"walk {direction}: planted-foot lead repeats {longest_run} cells ({leads})"
                    )
                closure_floor = min(0.55, float(np.median(adjacent[:-1])) * 0.75)
                if adjacent[-1] < closure_floor:
                    errors.append(
                        f"walk {direction}: loop closure IoU {adjacent[-1]:.3f}, "
                        f"expected >= {closure_floor:.3f}"
                    )
                entry["planted_foot_leads"] = leads

            report[f"{group}:{direction}"] = entry
    return report


def _validate_seat(stage_root: Path, errors: list[str]) -> dict[str, Any]:
    report: dict[str, Any] = {}
    standing_reference_name = {"ne": "voss_standing_idle_nw_00.png", "se": "voss_standing_idle_se_00.png"}
    for direction in SEAT_DIRECTIONS:
        idle = [
            _load_stage_cell(stage_root, "VossSeatedIdle.atlas", f"voss_seated_idle_{direction}_{i:02d}.png")
            for i in range(8)
        ]
        stand = [
            _load_stage_cell(stage_root, "VossSeatTransitions.atlas", f"voss_stand_up_{direction}_{i:02d}.png")
            for i in range(12)
        ]
        sit = [
            _load_stage_cell(stage_root, "VossSeatTransitions.atlas", f"voss_sit_down_{direction}_{i:02d}.png")
            for i in range(12)
        ]
        reference = _load_stage_cell(
            stage_root, "VossIdle.atlas", standing_reference_name[direction]
        )
        idle_metrics = [frame_metrics(cell) for cell in idle]
        stand_metrics = [frame_metrics(cell) for cell in stand]
        reference_metrics = frame_metrics(reference)
        neutral = idle_metrics[0]
        ious = [intersection_over_union(idle[0], cell) for cell in idle]
        centroid_drifts = [
            max(
                abs(metric.centroid_x - neutral.centroid_x),
                abs(metric.centroid_y - neutral.centroid_y),
            )
            for metric in idle_metrics
        ]
        if max(centroid_drifts) > 2.0:
            errors.append(f"seat {direction}: idle centroid drift {max(centroid_drifts):.2f}px (>2px)")
        if min(ious) < 0.86:
            errors.append(f"seat {direction}: neutral IoU {min(ious):.3f} (<0.86)")
        crown_retreat = max(
            (after.crown_y - before.crown_y for before, after in zip(stand_metrics, stand_metrics[1:])),
            default=0,
        )
        if crown_retreat > 4:
            errors.append(f"seat {direction}: adjacent crown retreats {crown_retreat}px (>4px)")
        total_rise = stand_metrics[0].crown_y - stand_metrics[-1].crown_y
        if not 38 <= total_rise <= 50:
            errors.append(f"seat {direction}: total rise {total_rise}px, expected 38...50px")
        head_widths = [metric.head_width for metric in idle_metrics + stand_metrics]
        if any(not 19 <= width <= 29 for width in head_widths):
            errors.append(f"seat {direction}: head widths {head_widths}, expected 19...29px")
        head_drift = max(head_widths) / min(head_widths)
        if head_drift > 1.30:
            errors.append(f"seat {direction}: head width drift {head_drift:.3f}x (>1.30x)")
        if abs(stand_metrics[0].height - idle_metrics[0].height) > 3:
            errors.append(f"seat {direction}: stand-up 00 does not hand off from seated neutral")
        if abs(stand_metrics[-1].height - reference_metrics.height) > 2:
            errors.append(f"seat {direction}: stand-up 11 does not match standing reference scale")
        for index, cell in enumerate(sit):
            if not np.array_equal(np.asarray(cell), np.asarray(stand[11 - index])):
                errors.append(
                    f"seat {direction}: sit-down {index:02d} is not exact reverse of stand-up {11-index:02d}"
                )
        report[direction] = {
            "idle_centroid_drift_px": round(max(centroid_drifts), 3),
            "minimum_neutral_iou": round(min(ious), 4),
            "maximum_adjacent_crown_retreat_px": crown_retreat,
            "total_rise_px": total_rise,
            "head_widths": head_widths,
            "head_width_drift_ratio": round(head_drift, 4),
        }
    return report


def _validate_anchors(manifest: dict[str, Any], errors: list[str]) -> dict[str, Any]:
    report: dict[str, Any] = {}
    bounds = manifest["gates"]["anchor_width_height_ratio"]
    for view in ("front", "back"):
        path = V16_ROOT / manifest["anchors_root"] / f"voss_anchor_{view}_chroma_v16.png"
        if not path.exists():
            errors.append(f"missing {view} anchor for processed shape gate")
            continue
        cell = process_figure(load_source(path))
        metrics = frame_metrics(cell)
        ratio = metrics.width / metrics.height
        report[view] = {"width": metrics.width, "height": metrics.height, "ratio": round(ratio, 4)}
        # At 56 native rows a single silhouette column becomes 3--4 texture
        # pixels.  Permit one 200px texture column at either boundary while
        # retaining/reporting the exact ratio (79/200=.395 rounds to approx .40).
        raster_tolerance = 1.0 / metrics.height
        if not float(bounds[0]) - raster_tolerance <= ratio <= float(bounds[1]) + raster_tolerance:
            errors.append(
                f"{view} anchor width/body-height ratio {ratio:.3f}, expected {bounds[0]:.2f}...{bounds[1]:.2f}"
            )
    return report


def validate_staging(stage_root: Path, manifest: dict[str, Any]) -> dict[str, Any]:
    """Run all machine-checkable gates against a complete staged atlas set."""
    errors: list[str] = []
    expected = expected_runtime_names()
    for atlas, names in expected.items():
        directory = stage_root / atlas
        actual = {path.name for path in directory.glob("*.png")} if directory.exists() else set()
        expected_set = set(names)
        missing, unexpected = sorted(expected_set - actual), sorted(actual - expected_set)
        if missing:
            errors.append(f"{atlas}: missing {len(missing)} staged files: {', '.join(missing[:5])}")
        if unexpected:
            errors.append(f"{atlas}: unexpected staged files: {', '.join(unexpected[:5])}")

    # Deeper gates assume the complete fixed filename set.  Stop here with an
    # actionable inventory error instead of cascading into FileNotFoundError.
    _fail_if(errors)

    raster_metrics: dict[str, dict[str, Any]] = {}
    for atlas, names in expected.items():
        for name in names:
            path = stage_root / atlas / name
            if not path.exists():
                continue
            allow_empty = atlas == "VossSeatedArms.atlas"
            cell_errors, metrics = _validate_raster_cell(path, allow_empty=allow_empty)
            errors.extend(cell_errors)
            if metrics is not None:
                raster_metrics[f"{atlas}/{name}"] = {
                    "width": metrics.width,
                    "height": metrics.height,
                    "foot_y": metrics.foot_y,
                    "center_x": metrics.center_x,
                    "head_width": metrics.head_width,
                }

    _fail_if(errors)

    # Primary standing/walk cells are all independently normalised to 200px.
    #
    # These are registered on body mass, not on the silhouette bbox, so the bbox
    # centre is deliberately allowed to sit off-centre — a walking figure with a
    # leg and an arm thrown forward has its bbox ahead of its body, and centring
    # that bbox is what put the body off-centre in the first place. The tight
    # centring gate for these cells is the per-clip centroid drift in
    # `_validate_motion`; what remains here is a sanity bound.
    for atlas in ("VossIdle.atlas", "VossWalk.atlas"):
        for name in expected[atlas]:
            metrics = raster_metrics.get(f"{atlas}/{name}")
            if metrics is None:
                continue
            if not 198 <= metrics["height"] <= 202:
                errors.append(f"{name}: standing height {metrics['height']}, expected 198...202px")
            if metrics["foot_y"] != VISIBLE_FOOT_ROW:
                errors.append(f"{name}: feet row {metrics['foot_y']}, expected 433")
            if abs(metrics["center_x"] - 255.5) > BODY_AXIS_BBOX_TOLERANCE:
                errors.append(
                    f"{name}: bbox center {metrics['center_x']:.1f}, "
                    f"expected within {BODY_AXIS_BBOX_TOLERANCE}px"
                )

    for direction in SEAT_DIRECTIONS:
        for phase in range(8):
            name = f"voss_seated_idle_{direction}_{phase:02d}.png"
            metrics = raster_metrics.get(f"VossSeatedIdle.atlas/{name}")
            if metrics is not None:
                if not 150 <= metrics["height"] <= 160:
                    errors.append(f"{name}: seated height {metrics['height']}, expected 150...160px")
                if metrics["foot_y"] != VISIBLE_FOOT_ROW:
                    errors.append(f"{name}: feet row {metrics['foot_y']}, expected 433")
                if abs(metrics["center_x"] - 255.5) > 2.0:
                    errors.append(f"{name}: bbox center {metrics['center_x']:.1f}, expected within 2px")
        for motion in ("stand_up", "sit_down"):
            for phase in range(12):
                name = f"voss_{motion}_{direction}_{phase:02d}.png"
                metrics = raster_metrics.get(f"VossSeatTransitions.atlas/{name}")
                if metrics is None:
                    continue
                if metrics["foot_y"] != VISIBLE_FOOT_ROW:
                    errors.append(f"{name}: feet row {metrics['foot_y']}, expected 433")
                if abs(metrics["center_x"] - 255.5) > 2.0:
                    errors.append(f"{name}: bbox center {metrics['center_x']:.1f}, expected within 2px")

    # Derivations must be pixel identities, not visual approximations.
    for phase in range(4):
        sw = _load_stage_cell(stage_root, "VossIdle.atlas", f"voss_standing_idle_sw_{phase:02d}.png")
        se = _load_stage_cell(stage_root, "VossIdle.atlas", f"voss_standing_idle_se_{phase:02d}.png")
        if not np.array_equal(np.asarray(se), np.asarray(sw.transpose(Image.Transpose.FLIP_LEFT_RIGHT))):
            errors.append(f"idle SE {phase:02d} is not the exact mirror of SW")

    for direction in SEAT_DIRECTIONS:
        for phase in range(8):
            arms = _load_stage_cell(
                stage_root, "VossSeatedArms.atlas", f"voss_seated_arms_{direction}_{phase:02d}.png"
            )
            if visible_mask(arms).any():
                errors.append(f"seated arms {direction} {phase:02d} is not transparent")

    shape_report = _validate_anchors(manifest, errors)
    wardrobe_report: dict[str, Any] = {}
    for direction in ("s", "ssw", "sw"):
        cell = _load_stage_cell(
            stage_root, "VossIdle.atlas", f"voss_standing_idle_{direction}_00.png"
        )
        spread = crunch.material_hue_spread(cell)
        wardrobe_report[f"processed_hue_spread_{direction}"] = round(spread, 4)
        if spread < float(manifest["gates"]["processed_front_hue_spread_min"]):
            errors.append(f"processed {direction} key hue spread {spread:.3f}, expected >=0.18")
    front = _load_stage_cell(stage_root, "VossIdle.atlas", "voss_standing_idle_s_00.png")
    material_scores = material_match_scores(front, manifest["wardrobe"])
    wardrobe_report["front_material_scores"] = {
        name: round(score, 4) for name, score in material_scores.items()
    }
    for name, score in material_scores.items():
        if score > 0.18:
            errors.append(f"front key has no material-specific {name} palette sample (score {score:.3f})")
    rear = _load_stage_cell(stage_root, "VossIdle.atlas", "voss_standing_idle_n_00.png")
    rear_forbidden = {
        name: _rear_forbidden_fraction(rear, manifest["wardrobe"][name])
        for name in ("shirt", "tie")
    }
    wardrobe_report["rear_forbidden_fraction"] = {
        name: round(value, 6) for name, value in rear_forbidden.items()
    }
    for name, fraction in rear_forbidden.items():
        if fraction > 0.001:
            errors.append(f"rear key paints {name} onto the back ({fraction * 100:.3f}% of body)")

    motion_report = _validate_motion(stage_root, errors)
    seat_report = _validate_seat(stage_root, errors)

    _fail_if(errors)
    output_hashes = {
        f"{atlas}/{name}": sha256(stage_root / atlas / name)
        for atlas, names in expected.items()
        for name in names
    }
    return {
        "status": "passed",
        "asset_version": "v16",
        "counts": {
            "primary_body_presentations": 176,
            "runtime_pngs": len(output_hashes),
            "transparent_seated_arms": 16,
            "compatibility_layers": 16,
        },
        "shape": shape_report,
        "wardrobe": wardrobe_report,
        "motion": motion_report,
        "seat": seat_report,
        "output_hashes": output_hashes,
        "manual_review_required": [
            "At least 12 of 16 unlabeled displayed facings are recognizable.",
            "SW walk has stable planted feet and a clean 0.25x first/last loop.",
            "Office seated preview contains exactly one world-owned chair.",
            "Identity, coat fit, gait phase, and chroma edges remain stable by eye.",
        ],
    }


def replace_directory_transactionally(new_directory: Path, destination: Path) -> None:
    """Atomically replace one generated staging directory, retaining rollback."""
    old = destination.with_name(f".{destination.name}.old-{uuid.uuid4().hex}")
    had_old = destination.exists()
    try:
        if had_old:
            os.replace(destination, old)
        os.replace(new_directory, destination)
    except Exception:
        if had_old and old.exists() and not destination.exists():
            os.replace(old, destination)
        raise
    else:
        if old.exists():
            shutil.rmtree(old)


def build_staging(manifest: dict[str, Any]) -> tuple[Path, dict[str, Any]]:
    source_report = validate_sources(manifest, include_all=True)
    staging = V16_ROOT / manifest["staging_root"]
    temporary = staging.with_name(f".{staging.name}.build-{uuid.uuid4().hex}")
    temporary.mkdir(parents=True, exist_ok=False)
    try:
        build_stage_contents(manifest, temporary)
        gate_report = validate_staging(temporary, manifest)
        report = {
            **gate_report,
            "manifest_sha256": sha256(MANIFEST_PATH),
            "source": source_report,
            "built_at_utc": datetime.now(timezone.utc).isoformat(),
        }
        write_json(temporary / "voss_v16_stage_report.json", report)
        replace_directory_transactionally(temporary, staging)
    except Exception:
        if temporary.exists():
            shutil.rmtree(temporary)
        raise
    return staging, report


def _copy_file_without_metadata(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, destination)


def backup_runtime_atlases() -> Path:
    timestamp = datetime.now(timezone.utc).strftime("v16-%Y%m%dT%H%M%SZ")
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
                raise V16ValidationError(f"cannot back up missing runtime atlas {source_dir}")
            for source in sorted(source_dir.glob("*.png")):
                destination = temporary / atlas / source.name
                _copy_file_without_metadata(source, destination)
                hashes[f"{atlas}/{source.name}"] = sha256(destination)
        write_json(
            temporary / "backup_manifest.json",
            {
                "asset_version": "v16",
                "captured_at_utc": datetime.now(timezone.utc).isoformat(),
                "source": str(RUNTIME_ATLASES.relative_to(ROOT)),
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


def _assert_tree_hashes(root: Path, expected_hashes: dict[str, str]) -> None:
    errors = [
        f"hash mismatch after copy: {relative}"
        for relative, expected in expected_hashes.items()
        if not (root / relative).is_file() or sha256(root / relative) != expected
    ]
    _fail_if(errors)


def install_runtime_transaction(stage_root: Path, report: dict[str, Any]) -> Path:
    """Swap all five Voss atlas folders, rolling every prior swap back on error."""
    validate_staging(stage_root, load_manifest())
    expected_hashes: dict[str, str] = report["output_hashes"]
    _assert_tree_hashes(stage_root, expected_hashes)

    token = uuid.uuid4().hex
    prepared: dict[str, Path] = {}
    retired: dict[str, Path] = {}
    try:
        for atlas in RUNTIME_ATLAS_ORDER:
            destination = RUNTIME_ATLASES / atlas
            prepared_dir = destination.with_name(f".{atlas}.v16-new-{token}")
            prepared_dir.mkdir(parents=True, exist_ok=False)
            for source in sorted((stage_root / atlas).glob("*.png")):
                _copy_file_without_metadata(source, prepared_dir / source.name)
            prepared[atlas] = prepared_dir
            retired[atlas] = destination.with_name(f".{atlas}.v16-old-{token}")

        _assert_tree_hashes(
            RUNTIME_ATLASES,
            {
                relative.replace(atlas + "/", prepared[atlas].name + "/", 1): digest
                for relative, digest in expected_hashes.items()
                for atlas in RUNTIME_ATLAS_ORDER
                if relative.startswith(atlas + "/")
            },
        )
        backup = backup_runtime_atlases()
    except Exception:
        for directory in prepared.values():
            if directory.exists():
                shutil.rmtree(directory)
        raise

    try:
        for atlas in RUNTIME_ATLAS_ORDER:
            destination = RUNTIME_ATLASES / atlas
            os.replace(destination, retired[atlas])
            os.replace(prepared[atlas], destination)
        _assert_tree_hashes(RUNTIME_ATLASES, expected_hashes)
    except Exception:
        # Include an atlas whose old directory was retired but whose new rename
        # failed before the replacement reached its destination.
        for atlas in reversed(RUNTIME_ATLAS_ORDER):
            destination = RUNTIME_ATLASES / atlas
            if retired[atlas].exists():
                failed = destination.with_name(f".{atlas}.v16-failed-{token}")
                if destination.exists():
                    os.replace(destination, failed)
                os.replace(retired[atlas], destination)
                if failed.exists():
                    shutil.rmtree(failed)
        raise
    finally:
        for directory in prepared.values():
            if directory.exists():
                shutil.rmtree(directory)

    for directory in retired.values():
        if directory.exists():
            shutil.rmtree(directory)
    return backup


def _print_validation_error(error: V16ValidationError) -> None:
    print(f"V16 validation failed ({len(error.errors)} issue(s)):", file=sys.stderr)
    for issue in error.errors:
        print(f" - {issue}", file=sys.stderr)


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("validate-proof", help="validate anchors and the eight-frame SW proof")
    subparsers.add_parser("validate", help="validate all 148 masters without writing outputs")
    subparsers.add_parser("stage", help="build and gate all 208 PNGs under PreRendered3DV16/Staging")
    install_parser = subparsers.add_parser("install", help="stage, back up, and replace runtime Voss atlases")
    install_parser.add_argument(
        "--confirm-runtime-replace",
        metavar="V16",
        help="required literal confirmation; staging remains the default safe operation",
    )
    args = parser.parse_args(argv)

    try:
        manifest = load_manifest()
        if args.command == "validate-proof":
            report = validate_sources(manifest, include_all=False)
            print(
                f"V16 proof inputs passed: {report['masters_validated']} SW walk cells, "
                f"{report['anchors_validated']} anchors"
            )
        elif args.command == "validate":
            report = validate_sources(manifest, include_all=True)
            print(
                f"V16 source validation passed: {report['masters_validated']} body masters, "
                f"{report['anchors_validated']} anchors; runtime untouched"
            )
        elif args.command == "stage":
            staging, report = build_staging(manifest)
            print(
                f"V16 staging passed: {report['counts']['runtime_pngs']} PNGs at "
                f"{staging.relative_to(ROOT)}; runtime untouched"
            )
        elif args.command == "install":
            if args.confirm_runtime_replace != "V16":
                parser.error("install requires --confirm-runtime-replace V16")
            staging, report = build_staging(manifest)
            backup = install_runtime_transaction(staging, report)
            print(
                f"V16 installed transactionally; prior runtime saved at {backup.relative_to(ROOT)}"
            )
    except V16ValidationError as error:
        _print_validation_error(error)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

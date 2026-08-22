#!/usr/bin/env python3
"""Build the office door family from a native-detail V12 edge master.

The room reference is the visual target, but its door is only a handful of
pixels wide.  Enlarging those pixels produced a broad, blurry floor-like slab
in game.  This pass maps a purpose-made high-resolution transparent master into
the existing V11 hinge/canvas registration and keeps the leaf deliberately
thin.  Mid/open states compress the same leaf toward the fixed hinge.
"""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
REFERENCE = ROOT / "ArtSource/Reference/Office/V12/office_target_reference.png"
GEOMETRY_PATH = ROOT / "ArtSource/Generated/Office/BGEE1950sV11/office_v11_geometry.json"
OUT = ROOT / "ArtSource/Generated/Office/BGEEReferenceV12/Props"
NATIVE_MASTER = OUT / "office_door_native_source_v12.png"

REFERENCE_SHA256 = "6fbb06a6bf54e821bcdf7ae5e86aecc998ed594b4869c79dbc78bb41d770bd19"
REFERENCE_SIZE = (1613, 975)
NATIVE_MASTER_SHA256 = "46111c6527a8b4e179614d2cd2d08c322d8c053de03a6cc5bee1de38ccc6991a"
NATIVE_MASTER_SIZE = (1536, 1024)
DISPLAY_SCALE = 0.28
TARGET_TEXTURE_THICKNESS = 34.0


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _opaque_bounds(image: Image.Image) -> list[int]:
    alpha = np.asarray(image.getchannel("A"), dtype=np.uint8)
    ys, xs = np.where(alpha > 16)
    if not len(xs):
        raise RuntimeError("door state contains no visible pixels")
    return [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]


def _actual_thickness(
    image: Image.Image, hinge: np.ndarray, direction: np.ndarray
) -> float:
    alpha = np.asarray(image.getchannel("A"), dtype=np.uint8)
    ys, xs = np.where(alpha > 32)
    points = np.column_stack((xs, ys)).astype(float)
    offsets = points - hinge
    along = offsets @ direction
    normal = np.asarray([-direction[1], direction[0]])
    across = offsets @ normal
    middle = (along >= along.max() * 0.35) & (along <= along.max() * 0.65)
    return float(across[middle].max() - across[middle].min())


def _closed_native_image(geometry: dict[str, object]) -> Image.Image:
    """Register the high-resolution edge master to the existing live hinge."""
    door = geometry["door"]
    reference = Image.open(REFERENCE)
    if reference.size != REFERENCE_SIZE or sha256(REFERENCE) != REFERENCE_SHA256:
        raise RuntimeError("the approved V12 room reference identity changed")
    source = Image.open(NATIVE_MASTER).convert("RGBA")
    if source.size != NATIVE_MASTER_SIZE or sha256(NATIVE_MASTER) != NATIVE_MASTER_SHA256:
        raise RuntimeError("the approved native V12 door master identity changed")

    alpha = np.asarray(source.getchannel("A"), dtype=np.uint8)
    ys, xs = np.where(alpha > 24)
    points = np.column_stack((xs, ys)).astype(np.float64)
    center = points.mean(axis=0)
    _, eigenvectors = np.linalg.eigh(np.cov(points.T))
    source_direction = eigenvectors[:, -1]
    if source_direction[0] > 0:
        source_direction *= -1
    source_normal = np.asarray(
        [-source_direction[1], source_direction[0]], dtype=np.float64
    )
    along = (points - center) @ source_direction
    across = (points - center) @ source_normal
    source_start = float(np.quantile(along, 0.01))
    source_end = float(np.quantile(along, 0.99))
    source_hinge_across = float(np.median(across[along <= np.quantile(along, 0.03)]))
    source_hinge = (
        center
        + source_direction * source_start
        + source_normal * source_hinge_across
    )
    source_axis_length = source_end - source_start

    canvas = tuple(int(value) for value in door["liveCanvas"])
    hinge = np.asarray(door["hingePixels"], dtype=np.float64)
    plate_hinge = np.asarray(door["targetHinge"], dtype=np.float64)
    plate_free = np.asarray(door["targetFreeEnd"], dtype=np.float64)
    target_vector = plate_free - plate_hinge
    target_length = float(np.linalg.norm(target_vector))
    target_direction = target_vector / target_length
    target_normal = np.asarray([-target_direction[1], target_direction[0]])
    along_scale = target_length / source_axis_length
    across_scale = TARGET_TEXTURE_THICKNESS / float(np.quantile(across, 0.99) - np.quantile(across, 0.01))

    # Pillow's affine matrix maps output coordinates back into source space.
    matrix = (
        np.outer(source_direction, target_direction) / along_scale
        + np.outer(source_normal, target_normal) / across_scale
    )
    offset = source_hinge - matrix @ hinge
    image = source.transform(
        canvas,
        Image.Transform.AFFINE,
        (
            matrix[0, 0],
            matrix[0, 1],
            offset[0],
            matrix[1, 0],
            matrix[1, 1],
            offset[1],
        ),
        resample=Image.Resampling.BICUBIC,
    )
    rgba = np.asarray(image, dtype=np.uint8).copy()
    rgba[:, :, 3] = np.where(rgba[:, :, 3] >= 3, rgba[:, :, 3], 0)
    # Match the quiet values of the approved room sliver. The native master
    # carries the detail, while this grade settles it into the dim cutaway.
    rgba[:, :, :3] = np.clip(
        rgba[:, :, :3].astype(np.float32) * 0.72, 0.0, 255.0
    ).astype(np.uint8)
    rgba[:, :, :3] = np.where((rgba[:, :, 3] > 0)[..., None], rgba[:, :, :3], 0)
    return Image.fromarray(rgba, "RGBA")


def _compressed_state(
    closed: Image.Image,
    hinge: np.ndarray,
    direction: np.ndarray,
    ratio: float,
) -> Image.Image:
    """Shorten along the registered axis while retaining both painted caps."""
    if abs(ratio - 1.0) < 1e-12:
        return closed.copy()
    normal = np.asarray([-direction[1], direction[0]], dtype=np.float64)
    matrix = np.outer(normal, normal) + np.outer(direction, direction) / ratio
    offset = hinge - matrix @ hinge
    image = closed.transform(
        closed.size,
        Image.Transform.AFFINE,
        (
            matrix[0, 0],
            matrix[0, 1],
            offset[0],
            matrix[1, 0],
            matrix[1, 1],
            offset[1],
        ),
        resample=Image.Resampling.BICUBIC,
    )
    rgba = np.asarray(image, dtype=np.uint8).copy()
    rgba[:, :, 3] = np.where(rgba[:, :, 3] >= 3, rgba[:, :, 3], 0)
    rgba[:, :, :3] = np.where((rgba[:, :, 3] > 0)[..., None], rgba[:, :, :3], 0)
    return Image.fromarray(rgba, "RGBA")


def _hover(image: Image.Image) -> Image.Image:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.uint8).copy()
    alpha = rgba[:, :, 3].copy()
    visible = alpha > 16
    rgb = rgba[:, :, :3].astype(np.float32)
    rgb = np.clip(
        rgb * np.asarray([0.92, 1.07, 1.09]) + np.asarray([2.0, 18.0, 21.0]),
        0.0,
        255.0,
    )
    padded = np.pad(visible, 1, mode="constant")
    eroded = np.stack(
        (
            padded[1:-1, :-2],
            padded[1:-1, 2:],
            padded[:-2, 1:-1],
            padded[2:, 1:-1],
        ),
        axis=0,
    ).all(axis=0)
    rim = visible & ~eroded
    rgb[rim] = np.asarray([16.0, 238.0, 242.0])
    rgba[:, :, :3] = np.where(visible[..., None], rgb, 0).astype(np.uint8)
    rgba[:, :, 3] = alpha
    return Image.fromarray(rgba, "RGBA")


def build_assets() -> tuple[dict[str, Image.Image], dict[str, object]]:
    geometry = json.loads(GEOMETRY_PATH.read_text(encoding="utf-8"))
    door = geometry["door"]
    hinge = np.asarray(door["hingePixels"], dtype=np.float64)
    plate_hinge = np.asarray(door["targetHinge"], dtype=np.float64)
    plate_free = np.asarray(door["targetFreeEnd"], dtype=np.float64)
    closed_vector = plate_free - plate_hinge
    closed_length = float(np.linalg.norm(closed_vector))
    direction = closed_vector / closed_length
    ratios = door["stateLengthRatios"]
    closed = _closed_native_image(geometry)
    images: dict[str, Image.Image] = {}
    states: dict[str, object] = {}
    for state in ("closed", "mid", "open"):
        ratio = float(ratios[state])
        image = _compressed_state(closed, hinge, direction, ratio)
        images[state] = image
        images[state + "Hover"] = _hover(image)
        image_free = hinge + direction * closed_length * ratio
        plate_free_for_state = plate_hinge + closed_vector * ratio
        states[state] = {
            "file": f"office_door_leaf_{state}_v12.png",
            "hoverFile": f"office_door_leaf_{state}_hover_v12.png",
            "lengthRatio": ratio,
            "registeredImageAxisEndpoints": [hinge.tolist(), image_free.tolist()],
            "registeredPlateAxisEndpoints": [plate_hinge.tolist(), plate_free_for_state.tolist()],
            "opaqueBounds": _opaque_bounds(image),
            "actualTextureThickness": round(
                _actual_thickness(image, hinge, direction), 3
            ),
        }
    family = {
        "version": "BGEEReferenceV12",
        "canvas": door["liveCanvas"],
        "hingeImageXY": door["hingePixels"],
        "anchorFromBottomLeft": door["anchor"],
        "displayScale": DISPLAY_SCALE,
        "plateHinge": door["targetHinge"],
        "closedPlateFreeEnd": door["targetFreeEnd"],
        "angleDegrees": door["targetAngleDegrees"],
        "maximumTextureThickness": TARGET_TEXTURE_THICKNESS,
        "source": {
            "file": str(NATIVE_MASTER.relative_to(ROOT)),
            "sha256": NATIVE_MASTER_SHA256,
            "visualTargetFile": str(REFERENCE.relative_to(ROOT)),
            "visualTargetSha256": REFERENCE_SHA256,
            "pixelPolicy": "native-resolution transparent master fitted to the approved thin door edge",
        },
        "stateSemantics": "closed is the full native edge master; mid/open compress it toward the fixed hinge",
        "states": states,
    }
    return images, family


def write_assets(output_dir: Path = OUT) -> dict[str, Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    images, family = build_assets()
    paths: dict[str, Path] = {}
    for state in ("closed", "mid", "open"):
        base = output_dir / f"office_door_leaf_{state}_v12.png"
        hover = output_dir / f"office_door_leaf_{state}_hover_v12.png"
        images[state].save(base, format="PNG", optimize=False)
        images[state + "Hover"].save(hover, format="PNG", optimize=False)
        paths[state] = base
        paths[state + "Hover"] = hover
    family["outputHashes"] = {path.name: sha256(path) for path in paths.values()}
    family_path = output_dir / "office_door_family_v12.json"
    family_path.write_text(json.dumps(family, indent=2) + "\n", encoding="utf-8")
    paths["family"] = family_path
    return paths


def main() -> None:
    for path in write_assets().values():
        print(f"wrote {path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

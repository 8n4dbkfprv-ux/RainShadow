#!/usr/bin/env python3
"""Build the office door family from the user-approved V12 reference pixels.

The door is only a few pixels wide in the supplied room image.  Repainting it
as several full-width boards made it read as a detached beam.  This pass keeps
the existing V11 hinge/canvas/runtime registration, but uniformly maps the
actual reference sliver into that registration.  Mid/open states compress the
same leaf along its axis, so the hinge, free-end cap, surface, and silhouette
remain one coherent object.
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

REFERENCE_SHA256 = "6fbb06a6bf54e821bcdf7ae5e86aecc998ed594b4869c79dbc78bb41d770bd19"
REFERENCE_SIZE = (1613, 975)


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


def _reference_alpha(
    rgb: np.ndarray,
    source_hinge: np.ndarray,
    source_free: np.ndarray,
    source_bbox: list[float],
) -> np.ndarray:
    """Key the isolated sliver from black without admitting the nearby floor.

    The 26.8px corridor is the measured reference thickness.  The bbox is a
    second lock: it prevents bicubic ringing from pulling floor-edge pixels
    into the separately rendered leaf at its hinge.
    """
    vector = source_free - source_hinge
    length = float(np.linalg.norm(vector))
    direction = vector / length
    normal = np.asarray([-direction[1], direction[0]], dtype=np.float64)
    yy, xx = np.indices(rgb.shape[:2])
    offsets = np.stack((xx - source_hinge[0], yy - source_hinge[1]), axis=-1)
    along = offsets @ direction
    across = offsets @ normal
    x0, y0, x1, y1 = source_bbox
    bbox = (xx >= x0) & (xx <= x1) & (yy >= y0) & (yy <= y1)
    corridor = (
        (along >= -3.0)
        & (along <= length + 4.0)
        & (across >= -13.4)
        & (across <= 13.4)
    )
    # The exterior is near-pure black.  A short ramp retains the door's dark
    # antialiased outline while making the surrounding cutaway truly clear.
    value = rgb.max(axis=2).astype(np.float32)
    return np.where(
        bbox & corridor,
        np.clip((value - 2.0) * 52.0, 0.0, 255.0),
        0.0,
    ).astype(np.uint8)


def _closed_reference_image(geometry: dict[str, object]) -> Image.Image:
    door = geometry["door"]
    reference = Image.open(REFERENCE).convert("RGB")
    if reference.size != REFERENCE_SIZE or sha256(REFERENCE) != REFERENCE_SHA256:
        raise RuntimeError("the approved V12 room reference identity changed")
    rgb = np.asarray(reference, dtype=np.uint8)
    source_hinge = np.asarray(door["sourceHinge"], dtype=np.float64)
    source_free = np.asarray(door["sourceFreeEnd"], dtype=np.float64)
    alpha = _reference_alpha(rgb, source_hinge, source_free, door["sourceBBox"])
    source = Image.fromarray(np.dstack((rgb, alpha)), "RGBA")

    canvas = tuple(int(value) for value in door["liveCanvas"])
    hinge = np.asarray(door["hingePixels"], dtype=np.float64)
    scale = float(geometry["referenceTransform"]["uniformScale"])
    affine = (
        1.0 / scale,
        0.0,
        source_hinge[0] - hinge[0] / scale,
        0.0,
        1.0 / scale,
        source_hinge[1] - hinge[1] / scale,
    )
    image = source.transform(
        canvas,
        Image.Transform.AFFINE,
        affine,
        resample=Image.Resampling.BICUBIC,
    )

    # The measured source bbox is the hard silhouette authority.  Clipping
    # only bicubic ringing keeps the output bounds identical to the registered
    # reference while retaining antialiasing inside them.
    plate_hinge = np.asarray(door["targetHinge"], dtype=np.float64)
    source_bbox = np.asarray(door["targetBBox"], dtype=np.float64)
    local_bbox = source_bbox - np.asarray(
        [plate_hinge[0], plate_hinge[1], plate_hinge[0], plate_hinge[1]]
    ) + np.asarray([hinge[0], hinge[1], hinge[0], hinge[1]])
    allowed = [
        int(math.ceil(local_bbox[0])),
        int(math.ceil(local_bbox[1])),
        int(math.floor(local_bbox[2])),
        int(math.floor(local_bbox[3])),
    ]
    rgba = np.asarray(image, dtype=np.uint8).copy()
    yy, xx = np.indices((canvas[1], canvas[0]))
    keep = (
        (xx >= allowed[0])
        & (xx <= allowed[2])
        & (yy >= allowed[1])
        & (yy <= allowed[3])
    )
    rgba[:, :, 3] = np.where(keep & (rgba[:, :, 3] >= 3), rgba[:, :, 3], 0)
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
    closed = _closed_reference_image(geometry)
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
        }
    family = {
        "version": "BGEEReferenceV12",
        "canvas": door["liveCanvas"],
        "hingeImageXY": door["hingePixels"],
        "anchorFromBottomLeft": door["anchor"],
        "displayScale": door["displayScale"],
        "plateHinge": door["targetHinge"],
        "closedPlateFreeEnd": door["targetFreeEnd"],
        "angleDegrees": door["targetAngleDegrees"],
        "maximumThickness": door["targetThickness"],
        "source": {
            "file": str(REFERENCE.relative_to(ROOT)),
            "sha256": REFERENCE_SHA256,
            "bbox": door["sourceBBox"],
            "hinge": door["sourceHinge"],
            "freeEnd": door["sourceFreeEnd"],
            "pixelPolicy": "uniformly transformed user-approved door pixels; nearby floor excluded",
        },
        "stateSemantics": "closed is the full reference sliver; mid/open compress it toward the fixed hinge",
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

#!/usr/bin/env python3
"""Verify the installed V12 reference-faithful entrance family.

The surviving entrance is a registered closed/mid/open edge silhouette. V12
keeps the V11 geometry and state semantics but replaces the procedural broad
boards with pixels uniformly extracted from the approved room reference.
"""

from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image

import office_layout_plan as layout
import office_room_plan as room


ROOT = Path(__file__).resolve().parents[2]
PROPS = ROOT / "RainShadow Shared/Resources/Art/Props/Office"
AREA = ROOT / "RainShadow Shared/Resources/Art/Areas/DetectiveOffice"
FAMILY = ROOT / "ArtSource/Generated/Office/office_door_family_v12.json"

CANVAS = (512, 320)
HINGE = np.array((488.0, 18.0))
ANCHOR = (0.953125, 0.94375)
DISPLAY_SCALE = 0.395
PLATE_PER_WORLD = 1.0 / room.ENVIRONMENT_SCALE


def alpha_points(image: Image.Image) -> np.ndarray:
    alpha = np.asarray(image.convert("RGBA"))[:, :, 3]
    ys, xs = np.where(alpha > 16)
    if not len(xs):
        raise RuntimeError("door state is empty")
    return np.column_stack((xs, ys))


def content_extent(points: np.ndarray) -> tuple[int, int, int, int]:
    return (
        int(points[:, 0].min()),
        int(points[:, 1].min()),
        int(points[:, 0].max()) + 1,
        int(points[:, 1].max()) + 1,
    )


def pca_elongation(points: np.ndarray) -> float:
    values = np.linalg.eigvalsh(np.cov(points.astype(float).T))
    return math.sqrt(float(values[-1] / max(values[0], 1e-9)))


def hover_is_tint_only(base: Image.Image, hover: Image.Image) -> bool:
    a = np.asarray(base.convert("RGBA"))
    b = np.asarray(hover.convert("RGBA"))
    return np.array_equal(a[:, :, 3], b[:, :, 3]) and bool(
        np.any(a[:, :, :3] != b[:, :, :3])
    )


def black_under_open_fraction(plate: Image.Image, door: Image.Image) -> float:
    factor = DISPLAY_SCALE * PLATE_PER_WORLD
    scaled = door.resize(
        (round(door.width * factor), round(door.height * factor)),
        Image.Resampling.LANCZOS,
    )
    points = alpha_points(scaled)
    authored_x, authored_y = layout.exterior_leaf_anchor_authored()
    image_anchor_y = room.ART_H - authored_y
    left = round(authored_x - scaled.width * ANCHOR[0])
    top = round(image_anchor_y - scaled.height * (1.0 - ANCHOR[1]))
    xs = points[:, 0] + left
    ys = points[:, 1] + top
    rgb = np.asarray(plate.convert("RGB"))
    valid = (xs >= 0) & (xs < rgb.shape[1]) & (ys >= 0) & (ys < rgb.shape[0])
    underneath = rgb[ys[valid], xs[valid]].max(axis=1)
    return float((underneath < 8).mean())


def main() -> int:
    manifest = json.loads(FAMILY.read_text())
    checks: list[tuple[str, bool, str]] = []

    checks.append(("manifest canvas", tuple(manifest["canvas"]) == CANVAS, str(manifest["canvas"])))
    checks.append(("manifest hinge", np.allclose(manifest["hingeImageXY"], HINGE), str(manifest["hingeImageXY"])))
    checks.append(("manifest anchor", np.allclose(manifest["anchorFromBottomLeft"], ANCHOR), str(manifest["anchorFromBottomLeft"])))

    images: dict[str, Image.Image] = {}
    widths: dict[str, int] = {}
    points: dict[str, np.ndarray] = {}
    for state, runtime_name in (
        ("closed", "office_door_leaf.png"),
        ("mid", "office_door_leaf_mid.png"),
        ("open", "office_door_leaf_open.png"),
    ):
        image = Image.open(PROPS / runtime_name).convert("RGBA")
        images[state] = image
        points[state] = alpha_points(image)
        bbox = content_extent(points[state])
        widths[state] = bbox[2] - bbox[0]
        checks.append((f"{state} canvas", image.size == CANVAS, str(image.size)))
        hinge_distance = float(np.linalg.norm(points[state] - HINGE, axis=1).min())
        checks.append((f"{state} hinge registration", hinge_distance <= 8.0, f"{hinge_distance:.2f}px"))

    checks.append((
        "monotonic reference-state extents",
        widths["closed"] > widths["mid"] > widths["open"],
        f"{widths['closed']} > {widths['mid']} > {widths['open']}",
    ))
    elongation = pca_elongation(points["closed"])
    checks.append(("closed state is an edge sliver", elongation >= 4.5, f"PCA elongation {elongation:.2f}x"))

    closed_far = points["closed"][
        np.argmax(np.linalg.norm(points["closed"] - HINGE, axis=1))
    ].astype(float)
    checks.append((
        "full reference state projects lower-left",
        closed_far[0] < HINGE[0] - 390 and closed_far[1] > HINGE[1] + 280,
        f"hinge={tuple(HINGE)} far={tuple(closed_far)}",
    ))

    closed_length = float(np.linalg.norm(points["closed"] - HINGE, axis=1).max())
    registered_endpoints = np.asarray(
        manifest["states"]["closed"]["registeredImageAxisEndpoints"], dtype=float
    )
    registered_length = float(np.linalg.norm(registered_endpoints[1] - registered_endpoints[0]))
    checks.append((
        "reference axis length",
        abs(closed_length - registered_length) <= 12.0,
        f"visible={closed_length:.2f}px registered={registered_length:.2f}px",
    ))

    plate = Image.open(AREA / "office_suite_plate.png").convert("RGB")
    black_fraction = black_under_open_fraction(plate, images["open"])
    checks.append(("open silhouette lies over black", black_fraction >= 0.55, f"{black_fraction:.1%}"))

    checks.append((
        "closed hover is tint-only",
        hover_is_tint_only(images["closed"], Image.open(PROPS / "office_door_leaf_hover.png")),
        "identical alpha; changed colour",
    ))
    checks.append((
        "open hover is tint-only",
        hover_is_tint_only(images["open"], Image.open(PROPS / "office_door_leaf_open_hover.png")),
        "identical alpha; changed colour",
    ))

    retired = (
        "office_internal_door_leaf.png",
        "office_door_leaf_fallen.png",
        "office_door_leaf_thickness.png",
    )
    # Source masters may remain for provenance, so grade the active prop manifest
    # rather than requiring destructive deletion of old files.
    active_props = json.loads((ROOT / "ArtSource/Generated/Office/office_props_v01.json").read_text())
    active_textures = {prop["textureName"] for prop in active_props["props"]}
    checks.append((
        "retired door textures absent from active props",
        not active_textures.intersection({Path(name).stem for name in retired}),
        str(sorted(active_textures.intersection({Path(name).stem for name in retired}))),
    ))

    for name, passed, detail in checks:
        print(f"{'PASS' if passed else 'FAIL'}  {name}: {detail}")
    all_pass = all(passed for _, passed, _ in checks)
    print(f"\nALL_PASS={all_pass}")
    return 0 if all_pass else 1


if __name__ == "__main__":
    raise SystemExit(main())

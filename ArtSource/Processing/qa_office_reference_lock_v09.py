#!/usr/bin/env python3
"""Grade the immutable V09 room mask, projection points, and live door family."""

from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import office_room_plan as room
import generate_office_cramped_bgee_v09 as generator


ROOT = Path(__file__).resolve().parents[2]
STAGE = ROOT / "ArtSource/Generated/Office/BGEECrampedV09"
GEOMETRY = STAGE / "office_v09_geometry.json"
PLATE = STAGE / "office_cramped_plate_v09.png"
MASK = STAGE / "office_cramped_architecture_mask_v09.png"
GRAYBOX = STAGE / "office_cramped_graybox_v09.png"
FAMILY = STAGE / "Props/office_door_family_v09.json"


def expected_mask(geometry: dict) -> np.ndarray:
    del geometry
    return np.asarray(generator._architecture_mask(generator._graybox()))


def nearest_boundary_distance(mask: np.ndarray, point: tuple[float, float]) -> float:
    x, y = point
    binary = mask > 0
    edge = binary ^ (
        np.roll(binary, 1, 0) & np.roll(binary, -1, 0)
        & np.roll(binary, 1, 1) & np.roll(binary, -1, 1)
    )
    ys, xs = np.where(edge)
    return float(np.sqrt((xs - x) ** 2 + (ys - y) ** 2).min())


def main() -> int:
    geometry = json.loads(GEOMETRY.read_text(encoding="utf-8"))
    frozen = np.asarray(Image.open(MASK).convert("L"))
    expected = expected_mask(geometry)
    plate = np.asarray(Image.open(PLATE).convert("RGB"))
    gray = np.asarray(Image.open(GRAYBOX).convert("RGB"))
    family = json.loads(FAMILY.read_text(encoding="utf-8"))
    checks: list[tuple[str, bool, str]] = []

    diff = int(np.count_nonzero(frozen != expected))
    checks.append(("architecture mask exact", diff == 0, f"{diff} differing pixels"))
    gray_mask = np.any(gray != 0, axis=2)
    checks.append(("graybox agrees with mask", np.array_equal(gray_mask, frozen > 0), "binary silhouette"))
    outside_nonblack = int(np.count_nonzero(np.any(plate != 0, axis=2) & (frozen == 0)))
    checks.append(("pure-black exterior", outside_nonblack == 0, f"{outside_nonblack} pixels"))

    control = geometry["room"]["controlPoints"]
    derived = {
        "rearFloor": room.plan(0, 0),
        "westFloor": room.plan(1, 0),
        "eastFloor": room.plan(0, 1),
        "nearFloor": room.plan(1, 1),
        "rearCrown": (room.REAR[0], room.REAR[1] - room.WALL_FACE_H),
    }
    for name, point in derived.items():
        distance = float(np.linalg.norm(np.asarray(point) - np.asarray(control[name])))
        x, y = (round(point[0]), round(point[1]))
        painted = 0 <= x < frozen.shape[1] and 0 <= y < frozen.shape[0] and frozen[y, x] > 0
        checks.append((f"control point {name}", distance <= 1.0 and painted, f"{distance:.2f}px; painted={painted}"))

    checks.append(("door canvas", family["canvas"] == geometry["door"]["liveCanvas"], str(family["canvas"])))
    checks.append(("door hinge exact", family["hingeImageXY"] == geometry["door"]["hingePixels"], str(family["hingeImageXY"])))
    checks.append(("door anchor exact", np.allclose(family["anchorFromBottomLeft"], geometry["door"]["anchor"]), str(family["anchorFromBottomLeft"])))

    open_image = np.asarray(Image.open(STAGE / "Props/office_door_leaf_open_v09.png").convert("RGBA"))
    ys, xs = np.where(open_image[:, :, 3] > 16)
    points = np.column_stack((xs, ys)).astype(float)
    hinge = np.asarray(geometry["door"]["hingePixels"], dtype=float)
    far = points[np.linalg.norm(points - hinge, axis=1).argmax()]
    vector = far - hinge
    angle = math.degrees(math.atan2(vector[1], -vector[0]))
    ref = geometry["referenceLock"]["doorCloseUp"]
    ref_vector = np.asarray(ref["normalizedFreeEnd"]) - np.asarray(ref["normalizedHinge"])
    ref_angle = math.degrees(math.atan2(ref_vector[1], -ref_vector[0]))
    checks.append(("door angle", abs(angle - ref_angle) <= 0.5, f"{angle:.2f}° vs {ref_angle:.2f}°"))
    length = float(np.linalg.norm(vector))
    covariance = np.cov(points.T)
    eigenvalues = np.linalg.eigvalsh(covariance)
    thickness_ratio = math.sqrt(float(eigenvalues[0] / eigenvalues[1]))
    checks.append(("door length ratio", 0.98 <= length / 444.0 <= 1.02, f"{length / 444.0:.3f}"))
    checks.append(("door thickness ratio", thickness_ratio <= 0.10, f"{thickness_ratio:.3f}"))

    for name, passed, detail in checks:
        print(f"{'PASS' if passed else 'FAIL'}  {name}: {detail}")
    ok = all(passed for _, passed, _ in checks)
    print(f"\nALL_PASS={ok}")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())

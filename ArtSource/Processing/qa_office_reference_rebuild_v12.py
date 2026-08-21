#!/usr/bin/env python3
"""Grade the V12 reference-faithful office plate and registered overlays."""

from __future__ import annotations

import hashlib
import json
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import generate_office_reference_rebuild_v12 as generator
import qa_plate_projection


ROOT = Path(__file__).resolve().parents[2]
STAGE = generator.STAGE
PLATE = STAGE / generator.FILENAMES["plate"]
ARCHITECTURE = STAGE / generator.FILENAMES["architectureMask"]
GLASS = STAGE / generator.FILENAMES["glassMask"]
HOVER = STAGE / generator.FILENAMES["nearHover"]
METRICS = STAGE / generator.FILENAMES["metrics"]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def polygon_mask(size: tuple[int, int], polygon: list[list[float]]) -> np.ndarray:
    image = Image.new("L", size, 0)
    ImageDraw.Draw(image).polygon([tuple(point) for point in polygon], fill=255)
    return np.asarray(image, dtype=np.uint8) > 0


def main() -> int:
    required = [
        generator.SOURCE,
        generator.TARGET_REFERENCE,
        generator.V11_GEOMETRY,
        generator.FLOOR_DETAIL,
        generator.WALL_DETAIL,
        PLATE,
        ARCHITECTURE,
        GLASS,
        HOVER,
        METRICS,
    ]
    missing = [str(path.relative_to(ROOT)) for path in required if not path.exists()]
    if missing:
        print("FAIL missing V12 files: " + ", ".join(missing))
        return 1

    metrics = json.loads(METRICS.read_text(encoding="utf-8"))
    geometry = json.loads(generator.V11_GEOMETRY.read_text(encoding="utf-8"))
    plate_image = Image.open(PLATE)
    plate = np.asarray(plate_image.convert("RGB"), dtype=np.uint8)
    architecture_image = Image.open(ARCHITECTURE)
    architecture = np.asarray(architecture_image.convert("L"), dtype=np.uint8)
    glass_image = Image.open(GLASS)
    glass = np.asarray(glass_image.convert("RGBA"), dtype=np.uint8)
    hover_image = Image.open(HOVER)
    hover = np.asarray(hover_image.convert("RGBA"), dtype=np.uint8)
    checks: list[tuple[str, bool, str]] = []

    checks.append((
        "source identities",
        sha256(generator.TARGET_REFERENCE) == "6fbb06a6bf54e821bcdf7ae5e86aecc998ed594b4869c79dbc78bb41d770bd19"
        and sha256(generator.SOURCE) == "e66a579d3d0990ab10d2584045e7d5ed012c843aee7689b8fde8ea5d15085b75",
        f"reference={sha256(generator.TARGET_REFERENCE)[:12]} redraw={sha256(generator.SOURCE)[:12]}",
    ))
    checks.append((
        "plate canvas/mode",
        plate_image.size == (4096, 2304) and plate_image.mode == "RGB",
        f"{plate_image.size} {plate_image.mode}",
    ))
    checks.append((
        "architecture mask",
        architecture_image.size == (4096, 2304) and architecture_image.mode == "L",
        f"{architecture_image.size} {architecture_image.mode}",
    ))
    outside = int(np.count_nonzero(np.any(plate != 0, axis=2) & (architecture == 0)))
    checks.append(("pure-black exterior", outside == 0, f"{outside} pixels"))

    registration = metrics["registration"]
    checks.append((
        "uniform registration only",
        registration["anisotropicWholePlateResize"] is False
        and abs(float(registration["uniformScale"]) - generator.UNIFORM_REGISTRATION["scale"]) < 1e-12,
        f"scale={registration['uniformScale']} translate={registration['uniformTranslation']}",
    ))
    checks.append((
        "navigation fit bound",
        "59.73 pixels" in registration["navigationGeometryAuthority"],
        registration["navigationGeometryAuthority"],
    ))

    projection = qa_plate_projection.grade(PLATE)
    checks.append((
        "BG:EE projection tight lock",
        projection["worst_delta"] <= 1.5,
        f"{projection['peak_pos']:+.2f}/{projection['peak_neg']:+.2f}; delta={projection['worst_delta']:.2f}°",
    ))
    density = 1.0 / float(metrics["environmentScale"])
    checks.append((
        "installed art density",
        density >= 2.53 and metrics["densityRestoration"]["floorHighPassMix"] > 0,
        f"{density:.4f} px/world unit with output-resolution material detail",
    ))

    with tempfile.TemporaryDirectory(prefix="rainshadow-v12-reproduce-") as temp_name:
        reproduced = generator.write_assets(Path(temp_name))
        compared = ["plate", "architectureMask", "glassMask", "nearHover", "metrics"]
        mismatches = [
            key
            for key in compared
            if sha256(STAGE / generator.FILENAMES[key]) != sha256(reproduced[key])
        ]
    checks.append((
        "deterministic regeneration",
        not mismatches,
        "identical" if not mismatches else ", ".join(mismatches),
    ))

    fireplace = geometry["fireplace"]
    fire_region = polygon_mask((4096, 2304), fireplace["targetCoverPolygon"])
    fire_pixels = plate[fire_region]
    hot = (
        (fire_pixels[:, 0] > 150)
        & (fire_pixels[:, 0] > fire_pixels[:, 1] + 35)
        & (fire_pixels[:, 1] > 45)
        & (fire_pixels[:, 2] < 95)
    )
    checks.append((
        "lit fireplace",
        int(hot.sum()) >= 2500 and metrics["flameOrEmberPixelsAuthored"] is True,
        f"hot pixels={int(hot.sum())}",
    ))
    floor_region = polygon_mask((4096, 2304), fireplace["targetFloorFootprint"])
    floor_pixels = plate[floor_region]
    warm = (
        (floor_pixels[:, 0] > floor_pixels[:, 2] + 45)
        & (floor_pixels[:, 0] > floor_pixels[:, 1] + 10)
    )
    checks.append(("localized hearth spill", int(warm.sum()) >= 15000, f"warm pixels={int(warm.sum())}"))
    checks.append((
        "no baked door",
        metrics["doorPixelsBakedIntoPlate"] is False,
        str(metrics["doorPixelsBakedIntoPlate"]),
    ))

    checks.append((
        "glass mask RGBA",
        glass_image.size == (4096, 2304) and glass_image.mode == "RGBA" and int((glass[:, :, 3] > 0).sum()) > 20000,
        f"{glass_image.size} {glass_image.mode} alphaPixels={int((glass[:, :, 3] > 0).sum())}",
    ))
    checks.append((
        "near hover RGBA",
        hover_image.size == (4096, 2304) and hover_image.mode == "RGBA" and int((hover[:, :, 3] > 0).sum()) > 20000,
        f"{hover_image.size} {hover_image.mode} alphaPixels={int((hover[:, :, 3] > 0).sum())}",
    ))
    near = next(window for window in metrics["windows"] if window["id"] == "near")
    old_near = next(window for window in geometry["windows"] if window["id"] == "near")
    near_delta = float(
        np.linalg.norm(
            np.asarray(near["aperture"], dtype=float).mean(axis=0)
            - np.asarray(old_near["targetAperturePolygon"], dtype=float).mean(axis=0)
        )
    )
    checks.append((
        "interactive window registration",
        near_delta <= 20.0,
        f"centre delta={near_delta:.2f}px ({near_delta * float(metrics['environmentScale']):.2f} world units)",
    ))

    for name, passed, detail in checks:
        print(f"{'PASS' if passed else 'FAIL'}  {name}: {detail}")
    ok = all(passed for _, passed, _ in checks)
    print(f"\nALL_PASS={ok}")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())

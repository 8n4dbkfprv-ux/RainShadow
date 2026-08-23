#!/usr/bin/env python3
"""Grade the V13 clean wall, ImageGen windows, and registered plate."""

from __future__ import annotations

import json
import math
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

import generate_office_reference_rebuild_v13 as generator
import qa_plate_projection


ROOT = Path(__file__).resolve().parents[2]
STAGE = generator.STAGE
PLATE = STAGE / generator.FILENAMES["plate"]
ARCHITECTURE = STAGE / generator.FILENAMES["architectureMask"]
GLASS = STAGE / generator.FILENAMES["glassMask"]
HOVER = STAGE / generator.FILENAMES["nearHover"]
METRICS = STAGE / generator.FILENAMES["metrics"]


def polygon_mask(
    size: tuple[int, int], polygons: list[list[list[float]]]
) -> np.ndarray:
    image = Image.new("L", size, 0)
    draw = ImageDraw.Draw(image)
    for polygon in polygons:
        draw.polygon([tuple(point) for point in polygon], fill=255)
    return np.asarray(image, dtype=np.uint8) > 0


def shifted(
    polygon: list[list[float]], translation: tuple[float, float]
) -> list[list[float]]:
    dx, dy = translation
    return [[x + dx, y + dy] for x, y in polygon]


def main() -> int:
    required = [
        generator.V12_SOURCE,
        generator.WINDOWLESS_SOURCE,
        generator.IMAGEGEN_WINDOW_EDIT,
        generator.SOURCE,
        PLATE,
        ARCHITECTURE,
        GLASS,
        HOVER,
        METRICS,
    ]
    missing = [str(path.relative_to(ROOT)) for path in required if not path.exists()]
    if missing:
        print("FAIL missing V13 files: " + ", ".join(missing))
        return 1

    metrics = json.loads(METRICS.read_text(encoding="utf-8"))
    source_image = Image.open(generator.SOURCE).convert("RGB")
    source = np.asarray(source_image, dtype=np.uint8)
    plate_image = Image.open(PLATE)
    plate = np.asarray(plate_image.convert("RGB"), dtype=np.uint8)
    architecture_image = Image.open(ARCHITECTURE)
    architecture = np.asarray(architecture_image.convert("L"), dtype=np.uint8)
    glass_image = Image.open(GLASS).convert("RGBA")
    glass = np.asarray(glass_image, dtype=np.uint8)
    hover_image = Image.open(HOVER).convert("RGBA")
    hover = np.asarray(hover_image, dtype=np.uint8)
    checks: list[tuple[str, bool, str]] = []

    checks.append((
        "source and plate canvases",
        source_image.size == (1672, 941)
        and plate_image.size == (4096, 2304)
        and plate_image.mode == "RGB",
        f"source={source_image.size}; plate={plate_image.size} {plate_image.mode}",
    ))
    checks.append((
        "frozen source identities",
        metrics["source"]["sha256"] == generator.v12.sha256(generator.SOURCE)
        and metrics["wallRepair"]["sourceSha256"]
        == generator.v12.sha256(generator.WINDOWLESS_SOURCE)
        and metrics["sourceProvenance"]["imagegenWindowEditSha256"]
        == generator.v12.sha256(generator.IMAGEGEN_WINDOW_EDIT),
        f"source={generator.v12.sha256(generator.SOURCE)[:12]} "
        f"repair={generator.v12.sha256(generator.WINDOWLESS_SOURCE)[:12]} "
        f"windows={generator.v12.sha256(generator.IMAGEGEN_WINDOW_EDIT)[:12]}",
    ))

    pair = metrics["windowPair"]
    gaps = [float(value) for value in pair["clearGapsAlongSourceX"]]
    checks.append((
        "even wall-axis window spacing",
        max(gaps) - min(gaps) <= 12.0
        and max(abs(a - b) for a, b in zip(gaps, generator.WINDOW_CLEAR_GAPS)) <= 1e-9,
        "/".join(f"{gap:.1f}px" for gap in gaps),
    ))

    translations = generator.WINDOW_TRANSLATIONS
    near_dx = float(pair["sourceTranslations"]["near"][0])
    near_dy = float(pair["sourceTranslations"]["near"][1])
    far_dx = float(pair["sourceTranslations"]["far"][0])
    far_dy = float(pair["sourceTranslations"]["far"][1])
    checks.append((
        "window translations follow wall axis",
        abs((far_dy - near_dy) / (far_dx - near_dx) + 0.75) <= 1e-12
        and translations["near"] == (0.0, 0.0),
        ", ".join(f"{key}=({dx:.3f},{dy:.3f})" for key, (dx, dy) in translations.items()),
    ))

    by_id = {window["id"]: window for window in generator.SOURCE_WINDOWS}
    expected_aperture = shifted(generator.NEAR_APERTURE, translations["far"])
    expected_glass = [shifted(pane, translations["far"]) for pane in generator.NEAR_GLASS]
    geometry_identical = (
        len(by_id["near"]["glass"]) == 6
        and len(by_id["far"]["glass"]) == 6
        and by_id["near"]["aperture"] == generator.NEAR_APERTURE
        and by_id["near"]["glass"] == generator.NEAR_GLASS
        and by_id["far"]["aperture"] == expected_aperture
        and by_id["far"]["glass"] == expected_glass
    )
    checks.append((
        "registered six-pane window geometry",
        geometry_identical,
        "two six-pane masks on one wall-axis translation" if geometry_identical else "geometry drift",
    ))

    wall_mask = polygon_mask(source_image.size, [generator.v12.SOURCE_PLANES["NW"]])
    # Six source pixels excludes only the antialiased crown/seam fringe.  A
    # genuine gouge like the rejected V13 copy remains hundreds of pixels deep
    # and still fails this interior continuity check.
    wall_interior = ndimage.binary_erosion(wall_mask, iterations=6)
    frame_masks = polygon_mask(
        source_image.size,
        list(generator.WINDOW_FRAME_POLYGONS.values()),
    )
    frame_masks = ndimage.binary_dilation(frame_masks, iterations=2)
    clear_plaster = wall_interior & ~frame_masks
    missing_wall = int(np.count_nonzero(clear_plaster & (source.max(axis=2) <= 3)))
    checks.append((
        "continuous NW wall plaster",
        missing_wall == 0,
        f"{missing_wall} black/missing interior pixels outside window frames",
    ))

    target_frames = list(generator.WINDOW_FRAME_POLYGONS.values())
    target_frame_mask = polygon_mask(source_image.size, target_frames)
    room_mask = polygon_mask(
        source_image.size, list(generator.v12.SOURCE_PLANES.values())
    )
    escaped_window_pixels = int(np.count_nonzero(target_frame_mask & ~room_mask))
    checks.append((
        "window inserts cannot escape registered room",
        escaped_window_pixels == 0,
        f"{escaped_window_pixels} escaped pixels",
    ))

    outside_plate = int(np.count_nonzero(
        np.any(plate != 0, axis=2) & (architecture == 0)
    ))
    checks.append((
        "pure-black registered exterior",
        outside_plate == 0,
        f"{outside_plate} pixels",
    ))

    projection = qa_plate_projection.grade(PLATE)
    checks.append((
        "BG:EE projection tight lock",
        projection["worst_delta"] <= 1.5,
        f"{projection['peak_pos']:+.2f}/{projection['peak_neg']:+.2f}; "
        f"delta={projection['worst_delta']:.2f}°",
    ))
    checks.append((
        "registered glass and hover masks",
        glass_image.size == (4096, 2304)
        and hover_image.size == (4096, 2304)
        and int(np.count_nonzero(glass[:, :, 3])) > 0
        and int(np.count_nonzero(hover[:, :, 3])) > 0,
        f"glass={int(np.count_nonzero(glass[:, :, 3]))} "
        f"hover={int(np.count_nonzero(hover[:, :, 3]))}",
    ))

    with tempfile.TemporaryDirectory(prefix="rainshadow-v13-reproduce-") as temp_name:
        reproduced = generator.write_assets(Path(temp_name))
        compared = ["plate", "architectureMask", "glassMask", "nearHover", "metrics"]
        mismatches = [
            key
            for key in compared
            if generator.v12.sha256(STAGE / generator.FILENAMES[key])
            != generator.v12.sha256(reproduced[key])
        ]
    checks.append((
        "deterministic regeneration",
        not mismatches,
        "identical" if not mismatches else ", ".join(mismatches),
    ))

    for name, passed, detail in checks:
        print(f"{'PASS' if passed else 'FAIL'}  {name}: {detail}")
    ok = all(passed for _, passed, _ in checks)
    print(f"\nALL_PASS={ok}")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())

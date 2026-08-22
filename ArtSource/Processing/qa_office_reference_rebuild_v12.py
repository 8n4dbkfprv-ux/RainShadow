#!/usr/bin/env python3
"""Grade the V12 reference-faithful office plate and registered overlays."""

from __future__ import annotations

import hashlib
import json
import math
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import generate_office_reference_rebuild_v12 as generator
import process_office_door_reference_v12 as door_generator
import qa_plate_projection


ROOT = Path(__file__).resolve().parents[2]
STAGE = generator.STAGE
PLATE = STAGE / generator.FILENAMES["plate"]
ARCHITECTURE = STAGE / generator.FILENAMES["architectureMask"]
GLASS = STAGE / generator.FILENAMES["glassMask"]
HOVER = STAGE / generator.FILENAMES["nearHover"]
METRICS = STAGE / generator.FILENAMES["metrics"]
DOOR_FAMILY = STAGE / "Props/office_door_family_v12.json"


def actual_thickness(image: Image.Image, hinge: np.ndarray, direction: np.ndarray) -> float:
    alpha = np.asarray(image.getchannel("A"), dtype=np.uint8)
    ys, xs = np.where(alpha > 32)
    points = np.column_stack((xs, ys)).astype(float)
    offsets = points - hinge
    along = offsets @ direction
    normal = np.asarray([-direction[1], direction[0]])
    across = offsets @ normal
    middle = (along >= along.max() * 0.35) & (along <= along.max() * 0.65)
    return float(across[middle].max() - across[middle].min())


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


def fireplace_source_envelope(path: Path) -> list[int]:
    """Measure the connected low-chroma stone relief on the frozen source."""
    rgb = np.asarray(Image.open(path).convert("RGB"), dtype=np.float32) / 255.0
    maximum = rgb.max(axis=2)
    minimum = rgb.min(axis=2)
    saturation = (maximum - minimum) / np.maximum(maximum, 1e-6)
    stone = (saturation < 0.48) & (maximum > 0.16) & (maximum < 0.70)
    roi = np.zeros(stone.shape, dtype=bool)
    roi[170:520, 850:1200] = stone[170:520, 850:1200]
    components: list[tuple[int, list[int]]] = []
    visited = np.zeros(roi.shape, dtype=bool)
    for seed_y, seed_x in np.argwhere(roi):
        if visited[seed_y, seed_x]:
            continue
        stack = [(int(seed_y), int(seed_x))]
        visited[seed_y, seed_x] = True
        count = 0
        min_x = max_x = int(seed_x)
        min_y = max_y = int(seed_y)
        while stack:
            y, x = stack.pop()
            count += 1
            min_x, max_x = min(min_x, x), max(max_x, x)
            min_y, max_y = min(min_y, y), max(max_y, y)
            for next_y, next_x in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                if (
                    0 <= next_y < roi.shape[0]
                    and 0 <= next_x < roi.shape[1]
                    and roi[next_y, next_x]
                    and not visited[next_y, next_x]
                ):
                    visited[next_y, next_x] = True
                    stack.append((next_y, next_x))
        if count > 100:
            components.append((count, [min_x, min_y, max_x + 1, max_y + 1]))
    if not components:
        raise RuntimeError("fireplace stone envelope was not detected")
    return max(components, key=lambda component: component[0])[1]


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
        DOOR_FAMILY,
        door_generator.NATIVE_MASTER,
    ]
    required.extend(
        STAGE / "Props" / f"office_door_leaf_{state}{suffix}_v12.png"
        for state in ("closed", "mid", "open")
        for suffix in ("", "_hover")
    )
    missing = [str(path.relative_to(ROOT)) for path in required if not path.exists()]
    if missing:
        print("FAIL missing V12 files: " + ", ".join(missing))
        return 1

    metrics = json.loads(METRICS.read_text(encoding="utf-8"))
    geometry = json.loads(generator.V11_GEOMETRY.read_text(encoding="utf-8"))
    door_family = json.loads(DOOR_FAMILY.read_text(encoding="utf-8"))
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
        and sha256(generator.SOURCE) == "22cc5cef3e311306c16352bed57a7ee27d0970631e09ccfc0803d98f70c64dd1",
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
    visual_scale = metrics["fireplace"]["visualScaleLock"]
    measured_envelope = fireplace_source_envelope(generator.SOURCE)
    envelope_width = measured_envelope[2] - measured_envelope[0]
    envelope_height = measured_envelope[3] - measured_envelope[1]
    checks.append((
        "fireplace visible envelope",
        measured_envelope == visual_scale["sourceEnvelope"]
        and 155 <= envelope_width <= 166
        and 185 <= envelope_height <= 198,
        f"source={measured_envelope} size={envelope_width}x{envelope_height}",
    ))
    registered_facade_height = float(fireplace["facadeHeight"])
    plate_jamb_height = float(visual_scale["plateJambHeightPixels"])
    adult_ratio = float(visual_scale["fireplaceToAdultRatio"])
    ratio_range = visual_scale["targetFireplaceToAdultRange"]
    checks.append((
        "fireplace humanoid scale lock",
        abs(plate_jamb_height - registered_facade_height) <= 1.0
        and float(ratio_range[0]) <= adult_ratio <= float(ratio_range[1])
        and abs(float(visual_scale["standingAdultWorldHeight"]) - 70.3125) <= 1e-9,
        f"jamb={plate_jamb_height:.2f}/{registered_facade_height:.2f}px ratio={adult_ratio:.3f} adults",
    ))
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

    door = geometry["door"]
    checks.append((
        "door source and visual-target identities",
        door_family["source"]["sha256"] == door_generator.NATIVE_MASTER_SHA256
        and sha256(door_generator.NATIVE_MASTER) == door_generator.NATIVE_MASTER_SHA256
        and door_family["source"]["visualTargetSha256"] == generator.sha256(generator.TARGET_REFERENCE)
        and door_family["source"]["pixelPolicy"].startswith("native-resolution"),
        door_family["source"]["sha256"][:12] + "…; " + door_family["source"]["pixelPolicy"],
    ))
    checks.append((
        "door canvas/hinge/anchor",
        door_family["canvas"] == [512, 320]
        and door_family["hingeImageXY"] == [488, 18]
        and door_family["anchorFromBottomLeft"] == [0.953125, 0.94375],
        f"{door_family['canvas']} hinge={door_family['hingeImageXY']} anchor={door_family['anchorFromBottomLeft']}",
    ))
    checks.append((
        "door reduced reference scale",
        abs(float(door_family["displayScale"]) - door_generator.DISPLAY_SCALE) < 1e-12
        and float(door_family["displayScale"]) < float(door["displayScale"]),
        f"{door_family['displayScale']} vs environment {door['displayScale']}",
    ))
    plate_hinge = np.asarray(door["targetHinge"], dtype=float)
    plate_free = np.asarray(door["targetFreeEnd"], dtype=float)
    closed_vector = plate_free - plate_hinge
    closed_length = float(np.linalg.norm(closed_vector))
    direction = closed_vector / closed_length
    angle = math.degrees(math.atan2(direction[1], -direction[0]))
    checks.append((
        "door reference axis",
        abs(angle - float(door["targetAngleDegrees"])) <= 0.01
        and abs(closed_length - float(door["targetLength"])) <= 0.01,
        f"{angle:.3f}° length={closed_length:.3f}px",
    ))
    for state in ("closed", "mid", "open"):
        state_record = door_family["states"][state]
        base = Image.open(STAGE / "Props" / state_record["file"]).convert("RGBA")
        hover_state = Image.open(STAGE / "Props" / state_record["hoverFile"]).convert("RGBA")
        endpoints = np.asarray(state_record["registeredImageAxisEndpoints"], dtype=float)
        target_length = closed_length * float(door["stateLengthRatios"][state])
        registered_length = float(np.linalg.norm(endpoints[1] - endpoints[0]))
        thickness = actual_thickness(base, np.asarray([488.0, 18.0]), direction)
        base_pixels = np.asarray(base, dtype=np.uint8)
        hover_pixels = np.asarray(hover_state, dtype=np.uint8)
        checks.append((
            f"door {state} reference registration",
            base.size == (512, 320)
            and np.linalg.norm(endpoints[0] - np.asarray([488.0, 18.0])) <= 0.001
            and abs(registered_length - target_length) <= 0.01
            and 28.0 <= thickness <= 40.0
            and abs(thickness - float(state_record["actualTextureThickness"])) <= 0.01,
            f"length={registered_length:.2f}/{target_length:.2f}px thickness={thickness:.2f}px",
        ))
        checks.append((
            f"door {state} hover colour only",
            np.array_equal(base_pixels[:, :, 3], hover_pixels[:, :, 3]),
            "alpha identical" if np.array_equal(base_pixels[:, :, 3], hover_pixels[:, :, 3]) else "alpha drift",
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

    with tempfile.TemporaryDirectory(prefix="rainshadow-v12-door-reproduce-") as temp_name:
        reproduced_door = door_generator.write_assets(Path(temp_name))
        door_mismatches = [
            key
            for key, path in reproduced_door.items()
            if sha256(path) != sha256(STAGE / "Props" / path.name)
        ]
    checks.append((
        "deterministic door regeneration",
        not door_mismatches,
        "identical" if not door_mismatches else ", ".join(door_mismatches),
    ))

    for name, passed, detail in checks:
        print(f"{'PASS' if passed else 'FAIL'}  {name}: {detail}")
    ok = all(passed for _, passed, _ in checks)
    print(f"\nALL_PASS={ok}")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())

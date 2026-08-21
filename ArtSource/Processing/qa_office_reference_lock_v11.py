#!/usr/bin/env python3
"""Grade the V11 reference transform, baked fixtures, masks, and door family."""

from __future__ import annotations

import hashlib
import json
import math
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import generate_office_1950s_bgee_v11 as generator
import qa_plate_projection


ROOT = Path(__file__).resolve().parents[2]
STAGE = ROOT / "ArtSource/Generated/Office/BGEE1950sV11"
GEOMETRY = STAGE / "office_v11_geometry.json"
PLATE = STAGE / generator.FILENAMES["plate"]
MASK = STAGE / generator.FILENAMES["architectureMask"]
GLASS = STAGE / generator.FILENAMES["glassMask"]
HOVER = STAGE / generator.FILENAMES["nearHover"]
METRICS = STAGE / generator.FILENAMES["metrics"]
FAMILY = STAGE / "Props/office_door_family_v11.json"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def transformed(point: list[float], transform: dict[str, object]) -> np.ndarray:
    scale = float(transform["uniformScale"])
    return np.asarray(
        [point[0] * scale, (point[1] - float(transform["sourceCropTop"])) * scale],
        dtype=float,
    )


def polygon_mask(size: tuple[int, int], polygons: list[list[list[float]]]) -> np.ndarray:
    image = Image.new("L", size, 0)
    draw = ImageDraw.Draw(image)
    for polygon in polygons:
        draw.polygon([tuple(point) for point in polygon], fill=255)
    return np.asarray(image, dtype=np.uint8)


def _actual_maximum_thickness(image: Image.Image, hinge: np.ndarray, direction: np.ndarray) -> float:
    alpha = np.asarray(image.getchannel("A"))
    ys, xs = np.where(alpha > 32)
    points = np.column_stack((xs, ys)).astype(float)
    offsets = points - hinge
    along = offsets @ direction
    normal = np.asarray([-direction[1], direction[0]])
    across = offsets @ normal
    length = float(along.max())
    middle = (along >= length * 0.35) & (along <= length * 0.65)
    return float(across[middle].max() - across[middle].min())


def main() -> int:
    required = [GEOMETRY, PLATE, MASK, GLASS, HOVER, METRICS, FAMILY]
    missing = [str(path.relative_to(ROOT)) for path in required if not path.exists()]
    if missing:
        print("FAIL missing V11 files: " + ", ".join(missing))
        return 1

    geometry = json.loads(GEOMETRY.read_text(encoding="utf-8"))
    metrics = json.loads(METRICS.read_text(encoding="utf-8"))
    family = json.loads(FAMILY.read_text(encoding="utf-8"))
    plate_image = Image.open(PLATE).convert("RGB")
    plate = np.asarray(plate_image)
    architecture_mask = np.asarray(Image.open(MASK).convert("L"))
    glass_image = Image.open(GLASS).convert("RGBA")
    glass = np.asarray(glass_image)
    hover = np.asarray(Image.open(HOVER).convert("RGBA"))
    checks: list[tuple[str, bool, str]] = []

    checks.append(("plate canvas/mode", Image.open(PLATE).size == (4096, 2304) and Image.open(PLATE).mode == "RGB", f"{Image.open(PLATE).size} {Image.open(PLATE).mode}"))
    checks.append(("reference identity", geometry["referenceLock"]["sha256"] == "6fbb06a6bf54e821bcdf7ae5e86aecc998ed594b4869c79dbc78bb41d770bd19" and geometry["referenceLock"]["nativeDimensions"] == [1613, 975], geometry["referenceLock"]["sha256"][:16] + "…"))
    transform = geometry["referenceTransform"]
    checks.append(("uniform transform", transform["anisotropicScalingAllowed"] is False and abs(float(transform["uniformScale"]) - 4096.0 / 1613.0) < 1e-12, f"scale={transform['uniformScale']}"))
    target_crop_height = (975.0 - 2.0 * float(transform["sourceCropTop"])) * float(transform["uniformScale"])
    checks.append(("16:9 vertical crop only", abs(target_crop_height - 2304.0) < 1e-6 and float(transform["sourceCropTop"]) == float(transform["sourceCropBottom"]), f"mappedHeight={target_crop_height:.6f}"))

    transform_deltas: list[float] = []
    for window in geometry["windows"]:
        for source, target in zip(window["sourceAperturePolygon"], window["targetAperturePolygon"]):
            transform_deltas.append(float(np.linalg.norm(transformed(source, transform) - np.asarray(target))))
        for source_poly, target_poly in zip(window["sourceGlassPolygons"], window["targetGlassPolygons"]):
            for source, target in zip(source_poly, target_poly):
                transform_deltas.append(float(np.linalg.norm(transformed(source, transform) - np.asarray(target))))
    fireplace = geometry["fireplace"]
    door = geometry["door"]
    for source, target in ((door["sourceHinge"], door["targetHinge"]), (door["sourceFreeEnd"], door["targetFreeEnd"])):
        transform_deltas.append(float(np.linalg.norm(transformed(source, transform) - np.asarray(target))))
    checks.append(("window/door points use one reference transform", max(transform_deltas) <= 0.001, f"worst={max(transform_deltas):.4f}px"))

    # The fixture reference is a front elevation. It must be affinely placed on
    # the authored NE wall, not keystone-warped through the screenshot's legacy
    # fireplace outline. Courses follow axisNE; jambs remain screen-vertical.
    room = geometry["room"]
    rear = np.asarray(room["rear"], dtype=float)
    axis_ne = np.asarray(room["axisNE"], dtype=float)
    axis_nw = np.asarray(room["axisNW"], dtype=float)
    wall = np.asarray(fireplace["targetWallPolygon"], dtype=float)
    top_course = wall[1] - wall[0]
    bottom_course = wall[2] - wall[3]
    left_jamb = wall[3] - wall[0]
    right_jamb = wall[2] - wall[1]
    target_course_slope = 0.75
    parallel_error = abs(float(top_course[1] - top_course[0] * target_course_slope))
    affine_error = max(
        float(np.linalg.norm(top_course - bottom_course)),
        float(np.linalg.norm(left_jamb - right_jamb)),
    )
    course_angle = math.degrees(math.atan2(top_course[1], top_course[0]))
    checks.append(("fireplace courses on NE axis", parallel_error <= 1e-6 and abs(course_angle - 36.86989765) <= 1e-6, f"angle={course_angle:.8f}° crossError={parallel_error:.8f}"))
    with Image.open(generator.FIREPLACE_SOURCE) as fixture_source:
        relief_source_aspect = fixture_source.width / fixture_source.height
    projected_fixture = generator._locked_relief(
        generator.FIREPLACE_SOURCE,
        target_slope=0.75,
        target_height=int(fireplace["reliefTargetHeight"]),
    )
    projected_aspect = projected_fixture.width / projected_fixture.height
    facade_aspect_error = abs(projected_aspect - float(fireplace["sourceFixtureAspect"]))
    relief_aspect_error = abs(
        relief_source_aspect - float(fireplace["reliefSourceAspect"])
    )
    reference_aspect = float(fireplace["sourceFixtureAspect"])
    projected_registration_error = abs(
        projected_aspect - float(fireplace["reliefProjectedAspect"])
    )
    checks.append(("fireplace reference proportion", facade_aspect_error <= 0.03, f"projected={projected_aspect:.6f} reference={reference_aspect:.6f} delta={facade_aspect_error:.6f}"))
    checks.append(("fireplace dimensional relief source", relief_aspect_error <= 1e-9 and int(fireplace["reliefTargetHeight"]) == 650 and projected_registration_error <= 1e-9, f"source={relief_source_aspect:.6f} registered={float(fireplace['reliefSourceAspect']):.6f} projected={projected_aspect:.6f} height={fireplace['reliefTargetHeight']}"))
    checks.append(("fireplace affine, no keystone", affine_error <= 1e-6, f"worst vector delta={affine_error:.8f}px"))
    checks.append(("fireplace jambs vertical", abs(left_jamb[0]) <= 1e-9 and abs(right_jamb[0]) <= 1e-9 and abs(left_jamb[1] - float(fireplace["facadeHeight"])) <= 1e-9, f"left={left_jamb.tolist()} right={right_jamb.tolist()}"))
    bounds = np.asarray(fireplace["targetWallBounds"], dtype=float)
    expected_bounds = np.asarray([wall[:, 0].min(), wall[:, 1].min(), wall[:, 0].max(), wall[:, 1].max()])
    checks.append(("fireplace bounds derived from facade", float(np.abs(bounds - expected_bounds).max()) <= 1e-6, f"{bounds.tolist()}"))

    footprint = np.asarray(fireplace["targetFloorFootprint"], dtype=float)
    footprint_base_error = max(
        float(np.linalg.norm(footprint[0] - wall[3])),
        float(np.linalg.norm(footprint[1] - wall[2])),
    )
    hearth_course_error = float(np.linalg.norm((footprint[2] - footprint[3]) - bottom_course))
    depth_left = footprint[3] - footprint[0]
    depth_right = footprint[2] - footprint[1]
    depth_parallel_error = abs(float(depth_left[1] + depth_left[0] * 0.75))
    checks.append(("hearth registered to facade base", footprint_base_error <= 1e-6 and hearth_course_error <= 1e-6, f"base={footprint_base_error:.8f}px course={hearth_course_error:.8f}px"))
    checks.append(("hearth affine into floor", float(np.linalg.norm(depth_left - depth_right)) <= 1e-6 and depth_parallel_error <= 0.002 and abs(np.linalg.norm(depth_left) - float(fireplace["hearthDepthPixels"])) <= 1e-6, f"depth={np.linalg.norm(depth_left):.3f}px crossError={depth_parallel_error:.8f}"))
    obstacle_error = float(np.abs(np.asarray(fireplace["targetObstaclePolygon"], dtype=float) - footprint).max())
    expected_cover = np.asarray([wall[0], wall[1], footprint[2], footprint[3]])
    cover_error = float(np.abs(np.asarray(fireplace["targetCoverPolygon"], dtype=float) - expected_cover).max())
    checks.append(("fireplace obstacle/cover registration", obstacle_error <= 1e-9 and cover_error <= 1e-9, f"obstacle={obstacle_error:.3f}px cover={cover_error:.3f}px"))

    outside_nonblack = int(np.count_nonzero(np.any(plate != 0, axis=2) & (architecture_mask == 0)))
    checks.append(("pure-black exterior", outside_nonblack == 0, f"{outside_nonblack} pixels"))
    density = 1.0 / float(geometry["environmentScale"])
    checks.append(("density", density >= 2.53, f"{density:.4f} px/world unit"))
    projection = qa_plate_projection.grade(PLATE)
    checks.append(("BG:EE projection", projection["worst_delta"] <= 1.5, f"{projection['peak_pos']:+.2f}/{projection['peak_neg']:+.2f}; delta={projection['worst_delta']:.2f}°"))

    with tempfile.TemporaryDirectory(prefix="rainshadow-v11-reproduce-") as temp_name:
        reproduced = generator.write_assets(Path(temp_name))
        compared = ["plate", "graybox", "architectureMask", "glassMask", "nearHover", "metrics"]
        mismatches = [key for key in compared if sha256(STAGE / generator.FILENAMES[key]) != sha256(reproduced[key])]
    checks.append(("deterministic hash reproduction", not mismatches, "identical" if not mismatches else ", ".join(mismatches)))

    aperture_masks: dict[str, np.ndarray] = {}
    with Image.open(generator.WINDOW_SOURCE).convert("RGBA") as window_source:
        source_alpha = np.asarray(window_source.getchannel("A"), dtype=np.uint8)
        transparent_fraction = float((source_alpha == 0).mean())
        corner_alpha = max(
            int(source_alpha[0, 0]),
            int(source_alpha[0, -1]),
            int(source_alpha[-1, 0]),
            int(source_alpha[-1, -1]),
        )
    checks.append(("window source has no black matte", transparent_fraction >= 0.25 and corner_alpha == 0, f"transparent={transparent_fraction:.1%} cornerAlpha={corner_alpha}"))
    for window in geometry["windows"]:
        aperture = polygon_mask((4096, 2304), [window["targetAperturePolygon"]])
        aperture_masks[window["id"]] = aperture
        pixels = plate[aperture > 0]
        detail = float(pixels.std()) if len(pixels) else 0.0
        checks.append((f"{window['id']} baked casement", len(pixels) > 1000 and detail >= 18.0, f"pixels={len(pixels)} std={detail:.1f}"))
    checks.append(("two baked windows", len(geometry["windows"]) == 2 and {window["role"] for window in geometry["windows"]} == {"decorative", "interactive:office.window"}, str([window["role"] for window in geometry["windows"]])))

    checks.append(("glass mask RGBA", glass_image.mode == "RGBA" and glass_image.size == (4096, 2304), f"{glass_image.mode} {glass_image.size}"))
    all_glass_polygons = [polygon for window in geometry["windows"] for polygon in window["targetGlassPolygons"]]
    expected_glass = polygon_mask((4096, 2304), all_glass_polygons)
    for window in geometry["windows"]:
        expected = polygon_mask((4096, 2304), window["targetGlassPolygons"])
        overlap = float((glass[:, :, 3][expected > 0] > 128).mean())
        checks.append((f"glass mask covers {window['id']}", overlap >= 0.92, f"{overlap:.1%}"))
    allowed_glass = np.asarray(Image.fromarray(expected_glass).filter(ImageFilter.MaxFilter(7))) > 0
    leaked_glass = int(np.count_nonzero((glass[:, :, 3] > 2) & ~allowed_glass))
    checks.append(("glass mask registered only", leaked_glass == 0, f"{leaked_glass} leaked pixels"))

    near_aperture = aperture_masks["near"] > 0
    far_aperture = aperture_masks["far"] > 0
    hover_alpha = hover[:, :, 3]
    near_coverage = float((hover_alpha[near_aperture] > 0).mean())
    far_hover_pixels = int(np.count_nonzero(hover_alpha[far_aperture]))
    allowed_hover = np.asarray(Image.fromarray(aperture_masks["near"]).filter(ImageFilter.MaxFilter(11))) > 0
    hover_leaks = int(np.count_nonzero((hover_alpha > 0) & ~allowed_hover))
    checks.append(("near hover registered", near_coverage >= 0.95, f"{near_coverage:.1%}"))
    checks.append(("far window has no hover", far_hover_pixels == 0, f"{far_hover_pixels} pixels"))
    checks.append(("hover transparent elsewhere", hover_leaks == 0, f"{hover_leaks} leaked pixels"))

    fireplace_mask = polygon_mask((4096, 2304), [fireplace["targetWallPolygon"]]) > 0
    fire_pixels = plate[fireplace_mask]
    hot = (fire_pixels[:, 0] > 145) & (fire_pixels[:, 1] < 105) & (fire_pixels[:, 2] < 70) & (fire_pixels[:, 0] - fire_pixels[:, 1] > 48)
    checks.append(("cold fireplace pixels", len(fire_pixels) > 50000 and int(hot.sum()) == 0 and metrics["flameOrEmberPixelsAuthored"] is False, f"pixels={len(fire_pixels)} hot={int(hot.sum())}"))
    checks.append(("no door pixels baked", metrics["doorPixelsBakedIntoPlate"] is False, str(metrics["doorPixelsBakedIntoPlate"])))

    checks.append(("door canvas", family["canvas"] == [512, 320], str(family["canvas"])))
    checks.append(("door hinge/anchor", family["hingeImageXY"] == [488.0, 18.0] and family["anchorFromBottomLeft"] == [0.953125, 0.94375], f"{family['hingeImageXY']} {family['anchorFromBottomLeft']}"))
    checks.append(("door display scale", abs(float(family["displayScale"]) - float(geometry["environmentScale"])) < 1e-12, str(family["displayScale"])))

    plate_hinge = np.asarray(door["targetHinge"], dtype=float)
    plate_free = np.asarray(door["targetFreeEnd"], dtype=float)
    closed_vector = plate_free - plate_hinge
    closed_length = float(np.linalg.norm(closed_vector))
    direction = closed_vector / closed_length
    angle = math.degrees(math.atan2(direction[1], -direction[0]))
    checks.append(("closed transformed endpoints", np.linalg.norm(np.asarray(family["plateHinge"]) - plate_hinge) <= 0.001 and np.linalg.norm(np.asarray(family["closedPlateFreeEnd"]) - plate_free) <= 0.001, f"hinge={family['plateHinge']} free={family['closedPlateFreeEnd']}"))
    checks.append(("closed angle", abs(angle - float(door["targetAngleDegrees"])) <= 0.25, f"{angle:.4f}°"))
    checks.append(("closed length", abs(closed_length - float(door["targetLength"])) <= 0.25, f"{closed_length:.3f}px"))

    expected_bbox = np.asarray(
        [
            float(door["targetBBox"][0]) - plate_hinge[0] + 488.0,
            float(door["targetBBox"][1]) - plate_hinge[1] + 18.0,
            float(door["targetBBox"][2]) - plate_hinge[0] + 488.0,
            float(door["targetBBox"][3]) - plate_hinge[1] + 18.0,
        ]
    )
    actual_bbox = np.asarray(family["states"]["closed"]["opaqueBounds"], dtype=float)
    bbox_delta = float(np.abs(actual_bbox - expected_bbox).max())
    checks.append(("closed transformed bbox", bbox_delta <= 2.0, f"worst={bbox_delta:.2f}px actual={actual_bbox.tolist()} expected={expected_bbox.round(2).tolist()}"))

    ratios = door["stateLengthRatios"]
    for state in ("closed", "mid", "open"):
        base_path = STAGE / "Props" / family["states"][state]["file"]
        hover_path = STAGE / "Props" / family["states"][state]["hoverFile"]
        base = Image.open(base_path).convert("RGBA")
        highlighted = Image.open(hover_path).convert("RGBA")
        alpha_equal = np.array_equal(np.asarray(base)[:, :, 3], np.asarray(highlighted)[:, :, 3])
        endpoints = np.asarray(family["states"][state]["registeredImageAxisEndpoints"], dtype=float)
        hinge_delta = float(np.linalg.norm(endpoints[0] - np.asarray([488.0, 18.0])))
        length = float(np.linalg.norm(endpoints[1] - endpoints[0]))
        target = closed_length * float(ratios[state])
        thickness = _actual_maximum_thickness(base, np.asarray([488.0, 18.0]), direction)
        checks.append((f"door {state} registration", hinge_delta <= 0.001 and abs(length - target) <= 0.25, f"hingeΔ={hinge_delta:.3f}px length={length:.3f}/{target:.3f}"))
        checks.append((f"door {state} thickness", abs(thickness - float(door["targetThickness"])) <= 2.5, f"{thickness:.2f}px"))
        checks.append((f"door {state} hover colour only", alpha_equal, "alpha identical" if alpha_equal else "alpha drift"))

    for name, passed, detail in checks:
        print(f"{'PASS' if passed else 'FAIL'}  {name}: {detail}")
    ok = all(passed for _, passed, _ in checks)
    print(f"\nALL_PASS={ok}")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())

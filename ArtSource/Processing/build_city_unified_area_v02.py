#!/usr/bin/env python3
"""Build monolithic Infinity-Engine-style city plates from whole-area masters.

The retired ward rebuild corrected and masked each generated lot independently.
That made the camera mathematically self-consistent while visibly stretching
individual buildings, and any failed sky mask printed a square through the
district.  Infinity Engine areas do not work that way: the background is one
pre-rendered painting (TIS tiles are storage), with navigation, cover and doors
authored separately.

This builder therefore applies at most one camera correction to the complete
area.  A restrained high-pass from the previous 8K flatten restores native
street/brick texture without restoring its low-frequency masks or crop seams.

    python3 ArtSource/Processing/build_city_unified_area_v02.py
    python3 ArtSource/Processing/build_city_unified_area_v02.py sable_row --install
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_city_ward_rebuild_v01 as ward
import qa_plate_projection as projection

ROOT = Path(__file__).resolve().parents[2]
MASTERS = ROOT / "ArtSource/Generated/CityDistrict/V2/UnifiedMasters"
DETAIL = ROOT / "ArtSource/Generated/CityDistrict/V2/WardRebuild"
STAGE = ROOT / "ArtSource/Generated/CityDistrict/V2/UnifiedPlates"
ART = ROOT / "RainShadow Shared/Resources/Art/Areas/CityDistrict/V2"
MAPS = ROOT / "RainShadow Shared/Resources/Art/UI/Map"
AREAS = ROOT / "RainShadow Shared/Resources/Areas"

WORLD_SIZE = (4096, 3072)
PLATE_SIZE = (8192, 6144)
PREVIEW_SIZE = (2048, 1536)
TOLERANCE = 1.5
CORRECTION_TARGET = 0.2
DETAIL_RADIUS = 4.8
DETAIL_STRENGTH = 0.42

SLUGS = tuple(ward.DISTRICTS)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def install_copy(source: Path, destination: Path) -> None:
    """Install without writing through one of the repository's hard links."""
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists() or destination.is_symlink():
        destination.unlink()
    shutil.copy2(source, destination)


def fit_four_three(image: Image.Image) -> Image.Image:
    """Centre-crop uniformly; never resize across aspect ratios."""
    image = image.convert("RGB")
    width, height = image.size
    target = 4.0 / 3.0
    ratio = width / height
    if abs(ratio - target) < 1e-6:
        return image
    if ratio > target:
        crop_width = int(round(height * target))
        x = (width - crop_width) // 2
        return image.crop((x, 0, x + crop_width, height))
    crop_height = int(round(width / target))
    y = (height - crop_height) // 2
    return image.crop((0, y, width, y + crop_height))


def grade(image: Image.Image, directory: Path, name: str) -> dict:
    path = directory / f"_{name}.png"
    image.convert("RGB").save(path)
    return projection.grade(path)


def warp_with_covered_edges(image: Image.Image, measured: dict) -> Image.Image:
    """Correct the whole painting while keeping the output canvas fully painted.

    `_warp_linear` deliberately writes transparent pixels outside its inverse
    sample.  Reflect-padding gives the transform enough source beyond the final
    crop; only the original-sized centre survives, so reflected content cannot
    appear except at the natural outer plate edge.
    """
    array = np.asarray(image.convert("RGB"))
    height, width = array.shape[:2]
    pad_y, pad_x = height // 4, width // 4
    padded = Image.fromarray(
        np.pad(array, ((pad_y, pad_y), (pad_x, pad_x), (0, 0)), mode="reflect")
    )
    warped = ward._warp_from_grade(padded, measured).convert("RGB")
    x = (warped.width - width) // 2
    y = (warped.height - height) // 2
    return warped.crop((x, y, x + width, y + height))


def projection_correct(image: Image.Image, directory: Path, slug: str) -> tuple[Image.Image, dict, int]:
    """Iteratively accept only whole-plate transforms that improve the lock."""
    current = fit_four_three(image)
    measured = grade(current, directory, f"{slug}_projection_0")
    iterations = 0
    for index in range(1, 7):
        if measured["worst_delta"] <= CORRECTION_TARGET:
            break
        candidate = warp_with_covered_edges(current, measured)
        candidate_grade = grade(candidate, directory, f"{slug}_projection_{index}")
        if candidate_grade["worst_delta"] >= measured["worst_delta"] - 0.03:
            break
        current = candidate
        measured = candidate_grade
        iterations = index
    return current, measured, iterations


def restore_native_detail(base: Image.Image, detail_path: Path) -> Image.Image:
    """Restore texture, not geometry, from the old 8K flatten."""
    base = base.convert("RGB").resize(PLATE_SIZE, Image.Resampling.LANCZOS)
    if not detail_path.exists():
        return base
    detail = fit_four_three(Image.open(detail_path)).resize(PLATE_SIZE, Image.Resampling.LANCZOS)
    blurred = detail.filter(ImageFilter.GaussianBlur(DETAIL_RADIUS))
    high_pass = ImageChops.subtract(detail, blurred, scale=1.0, offset=128)
    restored = ImageChops.add(base, high_pass, scale=1.0, offset=-128)
    return Image.blend(base, restored, DETAIL_STRENGTH)


def build(slug: str, install: bool) -> dict:
    source = MASTERS / f"{slug}.png"
    if not source.exists():
        raise FileNotFoundError(f"missing unified master: {source}")
    output = STAGE / slug
    output.mkdir(parents=True, exist_ok=True)

    corrected, source_grade, iterations = projection_correct(Image.open(source), output, slug)
    detail_path = DETAIL / slug / f"city_{slug}_ward_flatten_v01.png"
    plate = restore_native_detail(corrected, detail_path)
    plate_path = output / f"city_{slug}_area_v02.png"
    pre_door = output / f"city_{slug}_area_v02.pre_door.png"
    plate.save(pre_door, compress_level=3)
    plate.save(plate_path, compress_level=3)
    # Do not stamp a separate leaf onto the painting. Infinity Engine doors are
    # tiles of the same art; a drawn overlay is what made the portal read as a
    # decal. Human-scale openings belong in the next master, not a post-pass.
    plate = Image.open(plate_path)
    preview_path = output / f"city_{slug}_area_v02_preview.png"
    plate.resize(PREVIEW_SIZE, Image.Resampling.LANCZOS).save(preview_path)

    installed_grade = projection.grade(plate_path)
    if installed_grade["worst_delta"] > TOLERANCE:
        raise RuntimeError(
            f"{slug}: final plate is {installed_grade['worst_delta']:.2f} degrees off lock"
        )

    spec = ward.DISTRICTS[slug]
    light_path = output / f"{spec['area']}.lm.png"
    map_path = output / spec["map"]
    ward.bake_light(plate).save(light_path)
    ward.hud_map(plate).save(map_path)

    metrics = {
        "slug": slug,
        "architecture": "monolithic-pre-rendered-area",
        "world": list(WORLD_SIZE),
        "plate": list(PLATE_SIZE),
        "nativeMaster": list(corrected.size),
        "wholePlateCorrectionIterations": iterations,
        "sourceProjection": {
            "peak_pos": source_grade["peak_pos"],
            "peak_neg": source_grade["peak_neg"],
            "worst_delta": source_grade["worst_delta"],
        },
        "finalProjection": {
            "peak_pos": installed_grade["peak_pos"],
            "peak_neg": installed_grade["peak_neg"],
            "worst_delta": installed_grade["worst_delta"],
            "passes": True,
        },
        "sha256": sha256(plate_path),
    }
    (output / "metrics.json").write_text(json.dumps(metrics, indent=2) + "\n")

    if install:
        # Existing block names are already bundled by every app target.  The
        # catalog now treats them as the complete plate, not a modular layer.
        install_copy(plate_path, ART / spec["block"])
        install_copy(light_path, AREAS / f"{spec['area']}.lm.png")
        install_copy(map_path, MAPS / spec["map"])
    print(
        f"{slug}: {installed_grade['peak_pos']:+.2f}/{installed_grade['peak_neg']:+.2f} "
        f"delta {installed_grade['worst_delta']:.2f} degrees  PASS"
    )
    return metrics


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("districts", nargs="*", default=list(SLUGS))
    parser.add_argument("--install", action="store_true")
    args = parser.parse_args()
    unknown = sorted(set(args.districts) - set(SLUGS))
    if unknown:
        parser.error(f"unknown districts: {', '.join(unknown)}")
    summary = [build(slug, args.install) for slug in args.districts]
    STAGE.mkdir(parents=True, exist_ok=True)
    (STAGE / "metrics.json").write_text(json.dumps(summary, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Validate and normalize the original V11 office material/fixture sources.

The ImageGen fixture masters currently arrive as RGB images with a rendered
near-white checkerboard.  This importer keys only that neutral light field,
crops to the detected fixture, and writes isolated RGBA fixture sources.  It
never samples the supplied room screenshot and never overwrites a canonical
source unless ``--install`` is supplied.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter


ROOT = Path(__file__).resolve().parents[2]
STAGE = ROOT / "ArtSource/Generated/Office/BGEE1950sV11"
CANONICAL = {
    "floor": STAGE / "floor_material_source_v11.png",
    "wall": STAGE / "wall_material_source_v11.png",
    "window": STAGE / "steel_window_source_v11.png",
    "fireplace": STAGE / "cold_fireplace_source_v11.png",
    "window_relief": STAGE / "steel_window_relief_source_v11.png",
    "fireplace_relief": STAGE / "cold_fireplace_relief_source_v11.png",
    "window_reference_scale": STAGE / "steel_window_reference_scale_source_v11.png",
    "fireplace_reference_scale": STAGE / "cold_fireplace_reference_scale_source_v11.png",
}
NORMALIZED = {
    "window": STAGE / "steel_window_fixture_v11.png",
    "fireplace": STAGE / "cold_fireplace_fixture_v11.png",
    "window_relief": STAGE / "steel_window_relief_fixture_v11.png",
    "fireplace_relief": STAGE / "cold_fireplace_relief_fixture_v11.png",
    "window_reference_scale": STAGE / "steel_window_reference_scale_fixture_v11.png",
    "fireplace_reference_scale": STAGE / "cold_fireplace_reference_scale_fixture_v11.png",
}
MANIFEST = STAGE / "office_v11_source_manifest.json"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _fixture_foreground(source: Image.Image) -> tuple[Image.Image, list[int], float]:
    """Remove a near-white neutral checker field without erasing gray fixtures."""
    source_rgba = np.asarray(source.convert("RGBA"), dtype=np.uint8)
    source_alpha = source_rgba[:, :, 3]
    rgb = source_rgba[:, :, :3].astype(np.float32)

    # Prefer real transparency when ImageGen returned an isolated RGBA asset.
    # Re-keying that image from RGB used to turn its transparent black canvas
    # opaque, which shipped as a black rectangle around each window.
    if np.any(source_alpha < 250):
        alpha_image = Image.fromarray(source_alpha, "L")
        alpha = np.asarray(alpha_image.filter(ImageFilter.GaussianBlur(0.25)))
        ys, xs = np.where(alpha > 24)
        if len(xs) < source.width * source.height * 0.02:
            raise ValueError("fixture alpha contains too few foreground pixels")
        margin = max(3, round(max(source.size) * 0.004))
        x0 = max(0, int(xs.min()) - margin)
        y0 = max(0, int(ys.min()) - margin)
        x1 = min(source.width, int(xs.max()) + margin + 1)
        y1 = min(source.height, int(ys.max()) + margin + 1)
        rgba = source_rgba[y0:y1, x0:x1].copy()
        rgba[:, :, 3] = alpha[y0:y1, x0:x1]
        rgba[rgba[:, :, 3] == 0, :3] = 0
        coverage = float((rgba[:, :, 3] > 24).mean())
        return Image.fromarray(rgba, "RGBA"), [x0, y0, x1, y1], coverage

    maximum = rgb.max(axis=2)
    minimum = rgb.min(axis=2)
    luma = rgb.mean(axis=2)
    saturation = (maximum - minimum) / np.maximum(maximum, 1.0)

    # ImageGen sometimes renders its transparency preview into the RGB result.
    # Those near-white squares contain tiny chroma/noise variations, so a raw
    # saturation vote leaves salt-and-pepper alpha over the whole canvas.  Gate
    # chroma behind the same luminance band as the anti-aliased fixture edge.
    score = np.maximum(
        (236.0 - luma) * 16.0,
        np.where(luma < 238.0, saturation * 720.0, 0.0),
    )
    alpha = np.clip(score, 0.0, 255.0).astype(np.uint8)
    alpha_image = Image.fromarray(alpha, "L")
    # Remove isolated checker/noise grains without changing the connected
    # architectural silhouette, then soften only the retained outer edge.
    alpha_image = alpha_image.filter(ImageFilter.MinFilter(3))
    alpha_image = alpha_image.filter(ImageFilter.MaxFilter(3))
    alpha_image = alpha_image.filter(ImageFilter.GaussianBlur(0.45))
    alpha = np.asarray(alpha_image)
    ys, xs = np.where(alpha > 24)
    if len(xs) < source.width * source.height * 0.02:
        raise ValueError("fixture foreground detector found too few non-background pixels")
    margin = max(3, round(max(source.size) * 0.004))
    x0 = max(0, int(xs.min()) - margin)
    y0 = max(0, int(ys.min()) - margin)
    x1 = min(source.width, int(xs.max()) + margin + 1)
    y1 = min(source.height, int(ys.max()) + margin + 1)
    rgba = np.dstack([rgb.astype(np.uint8), alpha])[y0:y1, x0:x1]
    rgba[rgba[:, :, 3] == 0, :3] = 0
    coverage = float((rgba[:, :, 3] > 24).mean())
    return Image.fromarray(rgba, "RGBA"), [x0, y0, x1, y1], coverage


def _validate(name: str, path: Path) -> dict[str, object]:
    if not path.exists():
        raise RuntimeError(f"missing {name} source: {path}")
    with Image.open(path) as image:
        if image.format != "PNG":
            raise RuntimeError(f"{name} source must be PNG, got {image.format}")
        if min(image.size) < 512:
            raise RuntimeError(f"{name} source is too small: {image.size}")
        record: dict[str, object] = {
            "path": str(path.resolve()),
            "size": list(image.size),
            "mode": image.mode,
            "sha256": sha256(path),
        }
        if name in NORMALIZED:
            fixture, crop, coverage = _fixture_foreground(image)
            record["checkerboardKey"] = {
                "neutralLumaStart": 222,
                "sourceCrop": crop,
                "normalizedSize": list(fixture.size),
                "foregroundCoverage": coverage,
            }
    return record


def _atomic_copy(source: Path, target: Path) -> None:
    if source.resolve() == target.resolve():
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_name(target.name + ".v11-ingesting")
    shutil.copy2(source, temporary)
    temporary.replace(target)


def main() -> None:
    parser = argparse.ArgumentParser()
    for name in CANONICAL:
        parser.add_argument(f"--{name.replace('_', '-')}", dest=name, type=Path)
    parser.add_argument(
        "--install",
        action="store_true",
        help="atomically install candidates and write normalized RGBA fixtures",
    )
    args = parser.parse_args()

    candidates = {
        name: (getattr(args, name) or path).expanduser().resolve()
        for name, path in CANONICAL.items()
    }
    records = {name: _validate(name, path) for name, path in candidates.items()}
    for name, record in records.items():
        print(
            f"PASS {name:9s} {record['size']} {record['mode']} "
            f"sha256={str(record['sha256'])[:16]}…"
        )

    if not args.install:
        print("V11 source preflight passed; no files changed (use --install)")
        return

    STAGE.mkdir(parents=True, exist_ok=True)
    for name, target in CANONICAL.items():
        _atomic_copy(candidates[name], target)

    normalized_records: dict[str, object] = {}
    for name, target in NORMALIZED.items():
        with Image.open(CANONICAL[name]) as source:
            fixture, crop, coverage = _fixture_foreground(source)
        temporary = target.with_name(target.name + ".v11-ingesting")
        fixture.save(temporary, format="PNG", optimize=False)
        temporary.replace(target)
        normalized_records[name] = {
            "file": target.name,
            "size": list(fixture.size),
            "mode": fixture.mode,
            "sourceCrop": crop,
            "foregroundCoverage": coverage,
            "sha256": sha256(target),
        }

    manifest = {
        "version": "BGEE1950sV11",
        "sourcePolicy": (
            "original generated material/fixture sources only; supplied room screenshot "
            "is measurement reference and contributes zero pixels"
        ),
        "sources": {
            name: {
                "file": CANONICAL[name].name,
                "size": records[name]["size"],
                "mode": records[name]["mode"],
                "sha256": sha256(CANONICAL[name]),
            }
            for name in CANONICAL
        },
        "normalizedFixtures": normalized_records,
    }
    temporary_manifest = MANIFEST.with_name(MANIFEST.name + ".v11-ingesting")
    temporary_manifest.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    temporary_manifest.replace(MANIFEST)
    print(f"installed {len(CANONICAL)} isolated V11 sources")
    print(f"wrote {MANIFEST.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

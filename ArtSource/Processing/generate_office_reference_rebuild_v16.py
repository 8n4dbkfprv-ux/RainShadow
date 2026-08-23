#!/usr/bin/env python3
"""Register the V16 compact empty office onto the 4096×2304 plate.

ImageGen supplies the pixels (`office_room_envelope_imagegen_raw_v16.png`).
This stage pads to the V15 source frame, then applies one uniform scale chosen
so the floor's world-space diagonal is at most one visual-range diameter
(448 units at environment 0.395). It does not install over V15.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
STAGE = ROOT / "ArtSource/Generated/Office/BGEEReferenceV16"
SOURCE = STAGE / "office_room_envelope_imagegen_raw_v16.png"
SOURCE_FRAME = (1536, 1024)
CANVAS = (4096, 2304)
ENVIRONMENT_SCALE = 0.395
SIGHT_DIAMETER_WORLD = 448.0
# V15 used scale 2.0. V16 may use less so the compact room stays inside sight.
TRANSLATE = (512.0, 90.0)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def pad_to_source_frame(source: Image.Image) -> Image.Image:
    framed = Image.new("RGB", SOURCE_FRAME, (0, 0, 0))
    scale = min(SOURCE_FRAME[0] / source.width, SOURCE_FRAME[1] / source.height)
    resized = source.resize(
        (round(source.width * scale), round(source.height * scale)),
        Image.Resampling.LANCZOS,
    )
    framed.paste(
        resized,
        ((SOURCE_FRAME[0] - resized.width) // 2, (SOURCE_FRAME[1] - resized.height) // 2),
    )
    return framed


def floor_aabb(source: Image.Image) -> tuple[int, int, int, int]:
    rgb = np.asarray(source, dtype=np.float32)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    floor = (y > 40) & (r > 80) & (r > b + 15) & (g > b)
    ys, xs = np.where(floor)
    if xs.size == 0:
        raise RuntimeError("V16 source has no floor pixels")
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


def choose_scale(framed: Image.Image) -> float:
    x0, y0, x1, y1 = floor_aabb(framed)
    # AABB diagonal in source pixels, then ×scale ×environment = world.
    src_diag = float(np.hypot(x1 - x0, y1 - y0))
    # world = src_diag * scale * ENVIRONMENT_SCALE ≤ SIGHT_DIAMETER_WORLD
    max_scale = SIGHT_DIAMETER_WORLD / (src_diag * ENVIRONMENT_SCALE)
    # Never upscale past V15's 2.0; shrinking is the point.
    return min(2.0, max_scale)


def main() -> None:
    raw = Image.open(SOURCE).convert("RGB")
    framed = pad_to_source_frame(raw)
    scale = choose_scale(framed)
    x0, y0, x1, y1 = floor_aabb(framed)
    world_diag = float(np.hypot(x1 - x0, y1 - y0)) * scale * ENVIRONMENT_SCALE
    resized = framed.resize(
        (round(framed.width * scale), round(framed.height * scale)),
        Image.Resampling.LANCZOS,
    )
    plate = Image.new("RGB", CANVAS, (0, 0, 0))
    plate.paste(resized, (round(TRANSLATE[0]), round(TRANSLATE[1])))
    plate_path = STAGE / "office_reference_rebuild_plate_v16.png"
    plate.save(plate_path, optimize=True)
    metrics = {
        "version": "BGEEReferenceV16",
        "canvas": list(CANVAS),
        "environmentScale": ENVIRONMENT_SCALE,
        "geometryAuthority": "V16 compact BG-scale envelope; not installed over V15",
        "source": {
            "file": SOURCE.name,
            "size": list(raw.size),
            "sha256": sha256(SOURCE),
        },
        "registration": {
            "uniformScale": scale,
            "uniformTranslation": list(TRANSLATE),
            "sourceFloorAABB": [x0, y0, x1, y1],
            "worldAabbDiagonal": world_diag,
            "sightDiameterWorld": SIGHT_DIAMETER_WORLD,
            "fitsVisualRange": world_diag <= SIGHT_DIAMETER_WORLD + 1.0,
            "anisotropicWholePlateResize": False,
        },
        "installedOverV15": False,
    }
    metrics_path = STAGE / "office_reference_rebuild_metrics_v16.json"
    metrics_path.write_text(json.dumps(metrics, indent=2, sort_keys=True) + "\n")
    print(f"wrote {plate_path.relative_to(ROOT)}")
    print(f"wrote {metrics_path.relative_to(ROOT)}")
    print(f"scale={scale:.3f} worldAabbDiag={world_diag:.1f} fits={metrics['registration']['fitsVisualRange']}")


if __name__ == "__main__":
    main()

"""Bake the V10.3 integrated exterior doorway into the shipping suite plate.

The Image Generator supplies the painterly wall/jamb/reveal treatment. This
processor keeps registration deterministic:

* the generated crop is normalized to the exact shipping crop;
* only a feathered doorway region replaces suite pixels;
* the clear opening is re-punched from the measured room plan;
* the previous shipping suite is archived once before replacement.

The separate runtime frame sprite is intentionally no longer required.
"""

from __future__ import annotations

import shutil
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageOps

import office_room_plan as rp

ROOT = Path(__file__).resolve().parents[2]
GEN = ROOT / "ArtSource/Generated/Office"
RUNTIME = ROOT / "RainShadow Shared/Resources/Art/Areas/DetectiveOffice"

IG_SOURCE = GEN / "door_architecture_integrated_ig_v103.png"
PATCH_MASTER = GEN / "door_architecture_integrated_patch_v103.png"
BACKUP = GEN / "door_architecture_v103_pre/office_suite_plate.png"

# Exact crop used as the Image Generator edit target and QA crop.
CROP = (2980, 60, 3350, 620)
EXTERIOR_DOOR_B = 0.425

SUITE_TARGETS = (
    RUNTIME / "office_suite_plate.png",
    GEN / "office_suite_plate.png",
    GEN / "suite_plate_v01/office_suite_plate.png",
)


def _opening_quad() -> list[tuple[float, float]]:
    half_b = rp.EXTERIOR_DOOR_OPENING_B * 0.5
    b0 = EXTERIOR_DOOR_B - half_b
    b1 = EXTERIOR_DOOR_B + half_b
    g0 = rp.plan(0.0, b0)
    g1 = rp.plan(0.0, b1)
    base0 = rp.ne_wall_base(g0[0])
    base1 = rp.ne_wall_base(g1[0])
    return [
        (g0[0], base0),
        (g1[0], base1),
        (g1[0], base1 - rp.BAKED_DOORWAY_H),
        (g0[0], base0 - rp.BAKED_DOORWAY_H),
    ]


def _normalized_patch() -> Image.Image:
    if not IG_SOURCE.exists():
        raise SystemExit(f"missing Image Generator doorway source: {IG_SOURCE}")
    width = CROP[2] - CROP[0]
    height = CROP[3] - CROP[1]
    source = Image.open(IG_SOURCE).convert("RGB")
    # The built-in generator may vary the canvas by a few pixels. Fit to the
    # original registered crop without stretching the projection.
    patch = ImageOps.fit(
        source,
        (width, height),
        method=Image.Resampling.LANCZOS,
        centering=(0.5, 0.5),
    )
    patch.save(PATCH_MASTER)
    return patch


def _feather_mask(size: tuple[int, int]) -> Image.Image:
    width, height = size
    mask = Image.new("L", size, 0)
    # Keep the outer crop boundary untouched; the blur supplies a gentle seam.
    ImageDraw.Draw(mask).rounded_rectangle(
        (14, 10, width - 14, height - 10),
        radius=20,
        fill=255,
    )
    return mask.filter(ImageFilter.GaussianBlur(13))


def _punch_registered_opening(image: Image.Image) -> Image.Image:
    arr = np.asarray(image.convert("RGB"), np.float32).copy()
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).polygon(_opening_quad(), fill=255)
    opening = np.asarray(mask, np.float32) / 255.0

    # A nearly black hall with a tiny vertical falloff reads as depth without
    # turning the approved opening into a glowing portal.
    yy = np.arange(image.height, dtype=np.float32)[:, None]
    hall = np.zeros_like(arr)
    hall[:, :, 0] = 3.0 + yy / image.height * 1.5
    hall[:, :, 1] = 3.5 + yy / image.height * 1.2
    hall[:, :, 2] = 4.0 + yy / image.height * 0.8
    a = opening[:, :, None]
    arr = arr * (1.0 - a) + hall * a
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")


def _patch_suite(source: Path, patch: Image.Image) -> Image.Image:
    suite = Image.open(source).convert("RGB")
    if suite.size != (rp.ART_W, rp.ART_H):
        raise SystemExit(f"unexpected suite size {suite.size}: {source}")
    region = suite.crop(CROP)
    region = Image.composite(patch, region, _feather_mask(region.size))
    suite.paste(region, (CROP[0], CROP[1]))
    return _punch_registered_opening(suite)


def main() -> None:
    runtime = SUITE_TARGETS[0]
    if not runtime.exists():
        raise SystemExit(f"missing shipping suite: {runtime}")
    if not BACKUP.exists():
        BACKUP.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(runtime, BACKUP)

    patch = _normalized_patch()
    final = _patch_suite(runtime, patch)
    for target in SUITE_TARGETS:
        target.parent.mkdir(parents=True, exist_ok=True)
        final.save(target)

    half = final.resize((rp.ART_W // 2, rp.ART_H // 2), Image.Resampling.LANCZOS)
    half.save(GEN / "suite_plate_v01/office_suite_plate_half.png")
    final.crop(CROP).save(GEN / "door_architecture_integrated_runtime_crop_v103.png")
    print(f"baked integrated doorway into {len(SUITE_TARGETS)} suite plates")
    print(f"registered crop={CROP} opening={rp.BAKED_DOORWAY_W:.1f}x{rp.BAKED_DOORWAY_H:.1f}")


if __name__ == "__main__":
    main()

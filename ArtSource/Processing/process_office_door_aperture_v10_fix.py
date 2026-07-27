"""Fix V10 doorway smear: restore clean plates, material-aware shrink, rebuild suite.

The first V10 aperture patch filled surplus with per-pixel neighbor copies and
smeared both openings. This rebuild:

  1. Restores shell / partition / suite from door_aperture_v10_pre/
  2. Restores the NE exterior doorway by column-cloning adjacent wall face,
     then cuts a sharp detective-relative aperture (see DOOR_OPENING_TO_DETECTIVE)
     plus a small recess and hinge knuckles
  3. Repaints the partition from shell materials at the new opening size
  4. Rebakes the registered suite (shell + partition) so the internal opening
     is clean continuous wood, not a smeared hole punch

Does not regenerate leaf/frame IG art — re-run process_office_door_lettered_v01
after this script.
"""

from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import office_room_plan as rp
import process_office_partition_plate_v01 as part
import process_office_suite_plate_v01 as suite

ROOT = Path(__file__).resolve().parents[2]
ART_AREA = ROOT / "RainShadow Shared/Resources/Art/Areas/DetectiveOffice"
ART_PROPS = ROOT / "RainShadow Shared/Resources/Art/Props/Office"
ARCHIVE = ROOT / "ArtSource/Generated/Office/door_aperture_v10_pre"
GEN_OFFICE = ROOT / "ArtSource/Generated/Office"

SHELL_RUNTIME = ART_AREA / "office_shell_base.png"
SUITE_RUNTIME = ART_AREA / "office_suite_plate.png"
PARTITION_RUNTIME = ART_PROPS / "office_partition_wall.png"
OPENING_JSON = ART_PROPS / "office_partition_opening.json"

ART_W, ART_H = rp.ART_W, rp.ART_H
EXTERIOR_DOOR_B = 0.425
OLD_DOOR_H = 445.0
OLD_DOOR_W = OLD_DOOR_H / rp.DOOR_OPENING_ASPECT
OLD_OPENING_B = OLD_DOOR_W / abs(rp.AXIS_NE[0])
NE_SLOPE = rp.AXIS_NE[1] / rp.AXIS_NE[0]


def _poly_mask(pts: list[tuple[float, float]], blur: float = 0.0) -> np.ndarray:
    im = Image.new("L", (ART_W, ART_H), 0)
    ImageDraw.Draw(im).polygon([(float(x), float(y)) for x, y in pts], fill=255)
    if blur > 0:
        im = im.filter(ImageFilter.GaussianBlur(blur))
    return np.asarray(im, np.float32) / 255.0


def _exterior_quad(half_b: float, door_h: float) -> list[tuple[float, float]]:
    b0 = EXTERIOR_DOOR_B - half_b
    b1 = EXTERIOR_DOOR_B + half_b
    g0 = rp.plan(0.0, b0)
    g1 = rp.plan(0.0, b1)
    base0 = rp.ne_wall_base(g0[0])
    base1 = rp.ne_wall_base(g1[0])
    return [
        (g0[0], base0),
        (g1[0], base1),
        (g1[0], base1 - door_h),
        (g0[0], base0 - door_h),
    ]


def _restore_from_archive() -> None:
    required = (
        "office_shell_base.png",
        "office_suite_plate.png",
        "office_partition_wall.png",
        "office_partition_opening.json",
    )
    for name in required:
        src = ARCHIVE / name
        if not src.exists():
            raise SystemExit(f"missing archive plate {src}")
    shutil.copy2(ARCHIVE / "office_shell_base.png", SHELL_RUNTIME)
    shutil.copy2(ARCHIVE / "office_suite_plate.png", SUITE_RUNTIME)
    shutil.copy2(ARCHIVE / "office_partition_wall.png", PARTITION_RUNTIME)
    shutil.copy2(ARCHIVE / "office_partition_opening.json", OPENING_JSON)
    print(f"restored clean V9 plates from {ARCHIVE.name}")


def _sample_hall(rgb: np.ndarray) -> np.ndarray:
    samples = []
    half = OLD_OPENING_B * 0.35
    for b in np.linspace(EXTERIOR_DOOR_B - half, EXTERIOR_DOOR_B + half, 11):
        x, y = rp.plan(0.012, float(b))
        xi, yi = int(round(x)), int(round(y - 120))
        if 0 <= xi < ART_W and 0 <= yi < ART_H:
            samples.append(rgb[yi, xi])
    if not samples:
        return np.array([8.0, 7.0, 5.0], np.float32)
    return np.mean(samples, axis=0).astype(np.float32)


def _restore_ne_wall_over_old_doorway(rgb: np.ndarray) -> np.ndarray:
    """Tile a real NE wall-face band across the old doorway (no per-pixel smear)."""
    src = rgb.astype(np.float32)
    out = src.copy()
    old_half = OLD_OPENING_B * 0.5
    old_mask = _poly_mask(_exterior_quad(old_half, OLD_DOOR_H + 16.0), blur=1.0)
    old_pts = _exterior_quad(old_half, OLD_DOOR_H)
    x_left = min(p[0] for p in old_pts)
    x_right = max(p[0] for p in old_pts)

    # The NE wall left of this doorway is in deep room shadow / near the black
    # exterior silhouette, so left-side donors paint mud. Tile only from the
    # lit plaster band to the RIGHT of the old opening.
    right0, right1 = int(round(x_right + 24)), int(round(x_right + 140))
    right0, right1 = max(0, right0), max(right0 + 12, min(ART_W - 1, right1))
    # Keep only donor columns that are actually plaster-bright mid-face.
    bright_donors: list[int] = []
    probe_y = int(round(rp.ne_wall_base(float(right0)) - rp.WALL_FACE_H * 0.45))
    probe_y = int(np.clip(probe_y, 0, ART_H - 1))
    for dx in range(right0, right1 + 1):
        if float(src[probe_y, dx].mean()) >= 40:
            bright_donors.append(dx)
    if len(bright_donors) < 8:
        bright_donors = list(range(right0, right1 + 1))
    span = len(bright_donors)

    x0 = max(0, int(np.floor(x_left - 8)))
    x1 = min(ART_W, int(np.ceil(x_right + 8)))
    for x in range(x0, x1):
        col_w = old_mask[:, x]
        if float(col_w.max()) < 0.02:
            continue
        top = rp.ne_wall_top(float(x))
        base = rp.ne_wall_base(float(x))
        if base <= top + 1:
            continue
        donor = bright_donors[(x - x0) % span]
        d_top = rp.ne_wall_top(float(donor))
        d_base = rp.ne_wall_base(float(donor))
        y0 = max(0, int(np.floor(min(top, d_top) - 4)))
        y1 = min(ART_H, int(np.ceil(max(base, d_base) + 4)))
        for y in range(y0, y1):
            a = float(col_w[y])
            if a < 0.02:
                continue
            # Map by height above the floor base (stable when crown intercepts
            # go off-plate near the east corner).
            t = (base - float(y)) / max(1e-3, base - top)
            t = float(np.clip(t, 0.0, 1.0))
            sy = int(round(d_base - t * (d_base - d_top)))
            sy = int(np.clip(sy, 0, ART_H - 1))
            sample = src[sy, donor]
            if float(sample.mean()) < 32:
                for tip in (6, 14, 28, 44):
                    alt_i = ((x - x0) + tip) % span
                    alt = bright_donors[alt_i]
                    cand = src[sy, alt]
                    if float(cand.mean()) >= 32:
                        sample = cand
                        break
            out[y, x] = out[y, x] * (1.0 - a) + sample * a

    # Feather only the outer ring — do not blur the restored face itself.
    hard = _poly_mask(_exterior_quad(old_half, OLD_DOOR_H), blur=0.0)
    ring = np.clip(old_mask - hard, 0, 1)
    blur = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB").filter(
        ImageFilter.GaussianBlur(0.55)
    )
    blur_a = np.asarray(blur, np.float32)
    m = (ring * 0.35)[..., None]
    out = out * (1.0 - m) + blur_a * m
    return out


def _cut_exterior_aperture(rgb: np.ndarray) -> np.ndarray:
    out = rgb.astype(np.float32).copy()
    new_half = rp.EXTERIOR_DOOR_OPENING_B * 0.5
    # Sharp cut; 2 px short so soft measurement lands on plan height.
    cut_h = rp.BAKED_DOORWAY_H - 2.0
    hole = _poly_mask(_exterior_quad(new_half, cut_h), blur=0.2)
    # Near-black hall so the opening reads as a void behind the leaf/frame,
    # not a muddy patch the leaf looks pasted onto.
    hall = np.clip(_sample_hall(out) * 0.35, 0, 12)
    noise = (
        ((np.mgrid[0:ART_H, 0:ART_W][0] * 7 + np.mgrid[0:ART_H, 0:ART_W][1] * 13) % 17)
        - 8
    ) * 0.2
    hall_fill = np.clip(hall[None, None, :] + noise[..., None], 0, 16)
    a = hole[..., None]
    out = out * (1.0 - a) + hall_fill * a

    reveal_big = _poly_mask(
        [
            (p[0] + s * 5, p[1] + t * 5)
            for p, (s, t) in zip(
                _exterior_quad(new_half, cut_h),
                ((-1, 1), (1, 1), (1, -1), (-1, -1)),
            )
        ],
        blur=0.35,
    )
    ring = np.clip(reveal_big - hole, 0, 1)
    recess = np.array([28.0, 22.0, 16.0], np.float32)
    out = out * (1.0 - ring[..., None] * 0.7) + recess[None, None, :] * ring[..., None] * 0.7

    # Tiny, dark hinge hints only — bright gray tabs read as bad placeholders
    # against the black gap. Keep them barely above the recess wood.
    b0 = EXTERIOR_DOOR_B - new_half
    g0 = rp.plan(0.0, b0)
    base = rp.ne_wall_base(g0[0])
    half_h = max(1.0, rp.DOOR_HINGE_KNUCKLE_HALF_H * 0.55)
    kw = max(1.0, rp.DOOR_HINGE_KNUCKLE_W * 0.55)
    color = np.array([42.0, 32.0, 22.0], np.float32)
    for k in (0.22, 0.50, 0.78):
        hy = base - rp.BAKED_DOORWAY_H * k
        pts = [
            (g0[0] - 1, hy - half_h),
            (g0[0] + kw, hy - half_h + kw * NE_SLOPE),
            (g0[0] + kw, hy + half_h + kw * NE_SLOPE),
            (g0[0] - 1, hy + half_h),
        ]
        mask = _poly_mask(pts, blur=0.35)
        out = out * (1.0 - mask[..., None] * 0.55) + color * mask[..., None] * 0.55
    return out


def shrink_exterior_shell() -> None:
    shell = np.asarray(Image.open(SHELL_RUNTIME).convert("RGB"), np.float32)
    restored = _restore_ne_wall_over_old_doorway(shell)
    cut = _cut_exterior_aperture(restored)
    im = Image.fromarray(np.clip(cut, 0, 255).astype(np.uint8), "RGB")
    im.save(SHELL_RUNTIME)
    im.save(GEN_OFFICE / "office_shell_base_v10_aperture.png")
    print("wrote material-aware exterior aperture on shell")


def main(argv: list[str] | None = None) -> None:
    import argparse

    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--exterior-only",
        action="store_true",
        help="Re-shrink shell exterior from archive; keep current partition; rebake suite",
    )
    args = ap.parse_args(argv)

    if args.exterior_only:
        shutil.copy2(ARCHIVE / "office_shell_base.png", SHELL_RUNTIME)
        print("restored shell from archive")
        shrink_exterior_shell()
    else:
        _restore_from_archive()
        shrink_exterior_shell()
        print(
            f"painting partition at {rp.DOOR_OPENING_TO_DETECTIVE:.2f}× "
            f"opening ({rp.BAKED_DOORWAY_W:.1f}×{rp.BAKED_DOORWAY_H:.0f})…"
        )
        part.main()

    print("baking registered suite…")
    suite.main([])
    print("V10 aperture fix complete — re-ship door props next")


if __name__ == "__main__":
    main()

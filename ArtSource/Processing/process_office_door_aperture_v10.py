"""V10 wall-locked doorway shrink — apertures only, wall crowns untouched.

Loads the currently shipped shell / suite / partition plates and:
  1. fills the surplus of today's tall exterior + partition openings with
     sampled wall/wood from neighbouring face pixels
  2. cuts the new 1.25× Voss clear openings (≈130×287, H/W 2.20)
  3. paints detective-relative hinge knuckles on both hinge jambs
  4. writes opening JSON used by leaf placement / QA

Does NOT regenerate wall tiling or raise/lower crowns.
"""

from __future__ import annotations

import json
import shutil
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import office_room_plan as rp

ROOT = Path(__file__).resolve().parents[2]
ART_AREA = ROOT / "RainShadow Shared/Resources/Art/Areas/DetectiveOffice"
ART_PROPS = ROOT / "RainShadow Shared/Resources/Art/Props/Office"
GEN_SUITE = ROOT / "ArtSource/Generated/Office/suite_plate_v01"
GEN_PROPS = ROOT / "ArtSource/Generated/Office/Props"
GEN_OFFICE = ROOT / "ArtSource/Generated/Office"
ARCHIVE = GEN_OFFICE / "door_aperture_v10_pre"

SHELL_RUNTIME = ART_AREA / "office_shell_base.png"
SUITE_RUNTIME = ART_AREA / "office_suite_plate.png"
PARTITION_RUNTIME = ART_PROPS / "office_partition_wall.png"
OPENING_JSON = ART_PROPS / "office_partition_opening.json"

ART_W, ART_H = rp.ART_W, rp.ART_H
EXTERIOR_DOOR_B = 0.425
# Pre-V10 clear opening (detective-relative V9) used only to locate surplus.
OLD_DOOR_H = 445.0
OLD_DOOR_W = OLD_DOOR_H / rp.DOOR_OPENING_ASPECT
OLD_OPENING_B = OLD_DOOR_W / abs(rp.AXIS_NE[0])
NE_SLOPE = rp.AXIS_NE[1] / rp.AXIS_NE[0]
P = rp.PARTITION


def _poly_mask(pts: list[tuple[float, float]], blur: float = 0.5) -> np.ndarray:
    im = Image.new("L", (ART_W, ART_H), 0)
    draw = ImageDraw.Draw(im)
    draw.polygon([(float(x), float(y)) for x, y in pts], fill=255)
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


def _partition_quad(b0: float, b1: float, door_h: float) -> list[tuple[float, float]]:
    a_face = P.a_line + P.thickness_a
    d0 = rp.plan(a_face, b0)
    d1 = rp.plan(a_face, b1)
    return [
        (d0[0], d0[1]),
        (d1[0], d1[1]),
        (d1[0], d1[1] - door_h),
        (d0[0], d0[1] - door_h),
    ]


def _sample_hall(rgb: np.ndarray) -> np.ndarray:
    samples = []
    half = OLD_OPENING_B * 0.35
    for b in np.linspace(EXTERIOR_DOOR_B - half, EXTERIOR_DOOR_B + half, 11):
        x, y = rp.plan(0.012, float(b))
        xi, yi = int(round(x)), int(round(y - 120))
        if 0 <= xi < ART_W and 0 <= yi < ART_H:
            samples.append(rgb[yi, xi, :3])
    if not samples:
        return np.array([8.0, 7.0, 5.0], np.float32)
    return np.mean(samples, axis=0).astype(np.float32)


def _fill_exterior_surplus(rgb: np.ndarray) -> np.ndarray:
    """Restore NE wall plaster into the V9 surplus, then cut the V10 aperture."""
    out = rgb.astype(np.float32).copy()
    old_half = OLD_OPENING_B * 0.5
    new_half = rp.EXTERIOR_DOOR_OPENING_B * 0.5
    old_mask = _poly_mask(_exterior_quad(old_half, OLD_DOOR_H), blur=0.7)
    # Cut 2 px short of plan height so soft-edge dark measurement lands on 287.
    cut_h = rp.BAKED_DOORWAY_H - 2.0
    new_mask = _poly_mask(_exterior_quad(new_half, cut_h), blur=0.25)
    surplus = np.clip(old_mask - new_mask, 0, 1)

    # Sample plaster from just outside the old opening at each row.
    old_pts = _exterior_quad(old_half, OLD_DOOR_H)
    x_left = min(p[0] for p in old_pts)
    x_right = max(p[0] for p in old_pts)
    ys, xs = np.where(surplus > 0.05)
    for y, x in zip(ys, xs):
        src_x = int(round(x_left - 18)) if x < (x_left + x_right) * 0.5 else int(round(x_right + 18))
        src_x = int(np.clip(src_x, 0, ART_W - 1))
        # Prefer a lit wall sample; fall back a few pixels if we hit dark void.
        sample = out[y, src_x, :3]
        if float(sample.mean()) < 28:
            for dx in (8, 16, 28, 40):
                alt = int(np.clip(src_x + (-dx if src_x < x else dx), 0, ART_W - 1))
                cand = out[y, alt, :3]
                if float(cand.mean()) >= 28:
                    sample = cand
                    break
        a = float(surplus[y, x])
        out[y, x, :3] = out[y, x, :3] * (1.0 - a) + sample * a

    hall = _sample_hall(out)
    noise = (
        ((np.mgrid[0:ART_H, 0:ART_W][0] * 7 + np.mgrid[0:ART_H, 0:ART_W][1] * 13) % 17) - 8
    ) * 0.35
    hall_fill = np.clip(hall[None, None, :] + noise[..., None], 0, 45)
    a = new_mask[..., None]
    out[:, :, :3] = out[:, :, :3] * (1.0 - a) + hall_fill * a

    # Narrow recess shadow behind the independent frame.
    reveal = _poly_mask(_exterior_quad(new_half, cut_h), blur=0.0)
    # Expand 3px via max-filter approximation using a slightly larger quad.
    reveal_big = _poly_mask(
        [
            (p[0] + s * 3, p[1] + t * 3)
            for p, (s, t) in zip(
                _exterior_quad(new_half, cut_h),
                ((-1, 1), (1, 1), (1, -1), (-1, -1)),
            )
        ],
        blur=0.35,
    )
    ring = np.clip(reveal_big - new_mask, 0, 1)
    recess = np.clip(hall * 1.75, 0, 54)
    m = ring[..., None] * 0.55
    out[:, :, :3] = out[:, :, :3] * (1.0 - m) + recess[None, None, :] * m

    _paint_hinge_knuckles_exterior(out)
    return out


def _paint_hinge_knuckles_exterior(rgb: np.ndarray) -> None:
    """Small knuckles on the exterior hinge (image-left) jamb."""
    half = rp.EXTERIOR_DOOR_OPENING_B * 0.5
    b0 = EXTERIOR_DOOR_B - half
    g0 = rp.plan(0.0, b0)
    base = rp.ne_wall_base(g0[0])
    door_h = rp.BAKED_DOORWAY_H
    half_h = rp.DOOR_HINGE_KNUCKLE_HALF_H
    kw = rp.DOOR_HINGE_KNUCKLE_W
    color = np.array([88.0, 66.0, 44.0], np.float32)
    for k in (0.18, 0.48, 0.78):
        hy = base - door_h * k
        pts = [
            (g0[0] - 1, hy - half_h),
            (g0[0] + kw, hy - half_h + kw * NE_SLOPE),
            (g0[0] + kw, hy + half_h + kw * NE_SLOPE),
            (g0[0] - 1, hy + half_h),
        ]
        mask = _poly_mask(pts, blur=0.25)
        a = mask[..., None] * 0.9
        rgb[:, :, :3] = rgb[:, :, :3] * (1.0 - a) + color[None, None, :] * a


def _fill_partition_surplus(rgba: np.ndarray) -> tuple[np.ndarray, dict]:
    """Restore partition wood into the V9 surplus and cut the V10 opening."""
    out = rgba.astype(np.float32).copy()
    old_b0, old_b1 = 0.078, 0.078 + OLD_OPENING_B
    new_b0, new_b1 = P.b_door0, P.b_door1
    old_mask = _poly_mask(_partition_quad(old_b0, old_b1, OLD_DOOR_H), blur=0.6)
    new_mask = _poly_mask(_partition_quad(new_b0, new_b1, rp.BAKED_DOORWAY_H), blur=0.4)
    surplus = np.clip(old_mask - new_mask, 0, 1)

    a_face = P.a_line + P.thickness_a
    d0 = rp.plan(a_face, new_b0)
    # Sample wood from the hinge-side face just outside the old hole.
    sample_x = int(round(d0[0] - 22))
    ys, xs = np.where(surplus > 0.05)
    for y, x in zip(ys, xs):
        sx = int(np.clip(sample_x, 0, ART_W - 1))
        sample = out[y, sx, :3]
        if float(sample.mean()) < 20 or float(out[y, sx, 3]) < 40:
            for dx in (10, 20, 34):
                alt = int(np.clip(sx - dx, 0, ART_W - 1))
                if float(out[y, alt, 3]) >= 40 and float(out[y, alt, :3].mean()) >= 20:
                    sample = out[y, alt, :3]
                    break
        a = float(surplus[y, x])
        out[y, x, :3] = out[y, x, :3] * (1.0 - a) + sample * a
        out[y, x, 3] = max(float(out[y, x, 3]), 255.0 * a)

    # Clear the new opening (transparent for partition plate).
    a = new_mask
    out[:, :, 3] = out[:, :, 3] * (1.0 - a)
    out[:, :, :3] = out[:, :, :3] * (1.0 - a[..., None])

    # Slim casing ring on the opaque face around the opening.
    casing = _poly_mask(_partition_quad(new_b0, new_b1, rp.BAKED_DOORWAY_H), blur=0.0)
    casing_big = _poly_mask(
        [
            (p[0] + s * max(6.0, P.casing_h * 0.35), p[1] + t * max(6.0, P.casing_h * 0.35))
            for p, (s, t) in zip(
                _partition_quad(new_b0, new_b1, rp.BAKED_DOORWAY_H),
                ((-1, 1), (1, 1), (1, -1), (-1, -1)),
            )
        ],
        blur=0.3,
    )
    ring = np.clip(casing_big - new_mask, 0, 1) * (out[:, :, 3] / 255.0)
    wood = np.array([52.0, 38.0, 24.0], np.float32)
    out[:, :, :3] = out[:, :, :3] * (1.0 - ring[..., None] * 0.55) + wood * ring[..., None] * 0.55

    _paint_hinge_knuckles_partition(out)

    d1 = rp.plan(a_face, new_b1)
    opening = {
        "a_face": a_face,
        "a_back": P.a_line,
        "b_door0": new_b0,
        "b_door1": new_b1,
        "door_h": float(rp.BAKED_DOORWAY_H),
        "hinge_b": new_b0,
        "opening_w_px": float(d1[0] - d0[0]),
        "opening_h_px": float(rp.BAKED_DOORWAY_H),
        "hinge_plate_xy": [float(d0[0]), float(d0[1])],
        "latch_plate_xy": [float(d1[0]), float(d1[1])],
    }
    return out, opening


def _paint_hinge_knuckles_partition(rgba: np.ndarray) -> None:
    a_face = P.a_line + P.thickness_a
    d0 = rp.plan(a_face, P.b_door0)
    door_h = rp.BAKED_DOORWAY_H
    half_h = rp.DOOR_HINGE_KNUCKLE_HALF_H
    kw = rp.DOOR_HINGE_KNUCKLE_W
    color = np.array([78.0, 58.0, 38.0], np.float32)
    for k in (0.18, 0.48, 0.78):
        hy = d0[1] - door_h * k
        pts = [
            (d0[0] - 1, hy - half_h),
            (d0[0] + kw, hy - half_h + kw * NE_SLOPE),
            (d0[0] + kw, hy + half_h + kw * NE_SLOPE),
            (d0[0] - 1, hy + half_h),
        ]
        mask = _poly_mask(pts, blur=0.25)
        a = mask * (rgba[:, :, 3] / 255.0)
        rgba[:, :, :3] = rgba[:, :, :3] * (1.0 - a[..., None]) + color * a[..., None]


def _recompose_suite_partition(
    suite_rgb: np.ndarray,
    shell_rgb: np.ndarray,
    partition_rgba: np.ndarray,
    opening: dict,
) -> np.ndarray:
    """Replace the suite's partition doorway patch with shell+partition composite."""
    out = suite_rgb.astype(np.float32).copy()
    hx, hy = opening["hinge_plate_xy"]
    lx, ly = opening["latch_plate_xy"]
    # Cover both old and new openings so surplus fill lands on the suite.
    pad = 90
    x0 = max(0, int(round(min(hx, lx) - pad)))
    x1 = min(ART_W, int(round(max(hx, lx) + pad)))
    y0 = max(0, int(round(min(hy, ly) - rp.BAKED_DOORWAY_H - pad)))
    y1 = min(ART_H, int(round(max(hy, ly) + 40)))
    # Also include the old taller opening top.
    y0 = max(0, min(y0, int(round(min(hy, ly) - OLD_DOOR_H - 40))))

    part = partition_rgba[y0:y1, x0:x1]
    shell = shell_rgb[y0:y1, x0:x1, :3]
    a = part[:, :, 3:4] / 255.0
    composed = shell * (1.0 - a) + part[:, :, :3] * a
    out[y0:y1, x0:x1, :3] = composed
    if out.shape[2] == 4:
        out[y0:y1, x0:x1, 3] = 255.0
    return out


def _archive(path: Path) -> None:
    ARCHIVE.mkdir(parents=True, exist_ok=True)
    if path.exists():
        shutil.copy2(path, ARCHIVE / path.name)


def main() -> None:
    _archive(SHELL_RUNTIME)
    _archive(SUITE_RUNTIME)
    _archive(PARTITION_RUNTIME)
    _archive(OPENING_JSON)

    shell = np.asarray(Image.open(SHELL_RUNTIME).convert("RGB"), np.float32)
    suite_im = Image.open(SUITE_RUNTIME).convert("RGBA")
    suite = np.asarray(suite_im, np.float32)
    partition = np.asarray(Image.open(PARTITION_RUNTIME).convert("RGBA"), np.float32)

    shell_out = _fill_exterior_surplus(shell)
    # Exterior aperture on the suite plate matches the shell edit.
    suite_rgb = suite[:, :, :3].copy()
    suite_ext = _fill_exterior_surplus(suite_rgb)
    suite[:, :, :3] = suite_ext

    partition_out, opening = _fill_partition_surplus(partition)
    suite = _recompose_suite_partition(suite, shell_out, partition_out, opening)

    Image.fromarray(np.clip(shell_out, 0, 255).astype(np.uint8), "RGB").save(SHELL_RUNTIME)
    Image.fromarray(np.clip(shell_out, 0, 255).astype(np.uint8), "RGB").save(
        GEN_OFFICE / "office_shell_base_v10_aperture.png"
    )
    suite_u8 = np.clip(suite, 0, 255).astype(np.uint8)
    Image.fromarray(suite_u8, "RGBA").save(SUITE_RUNTIME)
    Image.fromarray(suite_u8, "RGBA").save(GEN_OFFICE / "office_suite_plate_v10_aperture.png")
    GEN_SUITE.mkdir(parents=True, exist_ok=True)
    Image.fromarray(suite_u8, "RGBA").save(GEN_SUITE / "office_suite_plate.png")

    part_u8 = np.clip(partition_out, 0, 255).astype(np.uint8)
    Image.fromarray(part_u8, "RGBA").save(PARTITION_RUNTIME)
    GEN_PROPS.mkdir(parents=True, exist_ok=True)
    Image.fromarray(part_u8, "RGBA").save(GEN_PROPS / "office_partition_wall.png")

    OPENING_JSON.write_text(json.dumps(opening, indent=2) + "\n", encoding="utf-8")
    (GEN_PROPS / "office_partition_opening.json").write_text(
        json.dumps(opening, indent=2) + "\n", encoding="utf-8"
    )

    suite_opening = {
        "plate_size": [ART_W, ART_H],
        "source": "v10_aperture_patch: locked wall + shrunk openings",
        "suite_full_b": rp.B_ROOM,
        "b_room": rp.B_ROOM,
        "movable_leaves_baked": False,
        "internal_door": opening,
        "exterior_door_plan": [0.004, EXTERIOR_DOOR_B],
        "note": "Wall crowns frozen; clear openings = 1.25× visible Voss.",
        "authored_jambs": {
            "hinge_face": list(rp.authored(opening["a_face"], opening["b_door0"])),
            "strike_face": list(rp.authored(opening["a_face"], opening["b_door1"])),
            "hinge_back": list(rp.authored(opening["a_back"], opening["b_door0"])),
            "strike_back": list(rp.authored(opening["a_back"], opening["b_door1"])),
            "b_door0": opening["b_door0"],
            "b_door1": opening["b_door1"],
            "a_face": opening["a_face"],
            "a_back": opening["a_back"],
        },
    }
    (GEN_SUITE / "office_suite_opening.json").write_text(
        json.dumps(suite_opening, indent=2) + "\n", encoding="utf-8"
    )

    print(
        "V10 aperture patch:",
        f"opening {opening['opening_w_px']:.1f}x{opening['opening_h_px']:.1f}",
        f"ratio={rp.DOOR_OPENING_TO_DETECTIVE}",
        f"H/W={opening['opening_h_px'] / max(opening['opening_w_px'], 1):.2f}",
    )
    print(f"archived pre-pass plates under {ARCHIVE}")


if __name__ == "__main__":
    main()

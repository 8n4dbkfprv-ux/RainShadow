"""LEGACY — not used for production when office_suite_plate is shipping.

Superseded by the full-suite plate path:
    ArtSource/Processing/process_office_suite_plate_v01.py
    ArtSource/Prompts/office_suite_plate_v01.md

Kept for RAINSHADOW_LEGACY_PARTITION=1 A/B only. Do not extend for production walls.

Originally replaced the obsolete strip-painter (`process_office_architecture_v01.py`).

Systems:
  1. office_partition_wall.png          — continuous full-height wall + doorframe
  2. office_partition_cutaway_mask.png  — visibility only (not collision)
  3. office_partition_wall_cutaway.png  — plate × mask (default gameplay)
  4. office_internal_door_leaf.png      — leaf sized from the plate opening
  5. office_foreground_cutaway.png      — soft void only (no kerb rails)
  6. office_partition_opening.json      — hinge / opening metrics for layout

Usage:
    python3 ArtSource/Processing/process_office_partition_plate_v01.py

If an Image Generator master exists at MASTERS/partition_plate_gen_v01.png it is
registered and colour-matched; otherwise the plate is painted from shell
materials as one continuous face (not modular half-height strips).
"""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import office_room_plan as rp

ROOT = Path(__file__).resolve().parents[2]
SHELL = ROOT / "RainShadow Shared/Resources/Art/Areas/DetectiveOffice/office_shell_base.png"
RUNTIME = ROOT / "RainShadow Shared/Resources/Art/Props/Office"
GENERATED = ROOT / "ArtSource/Generated/Office/Props"
MASTERS = Path.home() / ".cursor/projects/Users-laurensvanoorschot-Desktop-RainShadow/assets"
IG_MASTER = MASTERS / "partition_plate_gen_v01.png"

ART_W, ART_H = rp.ART_W, rp.ART_H
P = rp.PARTITION

# Clean shell sample windows (no recess, no doorway).
SAMPLE_NW = (1_330, 1_580)
SAMPLE_NE = (3_300, 3_560)

OFFICE_TINT = np.array([0.72, 0.76, 0.84], np.float32)
WAITING_WARM = np.array([255.0, 198.0, 140.0], np.float32)
WOOD = np.array([42.0, 30.0, 18.0], np.float32)
WOOD_LIT = np.array([78.0, 58.0, 38.0], np.float32)

NE_SLOPE = rp.AXIS_NE[1] / rp.AXIS_NE[0]
NW_SLOPE = rp.AXIS_NW[1] / rp.AXIS_NW[0]
DEPTH = (-P.thickness_a * rp.AXIS_NW[0], -P.thickness_a * rp.AXIS_NW[1])
CAP_DEPTH = (
    -rp.CAP_DEPTH_FRAC * P.thickness_a * rp.AXIS_NW[0],
    -rp.CAP_DEPTH_FRAC * P.thickness_a * rp.AXIS_NW[1],
)

# Narrow base lip left under the cutaway (wainscot remnant, not a half-wall).
CUTAWAY_LIP_H = 36.0
RNG = np.random.default_rng(20_260_725)


# ------------------------------------------------------------------ materials


def rectified_strip(shell: np.ndarray, x0: int, x1: int, top_fn, y0: float, y1: float) -> np.ndarray:
    height = int(round(y1 - y0))
    strip = np.zeros((height, x1 - x0, 3), np.float32)
    for i, x in enumerate(range(x0, x1)):
        top = top_fn(x)
        ys = np.clip((top + y0 + np.arange(height)).round().astype(int), 0, ART_H - 1)
        strip[:, i] = shell[ys, x, :3]
    return strip


def tile_columns(strip: np.ndarray, width: int, offset: int = 0) -> np.ndarray:
    """Repeat columns without mirroring — mirror tiling reads as wallpaper flip artifacts."""
    src_w = strip.shape[1]
    index = (np.arange(width) + offset) % src_w
    return strip[:, index]


def build_face(plaster: np.ndarray, rail: np.ndarray, wainscot: np.ndarray, width: int) -> np.ndarray:
    # Soften slightly so cracks do not read sharper than the shell plate.
    face = np.concatenate(
        [
            tile_columns(plaster, width, 41),
            tile_columns(rail, width, 17),
            tile_columns(wainscot, width, 113),
        ],
        axis=0,
    )
    # Mild blur on high-frequency plaster only (top band).
    plaster_h = plaster.shape[0]
    band = Image.fromarray(np.clip(face[:plaster_h], 0, 255).astype(np.uint8))
    band = band.filter(ImageFilter.GaussianBlur(0.55))
    face[:plaster_h] = np.asarray(band, np.float32)
    return face


def match_mean_std(src: np.ndarray, ref: np.ndarray, strength: float = 0.85) -> np.ndarray:
    out = src.copy()
    for c in range(3):
        s, r = src[..., c], ref[..., c]
        s_m, s_s = float(s.mean()), float(s.std()) + 1e-3
        r_m, r_s = float(r.mean()), float(r.std()) + 1e-3
        mapped = (s - s_m) * (r_s / s_s) + r_m
        out[..., c] = s * (1.0 - strength) + mapped * strength
    return out


# ------------------------------------------------------------------ drawing


def polygon_mask(points, blur: float = 0.6) -> np.ndarray:
    mask = Image.new("L", (ART_W, ART_H), 0)
    ImageDraw.Draw(mask).polygon([(float(x), float(y)) for x, y in points], fill=255)
    if blur > 0:
        mask = mask.filter(ImageFilter.GaussianBlur(blur))
    return np.asarray(mask, np.float32) / 255.0


def over(rgb: np.ndarray, alpha: np.ndarray, src: np.ndarray, mask: np.ndarray) -> None:
    m = np.clip(mask, 0, 1)[..., None]
    rgb[:] = rgb * (1.0 - m) + src * m
    np.maximum(alpha, mask, out=alpha)


def quad(rgb, alpha, points, colour, grain: float = 0.0, blur: float = 0.55) -> np.ndarray:
    mask = polygon_mask(points, blur)
    flat = np.zeros((ART_H, ART_W, 3), np.float32)
    flat[:] = np.asarray(colour, np.float32)
    if grain:
        flat += (RNG.random((ART_H, ART_W, 1)).astype(np.float32) - 0.5) * grain
    over(rgb, alpha, np.clip(flat, 0, 255), mask)
    return mask


def face_field(texture: np.ndarray, ground: np.ndarray, x0: int, face_h: float) -> np.ndarray:
    field = np.zeros((ART_H, ART_W, 3), np.float32)
    tex_h, tex_w = texture.shape[0], texture.shape[1]
    rows = np.arange(ART_H)
    for i, x in enumerate(range(x0, x0 + len(ground))):
        if not 0 <= x < ART_W:
            continue
        top = ground[i] - face_h
        idx = ((rows - top) / face_h * tex_h).astype(int)
        valid = (idx >= 0) & (idx < tex_h)
        field[valid, x] = texture[np.clip(idx[valid], 0, tex_h - 1), i % tex_w]
    return field


def paint_continuous_face(
    rgb: np.ndarray,
    alpha: np.ndarray,
    texture: np.ndarray,
    a_face: float,
    b0: float,
    b1: float,
    face_h: float,
) -> np.ndarray:
    """One continuous wall face along AXIS_NE — no height breaks."""
    g0, g1 = rp.plan(a_face, b0), rp.plan(a_face, b1)
    if g0[0] > g1[0]:
        g0, g1 = g1, g0
    x0, x1 = int(np.ceil(g0[0])), int(np.floor(g1[0]))
    if x1 <= x0:
        return np.zeros((ART_H, ART_W), np.float32)
    slope = (g1[1] - g0[1]) / (g1[0] - g0[0])
    xs = np.arange(x0, x1 + 1)
    ground = g0[1] + (xs - g0[0]) * slope
    mask = polygon_mask(
        [(g0[0], g0[1]), (g1[0], g1[1]), (g1[0], g1[1] - face_h), (g0[0], g0[1] - face_h)]
    )
    field = face_field(texture, ground, x0, face_h)
    over(rgb, alpha, field, mask)
    return mask


def punch_doorway(alpha: np.ndarray, a_face: float, door_h: float) -> None:
    """Clear the opening so the doorway is cut into the plate, not painted over."""
    d0, d1 = rp.plan(a_face, P.b_door0), rp.plan(a_face, P.b_door1)
    hole = polygon_mask(
        [
            (d0[0] + 2, d0[1] - 2),
            (d1[0] - 2, d1[1] - 2),
            (d1[0] - 2, d1[1] - door_h + 2),
            (d0[0] + 2, d0[1] - door_h + 2),
        ],
        blur=0.4,
    )
    alpha[:] *= 1.0 - hole


def shear_paste(
    rgb: np.ndarray,
    alpha: np.ndarray,
    elev: np.ndarray,
    x_left: float,
    y_base: float,
    slope: float,
) -> None:
    """Composite an upright elevation onto a wall plane (column i at x_left+i)."""
    h, w = elev.shape[:2]
    has_a = elev.shape[-1] == 4
    xl = int(round(x_left))
    src_rows = np.arange(h, dtype=np.float32)
    for i in range(w):
        x = xl + i
        if not 0 <= x < ART_W:
            continue
        base = y_base + i * slope
        top = int(np.floor(base)) - h
        ys = np.arange(top, top + h + 2)
        keep = (ys >= 0) & (ys < ART_H)
        ys = ys[keep]
        if ys.size == 0:
            continue
        src = (ys - base + h).astype(np.float32)
        if has_a:
            m = np.interp(src, src_rows, elev[:, i, 3], left=0.0, right=0.0) / 255.0
        else:
            m = ((src >= -0.5) & (src <= h - 0.5)).astype(np.float32)
        for cc in range(3):
            v = np.interp(src, src_rows, elev[:, i, cc], left=0.0, right=0.0)
            rgb[ys, x, cc] = rgb[ys, x, cc] * (1.0 - m) + v * m
        alpha[ys, x] = np.maximum(alpha[ys, x], m)


# ------------------------------------------------------------------ plate


def paint_partition_plate(mats: dict[str, np.ndarray]) -> tuple[Image.Image, dict]:
    """Full-height coherent partition with integrated doorway."""
    rgb = np.zeros((ART_H, ART_W, 3), np.float32)
    alpha = np.zeros((ART_H, ART_W), np.float32)

    a_face = P.a_line + P.thickness_a
    a_back = P.a_line
    face_h = P.face_h
    door_h = P.door_h
    tex = mats["face"] * OFFICE_TINT
    cap_rgb = mats["plaster"].reshape(-1, 3).mean(0) * 0.52
    reveal = mats["wainscot"].reshape(-1, 3).mean(0)

    # Thin cap along the entire full-height run (rear → near design edge).
    f0, f1 = rp.plan(a_face, -P.overrun_b), rp.plan(a_face, rp.B_ROOM)
    quad(
        rgb,
        alpha,
        [
            (f0[0], f0[1] - face_h),
            (f1[0], f1[1] - face_h),
            (f1[0] + CAP_DEPTH[0], f1[1] + CAP_DEPTH[1] - face_h),
            (f0[0] + CAP_DEPTH[0], f0[1] + CAP_DEPTH[1] - face_h),
        ],
        cap_rgb,
        grain=3.0,
    )

    # ONE continuous full-height face — doorway will be punched out.
    wall_mask = paint_continuous_face(
        rgb, alpha, tex, a_face, -P.overrun_b, rp.B_ROOM, face_h
    )
    punch_doorway(alpha, a_face, door_h)

    # Doorway assembly cut into the wall thickness (same plate).
    d0, d1 = rp.plan(a_face, P.b_door0), rp.plan(a_face, P.b_door1)
    b0, b1 = rp.plan(a_back, P.b_door0), rp.plan(a_back, P.b_door1)

    # Header: top of the shell-matched face texture, sheared so its base sits on
    # the door head — continuous plaster, not a flat grey fill.
    header_h = max(1, int(round(face_h - door_h)))
    x_left = min(d0[0], d1[0])
    width = max(1, int(round(abs(d1[0] - d0[0]))))
    header_tex = np.dstack([tex[:header_h, :width], np.full((header_h, width), 255.0)])
    shear_paste(rgb, alpha, header_tex, x_left, d0[1] - door_h, NE_SLOPE)
    # Cap across the header.
    quad(
        rgb,
        alpha,
        [
            (d0[0], d0[1] - face_h),
            (d1[0], d1[1] - face_h),
            (d1[0] + CAP_DEPTH[0], d1[1] + CAP_DEPTH[1] - face_h),
            (d0[0] + CAP_DEPTH[0], d0[1] + CAP_DEPTH[1] - face_h),
        ],
        cap_rgb,
        grain=2.5,
    )

    # Jamb reveals (wall thickness).
    for face_pt, back_pt, tone in ((d0, b0, 1.25), (d1, b1, 1.05)):
        quad(
            rgb,
            alpha,
            [
                (face_pt[0], face_pt[1]),
                (back_pt[0], back_pt[1]),
                (back_pt[0], back_pt[1] - door_h),
                (face_pt[0], face_pt[1] - door_h),
            ],
            reveal * tone,
            grain=4.0,
        )
    # Header soffit.
    quad(
        rgb,
        alpha,
        [
            (d0[0], d0[1] - door_h),
            (d1[0], d1[1] - door_h),
            (b1[0], b1[1] - door_h),
            (b0[0], b0[1] - door_h),
        ],
        reveal * 0.65,
        grain=3.0,
    )
    # Threshold.
    quad(
        rgb,
        alpha,
        [(d0[0], d0[1]), (d1[0], d1[1]), (b1[0], b1[1]), (b0[0], b0[1])],
        WOOD * 0.9,
        grain=5.0,
    )
    # Face casings (header + jambs) — part of the plate, not a separate prop.
    casing_h = P.casing_h
    jamb_w = max(7.0, rp.WALL_THICKNESS_PX * 0.6)
    quad(
        rgb,
        alpha,
        [
            (d0[0] - 2, d0[1] - door_h),
            (d1[0] + 2, d1[1] - door_h),
            (d1[0] + 2, d1[1] - door_h - casing_h),
            (d0[0] - 2, d0[1] - door_h - casing_h),
        ],
        WOOD_LIT,
        grain=4.0,
    )
    for gx, gy, sign in ((d0[0], d0[1], -1.0), (d1[0], d1[1], 1.0)):
        quad(
            rgb,
            alpha,
            [
                (gx, gy),
                (gx + sign * jamb_w, gy + sign * jamb_w * NE_SLOPE),
                (gx + sign * jamb_w, gy + sign * jamb_w * NE_SLOPE - door_h),
                (gx, gy - door_h),
            ],
            WOOD * 1.05,
            grain=4.0,
        )
    # Hinge knuckles on hinge jamb (b_door0).
    for k in (0.18, 0.48, 0.78):
        hy = d0[1] - door_h * k
        quad(
            rgb,
            alpha,
            [
                (d0[0] - 1, hy - 3),
                (d0[0] + 4, hy - 3 + 4 * NE_SLOPE),
                (d0[0] + 4, hy + 3 + 4 * NE_SLOPE),
                (d0[0] - 1, hy + 3),
            ],
            WOOD_LIT * 1.1,
            grain=1.5,
            blur=0.3,
        )

    # Rear T-junction butt + AO.
    jx, jy = rp.plan(a_face, 0.0)
    butt_w = max(10, int(round(rp.WALL_THICKNESS_PX * 1.4)))
    # Short return onto AXIS_NW into the rear wall mass.
    paint_continuous_face(rgb, alpha, tex[:, :butt_w], a_face, -0.002, 0.002, face_h)
    ys, xs = np.mgrid[0:ART_H, 0:ART_W].astype(np.float32)
    base = jy + (xs - jx) * NE_SLOPE
    height = base - ys
    corner = np.exp(-((xs - jx) / 42.0) ** 2) * np.clip(1.0 - height / face_h, 0.2, 1.0)
    wall = np.clip(alpha, 0, 1)
    rgb *= 1.0 - (corner * wall * 0.42)[..., None]

    # Lighting: cool face, warm doorway spill, floor contact.
    cool = np.clip(height / face_h, 0, 1) * wall_mask
    rgb += cool[..., None] * np.asarray([42.0, 52.0, 74.0], np.float32) / 255.0 * 18.0
    door_cx, door_cy = (d0[0] + d1[0]) * 0.5, (d0[1] + d1[1]) * 0.5
    spill = np.exp(-(((xs - door_cx) / 260.0) ** 2 + ((ys - door_cy + 20) / 170.0) ** 2))
    rgb += (spill * wall)[..., None] * WAITING_WARM / 255.0 * 28.0
    contact = np.clip(1.0 - height / 34.0, 0, 1) * np.clip(height / 2.0, 0, 1) * wall
    rgb *= 1.0 - (contact * 0.45)[..., None]

    # Floor contact shadow (office side).
    shadow = np.zeros((ART_H, ART_W), np.float32)
    for b_lo, b_hi in ((-P.overrun_b, P.b_door0), (P.b_door1, rp.B_ROOM)):
        g0, g1 = rp.plan(a_face, b_lo), rp.plan(a_face, b_hi)
        off = (0.014 * rp.AXIS_NW[0], 0.014 * rp.AXIS_NW[1])
        shadow = np.maximum(
            shadow,
            polygon_mask(
                [
                    (g0[0], g0[1]),
                    (g1[0], g1[1]),
                    (g1[0] + off[0], g1[1] + off[1]),
                    (g0[0] + off[0], g0[1] + off[1]),
                ],
                11.0,
            ),
        )
    dark = np.zeros((ART_H, ART_W, 3), np.float32)
    dark[:] = (6.0, 7.0, 10.0)
    over(rgb, alpha, dark, shadow * 0.5 * (1.0 - wall))

    opening = {
        "a_face": a_face,
        "a_back": a_back,
        "b_door0": P.b_door0,
        "b_door1": P.b_door1,
        "door_h": door_h,
        "hinge_b": P.b_door0,
        "opening_w_px": float(d1[0] - d0[0]),
        "opening_h_px": float(door_h),
        "hinge_plate_xy": [float(d0[0]), float(d0[1])],
        "latch_plate_xy": [float(d1[0]), float(d1[1])],
    }
    out = np.dstack([np.clip(rgb, 0, 255), np.clip(alpha, 0, 1) * 255]).astype(np.uint8)
    return Image.fromarray(out, "RGBA"), opening


def build_cutaway_mask() -> Image.Image:
    """White = keep wall; black = hide upper camera-facing section.

    Rear through short return past the doorway stays fully visible. Past
    `b_return1`, only a narrow base lip remains — not a half-height wall.
    """
    mask = np.zeros((ART_H, ART_W), np.float32)
    a_face = P.a_line + P.thickness_a
    face_h = P.face_h

    # Full visibility for rear → return end.
    g0, g1 = rp.plan(a_face, -P.overrun_b), rp.plan(a_face, P.b_return1)
    full = polygon_mask(
        [
            (g0[0] - 8, g0[1] + 20),
            (g1[0] + 8, g1[1] + 20),
            (g1[0] + 8, g1[1] - face_h - 20),
            (g0[0] - 8, g0[1] - face_h - 20),
        ],
        blur=1.2,
    )
    mask = np.maximum(mask, full)

    # Near run: only a narrow lip (base / wainscot remnant).
    n0, n1 = rp.plan(a_face, P.b_return1), rp.plan(a_face, rp.B_ROOM)
    lip = polygon_mask(
        [
            (n0[0] - 4, n0[1] + 12),
            (n1[0] + 4, n1[1] + 12),
            (n1[0] + 4, n1[1] - CUTAWAY_LIP_H),
            (n0[0] - 4, n0[1] - CUTAWAY_LIP_H),
        ],
        blur=1.5,
    )
    mask = np.maximum(mask, lip)

    # Soften the cut edge at b_return1 so it reads as a camera cut, not a step.
    cut = rp.plan(a_face, P.b_return1)
    ys, xs = np.mgrid[0:ART_H, 0:ART_W].astype(np.float32)
    edge = np.exp(-((xs - cut[0]) / 18.0) ** 2)
    # Slightly lift lip opacity near the cut for a clean finished end.
    mask = np.clip(mask + edge * lip * 0.15, 0, 1)

    im = Image.fromarray((mask * 255).astype(np.uint8), "L")
    return im.convert("RGBA")


def apply_mask(plate: Image.Image, mask: Image.Image) -> Image.Image:
    p = np.asarray(plate).astype(np.float32)
    m = np.asarray(mask.convert("L")).astype(np.float32) / 255.0
    p[..., 3] *= m
    return Image.fromarray(np.clip(p, 0, 255).astype(np.uint8), "RGBA")


def export_leaf(opening: dict, leaf_master: Path | None) -> Image.Image:
    """Door leaf sized exactly to the plate opening, hinged on b_door0, NW shear."""
    door_w = max(8, int(round(opening["opening_w_px"])))
    door_h = max(8, int(round(opening["opening_h_px"])))

    if leaf_master and leaf_master.exists():
        src = np.asarray(Image.open(leaf_master).convert("RGBA")).astype(np.float32)
        # Chroma key if green screen.
        r, g, b = src[..., 0], src[..., 1], src[..., 2]
        green = g - np.maximum(r, b)
        src[..., 3] *= np.clip(1.0 - (green - 8.0) / 46.0, 0, 1)
        ys, xs = np.where(src[..., 3] > 128)
        body = src[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]
        im = Image.fromarray(np.clip(body, 0, 255).astype(np.uint8), "RGBA")
    else:
        # Construct a simple frosted-glass leaf from shell timber tones.
        im = Image.new("RGBA", (door_w, door_h), (0, 0, 0, 0))
        draw = ImageDraw.Draw(im)
        draw.rectangle([0, 0, door_w - 1, door_h - 1], fill=(48, 34, 22, 255))
        glass_top = int(door_h * 0.22)
        glass_bot = int(door_h * 0.72)
        draw.rectangle([6, glass_top, door_w - 7, glass_bot], fill=(110, 108, 102, 200))
        draw.rectangle([8, int(door_h * 0.76), door_w - 9, door_h - 10], fill=(38, 28, 18, 255))
        # Handle on latch side (left of sprite after flip = free edge becomes left).
        draw.ellipse([door_w - 18, int(door_h * 0.48), door_w - 8, int(door_h * 0.48) + 10], fill=(160, 140, 90, 255))

    im = im.resize((door_w, door_h), Image.Resampling.LANCZOS)
    im = im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    body = np.asarray(im).astype(np.float32)

    rise = int(np.ceil(abs(NW_SLOPE) * door_w)) + 2
    canvas_rgb = np.zeros((door_h + rise, door_w, 3), np.float32)
    canvas_a = np.zeros((door_h + rise, door_w), np.float32)
    src_rows = np.arange(door_h, dtype=np.float32)
    for i in range(door_w):
        base = door_h + rise - 1 + i * NW_SLOPE
        ys = np.arange(max(0, int(np.floor(base)) - door_h), door_h + rise)
        src = (ys - base + door_h).astype(np.float32)
        for c in range(3):
            canvas_rgb[ys, i, c] = np.interp(src, src_rows, body[:, i, c], left=0, right=0)
        canvas_a[ys, i] = np.interp(src, src_rows, body[:, i, 3], left=0, right=0) / 255.0
    canvas_rgb *= np.asarray([0.94, 0.96, 1.02], np.float32)
    return Image.fromarray(
        np.dstack([np.clip(canvas_rgb, 0, 255), np.clip(canvas_a, 0, 1) * 255]).astype(np.uint8),
        "RGBA",
    )


def paint_soft_void() -> Image.Image:
    """Design-boundary void only — no kerb rails or end strips."""
    rgb = np.zeros((ART_H, ART_W, 3), np.float32)
    alpha = np.zeros((ART_H, ART_W), np.float32)
    t_ne = rp.WALL_THICKNESS_PX / rp.AXIS_NE_LEN
    void = np.zeros((ART_H, ART_W, 3), np.float32)
    void[:] = (3.0, 4.0, 7.0)
    pts = [
        rp.plan(-0.4, rp.B_ROOM + t_ne),
        rp.plan(rp.A_ROOM + 0.4, rp.B_ROOM + t_ne),
        rp.plan(rp.A_ROOM + 0.4, rp.B_NEAR + 0.6),
        rp.plan(-0.4, rp.B_NEAR + 0.6),
    ]
    mask = polygon_mask(pts, blur=3.5)
    ys = np.mgrid[0:ART_H, 0:ART_W][0].astype(np.float32)
    fade = np.clip((ys - rp.plan(0, rp.B_ROOM)[1]) / 650.0, 0, 1)
    over(rgb, alpha, void, mask * (0.08 + 0.28 * fade))
    return Image.fromarray(
        np.dstack([np.clip(rgb, 0, 255), np.clip(alpha, 0, 1) * 255]).astype(np.uint8), "RGBA"
    )


def sample_shell_materials(shell: np.ndarray) -> dict[str, np.ndarray]:
    """Sample plaster / rail / wainscot bands from the shell plate (RGB float)."""
    px0, px1 = SAMPLE_NW
    plaster = rectified_strip(shell, px0, px1, rp.nw_wall_top, 8.0, rp.PLASTER_H - 12.0)
    rail = rectified_strip(shell, px0, px1, rp.nw_wall_top, rp.PLASTER_H - 12.0, rp.PLASTER_H + 6.0)
    wainscot = rectified_strip(shell, px0, px1, rp.nw_wall_top, rp.PLASTER_H + 6.0, rp.WALL_FACE_H - 4.0)
    ne0, ne1 = SAMPLE_NE
    plaster_ne = rectified_strip(shell, ne0, ne1, rp.ne_wall_top, 8.0, rp.PLASTER_H - 12.0)
    plaster = match_mean_std(plaster, plaster_ne, 0.35)
    return {
        "plaster": plaster,
        "rail": rail,
        "wainscot": wainscot,
        "face": build_face(plaster, rail, wainscot, ART_W),
    }


def try_register_ig_master(shell: np.ndarray, mats: dict) -> Image.Image | None:
    if not IG_MASTER.exists():
        return None
    # Placeholder path: key chroma, resize to plate, colour-match mean to shell plaster.
    rgba = np.asarray(Image.open(IG_MASTER).convert("RGBA")).astype(np.float32)
    r, g, b = rgba[..., 0], rgba[..., 1], rgba[..., 2]
    green = g - np.maximum(r, b)
    rgba[..., 3] *= np.clip(1.0 - (green - 8.0) / 46.0, 0, 1)
    im = Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8), "RGBA")
    if im.size != (ART_W, ART_H):
        im = im.resize((ART_W, ART_H), Image.Resampling.LANCZOS)
    arr = np.asarray(im).astype(np.float32)
    lit = arr[..., 3] > 40
    if lit.any():
        ref = mats["plaster"].reshape(-1, 3)
        arr[..., :3] = match_mean_std(arr[..., :3], np.broadcast_to(ref.mean(0), arr[..., :3].shape), 0.75)
        arr[~lit, 3] = 0
    print(f"registered IG master {IG_MASTER.name}")
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


# ------------------------------------------------------------------ main


def main() -> None:
    shell_im = Image.open(SHELL).convert("RGBA")
    if shell_im.size != (ART_W, ART_H):
        shell_im = shell_im.resize((ART_W, ART_H), Image.Resampling.LANCZOS)
    shell = np.asarray(shell_im).astype(np.float32)
    mats = sample_shell_materials(shell)
    print("shell plaster mean", mats["plaster"].reshape(-1, 3).mean(0).round(1))

    RUNTIME.mkdir(parents=True, exist_ok=True)
    GENERATED.mkdir(parents=True, exist_ok=True)

    plate = try_register_ig_master(shell, mats)
    if plate is None:
        plate, opening = paint_partition_plate(mats)
        print("painted full-height partition from shell materials")
    else:
        # Opening metrics from plan even when IG supplies pixels.
        a_face = P.a_line + P.thickness_a
        d0, d1 = rp.plan(a_face, P.b_door0), rp.plan(a_face, P.b_door1)
        opening = {
            "a_face": a_face,
            "a_back": P.a_line,
            "b_door0": P.b_door0,
            "b_door1": P.b_door1,
            "door_h": P.door_h,
            "hinge_b": P.b_door0,
            "opening_w_px": float(d1[0] - d0[0]),
            "opening_h_px": float(P.door_h),
            "hinge_plate_xy": [float(d0[0]), float(d0[1])],
            "latch_plate_xy": [float(d1[0]), float(d1[1])],
        }

    mask = build_cutaway_mask()
    cutaway = apply_mask(plate, mask)
    leaf_master = MASTERS / "internal_door_leaf_gen_v01.png"
    leaf = export_leaf(opening, leaf_master if leaf_master.exists() else None)
    void = paint_soft_void()

    outputs = [
        (plate, "office_partition_wall.png"),
        (mask, "office_partition_cutaway_mask.png"),
        (cutaway, "office_partition_wall_cutaway.png"),
        (leaf, "office_internal_door_leaf.png"),
        (void, "office_foreground_cutaway.png"),
    ]
    for image, name in outputs:
        image.save(RUNTIME / name)
        image.save(GENERATED / name)
        a = np.asarray(image.convert("RGBA"))[:, :, 3]
        print(f"wrote {name:40s} opaque={(a > 20).sum():,}")

    meta_path = RUNTIME / "office_partition_opening.json"
    meta_path.write_text(json.dumps(opening, indent=2) + "\n", encoding="utf-8")
    (GENERATED / "office_partition_opening.json").write_text(meta_path.read_text(), encoding="utf-8")
    print("wrote office_partition_opening.json", opening)


if __name__ == "__main__":
    main()

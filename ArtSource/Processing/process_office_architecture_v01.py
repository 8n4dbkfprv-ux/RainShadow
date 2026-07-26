"""OBSOLETE — do not use for shipping architecture.

Frozen strip-painter. Production walls are now the full suite plate:

    ArtSource/Processing/process_office_suite_plate_v01.py
    ArtSource/Prompts/office_suite_plate_v01.md

The interim partition-plate path (`process_office_partition_plate_v01.py`) is
also legacy. This file is historical reference only. Do not extend it.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import office_room_plan as rp

ROOT = Path(__file__).resolve().parents[2]
SHELL = ROOT / "RainShadow Shared/Resources/Art/Areas/DetectiveOffice/office_shell_base.png"
RUNTIME = ROOT / "RainShadow Shared/Resources/Art/Props/Office"
GENERATED = ROOT / "ArtSource/Generated/Office/Props"
MASTERS = Path.home() / ".cursor/projects/Users-laurensvanoorschot-Desktop-RainShadow/assets"

ART_W, ART_H = rp.ART_W, rp.ART_H
P = rp.PARTITION
F = rp.FOREGROUND

WALL_ELEV = "partition_wall_elevation_gen_v01.png"
KERB_ELEV = "cutaway_kerb_elevation_gen_v01.png"
CASING_ELEV = "internal_doorway_frame_gen_v01.png"
LEAF_ELEV = "internal_door_leaf_gen_v01.png"

# Band boundaries measured on the generated elevations, as fractions of the
# painted band: (cap end, rail start, rail end, base-shoe start).
WALL_BANDS = (0.049, 0.600, 0.655, 0.935)
KERB_BANDS = (0.095, 0.425, 0.500, 0.935)

# Clean lit sample windows on each rear wall: no recess, no doorway, no stub.
# A new wall face is matched to whichever shell wall it runs parallel to, so it
# inherits that wall's share of the room light instead of an averaged tone.
SAMPLE_NW = (1_330, 1_580)
SAMPLE_NE = (3_300, 3_560)

RNG = np.random.default_rng(20_260_725)


# ------------------------------------------------------------------ chroma key


def key_chroma(path: Path, spill: float = 1.0) -> np.ndarray:
    """Generated master -> float RGBA with the green screen removed."""
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    greenness = g - np.maximum(r, b)
    alpha = np.clip(1.0 - (greenness - 8.0) / 46.0, 0.0, 1.0)
    # De-spill: pull the green channel back to the neighbouring channels where it
    # runs ahead of them, which is only ever chroma bleed on this material.
    ceiling = np.maximum(r, b) + 6.0
    over = np.maximum(g - ceiling, 0.0) * spill
    out = rgb.copy()
    out[..., 1] = g - over
    return np.dstack([out, alpha * 255.0])


def opaque_bbox(rgba: np.ndarray, thresh: float = 128.0) -> tuple[int, int, int, int]:
    ys, xs = np.where(rgba[..., 3] > thresh)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


# ------------------------------------------------------------------ re-banding


def resample_v(band: np.ndarray, height: int) -> np.ndarray:
    """Vertical-only resample of an RGBA band."""
    h = band.shape[0]
    src = np.linspace(0.0, h - 1.0, height)
    lo = np.floor(src).astype(int)
    hi = np.minimum(lo + 1, h - 1)
    t = (src - lo)[:, None, None]
    return band[lo] * (1.0 - t) + band[hi] * t


@dataclass(frozen=True)
class BandLayout:
    """Target pixel heights for the five horizontal bands of a wall face."""

    cap: int
    plaster: int
    rail: int
    wainscot: int
    shoe: int

    @property
    def total(self) -> int:
        return self.cap + self.plaster + self.rail + self.wainscot + self.shoe

    def slices(self) -> list[tuple[str, int]]:
        return [
            ("cap", self.cap),
            ("plaster", self.plaster),
            ("rail", self.rail),
            ("wainscot", self.wainscot),
            ("shoe", self.shoe),
        ]


def reband(elev: np.ndarray, fracs: tuple[float, ...], layout: BandLayout) -> dict[str, np.ndarray]:
    """Cut a generated elevation at its measured band edges, rescale each band."""
    x0, y0, x1, y1 = opaque_bbox(elev)
    band = elev[y0:y1, x0:x1]
    h = band.shape[0]
    edges = [0, *[int(round(f * h)) for f in fracs], h]
    out: dict[str, np.ndarray] = {}
    for (name, target), lo, hi in zip(layout.slices(), edges[:-1], edges[1:]):
        out[name] = resample_v(band[lo:hi], target)
    return out


# ------------------------------------------------------------------ colour match


def rectified_strip(shell: np.ndarray, top_fn, y0: float, y1: float, window) -> np.ndarray:
    """Lift a slanted shell wall band into an upright texture strip."""
    x0, x1 = window
    height = int(round(y1 - y0))
    strip = np.zeros((height, x1 - x0, 3), np.float32)
    for i, x in enumerate(range(x0, x1)):
        top = top_fn(x)
        ys = np.clip((top + y0 + np.arange(height)).round().astype(int), 0, ART_H - 1)
        strip[:, i] = shell[ys, x, :3]
    return strip


def match_to(band: np.ndarray, target: np.ndarray, strength: float = 1.0) -> np.ndarray:
    """Match a band's per-channel mean/spread to a shell sample."""
    out = band.copy()
    src = band[..., :3]
    weight = np.clip(band[..., 3:] / 255.0, 0, 1)
    total = weight.sum() + 1e-5
    for c in range(3):
        s_mean = (src[..., c : c + 1] * weight).sum() / total
        s_std = np.sqrt((((src[..., c : c + 1] - s_mean) ** 2) * weight).sum() / total) + 1e-3
        t_mean = float(target[..., c].mean())
        t_std = float(target[..., c].std()) + 1e-3
        gain = np.clip(t_std / s_std, 0.55, 1.6)
        matched = (src[..., c] - s_mean) * gain + t_mean
        out[..., c] = src[..., c] * (1.0 - strength) + matched * strength
    return np.clip(out, 0, 255)


def match_face(bands: dict[str, np.ndarray], mats: dict[str, np.ndarray], strength: float) -> dict[str, np.ndarray]:
    pairs = {
        "cap": mats["rail"],
        "plaster": mats["plaster"],
        "rail": mats["rail"],
        "wainscot": mats["wainscot"],
        "shoe": mats["rail"],
    }
    return {k: match_to(v, pairs[k], strength) for k, v in bands.items()}


def grime(face: np.ndarray, low: float = 0.80, high: float = 1.06, sigma: float = 34.0) -> np.ndarray:
    """Low-frequency soiling so a long run never reads as one flat panel."""
    h, w = face.shape[:2]
    noise = RNG.random((h, w)).astype(np.float32)
    field = np.asarray(
        Image.fromarray((noise * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(sigma)),
        np.float32,
    )
    field -= field.min()
    field /= max(field.max(), 1e-3)
    field = low + field * (high - low)
    out = face.copy()
    out[..., :3] *= field[..., None]
    return out


def stack_face(bands: dict[str, np.ndarray], layout: BandLayout, width: int) -> np.ndarray:
    """Tile each band to `width` and stack into one face texture."""
    rows = []
    for name, _ in layout.slices():
        band = bands[name]
        src_w = band.shape[1]
        mirrored = np.concatenate([band, band[:, ::-1]], axis=1)
        idx = (np.arange(width) + hash(name) % 97) % (2 * src_w)
        rows.append(mirrored[:, idx])
    return np.concatenate(rows, axis=0)


# ------------------------------------------------------------------ compositing


def polygon_mask(points, blur: float = 0.7) -> np.ndarray:
    mask = Image.new("L", (ART_W, ART_H), 0)
    ImageDraw.Draw(mask).polygon([(float(x), float(y)) for x, y in points], fill=255)
    if blur > 0:
        mask = mask.filter(ImageFilter.GaussianBlur(blur))
    return np.asarray(mask, np.float32) / 255.0


def over(dst_rgb: np.ndarray, dst_a: np.ndarray, rgb: np.ndarray, a: np.ndarray) -> None:
    """Source-over into a straight-alpha canvas."""
    out_a = a + dst_a * (1.0 - a)
    safe = np.maximum(out_a, 1e-5)[..., None]
    dst_rgb[:] = (rgb * a[..., None] + dst_rgb * dst_a[..., None] * (1.0 - a[..., None])) / safe
    dst_a[:] = out_a


def quad(rgb, alpha, points, colour, opacity: float = 1.0, blur: float = 0.7, grain: float = 0.0) -> np.ndarray:
    mask = polygon_mask(points, blur) * opacity
    flat = np.zeros((ART_H, ART_W, 3), np.float32)
    flat[:] = np.asarray(colour, np.float32)
    if grain > 0:
        flat += (RNG.random((ART_H, ART_W, 1)).astype(np.float32) - 0.5) * grain
    over(rgb, alpha, np.clip(flat, 0, 255), mask)
    return mask


def shear_paste(
    rgb: np.ndarray,
    alpha: np.ndarray,
    elev: np.ndarray,
    x_left: float,
    y_base: float,
    slope: float,
) -> np.ndarray:
    """Composite an upright elevation onto a wall plane running on a room axis.

    Column `i` lands at `x_left + i`; its bottom row sits on the wall's ground
    line `y_base + i * slope`. Sub-pixel offsets are interpolated so the top and
    bottom edges stay straight instead of stair-stepping.
    """
    h, w = elev.shape[:2]
    touched = np.zeros((ART_H, ART_W), np.float32)
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
        if not keep.any():
            continue
        ys = ys[keep]
        # source row coordinate for each destination row
        src = (ys - base + h).astype(np.float32)
        col = np.empty((ys.size, 4), np.float32)
        for c in range(4):
            col[:, c] = np.interp(src, src_rows, elev[:, i, c], left=0.0, right=0.0)
        a = np.clip(col[:, 3] / 255.0, 0, 1)
        dst_a = alpha[ys, x]
        out_a = a + dst_a * (1.0 - a)
        safe = np.maximum(out_a, 1e-5)
        rgb[ys, x] = (col[:, :3] * a[:, None] + rgb[ys, x] * dst_a[:, None] * (1.0 - a[:, None])) / safe[:, None]
        alpha[ys, x] = out_a
        touched[ys, x] = np.maximum(touched[ys, x], a)
    return touched


def shade(rgb: np.ndarray, mask: np.ndarray, factor) -> None:
    f = np.asarray(factor, np.float32)
    rgb *= 1.0 - mask[..., None] * (1.0 - f)


def glow(rgb: np.ndarray, mask: np.ndarray, colour, strength: float) -> None:
    rgb += mask[..., None] * np.asarray(colour, np.float32) * strength


# ------------------------------------------------------------------ geometry


# Exact shell-axis slopes — every partition edge, band and threshold uses these.
NE_SLOPE = rp.AXIS_NE[1] / rp.AXIS_NE[0]
NW_SLOPE = rp.AXIS_NW[1] / rp.AXIS_NW[0]

# Wall thickness expressed as a displacement along AXIS_NW (office face → back).
DEPTH = (-P.thickness_a * rp.AXIS_NW[0], -P.thickness_a * rp.AXIS_NW[1])

# Thin sawn lip — shell walls show almost no top face.
CAP_DEPTH = (
    -rp.CAP_DEPTH_FRAC * P.thickness_a * rp.AXIS_NW[0],
    -rp.CAP_DEPTH_FRAC * P.thickness_a * rp.AXIS_NW[1],
)


def face_run(a_face: float, b0: float, b1: float) -> tuple[float, float, int]:
    """(x_left, y_base_at_left, width) for a wall face on the north-east axis."""
    g0, g1 = rp.plan(a_face, b0), rp.plan(a_face, b1)
    return g0[0], g0[1], int(round(g1[0] - g0[0]))


def paint_cap(
    rgb: np.ndarray,
    alpha: np.ndarray,
    a_face: float,
    b0: float,
    b1: float,
    face_h: float,
    colour: np.ndarray,
) -> np.ndarray:
    """Sawn top of a wall run; edges stay parallel to AXIS_NE / AXIS_NW."""
    f0, f1 = rp.plan(a_face, b0), rp.plan(a_face, b1)
    return quad(
        rgb,
        alpha,
        [
            (f0[0], f0[1] - face_h),
            (f1[0], f1[1] - face_h),
            (f1[0] + CAP_DEPTH[0], f1[1] + CAP_DEPTH[1] - face_h),
            (f0[0] + CAP_DEPTH[0], f0[1] + CAP_DEPTH[1] - face_h),
        ],
        colour,
        grain=4.0,
    )


def paint_run_face(
    rgb: np.ndarray,
    alpha: np.ndarray,
    elev: np.ndarray,
    a_face: float,
    b0: float,
    b1: float,
) -> np.ndarray:
    """Shear an upright elevation onto one partition run along AXIS_NE."""
    x_left, y_base, width = face_run(a_face, b0, b1)
    if width <= 0:
        return np.zeros((ART_H, ART_W), np.float32)
    slice_ = elev[:, :width] if width <= elev.shape[1] else elev
    return shear_paste(rgb, alpha, slice_[:, :width], x_left, y_base, NE_SLOPE)


# ------------------------------------------------------------------ plates


def paint_partition(
    mats: dict[str, np.ndarray],
    face: np.ndarray,
    cutaway_face: np.ndarray,
    casing: np.ndarray,
) -> Image.Image:
    """Short full → doorway → short return → long low cutaway, on shell axes."""
    rgb = np.zeros((ART_H, ART_W, 3), np.float32)
    alpha = np.zeros((ART_H, ART_W), np.float32)

    a_face = P.a_line + P.thickness_a
    a_back = P.a_line
    full_h = P.face_h
    low_h = P.cutaway_face_h
    door_h = P.door_h
    casing_h = P.casing_h
    # Cap stays darker than the shell plaster highlight so it never reads as a
    # broad lit slab on top of the wall.
    cap_rgb = mats["plaster"].reshape(-1, 3).mean(0) * np.array([0.55, 0.56, 0.60])
    timber = mats["rail"].reshape(-1, 3).mean(0)
    reveal = mats["wainscot"].reshape(-1, 3).mean(0)

    # Sequence from rear wall toward camera (all runs parallel to AXIS_NE).
    rear = (-P.overrun_b, P.b_door0)
    ret = (P.b_door1, P.b_return1)
    near = (P.b_return1, rp.B_ROOM)

    wall_mask = np.zeros((ART_H, ART_W), np.float32)
    wall_mask = np.maximum(wall_mask, paint_run_face(rgb, alpha, face, a_face, *rear))
    wall_mask = np.maximum(wall_mask, paint_run_face(rgb, alpha, face, a_face, *ret))
    wall_mask = np.maximum(wall_mask, paint_run_face(rgb, alpha, cutaway_face, a_face, *near))

    for b0, b1, h in ((*rear, full_h), (*ret, full_h), (*near, low_h)):
        paint_cap(rgb, alpha, a_face, b0, b1, h, cap_rgb if h == full_h else cap_rgb * 0.88)

    # --- doorway cut into the partition thickness (not pasted in front)
    d0, d1 = rp.plan(a_face, P.b_door0), rp.plan(a_face, P.b_door1)
    back0, back1 = rp.plan(a_back, P.b_door0), rp.plan(a_back, P.b_door1)

    # Header plaster continuous with the full-height runs on both sides.
    header_h = max(1, int(round(full_h - door_h)))
    x_left, y_floor, width = face_run(a_face, P.b_door0, P.b_door1)
    if width > 0:
        shear_paste(rgb, alpha, face[:header_h, :width], x_left, y_floor - door_h, NE_SLOPE)
    paint_cap(rgb, alpha, a_face, P.b_door0, P.b_door1, full_h, cap_rgb)

    # Recess faces = exact wall thickness (AXIS_NW depth).
    for (f, b), colour in (
        ((d0, back0), reveal * 1.28),
        ((d1, back1), reveal * 1.08),
    ):
        quad(
            rgb,
            alpha,
            [(f[0], f[1]), (b[0], b[1]), (b[0], b[1] - door_h), (f[0], f[1] - door_h)],
            colour,
            grain=4.0,
        )
    # Header soffit across the recess.
    quad(
        rgb,
        alpha,
        [
            (d0[0], d0[1] - door_h),
            (d1[0], d1[1] - door_h),
            (back1[0], back1[1] - door_h),
            (back0[0], back0[1] - door_h),
        ],
        reveal * 0.68,
        grain=3.5,
    )
    # Threshold flush with the wall footprint.
    quad(
        rgb,
        alpha,
        [(d0[0], d0[1]), (d1[0], d1[1]), (back1[0], back1[1]), (back0[0], back0[1])],
        timber * 0.76,
        grain=6.0,
    )

    # Face casings: header + two jambs, sitting on the office face only.
    jamb_w = max(6.0, rp.WALL_THICKNESS_PX * 0.55)
    quad(
        rgb,
        alpha,
        [
            (d0[0] - 2, d0[1] - door_h),
            (d1[0] + 2, d1[1] - door_h),
            (d1[0] + 2, d1[1] - door_h - casing_h),
            (d0[0] - 2, d0[1] - door_h - casing_h),
        ],
        timber * 1.02,
        grain=5.0,
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
            timber * 0.94,
            grain=5.0,
        )
    # Three hinge knuckles on the hinge (up-run) jamb.
    hinge = timber * 1.15
    for k in (0.18, 0.48, 0.78):
        hy = d0[1] - door_h * k
        quad(
            rgb,
            alpha,
            [
                (d0[0] - 1, hy - 3),
                (d0[0] + 5, hy - 3 + 5 * NE_SLOPE),
                (d0[0] + 5, hy + 3 + 5 * NE_SLOPE),
                (d0[0] - 1, hy + 3),
            ],
            hinge,
            grain=2.0,
        )

    # Scaled casing ring, clipped to the opening so it cannot float past the wall.
    casing_x = d0[0] - (casing.shape[1] - (d1[0] - d0[0])) * 0.5
    shear_paste(rgb, alpha, casing, casing_x, d0[1] + (casing_x - d0[0]) * NE_SLOPE, NE_SLOPE)

    # --- rear T-junction: short butt into the NW shell wall + strong corner AO
    # A few columns of the same face, sheared onto AXIS_NW, hide the butt seam.
    jx, jy = rp.plan(a_face, 0.0)
    butt_w = max(8, int(round(rp.WALL_THICKNESS_PX * 1.2)))
    butt = face[:, :butt_w]
    shear_paste(rgb, alpha, butt, jx - butt_w * 0.35, jy - 2, NW_SLOPE)
    ys, xs = np.mgrid[0:ART_H, 0:ART_W].astype(np.float32)
    base_at_x = jy + (xs - jx) * NE_SLOPE
    height_above = base_at_x - ys
    corner = np.exp(-((xs - jx) / 48.0) ** 2) * np.clip(1.0 - height_above / full_h, 0.15, 1.0)
    shade(rgb, corner * np.clip(alpha, 0, 1) * 0.70, 0.55)
    join = np.exp(-((xs - jx) / 22.0) ** 2) * wall_mask * 0.35
    shade(rgb, join, 0.78)

    # --- lighting: cool private-office face, warm waiting spill through the door
    cool = np.clip(height_above / full_h, 0, 1) * wall_mask
    rgb += cool[..., None] * np.asarray([48.0, 58.0, 82.0], np.float32) / 255.0 * 22.0

    door_cx, door_cy = (d0[0] + d1[0]) * 0.5, (d0[1] + d1[1]) * 0.5
    spill = np.exp(-(((xs - door_cx) / 280.0) ** 2 + ((ys - door_cy + 20.0) / 180.0) ** 2))
    glow(rgb, spill * np.clip(alpha, 0, 1), [255.0, 198.0, 140.0], 0.14)

    # Jamb / leaf shadow on the office face.
    halo = np.exp(-(((xs - door_cx) / 120.0) ** 2 + ((ys - door_cy + 80.0) / 150.0) ** 2))
    shade(rgb, np.clip(halo - spill * 0.40, 0, 1) * wall_mask * 0.60, 0.66)

    # Thin cap highlight (shell direction) — keep it subtle so the lip stays thin.
    cap_band = (np.abs(height_above - full_h) < 3.0) | (np.abs(height_above - low_h) < 3.0)
    glow(rgb, cap_band.astype(np.float32) * wall_mask * 0.22, [170.0, 165.0, 155.0], 0.05)

    # Floor contact shadow along every run.
    contact = np.clip(1.0 - height_above / 36.0, 0.0, 1.0) * np.clip(height_above / 2.5, 0, 1) * wall_mask
    shade(rgb, contact, 0.52)

    shadow = np.zeros((ART_H, ART_W), np.float32)
    for b0, b1 in (rear, ret, near):
        g0, g1 = rp.plan(a_face, b0), rp.plan(a_face, b1)
        off = (0.016 * rp.AXIS_NW[0], 0.016 * rp.AXIS_NW[1])
        shadow = np.maximum(
            shadow,
            polygon_mask(
                [
                    (g0[0], g0[1]),
                    (g1[0], g1[1]),
                    (g1[0] + off[0], g1[1] + off[1]),
                    (g0[0] + off[0], g0[1] + off[1]),
                ],
                12.0,
            ),
        )
    floor_only = shadow * 0.52 * (1.0 - np.clip(alpha, 0, 1))
    dark = np.zeros((ART_H, ART_W, 3), np.float32)
    dark[:] = np.asarray([6.0, 7.0, 10.0], np.float32)
    over(rgb, alpha, dark, floor_only)

    return to_image(rgb, alpha)


def shell_gate(shell_luma: np.ndarray, x0: float, x1: float, base_at: callable) -> np.ndarray:
    """Per-column mask: 1 where the shell still paints room just past a wall base.

    The plate crops the room's east corner, so a run that keeps going lands on
    black and reads as a beam floating outside the building.
    """
    gate = np.zeros(ART_W, np.float32)
    lo, hi = int(min(x0, x1)), int(max(x0, x1))
    for x in range(max(lo, 0), min(hi, ART_W)):
        base = int(round(base_at(x)))
        window = shell_luma[max(0, base - 40) : min(ART_H, base + 40), x]
        gate[x] = 1.0 if window.size and window.max() > 15.0 else 0.0
    kernel = np.ones(41, np.float32) / 41.0
    return np.clip(np.convolve(gate, kernel, mode="same") * 1.6, 0.0, 1.0)


def paint_foreground(
    mats: dict[str, dict[str, np.ndarray]],
    kerbs: dict[str, np.ndarray],
    shell_luma: np.ndarray,
) -> Image.Image:
    """Short low returns only — open centre stretches, no continuous barrier."""
    rgb = np.zeros((ART_H, ART_W, 3), np.float32)
    alpha = np.zeros((ART_H, ART_W), np.float32)

    face_h = F.face_h
    cap_rgb = mats["ne"]["plaster"].reshape(-1, 3).mean(0) * 0.80
    t_nw = F.thickness / rp.AXIS_NW_LEN
    t_ne = F.thickness / rp.AXIS_NE_LEN
    o = F.overrun
    rlen = F.return_len

    # Soft void past the design boundary — translucent, never a tall dark wall.
    void_rgb = np.zeros((ART_H, ART_W, 3), np.float32)
    void_alpha = np.zeros((ART_H, ART_W), np.float32)
    void = np.zeros((ART_H, ART_W, 3), np.float32)
    void[:] = np.asarray([3.0, 4.0, 7.0], np.float32)
    void_pts = [
        rp.plan(-0.40, rp.B_ROOM + t_ne),
        rp.plan(rp.A_ROOM + 0.40, rp.B_ROOM + t_ne),
        rp.plan(rp.A_ROOM + 0.40, rp.B_NEAR + 0.60),
        rp.plan(-0.40, rp.B_NEAR + 0.60),
    ]
    void_mask = polygon_mask(void_pts, blur=3.0)
    ys_v = np.mgrid[0:ART_H, 0:ART_W][0].astype(np.float32)
    depth_fade = np.clip((ys_v - rp.plan(0, rp.B_ROOM)[1]) / 600.0, 0.0, 1.0)
    void_opacity = void_mask * (0.10 + 0.32 * depth_fade)
    void *= (1.0 - depth_fade * 0.30)[..., None]
    over(void_rgb, void_alpha, np.clip(void, 0, 255), void_opacity)

    depth_nw = (t_nw * rp.AXIS_NW[0], t_nw * rp.AXIS_NW[1])
    depth_ne = (t_ne * rp.AXIS_NE[0], t_ne * rp.AXIS_NE[1])

    # Short returns on the B_ROOM edge (parallel to AXIS_NW): left corner,
    # partition T-junction, right corner. Centre stretches stay open.
    a_part0 = P.a_line - 0.04
    a_part1 = P.a_line + P.thickness_a + 0.04
    east_segments = (
        (rp.A_ROOM - rlen, rp.A_ROOM + o),
        (a_part0, a_part1),
        (-o, rlen),
    )
    # Short return on the A_ROOM edge (parallel to AXIS_NE): only at the near corner.
    west_segments = ((rp.B_ROOM - rlen, rp.B_ROOM + o),)

    runs: list[tuple[str, tuple[float, float], tuple[float, float], float, tuple[float, float]]] = []
    for a0, a1 in east_segments:
        g0 = rp.plan(a0, rp.B_ROOM + t_ne)
        g1 = rp.plan(a1, rp.B_ROOM + t_ne)
        runs.append(("nw", g0, g1, NW_SLOPE, depth_ne))
    for b0, b1 in west_segments:
        g0 = rp.plan(rp.A_ROOM + t_nw, b0)
        g1 = rp.plan(rp.A_ROOM + t_nw, b1)
        runs.append(("ne", g0, g1, NE_SLOPE, depth_nw))

    cap_mask = np.zeros((ART_H, ART_W), np.float32)
    for _, g0, g1, slope, depth in runs:
        if abs(g1[0] - g0[0]) < 3:
            continue
        thin = (depth[0] * rp.CAP_DEPTH_FRAC, depth[1] * rp.CAP_DEPTH_FRAC)
        cap_mask = np.maximum(
            cap_mask,
            quad(
                rgb,
                alpha,
                [
                    (g0[0], g0[1] - face_h),
                    (g1[0], g1[1] - face_h),
                    (g1[0] - thin[0], g1[1] - thin[1] - face_h),
                    (g0[0] - thin[0], g0[1] - thin[1] - face_h),
                ],
                cap_rgb,
                grain=4.0,
            ),
        )

    face_mask = np.zeros((ART_H, ART_W), np.float32)
    for side, g0, g1, slope, _ in runs:
        width = int(round(abs(g1[0] - g0[0])))
        if width < 3:
            continue
        left = g0 if g0[0] <= g1[0] else g1
        face_mask = np.maximum(
            face_mask, shear_paste(rgb, alpha, kerbs[side][:, :width], left[0], left[1], slope)
        )

    ys = np.mgrid[0:ART_H, 0:ART_W][0].astype(np.float32)
    fall = np.clip(0.68 - (ys - 1_200.0) / 2_800.0, 0.42, 0.68)
    shade(rgb, face_mask * np.clip(1.0 - cap_mask, 0, 1), fall[..., None])
    shade(rgb, face_mask * 0.22, 0.58)

    gate = np.zeros(ART_W, np.float32)
    for _, g0, g1, slope, _ in runs:
        gate = np.maximum(
            gate, shell_gate(shell_luma, g0[0], g1[0], lambda x, g=g0, s=slope: g[1] + (x - g[0]) * s)
        )
    alpha *= np.maximum(gate[None, :], 0.15)

    over(void_rgb, void_alpha, rgb, alpha)
    return to_image(void_rgb, void_alpha)


def export_leaf(leaf: np.ndarray) -> Image.Image:
    """Door leaf swung 90° into the private office, sheared onto the NW axis."""
    door_w = int(round(rp.plan(0, P.b_door1)[0] - rp.plan(0, P.b_door0)[0]))
    door_h = int(round(P.door_h))
    x0, y0, x1, y1 = opaque_bbox(leaf)
    body = leaf[y0:y1, x0:x1]
    im = Image.fromarray(np.clip(body, 0, 255).astype(np.uint8), "RGBA")
    im = im.resize((door_w, door_h), Image.Resampling.LANCZOS)
    # Hinges must land on the jamb, which is the up-run side of the opening.
    im = im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    body = np.asarray(im).astype(np.float32)

    rise = int(np.ceil(abs(NW_SLOPE) * door_w)) + 2
    canvas_rgb = np.zeros((door_h + rise, door_w, 3), np.float32)
    canvas_a = np.zeros((door_h + rise, door_w), np.float32)
    src_rows = np.arange(door_h, dtype=np.float32)
    for i in range(door_w):
        # Column 0 is the free (handle) edge, furthest into the room.
        base = door_h + rise - 1 + i * NW_SLOPE
        ys = np.arange(max(0, int(np.floor(base)) - door_h), door_h + rise)
        src = (ys - base + door_h).astype(np.float32)
        for c in range(3):
            canvas_rgb[ys, i, c] = np.interp(src, src_rows, body[:, i, c], left=0.0, right=0.0)
        canvas_a[ys, i] = np.interp(src, src_rows, body[:, i, 3], left=0.0, right=0.0) / 255.0

    # Cool the office-facing side slightly and darken the hinge stile.
    canvas_rgb *= np.asarray([0.94, 0.96, 1.02], np.float32)
    edge = np.clip(np.linspace(1.0, 0.82, door_w), 0, 1)[None, :, None]
    canvas_rgb *= edge
    return to_image(canvas_rgb, canvas_a)


def to_image(rgb: np.ndarray, alpha: np.ndarray) -> Image.Image:
    out = np.dstack([np.clip(rgb, 0, 255), np.clip(alpha, 0, 1) * 255.0]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


# ------------------------------------------------------------------ main


def main() -> None:
    shell_im = Image.open(SHELL).convert("RGBA")
    if shell_im.size != (ART_W, ART_H):
        shell_im = shell_im.resize((ART_W, ART_H), Image.Resampling.LANCZOS)
    shell = np.asarray(shell_im).astype(np.float32)

    mats = {}
    for key, top_fn, window in (("nw", rp.nw_wall_top, SAMPLE_NW), ("ne", rp.ne_wall_top, SAMPLE_NE)):
        # Offsets measured off the shell: plaster fades into the chair rail at
        # 219, the rail timber runs 222-237, wainscot starts at 240.
        mats[key] = {
            "plaster": rectified_strip(shell, top_fn, 10.0, 216.0, window),
            "rail": rectified_strip(shell, top_fn, 222.0, 237.0, window),
            "wainscot": rectified_strip(shell, top_fn, 240.0, rp.WALL_FACE_H - 6.0, window),
        }
        for name, strip in mats[key].items():
            print(f"shell {key} {name:9s} mean={strip.reshape(-1, 3).mean(0).round(1)}")

    wall_layout = BandLayout(cap=16, plaster=195, rail=16, wainscot=111, shoe=10)
    assert wall_layout.total == int(P.face_h), wall_layout.total
    # Partition cutaway past the return: chair/desk height, wainscot + thin plaster.
    cutaway_layout = BandLayout(cap=6, plaster=4, rail=8, wainscot=46, shoe=8)
    assert cutaway_layout.total == int(P.cutaway_face_h), cutaway_layout.total
    # Foreground returns: short lip only.
    kerb_layout = BandLayout(cap=4, plaster=2, rail=4, wainscot=10, shoe=4)
    assert kerb_layout.total == int(F.face_h), kerb_layout.total

    wall_elev = key_chroma(MASTERS / WALL_ELEV)
    kerb_elev = key_chroma(MASTERS / KERB_ELEV)
    face = grime(
        stack_face(match_face(reband(wall_elev, WALL_BANDS, wall_layout), mats["ne"], 0.85), wall_layout, ART_W)
    )
    # Reuse the kerb elevation for both the partition's low run and the foreground.
    cutaway_face = grime(
        stack_face(
            match_face(reband(kerb_elev, KERB_BANDS, cutaway_layout), mats["ne"], 0.85),
            cutaway_layout,
            ART_W,
        ),
        low=0.78,
        high=1.05,
        sigma=22.0,
    )
    kerbs = {
        side: grime(
            stack_face(
                match_face(reband(kerb_elev, KERB_BANDS, kerb_layout), mats[side], 0.85), kerb_layout, ART_W
            ),
            low=0.74,
            high=1.04,
            sigma=18.0,
        )
        for side in ("nw", "ne")
    }

    casing = prepare_casing(key_chroma(MASTERS / CASING_ELEV), mats["ne"])
    leaf = key_chroma(MASTERS / LEAF_ELEV)

    RUNTIME.mkdir(parents=True, exist_ok=True)
    GENERATED.mkdir(parents=True, exist_ok=True)

    shell_luma = shell[..., :3] @ np.array([0.299, 0.587, 0.114], np.float32)
    plates = [
        (paint_partition(mats["ne"], face, cutaway_face, casing), "office_partition_wall.png"),
        (paint_foreground(mats, kerbs, shell_luma), "office_foreground_cutaway.png"),
        (export_leaf(leaf), "office_internal_door_leaf.png"),
    ]
    for image, name in plates:
        image.save(RUNTIME / name)
        image.save(GENERATED / name)
        a = np.asarray(image)[:, :, 3]
        print(f"wrote {name:34s} size={image.size} opaque={(a > 20).sum():,}")

    # Retire the slab-era plates so nothing can load them again.
    for stale in (
        "office_suite_architecture.png",
        "office_suite_architecture_graybox.png",
        "office_foreground_wall_graybox.png",
    ):
        path = RUNTIME / stale
        if path.exists():
            path.unlink()
            print(f"retired {stale}")


def prepare_casing(casing: np.ndarray, mats: dict[str, np.ndarray]) -> np.ndarray:
    """Scale the generated casing so its opening matches the planned doorway."""
    x0, y0, x1, y1 = opaque_bbox(casing)
    ring = casing[y0:y1, x0:x1]

    # The opening is the interior region the key punched out of the casing.
    inner = ring[..., 3] < 96
    ys, xs = np.where(inner)
    pad = 4
    keep = (ys > pad) & (ys < ring.shape[0] - pad) & (xs > pad) & (xs < ring.shape[1] - pad)
    ys, xs = ys[keep], xs[keep]
    hole = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)

    door_w = rp.plan(0, P.b_door1)[0] - rp.plan(0, P.b_door0)[0]
    scale_x = door_w / (hole[2] - hole[0])
    scale_y = P.door_h / (hole[3] - hole[1])
    im = Image.fromarray(np.clip(ring, 0, 255).astype(np.uint8), "RGBA")
    im = im.resize(
        (max(1, int(round(ring.shape[1] * scale_x))), max(1, int(round(ring.shape[0] * scale_y)))),
        Image.Resampling.LANCZOS,
    )
    scaled = np.asarray(im).astype(np.float32)

    # Trim to the casing itself: the surrounding wall strip is already painted.
    hole_y1 = int(round(hole[3] * scale_y))
    bottom = min(scaled.shape[0], hole_y1 + 6)
    scaled = scaled[:bottom]
    matched = match_to(scaled, mats["rail"], 0.85)
    matched[..., 3] = scaled[..., 3]

    # Mean-matching alone leaves the generated casing's highlights reading as pale
    # stone next to the room's timber, so its bright end is pinned to the shell's
    # own trim highlights as well.
    lit = matched[..., 3] > 128
    if lit.any():
        luma = matched[..., :3] @ np.array([0.299, 0.587, 0.114], np.float32)
        rail_luma = mats["rail"] @ np.array([0.299, 0.587, 0.114], np.float32)
        gain = float(np.percentile(rail_luma, 96) * 1.45 / max(np.percentile(luma[lit], 96), 1e-3))
        matched[..., :3] *= np.clip(gain, 0.30, 1.15)
    return matched


if __name__ == "__main__":
    main()

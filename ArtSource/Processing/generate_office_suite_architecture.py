"""Paint the interior partition and the low cutaway kerb from shell material.

Both plates are built in the shell's floor-plan basis (`office_room_plan`) so
every edge runs on a real room axis, and every surface is textured with pixels
lifted out of `office_shell_base.png` — the plaster cracks, nicotine staining,
wainscot grime and chair-rail timber are the shell's own, not flat fills.

Outputs (full 4096x2304 plates, registered to the shell):
  office_partition_wall.png     solid plaster run -> framed doorway -> glazed screen
  office_foreground_cutaway.png low kerb along both camera-near floor edges
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import office_room_plan as rp

ROOT = Path(__file__).resolve().parents[2]
SHELL = ROOT / "RainShadow Shared/Resources/Art/Areas/DetectiveOffice/office_shell_base.png"
RUNTIME = ROOT / "RainShadow Shared/Resources/Art/Props/Office"
GENERATED = ROOT / "ArtSource/Generated/Office/Props"

ART_W, ART_H = rp.ART_W, rp.ART_H
P = rp.PARTITION
F = rp.FOREGROUND

# Material sample windows on the north-west wall: bright, clean, no window recess.
PLASTER_SAMPLE_X = (1_330, 1_580)
WAINSCOT_SAMPLE_X = (1_330, 1_580)

# Interior partition is lit indirectly; the shell sample comes off a moonlit wall.
OFFICE_TINT = np.array([0.66, 0.70, 0.78])
WAITING_TINT = np.array([0.82, 0.74, 0.62])

# Joinery palette measured off the shell's own exterior door casing.
WOOD_BASE = np.array([42.0, 30.0, 18.0])
WOOD_LIT = np.array([84.0, 65.0, 43.0])
WOOD_SHADOW = np.array([20.0, 14.0, 8.0])
GLASS_TINT = np.array([62.0, 58.0, 52.0])

RNG = np.random.default_rng(20_260_725)


# ---------------------------------------------------------------- material


def rectified_strip(shell: np.ndarray, x0: int, x1: int, top_fn, y0: float, y1: float) -> np.ndarray:
    """Lift a slanted wall band into an upright texture strip."""
    height = int(round(y1 - y0))
    strip = np.zeros((height, x1 - x0, 3), np.float32)
    for i, x in enumerate(range(x0, x1)):
        top = top_fn(x)
        ys = np.clip((top + y0 + np.arange(height)).round().astype(int), 0, ART_H - 1)
        strip[:, i] = shell[ys, x, :3]
    return strip


def tile_columns(strip: np.ndarray, width: int, offset: int = 0) -> np.ndarray:
    """Repeat a strip horizontally, mirroring alternate copies to hide the seam."""
    src_w = strip.shape[1]
    mirrored = np.concatenate([strip, strip[:, ::-1]], axis=1)
    index = (np.arange(width) + offset) % (2 * src_w)
    return mirrored[:, index]


def build_face_texture(plaster: np.ndarray, rail: np.ndarray, wainscot: np.ndarray, width: int) -> np.ndarray:
    """Full wall face in shell proportions: plaster over chair rail over wainscot."""
    face = np.concatenate(
        [
            tile_columns(plaster, width, offset=41),
            tile_columns(rail, width, offset=17),
            tile_columns(wainscot, width, offset=113),
        ],
        axis=0,
    )
    return face


# ---------------------------------------------------------------- drawing


def polygon_mask(points, blur: float = 0.7) -> np.ndarray:
    mask = Image.new("L", (ART_W, ART_H), 0)
    ImageDraw.Draw(mask).polygon([(float(x), float(y)) for x, y in points], fill=255)
    if blur > 0:
        mask = mask.filter(ImageFilter.GaussianBlur(blur))
    return np.asarray(mask, np.float32) / 255.0


def composite(dst_rgb: np.ndarray, dst_a: np.ndarray, rgb: np.ndarray, mask: np.ndarray) -> None:
    """Source-over of an opaque colour field limited by `mask`."""
    m = mask[..., None]
    dst_rgb *= 1.0 - m
    dst_rgb += rgb * m
    np.maximum(dst_a, mask, out=dst_a)


def face_field(texture: np.ndarray, ground_of_x: np.ndarray, x0: int, face_h: float) -> np.ndarray:
    """Place a face texture so its bottom row follows the wall's ground line."""
    field = np.zeros((ART_H, ART_W, 3), np.float32)
    tex_h = texture.shape[0]
    rows = np.arange(ART_H)
    for i, x in enumerate(range(x0, x0 + len(ground_of_x))):
        if not 0 <= x < ART_W:
            continue
        ground = ground_of_x[i]
        top = ground - face_h
        idx = ((rows - top) / face_h * tex_h).astype(int)
        valid = (idx >= 0) & (idx < tex_h)
        field[valid, x] = texture[np.clip(idx[valid], 0, tex_h - 1), i % texture.shape[1]]
    return field


def wall_run(
    canvas_rgb: np.ndarray,
    canvas_a: np.ndarray,
    a_face: float,
    b0: float,
    b1: float,
    face_h: float,
    texture: np.ndarray,
    axis: str,
) -> tuple[np.ndarray, np.ndarray]:
    """Paint one straight wall face; returns (mask, ground line per column)."""
    if axis == "ne":
        g0, g1 = rp.plan(a_face, b0), rp.plan(a_face, b1)
    else:
        g0, g1 = rp.plan(b0, a_face), rp.plan(b1, a_face)
    if g0[0] > g1[0]:
        g0, g1 = g1, g0
    x_start, x_end = int(np.ceil(g0[0])), int(np.floor(g1[0]))
    slope = (g1[1] - g0[1]) / (g1[0] - g0[0])
    xs = np.arange(x_start, x_end + 1)
    ground = g0[1] + (xs - g0[0]) * slope

    mask = polygon_mask(
        [
            (g0[0], g0[1]),
            (g1[0], g1[1]),
            (g1[0], g1[1] - face_h),
            (g0[0], g0[1] - face_h),
        ]
    )
    field = face_field(texture, ground, x_start, face_h)
    composite(canvas_rgb, canvas_a, field, mask)
    return mask, ground


def quad(
    canvas_rgb,
    canvas_a,
    points,
    rgb,
    alpha: float = 1.0,
    blur: float = 0.7,
    grain: float = 0.0,
) -> np.ndarray:
    mask = polygon_mask(points, blur) * alpha
    flat = np.zeros((ART_H, ART_W, 3), np.float32)
    flat[:] = np.asarray(rgb, np.float32)
    if grain > 0:
        flat += (RNG.random((ART_H, ART_W, 1)).astype(np.float32) - 0.5) * grain
    composite(canvas_rgb, canvas_a, flat, mask)
    return mask


def timber(canvas_rgb, canvas_a, points, tone=None, lit_edge: str | None = None) -> None:
    """Dark joinery with a lit arris, matching the shell's door casing."""
    quad(canvas_rgb, canvas_a, points, WOOD_BASE if tone is None else tone, grain=9.0)
    if lit_edge is None:
        return
    (x0, y0), (x1, y1), (x2, y2), (x3, y3) = points
    if lit_edge == "top":
        edge = [(x3, y3), (x2, y2), (x2, y2 + 4), (x3, y3 + 4)]
    else:  # "left"
        edge = [(x0, y0), (x0 + 4, y0), (x3 + 4, y3), (x3, y3)]
    quad(canvas_rgb, canvas_a, edge, WOOD_LIT, grain=6.0, blur=0.5)


def shade(canvas_rgb, mask: np.ndarray, factor) -> None:
    f = np.asarray(factor, np.float32)
    m = mask[..., None]
    canvas_rgb *= 1.0 - m * (1.0 - f)


def glow(canvas_rgb, mask: np.ndarray, rgb, strength: float) -> None:
    canvas_rgb += mask[..., None] * np.asarray(rgb, np.float32) * strength


# ---------------------------------------------------------------- plates


def paint_partition(shell: np.ndarray, mats: dict[str, np.ndarray]) -> Image.Image:
    rgb = np.zeros((ART_H, ART_W, 3), np.float32)
    alpha = np.zeros((ART_H, ART_W), np.float32)

    a_face = P.a_line + P.thickness_a
    face_h = rp.WALL_FACE_H
    depth = (-P.thickness_a * rp.AXIS_NW[0], -P.thickness_a * rp.AXIS_NW[1])

    solid_tex = mats["face"] * OFFICE_TINT
    glazed_tex = mats["face"] * OFFICE_TINT * 0.94

    # --- top cap (drawn first so the faces overlap its lower edge)
    for b0, b1 in ((-0.012, P.b_door0), (P.b_door1, 1.0)):
        f0, f1 = rp.plan(a_face, b0), rp.plan(a_face, b1)
        cap = [
            (f0[0], f0[1] - face_h),
            (f1[0], f1[1] - face_h),
            (f1[0] + depth[0], f1[1] + depth[1] - face_h),
            (f0[0] + depth[0], f0[1] + depth[1] - face_h),
        ]
        quad(rgb, alpha, cap, mats["cap_top"] * 1.02)

    # --- solid plaster run: north-west wall junction to the doorway
    solid_mask, solid_ground = wall_run(
        rgb, alpha, a_face, -0.012, P.b_door0, face_h, solid_tex, "ne"
    )

    # --- glazed screen: doorway to the camera-near floor edge
    glaze_mask, glaze_ground = wall_run(
        rgb, alpha, a_face, P.b_door1, 1.0, face_h, glazed_tex, "ne"
    )

    dado = P.wainscot_h
    for b0, b1 in ((P.b_door1, 1.0),):
        g0, g1 = rp.plan(a_face, b0), rp.plan(a_face, b1)
        # frosted glass sits above the timber dado, under a heavy top rail
        glass = [
            (g0[0], g0[1] - dado - 14),
            (g1[0], g1[1] - dado - 14),
            (g1[0], g1[1] - face_h + 30),
            (g0[0], g0[1] - face_h + 30),
        ]
        gm = polygon_mask(glass, 0.6)
        panes = np.zeros((ART_H, ART_W, 3), np.float32)
        panes[:] = np.asarray([104.0, 116.0, 122.0], np.float32)
        frost = (np.random.default_rng(7).random((ART_H, ART_W, 1)).astype(np.float32) - 0.5) * 13.0
        panes += frost
        composite(rgb, alpha, panes, gm * 0.82)
        alpha[gm > 0.5] = np.minimum(alpha[gm > 0.5], 0.80)

        # mullions + rails in chair-rail timber
        rail_rgb = mats["rail_rgb"]
        run = g1[0] - g0[0]
        for k in range(1, 4):
            mx = g0[0] + run * k / 4.0
            my = g0[1] + (g1[1] - g0[1]) * k / 4.0
            quad(
                rgb,
                alpha,
                [
                    (mx - 9, my - dado - 8),
                    (mx + 9, my - dado - 8),
                    (mx + 9, my - face_h + 24),
                    (mx - 9, my - face_h + 24),
                ],
                rail_rgb * 0.96,
            )
        for off, thick in ((dado + 6, 18), (face_h - 30, 22)):
            quad(
                rgb,
                alpha,
                [
                    (g0[0], g0[1] - off),
                    (g1[0], g1[1] - off),
                    (g1[0], g1[1] - off - thick),
                    (g0[0], g0[1] - off - thick),
                ],
                rail_rgb,
            )

    # --- doorway: casing, reveal, header soffit, threshold
    d0, d1 = rp.plan(a_face, P.b_door0), rp.plan(a_face, P.b_door1)
    b0_back = (d0[0] + depth[0], d0[1] + depth[1])
    b1_back = (d1[0] + depth[0], d1[1] + depth[1])
    door_h = P.door_h

    # reveal on the up-run jamb (the only reveal the camera can see)
    quad(
        rgb,
        alpha,
        [
            (d0[0], d0[1]),
            (b0_back[0], b0_back[1]),
            (b0_back[0], b0_back[1] - door_h),
            (d0[0], d0[1] - door_h),
        ],
        mats["cap_top"] * 0.62,
    )
    # header soffit across the opening
    quad(
        rgb,
        alpha,
        [
            (d0[0], d0[1] - door_h),
            (d1[0], d1[1] - door_h),
            (b1_back[0], b1_back[1] - door_h),
            (b0_back[0], b0_back[1] - door_h),
        ],
        mats["cap_top"] * 0.5,
    )
    # dark hall behind the opening
    quad(
        rgb,
        alpha,
        [
            (b0_back[0], b0_back[1]),
            (b1_back[0], b1_back[1]),
            (b1_back[0], b1_back[1] - door_h),
            (b0_back[0], b0_back[1] - door_h),
        ],
        np.asarray([15.0, 14.0, 13.0]),
    )
    # threshold board on the floor
    quad(
        rgb,
        alpha,
        [
            (d0[0], d0[1]),
            (d1[0], d1[1]),
            (b1_back[0], b1_back[1]),
            (b0_back[0], b0_back[1]),
        ],
        mats["rail_rgb"] * 0.86,
    )

    casing = mats["rail_rgb"] * 1.06
    cw = 24.0
    for pts in (
        [(d0[0] - cw, d0[1] - 4), (d0[0], d0[1] - 4), (d0[0], d0[1] - door_h - cw), (d0[0] - cw, d0[1] - door_h - cw)],
        [(d1[0], d1[1] - 4), (d1[0] + cw, d1[1] - 4), (d1[0] + cw, d1[1] - door_h - cw), (d1[0], d1[1] - door_h - cw)],
        [
            (d0[0] - cw, d0[1] - door_h),
            (d1[0] + cw, d1[1] - door_h),
            (d1[0] + cw, d1[1] - door_h - cw),
            (d0[0] - cw, d0[1] - door_h - cw),
        ],
    ):
        quad(rgb, alpha, pts, casing)

    # --- lighting: cool office side, warm spill leaking out of the waiting room
    wall_mask = np.clip(solid_mask + glaze_mask, 0, 1)
    ys, xs = np.mgrid[0:ART_H, 0:ART_W].astype(np.float32)
    base_line = (xs - rp.plan(a_face, 0.0)[0]) * (rp.AXIS_NE[1] / rp.AXIS_NE[0]) + rp.plan(a_face, 0.0)[1]
    height_above = np.clip(base_line - ys, 0, face_h)
    contact = np.clip(1.0 - height_above / 58.0, 0.0, 1.0) * wall_mask
    shade(rgb, contact, 0.52)

    door_cx, door_cy = (d0[0] + d1[0]) * 0.5, (d0[1] + d1[1]) * 0.5
    spill = np.exp(-(((xs - door_cx) / 620.0) ** 2 + ((ys - door_cy + 60) / 300.0) ** 2)) * wall_mask
    glow(rgb, spill, WAITING_TINT * 255.0, 0.16)

    # floor contact shadow along the office side of the run, plus a doorway pool
    shadow = np.zeros((ART_H, ART_W), np.float32)
    for b0, b1 in ((-0.012, P.b_door0), (P.b_door1, 1.0)):
        g0, g1 = rp.plan(a_face, b0), rp.plan(a_face, b1)
        off = (0.03 * rp.AXIS_NW[0], 0.03 * rp.AXIS_NW[1])
        shadow = np.maximum(
            shadow,
            polygon_mask(
                [
                    (g0[0], g0[1]),
                    (g1[0], g1[1]),
                    (g1[0] + off[0], g1[1] + off[1]),
                    (g0[0] + off[0], g0[1] + off[1]),
                ],
                14.0,
            ),
        )
    shadow *= 0.55
    contact_rgb = np.zeros((ART_H, ART_W, 3), np.float32)
    contact_rgb[:] = np.asarray([8.0, 8.0, 10.0], np.float32)
    composite(rgb, alpha, contact_rgb, shadow * (1.0 - np.clip(alpha, 0, 1)))

    out = np.dstack([np.clip(rgb, 0, 255), np.clip(alpha, 0, 1) * 255.0]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def paint_foreground(shell: np.ndarray, mats: dict[str, np.ndarray]) -> Image.Image:
    rgb = np.zeros((ART_H, ART_W, 3), np.float32)
    alpha = np.zeros((ART_H, ART_W), np.float32)

    face_h = F.face_h
    kerb_tex = np.concatenate(
        [
            tile_columns(mats["rail"], ART_W, offset=53),
            tile_columns(mats["wainscot"], ART_W, offset=29),
        ],
        axis=0,
    )
    kerb_tex = kerb_tex * np.array([0.86, 0.88, 0.92], np.float32)

    t_nw = F.thickness / rp.AXIS_NW_LEN
    t_ne = F.thickness / rp.AXIS_NE_LEN

    runs = (
        ("ne", 1.0 + t_nw, 0.0, 1.0, (-t_nw * rp.AXIS_NW[0], -t_nw * rp.AXIS_NW[1])),
        ("nw", 1.0 + t_ne, 0.0, 1.0, (-t_ne * rp.AXIS_NE[0], -t_ne * rp.AXIS_NE[1])),
    )
    for axis, a_face, b0, b1, depth in runs:
        if axis == "ne":
            g0, g1 = rp.plan(a_face, b0), rp.plan(a_face, b1)
        else:
            g0, g1 = rp.plan(b0, a_face), rp.plan(b1, a_face)
        cap = [
            (g0[0], g0[1] - face_h),
            (g1[0], g1[1] - face_h),
            (g1[0] + depth[0], g1[1] + depth[1] - face_h),
            (g0[0] + depth[0], g0[1] + depth[1] - face_h),
        ]
        quad(rgb, alpha, cap, mats["cap_top"] * 1.16)
        wall_run(rgb, alpha, a_face, b0, b1, face_h, kerb_tex, axis)

    # wooden top cap highlight along both runs
    for axis, a_face in (("ne", 1.0 + t_nw), ("nw", 1.0 + t_ne)):
        if axis == "ne":
            g0, g1 = rp.plan(a_face, 0.0), rp.plan(a_face, 1.0)
        else:
            g0, g1 = rp.plan(0.0, a_face), rp.plan(1.0, a_face)
        quad(
            rgb,
            alpha,
            [
                (g0[0], g0[1] - face_h),
                (g1[0], g1[1] - face_h),
                (g1[0], g1[1] - face_h + F.cap_h),
                (g0[0], g0[1] - face_h + F.cap_h),
            ],
            mats["rail_rgb"] * 1.12,
        )

    ys, xs = np.mgrid[0:ART_H, 0:ART_W].astype(np.float32)
    solid = np.clip(alpha, 0, 1)
    # room light falls off toward the plate edge; keep the kerb reading as wall
    fall = np.clip(1.0 - (ys - 900.0) / 1_500.0, 0.55, 1.0)
    rgb *= fall[..., None]

    out = np.dstack([np.clip(rgb, 0, 255), solid * 255.0]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


# ---------------------------------------------------------------- main


def main() -> None:
    shell_im = Image.open(SHELL).convert("RGBA")
    if shell_im.size != (ART_W, ART_H):
        shell_im = shell_im.resize((ART_W, ART_H), Image.Resampling.LANCZOS)
    shell = np.asarray(shell_im).astype(np.float32)

    px0, px1 = PLASTER_SAMPLE_X
    wx0, wx1 = WAINSCOT_SAMPLE_X
    plaster = rectified_strip(shell, px0, px1, rp.nw_wall_top, 6.0, rp.PLASTER_H - 14.0)
    rail = rectified_strip(shell, wx0, wx1, rp.nw_wall_top, rp.PLASTER_H - 14.0, rp.PLASTER_H + 4.0)
    wainscot = rectified_strip(shell, wx0, wx1, rp.nw_wall_top, rp.PLASTER_H + 4.0, rp.WALL_FACE_H)

    mats = {
        "plaster": plaster,
        "rail": rail,
        "wainscot": wainscot,
        "rail_rgb": rail.reshape(-1, 3).mean(axis=0) * 1.15,
        "cap_top": plaster.reshape(-1, 3).mean(axis=0) * 0.58,
        "face": build_face_texture(plaster, rail, wainscot, ART_W),
    }
    print(
        "materials: plaster",
        plaster.reshape(-1, 3).mean(axis=0).round(1),
        "rail",
        mats["rail_rgb"].round(1),
        "wainscot",
        wainscot.reshape(-1, 3).mean(axis=0).round(1),
    )

    RUNTIME.mkdir(parents=True, exist_ok=True)
    GENERATED.mkdir(parents=True, exist_ok=True)

    partition = paint_partition(shell, mats)
    foreground = paint_foreground(shell, mats)
    for image, name in ((partition, "office_partition_wall.png"), (foreground, "office_foreground_cutaway.png")):
        image.save(RUNTIME / name)
        image.save(GENERATED / name)
        a = np.asarray(image)[:, :, 3]
        print(f"wrote {name} opaque={(a > 20).sum():,}")

    # Retire the slab-era plates so nothing can load them again.
    blank = Image.new("RGBA", (ART_W, ART_H), (0, 0, 0, 0))
    for stale in ("office_suite_architecture.png", "office_suite_architecture_graybox.png", "office_foreground_wall_graybox.png"):
        blank.save(RUNTIME / stale)


if __name__ == "__main__":
    main()

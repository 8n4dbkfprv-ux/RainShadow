"""Closed-fit verification for exterior + internal door shells.

Uses the same scales/opening constants the scene loads:
  - office_door_leaf / office_door_frame display scales from Architecture helpers
  - BAKED_DOORWAY_H + EXTERIOR_DOOR_OPENING_B / partition opening JSON
  - upright lettered internal master for closed-fit (sheared leaf is open pose)
  - Per-asset rear-fixture anchors matching the projected NE-wall thresholds

Exit 0 when size ratios pass AND leaf covers frame INNER under that anchor
(uncovered inner fraction, top-band residual, gap_top / overhang_bot).

Usage:
  python3 ArtSource/Processing/verify_door_shell_fit.py
  python3 ArtSource/Processing/verify_door_shell_fit.py --out ./door_fit_out
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

import office_room_plan as rp
from office_layout_plan import (
    DEPTH_PROP_ANCHOR_Y,
    ENV,
    EXTERIOR_DOOR,
    exterior_door_threshold_authored,
    exterior_frame_anchor_x,
    exterior_frame_anchor_y,
    exterior_frame_scale,
    exterior_leaf_anchor_y,
    exterior_leaf_scale,
    internal_door_leaf_anchor,
    internal_leaf_scale,
)

ROOT = Path(__file__).resolve().parents[2]
ART_PROPS = ROOT / "RainShadow Shared/Resources/Art/Props/Office"
ART_AREA = ROOT / "RainShadow Shared/Resources/Art/Areas/DetectiveOffice"
ART_ACTORS = ROOT / "RainShadow Shared/Resources/Art/Atlases"
GEN_PROPS = ROOT / "ArtSource/Generated/Office/Props"

VOSS_IDLE = ART_ACTORS / "VossIdle.atlas/voss_standing_idle_s_00.png"
VOSS_PRESENTATION_SIZE = 232.0
VOSS_ANCHOR = (0.5, 40 / 256)
DETECTIVE_BODY_H = rp.BODY_PLATE_H * ENV
TARGET_DOOR_MULTIPLE = rp.DOOR_OPENING_TO_DETECTIVE
BAND = (1.55, 1.85)
ASPECT = (2.0, 2.3)
FIT_TOL = 0.08
FRAME_W_TOL = 0.12
REFERENCE_RATIO_TOL = 0.01
# Matches DetectiveOfficeScene.addRearFixture; frame X and both Y anchors are
# asset-specific after projection onto the sloped NE wall.
REAR_FIXTURE_ANCHOR_X = 0.5
# Registration gates (plate px / fractions under shared anchor)
MAX_GAP_TOP_PX = 8
MAX_OVERHANG_BOT_PX = 8
MAX_UNCOVERED_FRAC = 0.06
MAX_TOP10_UNCOVERED = 0.20
# Frame outer must not read as a freestanding box wider than the shell hole
MAX_FRAME_OUTER_TO_OPENING_W = 1.25
# Shipping suite must contain the same freshly generated partition that the
# standalone runtime/debug plate exposes.
MAX_SUITE_PARTITION_PATCH_MAE = 0.50
MAX_SUITE_PARTITION_BAD_FRAC = 0.01
MAX_INTERNAL_HINGE_RESIDUAL_PX = 2.0


def content_size(im: Image.Image) -> tuple[int, int]:
    a = np.asarray(im.convert("RGBA"))[:, :, 3]
    ys, xs = np.where(a > 16)
    return int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1)


def contiguous_dark_height(
    rgb: np.ndarray,
    x: int,
    base_y: int,
    threshold: float = 28.0,
) -> float:
    """Measure the dark doorway run connected to the wall threshold."""
    dark_column = rgb[:, x].mean(axis=1) < threshold
    dark_bottom = next(
        (
            y
            for y in range(
                min(base_y, len(dark_column) - 1),
                max(-1, base_y - 20),
                -1,
            )
            if dark_column[y]
        ),
        None,
    )
    if dark_bottom is None:
        return 0.0
    dark_top = dark_bottom
    while dark_top > 0 and dark_column[dark_top - 1]:
        dark_top -= 1
    return float(dark_bottom - dark_top + 1)


def transparent_run(values: np.ndarray, seed: int, threshold: int = 16) -> int:
    """Length of the transparent run containing a known aperture seed."""
    if not 0 <= seed < len(values) or values[seed] >= threshold:
        return 0
    lo = seed
    while lo > 0 and values[lo - 1] < threshold:
        lo -= 1
    hi = seed + 1
    while hi < len(values) and values[hi] < threshold:
        hi += 1
    return hi - lo


def flood_inner(alpha: np.ndarray, thr: int = 16) -> np.ndarray:
    """Flood transparent interior from texture centre (fast seed search)."""
    h, w = alpha.shape
    vis = np.zeros((h, w), dtype=bool)
    cy, cx = h // 2, w // 2
    seed: tuple[int, int] | None = None
    if alpha[cy, cx] < thr:
        seed = (cy, cx)
    else:
        for radius in range(1, min(h, w) // 3, 2):
            for dy in range(-radius, radius + 1, 2):
                for dx in (-radius, radius):
                    y, x = cy + dy, cx + dx
                    if 0 <= y < h and 0 <= x < w and alpha[y, x] < thr:
                        seed = (y, x)
                        break
                if seed:
                    break
            if seed:
                break
            for dx in range(-radius, radius + 1, 2):
                for dy in (-radius, radius):
                    y, x = cy + dy, cx + dx
                    if 0 <= y < h and 0 <= x < w and alpha[y, x] < thr:
                        seed = (y, x)
                        break
                if seed:
                    break
            if seed:
                break
    if seed is None:
        return vis
    q: deque[tuple[int, int]] = deque([seed])
    vis[seed] = True
    while q:
        y, x = q.popleft()
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= ny < h and 0 <= nx < w and not vis[ny, nx] and alpha[ny, nx] < thr:
                vis[ny, nx] = True
                q.append((ny, nx))
    return vis


def rear_fixture_paste(
    w: int,
    h: int,
    ax: float,
    ay: float,
    anchor_y: float,
    anchor_x: float = REAR_FIXTURE_ANCHOR_X,
) -> tuple[int, int]:
    """Top-left paste for a rear fixture under its SpriteKit anchor."""
    return (
        int(round(ax - anchor_x * w)),
        int(round(ay - (1.0 - anchor_y) * h)),
    )


def actor_paste(w: int, h: int, ax: float, ay: float) -> tuple[int, int]:
    """Top-left paste for Voss under his live SpriteKit anchor (image y-down)."""
    ax_f, ay_f = VOSS_ANCHOR
    return int(round(ax - ax_f * w)), int(round(ay - (1.0 - ay_f) * h))


def qa_font(size: int = 18) -> ImageFont.ImageFont:
    """Readable project QA labels, with a Pillow-default fallback."""
    for path in (
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def label(
    draw: ImageDraw.ImageDraw,
    xy: tuple[int, int],
    text: str,
    font: ImageFont.ImageFont,
    fill: tuple[int, int, int, int],
) -> None:
    """Draw a compact high-contrast QA label."""
    box = draw.textbbox(xy, text, font=font)
    draw.rectangle((box[0] - 4, box[1] - 3, box[2] + 4, box[3] + 3), fill=(8, 8, 8, 218))
    draw.text(xy, text, font=font, fill=fill)


def frame_leaf_registration(
    frame: Image.Image,
    leaf: Image.Image,
    frame_scale: float,
    leaf_scale: float,
    frame_anchor_x: float,
    frame_anchor_y: float,
    leaf_anchor_y: float,
) -> dict[str, float]:
    """Coverage of frame INNER by leaf under their projected-wall anchors."""
    leaf_ps = leaf_scale / ENV
    frame_ps = frame_scale / ENV
    lw = max(1, int(round(leaf.size[0] * leaf_ps)))
    lh = max(1, int(round(leaf.size[1] * leaf_ps)))
    fw = max(1, int(round(frame.size[0] * frame_ps)))
    fh = max(1, int(round(frame.size[1] * frame_ps)))
    leaf_r = np.asarray(leaf.resize((lw, lh), Image.Resampling.LANCZOS))[:, :, 3] > 16
    frame_r = frame.resize((fw, fh), Image.Resampling.LANCZOS)
    fa = np.asarray(frame_r)[:, :, 3]
    inner = flood_inner(fa)
    iys, ixs = np.where(inner)
    if len(iys) == 0:
        return {
            "gap_top": 999.0,
            "overhang_bot": 999.0,
            "uncovered_frac": 1.0,
            "top10_unc_frac": 1.0,
            "fw": float(fw),
            "fh": float(fh),
            "lw": float(lw),
            "lh": float(lh),
        }
    iy0, iy1 = int(iys.min()), int(iys.max())
    # Relative origins under shared anchor (anchor at origin for relative math)
    lox = int(round(frame_anchor_x * fw - REAR_FIXTURE_ANCHOR_X * lw))
    loy = int(
        round(
            (1.0 - frame_anchor_y) * fh
            - (1.0 - leaf_anchor_y) * lh
        )
    )
    cover = np.zeros((fh, fw), dtype=bool)
    y0, y1 = max(0, loy), min(fh, loy + lh)
    x0, x1 = max(0, lox), min(fw, lox + lw)
    if y1 > y0 and x1 > x0:
        cover[y0:y1, x0:x1] = leaf_r[y0 - loy : y1 - loy, x0 - lox : x1 - lox]
    unc = int((inner & ~cover).sum())
    inn = max(1, int(inner.sum()))
    top_cut = iy0 + max(1, int(0.10 * (iy1 - iy0 + 1)))
    top = inner.copy()
    top[top_cut:, :] = False
    top_unc = int((top & ~cover).sum()) / max(1, int(top.sum()))
    return {
        "gap_top": float(loy - iy0),
        "overhang_bot": float((loy + lh - 1) - iy1),
        "uncovered_frac": unc / inn,
        "top10_unc_frac": float(top_unc),
        "fw": float(fw),
        "fh": float(fh),
        "lw": float(lw),
        "lh": float(lh),
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=Path, default=None, help="Directory for composites + metrics")
    args = ap.parse_args()
    out = args.out
    if out is not None:
        out.mkdir(parents=True, exist_ok=True)

    leaf = Image.open(ART_PROPS / "office_door_leaf.png").convert("RGBA")
    frame = Image.open(ART_PROPS / "office_door_frame.png").convert("RGBA")
    internal_leaf = Image.open(ART_PROPS / "office_internal_door_leaf.png").convert("RGBA")
    partition = Image.open(ART_PROPS / "office_partition_wall.png").convert("RGBA")
    shell = Image.open(ART_AREA / "office_shell_base.png").convert("RGB")
    suite = Image.open(ART_AREA / "office_suite_plate.png").convert("RGBA")
    voss = Image.open(VOSS_IDLE).convert("RGBA")
    opening = json.loads((ART_PROPS / "office_partition_opening.json").read_text(encoding="utf-8"))
    master_path = GEN_PROPS / "office_internal_door_leaf_lettered_master.png"
    imaster = Image.open(
        master_path if master_path.exists() else ART_PROPS / "office_internal_door_leaf.png"
    ).convert("RGBA")

    leaf_scale = exterior_leaf_scale()
    frame_scale = exterior_frame_scale()
    leaf_anchor_y = exterior_leaf_anchor_y()
    frame_anchor_x = exterior_frame_anchor_x()
    frame_anchor_y = exterior_frame_anchor_y()
    internal_scale = internal_leaf_scale()

    leaf_cw, _ = content_size(leaf)
    leaf_alpha = np.asarray(leaf)[:, :, 3]
    leaf_center_ys = np.where(leaf_alpha[:, leaf.width // 2] > 16)[0]
    leaf_ch = int(leaf_center_ys.max() - leaf_center_ys.min() + 1)
    leaf_disp_w, leaf_disp_h = leaf_cw * leaf_scale, leaf_ch * leaf_scale
    body_mult = leaf_disp_h / DETECTIVE_BODY_H
    voss_cw, voss_ch = content_size(voss)
    voss_plate_canvas = VOSS_PRESENTATION_SIZE / ENV
    voss_measured_plate_h = voss_ch / voss.height * voss_plate_canvas
    voss_measured_world_h = voss_measured_plate_h * ENV

    fa = np.asarray(frame)[:, :, 3]
    inner = flood_inner(fa)
    iys, ixs = np.where(inner)
    if len(iys) == 0:
        print("FAIL: frame has no inner aperture")
        return 1
    frame_iw = int(ixs.max() - ixs.min() + 1)
    frame_inner_cx = int(round((ixs.min() + ixs.max()) * 0.5))
    frame_center_ys = np.where(inner[:, frame_inner_cx])[0]
    frame_ih = int(frame_center_ys.max() - frame_center_ys.min() + 1)
    fi_w, fi_h = frame_iw * frame_scale, frame_ih * frame_scale

    open_w = rp.EXTERIOR_DOOR_OPENING_B * abs(rp.AXIS_NE[0])
    open_h = rp.BAKED_DOORWAY_H
    open_disp_w, open_disp_h = open_w * ENV, open_h * ENV
    opening_body_mult = open_disp_h / DETECTIVE_BODY_H

    oh = float(opening["opening_h_px"])
    ow = float(opening["opening_w_px"])
    iopen_disp_w, iopen_disp_h = ow * ENV, oh * ENV
    mw, mh = imaster.size
    master_disp_w, master_disp_h = mw * ENV, mh * ENV

    reg = frame_leaf_registration(
        frame,
        leaf,
        frame_scale,
        leaf_scale,
        frame_anchor_x,
        frame_anchor_y,
        leaf_anchor_y,
    )
    frame_outer_disp_w = float(frame.size[0]) * frame_scale
    frame_outer_disp_h = float(frame.size[1]) * frame_scale
    outer_to_open_w = frame_outer_disp_w / max(open_disp_w, 1e-6)

    # Shell dark aperture size near entrance (must match plan, not an oversized void)
    shell_rgb = np.asarray(shell.convert("RGB"))
    suite_rgb = np.asarray(suite.convert("RGB"))
    plan_g0 = rp.plan(0.0, EXTERIOR_DOOR[1] - rp.EXTERIOR_DOOR_OPENING_B * 0.5)
    plan_g1 = rp.plan(0.0, EXTERIOR_DOOR[1] + rp.EXTERIOR_DOOR_OPENING_B * 0.5)
    # The shipping shell cutter keeps the V6 floor threshold rather than the
    # approximate plan-basis Y. These are the actual painted aperture corners.
    g0 = (plan_g0[0], rp.ne_wall_base(plan_g0[0]))
    g1 = (plan_g1[0], rp.ne_wall_base(plan_g1[0]))
    mid_x = int(round((g0[0] + g1[0]) * 0.5))
    base_y = int(round((g0[1] + g1[1]) * 0.5))
    # Measure only the contiguous dark aperture that terminates at the wall
    # base. Check both the shell source and the shipping suite the game loads.
    shell_dark_h = contiguous_dark_height(shell_rgb, mid_x, base_y)
    suite_dark_h = contiguous_dark_height(suite_rgb, mid_x, base_y)
    shell_h_err = abs(shell_dark_h - open_h) / open_h if open_h else 1.0
    suite_h_err = abs(suite_dark_h - open_h) / open_h if open_h else 1.0

    # Verify the actual painted partition aperture, then prove that this exact
    # generated partition is the one composited into the shipping suite.
    hx, hy = opening["hinge_plate_xy"]
    lx, ly = opening["latch_plate_xy"]
    internal_cx = int(round((hx + lx) * 0.5))
    internal_base_y = int(round((hy + ly) * 0.5))
    internal_top_y = int(round(internal_base_y - oh))
    partition_alpha = np.asarray(partition)[:, :, 3]
    internal_mid_y = int(round((internal_top_y + internal_base_y) * 0.5))
    partition_clear_h = transparent_run(
        partition_alpha[:, internal_cx],
        internal_mid_y,
    )
    partition_clear_w = transparent_run(
        partition_alpha[internal_mid_y],
        internal_cx,
    )
    partition_clear_h_err = abs(partition_clear_h - oh) / max(oh, 1.0)
    partition_clear_w_err = abs(partition_clear_w - ow) / max(ow, 1.0)

    patch_x0 = max(0, int(round(min(hx, lx) - 70)))
    patch_x1 = min(shell.width, int(round(max(hx, lx) + 70)))
    patch_y0 = max(0, internal_top_y - 70)
    patch_y1 = min(shell.height, internal_base_y + 35)
    partition_patch = np.asarray(partition, np.float32)[
        patch_y0:patch_y1,
        patch_x0:patch_x1,
    ]
    shell_patch = np.asarray(shell.convert("RGBA"), np.float32)[
        patch_y0:patch_y1,
        patch_x0:patch_x1,
    ]
    suite_patch = np.asarray(suite, np.float32)[
        patch_y0:patch_y1,
        patch_x0:patch_x1,
    ]
    partition_a = partition_patch[:, :, 3:4] / 255.0
    expected_suite_rgb = (
        shell_patch[:, :, :3] * (1.0 - partition_a)
        + partition_patch[:, :, :3] * partition_a
    )
    suite_partition_delta = np.abs(
        expected_suite_rgb - suite_patch[:, :, :3]
    )
    suite_partition_patch_mae = float(suite_partition_delta.mean())
    suite_partition_bad_frac = float(
        (suite_partition_delta.max(axis=2) > 2.0).mean()
    )
    expected_leaf_scale = open_disp_h / max(leaf_ch, 1)
    expected_frame_scale = open_disp_h / max(frame_ih, 1)

    # Exercise the *shipping open internal leaf*, not only its upright master.
    # Its right texture edge is the hinge. At plate scale the visible hinge
    # silhouette must span the partition jamb from threshold to lintel.
    internal_plate_scale = internal_scale / ENV
    internal_w, internal_h = internal_leaf.size
    internal_alpha = np.asarray(internal_leaf)[:, :, 3]
    hinge_ys = np.where(internal_alpha[:, internal_w - 1] > 16)[0]
    internal_anchor_x, internal_anchor_authored_y = internal_door_leaf_anchor()
    internal_anchor_y = rp.ART_H - internal_anchor_authored_y
    internal_left = (
        internal_anchor_x
        - REAR_FIXTURE_ANCHOR_X * internal_w * internal_plate_scale
    )
    internal_top = (
        internal_anchor_y
        - (1.0 - DEPTH_PROP_ANCHOR_Y) * internal_h * internal_plate_scale
    )
    expected_hinge_top = hy - oh
    expected_hinge_bottom = hy
    transformed_hinge_x = internal_left + internal_w * internal_plate_scale
    if len(hinge_ys):
        transformed_hinge_top = internal_top + float(hinge_ys.min()) * internal_plate_scale
        transformed_hinge_bottom = (
            internal_top + float(hinge_ys.max() + 1) * internal_plate_scale
        )
        internal_visible_hinge_h = float(
            (hinge_ys.max() - hinge_ys.min() + 1) * internal_plate_scale
        )
    else:
        transformed_hinge_top = float("inf")
        transformed_hinge_bottom = float("-inf")
        internal_visible_hinge_h = 0.0
    internal_hinge_x_residual = abs(transformed_hinge_x - hx)
    internal_hinge_top_residual = abs(transformed_hinge_top - expected_hinge_top)
    internal_hinge_bottom_residual = abs(
        transformed_hinge_bottom - expected_hinge_bottom
    )

    # Full silhouette registration: the exterior frame's projected inner
    # aperture must coincide with the sloped shell parallelogram, not merely
    # match its midpoint height.
    entrance_ax, entrance_authored_y = exterior_door_threshold_authored()
    entrance_ay = rp.ART_H - entrance_authored_y
    fit_fw, fit_fh = int(reg["fw"]), int(reg["fh"])
    frame_fit = frame.resize((fit_fw, fit_fh), Image.Resampling.LANCZOS)
    frame_fit_inner = flood_inner(np.asarray(frame_fit)[:, :, 3])
    frame_fit_xy = rear_fixture_paste(
        fit_fw,
        fit_fh,
        entrance_ax,
        entrance_ay,
        frame_anchor_y,
        frame_anchor_x,
    )
    placed_inner = np.zeros((shell.height, shell.width), dtype=bool)
    fx0, fy0 = frame_fit_xy
    dx0, dy0 = max(0, fx0), max(0, fy0)
    dx1 = min(shell.width, fx0 + fit_fw)
    dy1 = min(shell.height, fy0 + fit_fh)
    if dx1 > dx0 and dy1 > dy0:
        placed_inner[dy0:dy1, dx0:dx1] = frame_fit_inner[
            dy0 - fy0 : dy1 - fy0,
            dx0 - fx0 : dx1 - fx0,
        ]
    expected_opening_image = Image.new("L", shell.size, 0)
    ImageDraw.Draw(expected_opening_image).polygon(
        [
            (g0[0], g0[1]),
            (g1[0], g1[1]),
            (g1[0], g1[1] - open_h),
            (g0[0], g0[1] - open_h),
        ],
        fill=255,
    )
    expected_opening = np.asarray(expected_opening_image) > 0
    opening_intersection = int((placed_inner & expected_opening).sum())
    opening_union = max(1, int((placed_inner | expected_opening).sum()))
    expected_opening_area = max(1, int(expected_opening.sum()))
    placed_inner_area = max(1, int(placed_inner.sum()))
    shell_frame_iou = opening_intersection / opening_union
    shell_frame_uncovered = (
        int((expected_opening & ~placed_inner).sum()) / expected_opening_area
    )
    shell_frame_overhang = (
        int((placed_inner & ~expected_opening).sum()) / placed_inner_area
    )

    checks = {
        "exterior_height": abs(leaf_disp_h - open_disp_h) / open_disp_h <= FIT_TOL,
        "exterior_width": abs(leaf_disp_w - open_disp_w) / open_disp_w <= FIT_TOL,
        "frame_inner_height": abs(fi_h - leaf_disp_h) / leaf_disp_h <= FIT_TOL,
        "frame_inner_width": abs(fi_w - leaf_disp_w) / leaf_disp_w <= FRAME_W_TOL,
        "door_band": BAND[0] <= body_mult <= BAND[1],
        "door_detective_reference": (
            abs(opening_body_mult - TARGET_DOOR_MULTIPLE) / TARGET_DOOR_MULTIPLE
            <= REFERENCE_RATIO_TOL
        ),
        "detective_sprite_matches_reference": (
            abs(voss_measured_plate_h - rp.BODY_PLATE_H) / rp.BODY_PLATE_H
            <= REFERENCE_RATIO_TOL
        ),
        "exterior_aspect": ASPECT[0] <= open_h / open_w <= ASPECT[1],
        "internal_height": abs(master_disp_h - iopen_disp_h) / iopen_disp_h <= FIT_TOL,
        "internal_width": abs(master_disp_w - iopen_disp_w) / iopen_disp_w <= FIT_TOL,
        "internal_aspect": ASPECT[0] <= oh / ow <= ASPECT[1],
        "internal_detective_reference": (
            abs(oh / rp.BODY_PLATE_H - TARGET_DOOR_MULTIPLE) / TARGET_DOOR_MULTIPLE
            <= REFERENCE_RATIO_TOL
        ),
        "internal_live_plate_scale": abs(internal_scale - ENV) < 1e-6,
        "internal_live_hinge_x": (
            internal_hinge_x_residual <= MAX_INTERNAL_HINGE_RESIDUAL_PX
        ),
        "internal_live_hinge_top": (
            internal_hinge_top_residual <= MAX_INTERNAL_HINGE_RESIDUAL_PX
        ),
        "internal_live_hinge_bottom": (
            internal_hinge_bottom_residual <= MAX_INTERNAL_HINGE_RESIDUAL_PX
        ),
        "scales_from_helpers": abs(leaf_scale - expected_leaf_scale) < 0.002
        and abs(frame_scale - expected_frame_scale) < 0.002
        and abs(frame_scale - leaf_scale) / max(leaf_scale, 1e-6) <= 0.08,
        # Registration under addRearFixture anchor (0.5, 0.04)
        "frame_leaf_gap_top": abs(reg["gap_top"]) <= MAX_GAP_TOP_PX,
        "frame_leaf_overhang_bot": abs(reg["overhang_bot"]) <= MAX_OVERHANG_BOT_PX,
        "frame_inner_coverage": reg["uncovered_frac"] <= MAX_UNCOVERED_FRAC,
        "frame_top_band_coverage": reg["top10_unc_frac"] <= MAX_TOP10_UNCOVERED,
        "frame_outer_not_freestanding": outer_to_open_w <= MAX_FRAME_OUTER_TO_OPENING_W,
        "frame_silhouette_matches_shell": (
            shell_frame_iou >= 0.90
            and shell_frame_uncovered <= 0.06
            and shell_frame_overhang <= 0.06
        ),
        "shell_opening_height": shell_h_err <= 0.12,
        "suite_opening_height": suite_h_err <= 0.12,
        "shell_detective_reference": (
            abs(shell_dark_h / rp.BODY_PLATE_H - TARGET_DOOR_MULTIPLE)
            / TARGET_DOOR_MULTIPLE
            <= REFERENCE_RATIO_TOL
        ),
        "suite_detective_reference": (
            abs(suite_dark_h / rp.BODY_PLATE_H - TARGET_DOOR_MULTIPLE)
            / TARGET_DOOR_MULTIPLE
            <= REFERENCE_RATIO_TOL
        ),
        "partition_pixels_fit_opening": (
            partition_clear_h_err <= 0.10
            and partition_clear_w_err <= 0.10
        ),
        "suite_contains_current_partition": (
            suite_partition_patch_mae <= MAX_SUITE_PARTITION_PATCH_MAE
            and suite_partition_bad_frac <= MAX_SUITE_PARTITION_BAD_FRAC
        ),
    }

    lines = [
        "=== Door shell fit metrics ===",
        f"ENV={ENV} detectiveBodyH={DETECTIVE_BODY_H:.3f} "
        f"detectivePlateH={rp.BODY_PLATE_H:.3f} "
        f"doorTarget={TARGET_DOOR_MULTIPLE:.3f}x "
        f"BAKED_DOORWAY_H={rp.BAKED_DOORWAY_H}",
        f"shipped Voss content={voss_cw}x{voss_ch} on {voss.width}x{voss.height}; "
        f"232-point presentation={voss_measured_world_h:.3f} world / "
        f"{voss_measured_plate_h:.3f} plate px",
        f"rear_fixture_anchor_x leaf={REAR_FIXTURE_ANCHOR_X:.5f} "
        f"frame={frame_anchor_x:.5f} "
        f"leaf_y={leaf_anchor_y:.5f} frame_y={frame_anchor_y:.5f}",
        "",
        "-- Exterior --",
        f"leaf content {leaf_cw}x{leaf_ch} scale={leaf_scale:.4f} display={leaf_disp_w:.2f}x{leaf_disp_h:.2f}",
        f"leaf body multiple={body_mult:.3f} (band {BAND[0]}-{BAND[1]})",
        f"opening body multiple={opening_body_mult:.3f} "
        f"(detective-reference target {TARGET_DOOR_MULTIPLE:.3f})",
        f"frame inner {frame_iw}x{frame_ih} display={fi_w:.2f}x{fi_h:.2f} scale={frame_scale:.4f}",
        f"frame outer display={frame_outer_disp_w:.2f}x{frame_outer_disp_h:.2f} outer/open_w={outer_to_open_w:.3f} (max {MAX_FRAME_OUTER_TO_OPENING_W})",
        f"opening plate {open_w:.1f}x{open_h:.1f} display={open_disp_w:.2f}x{open_disp_h:.2f} H/W={open_h/open_w:.2f}",
        f"shell dark H≈{shell_dark_h:.1f} vs plan {open_h:.1f} err={shell_h_err*100:.1f}%",
        f"suite dark H≈{suite_dark_h:.1f} vs plan {open_h:.1f} err={suite_h_err*100:.1f}%",
        f"|leaf-open|/open H={abs(leaf_disp_h-open_disp_h)/open_disp_h*100:.2f}% W={abs(leaf_disp_w-open_disp_w)/open_disp_w*100:.2f}%",
        f"|frame_inner-leaf|/leaf H={abs(fi_h-leaf_disp_h)/leaf_disp_h*100:.2f}% W={abs(fi_w-leaf_disp_w)/leaf_disp_w*100:.2f}%",
        f"frame/shell silhouette IoU={shell_frame_iou:.4f} "
        f"uncovered={shell_frame_uncovered:.4f} overhang={shell_frame_overhang:.4f}",
        f"shell threshold centre=({entrance_ax:.3f},{entrance_ay:.3f}) plate y-down",
        "",
        "-- Exterior projected-wall registration --",
        f"gap_top_px={reg['gap_top']:.1f} (max {MAX_GAP_TOP_PX})",
        f"overhang_bot_px={reg['overhang_bot']:.1f} (max {MAX_OVERHANG_BOT_PX})",
        f"uncovered_inner_frac={reg['uncovered_frac']:.4f} (max {MAX_UNCOVERED_FRAC})",
        f"top10_uncovered_frac={reg['top10_unc_frac']:.4f} (max {MAX_TOP10_UNCOVERED})",
        "",
        "-- Internal --",
        f"opening plate {ow:.1f}x{oh:.1f} display={iopen_disp_w:.2f}x{iopen_disp_h:.2f} H/W={oh/ow:.2f}",
        f"upright master {mw}x{mh} display={master_disp_w:.2f}x{master_disp_h:.2f}",
        f"|master-open|/open H={abs(master_disp_h-iopen_disp_h)/iopen_disp_h*100:.2f}% W={abs(master_disp_w-iopen_disp_w)/iopen_disp_w*100:.2f}%",
        f"live leaf {internal_w}x{internal_h} scale={internal_scale:.4f} "
        f"visible hinge={internal_visible_hinge_h:.1f}px",
        f"live hinge residual x={internal_hinge_x_residual:.2f}px "
        f"top={internal_hinge_top_residual:.2f}px "
        f"bottom={internal_hinge_bottom_residual:.2f}px "
        f"(max {MAX_INTERNAL_HINGE_RESIDUAL_PX:.1f}px)",
        f"painted clear run {partition_clear_w}x{partition_clear_h} "
        f"(casing-inclusive err W={partition_clear_w_err*100:.1f}% H={partition_clear_h_err*100:.1f}%)",
        f"suite/current-partition patch MAE={suite_partition_patch_mae:.4f} "
        f"bad>2={suite_partition_bad_frac:.4f}",
        "",
    ]
    for name, ok in checks.items():
        lines.append(f"PASS_{name}={ok}")
    all_pass = all(checks.values())
    lines.append(f"ALL_PASS={all_pass}")
    report = "\n".join(lines) + "\n"
    print(report, end="")

    if out is not None:
        (out / "door_shell_fit_metrics.txt").write_text(report, encoding="utf-8")
        # Exterior closed-fit composite using the same projected-wall anchors as the scene.
        lw, lh = int(reg["lw"]), int(reg["lh"])
        fw, fh = int(reg["fw"]), int(reg["fh"])
        leaf_r = leaf.resize((lw, lh), Image.Resampling.LANCZOS)
        frame_r = frame.resize((fw, fh), Image.Resampling.LANCZOS)
        ax, ay = entrance_ax, entrance_ay
        fxy = rear_fixture_paste(
            fw,
            fh,
            ax,
            ay,
            frame_anchor_y,
            frame_anchor_x,
        )
        lxy = rear_fixture_paste(lw, lh, ax, ay, leaf_anchor_y)
        comp = shell.copy()
        # shell is RGB; composite via RGBA temp
        layer = Image.new("RGBA", shell.size, (0, 0, 0, 0))
        layer.alpha_composite(frame_r, fxy)
        layer.alpha_composite(leaf_r, lxy)
        base = shell.convert("RGBA")
        base.alpha_composite(layer)
        base.convert("RGB").crop((2980, 60, 3350, 620)).save(out / "door_shell_fit_exterior.png")
        frame_only = shell.convert("RGBA")
        frame_layer = Image.new("RGBA", shell.size, (0, 0, 0, 0))
        frame_layer.alpha_composite(frame_r, fxy)
        frame_only.alpha_composite(frame_layer)
        frame_only.convert("RGB").crop((2980, 60, 3350, 620)).save(
            out / "door_shell_fit_exterior_open.png"
        )

        # Project-bound scale proof: actual shipped Voss at the live 232-point
        # presentation beside the exterior threshold, over the shipping shell.
        voss_canvas = max(1, int(round(VOSS_PRESENTATION_SIZE / ENV)))
        voss_r = voss.resize((voss_canvas, voss_canvas), Image.Resampling.NEAREST)
        actor_x = fxy[0] - 75
        actor_xy = actor_paste(voss_canvas, voss_canvas, actor_x, ay)
        reference = base.copy()
        reference.alpha_composite(voss_r, actor_xy)
        draw = ImageDraw.Draw(reference, "RGBA")
        font = qa_font()
        body_top = int(round(ay - rp.BODY_PLATE_H))
        door_top = int(round(ay - rp.BODY_PLATE_H * TARGET_DOOR_MULTIPLE))
        frame_right = fxy[0] + fw
        body_bracket_x = int(round(actor_x - 72))
        door_bracket_x = int(round(frame_right + 42))

        # Shared threshold and horizontal 1.0x / doorway-height guides.
        guide_left = body_bracket_x - 12
        guide_right = door_bracket_x + 12
        draw.line((guide_left, ay, guide_right, ay), fill=(245, 245, 245, 210), width=2)
        draw.line((body_bracket_x, body_top, frame_right, body_top), fill=(90, 220, 255, 180), width=2)
        draw.line((fxy[0], door_top, door_bracket_x, door_top), fill=(255, 190, 70, 200), width=2)

        # 1.0x Voss bracket.
        draw.line((body_bracket_x, body_top, body_bracket_x, ay), fill=(90, 220, 255, 255), width=3)
        draw.line((body_bracket_x - 7, body_top, body_bracket_x + 7, body_top), fill=(90, 220, 255, 255), width=3)
        draw.line((body_bracket_x - 7, ay, body_bracket_x + 7, ay), fill=(90, 220, 255, 255), width=3)
        label(
            draw,
            (body_bracket_x + 10, body_top + 8),
            f"1.0x Voss = {rp.BODY_PLATE_H:.0f}px",
            font,
            (110, 225, 255, 255),
        )

        # Doorway-to-detective target bracket.
        draw.line((door_bracket_x, door_top, door_bracket_x, ay), fill=(255, 190, 70, 255), width=3)
        draw.line((door_bracket_x - 7, door_top, door_bracket_x + 7, door_top), fill=(255, 190, 70, 255), width=3)
        draw.line((door_bracket_x - 7, ay, door_bracket_x + 7, ay), fill=(255, 190, 70, 255), width=3)
        label(
            draw,
            (fxy[0] + 8, door_top + 8),
            f"door = {TARGET_DOOR_MULTIPLE:.2f}x / {open_h:.0f}px",
            font,
            (255, 202, 95, 255),
        )

        crop = (
            max(0, body_bracket_x - 38),
            max(0, door_top - 54),
            min(reference.width, door_bracket_x + 185),
            min(reference.height, ay + 62),
        )
        reference.convert("RGB").crop(crop).save(out / "door_shell_fit_detective_reference.png")

        # Internal closed-fit (upright master). The processor pre-mirrors this
        # master before shearing so the open runtime leaf reads correctly; undo
        # that preparation in the flat QA proof so the office-side lettering is
        # shown in its final readable orientation.
        hx, hy = opening["hinge_plate_xy"]
        lx, ly = opening["latch_plate_xy"]
        cx, cy = (hx + lx) / 2, (hy + ly) / 2
        comp2 = suite.convert("RGB")
        qa_master = imaster.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        comp2.paste(
            qa_master,
            (int(round(cx - mw / 2)), int(round(cy - mh))),
            qa_master,
        )
        comp2.crop((1700, 200, 2100, 750)).save(out / "door_shell_fit_internal.png")

        # Internal open-fit composite from the exact runtime sheared leaf.
        live_w = max(1, int(round(internal_w * internal_plate_scale)))
        live_h = max(1, int(round(internal_h * internal_plate_scale)))
        live_leaf = internal_leaf.resize(
            (live_w, live_h),
            Image.Resampling.LANCZOS,
        )
        live_xy = (
            int(round(internal_left)),
            int(round(internal_top)),
        )
        live_comp = suite.convert("RGBA")
        live_layer = Image.new("RGBA", suite.size, (0, 0, 0, 0))
        live_layer.alpha_composite(live_leaf, live_xy)
        live_comp.alpha_composite(live_layer)
        live_comp.convert("RGB").crop((1600, 80, 2140, 780)).save(
            out / "door_shell_fit_internal_open.png"
        )

    return 0 if all_pass else 1


if __name__ == "__main__":
    sys.exit(main())

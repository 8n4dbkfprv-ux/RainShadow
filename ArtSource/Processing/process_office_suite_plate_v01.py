"""Stage 1 suite plate — one registered background for all fixed architecture.

Default bake (reliable registration):
  office_shell_base + continuous full-height partition (shell materials)
  composited into office_suite_plate.png at 4096×2304.

The partition continues PAST the doorway to enclose the waiting room; only the
extreme camera-near tip is cut away. This fixes the prior mask that dropped
the wall immediately after the latch jamb (b_return1 ≈ door + 0.034).

Optional IG master (not the default — recent gens dropped outer/partition walls):
  ArtSource/Generated/Office/suite_plate_v01/office_suite_plate_v01_gen.png
  Use --ig to ship a resized IG plate instead of the registered bake.

Usage:
    python3 ArtSource/Processing/process_office_suite_plate_v01.py
    python3 ArtSource/Processing/process_office_suite_plate_v01.py --ig
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

import office_room_plan as rp
import process_office_partition_plate_v01 as part

ROOT = Path(__file__).resolve().parents[2]
GEN_DIR = ROOT / "ArtSource/Generated/Office/suite_plate_v01"
GENERATED_COPY = ROOT / "ArtSource/Generated/Office/office_suite_plate.png"
RUNTIME = (
    ROOT
    / "RainShadow Shared"
    / "Resources"
    / "Art"
    / "Areas"
    / "DetectiveOffice"
    / "office_suite_plate.png"
)
SHELL = ROOT / "RainShadow Shared/Resources/Art/Areas/DetectiveOffice/office_shell_base.png"
CURSOR_ASSETS = (
    Path.home()
    / ".cursor/projects/Users-laurensvanoorschot-Desktop-RainShadow/assets"
)

ART_W, ART_H = 4096, 2304
MASTER_W, MASTER_H = 3840, 2160

# Full-height partition runs to the design near edge (past doorway ~0.17).
# Prior mask cliff at b_return1≈0.205 made the waiting room look unwalled.
SUITE_FULL_B = rp.B_ROOM
SUITE_LIP_H = 0.0


def find_ig_master() -> Path | None:
    for path in (
        GEN_DIR / "office_suite_plate_v01_gen.png",
        CURSOR_ASSETS / "office_suite_plate_v01_gen.png",
    ):
        if path.exists():
            return path
    return None


def suite_cutaway_mask() -> np.ndarray:
    """Keep partition solid through mid-room; only tip past SUITE_FULL_B is lip."""
    mask = np.zeros((ART_H, ART_W), np.float32)
    a_face = rp.PARTITION.a_line + rp.PARTITION.thickness_a
    face_h = rp.PARTITION.face_h

    g0, g1 = rp.plan(a_face, -rp.PARTITION.overrun_b), rp.plan(a_face, SUITE_FULL_B)
    full = part.polygon_mask(
        [
            (g0[0] - 10, g0[1] + 24),
            (g1[0] + 10, g1[1] + 24),
            (g1[0] + 10, g1[1] - face_h - 24),
            (g0[0] - 10, g0[1] - face_h - 24),
        ],
        blur=1.0,
    )
    mask = np.maximum(mask, full)

    # No mid-room lip cutaway — void past B_ROOM is painted into the plate.
    return mask


# Short L-returns that frame the waiting-room mouth without closing it.
# Keep well under half the mouth width so the centre stays an obvious cutaway.
CUTAWAY_RETURN_LEN = 0.055
# Overpaint tip bases into the floor so ends never float / no pale floor-edge sliver.
TIP_BASE_OVERPAINT_PX = 28.0


def paint_cutaway_readability(
    rgb: np.ndarray,
    alpha: np.ndarray,
    mats: dict[str, np.ndarray],
    source_rgba: np.ndarray | None = None,
) -> np.ndarray:
    """Make the waiting-room cutaway read as designed for non-CRPG players.

    1. End tips use WALL face texture (plaster/wainscot) — never floor swirl
    2. Short L-returns grown from those tips
    3. Floor threshold in the open mouth + strong contact AO under tip feet
    Mouth centre stays open — no wall bridging the gap.

    When source_rgba is provided (shell+partition composite), L-returns clone
    lit columns from the parent wall so wallpaper meets at the corner.
    """
    P = rp.PARTITION
    a_face = P.a_line + P.thickness_a
    a_back = P.a_line
    face_h = P.face_h
    wainscot = mats["wainscot"].reshape(-1, 3).mean(0)
    protect = np.zeros((ART_H, ART_W), np.float32)
    face_tex = mats["face"] * part.OFFICE_TINT
    shoe = TIP_BASE_OVERPAINT_PX
    src_rgb = source_rgba[:, :, :3] if source_rgba is not None else None

    def contact_shadow(a0: float, a1: float, b0: float, b1: float, strength: float = 0.55) -> None:
        """Soft AO on the floor under a tip / return — plants the wall."""
        shadow = part.polygon_mask(
            [
                rp.plan(a0, b0),
                rp.plan(a1, b0),
                rp.plan(a1, b1),
                rp.plan(a0, b1),
            ],
            blur=4.0,
        )
        dark = np.zeros((ART_H, ART_W, 3), np.float32)
        dark[:] = (3.0, 4.0, 6.0)
        part.over(rgb, alpha, dark, shadow * strength)

    th_tex, tw_tex = face_tex.shape[0], face_tex.shape[1]
    _p0, _p1 = rp.plan(a_face, -P.overrun_b), rp.plan(a_face, rp.B_ROOM)
    partition_x0 = int(np.ceil(min(_p0[0], _p1[0])))

    def u_partition_at_x(x: float) -> int:
        return int(round(x) - partition_x0) % tw_tex

    def u_at_partition_corner() -> int:
        cx, _ = rp.plan(a_face, rp.B_ROOM)
        return u_partition_at_x(cx)

    def paint_face_column(x: float, y_ground: float, u: int, darken: float = 1.0) -> None:
        """Fallback column from face_tex when no source composite is available."""
        xi = int(round(x))
        if not 0 <= xi < ART_W:
            return
        h = max(1, int(round(face_h)))
        rows = np.linspace(0, th_tex - 1, h).astype(int)
        col = face_tex[rows, u % tw_tex] * darken
        y_top = y_ground - h
        y0 = max(0, int(np.floor(y_top)))
        y1 = min(ART_H - 1, int(np.ceil(y_ground)))
        for y in range(y0, y1 + 1):
            t = (y - y_top) / max(h, 1)
            if t < -0.02 or t > 1.02:
                continue
            src = int(np.clip(round(t * (h - 1)), 0, h - 1))
            rgb[y, xi] = col[src]
            alpha[y, xi] = 1.0
        # Dark flush shoe — never sample a light texture row (reads as yellow geo).
        shoe_rgb = np.clip(wainscot * 0.55 * darken, 0, 255)
        for y in range(y1 + 1, min(ART_H, y1 + int(shoe) + 1)):
            rgb[y, xi] = shoe_rgb
            alpha[y, xi] = 1.0

    def clone_column(
        src_pt: tuple[float, float],
        dst_pt: tuple[float, float],
        darken: float = 1.0,
    ) -> None:
        """Copy a lit wall column from the parent face onto the return."""
        if src_rgb is None:
            u = u_partition_at_x(src_pt[0])
            paint_face_column(dst_pt[0], dst_pt[1], u, darken=darken)
            return
        h = max(1, int(round(face_h)))
        sxi = int(np.clip(round(src_pt[0]), 0, ART_W - 1))
        dxi = int(round(dst_pt[0]))
        if not 0 <= dxi < ART_W:
            return
        src_ys = np.clip(
            np.linspace(src_pt[1] - h, src_pt[1], h).astype(int), 0, ART_H - 1
        )
        col = src_rgb[src_ys, sxi] * darken
        y_top = dst_pt[1] - h
        y0 = max(0, int(np.floor(y_top)))
        y1 = min(ART_H - 1, int(np.ceil(dst_pt[1])))
        for y in range(y0, y1 + 1):
            t = (y - y_top) / max(h, 1)
            if t < -0.02 or t > 1.02:
                continue
            src_i = int(np.clip(round(t * (h - 1)), 0, h - 1))
            rgb[y, dxi] = col[src_i]
            alpha[y, dxi] = 1.0
        shoe_rgb = np.clip(wainscot * 0.55 * darken, 0, 255)
        for y in range(y1 + 1, min(ART_H, y1 + int(shoe) + 1)):
            rgb[y, dxi] = shoe_rgb
            alpha[y, dxi] = 1.0

    def tip_reveal_cloned(
        face_pt: tuple[float, float],
        back_pt: tuple[float, float],
        parent_a: float,
    ) -> None:
        """Thickness cap cloned from the parent wall near the corner."""
        steps = max(4, int(round(abs(back_pt[0] - face_pt[0]) + 2)))
        for i in range(steps):
            t = i / max(steps - 1, 1)
            x = face_pt[0] + (back_pt[0] - face_pt[0]) * t
            y = face_pt[1] + (back_pt[1] - face_pt[1]) * t
            path_px = abs(x - face_pt[0]) + abs(y - face_pt[1])
            db = path_px / max(rp.AXIS_NE_LEN, 1.0)
            src = rp.plan(parent_a, rp.B_ROOM - db)
            clone_column(src, (x, y), darken=1.0 - 0.10 * t)
        # Dark thickness foot only — lit wainscot here read as a yellow leftover edge.
        part.quad(
            rgb,
            alpha,
            [
                (face_pt[0] - 1, face_pt[1] + shoe),
                (back_pt[0] + 1, back_pt[1] + shoe),
                (back_pt[0] + 1, back_pt[1] + 2),
                (face_pt[0] - 1, face_pt[1] + 2),
            ],
            np.clip(wainscot * 0.5, 0, 255),
            grain=1.5,
            blur=0.5,
        )

    def l_return(a_from: float, a_to: float, parent_a: float) -> None:
        """Return that mirrors the parent wall by cloning its lit columns."""
        thick_b = P.thickness_a * 1.05
        b_face, b_back = rp.B_ROOM, rp.B_ROOM - thick_b
        f0, f1 = rp.plan(a_from, b_face), rp.plan(a_to, b_face)

        contact_shadow(
            min(a_from, a_to) - 0.01,
            max(a_from, a_to) + 0.01,
            b_back - 0.01,
            b_face + 0.022,
            strength=0.62,
        )

        steps = max(12, int(round(abs(a_to - a_from) * rp.AXIS_NW_LEN)))
        for i in range(steps + 1):
            t = i / max(steps, 1)
            a = a_from + (a_to - a_from) * t
            path_px = abs(a - a_from) * rp.AXIS_NW_LEN
            # Mirror: walk back along the parent face the same distance.
            db = path_px / max(rp.AXIS_NE_LEN, 1.0)
            src = rp.plan(parent_a, rp.B_ROOM - db)
            dst = rp.plan(a, b_face)
            clone_column(src, dst, darken=1.0)
            clone_column(src, (dst[0] - 1, dst[1]), darken=0.99)
            clone_column(src, (dst[0] + 1, dst[1]), darken=0.99)

        tip_reveal_cloned(
            rp.plan(a_to, b_face),
            rp.plan(a_to, b_back),
            parent_a=parent_a,
        )
        # Dark shoe flush to floor — same family as wainscot, never a lit sill.
        part.quad(
            rgb,
            alpha,
            [
                (f0[0], f0[1] + shoe),
                (f1[0], f1[1] + shoe),
                (f1[0], f1[1] + 1),
                (f0[0], f0[1] + 1),
            ],
            np.clip(wainscot * 0.5, 0, 255),
            grain=1.5,
            blur=0.6,
        )
        contact_shadow(a_to - 0.018, a_to + 0.018, b_back - 0.008, b_face + 0.028, 0.78)

    def floor_threshold(a0: float, a1: float) -> None:
        """Dark floor-edge AO in the open mouth — no pale board / lit sill."""
        if a1 - a0 < 0.02:
            return
        shadow = part.polygon_mask(
            [
                rp.plan(a0 - 0.01, rp.B_ROOM - 0.006),
                rp.plan(a1 + 0.01, rp.B_ROOM - 0.006),
                rp.plan(a1 + 0.01, rp.B_ROOM + 0.028),
                rp.plan(a0 - 0.01, rp.B_ROOM + 0.028),
            ],
            blur=4.0,
        )
        dark = np.zeros((ART_H, ART_W, 3), np.float32)
        dark[:] = (5.0, 6.0, 8.0)
        part.over(rgb, alpha, dark, shadow * 0.42)

    # Sill first (under tips), then tips overpaint flush into it.
    a_part_stub = a_face - CUTAWAY_RETURN_LEN
    a_ne_root = max(P.thickness_a * 1.5, 0.02)
    a_ne_stub = a_ne_root + CUTAWAY_RETURN_LEN
    floor_threshold(a_ne_stub + 0.008, a_part_stub - 0.008)
    floor_threshold(a_face + 0.02, min(rp.A_ROOM - 0.05, a_face + 0.55))

    # Partition tip + L-return: clone lit columns from the partition face.
    contact_shadow(a_back - 0.015, a_face + 0.025, rp.B_ROOM - 0.025, rp.B_ROOM + 0.025, 0.65)
    tip_reveal_cloned(
        rp.plan(a_face, rp.B_ROOM), rp.plan(a_back, rp.B_ROOM), parent_a=a_face
    )
    l_return(a_face, a_part_stub, parent_a=a_face)

    # NE return: clone from the shell NE wall (a≈0) so wallpaper meets that face.
    contact_shadow(a_ne_root - 0.015, a_ne_stub + 0.02, rp.B_ROOM - 0.025, rp.B_ROOM + 0.025, 0.65)
    tip_reveal_cloned(
        rp.plan(a_ne_root, rp.B_ROOM),
        rp.plan(a_ne_root + P.thickness_a, rp.B_ROOM),
        parent_a=0.0,
    )
    l_return(a_ne_root, a_ne_stub, parent_a=0.0)

    # Wide protect so the void cannot turn tips into black slots.
    for a0, a1 in (
        (a_part_stub - 0.04, a_face + 0.05),
        (a_ne_root - 0.03, a_ne_stub + 0.05),
        (a_back - 0.02, a_face + 0.04),
    ):
        q0, q1 = rp.plan(a0, rp.B_ROOM - 0.06), rp.plan(a1, rp.B_ROOM - 0.06)
        q2, q3 = rp.plan(a1, rp.B_ROOM + 0.04), rp.plan(a0, rp.B_ROOM + 0.04)
        protect = np.maximum(
            protect,
            part.polygon_mask(
                [
                    (q0[0], q0[1] + 16 + shoe),
                    (q1[0], q1[1] + 16 + shoe),
                    (q2[0], q2[1] - face_h - 28),
                    (q3[0], q3[1] - face_h - 28),
                ],
                blur=1.4,
            ),
        )
    protect = np.maximum(
        protect,
        part.polygon_mask(
            [
                rp.plan(-0.08, rp.B_ROOM - 0.03),
                rp.plan(rp.A_ROOM + 0.08, rp.B_ROOM - 0.03),
                rp.plan(rp.A_ROOM + 0.08, rp.B_ROOM + 0.05),
                rp.plan(-0.08, rp.B_ROOM + 0.05),
            ],
            blur=1.5,
        ),
    )
    return protect


def bake_design_edge_void(
    rgba: np.ndarray, extra_protect: np.ndarray | None = None
) -> np.ndarray:
    """Harder void past B_ROOM so the cutaway edge reads as a room boundary."""
    out = rgba.copy()
    t_ne = rp.WALL_THICKNESS_PX / rp.AXIS_NE_LEN
    pts = [
        rp.plan(-0.5, rp.B_ROOM + t_ne * 0.25),
        rp.plan(rp.A_ROOM + 0.5, rp.B_ROOM + t_ne * 0.25),
        rp.plan(rp.A_ROOM + 0.5, rp.B_NEAR + 0.8),
        rp.plan(-0.5, rp.B_NEAR + 0.8),
    ]
    mask = part.polygon_mask(pts, blur=1.2)
    ys = np.mgrid[0:ART_H, 0:ART_W][0].astype(np.float32)
    edge_y = float(rp.plan(0.5, rp.B_ROOM)[1])
    # Floor stops just past the sill; keep a short feather so it is not a ruler cut.
    soft = np.clip((ys - edge_y) / 72.0, 0, 1)
    a_face = rp.PARTITION.a_line + rp.PARTITION.thickness_a
    protect = np.zeros((ART_H, ART_W), np.float32)
    g0, g1 = rp.plan(a_face, -rp.PARTITION.overrun_b), rp.plan(a_face, rp.B_ROOM)
    protect = np.maximum(
        protect,
        part.polygon_mask(
            [
                (g0[0] - 14, g0[1] + 8),
                (g1[0] + 14, g1[1] + 8),
                (g1[0] + 14, g1[1] - rp.PARTITION.face_h - 16),
                (g0[0] - 14, g0[1] - rp.PARTITION.face_h - 16),
            ],
            blur=0.8,
        ),
    )
    if extra_protect is not None:
        protect = np.maximum(protect, extra_protect)
    m = (mask * soft * (1.0 - protect))[..., None]
    black = np.zeros_like(out)
    black[:, :, 3] = 255.0
    out = out * (1.0 - m) + black * m
    return out


def bake_registered_suite() -> tuple[Image.Image, dict]:
    shell = Image.open(SHELL).convert("RGBA")
    if shell.size != (ART_W, ART_H):
        shell = shell.resize((ART_W, ART_H), Image.Resampling.LANCZOS)

    shell_rgb = np.asarray(shell.convert("RGB"), np.float32)
    shell_f = np.dstack([shell_rgb, np.full(shell_rgb.shape[:2], 255.0, np.float32)])
    mats = part.sample_shell_materials(shell_f)
    partition, opening = part.paint_partition_plate(mats)

    mask = suite_cutaway_mask()
    cut = part.apply_mask(partition, Image.fromarray((mask * 255).astype(np.uint8), "L"))

    base = np.asarray(shell, np.float32)
    overlay = np.asarray(cut.convert("RGBA"), np.float32)
    a = overlay[:, :, 3:4] / 255.0
    out = base.copy()
    out[:, :, :3] = base[:, :, :3] * (1.0 - a) + overlay[:, :, :3] * a
    out[:, :, 3] = np.maximum(base[:, :, 3], overlay[:, :, 3])

    # Freeze the lit shell+partition before tips so both paint passes clone the same parent.
    pre_tip = out.copy()
    tip_rgb = np.zeros((ART_H, ART_W, 3), np.float32)
    tip_alpha = np.zeros((ART_H, ART_W), np.float32)
    tip_protect = paint_cutaway_readability(
        tip_rgb, tip_alpha, mats, source_rgba=pre_tip
    )
    tip_a = tip_alpha[..., None]
    out[:, :, :3] = out[:, :, :3] * (1.0 - tip_a) + tip_rgb * tip_a
    out[:, :, 3] = np.maximum(out[:, :, 3], tip_alpha * 255.0)

    out = bake_design_edge_void(out, extra_protect=tip_protect)

    # Re-apply cutaway cues after the void so end-caps/sill are never eaten to black.
    tip_rgb2 = np.zeros((ART_H, ART_W, 3), np.float32)
    tip_alpha2 = np.zeros((ART_H, ART_W), np.float32)
    paint_cutaway_readability(tip_rgb2, tip_alpha2, mats, source_rgba=pre_tip)
    tip_a2 = tip_alpha2[..., None]
    out[:, :, :3] = out[:, :, :3] * (1.0 - tip_a2) + tip_rgb2 * tip_a2
    out[:, :, 3] = np.maximum(out[:, :, 3], tip_alpha2 * 255.0)

    # Kill pale floor-edge slivers under cutaway tips (reads as leftover yellow geo).
    out = darken_tip_floor_slivers(out)

    plate = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")

    metrics = {
        "plate_size": [ART_W, ART_H],
        "source": "registered_bake: shell + partition + cutaway readability + void",
        "suite_full_b": SUITE_FULL_B,
        "b_room": rp.B_ROOM,
        "cutaway_return_len": CUTAWAY_RETURN_LEN,
        "movable_leaves_baked": False,
        "internal_door": opening,
        "exterior_door_plan": [0.004, 0.425],
        "note": "Mouth open; L-returns + dark tip feet + hard void for cutaway readability.",
    }
    return plate, metrics


def darken_tip_floor_slivers(rgba: np.ndarray) -> np.ndarray:
    """Crush bright floorboard edges under tip feet into dark contact."""
    out = rgba.copy()
    P = rp.PARTITION
    a_face = P.a_line + P.thickness_a
    a_back = P.a_line
    a_part_stub = a_face - CUTAWAY_RETURN_LEN
    a_ne_root = max(P.thickness_a * 1.5, 0.02)
    a_ne_stub = a_ne_root + CUTAWAY_RETURN_LEN
    mask = np.zeros((ART_H, ART_W), np.float32)
    for a0, a1, b0, b1 in (
        (a_back - 0.03, a_face + 0.04, rp.B_ROOM - 0.03, rp.B_ROOM + 0.055),
        # Past the stub tip — pale floorboards peek out beyond the L-return end.
        (a_part_stub - 0.05, a_face + 0.03, rp.B_ROOM - 0.03, rp.B_ROOM + 0.055),
        (a_ne_root - 0.03, a_ne_stub + 0.05, rp.B_ROOM - 0.03, rp.B_ROOM + 0.055),
    ):
        mask = np.maximum(
            mask,
            part.polygon_mask(
                [
                    rp.plan(a0, b0),
                    rp.plan(a1, b0),
                    rp.plan(a1, b1),
                    rp.plan(a0, b1),
                ],
                blur=3.5,
            ),
        )
    # Only crush pixels that are still too bright for a wall foot.
    lum = out[:, :, :3].mean(axis=2)
    hot = ((lum > 40.0) & (mask > 0.05)).astype(np.float32) * np.clip(mask * 1.4, 0, 1)
    dark = np.zeros_like(out[:, :, :3])
    dark[:] = (9.0, 8.0, 6.0)
    a = hot[..., None]
    out[:, :, :3] = out[:, :, :3] * (1.0 - a) + dark * a
    return out


def export_ig(master_path: Path) -> tuple[Image.Image, dict]:
    master = Image.open(master_path).convert("RGBA")
    if master.size != (MASTER_W, MASTER_H):
        master = master.resize((MASTER_W, MASTER_H), Image.Resampling.LANCZOS)
    runtime = master.resize((ART_W, ART_H), Image.Resampling.LANCZOS)
    a_face = rp.PARTITION.a_line + rp.PARTITION.thickness_a
    metrics = {
        "plate_size": [ART_W, ART_H],
        "source": f"ig_master:{master_path.name}",
        "movable_leaves_baked": False,
        "internal_door": {
            "a_face": a_face,
            "a_back": rp.PARTITION.a_line,
            "b_door0": rp.PARTITION.b_door0,
            "b_door1": rp.PARTITION.b_door1,
            "hinge_plate_xy": list(rp.plan(a_face, rp.PARTITION.b_door0)),
            "latch_plate_xy": list(rp.plan(a_face, rp.PARTITION.b_door1)),
        },
        "note": "IG path — verify outer walls + partition continuation before approval.",
    }
    return runtime, metrics


def opening_metrics_authored() -> dict:
    a_face = rp.PARTITION.a_line + rp.PARTITION.thickness_a
    a_back = rp.PARTITION.a_line
    b0, b1 = rp.PARTITION.b_door0, rp.PARTITION.b_door1

    def authored(a: float, b: float) -> list[float]:
        x, y_up = rp.authored(a, b)
        return [round(x, 2), round(y_up, 2)]

    return {
        "hinge_face": authored(a_face, b0),
        "strike_face": authored(a_face, b1),
        "hinge_back": authored(a_back, b0),
        "strike_back": authored(a_back, b1),
        "b_door0": b0,
        "b_door1": b1,
        "a_face": a_face,
        "a_back": a_back,
    }


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--ig",
        action="store_true",
        help="Ship resized Image Generator master instead of registered shell+partition bake",
    )
    args = parser.parse_args(argv)

    GEN_DIR.mkdir(parents=True, exist_ok=True)
    RUNTIME.parent.mkdir(parents=True, exist_ok=True)

    # Always archive the latest IG attempt for reference.
    ig = find_ig_master()
    if ig is not None:
        dest = GEN_DIR / "office_suite_plate_v01_gen.png"
        if ig.resolve() != dest.resolve():
            Image.open(ig).save(dest)
        print(f"archived IG master {dest}")

    if args.ig:
        if ig is None:
            raise SystemExit("No IG master found; cannot use --ig")
        plate, metrics = export_ig(ig)
        print("mode: IG resize (walls not guaranteed)")
    else:
        plate, metrics = bake_registered_suite()
        metrics["authored_jambs"] = opening_metrics_authored()
        print("mode: registered bake (shell + continuous partition past doorway)")

    plate.save(RUNTIME)
    plate.save(GENERATED_COPY)
    plate.save(GEN_DIR / "office_suite_plate.png")
    # Half-res review without launching the game.
    plate.resize((ART_W // 2, ART_H // 2), Image.Resampling.LANCZOS).save(
        GEN_DIR / "office_suite_plate_half.png"
    )

    metrics_path = GEN_DIR / "office_suite_opening.json"
    metrics_path.write_text(json.dumps(metrics, indent=2) + "\n")

    print(f"runtime {RUNTIME} {plate.size}")
    print(f"metrics {metrics_path}")
    print("NOTE: door leaves stay separate; no doorway module hole-punch into shell.")


if __name__ == "__main__":
    main()

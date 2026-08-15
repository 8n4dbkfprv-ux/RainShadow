"""Baldur's Gate: EE / Infinity Engine orthographic ground projection.

Canonical area-art camera for RainShadow. Matches GemRB searchmap geometry
(`SearchmapPoint(x/16, y/12)`, ground circle as a 16:12 ellipse) and the
runtime `SearchMap.defaultCellSize` of 16×12 world units.

Camera (orthographic — no vanishing point, uniform scale everywhere on plate):

    elevation  asin(0.75) ≈ 48.59°
    azimuth    45°  (ground axes symmetric on screen)
    ground axes on screen at atan(0.75) ≈ 36.87° from horizontal
    ground foreshortening  0.750 screen-Y per world-Y
    height foreshortening  sqrt(1 − 0.75²) ≈ 0.6614
    verticals stay vertical

Nav diamond is 128×96 (was 128×64 under the old 2:1 dimetric lock). That diamond
spans exactly 8×8 SearchMap cells, so planner and runtime share a ratio.

See Documentation/InfinityEngineGroundProjection.md for the visual spec.
"""

from __future__ import annotations

import math
import numpy as np
from PIL import Image, ImageDraw

# ---------------------------------------------------------------------------
# Canonical constants
# ---------------------------------------------------------------------------

GROUND_FORESHORTEN: float = 0.75
HEIGHT_FORESHORTEN: float = math.sqrt(1.0 - GROUND_FORESHORTEN * GROUND_FORESHORTEN)

ELEVATION_RAD: float = math.asin(GROUND_FORESHORTEN)
ELEVATION_DEG: float = math.degrees(ELEVATION_RAD)  # ≈ 48.5904
AZIMUTH_DEG: float = 45.0
GROUND_AXIS_DEG: float = math.degrees(math.atan(GROUND_FORESHORTEN))  # ≈ 36.8699

# Screen-space slope of each ground axis (±dy/dx). Under 45° azimuth both
# axes are symmetric: NW runs up-left, NE runs up-right in image space when
# the floor diamond is drawn with +Y toward the camera-near tip.
GROUND_SLOPE: float = GROUND_FORESHORTEN  # 0.75

# Nav / registration diamond. Half-steps are half the diamond axes.
DIAMOND_W: int = 128
DIAMOND_H: int = 96
HALF_STEP_X: float = DIAMOND_W / 2.0  # 64
HALF_STEP_Y: float = DIAMOND_H / 2.0  # 48

# AABB inset from the diamond so corner overhang does not eat neighbouring
# floor. X inset matches the old 104-from-128; Y is the 128×96-proportional
# 78 (was 52 from 64).
CELL_RECT: tuple[float, float] = (104.0, 78.0)
# Partition doorway AABBs stay at the old 40×20. Scaling Y with the taller
# diamond (→30) widens plan-b span past the painted aperture under the
# steeper ±0.75 axes and seals the waiting side. Plan-b aperture width, not
# diamond ratio, owns this inset.
PARTITION_CELL_RECT: tuple[float, float] = (40.0, 20.0)

# GemRB / Infinity Engine ground-circle ellipse (a circle on the ground).
ELLIPSE_A: int = 16
ELLIPSE_B: int = 12
ELLIPSE_RATIO: float = ELLIPSE_A / ELLIPSE_B  # 4/3

# Default plate origin used by the office layout planner (x locked to plate
# centre; y is re-derived against the painted floor plane elsewhere).
DEFAULT_ORIGIN_X: float = 2048.0

# UI ground-marker canvases match one nav diamond.
RING_SIZE: tuple[int, int] = (DIAMOND_W, DIAMOND_H)
PIP_SIZE: tuple[int, int] = (DIAMOND_W // 2, DIAMOND_H // 2)


# ---------------------------------------------------------------------------
# Unit axis helpers (plate / image space, y-down unless noted)
# ---------------------------------------------------------------------------

def ground_axis_ne(length: float = 1.0) -> tuple[float, float]:
    """Unit NE ground axis in image space (y down): +x, +y toward camera-near."""
    # Screen direction at +36.87° from horizontal: (1, +0.75) normalised, then
    # scaled so the Euclidean length equals `length`.
    inv = 1.0 / math.hypot(1.0, GROUND_SLOPE)
    return (length * inv, length * inv * GROUND_SLOPE)


def ground_axis_nw(length: float = 1.0) -> tuple[float, float]:
    """Unit NW ground axis in image space (y down): −x, +y toward camera-near."""
    inv = 1.0 / math.hypot(1.0, GROUND_SLOPE)
    return (-length * inv, length * inv * GROUND_SLOPE)


def axis_with_slope(dx: float, *, toward_camera: bool = True) -> tuple[float, float]:
    """Build an axis with canonical ±0.75 slope from a chosen screen-x run.

    Positive `dx` → NE axis; negative → NW. `toward_camera` puts +image-y on
    the camera-near direction (standard for RainShadow floor diamonds).
    """
    sign = 1.0 if toward_camera else -1.0
    return (dx, sign * abs(dx) * GROUND_SLOPE)


def screen_height(world_height: float) -> float:
    """Orthographic height foreshortening: world-up → screen-up pixels."""
    return world_height * HEIGHT_FORESHORTEN


def world_height(screen_h: float) -> float:
    return screen_h / HEIGHT_FORESHORTEN


# ---------------------------------------------------------------------------
# Cell ↔ plate projection (authored / y-up layout space)
# ---------------------------------------------------------------------------

def cell_to_authored(
    c: int,
    r: int,
    *,
    origin_x: float = DEFAULT_ORIGIN_X,
    origin_y: float,
) -> tuple[float, float]:
    """Dimetric cell indices → authored (y-up) plate point."""
    return (
        origin_x + (c - r) * HALF_STEP_X,
        origin_y + (c + r) * HALF_STEP_Y,
    )


def authored_to_cell(
    x: float,
    y: float,
    *,
    origin_x: float = DEFAULT_ORIGIN_X,
    origin_y: float,
) -> tuple[int, int]:
    """Authored (y-up) plate point → nearest dimetric cell indices."""
    px = (x - origin_x) / HALF_STEP_X
    py = (y - origin_y) / HALF_STEP_Y
    return (round((px + py) / 2.0), round((py - px) / 2.0))


def cell_aabb(x: float, y: float) -> tuple[float, float, float, float]:
    """Inset AABB for a nav solid centred on an authored point."""
    w, h = CELL_RECT
    return (x - w / 2.0, y - h / 2.0, w, h)


def partition_cell_aabb(x: float, y: float) -> tuple[float, float, float, float]:
    w, h = PARTITION_CELL_RECT
    return (x - w / 2.0, y - h / 2.0, w, h)


# ---------------------------------------------------------------------------
# Ground ellipse (selection rings, move markers, floor ripples)
# ---------------------------------------------------------------------------

def ellipse_box(
    cx: float,
    cy: float,
    radius: float,
    *,
    a: float = ELLIPSE_A,
    b: float = ELLIPSE_B,
) -> tuple[float, float, float, float]:
    """Axis-aligned bbox of a ground circle of the given searchmap radius.

    `radius` is in searchmap-cell units; screen radii are `radius * (a, b)`
    when the defaults match one IE search cell. Prefer
    `ground_ellipse_pixels` for UI canvases.
    """
    rx = radius * a
    ry = radius * b
    return (cx - rx, cy - ry, cx + rx, cy + ry)


def ground_ellipse_pixels(
    canvas: tuple[int, int],
    *,
    fill: float = 0.86,
) -> tuple[int, int, int, int]:
    """Pixel bbox of a 16:12 ground ellipse centred on `canvas`, inset by fill."""
    cw, ch = canvas
    # Fit the 4:3 ellipse inside the canvas while preserving aspect.
    max_w = cw * fill
    max_h = ch * fill
    # Target aspect = 16:12 = 4:3.
    if max_w / max_h > ELLIPSE_RATIO:
        eh = max_h
        ew = eh * ELLIPSE_RATIO
    else:
        ew = max_w
        eh = ew / ELLIPSE_RATIO
    left = (cw - ew) / 2.0
    top = (ch - eh) / 2.0
    return (
        int(round(left)),
        int(round(top)),
        int(round(left + ew - 1)),
        int(round(top + eh - 1)),
    )


def synthesize_ground_ring(
    rgb: tuple[int, int, int],
    size: tuple[int, int] = RING_SIZE,
    *,
    fill: float = 0.86,
) -> Image.Image:
    """Thin IE-style selection ring: 16:12 ellipse with soft outer falloff."""
    cw, ch = size
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(out)
    box = ground_ellipse_pixels(size, fill=fill)

    for inset, alpha in ((0, 55), (1, 140), (2, 255)):
        b = (box[0] + inset, box[1] + inset, box[2] - inset, box[3] - inset)
        if b[2] - b[0] < 4 or b[3] - b[1] < 2:
            break
        draw.ellipse(b, outline=(*rgb, alpha), width=1)

    rgba = np.array(out, dtype=np.float32)
    yy, xx = np.mgrid[0:ch, 0:cw]
    cx, cy = (cw - 1) / 2.0, (ch - 1) / 2.0
    ew = box[2] - box[0] + 1
    eh = box[3] - box[1] + 1
    rx = max(1.0, (ew / 2.0) - 3.2)
    ry = max(1.0, (eh / 2.0) - 3.2)
    inside = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2 <= 1.0
    rgba[inside, 3] = 0
    rgba[inside, :3] = 0
    return Image.fromarray(rgba.astype(np.uint8), "RGBA")


def is_within_ellipse(
    dx: float,
    dy: float,
    *,
    a: float = ELLIPSE_A,
    b: float = ELLIPSE_B,
) -> bool:
    """GemRB-style ground hit test: point relative to ellipse centre."""
    return (dx * dx) / (a * a) + (dy * dy) / (b * b) <= 1.0


def searchmap_point(x: float, y: float) -> tuple[float, float]:
    """World/plate point → continuous searchmap cell coordinates."""
    return (x / ELLIPSE_A, y / ELLIPSE_B)


# ---------------------------------------------------------------------------
# Dimetric box helper (procedural props / grayboxes)
# ---------------------------------------------------------------------------

def iso_box_points(
    cx: float,
    cy: float,
    w: float,
    d: float,
    h: float,
) -> dict[str, tuple[float, float]]:
    """Near-ground-centred BG:EE box corners (image y-down, cy = near ground).

    Ground foreshortening uses half-extent * 0.75/2 on each axis half so a
    square footprint reads as a 16:12 rhombus. Height is already screen-space;
    callers that hold world height should pass `screen_height(world_h)`.
    """
    hx = w / 2.0
    hy = w * GROUND_FORESHORTEN / 4.0  # half-width * (0.75/2)
    dx = d / 2.0
    dy = d * GROUND_FORESHORTEN / 4.0
    return {
        "nl": (cx - hx, cy - h),
        "nr": (cx + hx, cy - h),
        "fr": (cx + hx - dx, cy - h - dy),
        "fl": (cx - hx - dx, cy - h - dy),
        "gnl": (cx - hx, cy),
        "gnr": (cx + hx, cy),
        "gfr": (cx + hx - dx, cy - dy),
        "gfl": (cx - hx - dx, cy - dy),
    }


def wall_top_offset(face_h: float) -> tuple[float, float]:
    """Screen-space shift from a ground point to the top of a vertical face.

    Verticals stay vertical (Δx from ground-axis shear of the *base*, not the
    upright), so the upright itself is pure −image-y by `face_h`. Graybox
    drawers that previously used a fake skew on uprights should use this for
    the face height and keep base edges on the ±0.75 ground axes.
    """
    return (0.0, -face_h)


def ground_shear_for_height(face_h: float) -> float:
    """Legacy graybox helper: horizontal shift paired with a vertical rise.

    Under true IE projection uprights do not shear; this returns the ground
    slope times face height for drawers that still extrude a parallelogram
    face along a single screen axis (EW cutaway walls). Prefer painting the
    base on the ground axis and raising vertically when possible.
    """
    return face_h * GROUND_SLOPE


# ---------------------------------------------------------------------------
# Self-check
# ---------------------------------------------------------------------------

def _self_check() -> None:
    assert abs(HEIGHT_FORESHORTEN - 0.661437827766) < 1e-9
    assert abs(ELEVATION_DEG - 48.5903778907) < 1e-6
    assert abs(GROUND_AXIS_DEG - 36.8698976458) < 1e-6
    assert DIAMOND_W / ELLIPSE_A == DIAMOND_H / ELLIPSE_B == 8
    assert HALF_STEP_X == 64 and HALF_STEP_Y == 48
    o = cell_to_authored(0, 0, origin_y=100.0)
    assert o == (2048.0, 100.0)
    assert authored_to_cell(*o, origin_y=100.0) == (0, 0)
    p = cell_to_authored(1, 0, origin_y=100.0)
    assert p == (2112.0, 148.0)
    assert authored_to_cell(*p, origin_y=100.0) == (1, 0)
    assert is_within_ellipse(0, 0)
    assert is_within_ellipse(16, 0)
    assert is_within_ellipse(0, 12)
    assert not is_within_ellipse(16.1, 0)
    assert searchmap_point(32, 24) == (2.0, 2.0)
    ne = ground_axis_ne(1.0)
    nw = ground_axis_nw(1.0)
    assert abs(ne[1] / ne[0] - GROUND_SLOPE) < 1e-12
    assert abs(nw[1] / nw[0] + GROUND_SLOPE) < 1e-12
    print("ie_projection self-check OK")


if __name__ == "__main__":
    _self_check()

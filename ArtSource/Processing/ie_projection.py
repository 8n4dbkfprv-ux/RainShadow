"""Ground projection for RainShadow area art.

Two cameras are defined here, and exactly one is active.

`BGEE` is the target: the Baldur's Gate: EE / Infinity Engine orthographic
camera, which is what the runtime navigation layer already assumes
(`SearchMap.defaultCellSize` 16x12, `ActorLocomotionPacing.verticalProjectionScale`
0.75). Under it every ground line lands on a screen slope of +-0.75 (+-36.87
degrees), a circle on the ground is a 16:12 ellipse, and uprights stay vertical.

`LEGACY_V2` is what the pre-adoption plates were drawn to. Act I city grounds
and the V5 office suite are now on the BG:EE lock, so `ACTIVE` follows them.

Adoption is therefore a single edit *paired with new art*:

    ACTIVE = BGEE

plus re-fitting `office_room_plan` REAR/axis lengths to the new plate and
re-running the sequence in `Documentation/BGEEProjectionMasterRegen.md`.
`qa_ie_projection.py` enforces that the pipeline and `ACTIVE` agree.
"""

from __future__ import annotations

import math
from dataclasses import dataclass

import numpy as np
from PIL import Image, ImageDraw


@dataclass(frozen=True)
class GroundProjection:
    """A fixed orthographic ground camera plus the raster constants drawn to it.

    `ground_foreshorten` is screen-Y per world-Y on the ground plane; it is the
    tangent of the on-screen ground-axis angle and the sine of the camera
    elevation. Everything else either derives from it or is an authored raster
    size that must move with it.
    """

    name: str
    ground_foreshorten: float
    diamond: tuple[int, int]
    cell_rect: tuple[float, float]
    partition_cell_rect: tuple[float, float]
    ring_size: tuple[int, int]
    pip_size: tuple[int, int]
    # Screen-space shears used by the procedural graybox drawers. These were
    # hand-picked for the legacy camera and are not derived from it; under
    # BG:EE they become the real ground slope.
    graybox_skew: float
    fg_wall_skew: float
    # iso_box ground foreshortening as a fraction of width/depth.
    box_depth_frac: float

    @property
    def height_foreshorten(self) -> float:
        return math.sqrt(1.0 - self.ground_foreshorten**2)

    @property
    def elevation_deg(self) -> float:
        return math.degrees(math.asin(self.ground_foreshorten))

    @property
    def ground_axis_deg(self) -> float:
        return math.degrees(math.atan(self.ground_foreshorten))

    @property
    def ground_slope(self) -> float:
        return self.ground_foreshorten

    @property
    def half_step(self) -> tuple[float, float]:
        return (self.diamond[0] / 2.0, self.diamond[1] / 2.0)

    @property
    def ellipse_ratio(self) -> float:
        """Width:height of a ground circle under this camera."""
        return 1.0 / self.ground_foreshorten


# The target. 128x96 spans exactly 8x8 SearchMap cells of 16x12, so the planner
# grid and the runtime grid finally share a ratio.
BGEE = GroundProjection(
    name="bgee",
    ground_foreshorten=0.75,
    diamond=(128, 96),
    cell_rect=(104.0, 78.0),
    # Not scaled with the taller diamond: the partition inset is owned by the
    # painted doorway's plan-b width, and widening it seals the waiting side.
    partition_cell_rect=(40.0, 20.0),
    ring_size=(128, 96),
    pip_size=(64, 48),
    graybox_skew=0.75,
    fg_wall_skew=0.75,
    box_depth_frac=0.375,
)

# What the pre-adoption plates were drawn to. Kept so a revert is one flip.
LEGACY_V2 = GroundProjection(
    name="legacy_v2",
    ground_foreshorten=0.5,
    diamond=(128, 64),
    cell_rect=(104.0, 52.0),
    partition_cell_rect=(40.0, 20.0),
    ring_size=(128, 64),
    pip_size=(64, 32),
    graybox_skew=0.22,
    fg_wall_skew=0.35,
    box_depth_frac=0.25,
)

# ---------------------------------------------------------------------------
# Flip with the on-lock masters. City grounds + office V7 (V5 floor,
# human-scale wall face) are installed.
# ---------------------------------------------------------------------------
ACTIVE: GroundProjection = BGEE

# Active-camera aliases. Pipeline modules use these, so they follow ACTIVE.
GROUND_FORESHORTEN = ACTIVE.ground_foreshorten
GROUND_SLOPE = ACTIVE.ground_slope
HEIGHT_FORESHORTEN = ACTIVE.height_foreshorten
ELEVATION_DEG = ACTIVE.elevation_deg
GROUND_AXIS_DEG = ACTIVE.ground_axis_deg
AZIMUTH_DEG = 45.0

DIAMOND_W, DIAMOND_H = ACTIVE.diamond
HALF_STEP_X, HALF_STEP_Y = ACTIVE.half_step
CELL_RECT = ACTIVE.cell_rect
PARTITION_CELL_RECT = ACTIVE.partition_cell_rect
RING_SIZE = ACTIVE.ring_size
PIP_SIZE = ACTIVE.pip_size
GRAYBOX_SKEW = ACTIVE.graybox_skew
FG_WALL_SKEW = ACTIVE.fg_wall_skew
BOX_DEPTH_FRAC = ACTIVE.box_depth_frac

# GemRB / Infinity Engine searchmap cell and ground-circle ellipse. These are
# runtime facts, already shipped in Swift, and do not depend on ACTIVE.
ELLIPSE_A = 16
ELLIPSE_B = 12

# Plate centre used by the office layout planner.
DEFAULT_ORIGIN_X = 2048.0


# ---------------------------------------------------------------------------
# Axis helpers
# ---------------------------------------------------------------------------

def axis_with_slope(
    dx: float,
    *,
    toward_camera: bool = True,
    projection: GroundProjection | None = None,
) -> tuple[float, float]:
    """Ground axis with the camera's slope, from a chosen screen-x run.

    Positive `dx` gives the NE axis, negative the NW. `toward_camera` puts
    +image-y on the camera-near side, which is how RainShadow floor diamonds
    are authored.
    """
    p = projection or ACTIVE
    sign = 1.0 if toward_camera else -1.0
    return (dx, sign * abs(dx) * p.ground_slope)


def screen_height(world_height: float, projection: GroundProjection | None = None) -> float:
    """World-up height to screen-up pixels."""
    p = projection or ACTIVE
    return world_height * p.height_foreshorten


def ground_shear_for_height(face_h: float, projection: GroundProjection | None = None) -> float:
    """Horizontal shift paired with a vertical rise on a graybox wall face."""
    p = projection or ACTIVE
    return face_h * p.graybox_skew


# ---------------------------------------------------------------------------
# Cell <-> plate projection (authored / y-up layout space)
# ---------------------------------------------------------------------------

def cell_to_authored(
    c: int,
    r: int,
    *,
    origin_x: float = DEFAULT_ORIGIN_X,
    origin_y: float,
) -> tuple[float, float]:
    """Diamond cell indices to authored (y-up) plate point."""
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
    """Authored (y-up) plate point to nearest diamond cell indices."""
    px = (x - origin_x) / HALF_STEP_X
    py = (y - origin_y) / HALF_STEP_Y
    return (round((px + py) / 2.0), round((py - px) / 2.0))


def cell_aabb(x: float, y: float) -> tuple[float, float, float, float]:
    w, h = CELL_RECT
    return (x - w / 2.0, y - h / 2.0, w, h)


def partition_cell_aabb(x: float, y: float) -> tuple[float, float, float, float]:
    w, h = PARTITION_CELL_RECT
    return (x - w / 2.0, y - h / 2.0, w, h)


# ---------------------------------------------------------------------------
# Ground ellipse (selection rings, move markers, floor ripples)
# ---------------------------------------------------------------------------

def is_within_ellipse(dx: float, dy: float, *, a: float = ELLIPSE_A, b: float = ELLIPSE_B) -> bool:
    """GemRB-style ground hit test, relative to the ellipse centre."""
    return (dx * dx) / (a * a) + (dy * dy) / (b * b) <= 1.0


def searchmap_point(x: float, y: float) -> tuple[float, float]:
    """World/plate point to continuous searchmap cell coordinates."""
    return (x / ELLIPSE_A, y / ELLIPSE_B)


def ground_ellipse_pixels(
    canvas: tuple[int, int],
    *,
    fill: float = 0.86,
    projection: GroundProjection | None = None,
) -> tuple[int, int, int, int]:
    """Pixel bbox of a ground circle centred on `canvas`, inset by `fill`."""
    p = projection or ACTIVE
    cw, ch = canvas
    max_w, max_h = cw * fill, ch * fill
    aspect = p.ellipse_ratio
    if max_w / max_h > aspect:
        eh = max_h
        ew = eh * aspect
    else:
        ew = max_w
        eh = ew / aspect
    left, top = (cw - ew) / 2.0, (ch - eh) / 2.0
    return (
        int(round(left)),
        int(round(top)),
        int(round(left + ew - 1)),
        int(round(top + eh - 1)),
    )


def synthesize_ground_ring(
    rgb: tuple[int, int, int],
    size: tuple[int, int] | None = None,
    *,
    fill: float = 0.86,
    projection: GroundProjection | None = None,
) -> Image.Image:
    """Thin IE-style selection ring: a true ground circle with soft falloff."""
    p = projection or ACTIVE
    size = size or p.ring_size
    cw, ch = size
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(out)
    box = ground_ellipse_pixels(size, fill=fill, projection=p)

    for inset, alpha in ((0, 55), (1, 140), (2, 255)):
        b = (box[0] + inset, box[1] + inset, box[2] - inset, box[3] - inset)
        if b[2] - b[0] < 4 or b[3] - b[1] < 2:
            break
        draw.ellipse(b, outline=(*rgb, alpha), width=1)

    rgba = np.array(out, dtype=np.float32)
    yy, xx = np.mgrid[0:ch, 0:cw]
    cx, cy = (cw - 1) / 2.0, (ch - 1) / 2.0
    ew, eh = box[2] - box[0] + 1, box[3] - box[1] + 1
    rx = max(1.0, (ew / 2.0) - 3.2)
    ry = max(1.0, (eh / 2.0) - 3.2)
    inside = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2 <= 1.0
    rgba[inside, 3] = 0
    rgba[inside, :3] = 0
    return Image.fromarray(rgba.astype(np.uint8), "RGBA")


# ---------------------------------------------------------------------------
# Dimetric box helper (procedural props / grayboxes)
# ---------------------------------------------------------------------------

def iso_box_points(
    cx: float,
    cy: float,
    w: int,
    d: int,
    h: float,
) -> dict[str, tuple[float, float]]:
    """Near-ground-centred box corners (image y-down, cy = near ground).

    `h` is screen-space height; callers holding a world height should pass
    `screen_height(world_h)`.
    """
    hx = w // 2
    hy = max(1, int(w * BOX_DEPTH_FRAC))
    dx = d // 2
    dy = max(1, int(d * BOX_DEPTH_FRAC))
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


# ---------------------------------------------------------------------------
# Self-check
# ---------------------------------------------------------------------------

def _self_check() -> None:
    # BG:EE target facts, independent of which camera is active.
    assert abs(BGEE.height_foreshorten - 0.661437827766) < 1e-9
    assert abs(BGEE.elevation_deg - 48.5903778907) < 1e-6
    assert abs(BGEE.ground_axis_deg - 36.8698976458) < 1e-6
    assert abs(BGEE.ellipse_ratio - ELLIPSE_A / ELLIPSE_B) < 1e-12
    assert BGEE.diamond[0] / ELLIPSE_A == BGEE.diamond[1] / ELLIPSE_B == 8
    assert BGEE.half_step == (64, 48)

    # Legacy camera, currently active.
    assert LEGACY_V2.diamond == (128, 64)
    assert LEGACY_V2.half_step == (64, 32)

    o = cell_to_authored(0, 0, origin_y=100.0)
    assert o == (DEFAULT_ORIGIN_X, 100.0)
    assert authored_to_cell(*o, origin_y=100.0) == (0, 0)
    p = cell_to_authored(3, 1, origin_y=100.0)
    assert authored_to_cell(*p, origin_y=100.0) == (3, 1)

    assert is_within_ellipse(0, 0)
    assert is_within_ellipse(16, 0)
    assert is_within_ellipse(0, 12)
    assert not is_within_ellipse(16.1, 0)
    assert searchmap_point(32, 24) == (2.0, 2.0)

    ne = axis_with_slope(100.0, projection=BGEE)
    assert abs(ne[1] / ne[0] - 0.75) < 1e-12
    nw = axis_with_slope(-100.0, projection=BGEE)
    assert abs(nw[1] / nw[0] + 0.75) < 1e-12

    print(f"ie_projection self-check OK (active camera: {ACTIVE.name})")


if __name__ == "__main__":
    _self_check()

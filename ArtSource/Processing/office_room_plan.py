"""Measured room plan for the detective-office shell.

Everything new that must sit inside the painted room (partition, cutaway wall,
prop placement) is expressed in the shell's own floor-plan basis instead of
screen-axis rectangles. That is the difference between architecture that reads
as part of the plate and slabs that read as graybox.

Basis (all values in shell plate pixels, y down):

    img = REAR + a * AXIS_NW + b * AXIS_NE

    a = 0 on the north-east wall, grows toward the west corner
    b = 0 on the north-west wall, grows toward the camera

These axes are a *measurement of the installed plate*, not a free parameter.
The V7 suite (`install_office_bgee_v07.py`) keeps the V5 floor diamond on the
Baldur's Gate: EE lock (slopes exactly ±0.75) and shortens only the plaster
band so the exterior door column is a 1930s office, not a warehouse. Axis
lengths come from the painted wall shoes (NW = window wall, NE = exterior-door
wall) intersected with the camera-near cutaway. The geometric near tip sits
in the black below the clipped floor; walkable `FLOOR_*` stops on the paint.
"""

from __future__ import annotations

from dataclasses import dataclass
import json
from pathlib import Path

_ROOT = Path(__file__).resolve().parents[2]
_V10_GEOMETRY_PATH = (
    _ROOT / "ArtSource/Generated/Office/BGEETavernV10/office_v10_geometry.json"
)
_V10_GEOMETRY = json.loads(_V10_GEOMETRY_PATH.read_text(encoding="utf-8"))
_ROOM = _V10_GEOMETRY["room"]
_DOOR = _V10_GEOMETRY["door"]
_PILLARS = _V10_GEOMETRY["pillars"]
_STAIRS = _V10_GEOMETRY["stairs"]

ART_W, ART_H = _V10_GEOMETRY["canvas"]

# The shipped Voss idle body is 200 opaque pixels on a 512px texture, displayed
# on a 180-point SpriteKit node. Convert that exact visible silhouette back into
# shell-plate pixels; door architecture uses this rendered figure, not the
# legacy 82-unit logical navigation/body contract.
#
# Keep DETECTIVE_DISPLAY_FRAME_H in step with
# OfficeInteriorScale.ActorDisplay.spriteDisplaySize. It was 232 while the
# shipped plates were generated, which put the baked doorway at 0.74x the
# rendered body — Voss did not fit through his own door. Regenerating the shell
# from this plan will widen the aperture to match.
ENVIRONMENT_SCALE = 0.395
DETECTIVE_TEXTURE_CANVAS_H = 512.0
DETECTIVE_TEXTURE_BODY_H = 200.0
DETECTIVE_DISPLAY_FRAME_H = 180.0
DETECTIVE_VISIBLE_WORLD_H = (
    DETECTIVE_TEXTURE_BODY_H / DETECTIVE_TEXTURE_CANVAS_H * DETECTIVE_DISPLAY_FRAME_H
)
BODY_PLATE_H = DETECTIVE_VISIBLE_WORLD_H / ENVIRONMENT_SCALE

# V10 keeps the tavern hall diamond instead of shrinking the V08 open-plan
# suite. Actor body scale does not shrink with the plate.
SUITE_PLATE_SCALE = 0.70

# Painted clear doorway on the NE wall (V7 proportion lock), measured from
# floor contact up to the lintel underside. This is the 198 px opening from
# the door-column table, not the older 290 px recess-inclusive read.
BAKED_DOORWAY_W, BAKED_DOORWAY_H = _DOOR["openingPixels"]
DOOR_OPENING_ASPECT = BAKED_DOORWAY_H / BAKED_DOORWAY_W
DOOR_OPENING_TO_DETECTIVE = BAKED_DOORWAY_H / BODY_PLATE_H

OLD_WALL_FACE_H = 369.0
# V7 wall face at the exterior door column: clear opening + short plaster
# band (198 + 73). Wainscot is a material band inside that face, not an
# addend — it was unchanged by the crown drop.
PLASTER_H = 73.0
WAINSCOT_H = 170.0
WALL_FACE_H = BAKED_DOORWAY_H + PLASTER_H
DOOR_LINTEL_CLEARANCE_H = WALL_FACE_H - BAKED_DOORWAY_H
WALL_RAISE_FROM_V06 = WALL_FACE_H - OLD_WALL_FACE_H

# FLOOR diamond, fitted to the painted floor itself (V7 plate).
#
# Earlier passes fitted this to wall shoes or to the camera-near silhouette and
# came out skewed — the shipped REAR sat 123 px west of where the two axes
# actually meet. This is a direct fit: classify pixels whose local structure
# tensor runs on a ground axis, take the largest such component touching the
# painting's bottom (that is the boards, and it follows them through the
# partition doorway into the waiting bay), then take the bounding parallelogram
# in the u = y - 0.75x / v = y + 0.75x basis. West and east land on the painted
# floor's own corners and both slopes are exactly +-0.75 by construction.
#
# The near tip sits at y 1810 against a painting clipped at 1657, and the rear
# tip above the wall crowns — both correct, and both what the module docstring
# has always described: the geometric diamond extends past the paint, walkable
# FLOOR_* stops on it.
REAR = tuple(_ROOM["rear"])
AXIS_NW = tuple(_ROOM["axisNW"])  # exact -0.75 BG:EE ground axis
AXIS_NE = tuple(_ROOM["axisNE"])  # exact +0.75 BG:EE ground axis

# Wall-top silhouettes stay parallel to the floor axes; intercepts put the wall
# base through REAR at WALL_FACE_H.
NW_TOP_SLOPE = AXIS_NW[1] / AXIS_NW[0]
NE_TOP_SLOPE = AXIS_NE[1] / AXIS_NE[0]
NW_TOP_INTERCEPT = REAR[1] - WALL_FACE_H - NW_TOP_SLOPE * REAR[0]
NE_TOP_INTERCEPT = REAR[1] - WALL_FACE_H - NE_TOP_SLOPE * REAR[0]

# Painted plate already is the room; floor diamond is the fitted unit square.
A_NEAR = 1.00
B_NEAR = 1.00
A_ROOM = 1.00
B_ROOM = 1.00

# Exterior doorway opening width along AXIS_NE.
# Derived from Voss and the clear-opening aspect so shell, partition, leaves,
# navigation and QA all share one character-relative source of truth.
EXTERIOR_DOOR_OPENING_B = BAKED_DOORWAY_W / abs(AXIS_NE[0])

# Hardware placement relative to the painted doorway (not the full detective body,
# which is taller than the tight-plate aperture).
DOOR_HANDLE_TO_OPENING = 0.45
DOOR_HANDLE_HEIGHT = BAKED_DOORWAY_H * DOOR_HANDLE_TO_OPENING
DOOR_HANDLE_TO_DETECTIVE = DOOR_HANDLE_HEIGHT / BODY_PLATE_H
DOOR_HANDLE_LATCH_INSET = BAKED_DOORWAY_W * 0.13
DOOR_HANDLE_DIAMETER = BAKED_DOORWAY_H * 0.04
# Painted hinge knuckles on both doorway jambs (partition + exterior recess).
DOOR_HINGE_KNUCKLE_HALF_H = BAKED_DOORWAY_H * 0.02
DOOR_HINGE_KNUCKLE_W = BAKED_DOORWAY_W * 0.04


def nw_wall_top(x: float) -> float:
    return NW_TOP_SLOPE * x + NW_TOP_INTERCEPT


def nw_wall_base(x: float) -> float:
    return nw_wall_top(x) + WALL_FACE_H


def ne_wall_top(x: float) -> float:
    return NE_TOP_SLOPE * x + NE_TOP_INTERCEPT


def ne_wall_base(x: float) -> float:
    return ne_wall_top(x) + WALL_FACE_H


def plan(a: float, b: float) -> tuple[float, float]:
    """Floor-plan coordinate -> plate pixel (y down)."""
    return (
        REAR[0] + a * AXIS_NW[0] + b * AXIS_NE[0],
        REAR[1] + a * AXIS_NW[1] + b * AXIS_NE[1],
    )


def unplan(x: float, y: float) -> tuple[float, float]:
    """Plate pixel -> floor-plan coordinate (inverse of `plan`)."""
    m00, m10 = AXIS_NW
    m01, m11 = AXIS_NE
    det = m00 * m11 - m01 * m10
    dx, dy = x - REAR[0], y - REAR[1]
    return ((dx * m11 - m01 * dy) / det, (m00 * dy - dx * m10) / det)


def authored(a: float, b: float) -> tuple[float, float]:
    """Floor-plan coordinate -> authored layout point (y up)."""
    x, y = plan(a, b)
    return (x, ART_H - y)


def authored_to_plan(x: float, y: float) -> tuple[float, float]:
    return unplan(x, ART_H - y)


# Plan-space lengths of the two axes, used to express clearances in pixels.
AXIS_NW_LEN = (AXIS_NW[0] ** 2 + AXIS_NW[1] ** 2) ** 0.5
AXIS_NE_LEN = (AXIS_NE[0] ** 2 + AXIS_NE[1] ** 2) ** 0.5


# Master wall thickness in plate pixels — measured to match the shell's thin
# top lip (the painted rear walls show almost no cap mass). Jambs, returns and
# foreground kerbs that must match the shell derive from this.
WALL_THICKNESS_PX = float(_ROOM["wallThickness"])

# Interior partition mass — thicker than shell lips so the waiting-room wall
# reads as a separate freestanding wall, not a flat continuation of the NE wall.
PARTITION_THICKNESS_PX = 34.0

# Visible top-cap depth as a fraction of wall thickness. Shell walls barely show
# a sawn top; the partition uses a deeper fraction so its crown reads in-game.
CAP_DEPTH_FRAC = 0.08
PARTITION_CAP_DEPTH_FRAC = 0.42


@dataclass(frozen=True)
class Partition:
    """Interior partition parallel to the north-east shell wall (AXIS_NE).

    Visibility sequence from the rear wall toward the camera:

        short full-height run → framed doorway → short full-height return
        → low cutaway continuation to B_ROOM

    a_line is the waiting-room face; a_line + thickness_a is the office face.
    Both faces are painted so the waiting bay is clearly enclosed.
    """

    # Waiting-room face on the V5 shoe-fitted diamond (painted partition).
    a_line: float = 0.457
    # Clear opening on the painted partition, both jambs at a = 0.426.
    b_door0: float = 0.338
    b_door1: float = 0.505
    # Short full-height return past the high-b jamb before the cutaway drop.
    b_return1: float = 0.538 + 0.030
    # Freestanding interior mass (plan units along AXIS_NW).
    thickness_a: float = PARTITION_THICKNESS_PX / AXIS_NW_LEN
    face_h: float = WALL_FACE_H
    # Chair-seat / desk-height cutaway for the long camera-near run.
    cutaway_face_h: float = 72.0
    wainscot_h: float = WAINSCOT_H
    # Interior opening height matches the detective-relative exterior doorway.
    door_h: float = BAKED_DOORWAY_H
    # Face casing thickness derived from the detective so it remains readable
    # without becoming a second oversized door shell.
    casing_h: float = round(BODY_PLATE_H * 0.14)
    overrun_b: float = 0.012

    def base(self, b: float) -> tuple[float, float]:
        return plan(self.a_line, b)

    @property
    def wall_junction(self) -> tuple[float, float]:
        return self.base(0.0)

    @property
    def near_end(self) -> tuple[float, float]:
        return self.base(B_ROOM)

    @property
    def door_mid_b(self) -> float:
        return 0.5 * (self.b_door0 + self.b_door1)


PARTITION = Partition()


@dataclass(frozen=True)
class ForegroundWall:
    """Short low cutaway returns on the camera-near floor edges.

    Not a continuous barrier: left corner, partition T-junction, and right
    corner only. Open centre stretches keep the desk and waiting room readable.
    """

    # Short lip only — still a readable return, not a wall.
    face_h: float = 24.0
    cap_h: float = 4.0
    thickness: float = WALL_THICKNESS_PX
    overrun: float = 0.010
    # Length of each short return along the near edges (plan units).
    return_len: float = 0.085

    @property
    def west_corner(self) -> tuple[float, float]:
        return plan(A_ROOM, 0.0)

    @property
    def near_corner(self) -> tuple[float, float]:
        return plan(A_ROOM, B_ROOM)

    @property
    def east_corner(self) -> tuple[float, float]:
        return plan(0.0, B_ROOM)


FOREGROUND = ForegroundWall()

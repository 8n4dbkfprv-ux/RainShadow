"""Measured room plan for the detective-office shell.

Everything new that must sit inside the painted room (partition, cutaway wall,
prop placement) is expressed in the shell's own floor-plan basis instead of
screen-axis rectangles. That is the difference between architecture that reads
as part of the plate and slabs that read as graybox.

Basis (all values in shell plate pixels, y down):

    img = REAR + a * AXIS_NW + b * AXIS_NE

    a = 0 on the north-east wall, grows toward the west corner
    b = 0 on the north-west wall, grows toward the camera

The two axis vectors were fitted from the shell's own wall silhouettes:
`AXIS_NW` slope -0.419, `AXIS_NE` slope +0.463. Wall bands measured off the
same fit: 227 px of plaster above the chair rail, 121 px of wainscot below it.
"""

from __future__ import annotations

from dataclasses import dataclass

ART_W, ART_H = 4096, 2304

# Fitted wall silhouettes: y_top = slope * x + intercept (plate pixels, y down).
NW_TOP_SLOPE, NW_TOP_INTERCEPT = -0.419, 867.0
NE_TOP_SLOPE, NE_TOP_INTERCEPT = 0.463, -1290.0

PLASTER_H = 227.0
WAINSCOT_H = 121.0
WALL_FACE_H = PLASTER_H + WAINSCOT_H  # 348

# Room corners in plate pixels. REAR is where the two fitted wall bases meet;
# the west/east corners are where those bases leave the painted plate.
REAR = (2446.0, 200.0)
AXIS_NW = (-2206.0, 923.0)  # rear corner -> west corner
AXIS_NE = (1650.0, 763.0)  # rear corner -> east corner

# Camera-near floor boundary, measured off the painted plate rather than assumed
# to be a = 1 / b = 1: the shell paints roughly a quarter of a wall-length more
# floor past the north-east wall's fitted base line. Anything that has to sit on
# the room's near edge (the cutaway wall, the partition's near end) belongs here,
# not on the unit square, or it lands in the middle of the floor.
A_NEAR = 1.00
B_NEAR = 1.12

# Design boundary of the room itself, tighter than the painted plate: the office
# reads far too large for a one-man agency at the plate's full extent, so the
# cutaway wall stands at B_ROOM and everything camera-near of it is painted out.
# Design near-boundary of the suite (matches the last shipped navigation write).
# Architecture void / cutaway walls stand here; furniture layout is unchanged.
A_ROOM = A_NEAR
B_ROOM = 0.58

# Character body height in plate pixels (Voss idle frame measured at runtime
# display size). The master scale reference for every asset in the room.
BODY_PLATE_H = 229.0

# Height of the doorway opening the shell painted into the north-east wall,
# measured from the wall's ground line to the top of the dark hall beyond.
BAKED_DOORWAY_H = 220.0

# Exterior doorway opening width along AXIS_NE, measured from the shell plate
# (~153 screen-x px of continuous dark hall ≈ 0.093 plan-b).
EXTERIOR_DOOR_OPENING_B = 0.093


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
# top lip (the painted rear walls show almost no cap mass). Partition, jambs,
# returns and foreground kerbs all derive from this.
WALL_THICKNESS_PX = 12.0

# Visible top-cap depth as a fraction of wall thickness. Shell walls barely show
# a sawn top; anything near 0.3+ reads as a thick graybox slab.
CAP_DEPTH_FRAC = 0.08


@dataclass(frozen=True)
class Partition:
    """Interior partition parallel to the north-east shell wall (AXIS_NE).

    Visibility sequence from the rear wall toward the camera:

        short full-height run → framed doorway → short full-height return
        → low cutaway continuation to B_ROOM
    """

    a_line: float = 0.36
    # Door sits close to the rear wall so the full-height mass stays short.
    # Opening width matches the shell's exterior doorway (~EXTERIOR_DOOR_OPENING_B).
    b_door0: float = 0.078
    b_door1: float = 0.078 + EXTERIOR_DOOR_OPENING_B
    # Short full-height return past the latch jamb before the cutaway drop.
    b_return1: float = 0.078 + EXTERIOR_DOOR_OPENING_B + 0.034
    # Shell-matched thickness (plan units along AXIS_NW).
    thickness_a: float = WALL_THICKNESS_PX / AXIS_NW_LEN
    face_h: float = WALL_FACE_H
    # Chair-seat / desk-height cutaway for the long camera-near run.
    cutaway_face_h: float = 72.0
    wainscot_h: float = WAINSCOT_H
    # Interior opening height near the shell's baked exterior doorway.
    door_h: float = 228.0
    casing_h: float = 16.0
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

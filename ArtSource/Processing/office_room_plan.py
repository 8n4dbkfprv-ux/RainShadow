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

# The shipped Voss idle body is 200 opaque pixels on a 512px texture, displayed
# on a 232-point SpriteKit node. Convert that exact visible silhouette back into
# shell-plate pixels; door architecture uses this rendered figure, not the
# legacy 82-unit logical navigation/body contract.
ENVIRONMENT_SCALE = 0.395
DETECTIVE_TEXTURE_CANVAS_H = 512.0
DETECTIVE_TEXTURE_BODY_H = 200.0
DETECTIVE_DISPLAY_FRAME_H = 232.0
DETECTIVE_VISIBLE_WORLD_H = (
    DETECTIVE_TEXTURE_BODY_H / DETECTIVE_TEXTURE_CANVAS_H * DETECTIVE_DISPLAY_FRAME_H
)
BODY_PLATE_H = DETECTIVE_VISIBLE_WORLD_H / ENVIRONMENT_SCALE

# Cramped-tight suite places the IG architecture at 0.80 of full-bleed so
# modular props (unchanged body scale) fill the floor. Wall face and baked
# doorway openings scale with the plate; actor body scale does not.
SUITE_PLATE_SCALE = 0.60

# Character-relative clear opening (V10.1), scaled to the painted plate.
DOOR_OPENING_TO_DETECTIVE = 1.70
DOOR_OPENING_ASPECT = 2.20
BAKED_DOORWAY_H = float(
    round(BODY_PLATE_H * DOOR_OPENING_TO_DETECTIVE * SUITE_PLATE_SCALE)
)
BAKED_DOORWAY_W = BAKED_DOORWAY_H / DOOR_OPENING_ASPECT

OLD_WALL_FACE_H = 348.0
WALL_FACE_H = 505.0 * SUITE_PLATE_SCALE
DOOR_LINTEL_CLEARANCE_H = WALL_FACE_H - BAKED_DOORWAY_H
WAINSCOT_H = 121.0 * SUITE_PLATE_SCALE
PLASTER_H = WALL_FACE_H - WAINSCOT_H
WALL_RAISE_FROM_V06 = WALL_FACE_H - OLD_WALL_FACE_H

# Room corners for the shipped tight plate (cramped v03 placed at 0.60 on the
# 4096×2304 canvas). REAR is where the two wall runs meet.
REAR = (1936.0, 462.0)
AXIS_NW = (-679.0, 442.0)  # rear corner -> west corner
AXIS_NE = (897.0, 534.0)  # rear corner -> east corner

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

# Character-relative hardware placement. Processing normalizes both leaf knobs
# to this height above the threshold and inset from the latch edge.
DOOR_HANDLE_TO_DETECTIVE = 0.575
DOOR_HANDLE_HEIGHT = BODY_PLATE_H * DOOR_HANDLE_TO_DETECTIVE
DOOR_HANDLE_LATCH_INSET = BAKED_DOORWAY_W * 0.13
DOOR_HANDLE_DIAMETER = BODY_PLATE_H * 0.065
# Painted hinge knuckles on both doorway jambs (partition + exterior recess).
DOOR_HINGE_KNUCKLE_HALF_H = BODY_PLATE_H * 0.016
DOOR_HINGE_KNUCKLE_W = BODY_PLATE_H * 0.018


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
WALL_THICKNESS_PX = 12.0

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

    a_line: float = 0.36
    # Door sits close to the rear wall so the full-height mass stays short.
    # Opening width matches the shell's exterior doorway (~EXTERIOR_DOOR_OPENING_B).
    b_door0: float = 0.078
    b_door1: float = 0.078 + EXTERIOR_DOOR_OPENING_B
    # Short full-height return past the latch jamb before the cutaway drop.
    b_return1: float = 0.078 + EXTERIOR_DOOR_OPENING_B + 0.034
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

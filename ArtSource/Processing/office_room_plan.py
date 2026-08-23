"""Registered room plan for the V17 AR0809-exact detective-office shell.

Everything registered against the painted room (cutaway boundary, fireplace,
windows, door, and prop placement) is expressed in the shell's own floor-plan
basis instead of screen-axis rectangles.

Basis (all values in shell plate pixels, y down):

    img = REAR + a * AXIS_NW + b * AXIS_NE + a * b * CROSS_TERM

    a = 0 on the north-east wall, grows toward the west corner
    b = 0 on the north-west wall, grows toward the camera

The V17 ImageGen rebuild is the floor, wall, window and fireplace authority.
The V11 manifest remains only the environment-scale and exterior-door-state
art authority.
"""

from __future__ import annotations

from dataclasses import dataclass
import json
from pathlib import Path

_ROOT = Path(__file__).resolve().parents[2]
_V11_GEOMETRY_PATH = (
    _ROOT / "ArtSource/Generated/Office/BGEE1950sV11/office_v11_geometry.json"
)
_V11_GEOMETRY = json.loads(_V11_GEOMETRY_PATH.read_text(encoding="utf-8"))
_V17_METRICS_PATH = (
    _ROOT
    / "ArtSource/Generated/Office/BGEEReferenceV17/office_reference_rebuild_metrics_v17.json"
)
_V17_METRICS = json.loads(_V17_METRICS_PATH.read_text(encoding="utf-8"))
_V17_TARGET_PLANES = _V17_METRICS["registration"]["targetPlanes"]
_ROOM = _V11_GEOMETRY["room"]
_DOOR = _V11_GEOMETRY["door"]
_V17_WINDOWS_BY_ID = {window["id"]: window for window in _V17_METRICS["windows"]}
_WINDOWS = []
for _legacy_window in _V11_GEOMETRY["windows"]:
    _registered_window = _V17_WINDOWS_BY_ID[_legacy_window["id"]]
    _WINDOWS.append(
        {
            **_legacy_window,
            "targetAperturePolygon": _registered_window["aperture"],
            "targetGlassPolygons": _registered_window["glass"],
        }
    )
_FIREPLACE = {
    **_V11_GEOMETRY["fireplace"],
    **_V17_METRICS["fireplace"]["collisionAndCoverAuthority"],
    "facadeHeight": _V17_METRICS["fireplace"]["visualScaleLock"][
        "plateFixtureHeightPixels"
    ],
}
_PILLARS = _V11_GEOMETRY.get("pillars", [])
_STAIRS = _V11_GEOMETRY.get("stairs")

ART_W, ART_H = _V11_GEOMETRY["canvas"]

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
ENVIRONMENT_SCALE = float(_V11_GEOMETRY["environmentScale"])
DETECTIVE_TEXTURE_CANVAS_H = 512.0
DETECTIVE_TEXTURE_BODY_H = 200.0
DETECTIVE_DISPLAY_FRAME_H = 180.0
DETECTIVE_VISIBLE_WORLD_H = (
    DETECTIVE_TEXTURE_BODY_H / DETECTIVE_TEXTURE_CANVAS_H * DETECTIVE_DISPLAY_FRAME_H
)
BODY_PLATE_H = DETECTIVE_VISIBLE_WORLD_H / ENVIRONMENT_SCALE

# V11 is authored directly at the registered 4096x2304 plate size.
SUITE_PLATE_SCALE = 1.0

# Compatibility aliases for callers that historically treated the exterior
# leaf as an upright opening.  V11's registered visual is instead the exact
# edge-on screenshot sliver: thickness and hinge-to-free-end length.
BAKED_DOORWAY_W = float(_DOOR["targetThickness"])
BAKED_DOORWAY_H = float(_DOOR["targetLength"])
DOOR_OPENING_ASPECT = BAKED_DOORWAY_H / BAKED_DOORWAY_W
DOOR_OPENING_TO_DETECTIVE = BAKED_DOORWAY_H / BODY_PLATE_H

OLD_WALL_FACE_H = 271.0
WALL_FACE_H = float(
    _V17_METRICS["walls"]["visualScaleLock"]["plateRearHeightPixels"]
)
PLASTER_H = WALL_FACE_H
WAINSCOT_H = 0.0
DOOR_LINTEL_CLEARANCE_H = 0.0
WALL_RAISE_FROM_V06 = WALL_FACE_H - OLD_WALL_FACE_H

# V17's painted floor is itself the navigation basis. AR0809 has a deliberate
# four-corner taper, so use a bilinear quadrilateral rather than silently
# replacing its camera-near corner with an affine one.
_V17_PLANES = _V17_TARGET_PLANES
_V17_FLOOR = tuple(
    tuple(float(v) for v in point) for point in _V17_PLANES["floor"]
)
REAR = _V17_FLOOR[0]
REAR_FLOOR = REAR
AXIS_NW = (
    _V17_FLOOR[1][0] - REAR[0],
    _V17_FLOOR[1][1] - REAR[1],
)
AXIS_NE = (
    _V17_FLOOR[3][0] - REAR[0],
    _V17_FLOOR[3][1] - REAR[1],
)
NEAR = _V17_FLOOR[2]
CROSS_TERM = (
    NEAR[0] - _V17_FLOOR[1][0] - _V17_FLOOR[3][0] + REAR[0],
    NEAR[1] - _V17_FLOOR[1][1] - _V17_FLOOR[3][1] + REAR[1],
)
_NW_WALL = tuple(tuple(float(v) for v in point) for point in _V17_PLANES["NW"])
_NE_WALL = tuple(tuple(float(v) for v in point) for point in _V17_PLANES["NE"])


def _line_y(
    x: float,
    start: tuple[float, float],
    end: tuple[float, float],
) -> float:
    t = (x - start[0]) / (end[0] - start[0])
    return start[1] + t * (end[1] - start[1])

# Painted plate already is the room; floor diamond is the fitted unit square.
A_NEAR = 1.00
B_NEAR = 1.00
A_ROOM = 1.00
B_ROOM = 1.00

# Translate the retained V11 leaf onto V17's exact camera-near floor edge
# without rotating or resampling the door-state art.
_V11_DOOR_TARGET_HINGE = tuple(float(v) for v in _DOOR["targetHinge"])
_V11_DOOR_TARGET_FREE_END = tuple(float(v) for v in _DOOR["targetFreeEnd"])
_V17_NEAR_EDGE_START = tuple(float(v) for v in _V17_PLANES["floor"][2])
_V17_NEAR_EDGE_END = tuple(float(v) for v in _V17_PLANES["floor"][3])


def _v17_near_edge_y(x: float) -> float:
    t = (x - _V17_NEAR_EDGE_START[0]) / (
        _V17_NEAR_EDGE_END[0] - _V17_NEAR_EDGE_START[0]
    )
    return _V17_NEAR_EDGE_START[1] + t * (
        _V17_NEAR_EDGE_END[1] - _V17_NEAR_EDGE_START[1]
    )


# Seat the V11 leaf just outside the painted/fog diamond, matching a BG:EE
# near-edge door: a timber sliver in the black, hugging the cutaway. Uniform
# Y translation cannot put both ends on the tapered near-east edge (leaf 36°,
# cutaway 44°). 15 px left the free end on the boards; 115 px opened a gap
# in the void. 50 px puts both ends past b=1 while the centroid stays ~60 px
# camera-near of the edge.
DOOR_V17_EDGE_RASTER_MARGIN_Y = 100.0
DOOR_V17_EDGE_TRANSLATION_Y = sum(
    _v17_near_edge_y(point[0]) - point[1]
    for point in (_V11_DOOR_TARGET_HINGE, _V11_DOOR_TARGET_FREE_END)
) / 2.0 + DOOR_V17_EDGE_RASTER_MARGIN_Y
DOOR_TARGET_HINGE = (
    _V11_DOOR_TARGET_HINGE[0],
    _V11_DOOR_TARGET_HINGE[1] + DOOR_V17_EDGE_TRANSLATION_Y,
)
DOOR_TARGET_FREE_END = (
    _V11_DOOR_TARGET_FREE_END[0],
    _V11_DOOR_TARGET_FREE_END[1] + DOOR_V17_EDGE_TRANSLATION_Y,
)
_V11_DOOR_TARGET_BBOX = tuple(float(v) for v in _DOOR["targetBBox"])
DOOR_TARGET_BBOX = (
    _V11_DOOR_TARGET_BBOX[0],
    _V11_DOOR_TARGET_BBOX[1] + DOOR_V17_EDGE_TRANSLATION_Y,
    _V11_DOOR_TARGET_BBOX[2],
    _V11_DOOR_TARGET_BBOX[3] + DOOR_V17_EDGE_TRANSLATION_Y,
)
DOOR_TARGET_LENGTH = float(_DOOR["targetLength"])
DOOR_TARGET_THICKNESS = float(_DOOR["targetThickness"])
DOOR_TARGET_ANGLE_DEGREES = float(_DOOR["targetAngleDegrees"])
DOOR_LIVE_CANVAS = tuple(int(v) for v in _DOOR["liveCanvas"])
DOOR_HINGE_PIXELS = tuple(float(v) for v in _DOOR["hingePixels"])
DOOR_ANCHOR = tuple(float(v) for v in _DOOR["anchor"])
DOOR_STATE_LENGTH_RATIOS = {
    key: float(value) for key, value in _DOOR["stateLengthRatios"].items()
}

# Door span along the camera-near b=1 edge.  The exact plan endpoints are
# derived after `unplan` is declared; this compatibility value is initialised
# here and replaced below.
EXTERIOR_DOOR_OPENING_B = DOOR_TARGET_THICKNESS / abs(AXIS_NE[0])

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
    return _line_y(x, _NW_WALL[0], _NW_WALL[1])


def nw_wall_base(x: float) -> float:
    return _line_y(x, _NW_WALL[3], _NW_WALL[2])


def ne_wall_top(x: float) -> float:
    return _line_y(x, _NE_WALL[0], _NE_WALL[1])


def ne_wall_base(x: float) -> float:
    return _line_y(x, _NE_WALL[3], _NE_WALL[2])


def plan(a: float, b: float) -> tuple[float, float]:
    """Floor-plan coordinate -> plate pixel (y down)."""
    return (
        REAR[0] + a * AXIS_NW[0] + b * AXIS_NE[0] + a * b * CROSS_TERM[0],
        REAR[1] + a * AXIS_NW[1] + b * AXIS_NE[1] + a * b * CROSS_TERM[1],
    )


def unplan(x: float, y: float) -> tuple[float, float]:
    """Plate pixel -> floor-plan coordinate (Newton inverse of `plan`)."""
    m00, m10 = AXIS_NW
    m01, m11 = AXIS_NE
    det = m00 * m11 - m01 * m10
    dx, dy = x - REAR[0], y - REAR[1]
    a = (dx * m11 - m01 * dy) / det
    b = (m00 * dy - dx * m10) / det
    for _ in range(12):
        px, py = plan(a, b)
        error_x, error_y = px - x, py - y
        if max(abs(error_x), abs(error_y)) <= 1e-8:
            break
        jac_a = (
            AXIS_NW[0] + b * CROSS_TERM[0],
            AXIS_NW[1] + b * CROSS_TERM[1],
        )
        jac_b = (
            AXIS_NE[0] + a * CROSS_TERM[0],
            AXIS_NE[1] + a * CROSS_TERM[1],
        )
        jac_det = jac_a[0] * jac_b[1] - jac_b[0] * jac_a[1]
        if abs(jac_det) <= 1e-12:
            raise RuntimeError("V17 floor quadrilateral has a singular inverse")
        delta_a = (error_x * jac_b[1] - jac_b[0] * error_y) / jac_det
        delta_b = (jac_a[0] * error_y - error_x * jac_a[1]) / jac_det
        a -= delta_a
        b -= delta_b
    return a, b


def authored(a: float, b: float) -> tuple[float, float]:
    """Floor-plan coordinate -> authored layout point (y up)."""
    x, y = plan(a, b)
    return (x, ART_H - y)


def authored_to_plan(x: float, y: float) -> tuple[float, float]:
    return unplan(x, ART_H - y)


def plate_polygon_to_authored(
    polygon: list[list[float]] | tuple[tuple[float, float], ...],
) -> tuple[tuple[float, float], ...]:
    """Convert a manifest y-down polygon to authored y-up coordinates."""
    return tuple((float(x), ART_H - float(y)) for x, y in polygon)


def polygon_bounds(
    polygon: tuple[tuple[float, float], ...],
) -> tuple[float, float, float, float]:
    xs = [point[0] for point in polygon]
    ys = [point[1] for point in polygon]
    return min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys)


WINDOWS_BY_ID = {window["id"]: window for window in _WINDOWS}
NEAR_WINDOW = next(
    window for window in _WINDOWS if "office.window" in window.get("role", "")
)
FAR_WINDOW = next(window for window in _WINDOWS if window is not NEAR_WINDOW)
NEAR_WINDOW_APERTURE = plate_polygon_to_authored(
    NEAR_WINDOW["targetAperturePolygon"]
)
FAR_WINDOW_APERTURE = plate_polygon_to_authored(
    FAR_WINDOW["targetAperturePolygon"]
)
WINDOW_GLASS_POLYGONS = tuple(
    plate_polygon_to_authored(polygon)
    for window in _WINDOWS
    for polygon in window["targetGlassPolygons"]
)
FIREPLACE_OBSTACLE_POLYGON = plate_polygon_to_authored(
    _FIREPLACE["targetObstaclePolygon"]
)
FIREPLACE_COVER_POLYGON = plate_polygon_to_authored(
    _FIREPLACE["targetCoverPolygon"]
)

DOOR_HINGE_AUTHORED = (DOOR_TARGET_HINGE[0], ART_H - DOOR_TARGET_HINGE[1])
DOOR_FREE_END_AUTHORED = (
    DOOR_TARGET_FREE_END[0],
    ART_H - DOOR_TARGET_FREE_END[1],
)
DOOR_HINGE_PLAN = unplan(*DOOR_TARGET_HINGE)
DOOR_FREE_END_PLAN = unplan(*DOOR_TARGET_FREE_END)
DOOR_CENTER_PLAN = (
    (DOOR_HINGE_PLAN[0] + DOOR_FREE_END_PLAN[0]) * 0.5,
    (DOOR_HINGE_PLAN[1] + DOOR_FREE_END_PLAN[1]) * 0.5,
)
DOOR_SPAN_A = tuple(sorted((DOOR_HINGE_PLAN[0], DOOR_FREE_END_PLAN[0])))


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

    # Retired waiting-room face compatibility value.
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

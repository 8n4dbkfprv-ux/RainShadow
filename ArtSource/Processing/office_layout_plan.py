"""Single source of truth for the office suite layout.

Placements are authored in the shell's floor-plan basis (see `office_room_plan`)
so furniture sits on real wall lines instead of screen-space guesses:

    a  distance from the north-east wall (0 = on that wall, grows to the west)
    b  distance from the north-west wall (0 = on that wall, grows toward camera)

Prop display scales are expressed as multiples of the shipped detective's
rendered visible body, which is the master scale reference. Run this module to
emit the Swift layout and a navigation report:

    python3 ArtSource/Processing/office_layout_plan.py           # report
    python3 ArtSource/Processing/office_layout_plan.py --write    # patch Swift
"""

from __future__ import annotations

import math
import sys
from collections import deque
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path

import numpy as np
from PIL import Image

import office_room_plan as rp
import ie_projection as ie

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "RainShadow Shared/Resources/Art/Props/Office"
SWIFT = ROOT / "RainShadow Shared/Gameplay/Navigation/OfficeNavigationLayout.swift"

BODY = rp.BODY_PLATE_H
ENV = rp.ENVIRONMENT_SCALE
# The entrance edge is a separately rendered sprite, not part of the plate.
# Its native V12 master is intentionally smaller than the 0.395 environment
# scale so it matches the slim door sliver in the approved room reference.
DOOR_DISPLAY_SCALE = 0.28

# Metre -> plan units on each exact V14 floor axis (~200 plate px per metre).
# The painted floor and navigation basis are now the same parallelogram.
PX_PER_M = 200.0
_REF_AXIS_NW_X = abs(rp.AXIS_NW[0])
_REF_AXIS_NE_X = abs(rp.AXIS_NE[0])
M_PER_A = PX_PER_M / _REF_AXIS_NW_X
M_PER_B = PX_PER_M / _REF_AXIS_NE_X


class PlacementKind(str, Enum):
    FLOOR = "floor"
    WALL = "wall"
    SURFACE = "surface"


class Wall(str, Enum):
    NORTH_WEST = "northWest"
    NORTH_EAST = "northEast"


# One painted-source pixel of tolerance keeps antialiasing on the room side of
# the wall seam.  The actual stand-off comes from half the prop depth.
WALL_SEAM_CLEARANCE = 1.0 / min(_REF_AXIS_NW_X, _REF_AXIS_NE_X)


def wall_floor_point(wall: Wall, along: float) -> tuple[float, float]:
    """Plan coordinate on the painted wall/floor seam.

    V14's room basis begins exactly at the painted rear floor seam. Resolve the
    registered constant-height wall base, then offset into the floor.
    """
    if wall is Wall.NORTH_WEST:
        x, _ = rp.plan(along, 0.0)
        return rp.unplan(x, rp.nw_wall_base(x))
    x, _ = rp.plan(0.0, along)
    return rp.unplan(x, rp.ne_wall_base(x))


def wall_along_at_x(wall: Wall, plate_x: float) -> float:
    """Wall-axis parameter whose painted contact has the requested plate x."""
    if wall is Wall.NORTH_WEST:
        return (plate_x - rp.REAR[0]) / rp.AXIS_NW[0]
    return (plate_x - rp.REAR[0]) / rp.AXIS_NE[0]


def wall_flush(wall: Wall, along: float, depth_m: float) -> tuple[float, float]:
    """Floor anchor whose rear footprint edge contacts the painted wall."""
    a, b = wall_floor_point(wall, along)
    if wall is Wall.NORTH_WEST:
        return (a, b + depth_m * M_PER_B * 0.5 + WALL_SEAM_CLEARANCE)
    return (a + depth_m * M_PER_A * 0.5 + WALL_SEAM_CLEARANCE, b)

@dataclass
class Prop:
    key: str  # Swift AuthoredPlacement name
    art: str | None
    a: float
    b: float
    body: float | None = None  # rendered height as a multiple of the character
    # Explicit extents along the room-plan axes (a, b), never screen width/depth.
    plan_extents_m: tuple[float, float] = (0.6, 0.6)
    obstacle: bool = True
    placement: PlacementKind = PlacementKind.FLOOR
    wall: Wall | None = None
    support: str | None = None
    # Authored y-up offset from the parent's floor anchor to its usable surface.
    support_offset: tuple[float, float] = (0.0, 0.0)
    note: str = ""
    _content: tuple[float, float] = field(default=(0.0, 0.0), init=False)

    def measure(self) -> None:
        if self.art is None:
            return
        path = ART / f"{self.art}.png"
        if not path.exists():
            raise FileNotFoundError(path)
        alpha = np.asarray(Image.open(path).convert("RGBA"))[:, :, 3]
        ys, xs = np.where(alpha > 16)
        self._content = (float(xs.max() - xs.min() + 1), float(ys.max() - ys.min() + 1))

    @property
    def plate_size(self) -> tuple[float, float]:
        w, h = self._content
        if self.body is None or h == 0:
            return (w, h)
        plate_h = self.body * BODY
        return (w * plate_h / h, plate_h)

    @property
    def display_scale(self) -> float:
        """SpriteKit display scale: world units per source pixel."""
        _, h = self._content
        if self.body is None or h == 0:
            return ENV
        return self.body * BODY * ENV / h

    @property
    def authored(self) -> tuple[float, float]:
        if self.placement is PlacementKind.SURFACE:
            if self.support is None:
                raise ValueError(f"{self.key}: surface placement needs a support")
            parent = PROP_BY_KEY[self.support]
            px, py = parent.authored
            return (px + self.support_offset[0], py + self.support_offset[1])
        return rp.authored(self.a, self.b)

    @property
    def obstacle_rect(self) -> tuple[float, float, float, float]:
        """Authored AABB around the prop's floor footprint."""
        da = self.plan_extents_m[0] * M_PER_A * 0.5
        db = self.plan_extents_m[1] * M_PER_B * 0.5
        corners = [
            rp.authored(self.a + sa * da, self.b + sb * db)
            for sa in (-1, 1)
            for sb in (-1, 1)
        ]
        xs = [c[0] for c in corners]
        ys = [c[1] for c in corners]
        # The AABB of a dimetric diamond over-blocks; pull it back to the
        # inscribed box so a prop never eats its own approach cell.
        cx, cy = sum(xs) / 4, sum(ys) / 4
        w = (max(xs) - min(xs)) * 0.72
        h = (max(ys) - min(ys)) * 0.72
        return (cx - w / 2, cy - h / 2, w, h)


# --------------------------------------------------------------- the layout

# Fixed V14 features on the floor-plane axes.  The two windows and lit
# windows and radiators are baked; only registered window masks remain live.
# Navigation threshold on the walkable side of the cutaway. Independent of
# the leaf's void-side visual snap (DOOR_HINGE_AUTHORED).
EXTERIOR_DOOR = (0.533, 1.00)


def _polygon_centre(
    polygon: tuple[tuple[float, float], ...],
) -> tuple[float, float]:
    return (
        sum(point[0] for point in polygon) / len(polygon),
        sum(point[1] for point in polygon) / len(polygon),
    )


_near_window_centre = _polygon_centre(rp.NEAR_WINDOW_APERTURE)
WINDOW_A = rp.authored_to_plan(*_near_window_centre)[0]

# Visual door registration comes directly from the shared V11 manifest.
# Its edge-on leaf remains separate from the plate and threshold collision.
# Positions below use plate image coordinates (y down).
SHIPPING_EXTERIOR_OPENING_SIZE = (
    rp.DOOR_TARGET_THICKNESS,
    rp.DOOR_TARGET_LENGTH,
)
SHIPPING_EXTERIOR_THRESHOLD = rp.plan(*EXTERIOR_DOOR)
_door_x0, _door_y0, _door_x1, _door_y1 = rp.DOOR_TARGET_BBOX
DOOR_VISUAL_BOUNDS = (
    _door_x0,
    rp.ART_H - _door_y1,
    _door_x1 - _door_x0,
    _door_y1 - _door_y0,
)
# Every prop belongs to one coherent cluster. Wall contacts are computed from
# the explicit normal-axis extent; surface objects inherit a named support.
PROPS: list[Prop] = [
    # ---- records: packed into the tall rear bays. AR0809 tapers the wall
    # faces to points, and the two windows occupy a≈0.30–0.75 of the NW wall.
    Prop("safe", "office_safe",
         *wall_flush(Wall.NORTH_WEST, 0.070, 0.60), 0.34,
         (0.60, 0.60), wall=Wall.NORTH_WEST, note="records run, far end"),
    Prop("filingCabinetB", "office_filing_cabinet",
         *wall_flush(Wall.NORTH_EAST, 0.155, 0.62), 1.14,
         (0.62, 0.50), wall=Wall.NORTH_EAST,
         note="NE rear bay"),
    Prop("filingCabinet", "office_filing_cabinet_open",
         *wall_flush(Wall.NORTH_EAST, 0.255, 0.50), 1.14,
         (0.50, 0.62), wall=Wall.NORTH_EAST,
         note="drawer half open; NE rear bay"),
    Prop("bookshelf", "office_bookshelf",
         *wall_flush(Wall.NORTH_WEST, 0.185, 0.35), 1.34,
         (1.00, 0.35), wall=Wall.NORTH_WEST),
    Prop("archiveBoxOnCabinet", "office_archive_box_b", 0.245, 0.0, 0.36,
         obstacle=False, placement=PlacementKind.SURFACE, support="filingCabinetB",
         support_offset=(-10.0, 157.0), note="opaque base registered to cabinet top"),
    Prop("archiveStackOnCabinet", "office_archive_stack", 0.335, 0.0, 0.44,
         obstacle=False, placement=PlacementKind.SURFACE, support="filingCabinet",
         support_offset=(12.0, 155.0), note="opaque base registered to cabinet top"),
    Prop("archiveBoxA", "office_archive_box_a", 0.820, 0.250, 0.40,
         (0.50, 0.45), note="records overflow stack"),
    # V18's two period radiators are architecture pixels on the NW wall. They
    # intentionally have no prop, texture registration or separate obstacle.
    # ---- personal corner: furniture against the NE wall, away from the door.
    Prop("personalSideboard", "office_personal_sideboard",
         *wall_flush(Wall.NORTH_EAST, 0.550, 0.50),
         0.625, (0.50, 1.00),
         wall=Wall.NORTH_EAST),
    Prop("personalWashbasin", "office_personal_washbasin",
         *wall_flush(Wall.NORTH_EAST, 0.920, 0.50), 0.41, (0.50, 0.70),
         obstacle=False, wall=Wall.NORTH_EAST,
         note="retired domestic fixture; placement retained for source lineage"),
    Prop("personalFan", "office_personal_fan",
         *wall_flush(Wall.NORTH_EAST, 0.330, 0.50),
         0.68, (0.50, 0.50),
         wall=Wall.NORTH_EAST,
         note="NE wall personal corner"),
    Prop("personalBottle", "office_hidden_bottle", 0.0, 0.0, 0.22,
         obstacle=False, placement=PlacementKind.SURFACE, support="personalSideboard",
         support_offset=(-16.0, 110.0), note="opaque base registered to sideboard top"),
    Prop("personalGlass", "office_personal_glass", 0.0, 0.0, 0.10,
         obstacle=False, placement=PlacementKind.SURFACE, support="personalSideboard",
         support_offset=(12.0, 107.0), note="opaque base registered to sideboard top"),
    # ---- separated desk station. Chair is camera-near of the desk (higher b);
    # visitor chairs sit on the rear/far side so they do not share the egress aisle.
    Prop("deskEnsemble", "office_desk_bare", 0.480, 0.380, 0.99, (1.70, 0.90)),
    # Camera-near of the desk, same `a` as the kneehole, so the rear-facing
    # chair sits at the writing-side rather than out in the room.
    Prop("deskChair", "office_visitor_armchair", 0.450, 0.700, 0.82,
         (0.50, 0.50), obstacle=True, note="Voss seat at camera-near kneehole"),
    Prop("visitorArmchair", "office_visitor_armchair", 0.260, 0.220, 0.79,
         (0.65, 0.65)),
    Prop("visitorArmchairB", "office_visitor_armchair", 0.680, 0.200, 0.76,
         (0.65, 0.65)),
    Prop("wastebasket", "office_wastebasket", 0.730, 0.420, 0.32, (0.40, 0.40)),
    # ---- waiting nook beside the entrance, clear of its exact path.
    Prop("coatRack", "office_coat_rack", 0.900, 0.620, 0.88, (0.60, 0.60)),
    Prop("umbrellaStand", "office_umbrella_stand", 0.940, 0.720, 0.28,
         (0.35, 0.35)),
    Prop("waitingChairA", "office_waiting_chair_a", 0.700, 0.860, 0.60,
         (0.55, 0.55)),
    Prop("waitingTable", "office_waiting_table", 0.820, 0.860, 0.40,
         (0.55, 0.55)),
    Prop("waitingChairB", "office_waiting_chair_b", 0.940, 0.860, 0.58,
         (0.55, 0.55)),
    Prop("newspaper", "office_newspaper", 0.0, 0.0, 0.10,
         obstacle=False, placement=PlacementKind.SURFACE, support="waitingTable",
         support_offset=(-10.0, 70.0), note="opaque base registered to waiting-table top"),
    Prop("waitingAshtray", "office_waiting_ashtray", 0.0, 0.0, 0.07,
         obstacle=False, placement=PlacementKind.SURFACE, support="waitingTable",
         support_offset=(12.0, 70.0), note="opaque base registered to waiting-table top"),
]

PROP_BY_KEY = {p.key: p for p in PROPS}


def exterior_door_threshold_authored() -> tuple[float, float]:
    """Exact centre of the sole cutaway threshold."""
    return rp.authored(*EXTERIOR_DOOR)


def window_anchor_authored() -> tuple[float, float]:
    """Exact centre of the camera-nearer baked aperture (authored y-up)."""
    return _near_window_centre


def camera_authored() -> tuple[float, float]:
    """Camera centred on the V14 desk island and retained 13% play scale."""
    return rp.authored(0.520, 0.470)


# Worn burgundy rug under the central desk island.
RUG = (0.500, 0.525)
RUG_BODY = 2.2
RUG_FACTOR = 0.62

@dataclass(frozen=True)
class WallMount:
    wall: Wall
    a: float
    b: float
    height: float

    @property
    def plate(self) -> tuple[float, float]:
        if self.wall is Wall.NORTH_WEST:
            x, _ = rp.plan(self.a, 0.0)
            return (x, rp.nw_wall_base(x) - self.height)
        x, _ = rp.plan(0.0, self.b)
        return (x, rp.ne_wall_base(x) - self.height)


# Mounted fixtures use the measured V15 wall face. AR0809 tapers that face to
# a point at the west tip, so every mount stays in the tall rear bay (a<0.28)
# and above the low records units, never in a window aperture.
WALL_ART: dict[str, WallMount] = {
    "wallPhotos": WallMount(
        Wall.NORTH_WEST, 0.085, 0.0, 150.0
    ),
    "framedLicence": WallMount(
        Wall.NORTH_WEST, 0.175, 0.0, 155.0
    ),
    "caseBoard": WallMount(
        Wall.NORTH_WEST, 0.230, 0.0, 118.0
    ),
    "wallCityMap": WallMount(
        Wall.NORTH_EAST, 0.105, 0.0, 74.0
    ),
}

FLOOR_DECALS = {
    "windowSpill": rp.plan(WINDOW_A, 0.13),
    "blindStripes": rp.plan(WINDOW_A - 0.04, 0.20),
    "hallwayLight": rp.plan(EXTERIOR_DOOR[0], 1.018),
    "floorTrashA": rp.plan(0.740, 0.260),
    "floorTrashB": rp.plan(0.900, 0.110),
    "entranceRunner": rp.plan(EXTERIOR_DOOR[0], 0.830),
    "lampPool": None,  # follows the desk
}

APPROACH = {
    "office.window": (0.600, 0.260),
    # The exact centre of the adjacent runtime cell stays clear of the desk
    # footprint after the V15 floor-basis refit; the former b=.455 point was
    # geometrically clear but rounded into the isolated cell under its apron.
    "office.desk": (0.320, 0.320),
    "office.phone": (0.320, 0.320),
    "office.files": (0.160, 0.220),
    # Exact planner/runtime cell immediately inside the V15-refitted threshold.
    # It remains reachable with the leaf closed while the outside doorway cell
    # stays sealed until the door state opens.
    "office.door": (EXTERIOR_DOOR[0], 0.700),
}

# Chair-side egress is part of the V15 seat assembly. The runtime's 47.4-world
# seated offset equals 120 authored units, so animation settles exactly from
# this walkable root back onto the chair.
ACTOR_START_OFFSET_Y = -120.0  # retained for source compatibility


def actor_start_authored() -> tuple[float, float]:
    """Chair-side stand root: same column as the empty chair, 120 px camera-near."""
    x, y = rp.authored(PROP_BY_KEY["deskChair"].a, PROP_BY_KEY["deskChair"].b)
    return (x, y + ACTOR_START_OFFSET_Y)


ACTOR_START_PLAN = rp.authored_to_plan(*actor_start_authored())


# --------------------------------------------------------------- architecture


# Keep the nav diamond locked to the floor plane as REAR moves.
# 597.1 is the pre-correction plaster/wainscot rail y-down (legacy reference).
_LEGACY_RAIL_Y = 597.1
PROJECTION_ORIGIN_Y = 310.0 - (rp.REAR[1] - _LEGACY_RAIL_Y)


def cell_point(c: int, r: int) -> tuple[float, float]:
    return ie.cell_to_authored(c, r, origin_y=PROJECTION_ORIGIN_Y)


# The V11 compact redraw reaches into negative offline-grid indices.  This is
# only the planner mirror; runtime exports world coordinates/search-map pixels.
# Keep an explicit offset window so the west/near corners are validated rather
# than silently read as unwalkable at c/r < 0.
GRID_C_MIN, GRID_C_MAX = -8, 31
GRID_R_MIN, GRID_R_MAX = -8, 31


def grid_cells():
    for c in range(GRID_C_MIN, GRID_C_MAX + 1):
        for r in range(GRID_R_MIN, GRID_R_MAX + 1):
            yield c, r


# Diamond and insets follow `ie_projection.ACTIVE`, so they move with the
# camera the painted plate was drawn to rather than drifting from it.
CELL_RECT = ie.CELL_RECT  # inset from the diamond so corners pass
PARTITION_CELL_RECT = ie.PARTITION_CELL_RECT  # retired partition QA compatibility

def cell_rect(x: float, y: float) -> tuple[float, float, float, float]:
    return ie.cell_aabb(x, y)


def partition_cell_rects() -> list[tuple[float, float, float, float]]:
    """Compatibility hook for the retired suite partition; V11 has no solids."""
    return []


# Walkable floor, in plan units: wall stand-off at the rear and sides, and the
# camera-near edge taken from the room's design boundary (`B_ROOM`), where the
# regenerated cutaway wall stands — not the plate's oversized painted floor.
FLOOR_A = (0.045, rp.A_ROOM - 0.045)
FLOOR_B = (0.040, rp.B_ROOM - 0.050)


# The runtime search map rasterises obstacles against *world* cells of 16x12
# (`SearchMap.defaultCellSize`), which in authored units is this. The planner's
# own navigation grid is the `ie_projection.ACTIVE` diamond — today 128x64,
# which is 2.6x coarser across and 1.7x taller than a runtime cell, and that
# mismatch is what let a boundary measure open here and come out sealed in the
# game. Adopting BG:EE makes the diamond 128x96, exactly 8x8 search cells.
RUNTIME_CELL = (16.0 / ENV, 12.0 / ENV)

# Thickness of the sealing ring, in runtime cells. The office agent radius is 3
# world units, well under one cell, so three cells cannot be clipped through.
BOUNDARY_RING_CELLS = 3


def _rect_clear_of_floor(rect: tuple[float, float, float, float]) -> bool:
    """True when `rect` provably cannot touch the walkable floor.

    The floor is the plan-space band FLOOR_A x FLOOR_B, and `authored_to_plan` is
    affine, so each bound is a half-plane. A convex rect that violates one of them
    at all four corners is separated from the floor — a conservative test, which
    is what we want: it may leave a cell un-stamped, never stamp one that eats
    floor.
    """
    x, y, w, h = rect
    plans = [
        rp.authored_to_plan(px, py)
        for px, py in ((x, y), (x + w, y), (x, y + h), (x + w, y + h))
    ]
    return (
        all(p[0] < FLOOR_A[0] for p in plans)
        or all(p[0] > FLOOR_A[1] for p in plans)
        or all(p[1] < FLOOR_B[0] for p in plans)
        or all(p[1] > FLOOR_B[1] for p in plans)
    )


def _rect_overlaps_exterior_threshold(
    rect: tuple[float, float, float, float],
) -> bool:
    """Whether a boundary solid overlaps the registered V11 door aperture.

    The closed leaf is a separate door stamp.  Static boundary cells must leave
    its full hinge-to-free-end span open, otherwise clearing the door state would
    still leave an invisible wall across travel.
    """
    x, y, w, h = rect
    plans = [
        rp.authored_to_plan(px, py)
        for px, py in ((x, y), (x + w, y), (x, y + h), (x + w, y + h))
    ]
    a0, a1 = rp.DOOR_SPAN_A
    a_margin = 0.018
    b_margin = 0.105
    return (
        max(a for a, _ in plans) >= a0 - a_margin
        and min(a for a, _ in plans) <= a1 + a_margin
        and max(b for _, b in plans) >= 1.0 - b_margin
        and min(b for _, b in plans) <= 1.0 + b_margin
    )


def boundary_cell_rects() -> list[tuple[float, float, float, float]]:
    """A sealing ring of solids just outside the walkable floor.

    This used to stamp one 104x52 AABB per *iso* cell outside the floor. Those
    boxes approximate the diamond, so each overhangs its neighbours when the
    inset is too loose, and the union bit ~20x10 authored units into the floor
    on every edge. On the
    planner's coarse grid that rounded away; on the runtime 16x12 grid it ate the
    room, leaving 174 of 4694 walkable cells reachable and sealing the waiting
    side off entirely.
    """
    cw, ch = RUNTIME_CELL
    points = [cell_point(c, r) for c, r in grid_cells()]
    pad = (BOUNDARY_RING_CELLS + 1)
    x0 = min(p[0] for p in points) - pad * cw
    x1 = max(p[0] for p in points) + pad * cw
    y0 = min(p[1] for p in points) - pad * ch
    y1 = max(p[1] for p in points) + pad * ch

    columns = int(math.ceil((x1 - x0) / cw))
    rows = int(math.ceil((y1 - y0) / ch))

    def rect_at(i: int, j: int) -> tuple[float, float, float, float]:
        return (x0 + i * cw, y0 + j * ch, cw, ch)

    clear = {
        (i, j): _rect_clear_of_floor(rect_at(i, j))
        for i in range(columns)
        for j in range(rows)
    }

    # Only the band hugging the floor needs solids: everything beyond it is
    # unreachable once the band is sealed, and stamping it would multiply both
    # the emitted literal and the per-cell rasterisation cost for nothing.
    span = range(-BOUNDARY_RING_CELLS, BOUNDARY_RING_CELLS + 1)
    rects = []
    for (i, j), is_clear in sorted(clear.items()):
        if not is_clear:
            continue
        touches_floor = any(
            not clear.get((i + di, j + dj), True) for di in span for dj in span
        )
        if touches_floor and not _rect_overlaps_exterior_threshold(rect_at(i, j)):
            rects.append(rect_at(i, j))
    return rects


def foreground_obstacle() -> tuple[float, float, float, float]:
    """One near-edge cell, kept as a named rect for the layout tests."""
    x, y = rp.authored(rp.A_ROOM * 0.45, rp.B_ROOM - 0.02)
    return cell_rect(x, y)


def partition_open_cells() -> list[tuple[int, int]]:
    """Compatibility hook for the retired internal doorway."""
    return []


FOREGROUND_OBSTACLE = foreground_obstacle()

# Closed door stamp: a narrow AABB around the threshold centre. The full
# hinge-to-free span is diagonal, so its AABB would cut the interior in half.
# This box still contains the navigation threshold and the authored exterior
# waypoint without claiming the camera-near floor.
DOOR_THRESHOLD_HALF_A = 0.050
DOOR_THRESHOLD_B0 = 0.980
DOOR_THRESHOLD_B1 = 1.100


def plan_box_obstacle(
    a0: float, b0: float, a1: float, b1: float, inset: float = 0.72
) -> tuple[float, float, float, float]:
    """Authored AABB of a plan-space box, rejected by corners."""
    corners = [rp.authored(a, b) for a in (a0, a1) for b in (b0, b1)]
    xs = [c[0] for c in corners]
    ys = [c[1] for c in corners]
    cx, cy = sum(xs) / 4, sum(ys) / 4
    w = (max(xs) - min(xs)) * inset
    h = (max(ys) - min(ys)) * inset
    return (cx - w / 2, cy - h / 2, w, h)


DOOR_OBSTACLE = plan_box_obstacle(
    EXTERIOR_DOOR[0] - DOOR_THRESHOLD_HALF_A,
    DOOR_THRESHOLD_B0,
    EXTERIOR_DOOR[0] + DOOR_THRESHOLD_HALF_A,
    DOOR_THRESHOLD_B1,
    inset=1.0,
)

FIREPLACE_OBSTACLE = (0.0, 0.0, 0.0, 0.0)
FIREPLACE_COVER_RECT = (0.0, 0.0, 0.0, 0.0)


def inscribed_vertical_rects(
    polygon: tuple[tuple[float, float], ...], slices: int = 24
) -> list[tuple[float, float, float, float]]:
    """Approximate a convex floor polygon without blocking its AABB corners.

    ARE obstacles are rectangles, while the V14 hearth is a BG:EE-aligned
    parallelogram. Narrow rectangles are kept wholly inside that footprint;
    the separately registered wall polygon remains the exact outline.
    """
    min_x, _, width, _ = rp.polygon_bounds(polygon)
    step = width / slices

    def interval(x: float) -> tuple[float, float]:
        intersections: list[float] = []
        for start, end in zip(polygon, (*polygon[1:], polygon[0])):
            x0, y0 = start
            x1, y1 = end
            if abs(x1 - x0) < 1e-9:
                if abs(x - x0) < 1e-9:
                    intersections.extend((y0, y1))
                continue
            t = (x - x0) / (x1 - x0)
            if -1e-9 <= t <= 1.0 + 1e-9:
                intersections.append(y0 + t * (y1 - y0))
        return min(intersections), max(intersections)

    result: list[tuple[float, float, float, float]] = []
    # Pull each strip slightly off its bin edges. This preserves useful
    # collision at the pointed ends without ever extending outside the hearth.
    edge_inset = step * 0.08
    for index in range(slices):
        x0 = min_x + index * step + edge_inset
        x1 = min_x + (index + 1) * step - edge_inset
        low0, high0 = interval(x0)
        low1, high1 = interval(x1)
        low = max(low0, low1)
        high = min(high0, high1)
        if high > low:
            result.append((x0, low, x1 - x0, high - low))
    return result


def runtime_cell_center_rects(
    polygon: tuple[tuple[float, float], ...], half_extent: float = 0.5
) -> list[tuple[float, float, float, float]]:
    """Keep cells whose actual 16x12 runtime centres lie inside a thin solid.

    The compact V14 hearth is an edge-on parallelogram narrower than one search
    cell. Its exact inscribed strips remain useful for world-resolution line of
    sight, but none necessarily contains a raster cell centre. Add a tiny AABB
    around each centre that is genuinely inside the polygon. Requiring every
    AABB corner to remain inside preserves the conservative obstacle contract.
    """
    min_x, min_y, width, height = rp.polygon_bounds(polygon)
    cell_w, cell_h = RUNTIME_CELL

    def inside(point: tuple[float, float]) -> bool:
        signs: set[bool] = set()
        for start, end in zip(polygon, (*polygon[1:], polygon[0])):
            cross = ((end[0] - start[0]) * (point[1] - start[1])
                     - (end[1] - start[1]) * (point[0] - start[0]))
            if abs(cross) > 1e-9:
                signs.add(cross > 0)
        return len(signs) <= 1

    first_column = max(0, int(math.floor(min_x / cell_w)))
    last_column = int(math.ceil((min_x + width) / cell_w))
    first_row = max(0, int(math.floor(min_y / cell_h)))
    last_row = int(math.ceil((min_y + height) / cell_h))
    result: list[tuple[float, float, float, float]] = []
    for column in range(first_column, last_column + 1):
        for row in range(first_row, last_row + 1):
            center = ((column + 0.5) * cell_w, (row + 0.5) * cell_h)
            corners = (
                (center[0] - half_extent, center[1] - half_extent),
                (center[0] + half_extent, center[1] - half_extent),
                (center[0] + half_extent, center[1] + half_extent),
                (center[0] - half_extent, center[1] + half_extent),
            )
            if all(inside(corner) for corner in corners):
                result.append((
                    center[0] - half_extent,
                    center[1] - half_extent,
                    half_extent * 2,
                    half_extent * 2,
                ))
    return result


FIREPLACE_OBSTACLE_RECTS: list[tuple[float, float, float, float]] = []

# V11 deliberately removes the tavern pillars and stair run.  Zero/empty
# compatibility aliases keep older diagnostic callers source-compatible.
PILLAR_OBSTACLES: list[tuple[float, float, float, float]] = []
STAIR_OBSTACLE = (0.0, 0.0, 0.0, 0.0)


# --------------------------------------------------------------- navigation


class Grid:
    """Mirror of NavigationGrid's projection for offline validation."""

    def __init__(self, obstacles, half_w=3.0 / ENV, half_h=0.0):
        self.obstacles = [
            (x - half_w, y - half_h, w + 2 * half_w, h + 2 * half_h) for x, y, w, h in obstacles
        ]
        self.blocked = {
            (c, r) for c, r in grid_cells() if self.inside(cell_point(c, r))
        }

    def cell(self, p):
        return ie.authored_to_cell(p[0], p[1], origin_y=PROJECTION_ORIGIN_Y)

    def inside(self, p):
        return any(x <= p[0] <= x + w and y <= p[1] <= y + h for x, y, w, h in self.obstacles)

    def walkable(self, c, r):
        return (
            GRID_C_MIN <= c <= GRID_C_MAX
            and GRID_R_MIN <= r <= GRID_R_MAX
            and (c, r) not in self.blocked
        )

    def reachable(self, start):
        if not self.walkable(*start):
            return set()
        seen, queue = {start}, deque([start])
        while queue:
            c, r = queue.popleft()
            for dc in (-1, 0, 1):
                for dr in (-1, 0, 1):
                    if dc == dr == 0:
                        continue
                    n = (c + dc, r + dr)
                    if n in seen or not self.walkable(*n):
                        continue
                    if dc and dr and not (self.walkable(c + dc, r) and self.walkable(c, r + dr)):
                        continue
                    seen.add(n)
                    queue.append(n)
        return seen


class RuntimeRaster:
    """16x12-world-cell mirror used for honest V11 preflight flood-fill."""

    def __init__(self, obstacles: list[tuple[float, float, float, float]]):
        self.cell_w, self.cell_h = RUNTIME_CELL
        self.columns = int(math.ceil(rp.ART_W / self.cell_w))
        self.rows = int(math.ceil(rp.ART_H / self.cell_h))
        self.radius = 3.0 / ENV
        self.obstacles = obstacles

    def cell(self, point: tuple[float, float]) -> tuple[int, int]:
        return (
            int(math.floor(point[0] / self.cell_w)),
            int(math.floor(point[1] / self.cell_h)),
        )

    def centre(self, cell: tuple[int, int]) -> tuple[float, float]:
        return (
            (cell[0] + 0.5) * self.cell_w,
            (cell[1] + 0.5) * self.cell_h,
        )

    def contains(self, cell: tuple[int, int]) -> bool:
        return 0 <= cell[0] < self.columns and 0 <= cell[1] < self.rows

    def passable(self, point: tuple[float, float]) -> bool:
        x, y = point
        radius = self.radius
        if not (
            radius <= x <= rp.ART_W - radius
            and radius <= y <= rp.ART_H - radius
        ):
            return False
        for ox, oy, ow, oh in self.obstacles:
            closest_x = min(max(x, ox), ox + ow)
            closest_y = min(max(y, oy), oy + oh)
            if (closest_x - x) ** 2 + (closest_y - y) ** 2 <= radius**2:
                return False
        return True

    def cell_passable(self, cell: tuple[int, int]) -> bool:
        return self.contains(cell) and self.passable(self.centre(cell))

    def reachable(self, start: tuple[float, float]) -> set[tuple[int, int]]:
        start_cell = self.cell(start)
        if not self.passable(start) or not self.cell_passable(start_cell):
            return set()
        seen = {start_cell}
        queue = deque([start_cell])
        while queue:
            column, row = queue.popleft()
            for dc in (-1, 0, 1):
                for dr in (-1, 0, 1):
                    if dc == dr == 0:
                        continue
                    candidate = (column + dc, row + dr)
                    if candidate in seen or not self.cell_passable(candidate):
                        continue
                    if dc and dr and not (
                        self.cell_passable((column + dc, row))
                        and self.cell_passable((column, row + dr))
                    ):
                        continue
                    seen.add(candidate)
                    queue.append(candidate)
        return seen


# Floor collision for the live desk and chair only. Retired scenery must not
# leave invisible walls on the empty shell.
LIVE_OBSTACLE_KEYS = {"deskEnsemble", "deskChair"}


def build_obstacles(door_blocking: bool = True):
    rects = [*FIREPLACE_OBSTACLE_RECTS, *boundary_cell_rects()]
    if door_blocking:
        rects.insert(0, DOOR_OBSTACLE)
    rects += [
        p.obstacle_rect
        for p in PROPS
        if p.obstacle and p.key in LIVE_OBSTACLE_KEYS
    ]
    return rects


# --------------------------------------------------------------- Swift emit


def pt(p) -> str:
    return precise_pt(p)


def swift_scalar(value: float) -> str:
    """Shortest Swift literal that round-trips the authored Python float."""
    number = float(value)
    return "0.0" if number == 0.0 else repr(number)


def precise_pt(p) -> str:
    return f"CGPoint(x: {swift_scalar(p[0])}, y: {swift_scalar(p[1])})"


def rect(r) -> str:
    return (
        f"CGRect(x: {swift_scalar(r[0])}, y: {swift_scalar(r[1])}, "
        f"width: {swift_scalar(r[2])}, height: {swift_scalar(r[3])})"
    )


def samples(r) -> list[tuple[float, float]]:
    """Three points guaranteed to sit inside an obstacle rect."""
    x, y, w, h = r
    return [
        (x + w * 0.5, y + h * 0.5),
        (x + w * 0.3, y + h * 0.35),
        (x + w * 0.7, y + h * 0.65),
    ]


def emit() -> str:
    for prop in PROPS:
        prop.measure()

    lines: list[str] = []
    add = lines.append

    add("import CoreGraphics")
    add("")
    add("/// Generated by `ArtSource/Processing/office_layout_plan.py` — edit the")
    add("/// layout there and re-run, so art, navigation and previews stay in step.")
    add("///")
    add("/// Placements are authored in the shell's floor-plan basis: every prop sits on")
    add("/// a measured room axis, so furniture lines up with the painted walls.")
    add("enum OfficeNavigationLayout {")
    add("    enum Architecture {")
    add("        /// Shell-authoritative centre of the painted exterior threshold.")
    add(f"        static let entranceAnchor = {precise_pt(exterior_door_threshold_authored())}")
    add("        /// Centre of the camera-nearer baked steel casement.")
    add(f"        static let windowAnchor = {precise_pt(window_anchor_authored())}")
    add("        /// V14 compact-wall aperture registrations (authored plate coordinates).")
    add("        static let nearWindowAperture: [CGPoint] = [")
    for point in rp.NEAR_WINDOW_APERTURE:
        add(f"            {precise_pt(point)},")
    add("        ]")
    add("        static let farWindowAperture: [CGPoint] = [")
    for point in rp.FAR_WINDOW_APERTURE:
        add(f"            {precise_pt(point)},")
    add("        ]")
    add(f"        static let nearWindowHitArea = {rect(rp.polygon_bounds(rp.NEAR_WINDOW_APERTURE))}")
    add("        static let windowGlassPolygons: [[CGPoint]] = [")
    for polygon in rp.WINDOW_GLASS_POLYGONS:
        add("            [")
        for point in polygon:
            add(f"                {precise_pt(point)},")
        add("            ],")
    add("        ]")
    add("        /// Retired partition compatibility values; V11 is one open room.")
    add("        static let partitionLineA: CGFloat = 0")
    add("        static let partitionThicknessA: CGFloat = 0")
    add("        static let partitionDoorB0: CGFloat = 0")
    add("        static let partitionDoorB1: CGFloat = 0")
    add("        static let partitionReturnB1: CGFloat = 0")
    add(f"        static let wallThicknessPx: CGFloat = {rp.WALL_THICKNESS_PX:.1f}")
    add(f"        static let axisNW = CGVector(dx: {rp.AXIS_NW[0]:.1f}, dy: {rp.AXIS_NW[1]:.1f})")
    add(f"        static let axisNE = CGVector(dx: {rp.AXIS_NE[0]:.1f}, dy: {rp.AXIS_NE[1]:.1f})")
    add(f"        static let rearCorner = CGPoint(x: {rp.REAR[0]:.1f}, y: {rp.ART_H - rp.REAR[1]:.1f})")
    add("")
    add("        /// Zeroed compatibility geometry for the removed partition.")
    p0 = rp.plan(0, 0)
    add("        static let partitionPlateX0: CGFloat = 0")
    add("        static let partitionPlateX1: CGFloat = 0")
    add("        static let partitionPlateFaceHeight: CGFloat = 0")
    add("        static let partitionPlateCapHeight: CGFloat = 0")
    add("")
    add("        /// Ground line of the partition face at a shell-art x (y down).")
    add("        static func partitionPlateBaseY(atPlateX x: CGFloat) -> CGFloat {")
    add("            _ = x")
    add("            return 0")
    add("        }")
    add("")
    add("        /// Edge-on leaf thickness x hinge-to-free length from the V11 lock.")
    add(
        f"        static let entranceOpeningPlateSize = "
        f"CGSize(width: {SHIPPING_EXTERIOR_OPENING_SIZE[0]:.3f}, "
        f"height: {SHIPPING_EXTERIOR_OPENING_SIZE[1]:.3f})"
    )
    add(
        f"        /// Registered closed length {SHIPPING_EXTERIOR_OPENING_SIZE[1]:.3f} plate px; "
        "this is a foreshortened floor-edge leaf, not an upright opening height."
    )
    add(
        f"        static let entranceOpeningToDetectiveRatio: CGFloat = "
        f"{SHIPPING_EXTERIOR_OPENING_SIZE[1] / BODY:.3f}"
    )
    add(
        f"        static let entranceHandleHeightToDetective: CGFloat = "
        f"{rp.DOOR_HANDLE_TO_DETECTIVE:.3f}"
    )
    add("")
    add("        /// Edge-on BG:EE leaf family, registered by its exact upper-right hinge.")
    add(f"        static let entranceLeafDisplayScale: CGFloat = {DOOR_DISPLAY_SCALE:.6f}")
    add("        static let entranceLeafDisplayScaleX: CGFloat = entranceLeafDisplayScale")
    add("        static let entranceLeafDisplayScaleY: CGFloat = entranceLeafDisplayScale")
    add(f"        static let entranceLeafAnchorX: CGFloat = {rp.DOOR_ANCHOR[0]:.6f}")
    add(f"        static let entranceLeafAnchorY: CGFloat = {rp.DOOR_ANCHOR[1]:.6f}")
    add("        static let entranceLeafAnchorPoint = CGPoint(")
    add("            x: entranceLeafAnchorX, y: entranceLeafAnchorY")
    add("        )")
    add(f"        static let entranceLeafAnchor = {precise_pt(exterior_leaf_anchor_authored())}")
    add(f"        static let entranceLeafHitArea = {rect(DOOR_VISUAL_BOUNDS)}")
    add("        static let entranceFrameDisplayScale: CGFloat = 0")
    add("        static let entranceFrameDisplayScaleX: CGFloat = entranceFrameDisplayScale")
    add("        static let entranceFrameDisplayScaleY: CGFloat = entranceFrameDisplayScale")
    add("        static let entranceFrameAnchorX: CGFloat = 0")
    add("        static let entranceFrameAnchorY: CGFloat = 0")
    add("        /// Registered retracting states retain the same fixed hinge.")
    add(f"        static let entranceLeafClosedLengthRatio: CGFloat = {rp.DOOR_STATE_LENGTH_RATIOS['closed']:.3f}")
    add(f"        static let entranceLeafMidLengthRatio: CGFloat = {rp.DOOR_STATE_LENGTH_RATIOS['mid']:.3f}")
    add(f"        static let entranceLeafOpenLengthRatio: CGFloat = {rp.DOOR_STATE_LENGTH_RATIOS['open']:.3f}")
    add(f"        static let entranceFallenLeafScaleRatio: CGFloat = {rp.DOOR_STATE_LENGTH_RATIOS['open']:.3f}")
    add("        static let entranceFallingTransitionScale: CGFloat = entranceLeafDisplayScale")
    add(
        "        static let entranceFallenArtworkCanvasSize = CGSize("
        f"width: {rp.DOOR_LIVE_CANVAS[0]}, height: {rp.DOOR_LIVE_CANVAS[1]})"
    )
    add("        static let entranceFallenArtworkDisplayScale: CGFloat = entranceLeafDisplayScale")
    add("        static let entranceFallenArtworkDisplaySize = CGSize(")
    add("            width: entranceFallenArtworkCanvasSize.width")
    add("                * entranceFallenArtworkDisplayScale,")
    add("            height: entranceFallenArtworkCanvasSize.height")
    add("                * entranceFallenArtworkDisplayScale")
    add("        )")
    add("        /// Removed internal door compatibility values.")
    add("        static let internalHingePlateX: CGFloat = 0")
    add("        static let internalHingePlateHeight: CGFloat = 0")
    add("        static let internalLeafDisplayScale: CGFloat = 0")
    add("        static let internalLeafAnchor = CGPoint.zero")
    add("    }")
    add("")
    add("    /// Walkable chair-side stand point (camera-near of the kneehole).")
    add("    /// Kept outside the desk obstacle so leave-seat never starts on the")
    add("    /// visitor/rear side of the writing surface.")
    add(f"    private static let authoredActorStart = {precise_pt(actor_start_authored())}")
    add("")

    # ---- obstacles
    named_all = [(p.key, p.obstacle_rect) for p in PROPS if p.obstacle]
    named = [(key, rect) for key, rect in named_all if key in LIVE_OBSTACLE_KEYS]
    add("    // MARK: - Obstacles (authored AABBs around each floor footprint)")
    add("")
    add("    /// One cell of the camera-near boundary, kept named for the layout tests.")
    add(f"    static let authoredForegroundWallObstacle = {rect(FOREGROUND_OBSTACLE)}")
    add(f"    static let authoredDoorObstacle = {rect(DOOR_OBSTACLE)}")
    add(f"    static let authoredFireplaceObstacle = {rect(FIREPLACE_OBSTACLE)}")
    add("    static let authoredFireplaceObstacleSegments: [CGRect] = [")
    for segment in FIREPLACE_OBSTACLE_RECTS:
        add(f"        {rect(segment)},")
    add("    ]")
    add(f"    static let authoredFireplaceCoverRect = {rect(FIREPLACE_COVER_RECT)}")
    add("    static let authoredFireplaceObstaclePolygon: [CGPoint] = [")
    for point in rp.FIREPLACE_OBSTACLE_POLYGON:
        add(f"        {precise_pt(point)},")
    add("    ]")
    add("    static let authoredFireplaceCoverPolygon: [CGPoint] = [")
    for point in rp.FIREPLACE_COVER_POLYGON:
        add(f"        {precise_pt(point)},")
    add("    ]")
    add("    /// Retired V10 stair compatibility alias; no stair pixels or collision remain.")
    add(f"    static let authoredStairObstacle = {rect(STAIR_OBSTACLE)}")
    add("    static let authoredPillarSegments: [CGRect] = [")
    for r in PILLAR_OBSTACLES:
        add(f"        {rect(r)},")
    add("    ]")
    add("")
    bounds = boundary_cell_rects()
    add("    /// Room boundary: the rear and side walls plus the camera-near cutaway")
    add("    /// wall, one solid per navigation cell outside the painted floor.")
    add("    static let authoredBoundarySegments: [CGRect] = [")
    for r in bounds:
        add(f"        {rect(r)},")
    add("    ]")
    add("")
    part = partition_cell_rects()
    add("    /// Retired partition compatibility aliases; V11 is open-plan.")
    retired_partition = (0.0, 0.0, 0.0, 0.0)
    add(f"    static let authoredPartitionWallNorthObstacle = {rect(retired_partition)}")
    add(f"    static let authoredPartitionWallSouthObstacle = {rect(retired_partition)}")
    add("    static let authoredPartitionSegments: [CGRect] = [")
    for r in part:
        add(f"        {rect(r)},")
    add("    ]")
    add("")
    for key, r in named_all:
        add(f"    static let authored{key[0].upper()}{key[1:]}Obstacle = {rect(r)}")
    add("")
    sight_blocking_prop_keys = {"safe", "filingCabinet", "bookshelf"}
    sight_permeable_prop_keys = [
        key for key, _ in named if key not in sight_blocking_prop_keys
    ]
    add("    /// Furniture low enough to see over.")
    add("    ///")
    add("    /// Baldur's Gate paints these as terrain index 8 — blocks movement, passes")
    add("    /// sight — and reserves index 0 for the things that stop both. The office")
    add("    /// has always rasterised every rectangle as index 0, which was invisible")
    add("    /// while fog was a disc around the player and became wrong the moment fog")
    add("    /// started asking the search map what it could see: a desk two paces away")
    add("    /// shadowed the whole far wall.")
    add("    ///")
    add("    /// V18 keeps only the live desk and chair footprints here. Both are low")
    add("    /// enough to block feet while allowing sight to pass over them.")
    add("    private static var authoredSightPermeableObstacles: [CGRect] {")
    add("        [")
    for key in sight_permeable_prop_keys:
        add(f"            authored{key[0].upper()}{key[1:]}Obstacle,")
    add("        ]")
    add("    }")
    add("")
    add("    /// Sight-blocking architecture: the room shell, foreground boundary and")
    add("    /// registered entrance threshold. V18 authors no furniture cover polygons.")
    add("    private static var authoredSightBlockingObstacles: [CGRect] {")
    add("        [authoredDoorObstacle, authoredForegroundWallObstacle]")
    add("            + authoredFireplaceObstacleSegments")
    add("            + authoredBoundarySegments")
    add("            + authoredPartitionSegments")
    add("            + authoredPillarSegments")
    add("            + [")
    for key, _ in named:
        if key in sight_blocking_prop_keys:
            add(f"                authored{key[0].upper()}{key[1:]}Obstacle,")
    add("            ]")
    add("    }")
    add("")
    add("    private static var authoredObstacles: [CGRect] {")
    add("        authoredSightBlockingObstacles + authoredSightPermeableObstacles")
    add("    }")
    add("")
    add("    /// World-space subset of `obstacles` that stops feet but not sight.")
    add("    static var sightPermeableObstacles: [CGRect] {")
    add("        authoredSightPermeableObstacles.map(OfficeInteriorScale.mapRect)")
    add("    }")
    add("")

    # ---- sample points
    add("    // MARK: - Sample points (interior to each obstacle)")
    add("")
    sample_sets = [(key, r) for key, r in named_all]
    sample_sets.append(("doorLeaf", DOOR_OBSTACLE))
    sample_sets.append(("foregroundWall", FOREGROUND_OBSTACLE))
    sample_sets.append(("partitionWallNorth", retired_partition))
    sample_sets.append(("partitionWallSouth", retired_partition))
    for key, r in sample_sets:
        add(f"    static let authored{key[0].upper()}{key[1:]}SamplePoints: [CGPoint] = [")
        for s in samples(r):
            add(f"        {pt(s)},")
        add("    ]")
    add("    static let authoredFireplaceSamplePoints: [CGPoint] = [")
    for x, y, width, height in FIREPLACE_OBSTACLE_RECTS:
        add(f"        {precise_pt((x + width / 2, y + height / 2))},")
    add("    ]")
    add("")

    # ---- placements
    add("    // MARK: - Placements")
    add("")
    add("    enum AuthoredPlacement {")
    add("        /// Registered to the visual threshold baked into the shipping suite.")
    add("        static let doorLeaf = Architecture.entranceLeafAnchor")
    add("        static let window = Architecture.windowAnchor")
    add("        static let windowBlinds = window")
    add("        static let windowRotation: CGFloat = 0")
    wx, wy = window_anchor_authored()
    add(
        "        /// Full-plate registration for the mask whose alpha contains "
        "both baked glass apertures."
    )
    add(f"        static let windowRainMask = {rect((0.0, 0.0, rp.ART_W, rp.ART_H))}")
    add(f"        static let windowRainEmitter = {precise_pt((wx, wy + 72.0))}")
    add("        /// Recentred on the fitted V14 room envelope.")
    add(f"        static let camera = {pt(camera_authored())}")
    add("")
    for prop in PROPS:
        note = f"  // {prop.note}" if prop.note else ""
        # Prop records retain sub-pixel registration; emitting whole authored
        # pixels here made the Swift placement disagree with exported JSON.
        add(f"        static let {prop.key} = {precise_pt(prop.authored)}{note}")
    add("")
    add(f"        static let wornRug = {pt(rp.authored(*RUG))}")
    add("        static let floorWear = deskEnsemble")
    for key, mount in WALL_ART.items():
        plate = mount.plate
        add(f"        static let {key} = {pt((plate[0], rp.ART_H - plate[1]))}")
    for key, plate in FLOOR_DECALS.items():
        if plate is None:
            continue
        add(f"        static let {key} = {pt((plate[0], rp.ART_H - plate[1]))}")
    add("        static let lampPool = deskEnsemble")
    add("        /// Retired internal-door compatibility placement.")
    add("        static let internalDoorLeaf = Architecture.internalLeafAnchor")
    add("    }")
    add("")

    # ---- approach points, paths
    add("    private static let authoredApproachPoints: [String: CGPoint] = [")
    for name, (a, b) in APPROACH.items():
        add(f'        "{name}": {pt(rp.authored(a, b))},')
    add("    ]")
    add("")
    # The nav diamond is registered to the same floor plane as the props.
    # Moving the rear floor seam down by 121 plate pixels moves authored y-up
    # coordinates down by the same amount; keep grid cells stable with it.
    add(
        "    private static let authoredProjectionOrigin = "
        f"CGPoint(x: 2_048, y: {PROJECTION_ORIGIN_Y:_.0f})"
    )
    add(
        "    private static let authoredTileSize = "
        f"CGSize(width: {ie.DIAMOND_W}, height: {ie.DIAMOND_H})"
    )
    add("")
    add("    static var actorStart: CGPoint { OfficeInteriorScale.mapPoint(authoredActorStart) }")
    add("")
    add("    static var emptyDeskChairWorldPosition: CGPoint {")
    add("        let baseline = OfficeInteriorScale.mapPoint(AuthoredPlacement.deskChair)")
    add("        let nudge = OfficeInteriorScale.ActorDisplay.seatedDeskNudge")
    add("        return CGPoint(x: baseline.x + nudge.x, y: baseline.y + nudge.y)")
    add("    }")
    add("")
    add("    enum DeskDepth {")
    add("        /// Visitor chairs sit on the far side of the writing surface.")
    add(f"        static let visitorChairBias: CGFloat = {VISITOR_CHAIR_BIAS:.0f}")
    add("        static let topOccluderBias: CGFloat = -40")
    add("        /// Above seated Voss's lower layer, below a client passing camera-near.")
    add(f"        static let seatedFrontApronBias: CGFloat = {SEATED_DESK_FRONT_APRON_BIAS:.0f}")
    add("        static let standingFrontApronBias: CGFloat = 40")
    add("    }")
    add("")
    add("    /// Exterior threshold crossing. This segment intentionally starts")
    add("    /// outside the floor and passes the open edge-on leaf at the cutaway.")
    add("    static let clientDoorwayPath: [CGPoint] = [")
    for point in CLIENT_DOORWAY_PATH:
        add(f"        {pt(point)},")
    add("    ].map(OfficeInteriorScale.mapPoint)")
    add("")
    add("    /// Walkable open-plan anchors from the entrance toward the desk.")
    add("    static let clientWaitingRoomPath: [CGPoint] = [")
    for point in CLIENT_WAITING_ROOM_PATH:
        add(f"        {pt(point)},")
    add("    ].map(OfficeInteriorScale.mapPoint)")
    add("")
    add("    /// Compatibility-named open-floor circulation points; no partition remains.")
    add("    static let clientInternalDoorwayPath: [CGPoint] = [")
    for point in CLIENT_INTERNAL_DOORWAY_PATH:
        add(f"        {pt(point)},")
    add("    ].map(OfficeInteriorScale.mapPoint)")
    add("")
    add("    /// Direct approach to the desk's camera-near visitor stop.")
    add("    static let clientOfficeArrivalPath: [CGPoint] = [")
    for point in CLIENT_OFFICE_ARRIVAL_PATH:
        add(f"        {pt(point)},")
    add("    ].map(OfficeInteriorScale.mapPoint)")
    add("")
    add("    static let clientInteriorArrivalPath: [CGPoint] = [")
    add("        clientWaitingRoomPath,")
    add("        Array(clientInternalDoorwayPath.dropFirst()),")
    add("        Array(clientOfficeArrivalPath.dropFirst()),")
    add("    ].flatMap { $0 }")
    add("")
    add("    static var clientArrivalPath: [CGPoint] {")
    add("        Array(clientDoorwayPath.dropLast()) + clientInteriorArrivalPath")
    add("    }")
    add("")
    add("    static var clientDeparturePath: [CGPoint] { Array(clientArrivalPath.reversed()) }")
    add("")
    add("    /// Authored entrance-to-desk polyline across the open room.")
    add("    /// Do not A*-expand: these points preserve the intended staging beats.")
    add("    /// Anchors are collision-checked at layout generation.")
    add("    static func clientArrivalRoute(in navigation: NavigationMap) -> [CGPoint] {")
    add("        _ = navigation")
    add("        return clientArrivalPath")
    add("    }")
    add("")
    add("    static func clientDepartureRoute(in navigation: NavigationMap) -> [CGPoint] {")
    add("        Array(clientArrivalRoute(in: navigation).reversed())")
    add("    }")
    add("")
    add("    static let exteriorToInternalDoorPath: [CGPoint] = [")
    add("        Array(clientDoorwayPath.dropLast()),")
    add("        clientWaitingRoomPath,")
    add("        Array(clientInternalDoorwayPath.dropFirst()),")
    add("    ].flatMap { $0 }")
    add("")
    add("    static let internalDoorToClientPath: [CGPoint] = [")
    add("        clientInternalDoorwayPath,")
    add("        Array(clientOfficeArrivalPath.dropFirst()),")
    add("    ].flatMap { $0 }")
    add("")
    add("    static let recordsApproachPath: [CGPoint] = [")
    for a, b in RECORDS_PATH:
        add(f"        {pt(rp.authored(a, b))},")
    add("    ].map(OfficeInteriorScale.mapPoint)")
    add("")

    # ---- mapped accessors
    add("    static var obstacles: [CGRect] { authoredObstacles.map(OfficeInteriorScale.mapRect) }")
    add("")
    for key, _ in named_all:
        upper = f"{key[0].upper()}{key[1:]}"
        add(f"    static var {key}Obstacle: CGRect {{ OfficeInteriorScale.mapRect(authored{upper}Obstacle) }}")
    add("    static var doorObstacle: CGRect { OfficeInteriorScale.mapRect(authoredDoorObstacle) }")
    add("    static var fireplaceObstacle: CGRect { OfficeInteriorScale.mapRect(authoredFireplaceObstacle) }")
    add("    static var fireplaceObstacles: [CGRect] {")
    add("        authoredFireplaceObstacleSegments.map(OfficeInteriorScale.mapRect)")
    add("    }")
    add("    static var fireplaceCoverRect: CGRect { OfficeInteriorScale.mapRect(authoredFireplaceCoverRect) }")
    add("    static var fireplaceObstaclePolygon: [CGPoint] {")
    add("        authoredFireplaceObstaclePolygon.map(OfficeInteriorScale.mapPoint)")
    add("    }")
    add("    static var fireplaceCoverPolygon: [CGPoint] {")
    add("        authoredFireplaceCoverPolygon.map(OfficeInteriorScale.mapPoint)")
    add("    }")
    add("    static var foregroundWallObstacle: CGRect { OfficeInteriorScale.mapRect(authoredForegroundWallObstacle) }")
    add("    static var partitionWallNorthObstacle: CGRect { OfficeInteriorScale.mapRect(authoredPartitionWallNorthObstacle) }")
    add("    static var partitionWallSouthObstacle: CGRect { OfficeInteriorScale.mapRect(authoredPartitionWallSouthObstacle) }")
    add("")
    for key, _ in sample_sets:
        upper = f"{key[0].upper()}{key[1:]}"
        add(
            f"    static var {key}SamplePoints: [CGPoint] "
            f"{{ authored{upper}SamplePoints.map(OfficeInteriorScale.mapPoint) }}"
        )
    add("    static var fireplaceSamplePoints: [CGPoint] {")
    add("        authoredFireplaceSamplePoints.map(OfficeInteriorScale.mapPoint)")
    add("    }")
    add("")
    add("    static var majorPropSamplePoints: [CGPoint] {")
    all_sample_names = [
        f"{key}SamplePoints"
        for key, _ in named
    ] + ["doorLeafSamplePoints", "foregroundWallSamplePoints", "fireplaceSamplePoints"]
    add("        " + "\n            + ".join(all_sample_names))
    add("    }")
    add("")
    add("    static var approachPoints: [String: CGPoint] {")
    add("        authoredApproachPoints.mapValues(OfficeInteriorScale.mapPoint)")
    add("    }")
    add("")
    add("    /// Actual Voss stand-ins for architecture scale review: exterior entrance,")
    add("    /// desk, circulation midpoint, and waiting chair.")
    add("    static let authoredScaleReferenceStands: [CGPoint] = [")
    for a, b in SCALE_STANDS:
        add(f"        {pt(rp.authored(a, b))},")
    add("    ]")
    add("")
    add("    static var scaleReferenceStands: [CGPoint] {")
    add("        authoredScaleReferenceStands.map(OfficeInteriorScale.mapPoint)")
    add("    }")
    add("")
    add("    static var deskSamplePoints: [CGPoint] { deskEnsembleSamplePoints }")
    add("    static var deskObstacle: CGRect { deskEnsembleObstacle }")
    add("    static var authoredDeskObstacle: CGRect { authoredDeskEnsembleObstacle }")
    add("")

    add(HOTSPOTS_SWIFT)
    add(TAIL_SWIFT)
    return "\n".join(lines).rstrip() + "\n"


def exterior_leaf_anchor_authored() -> tuple[float, float]:
    """Exact V11 image hinge, converted from y-down to authored y-up."""
    return rp.DOOR_HINGE_AUTHORED


# Keep the desk's seated front-apron layer above Voss's lower body but below
# Lila while she is on the camera-near side. The old +55 bias covered her head
# and torso, which made the otherwise clear ground route read as desk clipping.
VISITOR_CHAIR_BIAS = -50.0
SEATED_DESK_FRONT_APRON_BIAS = 15.0

# V11 open-room traversal. Compatibility names remain because cutscene callers
# consume them, but the anchors form one honest threshold-to-desk path.
CLIENT_DOORWAY_PLAN_PATH = [
    (APPROACH["office.door"][0], 1.080),
    APPROACH["office.door"],
]
CLIENT_DOORWAY_PATH = [rp.authored(a, b) for a, b in CLIENT_DOORWAY_PLAN_PATH]
CLIENT_WAITING_CLEARANCE_PLAN_PATH = [
    (0.505, 0.661),
    (0.458, 0.597),
]
CLIENT_WAITING_ROOM_PATH = [
    CLIENT_DOORWAY_PATH[-1],
    *[rp.authored(a, b) for a, b in CLIENT_WAITING_CLEARANCE_PLAN_PATH],
]
CLIENT_INTERNAL_DOORWAY_PLAN_PATH = [
    (0.458, 0.597),
    (0.398, 0.513),
    (0.337, 0.425),
]
CLIENT_INTERNAL_DOORWAY_PATH = [
    rp.authored(a, b) for a, b in CLIENT_INTERNAL_DOORWAY_PLAN_PATH
]
# V18's exact AR0809 floor puts the former desk-side stop behind the desk from
# Voss's chair-side sight line. Stop on the last continuously visible clear
# anchor instead; otherwise Lila appears, walks one more leg, and vanishes when
# the dialogue beat starts. This small final step remains in the visible search
# cell while bringing her inside the desk-interaction distance.
CLIENT_DIALOGUE_STOP_PLAN = (0.332, 0.400)
CLIENT_OFFICE_ARRIVAL_PATH = [
    CLIENT_INTERNAL_DOORWAY_PATH[-1],
    rp.authored(*CLIENT_DIALOGUE_STOP_PLAN),
]
CLIENT_INTERIOR_PATH = [
    *CLIENT_WAITING_ROOM_PATH,
    *CLIENT_INTERNAL_DOORWAY_PATH[1:],
    *CLIENT_OFFICE_ARRIVAL_PATH[1:],
]
CLIENT_PATH = [*CLIENT_DOORWAY_PATH[:-1], *CLIENT_INTERIOR_PATH]

SCALE_STANDS = [
    APPROACH["office.door"],  # directly inside the sole cutaway entrance
    (0.680, 0.200),  # behind the central desk
    (0.780, 0.760),  # beside the waiting group
]

RECORDS_PATH = [
    (0.650, 0.240),
    (0.610, 0.175),
    APPROACH["office.files"],
]

HOTSPOTS_SWIFT = '''    static let authoredHotspots: [(id: String, name: String, hitArea: CGRect, observation: String)] = [
        (
            "office.window",
            "Rain-streaked window",
            Architecture.nearWindowHitArea,
            "The rain had been working the glass harder than I had worked a case."
        ),
        (
            "office.desk",
            "Desk",
            deskHitArea,
            "Three old cases, two unpaid bills, one clean page."
        ),
        (
            "office.phone",
            "Telephone",
            phoneHitArea,
            "Quiet. For once it had the decency to look guilty."
        ),
        (
            "office.files",
            "Case files",
            filesHitArea,
            "Closed, abandoned, and one I still lied about."
        ),
        (
            "office.door",
            "Office door",
            doorHitArea,
            "The hall smelled worse, but at least it led somewhere."
        )
    ]

    /// BG-style authored loot for searchable office containers (resolve-once on area entry).
    static let lootContainers: [LootContainerDefinition] = [
        LootContainerDefinition(
            id: "office.desk",
            entries: [
                .coins(pence: 36), // 3s loose change in the drawer
                .randomCoins(table: RandomCoinTable(penceForRolls2to20: [
                    1, 2, 3, 4, 6, 6, 8, 8, 12, 12, 12, 18, 18, 24, 24, 30, 36, 36, 48
                ]))
            ]
        ),
        LootContainerDefinition(
            id: "office.files",
            entries: [
                .randomCoins(table: RandomCoinTable(penceForRolls2to20: [
                    1, 1, 2, 2, 3, 3, 4, 4, 6, 6, 6, 8, 8, 12, 12, 12, 18, 18, 24
                ]))
            ]
        )
    ]

    static func lootContainer(for hotspotID: String) -> LootContainerDefinition? {
        lootContainers.first { $0.id == hotspotID }
    }

    /// Cutaway entrance and its edge-on timber silhouette.
    private static var doorHitArea: CGRect {
        Architecture.entranceLeafHitArea.insetBy(dx: -12, dy: -12)
    }

    private static var deskHitArea: CGRect {
        authoredDeskEnsembleObstacle.insetBy(dx: -90, dy: -70)
    }

    private static var phoneHitArea: CGRect {
        CGRect(
            x: AuthoredPlacement.deskEnsemble.x - 40,
            y: AuthoredPlacement.deskEnsemble.y + 40,
            width: 200,
            height: 150
        )
    }

    private static var filesHitArea: CGRect {
        CGRect(
            x: AuthoredPlacement.filingCabinet.x - 110,
            y: AuthoredPlacement.filingCabinet.y - 20,
            width: 300,
            height: 220
        )
    }
'''

TAIL_SWIFT = '''
    enum DialogueCameraFraming {
        static let legacyDownwardOffset: CGFloat = 55
        static let priorDownwardOffset: CGFloat = 28
        /// Scaled with the BG:EE mid-band camera (~9% rendered body) so dialogue
        /// framing keeps the prior on-screen downward bias after the zoom-out.
        static let cameraBelowActorMidpoint: CGFloat = 142
        static let lateralBiasTowardClient: CGFloat = 24

        static var actorFocusPoint: CGPoint {
            let voss = OfficeInteriorScale.mapPoint(AuthoredPlacement.deskChair)
            let lila = clientArrivalPath.last
                ?? OfficeInteriorScale.mapPoint(AuthoredPlacement.visitorArmchair)
            return CGPoint(
                x: (voss.x + lila.x) * 0.5 + lateralBiasTowardClient,
                y: (voss.y + lila.y) * 0.5
            )
        }

        static var dialogueCameraWorldPosition: CGPoint {
            let focus = actorFocusPoint
            return CGPoint(x: focus.x, y: focus.y - cameraBelowActorMidpoint)
        }

        static func dialogueCameraPosition(playCamera: CGPoint) -> CGPoint {
            _ = playCamera
            return dialogueCameraWorldPosition
        }

        static var downwardOffsetFromPlayCamera: CGFloat {
            let play = OfficeInteriorScale.mapPoint(AuthoredPlacement.camera)
            return play.y - dialogueCameraWorldPosition.y
        }

        static var lateralOffsetFromPlayCamera: CGFloat {
            let play = OfficeInteriorScale.mapPoint(AuthoredPlacement.camera)
            return dialogueCameraWorldPosition.x - play.x
        }
    }

    /// World-space bounds of the scaled office plate (BG search-map frame).
    static var navigationWorldBounds: CGRect {
        CGRect(origin: OfficeInteriorScale.shellOrigin, size: OfficeInteriorScale.scaledArtSize)
    }

    /// Node expansions one path search may spend in this room.
    ///
    /// Three times the engine default: a small interior packed with ~750
    /// obstacle rectangles expands far more nodes per unit travelled than an
    /// open street does. Named so the area record can carry it as data rather
    /// than the scene carrying it as configuration.
    static let pathSearchBudget = 96_000

    /// - Parameter entranceDoorBlocking: When false, exterior door cells are
    ///   clear (door has fallen / opening is open). Toggle later via
    ///   `NavigationMap.setEntranceDoorBlocking` without rebuilding.
    static func makeGrid(entranceDoorBlocking: Bool = true) -> NavigationMap {
        NavigationMap(
            worldBounds: navigationWorldBounds,
            obstacles: obstacles,
            agentProfile: .officeDetective,
            doorObstacles: [DoorObstacle(rect: doorObstacle)],
            entranceDoorBlocking: entranceDoorBlocking,
            maxNodes: pathSearchBudget
        )
    }

    static func isBlocked(_ point: CGPoint) -> Bool {
        obstacles.contains { $0.contains(point) }
    }
}
'''


# --------------------------------------------------------------- report


def report() -> bool:
    """Validate V18 with honest flood-fill and exact authored destinations."""
    for prop in PROPS:
        prop.measure()

    placement_ok = True
    for prop in PROPS:
        if prop.wall is Wall.NORTH_WEST:
            normal = prop.plan_extents_m[1] * M_PER_B * 0.5 + WALL_SEAM_CLEARANCE
            contact = rp.plan(prop.a, prop.b - normal)
            placement_ok &= abs(contact[1] - rp.nw_wall_base(contact[0])) < 1e-6
        elif prop.wall is Wall.NORTH_EAST:
            normal = prop.plan_extents_m[0] * M_PER_A * 0.5 + WALL_SEAM_CLEARANCE
            contact = rp.plan(prop.a - normal, prop.b)
            placement_ok &= abs(contact[1] - rp.ne_wall_base(contact[0])) < 1e-6
        if prop.placement is PlacementKind.SURFACE:
            parent = PROP_BY_KEY[prop.support or ""]
            parent_w, parent_h = parent.plate_size
            child_w, _ = prop.plate_size
            within = abs(prop.support_offset[0]) + child_w * 0.5 <= parent_w * 0.5
            contact = parent_h * 0.72 <= prop.support_offset[1] <= parent_h * 1.02
            placement_ok &= within and contact

    desk_rect = PROP_BY_KEY["deskEnsemble"].obstacle_rect
    chair_rect = PROP_BY_KEY["deskChair"].obstacle_rect
    dx, dy, dw, dh = desk_rect
    cx, cy, cw, ch = chair_rect
    chair_clears_apron = not (
        dx < cx + cw and cx < dx + dw and dy < cy + ch and cy < dy + dh
    )
    seat_x, seat_y = PROP_BY_KEY["deskChair"].authored
    egress_x, egress_y = actor_start_authored()
    seat_registered = (
        abs(seat_x - egress_x) < 1e-9
        and abs(seat_y - (egress_y - ACTOR_START_OFFSET_Y)) < 1e-9
    )
    placement_ok &= chair_clears_apron and seat_registered
    print(
        f"  placement relationships={placement_ok} "
        f"chairClearsDesk={chair_clears_apron} seatRegistered={seat_registered}"
    )

    obstacles = build_obstacles()
    grid = Grid(obstacles)
    start = rp.authored(*ACTOR_START_PLAN)
    start_cell = grid.cell(start)
    reach = grid.reachable(start_cell)
    ok = placement_ok and grid.walkable(*start_cell) and bool(reach)

    print("=== V18 AR0809-exact office navigation ===")
    print(f"  obstacles={len(obstacles)} partition solids={len(partition_cell_rects())}")
    print(f"  actorStart={start_cell} walkable={grid.walkable(*start_cell)} reachable={len(reach)}")
    for name, (a, b) in APPROACH.items():
        cell = grid.cell(rp.authored(a, b))
        good = cell in reach
        ok &= good
        print(f"  {name:15s} plan=({a:.3f},{b:.3f}) cell={cell} reachable={good}")

    # Mirror the runtime's 16x12-world search cells in both registered door
    # states.  Destinations are checked at their exact authored point before
    # flood membership; no nearest-cell fallback can turn a failure green.
    runtime_start = actor_start_authored()
    outside_door = CLIENT_DOORWAY_PATH[0]
    for state, blocking in (("closed", True), ("open", False)):
        runtime = RuntimeRaster(build_obstacles(door_blocking=blocking))
        runtime_reach = runtime.reachable(runtime_start)
        state_ok = bool(runtime_reach)
        for name, plan_point in APPROACH.items():
            destination = rp.authored(*plan_point)
            exact = runtime.passable(destination)
            reachable = runtime.cell(destination) in runtime_reach
            state_ok &= exact and reachable
        outside_exact = runtime.passable(outside_door)
        outside_reachable = runtime.cell(outside_door) in runtime_reach
        if blocking:
            state_ok &= not outside_exact and not outside_reachable
        else:
            state_ok &= outside_exact and outside_reachable
        ok &= state_ok
        print(
            f"  runtime {state:6s} flood={len(runtime_reach)} "
            f"outsideExact={outside_exact} outsideReachable={outside_reachable} "
            f"allApproachesExact={state_ok}"
        )

    fireplace_retired = (
        not rp.FIREPLACE_OBSTACLE_POLYGON
        and not rp.FIREPLACE_COVER_POLYGON
        and not FIREPLACE_OBSTACLE_RECTS
    )
    ok &= fireplace_retired
    print(f"  fireplace collision and cover retired={fireplace_retired}")

    room_cells = [
        (c, r)
        for c, r in grid_cells()
        if 0.0 <= rp.authored_to_plan(*cell_point(c, r))[0] <= rp.A_ROOM
        and 0.0 <= rp.authored_to_plan(*cell_point(c, r))[1] <= rp.B_ROOM
    ]
    reachable_room = set(room_cells) & reach
    open_share = len(reachable_room) / max(len(room_cells), 1)
    open_floor_ok = open_share >= 0.20
    ok &= open_floor_ok
    print(
        f"  open floor={len(reachable_room)}/{len(room_cells)} "
        f"({open_share:.0%}) valid={open_floor_ok}"
    )

    opening_a0, opening_a1 = rp.DOOR_SPAN_A
    doorway_ok = (
        CLIENT_DOORWAY_PLAN_PATH[0][1] > 1.0 > CLIENT_DOORWAY_PLAN_PATH[-1][1]
        and all(opening_a0 <= a <= opening_a1 for a, _ in CLIENT_DOORWAY_PLAN_PATH)
    )
    ok &= doorway_ok
    print(f"  sole cutaway threshold crossing valid={doorway_ok}")

    inside = [
        point
        for point in CLIENT_PATH[1:]
        if any(x <= point[0] <= x + w and y <= point[1] <= y + h
               for x, y, w, h in obstacles)
    ]
    anchors_clear = not inside
    ok &= anchors_clear
    print(f"  client anchors clear={anchors_clear} inside={len(inside)}")

    def _segment_hits(p0: tuple[float, float], p1: tuple[float, float]) -> bool:
        dx, dy = p1[0] - p0[0], p1[1] - p0[1]
        length = math.hypot(dx, dy)
        samples = max(2, int(math.ceil(length / 8.0)))
        for sample in range(samples + 1):
            t = sample / samples
            px, py = p0[0] + dx * t, p0[1] + dy * t
            if any(x <= px <= x + w and y <= py <= y + h for x, y, w, h in obstacles):
                return True
        return False

    # Skip the exterior threshold crossing; it is authored through the open leaf.
    legs_clear = all(
        not _segment_hits(CLIENT_PATH[i], CLIENT_PATH[i + 1])
        for i in range(1, len(CLIENT_PATH) - 1)
    )
    ok &= legs_clear
    print(f"  client interior legs clear={legs_clear}")

    monotonic = all(
        CLIENT_DOORWAY_PLAN_PATH[i + 1][1] < CLIENT_DOORWAY_PLAN_PATH[i][1]
        for i in range(len(CLIENT_DOORWAY_PLAN_PATH) - 1)
    )
    route_reaches_client_stop = all(
        abs(actual - expected) < 1e-9
        for actual, expected in zip(
            rp.authored_to_plan(*CLIENT_PATH[-1]),
            CLIENT_DIALOGUE_STOP_PLAN,
        )
    )
    ok &= monotonic and route_reaches_client_stop and not partition_cell_rects()
    print(
        f"  direct route monotonic={monotonic} "
        f"reachesVisibleClientStop={route_reaches_client_stop}"
    )
    print(f"\n  ALL CHECKS PASS: {bool(ok)}")
    return bool(ok)


def main() -> None:
    passed = report()
    if "--write" in sys.argv:
        if not passed:
            print("\nrefusing to write: navigation checks failed")
            return
        SWIFT.write_text(emit(), encoding="utf-8")
        print(f"\nwrote {SWIFT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

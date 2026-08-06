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

import sys
from collections import deque
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
from PIL import Image

import office_room_plan as rp

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "RainShadow Shared/Resources/Art/Props/Office"
SWIFT = ROOT / "RainShadow Shared/Gameplay/Navigation/OfficeNavigationLayout.swift"

BODY = rp.BODY_PLATE_H
ENV = rp.ENVIRONMENT_SCALE

# Metre -> plan units on each axis (~200 px of screen x per metre of floor).
# Keep the conversion locked to the pre-cramped axis lengths so prop obstacle
# footprints stay character-relative when the fitted room diamond changes size.
PX_PER_M = 200.0
_REF_AXIS_NW_X = 2206.0
_REF_AXIS_NE_X = 1650.0
M_PER_A = PX_PER_M / _REF_AXIS_NW_X
M_PER_B = PX_PER_M / _REF_AXIS_NE_X

# Wall stand-off for floor furniture that must read as flush.
FLUSH = 0.048

P = rp.PARTITION


@dataclass
class Prop:
    key: str  # Swift AuthoredPlacement name
    art: str | None
    a: float
    b: float
    body: float | None = None  # rendered height as a multiple of the character
    size_m: tuple[float, float] = (0.6, 0.6)  # (width along wall, depth)
    obstacle: bool = True
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
        return rp.authored(self.a, self.b)

    @property
    def obstacle_rect(self) -> tuple[float, float, float, float]:
        """Authored AABB around the prop's floor footprint."""
        da = self.size_m[1] * M_PER_A * 0.5
        db = self.size_m[0] * M_PER_B * 0.5
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

# Fixed suite features on the floor-plane axes (props sit on the boards).
# Door b re-derived from the painted NE threshold on the shoe-fitted diamond
# (was 0.75 on the oversized diamond; plate threshold is fixed).
EXTERIOR_DOOR = (0.0, 0.820)  # painted NE doorway centre on the floor diamond
WINDOW_A = 0.30  # NW-wall window recess on the tight plate

# Visual door registration measured directly from the shipping suite plate.
#
# The navigation partition and `office_partition_opening.json` describe a
# different generated bake. Keep those values for collision/pathing, but never
# use them to place the two live leaf sprites against `office_suite_plate.png`.
# Positions below use plate image coordinates (y down).
SHIPPING_EXTERIOR_OPENING_SIZE = (93.0, 206.0)
SHIPPING_EXTERIOR_THRESHOLD = (2600.65, 960.0)
# Low-b stile of the painted frosted opening (office face).
# Left jamb of the live clear aperture (office face ≈ b 0.752 → plate x ≈ 2297).
SHIPPING_INTERNAL_HINGE_X = 2296.6
SHIPPING_INTERNAL_HINGE_TOP_Y = 1001.0
SHIPPING_INTERNAL_HINGE_BOTTOM_Y = 1171.0

# Every prop belongs to one of four clusters: desk, records, entrance/waiting,
# personal corner. Floor anchors only — never wall-top plane.
PROPS: list[Prop] = [
    # ---- records cluster: flush to the NW wall (b ≈ FLUSH)
    Prop("safe", "office_safe", 0.620, FLUSH, 0.34, (0.6, 0.6), note="records run, east end"),
    Prop("filingCabinetB", "office_filing_cabinet", 0.690, FLUSH, 1.31, (0.5, 0.62)),
    Prop("filingCabinet", "office_filing_cabinet_open", 0.755, FLUSH, 1.31, (0.5, 0.62), note="drawer half open"),
    Prop("bookshelf", "office_bookshelf", 0.835, FLUSH, 1.67, (1.2, 0.35)),
    Prop("archiveBoxOnCabinet", "office_archive_box_b", 0.690, FLUSH, 0.36, obstacle=False, note="on cabinet B"),
    Prop("archiveStackOnCabinet", "office_archive_stack", 0.755, FLUSH, 0.44, obstacle=False, note="on cabinet A"),
    Prop("archiveBoxA", "office_archive_box_a", 0.800, 0.100, 0.40, (0.5, 0.45), note="only floor stack"),
    # ---- radiator under the window
    Prop("radiator", "office_radiator", WINDOW_A, FLUSH - 0.006, 0.82, (1.0, 0.2)),
    # ---- personal corner: partition rear, private-office side
    Prop("personalSideboard", "office_personal_sideboard", 0.430, FLUSH, 0.48, (1.2, 0.5)),
    # The generated washbasin is intentionally retired from the runtime set:
    # it made the room read as domestic rather than investigative.
    Prop(
        "personalWashbasin",
        "office_personal_washbasin",
        0.485,
        FLUSH,
        0.41,
        (0.7, 0.5),
        obstacle=False,
        note="retired domestic fixture; placement retained for source lineage",
    ),
    Prop("personalFan", "office_personal_fan", 0.410, 0.080, 0.68, (0.5, 0.5)),
    Prop("personalBottle", "office_hidden_bottle", 0.438, FLUSH + 0.004, 0.22, obstacle=False, note="on sideboard"),
    Prop("personalGlass", "office_personal_glass", 0.420, FLUSH + 0.004, 0.10, obstacle=False, note="on sideboard"),
    # ---- desk cluster: private office, on the floor boards
    Prop("deskEnsemble", "office_desk_bare", 0.600, 0.380, 0.99, (1.7, 0.9)),
    Prop("deskChair", "office_desk_chair", 0.675, 0.380, 0.64, (0.6, 0.6), obstacle=False),
    # Keep the client pair one step back from the writing surface. a=0.475 is
    # the farthest visitor-side placement that also clears the partition face.
    Prop("visitorArmchair", "office_visitor_armchair", 0.475, 0.310, 0.79, (0.65, 0.65)),
    Prop("visitorArmchairB", "office_visitor_armchair", 0.475, 0.450, 0.76, (0.65, 0.65)),
    Prop("wastebasket", "office_wastebasket", 0.670, 0.290, 0.32, (0.4, 0.4)),
    # ---- entrance / waiting: corridor from exterior door to partition
    Prop("coatRack", "office_coat_rack", 0.040, 0.880, 0.88, (0.6, 0.6)),
    Prop("umbrellaStand", "office_umbrella_stand", 0.070, 0.840, 0.28, (0.35, 0.35)),
    Prop("waitingChairA", "office_waiting_chair_a", 0.170, 0.580, 0.60, (0.55, 0.55)),
    Prop("waitingTable", "office_waiting_table", 0.170, 0.640, 0.36, (0.55, 0.55)),
    Prop("waitingChairB", "office_waiting_chair_b", 0.170, 0.700, 0.58, (0.55, 0.55)),
    Prop("newspaper", "office_newspaper", 0.164, 0.634, 0.10, obstacle=False, note="on table"),
    Prop("waitingAshtray", "office_waiting_ashtray", 0.178, 0.648, 0.07, obstacle=False, note="on table"),
]

PROP_BY_KEY = {p.key: p for p in PROPS}


def exterior_door_threshold_authored() -> tuple[float, float]:
    """Exact centre of the aperture threshold painted into the shipping shell."""
    x, _ = rp.plan(*EXTERIOR_DOOR)
    return (x, rp.ART_H - rp.ne_wall_base(x))


def window_anchor_authored() -> tuple[float, float]:
    """Centre of the painted window recess on the NW wall face (authored y-up)."""
    # Measured from the complete outer recess on the shipping suite plate. Using
    # the darker inner opening's centre left the lower-right sill exposed.
    # The rectification warp shifts the visual frame centre slightly upward, so
    # register four pixels lower than the geometric recess centre.
    recess_center_plate = (1768.5, 599.0)
    return (recess_center_plate[0], rp.ART_H - recess_center_plate[1])


def camera_authored() -> tuple[float, float]:
    """Camera recentred on the packed desk / private-office mass."""
    return rp.authored(0.52, 0.42)


# Worn burgundy rug under the desk island — office side of the partition only.
# Sized so opaque pixels stay at a > partition office face (no overlap into the
# waiting bay / doorway). Shared with addWornRug / compose_office_redesign_preview.
RUG = (0.660, 0.380)
RUG_BODY = 2.2
RUG_FACTOR = 0.62

# Wall art hangs on the north-west wall face directly above the records run —
# board, map and photo cluster packed together, deliberately uneven; authored in
# plate pixels (y down) because it sits on the wall plane, not the floor.
def _wall_art_plate(a: float, b: float, up: float) -> tuple[float, float]:
    """NW-wall decoration anchor: floor plan point raised `up` plate pixels."""
    x, y = rp.plan(a, b)
    return (x, y - up)


WALL_ART = {
    "wallPhotos": _wall_art_plate(1.08, FLUSH, 315.0),
    "caseBoard": _wall_art_plate(0.92, FLUSH, 410.0),
    "wallCityMap": _wall_art_plate(0.70, FLUSH, 370.0),
    "framedLicence": _wall_art_plate(0.52, FLUSH, 290.0),
}

FLOOR_DECALS = {
    "windowSpill": rp.plan(WINDOW_A, 0.10),
    "blindStripes": rp.plan(WINDOW_A + 0.04, 0.16),
    "hallwayLight": rp.plan(0.02, EXTERIOR_DOOR[1]),
    "floorTrashA": rp.plan(0.64, 0.29),
    "floorTrashB": rp.plan(0.79, 0.13),
    "entranceRunner": rp.plan(0.075, 0.80),
    "lampPool": None,  # follows the desk
}

APPROACH = {
    "office.window": (WINDOW_A, 0.120),
    "office.desk": (0.540, 0.520),
    "office.phone": (0.580, 0.520),
    "office.files": (0.755, 0.160),
    "office.door": (0.120, 0.540),  # waiting corridor; segment-clear from desk start
}

# Chair-side seat egress: walkable stand/walk root just camera-near (south) of
# the desk kneehole. Seat-egress settles the body offset from the chair into
# this root without sliding through the desktop (the old +208 put the root on
# the visitor/rear side of the desk).
#
# World seatedYOffset = -ACTOR_START_OFFSET_Y * ENV
#   (−(−30) * 0.395 ≈ +11.85) so actorStart + seatedYOffset lands on the chair.
ACTOR_START_OFFSET_Y = -30.0


# --------------------------------------------------------------- architecture


# Keep the dimetric grid locked to the floor plane as REAR moves.
# 597.1 is the pre-correction plaster/wainscot rail y-down (legacy reference).
_LEGACY_RAIL_Y = 597.1
PROJECTION_ORIGIN_Y = 310.0 - (rp.REAR[1] - _LEGACY_RAIL_Y)


def cell_point(c: int, r: int) -> tuple[float, float]:
    return (2_048 + (c - r) * 64, PROJECTION_ORIGIN_Y + (c + r) * 32)


CELL_RECT = (104.0, 52.0)  # slightly inset from the 128x64 cell so corners pass

# Partition solids use a tighter AABB than floor/boundary cells. The dimetric
# 104×52 footprint hangs into the painted doorway as a magenta box even when
# the cell centre is outside the aperture; 40×20 keeps the tip sealed without
# that screen-space overhang into the green aperture.
PARTITION_CELL_RECT = (40.0, 20.0)


def cell_rect(x: float, y: float) -> tuple[float, float, float, float]:
    return (x - CELL_RECT[0] / 2, y - CELL_RECT[1] / 2, *CELL_RECT)


def partition_cell_rect(x: float, y: float) -> tuple[float, float, float, float]:
    return (
        x - PARTITION_CELL_RECT[0] / 2,
        y - PARTITION_CELL_RECT[1] / 2,
        *PARTITION_CELL_RECT,
    )


def partition_cell_rects() -> list[tuple[float, float, float, float]]:
    """Continuous partition barrier as overlapping tight AABBs; doorway open.

    Nav-cell centres sit ~72px apart along the NE diagonal. A 40×20 AABB only
    covers ~45px of that run, so one solid per cell left walkable gaps through
    the frosted glass. Sample densely in plan-b (and across wall thickness)
    so neighbouring AABBs overlap into a sealed barrier while the leaf-width
    door band stays clear.

    Latch-side solids are nudged slightly toward the tip so the first jamb
    AABB does not cover the green aperture mid-point.
    """
    rects = []
    a_face = P.a_line + P.thickness_a
    a_samples = (
        P.a_line + 0.008,
        P.a_line + P.thickness_a * 0.5,
        a_face - 0.008,
    )
    latch_nudge_b = 0.012
    # Keep frost sealed, but leave a hair more clear aperture than the painted
    # hole so segment-clear A* can cross the doorway cells. Without this pad,
    # 40×20 partition AABBs clip the (17,13)↔(18,13) corridor and split the
    # private office into disconnected components (chair-side start could not
    # reach the window/door after moving the nav root off the far side of the
    # desk). 0.01 plan-b ≈ one dense sample; leak checks still pass.
    door_clear_pad = 0.01
    # 0.015·|AXIS_NE| ≈ 12px; dense enough that 40×20 AABBs cover frost cells
    # (the old 0.025 step left a walkable glass cell at b≈0.686).
    b_step = 0.015
    b = -0.03
    while b <= rp.B_ROOM + 0.03:
        if (P.b_door0 - door_clear_pad) <= b <= (P.b_door1 + door_clear_pad):
            b += b_step
            continue
        bb = b + latch_nudge_b if b > P.b_door1 else b
        for a in a_samples:
            x, y = rp.authored(a, bb)
            rects.append(partition_cell_rect(x, y))
        b += b_step
    # Drop the one latch-side AABB whose centre seals the scaled search-map
    # doorway cell (officeDetective radius 3). Broadening door_clear_pad to
    # remove its whole b-band also strips neighbouring frost and lets client
    # arrival shortcut through prop AABBs.
    sealed_doorway_cell = (2288.0, 1134.0, 40.0, 20.0)
    return [
        r for r in rects
        if not (
            abs(r[0] - sealed_doorway_cell[0]) < 0.5
            and abs(r[1] - sealed_doorway_cell[1]) < 0.5
        )
    ]


# Walkable floor, in plan units: wall stand-off at the rear and sides, and the
# camera-near edge taken from the room's design boundary (`B_ROOM`), where the
# regenerated cutaway wall stands — not the plate's oversized painted floor.
FLOOR_A = (0.045, rp.A_ROOM - 0.045)
FLOOR_B = (0.040, rp.B_ROOM - 0.050)


def boundary_cell_rects() -> list[tuple[float, float, float, float]]:
    """Solids for every navigation cell outside the painted floor.

    Without these the 31x31 grid lets the detective walk through the rear walls
    and off the camera-near edge; the cutaway wall used to fake part of this with
    one screen-axis rectangle that no longer matches the wall's position.
    """
    rects = []
    for c in range(31):
        for r in range(31):
            x, y = cell_point(c, r)
            a, b = rp.authored_to_plan(x, y)
            if FLOOR_A[0] <= a <= FLOOR_A[1] and FLOOR_B[0] <= b <= FLOOR_B[1]:
                continue
            rects.append(cell_rect(x, y))
    return rects


def foreground_obstacle() -> tuple[float, float, float, float]:
    """One near-edge cell, kept as a named rect for the layout tests."""
    x, y = rp.authored(rp.A_ROOM * 0.45, rp.B_ROOM - 0.02)
    return cell_rect(x, y)


def partition_open_cells() -> list[tuple[int, int]]:
    """Nav cells that belong to the painted doorway corridor.

    Cell centres can sit slightly outside the exact door b-band while still
    covering the aperture; pad so tip-seal BFS treats them as the only gap.
    """
    open_cells = []
    a_mid = P.a_line + P.thickness_a / 2
    for c in range(31):
        for r in range(31):
            x, y = cell_point(c, r)
            a, b = rp.authored_to_plan(x, y)
            if abs(a - a_mid) < 0.08 and (P.b_door0 - 0.025) <= b <= (P.b_door1 + 0.025):
                open_cells.append((c, r))
    return open_cells


FOREGROUND_OBSTACLE = foreground_obstacle()

# Exterior door leaf sits closed inside the suite's baked opening.
# Obstacle tracks the painted clear opening (not the pre-cramped full-bleed door).
_door = rp.authored(*EXTERIOR_DOOR)
_door_hw = max(rp.BAKED_DOORWAY_W * 0.85, 40.0)
_door_hh = max(rp.BAKED_DOORWAY_H * 0.35, 36.0)
DOOR_OBSTACLE = (
    _door[0] - _door_hw,
    _door[1] - _door_hh,
    _door_hw * 2.0,
    _door_hh * 2.0,
)


# --------------------------------------------------------------- navigation


class Grid:
    """Mirror of NavigationGrid's dimetric projection for offline validation."""

    def __init__(self, obstacles, columns=31, rows=31, half_w=3.0 / ENV, half_h=0.0):
        self.columns, self.rows = columns, rows
        self.obstacles = [
            (x - half_w, y - half_h, w + 2 * half_w, h + 2 * half_h) for x, y, w, h in obstacles
        ]
        self.blocked = {
            (c, r) for c in range(columns) for r in range(rows) if self.inside(cell_point(c, r))
        }

    def cell(self, p):
        px = (p[0] - 2_048) / 64.0
        py = (p[1] - PROJECTION_ORIGIN_Y) / 32.0
        return (round((px + py) / 2), round((py - px) / 2))

    def inside(self, p):
        return any(x <= p[0] <= x + w and y <= p[1] <= y + h for x, y, w, h in self.obstacles)

    def walkable(self, c, r):
        return 0 <= c < self.columns and 0 <= r < self.rows and (c, r) not in self.blocked

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


def build_obstacles():
    rects = [DOOR_OBSTACLE, *boundary_cell_rects(), *partition_cell_rects()]
    rects += [p.obstacle_rect for p in PROPS if p.obstacle]
    return rects


# --------------------------------------------------------------- Swift emit


def pt(p) -> str:
    return f"CGPoint(x: {p[0]:_.0f}, y: {p[1]:_.0f})".replace("_", "_")


def precise_pt(p) -> str:
    return f"CGPoint(x: {p[0]:_.3f}, y: {p[1]:_.3f})"


def rect(r) -> str:
    return f"CGRect(x: {r[0]:.0f}, y: {r[1]:.0f}, width: {r[2]:.0f}, height: {r[3]:.0f})"


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
    add("        /// Window insert centre on the painted left-wall recess.")
    add(f"        static let windowAnchor = {precise_pt(window_anchor_authored())}")
    add(f"        /// Interior partition: one wall on the room's north-east axis (a = {P.a_line}),")
    add("        /// with a single framed doorway as the only connection between rooms.")
    add(f"        static let partitionLineA: CGFloat = {P.a_line}")
    add(f"        static let partitionThicknessA: CGFloat = {P.thickness_a}")
    add(f"        static let partitionDoorB0: CGFloat = {P.b_door0}")
    add(f"        static let partitionDoorB1: CGFloat = {P.b_door1}")
    add(f"        static let partitionReturnB1: CGFloat = {P.b_return1}")
    add(f"        static let wallThicknessPx: CGFloat = {rp.WALL_THICKNESS_PX:.1f}")
    add(f"        static let axisNW = CGVector(dx: {rp.AXIS_NW[0]:.1f}, dy: {rp.AXIS_NW[1]:.1f})")
    add(f"        static let axisNE = CGVector(dx: {rp.AXIS_NE[0]:.1f}, dy: {rp.AXIS_NE[1]:.1f})")
    add(f"        static let rearCorner = CGPoint(x: {rp.REAR[0]:.1f}, y: {rp.ART_H - rp.REAR[1]:.1f})")
    add("")
    add("        /// Partition plate geometry in shell art pixels (y down), so the scene can")
    add("        /// slice the painted wall into depth-sorted columns that sort like props")
    add("        /// standing on the wall's own ground line.")
    p0 = rp.plan(P.a_line + P.thickness_a, -P.overrun_b)
    p1 = rp.plan(P.a_line + P.thickness_a, rp.B_ROOM)
    add(f"        static let partitionPlateX0: CGFloat = {p0[0]:.0f}")
    add(f"        static let partitionPlateX1: CGFloat = {p1[0]:.0f}")
    add(f"        static let partitionPlateFaceHeight: CGFloat = {P.face_h:.0f}")
    add(
        f"        static let partitionPlateCapHeight: CGFloat = "
        f"{abs(rp.CAP_DEPTH_FRAC * P.thickness_a * rp.AXIS_NW[1]) + 4:.0f}"
    )
    add("")
    add("        /// Ground line of the partition face at a shell-art x (y down).")
    add("        static func partitionPlateBaseY(atPlateX x: CGFloat) -> CGFloat {")
    add(f"            {p0[1]:.1f} + (x - {p0[0]:.0f}) * {rp.AXIS_NE[1] / rp.AXIS_NE[0]:.4f}")
    add("        }")
    add("")
    add("        /// Clear exterior opening measured from the shipping suite plate.")
    add(
        f"        static let entranceOpeningPlateSize = "
        f"CGSize(width: {SHIPPING_EXTERIOR_OPENING_SIZE[0]:.3f}, "
        f"height: {SHIPPING_EXTERIOR_OPENING_SIZE[1]:.1f})"
    )
    add(
        f"        static let entranceOpeningToDetectiveRatio: CGFloat = "
        f"{SHIPPING_EXTERIOR_OPENING_SIZE[1] / BODY:.2f}"
    )
    add(
        f"        static let entranceHandleHeightToDetective: CGFloat = "
        f"{rp.DOOR_HANDLE_TO_DETECTIVE:.3f}"
    )
    add("")
    add("        /// Exterior leaf/frame projected onto the sloped NE wall opening.")
    add("        /// Uniform height-fit (keeps sheared master aspect; no X-squash).")
    add(f"        static let entranceLeafDisplayScale: CGFloat = {exterior_leaf_scale():.4f}")
    add("        static let entranceLeafDisplayScaleX: CGFloat = entranceLeafDisplayScale")
    add("        static let entranceLeafDisplayScaleY: CGFloat = entranceLeafDisplayScale")
    add(f"        static let entranceLeafAnchorY: CGFloat = {exterior_leaf_anchor_y():.5f}")
    add(f"        static let entranceLeafAnchor = {precise_pt(exterior_leaf_anchor_authored())}")
    add(f"        static let entranceFrameDisplayScale: CGFloat = {exterior_frame_scale():.4f}")
    add("        static let entranceFrameDisplayScaleX: CGFloat = entranceFrameDisplayScale")
    add("        static let entranceFrameDisplayScaleY: CGFloat = entranceFrameDisplayScale")
    add(f"        static let entranceFrameAnchorX: CGFloat = {exterior_frame_anchor_x():.5f}")
    add(f"        static let entranceFrameAnchorY: CGFloat = {exterior_frame_anchor_y():.5f}")
    add("        /// Floor-projected presentation used after the leaf breaks free.")
    add("        static let entranceFallenLeafScaleRatio: CGFloat = 0.92")
    add("        /// The upright art grows slightly as its top swings toward the camera.")
    add("        /// This is only the transition silhouette; the landed art has an")
    add("        /// explicit world-space size below.")
    add("        static let entranceFallingTransitionScale: CGFloat = 0.17")
    add("        /// Purpose-built 768×512 landed-state art. The transparent source")
    add("        /// canvas stays centered so this scale yields a ~98×81 point door body.")
    add("        static let entranceFallenArtworkCanvasSize = CGSize(width: 768, height: 512)")
    add("        static let entranceFallenArtworkDisplayScale: CGFloat = 0.17")
    add("        static let entranceFallenArtworkDisplaySize = CGSize(")
    add("            width: entranceFallenArtworkCanvasSize.width")
    add("                * entranceFallenArtworkDisplayScale,")
    add("            height: entranceFallenArtworkCanvasSize.height")
    add("                * entranceFallenArtworkDisplayScale")
    add("        )")
    add("        /// Internal open leaf registered to the shipping partition hinge.")
    add(f"        static let internalHingePlateX: CGFloat = {SHIPPING_INTERNAL_HINGE_X:.1f}")
    add(
        f"        static let internalHingePlateHeight: CGFloat = "
        f"{SHIPPING_INTERNAL_HINGE_BOTTOM_Y - SHIPPING_INTERNAL_HINGE_TOP_Y:.1f}"
    )
    # Leaf scale keeps the validated fit; anchor is solved from the measured
    # clear-aperture hinge jamb so the open leaf tracks the painted frame.
    add("        /// Height-fit to `internalHingePlateHeight` × environment / hinge texture.")
    add("        static let internalLeafDisplayScale: CGFloat = 0.1726")
    leaf_x, leaf_y = internal_door_leaf_anchor()
    add(f"        static let internalLeafAnchor = CGPoint(x: {leaf_x:.3f}, y: {leaf_y:.3f})")
    add("    }")
    add("")
    add("    /// Walkable chair-side stand point (camera-near of the kneehole).")
    add("    /// Kept outside the desk obstacle so leave-seat never starts on the")
    add("    /// visitor/rear side of the writing surface.")
    add("    private static let authoredActorStart = CGPoint(")
    add("        x: AuthoredPlacement.deskChair.x,")
    offset_y = ACTOR_START_OFFSET_Y
    if offset_y < 0:
        add(f"        y: AuthoredPlacement.deskChair.y - {abs(offset_y):.0f}")
    else:
        add(f"        y: AuthoredPlacement.deskChair.y + {offset_y:.0f}")
    add("    )")
    add("")

    # ---- obstacles
    named = [(p.key, p.obstacle_rect) for p in PROPS if p.obstacle]
    add("    // MARK: - Obstacles (authored AABBs around each floor footprint)")
    add("")
    add("    /// One cell of the camera-near boundary, kept named for the layout tests.")
    add(f"    static let authoredForegroundWallObstacle = {rect(FOREGROUND_OBSTACLE)}")
    add(f"    static let authoredDoorObstacle = {rect(DOOR_OBSTACLE)}")
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
    add("    /// Partition solids: overlapping tight AABBs along the wall; doorway open.")
    add(f"    static let authoredPartitionWallNorthObstacle = {rect(part[0])}")
    add(f"    static let authoredPartitionWallSouthObstacle = {rect(part[-1])}")
    add("    static let authoredPartitionSegments: [CGRect] = [")
    for r in part:
        add(f"        {rect(r)},")
    add("    ]")
    add("")
    for key, r in named:
        add(f"    static let authored{key[0].upper()}{key[1:]}Obstacle = {rect(r)}")
    add("")
    add("    private static var authoredObstacles: [CGRect] {")
    add("        [authoredDoorObstacle, authoredForegroundWallObstacle]")
    add("            + authoredBoundarySegments")
    add("            + authoredPartitionSegments")
    add("            + [")
    for key, _ in named:
        add(f"                authored{key[0].upper()}{key[1:]}Obstacle,")
    add("            ]")
    add("    }")
    add("")

    # ---- sample points
    add("    // MARK: - Sample points (interior to each obstacle)")
    add("")
    sample_sets = [(key, r) for key, r in named]
    sample_sets.append(("doorLeaf", DOOR_OBSTACLE))
    sample_sets.append(("foregroundWall", FOREGROUND_OBSTACLE))
    sample_sets.append(("partitionWallNorth", part[0]))
    sample_sets.append(("partitionWallSouth", part[-1]))
    for key, r in sample_sets:
        add(f"    static let authored{key[0].upper()}{key[1:]}SamplePoints: [CGPoint] = [")
        for s in samples(r):
            add(f"        {pt(s)},")
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
    rain_w = 76.0 * rp.SUITE_PLATE_SCALE
    rain_h = 136.0 * rp.SUITE_PLATE_SCALE
    add(
        "        static let windowRainMask = CGRect("
        f"x: {wx - rain_w * 0.5:_.1f}, y: {wy - rain_h * 0.5:_.1f}, "
        f"width: {rain_w:_.1f}, height: {rain_h:_.1f})"
    )
    add(f"        static let windowRainEmitter = CGPoint(x: {wx:_.1f}, y: {wy + 72.0 * rp.SUITE_PLATE_SCALE:_.1f})")
    add("        /// Recentred on the fitted cramped room diamond.")
    add(f"        static let camera = {pt(camera_authored())}")
    add("")
    for prop in PROPS:
        note = f"  // {prop.note}" if prop.note else ""
        add(f"        static let {prop.key} = {pt(prop.authored)}{note}")
    add("")
    add(f"        static let wornRug = {pt(rp.authored(*RUG))}")
    add("        static let floorWear = deskEnsemble")
    for key, plate in WALL_ART.items():
        add(f"        static let {key} = {pt((plate[0], rp.ART_H - plate[1]))}")
    for key, plate in FLOOR_DECALS.items():
        if plate is None:
            continue
        add(f"        static let {key} = {pt((plate[0], rp.ART_H - plate[1]))}")
    add("        static let lampPool = deskEnsemble")
    add("        /// Leaf swung 90° into the private office, hinged on the up-run jamb.")
    add("        static let internalDoorLeaf = Architecture.internalLeafAnchor")
    add("    }")
    add("")

    # ---- approach points, paths
    add("    private static let authoredApproachPoints: [String: CGPoint] = [")
    for name, (a, b) in APPROACH.items():
        add(f'        "{name}": {pt(rp.authored(a, b))},')
    add("    ]")
    add("")
    # The dimetric grid is registered to the same floor plane as the props.
    # Moving the rear floor seam down by 121 plate pixels moves authored y-up
    # coordinates down by the same amount; keep grid cells stable with it.
    add(
        "    private static let authoredProjectionOrigin = "
        f"CGPoint(x: 2_048, y: {PROJECTION_ORIGIN_Y:_.0f})"
    )
    add("    private static let authoredTileSize = CGSize(width: 128, height: 64)")
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
    add("    /// outside the navigation floor and passes through the fallen door leaf.")
    add("    static let clientDoorwayPath: [CGPoint] = [")
    for point in CLIENT_DOORWAY_PATH:
        add(f"        {pt(point)},")
    add("    ].map(OfficeInteriorScale.mapPoint)")
    add("")
    add("    /// Walkable waiting-room anchors, ending immediately before the")
    add("    /// framed internal doorway in the production suite plate.")
    add("    static let clientWaitingRoomPath: [CGPoint] = [")
    for point in CLIENT_WAITING_ROOM_PATH:
        add(f"        {pt(point)},")
    add("    ].map(OfficeInteriorScale.mapPoint)")
    add("")
    add("    /// Explicit crossing through the real framed partition aperture.")
    add("    static let clientInternalDoorwayPath: [CGPoint] = [")
    for point in CLIENT_INTERNAL_DOORWAY_PATH:
        add(f"        {pt(point)},")
    add("    ].map(OfficeInteriorScale.mapPoint)")
    add("")
    add("    /// Direct private-office approach after clearing the internal door.")
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
    add("    /// Authored aperture polyline through the shipping painted doorway.")
    add("    /// Do not A*-expand: snapping interior anchors onto nearest walkable")
    add("    /// cells can walk the coat through frosted glass beside the real opening.")
    add("    /// Anchors are collision-checked at layout generation.")
    add("    static func clientArrivalRoute(in navigation: NavigationGrid) -> [CGPoint] {")
    add("        _ = navigation")
    add("        return clientArrivalPath")
    add("    }")
    add("")
    add("    static func clientDepartureRoute(in navigation: NavigationGrid) -> [CGPoint] {")
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
    for key, _ in named:
        upper = f"{key[0].upper()}{key[1:]}"
        add(f"    static var {key}Obstacle: CGRect {{ OfficeInteriorScale.mapRect(authored{upper}Obstacle) }}")
    add("    static var doorObstacle: CGRect { OfficeInteriorScale.mapRect(authoredDoorObstacle) }")
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
    add("")
    add("    static var majorPropSamplePoints: [CGPoint] {")
    add("        " + "\n            + ".join([f"{key}SamplePoints" for key, _ in sample_sets]))
    add("    }")
    add("")
    add("    static var approachPoints: [String: CGPoint] {")
    add("        authoredApproachPoints.mapValues(OfficeInteriorScale.mapPoint)")
    add("    }")
    add("")
    add("    /// Actual Voss stand-ins for architecture scale review: exterior door,")
    add("    /// desk, internal doorway, and waiting chair.")
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


DEPTH_PROP_ANCHOR_Y = 0.04  # matches `addDepthProp` in DetectiveOfficeScene


def exterior_leaf_anchor_authored() -> tuple[float, float]:
    """Authored node anchor registered to the shipping exterior threshold."""
    x, y_down = SHIPPING_EXTERIOR_THRESHOLD
    return (x, rp.ART_H - y_down)


def internal_door_leaf_anchor() -> tuple[float, float]:
    """Authored node anchor for the shipping plate's open internal leaf."""
    with Image.open(ART / "office_internal_door_leaf.png") as im:
        w, h = im.size
        alpha = np.asarray(im.convert("RGBA"))[:, :, 3]

    hinge_ys = np.where(alpha[:, w - 1] > 16)[0]
    if len(hinge_ys):
        content_h = float(hinge_ys.max() - hinge_ys.min() + 1)
        hinge_bottom_row = float(hinge_ys.max() + 1)
    else:
        content_h = float(h)
        hinge_bottom_row = float(h)

    hinge_height = SHIPPING_INTERNAL_HINGE_BOTTOM_Y - SHIPPING_INTERNAL_HINGE_TOP_Y
    plate_scale = hinge_height / max(content_h, 1.0)
    # `addDepthProp` keeps its shared (0.5, 0.04) anchor. Solve the node
    # position so the texture's right-edge alpha run lands exactly on the
    # measured hinge jamb.
    anchor_x = SHIPPING_INTERNAL_HINGE_X - (0.5 * w) * plate_scale
    anchor_y_down = SHIPPING_INTERNAL_HINGE_BOTTOM_Y + (
        (1.0 - DEPTH_PROP_ANCHOR_Y) * h - hinge_bottom_row
    ) * plate_scale
    return (
        anchor_x,
        rp.ART_H - anchor_y_down,
    )


def _flood_frame_inner(alpha: np.ndarray, thr: int = 16) -> np.ndarray:
    """Transparent frame aperture connected to the texture centre."""
    h, w = alpha.shape
    vis = np.zeros((h, w), dtype=bool)
    cy, cx = h // 2, w // 2
    q: deque[tuple[int, int]] = deque()
    if alpha[cy, cx] < thr:
        q.append((cy, cx))
        vis[cy, cx] = True
    else:
        found = False
        for radius in range(1, max(h, w) // 2):
            for dy in range(-radius, radius + 1):
                for dx in range(-radius, radius + 1):
                    y, x = cy + dy, cx + dx
                    if 0 <= y < h and 0 <= x < w and alpha[y, x] < thr:
                        q.append((y, x))
                        vis[y, x] = True
                        found = True
                        break
                if found:
                    break
            if found:
                break
    while q:
        y, x = q.popleft()
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not vis[ny, nx] and alpha[ny, nx] < thr:
                vis[ny, nx] = True
                q.append((ny, nx))
    return vis


def _vertical_run(mask: np.ndarray, x: int) -> tuple[float, int, int]:
    ys = np.where(mask[:, x])[0]
    if len(ys) == 0:
        return 0.0, 0, 0
    return float(ys.max() - ys.min() + 1), int(ys.min()), int(ys.max())


def exterior_leaf_scale() -> float:
    """Uniform fit: live leaf centre run → shipping exterior opening.

    Non-uniform X stretch made the door too wide and short; keep aspect of the
    sheared master and centre it on the painted aperture.
    """
    alpha = np.asarray(Image.open(ART / "office_door_leaf.png").convert("RGBA"))[:, :, 3]
    content_h, _, _ = _vertical_run(alpha > 16, alpha.shape[1] // 2)
    return SHIPPING_EXTERIOR_OPENING_SIZE[1] * ENV / max(content_h, 1.0)


def exterior_leaf_scale_x() -> float:
    return exterior_leaf_scale()


def exterior_leaf_scale_y() -> float:
    return exterior_leaf_scale()


def exterior_leaf_anchor_y() -> float:
    """SpriteKit anchor that places the projected leaf's centre threshold at plan."""
    alpha = np.asarray(Image.open(ART / "office_door_leaf.png").convert("RGBA"))[:, :, 3]
    _, _, bottom = _vertical_run(alpha > 16, alpha.shape[1] // 2)
    return 1.0 - (bottom + 1.0) / max(float(alpha.shape[0]), 1.0)


def exterior_frame_scale() -> float:
    """Uniform fit: legacy frame inner aperture → shipping clear opening."""
    path = ART / "office_door_frame.png"
    if not path.exists():
        return exterior_leaf_scale()
    alpha = np.asarray(Image.open(path).convert("RGBA"))[:, :, 3]
    vis = _flood_frame_inner(alpha)
    iys, ixs = np.where(vis)
    if len(iys) == 0:
        ys, _ = np.where(alpha > 16)
        content_h = float(ys.max() - ys.min() + 1) if len(ys) else 1.0
        return SHIPPING_EXTERIOR_OPENING_SIZE[1] * ENV / content_h
    inner_cx = int(round((ixs.min() + ixs.max()) * 0.5))
    inner_h, _, _ = _vertical_run(vis, inner_cx)
    return SHIPPING_EXTERIOR_OPENING_SIZE[1] * ENV / max(inner_h, 1.0)


def exterior_frame_scale_x() -> float:
    return exterior_frame_scale()


def exterior_frame_scale_y() -> float:
    return exterior_frame_scale()


def exterior_frame_anchor_x() -> float:
    """Sprite anchor that centres the asymmetric frame's inner aperture."""
    path = ART / "office_door_frame.png"
    if not path.exists():
        return 0.5
    alpha = np.asarray(Image.open(path).convert("RGBA"))[:, :, 3]
    inner = _flood_frame_inner(alpha)
    _, ixs = np.where(inner)
    if len(ixs) == 0:
        return 0.5
    # Convert pixel-centre bounds to the aperture's centre in texture-edge
    # coordinates, which is the coordinate system used by SKSpriteNode anchors.
    inner_center_x = (float(ixs.min()) + float(ixs.max()) + 1.0) * 0.5
    return inner_center_x / max(float(alpha.shape[1]), 1.0)


def exterior_frame_anchor_y() -> float:
    """SpriteKit anchor that places the frame aperture threshold at plan."""
    path = ART / "office_door_frame.png"
    if not path.exists():
        return exterior_leaf_anchor_y()
    alpha = np.asarray(Image.open(path).convert("RGBA"))[:, :, 3]
    inner = _flood_frame_inner(alpha)
    iys, ixs = np.where(inner)
    if len(iys) == 0:
        return exterior_leaf_anchor_y()
    inner_cx = int(round((ixs.min() + ixs.max()) * 0.5))
    _, _, bottom = _vertical_run(inner, inner_cx)
    return 1.0 - (bottom + 1.0) / max(float(alpha.shape[0]), 1.0)


def internal_leaf_scale() -> float:
    """Fit the open leaf's right-edge hinge run to the shipping jamb."""
    alpha = np.asarray(Image.open(ART / "office_internal_door_leaf.png").convert("RGBA"))[:, :, 3]
    hinge_x = alpha.shape[1] - 1
    content_h, _, _ = _vertical_run(alpha > 16, hinge_x)
    if content_h < 1.0:
        ys = np.where(alpha > 16)[0]
        content_h = float(ys.max() - ys.min() + 1) if len(ys) else 1.0
    hinge_height = SHIPPING_INTERNAL_HINGE_BOTTOM_Y - SHIPPING_INTERNAL_HINGE_TOP_Y
    return hinge_height * ENV / max(content_h, 1.0)


# The exterior doorway segment cannot be sent through NavigationGrid: its first
# point is deliberately outside the floor boundary and the static grid still
# contains the closed door-leaf obstacle. Keep this short segment authored
# through the painted opening, then hand off to routed interior anchors.
CLIENT_DOORWAY_PLAN_PATH = [
    (-0.080, EXTERIOR_DOOR[1]),  # outside, centred on the painted threshold
    (0.200, EXTERIOR_DOOR[1]),  # inside and clear of the fallen leaf / umbrella stand
]
CLIENT_DOORWAY_PATH = [rp.authored(a, b) for a, b in CLIENT_DOORWAY_PLAN_PATH]

# Cross the live clear aperture mid (≈ 0.776). Exact polyline (no A*).
CLIENT_INTERNAL_DOOR_B = 0.776
CLIENT_INTERNAL_DOORWAY_PLAN_PATH = [
    (P.a_line - 0.070, CLIENT_INTERNAL_DOOR_B),
    (P.a_line + P.thickness_a / 2, CLIENT_INTERNAL_DOOR_B),
    (P.a_line + P.thickness_a + 0.060, CLIENT_INTERNAL_DOOR_B),
]
CLIENT_INTERNAL_DOORWAY_PATH = [
    rp.authored(a, b) for a, b in CLIENT_INTERNAL_DOORWAY_PLAN_PATH
]

# The actor body is wider than its navigation contact core. Keep the waiting
# leg in the aisle between the chair backs and the partition (a ≈ 0.27) so the
# coat does not clip the exterior wall, then drop to the live aperture mid.
# CLIENT_WAITING_ROOM_PATH then hands off to CLIENT_INTERNAL_DOORWAY_PATH[0].
CLIENT_WAITING_CLEARANCE_PLAN_PATH = [
    (0.270, 0.790),  # aisle: clear of coat rack / exterior wall
    (0.270, CLIENT_INTERNAL_DOOR_B),  # drop to aperture b while still in aisle
]
CLIENT_WAITING_ROOM_PATH = [
    CLIENT_DOORWAY_PATH[-1],
    *[
        rp.authored(a, b)
        for a, b in CLIENT_WAITING_CLEARANCE_PLAN_PATH
    ],
    CLIENT_INTERNAL_DOORWAY_PATH[0],
]

# Keep the desk's seated front-apron layer above Voss's lower body but below
# Lila while she is on the camera-near side. The old +55 bias covered her head
# and torso, which made the otherwise clear ground route read as desk clipping.
VISITOR_CHAIR_BIAS = -50.0
SEATED_DESK_FRONT_APRON_BIAS = 15.0

# Visitor stop just inside the painted doorway; hold aperture b until clear of
# the partition so a diagonal cannot clip latch frost.
CLIENT_OFFICE_ARRIVAL_PATH = [
    CLIENT_INTERNAL_DOORWAY_PATH[-1],
    rp.authored(0.560, CLIENT_INTERNAL_DOOR_B),
]
CLIENT_INTERIOR_PATH = [
    *CLIENT_WAITING_ROOM_PATH,
    *CLIENT_INTERNAL_DOORWAY_PATH[1:],
    *CLIENT_OFFICE_ARRIVAL_PATH[1:],
]
CLIENT_PATH = [*CLIENT_DOORWAY_PATH[:-1], *CLIENT_INTERIOR_PATH]

SCALE_STANDS = [
    (0.080, EXTERIOR_DOOR[1]),  # directly beside the exterior doorway
    (0.680, 0.380),  # behind the desk
    (0.400, (P.b_door0 + P.b_door1) * 0.5),  # in the internal doorway
    (0.170, 0.600),  # beside the waiting chair
]

RECORDS_PATH = [
    (0.660, 0.300),
    (0.720, 0.200),
    (0.755, 0.160),
]

HOTSPOTS_SWIFT = '''    static let authoredHotspots: [(id: String, name: String, hitArea: CGRect, observation: String)] = [
        (
            "office.window",
            "Rain-streaked window",
            CGRect(x: 1_174, y: 1_758, width: 92, height: 160),
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

    /// Tall aperture covering the entrance leaf and threshold obstacle.
    private static var doorHitArea: CGRect {
        CGRect(x: 2_480, y: 1_180, width: 240, height: 480)
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

    /// - Parameter entranceDoorBlocking: When false, the upright exterior leaf
    ///   obstacle is omitted (door has fallen / opening is clear).
    static func makeGrid(entranceDoorBlocking: Bool = true) -> NavigationGrid {
        let gridObstacles: [CGRect]
        if entranceDoorBlocking {
            gridObstacles = obstacles
        } else {
            let door = doorObstacle
            gridObstacles = obstacles.filter { $0 != door }
        }
        return NavigationGrid(
            projection: .dimetric(
                origin: OfficeInteriorScale.mapPoint(authoredProjectionOrigin),
                tileSize: OfficeInteriorScale.mapSize(authoredTileSize)
            ),
            columns: 31,
            rows: 31,
            obstacles: gridObstacles,
            agentProfile: .officeDetective
        )
    }

    static func isBlocked(_ point: CGPoint) -> Bool {
        obstacles.contains { $0.contains(point) }
    }
}
'''


# --------------------------------------------------------------- report


def report() -> bool:
    for prop in PROPS:
        prop.measure()

    print(f"=== scale review (rendered height / character body, body = {BODY:.2f} plate px) ===")
    for prop in sorted((p for p in PROPS if p.body), key=lambda p: -p.body):
        w, h = prop.plate_size
        print(
            f"  {prop.key:22s} {prop.art:28s} body={prop.body:4.2f} "
            f"plate={w:5.0f}x{h:5.0f} displayScale={prop.display_scale:.4f}"
        )

    obstacles = build_obstacles()
    grid = Grid(obstacles)
    chair = PROP_BY_KEY["deskChair"].authored
    start = (chair[0], chair[1] + ACTOR_START_OFFSET_Y)
    start_cell = grid.cell(start)
    reach = grid.reachable(start_cell)

    print("\n=== navigation ===")
    print(f"  obstacles={len(obstacles)} partition solids={len(partition_cell_rects())}")
    print(
        f"  actorStart authored={start[0]:.0f},{start[1]:.0f} cell={start_cell} "
        f"walkable={grid.walkable(*start_cell)} reachable={len(reach)} cells"
    )
    ok = grid.walkable(*start_cell)
    for name, (a, b) in APPROACH.items():
        cell = grid.cell(rp.authored(a, b))
        good = cell in reach
        ok &= good
        print(f"  {name:15s} plan=({a:.3f},{b:.3f}) cell={cell} reachable={good}")

    door_cells = partition_open_cells()
    door_ok = [c in reach for c in door_cells]
    print(f"  doorway cells={door_cells} reachable={door_ok}")
    waiting = [c for c in reach if rp.authored_to_plan(*cell_point(*c))[0] < P.a_line]
    print(f"  waiting-side cells reachable={len(waiting)}")

    # Open-floor share: reachable cells against every cell inside the room's
    # design boundary (walls, partition, furniture included). A cramped office
    # should keep roughly 20-35% of the visible room as open walkable floor.
    room_cells = [
        (c, r)
        for c in range(31)
        for r in range(31)
        if 0.0 <= rp.authored_to_plan(*cell_point(c, r))[0] <= rp.A_ROOM
        and 0.0 <= rp.authored_to_plan(*cell_point(c, r))[1] <= rp.B_ROOM
    ]
    open_share = len(reach) / max(len(room_cells), 1)
    print(f"  open floor: {len(reach)}/{len(room_cells)} room cells = {open_share:.0%}")
    doorway_ok = (
        CLIENT_DOORWAY_PLAN_PATH[0][0] < 0.0 < CLIENT_DOORWAY_PLAN_PATH[-1][0]
        and all(EXTERIOR_DOOR[1] - rp.EXTERIOR_DOOR_OPENING_B / 2
                <= b
                <= EXTERIOR_DOOR[1] + rp.EXTERIOR_DOOR_OPENING_B / 2
                for _, b in CLIENT_DOORWAY_PLAN_PATH)
    )
    ok &= doorway_ok
    print(f"  client exterior doorway crossing valid={doorway_ok}")
    for label, routed_path in (
        ("waiting", CLIENT_WAITING_ROOM_PATH),
        ("office", CLIENT_OFFICE_ARRIVAL_PATH),
    ):
        for point in routed_path:
            cell = grid.cell(point)
            good = cell in reach
            ok &= good
            print(f"  client {label:7s} authored=({point[0]:.0f},{point[1]:.0f}) "
                  f"cell={cell} reachable={good}")
    # Cell centres can be walkable while the anchor itself still sits inside a
    # neighbouring solid; the runtime tests point-test the rects, so do the same.
    inside = [
        point
        for point in CLIENT_PATH[1:]
        if any(
            x <= point[0] <= x + w and y <= point[1] <= y + h
            for x, y, w, h in obstacles
        )
    ]
    anchors_clear = not inside
    ok &= anchors_clear
    print(f"  client anchors clear of solid rects={anchors_clear} inside={len(inside)}")

    internal_plans = [
        rp.authored_to_plan(*point) for point in CLIENT_INTERNAL_DOORWAY_PATH
    ]
    internal_door_ok = (
        internal_plans[0][0] < P.a_line
        and P.a_line < internal_plans[1][0] < P.a_line + P.thickness_a
        and internal_plans[2][0] > P.a_line + P.thickness_a
        and all(P.b_door0 < b < P.b_door1 for _, b in internal_plans)
    )
    ok &= internal_door_ok
    print(
        "  client production internal doorway crossing "
        f"valid={internal_door_ok} b={internal_plans[1][1]:.3f}"
    )

    # Lila's navigation root is narrower than her rendered coat and shoulders.
    # Hold the aisle between chair backs and partition, then enter on aperture b.
    waiting_clearance_ok = (
        len(CLIENT_WAITING_CLEARANCE_PLAN_PATH) >= 2
        and all(
            0.260 <= a <= P.a_line - 0.110
            for a, _ in CLIENT_WAITING_CLEARANCE_PLAN_PATH
        )
        and CLIENT_WAITING_CLEARANCE_PLAN_PATH[0][1] >= P.door_mid_b
        and abs(CLIENT_WAITING_CLEARANCE_PLAN_PATH[-1][1] - CLIENT_INTERNAL_DOOR_B) < 0.001
        and P.b_door0 <= CLIENT_WAITING_CLEARANCE_PLAN_PATH[-1][1] <= P.b_door1
    )
    ok &= waiting_clearance_ok
    print(
        "  client chair-side body clearance "
        f"valid={waiting_clearance_ok}"
    )

    # Once through the painted partition door, the visitor stop is one short
    # leg away on the office side of the aperture.
    office_plans = [
        rp.authored_to_plan(*point) for point in CLIENT_OFFICE_ARRIVAL_PATH
    ]
    door_exit_b = rp.authored_to_plan(*CLIENT_INTERNAL_DOORWAY_PATH[-1])[1]
    office_direct_ok = (
        len(office_plans) == 2
        and office_plans[-1][0] > P.a_line + P.thickness_a
        and max(a for a, _ in office_plans) <= 0.58
        and abs(office_plans[-1][1] - door_exit_b) <= 0.25
    )
    ok &= office_direct_ok
    print(
        "  client direct office approach "
        f"valid={office_direct_ok} anchors={len(office_plans)}"
    )

    # Rooms must not connect around the partition tip — only through the door.
    door_cells = set(partition_open_cells())
    waiting_seed = grid.cell(CLIENT_WAITING_ROOM_PATH[1])
    seen = {waiting_seed}
    queue = deque([waiting_seed])
    while queue:
        c, r = queue.popleft()
        for dc in (-1, 0, 1):
            for dr in (-1, 0, 1):
                if dc == dr == 0:
                    continue
                n = (c + dc, r + dr)
                if n in seen or not grid.walkable(*n) or n in door_cells:
                    continue
                if dc and dr and not (
                    grid.walkable(c + dc, r) and grid.walkable(c, r + dr)
                ):
                    continue
                seen.add(n)
                queue.append(n)
    a_mid = P.a_line + P.thickness_a / 2
    office_leaks = 0
    for c, r in seen:
        x, y = cell_point(c, r)
        a, _ = rp.authored_to_plan(x, y)
        if a > a_mid + 0.02:
            office_leaks += 1
    sealed_ok = office_leaks == 0
    ok &= sealed_ok
    print(f"  partition tip sealed (no office leak without door)={sealed_ok}")
    ok &= any(door_ok) and len(waiting) > 15
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

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
    Prop("personalWashbasin", "office_personal_washbasin", 0.485, FLUSH, 0.41, (0.7, 0.5)),
    Prop("personalFan", "office_personal_fan", 0.410, 0.080, 0.68, (0.5, 0.5)),
    Prop("personalBottle", "office_hidden_bottle", 0.438, FLUSH + 0.004, 0.22, obstacle=False, note="on sideboard"),
    Prop("personalGlass", "office_personal_glass", 0.420, FLUSH + 0.004, 0.10, obstacle=False, note="on sideboard"),
    # ---- desk cluster: private office, on the floor boards
    Prop("deskEnsemble", "office_desk_bare", 0.600, 0.380, 0.99, (1.7, 0.9)),
    Prop("deskChair", "office_desk_chair", 0.675, 0.380, 0.64, (0.6, 0.6), obstacle=False),
    # Footprint tightened so Lila can stand at the visitor side without being
    # forced into the empty rear-wall band (segment-clear cells at b≈0.22 only).
    Prop("visitorArmchair", "office_visitor_armchair", 0.500, 0.310, 0.79, (0.65, 0.65)),
    Prop("visitorArmchairB", "office_visitor_armchair", 0.500, 0.450, 0.76, (0.65, 0.65)),
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
    "caseBoard": _wall_art_plate(0.75, FLUSH, 100.0),
    "wallCityMap": _wall_art_plate(0.69, FLUSH, 120.0),
    "wallPhotos": _wall_art_plate(0.83, FLUSH, 90.0),
}

FLOOR_DECALS = {
    "windowSpill": rp.plan(WINDOW_A, 0.10),
    "blindStripes": rp.plan(WINDOW_A + 0.04, 0.16),
    "hallwayLight": rp.plan(0.02, EXTERIOR_DOOR[1]),
    "lampPool": None,  # follows the desk
}

APPROACH = {
    "office.window": (WINDOW_A, 0.120),
    "office.desk": (0.540, 0.520),
    "office.phone": (0.580, 0.520),
    "office.files": (0.755, 0.160),
    "office.door": (0.120, 0.540),  # waiting corridor; segment-clear from desk start
}

# Seated nav root = deskChair + seatedYOffset/environment (82/0.395 ≈ 208).
ACTOR_START_OFFSET = 208.0


# --------------------------------------------------------------- architecture


# Keep the dimetric grid locked to the floor plane as REAR moves.
# 597.1 is the pre-correction plaster/wainscot rail y-down (legacy reference).
_LEGACY_RAIL_Y = 597.1
PROJECTION_ORIGIN_Y = 310.0 - (rp.REAR[1] - _LEGACY_RAIL_Y)


def cell_point(c: int, r: int) -> tuple[float, float]:
    return (2_048 + (c - r) * 64, PROJECTION_ORIGIN_Y + (c + r) * 32)


CELL_RECT = (104.0, 52.0)  # slightly inset from the 128x64 cell so corners pass


def cell_rect(x: float, y: float) -> tuple[float, float, float, float]:
    return (x - CELL_RECT[0] / 2, y - CELL_RECT[1] / 2, *CELL_RECT)


def partition_cell_rects() -> list[tuple[float, float, float, float]]:
    """Per-cell solids along the partition, leaving the doorway open."""
    rects = []
    a0 = P.a_line - 0.010
    a1 = P.a_line + P.thickness_a + 0.010
    for c in range(31):
        for r in range(31):
            x, y = cell_point(c, r)
            a, b = rp.authored_to_plan(x, y)
            if not (a0 <= a <= a1 and -0.03 <= b <= rp.B_ROOM + 0.03):
                continue
            if P.b_door0 - 0.012 <= b <= P.b_door1 + 0.012:
                continue
            rects.append(cell_rect(x, y))
    return rects


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
    open_cells = []
    for c in range(31):
        for r in range(31):
            x, y = cell_point(c, r)
            a, b = rp.authored_to_plan(x, y)
            if abs(a - (P.a_line + P.thickness_a / 2)) < 0.05 and P.b_door0 <= b <= P.b_door1:
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
    add("        /// Clear doorway size, derived from the shipped detective silhouette.")
    add(
        f"        static let entranceOpeningPlateSize = "
        f"CGSize(width: {rp.BAKED_DOORWAY_W:.3f}, height: {rp.BAKED_DOORWAY_H:.1f})"
    )
    add(
        f"        static let entranceOpeningToDetectiveRatio: CGFloat = "
        f"{rp.DOOR_OPENING_TO_DETECTIVE:.2f}"
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
    add(f"        static let entranceFrameDisplayScale: CGFloat = {exterior_frame_scale():.4f}")
    add("        static let entranceFrameDisplayScaleX: CGFloat = entranceFrameDisplayScale")
    add("        static let entranceFrameDisplayScaleY: CGFloat = entranceFrameDisplayScale")
    add(f"        static let entranceFrameAnchorX: CGFloat = {exterior_frame_anchor_x():.5f}")
    add(f"        static let entranceFrameAnchorY: CGFloat = {exterior_frame_anchor_y():.5f}")
    add("        /// Floor-projected presentation used after the leaf breaks free.")
    add("        static let entranceFallenLeafScaleRatio: CGFloat = 0.92")
    add("        /// Internal sheared leaf fitted to partition clear opening height.")
    add(f"        static let internalLeafDisplayScale: CGFloat = {internal_leaf_scale():.4f}")
    add("    }")
    add("")
    add("    private static let authoredActorStart = CGPoint(")
    add("        x: AuthoredPlacement.deskChair.x,")
    add(f"        y: AuthoredPlacement.deskChair.y + {ACTOR_START_OFFSET:.0f}")
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
    mid = len(part) // 2
    add("    /// Partition solids, one per navigation cell, doorway cells omitted.")
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
    add("        /// Lowered beneath the sloped header so the complete top rail and")
    add("        /// a narrow dark reveal remain visible instead of reading as clipped.")
    add("        static let doorLeaf = CGPoint(")
    add("            x: Architecture.entranceAnchor.x,")
    add("            y: Architecture.entranceAnchor.y + 6")
    add("        )")
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
    add(f"        static let internalDoorLeaf = {precise_pt(internal_door_leaf_anchor())}")
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
    add("    /// Exterior threshold crossing. This segment intentionally starts")
    add("    /// outside the navigation floor and passes through the fallen door leaf.")
    add("    static let clientDoorwayPath: [CGPoint] = [")
    for a, b in CLIENT_DOORWAY_PATH:
        add(f"        {pt(rp.authored(a, b))},")
    add("    ].map(OfficeInteriorScale.mapPoint)")
    add("")
    add("    /// Walkable anchors from just inside the exterior door, through the")
    add("    /// waiting room and internal doorway, to the visitor approach.")
    add("    static let clientInteriorArrivalPath: [CGPoint] = [")
    for a, b in CLIENT_INTERIOR_PATH:
        add(f"        {pt(rp.authored(a, b))},")
    add("    ].map(OfficeInteriorScale.mapPoint)")
    add("")
    add("    static var clientArrivalPath: [CGPoint] {")
    add("        Array(clientDoorwayPath.dropLast()) + clientInteriorArrivalPath")
    add("    }")
    add("")
    add("    static var clientDeparturePath: [CGPoint] { Array(clientArrivalPath.reversed()) }")
    add("")
    add("    /// Preserve the authored exterior-door crossing, then let A* expand")
    add("    /// the interior anchors around waiting-room furniture and partition walls.")
    add("    static func clientArrivalRoute(in navigation: NavigationGrid) -> [CGPoint] {")
    add("        let interior = navigation.waypoints(visiting: clientInteriorArrivalPath)")
    add("            ?? clientInteriorArrivalPath")
    add("        return Array(clientDoorwayPath.dropLast()) + interior")
    add("    }")
    add("")
    add("    static func clientDepartureRoute(in navigation: NavigationGrid) -> [CGPoint] {")
    add("        Array(clientArrivalRoute(in: navigation).reversed())")
    add("    }")
    add("")
    add("    static let exteriorToInternalDoorPath: [CGPoint] = [")
    for a, b in CLIENT_PATH[:-2]:
        add(f"        {pt(rp.authored(a, b))},")
    add("    ].map(OfficeInteriorScale.mapPoint)")
    add("")
    add("    static let internalDoorToClientPath: [CGPoint] = [")
    for a, b in CLIENT_INTERIOR_PATH[-3:]:
        add(f"        {pt(rp.authored(a, b))},")
    add("    ].map(OfficeInteriorScale.mapPoint)")
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


def internal_door_leaf_anchor() -> tuple[float, float]:
    """Authored (y-up) depth-prop anchor for the open leaf on the partition hinge.

    Accounts for `internal_leaf_scale()` so the hinge-edge vertical run fills the
    painted opening: the old plate-scale (1:1) formula parked a down-scaled leaf
    near the rear wall instead of in the doorway.
    """
    import json

    opening_path = ART / "office_partition_opening.json"
    with Image.open(ART / "office_internal_door_leaf.png") as im:
        w, h = im.size
        alpha = np.asarray(im.convert("RGBA"))[:, :, 3]

    door_h = float(rp.BAKED_DOORWAY_H)
    # Hinge jamb threshold on the office face of the partition (plate y-down).
    jamb = rp.plan(P.a_line + P.thickness_a, P.b_door0)
    hinge_x = float(jamb[0])
    hinge_bottom_y = float(jamb[1])
    if opening_path.exists():
        meta = json.loads(opening_path.read_text(encoding="utf-8"))
        door_h = float(meta.get("opening_h_px", door_h))
        # hinge_plate_xy is the TOP of the painted opening; recover threshold.
        hx, hy_top = meta["hinge_plate_xy"]
        hinge_x = float(hx)
        # The metadata predates the corrected floor seam and is registered to
        # the plaster/wainscot rail. Carry its threshold down with the same
        # authoritative floor-plane correction as every other placement.
        hinge_bottom_y = (
            float(hy_top)
            + door_h
            + (rp.REAR[1] - _LEGACY_RAIL_Y)
        )

    hinge_ys = np.where(alpha[:, w - 1] > 16)[0]
    if len(hinge_ys):
        content_h = float(hinge_ys.max() - hinge_ys.min() + 1)
        hinge_run_center = (
            float(hinge_ys.min()) + float(hinge_ys.max()) + 1.0
        ) * 0.5
    else:
        content_h = float(h)
        hinge_run_center = h * 0.5

    plate_scale = door_h / max(content_h, 1.0)
    jamb_center_y = hinge_bottom_y - door_h * 0.5  # plate y-down mid-jamb
    # SpriteKit anchor (0.5, DEPTH_PROP_ANCHOR_Y): scale texture so hinge run
    # centres on the structural jamb (same identity as the scale=1 derivation).
    anchor_y = (
        jamb_center_y
        - hinge_run_center * plate_scale
        + (1.0 - DEPTH_PROP_ANCHOR_Y) * h * plate_scale
    )
    # Hinge sits on the right edge of the open-leaf texture.
    anchor_x = hinge_x - (0.5 * w) * plate_scale
    return (anchor_x, rp.ART_H - anchor_y)


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
    """Uniform fit: vertical jamb height → painted clear opening height.

    Non-uniform X stretch made the door too wide and short; keep aspect of the
    sheared master and centre it on the painted aperture.
    """
    alpha = np.asarray(Image.open(ART / "office_door_leaf.png").convert("RGBA"))[:, :, 3]
    content_h, _, _ = _vertical_run(alpha > 16, alpha.shape[1] // 2)
    return rp.BAKED_DOORWAY_H * ENV / max(content_h, 1.0)


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
    """Uniform fit: frame inner aperture height → painted clear opening height."""
    path = ART / "office_door_frame.png"
    if not path.exists():
        return exterior_leaf_scale()
    alpha = np.asarray(Image.open(path).convert("RGBA"))[:, :, 3]
    vis = _flood_frame_inner(alpha)
    iys, ixs = np.where(vis)
    if len(iys) == 0:
        ys, _ = np.where(alpha > 16)
        content_h = float(ys.max() - ys.min() + 1) if len(ys) else 1.0
        return rp.BAKED_DOORWAY_H * ENV / content_h
    inner_cx = int(round((ixs.min() + ixs.max()) * 0.5))
    inner_h, _, _ = _vertical_run(vis, inner_cx)
    return rp.BAKED_DOORWAY_H * ENV / max(inner_h, 1.0)


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
    """Fit the open leaf's hinge-jamb height to the partition clear opening.

    Plate-scale ENV registration was correct when the partition opening matched
    the full leaf master (~390–462 px). On the tight suite the painted opening
    is ~BAKED_DOORWAY_H, so scale from that measured height (or opening JSON).
    Use the hinge-edge vertical run, not the sheared free-edge bbox.
    """
    import json

    alpha = np.asarray(Image.open(ART / "office_internal_door_leaf.png").convert("RGBA"))[:, :, 3]
    hinge_x = alpha.shape[1] - 1
    content_h, _, _ = _vertical_run(alpha > 16, hinge_x)
    if content_h < 1.0:
        ys = np.where(alpha > 16)[0]
        content_h = float(ys.max() - ys.min() + 1) if len(ys) else 1.0
    door_h = float(rp.BAKED_DOORWAY_H)
    opening_path = ART / "office_partition_opening.json"
    if opening_path.exists():
        meta = json.loads(opening_path.read_text(encoding="utf-8"))
        door_h = float(meta.get("opening_h_px", door_h))
    return door_h * ENV / max(content_h, 1.0)


# The exterior doorway segment cannot be sent through NavigationGrid: its first
# point is deliberately outside the floor boundary and the static grid still
# contains the closed door-leaf obstacle. Keep this short segment authored
# through the painted opening, then hand off to routed interior anchors.
CLIENT_DOORWAY_PATH = [
    (-0.080, 0.790),  # outside the department, centred in the clear opening
    (0.200, 0.790),  # inside and clear of the fallen leaf / umbrella stand
]

CLIENT_INTERIOR_PATH = [
    CLIENT_DOORWAY_PATH[-1],
    (0.100, 0.550),  # waiting entrance, beyond the exterior wall
    (0.180, 0.400),  # waiting bay mid
    (0.280, 0.220),  # approach internal doorway (waiting face)
    (0.420, 0.160),  # through the partition doorway
    (0.420, 0.220),  # stand inside office at visitor approach (not empty rear)
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
            CGRect(x: 3_000, y: 1_400, width: 240, height: 480),
            "The hall smelled worse, but at least it led somewhere."
        )
    ]

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
        static let cameraBelowActorMidpoint: CGFloat = 110
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

    static func makeGrid() -> NavigationGrid {
        NavigationGrid(
            projection: .dimetric(
                origin: OfficeInteriorScale.mapPoint(authoredProjectionOrigin),
                tileSize: OfficeInteriorScale.mapSize(authoredTileSize)
            ),
            columns: 31,
            rows: 31,
            obstacles: obstacles,
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
    start = (chair[0], chair[1] + ACTOR_START_OFFSET)
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
        CLIENT_DOORWAY_PATH[0][0] < 0.0 < CLIENT_DOORWAY_PATH[-1][0]
        and all(EXTERIOR_DOOR[1] - rp.EXTERIOR_DOOR_OPENING_B / 2
                <= b
                <= EXTERIOR_DOOR[1] + rp.EXTERIOR_DOOR_OPENING_B / 2
                for _, b in CLIENT_DOORWAY_PATH)
    )
    ok &= doorway_ok
    print(f"  client exterior doorway crossing valid={doorway_ok}")
    for a, b in CLIENT_INTERIOR_PATH:
        cell = grid.cell(rp.authored(a, b))
        good = cell in reach
        ok &= good
        print(f"  client interior ({a:.3f},{b:.3f}) cell={cell} reachable={good}")
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

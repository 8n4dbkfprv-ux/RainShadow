"""Single source of truth for the office suite layout.

Placements are authored in the shell's floor-plan basis (see `office_room_plan`)
so furniture sits on real wall lines instead of screen-space guesses:

    a  distance from the north-east wall (0 = on that wall, grows to the west)
    b  distance from the north-west wall (0 = on that wall, grows toward camera)

Prop display scales are expressed as multiples of the character body (229 plate
px), which is the master scale reference. Run this module to emit the Swift
layout and a navigation report:

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

BODY = rp.BODY_PLATE_H  # 229 plate px, measured off the rendered Voss idle frame
ENV = 0.395

# Metre -> plan units on each axis (from the shell's own doorway width: ~200 px
# of screen x per metre of floor).
PX_PER_M = 200.0
M_PER_A = PX_PER_M / abs(rp.AXIS_NW[0])
M_PER_B = PX_PER_M / rp.AXIS_NE[0]

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

# Every prop belongs to one of four clusters: desk, records, entrance/waiting,
# personal corner. Nothing sits alone in open floor space.
PROPS: list[Prop] = [
    # ---- records cluster: one continuous storage run flush to the north-west
    # wall — safe at the east end, two cabinets, bookcase — nearly touching.
    Prop("safe", "office_safe", 0.640, FLUSH, 0.34, (0.6, 0.6), note="records run, east end"),
    Prop("filingCabinetB", "office_filing_cabinet", 0.700, FLUSH, 1.31, (0.5, 0.62)),
    Prop("filingCabinet", "office_filing_cabinet_open", 0.762, FLUSH, 1.31, (0.5, 0.62), note="drawer half open"),
    Prop("bookshelf", "office_bookshelf", 0.830, FLUSH, 1.67, (1.2, 0.35)),
    Prop("archiveBoxOnCabinet", "office_archive_box_b", 0.700, FLUSH, 0.36, obstacle=False, note="on cabinet B"),
    Prop("archiveStackOnCabinet", "office_archive_stack", 0.762, FLUSH, 0.44, obstacle=False, note="on cabinet A"),
    Prop("archiveBoxA", "office_archive_box_a", 0.802, 0.105, 0.40, (0.5, 0.45), note="only floor stack"),
    # ---- radiator under the window (window is fixed at a = 0.556)
    Prop("radiator", "office_radiator", 0.556, FLUSH - 0.006, 0.82, (1.0, 0.2)),
    # ---- personal corner: one neglected group in the dark partition corner
    Prop("personalSideboard", "office_personal_sideboard", 0.425, FLUSH, 0.48, (1.2, 0.5)),
    Prop("personalWashbasin", "office_personal_washbasin", 0.470, FLUSH, 0.41, (0.7, 0.5)),
    Prop("personalFan", "office_personal_fan", 0.405, 0.085, 0.68, (0.5, 0.5)),
    Prop("personalBottle", "office_hidden_bottle", 0.434, FLUSH + 0.004, 0.22, obstacle=False, note="on sideboard"),
    Prop("personalGlass", "office_personal_glass", 0.416, FLUSH + 0.004, 0.10, obstacle=False, note="on sideboard"),
    # ---- desk cluster: rear-left third of the shrunken office, everything on
    # one rug — detective behind the desk facing the door wall, clients side by
    # side opposite with a small gap, wastebasket tucked at the desk's end.
    Prop("deskEnsemble", "office_desk_bare", 0.655, 0.245, 0.99, (1.7, 0.9)),
    Prop("deskChair", "office_desk_chair", 0.725, 0.245, 0.64, (0.6, 0.6), obstacle=False),
    Prop("visitorArmchair", "office_visitor_armchair", 0.555, 0.185, 0.79, (0.8, 0.8)),
    Prop("visitorArmchairB", "office_visitor_armchair", 0.555, 0.310, 0.76, (0.8, 0.8)),
    Prop("wastebasket", "office_wastebasket", 0.720, 0.160, 0.32, (0.4, 0.4)),
    # ---- entrance / waiting cluster (matches last shipped Swift placements)
    Prop("coatRack", "office_coat_rack", 0.072, 0.475, 1.18, (0.6, 0.6)),
    Prop("umbrellaStand", "office_umbrella_stand", 0.052, 0.518, 0.28, (0.35, 0.35)),
    Prop("waitingChairA", "office_waiting_chair_a", 0.118, 0.485, 0.60, (0.55, 0.55)),
    Prop("waitingTable", "office_waiting_table", 0.118, 0.525, 0.36, (0.55, 0.55)),
    Prop("waitingChairB", "office_waiting_chair_b", 0.118, 0.562, 0.58, (0.55, 0.55)),
    Prop("newspaper", "office_newspaper", 0.112, 0.519, 0.10, obstacle=False, note="on table"),
    Prop("waitingAshtray", "office_waiting_ashtray", 0.126, 0.532, 0.07, obstacle=False, note="on table"),
]

PROP_BY_KEY = {p.key: p for p in PROPS}

# Fixed shell features, authored directly (the shell painted them).
EXTERIOR_DOOR = (0.004, 0.425)  # centre of the baked doorway on the north-east wall
WINDOW_A = 0.556

# One large worn burgundy rug: the desk, detective chair and both client chairs
# sit completely on it, so the group reads as a single composition.
RUG = (0.640, 0.248)
RUG_BODY = 2.2

# Wall art hangs on the north-west wall face directly above the records run —
# board, map and photo cluster packed together, deliberately uneven; authored in
# plate pixels (y down) because it sits on the wall plane, not the floor.
WALL_ART = {
    "caseBoard": (900.0, 520.0),
    "wallCityMap": (1_070.0, 470.0),
    "wallPhotos": (760.0, 590.0),
}

FLOOR_DECALS = {
    "windowSpill": (1_240.0, 800.0),
    "blindStripes": (1_330.0, 930.0),  # raked toward the rug and desk
    "hallwayLight": (3_130.0, 640.0),
    "lampPool": None,  # follows the desk
}

APPROACH = {
    # Stand just west of client chair A: the old spot right under the window now
    # sits inside the chair's footprint.
    "office.window": (0.502, 0.118),
    "office.desk": (0.610, 0.400),
    "office.phone": (0.650, 0.400),
    "office.files": (0.762, 0.168),
    "office.door": (0.124, 0.430),
}

ACTOR_START_OFFSET = 208.0  # seated nav root sits south of the chair sprite


# --------------------------------------------------------------- architecture


def cell_point(c: int, r: int) -> tuple[float, float]:
    return (2_048 + (c - r) * 64, 310 + (c + r) * 32)


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

# Exterior door leaf sits closed inside the shell's baked opening.
DOOR_OBSTACLE = (3_029.0, 1_539.0, 170.0, 140.0)


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
        py = (p[1] - 310) / 32.0
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
    add(f"        /// Exterior leaf closed inside the shell's baked opening.")
    add(f"        static let entranceAnchor = {pt(rp.authored(*EXTERIOR_DOOR))}")
    add("        /// Window insert centre on the shell's left-wall recess.")
    add("        static let windowAnchor = CGPoint(x: 1_220, y: 1_812)")
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
    add("        /// Exterior leaf closed inside the shell's baked opening.")
    add(f"        static let entranceLeafDisplayScale: CGFloat = {exterior_leaf_scale():.4f}")
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
    add("        static let doorLeaf = Architecture.entranceAnchor")
    add("        static let window = Architecture.windowAnchor")
    add("        static let windowBlinds = window")
    add("        static let windowRotation: CGFloat = -0.105")
    add("        static let windowRainMask = CGRect(x: 1_182, y: 1_744, width: 76, height: 136)")
    add("        static let windowRainEmitter = CGPoint(x: 1_220, y: 1_884)")
    add("        /// Recentred on the shrunken room (the plate's lower floor is gone).")
    add("        static let camera = CGPoint(x: 1_960, y: 1_340)")
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
    add(f"        static let internalDoorLeaf = {pt(internal_door_leaf_anchor())}")
    add("    }")
    add("")

    # ---- approach points, paths
    add("    private static let authoredApproachPoints: [String: CGPoint] = [")
    for name, (a, b) in APPROACH.items():
        add(f'        "{name}": {pt(rp.authored(a, b))},')
    add("    ]")
    add("")
    add("    private static let authoredProjectionOrigin = CGPoint(x: 2_048, y: 310)")
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
    add("    /// Exterior door → waiting room → internal doorway → client chair.")
    add("    static let clientArrivalPath: [CGPoint] = [")
    for a, b in CLIENT_PATH:
        add(f"        {pt(rp.authored(a, b))},")
    add("    ].map(OfficeInteriorScale.mapPoint)")
    add("")
    add("    static var clientDeparturePath: [CGPoint] { Array(clientArrivalPath.reversed()) }")
    add("")
    add("    static let exteriorToInternalDoorPath: [CGPoint] = [")
    for a, b in CLIENT_PATH[:3]:
        add(f"        {pt(rp.authored(a, b))},")
    add("    ].map(OfficeInteriorScale.mapPoint)")
    add("")
    add("    static let internalDoorToClientPath: [CGPoint] = [")
    for a, b in CLIENT_PATH[2:]:
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
    add("    /// Stand points for the architecture visibility capture: behind the desk,")
    add("    /// in the internal doorway, and beside the waiting chair.")
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
    return "\n".join(lines) + "\n"


DEPTH_PROP_ANCHOR_Y = 0.04  # matches `addDepthProp` in DetectiveOfficeScene


def internal_door_leaf_anchor() -> tuple[float, float]:
    """Authored anchor for the open leaf — hinge on the plate's doorway jamb."""
    import json

    opening_path = ART / "office_partition_opening.json"
    with Image.open(ART / "office_internal_door_leaf.png") as im:
        w, h = im.size
    if opening_path.exists():
        meta = json.loads(opening_path.read_text(encoding="utf-8"))
        hinge_x, hinge_y = meta["hinge_plate_xy"]
        # Sprite hinge is its right edge; free edge dips along AXIS_NW.
        bottom = hinge_y + abs(rp.AXIS_NW[1] / rp.AXIS_NW[0]) * w
        anchor_plate = (hinge_x - w / 2.0, bottom - DEPTH_PROP_ANCHOR_Y * h)
    else:
        jamb = rp.plan(P.a_line + P.thickness_a, P.b_door0)
        bottom = jamb[1] + abs(rp.AXIS_NW[1] / rp.AXIS_NW[0]) * w
        anchor_plate = (jamb[0] - w / 2.0, bottom - DEPTH_PROP_ANCHOR_Y * h)
    return (anchor_plate[0], rp.ART_H - anchor_plate[1])


def exterior_leaf_scale() -> float:
    """Scale the shell-era leaf art down to the baked opening it stands in."""
    alpha = np.asarray(Image.open(ART / "office_door_leaf.png").convert("RGBA"))[:, :, 3]
    ys, _ = np.where(alpha > 16)
    content_h = float(ys.max() - ys.min() + 1)
    return rp.BAKED_DOORWAY_H * ENV / content_h


CLIENT_PATH = [
    (0.052, 0.430),
    (0.180, 0.300),
    (0.280, 0.180),  # approach the rear doorway from the waiting room
    (0.395, P.door_mid_b),  # through the internal doorway
    (0.490, 0.375),  # standing beside the client chairs
]

SCALE_STANDS = [
    (0.760, 0.245),  # behind the desk
    (0.395, (P.b_door0 + P.b_door1) * 0.5),  # in the internal doorway
    (0.165, 0.500),  # beside the waiting chair
]

RECORDS_PATH = [
    (0.680, 0.340),
    (0.720, 0.220),
    (0.762, 0.168),
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

    print("=== scale review (rendered height / character body, body = 229 plate px) ===")
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
    for a, b in CLIENT_PATH:
        cell = grid.cell(rp.authored(a, b))
        good = cell in reach
        ok &= good
        print(f"  client path ({a:.3f},{b:.3f}) cell={cell} reachable={good}")
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

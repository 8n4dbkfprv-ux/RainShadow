import CoreGraphics

enum OfficeNavigationLayout {
    /// Authoring-space (pre-scale) layout, then mapped through `OfficeInteriorScale`.

    /// Nav root for seated Voss; visual seat is `deskChair` via `seatedYOffset`.
    // deskChair.y + seatedYOffset/environment (82/0.395 ≈ 208)
    private static let authoredActorStart = CGPoint(x: 2_070, y: 1_163)

    /// Ground-contact footprints in authored (pre-scale) space. Tall vertical props
    /// (door, cabinet, radiator, coat rack) only block their base; desk and
    /// seating cover the full floor projection so pathfinding cannot walk over
    /// the desktop or chair seats. Depth sorting still handles drawing order.
    private static let authoredObstacles = [
        authoredDeskObstacle,
        authoredVisitorArmchairObstacle,
        authoredFilingCabinetObstacle,
        authoredArchiveBoxAObstacle,
        authoredArchiveBoxBObstacle,
        authoredWastebasketObstacle,
        authoredRadiatorObstacle,
        authoredBookshelfObstacle,
        authoredArchiveStackObstacle,
        authoredCoatRackObstacle,
        authoredDoorObstacle
    ]

    /// Desk + detective chair floor solid (NE-facing desk island).
    /// maxY stays below `authoredActorStart` so sit-to-stand egress pathfinds.
    /// East edge leaves a corridor to the visitor chair / door.
    static let authoredDeskObstacle = CGRect(x: 1_860, y: 820, width: 400, height: 250)

    /// Visitor armchair on the NE / door approach side of the desk (on the client rug).
    /// Kept east of phone/files approaches so desk-item routes stay walkable.
    static let authoredVisitorArmchairObstacle = CGRect(x: 2_280, y: 1_030, width: 260, height: 160)

    /// Filing cabinet on the detective’s west flank (case-storage cluster).
    static let authoredFilingCabinetObstacle = CGRect(x: 1_670, y: 940, width: 190, height: 120)

    /// Closed archive box base solid (flush against cabinet).
    static let authoredArchiveBoxAObstacle = CGRect(x: 1_600, y: 920, width: 120, height: 90)

    /// Open archive box base solid (slightly forward stack of `a`).
    static let authoredArchiveBoxBObstacle = CGRect(x: 1_560, y: 870, width: 130, height: 90)

    /// Wastebasket at detective-side SW desk foot.
    static let authoredWastebasketObstacle = CGRect(x: 1_850, y: 820, width: 110, height: 90)

    /// Radiator base solid along the west wall.
    static let authoredRadiatorObstacle = CGRect(x: 930, y: 1_390, width: 340, height: 110)

    /// Bookshelf base solid flush to the left/back wall near the radiator.
    /// Kept clear of the window approach at (1350, 1400).
    static let authoredBookshelfObstacle = CGRect(x: 1_160, y: 1_290, width: 160, height: 90)

    /// Archive box stack near the door / coat-rack wall.
    static let authoredArchiveStackObstacle = CGRect(x: 2_720, y: 1_330, width: 160, height: 100)

    /// Coat rack base solid, registered to `AuthoredPlacement.coatRack`.
    static let authoredCoatRackObstacle = CGRect(x: 2_900, y: 1_340, width: 210, height: 120)

    /// Door leaf floor solid in authored space (registered to the V5 shell opening).
    static let authoredDoorObstacle = CGRect(x: 3_029, y: 1_539, width: 170, height: 140)

    /// Sample points on the desk / chair footprint used by tests (authored space).
    static let authoredDeskSamplePoints: [CGPoint] = [
        CGPoint(x: 2_100, y: 980),  // desk ensemble anchor
        CGPoint(x: 2_070, y: 955),  // chair / detective seat (kneehole center)
        CGPoint(x: 2_100, y: 1_040), // mid desktop band
        CGPoint(x: 2_140, y: 1_050), // NE desktop toward visitor
        CGPoint(x: 1_940, y: 940),  // SW pedestal
        CGPoint(x: 2_180, y: 1_020) // east desktop
    ]

    /// Sample points on the door leaf footprint used by tests (authored space).
    static let authoredDoorLeafSamplePoints: [CGPoint] = [
        CGPoint(x: 3_114, y: 1_554),
        CGPoint(x: 3_060, y: 1_545),
        CGPoint(x: 3_160, y: 1_565)
    ]

    /// Sample points on other major floor solids (authored space).
    static let authoredVisitorArmchairSamplePoints: [CGPoint] = [
        CGPoint(x: 2_360, y: 1_100),
        CGPoint(x: 2_440, y: 1_140),
        CGPoint(x: 2_380, y: 1_080)
    ]

    static let authoredFilingCabinetSamplePoints: [CGPoint] = [
        CGPoint(x: 1_760, y: 1_000),
        CGPoint(x: 1_710, y: 990),
        CGPoint(x: 1_820, y: 1_030)
    ]

    static let authoredRadiatorSamplePoints: [CGPoint] = [
        CGPoint(x: 1_100, y: 1_450),
        CGPoint(x: 1_000, y: 1_440),
        CGPoint(x: 1_200, y: 1_470)
    ]

    static let authoredCoatRackSamplePoints: [CGPoint] = [
        CGPoint(x: 3_000, y: 1_400),
        CGPoint(x: 2_940, y: 1_390),
        CGPoint(x: 3_060, y: 1_430)
    ]

    static let authoredArchiveBoxASamplePoints: [CGPoint] = [
        CGPoint(x: 1_660, y: 960),
        CGPoint(x: 1_630, y: 950),
        CGPoint(x: 1_690, y: 980)
    ]

    static let authoredArchiveBoxBSamplePoints: [CGPoint] = [
        CGPoint(x: 1_620, y: 910),
        CGPoint(x: 1_590, y: 900),
        CGPoint(x: 1_650, y: 930)
    ]

    static let authoredWastebasketSamplePoints: [CGPoint] = [
        CGPoint(x: 1_900, y: 860),
        CGPoint(x: 1_870, y: 850),
        CGPoint(x: 1_930, y: 890)
    ]

    static let authoredBookshelfSamplePoints: [CGPoint] = [
        CGPoint(x: 1_240, y: 1_340),
        CGPoint(x: 1_200, y: 1_330),
        CGPoint(x: 1_280, y: 1_360)
    ]

    static let authoredArchiveStackSamplePoints: [CGPoint] = [
        CGPoint(x: 2_800, y: 1_370),
        CGPoint(x: 2_760, y: 1_360),
        CGPoint(x: 2_840, y: 1_400)
    ]

    private static let authoredApproachPoints: [String: CGPoint] = [
        "office.window": CGPoint(x: 1_350, y: 1_400),
        // Visitor face of the NE-facing desk (approach from door corridor).
        "office.desk": CGPoint(x: 2_280, y: 1_200),
        "office.phone": CGPoint(x: 2_260, y: 1_180),
        "office.files": CGPoint(x: 2_240, y: 1_160),
        // In front of the door, clear of the leaf solid and the visitor armchair obstacle.
        "office.door": CGPoint(x: 2_700, y: 1_300)
    ]

    /// Near corner of the projected floor diamond. A 128×64 tile yields the
    /// fixed 2:1 dimetric perspective used by the background and actor facings.
    private static let authoredProjectionOrigin = CGPoint(x: 2_048, y: 310)
    private static let authoredTileSize = CGSize(width: 128, height: 64)

    static var actorStart: CGPoint { OfficeInteriorScale.mapPoint(authoredActorStart) }

    static let clientArrivalPath: [CGPoint] = [
        CGPoint(x: 3_000, y: 1_480),
        CGPoint(x: 2_700, y: 1_300),
        // Stop just NE of the visitor armchair (walkable), on the door→desk line.
        CGPoint(x: 2_460, y: 1_240)
    ].map(OfficeInteriorScale.mapPoint)

    static var clientDeparturePath: [CGPoint] {
        Array(clientArrivalPath.reversed())
    }

    static var obstacles: [CGRect] {
        authoredObstacles.map(OfficeInteriorScale.mapRect)
    }

    static var deskObstacle: CGRect {
        OfficeInteriorScale.mapRect(authoredDeskObstacle)
    }

    static var visitorArmchairObstacle: CGRect {
        OfficeInteriorScale.mapRect(authoredVisitorArmchairObstacle)
    }

    static var filingCabinetObstacle: CGRect {
        OfficeInteriorScale.mapRect(authoredFilingCabinetObstacle)
    }

    static var radiatorObstacle: CGRect {
        OfficeInteriorScale.mapRect(authoredRadiatorObstacle)
    }

    static var coatRackObstacle: CGRect {
        OfficeInteriorScale.mapRect(authoredCoatRackObstacle)
    }

    static var archiveBoxAObstacle: CGRect {
        OfficeInteriorScale.mapRect(authoredArchiveBoxAObstacle)
    }

    static var archiveBoxBObstacle: CGRect {
        OfficeInteriorScale.mapRect(authoredArchiveBoxBObstacle)
    }

    static var wastebasketObstacle: CGRect {
        OfficeInteriorScale.mapRect(authoredWastebasketObstacle)
    }

    static var bookshelfObstacle: CGRect {
        OfficeInteriorScale.mapRect(authoredBookshelfObstacle)
    }

    static var archiveStackObstacle: CGRect {
        OfficeInteriorScale.mapRect(authoredArchiveStackObstacle)
    }

    static var doorObstacle: CGRect {
        OfficeInteriorScale.mapRect(authoredDoorObstacle)
    }

    static var deskSamplePoints: [CGPoint] {
        authoredDeskSamplePoints.map(OfficeInteriorScale.mapPoint)
    }

    static var doorLeafSamplePoints: [CGPoint] {
        authoredDoorLeafSamplePoints.map(OfficeInteriorScale.mapPoint)
    }

    static var visitorArmchairSamplePoints: [CGPoint] {
        authoredVisitorArmchairSamplePoints.map(OfficeInteriorScale.mapPoint)
    }

    static var filingCabinetSamplePoints: [CGPoint] {
        authoredFilingCabinetSamplePoints.map(OfficeInteriorScale.mapPoint)
    }

    static var radiatorSamplePoints: [CGPoint] {
        authoredRadiatorSamplePoints.map(OfficeInteriorScale.mapPoint)
    }

    static var coatRackSamplePoints: [CGPoint] {
        authoredCoatRackSamplePoints.map(OfficeInteriorScale.mapPoint)
    }

    static var archiveBoxASamplePoints: [CGPoint] {
        authoredArchiveBoxASamplePoints.map(OfficeInteriorScale.mapPoint)
    }

    static var archiveBoxBSamplePoints: [CGPoint] {
        authoredArchiveBoxBSamplePoints.map(OfficeInteriorScale.mapPoint)
    }

    static var wastebasketSamplePoints: [CGPoint] {
        authoredWastebasketSamplePoints.map(OfficeInteriorScale.mapPoint)
    }

    static var bookshelfSamplePoints: [CGPoint] {
        authoredBookshelfSamplePoints.map(OfficeInteriorScale.mapPoint)
    }

    static var archiveStackSamplePoints: [CGPoint] {
        authoredArchiveStackSamplePoints.map(OfficeInteriorScale.mapPoint)
    }

    /// All major prop sample points used by office-obstacle tests.
    static var majorPropSamplePoints: [CGPoint] {
        deskSamplePoints
            + visitorArmchairSamplePoints
            + filingCabinetSamplePoints
            + archiveBoxASamplePoints
            + archiveBoxBSamplePoints
            + wastebasketSamplePoints
            + radiatorSamplePoints
            + bookshelfSamplePoints
            + archiveStackSamplePoints
            + coatRackSamplePoints
            + doorLeafSamplePoints
    }

    static var approachPoints: [String: CGPoint] {
        authoredApproachPoints.mapValues(OfficeInteriorScale.mapPoint)
    }

    /// Authoring-space prop anchors (pre-scale); scene maps through `OfficeInteriorScale`.
    enum AuthoredPlacement {
        static let radiator = CGPoint(x: 1_100, y: 1_450)
        /// Door leaf ground contact on the V5 doorway threshold (SK y-up).
        static let doorLeaf = CGPoint(x: 3_114, y: 1_554)
        // Maps to the actor's seated visual baseline (navigation root + seatedYOffset).
        // SW kneehole center — deep enough that lower body overlaps the apron strip.
        static let deskChair = CGPoint(x: 2_070, y: 955)
        static let filingCabinet = CGPoint(x: 1_760, y: 1_000)
        static let archiveBoxA = CGPoint(x: 1_660, y: 960)
        static let archiveBoxB = CGPoint(x: 1_620, y: 910)
        static let wastebasket = CGPoint(x: 1_900, y: 860)
        static let wornRug = CGPoint(x: 2_340, y: 1_090)
        static let floorTrashA = CGPoint(x: 1_880, y: 900)
        static let floorTrashB = CGPoint(x: 2_280, y: 1_060)
        static let floorTrashC = CGPoint(x: 2_920, y: 1_420)
        static let hiddenBottle = CGPoint(x: 1_950, y: 940)
        static let bookshelf = CGPoint(x: 1_240, y: 1_340)
        static let archiveStack = CGPoint(x: 2_800, y: 1_370)
        static let floorWear = CGPoint(x: 2_100, y: 980)
        static let windowSpill = CGPoint(x: 1_350, y: 1_420)
        static let coatRack = CGPoint(x: 3_000, y: 1_400)
        static let visitorArmchair = CGPoint(x: 2_360, y: 1_100)
        static let deskEnsemble = CGPoint(x: 2_100, y: 980)
        static let camera = CGPoint(x: 2_120, y: 1_080)
        /// Window insert centre on the V6 left-wall recess (SK y-up, sprite anchor 0.5).
        /// Nudged down so the sash covers the recess sill ledge.
        static let window = CGPoint(x: 1_220, y: 1_812)
        /// Slight clockwise tilt to match the left-wall dimetric sill (~6°).
        static let windowRotation: CGFloat = -0.105
        /// Matches the V6 glass opening / sash display on `office_shell_base` (SK y-up).
        static let windowRainMask = CGRect(x: 1_182, y: 1_744, width: 76, height: 136)
        static let windowRainEmitter = CGPoint(x: 1_220, y: 1_884)
        static let lampPool = CGPoint(x: 2_100, y: 1_020)
    }

    /// Case-intro dialogue camera: frame seated Voss + standing Lila in the free band above the panel.
    enum DialogueCameraFraming {
        /// Old play-camera-relative drop that only cropped heads (kept for regression tests).
        static let legacyDownwardOffset: CGFloat = 55
        /// Prior fixed drop from play camera (left the desk under the taller dialogue panel).
        static let priorDownwardOffset: CGFloat = 28
        /// Place the camera this far **below** the Voss–Lila midpoint so both sit in the upper free band.
        static let cameraBelowActorMidpoint: CGFloat = 110
        /// Slight pull toward Lila’s side of the desk.
        static let lateralBiasTowardClient: CGFloat = 24

        /// Midpoint between seated Voss and Lila’s arrival stop (world space).
        static var actorFocusPoint: CGPoint {
            let voss = OfficeInteriorScale.mapPoint(AuthoredPlacement.deskChair)
            let lila = clientArrivalPath.last
                ?? OfficeInteriorScale.mapPoint(AuthoredPlacement.visitorArmchair)
            return CGPoint(
                x: (voss.x + lila.x) * 0.5 + lateralBiasTowardClient,
                y: (voss.y + lila.y) * 0.5
            )
        }

        /// World-space camera target used by `DetectiveOfficeScene` during case intro dialogue.
        static var dialogueCameraWorldPosition: CGPoint {
            let focus = actorFocusPoint
            return CGPoint(
                x: focus.x,
                y: focus.y - cameraBelowActorMidpoint
            )
        }

        /// Play-camera-relative helper (tests / diagnostics). Prefer `dialogueCameraWorldPosition`.
        static func dialogueCameraPosition(playCamera: CGPoint) -> CGPoint {
            let target = dialogueCameraWorldPosition
            // Preserve the signature; actual framing is actor-focused, not play-camera delta.
            _ = playCamera
            return target
        }

        /// Downward delta from the authored play camera to the dialogue target (for tests).
        static var downwardOffsetFromPlayCamera: CGFloat {
            let play = OfficeInteriorScale.mapPoint(AuthoredPlacement.camera)
            return play.y - dialogueCameraWorldPosition.y
        }

        static var lateralOffsetFromPlayCamera: CGFloat {
            let play = OfficeInteriorScale.mapPoint(AuthoredPlacement.camera)
            return dialogueCameraWorldPosition.x - play.x
        }
    }

    static let authoredHotspots: [(id: String, name: String, hitArea: CGRect, observation: String)] = [
        (
            "office.window",
            "Rain-streaked window",
            CGRect(x: 1_174, y: 1_758, width: 92, height: 160),
            "The rain had been working the glass harder than I had worked a case."
        ),
        (
            "office.desk",
            "Desk",
            CGRect(x: 1_860, y: 820, width: 560, height: 400),
            "Three old cases, two unpaid bills, one clean page."
        ),
        (
            "office.phone",
            "Telephone",
            CGRect(x: 2_180, y: 1_020, width: 190, height: 150),
            "Quiet. For once it had the decency to look guilty."
        ),
        (
            "office.files",
            "Case files",
            CGRect(x: 1_980, y: 980, width: 230, height: 170),
            "Closed, abandoned, and one I still lied about."
        ),
        (
            "office.door",
            "Office door",
            CGRect(x: 3_000, y: 1_400, width: 240, height: 480),
            "The hall smelled worse, but at least it led somewhere."
        )
    ]

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

    /// True when a world-space point falls inside any office obstacle (including the door).
    static func isBlocked(_ point: CGPoint) -> Bool {
        obstacles.contains { $0.contains(point) }
    }
}

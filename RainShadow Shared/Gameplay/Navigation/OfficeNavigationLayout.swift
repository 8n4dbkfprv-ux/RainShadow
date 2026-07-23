import CoreGraphics

enum OfficeNavigationLayout {
    /// Authoring-space (pre-scale) layout, then mapped through `OfficeInteriorScale`.

    private static let authoredActorStart = CGPoint(x: 2_000, y: 1_218)

    /// Ground-contact footprints in authored (pre-scale) space. Tall vertical props
    /// (door, cabinet, radiator, coat rack) only block their base; desk and
    /// seating cover the full floor projection so pathfinding cannot walk over
    /// the desktop or chair seats. Depth sorting still handles drawing order.
    private static let authoredObstacles = [
        authoredDeskObstacle,
        authoredVisitorArmchairObstacle,
        authoredFilingCabinetObstacle,
        authoredRadiatorObstacle,
        authoredCoatRackObstacle,
        authoredDoorObstacle
    ]

    /// Desk + detective chair floor solid. Matches the bare-desk sprite ground
    /// projection (≈1118…1752 × 514…1044) closely enough that desktop taps stay
    /// solid, while the east edge is cut short of the filing cabinet so the
    /// corridor to the door remains pathfindable.
    static let authoredDeskObstacle = CGRect(x: 1_780, y: 850, width: 440, height: 300)

    /// Visitor armchair floor solid (base + lower seat mass).
    static let authoredVisitorArmchairObstacle = CGRect(x: 2_430, y: 720, width: 300, height: 190)

    /// Filing cabinet base solid.
    static let authoredFilingCabinetObstacle = CGRect(x: 2_540, y: 1_380, width: 250, height: 120)

    /// Radiator base solid along the west wall.
    static let authoredRadiatorObstacle = CGRect(x: 930, y: 1_390, width: 340, height: 110)

    /// Coat rack base solid, registered to `AuthoredPlacement.coatRack`.
    static let authoredCoatRackObstacle = CGRect(x: 3_030, y: 1_370, width: 210, height: 120)

    /// Door leaf floor solid in authored space (registered to the V5 shell opening).
    static let authoredDoorObstacle = CGRect(x: 3_029, y: 1_539, width: 170, height: 140)

    /// Sample points on the desk / chair footprint used by tests (authored space).
    static let authoredDeskSamplePoints: [CGPoint] = [
        CGPoint(x: 2_000, y: 900),  // desk ensemble anchor
        CGPoint(x: 2_000, y: 1_010), // chair anchor
        CGPoint(x: 2_000, y: 1_060), // mid desktop band
        CGPoint(x: 2_000, y: 1_120), // upper desktop band
        CGPoint(x: 1_850, y: 960),  // west pedestal
        CGPoint(x: 2_150, y: 1_040) // east desktop
    ]

    /// Sample points on the door leaf footprint used by tests (authored space).
    static let authoredDoorLeafSamplePoints: [CGPoint] = [
        CGPoint(x: 3_114, y: 1_554),
        CGPoint(x: 3_060, y: 1_545),
        CGPoint(x: 3_160, y: 1_565)
    ]

    /// Sample points on other major floor solids (authored space).
    static let authoredVisitorArmchairSamplePoints: [CGPoint] = [
        CGPoint(x: 2_580, y: 780),
        CGPoint(x: 2_580, y: 850),
        CGPoint(x: 2_500, y: 810)
    ]

    static let authoredFilingCabinetSamplePoints: [CGPoint] = [
        CGPoint(x: 2_650, y: 1_430),
        CGPoint(x: 2_600, y: 1_420),
        CGPoint(x: 2_720, y: 1_460)
    ]

    static let authoredRadiatorSamplePoints: [CGPoint] = [
        CGPoint(x: 1_100, y: 1_450),
        CGPoint(x: 1_000, y: 1_440),
        CGPoint(x: 1_200, y: 1_470)
    ]

    static let authoredCoatRackSamplePoints: [CGPoint] = [
        CGPoint(x: 3_140, y: 1_430),
        CGPoint(x: 3_080, y: 1_420),
        CGPoint(x: 3_200, y: 1_460)
    ]

    private static let authoredApproachPoints: [String: CGPoint] = [
        "office.window": CGPoint(x: 1_350, y: 1_400),
        "office.desk": CGPoint(x: 1_600, y: 1_100),
        "office.phone": CGPoint(x: 1_600, y: 1_200),
        "office.files": CGPoint(x: 1_650, y: 1_200),
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
        CGPoint(x: 2_430, y: 1_080)
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

    /// All major prop sample points used by office-obstacle tests.
    static var majorPropSamplePoints: [CGPoint] {
        deskSamplePoints
            + visitorArmchairSamplePoints
            + filingCabinetSamplePoints
            + radiatorSamplePoints
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
        static let deskChair = CGPoint(x: 2_000, y: 1_010)
        static let filingCabinet = CGPoint(x: 2_650, y: 1_430)
        static let coatRack = CGPoint(x: 3_140, y: 1_430)
        static let visitorArmchair = CGPoint(x: 2_580, y: 780)
        static let deskEnsemble = CGPoint(x: 2_000, y: 900)
        static let camera = CGPoint(x: 2_048, y: 1_152)
        /// Window insert centre on the V6 left-wall recess (SK y-up, sprite anchor 0.5).
        /// Nudged down so the sash covers the recess sill ledge.
        static let window = CGPoint(x: 1_220, y: 1_812)
        /// Slight clockwise tilt to match the left-wall dimetric sill (~6°).
        static let windowRotation: CGFloat = -0.105
        /// Matches the V6 glass opening / sash display on `office_shell_base` (SK y-up).
        static let windowRainMask = CGRect(x: 1_182, y: 1_744, width: 76, height: 136)
        static let windowRainEmitter = CGPoint(x: 1_220, y: 1_884)
        static let lampPool = CGPoint(x: 2_000, y: 1_040)
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
            CGRect(x: 1_700, y: 830, width: 600, height: 410),
            "Three old cases, two unpaid bills, one clean page."
        ),
        (
            "office.phone",
            "Telephone",
            CGRect(x: 2_050, y: 1_020, width: 190, height: 150),
            "Quiet. For once it had the decency to look guilty."
        ),
        (
            "office.files",
            "Case files",
            CGRect(x: 1_780, y: 1_020, width: 230, height: 170),
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

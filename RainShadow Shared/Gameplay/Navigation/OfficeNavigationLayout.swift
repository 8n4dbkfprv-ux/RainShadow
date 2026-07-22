import CoreGraphics

enum OfficeNavigationLayout {
    /// Authoring-space (pre-scale) layout, then mapped through `OfficeInteriorScale`.

    private static let authoredActorStart = CGPoint(x: 1_430, y: 1_080)

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
    static let authoredDeskObstacle = CGRect(x: 1_050, y: 500, width: 720, height: 520)

    /// Visitor armchair floor solid (base + lower seat mass).
    static let authoredVisitorArmchairObstacle = CGRect(x: 2_080, y: 285, width: 530, height: 300)

    /// Filing cabinet base solid.
    static let authoredFilingCabinetObstacle = CGRect(x: 1_865, y: 900, width: 430, height: 180)

    /// Radiator base solid along the west wall.
    static let authoredRadiatorObstacle = CGRect(x: 285, y: 840, width: 535, height: 120)

    /// Coat rack base solid, registered to `AuthoredPlacement.coatRack`.
    static let authoredCoatRackObstacle = CGRect(x: 2_790, y: 850, width: 280, height: 120)

    /// Door leaf floor solid in authored space (registered to the V2 shell opening).
    static let authoredDoorObstacle = CGRect(x: 2_260, y: 800, width: 400, height: 180)

    /// Sample points on the desk / chair footprint used by tests (authored space).
    static let authoredDeskSamplePoints: [CGPoint] = [
        CGPoint(x: 1_435, y: 535),  // desk ensemble anchor
        CGPoint(x: 1_430, y: 723),  // chair anchor
        CGPoint(x: 1_430, y: 850),  // mid desktop band
        CGPoint(x: 1_430, y: 920),  // upper desktop band
        CGPoint(x: 1_430, y: 1_000), // near back edge of desktop
        CGPoint(x: 1_200, y: 700),  // west pedestal
        CGPoint(x: 1_700, y: 850)   // east desktop
    ]

    /// Sample points on the door leaf footprint used by tests (authored space).
    static let authoredDoorLeafSamplePoints: [CGPoint] = [
        CGPoint(x: 2_450, y: 875),
        CGPoint(x: 2_380, y: 860),
        CGPoint(x: 2_520, y: 900)
    ]

    /// Sample points on other major floor solids (authored space).
    static let authoredVisitorArmchairSamplePoints: [CGPoint] = [
        CGPoint(x: 2_300, y: 390),
        CGPoint(x: 2_300, y: 520),
        CGPoint(x: 2_200, y: 450)
    ]

    static let authoredFilingCabinetSamplePoints: [CGPoint] = [
        CGPoint(x: 2_065, y: 990),
        CGPoint(x: 2_000, y: 960),
        CGPoint(x: 2_150, y: 1_020)
    ]

    static let authoredRadiatorSamplePoints: [CGPoint] = [
        CGPoint(x: 545, y: 900),
        CGPoint(x: 400, y: 900),
        CGPoint(x: 700, y: 920)
    ]

    static let authoredCoatRackSamplePoints: [CGPoint] = [
        CGPoint(x: 2_920, y: 890),
        CGPoint(x: 2_850, y: 900),
        CGPoint(x: 3_000, y: 910)
    ]

    private static let authoredApproachPoints: [String: CGPoint] = [
        "office.window": CGPoint(x: 920, y: 1_180),
        "office.desk": CGPoint(x: 1_235, y: 1_085),
        "office.phone": CGPoint(x: 1_300, y: 1_085),
        "office.files": CGPoint(x: 1_160, y: 1_075),
        // In front of the door, clear of the leaf solid and the visitor armchair obstacle.
        "office.door": CGPoint(x: 2_200, y: 750)
    ]

    /// Near corner of the projected floor diamond. A 128×64 tile yields the
    /// fixed 2:1 dimetric perspective used by the background and actor facings.
    private static let authoredProjectionOrigin = CGPoint(x: 1_536, y: 250)
    private static let authoredTileSize = CGSize(width: 128, height: 64)

    static var actorStart: CGPoint { OfficeInteriorScale.mapPoint(authoredActorStart) }

    static let clientArrivalPath: [CGPoint] = [
        CGPoint(x: 2_480, y: 780),
        CGPoint(x: 2_280, y: 690),
        CGPoint(x: 2_050, y: 600)
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
        static let radiator = CGPoint(x: 545, y: 900)
        static let doorLeaf = CGPoint(x: 2_450, y: 875)
        // Maps to the actor's seated visual baseline (navigation root + seatedYOffset).
        static let deskChair = CGPoint(x: 1_430, y: 723)
        static let filingCabinet = CGPoint(x: 2_065, y: 990)
        static let coatRack = CGPoint(x: 2_920, y: 890)
        static let visitorArmchair = CGPoint(x: 2_300, y: 390)
        static let deskEnsemble = CGPoint(x: 1_435, y: 535)
        static let camera = CGPoint(x: 1_536, y: 1_040)
        /// Matches shrunk glass opening on `office_shell_base` (SK y-up).
        static let windowRainMask = CGRect(x: 514, y: 1_225, width: 247, height: 367)
        static let windowRainEmitter = CGPoint(x: 638, y: 1_590)
        static let lampPool = CGPoint(x: 1_475, y: 780)
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
            CGRect(x: 480, y: 1_180, width: 320, height: 460),
            "The rain had been working the glass harder than I had worked a case."
        ),
        (
            "office.desk",
            "Desk",
            CGRect(x: 940, y: 510, width: 1_020, height: 810),
            "Three old cases, two unpaid bills, one clean page."
        ),
        (
            "office.phone",
            "Telephone",
            CGRect(x: 1_560, y: 960, width: 320, height: 250),
            "Quiet. For once it had the decency to look guilty."
        ),
        (
            "office.files",
            "Case files",
            CGRect(x: 1_015, y: 900, width: 510, height: 315),
            "Closed, abandoned, and one I still lied about."
        ),
        (
            "office.door",
            "Office door",
            CGRect(x: 2_300, y: 820, width: 590, height: 900),
            "The hall smelled worse, but at least it led somewhere."
        )
    ]

    static func makeGrid() -> NavigationGrid {
        NavigationGrid(
            projection: .dimetric(
                origin: OfficeInteriorScale.mapPoint(authoredProjectionOrigin),
                tileSize: OfficeInteriorScale.mapSize(authoredTileSize)
            ),
            columns: 21,
            rows: 21,
            obstacles: obstacles,
            agentProfile: .officeDetective
        )
    }

    /// True when a world-space point falls inside any office obstacle (including the door).
    static func isBlocked(_ point: CGPoint) -> Bool {
        obstacles.contains { $0.contains(point) }
    }
}

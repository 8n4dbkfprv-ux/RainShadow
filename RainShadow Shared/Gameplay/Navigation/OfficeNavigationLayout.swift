import CoreGraphics

enum OfficeNavigationLayout {
    /// Authoring-space (pre-scale) layout, then mapped through `OfficeInteriorScale`.

    private static let authoredActorStart = CGPoint(x: 1_430, y: 1_080)

    /// Ground-contact footprints in authored (pre-scale) space. These deliberately
    /// exclude the tall visible portions of props: those are handled by depth
    /// sorting, while navigation only blocks the area touching the floor.
    private static let authoredObstacles = [
        CGRect(x: 945, y: 500, width: 1_015, height: 300), // desk and chair
        CGRect(x: 2_080, y: 285, width: 530, height: 260), // visitor armchair
        CGRect(x: 1_865, y: 900, width: 430, height: 180), // filing cabinet
        CGRect(x: 285, y: 840, width: 535, height: 120), // radiator
        CGRect(x: 2_285, y: 790, width: 300, height: 160), // coat rack
        authoredDoorObstacle
    ]

    /// Door leaf floor solid in authored space (registered to the V2 shell opening).
    static let authoredDoorObstacle = CGRect(x: 2_260, y: 800, width: 400, height: 180)

    /// Sample points on the door leaf footprint used by tests (authored space).
    static let authoredDoorLeafSamplePoints: [CGPoint] = [
        CGPoint(x: 2_450, y: 875),
        CGPoint(x: 2_380, y: 860),
        CGPoint(x: 2_520, y: 900)
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

    static var doorObstacle: CGRect {
        OfficeInteriorScale.mapRect(authoredDoorObstacle)
    }

    static var doorLeafSamplePoints: [CGPoint] {
        authoredDoorLeafSamplePoints.map(OfficeInteriorScale.mapPoint)
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
            obstacles: obstacles
        )
    }

    /// True when a world-space point falls inside any office obstacle (including the door).
    static func isBlocked(_ point: CGPoint) -> Bool {
        obstacles.contains { $0.contains(point) }
    }
}

import CoreGraphics

/// Baldur's Gate-scale office contract. The generated shell, prop sprites and
/// actors have independent display scales but share one authored coordinate map.
enum OfficeInteriorScale {
    static let standingDetectiveSourceHeight: CGFloat = 100
    static let seatedDetectiveSourceHeight: CGFloat = 100
    /// Client atlases use the same 100-unit adult body as the detective (BG:EE
    /// party-member height class — no child-scale or giant-scale adults).
    static let standingClientSourceHeight: CGFloat = 100

    enum ActorDisplay {
        /// Actor atlases carry a 200px opaque body at 2x texture density. The V3
        /// office presents it as an 82-unit body, matching the tavern references.
        static let standingScale: CGFloat = 0.82
        static let seatedScale: CGFloat = 0.82
        /// Visual-only shift from the walkable navigation root into the chair/desk registration.
        static let seatedYOffset: CGFloat = -82
    }

    static let detectiveBodyHeight = standingDetectiveSourceHeight * ActorDisplay.standingScale
    static let seatedDetectiveBodyHeight = seatedDetectiveSourceHeight * ActorDisplay.seatedScale
    /// Same adult height as the detective — shared humanoid contract for office play.
    static let clientBodyHeight = standingClientSourceHeight * ActorDisplay.standingScale
    /// Canonical standing adult used by office furniture body-multiples and city props.
    static var standingAdultBodyHeight: CGFloat { detectiveBodyHeight }

    /// V3 shell / coordinate-map scale. The shell was regenerated with much
    /// smaller built features and a genuinely larger floor footprint; this is
    /// deliberately not reused as a prop scale.
    static let environment: CGFloat = 0.395

    /// Slightly tighter than the shared BG:EE mid-band (~9%): the office plate is
    /// cavernous, so ~10.5% body density crops empty foreground without breaking
    /// the 8–11% play-density band.
    static let playBodyToVisibleHeight: CGFloat = 0.105

    /// Presentation scale only; furniture/body proportions stay in world space.
    static var cameraVisibleHeight: CGFloat {
        standingAdultBodyHeight / playBodyToVisibleHeight
    }

    /// V3 plate centre and scale-about focus.
    static let layoutFocus = CGPoint(x: 2_048, y: 1_152)

    /// 16:9 V3 area plate derived from the 3840x2160 generated master.
    static let sourceArtOrigin = CGPoint.zero
    static let sourceArtSize = CGSize(width: 4_096, height: 2_304)

    // MARK: - Measured source content heights (opaque bbox of runtime PNGs)
    // Kept here so tests and scene code share one source of truth.

    enum SourceContentHeight {
        static let deskEnsemble: CGFloat = 760
        /// Floor contact → desktop face (includes drawer pedestal).
        static let deskWorkingSurface: CGFloat = 249
        /// Vertical drawer-stack face only (floor contact through top drawer rail, no lamp/desktop clutter).
        static let deskDrawerFace: CGFloat = 240
        static let deskLamp: CGFloat = 250
        static let deskPhone: CGFloat = 142
        static let deskMug: CGFloat = 123
        static let deskAshtray: CGFloat = 73
        static let deskFiles: CGFloat = 178
        static let deskPapers: CGFloat = 240
        static let deskChair: CGFloat = 438
        static let doorLeaf: CGFloat = 720
        static let filingCabinet: CGFloat = 549
        static let visitorArmchair: CGFloat = 430
        static let radiator: CGFloat = 340
        static let coatRack: CGFloat = 557
        static let archiveBox: CGFloat = 300
        static let wastebasket: CGFloat = 220
        static let floorTrash: CGFloat = 140
        static let wornRug: CGFloat = 500
        static let hiddenBottle: CGFloat = 200
        static let framedPhoto: CGFloat = 180
        static let pencilTray: CGFloat = 70
        static let standingDetective = standingDetectiveSourceHeight
        static let seatedDetective = seatedDetectiveSourceHeight
        /// V6 shell window glass opening (source pixels on office_shell_base).
        static let windowGlassOpening: CGFloat = 136
    }

    /// Per-prop scale relative to the V3 shell/coordinate scale. Absolute
    /// targets: standard 0.22, seating 0.17, desk 0.14, window overlay 0.24,
    /// floor decal 0.18, small props 0.12, pocket props 0.10.
    enum PropRelativeScale {
        static let standard: CGFloat = 0.22 / environment
        static let deskEnsemble: CGFloat = 0.14 / environment
        static let deskChair: CGFloat = 0.17 / environment
        static let visitorArmchair: CGFloat = 0.17 / environment
        static let window: CGFloat = 0.24 / environment
        static let floorDecal: CGFloat = 0.22 / environment
        static let smallProp: CGFloat = 0.12 / environment
        static let pocketProp: CGFloat = 0.10 / environment
        /// Full-plate overlays sized against the shell art (no extra relative inflate).
        static let plateOverlay: CGFloat = 1.0 / environment
    }

    // MARK: - BG acceptance bands (multiples of detective body)

    enum Band {
        static let standingBody: ClosedRange<CGFloat> = 78...90
        static let door: ClosedRange<CGFloat> = 1.80...2.20
        static let deskWorkingSurface: ClosedRange<CGFloat> = 0.32...0.50
        /// Drawer pedestal face: roughly knee-to-hip furniture.
        static let deskDrawerFace: ClosedRange<CGFloat> = 0.30...0.48
        static let deskLamp: ClosedRange<CGFloat> = 0.35...0.65
        static let deskPhone: ClosedRange<CGFloat> = 0.20...0.35
        static let deskMug: ClosedRange<CGFloat> = 0.15...0.30
        static let deskAshtray: ClosedRange<CGFloat> = 0.08...0.18
        static let deskFiles: ClosedRange<CGFloat> = 0.20...0.40
        static let deskPapers: ClosedRange<CGFloat> = 0.25...0.50
        static let chair: ClosedRange<CGFloat> = 0.6...1.0
        static let cabinet: ClosedRange<CGFloat> = 1.10...1.80
        /// Single rain window glass opening (not multi-story glass).
        /// Smaller than classic BG tavern glass: this office's short upper-wall band
        /// cannot host a 0.75–1.25× adult window without dominating the west wall.
        static let windowGlass: ClosedRange<CGFloat> = 0.55...0.90
    }

    // MARK: - Mapping

    static func mapPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: layoutFocus.x + (point.x - layoutFocus.x) * environment,
            y: layoutFocus.y + (point.y - layoutFocus.y) * environment
        )
    }

    static func mapSize(_ size: CGSize) -> CGSize {
        CGSize(width: size.width * environment, height: size.height * environment)
    }

    static func mapRect(_ rect: CGRect) -> CGRect {
        let origin = mapPoint(rect.origin)
        return CGRect(
            x: origin.x,
            y: origin.y,
            width: rect.width * environment,
            height: rect.height * environment
        )
    }

    /// World-unit height of opaque content after environment and relative prop scale.
    static func effectiveHeight(contentHeight: CGFloat, relativeScale: CGFloat = 1) -> CGFloat {
        contentHeight * environment * relativeScale
    }

    /// Furniture height as a multiple of standing detective body height.
    static func bodyMultiple(contentHeight: CGFloat, relativeScale: CGFloat = 1) -> CGFloat {
        effectiveHeight(contentHeight: contentHeight, relativeScale: relativeScale) / detectiveBodyHeight
    }

    /// Desk ensemble world display scale (environment × desk-relative).
    static var deskDisplayScale: CGFloat {
        environment * PropRelativeScale.deskEnsemble
    }

    static var standardPropDisplayScale: CGFloat {
        environment * PropRelativeScale.standard
    }

    static var seatingPropDisplayScale: CGFloat {
        environment * PropRelativeScale.deskChair
    }

    static var visitorArmchairDisplayScale: CGFloat {
        environment * PropRelativeScale.visitorArmchair
    }

    static var windowDisplayScale: CGFloat {
        environment * PropRelativeScale.window
    }

    static var floorDecalDisplayScale: CGFloat {
        environment * PropRelativeScale.floorDecal
    }

    /// Archive boxes, wastebasket, and floor trash — knee-high clutter, not furniture.
    static var smallPropDisplayScale: CGFloat {
        environment * PropRelativeScale.smallProp
    }

    /// Pocket-scale props tucked under the desk (e.g. hidden bottle).
    static var pocketPropDisplayScale: CGFloat {
        environment * PropRelativeScale.pocketProp
    }

    /// Alias kept for call sites that mean floor scrap clutter.
    static var clutterDisplayScale: CGFloat { smallPropDisplayScale }

    /// Display scale so a runtime texture matches shell world size 1:1 with art pixels.
    static var plateOverlayDisplayScale: CGFloat {
        environment * PropRelativeScale.plateOverlay
    }

    static var scaledArtSize: CGSize { mapSize(sourceArtSize) }

    static var shellOrigin: CGPoint { mapPoint(sourceArtOrigin) }
}

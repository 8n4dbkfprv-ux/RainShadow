import CoreGraphics

/// Single interior scale contract: standing detective stays ~100 world units;
/// shell + props share one environment scale so furniture-to-body ratios
/// match Baldur's Gate playable-view proportions from the user reference shots.
enum OfficeInteriorScale {
    static let standingDetectiveSourceHeight: CGFloat = 100
    static let seatedDetectiveSourceHeight: CGFloat = 100

    enum ActorDisplay {
        /// Actor atlases were authored against the room at their native 100px
        /// opaque height. Enlarging standing frames to 130% made the detective
        /// nearly as tall as the door and broke the fixed room perspective.
        static let standingScale: CGFloat = 1
        static let seatedScale: CGFloat = 1
        /// Visual-only shift from the walkable navigation root into the chair/desk registration.
        static let seatedYOffset: CGFloat = -100
    }

    static let detectiveBodyHeight = standingDetectiveSourceHeight * ActorDisplay.standingScale
    static let seatedDetectiveBodyHeight = seatedDetectiveSourceHeight * ActorDisplay.seatedScale

    /// Uniform display scale for shell architecture and free props.
    /// Chosen so door leaf ≈ 2.0× body (BG band 1.8–2.5).
    static let environment: CGFloat = 0.28

    /// Frames the scaled room at roughly 86% of viewport height. The panoramic
    /// V2 shell adds authored floor area horizontally, so this deliberately
    /// keeps the prior actor/prop scale and vertical camera framing unchanged.
    static var cameraVisibleHeight: CGFloat { scaledArtSize.height / 0.86 }

    /// Layout focus for scale-about transform (matches prior camera center / room mid).
    static let layoutFocus = CGPoint(x: 1_536, y: 1_024)

    /// Panoramic V2 area plate. The original 3072-wide authoring coordinates
    /// remain stable; the new shell extends 512 source pixels on either side.
    static let sourceArtOrigin = CGPoint(x: -512, y: 0)
    static let sourceArtSize = CGSize(width: 4_096, height: 2_048)

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
        static let doorLeaf: CGFloat = 705
        static let filingCabinet: CGFloat = 549
        static let visitorArmchair: CGFloat = 430
        static let radiator: CGFloat = 340
        static let coatRack: CGFloat = 557
        static let standingDetective = standingDetectiveSourceHeight
        static let seatedDetective = seatedDetectiveSourceHeight
        /// Shell window glass opening height after shrink (source pixels on office_shell_base).
        static let windowGlassOpening: CGFloat = 367
    }

    /// Additional per-prop scale relative to environment.
    enum PropRelativeScale {
        /// Shrinks desk pedestal/drawers into the knee–hip band vs the 100px standing body.
        static let deskEnsemble: CGFloat = 0.68
        static let deskChair: CGFloat = 0.72
        static let standard: CGFloat = 1
    }

    // MARK: - BG acceptance bands (multiples of detective body)

    enum Band {
        static let standingBody: ClosedRange<CGFloat> = 95...110
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
        static let windowGlass: ClosedRange<CGFloat> = 0.75...1.25
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

    static var scaledArtSize: CGSize { mapSize(sourceArtSize) }

    static var shellOrigin: CGPoint { mapPoint(sourceArtOrigin) }
}

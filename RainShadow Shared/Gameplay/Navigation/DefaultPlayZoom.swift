import CoreGraphics

/// Default human-scale density for playable maps.
///
/// Reference is BG:EE's zoomable widescreen view, whose area framing shows
/// roughly 9% of the visible height per standing adult.
///
/// This has been both ways. The original BG1 (1998) figure is ~13% — a 512×384
/// unobstructed playfield with a ~50 px adult — and the project ran at 13% for
/// a while, after a 9% pass was judged "a camera pulled too far back". In play
/// that reading turned out to be confounded: the city fog only lit 45% of the
/// screen width, so a wider camera made districts look emptier rather than
/// larger. Sizing the fog to the screen settled it, and 9% is the framing that
/// matches what BG:EE actually shows.
///
/// Sight is a creature stat again (`AreaAgentProfile.visualRangeInCells`, the
/// engine's 14 cells), so how much of the screen a district lights is authored
/// per area rather than derived from the viewport. If a district reads as a
/// keyhole of pavement again, that number is the one to raise — not this one.
///
/// 13% is still reachable — it is zoom step 10 (70%) of `CameraZoom`'s 1…27 band —
/// so this is a change of default, not of range.
///
/// Small rooms may occupy less of the viewport than large maps; preserving the
/// human scale is more important than enlarging a compact plate to fill every
/// edge.
///
/// Presentation grammar matches the Infinity Engine: fixed orthographic /
/// dimetric view; only uniform camera scale and authored or followed pan define
/// the view — no free pitch, yaw, or perspective FOV.
enum DefaultPlayZoom {
    /// Standing adult body height ÷ default camera-visible world height
    /// (default area-view density).
    static let bodyToVisibleHeightBand: ClosedRange<CGFloat> = 0.080...0.100

    /// Mid-band target (~9%), BG:EE area-view density.
    static let targetBodyToVisibleHeight: CGFloat = 0.09

    /// World-unit height the camera should show so `standingBodyHeight` lands on
    /// `targetBodyToVisibleHeight`. Pass the **rendered** on-screen body height
    /// (not a logical locomotion height), or density will undershoot on screen.
    static func cameraVisibleHeight(standingBodyHeight: CGFloat) -> CGFloat {
        standingBodyHeight / targetBodyToVisibleHeight
    }

    /// Body as a fraction of the camera-visible world height.
    static func standingBodyFraction(bodyHeight: CGFloat, visibleWorldHeight: CGFloat) -> CGFloat {
        bodyHeight / visibleWorldHeight
    }

    static func isInBand(bodyHeight: CGFloat, visibleWorldHeight: CGFloat) -> Bool {
        bodyToVisibleHeightBand.contains(
            standingBodyFraction(bodyHeight: bodyHeight, visibleWorldHeight: visibleWorldHeight)
        )
    }

    /// Uniform orthographic scale used by `BaseGameScene.layoutViewport`.
    /// `SKCameraNode` scale = visible world height ÷ scene view height.
    static func cameraScale(visibleWorldHeight: CGFloat, sceneHeight: CGFloat) -> CGFloat {
        guard sceneHeight > 0 else { return 1 }
        return visibleWorldHeight / sceneHeight
    }
}

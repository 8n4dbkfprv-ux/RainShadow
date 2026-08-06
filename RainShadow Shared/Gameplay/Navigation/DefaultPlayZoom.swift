import CoreGraphics

/// Default human-scale density for playable maps.
///
/// Reference is the original Baldur's Gate (1998), not BG:EE. There the
/// unobstructed playfield is 512×384 and a standing adult sprite is ~50 px, so
/// the adult occupies ~13% of the visible height at the engine's native 1:1
/// zoom. BG:EE's zoomable widescreen view shows far more world per adult (~9%),
/// which is why the previous 9% target read as a camera pulled too far back.
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
    static let bodyToVisibleHeightBand: ClosedRange<CGFloat> = 0.115...0.145

    /// Mid-band target (~13%) measured from original BG1 play density.
    static let targetBodyToVisibleHeight: CGFloat = 0.13

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

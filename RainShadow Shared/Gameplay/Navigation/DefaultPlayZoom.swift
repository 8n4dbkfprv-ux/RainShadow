import CoreGraphics

/// Default human-scale density for fixed-camera playable maps.
///
/// In the reference Baldur's Gate area view, a standing adult is roughly 8–11%
/// of the unobstructed playfield. Small rooms may occupy less of the viewport
/// than large maps; preserving the human scale is more important than enlarging
/// a compact plate to fill every edge.
///
/// Presentation grammar matches BG:EE: fixed orthographic / dimetric view;
/// only uniform camera scale and authored pan define the view — no free pitch,
/// yaw, or perspective FOV.
enum DefaultPlayZoom {
    /// Standing adult body height ÷ default camera-visible world height
    /// (default area-view density).
    static let bodyToVisibleHeightBand: ClosedRange<CGFloat> = 0.08...0.11

    /// Mid-band target (~9%) measured from BG:EE play density.
    static let targetBodyToVisibleHeight: CGFloat = 0.09

    /// World-unit height the camera should show so `standingBodyHeight` lands on
    /// `targetBodyToVisibleHeight`.
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

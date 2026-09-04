import CoreGraphics

/// The 100% camera calibration for native indexed creature sprites.
///
/// An Infinity Engine BAM frame is already a display-resolution image. At
/// `GameControl`'s 100% zoom, GemRB leaves the viewport unscaled:
///
/// ```
/// auto scale = GetScalePercent();
/// if (scale == 100) {
///     return;
/// }
/// viewport.Scale(scale);
/// ```
///
/// RainShadow keeps Voss's architecture-locked world height, so the equivalent
/// SpriteKit calibration is one native standing-body row per logical view point at
/// 100%. The camera therefore owns the conversion from world units to the
/// native raster. It does not fit the actor to a fixed fraction of every window.
/// A larger window reveals more of the area, as the engine viewport does.
/// Registered crop widths/pivots retain their existing source-pixel rounding;
/// this is native body-height calibration, not pixel-exact BAM registration.
///
/// SpriteKit and the OS still map logical points to backing pixels (for example
/// 2x on a Retina display). That display backing scale is outside the game-world
/// camera contract, just as window-system output scaling is outside a BAM.
enum DefaultPlayZoom {
    /// World units per logical view point needed to show a native body at 1:1.
    static func nativeSpriteCameraScale(
        standingBodyHeight: CGFloat,
        nativeBodyPixelHeight: CGFloat
    ) -> CGFloat {
        guard standingBodyHeight > 0, nativeBodyPixelHeight > 0 else { return 1 }
        return standingBodyHeight / nativeBodyPixelHeight
    }

    /// World height visible through a view at a given uniform camera scale.
    static func cameraVisibleHeight(sceneHeight: CGFloat, cameraScale: CGFloat) -> CGFloat {
        guard sceneHeight > 0, cameraScale > 0 else { return 0 }
        return sceneHeight * cameraScale
    }

    /// Logical view-point height of a body at a given camera scale.
    static func displayedBodyHeight(bodyHeight: CGFloat, cameraScale: CGFloat) -> CGFloat {
        guard cameraScale > 0 else { return 0 }
        return bodyHeight / cameraScale
    }

    /// Uniform orthographic scale for fixed-height cinematic framing.
    /// `SKCameraNode` scale = visible world height ÷ scene view height.
    static func cameraScale(visibleWorldHeight: CGFloat, sceneHeight: CGFloat) -> CGFloat {
        guard sceneHeight > 0 else { return 1 }
        return visibleWorldHeight / sceneHeight
    }
}

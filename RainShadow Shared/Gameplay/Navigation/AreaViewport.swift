import CoreGraphics

/// Where the viewport may sit over an area.
///
/// This is `GameControl::MoveViewportTo`'s clamp block, transliterated from
/// GemRB:
///
/// ```
/// Size mapsize = area->GetSize();
/// // TODO: make the overflow more dynamic
/// if (viewport.w >= mapsize.w + 64) {
///     p.x = (mapsize.w - viewport.w) / 2;
/// } else if (p.x + viewport.w >= mapsize.w + 64) {
///     p.x = mapsize.w - viewport.w + 64;
/// } else if (p.x < -64) {
///     p.x = -64;
/// }
///
/// constexpr int padding = 50;
/// if (viewport.h >= mapsize.h + mwinh + padding) {
///     p.y = (mapsize.h - viewport.h) / 2 + padding;
/// } else if (p.y + viewport.h >= mapsize.h + mwinh + padding) {
///     p.y = mapsize.h - viewport.h + mwinh + padding;
/// } else if (p.y < 0) {
///     p.y = 0;
/// }
/// ```
///
/// `mwinh` is the message text area's height, which RainShadow has no
/// counterpart for, so it is zero throughout.
///
/// **The engine lets black show.** Once the viewport outgrows the area the
/// engine centres the *map* inside it rather than refusing the zoom, and the
/// margin is void. That framing is deliberate — see `CameraZoom` for the band
/// that reaches it.
///
/// **The axes are not symmetric, and that is upstream.** GemRB's viewport is a
/// top-left origin in a y-*down* map space; a `SKCameraNode` is a centre in a
/// y-*up* world. Translating leaves two asymmetries that look like bugs:
///
/// - x overflows by 64 on **both** sides. y overflows by `padding` on one side
///   only — `p.y < 0` pins the engine's map top flush, with no give at all.
///   Engine-top is world `maxY`, so here the viewport may drop 50 units below
///   `minY` and may not rise one unit above `maxY`.
/// - the over-large centring carries `+ padding` too, so it is not a true
///   centre: world centre y lands on `map.midY - farEdgePadding`.
///
/// Both exist upstream to keep the map clear of the message window. Squaring
/// them up is the obvious-looking change and disagrees with the engine.
enum AreaViewport {
    /// GemRB's literal `64`, the horizontal overflow past the area edge.
    static let overflow: CGFloat = 64
    /// GemRB's `constexpr int padding = 50`.
    static let farEdgePadding: CGFloat = 50

    /// Camera centre `target` clamped over `map`, in y-up world space.
    ///
    /// - Parameters:
    ///   - target: desired camera centre.
    ///   - viewport: camera-visible world size at the current zoom.
    ///   - map: the area rect — GemRB's `area->GetSize()`, which is an origin
    ///     here because RainShadow areas do not all start at zero.
    static func clampedCenter(_ target: CGPoint, viewport: CGSize, map: CGRect) -> CGPoint {
        // `canMove = area != nullptr`: with no area the engine never clamps.
        guard !map.isEmpty else { return target }

        let halfWidth = viewport.width / 2
        let halfHeight = viewport.height / 2
        var centre = target

        if viewport.width >= map.width + overflow {
            centre.x = map.midX
        } else if centre.x + halfWidth >= map.maxX + overflow {
            centre.x = map.maxX + overflow - halfWidth
        } else if centre.x - halfWidth < map.minX - overflow {
            centre.x = map.minX - overflow + halfWidth
        }

        if viewport.height >= map.height + farEdgePadding {
            centre.y = map.midY - farEdgePadding
        } else if centre.y - halfHeight <= map.minY - farEdgePadding {
            centre.y = map.minY - farEdgePadding + halfHeight
        } else if centre.y + halfHeight > map.maxY {
            centre.y = map.maxY - halfHeight
        }

        return centre
    }
}

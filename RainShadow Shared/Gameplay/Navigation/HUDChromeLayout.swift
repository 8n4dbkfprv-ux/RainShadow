import CoreGraphics

/// Pure, SpriteKit-free geometry for Infinity Engine–style HUD rails.
/// Layout is driven by painted art aspect ratios so chrome is never non-uniformly stretched.
enum HUDChromeLayout {
    // MARK: - Left action rail (`hud_left_rail_plate_v03` 256×2048)

    enum LeftRail {
        /// Painted plate pixel size (runtime PNG).
        static let artPixelSize = CGSize(width: 256, height: 2_048)
        /// Width / height of the painted plate — uniform scale must preserve this.
        static let artAspectWidthOverHeight: CGFloat = 256.0 / 2_048.0
        static let wellCount = 12
        /// Well centers as fractions from the **top** of the cropped plate.
        /// Measured from horizontal metal dividers on `hud_left_rail_plate_v03`
        /// (equal spacing drifts ~2% low by the bottom well).
        static let wellCenterFractionsFromTop: [CGFloat] = [
            0.0770, 0.1614, 0.2409, 0.3186, 0.3961, 0.4738,
            0.5513, 0.6286, 0.7043, 0.7815, 0.8600, 0.9375
        ]
        /// Dark icon recess width relative to plate width (measured ~0.54 on art).
        static let wellWidthFractionOfPlate: CGFloat = 0.54
        /// Well height relative to plate height (measured slot ~0.078; square via min with width).
        static let wellHeightFractionOfPlate: CGFloat = 0.072
        /// Icons fill the well without overflowing the painted rim.
        static let iconFillOfWell: CGFloat = 0.90
        /// Vertical inset so top/bottom metal caps clear the view edge.
        static let edgePad: CGFloat = 10
        /// Horizontal inset so the painted left rim is not clipped by the SKView edge.
        /// Must stay ≥ 8; flush-left placement loses the outer metal bevel.
        static let leftInset: CGFloat = 16
        /// Soft min/max so icons stay usable on short viewports without a huge bar on 4K.
        static let minPlateWidth: CGFloat = 64
        static let maxPlateWidth: CGFloat = 120
        /// Hit target is slightly larger than the icon for fat-finger / mouse ease.
        static let hitPadding: CGFloat = 6

        /// Texture crop of the opaque plate (SpriteKit bottom-left origin).
        static let plateContentRect = CGRect(x: 0.01, y: 0.01, width: 0.98, height: 0.98)
    }

    struct LeftRailLayout: Equatable {
        /// Drawn plate size (aspect-locked to art).
        let plateSize: CGSize
        /// Plate center in HUD root space (origin = viewport center).
        let plateCenter: CGPoint
        /// Well rects in plate-local space (origin = plate center).
        let wellRects: [CGRect]
        /// Icon draw rects (centered in wells, square) in plate-local space.
        let iconRects: [CGRect]

        var railWidth: CGFloat { plateSize.width }

        /// Axis-aligned plate bounds in viewport-centered HUD space.
        var plateFrame: CGRect {
            CGRect(
                x: plateCenter.x - plateSize.width / 2,
                y: plateCenter.y - plateSize.height / 2,
                width: plateSize.width,
                height: plateSize.height
            )
        }

        /// Icon extent (side length) shared by all wells when wells are square.
        var iconExtent: CGFloat {
            guard let first = iconRects.first else { return 0 }
            return first.width
        }
    }

    /// Aspect-locked left rail that fits the visible HUD height without non-uniform stretch.
    static func leftRailLayout(for visibleSize: CGSize) -> LeftRailLayout {
        let maxH = max(1, visibleSize.height - LeftRail.edgePad * 2)
        // Prefer filling height (IE spine density); width follows art aspect.
        var plateH = maxH
        var plateW = plateH * LeftRail.artAspectWidthOverHeight

        if plateW > LeftRail.maxPlateWidth {
            plateW = LeftRail.maxPlateWidth
            plateH = plateW / LeftRail.artAspectWidthOverHeight
        }
        if plateW < LeftRail.minPlateWidth {
            plateW = LeftRail.minPlateWidth
            plateH = plateW / LeftRail.artAspectWidthOverHeight
            if plateH > maxH {
                plateH = maxH
                plateW = plateH * LeftRail.artAspectWidthOverHeight
            }
        }

        // Center the plate vertically (when shorter than the window after max-width clamp).
        // Inset from the left so the full painted metal rim stays inside the view.
        let plateCenter = CGPoint(
            x: -visibleSize.width / 2 + LeftRail.leftInset + plateW / 2,
            y: 0
        )

        let wellW = plateW * LeftRail.wellWidthFractionOfPlate
        let wellH = plateH * LeftRail.wellHeightFractionOfPlate
        // Square wells sized to the painted circular recesses (not oversize).
        let wellSide = min(wellW, wellH)
        let iconSide = wellSide * LeftRail.iconFillOfWell
        let centers = LeftRail.wellCenterFractionsFromTop

        var wellRects: [CGRect] = []
        var iconRects: [CGRect] = []
        for index in 0..<LeftRail.wellCount {
            let frac: CGFloat
            if index < centers.count {
                frac = centers[index]
            } else {
                frac = (CGFloat(index) + 0.5) / CGFloat(LeftRail.wellCount)
            }
            // Plate-local: top of plate is +plateH/2.
            let y = plateH / 2 - frac * plateH
            let well = CGRect(
                x: -wellSide / 2,
                y: y - wellSide / 2,
                width: wellSide,
                height: wellSide
            )
            let icon = CGRect(
                x: -iconSide / 2,
                y: y - iconSide / 2,
                width: iconSide,
                height: iconSide
            )
            wellRects.append(well)
            iconRects.append(icon)
        }

        return LeftRailLayout(
            plateSize: CGSize(width: plateW, height: plateH),
            plateCenter: plateCenter,
            wellRects: wellRects,
            iconRects: iconRects
        )
    }

    // MARK: - Right party rail (`hud_right_rail_plate_v03` letterboxed content)

    enum RightRail {
        static let railWidth: CGFloat = 124
        static let topInset: CGFloat = 10
        /// Opaque portrait+utility band (SpriteKit texture coords, origin bottom-left).
        static let plateContentRect = CGRect(x: 0.0, y: 0.383, width: 0.997, height: 0.234)
        /// Cropped content pixels ≈ 320×479 → height/width.
        static let plateContentAspectHeightOverWidth: CGFloat = 479.0 / 320.0

        /// Portrait hole inside cropped plate (fractions from **top** of content).
        /// Matches the punched transparent window on `hud_right_rail_plate_v03`
        /// (x≈0.10–0.90, y≈0.06–0.46 of the content crop).
        static let portraitTopFraction: CGFloat = 0.060
        static let portraitHeightFraction: CGFloat = 0.396
        static let portraitLeftFraction: CGFloat = 0.100
        static let portraitWidthFraction: CGFloat = 0.797
        /// Keep square photo clear of the metal rim (fraction of the short window side).
        static let portraitInnerInsetFraction: CGFloat = 0.08
        /// Absolute floor on the inner inset (points).
        static let portraitInnerInsetMin: CGFloat = 4

        /// Three utility slots below the portrait (centers from top of content).
        /// Measured from metal slot rails on the cropped plate (~0.53 / 0.67 / 0.79 / 0.91).
        static let utilityCenterFractionsFromTop: [CGFloat] = [0.596, 0.729, 0.853]
        /// Well side as a fraction of plate **height** (slot interior ~0.12 after rims).
        static let utilitySizeFractionOfPlateHeight: CGFloat = 0.10
        /// Cap relative to plate width so icons stay inside the metal rim.
        static let utilityMaxWidthFraction: CGFloat = 0.52
        static let utilityCenterXFractionFromLeft: CGFloat = 0.50
        static let utilityIconFill: CGFloat = 0.90

        static var plateHeight: CGFloat { railWidth * plateContentAspectHeightOverWidth }
    }

    struct RightRailLayout: Equatable {
        let plateSize: CGSize
        /// Plate center in HUD root space.
        let plateCenter: CGPoint
        /// Portrait window in plate-local space (origin = plate center).
        let portraitWindowRect: CGRect
        /// Photo rect fully inside the window (after inner inset).
        let portraitPhotoRect: CGRect
        /// Utility well rects in plate-local space.
        let utilityWellRects: [CGRect]
        /// Utility icon rects centered in wells.
        let utilityIconRects: [CGRect]

        var railWidth: CGFloat { plateSize.width }
    }

    static func rightRailLayout(for visibleSize: CGSize) -> RightRailLayout {
        let plateW = RightRail.railWidth
        let plateH = RightRail.plateHeight
        let plateSize = CGSize(width: plateW, height: plateH)
        let plateCenter = CGPoint(
            x: visibleSize.width / 2 - plateW / 2,
            y: visibleSize.height / 2 - RightRail.topInset - plateH / 2
        )

        let window = portraitWindowRect(in: plateSize)
        // Square photo CONTAINED in the window (not aspect-fill cover). Cover sizing
        // made the face too large for the short hole and looked like it spilled the bar.
        let inset = max(
            RightRail.portraitInnerInsetMin,
            min(window.width, window.height) * RightRail.portraitInnerInsetFraction
        )
        let photoSide = max(1, min(window.width, window.height) - inset * 2)
        let photo = CGRect(
            x: window.midX - photoSide / 2,
            y: window.midY - photoSide / 2,
            width: photoSide,
            height: photoSide
        )

        // Square wells sized for vertical stacking without overlap, capped by plate width.
        let fracs = RightRail.utilityCenterFractionsFromTop
        let minCenterGap: CGFloat = {
            guard fracs.count >= 2 else { return plateH * 0.14 }
            var minGap = CGFloat.greatestFiniteMagnitude
            for i in 0..<(fracs.count - 1) {
                minGap = min(minGap, abs(fracs[i + 1] - fracs[i]) * plateH)
            }
            return minGap
        }()
        let wellSide = min(
            plateH * RightRail.utilitySizeFractionOfPlateHeight,
            plateW * RightRail.utilityMaxWidthFraction,
            minCenterGap * 0.88
        )
        let iconSide = wellSide * RightRail.utilityIconFill
        let ux = -plateW / 2 + plateW * RightRail.utilityCenterXFractionFromLeft
        var wells: [CGRect] = []
        var icons: [CGRect] = []
        for frac in fracs {
            let y = plateH / 2 - frac * plateH
            wells.append(CGRect(x: ux - wellSide / 2, y: y - wellSide / 2, width: wellSide, height: wellSide))
            icons.append(CGRect(x: ux - iconSide / 2, y: y - iconSide / 2, width: iconSide, height: iconSide))
        }

        return RightRailLayout(
            plateSize: plateSize,
            plateCenter: plateCenter,
            portraitWindowRect: window,
            portraitPhotoRect: photo,
            utilityWellRects: wells,
            utilityIconRects: icons
        )
    }

    static func portraitWindowRect(in plate: CGSize) -> CGRect {
        let w = plate.width * RightRail.portraitWidthFraction
        let h = plate.height * RightRail.portraitHeightFraction
        let x = -plate.width / 2 + plate.width * RightRail.portraitLeftFraction
        let y = plate.height / 2
            - plate.height * RightRail.portraitTopFraction
            - h
        return CGRect(x: x, y: y, width: w, height: h)
    }

    // MARK: - Shared clearance (dialogue must clear these rails)

    /// Width reserved on the left for the action rail + breathing room.
    static func leftRailClearance(for visibleSize: CGSize) -> CGFloat {
        LeftRail.leftInset + leftRailLayout(for: visibleSize).railWidth + 10
    }

    /// True when the plate's axis-aligned bounds sit fully inside the viewport
    /// (HUD root space with origin at the view center) with the configured left inset.
    static func leftRailFullyOnScreen(for visibleSize: CGSize) -> Bool {
        let layout = leftRailLayout(for: visibleSize)
        let halfW = visibleSize.width / 2
        let halfH = visibleSize.height / 2
        let frame = layout.plateFrame
        let minLeft = -halfW + LeftRail.leftInset
        return frame.minX >= minLeft - 0.001
            && frame.maxX <= halfW + 0.001
            && frame.minY >= -halfH - 0.001
            && frame.maxY <= halfH + 0.001
    }

    /// Right portrait plate frame in viewport-centered HUD space.
    static func rightRailPlateFrame(for visibleSize: CGSize) -> CGRect {
        let layout = rightRailLayout(for: visibleSize)
        return CGRect(
            x: layout.plateCenter.x - layout.plateSize.width / 2,
            y: layout.plateCenter.y - layout.plateSize.height / 2,
            width: layout.plateSize.width,
            height: layout.plateSize.height
        )
    }

    static func rightRailFullyOnScreen(for visibleSize: CGSize) -> Bool {
        let frame = rightRailPlateFrame(for: visibleSize)
        let halfW = visibleSize.width / 2
        let halfH = visibleSize.height / 2
        return frame.minX >= -halfW - 0.001
            && frame.maxX <= halfW + 0.001
            && frame.minY >= -halfH - 0.001
            && frame.maxY <= halfH + 0.001
    }

    /// Width reserved on the right for the party rail + breathing room.
    static func rightRailClearance(for visibleSize: CGSize) -> CGFloat {
        rightRailLayout(for: visibleSize).railWidth + 10
    }
}

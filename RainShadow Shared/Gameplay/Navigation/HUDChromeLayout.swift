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

        /// Full texture bounds (SpriteKit bottom-left origin). The painted top and
        /// bottom ornaments reach the source edges, so even a 1% crop clips them.
        static let plateContentRect = CGRect(x: 0, y: 0, width: 1, height: 1)
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

    // MARK: - Compact loot container panel

    enum LootContainerPanel {
        static let slotsPerPage = 6
        static let sourceColumns = 3
        static let sourceRows = 2
        static let bagSlotsPerRow = 2
        static let bagVisibleRowCount = 2
        static let bagSlotsPerViewport = bagSlotsPerRow * bagVisibleRowCount
        static let maxWidth: CGFloat = 900
        static let aspectWidthOverHeight: CGFloat = 5
        static let horizontalMargin: CGFloat = 12
        static let bottomInset: CGFloat = 18
        static let minimumHitExtent: CGFloat = 44
        /// The painted plate spends its outer band on the metal frame, so every
        /// child lays out inside the recessed well, never against the full plate.
        /// Measured on `hud_loot_container_panel_v02` (1600×320): the well spans
        /// x 42…1558 and y 31…285, and the bottom rail is the thicker of the two.
        static let wellTopInsetFraction: CGFloat = 0.097
        static let wellBottomInsetFraction: CGFloat = 0.106
        static let wellSideInsetFraction: CGFloat = 0.026
        /// Slot pitch on the classic strip measures 195px against its 419px well.
        /// Measuring against the well rather than the plate is what makes the two
        /// comparable — our frame is nearly twice as thick as the reference's, so
        /// the same fraction of the *plate* would push the lower row into it.
        static let slotToWellHeightFraction: CGFloat = 0.466
        /// Take-all gem and page arrows measured off the classic container strip,
        /// where both are sized against the transfer slot they sit beside rather
        /// than against a fixed point extent: the gem reads a little over half a
        /// slot across (114/196), the arrow button a little over four fifths
        /// (161/196). Both bottom-align with the lower slot row.
        static let takeAllArtToSlotFraction: CGFloat = 0.58
        static let pageArrowToSlotFraction: CGFloat = 0.82

        /// Five-zone hierarchy measured from the classic container strip and
        /// translated into RainShadow's original 5:1 painted plate.
        // Slightly rebalance the research ratios at compact rail-safe widths so
        // the two real transfer grids and their controls retain 44pt hit areas.
        static let sourceIdentityMaxXFraction: CGFloat = 0.140
        static let sourceViewportMaxXFraction: CGFloat = 0.490
        static let carryMaxXFraction: CGFloat = 0.615
        static let bagViewportMaxXFraction: CGFloat = 0.880
    }

    /// Pure source-row viewport state shared by the SpriteKit panel and unit tests.
    /// `pageIndex` is retained as the public spelling, but each step advances one
    /// three-item row while the viewport continues to show two rows.
    struct LootContainerPage: Equatable {
        let pageIndex: Int
        let pageCount: Int
        let visibleRange: Range<Int>

        var canGoPrevious: Bool { pageIndex > 0 }
        var canGoNext: Bool { pageIndex + 1 < pageCount }
    }

    /// Two-column carried-bag viewport. Scrolling advances one row, so the
    /// middle row remains visible while moving through a longer bag.
    struct LootContainerBagViewport: Equatable {
        let rowIndex: Int
        let rowCount: Int
        let visibleRange: Range<Int>

        var canGoPrevious: Bool { rowIndex > 0 }
        var canGoNext: Bool { rowIndex + LootContainerPanel.bagVisibleRowCount < rowCount }
    }

    /// Clamps a requested source row and returns its overlapping six-entry slice.
    static func lootContainerPage(itemCount: Int, requestedPage: Int) -> LootContainerPage {
        let count = max(0, itemCount)
        let rowCount = max(1, (count + LootContainerPanel.sourceColumns - 1)
            / LootContainerPanel.sourceColumns)
        let lastPage = max(0, rowCount - LootContainerPanel.sourceRows)
        let pageIndex = min(max(0, requestedPage), lastPage)
        let lowerBound = min(count, pageIndex * LootContainerPanel.sourceColumns)
        let upperBound = min(count, lowerBound + LootContainerPanel.slotsPerPage)
        return LootContainerPage(
            pageIndex: pageIndex,
            pageCount: lastPage + 1,
            visibleRange: lowerBound..<upperBound
        )
    }

    static func lootContainerBagViewport(
        itemCount: Int,
        requestedRow: Int
    ) -> LootContainerBagViewport {
        let count = max(0, itemCount)
        let rowCount = max(1, (count + LootContainerPanel.bagSlotsPerRow - 1)
            / LootContainerPanel.bagSlotsPerRow)
        let lastRow = max(0, rowCount - LootContainerPanel.bagVisibleRowCount)
        let rowIndex = min(max(0, requestedRow), lastRow)
        let lowerBound = min(count, rowIndex * LootContainerPanel.bagSlotsPerRow)
        let upperBound = min(
            count,
            lowerBound + LootContainerPanel.bagSlotsPerViewport
        )
        return LootContainerBagViewport(
            rowIndex: rowIndex,
            rowCount: rowCount,
            visibleRange: lowerBound..<upperBound
        )
    }

    struct LootContainerPanelLayout: Equatable {
        /// Full panel contract in viewport-centred HUD coordinates.
        let panelRect: CGRect
        let sourceIdentityRect: CGRect
        let sourceViewportRect: CGRect
        let carryRect: CGRect
        let bagViewportRect: CGRect
        let walletWellRect: CGRect
        let sourcePropArtRect: CGRect
        let takeAllHitRect: CGRect
        let takeAllArtRect: CGRect
        let sourcePreviousPageHitRect: CGRect
        let sourcePreviousPageArtRect: CGRect
        let sourceNextPageHitRect: CGRect
        let sourceNextPageArtRect: CGRect
        /// Six positions in row-major order: three columns by two rows.
        let sourceSlotHitRects: [CGRect]
        let sourceSlotArtRects: [CGRect]
        let caseBagArtRect: CGRect
        let carriedWeightRect: CGRect
        let maximumWeightRect: CGRect
        let bagPreviousRowHitRect: CGRect
        let bagPreviousRowArtRect: CGRect
        let bagNextRowHitRect: CGRect
        let bagNextRowArtRect: CGRect
        /// Four item-transfer preview positions, two columns by two rows.
        let bagSlotHitRects: [CGRect]
        let bagSlotArtRects: [CGRect]
        let walletCoinArtRect: CGRect
        let walletRect: CGRect
        let walletValueRect: CGRect
    }

    /// Solves one transfer grid's slot extent together with the paging-arrow
    /// column beside it. The arrow tracks the slot, so the row width is solved
    /// against `columns + pageArrowToSlotFraction` slot units; when that lands
    /// the arrow under the minimum touch extent the arrow is pinned to 44pt and
    /// the slots are re-solved against the fixed column that leaves.
    private static func lootTransferGrid(
        zoneWidth: CGFloat,
        zoneHeight: CGFloat,
        columns: Int,
        rows: Int,
        gap: CGFloat,
        maximumSlotExtent: CGFloat
    ) -> (slotExtent: CGFloat, arrowExtent: CGFloat) {
        // `zoneHeight` is already the recessed well, so the rows may fill it.
        let heightLimit = (zoneHeight - gap) / CGFloat(rows)
        // Two gaps of side margin plus one between every column and the arrows.
        let gapTotal = gap * CGFloat(columns + 2)

        func clamp(_ widthLimit: CGFloat) -> CGFloat {
            max(
                LootContainerPanel.minimumHitExtent,
                min(maximumSlotExtent, heightLimit, widthLimit)
            )
        }

        let proportionalUnits = CGFloat(columns) + LootContainerPanel.pageArrowToSlotFraction
        let slotExtent = clamp(max(1, zoneWidth - gapTotal) / proportionalUnits)
        let arrowExtent = slotExtent * LootContainerPanel.pageArrowToSlotFraction
        guard arrowExtent < LootContainerPanel.minimumHitExtent else {
            return (slotExtent, arrowExtent)
        }
        let fixedColumn = max(
            1,
            zoneWidth - LootContainerPanel.minimumHitExtent - gapTotal
        ) / CGFloat(columns)
        return (clamp(fixedColumn), LootContainerPanel.minimumHitExtent)
    }

    /// Grows `rect` to the minimum touch extent about its own centre, then slides
    /// it back inside `bounds`. Clamping against `bounds ∪ rect` keeps the slide
    /// no larger than the growth on that edge, so the result always still covers
    /// `rect` — including when `rect` itself already pokes out of `bounds`.
    private static func touchTarget(around rect: CGRect, clampedTo bounds: CGRect) -> CGRect {
        let limit = bounds.union(rect)
        let width = max(LootContainerPanel.minimumHitExtent, rect.width)
        let height = max(LootContainerPanel.minimumHitExtent, rect.height)
        let x = min(
            max(rect.midX - width / 2, limit.minX),
            max(limit.minX, limit.maxX - width)
        )
        let y = min(
            max(rect.midY - height / 2, limit.minY),
            max(limit.minY, limit.maxY - height)
        )
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// A 5:1 bottom strip centred in the playable region between the two HUD rails.
    /// Runtime decoration and every hit target remain code-owned.
    static func lootContainerPanelLayout(for visibleSize: CGSize) -> LootContainerPanelLayout {
        let viewWidth = max(1, visibleSize.width)
        let viewHeight = max(1, visibleSize.height)
        let playMinX = -viewWidth / 2 + leftRailClearance(for: visibleSize)
        let playMaxX = viewWidth / 2 - rightRailClearance(for: visibleSize)
        let playWidth = max(1, playMaxX - playMinX)

        let horizontalLimit = max(1, playWidth - LootContainerPanel.horizontalMargin * 2)
        let verticalLimit = max(
            1,
            (viewHeight - LootContainerPanel.bottomInset * 2)
                * LootContainerPanel.aspectWidthOverHeight
        )
        let panelWidth = min(LootContainerPanel.maxWidth, horizontalLimit, verticalLimit)
        let panelHeight = panelWidth / LootContainerPanel.aspectWidthOverHeight
        let panelCenterX = (playMinX + playMaxX) / 2
        let panelRect = CGRect(
            x: panelCenterX - panelWidth / 2,
            y: -viewHeight / 2 + LootContainerPanel.bottomInset,
            width: panelWidth,
            height: panelHeight
        )
        // Every zone is a full-height slice of the recessed well, so nothing the
        // panel draws sits inside this band, not against the plate's own edges.
        let wellRect = CGRect(
            x: panelRect.minX + panelRect.width * LootContainerPanel.wellSideInsetFraction,
            y: panelRect.minY + panelRect.height * LootContainerPanel.wellBottomInsetFraction,
            width: max(1, panelRect.width
                * (1 - LootContainerPanel.wellSideInsetFraction * 2)),
            height: max(1, panelRect.height * (1
                - LootContainerPanel.wellTopInsetFraction
                - LootContainerPanel.wellBottomInsetFraction))
        )
        // Zones stay full-height columns; only the drawn children are well-bound,
        // so a viewport too short for two 44pt rows still reports honest zones.
        let innerMinX = wellRect.minX
        let innerMaxX = wellRect.maxX
        func zone(from minFraction: CGFloat, to maxFraction: CGFloat) -> CGRect {
            let minX = max(innerMinX, panelRect.minX + panelRect.width * minFraction)
            let maxX = min(innerMaxX, panelRect.minX + panelRect.width * maxFraction)
            return CGRect(
                x: minX,
                y: panelRect.minY,
                width: max(0, maxX - minX),
                height: panelRect.height
            )
        }
        /// The part of a zone that lies inside the painted well.
        func wellBand(of zone: CGRect) -> CGRect {
            CGRect(x: zone.minX, y: wellRect.minY, width: zone.width, height: wellRect.height)
        }
        let sourceIdentityRect = zone(
            from: LootContainerPanel.wellSideInsetFraction,
            to: LootContainerPanel.sourceIdentityMaxXFraction
        )
        let sourceViewportRect = zone(
            from: LootContainerPanel.sourceIdentityMaxXFraction,
            to: LootContainerPanel.sourceViewportMaxXFraction
        )
        let carryRect = zone(
            from: LootContainerPanel.sourceViewportMaxXFraction,
            to: LootContainerPanel.carryMaxXFraction
        )
        let bagViewportRect = zone(
            from: LootContainerPanel.carryMaxXFraction,
            to: LootContainerPanel.bagViewportMaxXFraction
        )
        let walletWellRect = CGRect(
            x: panelRect.minX + panelRect.width * LootContainerPanel.bagViewportMaxXFraction,
            y: panelRect.minY,
            width: innerMaxX
                - (panelRect.minX + panelRect.width * LootContainerPanel.bagViewportMaxXFraction),
            height: panelRect.height
        )

        // Breathing room for the labels and props *inside* the well — the frame
        // allowance is already spent by the well band itself.
        let verticalInset = min(6, max(2, panelHeight * 0.02))
        let gap = min(7, max(3, panelHeight * 0.025))
        let maximumSlotExtent = wellRect.height * LootContainerPanel.slotToWellHeightFraction

        let (sourceSlotExtent, sourceArrowExtent) = lootTransferGrid(
            zoneWidth: sourceViewportRect.width,
            zoneHeight: wellRect.height,
            columns: LootContainerPanel.sourceColumns,
            rows: LootContainerPanel.sourceRows,
            gap: gap,
            maximumSlotExtent: maximumSlotExtent
        )
        let sourceGridWidth = sourceSlotExtent * CGFloat(LootContainerPanel.sourceColumns)
            + gap * CGFloat(LootContainerPanel.sourceColumns - 1)
        let sourceControlsWidth = sourceGridWidth + gap + sourceArrowExtent
        let sourceMinX = sourceViewportRect.midX - sourceControlsWidth / 2
        let sourceGridHeight = sourceSlotExtent * CGFloat(LootContainerPanel.sourceRows) + gap
        let sourceMinY = wellRect.midY - sourceGridHeight / 2

        // The gem is centred in the identity column and sits on the same
        // baseline as the lower transfer row, exactly as on the classic strip.
        let takeAllArtExtent = sourceSlotExtent * LootContainerPanel.takeAllArtToSlotFraction
        let takeAllArtRect = CGRect(
            x: sourceIdentityRect.midX - takeAllArtExtent / 2,
            y: sourceMinY,
            width: takeAllArtExtent,
            height: takeAllArtExtent
        )
        let takeAllHitRect = touchTarget(
            around: takeAllArtRect,
            clampedTo: wellBand(of: sourceIdentityRect)
        )
        let sourcePropArtRect = CGRect(
            x: sourceIdentityRect.minX + gap,
            y: max(takeAllHitRect.maxY, takeAllArtRect.maxY),
            width: max(1, sourceIdentityRect.width - gap * 2),
            height: max(
                1,
                wellRect.maxY - verticalInset
                    - max(takeAllHitRect.maxY, takeAllArtRect.maxY)
            )
        )

        var sourceSlotHitRects: [CGRect] = []
        for row in 0..<LootContainerPanel.sourceRows {
            for column in 0..<LootContainerPanel.sourceColumns {
                sourceSlotHitRects.append(CGRect(
                    x: sourceMinX + CGFloat(column) * (sourceSlotExtent + gap),
                    y: sourceMinY
                        + CGFloat(LootContainerPanel.sourceRows - 1 - row)
                            * (sourceSlotExtent + gap),
                    width: sourceSlotExtent,
                    height: sourceSlotExtent
                ))
            }
        }
        // Up hugs the top row, down hugs the bottom row; the painted button art
        // fills its own hit target rather than floating inside a larger one.
        let sourceArrowX = sourceMinX + sourceGridWidth + gap
        let sourcePreviousPageArtRect = CGRect(
            x: sourceArrowX,
            y: sourceMinY + sourceGridHeight - sourceArrowExtent,
            width: sourceArrowExtent,
            height: sourceArrowExtent
        )
        let sourceNextPageArtRect = CGRect(
            x: sourceArrowX,
            y: sourceMinY,
            width: sourceArrowExtent,
            height: sourceArrowExtent
        )
        let sourcePreviousPageHitRect = sourcePreviousPageArtRect
        let sourceNextPageHitRect = sourceNextPageArtRect

        let weightHeight = min(24, max(18, panelHeight * 0.13))
        let carriedWeightRect = CGRect(
            x: carryRect.minX + gap,
            y: wellRect.maxY - verticalInset - weightHeight,
            width: max(1, carryRect.width - gap * 2),
            height: weightHeight
        )
        let maximumWeightRect = CGRect(
            x: carryRect.minX + gap,
            y: wellRect.minY + verticalInset,
            width: max(1, carryRect.width - gap * 2),
            height: weightHeight
        )
        let caseBagArtRect = CGRect(
            x: carryRect.minX + gap,
            y: maximumWeightRect.maxY,
            width: max(1, carryRect.width - gap * 2),
            height: max(1, carriedWeightRect.minY - maximumWeightRect.maxY)
        )

        let (bagSlotExtent, bagArrowExtent) = lootTransferGrid(
            zoneWidth: bagViewportRect.width,
            zoneHeight: wellRect.height,
            columns: LootContainerPanel.bagSlotsPerRow,
            rows: LootContainerPanel.bagVisibleRowCount,
            gap: gap,
            maximumSlotExtent: maximumSlotExtent
        )
        let bagGridWidth = bagSlotExtent * CGFloat(LootContainerPanel.bagSlotsPerRow) + gap
        let bagControlsWidth = bagGridWidth + gap + bagArrowExtent
        let bagGridHeight = bagSlotExtent * CGFloat(LootContainerPanel.bagVisibleRowCount) + gap
        let bagMinX = bagViewportRect.midX - bagControlsWidth / 2
        let bagMinY = wellRect.midY - bagGridHeight / 2
        var bagSlotArtRects: [CGRect] = []
        for row in 0..<LootContainerPanel.bagVisibleRowCount {
            for column in 0..<LootContainerPanel.bagSlotsPerRow {
                bagSlotArtRects.append(CGRect(
                    x: bagMinX + CGFloat(column) * (bagSlotExtent + gap),
                    y: bagMinY
                        + CGFloat(LootContainerPanel.bagVisibleRowCount - 1 - row)
                            * (bagSlotExtent + gap),
                    width: bagSlotExtent,
                    height: bagSlotExtent
                ))
            }
        }
        let bagArrowX = bagMinX + bagGridWidth + gap
        let bagPreviousRowArtRect = CGRect(
            x: bagArrowX,
            y: bagMinY + bagGridHeight - bagArrowExtent,
            width: bagArrowExtent,
            height: bagArrowExtent
        )
        let bagNextRowArtRect = CGRect(
            x: bagArrowX,
            y: bagMinY,
            width: bagArrowExtent,
            height: bagArrowExtent
        )
        let bagPreviousRowHitRect = bagPreviousRowArtRect
        let bagNextRowHitRect = bagNextRowArtRect

        let walletInset = max(3, min(7, panelWidth * 0.006))
        let walletValueHeight = min(30, max(20, panelHeight * 0.18))
        let walletValueRect = CGRect(
            x: walletWellRect.minX + walletInset,
            y: wellRect.minY + verticalInset,
            width: max(1, walletWellRect.width - walletInset * 2),
            height: walletValueHeight
        )
        let walletCoinArtRect = CGRect(
            x: walletWellRect.minX + walletInset,
            y: walletValueRect.maxY,
            width: max(1, walletWellRect.width - walletInset * 2),
            height: max(1, wellRect.maxY - verticalInset - walletValueRect.maxY)
        )
        let walletRect = wellBand(of: walletWellRect).insetBy(dx: walletInset, dy: verticalInset)

        return LootContainerPanelLayout(
            panelRect: panelRect,
            sourceIdentityRect: sourceIdentityRect,
            sourceViewportRect: sourceViewportRect,
            carryRect: carryRect,
            bagViewportRect: bagViewportRect,
            walletWellRect: walletWellRect,
            sourcePropArtRect: sourcePropArtRect,
            takeAllHitRect: takeAllHitRect,
            takeAllArtRect: takeAllArtRect,
            sourcePreviousPageHitRect: sourcePreviousPageHitRect,
            sourcePreviousPageArtRect: sourcePreviousPageArtRect,
            sourceNextPageHitRect: sourceNextPageHitRect,
            sourceNextPageArtRect: sourceNextPageArtRect,
            sourceSlotHitRects: sourceSlotHitRects,
            sourceSlotArtRects: sourceSlotHitRects,
            caseBagArtRect: caseBagArtRect,
            carriedWeightRect: carriedWeightRect,
            maximumWeightRect: maximumWeightRect,
            bagPreviousRowHitRect: bagPreviousRowHitRect,
            bagPreviousRowArtRect: bagPreviousRowArtRect,
            bagNextRowHitRect: bagNextRowHitRect,
            bagNextRowArtRect: bagNextRowArtRect,
            bagSlotHitRects: bagSlotArtRects,
            bagSlotArtRects: bagSlotArtRects,
            walletCoinArtRect: walletCoinArtRect,
            walletRect: walletRect,
            walletValueRect: walletValueRect
        )
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

import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import RainShadowCore

/// Guards the baked and runtime contracts for Voss's chairless seated idle and
/// seat transitions. The separate scene chair owns every visible chair pixel.
struct VossSeatScaleTests {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var atlases: URL {
        VossAtlasTestAssets.atlasRoot
    }

    @Test func actorDisplayUsesOneSizeForSeatedAndStanding() {
        #expect(OfficeInteriorScale.ActorDisplay.spriteDisplaySize == CGSize(width: 180, height: 180))
        // A posture-specific display size recreates the apparent growth that the
        // shared source-to-texture scale is designed to prevent.
        let scaleSource = try? String(
            contentsOf: repoRoot.appendingPathComponent(
                "RainShadow Shared/Gameplay/Navigation/OfficeInteriorScale.swift"
            ),
            encoding: .utf8
        )
        #expect(scaleSource?.contains("seatedSpriteDisplaySize") != true)
        #expect(scaleSource?.contains("width: 252") != true)

        let actorSource = try? String(
            contentsOf: repoRoot.appendingPathComponent(
                "RainShadow Shared/Gameplay/Actors/DetectiveActorNode.swift"
            ),
            encoding: .utf8
        )
        #expect(actorSource?.contains("seatedFrameDisplaySize") != true)
        #expect(actorSource?.contains("standingFrameDisplaySize") != true)
        #expect(actorSource?.contains("frameDisplaySizeConstant") == true)
    }

    @Test func allSeatedAndTransitionCellsMeetBakedAssetGates() throws {
        let thresholds = try VossV20ValidationThresholds.load()
        try validateSeatChain(.northEast, thresholds: thresholds)
        try validateSeatChain(.southEast, thresholds: thresholds)
    }

    private func validateSeatChain(
        _ direction: SeatVisualDirection,
        thresholds: VossV20ValidationThresholds
    ) throws {
        let idle = try loadSequence(
            atlas: "VossSeatedIdle.atlas",
            stem: "voss_seated_idle_\(direction.assetSuffix)",
            count: 8
        )
        let stand = try loadSequence(
            atlas: "VossSeatTransitions.atlas",
            stem: "voss_stand_up_\(direction.assetSuffix)",
            count: 12
        )
        let sit = try loadSequence(
            atlas: "VossSeatTransitions.atlas",
            stem: "voss_sit_down_\(direction.assetSuffix)",
            count: 12
        )

        // NE is rendered from the authored NW standing set with a negative
        // SpriteKit x-scale. Mirroring does not change the scalar measurements,
        // so the NW PNG is the direction-matched endpoint reference here.
        let standingReference = try loadPNG(
            atlas: "VossIdle.atlas",
            name: "voss_standing_idle_\(direction.standingReferenceSuffix)_00.png"
        )
        let referenceMetrics = try standingReference.metrics()
        #expect(thresholds.standingHeight.contains(referenceMetrics.height),
                "\(direction.label) standing reference height \(referenceMetrics.height), expected \(thresholds.standingHeight)")

        let namedCells = idle.enumerated().map {
            ("\(direction.label) seated idle \(String(format: "%02d", $0.offset))", $0.element)
        } + stand.enumerated().map {
            ("\(direction.label) stand-up \(String(format: "%02d", $0.offset))", $0.element)
        } + sit.enumerated().map {
            ("\(direction.label) sit-down \(String(format: "%02d", $0.offset))", $0.element)
        }

        for (label, cell) in namedCells {
            #expect(cell.width == thresholds.canvasWidth && cell.height == thresholds.canvasHeight,
                    "\(label) canvas is \(cell.width)x\(cell.height), expected \(thresholds.canvasWidth)x\(thresholds.canvasHeight)")
            #expect(cell.cornerAlphas == Array(repeating: thresholds.sentinelAlpha, count: 4),
                    "\(label) corner alpha values \(cell.cornerAlphas), expected four alpha-\(thresholds.sentinelAlpha) sentinels")

            let metrics = try cell.metrics()
            #expect(metrics.footY == thresholds.footRow,
                    "\(label) visible feet end at row \(metrics.footY), expected \(thresholds.footRow)")
            #expect(abs(metrics.centerX - 255.5) <= thresholds.centerTolerance,
                    "\(label) bbox centre \(metrics.centerX), expected within \(thresholds.centerTolerance)px of 255.5")
        }

        let idleMetrics = try idle.map { try $0.metrics() }
        let standMetrics = try stand.map { try $0.metrics() }
        let sitMetrics = try sit.map { try $0.metrics() }

        for (index, metrics) in idleMetrics.enumerated() {
            #expect(thresholds.seatedHeight.contains(metrics.height),
                    "\(direction.label) seated idle \(String(format: "%02d", index)) height \(metrics.height), expected \(thresholds.seatedHeight)")
        }
        #expect(thresholds.standingHeight.contains(standMetrics[11].height),
                "\(direction.label) standing endpoint height \(standMetrics[11].height), expected \(thresholds.standingHeight)")

        // With every frame foot-registered at row 433, comparing visual crown
        // rows is also an exact comparison of opaque body heights.
        #expect(abs(standMetrics[0].crownY - idleMetrics[0].crownY) <= 3,
                "\(direction.label) stand-up 00 crown \(standMetrics[0].crownY) vs idle neutral \(idleMetrics[0].crownY)")
        #expect(abs(standMetrics[11].crownY - referenceMetrics.crownY) <= 2,
                "\(direction.label) stand-up 11 crown \(standMetrics[11].crownY) vs standing reference \(referenceMetrics.crownY)")

        let contractMetrics = idleMetrics + standMetrics
        switch direction {
        case .northEast:
            // A 1-bit silhouette at 64 native rows puts the head about six
            // craft pixels across, so the registered 18...29 band is more
            // meaningful than a sub-pixel ratio against another direction.
            for (index, metrics) in contractMetrics.enumerated() {
                #expect(thresholds.seatedHeadWidth.contains(metrics.headWidth),
                        "NE cell \(index) head width \(metrics.headWidth), expected \(thresholds.seatedHeadWidth)")
            }
        case .southEast:
            for (index, metrics) in contractMetrics.enumerated() {
                let ratio = Double(metrics.headWidth) / Double(referenceMetrics.headWidth)
                // Keep the 0.90...1.10 source-scale gate, with exactly one
                // pre-enlargement craft sample of edge quantisation. At 64
                // rows that sample occupies 3.125 registered canvas pixels.
                let lower = 0.90 * Double(referenceMetrics.headWidth)
                    - thresholds.craftPixelCanvas
                let upper = 1.10 * Double(referenceMetrics.headWidth)
                    + thresholds.craftPixelCanvas
                #expect((lower...upper).contains(Double(metrics.headWidth)),
                        "SE cell \(index) head width \(metrics.headWidth) vs standing reference \(referenceMetrics.headWidth), expected 0.90...1.10 plus one \(thresholds.craftPixelCanvas)px craft sample (ratio \(ratio))")
            }
        }

        let headWidths = contractMetrics.map(\.headWidth)
        if let narrowest = headWidths.min(), let widest = headWidths.max(), narrowest > 0 {
            let drift = Double(widest) / Double(narrowest)
            // 1.30 matches validate_shared_scale_chain in process_voss_desk_ne_v01.py.
            // At 64 native rows one head-edge sample is still about one sixth
            // of the small head, so 1.12 cannot survive a 1-bit edge.
            let allowedWidth = thresholds.seatedHeadWidthDriftRatioMaximum
                * Double(narrowest) + thresholds.craftPixelCanvas
            #expect(Double(widest) <= allowedWidth,
                    "\(direction.label) clip-wide head drift \(drift), widths \(headWidths), expected <=\(thresholds.seatedHeadWidthDriftRatioMaximum)x plus one \(thresholds.craftPixelCanvas)px craft sample")
        } else {
            Issue.record("\(direction.label) clip contains no measurable head band")
        }

        let neutralMask = idle[0].opaqueMask
        let neutralCentroid = idleMetrics[0].centroid
        for index in 1..<idle.count {
            let centroid = idleMetrics[index].centroid
            #expect(abs(centroid.x - neutralCentroid.x) <= thresholds.seatedIdleCentroidDriftMaximum &&
                    abs(centroid.y - neutralCentroid.y) <= thresholds.seatedIdleCentroidDriftMaximum,
                    "\(direction.label) idle \(String(format: "%02d", index)) centroid \(centroid) vs neutral \(neutralCentroid)")
            let overlap = VossDecodedPNG.intersectionOverUnion(neutralMask, idle[index].opaqueMask)
            #expect(overlap >= thresholds.seatedIdleNeutralIoUMinimum,
                    "\(direction.label) idle \(String(format: "%02d", index)) neutral-mask IoU \(overlap), expected >= \(thresholds.seatedIdleNeutralIoUMinimum)")
        }

        for index in 1..<standMetrics.count {
            let crownRetreat = standMetrics[index].crownY - standMetrics[index - 1].crownY
            #expect(crownRetreat <= thresholds.adjacentCrownRetreatMaximum,
                    "\(direction.label) stand-up \(String(format: "%02d", index)) crown retreats \(crownRetreat)px")
        }
        let totalRise = standMetrics[0].crownY - standMetrics[11].crownY
        #expect(thresholds.transitionRise.contains(totalRise),
                "\(direction.label) stand-up crown rises \(totalRise)px, expected \(thresholds.transitionRise)")

        // Sit-down is an asset-level reversal, not a separately authored clip.
        for index in 0..<sit.count {
            let reverseIndex = stand.count - 1 - index
            #expect(sit[index].pixels == stand[reverseIndex].pixels,
                    "\(direction.label) sit-down \(String(format: "%02d", index)) is not the exact pixel reverse of stand-up \(String(format: "%02d", reverseIndex))")
            #expect(sitMetrics[index] == standMetrics[reverseIndex],
                    "\(direction.label) sit-down \(String(format: "%02d", index)) metrics differ from reversed stand-up")
        }
    }

    private func loadSequence(atlas: String, stem: String, count: Int) throws -> [VossDecodedPNG] {
        try (0..<count).map { index in
            try loadPNG(
                atlas: atlas,
                name: String(format: "%@_%02d.png", stem, index)
            )
        }
    }

    private func loadPNG(atlas: String, name: String) throws -> VossDecodedPNG {
        let url = atlases.appendingPathComponent(atlas).appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else {
            Issue.record("Missing \(name)")
            throw VossSeatAssetError.missingPNG(url)
        }
        return try VossDecodedPNG(contentsOf: url)
    }
}

private enum SeatVisualDirection {
    case northEast
    case southEast

    var assetSuffix: String {
        switch self {
        case .northEast: "ne"
        case .southEast: "se"
        }
    }

    var standingReferenceSuffix: String {
        switch self {
        case .northEast: "nw"
        case .southEast: "se"
        }
    }

    var label: String { assetSuffix.uppercased() }
}

private struct VossOpaqueBodyMetrics: Equatable {
    var width: Int
    var height: Int
    var headWidth: Int
    var crownY: Int
    var footY: Int
    var centerX: Double
    var centroid: CGPoint
}

private struct VossDecodedPNG {
    static let alphaThreshold: UInt8 = 16

    var width: Int
    var height: Int
    var pixels: [UInt8]
    var opaqueMask: [Bool]

    init(contentsOf url: URL) throws {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              image.width > 0,
              image.height > 0 else {
            throw VossSeatAssetError.invalidPNG(url)
        }

        width = image.width
        height = image.height
        let bytesPerRow = width * 4
        pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw VossSeatAssetError.invalidPNG(url)
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // The decoded bitmap rows follow PNG visual order: row 0 is the crown
        // side and increasing y moves toward the registered feet.
        opaqueMask = [Bool](repeating: false, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                guard !isCornerSentinel(x: x, y: y) else { continue }
                opaqueMask[y * width + x] = alpha(x: x, y: y) >= Self.alphaThreshold
            }
        }
    }

    var cornerAlphas: [UInt8] {
        guard width > 0, height > 0 else { return [] }
        return [
            alpha(x: 0, y: 0),
            alpha(x: width - 1, y: 0),
            alpha(x: 0, y: height - 1),
            alpha(x: width - 1, y: height - 1)
        ]
    }

    func metrics() throws -> VossOpaqueBodyMetrics {
        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1
        var sumX = 0
        var sumY = 0
        var count = 0

        for y in 0..<height {
            for x in 0..<width where opaqueMask[y * width + x] {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
                sumX += x
                sumY += y
                count += 1
            }
        }
        guard count > 0, maxX >= minX, maxY >= minY else {
            throw VossSeatAssetError.emptySprite
        }

        let bodyHeight = maxY - minY + 1
        // The visual top 10% stays above the bare-headed SE pose's raised
        // shoulder. A 12% band measures that shoulder as if it were the head.
        let headBandHeight = max(1, bodyHeight * 10 / 100)
        let headBandEnd = min(maxY, minY + headBandHeight - 1)
        var headMinX = width
        var headMaxX = -1
        for y in minY...headBandEnd {
            for x in 0..<width where opaqueMask[y * width + x] {
                headMinX = min(headMinX, x)
                headMaxX = max(headMaxX, x)
            }
        }
        guard headMaxX >= headMinX else {
            throw VossSeatAssetError.emptyHeadBand
        }

        return VossOpaqueBodyMetrics(
            width: maxX - minX + 1,
            height: bodyHeight,
            headWidth: headMaxX - headMinX + 1,
            crownY: minY,
            footY: maxY,
            centerX: Double(minX + maxX) / 2,
            centroid: CGPoint(x: Double(sumX) / Double(count), y: Double(sumY) / Double(count))
        )
    }

    static func intersectionOverUnion(_ lhs: [Bool], _ rhs: [Bool]) -> Double {
        guard lhs.count == rhs.count else { return 0 }
        var intersection = 0
        var union = 0
        for (left, right) in zip(lhs, rhs) {
            if left || right { union += 1 }
            if left && right { intersection += 1 }
        }
        return union > 0 ? Double(intersection) / Double(union) : 0
    }

    private func alpha(x: Int, y: Int) -> UInt8 {
        pixels[(y * width + x) * 4 + 3]
    }

    private func isCornerSentinel(x: Int, y: Int) -> Bool {
        (x == 0 || x == width - 1) && (y == 0 || y == height - 1)
    }
}

private enum VossSeatAssetError: Error {
    case missingPNG(URL)
    case invalidPNG(URL)
    case emptySprite
    case emptyHeadBand
}

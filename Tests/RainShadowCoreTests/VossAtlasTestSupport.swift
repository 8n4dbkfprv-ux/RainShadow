import CoreGraphics
import Foundation
import ImageIO

/// Test-only resolution for Voss's runtime atlas payload. Point
/// `RAINSHADOW_VOSS_ATLAS_ROOT` at a staged directory containing the five
/// `.atlas` folders to run the same Swift asset checks before installation.
enum VossAtlasTestAssets {
    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    static var atlasRoot: URL {
        if let override = ProcessInfo.processInfo.environment["RAINSHADOW_VOSS_ATLAS_ROOT"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true).standardizedFileURL
        }
        return repoRoot
            .appendingPathComponent("RainShadow Shared/Resources/Art/Atlases", isDirectory: true)
            .standardizedFileURL
    }

    static func cellURL(atlas: String, name: String) -> URL {
        atlasRoot
            .appendingPathComponent(atlas, isDirectory: true)
            .appendingPathComponent(name, isDirectory: false)
    }

    static var v20ManifestURL: URL? {
        let fixedV20 = repoRoot.appendingPathComponent(
            "ArtSource/Generated/Characters/Detective/PreRendered3DV20/voss_v20_manifest.json"
        )
        let candidates = [
            atlasRoot.appendingPathComponent("voss_v20_manifest.json"),
            atlasRoot.deletingLastPathComponent().appendingPathComponent("voss_v20_manifest.json"),
            atlasRoot.deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("voss_v20_manifest.json"),
            fixedV20
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    static var v20SourceRoot: URL {
        repoRoot.appendingPathComponent(
            "ArtSource/Generated/Characters/Detective/PreRendered3DV20/Frames",
            isDirectory: true
        )
    }

    static func v20SourceURL(group: String, direction: String, phase: Int) -> URL {
        let prefix = group == "walk" ? "voss_walk" : "voss_idle"
        let name = String(format: "%@_%@_%02d_chroma_v20.png", prefix, direction, phase)
        return v20SourceRoot.appendingPathComponent(name, isDirectory: false)
    }
}

/// The defaults are the locked V20 contract. When the V20 manifest is present,
/// values in `processing` and `gates` are authoritative so Python staging and
/// Swift validation cannot silently drift apart.
struct VossV20ValidationThresholds {
    var canvasWidth = 512
    var canvasHeight = 512
    var footRow = 433
    var sentinelAlpha: UInt8 = 1
    var allowedAlphaValues: Set<UInt8> = [0, 1, 255]
    var maximumOpaqueColors = 64
    var standingHeight = 198...202
    var seatedHeight = 150...160
    var centerTolerance = 2.0
    /// Idle and walk cells register on body mass, so their bbox sits wherever
    /// the pose puts it. This bounds how lopsided that may get; the tight gate
    /// for those clips is `centroidDriftMaximum`.
    var bodyAxisBBoxTolerance = 8.0
    var centroidDriftMaximum = 2.0
    var seatedIdleCentroidDriftMaximum = 2.0
    var seatedIdleNeutralIoUMinimum = 0.86
    var adjacentCrownRetreatMaximum = 4
    var transitionRise = 38...50
    var seatedHeadWidth = 19...29
    var seatedHeadWidthDriftRatioMaximum = 1.30
    var headJitterMaximum = 2.0
    var headPulseRatioMaximum = 1.12
    var torsoPulseRatioMaximum = 1.18
    var rearShirtFractionMaximum = 0.001
    var rearNorthSkinFractionMaximum = 0.03
    var requiredRearCells = 36
    var requiredUniqueWalkPhases = 8
    var requiresBothPlantedFootLeads = true
    var requiresWalkLoopClosure = true
    var maximumRepeatedFootLead = 3
    /// Scale-free idle↔walk head/shoulder disagreement on keyed source masters.
    /// Measured in source space because the 200px raster cannot express it.
    var idleWalkHeadShoulderRatioMaximum = 0.06

    static func load() throws -> Self {
        guard let manifestURL = VossAtlasTestAssets.v20ManifestURL else {
            return Self()
        }
        let data = try Data(contentsOf: manifestURL)
        guard let document = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              document["asset_version"] as? String == "v20" else {
            throw VossAtlasTestError.invalidV20Manifest(manifestURL)
        }

        var thresholds = Self()
        let processing = document["processing"] as? [String: Any] ?? [:]
        let gates = document["gates"] as? [String: Any] ?? [:]

        if let canvas = integerRange(processing["canvas"]), canvas.count == 2 {
            thresholds.canvasWidth = canvas[0]
            thresholds.canvasHeight = canvas[1]
        }
        thresholds.footRow = integer(processing["foot_row"]) ?? thresholds.footRow
        if let alpha = integer(processing["corner_sentinel_alpha"]),
           let exact = UInt8(exactly: alpha) {
            thresholds.sentinelAlpha = exact
        }
        if let alphas = integerRange(processing["allowed_alpha_values"]),
           alphas.allSatisfy({ UInt8(exactly: $0) != nil }) {
            thresholds.allowedAlphaValues = Set(alphas.compactMap { UInt8(exactly: $0) })
        }
        thresholds.maximumOpaqueColors = integer(processing["palette_colors"])
            ?? thresholds.maximumOpaqueColors

        if let height = integerRange(gates["standing_height"]), height.count == 2 {
            thresholds.standingHeight = height[0]...height[1]
        }
        if let height = integerRange(gates["seated_height"]), height.count == 2 {
            thresholds.seatedHeight = height[0]...height[1]
        }
        thresholds.centerTolerance = number(gates["center_tolerance"])
            ?? thresholds.centerTolerance
        thresholds.bodyAxisBBoxTolerance = number(gates["body_axis_bbox_tolerance"])
            ?? thresholds.bodyAxisBBoxTolerance
        thresholds.centroidDriftMaximum = number(gates["centroid_drift_max"])
            ?? thresholds.centroidDriftMaximum
        thresholds.seatedIdleCentroidDriftMaximum = number(gates["idle_centroid_drift_max"])
            ?? thresholds.seatedIdleCentroidDriftMaximum
        thresholds.seatedIdleNeutralIoUMinimum = number(gates["idle_neutral_iou_min"])
            ?? thresholds.seatedIdleNeutralIoUMinimum
        thresholds.adjacentCrownRetreatMaximum = integer(gates["adjacent_crown_retreat_max"])
            ?? thresholds.adjacentCrownRetreatMaximum
        if let rise = integerRange(gates["transition_rise"]), rise.count == 2 {
            thresholds.transitionRise = rise[0]...rise[1]
        }
        if let width = integerRange(gates["head_width"]), width.count == 2 {
            thresholds.seatedHeadWidth = width[0]...width[1]
        }
        thresholds.seatedHeadWidthDriftRatioMaximum = number(gates["head_width_drift_ratio_max"])
            ?? thresholds.seatedHeadWidthDriftRatioMaximum
        thresholds.headJitterMaximum = number(gates["head_jitter_max"])
            ?? thresholds.headJitterMaximum
        thresholds.headPulseRatioMaximum = firstNumber(
            in: gates,
            keys: ["head_pulse_ratio_max", "head_scale_ratio_max", "head_pulse_max"]
        ) ?? thresholds.headPulseRatioMaximum
        thresholds.torsoPulseRatioMaximum = firstNumber(
            in: gates,
            keys: ["torso_pulse_ratio_max", "torso_scale_ratio_max", "torso_pulse_max"]
        ) ?? thresholds.torsoPulseRatioMaximum
        thresholds.rearShirtFractionMaximum = number(gates["rear_shirt_fraction_max"])
            ?? thresholds.rearShirtFractionMaximum
        thresholds.rearNorthSkinFractionMaximum = firstNumber(
            in: gates,
            keys: ["rear_n_skin_fraction_max", "pure_rear_skin_fraction_max", "rear_north_skin_fraction_max"]
        ) ?? thresholds.rearNorthSkinFractionMaximum
        thresholds.requiredRearCells = integer(gates["rear_cells_required"])
            ?? thresholds.requiredRearCells
        thresholds.requiredUniqueWalkPhases = integer(gates["walk_unique_phases_required"])
            ?? thresholds.requiredUniqueWalkPhases
        thresholds.requiresBothPlantedFootLeads = boolean(gates["walk_both_planted_foot_leads_required"])
            ?? thresholds.requiresBothPlantedFootLeads
        thresholds.requiresWalkLoopClosure = boolean(gates["walk_loop_closure_required"])
            ?? thresholds.requiresWalkLoopClosure
        thresholds.maximumRepeatedFootLead = firstInteger(
            in: gates,
            keys: ["walk_repeated_same_lead_run_max", "maximum_repeated_foot_lead"]
        )
            ?? thresholds.maximumRepeatedFootLead
        thresholds.idleWalkHeadShoulderRatioMaximum = number(gates["idle_walk_head_shoulder_ratio_max"])
            ?? thresholds.idleWalkHeadShoulderRatioMaximum
        return thresholds
    }

    private static func firstNumber(in dictionary: [String: Any], keys: [String]) -> Double? {
        keys.lazy.compactMap { number(dictionary[$0]) }.first
    }

    private static func firstInteger(in dictionary: [String: Any], keys: [String]) -> Int? {
        keys.lazy.compactMap { integer(dictionary[$0]) }.first
    }

    private static func number(_ value: Any?) -> Double? {
        (value as? NSNumber)?.doubleValue
    }

    private static func integer(_ value: Any?) -> Int? {
        (value as? NSNumber)?.intValue
    }

    private static func boolean(_ value: Any?) -> Bool? {
        (value as? NSNumber)?.boolValue
    }

    private static func integerRange(_ value: Any?) -> [Int]? {
        (value as? [NSNumber])?.map(\.intValue)
    }
}

struct VossAtlasFrameMetrics {
    var width: Int
    var height: Int
    var crownY: Int
    var footY: Int
    var centerX: Double
    /// Mean x of the opaque body. Idle and walk cells are registered on this
    /// rather than on `centerX`, so it is the honest measure of whether the
    /// figure holds still across a clip.
    var centroidX: Double
    var headWidth: Int
    var headCenterX: Double
    var torsoWidth: Int
}

struct VossAtlasFrame {
    static let alphaThreshold: UInt8 = 16

    var width: Int
    var height: Int
    var pixels: [UInt8]
    var opaqueMask: [Bool]

    init(contentsOf url: URL) throws {
        try self.init(contentsOf: url, chromaKey: false)
    }

    /// Load a V20 chroma master: green-screen pixels are treated as transparent
    /// so source-space head/shoulder bands match the Python `anatomy_bands`.
    init(chromaContentsOf url: URL) throws {
        try self.init(contentsOf: url, chromaKey: true)
    }

    private init(contentsOf url: URL, chromaKey: Bool) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw VossAtlasTestError.missingPNG(url)
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              image.width > 0,
              image.height > 0 else {
            throw VossAtlasTestError.invalidPNG(url)
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
            throw VossAtlasTestError.invalidPNG(url)
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        opaqueMask = [Bool](repeating: false, count: width * height)
        for y in 0..<height {
            for x in 0..<width where !isCornerSentinel(x: x, y: y) {
                if chromaKey {
                    opaqueMask[y * width + x] = !isChromaGreen(x: x, y: y)
                } else {
                    opaqueMask[y * width + x] = alpha(x: x, y: y) >= Self.alphaThreshold
                }
            }
        }
    }

    var cornerAlphas: [UInt8] {
        [
            alpha(x: 0, y: 0),
            alpha(x: width - 1, y: 0),
            alpha(x: 0, y: height - 1),
            alpha(x: width - 1, y: height - 1)
        ]
    }

    var alphaValues: Set<UInt8> {
        var result: Set<UInt8> = []
        result.reserveCapacity(3)
        for index in stride(from: 3, to: pixels.count, by: 4) {
            result.insert(pixels[index])
        }
        return result
    }

    /// Distinct packed RGB values among opaque pixels. Exposed as a set so a
    /// caller can union it across a clip and check the whole loop shares one
    /// palette, not just that each frame stays inside a budget.
    var opaqueColors: Set<UInt32> {
        var colors: Set<UInt32> = []
        for index in opaqueMask.indices where opaqueMask[index] {
            let pixel = index * 4
            let packed = UInt32(pixels[pixel]) << 16
                | UInt32(pixels[pixel + 1]) << 8
                | UInt32(pixels[pixel + 2])
            colors.insert(packed)
        }
        return colors
    }

    var opaqueColorCount: Int { opaqueColors.count }

    func metrics() throws -> VossAtlasFrameMetrics {
        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1
        for y in 0..<height {
            for x in 0..<width where opaqueMask[y * width + x] {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else {
            throw VossAtlasTestError.emptySprite
        }

        let bodyHeight = maxY - minY + 1
        let headBandHeight = max(1, bodyHeight * 10 / 100)
        let headEnd = min(maxY, minY + headBandHeight - 1)
        var headMinX = width
        var headMaxX = -1
        for y in minY...headEnd {
            for x in 0..<width where opaqueMask[y * width + x] {
                headMinX = min(headMinX, x)
                headMaxX = max(headMaxX, x)
            }
        }
        guard headMaxX >= headMinX else {
            throw VossAtlasTestError.emptyHeadBand
        }

        var centroidSum = 0
        var centroidCount = 0
        for y in 0..<height {
            for x in 0..<width where opaqueMask[y * width + x] {
                centroidSum += x
                centroidCount += 1
            }
        }
        let centroidX = centroidCount > 0 ? Double(centroidSum) / Double(centroidCount) : 0

        let torsoStart = min(maxY, minY + Int((Double(bodyHeight) * 0.28).rounded()))
        let torsoEnd = min(maxY + 1, minY + Int((Double(bodyHeight) * 0.62).rounded()))
        var torsoMinX = width
        var torsoMaxX = -1
        if torsoStart < torsoEnd {
            for y in torsoStart..<torsoEnd {
                for x in 0..<width where opaqueMask[y * width + x] {
                    torsoMinX = min(torsoMinX, x)
                    torsoMaxX = max(torsoMaxX, x)
                }
            }
        }

        return VossAtlasFrameMetrics(
            width: maxX - minX + 1,
            height: bodyHeight,
            crownY: minY,
            footY: maxY,
            centerX: Double(minX + maxX) / 2,
            centroidX: centroidX,
            headWidth: headMaxX - headMinX + 1,
            headCenterX: Double(headMinX + headMaxX) / 2,
            torsoWidth: torsoMaxX >= torsoMinX ? torsoMaxX - torsoMinX + 1 : 0
        )
    }

    /// Shoulder width on the 10–29% band used by the idle↔walk identity gate.
    func shoulderWidth() throws -> Int {
        let body = try metrics()
        let start = min(body.footY, body.crownY + Int((Double(body.height) * 0.10).rounded()))
        let end = min(body.footY + 1, body.crownY + Int((Double(body.height) * 0.29).rounded()))
        var minX = width
        var maxX = -1
        if start < end {
            for y in start..<end {
                for x in 0..<width where opaqueMask[y * width + x] {
                    minX = min(minX, x)
                    maxX = max(maxX, x)
                }
            }
        }
        return maxX >= minX ? maxX - minX + 1 : 0
    }

    func footLead() throws -> Character {
        let body = try metrics()
        var minX = width
        var maxX = -1
        for y in 0..<height {
            for x in 0..<width where opaqueMask[y * width + x] {
                minX = min(minX, x)
                maxX = max(maxX, x)
            }
        }
        guard maxX >= minX else { return "?" }

        let middle = (minX + maxX) / 2
        let footBandStart = max(0, body.footY - max(8, Int((Double(body.height) * 0.12).rounded())))
        var leftFootY = -1
        var rightFootY = -1
        for y in footBandStart...body.footY {
            for x in 0..<width where opaqueMask[y * width + x] {
                if x < middle {
                    leftFootY = max(leftFootY, y)
                } else {
                    rightFootY = max(rightFootY, y)
                }
            }
        }
        if leftFootY < 0 && rightFootY < 0 { return "?" }
        if leftFootY < 0 { return "R" }
        if rightFootY < 0 { return "L" }
        if leftFootY > rightFootY + 2 { return "L" }
        if rightFootY > leftFootY + 2 { return "R" }
        return "="
    }

    static func intersectionOverUnion(_ first: VossAtlasFrame, _ second: VossAtlasFrame) -> Double {
        guard first.opaqueMask.count == second.opaqueMask.count else { return 0 }
        var intersection = 0
        var union = 0
        for (left, right) in zip(first.opaqueMask, second.opaqueMask) {
            if left || right { union += 1 }
            if left && right { intersection += 1 }
        }
        return union > 0 ? Double(intersection) / Double(union) : 0
    }

    private func alpha(x: Int, y: Int) -> UInt8 {
        pixels[(y * width + x) * 4 + 3]
    }

    private func isChromaGreen(x: Int, y: Int) -> Bool {
        let pixel = (y * width + x) * 4
        let red = Double(pixels[pixel])
        let green = Double(pixels[pixel + 1])
        let blue = Double(pixels[pixel + 2])
        let other = max(red, blue)
        let dominance = green - other
        return dominance > 20 && green > 80 && green > other * 1.18
    }

    private func isCornerSentinel(x: Int, y: Int) -> Bool {
        (x == 0 || x == width - 1) && (y == 0 || y == height - 1)
    }
}

enum VossAtlasTestError: Error {
    case missingPNG(URL)
    case invalidPNG(URL)
    case invalidV20Manifest(URL)
    case emptySprite
    case emptyHeadBand
}

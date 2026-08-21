import Foundation
import Testing
@testable import RainShadowCore

/// Strict, staging-addressable V20 gates for standing and locomotion cells.
/// These deliberately mirror the V20 Python validator's silhouette math.
struct VossAtlasV20ValidationTests {
    private let authoredDirections = ["s", "ssw", "sw", "wsw", "w", "wnw", "nw", "nnw", "n"]

    @Test func allStandingAndWalkCellsMeetV20RasterAndGeometryGates() throws {
        let thresholds = try VossV20ValidationThresholds.load()

        for direction in authoredDirections + ["se"] {
            for phase in 0..<4 {
                let name = String(format: "voss_standing_idle_%@_%02d.png", direction, phase)
                try validateRasterAndGeometry(
                    VossAtlasFrame(contentsOf: VossAtlasTestAssets.cellURL(
                        atlas: "VossIdle.atlas",
                        name: name
                    )),
                    label: "idle \(direction) \(String(format: "%02d", phase))",
                    thresholds: thresholds
                )
            }
        }

        for direction in authoredDirections {
            for phase in 0..<8 {
                let name = String(format: "voss_walk_%@_%02d.png", direction, phase)
                try validateRasterAndGeometry(
                    VossAtlasFrame(contentsOf: VossAtlasTestAssets.cellURL(
                        atlas: "VossWalk.atlas",
                        name: name
                    )),
                    label: "walk \(direction) \(String(format: "%02d", phase))",
                    thresholds: thresholds
                )
            }
        }
    }

    /// The standing idle went four asset versions with nothing gating it but a
    /// height the raster forces, so it could not fail. These are the same
    /// coherence checks the walk gets, minus the gait-specific ones.
    @Test func everyIdleDirectionHoldsStillAndKeepsOnePalette() throws {
        let thresholds = try VossV20ValidationThresholds.load()
        for direction in authoredDirections + ["se"] {
            let frames = try (0..<4).map { phase in
                try VossAtlasFrame(contentsOf: VossAtlasTestAssets.cellURL(
                    atlas: "VossIdle.atlas",
                    name: String(format: "voss_standing_idle_%@_%02d.png", direction, phase)
                ))
            }
            let metrics = try frames.map { try $0.metrics() }

            let centroids = metrics.map(\.centroidX)
            let drift = (centroids.max() ?? 0) - (centroids.min() ?? 0)
            #expect(
                drift <= thresholds.centroidDriftMaximum,
                "idle \(direction) body centroid drifts \(format(drift))px, expected <=\(format(thresholds.centroidDriftMaximum))px"
            )

            let headWidths = metrics.map(\.headWidth)
            if let minimum = headWidths.min(), let maximum = headWidths.max(), minimum > 0 {
                let pulse = Double(maximum) / Double(minimum)
                #expect(
                    Double(maximum) <= thresholds.headPulseRatioMaximum * Double(minimum)
                        + thresholds.craftPixelCanvas,
                    "idle \(direction) head scale pulses \(format(pulse))x, expected <=\(format(thresholds.headPulseRatioMaximum))x plus one \(format(thresholds.craftPixelCanvas))px craft sample"
                )
            }

            // One palette per clip: a loop carrying more colours than a palette
            // has entries is one whose frames were quantised apart, which is
            // what made the wardrobe shift between phases.
            var clipColours = Set<UInt32>()
            for frame in frames {
                clipColours.formUnion(frame.opaqueColors)
            }
            #expect(
                clipColours.count <= thresholds.maximumOpaqueColors,
                "idle \(direction) carries \(clipColours.count) distinct colours across 4 phases, expected <=\(thresholds.maximumOpaqueColors)"
            )
        }
    }

    /// Idle and walk of one direction must be the same character. Measured on
    /// keyed V20 source masters: the 200px raster cannot express a few-percent
    /// correction, which is why this is not a processed-cell check.
    @Test func everyDirectionIdleAndWalkShareOneHeadShoulderRatio() throws {
        let thresholds = try VossV20ValidationThresholds.load()
        if ProcessInfo.processInfo.environment["RAINSHADOW_VOSS_ATLAS_ROOT"]?
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            // This test reads keyed V20 Frames/, not the staged atlas under test.
            return
        }
        if thresholds.walkTorsoPulseRatioMaximum > 2.0 {
            // V21 video walks are not the V20 still-clip identity pair.
            return
        }
        let sourceRoot = VossAtlasTestAssets.v20SourceRoot
        guard FileManager.default.fileExists(atPath: sourceRoot.path) else {
            Issue.record("V20 source Frames/ are not in this checkout; Python validate_sources is the gate")
            return
        }

        for direction in authoredDirections {
            let idle = try (0..<4).map { phase in
                try VossAtlasFrame(chromaContentsOf: VossAtlasTestAssets.v20SourceURL(
                    group: "idle", direction: direction, phase: phase
                ))
            }
            let walk = try (0..<8).map { phase in
                try VossAtlasFrame(chromaContentsOf: VossAtlasTestAssets.v20SourceURL(
                    group: "walk", direction: direction, phase: phase
                ))
            }
            let idleHeads = try idle.map { try $0.metrics().headWidth }
            let idleShoulders = try idle.map { try $0.shoulderWidth() }
            let walkHeads = try walk.map { try $0.metrics().headWidth }
            let walkShoulders = try walk.map { try $0.shoulderWidth() }
            let idleRatio = median(idleHeads) / max(median(idleShoulders), 1)
            let walkRatio = median(walkHeads) / max(median(walkShoulders), 1)
            let disagreement = (walkRatio - idleRatio) / idleRatio
            #expect(
                abs(disagreement) <= thresholds.idleWalkHeadShoulderRatioMaximum,
                "idle/walk \(direction) head/shoulder ratio disagrees \(format(disagreement)), expected |delta| <=\(format(thresholds.idleWalkHeadShoulderRatioMaximum))"
            )
        }
    }

    @Test func everyWalkDirectionMeetsV20MotionGates() throws {
        let thresholds = try VossV20ValidationThresholds.load()
        for direction in authoredDirections {
            let frames = try (0..<8).map { phase in
                try VossAtlasFrame(contentsOf: VossAtlasTestAssets.cellURL(
                    atlas: "VossWalk.atlas",
                    name: String(format: "voss_walk_%@_%02d.png", direction, phase)
                ))
            }
            try validateMotion(frames, direction: direction, thresholds: thresholds)
        }
    }

    private func validateRasterAndGeometry(
        _ frame: VossAtlasFrame,
        label: String,
        thresholds: VossV20ValidationThresholds
    ) throws {
        #expect(
            frame.width == thresholds.canvasWidth && frame.height == thresholds.canvasHeight,
            "\(label) canvas is \(frame.width)x\(frame.height), expected \(thresholds.canvasWidth)x\(thresholds.canvasHeight)"
        )
        #expect(
            frame.cornerAlphas == Array(repeating: thresholds.sentinelAlpha, count: 4),
            "\(label) corner alpha values \(frame.cornerAlphas), expected four alpha-\(thresholds.sentinelAlpha) sentinels"
        )
        #expect(
            frame.alphaValues == thresholds.allowedAlphaValues,
            "\(label) alpha values \(frame.alphaValues.sorted()), expected \(thresholds.allowedAlphaValues.sorted())"
        )
        #expect(
            frame.opaqueColorCount <= thresholds.maximumOpaqueColors,
            "\(label) has \(frame.opaqueColorCount) opaque colours, expected <=\(thresholds.maximumOpaqueColors)"
        )

        let metrics = try frame.metrics()
        #expect(
            thresholds.standingHeight.contains(metrics.height),
            "\(label) body height \(metrics.height), expected \(thresholds.standingHeight.lowerBound)...\(thresholds.standingHeight.upperBound)"
        )
        #expect(
            metrics.footY == thresholds.footRow,
            "\(label) visible feet end at row \(metrics.footY), expected \(thresholds.footRow)"
        )
        // Registered on body mass, not on the silhouette bbox: a walking figure
        // with a leg thrown forward has its bbox ahead of its body, and centring
        // that bbox is what slid the body off-centre. This is the sanity bound;
        // the tight gate is the per-clip centroid drift in validateMotion.
        #expect(
            abs(metrics.centerX - 255.5) <= thresholds.bodyAxisBBoxTolerance,
            "\(label) bbox centre \(format(metrics.centerX)), expected within \(format(thresholds.bodyAxisBBoxTolerance))px of 255.5"
        )
    }

    private func validateMotion(
        _ frames: [VossAtlasFrame],
        direction: String,
        thresholds: VossV20ValidationThresholds
    ) throws {
        #expect(
            frames.count == thresholds.requiredUniqueWalkPhases,
            "walk \(direction) has \(frames.count) phases, expected \(thresholds.requiredUniqueWalkPhases)"
        )
        let uniquePixels = Set(frames.map { Data($0.pixels) })
        #expect(
            uniquePixels.count == thresholds.requiredUniqueWalkPhases,
            "walk \(direction) has \(uniquePixels.count) unique processed phases, expected \(thresholds.requiredUniqueWalkPhases)"
        )

        let metrics = try frames.map { try $0.metrics() }
        let headCenters = metrics.map(\.headCenterX)
        let headJitter = (headCenters.max() ?? 0) - (headCenters.min() ?? 0)
        #expect(
            headJitter <= thresholds.walkHeadJitterMaximum,
            "walk \(direction) head jitter is \(format(headJitter))px, expected <=\(format(thresholds.walkHeadJitterMaximum))px"
        )

        // The gate that carries the registration: with cells registered on body
        // mass this is what says the figure holds still, and it is the number
        // that moved (4.95px -> 0.85px on the walks) when it stopped being the
        // silhouette bbox that was pinned.
        let centroids = metrics.map(\.centroidX)
        let centroidDrift = (centroids.max() ?? 0) - (centroids.min() ?? 0)
        #expect(
            centroidDrift <= thresholds.walkCentroidDriftMaximum,
            "walk \(direction) body centroid drifts \(format(centroidDrift))px, expected <=\(format(thresholds.walkCentroidDriftMaximum))px"
        )

        let headWidths = metrics.map(\.headWidth)
        if let minimum = headWidths.min(), let maximum = headWidths.max(), minimum > 0 {
            let pulse = Double(maximum) / Double(minimum)
            #expect(
                Double(maximum) <= thresholds.walkHeadPulseRatioMaximum * Double(minimum)
                    + thresholds.craftPixelCanvas,
                "walk \(direction) head scale pulses \(format(pulse))x, expected <=\(format(thresholds.walkHeadPulseRatioMaximum))x plus one \(format(thresholds.craftPixelCanvas))px craft sample"
            )
        } else {
            Issue.record("walk \(direction) contains no measurable head band")
        }

        let torsoWidths = metrics.map(\.torsoWidth).filter { $0 > 0 }
        if let minimum = torsoWidths.min(), let maximum = torsoWidths.max(), minimum > 0 {
            let pulse = Double(maximum) / Double(minimum)
            #expect(
                pulse <= thresholds.walkTorsoPulseRatioMaximum,
                "walk \(direction) torso scale pulses \(format(pulse))x, expected <=\(format(thresholds.walkTorsoPulseRatioMaximum))x"
            )
        } else {
            Issue.record("walk \(direction) contains no measurable torso band")
        }

        let leadCharacters = try frames.map { try $0.footLead() }
        let leads = String(leadCharacters)
        if thresholds.requiresBothPlantedFootLeads {
            #expect(
                leadCharacters.contains("L") && leadCharacters.contains("R"),
                "walk \(direction) planted-foot sequence does not exchange L/R (\(leads))"
            )
        }
        let repeated = longestRepeatedFootLead(in: leadCharacters)
        #expect(
            repeated <= thresholds.maximumRepeatedFootLead,
            "walk \(direction) repeats one planted-foot lead for \(repeated) cells (\(leads)); expected <=\(thresholds.maximumRepeatedFootLead)"
        )

        let adjacentIoU = frames.indices.map { index in
            VossAtlasFrame.intersectionOverUnion(frames[index], frames[(index + 1) % frames.count])
        }
        let ordinaryTransitions = adjacentIoU.dropLast().sorted()
        let median = ordinaryTransitions[ordinaryTransitions.count / 2]
        let closureFloor = min(0.55, median * 0.75)
        if thresholds.requiresWalkLoopClosure {
            #expect(
                adjacentIoU.last! >= closureFloor,
                "walk \(direction) loop closure IoU \(format(adjacentIoU.last!)), expected >=\(format(closureFloor))"
            )
        }
    }

    private func longestRepeatedFootLead(in leads: [Character]) -> Int {
        var longest = 1
        var run = 1
        var previous: Character?
        for lead in leads {
            guard lead == "L" || lead == "R" else {
                previous = nil
                run = 1
                continue
            }
            if lead == previous {
                run += 1
                longest = max(longest, run)
            } else {
                previous = lead
                run = 1
            }
        }
        return longest
    }

    private func format(_ value: Double) -> String {
        String(format: "%.3f", value)
    }

    private func median(_ values: [Int]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return Double(sorted[middle - 1] + sorted[middle]) / 2
        }
        return Double(sorted[middle])
    }
}

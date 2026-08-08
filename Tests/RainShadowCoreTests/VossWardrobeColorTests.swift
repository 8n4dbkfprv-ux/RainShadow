import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import RainShadowCore

/// Guards Voss's V17 material palette and separation across source and runtime
/// art. V17 removes the mustard waistcoat and green tie, and uses seven frozen
/// brown/cream/black/charcoal/skin/auburn material targets.
struct VossWardrobeColorTests {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var atlases: URL {
        repoRoot.appendingPathComponent("RainShadow Shared/Resources/Art/Atlases")
    }

    private var v17: URL {
        repoRoot.appendingPathComponent(
            "ArtSource/Generated/Characters/Detective/PreRendered3DV17"
        )
    }

    @Test func v17InstallerCarriesTheLockedSevenMaterialPalette() throws {
        let installer = try String(
            contentsOf: repoRoot.appendingPathComponent("ArtSource/Processing/install_voss_v17.py"),
            encoding: .utf8
        )

        for material in VossMaterial.allCases {
            let rgb = material.lockedRGB
            let expected = "\"\(material.rawValue)\": (\(Int(rgb.r)), \(Int(rgb.g)), \(Int(rgb.b)))"
            #expect(installer.contains(expected), "V17 installer is missing palette slot \(expected)")
        }

        #expect(installer.contains("material_separation_report"))
        #expect(installer.contains("minimum_target_delta_e"))
        #expect(installer.contains("minimum_luminance_gap"))
        #expect(installer.contains("RAINSHADOW_PRESERVE_WARDROBE"))
    }

    @Test func approvedV17AnchorReachesTheSourceTarget() throws {
        try expectPaletteCoverage(
            label: "approved V17 front anchor",
            url: v17.appendingPathComponent("Anchors/voss_anchor_front_chroma_v17.png"),
            minimum: 0.60
        )
    }

    @Test func v17FrontKeyReachesTheSourceTarget() throws {
        try expectPaletteCoverage(
            label: "V17 authored front key",
            url: v17.appendingPathComponent("Frames/voss_idle_s_00_chroma_v17.png"),
            minimum: 0.70
        )
    }

    @Test func processedFrontAndThreeQuarterCellsKeepMaterialSeparation() throws {
        let subjects = [
            ("idle S", "VossIdle.atlas", "voss_standing_idle_s_00.png"),
            ("idle SSW", "VossIdle.atlas", "voss_standing_idle_ssw_00.png"),
            ("idle SW", "VossIdle.atlas", "voss_standing_idle_sw_00.png"),
            ("walk S", "VossWalk.atlas", "voss_walk_s_00.png"),
            ("walk SSW", "VossWalk.atlas", "voss_walk_ssw_00.png"),
            ("walk SW", "VossWalk.atlas", "voss_walk_sw_00.png"),
            ("seated SE", "VossSeatedIdle.atlas", "voss_seated_idle_se_00.png")
        ]

        for (label, atlas, name) in subjects {
            let sample = try load(
                atlases.appendingPathComponent(atlas).appendingPathComponent(name),
                label: label
            )
            let recognized = sample.lockedPaletteCoverage
            #expect(
                recognized >= 0.70,
                "\(label) locked-palette coverage \(format(recognized)); expected >= 0.70"
            )
        }
    }

    @Test func rearCellsDoNotPaintFrontGarmentsOntoVossBack() throws {
        let subjects = [
            (
                "V17 authored rear key",
                v17.appendingPathComponent("Frames/voss_idle_n_00_chroma_v17.png")
            ),
            (
                "processed idle N",
                atlases.appendingPathComponent("VossIdle.atlas/voss_standing_idle_n_00.png")
            ),
            (
                "processed walk N",
                atlases.appendingPathComponent("VossWalk.atlas/voss_walk_n_00.png")
            )
        ]

        for (label, url) in subjects {
            let sample = try load(url, label: label)
            let fraction = sample.fractionNear(material: .shirt, tolerance: 0.10)
            #expect(
                fraction <= 0.005,
                "\(label) has \(format(fraction)) of body pixels near front-only shirt; expected <= 0.005"
            )
        }
    }

    private func load(_ url: URL, label: String) throws -> VossWardrobeSample {
        guard FileManager.default.fileExists(atPath: url.path) else {
            Issue.record("Missing \(label): \(url.path)")
            throw VossWardrobeColorError.missingPNG(url)
        }
        return try VossWardrobeSample(contentsOf: url)
    }

    private func expectPaletteCoverage(label: String, url: URL, minimum: Double) throws {
        let coverage = try load(url, label: label).lockedPaletteCoverage
        #expect(
            coverage >= minimum,
            "\(label) locked-palette coverage \(format(coverage)); expected >= \(format(minimum))"
        )
    }

    private func format(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}

private enum VossMaterial: String, CaseIterable {
    case shirt
    case skin
    case coat
    case tie
    case shoes
    case trousers
    case hair

    var lockedRGB: VossRGB {
        switch self {
        case .coat: VossRGB(r: 101, g: 59, b: 38)          // #653B26
        case .shirt: VossRGB(r: 211, g: 194, b: 160)       // #D3C2A0
        case .tie: VossRGB(r: 31, g: 30, b: 31)            // #1F1E1F
        case .trousers: VossRGB(r: 55, g: 55, b: 59)       // #37373B
        case .shoes: VossRGB(r: 75, g: 47, b: 35)          // #4B2F23
        case .skin: VossRGB(r: 202, g: 143, b: 108)        // #CA8F6C
        case .hair: VossRGB(r: 112, g: 50, b: 29)          // #70321D
        }
    }
}

private struct VossRGB {
    var r: Double
    var g: Double
    var b: Double

    var mean: Double { (r + g + b) / 3.0 }

    var normalized: VossRGB {
        let divisor = max(mean, 1.0)
        return VossRGB(r: r / divisor, g: g / divisor, b: b / divisor)
    }

    func distance(to other: VossRGB) -> Double {
        let dr = r - other.r
        let dg = g - other.g
        let db = b - other.b
        return (dr * dr + dg * dg + db * db).squareRoot()
    }

    func hueDistance(to other: VossRGB) -> Double {
        normalized.distance(to: other.normalized)
    }
}

private enum VossWardrobeColorError: Error {
    case missingPNG(URL)
    case invalidPNG(URL)
    case noBodyPixels(URL)
}

private struct VossWardrobeSample {
    private let pixels: [VossRGB]

    init(contentsOf url: URL) throws {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              image.width > 0,
              image.height > 0 else {
            throw VossWardrobeColorError.invalidPNG(url)
        }

        let width = image.width
        let height = image.height
        let bytesPerRow = width * 4
        var decoded = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let context = CGContext(
            data: &decoded,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw VossWardrobeColorError.invalidPNG(url)
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var body: [VossRGB] = []
        body.reserveCapacity(width * height / 8)
        for y in 0..<height {
            for x in 0..<width {
                // V14 writes alpha-1 sentinels into all four canvas corners.
                if (x == 0 || x == width - 1) && (y == 0 || y == height - 1) {
                    continue
                }
                let index = y * bytesPerRow + x * 4
                guard decoded[index + 3] >= 128 else { continue }
                let pixel = VossRGB(
                    r: Double(decoded[index]),
                    g: Double(decoded[index + 1]),
                    b: Double(decoded[index + 2])
                )
                // Image Generator masters are RGB chroma images; runtime cells
                // are RGBA. This makes the same sampler authoritative for both.
                let isChroma = pixel.g > 140 &&
                    pixel.g > pixel.r + 40 &&
                    pixel.g > pixel.b + 40
                guard !isChroma, pixel.mean > 25 else { continue }
                body.append(pixel)
            }
        }

        guard body.count >= 64 else {
            throw VossWardrobeColorError.noBodyPixels(url)
        }
        pixels = body
    }

    /// Hue spread across the eight locked material slots. Each body pixel is
    /// assigned to the nearest authored slot in normalized RGB; slots covering
    /// at least 8% of the body then use the same (G/R, B/R) distance as the
    /// Python V14 wardrobe QA. This deterministic palette-seeded form avoids a
    /// k-means seed changing the pass/fail result.
    var paletteHueSpread: Double {
        var sums = Dictionary(
            uniqueKeysWithValues: VossMaterial.allCases.map {
                ($0, (r: 0.0, g: 0.0, b: 0.0, count: 0))
            }
        )

        for pixel in pixels {
            let material = nearestMaterial(to: pixel)
            var current = sums[material]!
            current.r += pixel.r
            current.g += pixel.g
            current.b += pixel.b
            current.count += 1
            sums[material] = current
        }

        let fractions = VossMaterial.allCases.map { material in
            Double(sums[material]!.count) / Double(pixels.count)
        }
        let largest = fractions.max() ?? 0
        var solid = VossMaterial.allCases.filter { material in
            Double(sums[material]!.count) / Double(pixels.count) >= 0.08
        }
        if solid.count < 2 {
            solid = VossMaterial.allCases.filter { material in
                Double(sums[material]!.count) / Double(pixels.count) >= largest * 0.5
            }
        }
        guard solid.count >= 2 else { return 0 }

        var spread = 0.0
        for firstIndex in 0..<(solid.count - 1) {
            for secondIndex in (firstIndex + 1)..<solid.count {
                let first = mean(for: sums[solid[firstIndex]]!)
                let second = mean(for: sums[solid[secondIndex]]!)
                let firstHue = VossRGB(
                    r: 0,
                    g: first.g / max(first.r, 1),
                    b: first.b / max(first.r, 1)
                )
                let secondHue = VossRGB(
                    r: 0,
                    g: second.g / max(second.r, 1),
                    b: second.b / max(second.r, 1)
                )
                spread = max(spread, firstHue.distance(to: secondHue))
            }
        }
        return spread
    }

    /// Share of body pixels whose normalized hue sits near at least one of the
    /// locked material midtones. Shadows and highlights may move value freely.
    var lockedPaletteCoverage: Double {
        let recognized = pixels.count { pixel in
            VossMaterial.allCases.map {
                pixel.hueDistance(to: $0.lockedRGB)
            }.min()! <= 0.20
        }
        return Double(recognized) / Double(pixels.count)
    }

    func fractionNear(material: VossMaterial, tolerance: Double) -> Double {
        let count = pixels.count {
            $0.hueDistance(to: material.lockedRGB) <= tolerance
        }
        return Double(count) / Double(pixels.count)
    }

    private func nearestMaterial(to pixel: VossRGB) -> VossMaterial {
        VossMaterial.allCases.min {
            pixel.hueDistance(to: $0.lockedRGB) <
                pixel.hueDistance(to: $1.lockedRGB)
        }!
    }

    private func mean(for slot: (r: Double, g: Double, b: Double, count: Int)) -> VossRGB {
        let count = Double(max(slot.count, 1))
        return VossRGB(r: slot.r / count, g: slot.g / count, b: slot.b / count)
    }
}

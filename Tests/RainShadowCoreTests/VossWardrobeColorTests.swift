import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import RainShadowCore

/// Guards the shared paperdoll wardrobe grade across seated, idle, and walk atlases.
/// Idle/walk used to bake darker, lower-chroma coats than the desk pose.
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

    @Test func pipelineUsesSeatedPlayScaleWardrobeAuthority() throws {
        let processor = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "ArtSource/Processing/process_pre_rendered_characters_v12.py"
            ),
            encoding: .utf8
        )
        #expect(processor.contains("def identity_wardrobe_lock"))
        #expect(processor.contains("play_scale_wardrobe_stats"))
        #expect(processor.contains("identity_wardrobe_lock(frame)"))
        #expect(processor.contains("_face_roi_mask"))
        #expect(processor.contains("_coat_roi_mask"))
        #expect(!processor.contains("Target from walk coat"))
    }

    @Test func gameplayAtlasesShareFaceAndCoatGrade() throws {
        let seated = try loadRegions(
            atlas: "VossSeatedIdle.atlas",
            name: "voss_seated_idle_ne_00.png"
        )
        let standEndpoint = try loadRegions(
            atlas: "VossSeatTransitions.atlas",
            name: "voss_stand_up_ne_11.png"
        )
        let idleNW = try loadRegions(
            atlas: "VossIdle.atlas",
            name: "voss_standing_idle_nw_00.png"
        )
        let walkS = try loadRegions(
            atlas: "VossWalk.atlas",
            name: "voss_walk_s_00.png"
        )
        let walkNW = try loadRegions(
            atlas: "VossWalk.atlas",
            name: "voss_walk_nw_00.png"
        )

        // Frozen seated-desk targets: face ~140/99/56, coat ~98/67/36.
        for (label, regions) in [
            ("seated", seated),
            ("stand-up 11", standEndpoint),
            ("idle NW", idleNW),
            ("walk S", walkS),
            ("walk NW", walkNW)
        ] {
            #expect(regions.face.r > regions.face.b + 10, "\(label) face not warm: \(regions.face)")
            #expect(regions.coat.r > regions.coat.g, "\(label) coat olive: \(regions.coat)")
            #expect((120.0...165.0).contains(regions.face.r), "\(label) face R \(regions.face.r)")
            #expect((85.0...120.0).contains(regions.coat.r), "\(label) coat R \(regions.coat.r)")
        }

        // Face and coat ROIs must track seated within a tight band.
        for (label, regions) in [
            ("stand-up 11", standEndpoint),
            ("idle NW", idleNW),
            ("walk S", walkS),
            ("walk NW", walkNW)
        ] {
            let faceDelta = regions.face.distance(to: seated.face)
            let coatDelta = regions.coat.distance(to: seated.coat)
            // Pose/viewpoint still changes which folds are lit; keep a tight band
            // without failing on S-facing walk silhouette sampling.
            #expect(faceDelta <= 16.0, "\(label) face delta \(faceDelta) from seated \(seated.face)")
            #expect(coatDelta <= 16.0, "\(label) coat delta \(coatDelta) from seated \(seated.coat)")
        }

        // End-of-stand handoff must not color-pop into standing idle.
        #expect(standEndpoint.face.distance(to: idleNW.face) <= 6.0)
        #expect(standEndpoint.coat.distance(to: idleNW.coat) <= 6.0)
    }

    private func loadRegions(atlas: String, name: String) throws -> FaceCoatRGB {
        let url = atlases.appendingPathComponent(atlas).appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else {
            Issue.record("Missing \(atlas)/\(name)")
            throw VossWardrobeColorError.missingPNG(url)
        }
        return try VossCoatSampler.faceAndCoatMeans(contentsOf: url)
    }
}

private struct CoatRGB: Equatable, CustomStringConvertible {
    var r: Double
    var g: Double
    var b: Double

    var description: String {
        String(format: "(%.1f, %.1f, %.1f)", r, g, b)
    }

    func distance(to other: CoatRGB) -> Double {
        let dr = r - other.r
        let dg = g - other.g
        let db = b - other.b
        return (dr * dr + dg * dg + db * db).squareRoot()
    }
}

private struct FaceCoatRGB {
    var face: CoatRGB
    var coat: CoatRGB
}

private enum VossWardrobeColorError: Error {
    case missingPNG(URL)
    case invalidPNG(URL)
    case noCoatPixels(URL)
}

private enum VossCoatSampler {
    static let alphaThreshold: UInt8 = 40

    /// Geometric face/coat ROIs matching `identity_wardrobe_lock`.
    static func faceAndCoatMeans(contentsOf url: URL) throws -> FaceCoatRGB {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              image.width > 0,
              image.height > 0 else {
            throw VossWardrobeColorError.invalidPNG(url)
        }

        let width = image.width
        let height = image.height
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let context = CGContext(
            data: &pixels,
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

        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1
        for y in 0..<height {
            for x in 0..<width {
                if (x == 0 || x == width - 1) && (y == 0 || y == height - 1) { continue }
                let a = pixels[y * bytesPerRow + x * 4 + 3]
                guard a >= alphaThreshold else { continue }
                minX = min(minX, x)
                maxX = max(maxX, x)
                minY = min(minY, y)
                maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else {
            throw VossWardrobeColorError.noCoatPixels(url)
        }

        let bodyH = max(1, maxY - minY + 1)
        let bodyW = max(1, maxX - minX + 1)
        let faceY1 = min(height - 1, minY + max(2, bodyH * 30 / 100))
        let faceX0 = min(width - 1, minX + bodyW * 15 / 100)
        let faceX1 = min(width - 1, max(faceX0, minX + bodyW * 85 / 100))
        let coatY0 = min(height - 1, minY + bodyH * 28 / 100)
        let coatY1 = min(height - 1, max(coatY0, minY + bodyH * 72 / 100))
        let coatX0 = min(width - 1, minX + bodyW * 12 / 100)
        let coatX1 = min(width - 1, max(coatX0, minX + bodyW * 88 / 100))

        func mean(x0: Int, x1: Int, y0: Int, y1: Int, excludingFace: Bool) throws -> CoatRGB {
            let xLo = max(0, min(x0, x1))
            let xHi = min(width - 1, max(x0, x1))
            let yLo = max(0, min(y0, y1))
            let yHi = min(height - 1, max(y0, y1))
            var sumR = 0.0, sumG = 0.0, sumB = 0.0
            var count = 0
            for y in yLo...yHi {
                for x in xLo...xHi {
                    if (x == 0 || x == width - 1) && (y == 0 || y == height - 1) { continue }
                    if excludingFace,
                       y >= minY, y < faceY1,
                       x >= faceX0, x <= faceX1 {
                        continue
                    }
                    let i = y * bytesPerRow + x * 4
                    guard i + 3 < pixels.count else { continue }
                    let a = pixels[i + 3]
                    guard a >= alphaThreshold else { continue }
                    let r = Double(pixels[i])
                    let g = Double(pixels[i + 1])
                    let b = Double(pixels[i + 2])
                    let lum = (r + g + b) / 3.0
                    guard lum > 18 else { continue }
                    sumR += r
                    sumG += g
                    sumB += b
                    count += 1
                }
            }
            guard count >= 20 else {
                throw VossWardrobeColorError.noCoatPixels(url)
            }
            return CoatRGB(
                r: sumR / Double(count),
                g: sumG / Double(count),
                b: sumB / Double(count)
            )
        }

        let face = try mean(x0: faceX0, x1: faceX1, y0: minY, y1: faceY1, excludingFace: false)
        let coat = try mean(x0: coatX0, x1: coatX1, y0: coatY0, y1: coatY1, excludingFace: true)
        return FaceCoatRGB(face: face, coat: coat)
    }
}

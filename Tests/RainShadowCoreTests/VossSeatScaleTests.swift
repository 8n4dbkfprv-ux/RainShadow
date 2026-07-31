import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import RainShadowCore

/// Guards the Harlan Voss desk sit/stand scale contract: seated idle must share
/// fedora scale with stand-up / standing idle, and crouch must stay shorter than
/// the 200px standing body on the 512 canvas (no 252→232 presentation workaround).
struct VossSeatScaleTests {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var atlases: URL {
        repoRoot.appendingPathComponent("RainShadow Shared/Resources/Art/Atlases")
    }

    @Test func actorDisplayUsesOneSizeForSeatedAndStanding() {
        #expect(OfficeInteriorScale.ActorDisplay.spriteDisplaySize == CGSize(width: 232, height: 232))
        // Dual-size desk inflate (252) caused a height snap on stand-up egress.
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

    @Test func seatedIdleHeadMatchesStandingScale() throws {
        let idle = atlases.appendingPathComponent(
            "VossSeatedIdle.atlas/voss_seated_idle_ne_00.png"
        )
        let standUpEnd = atlases.appendingPathComponent(
            "VossSeatTransitions.atlas/voss_stand_up_ne_11.png"
        )
        let standing = atlases.appendingPathComponent(
            "VossIdle.atlas/voss_standing_idle_se_00.png"
        )
        for url in [idle, standUpEnd, standing] {
            #expect(FileManager.default.fileExists(atPath: url.path), "Missing \(url.lastPathComponent)")
        }

        let idleMetrics = try VossSpriteMetrics.opaqueBody(ofPNG: idle)
        let standUpMetrics = try VossSpriteMetrics.opaqueBody(ofPNG: standUpEnd)
        let standingMetrics = try VossSpriteMetrics.opaqueBody(ofPNG: standing)

        // Crouch stays shorter than the standing 200px texture body.
        #expect(idleMetrics.height >= 120)
        #expect(idleMetrics.height <= 170)
        #expect(standingMetrics.height >= 190)
        #expect(standingMetrics.height <= 210)

        // Fedora band width must stay near standing scale (broken bake was ~15 vs ~32).
        let vsStanding = Double(idleMetrics.headWidth) / Double(standingMetrics.headWidth)
        let vsStandUp = Double(idleMetrics.headWidth) / Double(standUpMetrics.headWidth)
        #expect((0.85...1.15).contains(vsStanding),
                "Seated idle head \(idleMetrics.headWidth) vs standing \(standingMetrics.headWidth)")
        #expect((0.85...1.15).contains(vsStandUp),
                "Seated idle head \(idleMetrics.headWidth) vs stand-up end \(standUpMetrics.headWidth)")
    }

    @Test func standUpClipRisesWithoutCollapsingToTinyIdleScale() throws {
        let idle = try VossSpriteMetrics.opaqueBody(
            ofPNG: atlases.appendingPathComponent(
                "VossSeatedIdle.atlas/voss_seated_idle_ne_00.png"
            )
        )
        var previousHeight = 0
        for index in 0..<12 {
            let url = atlases.appendingPathComponent(
                String(format: "VossSeatTransitions.atlas/voss_stand_up_ne_%02d.png", index)
            )
            #expect(FileManager.default.fileExists(atPath: url.path))
            let metrics = try VossSpriteMetrics.opaqueBody(ofPNG: url)
            // First cells stay near seated crouch height; never the old 40px-wide squash.
            if index == 0 {
                #expect(abs(metrics.height - idle.height) <= 20,
                        "stand-up 00 height \(metrics.height) should be near idle \(idle.height)")
                let headRatio = Double(metrics.headWidth) / Double(idle.headWidth)
                #expect((0.80...1.20).contains(headRatio),
                        "stand-up 00 head \(metrics.headWidth) vs idle \(idle.headWidth)")
            }
            #expect(metrics.height + 4 >= previousHeight,
                    "stand-up body height should not shrink mid-clip (frame \(index))")
            previousHeight = metrics.height
        }
        #expect(previousHeight >= 190)
    }
}

private struct VossOpaqueBodyMetrics {
    var width: Int
    var height: Int
    var headWidth: Int
}

private enum VossSpriteMetrics {
    static func opaqueBody(ofPNG url: URL) throws -> VossOpaqueBodyMetrics {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let ctx = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let alphaThreshold: UInt8 = 16
        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1
        for y in 0..<height {
            for x in 0..<width {
                // Ignore atlas corner sentinels that lock the 512 canvas.
                if (x == 0 || x == width - 1) && (y == 0 || y == height - 1) {
                    continue
                }
                let a = pixels[y * bytesPerRow + x * 4 + 3]
                guard a >= alphaThreshold else { continue }
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let bodyHeight = maxY - minY + 1
        let band = max(1, bodyHeight * 12 / 100)
        // CGContext y=0 is the image bottom; opaque maxY is the visual head.
        let headY0 = max(0, maxY - band + 1)
        var headMinX = width
        var headMaxX = -1
        for y in headY0...maxY {
            for x in 0..<width {
                if (x == 0 || x == width - 1) && (y == 0 || y == height - 1) {
                    continue
                }
                let a = pixels[y * bytesPerRow + x * 4 + 3]
                guard a >= alphaThreshold else { continue }
                headMinX = min(headMinX, x)
                headMaxX = max(headMaxX, x)
            }
        }
        let headWidth = headMaxX >= headMinX ? headMaxX - headMinX + 1 : 0
        return VossOpaqueBodyMetrics(
            width: maxX - minX + 1,
            height: bodyHeight,
            headWidth: headWidth
        )
    }
}

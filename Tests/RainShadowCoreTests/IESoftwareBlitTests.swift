import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import RainShadowCore

struct IESoftwareBlitTests {
    typealias Blit = IESoftwareBlit

    @Test func separateProductTruncationIsNotGPUAlphaBlending() {
        // Exact ShaderBlend<true>: 128 + 127 = 255 for white, but
        // DIV255(128*100) + DIV255(127*100) = 50 + 49 = 99, not 100.
        let c = Blit.pixel(IEColor(100, 100, 100, 128), over: IEColor(100, 100, 100),
                           tint: .opaqueWhite, flags: .blended)
        #expect(c == IEColor(99, 99, 99, 255))
        #expect(Blit.pixel(.opaqueWhite, over: .transparentBlack,
                           tint: .opaqueWhite, flags: .blended) == .opaqueWhite)
        #expect(Blit.pixel(IEColor(255, 128, 10, 0), over: IEColor(3, 4, 5, 6),
                           tint: .opaqueWhite, flags: .sepia, mask: 128) == IEColor(3, 4, 5, 6))
    }

    @Test func rawMaskRetainsUpstreamsByteWrapping() {
        // (255 - 1) + 128 * 1 = 382 -> uint8_t 126, NOT alpha multiplication.
        let c = Blit.pixel(IEColor(255, 255, 255, 128), over: .transparentBlack,
                           tint: .opaqueWhite, flags: .blended, mask: 1)
        #expect(c == IEColor(126, 126, 126, 126))
    }

    @Test func integerPivotAndKeyAreAppliedBeforeShading() throws {
        var palette = [IEColor](repeating: .opaqueWhite, count: 256)
        palette[0] = IEColor(255, 0, 255, 255) // Still a colour key, not magenta ink.
        palette[1] = IEColor(64, 80, 100)
        let frame = try Blit.Frame(width: 2, height: 1, origin: .init(x: -2, y: 3), indices: [1, 0])
        var buffer = try Blit.Buffer(width: 6, height: 4,
                                    pixels: .init(repeating: IEColor(10, 20, 30), count: 24))
        try buffer.blit(frame, palette: palette, at: .init(x: 1, y: 4))
        #expect(buffer.pixels[1 * 6 + 3] == palette[1])
        #expect(buffer.pixels.filter { $0 == palette[1] }.count == 1)
        #expect(buffer.pixels[1 * 6 + 4] == IEColor(10, 20, 30))
    }

    @Test func clippingKeepsSDL1sTotalTrimAndClippedMirrorOrder() throws {
        let palette = (0..<256).map { IEColor(UInt8($0), 0, 0) }
        let frame = try Blit.Frame(width: 6, height: 1, origin: .init(x: 0, y: 0), indices: [1, 2, 3, 4, 5, 6])
        var buffer = try Blit.Buffer(width: 2, height: 1, pixels: [.opaqueWhite, .opaqueWhite])
        try buffer.blit(frame, palette: palette, at: .init(x: -2, y: 0))
        #expect(buffer.pixels.map(\.r) == [5, 6]) // Total trim 4, not left trim 2.
        try buffer.blit(frame, palette: palette, at: .init(x: -2, y: 0), mirrorX: true)
        #expect(buffer.pixels.map(\.r) == [6, 5]) // Reverse the trimmed region.
    }

    @Test func validationRejectsUnsupportedEffectsInsteadOfIgnoringThem() throws {
        #expect(throws: Blit.Failure.invalidDimensions) {
            try Blit.Frame(width: -1, height: 1, origin: .init(x: 0, y: 0), indices: [])
        }
        #expect(throws: Blit.Failure.invalidPixelCount) {
            try Blit.Buffer(width: 1, height: 1, pixels: [])
        }
        let frame = try Blit.Frame(width: 1, height: 1, origin: .init(x: 0, y: 0), indices: [1])
        var buffer = try Blit.Buffer(width: 1, height: 1, pixels: [.opaqueWhite])
        let palette = [IEColor](repeating: .opaqueWhite, count: 256)
        #expect(throws: Blit.Failure.unsupportedFlags(IEBlitFlags.halftrans.rawValue)) {
            try buffer.blit(frame, palette: palette, at: .init(x: 0, y: 0), flags: .halftrans)
        }
        #expect(throws: Blit.Failure.invalidMask) {
            try buffer.blit(frame, palette: palette, at: .init(x: 0, y: 0), mask: [])
        }
    }

    @Test func nativeAdapterUsesOneScaleAcrossTheCompleteVossInventory() throws {
        let sprite = try VossAtlasTestAssets.indexedSprite()
        #expect(sprite.registeredPixelsPerNativePixel == 3.125)
        var nonempty = 0
        for frame in sprite.frames {
            let native = try sprite.softwareFrame(for: frame)
            #expect(native.width == frame.nativeSize.width)
            #expect(native.height == frame.nativeSize.height)
            #expect(native.indices == frame.indices)
            guard !frame.isEmpty else { continue }
            nonempty += 1
            let x = frame.pivotFromCropBottomLeft.x / sprite.registeredPixelsPerNativePixel
            let y = (Double(frame.size.height) - frame.pivotFromCropBottomLeft.y)
                / sprite.registeredPixelsPerNativePixel
            #expect(abs(Double(native.origin.x) - x) <= 0.5)
            #expect(abs(Double(native.origin.y) - y) <= 0.5)
        }
        #expect(nonempty == 224)
    }

    private struct Case {
        var width: Int
        var height: Int
        var frame: Blit.Frame
        var palette: [IEColor]
        var background: [IEColor]
        var position: Blit.Point
        var clip: Blit.Rect
        var flags: IEBlitFlags
        var tint: IEColor
        var mirrorX = false
        var mirrorY = false
        var mask: [UInt8]? = nil

        func render() throws -> Blit.Buffer {
            var buffer = try Blit.Buffer(width: width, height: height, pixels: background)
            try buffer.blit(frame, palette: palette, at: position, clip: clip, tint: tint,
                            flags: flags, mirrorX: mirrorX, mirrorY: mirrorY, mask: mask)
            return buffer
        }

        func append(to data: inout Data) {
            let header = [width, height, frame.width, frame.height, frame.origin.x, frame.origin.y,
                          position.x, position.y, clip.x, clip.y, clip.width, clip.height,
                          Int(flags.rawValue), (mirrorX ? 1 : 0) | (mirrorY ? 2 : 0), mask == nil ? 0 : 1]
            for v in header {
                var word = Int32(v).littleEndian
                withUnsafeBytes(of: &word) { data.append(contentsOf: $0) }
            }
            data.append(contentsOf: [tint.r, tint.g, tint.b, tint.a])
            for c in palette { data.append(contentsOf: [c.r, c.g, c.b, c.a]) }
            data.append(contentsOf: frame.indices)
            for c in background { data.append(contentsOf: [c.r, c.g, c.b, c.a]) }
            if let mask { data.append(contentsOf: mask) }
        }
    }

    /// The QA command compiles GemRB C++ and sets this path. Normal Swift tests
    /// still exercise the fixed regressions above; they do not pretend a second
    /// Swift formula is an independent upstream oracle.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["RAINSHADOW_IE_SOFTWARE_ORACLE"] != nil))
    func differentialAgainstCompiledGemRB() throws {
        let executable = try #require(ProcessInfo.processInfo.environment["RAINSHADOW_IE_SOFTWARE_ORACLE"])
        let sprite = try VossAtlasTestAssets.indexedSprite()
        var state: UInt32 = 0x1c45_c185
        func random(_ bound: Int) -> Int {
            state = state &* 1_664_525 &+ 1_013_904_223
            return Int(state >> 8) % bound
        }
        func color() -> IEColor { IEColor(UInt8(random(256)), UInt8(random(256)), UInt8(random(256)), UInt8(random(256))) }
        let modes: [IEBlitFlags] = [[], .blended, .colorMod, .grey, .sepia,
                                    [.colorMod, .grey], [.colorMod, .sepia], [.colorMod, .grey, .sepia]]
        var cases = [Case]()
        // Adversarial frame geometry, arbitrary alpha, every shader selection,
        // all four mirroring combinations, raw alpha masks and coloured keys.
        for i in 0..<256 {
            let w = 1 + random(47), h = 1 + random(43)
            let palette = (0..<256).map { _ in color() }
            let frame = try Blit.Frame(width: w, height: h,
                                       origin: .init(x: random(60) - 20, y: random(60) - 20),
                                       indices: (0..<(w * h)).map { _ in UInt8(random(256)) })
            cases.append(Case(width: 31, height: 23, frame: frame, palette: palette,
                              background: (0..<(31 * 23)).map { _ in color() },
                              position: .init(x: random(70) - 20, y: random(60) - 20),
                              clip: .init(x: random(8) - 4, y: random(8) - 4,
                                          width: 12 + random(28), height: 12 + random(28)),
                              flags: modes[i % modes.count], tint: color(),
                              mirrorX: i % 2 == 0, mirrorY: i % 4 < 2,
                              mask: i % 3 == 0 ? (0..<(31 * 23)).map { _ in UInt8(random(256)) } : nil))
        }
        // Every palette alpha byte is exercised at an on-screen location.
        let alphaFrame = try Blit.Frame(width: 255, height: 1, origin: .init(x: 0, y: 0), indices: Array(1...255))
        for mode in modes {
            for maskByte: UInt8 in [0, 1, 127, 128, 254, 255] {
                cases.append(Case(width: 255, height: 1, frame: alphaFrame,
                                  palette: (0...255).map { IEColor(101, 173, 249, UInt8($0)) },
                                  background: (0..<255).map { IEColor(UInt8($0), 100, 255, UInt8(254 - $0)) },
                                  position: .init(x: 0, y: 0), clip: .init(x: 0, y: 0, width: 255, height: 1),
                                  flags: mode, tint: IEColor(181, 219, 243), mask: .init(repeating: maskByte, count: 255)))
            }
        }
        let background: [IEColor] = (0..<9216).map { (p: Int) -> IEColor in
            let red = UInt8(32 + (p % 73))
            let green = UInt8(24 + ((p / 96) % 53))
            let blue = UInt8(20 + (p % 41))
            return IEColor(red, green, blue)
        }
        for (i, frame) in sprite.frames.enumerated() {
            for variant in 0..<4 {
                cases.append(Case(width: 96, height: 96, frame: try sprite.softwareFrame(for: frame),
                                  palette: sprite.palette.colors, background: background,
                                  position: .init(x: variant == 1 ? 0 : 48, y: variant == 2 ? 10 : 80),
                                  clip: .init(x: 0, y: 0, width: 96, height: 96),
                                  flags: modes[(i + variant) % modes.count], tint: IEColor(191, 207, 223),
                                  mirrorX: variant >= 2, mirrorY: variant == 3))
            }
        }
        let work = FileManager.default.temporaryDirectory.appendingPathComponent("ie-software-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }
        var request = Data()
        var count = UInt32(cases.count).littleEndian
        withUnsafeBytes(of: &count) { request.append(contentsOf: $0) }
        var expected = Data()
        for c in cases {
            c.append(to: &request)
            expected.append(contentsOf: try c.render().rgba)
        }
        let input = work.appendingPathComponent("request.bin")
        let output = work.appendingPathComponent("reference.bin")
        try request.write(to: input)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = [input.path, output.path]
        try process.run()
        process.waitUntilExit()
        try #require(process.terminationStatus == 0)
        let actual = try Data(contentsOf: output)
        try #require(actual.count == expected.count)
        let mismatches = zip(expected, actual).reduce(0) { $0 + ($1.0 == $1.1 ? 0 : 1) }
        #expect(mismatches == 0)
        print("GemRB software oracle: \(cases.count) cases, \(sprite.frames.count) Voss frames, \(expected.count) bytes, \(mismatches) mismatches")
        if let path = ProcessInfo.processInfo.environment["RAINSHADOW_IE_SOFTWARE_REVIEW"] {
            let root = URL(fileURLWithPath: path)
            let report: [String: Any] = ["cases": cases.count, "installed_frames": sprite.frames.count,
                                      "nonempty_frames": sprite.frames.filter { !$0.isEmpty }.count,
                                      "compared_rgba_bytes": expected.count, "mismatched_bytes": mismatches]
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                .write(to: root.appendingPathComponent("pixel_comparison.json"))
            try writeReview(sprite: sprite, to: root)
        }
    }

    private func writeReview(sprite: IEIndexedSprite, to root: URL) throws {
        let frames = sprite.frames.filter { $0.id.name.hasPrefix("voss_standing_idle_") && $0.id.name.hasSuffix("_00.png") }
            .sorted { $0.id.name < $1.id.name }
        let width = max(1, frames.count) * 96, height = 96
        var sheet = try Blit.Buffer(width: width, height: height,
                                   pixels: .init(repeating: IEColor(32, 35, 37), count: width * height))
        for (column, frame) in frames.enumerated() {
            try sheet.blit(sprite.softwareFrame(for: frame), palette: sprite.palette.colors,
                           at: .init(x: column * 96 + 48, y: 80))
        }
        let bytes = Data(sheet.rgba)
        let provider = try #require(CGDataProvider(data: bytes as CFData))
        let image = try #require(CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                                        bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                        provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        let url = root.appendingPathComponent("voss_native_software.png")
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        try #require(CGImageDestinationFinalize(destination))
        try frames.map(\.id.name).joined(separator: "\n").write(to: root.appendingPathComponent("native_columns.txt"), atomically: true, encoding: .utf8)
        let sw = try #require(frames.first { $0.id.name == "voss_standing_idle_sw_00.png" })
        let native = try sprite.softwareFrame(for: sw)
        let pivot = try #require(sw.normalizedPivot)
        let scale = Double(OfficeInteriorScale.cameraScaleAt100Percent)
        var reference = try Blit.Buffer(width: 96, height: 96,
                                       pixels: .init(repeating: IEColor(32, 35, 37), count: 96 * 96))
        try reference.blit(native, palette: sprite.palette.colors, at: .init(x: 48, y: 80),
                           tint: IEColor(191, 207, 223), flags: [.blended, .colorMod])
        try Data(reference.rgba).write(to: root.appendingPathComponent("sw_reference.rgba"))
        try Data(sprite.rgba(for: sw)).write(to: root.appendingPathComponent("sw_source.rgba"))
        let presentation: [String: Any] = [
            "frame": sw.id.name, "width": native.width, "height": native.height,
            "origin_x": native.origin.x, "origin_y": native.origin.y,
            "registered_width_points": Double(sw.size.width) * sprite.displayUnitsPerSourcePixel.x / scale,
            "registered_height_points": Double(sw.size.height) * sprite.displayUnitsPerSourcePixel.y / scale,
            "anchor_x": pivot.x, "anchor_y": pivot.y,
            "tint": [191, 207, 223], "background": [32, 35, 37],
            "note": "isolated 100% logical-pixel adapter proof, not a live-game screenshot"
        ]
        try JSONSerialization.data(withJSONObject: presentation, options: [.prettyPrinted, .sortedKeys])
            .write(to: root.appendingPathComponent("presentation_input.json"))
    }
}

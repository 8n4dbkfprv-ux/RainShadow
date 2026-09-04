import Foundation
import Testing
@testable import RainShadowCore

/// Pins `IEResample` to `ArtSource/Processing/ie_resample.py`.
///
/// Both are transliterations of Near Infinity's `scaleSuperXBR`, and the atlas
/// round-trip tests are only exact while they agree: the bake renders a frame in
/// Python and the round-trip re-renders it here. A drift between the two shows
/// up as a whole-atlas failure with no obvious cause, so it is pinned directly.
struct IEResampleTests {
    private struct Fixture: Decodable {
        struct Case: Decodable {
            let name: String
            let width: Int
            let height: Int
            let factor: Double
            let input: [UInt32]
            let output_width: Int
            let output_height: Int
            let output: [UInt32]
        }
        struct Render: Decodable {
            let name: String
            let native_width: Int
            let native_height: Int
            let indices: [UInt8]
            let texture_width: Int
            let texture_height: Int
            let colors: [UInt32]
            let rgba: [UInt8]
        }
        let shipping_scale: Double
        let cases: [Case]
        let renders: [Render]
    }

    private static let fixture: Fixture = {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/IEResample/superxbr.json")
        // swiftlint:disable:next force_try
        return try! JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    }()

    @Test func superXBRMatchesThePythonPortPixelForPixel() {
        for testCase in Self.fixture.cases {
            let result = IEResample.scaleSuperXBR(
                testCase.input, testCase.width, testCase.height,
                testCase.factor, testCase.factor
            )
            let shape = "\(result.width)x\(result.height)"
            let wanted = "\(testCase.output_width)x\(testCase.output_height)"
            #expect(
                result.width == testCase.output_width && result.height == testCase.output_height,
                "\(testCase.name) produced \(shape), expected \(wanted)"
            )
            #expect(result.pixels == testCase.output, "\(testCase.name) diverged from the Python port")
        }
    }

    @Test func theShippingScaleIsTheRegisteredBodyOverTheNativeCraft() {
        // 200px registered body / 64 native rows. If either constant moves, the
        // fixture was generated at a scale the bake no longer uses.
        #expect(Self.fixture.shipping_scale == 200.0 / 64.0)
    }

    @Test func doublingIsExactlyTwiceTheInput() {
        let pixels: [UInt32] = [
            0xFF00_0000, 0xFFFF_FFFF,
            0xFFFF_FFFF, 0xFF00_0000,
        ]
        let result = IEResample.scaleSuperXBR2x(pixels, 2, 2)
        #expect(result.width == 4 && result.height == 4)
        #expect(result.pixels.count == 16)
    }

    @Test func lanczosWeightUsesUpstreamsAsymmetricBound() {
        // `x <= -kernelSize || x > kernelSize` — not `abs(x) >= kernelSize`. The
        // left edge is exclusive and the right inclusive, so -3 is zero and +3
        // is not. Reproducing that is the difference from a tidied rewrite.
        #expect(IEResample.lanczos(0.0, 3) == 1.0)
        #expect(IEResample.lanczos(-3.0, 3) == 0.0)
        #expect(IEResample.lanczos(3.5, 3) == 0.0)
        #expect(IEResample.lanczos(3.0, 3) != 0.0)
    }

    @Test func theWholeRenderPathMatchesThePythonBake() throws {
        // `scaleSuperXBR` agreeing is not enough: the atlas round-trip compares
        // a full render, which also covers resolving indices through the
        // palette, the unpremultiply rounding, and the 1-bit silhouette.
        let tables = try IEGradientTables.load()
        for render in Self.fixture.renders {
            let palette = IEPaperdollColours.setup(colors: render.colors, tables: tables)
            let produced = IEIndexedSprite.render(
                indices: render.indices,
                nativeSize: .init(width: render.native_width, height: render.native_height),
                textureSize: .init(width: render.texture_width, height: render.texture_height),
                palette: palette
            )
            #expect(
                produced.count == render.rgba.count,
                "\(render.name) produced \(produced.count) bytes, expected \(render.rgba.count)"
            )
            #expect(produced == render.rgba, "\(render.name) diverged from the Python render")
        }
    }

    @Test func truncationTowardZeroNotFloor() {
        // The Super xBR weights include negatives (w1 = -0.129633), so an
        // intermediate can be negative and Java's `(int)` cast must truncate.
        #expect(IEResample.truncate(-0.7) == 0)
        #expect(IEResample.truncate(0.7) == 0)
        #expect(IEResample.truncate(-1.9) == -1)
    }
}

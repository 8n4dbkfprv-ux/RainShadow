import Foundation
import Testing
@testable import RainShadowCore

/// Holds the GemRB colour-model port (`IEPalette`, `IEGradientTables`,
/// `IEPaperdollColours`, `PLTSprite`) to upstream's answers.
///
/// The fixture these read is produced by
/// `ArtSource/Processing/emit_ie_palette_fixture.py` from the Python port of the
/// same functions, so a change that moves one language and not the other fails
/// here rather than shipping as a quiet colour shift.
/// `ArtSource/Processing/qa_ie_palette_port.py` checks the other side: that the
/// layout matches shipped BG:EE data.
struct IEPaletteTests {
    private struct Fixture: Decodable {
        struct Case: Decodable {
            let name: String
            let colors: [UInt32]
            let type: Int
            let palette: [[UInt8]]
        }
        struct Gradient: Decodable {
            let color: [UInt8]
            let back: [UInt8]
            let palette: [[UInt8]]
        }
        let paperdoll_colours: [Case]
        let gradient_constructor: Gradient
    }

    private static let fixture: Fixture = {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/IEPalette/paperdoll_colours.json")
        // swiftlint:disable:next force_try
        return try! JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    }()

    private func tables() throws -> IEGradientTables {
        try IEGradientTables.load()
    }

    private func colors(_ entries: [[UInt8]]) -> [IEColor] {
        entries.map { IEColor($0[0], $0[1], $0[2], $0[3]) }
    }

    // MARK: - Gradient tables

    @Test func gradientTablesAreTheShippedBGEEShape() throws {
        let tables = try tables()
        #expect(tables.palette16(0).count == IEGradientTables.shades16)
        #expect(tables.palette256(0).count == IEGradientTables.shades256)
        // MPALETTE row 12 is the most-used skin gradient across BG:EE's 2,253
        // creatures; if the table ever loads flipped or byte-swapped, this pale
        // pink first shade is the first thing to move.
        #expect(Array(tables.palette16(12)).first == IEColor(242, 217, 217, 255))
    }

    @Test func gradientLookupFallsBackToRowZeroOutOfRange() throws {
        let tables = try tables()
        // `return (idx >= palettes16.size()) ? palettes16[0] : palettes16[idx];`
        // The argument is a uint8_t, so 0x100 is index 0 twice over.
        #expect(Array(tables.palette16(0x100)) == Array(tables.palette16(0)))
        #expect(Array(tables.palette256(0x1FF)) == Array(tables.palette256(0xFF)))
    }

    // MARK: - SetupPaperdollColours

    @Test func paperdollColoursMatchThePythonPortEntryForEntry() throws {
        let tables = try tables()
        for testCase in Self.fixture.paperdoll_colours {
            let palette = IEPaperdollColours.setup(
                colors: testCase.colors,
                type: testCase.type,
                tables: tables
            )
            #expect(
                palette.colors == colors(testCase.palette),
                "\(testCase.name) diverged from the Python port"
            )
        }
    }

    @Test func eachMaterialSlotLandsOnItsOwnTwelveShadeRun() throws {
        let tables = try tables()
        let indices: [UInt32] = [10, 20, 30, 12, 40, 50, 60]
        let palette = IEPaperdollColours.setup(colors: indices, tables: tables)

        for slot in IEMaterialSlot.allCases {
            let start = slot.paletteOffset
            let run = Array(palette.colors[start..<(start + IEPaperdollColours.numCols)])
            let expected = Array(tables.palette16(Int(indices[slot.rawValue])).prefix(12))
            #expect(run == expected, "slot \(slot) is not its own gradient run")
        }
        // The seven runs have to end exactly where the alias region starts, or
        // every alias below copies the wrong material.
        #expect(IEMaterialSlot.hair.paletteOffset + IEPaperdollColours.numCols == 0x58)
    }

    @Test func aliasRegionsCopyTheMaterialsUpstreamSays() throws {
        let tables = try tables()
        let palette = IEPaperdollColours.setup(
            colors: [10, 20, 30, 12, 40, 50, 60],
            tables: tables
        )
        func run(_ start: Int) -> [IEColor] { Array(palette.colors[start..<(start + 8)]) }

        #expect(run(0x58) == run(0x11), "0x58 aliases minor")
        #expect(run(0x60) == run(0x1D), "0x60 aliases major")
        #expect(run(0x70) == run(0x05), "0x70 aliases metal")
        #expect(run(0xB0) == run(0x29), "0xB0 aliases skin")
        // `for (int i = 0xB8; i < 0xFF; i += 0x08)` stops at 0xF8 and still
        // fills through 0xFF, so the very last entry is leather.
        #expect(run(0xF8) == run(0x35), "the 0xB8 loop fills through 0xFF")
    }

    @Test func theShadowIsAPaletteEntryNotABakedPixel() throws {
        let tables = try tables()
        var palette = IEPaperdollColours.setup(
            colors: [1, 2, 3, 4, 5, 6, 7],
            tables: tables
        )
        #expect(palette[IEPalette.shadowIndex] == IEColor(0, 0, 0, 255))

        palette.translucentShadowColor(true)
        #expect(palette[IEPalette.shadowIndex].a == 128)
        palette.translucentShadowColor(false)
        #expect(palette[IEPalette.shadowIndex].a == 255)
    }

    @Test func typeShiftsTheColourDwordBeforeTheLookup() throws {
        let tables = try tables()
        let shifted = IEPaperdollColours.setup(
            colors: [UInt32](repeating: 0x0C00, count: 7),
            type: 1,
            tables: tables
        )
        #expect(Array(shifted.colors[0x04..<0x10]) == Array(tables.palette16(12).prefix(12)))
    }

    // MARK: - Palette(color, back)

    @Test func gradientConstructorMatchesThePythonPort() throws {
        let fixture = Self.fixture.gradient_constructor
        let palette = IEPalette(
            color: IEColor(fixture.color[0], fixture.color[1], fixture.color[2]),
            back: IEColor(fixture.back[0], fixture.back[1], fixture.back[2])
        )
        #expect(palette.colors == colors(fixture.palette))
    }

    @Test func gradientConstructorTruncatesRatherThanRounds() {
        // `std::min<int>(...)` converts the float to int before comparing, so
        // the midpoint of a 100..200 ramp is 150 and not 151.
        let grey = IEPalette(color: IEColor(200, 200, 200), back: IEColor(100, 100, 100))
        #expect(grey[128].r == 150)
        #expect(grey[0] == IEColor(0, 0xFF, 0, 0))
        #expect(grey[255] == IEColor(200, 200, 200, 0xFF))
    }

    // MARK: - PLT

    @Test func pltDecodesBottomUpAndKeysOnIntensity() throws {
        let tables = try tables()
        let width = 3
        let height = 2
        // Row 0 as stored is the *bottom* row of the image.
        var plane: [UInt8] = []
        for row in 0..<height {
            for column in 0..<width {
                plane.append(UInt8(row * 40 + column * 10))
                plane.append(UInt8(column % 8))
            }
        }
        var data = Data("PLT V1  ".utf8)
        data.append(contentsOf: [UInt8](repeating: 0, count: 8))
        data.append(contentsOf: withUnsafeBytes(of: UInt32(width).littleEndian, Array.init))
        data.append(contentsOf: withUnsafeBytes(of: UInt32(height).littleEndian, Array.init))
        data.append(contentsOf: plane)

        let sprite = try PLTSprite(data: data)
        #expect(sprite.width == width)
        #expect(sprite.height == height)

        let indices: [UInt32] = [0, 1, 2, 3, 4, 5, 6, 7]
        let rgba = sprite.rgba(paletteIndex: indices, tables: tables)
        #expect(rgba.count == width * height * 4)

        // `for (int y = Height - 1; y >= 0; y--)` — stored row 1 comes out first.
        let storedTopRow = 1
        for column in 0..<width {
            let intensity = Int(plane[(storedTopRow * width + column) * 2])
            let range = Int(plane[(storedTopRow * width + column) * 2 + 1])
            let gradient = indices[PLTSprite.pperm[range]]
            let expected = Array(tables.palette256(Int(gradient)))[intensity]
            let offset = column * 4
            #expect(rgba[offset] == expected.r)
            #expect(rgba[offset + 1] == expected.g)
            #expect(rgba[offset + 2] == expected.b)
            #expect(rgba[offset + 3] == 0xFF)
        }
    }

    @Test func pltIntensityFFIsTransparent() throws {
        let tables = try tables()
        var data = Data("PLT V1  ".utf8)
        data.append(contentsOf: [UInt8](repeating: 0, count: 8))
        data.append(contentsOf: withUnsafeBytes(of: UInt32(1).littleEndian, Array.init))
        data.append(contentsOf: withUnsafeBytes(of: UInt32(1).littleEndian, Array.init))
        data.append(contentsOf: [0xFF, 0x00])

        let rgba = try PLTSprite(data: data).rgba(paletteIndex: [UInt32](repeating: 0, count: 8), tables: tables)
        #expect(rgba[3] == 0x00)
    }

    @Test func pltRejectsAFileThatIsNotOne() {
        #expect(throws: PLTError.self) {
            _ = try PLTSprite(data: Data("NOT A PLT FILE AT ALL...".utf8))
        }
    }
}

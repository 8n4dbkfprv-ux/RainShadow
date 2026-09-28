import Foundation

/// Explicit indexed asset encoding. Legacy assets keep the GemRB palette;
/// CHMF assets carry the BG:EE pairwise material ranges. See
/// Documentation/VossCurrentRuntime.md for provenance and the source difference.
enum IECharacterPaletteLayout: String, Sendable {
    case gemrbAliases = "gemrb-alias-v1"
    case bgeeMixed = "bgee-mixed-v1"

    static let mixedPairs: [(IEMaterialSlot, IEMaterialSlot)] =
        IEMaterialSlot.allCases.flatMap { first in
            IEMaterialSlot.allCases.filter { $0.rawValue > first.rawValue }.map { (first, $0) }
        }
    private static let mixedShadeColumns = [0, 1, 3, 4, 6, 7, 9, 10]

    func palette(colors: [UInt32], tables: IEGradientTables) -> IEPalette {
        var result = IEPaperdollColours.setup(colors: colors, tables: tables)
        guard self == .bgeeMixed else { return result }
        for (pairIndex, pair) in Self.mixedPairs.enumerated() {
            for (shade, column) in Self.mixedShadeColumns.enumerated() {
                let a = result[pair.0.paletteOffset + column]
                let b = result[pair.1.paletteOffset + column]
                func mean(_ x: UInt8, _ y: UInt8) -> UInt8 { UInt8((Int(x) + Int(y)) / 2) }
                result[88 + pairIndex * 8 + shade] = IEColor(mean(a.r, b.r), mean(a.g, b.g), mean(a.b, b.b))
            }
        }
        result[2] = IEColor(0, 0, 0)
        result[3] = IEColor(0, 0, 0)
        return result
    }

    func materials(for index: UInt8) -> [IEMaterialSlot] {
        if (4..<88).contains(index) {
            return [IEMaterialSlot(rawValue: (Int(index) - 4) / 12)!]
        }
        guard self == .bgeeMixed, index >= 88 else { return [] }
        let pair = Self.mixedPairs[(Int(index) - 88) / 8]
        return [pair.0, pair.1]
    }

    func allows(_ index: UInt8) -> Bool {
        index <= 1 || !materials(for: index).isEmpty
    }
}

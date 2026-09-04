import Foundation

enum IEGradientError: Error, CustomStringConvertible {
    case resourceNotFound(name: String)
    case malformed(name: String, expected: Int, got: Int)

    var description: String {
        switch self {
        case let .resourceNotFound(name):
            return "IE gradient table \(name).bin not found"
        case let .malformed(name, expected, got):
            return "IE gradient table \(name).bin is \(got) bytes, expected \(expected)"
        }
    }
}

/// The engine's gradient tables (GemRB `core/Interface.h`, `LoadPalette<SIZE>`).
///
/// ```cpp
/// template<int SIZE>
/// bool LoadPalette(const ResRef& resref, std::vector<ColorPal<SIZE>>& palettes) const
/// {
///     ...
///     int height = image->Frame.h;
///     palettes.resize(height);
///     Region clip(0, 0, SIZE, height);
///     auto it = image->GetIterator(..., clip);
///     for (; it != end; ++it) {
///         const Point& p = it.Position();
///         palettes[p.y][p.x] = it.ReadRGBA();
///     }
/// }
/// ```
///
/// So: **row is the gradient index, column is the shade**. The whole IE colour
/// model is those two lookups. A character is seven gradient indices — one per
/// material slot — and `SetupPaperdollColours` copies runs out of these rows.
///
/// The data is BG:EE's `MPALETTE` (12 shades × 256 gradients) and `MPAL256`
/// (256 × 256), extracted by `ArtSource/Processing/extract_ie_gradients.py`.
/// BG:EE ships no PAL32 resource, so `LoadPalette<32>` has nothing to load
/// there and nothing here reads one.
struct IEGradientTables: Sendable {
    /// `MPALETTE` is 12 columns wide even though the container is
    /// `ColorPal<16>`. `Region clip(0, 0, SIZE, height)` is a maximum, not a
    /// promise, and `SetupPaperdollColours` only ever copies `numCols = 12`.
    static let shades16 = 12
    static let shades256 = 256
    static let gradientCount = 256

    private let pal16: [IEColor]
    private let pal256: [IEColor]

    init(pal16: [IEColor], pal256: [IEColor]) {
        self.pal16 = pal16
        self.pal256 = pal256
    }

    /// `GetPalette16(uint8_t idx)`:
    /// `return (idx >= palettes16.size()) ? palettes16[0] : palettes16[idx];`
    ///
    /// The argument is a `uint8_t`, so a shifted colour dword truncates to its
    /// low byte before the lookup ever happens.
    func palette16(_ index: Int) -> ArraySlice<IEColor> {
        row(in: pal16, index: index, width: Self.shades16)
    }

    /// `GetPalette256(uint8_t idx)`.
    func palette256(_ index: Int) -> ArraySlice<IEColor> {
        row(in: pal256, index: index, width: Self.shades256)
    }

    private func row(in table: [IEColor], index: Int, width: Int) -> ArraySlice<IEColor> {
        let rows = table.count / width
        let clamped = (index & 0xFF) >= rows ? 0 : (index & 0xFF)
        let start = clamped * width
        return table[start..<(start + width)]
    }

    // MARK: - Loading

    /// `.copy("../../Resources/Art/IE")` puts the directory itself in the
    /// bundle, so the subdirectory is its name — the same shape as
    /// `AreaCatalogLoader.resourceSubdirectory`'s "Areas".
    static let resourceSubdirectory = "IE"

    static func load(bundle: Bundle? = nil) throws -> IEGradientTables {
        IEGradientTables(
            pal16: try table(named: "pal16", width: shades16, bundle: bundle),
            pal256: try table(named: "pal256", width: shades256, bundle: bundle)
        )
    }

    private static func table(named name: String, width: Int, bundle: Bundle?) throws -> [IEColor] {
        let data = try resourceData(named: name, bundle: bundle)
        let expected = gradientCount * width * 4
        guard data.count == expected else {
            throw IEGradientError.malformed(name: name, expected: expected, got: data.count)
        }
        return stride(from: 0, to: data.count, by: 4).map { offset in
            IEColor(data[offset], data[offset + 1], data[offset + 2], data[offset + 3])
        }
    }

    private static func resourceData(named name: String, bundle: Bundle?) throws -> Data {
        let searchBundles: [Bundle] = {
            if let bundle { return [bundle] }
            #if SWIFT_PACKAGE
            return [.module, .main]
            #else
            return [.main]
            #endif
        }()
        for candidate in searchBundles {
            if let url = candidate.url(
                forResource: name,
                withExtension: "bin",
                subdirectory: resourceSubdirectory
            ) ?? candidate.url(forResource: name, withExtension: "bin") {
                return try Data(contentsOf: url)
            }
        }
        let url = developmentDirectory.appendingPathComponent("\(name).bin", isDirectory: false)
        if FileManager.default.fileExists(atPath: url.path) {
            return try Data(contentsOf: url)
        }
        throw IEGradientError.resourceNotFound(name: name)
    }

    /// Mirrors `AreaCatalogLoader.developmentAreasDirectory`: the checkout copy,
    /// so tests and tools work before the app bundle is built.
    static var developmentDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Navigation
            .deletingLastPathComponent()   // Gameplay
            .deletingLastPathComponent()   // RainShadow Shared
            .appendingPathComponent("Resources/Art/IE", isDirectory: true)
    }
}

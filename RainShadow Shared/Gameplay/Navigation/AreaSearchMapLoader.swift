import CoreGraphics
import Foundation
import ImageIO

enum AreaSearchMapError: Error, Equatable, CustomStringConvertible {
    case resourceNotFound(name: String)
    case undecodable(name: String)
    case wrongSize(name: String, expected: (columns: Int, rows: Int), found: (Int, Int))

    static func == (lhs: AreaSearchMapError, rhs: AreaSearchMapError) -> Bool {
        lhs.description == rhs.description
    }

    var description: String {
        switch self {
        case .resourceNotFound(let name):
            "Search map '\(name).png' not found"
        case .undecodable(let name):
            "Search map '\(name).png' could not be decoded as an image"
        case .wrongSize(let name, let expected, let found):
            "Search map '\(name).png' is \(found.0)x\(found.1) cells but the area needs "
                + "\(expected.columns)x\(expected.rows)"
        }
    }
}

/// Reads a painted search map into terrain indices.
///
/// The shipped format is an **8-bit greyscale PNG at one pixel per search cell,
/// whose pixel value is the `SearchMapTerrain` raw value**. Infinity Engine
/// areas ship a palettised `SR.BMP` whose palette *index* carries the meaning
/// and whose colours are only there so a human can read it; greyscale keeps that
/// property — the number is the meaning — without depending on how a given
/// encoder or decoder chooses to preserve a palette. The colours from BG's own
/// table are still emitted, as a separate review render under `ArtSource`, which
/// is not shipped and which nothing reads back.
///
/// Indices 0…15 are all nearly black, so a shipped search map looks like an
/// empty image if opened directly. That is expected; grade it with
/// `qa_area_searchmap.py` or look at the review render beside it.
enum AreaSearchMapLoader {
    /// `Resources/Areas/<name>.png`, alongside the `.area.json` that names it.
    static let resourceSubdirectory = AreaCatalogLoader.resourceSubdirectory

    struct Raster: Equatable, Sendable {
        let columns: Int
        let rows: Int
        /// Row-major from the world's **minimum** corner: index 0 is the
        /// bottom-left cell.
        let terrainIndices: [UInt8]
    }

    // MARK: - Decoding

    /// Decode PNG bytes into world-oriented terrain indices.
    ///
    /// PNG rows run top-down and world rows run bottom-up, so the rows are
    /// flipped here rather than at every read site. Getting this backwards is
    /// silent — a vertically mirrored office still has a plausible amount of
    /// floor in it — so `AreaSearchMapTests` pins the orientation with an
    /// asymmetric fixture.
    static func decode(_ data: Data, name: String = "<data>") throws -> Raster {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw AreaSearchMapError.undecodable(name: name)
        }

        let columns = image.width
        let rows = image.height
        var pixels = [UInt8](repeating: 0, count: columns * rows)

        // Redraw into a known 8-bit grey buffer rather than trusting the file's
        // own layout: a PNG may arrive palettised, 16-bit, or with an alpha
        // channel, and every one of those would read as garbage indices.
        guard let context = CGContext(
            data: &pixels,
            width: columns,
            height: rows,
            bitsPerComponent: 8,
            bytesPerRow: columns,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            throw AreaSearchMapError.undecodable(name: name)
        }
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: columns, height: rows))

        // CGContext with a raw buffer writes row 0 at the top of `pixels`, so
        // flip into world order (row 0 = bottom).
        var flipped = [UInt8](repeating: 0, count: columns * rows)
        for row in 0..<rows {
            let sourceStart = (rows - 1 - row) * columns
            let destinationStart = row * columns
            for column in 0..<columns {
                flipped[destinationStart + column] = pixels[sourceStart + column]
            }
        }

        return Raster(columns: columns, rows: rows, terrainIndices: flipped)
    }

    // MARK: - Loading

    static func load(named name: String, bundle: Bundle? = nil) throws -> Raster {
        try decode(resourceData(named: name, bundle: bundle), name: name)
    }

    static func resourceData(named name: String, bundle: Bundle?) throws -> Data {
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
                withExtension: "png",
                subdirectory: resourceSubdirectory
            ) ?? candidate.url(forResource: name, withExtension: "png") {
                return try Data(contentsOf: url)
            }
        }
        let url = AreaCatalogLoader.developmentAreasDirectory
            .appendingPathComponent("\(name).png", isDirectory: false)
        if FileManager.default.fileExists(atPath: url.path) {
            return try Data(contentsOf: url)
        }
        throw AreaSearchMapError.resourceNotFound(name: name)
    }
}

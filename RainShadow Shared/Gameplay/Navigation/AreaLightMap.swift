import CoreGraphics
import Foundation
import ImageIO

/// One RGB sample from a night light map, in 0...1 linear-ish channel space.
///
/// SpriteKit is not imported here: the navigation target has to stay UI-free,
/// and the scene layer turns this into a tint.
struct AreaLightSample: Equatable, Sendable {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat

    static let identity = AreaLightSample(red: 1, green: 1, blue: 1)

    var luminance: CGFloat {
        0.2126 * red + 0.7152 * green + 0.0722 * blue
    }
}

/// Night light map (IE `LM.BMP`) and optional height map (`HT.BMP`) at search-map
/// resolution: one pixel per 16×12 cell.
struct AreaLightMap: Equatable, Sendable {
    let columns: Int
    let rows: Int
    /// Row-major from the world's minimum corner, matching `AreaSearchMapLoader`.
    let samples: [AreaLightSample]

    func sample(
        at point: CGPoint,
        origin: CGPoint,
        cellSize: CGSize
    ) -> AreaLightSample {
        guard columns > 0, rows > 0, !samples.isEmpty else { return .identity }
        let u = (point.x - origin.x) / cellSize.width - 0.5
        let v = (point.y - origin.y) / cellSize.height - 0.5
        let x0 = Int(floor(u))
        let y0 = Int(floor(v))
        let tx = u - CGFloat(x0)
        let ty = v - CGFloat(y0)
        let a = pixel(column: x0, row: y0)
        let b = pixel(column: x0 + 1, row: y0)
        let c = pixel(column: x0, row: y0 + 1)
        let d = pixel(column: x0 + 1, row: y0 + 1)
        return AreaLightSample(
            red: bilinear(a.red, b.red, c.red, d.red, tx, ty),
            green: bilinear(a.green, b.green, c.green, d.green, tx, ty),
            blue: bilinear(a.blue, b.blue, c.blue, d.blue, tx, ty)
        )
    }

    private func pixel(column: Int, row: Int) -> AreaLightSample {
        let c = min(max(column, 0), columns - 1)
        let r = min(max(row, 0), rows - 1)
        return samples[r * columns + c]
    }

    private func bilinear(
        _ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat,
        _ tx: CGFloat, _ ty: CGFloat
    ) -> CGFloat {
        let top = a * (1 - tx) + b * tx
        let bottom = c * (1 - tx) + d * tx
        return top * (1 - ty) + bottom * ty
    }
}

enum AreaLightMapLoader {
    static func load(named name: String, bundle: Bundle? = nil) throws -> AreaLightMap {
        try decode(AreaSearchMapLoader.resourceData(named: name, bundle: bundle), name: name)
    }

    /// Best-effort load so a missing night map leaves actors on the scene grade.
    static func loadIfPresent(named name: String, bundle: Bundle? = nil) -> AreaLightMap? {
        (try? load(named: name, bundle: bundle))
    }

    static func decode(_ data: Data, name: String = "<data>") throws -> AreaLightMap {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw AreaSearchMapError.undecodable(name: name)
        }
        let columns = image.width
        let rows = image.height
        var pixels = [UInt8](repeating: 0, count: columns * rows * 4)
        guard let context = CGContext(
            data: &pixels,
            width: columns,
            height: rows,
            bitsPerComponent: 8,
            bytesPerRow: columns * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            throw AreaSearchMapError.undecodable(name: name)
        }
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: columns, height: rows))

        var samples = [AreaLightSample](repeating: .identity, count: columns * rows)
        for row in 0..<rows {
            let srcRow = rows - 1 - row
            for column in 0..<columns {
                let i = (srcRow * columns + column) * 4
                samples[row * columns + column] = AreaLightSample(
                    red: CGFloat(pixels[i]) / 255,
                    green: CGFloat(pixels[i + 1]) / 255,
                    blue: CGFloat(pixels[i + 2]) / 255
                )
            }
        }
        return AreaLightMap(columns: columns, rows: rows, samples: samples)
    }
}

/// Greyscale height map. Pixel 128 is "floor"; the runtime offsets the sprite
/// inside its foot circle, not the feet themselves.
enum AreaHeightMap {
    /// World-unit vertical offset for a standing sprite. Zero at mid-grey.
    static func offset(
        from raster: AreaSearchMapLoader.Raster,
        at point: CGPoint,
        origin: CGPoint,
        cellSize: CGSize,
        maximum: CGFloat = 6
    ) -> CGFloat {
        let column = min(
            max(Int(floor((point.x - origin.x) / cellSize.width)), 0),
            raster.columns - 1
        )
        let row = min(
            max(Int(floor((point.y - origin.y) / cellSize.height)), 0),
            raster.rows - 1
        )
        let value = CGFloat(raster.terrainIndices[row * raster.columns + column])
        return ((value / 255) - 0.5) * 2 * maximum
    }

    static func loadIfPresent(named name: String, bundle: Bundle? = nil) -> AreaSearchMapLoader.Raster? {
        try? AreaSearchMapLoader.load(named: name, bundle: bundle)
    }
}

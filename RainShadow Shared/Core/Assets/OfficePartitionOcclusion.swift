import CoreGraphics
import Foundation
import SpriteKit

/// Suite-plate partition occlusion: the frosted glass is baked into
/// `office_suite_plate`, but actors live in `depthWorldRoot` and would always
/// paint over that glass. Punch the glass out of the plate and redraw it as
/// depth-sorted slices so Lila can pass behind the panels.
///
/// `office_partition_wall_cutaway` only keeps the hinge-side run (latch glass is
/// stripped), so occlusion uses the full partition wall with the painted door
/// aperture cleared by screen-x columns.
@MainActor
enum OfficePartitionOcclusion {
    private static var cachedDoorClearedWallImage: CGImage?
    private static var cachedWallTexture: SKTexture?
    private static var cachedPunchedSuitePlate: SKTexture?

    /// Full partition wall with the painted door band cleared (transparent).
    static func wallTextureWithDoorCleared() -> SKTexture? {
        if let cachedWallTexture { return cachedWallTexture }
        guard let image = wallImageWithDoorCleared() else {
            return GameArt.texture(named: "office_partition_wall_cutaway")
                ?? GameArt.texture(named: "office_partition_wall")
        }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .linear
        cachedWallTexture = texture
        return texture
    }

    /// Suite plate with frosted partition glass removed so wall slices can occlude.
    ///
    /// Punch with the *full* wall (door columns included). Punching with the
    /// door-cleared mask left baked suite-plate frost in the aperture, so Lila
    /// still read as walking through glass even when slices were open.
    static func suitePlatePunchingPartition() -> SKTexture? {
        if let cachedPunchedSuitePlate { return cachedPunchedSuitePlate }
        guard let plate = GameArt.standaloneCGImage(named: "office_suite_plate") else {
            return nil
        }
        guard let mask = GameArt.standaloneCGImage(named: "office_partition_wall") else {
            let texture = SKTexture(cgImage: plate)
            texture.filteringMode = .linear
            cachedPunchedSuitePlate = texture
            return texture
        }

        let width = plate.width
        let height = plate.height
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return GameArt.texture(named: "office_suite_plate")
        }

        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.draw(plate, in: rect)
        context.setBlendMode(.destinationOut)
        context.draw(mask, in: rect)
        // Also clear the padded door columns — baked plate frost can extend past
        // the wall mask alpha and still paint over aperture walkers.
        context.setBlendMode(.copy)
        context.setFillColor(red: 0, green: 0, blue: 0, alpha: 0)
        let (x0, x1) = doorApertureImageXRange()
        let lo = max(0, x0)
        let hi = min(width - 1, x1)
        if lo <= hi {
            context.clear(CGRect(x: lo, y: 0, width: hi - lo + 1, height: height))
        }
        guard let punched = context.makeImage() else {
            return GameArt.texture(named: "office_suite_plate")
        }
        let texture = SKTexture(cgImage: punched)
        texture.filteringMode = .linear
        cachedPunchedSuitePlate = texture
        return texture
    }

    private static func wallImageWithDoorCleared() -> CGImage? {
        if let cachedDoorClearedWallImage { return cachedDoorClearedWallImage }
        guard let wall = GameArt.standaloneCGImage(named: "office_partition_wall"),
              let cleared = clearingDoorAperture(in: wall) else {
            return nil
        }
        cachedDoorClearedWallImage = cleared
        return cleared
    }

    /// Clears vertical screen columns spanning the painted door aperture.
    /// Uses CG clear (no CPU buffer flip) so the mask stays aligned with the plate.
    private static func clearingDoorAperture(in wall: CGImage) -> CGImage? {
        let width = wall.width
        let height = wall.height
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.draw(wall, in: rect)

        let (x0, x1) = doorApertureImageXRange()
        let lo = max(0, x0)
        let hi = min(width - 1, x1)
        if lo <= hi {
            context.clear(CGRect(
                x: lo,
                y: 0,
                width: hi - lo + 1,
                height: height
            ))
        }

        return context.makeImage()
    }

    /// Inclusive plate-X bounds of the cleared door (with coat pad).
    static var doorApertureMinImageX: CGFloat {
        CGFloat(doorApertureImageXRange().0)
    }

    static var doorApertureMaxImageX: CGFloat {
        CGFloat(doorApertureImageXRange().1)
    }

    /// Image-space X span of the painted door at the partition face/back.
    private static func doorApertureImageXRange() -> (Int, Int) {
        let arch = OfficeNavigationLayout.Architecture.self
        let door0 = arch.partitionDoorB0
        let door1 = arch.partitionDoorB1
        let aSamples: [CGFloat] = [
            arch.partitionLineA - 0.02,
            arch.partitionLineA,
            arch.partitionLineA + arch.partitionThicknessA * 0.5,
            arch.partitionLineA + arch.partitionThicknessA,
            arch.partitionLineA + arch.partitionThicknessA + 0.02
        ]
        var xs: [CGFloat] = []
        var b = door0
        while b <= door1 + 0.0001 {
            for a in aSamples {
                xs.append(imageX(a: a, b: b))
            }
            b += 0.002
        }
        guard let minX = xs.min(), let maxX = xs.max() else {
            return (0, -1)
        }
        // Pad both sides so adjacent frost slices cannot depth-sort over a
        // walker whose feet are already in the clear reveal. Hinge pad covers
        // the SW coat trailing into the hinge pane; tip pad covers the lead.
        return (Int(floor(minX)) - 120, Int(ceil(maxX)) + 160)
    }

    /// Plate X for plan (a, b). Matches `office_room_plan.plan` X.
    private static func imageX(a: CGFloat, b: CGFloat) -> CGFloat {
        let arch = OfficeNavigationLayout.Architecture.self
        return arch.rearCorner.x + a * arch.axisNW.dx + b * arch.axisNE.dx
    }
}

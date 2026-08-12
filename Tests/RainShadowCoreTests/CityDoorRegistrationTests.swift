import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import RainShadowCore

/// City facades ship with an empty doorway aperture and the closed leaf ships as a
/// separate prop. These hold the two together: a leaf's painted threshold must land
/// on its facade's measured aperture, and the portal you click must cover the leaf
/// you can see. Both used to be hand-authored offsets, and both had drifted — leaves
/// sat on roofs and out on open pavement, and Sable Row's apartment door covered 28%
/// of its own portal.
struct CityDoorRegistrationTests {

    // MARK: - Shipped texture measurement

    /// Opaque bounds of a shipped texture, in canvas pixels (origin top-left).
    struct MeasuredTexture {
        let canvas: CGSize
        let x: ClosedRange<CGFloat>
        let y: ClosedRange<CGFloat>
    }

    static let propsRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("RainShadow Shared/Resources/Art/Props/CityDistrict/V2", isDirectory: true)

    static func measure(_ textureName: String) -> MeasuredTexture? {
        let url = propsRoot.appendingPathComponent("\(textureName).png")
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = pixels.withUnsafeMutableBytes({ bytes in
            CGContext(
                data: bytes.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        }) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width, maxX = -1, minY = height, maxY = -1
        for y in 0..<height {
            for x in 0..<width where pixels[(y * width + x) * 4 + 3] > 28 {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }
        guard maxX >= 0 else { return nil }
        return MeasuredTexture(
            canvas: CGSize(width: width, height: height),
            // Upper bounds are exclusive edges: the far side of the last opaque pixel.
            x: CGFloat(minX)...CGFloat(maxX + 1),
            y: CGFloat(minY)...CGFloat(maxY + 1)
        )
    }

    // MARK: - Pairing

    static let leafTextures = CityDistrictLayout.aperturesByLeafTexture

    /// The facade a leaf belongs to, found in the same district. Leaf names extend
    /// their building's (`city_door_voss_stoop_garage` → `city_building_voss_stoop`),
    /// so the longest matching building stem wins.
    static func building(
        for leaf: CityDistrictDefinition.VisualSprite,
        in district: CityDistrictDefinition
    ) -> CityDistrictDefinition.VisualSprite? {
        let stem = leaf.textureName.replacingOccurrences(of: "city_door_", with: "")
        return district.visualSprites
            .filter { $0.textureName.hasPrefix("city_building_") }
            .filter {
                let base = $0.textureName.replacingOccurrences(of: "city_building_", with: "")
                return stem == base || stem.hasPrefix(base + "_")
            }
            .max { $0.textureName.count < $1.textureName.count }
    }

    static func paintedRect(
        of sprite: CityDistrictDefinition.VisualSprite,
        measured: MeasuredTexture
    ) -> CGRect {
        CityDistrictLayout.paintedRect(
            of: sprite, canvas: measured.canvas, contentX: measured.x, contentY: measured.y
        )
    }

    static var allLeaves: [(CityDistrictID, CityDistrictDefinition, CityDistrictDefinition.VisualSprite)] {
        CityDistrictID.allCases.flatMap { id -> [(CityDistrictID, CityDistrictDefinition, CityDistrictDefinition.VisualSprite)] in
            let district = CityDistrictCatalog.definition(for: id)
            return district.visualSprites
                .filter { $0.textureName.hasPrefix("city_door_") }
                .map { (id, district, $0) }
        }
    }

    // MARK: - Tests

    @Test func everyShippedLeafIsPlacedAndEveryPlacedLeafIsShipped() {
        let placed = Set(Self.allLeaves.map { $0.2.textureName })
        #expect(placed == Set(Self.leafTextures.keys), "Leaf registry and catalog disagree")
        #expect(placed.count == 24)
    }

    /// The derivation rests on the canvases `process_city_districts_v02.py` fits to,
    /// and on leaves being bottom-aligned with a 4 px margin. If a re-export changes
    /// either, every leaf silently shifts, so pin it here.
    @Test func shippedCanvasesMatchTheDerivationContract() {
        for (_, district, leaf) in Self.allLeaves {
            guard let measured = Self.measure(leaf.textureName) else {
                Issue.record("Missing shipped texture \(leaf.textureName)"); continue
            }
            #expect(measured.canvas == CityDistrictLayout.doorCanvas, "\(leaf.textureName) canvas")
            let footInset = measured.canvas.height - measured.y.upperBound
            #expect(
                abs(footInset - CityDistrictLayout.doorCanvasFootInset) <= 1,
                "\(leaf.textureName) sits \(footInset) px above its canvas bottom, not \(CityDistrictLayout.doorCanvasFootInset)"
            )
            guard let facade = Self.building(for: leaf, in: district),
                  let facadeArt = Self.measure(facade.textureName) else { continue }
            #expect(facadeArt.canvas == CityDistrictLayout.buildingCanvas, "\(facade.textureName) canvas")
        }
    }

    /// The invariant the whole change exists to hold: a leaf's painted threshold sits
    /// on the aperture measured for it, in world space.
    @Test func everyLeafThresholdLandsOnItsMeasuredAperture() {
        for (id, district, leaf) in Self.allLeaves {
            guard let aperture = Self.leafTextures[leaf.textureName] else {
                Issue.record("No aperture recorded for \(leaf.textureName)"); continue
            }
            guard let facade = Self.building(for: leaf, in: district) else {
                Issue.record("\(leaf.textureName) has no facade in \(id)"); continue
            }
            guard let measured = Self.measure(leaf.textureName) else { continue }

            let target = CityDistrictLayout.aperturePoint(of: aperture, on: facade)
            let foot = CityDistrictLayout.worldPoint(
                canvasPixel: CGPoint(
                    x: (measured.x.lowerBound + measured.x.upperBound) / 2,
                    y: measured.y.upperBound
                ),
                canvas: measured.canvas,
                sprite: leaf
            )
            // Tolerance is one texture pixel of leaf art (~0.3 world units).
            #expect(
                abs(foot.x - target.x) <= 1.5 && abs(foot.y - target.y) <= 1.5,
                "\(id) \(leaf.textureName) foot \(foot) is off its aperture \(target)"
            )
        }
    }

    /// Catches the failure that started this: a leaf adrift on the pavement or up on
    /// a roof. A door belongs inside the facade it opens.
    @Test func everyLeafSitsWithinItsFacade() {
        for (id, district, leaf) in Self.allLeaves {
            guard let facade = Self.building(for: leaf, in: district),
                  let leafArt = Self.measure(leaf.textureName),
                  let facadeArt = Self.measure(facade.textureName) else { continue }
            let leafRect = Self.paintedRect(of: leaf, measured: leafArt)
            let facadeRect = Self.paintedRect(of: facade, measured: facadeArt)
            #expect(
                facadeRect.insetBy(dx: -2, dy: -2).contains(leafRect),
                "\(id) \(leaf.textureName) \(leafRect) is not inside \(facade.textureName) \(facadeRect)"
            )
        }
    }

    /// Apertures are read off the 512x640 facade canvas; a value outside it means a
    /// measurement was recorded against the wrong image.
    @Test func everyApertureLiesOnTheFacadeCanvas() {
        let canvas = CityDistrictLayout.buildingCanvas
        for (name, aperture) in CityDistrictLayout.aperturesByLeafTexture {
            #expect((0...canvas.width).contains(aperture.centreX), "\(name) centreX")
            #expect((0...canvas.height).contains(aperture.thresholdY), "\(name) thresholdY")
            #expect(aperture.leafHeight > 0, "\(name) leafHeight")
        }
    }

    /// A portal has to be clickable where its door is painted. Sable Row's covered
    /// 28% of `city_door_voss_stoop`, and the uncovered part sat inside a blocking
    /// obstacle, so clicking the visible apartment door did nothing at all.
    @Test func everyPortalHitAreaCoversItsDoorLeaf() {
        for id in CityDistrictID.allCases {
            let district = CityDistrictCatalog.definition(for: id)
            for portal in district.portals {
                let covered = district.visualSprites
                    .filter { $0.textureName.hasPrefix("city_door_") }
                    .compactMap { leaf -> CGFloat? in
                        guard let art = Self.measure(leaf.textureName) else { return nil }
                        let rect = Self.paintedRect(of: leaf, measured: art)
                        let overlap = rect.intersection(portal.hitArea)
                        guard !overlap.isNull, rect.width > 0, rect.height > 0 else { return nil }
                        return (overlap.width * overlap.height) / (rect.width * rect.height)
                    }
                    .max() ?? 0
                #expect(
                    covered >= 0.9,
                    "\(id) portal \(portal.id) covers only \(Int(covered * 100))% of its nearest door leaf"
                )
            }
        }
    }

    /// Approaches belong on the street the door faces, never on the door sprite —
    /// the sprite is inside the building's obstacle, which is what made every city
    /// approach unreachable once before. Keep them out of the clickable door too, so
    /// the walk-up target stays orderable.
    @Test func portalApproachesStayOffTheDoorArt() {
        for id in CityDistrictID.allCases {
            let district = CityDistrictCatalog.definition(for: id)
            for portal in district.portals {
                #expect(
                    !portal.hitArea.contains(portal.approachPoint),
                    "\(id) portal \(portal.id) approach \(portal.approachPoint) sits inside its own hit area"
                )
                #expect(
                    !district.obstacles.contains { $0.contains(portal.approachPoint) },
                    "\(id) portal \(portal.id) approach \(portal.approachPoint) is inside an obstacle"
                )
            }
        }
    }

    /// Leaves must sort in front of the facade they sit in.
    @Test func everyLeafDrawsAheadOfItsFacade() {
        let artHeight = CityDistrictDefinition.worldArtSize.height
        func depth(_ s: CityDistrictDefinition.VisualSprite) -> CGFloat {
            (artHeight - s.groundPoint.y) * 0.5 + s.depthBias
        }
        for (id, district, leaf) in Self.allLeaves {
            guard let facade = Self.building(for: leaf, in: district) else { continue }
            #expect(
                depth(leaf) > depth(facade),
                "\(id) \(leaf.textureName) sorts behind \(facade.textureName)"
            )
        }
    }
}

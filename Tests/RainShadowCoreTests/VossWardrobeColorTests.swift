import Foundation
import Testing
@testable import RainShadowCore

/// Holds the runtime indexed-colour contract. The material byte plane and the
/// character palette are the authority. Voss resolves that plane directly for
/// linear display; legacy filtered RGBA atlases remain compatibility payloads.
struct VossWardrobeColorTests {
    @Test func bundledCurrentManifestWinsOverTheDevelopmentFallback() throws {
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("VossBundleTest-\(UUID().uuidString).bundle")
        defer { try? FileManager.default.removeItem(at: temporary) }
        let contents = temporary.appendingPathComponent("Contents")
        let resources = contents.appendingPathComponent("Resources/Voss")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        let info: [String: Any] = ["CFBundleIdentifier": "test.voss.current-manifest",
                                  "CFBundlePackageType": "BNDL", "CFBundleVersion": "1"]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: contents.appendingPathComponent("Info.plist"))
        let original = VossAtlasTestAssets.indexedManifestURL()
        var manifest = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: original)) as? [String: Any])
        var colors = try #require(manifest["colors"] as? [Int])
        colors[0] = 1 // Different from checkout V22 and replacement V12.
        manifest["colors"] = colors
        try JSONSerialization.data(withJSONObject: manifest)
            .write(to: resources.appendingPathComponent(IEIndexedSprite.manifestFileName))
        try FileManager.default.copyItem(
            at: original.deletingLastPathComponent().appendingPathComponent("avatar-v02.indices"),
            to: resources.appendingPathComponent("avatar-v02.indices"))
        let bundle = try #require(Bundle(url: temporary))
        let loaded = try IEIndexedSprite.load(character: "Voss", bundle: bundle, tables: IEGradientTables.load())
        #expect(loaded.colors[0] == 1)
        #expect(loaded.frames.count == 248)
    }

    private var repoRoot: URL { VossAtlasTestAssets.repoRoot }

    private var atlasRoot: URL { VossAtlasTestAssets.atlasRoot }

    @Test func vossBundleHasTheExactInventoryAndCharacterPalette() throws {
        let voss = try loadSprite("Voss")

        #expect(voss.character == "voss")
        #expect(voss.frames.count == 248)
        #expect(voss.frames.count(where: \.isEmpty) == 24)
        let expected: [UInt32]
        if ["meshy_sep05_v03", "meshy_sep06_v04", "meshy_sep06_pose_v05"].contains(VossAtlasTestAssets.assetAuthority) {
            expected = [23, 5, 138, 161, 138, 5, 22]
        } else if ["replacement_v13", "replacement_v14"].contains(VossAtlasTestAssets.assetAuthority) {
            expected = [138, 107, 144, 159, 138, 100, 22]
        } else if VossAtlasTestAssets.usesProjectionRegistration {
            expected = [138, 248, 144, 159, 138, 100, 22]
        } else {
            expected = [138, 171, 198, 84, 160, 237, 48]
        }
        #expect(voss.colors == expected)
        #expect(voss.sourceCanvasSize == .init(width: 512, height: 512))
        let embeddedCandidate = ["meshy_sep06_v04", "meshy_sep06_pose_v05"].contains(VossAtlasTestAssets.assetAuthority)
        let displaySize = embeddedCandidate ? 163.125 : 180.0
        #expect(voss.compatibilityDisplaySize == .init(x: displaySize, y: displaySize))
        #expect(voss.textureFilter == .linear)
        #expect(voss.hasEmbeddedShadow == embeddedCandidate)
        #expect(voss.shadowOwner == (embeddedCandidate ? "embedded palette index 1" : "external ContactShadowNode"))
        try expectExactAtlasInventory(for: voss)
    }

    @Test func lilaBundleHasTheExactIndexedInventoryAndCharacterPalette() throws {
        let lila = try loadSprite("Lila")

        #expect(lila.character == "lila")
        #expect(lila.frames.count == 25)
        #expect(lila.frames.allSatisfy { !$0.isEmpty })
        #expect(lila.colors == [22, 5, 253, 233, 193, 219, 234])
        #expect(lila.sourceCanvasSize == .init(width: 512, height: 512))
        #expect(lila.compatibilityDisplaySize == .init(x: 180, y: 180))
        #expect(lila.textureFilter == .linear)
        #expect(lila.hasEmbeddedShadow == false)
        #expect(lila.shadowOwner == "external ContactShadowNode")
        try expectExactAtlasInventory(for: lila)
    }

    @Test func materialPlanesUseAuthoredSlotsAndDeclaredShadowOwnership() throws {
        let voss = try loadSprite("Voss")
        let lila = try loadSprite("Lila")

        let vossSlots = expectAllowedIndices(in: voss)
        #expect(vossSlots == Set(IEMaterialSlot.allCases))

        let lilaSlots = expectAllowedIndices(in: lila)
        #expect(lilaSlots == Set([
            IEMaterialSlot.metal,
            .major,
            .skin,
            .leather,
            .armor,
            .hair
        ]))
    }

    @Test(arguments: ["Voss", "Lila"])
    func everyFrameResolvesNativePixelsForDirectLinearDisplay(character: String) throws {
        let sprite = try loadSprite(character)
        #expect(sprite.textureFilter == .linear)

        for frame in sprite.frames {
            #expect(sprite.texturePixelSize(for: frame) == frame.nativeSize)
            let actual = sprite.rgba(for: frame)
            let colors = sprite.resolvedColors(for: frame)
            let expected = colors.flatMap { [$0.r, $0.g, $0.b, $0.a] }
            #expect(actual == expected, "\(frame.id.atlas)/\(frame.id.name) was prefiltered")
        }
    }

    @Test func everyLilaFrameRoundTripsExactlyToItsCompatibilityAtlasCell() throws {
        try expectAtlasRoundTrip(for: loadSprite("Lila"))
    }

    @Test func changingOneCharacterColourChangesOnlyThatMaterialRun() throws {
        let sprite = try loadSprite("Voss")
        let frame = try #require(sprite.frame(
            atlas: "VossIdle.atlas",
            name: "voss_standing_idle_s_00.png"
        ))
        let originalIndices = frame.indices
        let originalGeometry = (
            size: frame.size,
            trim: frame.trimOriginTopLeft,
            pivot: frame.pivotFromCropBottomLeft
        )

        var alternateColors = sprite.colors
        alternateColors[IEMaterialSlot.armor.rawValue] = 42

        // The contract is about *indices*, so it is asserted on the index plane.
        // Voss is resolved directly at native resolution, so material ownership
        // remains categorical until SpriteKit performs the final linear sample.
        let tables = try IEGradientTables.load()
        let alternatePalette = IEPaperdollColours.setup(colors: alternateColors, tables: tables)
        let baseline = sprite.resolvedColors(for: frame)

        var changedArmorPixels = 0
        var changedOutsideArmor = 0
        var changedAlpha = 0
        for pixel in frame.indices.indices {
            let index = frame.indices[pixel]
            let after = alternatePalette[Int(index)]
            if baseline[pixel] != after {
                if materialSlot(for: index) == .armor {
                    changedArmorPixels += 1
                } else {
                    changedOutsideArmor += 1
                }
            }
            if baseline[pixel].a != after.a {
                changedAlpha += 1
            }
        }

        #expect(changedArmorPixels > 0)
        #expect(changedOutsideArmor == 0)
        #expect(changedAlpha == 0)

        // And the render still responds to it, with the silhouette untouched.
        let renderedBefore = sprite.rgba(for: frame)
        let renderedAfter = sprite.rgba(for: frame, colors: alternateColors)
        #expect(renderedBefore != renderedAfter, "recolouring must reach the render")
        let alphaBefore = stride(from: 3, to: renderedBefore.count, by: 4).map { renderedBefore[$0] }
        let alphaAfter = stride(from: 3, to: renderedAfter.count, by: 4).map { renderedAfter[$0] }
        #expect(alphaBefore == alphaAfter, "recolouring must not move the silhouette")

        #expect(frame.indices == originalIndices)
        #expect(frame.size == originalGeometry.size)
        #expect(frame.trimOriginTopLeft == originalGeometry.trim)
        #expect(frame.pivotFromCropBottomLeft == originalGeometry.pivot)
    }

    @Test func allRearAndNorthSeatFramesExcludeFrontGarmentIndices() throws {
        let sprite = try loadSprite("Voss")
        let rear = rearStandingAndWalkIDs()
        let northSeat = northSeatIDs()
        #expect(rear.count == 36)
        #expect(northSeat.count == 32)

        for id in rear + northSeat {
            let frame = try #require(sprite.frame(atlas: id.atlas, name: id.name))
            let body = frame.indices.filter { materialSlot(for: $0) != nil }
            let slots = Set(body.compactMap(materialSlot(for:)))

            // MINOR is Voss's shirt and MAJOR is his tie. A direct absence is
            // stronger than the retired nearest-RGB fraction and cannot be
            // fooled by changing the character palette.
            #expect(!slots.contains(.minor), "\(id.atlas)/\(id.name) contains shirt indices")
            #expect(!slots.contains(.major), "\(id.atlas)/\(id.name) contains tie indices")

            // Rear hands can remain visible; a front face cannot. This is the
            // old 3% topology ceiling, now measured exactly by material slot.
            let skinPixels = body.count { materialSlot(for: $0) == .skin }
            let skinShare = Double(skinPixels) / Double(max(body.count, 1))
            #expect(
                skinShare <= 0.03,
                "\(id.atlas)/\(id.name) assigns \(skinShare) of its body to skin"
            )
        }
    }

    private func loadSprite(_ character: String) throws -> IEIndexedSprite {
        try VossAtlasTestAssets.indexedSprite(character: character)
    }

    private func atlasRoot(for sprite: IEIndexedSprite) -> URL {
        sprite.character.lowercased() == "voss" ? atlasRoot :
            repoRoot.appendingPathComponent("RainShadow Shared/Resources/Art/Atlases")
    }

    private func expectExactAtlasInventory(for sprite: IEIndexedSprite) throws {
        let expectedByAtlas = Dictionary(grouping: sprite.frames, by: { $0.id.atlas })
        for (atlas, frames) in expectedByAtlas {
            let directory = atlasRoot(for: sprite).appendingPathComponent(atlas, isDirectory: true)
            let actual = try Set(FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension == "png" }.map(\.lastPathComponent))
            let expected = Set(frames.map { $0.id.name })
            #expect(actual == expected, "\(atlas) does not exactly match the indexed inventory")
        }
    }

    @discardableResult
    private func expectAllowedIndices(in sprite: IEIndexedSprite) -> Set<IEMaterialSlot> {
        var usedSlots: Set<IEMaterialSlot> = []
        var invalid: Set<UInt8> = []
        var shadowPixels = 0
        for frame in sprite.frames {
            // The stored plane is native since bundle v02; `size` is what it
            // is rendered to.
            #expect(frame.indices.count == frame.nativeSize.width * frame.nativeSize.height)
            for index in frame.indices {
                if index == UInt8(IEPalette.colorKeyIndex) { continue }
                if index == UInt8(IEPalette.shadowIndex) {
                    shadowPixels += 1
                    continue
                }
                guard let slot = materialSlot(for: index) else {
                    invalid.insert(index)
                    continue
                }
                usedSlots.insert(slot)
            }
        }
        #expect(invalid.isEmpty, "\(sprite.character) has invalid body indices \(invalid.sorted())")
        #expect((shadowPixels > 0) == sprite.hasEmbeddedShadow,
                "\(sprite.character)'s index-1 pixels must match declared shadow ownership")
        return usedSlots
    }

    private func expectAtlasRoundTrip(for sprite: IEIndexedSprite) throws {
        for frame in sprite.frames {
            let url = atlasRoot(for: sprite)
                .appendingPathComponent(frame.id.atlas, isDirectory: true)
                .appendingPathComponent(frame.id.name, isDirectory: false)
            let compatibility = try VossAtlasFrame(contentsOf: url)
            #expect(compatibility.width == sprite.sourceCanvasSize.width)
            #expect(compatibility.height == sprite.sourceCanvasSize.height)

            var expected = [UInt8](repeating: 0, count: compatibility.pixels.count)
            // `IEIndexedSprite.render` rather than `sprite.rgba(for:)`.
            // Presentation is native everywhere now, so `rgba(for:)` returns the
            // unscaled index plane and no longer describes this surface. The
            // prefiltered bake still has to be reproducible byte for byte, and
            // this is the check that says so — it just names the offline
            // reference explicitly instead of reaching it through a runtime call
            // that has moved on.
            let resolved = IEIndexedSprite.render(
                indices: frame.indices,
                nativeSize: frame.nativeSize,
                textureSize: frame.size,
                palette: sprite.palette
            )
            if !frame.isEmpty {
                for row in 0..<frame.size.height {
                    let sourceStart = row * frame.size.width * 4
                    let destinationStart = (
                        (frame.trimOriginTopLeft.height + row) * compatibility.width
                            + frame.trimOriginTopLeft.width
                    ) * 4
                    expected.replaceSubrange(
                        destinationStart..<(destinationStart + frame.size.width * 4),
                        with: resolved[sourceStart..<(sourceStart + frame.size.width * 4)]
                    )
                }
            }

            var actual = compatibility.pixels
            // The compatibility atlas retains the four alpha-1 packing
            // sentinels. They are deliberately not part of the indexed model.
            for (x, y) in [
                (0, 0),
                (compatibility.width - 1, 0),
                (0, compatibility.height - 1),
                (compatibility.width - 1, compatibility.height - 1)
            ] {
                let start = (y * compatibility.width + x) * 4
                actual.replaceSubrange(start..<(start + 4), with: [0, 0, 0, 0])
            }

            let firstMismatch = actual.indices.first { actual[$0] != expected[$0] }
            #expect(
                firstMismatch == nil,
                "\(frame.id.atlas)/\(frame.id.name) differs at RGBA byte \(String(describing: firstMismatch))"
            )
        }
    }

    private func materialSlot(for index: UInt8) -> IEMaterialSlot? {
        guard (0x04..<0x58).contains(index) else { return nil }
        return IEMaterialSlot(rawValue: (Int(index) - 0x04) / IEPaperdollColours.numCols)
    }

    private func rearStandingAndWalkIDs() -> [IEIndexedSprite.FrameID] {
        ["n", "nnw", "nw"].flatMap { direction in
            (0..<4).map {
                IEIndexedSprite.FrameID(
                    atlas: "VossIdle.atlas",
                    name: String(format: "voss_standing_idle_%@_%02d.png", direction, $0)
                )
            } + (0..<8).map {
                IEIndexedSprite.FrameID(
                    atlas: "VossWalk.atlas",
                    name: String(format: "voss_walk_%@_%02d.png", direction, $0)
                )
            }
        }
    }

    private func northSeatIDs() -> [IEIndexedSprite.FrameID] {
        [
            ("VossSeatedIdle.atlas", "voss_seated_idle", 8),
            ("VossSeatTransitions.atlas", "voss_stand_up", 12),
            ("VossSeatTransitions.atlas", "voss_sit_down", 12)
        ].flatMap { atlas, stem, count in
            (0..<count).map {
                IEIndexedSprite.FrameID(
                    atlas: atlas,
                    name: String(format: "%@_n_%02d.png", stem, $0)
                )
            }
        }
    }
}

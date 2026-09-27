import CoreGraphics
import CryptoKit
import Foundation
import Testing
@testable import RainShadowCore
@testable import RainShadowPersistence

struct OfficeRestoreTests {
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    @Test func approvedV19PlateAndRegisteredGeometryShipTogether() throws {
        let area = try AreaCatalogLoader.load(HarborpointAreas.office)
        let plate = root.appendingPathComponent("RainShadow Shared/Resources/Art/Areas/DetectiveOffice/office_suite_plate.png")
        let digest = SHA256.hash(data: try Data(contentsOf: plate)).map { String(format: "%02x", $0) }.joined()
        #expect(digest == "bdc057a9aba0bdea898238cd61061a2f7a35970e3f32f4a3319d4469134eb04c")
        #expect(OfficeInteriorScale.sourceArtSize == CGSize(width: 5120, height: 3840))
        #expect(area.worldBounds == OfficeInteriorScale.worldBounds)
        #expect(area.containers.count == 6)
        #expect(area.region(id: "living.bed") != nil)
        #expect(area.doors.isEmpty)
        #expect(area.props.map(\.id) == ["office_v15_desk_cover"])
    }

    @Test func startupAndCityUseOneOfficeWithRegisteredFireSequences() throws {
        let area = try AreaCatalogLoader.load(HarborpointAreas.office)
        let street = try AreaCatalogLoader.load(HarborpointAreas.sableRow)
        let entry = try #require(street.travelRegions.first { $0.travel?.destination == HarborpointAreas.office })
        #expect(entry.travel?.entrance == OfficeAreaAdapter.cityArrivalEntrance)
        #expect(area.entrance(named: OfficeAreaAdapter.cityArrivalEntrance) != nil)
        #expect(area.travelRegions.first?.travel?.destination == street.id)
        #expect(area.animations.count == 3)
        for animation in area.animations {
            let resource = try #require(animation.resourceName)
            let file = root.appendingPathComponent("RainShadow Shared/Resources/Animations/\(resource).animation.json")
            let manifest = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
            let frames = try #require(manifest["frames"] as? [[String: Any]])
            #expect(frames.count == 60)
            #expect(animation.frameRate == 15)
            for frame in frames {
                let name = try #require(frame["texture"] as? String)
                #expect(FileManager.default.fileExists(atPath: file.deletingLastPathComponent().appendingPathComponent(name).path))
            }
        }
    }
    @MainActor @Test func oldOfficeSaveKeepsProgressAndRecoversDroppedItems() throws {
        let name = "RainShadow.OfficeRestore.Tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = SaveStore(defaults: defaults, key: "save", resetsOnLaunch: false)
        var old = SaveSnapshot(hasCompletedOfficeCaseIntro: true, walletPence: 999,
            groundPiles: ["office_suite": [.init(id: "brass_key", quantity: 1, x: -500, y: -500)]])
        old.officeLayoutRevision = 0
        store.save(old)
        let restored = store.load()
        #expect(restored.hasCompletedOfficeCaseIntro && restored.walletPence == 999)
        #expect(restored.officeLayoutRevision == 1)
        let item = try #require(restored.groundPiles["office_suite"]?.first)
        let area = try AreaCatalogLoader.load(HarborpointAreas.office)
        #expect(CGPoint(x: item.x, y: item.y) == area.spawnPoint(entrance: nil))
        #expect(defaults.data(forKey: "save.BeforeOfficeLayoutV19") != nil)
        #expect(store.load().groundPiles == restored.groundPiles)
    }

}

import Foundation
import Testing
@testable import RainShadowCore

/// Ambients as area data.
///
/// Each scene used to open with one hardcoded `RainAudio.loopingAmbience` call.
/// These assert the records say what the scenes used to, because the values are
/// now the only copy — and the office's were wrong when first written.
struct AreaAmbientTests {

    @Test func everyNavigableAreaAuthorsAnAmbientBed() throws {
        for area in try AreaCatalogLoader.load(HarborpointAreas.shippedIDs).allAreas {
            #expect(!area.ambients.isEmpty, "'\(area.id)' plays nothing")
            for ambient in area.ambients {
                #expect(!ambient.assetName.isEmpty, "'\(area.id)' ambient has no asset")
                #expect(
                    (0...1).contains(ambient.volume),
                    "'\(area.id)' ambient volume \(ambient.volume) is out of range"
                )
            }
        }
    }

    /// The office hears rain on its *window*, not the street bed the districts
    /// play. The record said `amb_rain_exterior` at 0.34 because the adapter
    /// copied the city's ambient when the record was first written, while the
    /// scene had always played `amb_rain_window` at 0.27. Pinned so a future
    /// re-export cannot quietly swap the office's audio again.
    @Test func theOfficeHearsItsWindowRatherThanTheStreet() throws {
        let office = try AreaCatalogLoader.load(HarborpointAreas.office)
        let ambient = try #require(office.ambients.first)
        #expect(ambient.assetName == "amb_rain_window")
        #expect(abs(ambient.volume - 0.27) < 0.001)
    }

    @Test func aDistrictHearsTheStreetBed() throws {
        let sableRow = try AreaCatalogLoader.load(HarborpointAreas.sableRow)
        let ambient = try #require(sableRow.ambients.first)
        #expect(ambient.assetName == "amb_rain_exterior")
        #expect(abs(ambient.volume - 0.34) < 0.001)
    }

    /// The establishing shot is louder than play — it is the only thing on
    /// screen. Kept as data even though that scene has no area runtime.
    @Test func theOpeningExteriorIsTheLoudestBed() throws {
        let catalog = try AreaCatalogLoader.load(HarborpointAreas.shippedIDs)
        let exterior = try #require(catalog.area(for: HarborpointAreas.openingExterior))
        let ambient = try #require(exterior.ambients.first)
        #expect(abs(ambient.volume - 0.52) < 0.001)

        let loudestElsewhere = catalog.allAreas
            .filter { $0.id != HarborpointAreas.openingExterior }
            .flatMap(\.ambients)
            .map(\.volume)
            .max() ?? 0
        #expect(ambient.volume > loudestElsewhere)
    }
}

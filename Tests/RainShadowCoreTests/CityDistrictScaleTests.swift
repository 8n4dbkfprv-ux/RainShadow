import CoreGraphics
import Testing
@testable import RainShadowCore

struct CityDistrictScaleTests {
    @Test func standingAdultMatchesOfficeDetective() {
        #expect(CityDistrictLayout.standingAdultBodyHeight == OfficeInteriorScale.standingAdultBodyHeight)
        #expect(
            CityDistrictLayout.standingAdultBodyHeight
                == OfficeInteriorScale.renderedStandingDetectiveBodyHeight
        )
        #expect(OfficeInteriorScale.Band.standingBody.contains(CityDistrictLayout.standingAdultBodyHeight))
    }

    @Test func multiStoryBuildingsAreClearlyTallerThanAdult() {
        let samples: [(String, CGFloat)] = [
            ("city_building_voss_stoop", CityDistrictLayout.SourceContentHeight.buildingVossStoop),
            ("city_building_tenement", CityDistrictLayout.SourceContentHeight.buildingTenement),
            ("city_building_storefront", CityDistrictLayout.SourceContentHeight.buildingStorefront),
            ("city_building_rowhouse", CityDistrictLayout.SourceContentHeight.buildingRowhouse),
            ("city_building_shop", CityDistrictLayout.SourceContentHeight.buildingShop),
            ("city_building_gatehouse", CityDistrictLayout.SourceContentHeight.buildingGatehouse),
            ("city_building_shipping_office", CityDistrictLayout.SourceContentHeight.buildingShippingOffice),
            ("city_building_lila_rooms", CityDistrictLayout.SourceContentHeight.buildingLilaRooms),
            ("city_building_pd_station", CityDistrictLayout.SourceContentHeight.buildingPDStation),
            ("city_building_records_annex", CityDistrictLayout.SourceContentHeight.buildingRecordsAnnex)
        ]
        for (name, height) in samples {
            let multiple = CityDistrictLayout.bodyMultiple(contentHeight: height, textureName: name)
            #expect(multiple != nil, "Missing sprite scale for \(name)")
            if let multiple {
                #expect(
                    CityDistrictLayout.Band.multiStoryBuilding.contains(multiple),
                    "\(name) body× \(multiple) outside multi-story band"
                )
                #expect(multiple > 1.5, "Building \(name) must read taller than the actor")
            }
        }
    }

    @Test func landmarkDoorsClearStandingVoss() {
        let samples: [(String, CGFloat)] = [
            ("city_building_voss_stoop", CityDistrictLayout.SourceDoorLeafHeight.buildingVossStoop),
            ("city_building_tenement", CityDistrictLayout.SourceDoorLeafHeight.buildingTenement),
            ("city_building_storefront", CityDistrictLayout.SourceDoorLeafHeight.buildingStorefront),
            ("city_building_rowhouse", CityDistrictLayout.SourceDoorLeafHeight.buildingRowhouse),
            ("city_building_shop", CityDistrictLayout.SourceDoorLeafHeight.buildingShop),
            ("city_building_gatehouse", CityDistrictLayout.SourceDoorLeafHeight.buildingGatehouse),
            ("city_building_shipping_office", CityDistrictLayout.SourceDoorLeafHeight.buildingShippingOffice),
            ("city_building_lila_rooms", CityDistrictLayout.SourceDoorLeafHeight.buildingLilaRooms),
            ("city_building_pd_station", CityDistrictLayout.SourceDoorLeafHeight.buildingPDStation),
            ("city_building_records_annex", CityDistrictLayout.SourceDoorLeafHeight.buildingRecordsAnnex)
        ]
        for (name, doorLeaf) in samples {
            let multiple = CityDistrictLayout.doorBodyMultiple(doorLeafHeight: doorLeaf, textureName: name)
            #expect(multiple != nil, "Missing scale for door on \(name)")
            if let multiple {
                #expect(
                    CityDistrictLayout.Band.doorLeaf.contains(multiple),
                    "\(name) door body× \(multiple) outside readable door band (must clear Voss)"
                )
                #expect(
                    multiple >= 1.0,
                    "\(name) door \(multiple)× adult is shorter than standing Voss"
                )
            }
        }
    }

    @Test func doorAnchoredScaleHitsTargetMultiple() {
        let scale = CityDistrictLayout.doorAnchoredScale(
            doorLeaf: CityDistrictLayout.SourceDoorLeafHeight.buildingVossStoop
        )
        let multiple = CityDistrictLayout.bodyMultiple(
            contentHeight: CityDistrictLayout.SourceDoorLeafHeight.buildingVossStoop,
            scale: scale
        )
        #expect(abs(multiple - CityDistrictLayout.targetDoorBodyMultiple) < 0.02)
        #expect(abs(scale - CityDistrictLayout.BuildingDisplayScale.vossStoop) < 0.001)
    }

    @Test func carsStayNearAdultBodyHeight() {
        let samples: [(String, CGFloat)] = [
            ("city_prop_car_black", CityDistrictLayout.SourceContentHeight.carBlack),
            ("city_prop_car_olive", CityDistrictLayout.SourceContentHeight.carOlive),
            ("city_prop_car_maroon", CityDistrictLayout.SourceContentHeight.carMaroon)
        ]
        for (name, height) in samples {
            let multiple = CityDistrictLayout.bodyMultiple(contentHeight: height, textureName: name)
            #expect(multiple != nil, "Missing sprite scale for \(name)")
            if let multiple {
                #expect(
                    CityDistrictLayout.Band.car.contains(multiple),
                    "\(name) body× \(multiple) outside car band (must not scale with buildings)"
                )
            }
        }
    }

    @Test func carsAreNotScaledUpWithBuildingFacades() {
        let carScales = CityDistrictLayout.visualSprites
            .filter { $0.textureName.contains("car_") }
            .map(\.scale)
        #expect(!carScales.isEmpty)
        #expect(carScales.allSatisfy { $0 <= 0.30 })
        #expect(carScales.allSatisfy { abs($0 - CityDistrictLayout.PropDisplayScale.car) < 0.001
            || abs($0 - CityDistrictLayout.PropDisplayScale.carSpoke) < 0.001 })
    }

    @Test func streetFurnitureStaysHumanScaleBelowBuildings() {
        let lamp = CityDistrictLayout.bodyMultiple(
            contentHeight: CityDistrictLayout.SourceContentHeight.lamp,
            textureName: "city_prop_lamp"
        )
        let bench = CityDistrictLayout.bodyMultiple(
            contentHeight: CityDistrictLayout.SourceContentHeight.bench,
            textureName: "city_prop_bench"
        )
        let kiosk = CityDistrictLayout.bodyMultiple(
            contentHeight: CityDistrictLayout.SourceContentHeight.kiosk,
            textureName: "city_prop_kiosk"
        )
        #expect(lamp != nil && bench != nil && kiosk != nil)
        if let lamp {
            #expect(CityDistrictLayout.Band.streetLamp.contains(lamp))
        }
        if let bench {
            #expect(CityDistrictLayout.Band.bench.contains(bench))
        }
        if let kiosk {
            #expect(CityDistrictLayout.Band.kiosk.contains(kiosk))
        }

        let building = CityDistrictLayout.bodyMultiple(
            contentHeight: CityDistrictLayout.SourceContentHeight.buildingVossStoop,
            textureName: "city_building_voss_stoop"
        )!
        if let lamp, let bench, let kiosk {
            #expect(lamp < building)
            #expect(bench < building)
            #expect(kiosk < building)
        }
    }

    @Test func displayHeightIsContentTimesSpriteScale() {
        let scale = CityDistrictLayout.representativeScale(forTextureName: "city_prop_car_black")!
        let content = CityDistrictLayout.SourceContentHeight.carBlack
        let display = CityDistrictLayout.displayHeight(contentHeight: content, scale: scale)
        #expect(abs(display - content * scale) < 0.0001)
        #expect(
            abs(
                CityDistrictLayout.bodyMultiple(contentHeight: content, scale: scale)
                    - display / CityDistrictLayout.standingAdultBodyHeight
            ) < 0.0001
        )
    }

    @Test func everyVisualSpriteUsesPositiveHumanScale() {
        for sprite in CityDistrictLayout.visualSprites {
            #expect(sprite.scale > 0)
            #expect(sprite.scale < 4, "Sprite \(sprite.textureName) scale \(sprite.scale) looks like unscaled full-res art")
        }
        let carScales = CityDistrictLayout.visualSprites
            .filter { $0.textureName.contains("car_") }
            .map(\.scale)
        #expect(!carScales.isEmpty)
        #expect(carScales.allSatisfy { $0 <= 0.75 })
        let buildingScales = CityDistrictLayout.visualSprites
            .filter { $0.textureName.hasPrefix("city_building_") }
            .map(\.scale)
        let lampScales = CityDistrictLayout.visualSprites
            .filter { $0.textureName == "city_prop_lamp" }
            .map(\.scale)
        #expect(buildingScales.min()! > lampScales.max()!)
    }

    @Test func doorLeavesTallerThanCarRoofsOnSableRow() {
        let stoopDoor = CityDistrictLayout.doorBodyMultiple(
            doorLeafHeight: CityDistrictLayout.SourceDoorLeafHeight.buildingVossStoop,
            textureName: "city_building_voss_stoop"
        )!
        let car = CityDistrictLayout.bodyMultiple(
            contentHeight: CityDistrictLayout.SourceContentHeight.carBlack,
            textureName: "city_prop_car_black"
        )!
        #expect(stoopDoor > car * 0.95, "Doors should not read shorter than parked car roofs")
    }

    @Test func sharedAdultBodyIsUsedByCityCameraDensity() {
        let fraction = DefaultPlayZoom.standingBodyFraction(
            bodyHeight: OfficeInteriorScale.renderedStandingDetectiveBodyHeight,
            visibleWorldHeight: CityDistrictLayout.cameraVisibleHeight
        )
        #expect(DefaultPlayZoom.bodyToVisibleHeightBand.contains(fraction))
        #expect(abs(fraction - DefaultPlayZoom.targetBodyToVisibleHeight) < 0.0001)
    }

    @Test func actICatalogCoversCaseTravelDistricts() {
        let ids = Set(CityDistrictID.allCases)
        #expect(ids.contains(.sableRow))
        #expect(ids.contains(.wharfLadder))
        #expect(ids.contains(.riverside))
        #expect(ids.contains(.harborpointPD))
        #expect(ids.contains(.lilaStreet))
        #expect(ids.contains(.civicRecords))
        #expect(CityDistrictCatalog.sableRow.portals.contains(where: {
            if case .office = $0.destination { return true }
            return false
        }))
    }

    @Test func allDistrictsUseDoorAnchoredBuildingScales() {
        for id in CityDistrictID.allCases {
            let buildings = CityDistrictCatalog.definition(for: id).visualSprites
                .filter { $0.textureName.hasPrefix("city_building_") }
            #expect(!buildings.isEmpty, "District \(id) missing buildings")
            for sprite in buildings {
                #expect(sprite.scale >= 0.5, "\(sprite.textureName) in \(id) scale too small (\(sprite.scale))")
                #expect(sprite.scale <= 2.5, "\(sprite.textureName) in \(id) scale too large (\(sprite.scale))")
            }
        }
    }
}

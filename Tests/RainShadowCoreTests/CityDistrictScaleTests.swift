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
        let terraceMultiple = CityDistrictLayout.TerraceSpec.worldHeight
            / CityDistrictLayout.standingAdultBodyHeight
        #expect(CityDistrictLayout.Band.multiStoryBuilding.contains(terraceMultiple))
        // Infinity Engine city block: ~3 storeys + roof ≈ 6 standing adults.
        #expect((5.0...7.0).contains(terraceMultiple), "Sable terrace \(terraceMultiple)× adult is not IE city scale")
        #expect(terraceMultiple > 1.5)

        let samples: [(String, CGFloat)] = [
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
        let sableLeaves: [(String, CGFloat)] = [
            ("city_door_voss_stoop", CityDistrictLayout.SourceSeparateDoorLeafHeight.standard),
            ("city_door_tenement", CityDistrictLayout.SourceSeparateDoorLeafHeight.standard),
            ("city_door_storefront", CityDistrictLayout.SourceSeparateDoorLeafHeight.standard),
            ("city_door_rowhouse", CityDistrictLayout.SourceSeparateDoorLeafHeight.standard),
            ("city_door_shop", CityDistrictLayout.SourceSeparateDoorLeafHeight.standard),
            ("city_door_gatehouse", CityDistrictLayout.SourceSeparateDoorLeafHeight.standard)
        ]
        for (name, doorLeaf) in sableLeaves {
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

        let cubeSamples: [(String, CGFloat)] = [
            ("city_building_shipping_office", CityDistrictLayout.SourceDoorLeafHeight.buildingShippingOffice),
            ("city_building_lila_rooms", CityDistrictLayout.SourceDoorLeafHeight.buildingLilaRooms),
            ("city_building_pd_station", CityDistrictLayout.SourceDoorLeafHeight.buildingPDStation),
            ("city_building_records_annex", CityDistrictLayout.SourceDoorLeafHeight.buildingRecordsAnnex)
        ]
        for (name, doorLeaf) in cubeSamples {
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
        let carScales = CityDistrictCatalog.wharfLadder.visualSprites
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
            scale: CityDistrictLayout.PropDisplayScale.bench
        )
        let kiosk = CityDistrictLayout.bodyMultiple(
            contentHeight: CityDistrictLayout.SourceContentHeight.kiosk,
            textureName: "city_prop_kiosk"
        )
        #expect(lamp != nil && kiosk != nil)
        if let lamp {
            #expect(CityDistrictLayout.Band.streetLamp.contains(lamp))
        }
        #expect(CityDistrictLayout.Band.bench.contains(bench))
        if let kiosk {
            #expect(CityDistrictLayout.Band.kiosk.contains(kiosk))
        }

        let building = CityDistrictLayout.TerraceSpec.worldHeight
            / CityDistrictLayout.standingAdultBodyHeight
        if let lamp, let kiosk {
            #expect(lamp < building)
            #expect(bench < building)
            #expect(kiosk < building)
        }
    }

    @Test func displayHeightIsContentTimesSpriteScale() {
        let scale = CityDistrictLayout.anyDistrictScale(forTextureName: "city_prop_car_black")!
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
        let carScales = CityDistrictCatalog.wharfLadder.visualSprites
            .filter { $0.textureName.contains("car_") }
            .map(\.scale)
        #expect(!carScales.isEmpty)
        #expect(carScales.allSatisfy { $0 <= 0.75 })
        let facadeScales = CityDistrictCatalog.wharfLadder.visualSprites
            .filter { $0.textureName.hasPrefix("city_building_") }
            .map(\.scale)
        let lampScales = CityDistrictCatalog.wharfLadder.visualSprites
            .filter { $0.textureName == "city_prop_lamp" }
            .map(\.scale)
        #expect(!facadeScales.isEmpty)
        #expect(!lampScales.isEmpty)
        #expect(facadeScales.min()! > lampScales.max()!)
    }

    @Test func doorLeavesTallerThanCarRoofsOnSableRow() {
        let stoopDoor = CityDistrictLayout.doorBodyMultiple(
            doorLeafHeight: CityDistrictLayout.SourceSeparateDoorLeafHeight.standard,
            textureName: "city_door_voss_stoop"
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
            let sprites = CityDistrictCatalog.definition(for: id).visualSprites
            let lots = sprites.filter { $0.textureName.hasPrefix("city_sable_lot_") }
            if !lots.isEmpty {
                #expect(lots.count >= 12, "\(id) baked plate is missing lot crops")
                continue
            }
            let terraces = sprites.filter { $0.textureName.hasPrefix("city_terrace_") }
            if !terraces.isEmpty {
                for sprite in terraces {
                    guard let worldSize = sprite.worldSize else {
                        Issue.record("\(sprite.textureName) in \(id) is missing worldSize")
                        continue
                    }
                    let multiple = worldSize.height / CityDistrictLayout.standingAdultBodyHeight
                    #expect(
                        CityDistrictLayout.Band.multiStoryBuilding.contains(multiple),
                        "\(sprite.textureName) in \(id) world height \(multiple)× adult"
                    )
                }
                continue
            }
            let buildings = sprites.filter { $0.textureName.hasPrefix("city_building_") }
            #expect(!buildings.isEmpty, "District \(id) missing buildings")
            for sprite in buildings {
                #expect(sprite.scale >= 0.5, "\(sprite.textureName) in \(id) scale too small (\(sprite.scale))")
                #expect(sprite.scale <= 2.5, "\(sprite.textureName) in \(id) scale too large (\(sprite.scale))")
            }
        }
    }
}

import CoreGraphics
import Testing
@testable import RainShadowCore

struct CityDistrictScaleTests {
    @Test func standingAdultMatchesOfficeDetective() {
        #expect(CityDistrictLayout.standingAdultBodyHeight == OfficeInteriorScale.detectiveBodyHeight)
        #expect(CityDistrictLayout.standingAdultBodyHeight == OfficeInteriorScale.standingAdultBodyHeight)
        #expect(OfficeInteriorScale.Band.standingBody.contains(CityDistrictLayout.standingAdultBodyHeight))
    }

    @Test func multiStoryBuildingsAreClearlyTallerThanAdult() {
        let samples: [(String, CGFloat)] = [
            ("city_building_central", CityDistrictLayout.SourceContentHeight.buildingCentral),
            ("city_building_mid", CityDistrictLayout.SourceContentHeight.buildingMid),
            ("city_building_se", CityDistrictLayout.SourceContentHeight.buildingSE),
            ("city_building_nw", CityDistrictLayout.SourceContentHeight.buildingNW),
            ("city_building_ne", CityDistrictLayout.SourceContentHeight.buildingNE),
            ("city_building_sw", CityDistrictLayout.SourceContentHeight.buildingSW)
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

    @Test func carsStayNearAdultBodyHeight() {
        let samples: [(String, CGFloat)] = [
            ("city_car_black", CityDistrictLayout.SourceContentHeight.carBlack),
            ("city_car_olive", CityDistrictLayout.SourceContentHeight.carOlive),
            ("city_car_maroon", CityDistrictLayout.SourceContentHeight.carMaroon)
        ]
        for (name, height) in samples {
            let multiple = CityDistrictLayout.bodyMultiple(contentHeight: height, textureName: name)
            #expect(multiple != nil, "Missing sprite scale for \(name)")
            if let multiple {
                #expect(
                    CityDistrictLayout.Band.car.contains(multiple),
                    "\(name) body× \(multiple) outside car band (must not be multi-story tall)"
                )
            }
        }
    }

    @Test func streetFurnitureStaysHumanScaleBelowBuildings() {
        let lamp = CityDistrictLayout.bodyMultiple(
            contentHeight: CityDistrictLayout.SourceContentHeight.lamp,
            textureName: "city_lamp"
        )
        let bench = CityDistrictLayout.bodyMultiple(
            contentHeight: CityDistrictLayout.SourceContentHeight.bench,
            textureName: "city_bench"
        )
        let kiosk = CityDistrictLayout.bodyMultiple(
            contentHeight: CityDistrictLayout.SourceContentHeight.kiosk,
            textureName: "city_kiosk"
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
            contentHeight: CityDistrictLayout.SourceContentHeight.buildingCentral,
            textureName: "city_building_central"
        )!
        if let lamp, let bench, let kiosk {
            #expect(lamp < building)
            #expect(bench < building)
            #expect(kiosk < building)
        }
    }

    @Test func displayHeightIsContentTimesSpriteScale() {
        let scale = CityDistrictLayout.representativeScale(forTextureName: "city_car_black")!
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
        // Cars must stay on the compact human-scale path (not building-sized).
        let carScales = CityDistrictLayout.visualSprites
            .filter { $0.textureName.hasPrefix("city_car_") }
            .map(\.scale)
        #expect(!carScales.isEmpty)
        #expect(carScales.allSatisfy { $0 <= 0.75 })
        // Multi-story blocks use higher scales than street furniture.
        let buildingScales = CityDistrictLayout.visualSprites
            .filter { $0.textureName.hasPrefix("city_building_") }
            .map(\.scale)
        let lampScales = CityDistrictLayout.visualSprites
            .filter { $0.textureName == "city_lamp" }
            .map(\.scale)
        #expect(buildingScales.min()! > lampScales.max()!)
    }

    @Test func sharedAdultBodyIsUsedByCityCameraDensity() {
        let fraction = DefaultPlayZoom.standingBodyFraction(
            bodyHeight: CityDistrictLayout.standingAdultBodyHeight,
            visibleWorldHeight: CityDistrictLayout.cameraVisibleHeight
        )
        #expect(DefaultPlayZoom.bodyToVisibleHeightBand.contains(fraction))
    }
}

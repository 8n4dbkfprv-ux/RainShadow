import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore

struct HotspotHoverHighlightTests {
    private let desk = HotspotHoverHighlight.Target(
        id: "office.desk",
        hitArea: CGRect(x: 100, y: 200, width: 200, height: 150)
    )
    private let window = HotspotHoverHighlight.Target(
        id: "office.window",
        hitArea: CGRect(x: 0, y: 400, width: 80, height: 120)
    )
    /// Nested inside desk; first-list-wins matches click hit-test order.
    private let phone = HotspotHoverHighlight.Target(
        id: "office.phone",
        hitArea: CGRect(x: 250, y: 280, width: 60, height: 40)
    )

    private var targets: [HotspotHoverHighlight.Target] {
        [desk, window, phone]
    }

    @Test func selectedIDMatchesFirstHitAreaContainingPoint() {
        #expect(
            HotspotHoverHighlight.selectedID(at: CGPoint(x: 150, y: 250), among: targets)
                == "office.desk"
        )
        #expect(
            HotspotHoverHighlight.selectedID(at: CGPoint(x: 40, y: 450), among: targets)
                == "office.window"
        )
        #expect(
            HotspotHoverHighlight.selectedID(at: CGPoint(x: 280, y: 300), among: targets)
                == "office.desk"
        )
        #expect(
            HotspotHoverHighlight.selectedID(at: CGPoint(x: 280, y: 300), among: [phone, desk])
                == "office.phone"
        )
        #expect(
            HotspotHoverHighlight.selectedID(at: CGPoint(x: 10, y: 10), among: targets) == nil
        )
    }

    @Test func presentationAppliesBGBlueSpriteTintWhenSelected() {
        let presentation = HotspotHoverHighlight.presentation(
            at: CGPoint(x: 150, y: 250),
            among: targets,
            worldInteractionBlocked: false
        )
        #expect(presentation.isVisible)
        #expect(presentation.hotspotID == "office.desk")
        #expect(presentation.usesSpriteTint)
        #expect(presentation.isBGBlueSpriteTint)
        #expect(HotspotHoverHighlight.blueRedBand.contains(presentation.red))
        #expect(HotspotHoverHighlight.blueGreenBand.contains(presentation.green))
        #expect(HotspotHoverHighlight.blueBlueBand.contains(presentation.blue))
        #expect(
            HotspotHoverHighlight.selectedBlendBand.contains(presentation.colorBlendFactor)
        )
        #expect(
            presentation.colorBlendFactor == HotspotHoverHighlight.selectedColorBlendFactor
        )
        // Stronger than the prior subtle 0.42 wash.
        #expect(
            HotspotHoverHighlight.selectedColorBlendFactor
                > HotspotHoverHighlight.legacySubtleColorBlendFactor
        )
        #expect(presentation.colorBlendFactor > 0.42)
    }

    @Test func presentationClearsSpriteTintOnMiss() {
        let presentation = HotspotHoverHighlight.presentation(
            at: CGPoint(x: -50, y: -50),
            among: targets,
            worldInteractionBlocked: false
        )
        #expect(!presentation.isVisible)
        #expect(presentation.hotspotID == nil)
        #expect(presentation.isClearedSpriteTint)
        #expect(!presentation.isBGBlueSpriteTint)
        #expect(
            presentation.colorBlendFactor == HotspotHoverHighlight.clearedColorBlendFactor
        )
    }

    @Test func presentationClearsWhenWorldInteractionBlocked() {
        let presentation = HotspotHoverHighlight.presentation(
            at: CGPoint(x: 150, y: 250),
            among: targets,
            worldInteractionBlocked: true
        )
        #expect(!presentation.isVisible)
        #expect(presentation.hotspotID == nil)
        #expect(presentation.isClearedSpriteTint)
        #expect(
            presentation.colorBlendFactor == HotspotHoverHighlight.clearedColorBlendFactor
        )

        let noPoint = HotspotHoverHighlight.presentation(
            at: nil,
            among: targets,
            worldInteractionBlocked: false
        )
        #expect(noPoint.isClearedSpriteTint)
    }

    @Test func updateWithHitThenMissTogglesSpriteTint() {
        // Drive the real presentation entry the scene calls for pointer-move.
        let hit = HotspotHoverHighlight.presentation(
            at: CGPoint(x: 40, y: 450),
            among: targets,
            worldInteractionBlocked: false
        )
        #expect(hit.isVisible)
        #expect(hit.hotspotID == "office.window")
        #expect(hit.isBGBlueSpriteTint)
        #expect(hit.usesSpriteTint)

        let miss = HotspotHoverHighlight.presentation(
            at: CGPoint(x: 999, y: 999),
            among: targets,
            worldInteractionBlocked: false
        )
        #expect(!miss.isVisible)
        #expect(miss.isClearedSpriteTint)
        #expect(miss.colorBlendFactor == 0)
    }

    @Test func officeAuthoredHotspotsSelectViaShippedLayoutRects() {
        let targets = HotspotHoverHighlight.targets(
            from: OfficeNavigationLayout.authoredHotspots.map {
                (id: $0.id, hitArea: OfficeInteriorScale.mapRect($0.hitArea))
            }
        )
        #expect(targets.count >= 4)
        guard let desk = targets.first(where: { $0.id == "office.desk" }),
              let window = targets.first(where: { $0.id == "office.window" }),
              let door = targets.first(where: { $0.id == "office.door" }) else {
            #expect(Bool(false), "Expected desk/window/door hotspots")
            return
        }

        let deskMid = CGPoint(x: desk.hitArea.midX, y: desk.hitArea.midY)
        #expect(HotspotHoverHighlight.selectedID(at: deskMid, among: targets) == "office.desk")

        let windowMid = CGPoint(x: window.hitArea.midX, y: window.hitArea.midY)
        #expect(HotspotHoverHighlight.selectedID(at: windowMid, among: targets) == "office.window")

        let doorMid = CGPoint(x: door.hitArea.midX, y: door.hitArea.midY)
        #expect(HotspotHoverHighlight.selectedID(at: doorMid, among: targets) == "office.door")

        for point in [deskMid, windowMid, doorMid] {
            let shown = HotspotHoverHighlight.presentation(
                at: point,
                among: targets,
                worldInteractionBlocked: false
            )
            #expect(shown.isVisible)
            #expect(shown.isBGBlueSpriteTint)
            let blocked = HotspotHoverHighlight.presentation(
                at: point,
                among: targets,
                worldInteractionBlocked: true
            )
            #expect(blocked.isClearedSpriteTint)
        }
    }

    @Test func sceneWiresSpriteTintNotOutlineChrome() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sceneURL = root.appendingPathComponent(
            "RainShadow Shared/Scenes/DetectiveOffice/DetectiveOfficeScene.swift"
        )
        let source = try String(contentsOf: sceneURL, encoding: .utf8)
        #expect(source.contains("updateHotspotHoverHighlight(at:"))
        #expect(source.contains("HotspotHoverHighlight.presentation("))
        #expect(source.contains("clearHotspotHoverHighlight()"))
        #expect(source.contains("hotspotHoverSprites"))
        #expect(source.contains("registerHoverSprite"))
        #expect(source.contains("colorBlendFactor"))
        #expect(source.contains("selectedColorBlendFactor")
            || source.contains("presentation.colorBlendFactor"))
        // Rect outline is no longer the primary hover chrome.
        #expect(!source.contains("hotspotHoverOutline"))
        #expect(!source.contains("configureHotspotHoverOutline"))
    }

    @Test func windowIsNotBoundToRadiatorAndDeskMapsToDeskProps() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sceneURL = root.appendingPathComponent(
            "RainShadow Shared/Scenes/DetectiveOffice/DetectiveOfficeScene.swift"
        )
        let source = try String(contentsOf: sceneURL, encoding: .utf8)

        // Must not register any hover sprites for office.window (no window-frame prop).
        #expect(!source.contains("registerHoverSprite(radiator, for: \"office.window\")"))
        #expect(!source.contains("for: \"office.window\""))

        // Desk still registers desk ensemble props.
        #expect(source.contains("registerHoverSprite(deskBare, for: \"office.desk\")")
            || source.contains("for: \"office.desk\""))
        #expect(source.contains("registerHoverSprite(chair, for: \"office.desk\")")
            || source.contains("office_desk_chair"))
        #expect(source.contains("office_desk_bare"))
    }
}

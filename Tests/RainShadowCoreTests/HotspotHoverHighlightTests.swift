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
        // Phone rect sits inside desk; list order prefers desk (same as scene click).
        #expect(
            HotspotHoverHighlight.selectedID(at: CGPoint(x: 280, y: 300), among: targets)
                == "office.desk"
        )
        // Phone-first list selects phone for the same point.
        #expect(
            HotspotHoverHighlight.selectedID(at: CGPoint(x: 280, y: 300), among: [phone, desk])
                == "office.phone"
        )
        #expect(
            HotspotHoverHighlight.selectedID(at: CGPoint(x: 10, y: 10), among: targets) == nil
        )
    }

    @Test func presentationShowsBGBlueWhenHotspotSelected() {
        let presentation = HotspotHoverHighlight.presentation(
            at: CGPoint(x: 150, y: 250),
            among: targets,
            worldInteractionBlocked: false
        )
        #expect(presentation.isVisible)
        #expect(presentation.hotspotID == "office.desk")
        #expect(presentation.hitArea == desk.hitArea)
        #expect(presentation.isBGBlueStroke)
        #expect(HotspotHoverHighlight.blueRedBand.contains(presentation.red))
        #expect(HotspotHoverHighlight.blueGreenBand.contains(presentation.green))
        #expect(HotspotHoverHighlight.blueBlueBand.contains(presentation.blue))
        #expect(presentation.alpha > 0.5)
    }

    @Test func presentationClearsOnMiss() {
        let presentation = HotspotHoverHighlight.presentation(
            at: CGPoint(x: -50, y: -50),
            among: targets,
            worldInteractionBlocked: false
        )
        #expect(!presentation.isVisible)
        #expect(presentation.hotspotID == nil)
        #expect(presentation.hitArea == nil)
        #expect(!presentation.isBGBlueStroke)
    }

    @Test func presentationClearsWhenWorldInteractionBlocked() {
        let blockedCases = [true]
        for blocked in blockedCases {
            let presentation = HotspotHoverHighlight.presentation(
                at: CGPoint(x: 150, y: 250),
                among: targets,
                worldInteractionBlocked: blocked
            )
            #expect(!presentation.isVisible)
            #expect(presentation.hotspotID == nil)
            #expect(presentation == .hidden || !presentation.isVisible)
        }

        // Nil point also clears.
        let noPoint = HotspotHoverHighlight.presentation(
            at: nil,
            among: targets,
            worldInteractionBlocked: false
        )
        #expect(!noPoint.isVisible)
    }

    @Test func updateWithHitThenMissTogglesVisibility() {
        // Drive the real presentation entry the scene calls for pointer-move.
        let hit = HotspotHoverHighlight.presentation(
            at: CGPoint(x: 40, y: 450),
            among: targets,
            worldInteractionBlocked: false
        )
        #expect(hit.isVisible)
        #expect(hit.hotspotID == "office.window")
        #expect(hit.isBGBlueStroke)

        let miss = HotspotHoverHighlight.presentation(
            at: CGPoint(x: 999, y: 999),
            among: targets,
            worldInteractionBlocked: false
        )
        #expect(!miss.isVisible)
        #expect(miss.hotspotID == nil)
    }

    @Test func officeAuthoredHotspotsSelectViaShippedLayoutRects() {
        // Real office hotspots (mapped). Prefer non-overlapping samples: window + door
        // sit outside the large desk rect; desk mid selects desk; blocked UI clears all.
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
            #expect(shown.isBGBlueStroke)
            let blocked = HotspotHoverHighlight.presentation(
                at: point,
                among: targets,
                worldInteractionBlocked: true
            )
            #expect(!blocked.isVisible)
        }
    }

    @Test func sceneWiresPointerMoveToShippedHoverEntry() throws {
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
        #expect(source.contains("hotspotHoverOutline"))
        #expect(source.contains("HotspotHoverHighlight.outlineBlue")
            || source.contains("HotspotHoverHighlight.outlineRed"))
    }
}

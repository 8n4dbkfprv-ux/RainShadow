import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore

struct HighlightOutlineTests {
    private func square(
        id: String,
        kind: HighlightableKind,
        origin: CGPoint,
        size: CGFloat = 40,
        isLocked: Bool = false,
        isEmpty: Bool = false,
        isSecretFound: Bool = false,
        trapIsVisible: Bool = false,
        suppressedByClosedDoor: Bool = false
    ) -> HighlightableObject {
        HighlightableObject(
            id: id,
            kind: kind,
            polygon: HighlightGeometry.quad(
                from: CGRect(x: origin.x, y: origin.y, width: size, height: size)
            ),
            isLocked: isLocked,
            isEmpty: isEmpty,
            isSecretFound: isSecretFound,
            trapIsVisible: trapIsVisible,
            suppressedByClosedDoor: suppressedByClosedDoor
        )
    }

    @Test func pointInPolygonIncludesInteriorAndEdge() {
        let polygon = HighlightGeometry.quad(from: CGRect(x: 10, y: 10, width: 20, height: 20))
        #expect(HighlightGeometry.contains(CGPoint(x: 20, y: 20), polygon: polygon))
        #expect(HighlightGeometry.contains(CGPoint(x: 10, y: 10), polygon: polygon))
        #expect(!HighlightGeometry.contains(CGPoint(x: 5, y: 20), polygon: polygon))
    }

    @Test func doorBeatsInfoPointAndContainerOverridesInfo() {
        let door = square(id: "door", kind: .door, origin: CGPoint(x: 0, y: 0))
        let info = square(id: "info", kind: .infoPoint, origin: CGPoint(x: 20, y: 20))
        let container = square(id: "chest", kind: .container, origin: CGPoint(x: 20, y: 20))
        let overlap = CGPoint(x: 25, y: 25)

        #expect(HighlightableObject.hit(at: overlap, among: [info, door])?.id == "door")
        #expect(HighlightableObject.hit(at: overlap, among: [info, container])?.id == "chest")
        #expect(HighlightableObject.hit(at: overlap, among: [container, door])?.id == "door")
    }

    @Test func hoverUsesCyanUnlessTrapOrTargetableLock() {
        let door = square(id: "door", kind: .door, origin: .zero, isLocked: true)
        let inside = CGPoint(x: 10, y: 10)

        let hover = HighlightResolver.resolve(
            hoverPoint: inside,
            revealAll: false,
            worldInteractionBlocked: false,
            objects: [door]
        )
        #expect(hover.hoverID == "door")
        #expect(hover.outlines == [ObjectHighlight(id: "door", color: HighlightPalette.hoverDoor)])

        let targetable = HighlightResolver.resolve(
            hoverPoint: inside,
            revealAll: false,
            worldInteractionBlocked: false,
            targetModeActive: true,
            objects: [door]
        )
        #expect(targetable.outlines.first?.color == HighlightPalette.hoverTargetable)

        let trapDoor = square(id: "door", kind: .door, origin: .zero, trapIsVisible: true)
        let trap = HighlightResolver.resolve(
            hoverPoint: nil,
            revealAll: false,
            worldInteractionBlocked: false,
            objects: [trapDoor]
        )
        #expect(trap.outlines == [ObjectHighlight(id: "door", color: HighlightPalette.trap)])
    }

    @Test func revealAllUsesAltDoorAndContainerColoursAndSkipsInfoPoints() {
        let door = square(id: "door", kind: .door, origin: .zero)
        let chest = square(id: "chest", kind: .container, origin: CGPoint(x: 50, y: 0))
        let empty = square(id: "empty", kind: .container, origin: CGPoint(x: 100, y: 0), isEmpty: true)
        let window = square(id: "window", kind: .infoPoint, origin: CGPoint(x: 150, y: 0))
        let hidden = square(id: "behind", kind: .container, origin: CGPoint(x: 200, y: 0), suppressedByClosedDoor: true)

        let result = HighlightResolver.resolve(
            hoverPoint: nil,
            revealAll: true,
            worldInteractionBlocked: false,
            objects: [door, chest, empty, window, hidden]
        )
        let byID = Dictionary(uniqueKeysWithValues: result.outlines.map { ($0.id, $0.color) })
        #expect(byID["door"] == HighlightPalette.altDoor)
        #expect(byID["chest"] == HighlightPalette.altContainer)
        #expect(byID["empty"] == HighlightPalette.emptyContainer)
        #expect(byID["window"] == nil)
        #expect(byID["behind"] == nil)
        #expect(result.hoverID == nil)
    }

    @Test func blockedWorldInteractionDrawsNothing() {
        let door = square(id: "door", kind: .door, origin: .zero)
        let result = HighlightResolver.resolve(
            hoverPoint: CGPoint(x: 10, y: 10),
            revealAll: true,
            worldInteractionBlocked: true,
            objects: [door]
        )
        #expect(result == .empty)
    }

    @Test func hoverColourWinsOverRevealAllOnTheSameObject() {
        let door = square(id: "door", kind: .door, origin: .zero)
        let result = HighlightResolver.resolve(
            hoverPoint: CGPoint(x: 10, y: 10),
            revealAll: true,
            worldInteractionBlocked: false,
            objects: [door]
        )
        #expect(result.outlines == [ObjectHighlight(id: "door", color: HighlightPalette.hoverDoor)])
    }

    @Test func secretFoundDoorStaysMagentaWithoutHover() {
        let door = square(id: "secret", kind: .door, origin: .zero, isSecretFound: true)
        let result = HighlightResolver.resolve(
            hoverPoint: nil,
            revealAll: false,
            worldInteractionBlocked: false,
            objects: [door]
        )
        #expect(result.outlines == [ObjectHighlight(id: "secret", color: HighlightPalette.hiddenDoor)])
    }

    @Test func authoredOfficeHotspotsRemainSelectable() {
        let objects = OfficeHighlightOutlines.objects()
        let expected = ["office.desk", "office.window", "office.door", "office.phone", "office.files"]
        for id in expected {
            guard let object = objects.first(where: { $0.id == id }) else {
                #expect(Bool(false), "Missing office outline \(id)")
                continue
            }
            let box = object.boundingBox
            #expect(object.contains(CGPoint(x: box.midX, y: box.midY)))
        }
        #expect(objects.first { $0.id == "office.door" }?.kind == .door)
        #expect(objects.first { $0.id == "office.desk" }?.kind == .container)
        #expect(objects.first { $0.id == "office.files" }?.kind == .container)
        #expect(objects.first { $0.id == "office.window" }?.kind == .infoPoint)
    }

    @Test func cityPortalsAreDoorQuadsKeyedByCatalogID() {
        for district in CityDistrictID.allCases {
            let portals = CityDistrictCatalog.definition(for: district).portals
            let objects = CityHighlightOutlines.objects(for: district)
            #expect(objects.count == portals.count)
            for portal in portals {
                guard let object = objects.first(where: { $0.id == portal.id }) else {
                    #expect(Bool(false), "Missing city outline \(portal.id)")
                    continue
                }
                #expect(object.kind == .door)
                #expect(object.contains(CGPoint(x: portal.hitArea.midX, y: portal.hitArea.midY)))
            }
        }
    }

    /// A ring that equals its own bounding rectangle is a box, which is the
    /// thing the Infinity Engine never draws: every ARE outline is a vertex ring
    /// traced over the painted object. Vertex *count* is not the invariant — an
    /// edge-on door leaf is honestly four points — so test the shape instead.
    private func isAxisAlignedBox(_ polygon: [CGPoint], tolerance: CGFloat = 0.5) -> Bool {
        guard polygon.count == 4 else { return false }
        let xs = Set(polygon.map { ($0.x / tolerance).rounded() })
        let ys = Set(polygon.map { ($0.y / tolerance).rounded() })
        return xs.count == 2 && ys.count == 2
    }

    @Test func officeOutlinesAreTracedSilhouettesNotBoxes() {
        for object in OfficeHighlightOutlines.objects() {
            #expect(
                !isAxisAlignedBox(object.polygon),
                "\(object.id) is still an axis-aligned box"
            )
        }
    }

    @Test func cityPortalOutlinesAreTracedLeavesNotApertureQuads() {
        for district in CityDistrictID.allCases {
            for object in CityHighlightOutlines.objects(for: district) {
                #expect(
                    !isAxisAlignedBox(object.closedPolygon),
                    "\(object.id) closed ring is still an axis-aligned box"
                )
                if let open = object.openPolygon {
                    #expect(
                        !isAxisAlignedBox(open),
                        "\(object.id) open ring is still an axis-aligned box"
                    )
                }
            }
        }
    }

    /// GemRB `DoorTrigger::StatePolygon`: `open ? openTrigger : closedTrigger`,
    /// falling back to the closed ring for a door whose art gives no open one.
    @Test func doorOutlineFollowsOpenState() {
        let closed = HighlightGeometry.quad(from: CGRect(x: 0, y: 0, width: 10, height: 10))
        let open: [CGPoint] = [
            CGPoint(x: 20, y: 0), CGPoint(x: 24, y: 2), CGPoint(x: 24, y: 12)
        ]
        var door = HighlightableObject(id: "d", kind: .door, polygon: closed, openPolygon: open)
        #expect(door.polygon == closed)
        door.isOpen = true
        #expect(door.polygon == open)

        var plain = HighlightableObject(id: "p", kind: .door, polygon: closed)
        plain.isOpen = true
        #expect(plain.polygon == closed)
    }

    @Test func officeSceneUsesRuntimePolygonOutlinesNotHoverPNGs() throws {
        let source = try officeSceneSource()
        #expect(source.contains("OfficeHighlightOutlines.objects()"))
        #expect(source.contains("installHighlightables"))
        #expect(source.contains("setHighlightHoverPoint"))
        #expect(source.contains("configureHotspots"))
        #expect(source.contains("buildRegisteredDoorVisual()"))
        #expect(source.contains("if let travel = hotspot.travel"))
        #expect(source.contains("to: travel.destination"))
        #expect(source.contains("entrance: travel.entrance"))
        #expect(!source.contains("to: HarborpointAreas.sableRow"))
        #expect(!source.contains("GameArt.standaloneTexture(named: \"\\(assetName)_hover\")"))
        #expect(!source.contains("entry.sprite.texture = entry.hoverTexture"))
        #expect(!source.contains("addBakedWindowHoverOverlay()"))
        #expect(!source.contains("hoverBindings"))
        for forbidden in [
            "SKShader", ".shader =", "colorBlendFactor", "hoverEdgeTextureCache",
            "makeCyanEdge", "cyanEdgeTexture", "applyHoverWashAndEdgeOverlay"
        ] {
            #expect(!source.contains(forbidden), "Runtime hover rendering remains: \(forbidden)")
        }
    }

    @Test func citySceneWiresCatalogOutlines() throws {
        let url = repositoryRoot().appendingPathComponent(
            "RainShadow Shared/Scenes/CityDistrict/CityDistrictScene.swift"
        )
        let source = try String(contentsOf: url, encoding: .utf8)
        #expect(source.contains("CityHighlightOutlines.objects(for: districtID)"))
        #expect(source.contains("installHighlightables"))
        #expect(source.contains("setHighlightHoverPoint"))
    }

    @Test func registeredDoorNormalizesBeforeAssigningTextureSize() throws {
        let source = try officeSceneSource()
        #expect(source.contains(
            """
            officeDoor.setScale(1)
                    officeDoor.texture = texture
                    officeDoor.size = texture.size()
            """
        ))
        #expect(source.contains("officeDoor.setScale(registration.scale)"))
    }

    private func officeSceneSource() throws -> String {
        let url = repositoryRoot().appendingPathComponent(
            "RainShadow Shared/Scenes/DetectiveOffice/DetectiveOfficeScene.swift"
        )
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

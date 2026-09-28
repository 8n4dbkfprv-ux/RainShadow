import CoreGraphics
import Foundation

/// One loaded area, and the state that belongs to it rather than to the scene
/// drawing it — GemRB's `Map` in the shape RainShadow currently needs it.
///
/// Authored records remain immutable; current door flags and spent proximity
/// events belong to this visit and are copied to the session's saved ARE state.
@MainActor
final class AreaRuntime {
    let area: AreaDefinition
    let navigation: NavigationMap
    private(set) var openDoorIDs: Set<String>
    private(set) var currentWallPolygons: [AreaWallPolygon] = []
    let movement: MovementOrderQueue
    private(set) var objectState: AreaObjectState

    init(area: AreaDefinition, navigation: NavigationMap, playerActorID: String, objectState: AreaObjectState = .init()) {
        self.objectState = objectState
        self.openDoorIDs = Set(area.doors.filter { objectState.isOpen($0) }.map(\.id))
        for door in area.doors {
            if let open = objectState.doorOpen[door.id] { navigation.setDoor(door.id, open: open) }
        }
        self.area = area
        self.navigation = navigation
        self.movement = MovementOrderQueue(navigation: navigation, actorID: playerActorID)
        refreshDoorWalls()
    }

    /// Build the navigation map from the area itself. Used by areas whose
    /// geometry is fully expressed in the record.
    convenience init(area: AreaDefinition, playerActorID: String, objectState: AreaObjectState = .init()) {
        self.init(
            area: area,
            navigation: area.makeNavigationMap(),
            playerActorID: playerActorID,
            objectState: objectState
        )
    }

    /// GemRB DoorTrigger::SetState selects open/closed walls, then invalidates
    /// the stencil. Navigation retains its existing door-cell implementation.
    @discardableResult
    func setDoor(_ id: String, open: Bool) -> AreaDoorChange {
        guard let door = area.doors.first(where: { $0.id == id }) else { return .init(accepted: false) }
        let change = navigation.changeDoor(door, open: open)
        guard change.accepted else { return change }
        objectState.setDoor(door, open: open)
        if open { openDoorIDs.insert(id) } else { openDoorIDs.remove(id) }
        refreshDoorWalls()
        return change
    }

    func recordSpentTriggers(_ ids: Set<String>) {
        objectState.spentTriggers = ids
    }

    private func refreshDoorWalls() {
        currentWallPolygons = area.wallPolygons + area.doors.flatMap { door in
            guard let tiles = door.backgroundTiles else { return [AreaWallPolygon]() }
            return openDoorIDs.contains(door.id) ? tiles.openWalls : tiles.closedWalls
        }
    }

    func makeWallStencil() -> AreaWallStencil.Mask {
        var current = area
        current.wallPolygons = currentWallPolygons
        return current.makeWallStencil()
    }

    // MARK: - Area queries

    var id: AreaID { area.id }

    /// Where an arrival by this entrance name lands.
    func spawnPoint(entrance: String?) -> CGPoint? {
        area.spawnPoint(entrance: entrance)
    }

    /// The region under a world point, topmost-authored first.
    func region(at point: CGPoint, of kind: AreaRegionKind? = nil) -> AreaRegion? {
        area.region(at: point, of: kind)
    }

    /// What the ground sounds like here, from the search map's terrain.
    func surface(at point: CGPoint) -> SearchMapSurface? {
        navigation.searchMap.surface(at: point)
    }

    /// The area's script, if it names one.
    var script: AreaScript? { AreaScriptCatalog.script(for: area) }

    /// Whether an actor standing here is behind covering scenery.
    func isCovered(_ point: CGPoint) -> Bool {
        currentWallPolygons.contains { $0.coversActor(at: point, height: OfficeInteriorScale.renderedStandingDetectiveBodyHeight) }
    }

    /// Union of every covering outline, in world space.
    ///
    /// One path rather than one per polygon: the overlay that redraws scenery
    /// over actors is a single masked copy of the plate, so a room with a dozen
    /// walls still costs one extra draw.
    var coverPath: CGPath? {
        let covering = currentWallPolygons.filter(\.coversActors)
        guard !covering.isEmpty else { return nil }
        let path = CGMutablePath()
        for wall in covering {
            guard let first = wall.polygon.first else { continue }
            path.move(to: first.cgPoint)
            for vertex in wall.polygon.dropFirst() {
                path.addLine(to: vertex.cgPoint)
            }
            path.closeSubpath()
        }
        return path.isEmpty ? nil : path
    }

    func hidesWallLockedAnimation(at point: CGPoint) -> Bool {
        isCovered(point)
    }
}

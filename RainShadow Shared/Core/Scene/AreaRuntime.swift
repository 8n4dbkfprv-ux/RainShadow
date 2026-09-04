import CoreGraphics
import Foundation

/// One loaded area, and the state that belongs to it rather than to the scene
/// drawing it — GemRB's `Map` in the shape RainShadow currently needs it.
///
/// Today that is the area record, the navigation map built for it, and the
/// player's waypoint queue. Every scene needs exactly those three and they are
/// always constructed together; keeping them as three separate stored
/// properties in each scene is how they drifted apart in the first place.
///
/// **What is deliberately *not* here.** The plan for this extraction assumed the
/// two scenes also duplicated fog, HUD building and container handling. Measured,
/// they do not:
///
/// - Fog no longer differs at all, and could move here — but it is a node in
///   the scene graph, not state. Both areas explore the same way, draw the same
///   two bitmaps and take their sight range from the area record; the only
///   difference left is that a district folds its explored cells back into the
///   session (`recordCityFogExplored`) so they outlive the visit, and a room
///   does not. That is one call in one scene, not a seam worth extracting.
/// - The office has no `buildHud` at all — the city's 70 lines have no
///   counterpart to share with.
/// - Containers and a stampable door exist only in the office; edge exits and a
///   world map only in the city.
///
/// The one genuinely identical remnant is `isFloorOrderable`, at six lines,
/// which is not worth a seam. So this stays small on purpose: the real
/// duplication was the waypoint queue, and that already moved to
/// `MovementOrderQueue` where it could be tested.
///
/// Both shipped scenes now build their navigation from the area record. The one
/// thing that used to prevent that — the office's 96,000-node path budget, three
/// times the engine default because a small room packed with ~750 obstacle
/// rectangles expands far more nodes per unit travelled than an open street —
/// is carried by the record as `pathSearchBudget`. The injecting initialiser
/// stays for a scene that needs a map built some other way.
@MainActor
final class AreaRuntime {
    let area: AreaDefinition
    let navigation: NavigationMap
    let movement: MovementOrderQueue

    init(area: AreaDefinition, navigation: NavigationMap, playerActorID: String) {
        self.area = area
        self.navigation = navigation
        self.movement = MovementOrderQueue(navigation: navigation, actorID: playerActorID)
    }

    /// Build the navigation map from the area itself. Used by areas whose
    /// geometry is fully expressed in the record.
    convenience init(area: AreaDefinition, playerActorID: String) {
        self.init(
            area: area,
            navigation: area.makeNavigationMap(),
            playerActorID: playerActorID
        )
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
        area.isCovered(point)
    }

    /// Union of every covering outline, in world space.
    ///
    /// One path rather than one per polygon: the overlay that redraws scenery
    /// over actors is a single masked copy of the plate, so a room with a dozen
    /// walls still costs one extra draw.
    var coverPath: CGPath? {
        let covering = area.wallPolygons.filter(\.coversActors)
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
        area.hidesWallLockedAnimation(at: point)
    }
}

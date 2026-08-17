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
/// - Fog differs in kind, not in detail. The city keeps a growing set of
///   revealed points and persists it per district (`recordCityFogReveal`), which
///   is BG's explored bitmask; the office keeps an eight-point trail around the
///   actor, which is a moving light. Merging them would be a behaviour change
///   dressed as a refactor.
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
/// The navigation map is injected rather than built from `area`, because the two
/// are not yet interchangeable: the office runs a 96,000-node path budget
/// against the 32,000 default, and that budget is scene configuration today
/// rather than part of the area record. Moving it into the record is Phase 5's
/// job, at which point this can build its own map.
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
}

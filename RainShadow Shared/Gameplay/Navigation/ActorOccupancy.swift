import CoreGraphics
import Foundation

/// Identity of an actor stamped into the search map (BG PC / NPC bits).
enum NavigationActorKind: Equatable, Sendable {
    case player
    case npc

    var flag: PathMapFlags {
        switch self {
        case .player: return .pc
        case .npc: return .npc
        }
    }
}

/// Runtime record of one actor's search-map occupancy and bump state.
struct OccupyingActor: Equatable, Sendable {
    let id: String
    let kind: NavigationActorKind
    var position: CGPoint
    /// World-unit proximity radius. Used for bump/overlap decisions between two
    /// bodies, *not* for the search-map stamp — see `personalSpaceCells`.
    var radius: CGFloat
    /// Idle / friendly actors are bumpable (BG:EE default for party/NPCs).
    var isBumpable: Bool
    var isMoving: Bool
    /// BG:EE `personal_space`, in search-map cells. The occupancy stamp covers
    /// `personalSpaceCells - 1` cells and the clearance test only
    /// `personalSpaceCells - 2`; `SearchMap.stampActor` documents why the two
    /// differ.
    var personalSpaceCells: Int = ActorLocomotionPacing.personalSpaceCells
    /// `Movable::BlocksSearchMap`. A ghost or a cutscene-only figure does not
    /// stamp the raster and is not something to bump: `DoStep` reads this on the
    /// *blocker* as well as on the walker before it decides to shove.
    var blocksSearchMap: Bool = true
}

/// The engine's actor occupancy: stamp and clear PC / NPC cells, and answer
/// which body is standing where.
///
/// This type deliberately does *not* decide what to do about a blocker. In the
/// engine that lives on the walker — `Movable::DoStep` looks ahead, and either
/// tells the blocker to `BumpAway` or backs off itself. The retry budget
/// (`pathTries` / `MAX_PATH_TRIES`) likewise belongs to the walker, and caps
/// failed *searches*, not failed steps.
final class ActorOccupancy {
    private(set) var actors: [String: OccupyingActor] = [:]

    weak var searchMap: SearchMap?

    init(searchMap: SearchMap? = nil) {
        self.searchMap = searchMap
    }

    func register(_ actor: OccupyingActor) {
        if let previous = actors[actor.id] {
            clearStamp(previous)
        }
        actors[actor.id] = actor
        stamp(actor)
    }

    func unregister(id: String) {
        if let previous = actors[id] {
            clearStamp(previous)
        }
        actors.removeValue(forKey: id)
    }

    func updatePosition(id: String, to point: CGPoint, isMoving: Bool? = nil) {
        guard var actor = actors[id] else { return }
        let previous = actor
        actor.position = point
        if let isMoving {
            actor.isMoving = isMoving
            // Moving actors are not bumpable; idle ones are.
            actor.isBumpable = !isMoving
        }
        actors[id] = actor

        let cellUnchanged: Bool
        if let searchMap {
            cellUnchanged = searchMap.cell(for: previous.position) == searchMap.cell(for: point)
        } else {
            cellUnchanged = previous.position == point
        }
        if cellUnchanged && previous.isMoving == actor.isMoving {
            return
        }
        clearStamp(previous)
        stamp(actor)
    }

    func setBumpable(id: String, bumpable: Bool) {
        guard var actor = actors[id] else { return }
        actor.isBumpable = bumpable
        actors[id] = actor
    }

    /// `PathFinder::ClearSearchMapFor` — lift this actor's stamp, run `body`,
    /// put it back.
    ///
    /// The engine brackets both the pathfinder and `RandomWalk` like this.
    /// Without it an actor asking whether it can go somewhere reads its own
    /// footprint as an obstacle: `GetBlockedTile` clears `PASSABLE` wherever an
    /// actor is stamped, and the stamp covers the ground under its own feet —
    /// so with `PF_ACTORS_ARE_BLOCKING` the search rejects every cell around the
    /// source and the actor cannot plan a route out of its own personal space.
    ///
    /// Clearing paints a disc, so it also erases the overlapping part of any
    /// neighbour's stamp. The engine repaints those, and so does this; the
    /// instigator itself is the one body deliberately left off.
    func withStampLifted<T>(id: String, _ body: () -> T) -> T {
        guard let actor = actors[id], actor.blocksSearchMap else { return body() }
        clearStamp(actor)
        restampNeighbours(of: actor)
        defer { stamp(actor) }
        return body()
    }

    /// Repaint every stamping body whose disc could have been clipped by
    /// clearing `actor`'s. The engine's radius is `MAX_CIRCLE_SIZE * 3` feet;
    /// ours is the same in cells, converted through the cell size.
    private func restampNeighbours(of actor: OccupyingActor) {
        guard let searchMap else { return }
        let reach = CGFloat(SearchMap.maxCircleSize * 3) * searchMap.cellSize.width
        let reachSquared = reach * reach
        for neighbour in actors.values {
            guard neighbour.id != actor.id, neighbour.blocksSearchMap else { continue }
            let dx = neighbour.position.x - actor.position.x
            let dy = neighbour.position.y - actor.position.y
            guard dx * dx + dy * dy <= reachSquared else { continue }
            stamp(neighbour)
        }
    }

    /// Restamp every registered actor (e.g. after door stamp clears actor bits).
    func restampAll() {
        guard let searchMap else { return }
        searchMap.clearActorFlags()
        for actor in actors.values {
            stamp(actor)
        }
    }

    /// `Map::GetActor` — the body standing at `point`, if any.
    ///
    /// `DoStep` walks its collision probe outward and takes the first hit, so
    /// nearest-first is the order that matters.
    func actor(at point: CGPoint, excluding identity: String?) -> OccupyingActor? {
        var best: (distance: CGFloat, actor: OccupyingActor)?
        for actor in actors.values {
            if actor.id == identity { continue }
            let distance = hypot(actor.position.x - point.x, actor.position.y - point.y)
            guard distance <= actor.radius else { continue }
            if best == nil || distance < best!.distance {
                best = (distance, actor)
            }
        }
        return best?.actor
    }

    /// Whether `point` is occupied by an unbumpable actor other than `exceptID`.
    func isBlockedByUnbumpableActor(at point: CGPoint, radius: CGFloat, exceptID: String?) -> Bool {
        for actor in actors.values {
            if actor.id == exceptID { continue }
            if actor.isBumpable { continue }
            if circlesOverlap(actor.position, actor.radius, point, radius) {
                return true
            }
        }
        return false
    }

    // MARK: - Private

    /// `Map::BlockSearchMapFor` — paint this actor's occupancy disc.
    ///
    /// Guarded on `BlocksSearchMap`, as the engine's every call site is: a ghost
    /// or a cutscene-only figure is present in the world and pickable, but it is
    /// not in the raster, so nothing routes around it and nothing bumps it.
    private func stamp(_ actor: OccupyingActor) {
        guard actor.blocksSearchMap else { return }
        searchMap?.paintSearchMap(
            at: actor.position,
            blockSize: actor.personalSpaceCells,
            value: actor.kind.flag
        )
    }

    /// `Map::ClearSearchMapFor` — the same paint with an empty value. The engine
    /// clears by rewriting the actor nibble, not by masking a specific bit, so a
    /// stale stamp from either kind is lifted.
    private func clearStamp(_ actor: OccupyingActor) {
        guard actor.blocksSearchMap else { return }
        searchMap?.paintSearchMap(
            at: actor.position,
            blockSize: actor.personalSpaceCells,
            value: []
        )
    }

    private func circlesOverlap(
        _ a: CGPoint,
        _ ar: CGFloat,
        _ b: CGPoint,
        _ br: CGFloat
    ) -> Bool {
        let dx = a.x - b.x
        let dy = a.y - b.y
        let limit = ar + br
        return dx * dx + dy * dy <= limit * limit
    }

    /// Pick the nearest passable cell beside the blocker, preferring the side
    /// away from the mover (BG:EE bump aside).
}

/// Occupancy is what answers the search's "can I plan through this body" question.
extension ActorOccupancy: ActorTraversability {
    /// GemRB consults a `TraversabilityCache` snapshot here; the meaning is the
    /// same. A body that can be pushed aside is not an obstacle to planning.
    func isUnbumpableActor(at point: CGPoint, excluding identity: String?) -> Bool {
        for actor in actors.values {
            if actor.id == identity { continue }
            if actor.isBumpable { continue }
            let distance = hypot(actor.position.x - point.x, actor.position.y - point.y)
            if distance <= actor.radius { return true }
        }
        return false
    }
}

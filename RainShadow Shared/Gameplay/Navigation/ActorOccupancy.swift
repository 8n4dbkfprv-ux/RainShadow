import CoreGraphics
import Foundation

/// Identity of an actor stamped into the search map (BG PC / NPC bits).
enum NavigationActorKind: Equatable, Sendable {
    case player
    case npc

    var flag: SearchMapFlags {
        switch self {
        case .player: return .playerActor
        case .npc: return .npcActor
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
}

/// Result of a bump request: the blocker should sidestep, then return.
struct BumpRequest: Equatable, Sendable {
    let actorID: String
    let sidestepPoint: CGPoint
    let returnPoint: CGPoint
}

/// BG:EE-style actor occupancy: stamp/clear PC/NPC cells, prefer walking around
/// bumpable actors, and when a mover is blocked ask the idle actor to sidestep.
/// Congested movers back off with a retry counter instead of repathing forever.
final class ActorOccupancy {
    private(set) var actors: [String: OccupyingActor] = [:]
    /// Consecutive *failed replans* toward the same goal, per mover id.
    private var congestionRetries: [String: Int] = [:]

    /// Replan budget, mirroring GemRB's `MAX_PATH_TRIES` in `Actor::NewPath`:
    /// past this many consecutive searches that found nothing, the mover
    /// abandons its goal instead of grinding a search forever against geometry
    /// that is not going to open.
    ///
    /// This is *not* the per-step bump wait — the engine backs off immediately on
    /// an unbumpable blocker (`Movable::Backoff`), without a retry count.
    var maxCongestionRetries: Int = 8

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
        congestionRetries.removeValue(forKey: id)
    }

    func updatePosition(id: String, to point: CGPoint, isMoving: Bool? = nil) {
        guard var actor = actors[id] else { return }
        clearStamp(actor)
        actor.position = point
        if let isMoving {
            actor.isMoving = isMoving
            // Moving actors are not bumpable; idle ones are.
            actor.isBumpable = !isMoving
        }
        actors[id] = actor
        stamp(actor)
    }

    func setBumpable(id: String, bumpable: Bool) {
        guard var actor = actors[id] else { return }
        actor.isBumpable = bumpable
        actors[id] = actor
    }

    /// Restamp every registered actor (e.g. after door stamp clears actor bits).
    func restampAll() {
        guard let searchMap else { return }
        searchMap.clearActorFlags()
        for actor in actors.values {
            stamp(actor)
        }
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

    /// Find a bumpable idle actor overlapping `point` that can sidestep.
    func bumpRequest(
        forMover moverID: String,
        at point: CGPoint,
        moverRadius: CGFloat
    ) -> BumpRequest? {
        guard let searchMap else { return nil }
        guard let mover = actors[moverID] else { return nil }

        for actor in actors.values {
            if actor.id == moverID { continue }
            guard actor.isBumpable, !actor.isMoving else { continue }
            guard circlesOverlap(actor.position, actor.radius, point, moverRadius) else {
                continue
            }

            if let sidestep = findSidestep(
                for: actor,
                awayFrom: mover.position,
                in: searchMap
            ) {
                congestionRetries[moverID] = 0
                return BumpRequest(
                    actorID: actor.id,
                    sidestepPoint: sidestep,
                    returnPoint: actor.position
                )
            }
        }
        return nil
    }

    /// Record a replan that found no route. Returns true once the mover has
    /// exhausted its budget and should abandon the goal.
    @discardableResult
    func recordCongestion(for moverID: String) -> Bool {
        let next = (congestionRetries[moverID] ?? 0) + 1
        congestionRetries[moverID] = next
        return next >= maxCongestionRetries
    }

    func clearCongestion(for moverID: String) {
        congestionRetries[moverID] = 0
    }

    // MARK: - Private

    private func stamp(_ actor: OccupyingActor) {
        searchMap?.stampActor(
            at: actor.position,
            personalSpaceCells: actor.personalSpaceCells,
            flag: actor.kind.flag,
            set: true
        )
    }

    private func clearStamp(_ actor: OccupyingActor) {
        searchMap?.stampActor(
            at: actor.position,
            personalSpaceCells: actor.personalSpaceCells,
            flag: actor.kind.flag,
            set: false
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
    private func findSidestep(
        for actor: OccupyingActor,
        awayFrom mover: CGPoint,
        in searchMap: SearchMap
    ) -> CGPoint? {
        let away = CGVector(dx: actor.position.x - mover.x, dy: actor.position.y - mover.y)
        let length = hypot(away.dx, away.dy)
        let dir: CGVector
        if length > CGFloat.ulpOfOne {
            dir = CGVector(dx: away.dx / length, dy: away.dy / length)
        } else {
            dir = CGVector(dx: 1, dy: 0)
        }

        let offsets: [CGVector] = [
            dir,
            CGVector(dx: -dir.dy, dy: dir.dx),
            CGVector(dx: dir.dy, dy: -dir.dx),
            CGVector(dx: -dir.dx, dy: -dir.dy),
            CGVector(dx: dir.dx - dir.dy, dy: dir.dy + dir.dx),
            CGVector(dx: dir.dx + dir.dy, dy: dir.dy - dir.dx)
        ]

        let step = max(searchMap.cellSize.width, actor.radius * 2 + 2)
        for ring in 1...4 {
            for offset in offsets {
                let candidate = CGPoint(
                    x: actor.position.x + offset.dx * step * CGFloat(ring),
                    y: actor.position.y + offset.dy * step * CGFloat(ring)
                )
                if searchMap.isPassable(
                    at: candidate,
                    radius: actor.radius,
                    treatActorsAsBlocking: true
                ) {
                    return candidate
                }
            }
        }
        return nil
    }
}

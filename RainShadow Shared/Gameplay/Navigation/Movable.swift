import CoreGraphics
import Foundation

/// Movement stage of a `Movable`, and the gate `doStep` uses to decide what to
/// do with `path` (GemRB `core/Scriptable/Movable.h`).
///
/// The engine carries a fourth state, `FindPathScheduled`, because it runs the
/// search on worker threads and an actor may keep walking a stale path for the
/// tick or two a request is in flight. We search synchronously, so a request is
/// answered inside `walkTo` and that state has nothing to describe.
///
/// `pathSearchFailed` is not similarly optional. It is what makes an unreachable
/// destination *terminate*: the caller learns the search found nothing on its
/// next `walkTo` for the same spot, and until then the dead end is parked in the
/// state. Collapsing straight to `noMovement` makes move actions refile the same
/// hopeless request forever.
enum MovementState: Equatable, Sendable {
    /// Idle; `path` is empty.
    case noMovement
    /// Idle; the last search found nothing and that is not reported yet.
    case pathSearchFailed
    /// Walking `path`.
    case moving
}

/// The engine's animation stances, in the subset movement touches.
enum MovableStance: Equatable, Sendable {
    case awake
    case ready
    case walk
    case run
    case headTurn
}

/// Which kind of order produced a search, which decides how its result is
/// treated (`FindPathRequestType`).
enum FindPathRequestType: Equatable, Sendable {
    case walkTo
    /// A retry issued by `Actor::NewPath`. Only this kind counts a failed search
    /// against `MAX_PATH_TRIES`.
    case walkToFromNewPath
    case addWaypoint
    case runAway
}

/// What one call to `randomWalk` decided (`Movable::RandomWalk`).
///
/// The engine expresses these by pushing actions onto its own queue — a
/// `RandomTurn()` in front of the current action, a `SetWait`, a
/// `ReleaseCurrentAction`. RainShadow has no action queue, so `randomWalk`
/// reports what the engine would have queued and the caller drives it.
enum RandomWalkOutcome: Equatable, Sendable {
    /// Already walking, or a search is pending. Nothing was decided.
    case busy
    /// The 50/50 came up "turn in place". The engine spins once and hands
    /// control back; only `canStop` walks take this branch.
    case spin
    /// A step was adopted and the actor is walking it.
    case wandering
    /// The wander budget ran out, or nowhere was reachable, so the actor is
    /// walking back to `homeLocation`.
    case returningHome
}

/// What one call to `doStep` did, so the owning node can drive animation, audio
/// and the blocker's sidestep without `Movable` knowing about any of them.
struct StepOutcome: Equatable, Sendable {
    var moved = false
    var arrived = false
    /// The actor `doStep` decided to push out of the way. The caller relays a
    /// `bumpAway()` to it, because a `Movable` has no handle on its neighbours.
    var bumpedActorID: String?
    var backedOff = false
    var abandoned = false
}

/// Route execution, transliterated from GemRB `Movable`
/// (`core/Scriptable/Movable.cpp`).
///
/// The movement logic is a proportional regulator: the displacement vector has a
/// fixed radius derived from walk speed and points at the next path node. The
/// bumping logic checks whether moving by that vector would collide, and if so
/// either pushes the blocker aside or waits a random number of ticks — a scheme
/// the engine describes as "inspired by network media access control
/// algorithms", which is what stops two actors deadlocking in lockstep.
struct Movable {
    /// `MAX_PATH_TRIES` (`core/Scriptable/Actor.h`).
    static let maxPathTries = 8
    /// `MAX_BUMP_BACK_TRIES`.
    static let maxBumpBackTries = 16
    /// `MAX_RAND_WALK` — wanders before an actor heads home.
    static let maxRandomWalk = 10
    /// The engine's default random-walk radius when `maxWalkDistance` is unset.
    static let defaultRandomWalkRadius = 5

    weak var map: NavigationMap?
    var identity: String
    var circleSize: Int
    /// Whether this body stamps the search map at all. Ghosts and cutscene-only
    /// figures do not.
    var blocksSearchMap: Bool

    var position: CGPoint
    var destination: CGPoint
    private(set) var orientation: ActorFacing
    var newOrientation: ActorFacing
    private(set) var stance: MovableStance = .awake

    private(set) var path = Path()
    private(set) var movementState: MovementState = .noMovement

    /// Tick of the last emitted step. Also gates `getNextFace`, so a walking
    /// creature cannot also spend the tick turning.
    private(set) var timeStartStep = 0
    private var prevTicks = 0
    private var lastFailedDestination: CGPoint?
    private(set) var pathAbandoned = false

    private(set) var oldPos: CGPoint
    private(set) var bumped = false
    private var bumpBackTries = 0
    private(set) var pathTries = 0
    private(set) var randomBackoff = 0
    var pathfindingDistance: Int
    var isRunning = false

    /// Spawn point. `RandomWalk` returns here once the wander budget is spent.
    var homeLocation: CGPoint
    /// `maxWalkDistance` — how far from home a wander may stray, in cells. Zero
    /// takes the engine's default of five.
    var maxWalkDistance: Int = 0
    private(set) var randomWalkCounter = 0

    init(
        map: NavigationMap? = nil,
        identity: String,
        position: CGPoint,
        circleSize: Int = ActorLocomotionPacing.personalSpaceCells,
        blocksSearchMap: Bool = true,
        orientation: ActorFacing = .south
    ) {
        self.map = map
        self.identity = identity
        self.circleSize = circleSize
        self.blocksSearchMap = blocksSearchMap
        self.position = position.rounded
        self.destination = position.rounded
        self.oldPos = position.rounded
        self.orientation = orientation
        self.newOrientation = orientation
        self.pathfindingDistance = circleSize
        self.homeLocation = position.rounded
    }

    // MARK: - Interrogation

    var isMoving: Bool { movementState == .moving }
    var hasPath: Bool { path.isPresent }
    var isBumped: Bool { bumped }
    var isBackingOff: Bool { randomBackoff > 0 }
    var isInMovingStance: Bool { stance == .walk || stance == .run }
    /// Ordered goals still ahead, for ground reticles.
    var pendingWaypoints: [CGPoint] { path.pendingWaypoints }
    var remainingPoints: [CGPoint] { path.remainingPoints }

    /// `GetMostLikelyPosition` — where this actor is heading, for anything that
    /// needs to aim at a mover rather than at where it currently stands.
    var mostLikelyPosition: CGPoint {
        guard path.isPresent else { return position }
        let halfway = path.size / 2
        if let node = path.nextStep(halfway) {
            return CGPoint(
                x: node.point.x + map!.searchMap.cellSize.width / 2,
                y: node.point.y + map!.searchMap.cellSize.height / 2
            )
        }
        return destination
    }

    // MARK: - Orientation

    mutating func setOrientation(_ value: ActorFacing, slow: Bool) {
        newOrientation = value
        if !slow {
            orientation = newOrientation
        }
    }

    mutating func setOrientation(from: CGPoint, to: CGPoint, slow: Bool) {
        setOrientation(ActorFacing.orient(from: from, to: to), slow: slow)
    }

    /// `GetNextFace` — one bin of a gradual turn, unless a step was already
    /// spent this tick.
    func nextFace(at ticks: Int) -> ActorFacing {
        if timeStartStep == ticks { return orientation }
        return orientation.stepped(toward: newOrientation)
    }

    /// Spend a tick turning in place. Standing actors only; `doStep` snaps.
    mutating func advanceTurn(at ticks: Int) {
        orientation = nextFace(at: ticks)
    }

    // MARK: - Backoff

    /// `Movable::Backoff` — drop the walk stance and wait a randomised number of
    /// ticks before retrying the same step. The route is never discarded.
    mutating func backoff() {
        stance = .ready
        randomBackoff = isRunning
            ? Int.random(in: (Self.maxPathTries * 2 / 3)...(Self.maxPathTries * 4 / 3))
            : Int.random(in: Self.maxPathTries...(Self.maxPathTries * 2))
    }

    mutating func decreaseBackoff() {
        randomBackoff -= 1
    }

    // MARK: - Stepping

    /// `Movable::DoStep`. One call per logic tick.
    ///
    /// `walkScale` is `1500 / IE_MOVEMENTRATE`; larger is slower, as in the
    /// engine. Zero means immobile.
    @discardableResult
    mutating func doStep(walkScale: CGFloat, time: Int) -> StepOutcome {
        var outcome = StepOutcome()

        // Only bump back when not moving. An actor can still be bumped while
        // moving if it is backing off.
        guard movementState == .moving else {
            if bumped { bumpBack() }
            return outcome
        }
        guard walkScale > 0 else {
            stance = .ready
            timeStartStep = time
            return outcome
        }
        guard time > timeStartStep else { return outcome }
        guard path.isPresent, let step = path.currentStepNode else { return outcome }

        var dx = step.point.x - position.x
        var dy = step.point.y - position.y
        PathFinder.normalizeDeltas(
            &dx,
            &dy,
            factor: ActorLocomotionPacing.infinityEngineStepTime / walkScale
        )
        if dx == 0 && dy == 0 {
            // Shouldn't happen, but does — we are exactly on the goal already.
            clearPath(resetDestination: true)
            pathAbandoned = true
            outcome.abandoned = true
            return outcome
        }

        // Look ahead *along the way*, not in a ring: the engine explicitly does
        // not want to be blocked by actors standing off to the sides. Probing at
        // the mover's own position only fires once two bodies interpenetrate.
        var actorInTheWay: OccupyingActor?
        if let occupancy = map?.occupancy {
            let lookahead = ((circleSize < 3 ? 3 : circleSize) - 1) * 3
            var radius = lookahead
            while radius > 0 {
                let probe = CGPoint(
                    x: position.x + dx * CGFloat(radius),
                    y: position.y + dy * CGFloat(radius)
                )
                if let hit = occupancy.actor(at: probe, excluding: identity) {
                    actorInTheWay = hit
                    break
                }
                radius -= 1
            }
        }

        if let blocker = actorInTheWay, blocksSearchMap, blocker.blocksSearchMap {
            // Give up rather than shove when the goal is already in reach, so a
            // close approach does not push furniture-adjacent NPCs around.
            if path.size == 1, withinPersonalRange(of: step.point) {
                clearPath(resetDestination: true)
                newOrientation = orientation
                pathAbandoned = true
                outcome.abandoned = true
                return outcome
            }
            if blocker.isBumpable {
                outcome.bumpedActorID = blocker.id
            } else {
                backoff()
                outcome.backedOff = true
                return outcome
            }
        }

        // Stop if there is a wall in the way.
        let wallProbe = CGPoint(x: position.x + dx, y: position.y + dy)
        if blocksSearchMap, let searchMap = map?.searchMap,
           searchMap.blockedTile(at: searchMap.cell(for: wallProbe)).contains(.sidewall) {
            clearPath(resetDestination: true)
            newOrientation = orientation
            outcome.abandoned = true
            return outcome
        }

        position = CGPoint(x: position.x + dx, y: position.y + dy)
        oldPos = position
        stance = isRunning ? .run : .walk
        if blocksSearchMap {
            map?.occupancy.updatePosition(id: identity, to: position, isMoving: true)
        }

        setOrientation(step.orient, slow: false)
        timeStartStep = time
        outcome.moved = true

        if position == step.point {
            path.nodes[path.currentStep].waypoint = false
            path.currentStep += 1
            if path.currentStep >= path.size {
                clearPath(resetDestination: true)
                newOrientation = orientation
                pathfindingDistance = circleSize
                outcome.arrived = true
            }
        }
        return outcome
    }

    // MARK: - Orders

    /// `Movable::WalkTo`.
    ///
    /// The 2-tick rate limit is the engine's, and its comment explains it: the
    /// function is called every tick while an actor follows another actor.
    mutating func walkTo(
        _ des: CGPoint,
        minDistance: CGFloat = 0,
        requestType: FindPathRequestType = .walkTo,
        ticks: Int
    ) {
        // Only rate-limit an actor that is actually walking.
        if movementState == .moving, prevTicks > 0, ticks < prevTicks + 2 {
            return
        }

        // Report a search that already came back empty for this exact spot, then
        // consume the verdict so a later order for the same place still gets a
        // fresh search. A different destination falls through to a real one.
        if movementState == .pathSearchFailed {
            movementState = .noMovement
            if let failed = lastFailedDestination, des.rounded == failed {
                destination = des.rounded
                return
            }
        }

        prevTicks = ticks
        destination = des.rounded

        if pathAbandoned {
            clearPath(resetDestination: true)
            return
        }

        if let searchMap = map?.searchMap,
           searchMap.cell(for: position) == searchMap.cell(for: destination) {
            // `ClearPath(true)` then `SetStance(IE_ANI_HEAD_TURN)`, and nothing
            // else: the engine does not aim the turn at the click. The head-turn
            // stance is an idle flourish, not a pivot toward a target, and the
            // caller that wants a facing sets one itself.
            clearPath(resetDestination: true)
            stance = .headTurn
            return
        }

        var flags: PathFinderFlags = [.sight]
        if requestType == .walkTo || requestType == .walkToFromNewPath {
            flags.insert(.actorsAreBlocking)
        }
        let found = map?.findPath(
            from: position,
            to: destination,
            minDistance: minDistance,
            flags: flags,
            identity: identity
        ) ?? Path()

        onPathCalculated(
            found,
            requestType: requestType,
            requestedDestination: destination,
            minDistance: minDistance
        )
    }

    /// `Movable::OnPathCalculated` — what a finished search does to the actor,
    /// which depends on why it was asked for.
    private mutating func onPathCalculated(
        _ newPath: Path,
        requestType: FindPathRequestType,
        requestedDestination: CGPoint,
        minDistance: CGFloat
    ) {
        switch requestType {
        case .walkTo, .walkToFromNewPath:
            if newPath.isPresent, newPath != path {
                clearPath(resetDestination: false)
                path = newPath
                movementState = .moving
                return
            }

            pathfindingDistance = max(circleSize, Int(minDistance))
            if path.isEmpty {
                movementState = .pathSearchFailed
                lastFailedDestination = requestedDestination
                if requestType == .walkToFromNewPath {
                    pathTries += 1
                }
            } else {
                movementState = .moving
            }

        case .addWaypoint:
            // A waypoint too close to plan for produces nothing. Dropping to
            // `noMovement` unconditionally here would strand an actor still
            // holding the leg it was walking.
            guard newPath.isPresent else {
                movementState = path.isPresent ? .moving : .noMovement
                return
            }
            path.markLastAsWaypoint()
            path.append(newPath)
            movementState = .moving

        case .runAway:
            path = newPath
            movementState = path.isPresent ? .moving : .noMovement
        }
    }

    /// `Movable::AddWayPoint` — extend a path already being walked.
    ///
    /// Three engine behaviours are load-bearing here. The new leg is searched
    /// **from the last path node**, not from the actor, so legs chain end to end
    /// and the queue survives the actor being anywhere along the current one.
    /// With nothing to extend this degrades to a plain `walkTo`. And an appended
    /// leg ignores other actors, where a fresh order treats them as blocking —
    /// deliberate, since whoever is in the way now will have moved by the time a
    /// later leg is walked.
    mutating func addWayPoint(_ des: CGPoint, ticks: Int) {
        if path.isEmpty {
            // A waypoint is a new order, not the retry of a failed one, so it
            // must not be answered by a stale failure verdict.
            if movementState == .pathSearchFailed {
                movementState = .noMovement
            }
            walkTo(des, ticks: ticks)
            return
        }

        destination = des.rounded
        guard let lastStep = path.nodes.last else { return }

        let leg = map?.findPath(
            from: lastStep.point,
            to: destination,
            flags: [.sight],
            identity: identity
        ) ?? Path()

        onPathCalculated(
            leg,
            requestType: .addWaypoint,
            requestedDestination: destination,
            minDistance: 0
        )
    }

    /// `Movable::MoveLine` — walk a ruled line, `steps` cells in `orient`.
    ///
    /// The path is a single node, the line's far end; `DoStep` takes care of
    /// stopping on a wall along the way. Building `path` by hand means the
    /// state has to be advanced by hand too — `doStep` ignores a path while the
    /// state is `noMovement`.
    mutating func moveLine(steps: Int, orient: ActorFacing) {
        guard movementState != .moving, steps != 0, let map else { return }
        path.appendStep(
            PathFinder.calculateLineEnd(
                on: map.searchMap,
                from: position,
                steps: steps,
                orient: orient
            )
        )
        if let last = path.nodes.last { destination = last.point }
        movementState = .moving
    }

    /// `Movable::RunAwayFrom` — flee `threat`, up to `pathLength` cells.
    ///
    /// `noBackAway` withholds `PF_BACKAWAY`, the flag that lets the search face
    /// a creature *toward* the thing it is retreating from when the destination
    /// is behind it — a fleeing beetle keeps its eyes on you.
    mutating func runAwayFrom(
        _ threat: CGPoint,
        pathLength: Int,
        noBackAway: Bool,
        walkScale: CGFloat
    ) {
        clearPath(resetDestination: true)
        guard let map, walkScale > 0 else { return }
        guard let target = PathFinder.calculateRunAwayPoint(
            on: map.searchMap,
            from: position,
            threat: threat,
            maxPathLength: pathLength,
            walkScale: walkScale,
            circleSize: circleSize
        ) else { return }

        var flags: PathFinderFlags = [.sight]
        if !noBackAway { flags.insert(.backAway) }
        let found = map.findPath(
            from: position,
            to: target,
            minDistance: CGFloat(circleSize),
            flags: flags,
            identity: identity
        )
        destination = target.rounded
        onPathCalculated(
            found,
            requestType: .runAway,
            requestedDestination: destination,
            minDistance: CGFloat(circleSize)
        )
    }

    /// `Movable::RandomWalk` — one wander step, or the decision not to take one.
    ///
    /// `canStop` is the engine's "not a continuous walker" flag, and buys a
    /// 50/50 chance of spinning in place instead of moving. Two of the engine's
    /// branches have no equivalent here and are deliberately absent: the
    /// off-screen check that makes an unseen actor wait a random 1-40 seconds
    /// (there is no viewport to consult from this layer), and the
    /// `RandomWalkTime` action parameters that count moves down to a release.
    /// Both belong to the action queue rather than to movement.
    ///
    /// The actor's own stamp is lifted for the query, as the engine does, or it
    /// reads the ground under its own feet as occupied.
    @discardableResult
    mutating func randomWalk(canStop: Bool, run: Bool, walkScale: CGFloat, ticks: Int) -> RandomWalkOutcome {
        guard movementState != .moving else { return .busy }
        if canStop, Bool.random() { return .spin }

        randomWalkCounter += 1
        if randomWalkCounter > Self.maxRandomWalk {
            randomWalkCounter = 0
            walkTo(homeLocation, ticks: ticks)
            return .returningHome
        }

        if run { isRunning = true }
        guard let map else { return .busy }

        let radius = maxWalkDistance > 0 ? maxWalkDistance : Self.defaultRandomWalkRadius
        let step = blocksSearchMap
            ? map.occupancy.withStampLifted(id: identity) {
                PathFinder.calculateRandomWalkPoint(
                    on: map.searchMap,
                    from: position,
                    circleSize: circleSize,
                    radius: radius,
                    walkScale: walkScale
                )
            }
            : PathFinder.calculateRandomWalkPoint(
                on: map.searchMap,
                from: position,
                circleSize: circleSize,
                radius: radius,
                walkScale: walkScale
            )

        guard let step else {
            randomWalkCounter = 0
            walkTo(homeLocation, ticks: ticks)
            return .returningHome
        }

        destination = step.point
        // Start or end does not matter: the path is empty here.
        path.prependStep(step)
        movementState = .moving
        return .wandering
    }

    /// Reset the wander budget — the engine clears it whenever an actor heads
    /// home, and a caller ending a wander behaviour should too.
    mutating func resetRandomWalkCounter() {
        randomWalkCounter = 0
    }

    /// Adopt a route built elsewhere — scripted beats and cutscenes, which
    /// resolve their anchors through `NavigationMap.waypoints(visiting:)`.
    ///
    /// `MoveLine` and `RandomWalk` do the same thing in the engine, and carry
    /// the same warning: `DoStep` ignores a path while the state is
    /// `noMovement`, so anything populating `path` directly must advance the
    /// state by hand or the actor holds a route it never walks.
    mutating func adopt(_ newPath: Path) {
        clearPath(resetDestination: false)
        path = newPath
        if let last = newPath.nodes.last {
            destination = last.point
        }
        movementState = newPath.isPresent ? .moving : .noMovement
    }

    /// Splice a leg onto the end of the live route, marking the junction.
    mutating func appendPath(_ leg: Path) {
        guard leg.isPresent else { return }
        guard path.isPresent else {
            adopt(leg)
            return
        }
        path.markLastAsWaypoint()
        path.append(leg)
        if let last = leg.nodes.last {
            destination = last.point
        }
        movementState = .moving
    }

    /// Orientation stored on the node currently being walked toward.
    var currentNodeOrientation: ActorFacing? {
        path.currentStepNode?.orient
    }

    /// How many ticks the walk to `point` takes at `walkScale`, by running the
    /// same `NormalizeDeltas` the actor will. Used to match an animation to the
    /// leg it hands over to; quantisation means this cannot be a division.
    func ticksToReach(_ point: CGPoint, walkScale: CGFloat) -> Int {
        guard walkScale > 0 else { return 0 }
        let factor = ActorLocomotionPacing.infinityEngineStepTime / walkScale
        // Both ends are snapped, because `NormalizeDeltas` rounds every step up
        // to a whole unit and arrival here is the same exact `cursor == goal`
        // test `doStep` uses. `doStep` can rely on that because `walkTo` and
        // `moveTo` snap the position they set; this loop was handed
        // `movable.position` straight from the actor node, which carries the
        // sub-unit remainder of the last frame. A fractional offset can never be
        // cancelled by whole-unit steps, so the loop always ran to its 4_096
        // iteration cap and every caller read that back as the tick count —
        // which is how the seat egress came to be animated over 273 seconds.
        var cursor = position.rounded
        let goal = point.rounded
        var ticks = 0
        while cursor != goal && ticks < 4_096 {
            var dx = goal.x - cursor.x
            var dy = goal.y - cursor.y
            PathFinder.normalizeDeltas(&dx, &dy, factor: factor)
            if dx == 0 && dy == 0 { break }
            cursor = CGPoint(x: cursor.x + dx, y: cursor.y + dy)
            ticks += 1
        }
        return ticks
    }

    /// `Movable::MoveTo` — teleport, restamping occupancy.
    mutating func moveTo(_ des: CGPoint) {
        position = des.rounded
        oldPos = position
        destination = position
        if blocksSearchMap {
            map?.occupancy.updatePosition(id: identity, to: position)
        }
    }

    /// `Movable::Stop`.
    mutating func stop() {
        clearPath(resetDestination: true)
    }

    /// `Movable::ClearPath`.
    mutating func clearPath(resetDestination: Bool) {
        pathAbandoned = false
        if resetDestination {
            // Makes attackers come to us rather than to where we were going.
            destination = position
            if stance == .walk || stance == .run {
                stance = .awake
            }
        }
        path.clear()
        movementState = .noMovement
    }

    /// Reset the failed-search latch. `Actor::NewPath`'s retry budget is the
    /// only thing that reads `pathTries`.
    mutating func resetPathTries() {
        pathTries = 0
    }

    /// Test seam. `pathTries` is only ever incremented by a failed
    /// `walkToFromNewPath` search, which cannot be provoked on open floor.
    mutating func debugCountFailedPathTry() {
        pathTries += 1
    }

    /// `Actor::NewPath` compares strictly greater, so the budget is one more
    /// retry than the constant reads.
    var hasExhaustedPathTries: Bool { pathTries > Self.maxPathTries }

    // MARK: - Bumping

    /// `Movable::BumpAway` — step off the spot so a mover can get past.
    mutating func bumpAway() {
        guard let map else { return }
        if !bumped { oldPos = position }
        bumped = true
        bumpBackTries = 0
        position = map.pathFinder.adjustPositionNavmap(position).rounded
        if blocksSearchMap {
            map.occupancy.updatePosition(id: identity, to: position)
        }
    }

    /// `Movable::BumpBack` — reclaim the spot once it is free again.
    ///
    /// Giving up is bounded, not indefinite: past `MAX_BUMP_BACK_TRIES` within
    /// its own personal space an actor accepts where it stands, and drops its
    /// path outright if it was already near its destination.
    mutating func bumpBack() {
        guard let map else { return }
        let searchMap = map.searchMap
        let oldCell = searchMap.cell(for: oldPos)
        let oldStatus = searchMap.blockedTile(at: oldCell)

        if oldStatus.contains(.passable) {
            bumped = false
            moveTo(oldPos)
            bumpBackTries = 0
            return
        }

        // Also go back if the only thing "blocking" the spot is this actor.
        if !oldStatus.isDisjoint(with: .actor),
           map.occupancy.actor(at: oldPos, excluding: nil)?.id == identity {
            bumped = false
            moveTo(oldPos)
            bumpBackTries = 0
            return
        }

        // The engine gates what follows on `GetStat(IE_EA) < EA_GOODCUTOFF`, so
        // only friendly actors ever give up on reclaiming their spot; a hostile
        // keeps trying forever. RainShadow has no alignment axis to read, and
        // inventing one to reproduce a "never give up" branch nothing would take
        // would be worse than the omission. Everyone gives up here.
        bumpBackTries += 1
        let personalSpace = CGFloat(circleSize) * searchMap.cellSize.width * 2
        if bumpBackTries > Self.maxBumpBackTries,
           squaredDistance(position, oldPos) < personalSpace * personalSpace {
            oldPos = position
            bumped = false
            bumpBackTries = 0
            if squaredDistance(position, destination) < personalSpace * personalSpace {
                clearPath(resetDestination: true)
            }
        }
    }

    // MARK: - Private

    /// `WithinPersonalRange(this, dest, 1)` — one foot from this body's own feet
    /// circle, measured on the engine's 16:12 ellipse.
    ///
    /// The engine's comment says why the cut-off is a foot: "attacking with
    /// close-ranged weapons is unlikely to stop approaching too soon". This used
    /// to approximate it as a plain `circleSize * cellWidth` radius, which is
    /// both circular and a different number.
    private func withinPersonalRange(of destination: CGPoint) -> Bool {
        IEGeometry.withinPersonalRange(
            actor: position,
            circleSize: circleSize,
            destination: destination,
            feet: 1
        )
    }

    private func squaredDistance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return dx * dx + dy * dy
    }
}

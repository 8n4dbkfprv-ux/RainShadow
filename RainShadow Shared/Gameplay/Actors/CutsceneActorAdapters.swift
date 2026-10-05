import SpriteKit

/// Cutscene driving for the two shipped actors.
///
/// Adapters rather than new locomotion: every floor move still goes through
/// `Movable::DoStep` and the 15 Hz logic tick, which is the frozen rule from
/// `Documentation/README.md` — authored polylines are routes, never `SKAction`
/// movement chains.

extension DetectiveActorNode: CutsceneActorDriving {
    var cutsceneWorldPosition: CGPoint { position }
    var cutsceneNavigationID: String { movable.identity }

    func cutsceneFollow(
        path: [CGPoint],
        style: CutsceneWalkStyle,
        completion: @escaping () -> Void
    ) {
        // An authored rail is a polyline, not a search result, so the node
        // orientations are computed the way `FindPath` would have stored them.
        walk(path: Path(points: path, from: position), completeWhenStopped: true, completion: completion)
    }

    func cutsceneJump(to point: CGPoint, style: CutsceneWalkStyle) {
        cancelMovement()
        relocateForDoor(to: point.rounded)
    }

    func cutsceneFace(_ facing: ActorFacing) { setEntranceFacing(facing) }
    func cutsceneFace(toward point: CGPoint) {
        setEntranceFacing(ActorFacing.orient(from: position, to: point))
    }
    func cutsceneClearActions() { cancelMovement() }
    func cutsceneStandImmediately() { beginOpenWorldStanding() }

    /// An empty route is the seat-egress path: the stand-up strip, then the
    /// slide out of the kneehole, ending in standing idle at the same spot. He
    /// gets to his feet without walking anywhere.
    func cutsceneStandUp(completion: @escaping () -> Void) {
        walk(path: Path(), completion: completion)
    }
}

extension ClientActorNode: CutsceneActorDriving {
    var cutsceneWorldPosition: CGPoint { position }

    func cutsceneFollow(
        path: [CGPoint],
        style: CutsceneWalkStyle,
        completion: @escaping () -> Void
    ) {
        switch style {
        case .entering:
            performEntrance(along: path, completion: completion)
        case .leaving:
            performExit(along: path, completion: completion)
        case .plain:
            walk(path: path, completion: completion)
        }
    }

    func cutsceneJump(to point: CGPoint, style: CutsceneWalkStyle) {
        jumpForCutscene(to: point, style: style)
    }
    func cutsceneFace(_ facing: ActorFacing) { setScriptedFacing(facing) }
    func cutsceneFace(toward point: CGPoint) {
        setScriptedFacing(ActorFacing.orient(from: position, to: point))
    }
    func cutsceneClearActions() { stopScriptedMovement() }
    func cutsceneStandImmediately() {}
    func cutsceneStandUp(completion: @escaping () -> Void) { completion() }
}

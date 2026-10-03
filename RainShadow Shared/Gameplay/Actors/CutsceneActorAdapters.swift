import SpriteKit

/// Cutscene driving for the two shipped actors.
///
/// Adapters rather than new locomotion: every floor move still goes through
/// `Movable::DoStep` and the 15 Hz logic tick, which is the frozen rule from
/// `Documentation/README.md` — authored polylines are routes, never `SKAction`
/// movement chains.

extension DetectiveActorNode: CutsceneActorDriving {
    var cutsceneWorldPosition: CGPoint { position }

    func cutsceneFollow(
        path: [CGPoint],
        style: CutsceneWalkStyle,
        completion: @escaping () -> Void
    ) {
        // An authored rail is a polyline, not a search result, so the node
        // orientations are computed the way `FindPath` would have stored them.
        walk(path: Path(points: path, from: position), completion: completion)
    }

    func cutsceneJump(to point: CGPoint, style: CutsceneWalkStyle) {
        cancelMovement()
        position = point
    }

    func cutsceneFace(_ facing: ActorFacing) {
        // Orientations run clockwise from S; `mathy` converts to the
        // counter-clockwise-from-E angle trigonometry expects
        // (`GetMathyOrientation`).
        let vector = facing.vector
        turnToFace(
            CGPoint(x: position.x + vector.dx * 100, y: position.y + vector.dy * 100)
        )
    }

    func cutsceneFace(toward point: CGPoint) {
        turnToFace(point)
    }

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
        switch style {
        case .entering:
            // Snaps to the authored end pose and fires the same completion a
            // natural finish would. The runner has already retired the cue by
            // then, so the report is a no-op — but the pose is identical, which
            // is the half that matters.
            completeEntranceImmediately()
        case .leaving:
            completeExitImmediately()
        case .plain:
            position = point
        }
    }

    /// Art-blocked, and deliberately loud about it.
    ///
    /// `ClientActorNode` ships three strips — arrival SW, departure NE, departure
    /// NW. There is no "turns to look at you" frame, so a facing cue authored on
    /// the client has no honest presentation. Picking the nearest departure strip
    /// would face her at the door she just came through.
    func cutsceneFace(_ facing: ActorFacing) {
        assertionFailure(
            "Cutscene faced the client (\(facing)). Lila has arrival and departure "
                + "strips only — no turn-in-place art — so a facing cue on her cannot "
                + "be drawn. Author it on the detective, or add the strip first."
        )
    }

    func cutsceneFace(toward point: CGPoint) {
        assertionFailure(
            "Cutscene faced the client toward \(point). See cutsceneFace(_:) — "
                + "there is no turn-in-place art for Lila."
        )
    }

    func cutsceneStandUp(completion: @escaping () -> Void) {
        assertionFailure("Cutscene stood the client up; only the detective has a seat.")
        completion()
    }
}

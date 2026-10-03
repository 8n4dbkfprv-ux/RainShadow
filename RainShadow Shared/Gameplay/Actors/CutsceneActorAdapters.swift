import SpriteKit

extension DetectiveActorNode: CutsceneActorDriving {
    var cutsceneWorldPosition: CGPoint { position }
    var cutsceneNavigationID: String { movable.identity }

    func cutsceneFollow(path: [CGPoint], completion: @escaping () -> Void) {
        walk(path: Path(points: path, from: position), completion: completion)
    }

    func cutsceneJump(to point: CGPoint) {
        cancelMovement()
        relocateForDoor(to: point)
    }

    func cutsceneFace(_ facing: ActorFacing) { setEntranceFacing(facing) }
    func cutsceneFace(toward point: CGPoint) {
        setEntranceFacing(ActorFacing.orient(from: position, to: point))
    }

    func cutscenePlaySequence(_ sequence: CutsceneSequence, completion: @escaping () -> Void) {
        walk(path: Path(), completion: completion)
    }
    func cutsceneSetHidden(_ hidden: Bool) { isHidden = hidden }
    func cutsceneClearActions() { cancelMovement() }
}

extension ClientActorNode: CutsceneActorDriving {
    var cutsceneWorldPosition: CGPoint { position }

    func cutsceneFollow(path: [CGPoint], completion: @escaping () -> Void) {
        walk(path: path, completion: completion)
    }

    func cutsceneJump(to point: CGPoint) {
        jumpForCutscene(to: point)
    }
    func cutsceneFace(_ facing: ActorFacing) { setScriptedFacing(facing) }
    func cutsceneFace(toward point: CGPoint) {
        setScriptedFacing(ActorFacing.orient(from: position, to: point))
    }
    func cutsceneClearActions() { stopScriptedMovement() }
    func cutsceneSetHidden(_ hidden: Bool) { isHidden = hidden }
    func cutscenePlaySequence(_ sequence: CutsceneSequence, completion: @escaping () -> Void) { completion() }
}

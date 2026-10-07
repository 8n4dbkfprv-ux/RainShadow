import SpriteKit

/// Area-local presentation. All durable progress belongs to WharfLadderStory;
/// destroying this director during a fade leaves a resumable pending request.
@MainActor
final class WharfLadderDirector {
    private unowned let scene: CityDistrictScene
    private var completion: (() -> Void)?
    private var resolving: WharfLadderStory.Encounter?
    private var walkingIntoRoom = false
    private var crew: [CharacterAppearanceNode] = []
    private(set) var combatDirector: TacticalCombatDirector?
    var isCombatActive: Bool { combatDirector != nil }
    private(set) var isActive = false
    private(set) var cinematicMode = false
    private var state: CaseState { scene.context.session.caseState }

    init(scene: CityDistrictScene) { self.scene = scene }

    func start(exteriorCompletion: (() -> Void)? = nil) {
        guard !isActive else { return }
        isActive = true
        scene.dialogueIsActive = true
        scene.hudRoot.childNode(withName: "city.arrivalHint")?.removeFromParent()
        completion = exteriorCompletion
        scene.detective.cancelMovement()
        scene.setCameraScroll(.zero)
        scene.context.session.updateWharfStory { state, _ in WharfLadderStory.beginVisit(&state) }
        if let saved = scene.context.session.tacticalCombat, saved.areaID == scene.area.id.rawValue,
           let encounter = WharfLadderStory.Encounter(rawValue: saved.encounterID) {
            let opponents = saved.actors.filter { !$0.player }.sorted { $0.id < $1.id }
            stageCrew(count: opponents.count, clerk: false, restoredPoints: opponents.map(\.position))
            beginCombat(encounter, restored: saved)
            return
        }
        if scene.area.id == WharfLadderStory.interior,
           let target = scene.navigation.nearestWalkablePoint(to: CGPoint(x: scene.area.worldBounds.midX, y: scene.area.worldBounds.midY)),
           scene.navigation.occupancy.withStampLifted(id: scene.detective.cutsceneNavigationID, {
               scene.navigation.reachesExactly(from: scene.detective.position, to: target)
           }) {
            walkingIntoRoom = true
            scene.cutsceneDirector.play(Cutscene(id: "wharf-ladder.enter-room", tracks: [
                CutsceneTrack(.actor(.detective), [.setCutsceneMode(true), .letterbox(true),
                    .moveToPoint(target), .letterbox(false), .setCutsceneMode(false)])
            ]), on: scene)
        } else { advance() }
    }

    private func advance() {
        if let pending = WharfLadderStory.pendingAftermath(in: state) {
            showAftermath(pending)
            return
        }
        if WharfLadderStory.requested(.e1, in: state) {
            stageCrew(count: 2, clerk: false)
            resolve(.e1); return
        }
        if let next = WharfLadderStory.nextFloor(in: state) {
            if next == .clockroom && scene.area.id == WharfLadderStory.exterior { finish(); return }
            stageCrew(count: next.crewCount, clerk: false)
            if WharfLadderStory.requested(next, in: state) { resolve(next); return }
            show(next.graph) { [weak self] in self?.resolve(next) }
            return
        }
        if scene.area.id == WharfLadderStory.exterior { finish(); return }
        showMerrick()
    }

    private func showMerrick() {
        guard state.hasFlag("combat.a1.clockroom.done") else { advance(); return }
        stageCrew(count: 1, clerk: true)
        show(WharfLadderDialogue.graph("wharf-ladder")) { [weak self] in
            guard let self else { return }
            if WharfLadderStory.requested(.e1, in: self.state) {
                self.stageCrew(count: 2, clerk: false)
                self.resolve(.e1)
            } else { self.finish() }
        }
    }

    private func resolve(_ encounter: WharfLadderStory.Encounter) {
        guard WharfLadderStory.requested(encounter, in: state) else { finish(); return }
        if WharfLadderStory.quiet(encounter, in: state) {
            // Story mode narrates the earned crossing. A future sightline runner
            // can replace this dispatch without changing its dialogue contract.
            commit(encounter)
            showAftermath(encounter)
            return
        }
        beginCombat(encounter)
    }

    private func beginCombat(_ encounter: WharfLadderStory.Encounter, restored: TacticalCombat? = nil) {
        // Story-only harness remains an explicit debug compatibility mode.
        #if DEBUG
        if ProcessInfo.processInfo.environment["RAINSHADOW_QA_WHARF"] != nil {
            resolving = encounter
            scene.cutsceneDirector.play(WharfLadderStory.cinematic(for: encounter), on: scene)
            return
        }
        #endif
        guard !crew.isEmpty else { assertionFailure("Combat has no staged opponents"); return }
        let openingBonus = state.hasFlag(encounter.prefix + ".opening.firstBlow") ? 20 : 0
        let rattled = state.hasFlag(encounter.prefix + ".opening.rattled")
        var actors = [Combatant(id: TacticalCombat.playerID, name: "Voss", player: true,
            position: scene.detective.position.rounded, hp: 12, maximumHP: 12,
            defence: 12 + scene.context.session.defenceBonus, attackBonus: 5,
            damageMin: 3, damageMax: 5, initiativeBonus: 3 + openingBonus,
            speed: scene.detective.movementProfile.effectiveMoveScale == nil ? 0 :
                240 * Double((scene.detective.movementProfile.effectiveMoveScale ?? 9) / 9))]
        actors += crew.enumerated().map { index, node in
            Combatant(id: node.definition.id, name: "Hand \(index + 1)", player: false,
                      position: node.position.rounded, hp: 7, maximumHP: 7,
                      defence: 11, attackBonus: rattled ? 0 : 2, damageMin: 1, damageMax: 3,
                      initiativeBonus: 1)
        }
        actors[0].rangedWeapon = .bow
        if restored == nil, encounter == .gate, actors.count > 2 {
            actors[2].rangedWeapon = .bow
            actors[2].name = "Lookout"
            if let path = CombatNavigation.firingPosition(in: scene.navigation, actor: actors[2], target: actors[0], limit: 400),
               let point = path.destination {
                actors[2].position = point
                crew[1].position = point
                scene.navigation.updateActor(id: actors[2].id, position: point, isMoving: false)
            }
        }
        for node in crew {
            let actor = (restored?.actors ?? actors).first { $0.id == node.definition.id }
            if actor?.rangedWeapon == .bow {
                var definition = node.definition
                definition.appearance.equipment = [.init(item: .elvenCourtBow), .init(item: .elvenCourtArrow)]
                do { try node.apply(definition) }
                catch { assertionFailure("Lookout artwork: \(error)") }
            }
        }
        var seed = UInt64.random(in: 1...UInt64.max)
        #if DEBUG
        if ProcessInfo.processInfo.environment["RAINSHADOW_QA_COMBAT"] != nil { seed = 42 }
        #endif
        let model = restored ?? TacticalCombat(encounterID: encounter.rawValue, areaID: scene.area.id.rawValue,
            actors: actors, seed: seed, barrels: encounter == .gate
                ? CombatNavigation.gateBarrels(in: scene.navigation, actors: actors) : [])
        scene.pause.clearPlayerPause()
        combatDirector = TacticalCombatDirector(scene: scene, combat: model, crew: crew) { [weak self] in
            guard let self else { return }
            self.combatDirector = nil
            self.showAftermath(encounter)
        }
        scene.overlayPresentationDidChange()
    }

    func cutsceneCompleted() {
        if walkingIntoRoom { walkingIntoRoom = false; advance(); return }
        guard let encounter = resolving else { return }
        resolving = nil
        commit(encounter)
        showAftermath(encounter)
    }

    private func commit(_ encounter: WharfLadderStory.Encounter) {
        scene.context.session.updateWharfStory { state, _ in
            WharfLadderStory.resolve(encounter, in: &state)
        }
    }

    private func showAftermath(_ encounter: WharfLadderStory.Encounter) {
        clearCrew()
        if encounter == .e1 {
            // E1 already has authored victory/loss aftermath in PR #32.
            show(WharfLadderDialogue.graph("wharf-ladder")) { [weak self] in
                guard let self else { return }
                self.acknowledge(encounter)
                self.finish()
            }
        } else {
            let ending = state.hasFlag(encounter.prefix + ".outcome.slipped") ? "crossed"
                : state.hasFlag(encounter.prefix + ".outcome.lost") ? "lost" : "won"
            show(WharfLadderDialogue.narration(encounter.rawValue + "." + ending)) { [weak self] in
                guard let self else { return }
                self.acknowledge(encounter)
                self.advance()
            }
        }
    }

    private func acknowledge(_ encounter: WharfLadderStory.Encounter) {
        scene.context.session.updateWharfStory { state, _ in WharfLadderStory.acknowledge(encounter, in: &state) }
    }

    private func show(_ graph: DialogueGraph, completion: @escaping () -> Void) {
        scene.dialogueIsActive = true
        scene.dialoguePresenter.layout(for: scene.size)
        scene.presentDialogue(graph, onComplete: completion)
    }

    private func finish() {
        clearCrew()
        scene.dialogueIsActive = false
        isActive = false
        cinematicMode = false
        scene.overlayPresentationDidChange()
        let next = completion
        completion = nil
        next?()
    }

    func setCinematicMode(_ active: Bool) {
        cinematicMode = active
        scene.overlayPresentationDidChange()
    }

    func clearCrew() {
        for actor in crew {
            scene.navigation.unregisterActor(id: actor.definition.id)
            actor.removeFromParent()
        }
        crew.removeAll()
    }

    private func stageCrew(count: Int, clerk: Bool, restoredPoints: [CGPoint]? = nil) {
        clearCrew()
        let points = restoredPoints ?? WharfLadderStaging.positions(near: scene.detective.position, count: count, navigation: scene.navigation,
                                                   ignoringActorID: scene.detective.cutsceneNavigationID)
        for (index, point) in points.enumerated() {
            var definition = CharacterDefinition.bandit
            definition.id = "wharf-ladder.crew.\(index)"
            definition.factionID = clerk ? "shipping-office" : "dock-tally"
            definition.appearance.equipment = []
            definition.appearance.colors = CharacterColors(minor: clerk ? 46 : 49, major: clerk ? 63 : UInt8(59 + index))
            do {
                let actor = try CharacterAppearanceNode(definition: definition)
                actor.position = point
                try actor.present(action: .idle, facing: .orient(from: point, to: scene.detective.position), phase: 0)
                actor.applySceneLighting(scene.area.id == WharfLadderStory.exterior ? .cityDay : .officeInterior)
                scene.depthWorldRoot.addChild(actor)
                scene.navigation.registerActor(id: definition.id, kind: .npc, at: point)
                crew.append(actor)
            } catch { assertionFailure("Wharf Ladder crew appearance: \(error)") }
        }
        if let first = points.first { scene.detective.setEntranceFacing(.orient(from: scene.detective.position, to: first)) }
    }

    func update(at time: TimeInterval) {
        for actor in crew {
            do {
                if combatDirector?.isWalking(actor.definition.id) != true && combatDirector?.isShooting(actor.definition.id) != true {
                    try actor.advance(action: .idle, facing: actor.currentFacing, at: time, paused: scene.pause.isPaused)
                }
            }
            catch { assertionFailure("Wharf Ladder crew animation: \(error)") }
            scene.applyAreaLighting(to: actor)
            scene.updateDepth(of: actor)
            scene.applyActorCover(to: actor, at: actor.position)
        }
        combatDirector?.update(at: time)
    }
}

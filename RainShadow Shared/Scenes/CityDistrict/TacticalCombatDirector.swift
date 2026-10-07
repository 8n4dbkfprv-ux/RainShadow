import SpriteKit

/// Scene adapter for the pure combat core. The turn is locked while its accepted
/// event is presented; save/reload resumes at that event's already-saved endpoint.
@MainActor
final class TacticalCombatDirector {
    private unowned let scene: CityDistrictScene
    private let crew: [CharacterAppearanceNode]
    private let completion: () -> Void
    private(set) var combat: TacticalCombat
    private let hud = SKNode()
    private let header = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let order = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let message = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let history = SKLabelNode(fontNamed: "AvenirNext-Regular")
    private let panel = SKShapeNode()
    private let turnPanel = SKShapeNode()
    private var buttons: [SKShapeNode] = []
    private let routePreview = SKShapeNode()
    private var badges: [String: SKLabelNode] = [:]
    private var rings: [String: SKShapeNode] = [:]
    private var lastTime: TimeInterval?
    private var delay: TimeInterval = 0.5
    private var movingID: String?
    private var enemyMover: Movable?
    private var movementTicks = LogicTickClock()
    private var tick = 0
    private var finished = false
    private(set) var aimingFireArrow = false
    private var playerBowNode: CharacterAppearanceNode?
    private var barrelNodes: [String: CombatBarrelVisual] = [:]
    private(set) var knockbacks: [TacticalCombat.Displacement] = []
    private(set) var knockbackElapsed: TimeInterval = 0
    private(set) var blasts: [BarrelBlastVisual] = []
    var presentedCombat: TacticalCombat { rangedShot.flatMap { $0.impactPresented ? nil : $0.before } ?? combat }
    private(set) var rangedShot: BowShotPresentation?
    func isShooting(_ id: String) -> Bool { rangedShot?.actor.definition.id == id }
    private(set) var bearNode: CharacterAppearanceNode?
    private var displayingBear = false
    private var formTransition: (toBear: Bool, elapsed: TimeInterval)?
    private var formEffect: BearTransformationEffect?
    private var bearAction: (action: CharacterVisualAction, elapsed: TimeInterval)?
    var transformationCameraOffset: CGPoint { formEffect?.cameraOffset ?? .zero }
    private var bearFacing: ActorFacing = .south
    private var feedback = "Click ground to move • Click a rival to strike"
    var busy: Bool { movingID != nil || delay > 0 || formTransition != nil || rangedShot != nil || !blasts.isEmpty || !knockbacks.isEmpty }
    func isWalking(_ id: String) -> Bool { movingID == id }

    init(scene: CityDistrictScene, combat: TacticalCombat, crew: [CharacterAppearanceNode], completion: @escaping () -> Void) {
        self.scene = scene; self.combat = combat; self.crew = crew; self.completion = completion
        hud.name = "combat.hud"; hud.zPosition = 900
        scene.hudRoot.addChild(hud)
        for shape in [panel, turnPanel] {
            shape.fillColor = SKColor(red: 0.055, green: 0.065, blue: 0.075, alpha: 0.97)
            shape.strokeColor = SKColor(red: 0.55, green: 0.45, blue: 0.28, alpha: 1)
            hud.addChild(shape)
        }
        for label in [header, order, message, history] {
            label.fontColor = .white; label.verticalAlignmentMode = .center
            hud.addChild(label)
        }
        for (name, title) in [("combat.defend", "Defend [1]"), ("combat.end", "End turn [Enter]"), ("combat.yield", "Yield [3]"), ("combat.bear", "Bear Form [4]"), ("combat.fire", "Fire arrow [5]")] {
            let button = SKShapeNode(rectOf: CGSize(width: 150, height: 44), cornerRadius: 6)
            button.name = name
            button.fillColor = SKColor(white: 0.17, alpha: 1)
            button.strokeColor = SKColor(white: 0.5, alpha: 1)
            let text = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            text.text = title; text.fontSize = 14; text.verticalAlignmentMode = .center
            button.addChild(text); hud.addChild(button); buttons.append(button)
        }
        routePreview.strokeColor = .cyan; routePreview.lineWidth = 2; routePreview.zPosition = 10000
        scene.depthWorldRoot.addChild(routePreview)
        scene.detective.cancelMovement()
        for actor in combat.actors {
            let node = actorNode(actor.id)
            node?.position = actor.position
            if actor.player { scene.detective.syncMovablePosition(actor.position) }
            let badge = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            badge.fontSize = 14; badge.position.y = 78; badge.zPosition = 100
            node?.addChild(badge); badges[actor.id] = badge
            let ring = SKShapeNode(ellipseOf: CGSize(width: 58, height: 43.5))
            ring.lineWidth = 2; ring.zPosition = -0.1
            node?.addChild(ring); rings[actor.id] = ring
            if actor.conscious { scene.navigation.updateActor(id: actor.id, position: actor.position, isMoving: false) }
            else { scene.navigation.unregisterActor(id: actor.id); node?.isHidden = true }
        }
        if combat.isBear {
            do { try prepareBear(); setDisplayedForm(true); registerPlayerFootprint() }
            catch { assertionFailure("Saved Bear Form cannot load: \(error)") }
        }
        for barrel in combat.barrels ?? [] {
            let node = CombatBarrelVisual(barrel: barrel)
            scene.depthWorldRoot.addChild(node); scene.updateDepth(of: node)
            barrelNodes[barrel.id] = node
            if !barrel.isBroken { scene.navigation.occupancy.register(OccupyingActor(id: barrel.id, kind: .npc,
                position: barrel.position, radius: 20, isBumpable: false, isMoving: false,
                personalSpaceCells: 3)) }
        }
        layout()
        refresh()
        scene.context.session.checkpointCombat(combat)
    }

    func layout() {
        let left = HUDChromeLayout.leftRailClearance(for: scene.size)
        let right = HUDChromeLayout.rightRailClearance(for: scene.size)
        let width = max(260, min(820, scene.size.width - left - right - 16))
        hud.position.x = (left - right) / 2
        let compact = width < 660
        let height: CGFloat = compact ? 230 : 130
        panel.path = CGPath(roundedRect: CGRect(x: -width / 2, y: -height / 2, width: width, height: height), cornerWidth: 8, cornerHeight: 8, transform: nil)
        panel.position.y = -scene.size.height / 2 + height / 2 + 24
        turnPanel.path = CGPath(roundedRect: CGRect(x: -width / 2, y: -30, width: width, height: 60), cornerWidth: 8, cornerHeight: 8, transform: nil)
        turnPanel.position.y = scene.size.height / 2 - 48
        header.position.y = turnPanel.position.y + 11
        order.position.y = turnPanel.position.y - 13
        message.position.y = panel.position.y + height / 2 - 22
        history.position.y = panel.position.y + height / 2 - 51
        header.fontSize = 17; order.fontSize = 13; message.fontSize = 14; history.fontSize = 12
        for label in [message, history, order] { label.preferredMaxLayoutWidth = width - 24; label.numberOfLines = 2 }
        for (i, button) in buttons.enumerated() {
            let spacing = compact ? min(162, (width - 12) / 2) : min(154, (width - 20) / 5)
            button.setScale(compact ? min(1, (width - 24) / 300) : min(1, spacing / 154))
            button.position = CGPoint(x: (CGFloat(compact ? i % 2 : i) - (compact ? 0.5 : 2)) * spacing,
                                      y: panel.position.y - height / 2 + 28 + (compact ? CGFloat(2 - i / 2) * 49 : 0))
        }
        hud.setScale(1)
    }

    private func actorNode(_ id: String) -> SKNode? {
        id == TacticalCombat.playerID ? (displayingBear ? bearNode : scene.detective) : crew.first { $0.definition.id == id }
    }
    private func refresh() {
        let shown = presentedCombat
        header.text = "ROUND \(shown.round)  •  \(shown.current.name.uppercased())\(scene.pause.isPausedByPlayer ? " — PAUSED [Space]" : "")"
        order.text = shown.actors.filter(\.conscious).map { "\($0.id == shown.current.id ? "▶ " : "")\($0.name) \($0.initiative)" }.joined(separator: "   →   ")
        let move = Int(combat.budget.availableMovement(speed: combat.movementSpeed(for: combat.current)) / 8)
        message.text = combat.isPlayerTurn
            ? "\(feedback)  |  Strike: \(combat.budget.canAttack ? "ready" : "spent") • Move: \(move) ft"
            : "\(combat.current.name) is taking their turn…"
        history.text = presentedCombat.log.suffix(2).joined(separator: "\n")
        buttons.forEach { $0.alpha = combat.isPlayerTurn && !busy ? 1 : 0.45 }
        (buttons[3].children.first as? SKLabelNode)?.text = combat.isBear ? "Revert [4]" : combat.bearForm == nil ? "Bear Form [4]" : "Bear Form spent"
        if !combat.isBear && combat.bearForm != nil { buttons[3].alpha = 0.35 }
        for actor in shown.actors {
            let shortName = actor.player ? "" : actor.name.replacingOccurrences(of: "Hand ", with: "") + " · "
            badges[actor.id]?.text = "\(shortName)\(actor.hp)/\(actor.maximumHP)\(actor.defending ? " +4" : "")"
            if actor.player, shown.isBear, let form = shown.bearForm {
                badges[actor.id]?.text = "\(actor.hp)/\(actor.maximumHP) +\(form.temporaryHP) • \(form.turnsRemaining)t"
            }
            badges[actor.id]?.fontColor = actor.player ? .cyan : SKColor(red: 1, green: 0.7, blue: 0.55, alpha: 1)
            rings[actor.id]?.strokeColor = actor.id == shown.current.id ? .yellow : actor.player ? .cyan : .red
        }
    }
    private func checkpoint(synchronize: Bool = true) {
        scene.context.session.checkpointCombat(combat)
        if synchronize { synchronizeForm() }
        routePreview.path = nil
        refresh()
    }
    func command(_ digit: Int) {
        guard combat.isPlayerTurn, !busy, !scene.pause.isPausedByPlayer else { return }
        if digit != 5 { aimingFireArrow = false; routePreview.path = nil }
        switch digit {
        case 1:
            if combat.defend() { feedback = "Guard raised. Move or end your turn."; checkpoint() }
            else { feedback = "No standard action remains."; refresh() }
        case 2:
            _ = combat.endTurn(); delay = 0.5; feedback = "Click ground to move • Click a rival to strike"; checkpoint()
        case 3:
            combat.yield(); checkpoint(); delay = 0.4
        case 4:
            if combat.isBear {
                if combat.revertBear() { checkpoint() }
                else { feedback = "Reverting needs a standard action."; refresh() }
            } else if combat.canTransform {
                guard BearFormRules.canStand(in: scene.navigation, actor: combat.current) else {
                    feedback = "Move into open space: the bear needs more room."; refresh(); return
                }
                do { try prepareBear() }
                catch { feedback = "Bear artwork could not load."; refresh(); return }
                if combat.transformToBear(hasClearance: true) { checkpoint() }
            } else { feedback = combat.bearForm == nil ? "Bear Form needs a standard action." : "Bear Form is spent for this encounter."; refresh() }
        case 5:
            guard aimingFireArrow || canUsePlayerBow() else { refresh(); return }
            aimingFireArrow.toggle()
            feedback = aimingFireArrow ? "Fire arrow: click a rival or oil barrel. Blasts hit everyone." : "Click ground to move • Click a rival to strike"
            routePreview.path = nil; refresh()
        default: break
        }
    }
    func pointer(at scenePoint: CGPoint) {
        let point = hud.convert(scenePoint, from: scene)
        for (i, button) in buttons.enumerated() where button.contains(point) { command(i + 1); return }
        if panel.contains(point) || turnPanel.contains(point) || existingChromeContains(point) { return }
        guard combat.isPlayerTurn, !busy, !scene.pause.isPausedByPlayer else { return }
        let world = scene.depthWorldRoot.convert(scenePoint, from: scene)
        if let barrel = barrel(at: world) {
            if aimingFireArrow {
                guard canUsePlayerBow() else { refresh(); return }
                shootBarrel(barrel)
            } else { smashBarrel(barrel) }
            return
        }
        if let target = combat.actors.filter({ !$0.player && $0.conscious }).min(by: {
            hypot(world.x - $0.position.x, world.y - $0.position.y - 70) < hypot(world.x - $1.position.x, world.y - $1.position.y - 70)
        }), CGRect(x: target.position.x - 48, y: target.position.y - 20, width: 96, height: 110).contains(world) {
            if aimingFireArrow { shoot(target) } else { strike(target) }
        } else if aimingFireArrow {
            feedback = "Choose a rival or oil barrel, or press 5 to cancel."; refresh()
        } else if let path = CombatNavigation.route(in: scene.navigation, actor: combat.current, to: world, bear: combat.isBear) {
            if !move(path) { feedback = "That destination exceeds your movement allowance."; refresh() }
        } else { feedback = "No clear route to that point."; refresh() }
    }
    func hover(at scenePoint: CGPoint) {
        guard combat.isPlayerTurn, !busy else { routePreview.path = nil; return }
        let hudPoint = hud.convert(scenePoint, from: scene)
        guard !panel.contains(hudPoint), !turnPanel.contains(hudPoint), !existingChromeContains(hudPoint) else { routePreview.path = nil; return }
        let world = scene.depthWorldRoot.convert(scenePoint, from: scene)
        if let barrel = barrel(at: world) { preview(barrel); return }
        if aimingFireArrow { routePreview.path = nil; return }
        guard let path = CombatNavigation.route(in: scene.navigation, actor: combat.current, to: world, bear: combat.isBear) else {
            routePreview.path = nil; return
        }
        let drawing = CGMutablePath(); drawing.move(to: combat.current.position)
        path.remainingPoints.forEach { drawing.addLine(to: $0) }
        routePreview.path = drawing
        routePreview.strokeColor = CombatNavigation.length(path, from: combat.current.position)
            <= combat.budget.availableMovement(speed: combat.movementSpeed(for: combat.current)) ? .cyan : .red
    }
    private func existingChromeContains(_ point: CGPoint) -> Bool {
        let rootPoint = scene.hudRoot.convert(point, from: hud)
        return HUDChromeLayout.leftRailLayout(for: scene.size).plateFrame.contains(rootPoint)
            || HUDChromeLayout.rightRailPlateFrame(for: scene.size).contains(rootPoint)
    }
    @discardableResult private func move(_ path: Path) -> Bool {
        let actor = combat.current
        guard combat.move(along: path) else { return false }
        movingID = actor.id
        feedback = "Click ground to move • Click a rival to strike"
        checkpoint()
        if actor.player && !combat.isBear {
            scene.detective.walk(path: path, completeWhenStopped: true) { [weak self] in self?.movementCompleted() }
        } else {
            // The route was certified with actors blocking. Other combatants stay
            // stationary, so playback uses the port's integral DoStep without bumping them.
            var mover = Movable(identity: actor.id, position: actor.position)
            mover.adopt(path); enemyMover = mover
            movementTicks.reset(); tick = 0
        }
        return true
    }
    private func movementCompleted() {
        guard let id = movingID else { return }
        // If the existing mover stopped early, keep its actual position; the
        // accepted movement budget is still spent, never teleport through a blocker.
        if let point = actorNode(id)?.position { combat.reconcilePosition(id: id, point: point) }
        movingID = nil; enemyMover = nil; delay = 0.35
        if let actor = combat.actors.first(where: { $0.id == id }) {
            scene.navigation.updateActor(id: id, position: actor.position, isMoving: false)
        }
        checkpoint()
    }
    private func strike(_ target: Combatant) {
        let attacker = combat.current
        let wasBear = combat.isBear
        let line = CombatNavigation.clearLine(in: scene.navigation, from: attacker.position, to: target.position, excluding: [attacker.id, target.id])
        guard let result = combat.attack(target: target.id, clearLine: line) else {
            feedback = combat.budget.canAttack ? "Move closer with a clear line before striking." : "No standard action remains."
            refresh(); return
        }
        if attacker.player { scene.detective.setEntranceFacing(.orient(from: attacker.position, to: target.position)) }
        else if let node = actorNode(attacker.id) as? CharacterAppearanceNode {
            try? node.present(action: .idle, facing: .orient(from: attacker.position, to: target.position), phase: 0)
        }
        delay = 0.85
        if attacker.player && wasBear {
            bearFacing = .orient(from: attacker.position, to: target.position)
            bearAction = (.attack, 0)
        } else if target.player && wasBear && combat.isBear && result.damage > 0 {
            bearAction = (.hit, 0)
        }
        checkpoint()
        presentImpact(result, target: target)
    }
    private func presentImpact(_ result: TacticalCombat.Strike, target: Combatant) {
        // Impact is immediate for melee and delayed until arrow arrival for bows.
        let effect = SKShapeNode(ellipseOf: CGSize(width: 52, height: 38))
        effect.position = CGPoint(x: target.position.x, y: target.position.y + 45)
        effect.strokeColor = result.damage > 0 ? .orange : .white; effect.lineWidth = 3; effect.zPosition = 20000
        scene.depthWorldRoot.addChild(effect)
        effect.run(.sequence([.group([.scale(to: 1.8, duration: 0.3), .fadeOut(withDuration: 0.4)]), .removeFromParent()]))
        let number = SKLabelNode(fontNamed: "AvenirNext-Bold")
        number.text = result.damage > 0 ? "−\(result.damage)" : "MISS"
        number.fontSize = 26; number.position = CGPoint(x: target.position.x, y: target.position.y + 95); number.zPosition = 20001
        scene.depthWorldRoot.addChild(number)
        number.run(.sequence([.group([.moveBy(x: 0, y: 35, duration: 0.7), .fadeOut(withDuration: 0.8)]), .removeFromParent()]))
        if result.knockedOut {
            scene.navigation.unregisterActor(id: target.id)
            actorNode(target.id)?.isHidden = true
        }
    }
    private func shoot(_ target: Combatant) {
        let attacker = combat.current
        guard let node = bowActor(for: attacker) else { return }
        let line = CombatNavigation.clearLine(in: scene.navigation, from: attacker.position, to: target.position,
            excluding: [attacker.id, target.id])
        let before = combat
        guard let result = combat.attack(target: target.id, clearLine: line, ranged: true) else {
            feedback = "Fire arrow needs a standard action, range beyond melee, and a clear shot."; refresh(); return
        }
        beginBowPresentation(attacker)
        rangedShot = BowShotPresentation(before: before, result: result, target: target, actor: node,
            parent: scene.depthWorldRoot, targetHeight: (before.isBear ? 30 : 54) + scene.detective.visualHeightOffset)
        delay = 0.25
        // Save the accepted outcome, but reveal its damage/form changes at impact.
        checkpoint(synchronize: false)
    }
    private func canUsePlayerBow() -> Bool {
        guard !combat.isBear, combat.current.rangedWeapon == .bow else {
            feedback = "Fire arrows require human form and a bow."; return false
        }
        guard !VossArmorAppearance.allCases.contains(where: { $0.isEquipped(in: scene.context.session.characterInventory) }) else {
            feedback = "This bow clip supports unarmored Voss. Change armor before combat."; return false
        }
        return true
    }
    private func bowActor(for actor: Combatant) -> CharacterAppearanceNode? {
        guard actor.player else { return actorNode(actor.id) as? CharacterAppearanceNode }
        guard canUsePlayerBow() else { refresh(); return nil }
        if playerBowNode == nil {
            var definition = CharacterDefinition.voss
            definition.appearance.equipment = [.init(item: .elvenCourtBow), .init(item: .elvenCourtArrow)]
            do {
                let node = try CharacterAppearanceNode(definition: definition)
                node.isHidden = true
                node.applySceneLighting(scene.area.id == WharfLadderStory.exterior ? .cityDay : .officeInterior)
                scene.depthWorldRoot.addChild(node); playerBowNode = node
            } catch { feedback = "Bow artwork could not load."; refresh(); return nil }
        }
        playerBowNode?.position = actor.position
        playerBowNode?.visualHeightOffset = scene.detective.visualHeightOffset
        if let node = playerBowNode { scene.updateDepth(of: node); scene.applyActorCover(to: node, at: actor.position) }
        return playerBowNode
    }
    private func beginBowPresentation(_ actor: Combatant) {
        aimingFireArrow = false
        feedback = "Click ground to move • Click a rival to strike"
        if actor.player {
            scene.detective.isHidden = true; playerBowNode?.isHidden = false
            for decoration in [badges[actor.id], rings[actor.id]] as [SKNode?] {
                decoration?.removeFromParent()
                if let decoration { playerBowNode?.addChild(decoration) }
            }
        }
    }
    private func barrel(at point: CGPoint) -> CombatBarrel? {
        combat.liveBarrels.first { CGRect(x: $0.position.x - 26, y: $0.position.y - 8,
                                         width: 52, height: $0.isBroken ? 40 : 68).contains(point) }
    }
    private func blastVisible(_ from: CGPoint, _ to: CGPoint) -> Bool {
        CombatNavigation.clearLine(in: scene.navigation, from: from, to: to,
                                   excluding: Array(scene.navigation.occupancy.actors.keys))
    }
    private func preview(_ barrel: CombatBarrel) {
        let path = CGMutablePath()
        for item in combat.explosionChain(startingAt: barrel.id, visible: blastVisible) {
            path.addEllipse(in: CGRect(x: item.position.x - 120, y: item.position.y - 90, width: 240, height: 180))
        }
        routePreview.path = path; routePreview.strokeColor = .orange
    }
    private func smashBarrel(_ barrel: CombatBarrel) {
        let clear = CombatNavigation.clearLine(in: scene.navigation, from: combat.current.position,
            to: barrel.position, excluding: [combat.current.id, barrel.id])
        guard combat.breakBarrel(barrel.id, clearLine: clear) else {
            feedback = barrel.isBroken ? "Oil spill: use Fire arrow [5] to ignite it."
                : "Move within melee reach to break it, or use Fire arrow [5]."
            refresh(); return
        }
        if let updated = combat.barrels?.first(where: { $0.id == barrel.id }) { barrelNodes[barrel.id]?.apply(updated) }
        scene.navigation.unregisterActor(id: barrel.id)
        if combat.isBear { bearFacing = .orient(from: combat.current.position, to: barrel.position); bearAction = (.attack, 0) }
        else { scene.detective.setEntranceFacing(.orient(from: combat.current.position, to: barrel.position)) }
        feedback = "Barrel broken. The spilled oil can still ignite."
        delay = 0.3; checkpoint()
    }
    private func shootBarrel(_ barrel: CombatBarrel) {
        let attacker = combat.current
        guard let node = bowActor(for: attacker) else { return }
        let before = combat
        let clear = CombatNavigation.clearLine(in: scene.navigation, from: attacker.position,
            to: barrel.position, excluding: [attacker.id, barrel.id])
        guard let explosions = combat.igniteBarrel(barrel.id, clearShot: clear, visible: blastVisible) else {
            feedback = "Fire arrow needs a standard action, range beyond melee, and a clear shot."; refresh(); return
        }
        let displacements = combat.applyExplosionKnockback(explosions) { actor, source, actors in
            CombatNavigation.knockbackDestination(in: scene.navigation, actor: actor, awayFrom: source,
                actors: actors, destroyedBarrels: explosions.map { $0.barrel.id }, bear: actor.player && before.isBear)
        }
        beginBowPresentation(attacker)
        let target = Combatant(id: barrel.id, name: barrel.name, player: !attacker.player,
            position: barrel.position, hp: 1, maximumHP: 1, defence: 0, attackBonus: 0,
            damageMin: 1, damageMax: 1, initiativeBonus: 0)
        rangedShot = BowShotPresentation(before: before,
            result: .init(attacker: attacker.id, target: barrel.id, roll: 0, damage: 1, knockedOut: true),
            target: target, actor: node, parent: scene.depthWorldRoot, targetHeight: barrel.isBroken ? 4 : 32, explosions: explosions, displacements: displacements)
        delay = 0.25; checkpoint(synchronize: false)
    }
    private func usefulBarrel(for actor: Combatant) -> CombatBarrel? {
        guard combat.budget.canAttack else { return nil }
        return combat.liveBarrels.first { barrel in
            let distance = CombatNavigation.distance(actor.position, barrel.position)
            guard distance > TacticalCombat.meleeReach && distance <= BowAttackRules.range,
                CombatNavigation.clearLine(in: scene.navigation, from: actor.position, to: barrel.position,
                                           excluding: [actor.id, barrel.id]) else { return false }
            let chain = combat.explosionChain(startingAt: barrel.id, visible: blastVisible)
            let hit = combat.actors.filter { candidate in candidate.conscious && chain.contains {
                CombatNavigation.distance($0.position, candidate.position) <= CombatBarrel.blastRadius
                    && blastVisible($0.position, candidate.position)
            } }
            return hit.contains { $0.player != actor.player } && !hit.contains { $0.player == actor.player }
        }
    }
    private func equipLookout(_ actor: Combatant, bow: Bool) {
        guard let node = actorNode(actor.id) as? CharacterAppearanceNode else { return }
        var definition = node.definition
        definition.appearance.equipment = bow ? [.init(item: .elvenCourtBow), .init(item: .elvenCourtArrow)]
            : [.init(item: .lanternShortsword)]
        try? node.apply(definition)
    }
    private func enemyTurn() {
        guard let target = combat.actors.first(where: { $0.player && $0.conscious }) else { return }
        let actor = combat.current
        let distance = CombatNavigation.distance(actor.position, target.position)
        if actor.rangedWeapon == .bow {
            if let barrel = usefulBarrel(for: actor) { equipLookout(actor, bow: true); shootBarrel(barrel); return }
            equipLookout(actor, bow: distance > TacticalCombat.meleeReach)
            if combat.budget.canAttack, BowAttackRules.canShoot(attacker: actor, target: target,
                clearLine: CombatNavigation.clearLine(in: scene.navigation, from: actor.position, to: target.position,
                    excluding: [actor.id, target.id])) { shoot(target); return }
            if combat.budget.canAttack, distance > TacticalCombat.meleeReach,
               let path = CombatNavigation.firingPosition(in: scene.navigation, actor: actor, target: target,
                   limit: min(actor.speed, combat.budget.availableMovement(speed: actor.speed))), move(path) { return }
        }
        if combat.budget.canAttack,
           CombatNavigation.distance(actor.position, target.position) <= TacticalCombat.meleeReach,
           CombatNavigation.clearLine(in: scene.navigation, from: actor.position, to: target.position, excluding: [actor.id, target.id]) {
            strike(target); return
        }
        // Spend only movement needed to approach; avoid wandering after attacking.
        if combat.budget.canAttack,
           let path = CombatNavigation.approach(in: scene.navigation, actor: actor, target: target,
                   limit: combat.budget.availableMovement(speed: actor.speed)), move(path) { return }
        _ = combat.endTurn(); delay = 0.5; checkpoint()
    }
    func update(at time: TimeInterval) {
        defer { lastTime = time }
        guard !finished else { return }
        let delta = min(0.1, max(0, time - (lastTime ?? time)))
        refresh()
        formEffect?.setPaused(scene.pause.isPausedByPlayer)
        guard !scene.pause.isPausedByPlayer else { return }
        for blast in blasts { blast.advance(delta: delta) }
        blasts.filter(\.finished).forEach { $0.removeFromParent() }
        blasts.removeAll(where: \.finished)
        if let shot = rangedShot {
            shot.advance(delta: delta)
            if shot.elapsed >= shot.impactTime && !shot.impactPresented {
                shot.impactPresented = true
                if shot.before.isBear && combat.isBear && shot.result.damage > 0 { bearAction = (.hit, 0) }
                if shot.explosions.isEmpty { presentImpact(shot.result, target: shot.target) }
                else {
                    for explosion in shot.explosions {
                        if let remains = combat.barrels?.first(where: { $0.id == explosion.barrel.id }) {
                            barrelNodes[remains.id]?.apply(remains)
                        }
                        scene.navigation.unregisterActor(id: explosion.barrel.id)
                        let blast = BarrelBlastVisual(at: explosion.barrel.position)
                        scene.depthWorldRoot.addChild(blast); blasts.append(blast)
                        for hit in explosion.hits {
                            if let target = shot.before.actors.first(where: { $0.id == hit.target }) { presentImpact(hit, target: target) }
                        }
                    }
                }
                knockbacks = shot.displacements; knockbackElapsed = 0
                synchronizeForm()
                refresh()
            }
            if shot.finished {
                shot.stop(); rangedShot = nil
                playerBowNode?.isHidden = true
                if shot.before.current.player {
                    for decoration in [badges[TacticalCombat.playerID], rings[TacticalCombat.playerID]] as [SKNode?] {
                        decoration?.removeFromParent()
                        if let decoration { actorNode(TacticalCombat.playerID)?.addChild(decoration) }
                    }
                }
                scene.detective.isHidden = displayingBear || !combat.actors.first(where: \.player)!.conscious
            }
        }
        advanceKnockback(delta: delta)
        updateForm(delta: delta, time: time)
        if var mover = enemyMover, let id = movingID, let node = actorNode(id) as? CharacterAppearanceNode {
            for _ in 0..<movementTicks.drain(deltaTime: delta) {
                tick += 1
                _ = mover.doStep(walkScale: MovementProfile.humanoid.walkScale ?? 0, time: tick)
                if !mover.isMoving { break }
            }
            node.position = mover.position
            if id == TacticalCombat.playerID {
                scene.detective.position = mover.position
                scene.detective.syncMovablePosition(mover.position)
                bearFacing = mover.orientation
            } else {
                try? node.advance(action: mover.isMoving ? .walk : .idle, facing: mover.orientation, at: time, paused: false)
            }
            scene.navigation.updateActor(id: id, position: node.position, isMoving: mover.isMoving)
            enemyMover = mover
            if !mover.isMoving { movementCompleted() }
        }
        guard movingID == nil, formTransition == nil, rangedShot == nil, blasts.isEmpty, knockbacks.isEmpty else { return }
        delay = max(0, delay - delta)
        guard delay == 0 else { return }
        if combat.outcome != nil { finish(); return }
        if !combat.isPlayerTurn { enemyTurn() }
    }
    private func advanceKnockback(delta: TimeInterval) {
        guard !knockbacks.isEmpty else { return }
        knockbackElapsed += delta
        let t = min(1, knockbackElapsed / 0.35)
        let ease = CGFloat(1 - pow(1 - t, 3))
        for move in knockbacks {
            let point = CGPoint(x: move.from.x + (move.to.x - move.from.x) * ease,
                                y: move.from.y + (move.to.y - move.from.y) * ease).rounded
            var nodes = [actorNode(move.id)].compactMap { $0 }
            if move.id == TacticalCombat.playerID {
                scene.detective.position = point; scene.detective.syncMovablePosition(point)
                formEffect?.position = point
                nodes += [bearNode, playerBowNode].compactMap { $0 }
            }
            for node in nodes {
                node.position = point; scene.updateDepth(of: node)
                if let character = node as? CharacterAppearanceNode { scene.applyActorCover(to: character, at: point) }
            }
            // Turns remain locked; reserve the accepted endpoint throughout presentation.
            scene.navigation.updateActor(id: move.id, position: move.to, isMoving: false)
        }
        if t >= 1 { knockbacks.removeAll() }
    }
    func finish() {
        guard !finished, combat.outcome != nil else { return }
        finished = true
        scene.context.session.finishCombat(combat)
        hud.removeFromParent(); routePreview.removeFromParent()
        badges.values.forEach { $0.removeFromParent() }; rings.values.forEach { $0.removeFromParent() }
        rangedShot?.stop(); rangedShot = nil
        playerBowNode?.removeFromParent()
        for (id, node) in barrelNodes {
            if combat.barrels?.first(where: { $0.id == id })?.isBroken != true { node.removeFromParent() }
            scene.navigation.unregisterActor(id: id)
        }
        barrelNodes.removeAll()
        blasts.forEach { $0.removeFromParent() }; blasts.removeAll()
        bearNode?.removeFromParent(); formEffect?.stop()
        scene.detective.alpha = 1
        scene.detective.isHidden = false
        scene.navigation.registerActor(id: TacticalCombat.playerID, kind: .player, at: scene.detective.position, radius: NavigationAgentProfile.detective.radius)
        completion()
    }

    private func prepareBear() throws {
        guard bearNode == nil else { return }
        let node = try CharacterAppearanceNode(definition: .init(id: "combat.bear.visual",
            classID: nil, factionID: nil, appearance: .init(body: .bearGuardian)))
        node.isHidden = true
        node.applySceneLighting(scene.area.id == WharfLadderStory.exterior ? .cityDay : .officeInterior)
        scene.depthWorldRoot.addChild(node)
        bearNode = node
    }

    private func registerPlayerFootprint() {
        scene.navigation.registerActor(id: TacticalCombat.playerID, kind: .player, at: scene.detective.position,
            radius: combat.isBear ? BearFormRules.radius : NavigationAgentProfile.detective.radius,
            personalSpaceCells: combat.isBear ? BearFormRules.circleSize : ActorLocomotionPacing.personalSpaceCells)
    }

    private func setDisplayedForm(_ bear: Bool) {
        displayingBear = bear
        scene.detective.isHidden = bear
        bearNode?.isHidden = !bear
        bearNode?.position = scene.detective.position
        let node = actorNode(TacticalCombat.playerID)
        for decoration in [badges[TacticalCombat.playerID], rings[TacticalCombat.playerID]] as [SKNode?] {
            decoration?.removeFromParent()
            if let decoration { node?.addChild(decoration) }
        }
        rings[TacticalCombat.playerID]?.setScale(bear ? 1.4 : 1)
        if !bear { scene.detective.setEntranceFacing(bearFacing) }
    }

    private func synchronizeForm() {
        guard combat.isBear != displayingBear, formTransition == nil else { return }
        registerPlayerFootprint()
        bearFacing = displayingBear ? bearFacing : scene.detective.currentFacing
        formTransition = (combat.isBear, 0)
        if displayingBear { bearAction = (.revert, 0) }
        let effect = BearTransformationEffect(reverting: !combat.isBear)
        effect.position = scene.detective.position
        scene.depthWorldRoot.addChild(effect)
        effect.captureSilhouette(of: displayingBear ? bearNode! : scene.detective)
        formEffect = effect
        delay = max(delay, 0.3)
    }

    private func updateForm(delta: TimeInterval, time: TimeInterval) {
        if var transition = formTransition {
            transition.elapsed += delta
            formEffect?.advance(to: transition.elapsed)
            let t = transition.elapsed
            let reveal = BearTransformationEffect.revealTime
            // Fade the outgoing actor beneath the rising texture fragments and
            // mist. At the switch both bodies are invisible; no naked pop.
            let visible = actorNode(TacticalCombat.playerID)
            if t < reveal {
                visible?.alpha = 1 - BearTransformationEffect.ramp(t, 0.30, reveal)
            } else {
                if displayingBear != transition.toBear {
                    scene.detective.alpha = 1; bearNode?.alpha = 1
                    setDisplayedForm(transition.toBear)
                    bearAction = nil
                }
                actorNode(TacticalCombat.playerID)?.alpha = BearTransformationEffect.ramp(t, reveal, 0.96)
            }
            if t >= BearTransformationEffect.duration {
                scene.detective.alpha = 1; bearNode?.alpha = 1
                formTransition = nil; formEffect?.stop(); formEffect = nil
            } else { formTransition = transition }
        }
        guard displayingBear, let bearNode else { return }
        bearNode.position = scene.detective.position
        if let transition = formTransition, transition.toBear {
            // Reverse the authored crouch, retaining every frame's ground pivot.
            let rise = BearTransformationEffect.ramp(transition.elapsed, BearTransformationEffect.revealTime, 1.30)
            try? bearNode.present(action: .revert, facing: bearFacing, phase: min(9, max(0, Int((1 - rise) * 9))))
        } else if var action = bearAction {
            action.elapsed += delta
            let count = (try? BearAnimationSet.frameCount(for: action.action)) ?? 1
            let frame = min(count - 1, Int(action.elapsed * 15))
            try? bearNode.present(action: action.action, facing: bearFacing, phase: frame)
            bearAction = action.elapsed >= Double(count) / 15 ? nil : action
        } else {
            try? bearNode.advance(action: movingID == TacticalCombat.playerID ? .walk : .idle,
                                  facing: bearFacing, at: time, paused: false)
        }
        scene.applyAreaLighting(to: bearNode)
        scene.updateDepth(of: bearNode)
        scene.applyActorCover(to: bearNode, at: bearNode.position)
    }
}

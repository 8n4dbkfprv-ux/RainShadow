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
    private var feedback = "Click ground to move • Click a rival to strike"
    var busy: Bool { movingID != nil || delay > 0 }
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
        for (name, title) in [("combat.defend", "Defend [1]"), ("combat.end", "End turn [Enter]"), ("combat.yield", "Yield [3]")] {
            let button = SKShapeNode(rectOf: CGSize(width: 150, height: 36), cornerRadius: 6)
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
        layout()
        refresh()
        scene.context.session.checkpointCombat(combat)
    }

    func layout() {
        let width = max(320, min(820, scene.size.width - 170))
        panel.path = CGPath(roundedRect: CGRect(x: -width / 2, y: -62, width: width, height: 124), cornerWidth: 8, cornerHeight: 8, transform: nil)
        panel.position.y = -scene.size.height / 2 + 92
        turnPanel.path = CGPath(roundedRect: CGRect(x: -width / 2, y: -30, width: width, height: 60), cornerWidth: 8, cornerHeight: 8, transform: nil)
        turnPanel.position.y = scene.size.height / 2 - 48
        header.position.y = turnPanel.position.y + 11
        order.position.y = turnPanel.position.y - 13
        message.position.y = panel.position.y + 38
        history.position.y = panel.position.y + 10
        for (i, button) in buttons.enumerated() {
            button.position = CGPoint(x: CGFloat(i - 1) * 162, y: panel.position.y - 31)
        }
        header.fontSize = 17; order.fontSize = 13; message.fontSize = 14; history.fontSize = 12
        for label in [message, history, order] { label.preferredMaxLayoutWidth = width - 24; label.numberOfLines = 2 }
        let buttonScale = min(1, (width - 28) / 474)
        for (i, button) in buttons.enumerated() {
            button.setScale(buttonScale)
            button.position.x = CGFloat(i - 1) * 162 * buttonScale
        }
        hud.setScale(1)
    }

    private func actorNode(_ id: String) -> SKNode? {
        id == TacticalCombat.playerID ? scene.detective : crew.first { $0.definition.id == id }
    }
    private func refresh() {
        header.text = "ROUND \(combat.round)  •  \(combat.current.name.uppercased())\(scene.pause.isPausedByPlayer ? " — PAUSED [Space]" : "")"
        order.text = combat.actors.filter(\.conscious).map { "\($0.id == combat.current.id ? "▶ " : "")\($0.name) \($0.initiative)" }.joined(separator: "   →   ")
        let move = Int(combat.budget.availableMovement(speed: combat.current.speed) / 8)
        message.text = combat.isPlayerTurn
            ? "\(feedback)  |  Strike: \(combat.budget.canAttack ? "ready" : "spent") • Move: \(move) ft"
            : "\(combat.current.name) is taking their turn…"
        history.text = combat.log.suffix(2).joined(separator: "\n")
        buttons.forEach { $0.alpha = combat.isPlayerTurn && !busy ? 1 : 0.45 }
        for actor in combat.actors {
            let shortName = actor.player ? "" : actor.name.replacingOccurrences(of: "Hand ", with: "") + " · "
            badges[actor.id]?.text = "\(shortName)\(actor.hp)/\(actor.maximumHP)\(actor.defending ? " +4" : "")"
            badges[actor.id]?.fontColor = actor.player ? .cyan : SKColor(red: 1, green: 0.7, blue: 0.55, alpha: 1)
            rings[actor.id]?.strokeColor = actor.id == combat.current.id ? .yellow : actor.player ? .cyan : .red
        }
    }
    private func checkpoint() {
        scene.context.session.checkpointCombat(combat)
        routePreview.path = nil
        refresh()
    }
    func command(_ digit: Int) {
        guard combat.isPlayerTurn, !busy, !scene.pause.isPausedByPlayer else { return }
        switch digit {
        case 1:
            if combat.defend() { feedback = "Guard raised. Move or end your turn."; checkpoint() }
            else { feedback = "No standard action remains."; refresh() }
        case 2:
            _ = combat.endTurn(); delay = 0.5; feedback = "Click ground to move • Click a rival to strike"; checkpoint()
        case 3:
            combat.yield(); checkpoint(); delay = 0.4
        default: break
        }
    }
    func pointer(at scenePoint: CGPoint) {
        let point = hud.convert(scenePoint, from: scene)
        for (i, button) in buttons.enumerated() where button.contains(point) { command(i + 1); return }
        if panel.contains(point) || turnPanel.contains(point) || existingChromeContains(point) { return }
        guard combat.isPlayerTurn, !busy, !scene.pause.isPausedByPlayer else { return }
        let world = scene.depthWorldRoot.convert(scenePoint, from: scene)
        if let target = combat.actors.filter({ !$0.player && $0.conscious }).min(by: {
            hypot(world.x - $0.position.x, world.y - $0.position.y - 70) < hypot(world.x - $1.position.x, world.y - $1.position.y - 70)
        }), CGRect(x: target.position.x - 48, y: target.position.y - 20, width: 96, height: 110).contains(world) {
            strike(target)
        } else if let path = CombatNavigation.route(in: scene.navigation, actor: combat.current, to: world) {
            if !move(path) { feedback = "That destination exceeds your movement allowance."; refresh() }
        } else { feedback = "No clear route to that point."; refresh() }
    }
    func hover(at scenePoint: CGPoint) {
        guard combat.isPlayerTurn, !busy else { routePreview.path = nil; return }
        let hudPoint = hud.convert(scenePoint, from: scene)
        guard !panel.contains(hudPoint), !turnPanel.contains(hudPoint), !existingChromeContains(hudPoint) else { routePreview.path = nil; return }
        let world = scene.depthWorldRoot.convert(scenePoint, from: scene)
        guard let path = CombatNavigation.route(in: scene.navigation, actor: combat.current, to: world) else {
            routePreview.path = nil; return
        }
        let drawing = CGMutablePath(); drawing.move(to: combat.current.position)
        path.remainingPoints.forEach { drawing.addLine(to: $0) }
        routePreview.path = drawing
        routePreview.strokeColor = CombatNavigation.length(path, from: combat.current.position)
            <= combat.budget.availableMovement(speed: combat.current.speed) ? .cyan : .red
    }
    private func existingChromeContains(_ point: CGPoint) -> Bool {
        HUDChromeLayout.leftRailLayout(for: scene.size).plateFrame.contains(point)
            || HUDChromeLayout.rightRailPlateFrame(for: scene.size).contains(point)
    }
    @discardableResult private func move(_ path: Path) -> Bool {
        let actor = combat.current
        guard combat.move(along: path) else { return false }
        movingID = actor.id
        feedback = "Click ground to move • Click a rival to strike"
        checkpoint()
        if actor.player {
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
        checkpoint()
        // Explicit abstract impact feedback. Approved sprite payloads stay intact.
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
    private func enemyTurn() {
        guard let target = combat.actors.first(where: { $0.player && $0.conscious }) else { return }
        let actor = combat.current
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
        guard !scene.pause.isPausedByPlayer else { return }
        if var mover = enemyMover, let id = movingID, let node = actorNode(id) as? CharacterAppearanceNode {
            for _ in 0..<movementTicks.drain(deltaTime: delta) {
                tick += 1
                _ = mover.doStep(walkScale: MovementProfile.humanoid.walkScale ?? 0, time: tick)
                if !mover.isMoving { break }
            }
            node.position = mover.position
            try? node.advance(action: mover.isMoving ? .walk : .idle, facing: mover.orientation, at: time, paused: false)
            scene.navigation.updateActor(id: id, position: node.position, isMoving: mover.isMoving)
            enemyMover = mover
            if !mover.isMoving { movementCompleted() }
        }
        guard movingID == nil else { return }
        delay = max(0, delay - delta)
        guard delay == 0 else { return }
        if combat.outcome != nil { finish(); return }
        if !combat.isPlayerTurn { enemyTurn() }
    }
    func finish() {
        guard !finished, combat.outcome != nil else { return }
        finished = true
        scene.context.session.finishCombat(combat)
        hud.removeFromParent(); routePreview.removeFromParent()
        badges.values.forEach { $0.removeFromParent() }; rings.values.forEach { $0.removeFromParent() }
        scene.detective.isHidden = false
        scene.navigation.registerActor(id: TacticalCombat.playerID, kind: .player, at: scene.detective.position, radius: NavigationAgentProfile.detective.radius)
        completion()
    }
}

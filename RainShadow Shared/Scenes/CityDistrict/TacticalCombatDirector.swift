import SpriteKit
import AVFoundation

/// Scene adapter for the pure combat core. The turn is locked while its accepted
/// event is presented; save/reload resumes at that event's already-saved endpoint.
@MainActor
final class TacticalCombatDirector {
    private unowned let scene: CityDistrictScene
    private let crew: [CharacterAppearanceNode]
    private let completion: () -> Void
    private(set) var combat: TacticalCombat
    private let hud = SKNode()
    let initiativeBar = CombatInitiativeBar()
    private let message = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let history = SKLabelNode(fontNamed: "AvenirNext-Regular")
    private let panel = SKShapeNode()
    private let turnPanel = SKShapeNode()
    private var buttons: [SKShapeNode] = []
    private var laidOutBearForm: Bool?
    var visibleCombatCommands: [String] { activeButtons.compactMap(\.name) }
    private var activeButtons: [SKShapeNode] {
        combat.isBear ? [14, 15, 3, 0, 11, 1, 2].map { buttons[$0] } : Array(buttons.prefix(14))
    }
    private let routePreview = SKShapeNode()
    private let sightPreview = SKNode()
    private var showingSight = false
    private(set) var selectingSneakAttack = false
    private var badges: [String: SKLabelNode] = [:]
    private var rings: [String: SKShapeNode] = [:]
    private(set) var defeatNodes: [String: CharacterAppearanceNode] = [:]
    private(set) var defeats: [String: CombatDefeatMotion] = [:]
    var defeatsAnimating: Bool { defeats.values.contains { !$0.finished } }
    private(set) var hitReactions: [String: CombatRecoil] = [:]
    private var reactionFacings: [String: (start: ActorFacing, rest: ActorFacing)] = [:]
    private(set) var reactionNodes: [String: CharacterAppearanceNode] = [:]
    private(set) var stealthNodes: [String: CharacterAppearanceNode] = [:]
    private(set) var hideTransitions: [String: TimeInterval] = [:]
    private var stealthTime: TimeInterval = 0
    private var stealthTravel: [String: Double] = [:]
    private var stealthPositions: [String: CGPoint] = [:]
    private var preSneakMovementProfile: MovementProfile?
    private(set) var burningNodes: [String: CharacterBurningVisual] = [:]
    private var fireTime: TimeInterval = 0
    private var lastTime: TimeInterval?
    private var delay: TimeInterval = 0.5
    private var movingID: String?
    private var enemyMover: Movable?
    private var movementTicks = LogicTickClock()
    private var tick = 0
    private var finished = false
    private(set) var selectedManeuver: CombatManeuver?
    private(set) var selectingShove = false
    struct ShovePresentation {
        let before: TacticalCombat
        let result: TacticalCombat.Shove
        let target: Combatant
        let node: CharacterAppearanceNode
        let facing: ActorFacing
        var elapsed = 0.0
        var impactPresented = false
    }
    private(set) var shovePresentation: ShovePresentation?
    private(set) var aimingFireArrow = false
    private(set) var selectingClaw = false
    struct BearAbilityPresentation {
        let before: TacticalCombat
        let action: CharacterVisualAction
        let strike: TacticalCombat.Strike?
        let targets: [Combatant]
        var elapsed = 0.0
        var impactPresented = false
        var impactTime: Double { action == .roar ? BearFormRules.roarImpactTime : BearFormRules.clawImpactTime }
        var duration: Double { action == .roar ? BearFormRules.roarDuration : BearFormRules.clawDuration }
    }
    private(set) var bearAbility: BearAbilityPresentation?
    private var roarWaves: [SKShapeNode] = []
    private var roarSound: AVAudioPlayer?
    var roarSoundIsPlaying: Bool { roarSound?.isPlaying == true }
    private var playerBowNode: CharacterAppearanceNode?
    private var playerMeleeNode: CharacterAppearanceNode?
    private(set) var barrelNodes: [String: CombatBarrelVisual] = [:]
    private(set) var knockbacks: [TacticalCombat.Displacement] = []
    private(set) var knockbackElapsed: TimeInterval = 0
    private(set) var blasts: [BarrelBlastVisual] = []
    var presentedCombat: TacticalCombat {
        bearAbility.flatMap { $0.impactPresented ? nil : $0.before }
            ?? shovePresentation.flatMap { $0.impactPresented ? nil : $0.before }
            ?? meleeAttack.flatMap { $0.impactPresented ? nil : $0.before }
            ?? rangedShot.flatMap { $0.impactPresented ? nil : $0.before } ?? combat
    }
    private(set) var meleeAttack: MeleeAttackPresentation?
    func isStriking(_ id: String) -> Bool { bearAbility?.before.current.id == id || meleeAttack?.before.current.id == id || shovePresentation?.before.current.id == id }
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
    var debrisMoving: Bool { barrelNodes.values.contains { $0.isSimulating } }
    /// Held Prone poses remain visible without blocking other actors' turns.
    private var reactionsAnimating: Bool {
        hitReactions.contains { id, reaction in
            !(presentedCombat.actors.contains { $0.id == id && $0.isProne }
                && reaction.kind == .tripFall && reaction.elapsed >= ProneMotion.holdTime)
        }
    }
    var busy: Bool { bearAbility != nil || bearAction != nil || shovePresentation != nil || defeatsAnimating || !hideTransitions.isEmpty || movingID != nil || delay > 0 || formTransition != nil || rangedShot != nil || meleeAttack != nil || !blasts.isEmpty || !knockbacks.isEmpty || debrisMoving || reactionsAnimating }
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
        turnPanel.fillColor = .clear; turnPanel.strokeColor = .clear
        hud.addChild(initiativeBar)
        for label in [message, history] {
            label.fontColor = .white; label.verticalAlignmentMode = .center
            hud.addChild(label)
        }
        let commands = [("combat.defend", "Defend [1]"), ("combat.end", "End turn [Enter]"), ("combat.yield", "Yield [3]"), ("combat.bear", "Bear Form [4]"), ("combat.fire", "Fire arrow [5]")]
            + CombatManeuver.allCases.filter { $0 != .tripAttack }.enumerated().map { ("combat." + $0.element.rawValue, "\($0.element.title) [\($0.offset + 6)]") }
        for (name, title) in commands + [("combat.hide", "Hide"), ("combat.sneak", "Sneak attack"), ("combat.extinguish", "Extinguish"), ("combat.shove", "Shove · bonus"), ("combat.tripAttack", "Trip attack"), ("combat.claw", "Claw attack [5]"), ("combat.roar", "Goading roar [6]")] {
            let button = SKShapeNode(rectOf: CGSize(width: 150, height: 44), cornerRadius: 6)
            button.name = name
            button.fillColor = SKColor(white: 0.17, alpha: 1)
            button.strokeColor = SKColor(white: 0.5, alpha: 1)
            let text = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            text.text = title; text.fontSize = 14; text.verticalAlignmentMode = .center
            button.addChild(text); hud.addChild(button); buttons.append(button)
        }
        routePreview.name = "combat.routePreview"
        routePreview.strokeColor = .cyan; routePreview.lineWidth = 2; routePreview.zPosition = 10000
        scene.depthWorldRoot.addChild(routePreview)
        sightPreview.zPosition = -0.2; scene.depthWorldRoot.addChild(sightPreview)
        scene.detective.cancelMovement()
        for actor in combat.actors {
            let node = actorNode(actor.id)
            node?.position = actor.position
            self.combat.setInitialFacing(actor.id, facing: (node as? CharacterAppearanceNode)?.currentFacing ?? .northEast)
            let facing = ActorFacing.clamped(self.combat.actors.first { $0.id == actor.id }!.combatFacing!)
            if actor.player { scene.detective.setEntranceFacing(facing) }
            else if let node = node as? CharacterAppearanceNode { try? node.present(action: .idle, facing: facing, phase: 0) }
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
            let node = CombatBarrelVisual(barrel: barrel,
                lighting: scene.area.id == WharfLadderStory.exterior ? .cityDay : .officeInterior)
            scene.depthWorldRoot.addChild(node); scene.updateDepth(of: node)
            barrelNodes[barrel.id] = node
            if !barrel.isBroken { scene.navigation.occupancy.register(OccupyingActor(id: barrel.id, kind: .npc,
                position: barrel.position, radius: 20, isBumpable: false, isMoving: false,
                personalSpaceCells: 3)) }
        }
        for actor in combat.actors where !actor.conscious { beginDefeat(actor, restored: true) }
        updateDefeats(delta: 0)
        for actor in combat.actors where actor.isProne {
            let result = TacticalCombat.Strike(attacker: actor.id, target: actor.id, roll: 0, damage: 0, knockedOut: false)
            beginReaction(result, target: actor, kind: .tripFall, elapsed: ProneMotion.holdTime)
        }
        updateReactions()
        layout()
        updateStealth(delta: 0)
        updateBurning(delta: 0)
        refresh()
        scene.context.session.checkpointCombat(self.combat)
    }

    func layout() {
        laidOutBearForm = combat.isBear
        let visible = activeButtons
        for button in buttons { button.isHidden = !visible.contains { $0 === button } }
        let left = HUDChromeLayout.leftRailClearance(for: scene.size)
        let right = HUDChromeLayout.rightRailClearance(for: scene.size)
        let width = max(260, min(820, scene.size.width - left - right - 16))
        hud.position.x = (left - right) / 2
        let columns = width >= 760 ? 5 : width >= 460 ? 3 : 2
        let rows = Int(ceil(Double(visible.count) / Double(columns)))
        let height: CGFloat = 140 + CGFloat(rows) * 48
        panel.path = CGPath(roundedRect: CGRect(x: -width / 2, y: -height / 2, width: width, height: height), cornerWidth: 8, cornerHeight: 8, transform: nil)
        panel.position.y = -scene.size.height / 2 + height / 2 + 24
        turnPanel.path = CGPath(rect: CGRect(x: -width / 2, y: -72, width: width, height: 138), transform: nil)
        turnPanel.position.y = scene.size.height / 2 - 78
        initiativeBar.position = turnPanel.position
        initiativeBar.layout(width: width)
        message.position.y = panel.position.y + height / 2 - (width < 660 ? 40 : 22)
        history.position.y = panel.position.y + height / 2 - (width < 660 ? 104 : 51)
        message.fontSize = 14; history.fontSize = 12
        for label in [message, history] { label.preferredMaxLayoutWidth = width - 24; label.numberOfLines = 2 }
        message.numberOfLines = width < 660 ? 4 : 2
        for (i, button) in visible.enumerated() {
            let spacing = min(158, (width - 20) / CGFloat(columns))
            button.setScale(min(1, spacing / 154))
            button.position = CGPoint(x: (CGFloat(i % columns) - CGFloat(columns - 1) / 2) * spacing,
                y: panel.position.y - height / 2 + 28 + CGFloat(rows - 1 - i / columns) * 48)
        }
        hud.setScale(1)
    }

    private func actorNode(_ id: String) -> SKNode? {
        id == TacticalCombat.playerID ? (displayingBear ? bearNode : scene.detective) : crew.first { $0.definition.id == id }
    }
    private func refresh() {
        if laidOutBearForm != combat.isBear { layout() }
        let shown = presentedCombat
        initiativeBar.update(combat: shown, paused: scene.pause.isPausedByPlayer)
        let move = Int(combat.budget.availableMovement(speed: combat.movementSpeed(for: combat.current)) / 8)
        message.text = combat.isPlayerTurn
            ? "\(feedback)  |  Strike: \(combat.budget.canAttack ? "ready" : "spent") • Move: \(move) ft"
            : "\(combat.current.name) is taking their turn…"
        history.text = presentedCombat.log.suffix(2).joined(separator: "\n")
        buttons.forEach { $0.alpha = combat.isPlayerTurn && !busy ? 1 : 0.45 }
        (buttons[3].children.first as? SKLabelNode)?.text = combat.isBear ? "Human form [4]" : combat.bearForm == nil ? "Bear Form [4]" : "Bear Form spent"
        if !combat.isBear && combat.bearForm != nil { buttons[3].alpha = 0.35 }
        for (index, maneuver) in CombatManeuver.allCases.enumerated() {
            let button = buttons[maneuver == .tripAttack ? 13 : index + 5]
            let spent = (combat.current.usedManeuvers ?? []).contains(maneuver)
            (button.children.first as? SKLabelNode)?.text = spent ? maneuver.title + " · spent" : maneuver == .tripAttack ? "Trip attack" : "\(maneuver.title) [\(index + 6)]"
            let gear = !maneuver.ranged || playerBowSupported
            button.alpha = combat.isPlayerTurn && !busy && gear && combat.canUse(maneuver, hasSword: playerHasSword) ? 1 : 0.35
            button.strokeColor = selectedManeuver == maneuver ? .cyan : SKColor(white: 0.5, alpha: 1)
        }
        buttons[9].alpha = combat.isPlayerTurn && !busy && combat.canHide ? 1 : 0.35
        (buttons[9].children.first as? SKLabelNode)?.text = combat.current.hidden == true ? "Hidden" : combat.current.hideUsed == true ? "Hide · spent" : "Hide"
        buttons[10].alpha = combat.isPlayerTurn && !busy && !combat.isBear && combat.budget.canAttack && combat.current.sneakSpent != true && (playerHasSword || playerBowSupported) ? 1 : 0.35
        buttons[10].strokeColor = selectingSneakAttack ? .cyan : SKColor(white: 0.5, alpha: 1)
        (buttons[10].children.first as? SKLabelNode)?.text = combat.current.sneakSpent == true ? "Sneak · spent" : "Sneak attack +1d6"
        buttons[11].alpha = combat.isPlayerTurn && !busy && combat.canExtinguish ? 1 : 0.35
        buttons[12].alpha = combat.isPlayerTurn && !busy && combat.canShove ? 1 : 0.35
        buttons[12].strokeColor = selectingShove ? .cyan : SKColor(white: 0.5, alpha: 1)
        (buttons[12].children.first as? SKLabelNode)?.text = combat.current.shoveSpent == true ? "Shove · spent" : "Shove · bonus"
        buttons[4].strokeColor = aimingFireArrow ? .cyan : SKColor(white: 0.5, alpha: 1)
        buttons[14].alpha = combat.isPlayerTurn && !busy && combat.budget.canAttack ? 1 : 0.35
        buttons[14].strokeColor = selectingClaw ? .cyan : SKColor(white: 0.5, alpha: 1)
        buttons[15].alpha = combat.canGoadingRoar && !busy ? 1 : 0.35
        (buttons[15].children.first as? SKLabelNode)?.text = combat.bearForm?.roarSpent == true ? "Roar · spent" : "Goading roar [6]"
        for actor in shown.actors {
            let shortName = actor.player ? "" : actor.name.replacingOccurrences(of: "Hand ", with: "") + " · "
            badges[actor.id]?.text = "\(shortName)\(actor.hp)/\(actor.maximumHP)\(actor.defending ? " +4" : "")"
            if actor.player, shown.isBear, let form = shown.bearForm {
                badges[actor.id]?.text = "Bear Health: \(form.temporaryHP)/\(BearFormRules.maximumEndurance) • \(form.turnsRemaining)t"
            }
            if let condition = actor.conditions, !condition.label.isEmpty {
                badges[actor.id]?.text = (badges[actor.id]?.text ?? "") + " · " + condition.label
            }
            if actor.isBurning { badges[actor.id]?.text = (badges[actor.id]?.text ?? "") + " · Burning \(actor.burningTurns!)t" }
            if actor.hidden == true { badges[actor.id]?.text = (badges[actor.id]?.text ?? "") + " · Hidden" }
            badges[actor.id]?.fontColor = actor.player ? .cyan : SKColor(red: 1, green: 0.7, blue: 0.55, alpha: 1)
            rings[actor.id]?.strokeColor = actor.id == shown.current.id ? .yellow : actor.player ? .cyan : .red
        }
    }
    private func checkpoint(synchronize: Bool = true) {
        scene.context.session.checkpointCombat(combat)
        if synchronize { synchronizeForm() }
        drawSight()
        routePreview.path = nil
        refresh()
    }
    /// Inventory owns input and presentation while open; keep the player's
    /// explicit pause independent so closing the bag cannot clear it.
    func setInventoryPresented(_ presented: Bool) {
        hud.isHidden = presented
        if presented { cancelTargeting() }
    }
    private var presentationPaused: Bool { scene.pause.isPausedByPlayer || scene.anyOverlayIsPresented }

    func command(_ input: Int) {
        guard combat.isPlayerTurn, !busy, !presentationPaused else { return }
        let digit = combat.isBear ? (input == 5 ? 15 : input == 6 ? 16 : input) : input
        if combat.isBear && ![1, 2, 3, 4, 12, 15, 16].contains(digit) { return }
        if digit == 15 {
            guard combat.isBear, combat.budget.canAttack else { return }
            let wasSelected = selectingClaw; cancelTargeting(); selectingClaw = !wasSelected
            feedback = selectingClaw ? "Claw Attack: choose a nearby rival • 5–8 damage • standard action." : "Click ground to move • Click a rival to claw"
            refresh(); return
        }
        if digit == 16 { performRoar(); return }
        selectingClaw = false
        if digit == 13 {
            if selectingShove { cancelTargeting(); refresh(); return }
            guard combat.canShove else { feedback = combat.isBear ? "Shove requires human form." : "Shove bonus action is spent this turn."; refresh(); return }
            cancelTargeting(); selectingShove = true
            feedback = "Shove: choose a nearby rival. Bonus action; keeps your attack. Hover for chance and landing."
            refresh(); return
        }
        if selectingShove { cancelTargeting() }
        if digit == 12 {
            if combat.extinguish() {
                cancelTargeting(); feedback = "Flames extinguished. Move or end your turn."
                updateBurning(delta: 0); checkpoint()
            } else { feedback = combat.current.isBurning ? "Extinguish needs a standard action." : "You are not burning."; refresh() }
            return
        }
        if digit == 10 {
            selectingSneakAttack = false; selectedManeuver = nil; aimingFireArrow = false; showingSight = true
            if combat.hide(observed: isObserved(combat.current, at: combat.current.position)) {
                hideTransitions[combat.current.id] = 0
                updateStealth(delta: 0)
                feedback = "Hidden: attack with advantage. Sneak Attack adds +1d6. Red areas show enemy sight."
                checkpoint()
            } else {
                feedback = combat.canHide ? "Move outside the red sight cones or behind cover, then Hide." : combat.current.isBurning ? "Extinguish the flames before hiding." : combat.isBear ? "Hide requires human form." : "Hide is already active or spent this turn."
                drawSight(); refresh()
            }
            return
        }
        if digit == 11 {
            if selectingSneakAttack { cancelTargeting(); return }
            guard !combat.isBear, combat.current.sneakSpent != true, combat.budget.canAttack,
                  playerHasSword || playerBowSupported else {
                feedback = "Sneak Attack needs human form, a shortsword or bow, and an unspent attack."; refresh(); return
            }
            selectingSneakAttack = true; selectedManeuver = nil; aimingFireArrow = false; showingSight = true
            feedback = "Sneak Attack +1d6: choose a rival. Hide for advantage; an adjacent ally also qualifies."
            drawSight(); refresh(); return
        }
        selectingSneakAttack = false
        if (6...9).contains(digit) || digit == 14 {
            let maneuver = digit == 14 ? CombatManeuver.tripAttack : CombatManeuver.allCases[digit - 6]
            if selectedManeuver == maneuver { cancelTargeting(); return }
            guard combat.canUse(maneuver, hasSword: playerHasSword), !maneuver.ranged || playerBowSupported else {
                feedback = "\(maneuver.title): \((combat.current.usedManeuvers ?? []).contains(maneuver) ? "spent this encounter" : combat.isBear ? "requires human form" : maneuver.ranged && !playerBowSupported ? "requires a bow and no armor" : !maneuver.ranged && !playerHasSword ? "equip a sword before combat" : "not enough actions remaining")."
                refresh(); return
            }
            selectedManeuver = maneuver; aimingFireArrow = false; routePreview.path = nil
            feedback = "\(maneuver.title) · 1 use/fight: \(maneuver.detail). Select a rival; select this action again to cancel."
            refresh(); return
        }
        selectedManeuver = nil
        if digit != 5 { aimingFireArrow = false; routePreview.path = nil }
        switch digit {
        case 1:
            if combat.defend() { feedback = "Guard raised. Move or end your turn."; checkpoint() }
            else { feedback = "No standard action remains."; refresh() }
        case 2:
            endCombatTurn(); delay = 0.5; feedback = "Click ground to move • Click a rival to strike"; checkpoint()
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
            feedback = aimingFireArrow ? "Fire arrow: hit a rival to burn them for 2 turns, or ignite a barrel. Blasts hit everyone." : "Click ground to move • Click a rival to strike"
            routePreview.path = nil; refresh()
        default: break
        }
    }
    func cancelTargeting() {
        selectingClaw = false
        routePreview.zPosition = 10000
        selectingShove = false
        selectingSneakAttack = false; showingSight = false; sightPreview.removeAllChildren()
        selectedManeuver = nil; aimingFireArrow = false; routePreview.path = nil
        feedback = "Click ground to move • Click a rival to strike"; refresh()
    }
    private var playerHasSword: Bool {
        VossWeaponAppearance.equipped(in: scene.context.session.characterInventory,
            catalog: scene.context.session.itemCatalog) == .lanternShortsword
    }
    private var playerBowSupported: Bool {
        !combat.isBear && combat.current.rangedWeapon == .bow
            && !VossArmorAppearance.allCases.contains { $0.isEquipped(in: scene.context.session.characterInventory) }
    }
    func pointer(at scenePoint: CGPoint) {
        guard !scene.anyOverlayIsPresented else { return }
        let point = hud.convert(scenePoint, from: scene)
        for (i, button) in buttons.enumerated() where !button.isHidden && button.contains(point) { command(i + 1); return }
        if panel.contains(point) || turnPanel.contains(point) || existingChromeContains(point) { return }
        guard combat.isPlayerTurn, !busy, !presentationPaused else { return }
        let world = scene.depthWorldRoot.convert(scenePoint, from: scene)
        if selectingShove {
            if let target = shoveTarget(at: world) { performShove(target) }
            else { feedback = "Choose a nearby standing rival to shove."; refresh() }
            return
        }
        if let barrel = barrel(at: world) {
            if selectedManeuver != nil || selectingSneakAttack { feedback = "Weapon techniques target rivals. Use Fire arrow [5] for barrels."; refresh(); return }
            if aimingFireArrow {
                guard canUsePlayerBow() else { refresh(); return }
                shootBarrel(barrel)
            } else { smashBarrel(barrel) }
            return
        }
        if let target = combat.actors.filter({ !$0.player && $0.conscious }).min(by: {
            hypot(world.x - $0.position.x, world.y - $0.position.y - 70) < hypot(world.x - $1.position.x, world.y - $1.position.y - 70)
        }), CGRect(x: target.position.x - 48, y: target.position.y - 20, width: 96, height: 110).contains(world) {
            if selectingSneakAttack {
                let wasHidden = combat.current.hidden == true
                revealObservedActors()
                if wasHidden && combat.current.hidden != true { checkpoint() }
                let ranged = !playerHasSword || CombatNavigation.distance(combat.current.position, target.position) > TacticalCombat.meleeReach
                if ranged && !playerBowSupported { feedback = "Move into shortsword reach, or equip a supported bow."; refresh(); return }
                let line = sneakLine(combat.current, target)
                if let reason = combat.sneakAttackReason(target: target, ranged: ranged, hasSword: playerHasSword, clearLine: line, allyLine: sneakLine) {
                    feedback = reason; refresh(); return
                }
                if ranged { shoot(target, requireSneakAttack: true) } else { strike(target, requireSneakAttack: true) }
            } else if aimingFireArrow || selectedManeuver?.ranged == true { shoot(target, maneuver: selectedManeuver) }
            else { strike(target, maneuver: selectedManeuver) }
        } else if selectingClaw {
            feedback = "Choose a nearby rival, or select Claw Attack again to move."; refresh()
        } else if selectingSneakAttack {
            feedback = "Choose a rival for Sneak Attack, or click Sneak attack again to move."; refresh()
        } else if aimingFireArrow || selectedManeuver != nil {
            feedback = selectedManeuver.map { "\($0.title): \($0.detail). Select a rival." }
                ?? "Choose a rival or oil barrel, or press 5 to cancel."; refresh()
        } else if let path = CombatNavigation.route(in: scene.navigation, actor: combat.current, to: world, bear: combat.isBear) {
            if !move(path) { feedback = "That destination exceeds your movement allowance."; refresh() }
        } else { feedback = "No clear route to that point."; refresh() }
    }
    func hover(at scenePoint: CGPoint) {
        guard combat.isPlayerTurn, !busy, !scene.anyOverlayIsPresented else { routePreview.path = nil; return }
        let hudPoint = hud.convert(scenePoint, from: scene)
        guard !panel.contains(hudPoint), !turnPanel.contains(hudPoint), !existingChromeContains(hudPoint) else { routePreview.path = nil; return }
        let world = scene.depthWorldRoot.convert(scenePoint, from: scene)
        if selectingShove {
            if let target = shoveTarget(at: world) { previewShove(target) } else { routePreview.path = nil }
            return
        }
        if selectedManeuver != nil || selectingSneakAttack || selectingClaw { routePreview.path = nil; return }
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
        if actor.hidden == true && path.remainingPoints.contains(where: { isObserved(actor, at: $0) }) { combat.reveal(actor.id) }
        for concealed in combat.actors where concealed.hidden == true && concealed.player != actor.player {
            var observer = actor
            for point in path.remainingPoints {
                observer.combatFacing = ActorFacing.orient(from: observer.position, to: point).rawValue
                observer.position = point
                if TacticalCombat.insideSightCone(observer: observer, point: concealed.position)
                    && CombatNavigation.clearLine(in: scene.navigation, from: point, to: concealed.position,
                        excluding: combat.actors.map(\.id)) {
                    combat.reveal(concealed.id); break
                }
            }
        }
        movingID = actor.id
        feedback = "Click ground to move • Click a rival to strike"
        checkpoint()
        if actor.player && !combat.isBear {
            if combat.current.hidden == true {
                preSneakMovementProfile = scene.detective.movementProfile
                scene.detective.movementProfile.rateMultiplier *= 0.5
            }
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
        if let profile = preSneakMovementProfile { scene.detective.movementProfile = profile; preSneakMovementProfile = nil }
        revealObservedActors()
        if let actor = combat.actors.first(where: { $0.id == id }) {
            scene.navigation.updateActor(id: id, position: actor.position, isMoving: false)
        }
        checkpoint()
    }
    private func strike(_ target: Combatant, maneuver: CombatManeuver? = nil, requireSneakAttack: Bool = false) {
        let attacker = combat.current
        let wasBear = combat.isBear
        let before = combat
        if maneuver == .tripAttack && (target.isProne || (target.player && wasBear)) {
            feedback = target.isProne ? "That rival is already Prone." : "Trip Attack requires a human target."
            refresh(); return
        }
        let node = attacker.player && wasBear ? nil : meleeActor(for: attacker)
        guard attacker.player && wasBear || node != nil else { return }
        let line = CombatNavigation.clearLine(in: scene.navigation, from: attacker.position, to: target.position, excluding: [attacker.id, target.id])
        guard let result = combat.attack(target: target.id, clearLine: line, maneuver: maneuver,
            hasSword: node?.definition.appearance.equipment.contains { $0.item == .lanternShortsword } == true,
            requireSneakAttack: requireSneakAttack, allyLine: sneakLine) else {
            feedback = combat.budget.canAttack ? "Move closer with a clear line before striking." : "No standard action remains."
            refresh(); return
        }
        selectingSneakAttack = false
        selectingClaw = false
        selectedManeuver = nil
        feedback = maneuver.map { "\($0.title) used. Move or end your turn." } ?? "Click ground to move • Click a rival to strike"
        if attacker.player { scene.detective.setEntranceFacing(.orient(from: attacker.position, to: target.position)) }
        else if let node = actorNode(attacker.id) as? CharacterAppearanceNode {
            try? node.present(action: .idle, facing: .orient(from: attacker.position, to: target.position), phase: 0)
        }
        delay = 0.85
        if attacker.player && wasBear {
            bearFacing = .orient(from: attacker.position, to: target.position)
            bearAbility = BearAbilityPresentation(before: before, action: .attack, strike: result, targets: [target])
            delay = 0.15
            checkpoint(synchronize: false)
            return
        } else if node == nil && target.player && wasBear && combat.isBear && result.damage > 0 {
            bearAction = (.hit, 0)
        }
        if let node {
            beginMeleePresentation(attacker, node: node)
            meleeAttack = MeleeAttackPresentation(before: before, result: result, target: target, actor: node)
            delay = 0.15
            checkpoint(synchronize: false)
        } else {
            checkpoint()
            presentImpact(result, target: target)
        }
    }
    private func beginMeleePresentation(_ actor: Combatant, node: CharacterAppearanceNode) {
        guard actor.player else { return }
        scene.detective.isHidden = true; node.isHidden = false
        for decoration in [badges[actor.id], rings[actor.id]] as [SKNode?] {
            decoration?.removeFromParent()
            if let decoration { node.addChild(decoration) }
        }
    }
    private func meleeActor(for actor: Combatant) -> CharacterAppearanceNode? {
        guard actor.player else { return actorNode(actor.id) as? CharacterAppearanceNode }
        var definition = CharacterDefinition.voss
        let inventory = scene.context.session.characterInventory
        definition.appearance.equipment = VossArmorAppearance.allCases.compactMap {
            guard $0.isEquipped(in: inventory), let item = CharacterEquipmentCode(rawValue: $0.rawValue) else { return nil }
            return .init(item: item)
        }
        if VossWeaponAppearance.equipped(in: inventory, catalog: scene.context.session.itemCatalog) == .lanternShortsword {
            definition.appearance.equipment.append(.init(item: .lanternShortsword))
        }
        do {
            if let playerMeleeNode { try playerMeleeNode.apply(definition) }
            else {
                let node = try CharacterAppearanceNode(definition: definition)
                node.isHidden = true
                node.applySceneLighting(scene.area.id == WharfLadderStory.exterior ? .cityDay : .officeInterior)
                scene.depthWorldRoot.addChild(node); playerMeleeNode = node
            }
        } catch { feedback = "Melee artwork could not load."; refresh(); return nil }
        let node = playerMeleeNode!
        node.position = actor.position; node.visualHeightOffset = scene.detective.visualHeightOffset
        scene.applyAreaLighting(to: node); scene.updateDepth(of: node); scene.applyActorCover(to: node, at: actor.position)
        return node
    }
    private func shoveTarget(at point: CGPoint) -> Combatant? {
        combat.actors.filter { $0.conscious && $0.id != combat.current.id && ($0.hidden != true || $0.player == combat.current.player) }
            .min { CombatNavigation.distance($0.position, point) < CombatNavigation.distance($1.position, point) }
            .flatMap { CombatNavigation.distance($0.position, point) <= 65 ? $0 : nil }
    }
    private func shoveLanding(_ target: Combatant) -> CGPoint {
        CombatNavigation.knockbackDestination(in: scene.navigation, actor: target, awayFrom: combat.current.position,
            actors: combat.actors, destroyedBarrels: [], bear: target.player && combat.isBear,
            maximumDistance: ShoveRules.distance(attacker: combat.physique(of: combat.current), target: combat.physique(of: target)))
    }
    private func shoveClear(_ target: Combatant) -> Bool {
        CombatNavigation.clearLine(in: scene.navigation, from: combat.current.position, to: target.position,
            excluding: [combat.current.id, target.id])
    }
    private func previewShove(_ target: Combatant) {
        let end = shoveLanding(target), clear = shoveClear(target)
        let preview = combat.shovePreview(target: target.id, clearLine: clear, destination: end)
        let path = CGMutablePath(); path.move(to: target.position); path.addLine(to: end)
        path.addEllipse(in: CGRect(x: end.x - 24, y: end.y - 18, width: 48, height: 36))
        routePreview.zPosition = SceneLayer.hud.rawValue - SceneLayer.depthWorld.rawValue - 1
        routePreview.path = path; routePreview.strokeColor = preview == nil ? .red : .cyan
        feedback = preview.map { "Shove \($0.chance)% · \(Int(CombatNavigation.distance(target.position, end) / 8)) ft · bonus action" }
            ?? combat.shoveProblem(target: target.id, clearLine: clear, destination: end) ?? "Cannot shove."
        refresh()
    }
    private func performShove(_ target: Combatant) {
        let end = shoveLanding(target), clear = shoveClear(target)
        guard combat.shovePreview(target: target.id, clearLine: clear, destination: end) != nil else { previewShove(target); return }
        let actor = combat.current
        var definition: CharacterDefinition
        if actor.player {
            definition = .voss
            let inventory = scene.context.session.characterInventory
            let catalog = scene.context.session.itemCatalog
            definition.appearance.equipment = VossArmorAppearance.allCases.compactMap {
                $0.isEquipped(in: inventory) ? CharacterEquipmentCode(rawValue: $0.rawValue).map { .init(item: $0) } : nil
            }
            if let weapon = VossWeaponAppearance.equipped(in: inventory, catalog: catalog),
               let item = CharacterEquipmentCode(rawValue: weapon.rawValue) { definition.appearance.equipment.append(.init(item: item)) }
            if let ammunition = VossAmmunitionAppearance.equipped(in: inventory, catalog: catalog),
               let item = CharacterEquipmentCode(rawValue: ammunition.rawValue) { definition.appearance.equipment.append(.init(item: item)) }
        } else if let original = actorNode(actor.id) as? CharacterAppearanceNode { definition = original.definition }
        else { return }
        definition.appearance.equipment.removeAll { $0.item == .elvenCourtArrow }
        let facing = ActorFacing.orient(from: actor.position, to: target.position)
        do {
            let node = try CharacterAppearanceNode(definition: definition)
            try node.present(action: .shove, facing: facing, phase: 0)
            node.position = actor.position
            node.visualHeightOffset = actor.player ? scene.detective.visualHeightOffset : (actorNode(actor.id) as? CharacterAppearanceNode)?.visualHeightOffset ?? 0
            let before = combat
            guard let result = combat.shove(target: target.id, clearLine: clear, destination: end) else { return }
            node.name = "combat.shove.actor"; scene.depthWorldRoot.addChild(node)
            scene.applyAreaLighting(to: node); scene.updateDepth(of: node); scene.applyActorCover(to: node, at: node.position)
            actorNode(actor.id)?.isHidden = true
            if actor.player { scene.detective.setEntranceFacing(facing) }
            else if let original = actorNode(actor.id) as? CharacterAppearanceNode { try? original.present(action: .idle, facing: facing, phase: 0) }
            stealthNodes[actor.id]?.isHidden = true
            for decoration in [badges[actor.id], rings[actor.id]] as [SKNode?] {
                decoration?.removeFromParent(); if let decoration { node.addChild(decoration) }
            }
            shovePresentation = ShovePresentation(before: before, result: result, target: target, node: node, facing: facing)
            // Occupancy reserves the accepted endpoint even while the old pose is visible.
            if let move = result.displacement { scene.navigation.updateActor(id: move.id, position: move.to, isMoving: false) }
            cancelTargeting(); checkpoint()
        } catch { feedback = "Shove artwork could not load."; refresh() }
    }
    private func updateShove(delta: Double) {
        guard var shove = shovePresentation else { return }
        shove.elapsed += delta
        // The shared melee reach includes both actors' footprints. Step the
        // presentation into palm contact, then recover to the unchanged game position.
        let start = shove.before.current.position
        let distance = CombatNavigation.distance(start, shove.target.position)
        let step = max(0, distance - 58)
        let contact = ShoveAnimationSet.impactTime
        let t = min(1, max(0, shove.elapsed < contact ? shove.elapsed / contact
            : (ShoveAnimationSet.duration - shove.elapsed) / (ShoveAnimationSet.duration - contact)))
        let amount = CGFloat(step / max(1, distance) * t * t * (3 - 2 * t))
        shove.node.position = CGPoint(x: start.x + (shove.target.position.x - start.x) * amount,
                                      y: start.y + (shove.target.position.y - start.y) * amount)
        try? shove.node.present(action: .shove, facing: shove.facing, phase: ShoveAnimationSet.phase(elapsed: shove.elapsed))
        scene.applyAreaLighting(to: shove.node); scene.updateDepth(of: shove.node); scene.applyActorCover(to: shove.node, at: shove.node.position)
        if !shove.impactPresented && shove.elapsed >= ShoveAnimationSet.impactTime {
            shove.impactPresented = true
            let elapsed = max(0, shove.elapsed - ShoveAnimationSet.impactTime)
            if let move = shove.result.displacement { knockbacks = [move]; knockbackElapsed = elapsed - delta }
            let hit = TacticalCombat.Strike(attacker: shove.result.attacker, target: shove.result.target, roll: shove.result.roll, damage: 0, knockedOut: false)
            // Cosmetic knockdown: use the full fall/get-up clip without adding
            // Prone, damage, or a movement charge. Its recovery keeps the turn busy.
            beginReaction(hit, target: shove.target, kind: shove.result.succeeded ? .fall : .hit,
                elapsed: elapsed, source: shove.before.current.position)
            feedback = shove.result.succeeded ? "Shoved back. Your normal attack is still available if unspent." : "Shove resisted. Bonus action spent."
            let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
            label.text = shove.result.succeeded ? "SHOVED" : "RESISTED"; label.fontSize = 20
            label.position = CGPoint(x: shove.target.position.x, y: shove.target.position.y + 90); label.zPosition = 20001
            scene.depthWorldRoot.addChild(label); label.run(.sequence([.group([.moveBy(x: 0, y: 22, duration: 0.6), .fadeOut(withDuration: 0.7)]), .removeFromParent()]))
        }
        if shove.elapsed >= ShoveAnimationSet.duration {
            let id = shove.result.attacker, original = actorNode(shove.result.attacker)
            original?.isHidden = false
            for decoration in [badges[id], rings[id]] as [SKNode?] {
                decoration?.removeFromParent(); if let decoration { original?.addChild(decoration) }
            }
            shove.node.removeFromParent(); shovePresentation = nil
            revealObservedActors(); checkpoint(); return
        }
        shovePresentation = shove
    }

    private func beginReaction(_ result: TacticalCombat.Strike, target: Combatant,
                               kind: CombatReactionKind, elapsed: Double = 0, source: CGPoint? = nil) {
        guard !result.knockedOut, let attacker = combat.actors.first(where: { $0.id == result.attacker }),
              combat.actors.contains(where: { $0.id == target.id && $0.conscious }) else { return }
        // Further hits and misses never make a Prone target stand up early.
        if target.isProne && kind != .tripFall { return }
        // The bear keeps its existing authored hit animation. Human equipment clips
        // must never be substituted during a transformation.
        guard !(target.player && (displayingBear || formTransition != nil)) else { return }
        var definition: CharacterDefinition
        var facing: ActorFacing
        if target.player {
            definition = .voss; facing = scene.detective.currentFacing
            let inventory = scene.context.session.characterInventory
            let catalog = scene.context.session.itemCatalog
            definition.appearance.equipment = VossArmorAppearance.allCases.compactMap {
                guard $0.isEquipped(in: inventory), let item = CharacterEquipmentCode(rawValue: $0.rawValue) else { return nil }
                return .init(item: item)
            }
            if let weapon = VossWeaponAppearance.equipped(in: inventory, catalog: catalog),
               let item = CharacterEquipmentCode(rawValue: weapon.rawValue) { definition.appearance.equipment.append(.init(item: item)) }
            if let arrow = VossAmmunitionAppearance.equipped(in: inventory, catalog: catalog),
               let item = CharacterEquipmentCode(rawValue: arrow.rawValue) { definition.appearance.equipment.append(.init(item: item)) }
        } else {
            guard let actor = actorNode(target.id) as? CharacterAppearanceNode,
                  actor.definition.appearance.body == .humanMale01 else { return }
            definition = actor.definition; facing = actor.currentFacing
        }
        let restingFacing = facing
        if let source, kind.isKnockback { facing = .orient(from: target.position, to: source) }
        do {
            let node: CharacterAppearanceNode
            if let existing = reactionNodes[target.id] { node = existing; try node.present(action: .idle, facing: facing, phase: 0); try node.apply(definition) }
            else {
                node = try CharacterAppearanceNode(definition: definition)
                reactionNodes[target.id] = node; scene.depthWorldRoot.addChild(node)
            }
            node.name = "combat.reaction." + target.id
            node.applySceneLighting(scene.area.id == WharfLadderStory.exterior ? .cityDay : .officeInterior)
            try node.presentReaction(kind, facing: facing, phase: 0)
            var reaction = CombatRecoil(from: source ?? attacker.position, to: target.position, heavy: source != nil || result.maneuver == .powerStrike, kind: kind)
            reaction.elapsed = elapsed; hitReactions[target.id] = reaction
            reactionFacings[target.id] = (facing, restingFacing)
        } catch { feedback = "Reaction artwork could not load." }
    }

    private func updateReactions() {
        for id in Array(hitReactions.keys) {
            guard let reaction = hitReactions[id], let node = reactionNodes[id], let original = actorNode(id) else { continue }
            let prone = presentedCombat.actors.contains { $0.id == id && $0.isProne }
            let phase = prone && reaction.kind == .tripFall ? min(ProneMotion.holdPhase, reaction.phase) : reaction.phase
            if reaction.finished && !prone {
                node.setCombatRecoil(0); node.isHidden = true; hitReactions[id] = nil; reactionFacings[id] = nil
                original.isHidden = !combat.actors.contains { $0.id == id && $0.conscious }
                for decoration in [badges[id], rings[id]] as [SKNode?] {
                    decoration?.removeFromParent(); if let decoration { original.addChild(decoration) }
                }
                continue
            }
            node.position = original.position
            node.visualHeightOffset = id == TacticalCombat.playerID ? scene.detective.visualHeightOffset : (original as? CharacterAppearanceNode)?.visualHeightOffset ?? 0
            node.isHidden = false; original.isHidden = true
            if id == TacticalCombat.playerID { playerBowNode?.isHidden = true; playerMeleeNode?.isHidden = true }
            let facings = reactionFacings[id] ?? (node.currentFacing, node.currentFacing)
            let facing = reaction.kind.isKnockback ? ExplosionKnockbackMotion.recoveryFacing(
                from: facings.0, to: facings.1, phase: phase, frames: reaction.kind.frames) : facings.0
            try? node.presentReaction(reaction.kind, facing: facing, phase: phase)
            node.setCombatRecoil(CGFloat(reaction.angle))
            scene.applyAreaLighting(to: node); scene.updateDepth(of: node); scene.applyActorCover(to: node, at: node.position)
            for decoration in [badges[id], rings[id]] as [SKNode?] where decoration?.parent !== node {
                decoration?.removeFromParent(); if let decoration { node.addChild(decoration) }
            }
        }
    }

    private func beginDefeat(_ actor: Combatant, restored: Bool = false) {
        guard defeatNodes[actor.id] == nil else { return }
        var definition: CharacterDefinition
        if actor.player {
            definition = .voss
            let inventory = scene.context.session.characterInventory
            let catalog = scene.context.session.itemCatalog
            definition.appearance.equipment = VossArmorAppearance.allCases.compactMap {
                $0.isEquipped(in: inventory) ? CharacterEquipmentCode(rawValue: $0.rawValue).map { .init(item: $0) } : nil
            }
            if let weapon = VossWeaponAppearance.equipped(in: inventory, catalog: catalog),
               let item = CharacterEquipmentCode(rawValue: weapon.rawValue) { definition.appearance.equipment.append(.init(item: item)) }
            if let ammunition = VossAmmunitionAppearance.equipped(in: inventory, catalog: catalog),
               let item = CharacterEquipmentCode(rawValue: ammunition.rawValue) { definition.appearance.equipment.append(.init(item: item)) }
        } else if let original = actorNode(actor.id) as? CharacterAppearanceNode { definition = original.definition }
        else { return }
        let facing = ActorFacing.clamped(actor.combatFacing ?? (actorNode(actor.id) as? CharacterAppearanceNode)?.currentFacing.rawValue ?? scene.detective.currentFacing.rawValue)
        do {
            let node = try CharacterAppearanceNode(definition: definition)
            node.name = "combat.defeated." + actor.id
            node.position = actorNode(actor.id)?.position ?? actor.position
            node.visualHeightOffset = actor.player ? scene.detective.visualHeightOffset : (actorNode(actor.id) as? CharacterAppearanceNode)?.visualHeightOffset ?? 0
            node.applySceneLighting(scene.area.id == WharfLadderStory.exterior ? .cityDay : .officeInterior)
            let motion = CombatDefeatMotion(facing: facing, elapsed: restored || actor.isProne ? DefeatAnimationSet.duration : 0)
            try node.present(action: .die, facing: facing, phase: motion.phase)
            scene.depthWorldRoot.addChild(node)
            defeatNodes[actor.id] = node; defeats[actor.id] = motion
            node.isHidden = actor.player && (displayingBear || formTransition != nil)
            hitReactions[actor.id] = nil; reactionFacings[actor.id] = nil
            reactionNodes[actor.id]?.isHidden = true; stealthNodes[actor.id]?.isHidden = true
            hideTransitions[actor.id] = nil
            badges[actor.id]?.isHidden = true; rings[actor.id]?.isHidden = true
            scene.navigation.unregisterActor(id: actor.id)
            if !node.isHidden { actorNode(actor.id)?.isHidden = true }
        } catch { feedback = "Defeat artwork could not load."; assertionFailure("Defeat artwork: \(error)") }
    }

    private func updateDefeats(delta: Double) {
        for id in defeats.keys {
            guard var motion = defeats[id], let node = defeatNodes[id] else { continue }
            // Depleting Bear Form first plays its existing reversion, then the
            // human collapse. Never replace a visible bear with human death art.
            if id == TacticalCombat.playerID && (displayingBear || formTransition != nil) { node.isHidden = true; continue }
            motion.elapsed = min(DefeatAnimationSet.duration, motion.elapsed + delta); defeats[id] = motion
            try? node.present(action: .die, facing: motion.facing, phase: motion.phase)
            node.isHidden = false
            scene.navigation.unregisterActor(id: id)
            actorNode(id)?.isHidden = true
            if id == TacticalCombat.playerID { playerMeleeNode?.isHidden = true; playerBowNode?.isHidden = true }
            scene.applyAreaLighting(to: node); scene.updateDepth(of: node); scene.applyActorCover(to: node, at: node.position)
        }
    }

    private func presentImpact(_ result: TacticalCombat.Strike, target: Combatant, reacts: Bool = true) {
        if reacts && result.damage > 0 && !result.knockedOut { beginReaction(result, target: target, kind: result.maneuver == .tripAttack ? .tripFall : .hit) }
        // Immediate bear attacks have no human wind-up presentation to anticipate.
        if reacts && result.damage == 0 && hitReactions[target.id] == nil { beginReaction(result, target: target, kind: .dodge) }
        // Accepted damage is revealed by the action presentation at its hit marker.
        let effect = SKShapeNode(ellipseOf: CGSize(width: 52, height: 38))
        effect.position = CGPoint(x: target.position.x, y: target.position.y + (target.isProne || result.maneuver == .tripAttack ? 20 : 45))
        effect.strokeColor = result.sneakDamage > 0 ? .magenta : result.damage > 0 ? .orange : .white; effect.lineWidth = 3; effect.zPosition = 20000
        scene.depthWorldRoot.addChild(effect)
        effect.run(.sequence([.group([.scale(to: 1.8, duration: 0.3), .fadeOut(withDuration: 0.4)]), .removeFromParent()]))
        let number = SKLabelNode(fontNamed: "AvenirNext-Bold")
        number.text = result.damage > 0 ? "−\(result.damage)" : "MISS"
        if result.damage > 0, !result.knockedOut {
            if result.fireArrow { number.text! += " · Burning" }
            if result.maneuver == .feintingCut { number.text! += " · Weakened" }
            if result.maneuver == .pinningShot { number.text! += " · Slowed" }
            if result.maneuver == .tripAttack { number.text! += " · Prone" }
        }
        if result.sneakDamage > 0 { number.text! += " · Sneak +\(result.sneakDamage)" }
        number.fontSize = 26; number.position = CGPoint(x: target.position.x, y: target.position.y + 95); number.zPosition = 20001
        scene.depthWorldRoot.addChild(number)
        number.run(.sequence([.group([.moveBy(x: 0, y: 35, duration: 0.7), .fadeOut(withDuration: 0.8)]), .removeFromParent()]))
        if result.knockedOut { beginDefeat(target) }
    }
    private func shoot(_ target: Combatant, maneuver: CombatManeuver? = nil, requireSneakAttack: Bool = false) {
        let attacker = combat.current
        guard let node = bowActor(for: attacker) else { return }
        let line = CombatNavigation.clearLine(in: scene.navigation, from: attacker.position, to: target.position,
            excluding: [attacker.id, target.id])
        let before = combat
        guard let result = combat.attack(target: target.id, clearLine: line, ranged: true, maneuver: maneuver, requireSneakAttack: requireSneakAttack, allyLine: sneakLine) else {
            feedback = "\(maneuver?.title ?? "Fire arrow"): needs \(maneuver == .aimedShot ? "a full turn" : "a standard action"), range beyond melee, and a clear shot."; refresh(); return
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
        selectingSneakAttack = false
        aimingFireArrow = false; selectedManeuver = nil
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
        let before = combat
        let node = combat.isBear ? nil : meleeActor(for: combat.current)
        guard combat.isBear || node != nil else { return }
        let clear = CombatNavigation.clearLine(in: scene.navigation, from: combat.current.position,
            to: barrel.position, excluding: [combat.current.id, barrel.id])
        guard combat.breakBarrel(barrel.id, clearLine: clear) else {
            feedback = barrel.isBroken ? "Oil spill: use Fire arrow [5] to ignite it."
                : "Move within melee reach to break it, or use Fire arrow [5]."
            refresh(); return
        }
        let destruction = BarrelDestruction(barrel: barrel, explosion: false,
            impactFrom: combat.current.position, searchMap: scene.navigation.searchMap)
        combat.recordBarrelDebris(barrel.id, poses: destruction.finalPoses)
        if let node {
            let attacker = before.current
            scene.detective.setEntranceFacing(.orient(from: attacker.position, to: barrel.position))
            beginMeleePresentation(attacker, node: node)
            let target = Combatant(id: barrel.id, name: barrel.name, player: false, position: barrel.position,
                hp: 1, maximumHP: 1, defence: 0, attackBonus: 0, damageMin: 1, damageMax: 1, initiativeBonus: 0)
            meleeAttack = MeleeAttackPresentation(before: before,
                result: .init(attacker: attacker.id, target: barrel.id, roll: 0, damage: 1, knockedOut: true),
                target: target, actor: node, barrelDestruction: destruction)
            delay = 0.15; checkpoint(synchronize: false)
        } else {
            if let updated = combat.barrels?.first(where: { $0.id == barrel.id }) {
                barrelNodes[barrel.id]?.apply(updated, destruction: destruction)
            }
            scene.navigation.unregisterActor(id: barrel.id)
            bearFacing = .orient(from: combat.current.position, to: barrel.position); bearAction = (.attack, 0)
            feedback = "Barrel broken. The spilled oil can still ignite."
            delay = 0.3; checkpoint()
        }
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
        var destructions: [String: BarrelDestruction] = [:]
        for explosion in explosions {
            let destruction = BarrelDestruction(barrel: explosion.barrel, explosion: true,
                impactFrom: attacker.position, searchMap: scene.navigation.searchMap)
            combat.recordBarrelDebris(explosion.barrel.id, poses: destruction.finalPoses)
            destructions[explosion.barrel.id] = destruction
        }
        beginBowPresentation(attacker)
        let target = Combatant(id: barrel.id, name: barrel.name, player: !attacker.player,
            position: barrel.position, hp: 1, maximumHP: 1, defence: 0, attackBonus: 0,
            damageMin: 1, damageMax: 1, initiativeBonus: 0)
        rangedShot = BowShotPresentation(before: before,
            result: .init(attacker: attacker.id, target: barrel.id, roll: 0, damage: 1, knockedOut: true),
            target: target, actor: node, parent: scene.depthWorldRoot, targetHeight: barrel.isBroken ? 4 : 32, explosions: explosions, displacements: displacements, destructions: destructions)
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
    private func sneakLine(_ a: Combatant, _ b: Combatant) -> Bool {
        CombatNavigation.clearLine(in: scene.navigation, from: a.position, to: b.position, excluding: [a.id, b.id])
    }
    func isObserved(_ actor: Combatant, at point: CGPoint) -> Bool {
        combat.actors.contains { observer in
            observer.player != actor.player && observer.conscious
                && TacticalCombat.insideSightCone(observer: observer, point: point)
                && CombatNavigation.clearLine(in: scene.navigation, from: observer.position, to: point,
                    excluding: combat.actors.map(\.id))
        }
    }
    private func revealObservedActors() {
        for actor in combat.actors where actor.hidden == true {
            if isObserved(actor, at: actor.position) { combat.reveal(actor.id) }
        }
    }
    private func drawSight() {
        sightPreview.removeAllChildren()
        guard showingSight && combat.isPlayerTurn else { return }
        for observer in combat.actors where !observer.player && observer.conscious {
            let path = CGMutablePath(); path.move(to: observer.position)
            let facing = Double(observer.combatFacing ?? 0) * .pi / 8
            for ray in 0...16 {
                let angle = facing - .pi / 3 + Double(ray) * (.pi * 2 / 3) / 16
                var end = observer.position
                for step in 1...32 {
                    let distance = Double(step) * BowAttackRules.range / 32
                    let point = CGPoint(x: observer.position.x - sin(angle) * distance,
                        y: observer.position.y - cos(angle) * distance * ActorLocomotionPacing.verticalProjectionScale)
                    if !CombatNavigation.clearLine(in: scene.navigation, from: observer.position, to: point,
                        excluding: combat.actors.map(\.id)) { break }
                    end = point
                }
                path.addLine(to: end)
            }
            path.closeSubpath()
            let node = SKShapeNode(path: path); node.fillColor = SKColor.red.withAlphaComponent(0.12)
            node.strokeColor = SKColor.red.withAlphaComponent(0.35); node.lineWidth = 1
            sightPreview.addChild(node)
        }
    }
    private func endCombatTurn() {
        let before = combat
        var burn: TacticalCombat.Strike?
        guard combat.endTurn(burningHit: { burn = $0 }) else { return }
        if before.actors.contains(where: { $0.id == combat.current.id && $0.isProne }),
           hitReactions[combat.current.id] != nil {
            hitReactions[combat.current.id]?.elapsed = ProneMotion.holdTime
        }
        if let burn { presentImpact(burn, target: before.current, reacts: false) }
        updateBurning(delta: 0)
    }

    private func updateStealth(delta: TimeInterval) {
        stealthTime += delta
        let hidden = presentedCombat.actors.filter { $0.id != shovePresentation?.result.attacker && $0.id != shovePresentation?.result.target && $0.hidden == true && $0.conscious && !($0.player && displayingBear) }
        let ids = Set(hidden.map(\.id))
        for id in Array(stealthNodes.keys) where !ids.contains(id) || isStriking(id) || isShooting(id) || hitReactions[id] != nil {
            let node = stealthNodes[id]!
            guard !node.isHidden else { hideTransitions[id] = nil; continue }
            node.isHidden = true; hideTransitions[id] = nil; stealthPositions[id] = nil; stealthTravel[id] = nil
            // Never reveal the underlying body during another presentation.
            if !isStriking(id) && !isShooting(id) && hitReactions[id] == nil {
                actorNode(id)?.isHidden = !combat.actors.contains { $0.id == id && $0.conscious }
                for decoration in [badges[id], rings[id]] as [SKNode?] {
                    decoration?.removeFromParent(); if let decoration { actorNode(id)?.addChild(decoration) }
                }
            }
        }
        for actor in hidden where !isStriking(actor.id) && !isShooting(actor.id) && hitReactions[actor.id] == nil {
            guard let original = actorNode(actor.id) else { continue }
            var definition: CharacterDefinition
            if actor.player {
                definition = .voss
                let inventory = scene.context.session.characterInventory
                definition.appearance.equipment = VossArmorAppearance.allCases.compactMap {
                    $0.isEquipped(in: inventory) ? CharacterEquipmentCode(rawValue: $0.rawValue).map { .init(item: $0) } : nil
                }
                if let weapon = VossWeaponAppearance.equipped(in: inventory, catalog: scene.context.session.itemCatalog),
                   let item = CharacterEquipmentCode(rawValue: weapon.rawValue) { definition.appearance.equipment.append(.init(item: item)) }
                if let arrow = VossAmmunitionAppearance.equipped(in: inventory, catalog: scene.context.session.itemCatalog),
                   let item = CharacterEquipmentCode(rawValue: arrow.rawValue) { definition.appearance.equipment.append(.init(item: item)) }
            } else if let body = original as? CharacterAppearanceNode { definition = body.definition }
            else { continue }
            let facing = actor.player ? scene.detective.currentFacing : (original as? CharacterAppearanceNode)?.currentFacing ?? .south
            do {
                let node: CharacterAppearanceNode
                if let existing = stealthNodes[actor.id] {
                    node = existing
                    if node.definition != definition { try node.apply(definition) }
                } else {
                    node = try CharacterAppearanceNode(definition: definition)
                    node.name = "combat.stealth." + actor.id
                    node.applySceneLighting(scene.area.id == WharfLadderStory.exterior ? .cityDay : .officeInterior)
                    stealthNodes[actor.id] = node; scene.depthWorldRoot.addChild(node)
                }
                let clip: StealthClip, phase: Int
                if let entered = hideTransitions[actor.id] {
                    let elapsed = entered + delta
                    hideTransitions[actor.id] = elapsed >= Double(StealthClip.hide.frames) / StealthAnimationSet.fps ? nil : elapsed
                    clip = .hide; phase = StealthAnimationSet.phase(.hide, elapsed: elapsed)
                } else if movingID == actor.id {
                    let step = stealthPositions[actor.id].map { CombatNavigation.distance($0, original.position) } ?? 0
                    stealthTravel[actor.id, default: 0] += step
                    clip = .sneakwalk
                    // One authored stride spans 0.88 m at the locked body density.
                    phase = Int(stealthTravel[actor.id, default: 0] / 43 * Double(clip.frames)) % clip.frames
                } else {
                    clip = .sneakidle; phase = StealthAnimationSet.phase(.sneakidle, elapsed: stealthTime, looping: true)
                }
                stealthPositions[actor.id] = original.position
                node.position = original.position
                node.visualHeightOffset = actor.player ? scene.detective.visualHeightOffset : (original as? CharacterAppearanceNode)?.visualHeightOffset ?? 0
                try node.presentStealth(clip, facing: facing, phase: phase)
                node.isHidden = false; original.isHidden = true
                scene.applyAreaLighting(to: node); scene.updateDepth(of: node); scene.applyActorCover(to: node, at: node.position)
                for decoration in [badges[actor.id], rings[actor.id]] as [SKNode?] where decoration?.parent !== node {
                    decoration?.removeFromParent(); if let decoration { node.addChild(decoration) }
                }
            } catch { hideTransitions[actor.id] = nil; feedback = "Stealth artwork could not load." }
        }
    }

    private func updateBurning(delta: TimeInterval) {
        fireTime += delta
        let burning = presentedCombat.actors.filter(\.isBurning)
        let ids = Set(burning.map(\.id))
        for id in Array(burningNodes.keys) where !ids.contains(id) {
            burningNodes.removeValue(forKey: id)?.removeFromParent()
        }
        for actor in burning {
            let visual: CharacterBurningVisual
            if let existing = burningNodes[actor.id] { visual = existing }
            else { visual = CharacterBurningVisual(); burningNodes[actor.id] = visual }
            // Follow the visible body through weapon, recoil, form and movement proxies.
            let candidates: [SKNode?] = [reactionNodes[actor.id], stealthNodes[actor.id],
                actor.player ? playerBowNode : nil, actor.player ? playerMeleeNode : nil, actorNode(actor.id)]
            guard let body = candidates.compactMap({ $0 }).first(where: { !$0.isHidden }) else { visual.isHidden = true; continue }
            if visual.parent !== body { visual.removeFromParent(); body.addChild(visual) }
            visual.isHidden = false
            let height = (body as? CharacterAppearanceNode)?.visualHeightOffset ?? (actor.player ? scene.detective.visualHeightOffset : 0)
            visual.position.y = height
            visual.sample(time: fireTime, bear: actor.player && displayingBear)
        }
    }

    private func enemyTurn() {
        let goadingTarget = combat.goadingTarget(for: combat.current)
        if goadingTarget == nil && combat.current.isBurning && combat.current.hp <= 8 && combat.extinguish() {
            updateBurning(delta: 0); delay = 0.5; checkpoint(); return
        }
        guard let target = goadingTarget ?? combat.actors.first(where: { $0.player && $0.conscious }) else { return }
        if target.hidden == true {
            let lastSeen = target.lastSeenPosition ?? target.position
            combat.face(combat.current.id, toward: lastSeen)
            if let node = actorNode(combat.current.id) as? CharacterAppearanceNode {
                try? node.present(action: .idle, facing: ActorFacing.clamped(combat.current.combatFacing ?? 0), phase: 0)
            }
            revealObservedActors(); checkpoint()
            if combat.actors.first(where: { $0.id == target.id })?.hidden == true {
                var searchTarget = target; searchTarget.position = lastSeen
                if let path = CombatNavigation.approach(in: scene.navigation, actor: combat.current, target: searchTarget,
                    limit: combat.budget.availableMovement(speed: combat.current.speed)), move(path) { return }
                endCombatTurn(); delay = 0.5; checkpoint(); return
            }
        }
        let actor = combat.current
        let distance = CombatNavigation.distance(actor.position, target.position)
        if actor.rangedWeapon == .bow {
            if goadingTarget == nil, combat.canShove, combat.budget.canAttack, distance <= TacticalCombat.meleeReach {
                let end = shoveLanding(target)
                if CombatNavigation.distance(actor.position, end) > TacticalCombat.meleeReach + 8,
                   let preview = combat.shovePreview(target: target.id, clearLine: shoveClear(target), destination: end), preview.chance >= 25 {
                    performShove(target); return
                }
            }
            if goadingTarget == nil, let barrel = usefulBarrel(for: actor) { equipLookout(actor, bow: true); shootBarrel(barrel); return }
            equipLookout(actor, bow: distance > TacticalCombat.meleeReach)
            if combat.budget.canAttack, BowAttackRules.canShoot(attacker: actor, target: target,
                clearLine: CombatNavigation.clearLine(in: scene.navigation, from: actor.position, to: target.position,
                    excluding: [actor.id, target.id])) {
                shoot(target, maneuver: combat.preferredManeuver(target: target, ranged: true)); return
            }
            if combat.budget.canAttack, distance > TacticalCombat.meleeReach,
               let path = CombatNavigation.firingPosition(in: scene.navigation, actor: actor, target: target,
                   limit: min(combat.movementSpeed(for: actor), combat.budget.availableMovement(speed: combat.movementSpeed(for: actor)))), move(path) { return }
        }
        if combat.budget.canAttack,
           CombatNavigation.distance(actor.position, target.position) <= TacticalCombat.meleeReach,
           CombatNavigation.clearLine(in: scene.navigation, from: actor.position, to: target.position, excluding: [actor.id, target.id]) {
            let hasSword = (actorNode(actor.id) as? CharacterAppearanceNode)?.definition.appearance.equipment.contains { $0.item == .lanternShortsword } == true
            strike(target, maneuver: combat.preferredManeuver(target: target, ranged: false, hasSword: hasSword)); return
        }
        // Spend only movement needed to approach; avoid wandering after attacking.
        if combat.budget.canAttack,
           let path = CombatNavigation.approach(in: scene.navigation, actor: actor, target: target,
                   limit: combat.budget.availableMovement(speed: combat.movementSpeed(for: actor))), move(path) { return }
        endCombatTurn(); delay = 0.5; checkpoint()
    }
    func update(at time: TimeInterval) {
        defer { lastTime = time }
        guard !finished else { return }
        let delta = min(0.1, max(0, time - (lastTime ?? time)))
        refresh()
        formEffect?.setPaused(presentationPaused)
        if presentationPaused { roarSound?.pause() }
        else if let roarSound, let ability = bearAbility, ability.action == .roar {
            if abs(roarSound.currentTime - ability.elapsed) > 0.1 { roarSound.currentTime = ability.elapsed }
            if !roarSound.isPlaying { roarSound.play() }
        }
        guard !presentationPaused else { return }
        for id in Array(hitReactions.keys) {
            hitReactions[id]?.elapsed += delta
            if presentedCombat.actors.contains(where: { $0.id == id && $0.isProne }), hitReactions[id]?.kind == .tripFall {
                let elapsed = hitReactions[id]!.elapsed
                hitReactions[id]?.elapsed = min(ProneMotion.holdTime, elapsed)
            }
        }
        for node in barrelNodes.values { node.advance(delta: delta) }
        for blast in blasts { blast.advance(delta: delta) }
        blasts.filter(\.finished).forEach { $0.removeFromParent() }
        blasts.removeAll(where: \.finished)
        if let attack = meleeAttack {
            attack.advance(delta: delta)
            if !attack.dodgePresented, attack.barrelDestruction == nil, attack.result.damage == 0,
               attack.elapsed >= attack.impactTime - CombatRecoil.dodgeLeadTime {
                attack.dodgePresented = true
                beginReaction(attack.result, target: attack.target, kind: .dodge,
                              elapsed: max(0, attack.elapsed - (attack.impactTime - CombatRecoil.dodgeLeadTime)))
            }
            if attack.elapsed >= attack.impactTime && !attack.impactPresented {
                attack.impactPresented = true
                if attack.target.player && attack.before.isBear && combat.isBear && attack.result.damage > 0 {
                    bearAction = (.hit, 0)
                }
                if let destruction = attack.barrelDestruction {
                    if let updated = combat.barrels?.first(where: { $0.id == attack.target.id }) {
                        barrelNodes[updated.id]?.apply(updated, destruction: destruction)
                    }
                    scene.navigation.unregisterActor(id: attack.target.id)
                    feedback = "Barrel broken. The spilled oil can still ignite."
                } else { presentImpact(attack.result, target: attack.target) }
                synchronizeForm(); refresh()
            }
            if attack.finished {
                attack.stop(); meleeAttack = nil; playerMeleeNode?.isHidden = true
                if attack.before.current.player {
                    for decoration in [badges[TacticalCombat.playerID], rings[TacticalCombat.playerID]] as [SKNode?] {
                        decoration?.removeFromParent()
                        if let decoration { actorNode(TacticalCombat.playerID)?.addChild(decoration) }
                    }
                    scene.detective.isHidden = displayingBear || !combat.actors.first(where: \.player)!.conscious
                }
            }
        }
        if let shot = rangedShot {
            shot.advance(delta: delta)
            if !shot.dodgePresented, shot.explosions.isEmpty, shot.result.damage == 0,
               shot.elapsed >= shot.impactTime - CombatRecoil.dodgeLeadTime {
                shot.dodgePresented = true
                beginReaction(shot.result, target: shot.target, kind: .dodge,
                              elapsed: max(0, shot.elapsed - (shot.impactTime - CombatRecoil.dodgeLeadTime)))
            }
            if shot.elapsed >= shot.impactTime && !shot.impactPresented {
                shot.impactPresented = true
                if shot.before.isBear && combat.isBear && shot.result.damage > 0 { bearAction = (.hit, 0) }
                if shot.explosions.isEmpty { presentImpact(shot.result, target: shot.target) }
                else {
                    for explosion in shot.explosions {
                        if let remains = combat.barrels?.first(where: { $0.id == explosion.barrel.id }) {
                            barrelNodes[remains.id]?.apply(remains, destruction: shot.destructions[remains.id])
                        }
                        scene.navigation.unregisterActor(id: explosion.barrel.id)
                        let blast = BarrelBlastVisual(at: explosion.barrel.position)
                        scene.depthWorldRoot.addChild(blast); blasts.append(blast)
                        for hit in explosion.hits {
                            if let target = shot.before.actors.first(where: { $0.id == hit.target }) { presentImpact(hit, target: target, reacts: false) }
                        }
                    }
                }
                if !shot.explosions.isEmpty {
                    knockbacks = shot.displacements
                    let impactElapsed = max(0, shot.elapsed - shot.impactTime)
                    // advanceKnockback still runs later this tick. Both clocks
                    // start at the same amount of time past the impact marker.
                    knockbackElapsed = impactElapsed - delta
                    beginExplosionReactions(shot, elapsed: impactElapsed)
                }
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
        updateBearAbility(delta: delta)
        updateShove(delta: delta)
        advanceKnockback(delta: delta)
        updateForm(delta: delta, time: time)
        updateReactions()
        if var mover = enemyMover, let id = movingID, let node = actorNode(id) as? CharacterAppearanceNode {
            for _ in 0..<movementTicks.drain(deltaTime: delta) {
                tick += 1
                _ = mover.doStep(walkScale: MovementProfile(rateMultiplier: combat.actors.first(where: { $0.id == id })?.hidden == true ? 0.5 : 1).walkScale ?? 0, time: tick)
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
        updateStealth(delta: delta)
        updateDefeats(delta: delta)
        updateBurning(delta: delta)
        guard bearAbility == nil, bearAction == nil, shovePresentation == nil, !defeatsAnimating, hideTransitions.isEmpty, movingID == nil, formTransition == nil, rangedShot == nil, meleeAttack == nil, blasts.isEmpty, knockbacks.isEmpty, !debrisMoving, !reactionsAnimating else { return }
        delay = max(0, delay - delta)
        guard delay == 0 else { return }
        if combat.outcome != nil { finish(); return }
        if !combat.isPlayerTurn { enemyTurn() }
    }
    private func beginExplosionReactions(_ shot: BowShotPresentation, elapsed: TimeInterval) {
        for target in shot.before.actors {
            let blasts = shot.explosions.filter { $0.hits.contains { $0.target == target.id && $0.damage > 0 } }
            guard let first = blasts.first,
                  let hit = first.hits.first(where: { $0.target == target.id }),
                  combat.actors.contains(where: { $0.id == target.id && $0.conscious }) else { continue }
            let move = shot.displacements.first { $0.id == target.id }
            let kind = ExplosionKnockbackMotion.reaction(
                distanceFromBlast: CombatNavigation.distance(target.position, first.barrel.position),
                blasts: blasts.count,
                travel: move.map { CombatNavigation.distance($0.from, $0.to) } ?? 0)
            beginReaction(hit, target: target, kind: kind, elapsed: elapsed, source: first.barrel.position)
        }
    }

    private func advanceKnockback(delta: TimeInterval) {
        guard !knockbacks.isEmpty else { return }
        knockbackElapsed += delta
        let settled = knockbacks.allSatisfy { knockbackElapsed >= ExplosionKnockbackMotion.stopTime(from: $0.from, to: $0.to) }
        for move in knockbacks {
            let point = ExplosionKnockbackMotion.position(from: move.from, to: move.to, elapsed: knockbackElapsed)
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
        if settled { knockbacks.removeAll() }
    }
    func finish() {
        guard !finished, !defeatsAnimating, combat.outcome != nil else { return }
        finished = true
        scene.detective.setCombatRecoil(0)
        crew.forEach { $0.setCombatRecoil(0) }; bearNode?.setCombatRecoil(0)
        hitReactions.removeAll(); reactionFacings.removeAll()
        reactionNodes.values.forEach { $0.removeFromParent() }; reactionNodes.removeAll()
        if let profile = preSneakMovementProfile { scene.detective.movementProfile = profile; preSneakMovementProfile = nil }
        stealthNodes.values.forEach { $0.removeFromParent() }; stealthNodes.removeAll(); hideTransitions.removeAll()
        burningNodes.values.forEach { $0.removeFromParent() }; burningNodes.removeAll()
        scene.context.session.finishCombat(combat)
        hud.removeFromParent(); routePreview.removeFromParent(); sightPreview.removeFromParent()
        badges.values.forEach { $0.removeFromParent() }; rings.values.forEach { $0.removeFromParent() }
        rangedShot?.stop(); rangedShot = nil
        playerBowNode?.removeFromParent()
        meleeAttack?.stop(); meleeAttack = nil
        playerMeleeNode?.removeFromParent()
        for (id, node) in barrelNodes {
            if combat.barrels?.first(where: { $0.id == id })?.isBroken != true { node.removeFromParent() }
            scene.navigation.unregisterActor(id: id)
        }
        barrelNodes.removeAll()
        blasts.forEach { $0.removeFromParent() }; blasts.removeAll()
        bearNode?.removeFromParent(); formEffect?.stop()
        roarWaves.forEach { $0.removeFromParent() }; roarWaves.removeAll(); bearAbility = nil; bearAction = nil
        roarSound?.stop(); roarSound = nil
        scene.detective.alpha = 1
        scene.detective.isHidden = defeatNodes[TacticalCombat.playerID] != nil
        if defeatNodes[TacticalCombat.playerID] == nil {
            scene.navigation.registerActor(id: TacticalCombat.playerID, kind: .player, at: scene.detective.position, radius: NavigationAgentProfile.detective.radius)
        }
        completion()
    }

    private func performRoar() {
        guard combat.canGoadingRoar else {
            feedback = combat.isBear ? (combat.bearForm?.roarSpent == true ? "Goading Roar is spent for this transformation." : "Goading Roar needs a standard action.") : "Goading Roar requires Bear Form."
            refresh(); return
        }
        let before = combat
        let visibleTargets = combat.roarTargets(clearLine: sneakLine)
        guard !visibleTargets.isEmpty else {
            feedback = "Goading Roar: no visible rivals within 30 feet. Move closer; nothing was spent."
            refresh(); return
        }
        guard combat.goadingRoar(clearLine: sneakLine) != nil else { return }
        cancelTargeting()
        if let nearest = visibleTargets.min(by: { CombatNavigation.distance(before.current.position, $0.position) < CombatNavigation.distance(before.current.position, $1.position) }) {
            bearFacing = .orient(from: before.current.position, to: nearest.position)
        }
        bearAbility = BearAbilityPresentation(before: before, action: .roar, strike: nil, targets: visibleTargets)
        roarSound = try? AVAudioPlayer(data: BearTransformationEffect.roarSoundData())
        roarSound?.volume = 0.45; roarSound?.prepareToPlay(); roarSound?.play()
        feedback = "Goading Roar: nearby rivals focus on the bear through their next turn."
        delay = 0.15
        for _ in 0..<3 {
            let wave = SKShapeNode(ellipseOf: CGSize(width: 2, height: 1.5))
            wave.strokeColor = SKColor(red: 1, green: 0.76, blue: 0.3, alpha: 1)
            wave.fillColor = .clear; wave.lineWidth = 0.04; wave.zPosition = 1
            wave.position = before.current.position; wave.isHidden = true
            scene.depthWorldRoot.addChild(wave); roarWaves.append(wave)
        }
        checkpoint(synchronize: false)
    }

    private func updateBearAbility(delta: Double) {
        guard var ability = bearAbility else { return }
        ability.elapsed += delta
        if let strike = ability.strike, strike.damage == 0,
           ability.elapsed >= ability.impactTime - CombatRecoil.dodgeLeadTime,
           hitReactions[strike.target] == nil, !ability.impactPresented {
            beginReaction(strike, target: ability.targets[0], kind: .dodge,
                          elapsed: max(0, ability.elapsed - (ability.impactTime - CombatRecoil.dodgeLeadTime)))
        }
        if !ability.impactPresented && ability.elapsed >= ability.impactTime {
            ability.impactPresented = true
            bearAbility = ability
            if let strike = ability.strike { presentImpact(strike, target: ability.targets[0]) }
            else {
                for target in ability.targets {
                    let response = TacticalCombat.Strike(attacker: ability.before.current.id, target: target.id, roll: 0, damage: 0, knockedOut: false)
                    beginReaction(response, target: target, kind: .hit)
                }
            }
            refresh()
        }
        for (i, wave) in roarWaves.enumerated() {
            let t = (ability.elapsed - ability.impactTime - Double(i) * 0.10) / 0.5
            wave.isHidden = t < 0 || t >= 1
            wave.setScale(CGFloat(16 + BearFormRules.roarRadius * min(1, max(0, t))))
            wave.alpha = CGFloat(0.55 * (1 - min(1, max(0, t))))
        }
        if ability.elapsed >= ability.duration {
            bearAbility = nil
            roarSound?.stop(); roarSound = nil
            roarWaves.forEach { $0.removeFromParent() }; roarWaves.removeAll()
        } else { bearAbility = ability }
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
        cancelTargeting()
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
        } else if let ability = bearAbility {
            let fps = ability.action == .roar ? 20.0 : BearFormRules.clawFPS
            let count = (try? BearAnimationSet.frameCount(for: ability.action)) ?? 1
            try? bearNode.present(action: ability.action, facing: bearFacing, phase: min(count - 1, Int(ability.elapsed * fps)))
        } else if var action = bearAction {
            action.elapsed += delta
            let count = (try? BearAnimationSet.frameCount(for: action.action)) ?? 1
            let fps = action.action == .attack ? BearFormRules.clawFPS : 15.0
            let frame = min(count - 1, Int(action.elapsed * fps))
            try? bearNode.present(action: action.action, facing: bearFacing, phase: frame)
            bearAction = action.elapsed >= Double(count) / fps ? nil : action
        } else {
            try? bearNode.advance(action: movingID == TacticalCombat.playerID ? .walk : .idle,
                                  facing: bearFacing, at: time, paused: false)
        }
        scene.applyAreaLighting(to: bearNode)
        scene.updateDepth(of: bearNode)
        scene.applyActorCover(to: bearNode, at: bearNode.position)
    }
}

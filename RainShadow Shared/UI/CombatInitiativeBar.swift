import SpriteKit

/// A presentation of the combat core's stable initiative order, never a second
/// turn scheduler. The director supplies presentedCombat to preserve hit timing.
@MainActor
final class CombatInitiativeBar: SKNode {
    struct Entry: Equatable {
        let id: String
        let name: String
        let initiative: Int
        let allied: Bool
        let active: Bool
        let acted: Bool
        let portrait: String
        let health: Int
        let maximumHealth: Int
        let status: String
    }

    private(set) var entries: [Entry] = []
    private(set) var activeID: String?
    private let cards = SKNode()
    private let caption = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private var availableWidth: CGFloat = 820
    private var textures: [String: SKTexture] = [:]

    override init() {
        super.init()
        name = "combat.initiative"
        addChild(cards)
        caption.fontSize = 12
        caption.fontColor = SKColor(red: 0.94, green: 0.86, blue: 0.68, alpha: 1)
        caption.verticalAlignmentMode = .center
        caption.position.y = 53
        caption.name = "combat.initiative.caption"
        addChild(caption)
    }

    required init?(coder: NSCoder) { fatalError("Created in code") }

    func layout(width: CGFloat) {
        guard availableWidth != width else { return }
        availableWidth = width
        caption.preferredMaxLayoutWidth = width
        caption.numberOfLines = 2
        rebuildCards()
    }

    func update(combat: TacticalCombat, paused: Bool) {
        let activeIndex = combat.actors.firstIndex { $0.id == combat.current.id }!
        let next = combat.actors.enumerated().compactMap { index, actor -> Entry? in
            guard actor.conscious else { return nil }
            let bear = actor.player && combat.isBear
            let status = [actor.conditions?.label, actor.isBurning ? "Burning" : nil,
                          actor.hidden == true ? "Hidden" : nil, actor.defending ? "Guard" : nil]
                .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
            return Entry(id: actor.id, name: actor.name, initiative: actor.initiative,
                         allied: actor.player, active: actor.id == combat.current.id,
                         acted: index < activeIndex,
                         portrait: bear ? "bear_portrait_guardian" : actor.player
                            ? "dialogue_portrait_harlan_voss_v01" : "initiative_dockhand_portrait_v01",
                         health: bear ? combat.bearForm!.temporaryHP : actor.hp,
                         maximumHealth: bear ? BearFormRules.maximumEndurance : actor.maximumHP,
                         status: status)
        }
        activeID = combat.current.id
        caption.text = "ROUND \(combat.round)  ·  \(combat.current.name.uppercased())\(paused ? "  ·  PAUSED [Space]" : "")"
        guard next != entries else { return }
        entries = next
        rebuildCards()
    }

    private func texture(_ name: String) -> SKTexture? {
        if let cached = textures[name] { return cached }
        guard let result = GameArt.texture(named: name) else {
            assertionFailure("Missing initiative art: \(name)"); return nil
        }
        result.filteringMode = .linear
        textures[name] = result
        return result
    }

    private func rebuildCards() {
        cards.removeAllChildren()
        // Scale the whole strip at narrow widths; its order and every combatant
        // remain visible. No horizontal overflow into the existing side rails.
        let spacing: CGFloat = 78
        let naturalWidth = max(1, CGFloat(entries.count) * spacing)
        cards.setScale(min(1, availableWidth / naturalWidth))
        for (index, entry) in entries.enumerated() {
            let root = SKNode()
            root.name = "combat.initiative.actor.\(entry.id)"
            root.position.x = (CGFloat(index) - CGFloat(entries.count - 1) / 2) * spacing
            root.alpha = entry.acted ? 0.57 : 1
            cards.addChild(root)

            let team = entry.allied ? SKColor(red: 0.19, green: 0.65, blue: 0.94, alpha: 1)
                                   : SKColor(red: 0.85, green: 0.24, blue: 0.22, alpha: 1)
            let well = SKShapeNode(rectOf: CGSize(width: 59, height: 59), cornerRadius: 2)
            well.fillColor = SKColor(white: 0.035, alpha: 0.98)
            well.strokeColor = team
            well.lineWidth = 3
            root.addChild(well)

            let portrait = SKSpriteNode(texture: texture(entry.portrait), size: CGSize(width: 54, height: 54))
            portrait.name = "combat.initiative.portrait"
            portrait.zPosition = 1
            root.addChild(portrait)

            let frame = SKSpriteNode(texture: texture("initiative_portrait_frame_v01"), size: CGSize(width: 72, height: 72))
            frame.zPosition = 2
            root.addChild(frame)

            let outline = SKShapeNode(rectOf: CGSize(width: 65, height: 65), cornerRadius: 2)
            outline.strokeColor = entry.active ? SKColor(red: 1, green: 0.86, blue: 0.43, alpha: 1) : team
            outline.lineWidth = entry.active ? 2.5 : 1.5
            outline.glowWidth = entry.active ? 2 : 0
            outline.fillColor = .clear
            outline.zPosition = 3
            root.addChild(outline)

            if entry.active {
                let marker = CGMutablePath()
                marker.move(to: CGPoint(x: -5, y: 41)); marker.addLine(to: CGPoint(x: 5, y: 41))
                marker.addLine(to: CGPoint(x: 0, y: 35)); marker.closeSubpath()
                let arrow = SKShapeNode(path: marker)
                arrow.name = "combat.initiative.active"
                arrow.fillColor = outline.strokeColor; arrow.strokeColor = .clear
                root.addChild(arrow)
            }

            let healthBack = SKSpriteNode(color: SKColor(white: 0.05, alpha: 1), size: CGSize(width: 53, height: 3))
            healthBack.position.y = -26; healthBack.zPosition = 3
            root.addChild(healthBack)
            let ratio = min(1, max(0, CGFloat(entry.health) / CGFloat(max(1, entry.maximumHealth))))
            let health = SKSpriteNode(color: team, size: CGSize(width: 53 * ratio, height: 3))
            health.anchorPoint.x = 0; health.position = CGPoint(x: -26.5, y: -26); health.zPosition = 4
            root.addChild(health)

            let rollBack = SKShapeNode(circleOfRadius: 10)
            rollBack.fillColor = SKColor(white: 0.055, alpha: 1); rollBack.strokeColor = team
            rollBack.position = CGPoint(x: 25, y: -27); rollBack.zPosition = 5
            let roll = label("\(entry.initiative)", size: 11)
            roll.position.y = 0; rollBack.addChild(roll); root.addChild(rollBack)

            let title = label(entry.name, size: 11)
            title.position.y = -43; title.preferredMaxLayoutWidth = 74
            root.addChild(title)
            if !entry.status.isEmpty {
                let state = label(entry.status, size: 9)
                state.fontColor = SKColor(red: 1, green: 0.77, blue: 0.48, alpha: 1)
                state.position.y = -57; state.preferredMaxLayoutWidth = 74; state.numberOfLines = 2
                root.addChild(state)
            }
        }
    }

    private func label(_ text: String, size: CGFloat) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = text; label.fontSize = size; label.fontColor = .white
        label.verticalAlignmentMode = .center
        return label
    }
}

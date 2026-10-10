import SpriteKit

/// Generated glyphs and chrome are presentation only. Commands keep their
/// existing names and indices in TacticalCombatDirector.
@MainActor
final class CombatActionButton: SKShapeNode {
    var titleText: String
    let detail: String
    let glyph = SKSpriteNode()
    let badge = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let key = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let endTitle = SKLabelNode(fontNamed: UITheme.Font.hudVital)
    private(set) var glyphIndex = -1
    static let fleeGlyph = 20
    private static let sheet = GameArt.texture(named: "combat_action_inkwash_v02")
    private static var glyphTextures: [Int: SKTexture] = [:]
    private static let slots = GameArt.texture(named: "combat_action_slots_v01")
    private static var slotTextures: [Int: SKTexture] = [:]
    private static let paper = UIPaintedChrome.parchmentSurface()
    static let selectionColor = SKColor(red: 0.13, green: 0.34, blue: 0.38, alpha: 1)
    private static var washes: [String: SKShader] = [:]
    private static var inks: [String: SKShader] = [:]
    private static func slotIndex(for glyph: Int) -> Int {
        switch glyph {
        case 1, 6, 7, 17: return 1
        case 2, 8, 9: return 2
        case 3, 13, 14: return 3
        case 10, 11, 15, 16, fleeGlyph: return 4
        case 18: return 5
        default: return 0
        }
    }

    private static func slot(for glyph: Int) -> SKTexture? {
        let index = slotIndex(for: glyph)
        if let cached = slotTextures[index] { return cached }
        guard let image = slots?.cgImage() else { return nil }
        // Measured painted frames in the generated 1536×1024 master. Exclude
        // the sheet's gutters; the button's existing rounded path clips corners.
        let xs: [CGFloat] = [55, 535, 1009]
        let ys: [CGFloat] = [55, 513]
        let rect = CGRect(x: xs[index % 3], y: ys[index / 3], width: 472, height: 447)
        let scaled = CGRect(x: rect.minX * CGFloat(image.width) / 1536,
                            y: rect.minY * CGFloat(image.height) / 1024,
                            width: rect.width * CGFloat(image.width) / 1536,
                            height: rect.height * CGFloat(image.height) / 1024)
        guard let crop = image.cropping(to: scaled) else { return nil }
        let texture = SKTexture(cgImage: crop); texture.filteringMode = .linear
        slotTextures[index] = texture
        return texture
    }
    // Colour only the existing pigment. The painting still supplies coverage,
    // brush grain and diluted edges; parchment and button chrome stay separate.
    private static func ink(for index: Int) -> SKShader {
        let low: String, middle: String, high: String
        switch index {
        case 1, 6, 7, 17: // Bow and ordinary ammunition: blue.
            (low, middle, high) = ("0.055, 0.15, 0.25", "0.10, 0.37, 0.56", "0.27, 0.61, 0.72")
        case 2, 8, 9: // Ward and stealth: violet.
            (low, middle, high) = ("0.20, 0.08, 0.27", "0.42, 0.21, 0.53", "0.65, 0.40, 0.68")
        case 3, 13, 14: // Bear abilities: green.
            (low, middle, high) = ("0.10, 0.20, 0.075", "0.29, 0.43, 0.12", "0.55, 0.62, 0.24")
        case 10, 11, 15, 16, fleeGlyph: // Utility and movement: teal.
            (low, middle, high) = ("0.045, 0.21, 0.18", "0.08, 0.43, 0.36", "0.30, 0.65, 0.52")
        case 18: // Fire ammunition changes colour along with its symbol.
            (low, middle, high) = ("0.35, 0.055, 0.025", "0.77, 0.22, 0.045", "0.94, 0.55, 0.12")
        default: // Sword techniques and End Turn: amber.
            (low, middle, high) = ("0.26, 0.105, 0.025", "0.61, 0.29, 0.055", "0.84, 0.55, 0.17")
        }
        let key = low + middle + high
        if let shader = inks[key] { return shader }
        let shader = SKShader(source: """
        void main() {
            vec3 sampleColor = texture2D(u_texture, v_tex_coord).rgb;
            float density = 1.0 - dot(sampleColor, vec3(0.299, 0.587, 0.114));
            float coverage = smoothstep(0.035, 0.98, density);
            float height = clamp(v_tex_coord.y * 0.88 + v_tex_coord.x * 0.12, 0.0, 1.0);
            vec3 ink = mix(vec3(\(low)), vec3(\(middle)), smoothstep(0.05, 0.55, height));
            ink = mix(ink, vec3(\(high)), smoothstep(0.50, 0.95, height));
            ink *= mix(0.85, 1.0, density);
            gl_FragColor = vec4(ink * coverage, coverage) * v_color_mix.a;
        }
        """)
        inks[key] = shader
        return shader
    }

    init(name: String, title: String, glyph: Int, shortcut: String, detail: String) {
        titleText = title; self.detail = detail
        super.init()
        self.name = name
        fillColor = .white
        fillTexture = Self.paper
        fillShader = Self.wash(for: name)
        strokeColor = UITheme.Color.engraved; lineWidth = 1
        addChild(self.glyph)
        for label in [key, badge, endTitle] {
            label.fontColor = UITheme.Color.ink
            label.verticalAlignmentMode = .center
            addChild(label)
        }
        key.text = shortcut; key.fontSize = 9
        badge.fontSize = 10; badge.horizontalAlignmentMode = .right
        endTitle.text = "End Turn"; endTitle.fontSize = 12
        setGlyph(glyph)
        configureSize(largeEnd: false)
    }

    required init?(coder: NSCoder) { fatalError("Created in code") }

    private static func wash(for name: String) -> SKShader {
        let tint: String
        switch name {
        case "combat.ranged", "combat.aimedShot", "combat.pinningShot", "combat.ammunition": tint = "0.66, 0.78, 0.84"
        case "combat.bear", "combat.claw", "combat.roar": tint = "0.70, 0.78, 0.59"
        case "combat.bladeWard", "combat.hide", "combat.sneak": tint = "0.79, 0.68, 0.80"
        case "combat.end": tint = "0.87, 0.62, 0.47"
        default: tint = "0.89, 0.73, 0.48"
        }
        if let shader = washes[tint] { return shader }
        let shader = SKShader(source: """
            void main() {
                vec3 paper = texture2D(u_texture, v_tex_coord).rgb;
                float blend = smoothstep(0.0, 1.0, v_tex_coord.y);
                vec3 wash = mix(vec3(1.0), mix(vec3(\(tint)), vec3(1.0, 0.98, 0.93), blend), 0.24);
                gl_FragColor = vec4(paper * wash, 1.0) * v_color_mix.a;
            }
            """)
        washes[tint] = shader
        return shader
    }

    func updateSelectionAppearance() {
        lineWidth = strokeColor == Self.selectionColor || strokeColor == .orange ? 2.5 : 1
    }

    func setGlyph(_ index: Int) {
        guard index != glyphIndex else { return }
        glyphIndex = index
        glyph.shader = Self.ink(for: index)
        if name != "combat.end", let slot = Self.slot(for: index) {
            fillTexture = slot
            fillShader = nil
        }
        if let cached = Self.glyphTextures[index] { glyph.texture = cached; return }
        if index == Self.fleeGlyph {
            let texture = GameArt.texture(named: "combat_flee_inkwash_v01")
            texture?.filteringMode = .linear
            Self.glyphTextures[index] = texture
            glyph.texture = texture
            return
        }
        if let sheet = Self.sheet {
            // Isolate each painted cell and cache it with local 0–1 shader UVs.
            let image = sheet.cgImage()
            let w = Double(image.width) / 5, h = Double(image.height) / 4
            guard let cell = image.cropping(to: CGRect(x: Double(index % 5) * w,
                y: Double(index / 5) * h, width: w, height: h)) else { return }
            let texture = SKTexture(cgImage: cell)
            texture.filteringMode = .linear
            Self.glyphTextures[index] = texture
            glyph.texture = texture
        }
    }

    func configureSize(largeEnd: Bool) {
        let end = name == "combat.end"
        let side: CGFloat = largeEnd ? 68 : 48
        path = end ? CGPath(ellipseIn: CGRect(x: -side / 2, y: -side / 2, width: side, height: side), transform: nil)
            : CGPath(roundedRect: CGRect(x: -24, y: -24, width: 48, height: 48), cornerWidth: 3, cornerHeight: 3, transform: nil)
        glyph.size = end ? CGSize(width: 27, height: 27) : CGSize(width: 43, height: 43)
        glyph.position.y = end ? 9 : 1
        // Keep counters and shortcuts inside the painted rim, on pale paper.
        key.position = CGPoint(x: -16, y: -15)
        badge.position = CGPoint(x: 18, y: -15)
        key.isHidden = end
        endTitle.isHidden = !end; endTitle.fontSize = largeEnd ? 12 : 10
        endTitle.position.y = -14
    }
}

@MainActor
final class CombatActionBar: SKNode {
    private let plate = SKSpriteNode()
    private let plateMount = SKNode()
    private let portrait = SKSpriteNode()
    private let portraitFrame = SKSpriteNode(texture: GameArt.texture(named: "initiative_portrait_frame_v01"))
    private let health = SKLabelNode(fontNamed: UITheme.Font.hudVital)
    private let resources = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let tooltip = SKShapeNode()
    private let tooltipText = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private var portraitName = ""
    private var availableWidth: CGFloat = 820
    private(set) var height: CGFloat = 146
    private(set) var tooltipTitle: String?
    private weak var inspectedButton: CombatActionButton?

    override init() {
        super.init()
        name = "combat.actionBar"
        if let texture = GameArt.texture(named: "ui_folio_strip_fantasy_v01") {
            // Same generated parchment master used by inventory's folio sections.
            plate.texture = texture
            plate.texture?.filteringMode = .linear
        }
        plate.centerRect = CGRect(x: 0.06, y: 0.24, width: 0.88, height: 0.52)
        // Nine-slice caps are source pixels. Scale the painting down while
        // sizing the centre in the inverse space, so borders stay thin at play size.
        plateMount.name = "combat.actionBar.chrome"
        plateMount.setScale(0.5)
        plateMount.zPosition = -2; addChild(plateMount); plateMount.addChild(plate)
        portrait.size = CGSize(width: 66, height: 66)
        portraitFrame.size = CGSize(width: 84, height: 84)
        for node in [portrait, portraitFrame, health, resources, tooltip] { addChild(node) }
        health.fontSize = 14; health.fontColor = UITheme.Color.ink
        resources.fontSize = 10; resources.fontColor = UITheme.Color.ink
        health.verticalAlignmentMode = .center; resources.verticalAlignmentMode = .center
        tooltip.zPosition = 5; tooltip.isHidden = true
        tooltip.fillColor = .white
        tooltip.fillTexture = UIPaintedChrome.parchmentSurface()
        tooltip.strokeColor = UITheme.Color.engraved
        tooltipText.fontSize = 12; tooltipText.fontColor = UITheme.Color.ink
        tooltipText.verticalAlignmentMode = .center; tooltipText.numberOfLines = 4
        tooltip.addChild(tooltipText)
    }

    required init?(coder: NSCoder) { fatalError("Created in code") }

    func layout(width: CGFloat, buttons: [CombatActionButton]) {
        availableWidth = width
        let wide = width >= 560
        let grid = buttons.filter { !wide || $0.name != "combat.end" }
        let gridWidth = wide ? width - 224 : width - 32
        let columns = max(1, min(8, grid.count, Int(gridWidth / 54)))
        let rows = Int(ceil(Double(grid.count) / Double(columns)))
        height = max(150, CGFloat(rows) * 54 + 42)
        plate.size = CGSize(width: width * 2, height: height * 2)
        for (index, button) in grid.enumerated() {
            button.configureSize(largeEnd: false)
            button.position = CGPoint(x: (CGFloat(index % columns) - CGFloat(columns - 1) / 2) * 54,
                y: CGFloat(rows - 1) * 27 - 4 - CGFloat(index / columns) * 54)
        }
        if wide, let end = buttons.first(where: { $0.name == "combat.end" }) {
            end.configureSize(largeEnd: true)
            end.position = CGPoint(x: width / 2 - 57, y: -4)
        }
        portrait.isHidden = !wide; portraitFrame.isHidden = !wide
        portrait.position = CGPoint(x: -width / 2 + 58, y: 4)
        portraitFrame.position = portrait.position
        health.position = wide ? CGPoint(x: portrait.position.x, y: -49)
            : CGPoint(x: -width / 2 + 57, y: height / 2 - 15)
        resources.position = CGPoint(x: wide ? 0 : 44, y: height / 2 - 15)
        resources.fontSize = wide ? 10 : 9
        showTooltip(nil)
    }

    func update(combat: TacticalCombat) {
        guard let player = combat.actors.first(where: \.player) else { return }
        let next = combat.isBear ? "bear_portrait_guardian" : "dialogue_portrait_harlan_voss_v01"
        if portraitName != next {
            portraitName = next; portrait.texture = GameArt.texture(named: next)
            portrait.texture?.filteringMode = .linear
        }
        let hp = combat.isBear ? combat.bearForm!.temporaryHP : player.hp
        let maximum = combat.isBear ? BearFormRules.maximumEndurance : player.maximumHP
        health.text = "\(hp) / \(maximum)"
        let move = Int(combat.budget.availableMovement(speed: combat.movementSpeed(for: player)) / 8)
        resources.text = combat.isPlayerTurn
            ? "\(combat.budget.canAttack ? "◆ ATTACK" : "◇ SPENT")   ·   MOVE \(move) ft"
            : "ENEMY TURN"
    }

    func showTooltip(_ button: CombatActionButton?) {
        inspectedButton = button
        tooltipTitle = button?.titleText
        tooltip.isHidden = button == nil
        guard let button else { return }
        let width = min(380, availableWidth - 12)
        tooltip.path = CGPath(roundedRect: CGRect(x: -width / 2, y: -43, width: width, height: 86), cornerWidth: 5, cornerHeight: 5, transform: nil)
        tooltipText.preferredMaxLayoutWidth = width - 22
        tooltipText.text = button.titleText + "\n" + button.detail
            + (button.alpha < 0.9 ? "\nUnavailable this turn or requirements unmet." : "")
        tooltip.position = CGPoint(x: max(-availableWidth / 2 + width / 2 + 6,
            min(availableWidth / 2 - width / 2 - 6, button.position.x)), y: height / 2 + 52)
    }

    func refreshTooltip() {
        if let button = inspectedButton { showTooltip(button.isHidden ? nil : button) }
    }

    func containsChrome(at point: CGPoint) -> Bool {
        plate.contains(plateMount.convert(point, from: self)) || (!tooltip.isHidden && tooltip.contains(point))
    }
}

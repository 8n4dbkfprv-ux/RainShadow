import SpriteKit

/// A presentation of the certified route, never an alternate navigation query.
/// Splitting a segment changes its colour only; walking still uses the original Path.
@MainActor final class CombatMovementPreview: SKNode {
    struct Geometry {
        let points: [CGPoint]
        let reachable: [CGPoint]
        let excess: [CGPoint]
        let distance: Double
        var endpoint: CGPoint? { points.last }

        init(points: [CGPoint], allowance: Double) {
            self.points = points
            var reachable = points.first.map { [$0] } ?? []
            var excess: [CGPoint] = []
            var spent = 0.0
            let limit = max(0, allowance)
            for (a, b) in zip(points, points.dropFirst()) {
                let length = CombatNavigation.distance(a, b)
                guard length > 0 else { continue }
                if spent + length <= limit {
                    reachable.append(b)
                } else if spent <= limit {
                    let fraction = CGFloat((limit - spent) / length)
                    let cut = CGPoint(x: a.x + (b.x - a.x) * fraction, y: a.y + (b.y - a.y) * fraction)
                    if reachable.last != cut { reachable.append(cut) }
                    excess.append(contentsOf: [cut, b])
                } else {
                    if excess.isEmpty { excess.append(a) }
                    excess.append(b)
                }
                spent += length
            }
            self.reachable = reachable; self.excess = excess; distance = spent
        }
    }

    private(set) var geometry = Geometry(points: [], allowance: 0)
    private(set) var canMove = false
    private let outline = SKShapeNode()
    private let available = SKShapeNode()
    private let unavailable = SKShapeNode()
    private let boundary = SKShapeNode()
    private let marker = SKShapeNode()
    private let caption = SKNode()
    private let distanceShadow = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let hintShadow = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let distanceLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let hintLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private static let reachableColor = SKColor.white
    private static let blocked = SKColor(red: 1, green: 0.22, blue: 0.20, alpha: 1)
    var captionText: String { distanceLabel.text ?? "" }

    override init() {
        super.init()
        name = "combat.movementPreview"
        isHidden = true
        for node in [outline, available, unavailable] {
            node.lineCap = .round; node.lineJoin = .round
            node.fillColor = .clear; addChild(node)
        }
        outline.strokeColor = SKColor(white: 0.06, alpha: 0.85)
        available.strokeColor = Self.reachableColor
        unavailable.strokeColor = Self.blocked
        available.zPosition = 1; unavailable.zPosition = 1
        boundary.fillColor = Self.blocked; boundary.strokeColor = SKColor(white: 0.06, alpha: 1)
        boundary.zPosition = 2; addChild(boundary)
        marker.name = "combat.movementDestination"
        marker.fillColor = .clear
        marker.zPosition = 3; addChild(marker)
        caption.zPosition = 4; addChild(caption)
        for label in [distanceShadow, hintShadow, distanceLabel, hintLabel] {
            label.verticalAlignmentMode = .center; caption.addChild(label)
        }
        distanceLabel.zPosition = 1; hintLabel.zPosition = 1
        distanceLabel.fontSize = 13; distanceLabel.position.y = 8
        hintLabel.fontSize = 11; hintLabel.position.y = -8
        hintLabel.fontColor = .white
        for (shadow, label) in [(distanceShadow, distanceLabel), (hintShadow, hintLabel)] {
            shadow.fontSize = label.fontSize; shadow.fontColor = .black
            shadow.position = CGPoint(x: 1, y: label.position.y - 1)
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func clear() { isHidden = true }

    func show(path: Path, actor: Combatant, budget: CombatBudget, speed: Double, cameraScale: CGFloat) {
        let allowance = budget.availableMovement(speed: speed)
        geometry = Geometry(points: [actor.position] + path.remainingPoints, allowance: allowance)
        guard let end = geometry.endpoint, geometry.distance > 0 else { clear(); return }
        var after = budget
        canMove = after.move(distance: geometry.distance, speed: speed)
        outline.path = Self.path(geometry.points)
        available.path = Self.path(geometry.reachable)
        unavailable.path = Self.path(geometry.excess)
        marker.position = end
        marker.strokeColor = canMove ? .white : Self.blocked
        boundary.isHidden = geometry.excess.isEmpty
        boundary.position = geometry.excess.first ?? end
        distanceLabel.fontColor = canMove ? Self.reachableColor : Self.blocked
        let feet = String(format: "%.1f", geometry.distance / 8)
        let remaining = String(format: "%.1f", max(0, allowance - geometry.distance) / 8)
        distanceLabel.text = "\(feet) ft"
        hintLabel.text = canMove ? "\(remaining) ft remaining" : budget.canAttack
            ? "Not enough movement · Dash available" : "Not enough movement"
        distanceShadow.text = distanceLabel.text; hintShadow.text = hintLabel.text
        isHidden = false
        updateScale(cameraScale)
    }

    func advance(delta: TimeInterval, cameraScale: CGFloat) {
        guard !isHidden else { return }
        updateScale(cameraScale)
    }

    private func updateScale(_ cameraScale: CGFloat) {
        let scale = max(0.01, cameraScale)
        outline.lineWidth = 3.5 * scale
        available.lineWidth = 1.5 * scale; unavailable.lineWidth = 1.5 * scale
        // Ground projection is the same 0.75 as the actor rings. The endpoint
        // stays in world space; thin strokes and the caption stay legible at zoom.
        let diameter = max(40, 24 * scale)
        marker.path = CGPath(ellipseIn: CGRect(x: -diameter / 2, y: -diameter * 0.375,
                                              width: diameter, height: diameter * 0.75), transform: nil)
        marker.lineWidth = 1.3 * scale
        let diamond = CGMutablePath()
        diamond.move(to: CGPoint(x: 0, y: 4 * scale))
        diamond.addLine(to: CGPoint(x: 4 * scale, y: 0))
        diamond.addLine(to: CGPoint(x: 0, y: -4 * scale))
        diamond.addLine(to: CGPoint(x: -4 * scale, y: 0)); diamond.closeSubpath()
        boundary.path = diamond; boundary.lineWidth = scale
        caption.setScale(scale)
        caption.position = CGPoint(x: marker.position.x, y: marker.position.y + diameter * 0.375 + 25 * scale)
    }

    private static func path(_ points: [CGPoint]) -> CGPath? {
        guard points.count > 1, let first = points.first else { return nil }
        let path = CGMutablePath(); path.move(to: first)
        points.dropFirst().forEach { path.addLine(to: $0) }
        return path
    }
}

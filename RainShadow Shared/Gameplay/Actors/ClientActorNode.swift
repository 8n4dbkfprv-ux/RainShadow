import SpriteKit

@MainActor
final class ClientActorNode: SKNode {
    private let contactShadow: SKShapeNode
    private let body: SKSpriteNode
    private let arrivalTextures: [SKTexture]
    private let departureTextures: [SKTexture]

    override init() {
        // 8 authored walk phases + a final standing idle frame (index 08).
        arrivalTextures = (0..<(ActorLocomotionPacing.walkFramesPerCycle + 1)).compactMap {
            GameArt.texture(named: String(format: "lila_arrival_sw_%02d", $0))
        }
        departureTextures = (0..<ActorLocomotionPacing.walkFramesPerCycle).compactMap {
            GameArt.texture(named: String(format: "lila_departure_ne_%02d", $0))
        }

        contactShadow = SKShapeNode(ellipseOf: CGSize(width: 44, height: 15))
        contactShadow.fillColor = SKColor(white: 0, alpha: 0.32)
        contactShadow.strokeColor = .clear
        contactShadow.position = CGPoint(x: 0, y: 3)
        contactShadow.setScale(OfficeInteriorScale.ActorDisplay.standingScale)

        if let texture = arrivalTextures.last {
            body = SKSpriteNode(texture: texture, size: CGSize(width: 256, height: 256))
        } else {
            body = SKSpriteNode(
                color: SKColor(red: 0.18, green: 0.08, blue: 0.1, alpha: 1),
                size: CGSize(width: 42, height: OfficeInteriorScale.clientBodyHeight)
            )
        }
        body.anchorPoint = CGPoint(x: 0.5, y: 39 / 256)
        body.texture?.filteringMode = .nearest
        // Same adult standing scale as DetectiveActorNode (BG:EE shared party height).
        body.xScale = OfficeInteriorScale.ActorDisplay.standingScale
        body.yScale = OfficeInteriorScale.ActorDisplay.standingScale

        super.init()
        name = "client.lilaMarch"
        addChild(contactShadow)
        addChild(body)
        isHidden = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("ClientActorNode is created programmatically")
    }

    func performEntrance(along points: [CGPoint], completion: @escaping () -> Void) {
        guard let start = points.first else {
            completion()
            return
        }

        removeAllActions()
        body.removeAllActions()
        body.position = .zero
        position = start
        alpha = 0
        isHidden = false

        let walkingFrames = Array(arrivalTextures.prefix(ActorLocomotionPacing.walkFramesPerCycle))
        if walkingFrames.count == ActorLocomotionPacing.walkFramesPerCycle {
            walkingFrames.forEach { $0.filteringMode = .nearest }
            body.run(
                .repeatForever(.animate(
                    with: walkingFrames,
                    timePerFrame: ActorLocomotionPacing.walkCycleSecondsPerFrame
                )),
                withKey: "clientWalkCycle"
            )
        }

        var actions: [SKAction] = [.fadeIn(withDuration: 0.22)]
        var prior = start
        for destination in points.dropFirst() {
            let distance = hypot(destination.x - prior.x, destination.y - prior.y)
            let movement = SKAction.move(
                to: destination,
                duration: ActorLocomotionPacing.pathDuration(distance: distance)
            )
            movement.timingMode = .linear
            actions.append(movement)
            prior = destination
        }
        actions.append(.run { [weak self] in
            guard let self else { return }
            self.body.removeAction(forKey: "clientWalkCycle")
            if let idle = self.arrivalTextures.last {
                self.body.texture = idle
                self.body.texture?.filteringMode = .nearest
            }
            self.startIdle()
            completion()
        })
        run(.sequence(actions), withKey: "clientEntrance")
    }

    func performExit(along points: [CGPoint], completion: @escaping () -> Void) {
        guard let start = points.first else {
            completion()
            return
        }

        removeAllActions()
        body.removeAllActions()
        body.position = .zero
        position = start

        if departureTextures.count == ActorLocomotionPacing.walkFramesPerCycle {
            departureTextures.forEach { $0.filteringMode = .nearest }
            body.texture = departureTextures[0]
            body.run(
                .repeatForever(.animate(
                    with: departureTextures,
                    timePerFrame: ActorLocomotionPacing.walkCycleSecondsPerFrame
                )),
                withKey: "clientWalkCycle"
            )
        }

        var actions: [SKAction] = []
        var prior = start
        for destination in points.dropFirst() {
            let distance = hypot(destination.x - prior.x, destination.y - prior.y)
            let movement = SKAction.move(
                to: destination,
                duration: ActorLocomotionPacing.pathDuration(distance: distance)
            )
            movement.timingMode = .linear
            actions.append(movement)
            prior = destination
        }
        actions.append(.fadeOut(withDuration: 0.2))
        actions.append(.run { [weak self] in
            guard let self else { return }
            self.body.removeAction(forKey: "clientWalkCycle")
            self.isHidden = true
            completion()
        })
        run(.sequence(actions), withKey: "clientExit")
    }

    private func startIdle() {
        body.removeAction(forKey: "clientIdle")
        body.run(
            .repeatForever(.sequence([
                .moveBy(x: 0, y: 1, duration: 0.85),
                .moveBy(x: 0, y: -1, duration: 0.9)
            ])),
            withKey: "clientIdle"
        )
    }
}

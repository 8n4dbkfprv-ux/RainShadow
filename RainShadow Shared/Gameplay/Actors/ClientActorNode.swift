import SpriteKit

@MainActor
final class ClientActorNode: SKNode {
    private enum DepartureFacingBin {
        case northEast
        case northWest
    }

    private static let stripHandoffDuration: TimeInterval = 0.16

    private let contactShadow: SKShapeNode
    private let body: SKSpriteNode
    /// Holds the outgoing departure strip during a facing handoff crossfade.
    private let bodyHandoff: SKSpriteNode
    private let arrivalTextures: [SKTexture]
    private let departureNETextures: [SKTexture]
    private let departureNWTextures: [SKTexture]

    override init() {
        // 8 authored walk phases + a final standing idle frame (index 08).
        arrivalTextures = (0..<(ActorLocomotionPacing.walkFramesPerCycle + 1)).compactMap {
            GameArt.texture(named: String(format: "lila_arrival_sw_%02d", $0))
        }
        departureNETextures = (0..<ActorLocomotionPacing.walkFramesPerCycle).compactMap {
            GameArt.texture(named: String(format: "lila_departure_ne_%02d", $0))
        }
        departureNWTextures = (0..<ActorLocomotionPacing.walkFramesPerCycle).compactMap {
            GameArt.texture(named: String(format: "lila_departure_nw_%02d", $0))
        }

        contactShadow = SKShapeNode(ellipseOf: CGSize(width: 44, height: 15))
        contactShadow.fillColor = SKColor(white: 0, alpha: 0.32)
        contactShadow.strokeColor = .clear
        contactShadow.position = CGPoint(x: 0, y: 3)
        contactShadow.setScale(OfficeInteriorScale.ActorDisplay.standingScale)

        if let texture = arrivalTextures.last {
            body = SKSpriteNode(texture: texture, size: OfficeInteriorScale.ActorDisplay.spriteDisplaySize)
        } else {
            body = SKSpriteNode(
                color: SKColor(red: 0.18, green: 0.08, blue: 0.1, alpha: 1),
                size: CGSize(width: 42, height: OfficeInteriorScale.clientBodyHeight)
            )
        }
        body.anchorPoint = CGPoint(x: 0.5, y: 39 / 256)
        body.texture?.filteringMode = .nearest
        // Same adult standing presentation as DetectiveActorNode (integer-pixel sprite scale).
        // Never negate xScale — handbag/light contract forbids whole-figure mirroring.
        body.xScale = OfficeInteriorScale.ActorDisplay.spriteScale
        body.yScale = OfficeInteriorScale.ActorDisplay.spriteScale

        bodyHandoff = SKSpriteNode(color: .clear, size: OfficeInteriorScale.ActorDisplay.spriteDisplaySize)
        bodyHandoff.anchorPoint = body.anchorPoint
        bodyHandoff.xScale = body.xScale
        bodyHandoff.yScale = body.yScale
        bodyHandoff.isHidden = true
        bodyHandoff.alpha = 0
        bodyHandoff.zPosition = body.zPosition - 0.1

        super.init()
        name = "client.lilaMarch"
        addChild(contactShadow)
        addChild(bodyHandoff)
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
        bodyHandoff.removeAllActions()
        clearDepartureHandoff()
        body.position = .zero
        bodyHandoff.position = .zero
        body.alpha = 1
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
        bodyHandoff.removeAllActions()
        clearDepartureHandoff()
        body.position = .zero
        bodyHandoff.position = .zero
        body.alpha = 1
        position = start

        let expected = ActorLocomotionPacing.walkFramesPerCycle
        if departureNETextures.count != expected {
            assertionFailure("Expected \(expected) NE departure textures, found \(departureNETextures.count)")
        }
        if departureNWTextures.count != expected {
            assertionFailure("Expected \(expected) NW departure textures, found \(departureNWTextures.count)")
        }

        var actions: [SKAction] = []
        var prior = start
        var activeBin: DepartureFacingBin?
        for destination in points.dropFirst() {
            let dx = destination.x - prior.x
            let dy = destination.y - prior.y
            let bin = Self.departureFacingBin(dx: dx, dy: dy)
            if activeBin != bin {
                let textures = departureTextures(for: bin)
                let crossfade = activeBin != nil
                actions.append(.run { [weak self] in
                    self?.startDepartureWalkCycle(textures, crossfade: crossfade)
                })
                activeBin = bin
            }

            let distance = hypot(dx, dy)
            let movement = SKAction.move(
                to: destination,
                duration: ActorLocomotionPacing.pathDuration(distance: distance)
            )
            movement.timingMode = .linear
            actions.append(movement)
            prior = destination
        }

        if activeBin == nil {
            // Degenerate single-point path — still try to show a strip if available.
            actions.insert(.run { [weak self] in
                guard let self else { return }
                self.startDepartureWalkCycle(self.departureTextures(for: .northEast), crossfade: false)
            }, at: 0)
        }

        actions.append(.fadeOut(withDuration: 0.2))
        actions.append(.run { [weak self] in
            guard let self else { return }
            self.body.removeAction(forKey: "clientWalkCycle")
            self.clearDepartureHandoff()
            self.isHidden = true
            completion()
        })
        run(.sequence(actions), withKey: "clientExit")
    }

    private func departureTextures(for bin: DepartureFacingBin) -> [SKTexture] {
        let expected = ActorLocomotionPacing.walkFramesPerCycle
        switch bin {
        case .northWest:
            if departureNWTextures.count == expected { return departureNWTextures }
            if departureNETextures.count == expected { return departureNETextures }
        case .northEast:
            if departureNETextures.count == expected { return departureNETextures }
            if departureNWTextures.count == expected { return departureNWTextures }
        }
        return departureNETextures.isEmpty ? departureNWTextures : departureNETextures
    }

    private func startDepartureWalkCycle(_ textures: [SKTexture], crossfade: Bool) {
        guard textures.count == ActorLocomotionPacing.walkFramesPerCycle else { return }
        textures.forEach { $0.filteringMode = .nearest }

        if crossfade, let outgoing = body.texture {
            bodyHandoff.removeAllActions()
            bodyHandoff.texture = outgoing
            bodyHandoff.texture?.filteringMode = .nearest
            bodyHandoff.xScale = abs(OfficeInteriorScale.ActorDisplay.spriteScale)
            bodyHandoff.yScale = OfficeInteriorScale.ActorDisplay.spriteScale
            bodyHandoff.position = body.position
            bodyHandoff.isHidden = false
            bodyHandoff.alpha = 1
            body.alpha = 0
            bodyHandoff.run(.sequence([
                .fadeOut(withDuration: Self.stripHandoffDuration),
                .run { [weak self] in self?.clearDepartureHandoff() }
            ]))
            body.run(.fadeIn(withDuration: Self.stripHandoffDuration))
        } else {
            clearDepartureHandoff()
            body.alpha = 1
        }

        body.removeAction(forKey: "clientWalkCycle")
        body.texture = textures[0]
        body.texture?.filteringMode = .nearest
        body.xScale = abs(OfficeInteriorScale.ActorDisplay.spriteScale)
        body.run(
            .repeatForever(.animate(
                with: textures,
                timePerFrame: ActorLocomotionPacing.walkCycleSecondsPerFrame
            )),
            withKey: "clientWalkCycle"
        )
    }

    private func clearDepartureHandoff() {
        bodyHandoff.removeAllActions()
        bodyHandoff.isHidden = true
        bodyHandoff.alpha = 0
        bodyHandoff.texture = nil
    }

    /// Map a path segment to authored departure art without mirroring.
    /// Western/northern bins use NW; eastern bins use NE. Heading and strip stay matched
    /// so the internal-door turn never moonwalks (NW art while moving east).
    private static func departureFacingBin(dx: CGFloat, dy: CGFloat) -> DepartureFacingBin {
        let facing = ActorFacing.resolve(dx: dx, dy: dy, retaining: .northEast, hysteresis: 0)
        switch facing {
        case .northWest, .northNorthWest, .westNorthWest, .west, .westSouthWest, .north:
            return .northWest
        default:
            return .northEast
        }
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

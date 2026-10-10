import Foundation
import Testing
@testable import RainShadowCore

struct RunAnimationTests {
    @Test func dashGaitPersistsAcrossMovesAndReloadButEndsWithTheTurn() throws {
        let legacy = Data(#"{"state":4,"movementRemaining":0}"#.utf8)
        var budget = try JSONDecoder().decode(CombatBudget.self, from: legacy)
        #expect(!budget.usesRunningGait)
        let dashed = budget.dash(speed: 240)
        let moved = budget.move(distance: 100, speed: 240)
        #expect(dashed && moved)
        #expect(budget.usesRunningGait && budget.availableMovement(speed: 240) == 380)
        let restored = try JSONDecoder().decode(CombatBudget.self, from: JSONEncoder().encode(budget))
        #expect(restored == budget && restored.usesRunningGait)
        #expect(!CombatBudget().usesRunningGait)
    }
    @Test func distanceDrivesFramesAndIntegralRunningStepsKeepTheirEndpoint() {
        for bear in [false, true] {
            let stride = CombatRunMotion.stride(bear: bear)
            #expect(CombatRunMotion.phase(distance: stride / 2, bear: bear) == 8)
            #expect(CombatRunMotion.phase(distance: stride, bear: bear) == 0)
            #expect(CombatRunMotion.phase(distance: -1, bear: bear) == 0)
        }
        func traverse(running: Bool) -> (Int, CGPoint) {
            var mover = Movable(identity: "qa.run", position: .zero)
            mover.adopt(Path(points: [CGPoint(x: 320, y: 0)], from: .zero))
            var ticks = 0, distance = 0.0
            while mover.isMoving && ticks < 200 {
                ticks += 1; let before = mover.position
                let rate = running ? CombatRunMotion.rate(travelled: distance, remaining: 320 - distance) : 1
                _ = mover.doStep(walkScale: MovementProfile(rateMultiplier: rate).walkScale!, time: ticks)
                distance += CombatNavigation.distance(before, mover.position)
            }
            return (ticks, mover.position)
        }
        let walk = traverse(running: false), run = traverse(running: true)
        #expect(run.1 == walk.1 && run.1 == CGPoint(x: 320, y: 0))
        #expect(run.0 < walk.0)
        #expect(CombatRunMotion.rate(travelled: 0, remaining: 320) < CombatRunMotion.rate(travelled: 100, remaining: 220))
        #expect(CombatRunMotion.rate(travelled: 315, remaining: 5) < CombatRunMotion.rate(travelled: 100, remaining: 220))
    }
    @Test func everyRunningLayerAndDirectionIsCompleteAndTheApprovedWalksAreIntact() throws {
        #expect(RunAnimationSet.hashes.count == 6)
        for character in RunAnimationSet.hashes.keys {
            let sprite = try IEIndexedSprite.load(character: character)
            try RunAnimationSet.validate(sprite, character: character)
            for facing in ActorFacing.allCases {
                let frames = try (0..<RunAnimationSet.frames).map {
                    sprite.frame(atlas: character + ".atlas", name: try RunAnimationSet.name(facing: facing, phase: $0))!
                }
                if character == RunAnimationSet.body || character == RunAnimationSet.bear {
                    #expect(Set(frames.map { Data($0.indices) }).count >= 14)
                }
            }
        }
        try VossAnimationSet.validate(IEIndexedSprite.load(character: VossAnimationSet.character))
        try BearAnimationSet.validate(IEIndexedSprite.load(character: BearAnimationSet.character))
        try LilaAnimationSet.validate(IEIndexedSprite.load(character: LilaAnimationSet.character))
    }
}

import Testing
import Foundation
import CoreGraphics
@testable import RainShadowCore

struct BarrelDebrisPhysicsTests {
    private let barrel = CombatBarrel(id: "physics.oil", position: CGPoint(x: 400, y: 300))
    private func map(obstacles: [CGRect] = []) -> NavigationMap {
        NavigationMap(worldBounds: CGRect(x: 0, y: 0, width: 900, height: 700), obstacles: obstacles)
    }
    private func destruction(explosion: Bool = true, map: NavigationMap) -> BarrelDestruction {
        BarrelDestruction(barrel: barrel, explosion: explosion,
            impactFrom: CGPoint(x: 300, y: 300), searchMap: map.searchMap)
    }
    @Test func gravityBounceSpinAndFrictionSettleEveryFragment() {
        let effect = destruction(map: map())
        #expect(effect.finalPoses.count == 14)
        #expect(Set(effect.finalPoses.map(\.kind)) == Set(BarrelFragmentPose.Kind.allCases))
        #expect(effect.duration > 0.5 && effect.duration <= 3)
        #expect(effect.samples.last!.allSatisfy { $0.sleeping && $0.height == 0 && $0.velocity == .zero })
        #expect(effect.samples.last!.contains { $0.bounces >= 2 })
        #expect(effect.samples.dropFirst().contains { $0[0].height > effect.samples[0][0].height })
        #expect(effect.finalPoses[0].angle != effect.samples[0][0].pose.angle)
        #expect(effect.sample(at: 100) == effect.samples.last)
    }
    @Test func explosionScattersFartherThanAHandStrike() {
        let terrain = map()
        let blast = destruction(map: terrain), strike = destruction(explosion: false, map: terrain)
        func spread(_ effect: BarrelDestruction) -> Double {
            effect.finalPoses.map { CombatNavigation.distance(barrel.position, $0.point) }.reduce(0, +)
        }
        #expect(spread(blast) > spread(strike) * 1.5)
        #expect(blast.samples.flatMap { $0 }.map(\.height).max()! > strike.samples.flatMap { $0 }.map(\.height).max()!)
    }
    @Test func fragmentsBounceOffWallsAndNeverCrossTheRaster() {
        let terrain = map(obstacles: [CGRect(x: 450, y: 0, width: 16, height: 700)])
        let effect = destruction(map: terrain)
        #expect(effect.samples.last!.contains { $0.wallContacts > 0 })
        #expect(effect.samples.joined().allSatisfy {
            $0.pose.point.x < 450 && BarrelDestruction.allows($0.pose.point, radius: $0.radius, in: terrain.searchMap)
        })
        #expect(effect.samples.last!.allSatisfy { $0.sleeping })
    }
    @Test func mapEdgesKeepFragmentsOnThePlayableGround() {
        let terrain = NavigationMap(worldBounds: CGRect(x: 360, y: 260, width: 100, height: 80), obstacles: [])
        let effect = destruction(map: terrain)
        #expect(effect.samples.last!.contains { $0.wallContacts > 0 })
        #expect(effect.samples.joined().allSatisfy {
            BarrelDestruction.allows($0.pose.point, radius: $0.radius, in: terrain.searchMap)
        })
        #expect(effect.samples.last!.allSatisfy { $0.sleeping })
    }
    @Test func samplingAndCosmeticRandomnessAreDeterministicAndDoNotTouchOccupancy() {
        let terrain = map()
        terrain.registerActor(id: "actor", kind: .npc, at: barrel.position)
        let records = terrain.occupancy.actors
        let flags = terrain.searchMap.flags(at: barrel.position)
        let a = destruction(map: terrain), b = destruction(map: terrain)
        #expect(a.samples == b.samples)
        #expect(a.sample(at: 0.45) == a.sample(at: 0.45))
        #expect(terrain.occupancy.actors == records && terrain.searchMap.flags(at: barrel.position) == flags)
    }
    @Test func saveRestoresSettledFragmentsAndSpillExplosionStartsFromThosePieces() throws {
        var model = TacticalCombat(encounterID: "gate", areaID: "city_wharf_ladder", actors: [
            Combatant(id: TacticalCombat.playerID, name: "Voss", player: true, position: CGPoint(x: 320, y: 300),
                hp: 20, maximumHP: 20, defence: 10, attackBonus: 2, damageMin: 1, damageMax: 3, initiativeBonus: 100),
            Combatant(id: "rival", name: "Rival", player: false, position: CGPoint(x: 700, y: 300),
                hp: 20, maximumHP: 20, defence: 10, attackBonus: 2, damageMin: 1, damageMax: 3, initiativeBonus: 0)
        ], seed: 42, barrels: [barrel])
        let broken = model.breakBarrel(barrel.id, clearLine: true)
        #expect(broken)
        let accepted = model
        let terrain = map(), effect = destruction(explosion: false, map: map())
        model.recordBarrelDebris(barrel.id, poses: effect.finalPoses)
        #expect(model.randomState == accepted.randomState && model.actors == accepted.actors && model.budget == accepted.budget)
        let restored = try JSONDecoder().decode(TacticalCombat.self, from: JSONEncoder().encode(model))
        #expect(restored == model && restored.isValid)
        let spill = try #require(restored.liveBarrels.first)
        let ignition = BarrelDestruction(barrel: spill, explosion: true, impactFrom: .zero, searchMap: terrain.searchMap)
        #expect(ignition.samples[0].map(\.pose) == effect.finalPoses)
        #expect(ignition.samples[0].allSatisfy { $0.height == 0 })
        #expect(ignition.samples.last!.allSatisfy { $0.sleeping })
    }
    @Test func closedDoorsBlockFragmentsAndOpenDoorsLetThemPass() {
        let terrain = map()
        terrain.searchMap.setDoorObstacles([DoorObstacle(id: "door",
            closedRect: CGRect(x: 450, y: 0, width: 16, height: 700))], blocking: true)
        let closed = destruction(map: terrain)
        #expect(closed.samples.joined().allSatisfy { $0.pose.point.x < 450 })
        terrain.searchMap.setDoor(id: "door", open: true)
        let opened = destruction(map: terrain)
        #expect(opened.samples.joined().contains { $0.pose.point.x > 466 })
    }
    @Test func cosmeticLayoutsStayBoundedAcrossDifferentSeedsAndStrikeDirections() {
        let terrain = map(obstacles: [CGRect(x: 455, y: 0, width: 16, height: 700)])
        for i in 0..<24 {
            let item = CombatBarrel(id: "physics.\(i)", position: barrel.position)
            let effect = BarrelDestruction(barrel: item, explosion: i.isMultiple(of: 2),
                impactFrom: CGPoint(x: 400 + cos(Double(i)) * 90, y: 300 + sin(Double(i)) * 70),
                searchMap: terrain.searchMap)
            #expect(effect.samples.last!.allSatisfy { $0.sleeping && $0.height == 0 })
            #expect(effect.finalPoses.allSatisfy { $0.isValid })
            #expect(effect.sample(at: effect.duration).map(\.pose) == effect.finalPoses)
            #expect(effect.samples.joined().allSatisfy {
                BarrelDestruction.allows($0.pose.point, radius: $0.radius, in: terrain.searchMap)
            })
        }
    }

}

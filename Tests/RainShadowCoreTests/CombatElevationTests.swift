import Foundation
import CoreGraphics
import Testing
@testable import RainShadowCore

struct CombatElevationTests {
    private let high = CGPoint(x: 1996, y: 2359)
    private let low = CGPoint(x: 1933, y: 1896)
    private func fight(highAttacker: Bool = true, seed: UInt64 = 1) -> TacticalCombat {
        TacticalCombat(encounterID: "elevation", areaID: "city_wharf_ladder", actors: [
            Combatant(id: TacticalCombat.playerID, name: "Voss", player: true, position: highAttacker ? high : low,
                hp: 100, maximumHP: 100, defence: 15, attackBonus: 4, damageMin: 3, damageMax: 6,
                initiativeBonus: 100, rangedWeapon: .bow),
            Combatant(id: "archer", name: "Archer", player: false, position: highAttacker ? low : high,
                hp: 100, maximumHP: 100, defence: 15, attackBonus: 4, damageMin: 3, damageMax: 6,
                initiativeBonus: -100, rangedWeapon: .bow)
        ], seed: seed)
    }
    @Test func thresholdIsSignedAndDoesNotGrantAdvantage() throws {
        for (a, b, expected) in [(10.0, 0.0, 2), (0, 10, -2), (9.999, 0, 0), (0, 9.999, 0), (20, 20, 0), (50, 0, 2)] {
            #expect(CombatElevation.rangedModifier(attackerFeet: a, targetFeet: b) == expected)
        }
        for elevated in [true, false] {
            let game = fight(highAttacker: elevated), before = fight(highAttacker: elevated)
            let preview = game.attackPreview(target: game.actors[1], clearLine: true, ranged: true)
            #expect(preview.elevationModifier == (elevated ? 2 : -2))
            #expect(abs(preview.hitChance - (elevated ? 0.6 : 0.4)) < 0.00001)
            #expect(preview.edge == 0 && game == before)
            #expect(game.attackPreview(target: game.actors[1], clearLine: false, ranged: true).unavailableReason != nil)
            #expect(game.attackPreview(target: game.actors[1], clearLine: true).elevationModifier == 0)
            #expect(try JSONDecoder().decode(TacticalCombat.self, from: JSONEncoder().encode(game)) == game)
        }
    }
    @Test func roofIsDisconnectedAndLadderEndpointsHaveClearance() throws {
        let area = try AreaCatalogLoader.load(WharfLadderStory.exterior), map = area.makeNavigationMap()
        let ladder = try #require(area.ladders.first)
        var actor = fight().current; actor.position = low
        #expect(CombatNavigation.route(in: map, actor: actor, to: ladder.bottom.cgPoint) != nil)
        #expect(CombatNavigation.route(in: map, actor: actor, to: ladder.top.cgPoint) == nil)
        #expect(ladder.exitIsClear(in: map, actorID: actor.id, from: ladder.bottom.cgPoint))
        #expect(ladder.exitIsClear(in: map, actorID: actor.id, from: ladder.top.cgPoint))
        actor.position = ladder.top.cgPoint.rounded
        let roof = try #require(area.elevationSurfaces.first { $0.id == "shipping.roof" })
        #expect(CombatNavigation.route(in: map, actor: actor, to: roof.point(u: 0.5, v: 0.5)) != nil)
        let visible = CombatNavigation.clearLine(in: map, from: actor.position, to: low)
        #expect(visible)
        #expect(CombatElevation.feet(at: actor.position, in: "RS0200") > 18)
        actor.position = low
        let door = try #require(area.travelRegions.first { $0.id == "portal.shippingOffice" }?.approachPoint?.cgPoint)
        #expect(CombatNavigation.route(in: map, actor: actor, to: door) != nil)
        #expect(!area.props.contains { $0.id == "wharf.loading.platform" })
        #expect(try JSONDecoder().decode(AreaDefinition.self, from: JSONEncoder().encode(area)).ladders == area.ladders)
    }
    @Test func ladderSpendsMovementOnceAndRejectsBlockedOrDistantUse() throws {
        let area = try AreaCatalogLoader.load(WharfLadderStory.exterior), ladder = try #require(area.ladders.first)
        var game = fight(); let before = game
        #expect({ game.climb(ladder, exitClear: false) }() == false); #expect(game == before)
        game.reconcilePosition(id: game.current.id, point: ladder.bottom.cgPoint.rounded)
        let movement = game.budget.availableMovement(speed: game.current.speed)
        #expect({ game.climb(ladder, exitClear: true) }())
        #expect(game.current.position == ladder.top.cgPoint.rounded)
        #expect(game.budget.canAttack && game.randomState == before.randomState)
        #expect(abs(game.budget.availableMovement(speed: game.current.speed) - (movement-ladder.costFeet*8)) < 0.001)
        #expect({ game.climb(ladder, exitClear: true) }() == false)
        #expect({ game.dash() }()); #expect({ game.climb(ladder, exitClear: true) }())
        #expect(game.current.position == ladder.bottom.cgPoint.rounded)
        #expect(try JSONDecoder().decode(TacticalCombat.self, from: JSONEncoder().encode(game)) == game)
    }
    @Test func roofAttacksResolveTheSameBonusShownInPreview() throws {
        for highAttacker in [true, false] { for seed in UInt64(1)...30 {
            var game = fight(highAttacker: highAttacker, seed: seed)
            let result = game.attack(target: "archer", clearLine: true, ranged: true)
            let strike = try #require(result)
            #expect(strike.landed == TacticalCombat.attackHits(die: strike.roll, bonus: highAttacker ? 6 : 2, defence: 15))
        } }
    }
    @Test func ladderExitOccupancyAndEnemyPlanningUseTheSameLink() throws {
        let area = try AreaCatalogLoader.load(WharfLadderStory.exterior), ladder = try #require(area.ladders.first)
        let map = area.makeNavigationMap()
        map.registerActor(id: "blocker", kind: .npc, at: ladder.top.cgPoint.rounded)
        let blocked = ladder.exitIsClear(in: map, actorID: "climber", from: ladder.bottom.cgPoint)
        #expect(!blocked); map.unregisterActor(id: "blocker")
        var actors = fight().actors
        actors[0].position = low; actors[0].initiativeBonus = -100
        actors[1].position = ladder.bottom.cgPoint.rounded; actors[1].initiativeBonus = 100; actors[1].enemyRole = .archer
        let game = TacticalCombat(encounterID: "roof", areaID: "RS0200", actors: actors, seed: 42)
        let before = map.occupancy.actors
        let choice = EnemyTactics.choose(combat: game, map: map)
        if case .climb(let chosen) = choice.action { #expect(chosen.id == ladder.id) }
        else { Issue.record("Expected a useful climb: \(choice.reason)") }
        #expect(map.occupancy.actors == before)
    }
    @Test func ladderDepartureOffersAReactionAndDisengagePreventsIt() throws {
        let area = try AreaCatalogLoader.load(WharfLadderStory.exterior), ladder = try #require(area.ladders.first)
        var actors = fight().actors
        actors[0].position = ladder.bottom.cgPoint.rounded
        actors[1].position = CGPoint(x: actors[0].position.x+30, y: actors[0].position.y)
        actors[1].rangedWeapon = nil; actors[1].rangedReadied = false
        var game = TacticalCombat(encounterID: "ladder", areaID: "RS0200", actors: actors, seed: 42)
        let action = game.budget, point = game.current.position
        let reaction = game.ladderOpportunity(ladder, clearLine: { _, _ in true })
        #expect(reaction?.reaction?.opportunityAttack == true)
        #expect(game.budget == action && game.current.position == point)
        #expect(game.actors.first { $0.id == "archer" }?.hasReaction == false)
        let again = game.ladderOpportunity(ladder, clearLine: { _, _ in true }); #expect(again == nil)
        var safe = TacticalCombat(encounterID: "ladder", areaID: "RS0200", actors: actors, seed: 42)
        let disengaged = safe.disengage(); #expect(disengaged)
        let noReaction = safe.ladderOpportunity(ladder, clearLine: { _, _ in true }); #expect(noReaction == nil)
    }
    @Test func projectileRasterDistinguishesRailsWaterWallsRoofsAndActors() {
        for terrain: UInt8 in [0, 8, 10, 12, 13] {
            var cells = [UInt8](repeating: 7, count: 20*20)
            for row in 0..<20 { cells[row*20+10] = terrain }
            let map = NavigationMap(searchMap: SearchMap(worldBounds: CGRect(x: 0, y: 0, width: 320, height: 240),
                terrainIndices: cells, columns: 20, rows: 20))
            let a = CGPoint(x: 80, y: 100), b = CGPoint(x: 240, y: 100)
            #expect(CombatNavigation.clearLine(in: map, from: a, to: b) == (terrain == 8 || terrain == 12))
            var walker = fight().current; walker.position = a
            #expect(CombatNavigation.route(in: map, actor: walker, to: b) == nil)
            map.registerActor(id: "intervening", kind: .npc, at: CGPoint(x: 128, y: 100))
            #expect(!CombatNavigation.clearLine(in: map, from: a, to: b))
        }
    }
}

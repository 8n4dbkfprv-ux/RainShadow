import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore
@testable import RainShadowPersistence

struct AreaLifecycleTests {
    private func door(open: Bool = false, sliding: Bool = false) -> AreaDoor {
        AreaDoor(id: "door", closedObstacle: .init(x: 32, y: 24, w: 16, h: 12),
                 openObstacle: .init(x: 64, y: 24, w: 16, h: 12),
                 startsClosed: !open, isLocked: true, isSliding: sliding,
                 keyItem: "key", closedImpededCells: [.init(column: 2, row: 2)],
                 openImpededCells: [.init(column: 4, row: 2)])
    }

    private func map(_ door: AreaDoor) -> NavigationMap {
        NavigationMap(worldBounds: CGRect(x: 0, y: 0, width: 160, height: 120),
                      obstacles: [], doorObstacles: [door.searchMapObstacle])
    }

    @Test func changedDoorStateSurvivesSerializationWithoutChangingOtherAreas() throws {
        let door = door()
        var state = AreaObjectState()
        #expect(!state.isOpen(door))
        #expect(!state.canOpen(door, holdingKey: { _ in false }))
        state.setDoor(door, open: true)
        // A BG door stays unlocked even after closing and losing the key.
        state.setDoor(door, open: false)
        let snapshot = SaveSnapshot(areaDoorOpen: ["a": state.doorOpen, "b": ["door": true]],
                                    areaUnlockedDoors: ["a": state.unlockedDoors],
                                    areaSpentTriggers: ["a": ["trap"]])
        let restored = try JSONDecoder().decode(SaveSnapshot.self, from: JSONEncoder().encode(snapshot))
        let loaded = AreaObjectState(doorOpen: restored.areaDoorOpen["a"]!,
                                     unlockedDoors: restored.areaUnlockedDoors["a"]!,
                                     spentTriggers: restored.areaSpentTriggers["a"]!)
        #expect(!loaded.isOpen(door))
        #expect(loaded.canOpen(door, holdingKey: { _ in false }))
        #expect(loaded.spentTriggers == ["trap"])
        #expect(restored.areaDoorOpen["b"]?["door"] == true)
        #expect(AreaObjectState().isOpen(self.door(open: true)))
    }

    @Test func oldSavesUseAuthoredStartStates() throws {
        let restored = try JSONDecoder().decode(SaveSnapshot.self, from: Data("{}".utf8))
        #expect(restored.areaDoorOpen.isEmpty)
        #expect(restored.areaUnlockedDoors.isEmpty)
        #expect(restored.areaSpentTriggers.isEmpty)
        #expect(!AreaObjectState().isOpen(door()))
    }

    @Test func timerFreezesWithoutACatchUpBurst() {
        var clock = AreaLogicClock()
        let didAdvance1 = clock.advance(at: 0, paused: false)
        #expect(didAdvance1)
        #expect(clock.pollsScript) // first area update is never staggered
        let didAdvance2 = !clock.advance(at: 0.02, paused: false)
        #expect(didAdvance2)
        let didAdvance3 = !clock.advance(at: 100, paused: true)
        #expect(didAdvance3)
        let didAdvance4 = !clock.advance(at: 100.01, paused: false)
        #expect(didAdvance4)
        let didAdvance5 = clock.advance(at: 100.066, paused: false)
        #expect(didAdvance5)
        #expect(clock.ticks == 2)
        #expect(!clock.pollsScript)
        let didAdvance6 = clock.advance(at: 1000, paused: false)
        #expect(didAdvance6)
        #expect(clock.ticks == 3) // GlobalTimer runs one update after a stall
    }

    @Test func areaScriptsPollOnFirstThenEverySixteenthTick() {
        var clock = AreaLogicClock()
        var polls: [UInt64] = []
        for frame in 0..<40 {
            let didAdvance7 = clock.advance(at: Double(frame) * AreaLogicClock.interval, paused: false)
            #expect(didAdvance7)
            if clock.pollsScript { polls.append(clock.ticks) }
        }
        #expect(polls == [1, 16, 32])
    }

    @Test func occupiedCloseIsRejectedWithoutMutatingDoorOrActor() {
        let door = door(open: true)
        let map = map(door)
        map.registerActor(id: "pc", kind: .player, at: CGPoint(x: 40, y: 30), radius: 3)
        let before = map.occupancy.actors["pc"]
        let outcome = map.changeDoor(door, open: false)
        #expect(!outcome.accepted)
        #expect(map.occupancy.actors["pc"] == before)
        #expect(!map.searchMap.doorBlocksMovement(at: .init(column: 2, row: 2)))
        #expect(map.searchMap.doorBlocksMovement(at: .init(column: 4, row: 2)))
    }

    @Test func personalSpaceAcrossTheLeafDoesNotBlockClosing() {
        let door = door(open: true)
        let map = map(door)
        map.registerActor(id: "pc", kind: .player, at: CGPoint(x: 24, y: 30), radius: 3)
        // The large IE occupancy stamp reaches the leaf, but the origin does not.
        #expect(!map.searchMap.flags(at: .init(column: 2, row: 2)).intersection(.actor).isEmpty)
        #expect(map.changeDoor(door, open: false).accepted)
        #expect(map.searchMap.doorBlocksMovement(at: .init(column: 2, row: 2)))
    }

    @Test func aDoorJumpCancelsBumpBackToTheOldPosition() {
        let map = map(door())
        var actor = Movable(map: map, identity: "pc", position: CGPoint(x: 80, y: 60), circleSize: 2)
        actor.bumpAway()
        #expect(actor.isBumped)
        actor.position = CGPoint(x: 104, y: 66)
        actor.impedeBumping()
        #expect(!actor.isBumped)
        #expect(actor.oldPos == actor.position)
    }

    @Test func openingMarksOccupantsAndUsesTheUpstreamPreSwitchJump() {
        let door = door()
        let map = map(door)
        map.registerActor(id: "pc", kind: .player, at: CGPoint(x: 65, y: 25), radius: 3)
        let outcome = map.changeDoor(door, open: true)
        #expect(outcome.accepted)
        // AdjustPositionNavmap returns the current cell centre before the door
        // switches. Do not invent a post-switch clearance search to change this.
        #expect(outcome.relocatedActors["pc"] == CGPoint(x: 72, y: 30))
        #expect(map.occupancy.actors["pc"]?.position == CGPoint(x: 72, y: 30))
        #expect(map.searchMap.doorBlocksMovement(at: .init(column: 4, row: 2)))
        #expect(!map.searchMap.doorBlocksMovement(at: .init(column: 2, row: 2)))
    }

    @Test func slidingAndForcedDoorsCanCloseWithAnOccupant() {
        for forced in [false, true] {
            let door = door(open: true, sliding: !forced)
            let map = map(door)
            map.registerActor(id: "pc", kind: .player, at: CGPoint(x: 40, y: 30), radius: 3)
            #expect(map.changeDoor(door, open: false, force: forced).accepted)
            #expect(map.searchMap.doorBlocksMovement(at: .init(column: 2, row: 2)))
        }
    }

    @Test func legacyRectAndExplicitCellsUseTheSameOccupancyAuthority() {
        var door = door(open: true)
        door.closedImpededCells = []
        let map = map(door)
        #expect(map.searchMap.impededCells(for: door.searchMapObstacle, open: false)
            == [.init(column: 2, row: 2)])
        map.registerActor(id: "pc", kind: .player, at: CGPoint(x: 40, y: 30), radius: 3)
        #expect(!map.changeDoor(door, open: false).accepted)
    }

    @Test func aSpentTriggerDoesNotRearmOnANewVisit() {
        let region = AreaRegion(id: "trap", kind: .trigger,
            polygon: [.init(x: 0, y: 0), .init(x: 16, y: 0), .init(x: 16, y: 12), .init(x: 0, y: 12)])
        var first = AreaTriggerTracker()
        #expect((first.evaluate(regions: [region], at: CGPoint(x: 8, y: 6)).count == 1))
        var second = AreaTriggerTracker(spentIDs: first.spentIDs)
        #expect((second.evaluate(regions: [region], at: CGPoint(x: 8, y: 6)).isEmpty))
        var repeatable = region
        repeatable.resets = true
        #expect((second.evaluate(regions: [repeatable], at: CGPoint(x: 100, y: 100)).isEmpty))
        #expect((second.evaluate(regions: [repeatable], at: CGPoint(x: 8, y: 6)).count == 1))
    }

    @Test func aTriggerHookStillHonoursItsScriptCondition() {
        let script = AreaScript(id: "trap", blocks: [
            .init(id: "fire", when: .variableIsSet("armed"), do: [.incrementVariable("count", by: 1)])
        ])
        let blocked = AreaScriptRunner.runBlock("fire", of: script, in: AreaScriptTests.context())
        #expect(!blocked.didFire)
        var vars = AreaVariables()
        vars.setFlag(true, "armed", in: AreaScriptTests.office)
        let fired = AreaScriptRunner.runBlock("fire", of: script, in: AreaScriptTests.context(variables: vars))
        #expect(fired.variables.integer("count", in: AreaScriptTests.office) == 1)
    }

    @Test func aDeactivatedRegionCannotBePickedEvenOverAnotherRegion() throws {
        var area = try AreaCatalogLoader.load(HarborpointAreas.office)
        let active = AreaRegion(id: "active", kind: .travel,
            polygon: [.init(x: 0, y: 0), .init(x: 16, y: 0), .init(x: 16, y: 12), .init(x: 0, y: 12)])
        var disabled = active
        disabled.id = "disabled"
        disabled.isDeactivated = true
        area.regions = [active, disabled]
        #expect(area.region(at: CGPoint(x: 8, y: 6))?.id == "active")
        area.regions = [disabled]
        #expect(area.region(at: CGPoint(x: 8, y: 6)) == nil)
    }

    @Test func entranceFallbackKeepsPositionAndOrientationTogether() throws {
        var area = try AreaCatalogLoader.load(HarborpointAreas.office)
        area.entrances = [.init(name: "default", point: .init(x: 8, y: 6), facing: 90),
                          .init(name: "west", point: .init(x: 24, y: 6), facing: 180)]
        #expect(area.resolvedEntrance(named: "west")?.orientation == .west)
        #expect(area.resolvedEntrance(named: "missing")?.orientation == .north)
        #expect(area.spawnPoint(entrance: "missing") == CGPoint(x: 8, y: 6))
        #expect(AreaEntrance(name: "s", point: .init(x: 0, y: 0), facing: -90).orientation == .south)
    }
}

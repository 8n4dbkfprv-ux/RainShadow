import CoreGraphics
import Testing
@testable import RainShadowCore

/// GemRB 1c45c185: DoStep's cutscene exception affects SIDEWALL only;
/// Map::UpdateScripts still services actor backoff and calls NewPath.
struct CinematicMovementTests {
    @Test func cutsceneModeSkipsTheStepWallCheckOnly() {
        let search = SearchMap(worldBounds: CGRect(x: 0, y: 0, width: 640, height: 480),
                               terrainIndices: Array(repeating: SearchMapTerrain.wall.rawValue, count: 1600),
                               columns: 40, rows: 40)
        let map = NavigationMap(searchMap: search)
        let start = CGPoint(x: 160, y: 240)
        var ordinary = MovableTestSupport.movable(on: map, at: start, blocksSearchMap: true)
        ordinary.adopt(Path(points: [CGPoint(x: 500, y: 240)], from: start))
        var cinematic = ordinary
        #expect(ordinary.doStep(walkScale: 100, time: 1).abandoned)
        #expect(ordinary.position == start)
        #expect(cinematic.doStep(walkScale: 100, time: 1, inCutsceneMode: true).moved)
        #expect(cinematic.position.x > start.x)
    }

    @Test func aCinematicActorStillWaitsForAnUnbumpableActor() {
        let map = MovableTestSupport.openMap()
        let start = CGPoint(x: 160, y: 240)
        var actor = MovableTestSupport.movable(on: map, at: start, blocksSearchMap: true)
        actor.adopt(Path(points: [CGPoint(x: 500, y: 240)], from: start))
        map.registerActor(id: "blocker", kind: .npc, at: CGPoint(x: 195, y: 240), radius: 16, isMoving: true)
        let result = actor.doStep(walkScale: 100, time: 1, inCutsceneMode: true)
        #expect(result.backedOff)
        #expect(!result.moved)
        #expect(actor.position == start)
        #expect(actor.isBackingOff)
    }

    @Test func expiringBackoffReplansWithoutSpendingAMovementStep() {
        let map = MovableTestSupport.openMap()
        let start = CGPoint(x: 160, y: 240)
        let destination = CGPoint(x: 500, y: 240)
        var actor = MovableTestSupport.movable(on: map, at: start, blocksSearchMap: true)
        actor.adopt(Path(points: [destination], from: start))
        actor.backoff()
        var tick = 1
        while actor.isBackingOff && tick < 40 {
            let waited = actor.advanceBackoff(walkScale: 100, ticks: tick)
            #expect(waited)
            #expect(actor.position == start)
            tick += 1
        }
        #expect(!actor.isBackingOff)
        #expect(actor.isMoving)
        #expect(actor.destination == destination)
        let waitedAfterExpiry = actor.advanceBackoff(walkScale: 100, ticks: tick)
        #expect(!waitedAfterExpiry)
        #expect(actor.doStep(walkScale: 100, time: tick).moved)
    }
}

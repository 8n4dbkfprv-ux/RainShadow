import CoreGraphics
import Testing
@testable import RainShadowCore

struct CutsceneCatalogTests {
    private let route = [CGPoint(x: 10, y: 20), CGPoint(x: 100, y: 200)]

    @Test func entranceOpensDoorBeforeRoutedMovementAndResumesAfterCameraArrival() {
        var runner = CutsceneRunner()
        let first = runner.begin(CutsceneCatalog.clientEntrance(route: route, resumeDialogueNodeID: "ready"), at: 0)
        let cues = first.commands.map(\.cue)
        #expect(cues.firstIndex(of: .setDoor(.officeEntrance, open: true))! < cues.firstIndex(of: .moveToPoint(route.last!))!)
        #expect(cues.contains(.jumpToPoint(route.first!)) && cues.contains(.hideCreature(false)))
        _ = runner.advance(ticks: 8)
        _ = runner.noteAnimationCompleted(.actor(.detective), sequence: .getUp)
        _ = runner.advance(ticks: 1)
        _ = runner.noteCompleted(.actor(.client))
        let reading = runner.advance(ticks: 13)
        #expect(reading.commands.map(\.cue).contains(.moveViewPointUntilDone(CutsceneCatalog.OfficeCutsceneFraming.dialogueFraming, .standard)))
        #expect(!reading.commands.map(\.cue).contains(.resumeDialogue(nodeID: "ready")))
        let end = runner.noteCompleted(.actor(.client))
        #expect(end.commands.map(\.cue) == [.setCutsceneMode(false), .resumeDialogue(nodeID: "ready")])
        #expect(end.completion == .natural)
    }

    @Test(arguments: 0..<40)
    func entranceRecoveryPositionsClientBeforeFacingAndDialogue(tick: Int) {
        var runner = CutsceneRunner()
        _ = runner.begin(CutsceneCatalog.clientEntrance(route: route, resumeDialogueNodeID: "ready"), at: 0)
        _ = runner.advance(ticks: tick)
        var commands = runner.skip(at: 0).commands
        commands += runner.noteAnimationCompleted(.actor(.detective), sequence: .getUp).commands
        for _ in 0..<3 { commands += runner.advance(ticks: 1).commands }
        let cues = commands.map(\.cue)
        let snap = cues.firstIndex(of: .jumpToPoint(route.last!))!
        let face = cues.firstIndex(of: .faceObject(.client))!
        let resume = cues.firstIndex(of: .resumeDialogue(nodeID: "ready"))!
        #expect(snap < face && face < resume)
        #expect(!runner.isPlaying && runner.wasBroken)
    }

    @Test func exitHidesClientOnlyAfterMovementAndAuthorsAReadingWait() {
        var runner = CutsceneRunner()
        let first = runner.begin(CutsceneCatalog.clientExit(route: route), at: 0)
        #expect(!first.commands.map(\.cue).contains(.hideCreature(true)))
        let departed = runner.noteCompleted(.actor(.client))
        #expect(departed.commands.map(\.cue).contains(.hideCreature(true)))
        #expect(departed.commands.contains(CutsceneCommand(.actor(.detective), CutsceneCatalog.fileTheNightHeadText)))
        #expect(runner.advance(ticks: CutsceneCatalog.fileTheNightBeat.ticks - 1).completion == nil)
        #expect(runner.advance(ticks: 1).completion == .natural)
    }

    @Test func exitRecoveryExplicitlyTeleportsAndHidesClient() {
        var runner = CutsceneRunner()
        _ = runner.begin(CutsceneCatalog.clientExit(route: route), at: 0)
        let step = runner.skip(at: 0)
        let cues = step.commands.map(\.cue)
        #expect(cues.firstIndex(of: .jumpToPoint(route.last!))! < cues.firstIndex(of: .hideCreature(true))!)
        #expect(cues.last == .setCutsceneMode(false))
        #expect(step.completion == .skipped)
    }

    @Test func openingUsesActualIntegerPansAndFinishesInTenToFourteenSeconds() {
        var runner = CutsceneRunner()
        var viewport = CutsceneViewport(position: CutsceneCatalog.OpeningExteriorFraming.streetLevel)
        var waiting = false
        func consume(_ step: CutsceneStep) {
            for command in step.commands {
                if case .moveViewPointUntilDone(let point, let speed) = command.cue {
                    viewport.move(to: point, speed: speed)
                    waiting = true
                }
            }
        }
        consume(runner.begin(CutsceneCatalog.openingExterior, at: 0))
        for _ in 0..<300 where runner.isPlaying {
            viewport.advance()
            consume(runner.advance(ticks: 1))
            if waiting && !viewport.isMoving {
                waiting = false
                consume(runner.noteCompleted(.world))
            }
        }
        #expect(!runner.isPlaying)
        #expect((150...210).contains(runner.elapsedTicks), "Opening ran \(runner.elapsedTicks) ticks")
        #expect(viewport.position == CutsceneCatalog.OpeningExteriorFraming.officeWindow)
        #expect(runner.fade.alpha == 255)
    }

    @Test func allShippedSequencesExplicitlyEnableBreakingAndAuthorRecovery() {
        for scene in [CutsceneCatalog.openingExterior,
                      CutsceneCatalog.clientEntrance(route: route, resumeDialogueNodeID: nil),
                      CutsceneCatalog.clientExit(route: route)] {
            #expect(scene.skipTracks != nil)
            #expect(scene.tracks.flatMap(\.cues).contains(.setCutsceneBreakable(true)))
            #expect(!scene.isBreakable) // The action opts in, never an implicit default.
        }
    }

    @Test func cinematicMovementReachesBothOfficeEndpointsThroughTheEngineRaster() throws {
        let map = OfficeNavigationLayout.makeGrid(entranceDoorBlocking: false)
        let arrival = OfficeNavigationLayout.clientArrivalRoute(in: map)
        let start = try #require(arrival.first)
        let end = try #require(arrival.last)
        for (from, to) in [(start, end), (end, start)] {
            let path = map.pathAvoidingActors(from: from, to: to, identity: "client")
            #expect(!path.isEmpty)
            var actor = Movable(map: map, identity: "client", position: from, circleSize: map.circleSize, blocksSearchMap: false)
            actor.adopt(path)
            for tick in 1...4000 where actor.isMoving {
                _ = actor.doStep(walkScale: MovableTestSupport.humanoidWalkScale, time: tick)
            }
            #expect(!actor.isMoving)
            #expect(map.searchMap.cell(for: actor.position) == map.searchMap.cell(for: to))
        }
    }
}

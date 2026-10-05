import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore

/// Pins the shipped choreography. These used to be assertions about the *text*
/// of `DetectiveOfficeScene.swift`; now they are assertions about the cutscenes.
struct CutsceneCatalogTests {

    private static let shipped: [Cutscene] = [
        CutsceneCatalog.openingExterior,
        CutsceneCatalog.clientEntrance(
            route: OfficeNavigationLayout.clientArrivalPath,
            resumeDialogueNodeID: "voss.monologue.5"
        ),
        CutsceneCatalog.clientExit(route: OfficeNavigationLayout.clientDeparturePath)
    ]

    /// Two tracks for one subject would serialise onto a single action list in
    /// BG. Here it is an authoring error, and `CutsceneRunner.begin` asserts it —
    /// but an assert only fires in debug, so pin it for every shipped cutscene.
    @Test func noShippedCutsceneAddressesASubjectTwice() {
        for cutscene in Self.shipped {
            let subjects = cutscene.tracks.map(\.subject)
            #expect(
                Set(subjects).count == subjects.count,
                "\(cutscene.id) addresses a subject on two tracks"
            )
        }
    }

    /// Every shipped cutscene must actually run to completion when played out.
    /// A track waiting on a report that never comes is a soft-lock with the
    /// player's input already taken away.
    @Test func everyShippedCutsceneTerminates() {
        for cutscene in Self.shipped {
            var runner = CutsceneRunner()
            _ = runner.begin(cutscene, at: 0)
            for _ in 0..<2_000 where runner.isPlaying {
                _ = runner.advance(ticks: 1)
                for subject in Set(cutscene.tracks.map(\.subject) + [.actor(.detective), .actor(.client)]) {
                    _ = runner.noteCompleted(subject)
                }
            }
            #expect(!runner.isPlaying, "\(cutscene.id) never finished")
        }
    }

    /// All three are breakable with the 1.0 s grace the exterior established.
    @Test func shippedCutscenesAreBreakableAfterTheStandardGrace() {
        for cutscene in Self.shipped {
            #expect(cutscene.isBreakable, "\(cutscene.id)")
            #expect(cutscene.graceSeconds == BreakableCutsceneGate.defaultGraceSeconds)
        }
    }

    // MARK: - Opening exterior

    @Test func openingRunsAboutTwelveSecondsLikeTheShippedTimeline() {
        // GDD asks for a 10–14 s establishing shot; the shipped scene ran 12.0 s.
        var runner = CutsceneRunner()
        let cutscene = CutsceneCatalog.openingExterior
        _ = runner.begin(cutscene, at: 0)
        var ticks = 0
        while runner.isPlaying, ticks < 1_000 {
            _ = runner.advance(ticks: 1)
            // The camera scrolls are the only open-ended cues; report them
            // promptly so the measurement is of the authored beats.
            _ = runner.noteCompleted(.camera)
            ticks += 1
        }
        let seconds = TimeInterval(ticks) * LogicTickClock.tickDuration
        #expect(seconds >= 10 && seconds <= 14, "Opening ran \(seconds)s")
    }

    /// Pan, hold, push — not one continuous lerp.
    @Test func openingCameraPansThenHoldsThenPushes() {
        let camera = try! #require(
            CutsceneCatalog.openingExterior.tracks.first { $0.subject == .camera }
        )
        #expect(camera.cues == [
            .wait(.seconds(1.0)),
            .moveViewPoint(CutsceneCatalog.OpeningExteriorFraming.buildingWide, .slow),
            .wait(.ticks(15)),
            .moveViewPoint(CutsceneCatalog.OpeningExteriorFraming.officeWindow, .standard)
        ])
    }

    /// Scale is a multiple of the scene's resolved base zoom. Absolute scales are
    /// stomped by `layoutViewport()` on the first window resize.
    @Test func openingZoomStaysWithinTheRestrainedBand() {
        let zoom = try! #require(
            CutsceneCatalog.openingExterior.tracks.first { $0.subject == .cameraZoom }
        )
        let scales: [CGFloat] = zoom.cues.compactMap {
            if case .cameraScale(let scale, _) = $0 { return scale }
            return nil
        }
        #expect(scales == [1.08, 0.82, 0.68])
        #expect(scales.allSatisfy { $0 > 0.5 && $0 < 1.5 }, "GDD §5.2: restrained scale only")
    }

    // MARK: - Client entrance

    @Test func entranceActorWalksThenFacesThenResumesDialogue() throws {
        let cutscene = CutsceneCatalog.clientEntrance(route: OfficeNavigationLayout.clientArrivalPath,
                                                     resumeDialogueNodeID: "voss.monologue.5")
        let client = try #require(cutscene.tracks.first { $0.subject == .actor(.client) })
        let walk = try #require(client.cues.firstIndex {
            if case .followPath = $0 { return true }; return false
        })
        let face = try #require(client.cues.firstIndex(of: .faceObject(.detective)))
        let resume = try #require(client.cues.firstIndex(of: .resumeDialogue(nodeID: "voss.monologue.5")))
        #expect(walk < face && face < resume)
        #expect(cutscene.skipTracks?.contains {
            $0.subject == .actor(.client) && $0.cues.contains(.faceObject(.detective))
        } == true)
    }

    @Test func entranceOpensDoorBeforeWalking() throws {
        let cutscene = CutsceneCatalog.clientEntrance(route: [.zero], resumeDialogueNodeID: nil)
        let client = try #require(cutscene.tracks.first { $0.subject == .actor(.client) })
        let door = try #require(client.cues.firstIndex(of: .setDoor(.officeEntrance, open: true)))
        let walk = try #require(client.cues.firstIndex(of: .followPath([.zero], .entering)))
        #expect(door < walk)
    }

    @Test func detectiveStandIsQueuedInParallelBeforeClientWalk() throws {
        let cutscene = CutsceneCatalog.clientEntrance(route: [.zero], resumeDialogueNodeID: nil)
        let client = try #require(cutscene.tracks.first { $0.subject == .actor(.client) })
        let wait = try #require(client.cues.firstIndex(of: .actionOverride(.detective, .wait(.ticks(8)))))
        let stand = try #require(client.cues.firstIndex(of: .actionOverride(.detective, .standUp)))
        let walk = try #require(client.cues.firstIndex(of: .followPath([.zero], .entering)))
        #expect(wait < stand && stand < walk)
    }

    /// The camera reaches the aperture before she does.
    @Test func entranceCameraAnticipatesTheDoorway() {
        let cutscene = CutsceneCatalog.clientEntrance(route: [.zero], resumeDialogueNodeID: nil)
        let camera = try! #require(cutscene.tracks.first { $0.subject == .camera })
        #expect(camera.cues.first == .moveViewPoint(
            CutsceneCatalog.OfficeCutsceneFraming.entranceSightline, .fast
        ))
        #expect(camera.cues.last == .moveViewPoint(
            CutsceneCatalog.OfficeCutsceneFraming.dialogueFraming, .standard
        ))
    }

    /// Skipping mid-walk must still resume the graph on the authored node.
    @Test func skippingTheEntranceStillResumesTheDialogueGraph() {
        var runner = CutsceneRunner()
        _ = runner.begin(
            CutsceneCatalog.clientEntrance(
                route: OfficeNavigationLayout.clientArrivalPath,
                resumeDialogueNodeID: "voss.monologue.5"
            ),
            at: 0
        )
        _ = runner.advance(ticks: 20)
        let step = runner.skip(at: 100)
        #expect(step.completion == .skipped)
        #expect(step.commands.contains(CutsceneCommand(.chrome, .resumeDialogue(nodeID: "voss.monologue.5"))))
        #expect(step.commands.contains(CutsceneCommand(.chrome, .letterbox(false))))
        // And she is standing where the walk would have left her.
        let end = try! #require(OfficeNavigationLayout.clientArrivalPath.last)
        #expect(step.commands.contains(
            CutsceneCommand(.actor(.client), .jumpToPoint(end, .entering))
        ))
    }

    // MARK: - Client exit

    /// The camera stays with her instead of cutting back to Voss as she leaves.
    @Test func exitHoldsOnTheClientBeforeReleasingTheCamera() {
        let camera = try! #require(
            CutsceneCatalog.clientExit(route: [.zero]).tracks.first { $0.subject == .camera }
        )
        #expect(camera.cues == [.moveViewObject(.client, .veryFast)])
        let client = try! #require(CutsceneCatalog.clientExit(route: [.zero]).tracks.first {
            $0.subject == .actor(.client)
        })
        let walk = try! #require(client.cues.firstIndex(of: .followPath([.zero], .leaving)))
        let release = try! #require(client.cues.firstIndex(of: .releaseCamera))
        #expect(walk < release)
    }

    /// Control comes back only after she has cleared the room, and the visit
    /// flag is set on the way out so the intro cannot replay.
    @Test func exitEndsCutsceneModeAndSetsTheGuardFlag() {
        let chrome = try! #require(
            CutsceneCatalog.clientExit(route: [.zero]).tracks.first { $0.subject == .actor(.client) }
        )
        #expect(chrome.cues.last == .setCutsceneMode(false))
        let modeOff = try! #require(chrome.cues.firstIndex(of: .setCutsceneMode(false)))
        let join = try! #require(chrome.cues.firstIndex {
            if case .followPath = $0 { return true }
            return false
        })
        #expect(join < modeOff, "Player control must not return while she is still walking")
        let thought = try! #require(chrome.cues.firstIndex {
            if case .actionOverride(.detective, .displayStringHead(let key, _)) = $0 {
                return key == CutsceneCatalog.StringKey.fileTheNight
            }
            return false
        })
        #expect(join < thought, "The PC thought waits until she has left")
        #expect(thought < modeOff, "The thought finishes before control returns")

        // The guard flag is set before the walk, not after: quitting during her
        // departure must not replay the whole intro on the next load.
        let flag = try! #require(
            chrome.cues.firstIndex(of: .setFlag(CutsceneCatalog.CutsceneFlags.officeCaseIntroCompleted))
        )
        #expect(flag < join)
    }

    /// Breaking the exit still unlocks control and sets the flag — the failure
    /// mode a hand-written skip path exists to avoid.
    @Test func skippingTheExitStillUnlocksControlAndRecordsTheVisit() {
        var runner = CutsceneRunner()
        // What matters is the whole run, not the skip step alone: a cue that has
        // already fired is not owed again, and `.setFlag` leads this cutscene.
        var commands = runner.begin(
            CutsceneCatalog.clientExit(route: [.zero, CGPoint(x: 50, y: 0)]),
            at: 0
        ).commands
        commands += runner.skip(at: 100).commands
        #expect(commands.contains(CutsceneCommand(.chrome, .setCutsceneMode(false))))
        #expect(commands.contains(
            CutsceneCommand(.chrome, .setFlag(CutsceneCatalog.CutsceneFlags.officeCaseIntroCompleted))
        ))
    }
}

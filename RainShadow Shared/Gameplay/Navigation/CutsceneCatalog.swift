import CoreGraphics
import Foundation

/// Every cutscene RainShadow ships, authored as track lists.
///
/// These read the way a Baldur's Gate `.baf` cutscene reads, and for the same
/// reason: one block per acting subject, cues in order inside a block, blocks
/// running against each other. What used to be two hundred lines of `SKAction`
/// and completion callbacks inside a three-thousand-line scene is the shape of
/// the thing itself.
///
/// The house style from `CinematicSystemRoadmap` §5.4 still holds — slow pans,
/// pushes, restrained scale, nothing flashy. BG's camera has exactly two verbs
/// and that restraint is most of why its cutscenes age well.
enum CutsceneCatalog {

    /// Stable cutscene ids. Named separately so a scene can recognise a
    /// completion without building the cutscene again to read its id.
    enum ID {
        static let openingExterior = "opening.exterior"
        static let clientEntrance = "office.clientEntrance"
        static let clientExit = "office.clientExit"
    }

    // MARK: - Opening exterior

    /// The establishing shot: rain, a building, one warm window.
    ///
    /// Previously a single 11.5 s ease that the scene then waited 12.0 s to end,
    /// so the last half-second was a dead camera. Re-cut as BG beats — a slow
    /// pan onto the building, a held breath, then a push onto the window — which
    /// is the same total length with a shape to it.
    static var openingExterior: Cutscene {
        Cutscene(
            id: ID.openingExterior,
            graceSeconds: BreakableCutsceneGate.defaultGraceSeconds,
            tracks: [
                CutsceneTrack(.chrome, [
                    .setCutsceneMode(true),
                    .fadeFromColor(.black, .seconds(1.5)),
                    .wait(.seconds(9.4)),
                    // The warm bloom through the window is the cut into the office.
                    .fadeToColor(.warmWindowBloom, .seconds(0.72)),
                    .setFlag(CutsceneFlags.openingSeen)
                ]),
                CutsceneTrack(.camera, [
                    .wait(.seconds(1.0)),
                    .moveViewPoint(OpeningExteriorFraming.buildingWide, .slow),
                    // SmallWait(15): a held breath before the push. BG punctuates
                    // with stillness far more than it does with movement.
                    .wait(.ticks(15)),
                    .moveViewPoint(OpeningExteriorFraming.officeWindow, .standard)
                ]),
                CutsceneTrack(.cameraZoom, [
                    .cameraScale(OpeningExteriorFraming.openingScale, .instant),
                    .wait(.seconds(1.0)),
                    .cameraScale(OpeningExteriorFraming.approachScale, .seconds(9.0)),
                    .cameraScale(OpeningExteriorFraming.arrivalScale, .seconds(0.8))
                ])
            ]
        )
    }

    /// Camera marks for the opening. Scene-space points on the 3072×1728 plate.
    enum OpeningExteriorFraming {
        /// Where the camera rests as the scene opens — street level, wide.
        static let streetLevel = CGPoint(x: 1_536, y: 760)
        /// The building, framed whole.
        static let buildingWide = CGPoint(x: 1_580, y: 900)
        /// The one lit window on the third floor: Voss, still at his desk.
        static let officeWindow = CGPoint(x: 1_650, y: 1_000)

        /// Multiples of the scene's resolved base zoom, not absolute scales —
        /// `BaseGameScene.layoutViewport()` recomputes `baseCameraScale` on every
        /// resize, so anything absolute is stomped the first time the window moves.
        static let openingScale: CGFloat = 1.08
        static let approachScale: CGFloat = 0.82
        static let arrivalScale: CGFloat = 0.68
    }

    // MARK: - Office: the client visit

    /// Lila March arrives through the sole cutaway entrance, crosses the open
    /// room, and Voss gets to his feet.
    ///
    /// Deferred out of `voss.monologue.4` by that node's `onLeaveCue`, and it
    /// resumes the graph on the far side. This is classic BG structure —
    /// dialogue, cutscene, dialogue — and the roadmap calls it out as already
    /// aligned by design (§4).
    ///
    /// Reading the tracks: `.chrome` is the master block, the one BG would give
    /// `CutSceneId(Player1)`. It raises the bars, hands the walk to Lila with
    /// `ActionOverride` — blocking until she arrives — then turns Voss toward
    /// her and gives the dialogue back. Meanwhile the door opens, Voss rises,
    /// and the camera works ahead of her.
    static func clientEntrance(
        route: [CGPoint],
        resumeDialogueNodeID: String?
    ) -> Cutscene {
        Cutscene(
            id: ID.clientEntrance,
            graceSeconds: BreakableCutsceneGate.defaultGraceSeconds,
            tracks: [
                CutsceneTrack(.chrome, [
                    .setCutsceneMode(true),
                    .suppressDialogue,
                    .letterbox(true),
                    .actionOverride(.client, .followPath(route, .entering)),
                    // BG:EE turns conversation participants toward each other
                    // slowly when a dialogue opens (`GSUtils.cpp` calls
                    // `SetOrientation(…, slow: true)` for talker and talkee).
                    // He stood during her walk-in, so this is a visible pivot
                    // rather than a pop.
                    .actionOverride(.detective, .faceObject(.client)),
                    .letterbox(false),
                    .resumeDialogue(nodeID: resumeDialogueNodeID)
                ]),
                CutsceneTrack(.world, [
                    // BG:EE order: a door clears its search-map cells before the
                    // creature paths through it.
                    .setDoor(.officeEntrance, open: true)
                ]),
                CutsceneTrack(.actor(.detective), [
                    // Long enough that he reacts to the door rather than
                    // anticipating it. He rises where he sits — the empty route
                    // is the seat-egress path, not a walk.
                    .wait(.ticks(8)),
                    .standUp
                ]),
                CutsceneTrack(.camera, [
                    // Anticipation: the camera reaches the aperture before she
                    // does. The shipped version held on the desk for the whole
                    // walk and then jerked to the dialogue framing once she had
                    // already arrived, which reads as a reaction rather than a shot.
                    .moveViewPoint(OfficeCutsceneFraming.entranceSightline, .fast),
                    .moveViewObject(.client, .veryFast),
                    .wait(.ticks(12)),
                    .moveViewPoint(OfficeCutsceneFraming.dialogueFraming, .standard)
                ])
            ]
        )
    }

    /// Lila leaves. The camera stays with her until she is out, then lets go.
    ///
    /// The shipped order restored the camera to Voss the moment the exit began,
    /// so she walked out off-screen. BG lets an actor leave frame — the room
    /// being empty afterwards is the point of the shot.
    static func clientExit(route: [CGPoint]) -> Cutscene {
        Cutscene(
            id: ID.clientExit,
            graceSeconds: BreakableCutsceneGate.defaultGraceSeconds,
            tracks: [
                CutsceneTrack(.chrome, [
                    // SetGlobal first, not last: the visit counts as played the
                    // moment she starts leaving. Quitting during the departure
                    // walk must not replay the whole intro on the next load.
                    .setFlag(CutsceneFlags.officeCaseIntroCompleted),
                    .letterbox(true),
                    .actionOverride(.client, .followPath(route, .leaving)),
                    .letterbox(false),
                    // EndCutSceneMode: free-play rails and player control return.
                    .setCutsceneMode(false)
                ]),
                CutsceneTrack(.camera, [
                    .moveViewObject(.client, .veryFast),
                    .wait(.ticks(10)),
                    .releaseCamera
                ])
            ]
        )
    }

    /// Office marks. Derived from the authored layout rather than restated, so a
    /// change to the room's geometry moves the camera with it.
    enum OfficeCutsceneFraming {
        /// The open-room sightline just inside the sole cutaway entrance.
        static var entranceSightline: CGPoint {
            OfficeNavigationLayout.clientWaitingRoomPath.last
                ?? OfficeNavigationLayout.DialogueCameraFraming.dialogueCameraWorldPosition
        }

        /// The two-shot the conversation plays in.
        static var dialogueFraming: CGPoint {
            OfficeNavigationLayout.DialogueCameraFraming.dialogueCameraWorldPosition
        }
    }

    /// Guard flags a cutscene sets on its way out, so it cannot re-fire — BG's
    /// `SetGlobal` at the end of a cutscene script.
    enum CutsceneFlags {
        static let openingSeen = "cutscene.opening.seen"
        static let officeCaseIntroCompleted = "cutscene.office.caseIntro.completed"
    }
}

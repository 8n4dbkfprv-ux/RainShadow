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
        /// Warm bay window above the entrance, measured on the Sable Row intro painting.
        static let officeWindow = CGPoint(x: 1_544, y: 804)

        /// Multiples of the scene's resolved base zoom, not absolute scales —
        /// `BaseGameScene.layoutViewport()` recomputes `baseCameraScale` on every
        /// resize, so anything absolute is stomped the first time the window moves.
        static let openingScale: CGFloat = 1.08
        static let approachScale: CGFloat = 0.82
        static let arrivalScale: CGFloat = 0.68
    }

    // MARK: - Office: the client visit

    /// The moving actor owns the continuation. ActionOverride starts Voss's
    /// work in parallel; it is not a join on Lila's walk.
    static func clientEntrance(route: [CGPoint], resumeDialogueNodeID: String?) -> Cutscene {
        Cutscene(id: ID.clientEntrance, tracks: [
            CutsceneTrack(.actor(.client), [
                .setCutsceneMode(true), .suppressDialogue, .letterbox(true),
                .setDoor(.officeEntrance, open: true),
                .actionOverride(.detective, .wait(.ticks(8))),
                .actionOverride(.detective, .standUp),
                .followPath(route, .entering),
                .faceObject(.detective),
                .actionOverride(.detective, .faceObject(.client)),
                .wait(.ticks(1)), .letterbox(false), .setCutsceneMode(false),
                .resumeDialogue(nodeID: resumeDialogueNodeID)
            ]),
            CutsceneTrack(.camera, [
                .moveViewPoint(OfficeCutsceneFraming.entranceSightline, .fast),
                .moveViewObject(.client, .veryFast), .wait(.ticks(12)),
                .moveViewPoint(OfficeCutsceneFraming.dialogueFraming, .standard)
            ])
        ], skipTracks: [
            CutsceneTrack(.world, [.setDoor(.officeEntrance, open: true)]),
            CutsceneTrack(.actor(.detective), [.standUp]),
            CutsceneTrack(.actor(.client), route.last.map { [.jumpToPoint($0, .entering)] } ?? []),
            CutsceneTrack(.actor(.client), [.faceObject(.detective)]),
            CutsceneTrack(.actor(.detective), [.faceObject(.client)]),
            CutsceneTrack(.camera, [.moveViewPoint(OfficeCutsceneFraming.dialogueFraming, .instant)]),
            CutsceneTrack(.chrome, [.letterbox(false), .setCutsceneMode(false), .resumeDialogue(nodeID: resumeDialogueNodeID)])
        ])
    }

    static func clientExit(route: [CGPoint]) -> Cutscene {
        Cutscene(id: ID.clientExit, tracks: [
            CutsceneTrack(.actor(.client), [
                .setCutsceneMode(true), .setFlag(CutsceneFlags.officeCaseIntroCompleted),
                .letterbox(true), .followPath(route, .leaving), .letterbox(false),
                .actionOverride(.detective, fileTheNightHeadText),
                .wait(fileTheNightHeadText.duration), .releaseCamera, .setCutsceneMode(false)
            ]),
            CutsceneTrack(.camera, [.moveViewObject(.client, .veryFast)])
        ], skipTracks: [
            CutsceneTrack(.actor(.client), route.last.map { [.jumpToPoint($0, .leaving)] } ?? []),
            CutsceneTrack(.camera, [.releaseCamera]),
            CutsceneTrack(.chrome, [.setFlag(CutsceneFlags.officeCaseIntroCompleted), .letterbox(false), .setCutsceneMode(false)])
        ])
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

    /// String-table keys a cutscene resolves through `DisplayStringHead`.
    enum StringKey {
        /// PC thought after Lila leaves. Former desk-monologue page 2.
        static let fileTheNight = "dlg.empty-coat.desk-monologue.node.voss.desk.casefile.2.text"
    }

    /// One overhead line over Voss, timed like InfoPoint `DisplayString`.
    static var fileTheNightHeadText: CutsceneCue {
        let text = DialogueStringTable.shipped.stringIfPresent(for: StringKey.fileTheNight) ?? ""
        return .displayStringHead(
            stringKey: StringKey.fileTheNight,
            .seconds(DisplayStringDuration.seconds(for: text))
        )
    }
}

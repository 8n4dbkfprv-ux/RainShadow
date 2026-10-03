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
    /// Fixed-scale engine viewport pans, integer waits and black fades.
    static var openingExterior: Cutscene {
        Cutscene(
            id: ID.openingExterior,
            tracks: [
                CutsceneTrack(.world, [
                    .setCutsceneMode(true), .setCutsceneBreakable(true),
                    .fadeFromColor(.black, .ticks(23)),
                    .wait(.seconds(1)),
                    .moveViewPointUntilDone(OpeningExteriorFraming.buildingWide, .standard),
                    .wait(.seconds(4)),
                    .moveViewPointUntilDone(OpeningExteriorFraming.officeWindow, .standard),
                    .fadeToColor(.black, .ticks(11)),
                    .setFlag(CutsceneFlags.openingSeen), .setCutsceneMode(false)
                ])
            ],
            skipTracks: [
                CutsceneTrack(.world, [
                    .setCutsceneMode(true),
                    .fadeToColor(.black, .ticks(1)),
                    .setFlag(CutsceneFlags.openingSeen), .setCutsceneMode(false)
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

    }

    // MARK: - Office: the client visit

    /// Lila owns the entrance script. Her MoveToPoint blocks her subsequent
    /// camera/dialogue actions while Voss's overridden animation runs in parallel.
    static func clientEntrance(route: [CGPoint], resumeDialogueNodeID: String?) -> Cutscene {
        let arrival: [CutsceneCue] = route.first.map { [.jumpToPoint($0)] } ?? []
        let movement: [CutsceneCue] = route.last.map { [.moveToPoint($0)] } ?? []
        let recovery: [CutsceneCue] = route.last.map { [.actionOverride(.client, .jumpToPoint($0))] } ?? []
        return Cutscene(
            id: ID.clientEntrance,
            tracks: [
                CutsceneTrack(.actor(.client), [
                    .setCutsceneMode(true), .setCutsceneBreakable(true), .suppressDialogue,
                    .setDoor(.officeEntrance, open: true)
                ] + arrival + [
                    .hideCreature(false),
                    .moveViewPoint(OfficeCutsceneFraming.entranceSightline, .fast),
                    .actionOverride(.detective, .wait(.ticks(8))),
                    .actionOverride(.detective, .playSequence(.getUp)),
                    .actionOverride(.detective, .waitAnimation(.getUp)),
                    .actionOverride(.detective, .faceObject(.client))
                ] + movement + [
                    .faceObject(.detective),
                    .actionOverride(.detective, .faceObject(.client)),
                    .wait(.ticks(12)),
                    .moveViewPointUntilDone(OfficeCutsceneFraming.dialogueFraming, .standard),
                    .setCutsceneMode(false), .resumeDialogue(nodeID: resumeDialogueNodeID)
                ])
            ],
            skipTracks: [
                CutsceneTrack(.actor(.detective), [
                    .setCutsceneMode(true), .setDoor(.officeEntrance, open: true)
                ] + recovery + [
                    .actionOverride(.client, .hideCreature(false)),
                    .actionOverride(.client, .faceObject(.detective)),
                    .playSequence(.getUp), .waitAnimation(.getUp),
                    .wait(.ticks(1)), .faceObject(.client),
                    .moveViewPoint(OfficeCutsceneFraming.dialogueFraming, .instant),
                    .setCutsceneMode(false), .resumeDialogue(nodeID: resumeDialogueNodeID)
                ])
            ]
        )
    }

    /// The departing actor owns the script; disappearance and the explicit
    /// reading beat cannot run until MoveToPoint has released its action.
    static func clientExit(route: [CGPoint]) -> Cutscene {
        let endpoint = route.last ?? OfficeCutsceneFraming.entranceSightline
        return Cutscene(
            id: ID.clientExit,
            tracks: [
                CutsceneTrack(.actor(.client), [
                    .setCutsceneMode(true), .setCutsceneBreakable(true),
                    .setFlag(CutsceneFlags.officeCaseIntroCompleted),
                    .moveViewPoint(endpoint, .veryFast), .moveToPoint(endpoint),
                    .hideCreature(true),
                    .actionOverride(.detective, fileTheNightHeadText),
                    .wait(fileTheNightBeat),
                    .moveViewObject(.detective, .instant), .releaseCamera,
                    .setCutsceneMode(false)
                ])
            ],
            skipTracks: [
                CutsceneTrack(.actor(.client), [
                    .jumpToPoint(endpoint), .hideCreature(true),
                    .moveViewObject(.detective, .instant), .releaseCamera,
                    .setFlag(CutsceneFlags.officeCaseIntroCompleted), .setCutsceneMode(false)
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

    /// String-table keys a cutscene resolves through `DisplayStringHead`.
    enum StringKey {
        /// PC thought after Lila leaves. Former desk-monologue page 2.
        static let fileTheNight = "dlg.empty-coat.desk-monologue.node.voss.desk.casefile.2.text"
    }

    static var fileTheNightBeat: CutsceneBeat {
        let text = DialogueStringTable.shipped.stringIfPresent(for: StringKey.fileTheNight) ?? ""
        return .ticks(Int(ceil(DisplayStringDuration.seconds(for: text) * LogicTickClock.ticksPerSecond)))
    }

    static var fileTheNightHeadText: CutsceneCue {
        .displayStringHead(stringKey: StringKey.fileTheNight, fileTheNightBeat)
    }
}

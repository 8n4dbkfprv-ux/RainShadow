import Foundation
import Testing
@testable import RainShadowCore

/// Exercises the **shipped** Empty Coat case-intro graph (same source the office presents).
struct EmptyCoatCaseIntroductionTests {
    private var nodes: [CaseDialogueNode] { EmptyCoatCaseIntroduction.nodes }
    private var startID: String { EmptyCoatCaseIntroduction.startNodeID }

    @Test func startsWithNoirMonologueAboutWhatIsAboutToHappen() {
        let start = nodes.first { $0.id == startID }
        #expect(start != nil)
        guard let start else { return }

        #expect(start.speaker == EmptyCoatCaseIntroduction.vossSpeaker)
        #expect(start.speaker == "Harlan Voss")
        #expect(start.isInteriorMonologue)
        let body = start.text.lowercased()
        #expect(body.contains("rain"))
        #expect(body.contains("glass") || body.contains("afternoon"))
        // Monologue chain continues (not a choice beat).
        #expect(start.choices.isEmpty)
        #expect(start.nextNodeID != nil)

        // Full monologue sequence exists before Lila speaks.
        let monologueNodes = nodes.filter { $0.id.hasPrefix("voss.monologue") }
        #expect(monologueNodes.count >= 3)
        for node in monologueNodes {
            #expect(node.isInteriorMonologue)
        }
        let monologueText = monologueNodes.map(\.text).joined(separator: " ").lowercased()
        #expect(monologueText.contains("rain"))
        #expect(monologueText.contains("coat") || monologueText.contains("case"))
        #expect(monologueText.contains("woman") || monologueText.contains("door"))
        #expect(!monologueText.contains("dame"))

        // Spoken conversation lines (Lila + case title end) are not monologue italics.
        // Classic BG: mid-convo PC speech is reply-option text, not speaker states.
        let spoken = nodes.filter { $0.id.hasPrefix("lila.") || $0.id == EmptyCoatCaseIntroduction.caseOpenedNodeID }
        #expect(!spoken.isEmpty)
        for node in spoken {
            #expect(!node.isInteriorMonologue)
        }
    }

    /// Classic BG roles: after the opening monologue, PC lines that commit the case are
    /// player-selectable transitions—not main-speaker Continue pages (IESDP: state = actor,
    /// transition = what the player character says).
    @Test func midConversationPCLinesAreReplyOptionsNotContinueStates() {
        let byID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })

        // No non-monologue Harlan Voss nodes that only Continue (empty choices + nextNodeID).
        let midConvoPCContinuePages = nodes.filter { node in
            node.speaker == EmptyCoatCaseIntroduction.vossSpeaker
                && !node.isInteriorMonologue
                && node.choices.isEmpty
                && node.nextNodeID != nil
                && !node.endsDialogue
        }
        #expect(
            midConvoPCContinuePages.isEmpty,
            "Mid-convo PC Continue pages (non-classic BG): \(midConvoPCContinuePages.map(\.id))"
        )
        #expect(byID["voss.accept"] == nil)
        #expect(byID["voss.accept.b"] == nil)

        // Acceptance lives on reply choices toward the plea.
        let acceptAnchors = ["i'll take the key", "i'll take the case", "don't wait by the phone"]
        let triad3Terminals = ["lila.reply.good3.b", "lila.reply.neutral3.b", "lila.reply.cynical3.b"]
        for terminalID in triad3Terminals {
            let terminal = byID[terminalID]
            #expect(terminal != nil, "Missing \(terminalID)")
            #expect(terminal?.speaker == EmptyCoatCaseIntroduction.lilaSpeaker)
            #expect(terminal?.nextNodeID == nil)
            #expect(terminal?.choices.isEmpty == false)
            let choiceTexts = (terminal?.choices ?? []).map { $0.text.lowercased() }
            #expect(
                choiceTexts.contains { text in acceptAnchors.allSatisfy { text.contains($0) } },
                "\(terminalID) must expose acceptance as choice text"
            )
            for choice in terminal?.choices ?? [] {
                #expect(choice.destinationID == "lila.plea")
                let fromChoice = CaseDialogueGraph.report(nodes: nodes, startID: choice.destinationID)
                #expect(fromChoice.reachesEnding)
            }
        }

        // Main-speaker Continue pages in the Lila conversation are NPC (or case-title end), not Voss.
        let lilaChain = nodes.filter { $0.id.hasPrefix("lila.") || $0.id == EmptyCoatCaseIntroduction.caseOpenedNodeID }
        for node in lilaChain where node.choices.isEmpty && node.nextNodeID != nil {
            #expect(node.speaker == EmptyCoatCaseIntroduction.lilaSpeaker)
            #expect(node.speaker != EmptyCoatCaseIntroduction.vossSpeaker)
        }
    }

    @Test func presenterUsesItalicFontForInteriorMonologue() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let presenterURL = root
            .appendingPathComponent("RainShadow Shared/UI/DialoguePresenter.swift")
        let source = try String(contentsOf: presenterURL, encoding: .utf8)
        #expect(source.contains("isInteriorMonologue"))
        #expect(source.contains("Palatino-Italic"))
    }

    @Test func usesCanonSpeakerNamesNotActiveRetiredLeads() {
        let speakers = Set(nodes.map(\.speaker))
        #expect(speakers.contains("Harlan Voss"))
        #expect(speakers.contains("Lila March"))
        #expect(speakers.contains("Case opened"))
        #expect(!speakers.contains("Vivian Hart"))
        #expect(!speakers.contains("Elias Vale"))
    }

    @Test func hasAtLeastTwoFullToneTriadChoiceBeats() {
        let triadNodes = nodes.filter { node in
            let tones = Set(node.choices.compactMap(\.tone))
            return tones == Set(DialogueTone.allCases) && node.choices.count >= 3
        }
        #expect(triadNodes.count >= 2)

        for node in triadNodes {
            let byTone = Dictionary(uniqueKeysWithValues: node.choices.compactMap { choice -> (DialogueTone, CaseDialogueChoice)? in
                guard let tone = choice.tone else { return nil }
                return (tone, choice)
            })
            #expect(byTone[.goodHeroic] != nil)
            #expect(byTone[.neutralPragmatic] != nil)
            #expect(byTone[.cynicalSarcasm] != nil)
            // Tone is author metadata only — no on-screen Good/Neutral/Cynical labels.
            for choice in node.choices {
                let lower = choice.text.lowercased()
                #expect(!lower.hasPrefix("good:"))
                #expect(!lower.hasPrefix("neutral:"))
                #expect(!lower.hasPrefix("cynical:"))
                #expect(!choice.text.hasPrefix("Good/Heroic"))
                #expect(!choice.text.hasPrefix("Neutral/Pragmatic"))
                #expect(!choice.text.hasPrefix("Cynical/Sarcasm"))
            }
        }
    }

    @Test func isSubstantiallyLongerThanLegacyShortIntro() {
        let report = CaseDialogueGraph.report(nodes: nodes, startID: startID)
        #expect(nodes.count > EmptyCoatCaseIntroduction.legacyNodeCountFloor)
        #expect(nodes.count >= 18)
        #expect(report.totalBodyCharacters > EmptyCoatCaseIntroduction.legacyBodyCharacterFloor)
    }

    @Test func voiceLockKeepsInspectPleaAndPDAndHidesIntentionLabels() {
        let inspect = OfficeHotspotDialogue.self
        #expect(
            inspect.graph(forHotspotID: "office.desk").nodes.contains {
                $0.text == "Three old cases, two unpaid bills, one clean page."
            }
        )
        #expect(
            inspect.graph(forHotspotID: "office.window").nodes.contains {
                $0.text == "The rain had been working the glass harder than I had worked a case."
            }
        )
        #expect(
            inspect.graph(forHotspotID: "office.phone").nodes.contains {
                $0.text == "Quiet. For once it had the decency to look guilty."
            }
        )
        #expect(
            inspect.graph(forHotspotID: "office.files").nodes.contains {
                $0.text == "Closed, abandoned, and one I still lied about."
            }
        )
        #expect(
            inspect.graph(forHotspotID: "office.door").nodes.contains {
                $0.text == "The hall smelled worse, but at least it led somewhere."
            }
        )

        let plea = nodes.first { $0.id == "lila.plea" }?.text ?? ""
        #expect(plea.contains("Find the sister—not the coat's alibi."))

        let pd = nodes.first { $0.id == "lila.police.story" }?.text ?? ""
        #expect(pd.contains("filed it soft"))
        #expect(pd.contains("probable drowning"))

        let keyReveal = nodes.first { $0.id == "lila.key.reveal" }?.text ?? ""
        #expect(keyReveal.contains("Lillian still sews her own hems."))

        let painted = ["[Open]", "[Press]", "[Feign]", "[Trade]", "[Observe]", "[Leave]"]
        for node in nodes {
            for choice in node.choices {
                let row = choice.displayText(index: 0)
                for label in painted {
                    #expect(
                        !row.contains(label),
                        "Intention label \(label) painted on \(node.id): \(row)"
                    )
                }
            }
        }

        let leaveChoices = nodes.flatMap(\.choices).filter { $0.intention == .leave }
        #expect(leaveChoices.isEmpty, "Leave is unused on Empty Coat; do not fill the taxonomy")
    }

    @Test func graphIntegrityEveryChoiceReachesCaseOpened() {
        let report = CaseDialogueGraph.report(nodes: nodes, startID: startID)
        #expect(report.missingDestinationIDs.isEmpty, "Missing: \(report.missingDestinationIDs)")
        #expect(report.reachesEnding)
        #expect(report.isSound)
        #expect(report.triadChoiceBeats >= 2)
        #expect(report.gatedChoiceCount >= 1)
        #expect(report.actionChoiceCount >= 2)
        #expect(report.reachableNodeIDs.contains(EmptyCoatCaseIntroduction.caseOpenedNodeID))
        #expect(report.reachableNodeIDs.contains("lila.reply.press.gated"))

        // Every choice destination is inside the graph and can still reach an ending.
        let byID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        for node in nodes {
            for choice in node.choices {
                #expect(byID[choice.destinationID] != nil)
                let fromChoice = CaseDialogueGraph.report(nodes: nodes, startID: choice.destinationID)
                #expect(
                    fromChoice.reachesEnding,
                    "Choice \(node.id)->\(choice.destinationID) cannot reach ending"
                )
            }
        }

        let end = byID[EmptyCoatCaseIntroduction.caseOpenedNodeID]
        #expect(end?.endsDialogue == true)
        #expect(end?.text.uppercased().contains("EMPTY COAT") == true)
    }

    @Test func longLilaBeatsUseContinueInsteadOfStackingParagraphs() {
        let entrance = nodes.first { $0.id == "lila.entrance" }
        #expect(entrance != nil)
        #expect(entrance?.choices.isEmpty == true)
        #expect(entrance?.nextNodeID == "lila.entrance.case")
        #expect(!(entrance?.text.contains("My sister Lillian") ?? true))

        let entranceCase = nodes.first { $0.id == "lila.entrance.case" }
        #expect(entranceCase?.text.contains("My sister Lillian") == true)
        #expect(entranceCase?.choices.count == 3)

        // Multi-paragraph key beat is also Continue-paged.
        let key = nodes.first { $0.id == "lila.key.reveal" }
        #expect(key?.nextNodeID == "lila.key.reveal.b")
        #expect(key?.choices.isEmpty == true)
        #expect(nodes.contains { $0.id == "lila.key.reveal.b" })
    }

    @Test func officeScenePresentsShippedEmptyCoatGraph() throws {
        // Structural: the office must call the pure script, not an inlined copy.
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sceneURL = root
            .appendingPathComponent("RainShadow Shared/Scenes/DetectiveOffice/DetectiveOfficeScene.swift")
        let source = try String(contentsOf: sceneURL, encoding: .utf8)
        #expect(source.contains("EmptyCoatCaseIntroduction.graph"))
        #expect(source.contains("presentDialogue("))
        #expect(!source.contains("speaker: \"Vivian Hart\""))
        #expect(!source.contains("speaker: \"Elias Vale\""))
        #expect(!source.contains("vivian.opening"))
    }

    // MARK: - Entrance cue + voice openers (shipped pure helpers)

    @Test func monologueStartDoesNotTriggerClientEntrance() {
        // Intro presents monologue first; entrance is leave-gated (BG Continue → cinematic).
        #expect(startID == "voss.monologue.1")
        #expect(!EmptyCoatCaseIntroduction.shouldStartClientEntrance(whenShowing: startID))
        #expect(!EmptyCoatCaseIntroduction.shouldStartClientEntrance(whenShowing: "voss.monologue.2"))
        #expect(!EmptyCoatCaseIntroduction.shouldStartClientEntrance(whenShowing: "voss.monologue.3"))
        #expect(!EmptyCoatCaseIntroduction.shouldStartClientEntrance(whenShowing: "voss.monologue.4"))
        #expect(!EmptyCoatCaseIntroduction.shouldStartClientEntrance(whenShowing: "lila.entrance"))
        #expect(!EmptyCoatCaseIntroduction.shouldStartClientEntrance(whenShowing: EmptyCoatCaseIntroduction.caseOpenedNodeID))
        // No monologue page arms entrance on *show* — only whenLeaving the cue.
        for node in nodes where node.id.hasPrefix("voss.monologue") {
            #expect(!EmptyCoatCaseIntroduction.shouldStartClientEntrance(whenShowing: node.id))
        }
    }

    @Test func clientEntranceCueIsSoleLateMonologueLeaveTrigger() {
        let cue = EmptyCoatCaseIntroduction.clientEntranceCueNodeID
        #expect(cue == "voss.monologue.4")
        // Data-driven: only the authored leave cue starts the no-dialogue cinematic.
        let cueNode = nodes.first { $0.id == cue }
        #expect(cueNode?.onLeaveCue == OfficeDialogueCues.clientEntrance)
        #expect(EmptyCoatCaseIntroduction.shouldStartClientEntrance(whenLeaving: cue))
        #expect(!EmptyCoatCaseIntroduction.shouldStartClientEntrance(whenShowing: cue))

        let monologueIDs = nodes
            .map(\.id)
            .filter { $0.hasPrefix("voss.monologue") }
        #expect(monologueIDs.contains(cue))
        #expect(monologueIDs.contains(startID))
        // Exactly one monologue node authors the entrance leave cue.
        let leaveCued = nodes.filter {
            $0.id.hasPrefix("voss.monologue") && $0.onLeaveCue == OfficeDialogueCues.clientEntrance
        }
        #expect(leaveCued.map(\.id) == [cue])

        // No shipped node authors a show cue. `handleDialogueShowCue` trips in debug on
        // an unhandled one, so authoring a cue here without wiring the scene now fails
        // loudly instead of being decoded and dropped the way `onShowCue` always was.
        #expect(nodes.allSatisfy { $0.onShowCue == nil })
        for id in monologueIDs where id != cue {
            #expect(
                !EmptyCoatCaseIntroduction.shouldStartClientEntrance(whenLeaving: id),
                "Unexpected leave-entrance trigger on \(id)"
            )
            #expect(nodes.first { $0.id == id }?.onLeaveCue == nil)
        }
        #expect(!EmptyCoatCaseIntroduction.shouldStartClientEntrance(whenLeaving: "lila.entrance"))
        #expect(nodes.first { $0.id == "lila.entrance" }?.onLeaveCue == nil)

        // Cue text narratively introduces arrival (hallway / heels / door).
        #expect(cueNode != nil)
        let body = (cueNode?.text ?? "").lowercased()
        #expect(body.contains("hallway") || body.contains("heels") || body.contains("door"))
        // After cinematic, monologue continues (next page), then Lila speaks.
        #expect(cueNode?.nextNodeID == "voss.monologue.5")
        #expect(nodes.contains { $0.id == "voss.monologue.5" })
    }

    @Test func monologueAndLilaNodesShipGrokVoiceAssets() {
        // Entire Voss monologue + entire Lila dialogue: one Grok Voice clip per speaker node.
        let monologue = nodes.filter { $0.id.hasPrefix("voss.monologue") }
        let lila = nodes.filter { $0.speaker == EmptyCoatCaseIntroduction.lilaSpeaker }
        #expect(monologue.count == 5)
        #expect(lila.count >= 20)

        for node in monologue {
            #expect(node.voiceAssetName != nil, "Missing VO on \(node.id)")
            #expect(
                node.voiceAssetName == EmptyCoatCaseIntroduction.bundledVoiceFileName(for: node.id),
                "VO name mismatch on \(node.id)"
            )
            #expect(node.voiceAssetName?.hasPrefix("vo_voss_monologue_") == true)
            #expect(node.voiceAssetName?.hasSuffix(".m4a") == true)
        }
        // Phase 1 gated Press beat has no VO clip yet; keep silent until assets exist.
        let lilaAwaitingVO: Set<String> = ["lila.reply.press.gated"]
        for node in lila {
            if lilaAwaitingVO.contains(node.id) {
                #expect(node.voiceAssetName == nil, "Unexpected VO on unvoiced \(node.id)")
                continue
            }
            #expect(node.voiceAssetName != nil, "Missing VO on \(node.id)")
            #expect(
                node.voiceAssetName == EmptyCoatCaseIntroduction.bundledVoiceFileName(for: node.id),
                "VO name mismatch on \(node.id)"
            )
            #expect(node.voiceAssetName?.hasPrefix("vo_lila_") == true)
            #expect(node.voiceAssetName?.hasSuffix(".m4a") == true)
        }

        // Case-title closer stays silent (UI sting, not spoken VO).
        let closer = nodes.first { $0.id == EmptyCoatCaseIntroduction.caseOpenedNodeID }
        #expect(closer?.voiceAssetName == nil)

        #expect(
            EmptyCoatCaseIntroduction.voiceAssetName(for: startID)
                == EmptyCoatCaseIntroduction.monologueOpenerVoiceAsset
        )
        #expect(
            EmptyCoatCaseIntroduction.voiceAssetName(
                for: EmptyCoatCaseIntroduction.lilaConversationStartNodeID
            ) == EmptyCoatCaseIntroduction.lilaEntranceVoiceAsset
        )
    }

    @Test func officeIntroWiresEntranceCueAndVoicePlayback() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sceneURL = root
            .appendingPathComponent("RainShadow Shared/Scenes/DetectiveOffice/DetectiveOfficeScene.swift")
        let presenterURL = root
            .appendingPathComponent("RainShadow Shared/UI/DialoguePresenter.swift")
        let baseURL = root
            .appendingPathComponent("RainShadow Shared/Core/Scene/BaseGameScene.swift")
        let scene = try String(contentsOf: sceneURL, encoding: .utf8)
        let presenter = try String(contentsOf: presenterURL, encoding: .utf8)
        let base = try String(contentsOf: baseURL, encoding: .utf8)

        // Monologue presents first; entrance is deferred until Continue *from* the leave cue.
        // PR3: scene maps `onLeaveCue` → cinematic (not Empty Coat node-id helpers).
        #expect(scene.contains("onLeaveCue"))
        #expect(scene.contains("OfficeDialogueCues.clientEntrance"))
        // Both cue kinds resolve through a lookup, so an authored cue with no handler
        // is a debug trip rather than a silent drop — which is what `onShowCue` was.
        #expect(scene.contains("deferringLeaveCueHandler"))
        #expect(scene.contains("onShowCue"))
        #expect(scene.contains("handleDialogueShowCue"))
        #expect(scene.contains("shouldDeferAdvance"))
        #expect(scene.contains("beginClientEntranceIfNeeded"))
        // Voice-over and cue reaction are a scene concern; the `onNodeShown` closure that
        // drives them now lives on `BaseGameScene` so every scene can converse.
        #expect(scene.contains("override func dialogueNodeDidShow"))
        #expect(base.contains("onNodeShown"))
        #expect(base.contains("func presentDialogue("))
        #expect(base.contains("noteTalk(with:"))
        #expect(scene.contains("pendingPostEntranceNodeID"))
        // Grok Voice plays on each node show; stops when dialogue finishes / cinematic starts.
        #expect(scene.contains("playVoiceOver"))
        #expect(scene.contains("stopVoiceOver"))
        #expect(scene.contains("node.voiceAssetName") || scene.contains("voiceAssetName"))
        #expect(scene.contains("EmptyCoatCaseIntroduction.graph"))
        // Door/entrance only inside the gated helper, not at the top of startCaseIntroduction before present.
        if let body = Self.methodBody(startingAt: "private func startCaseIntroduction()", in: scene) {
            do {
                #expect(body.contains("presentDialogue("))
                #expect(body.contains("shouldDeferAdvance"))
                // The cue *id* lives in the handler table, not here: the scene reads
                // whatever `onLeaveCue` the data names and looks it up.
                #expect(body.contains("onLeaveCue"))
                #expect(!body.contains("shouldStartClientEntrance"))
                #expect(!body.contains("animateDoorFalling()"))
                #expect(!body.contains("performEntrance"))
            }
        }
        #expect(presenter.contains("onNodeShown"))
        #expect(presenter.contains("shouldDeferAdvance"))
        #expect(presenter.contains("onLeaveCue"))
        #expect(presenter.contains("selectChoice") || presenter.contains("advanceContinue"))
        #expect(presenter.contains("func present("))
        // BG:EE keyboard: Space/Return = Continue/End only; 1–9 pick PC replies.
        #expect(scene.contains("activateCommandControl"))
        #expect(scene.contains("handleDialogueChoiceDigit"))
        #expect(scene.contains("selectChoice(at: digit - 1)") || scene.contains("selectChoice(at:"))
        #expect(!scene.contains("activateFocusedControl"))
        #expect(presenter.contains("func activateCommandControl"))
        #expect(presenter.contains("func selectChoice(at"))
        #expect(presenter.contains("!choiceRows.isEmpty") && presenter.contains("return"))
        // BG:EE one-shot intro: completed visit must not replay on office re-enter.
        #expect(scene.contains("hasCompletedOfficeCaseIntro"))
        #expect(scene.contains("applyCompletedOfficeCaseIntroFreeplayState"))
        #expect(scene.contains("markOfficeCaseIntroCompleted"))

        // BG-classic: Continue from cue → hide dialogue + walk cinematic → resume next page.
        #expect(scene.contains("setCutsceneChromeSuppressed"))
        #expect(scene.contains("updateGameplayChromeVisibility"))
        #expect(scene.contains("setCutsceneSuppressed(true)"))
        #expect(scene.contains("resumeAfterCutscene(advancingTo:"))
        #expect(presenter.contains("setCutsceneSuppressed"))
        #expect(presenter.contains("resumeAfterCutscene(advancingTo:"))
        #expect(presenter.contains("isCutsceneSuppressed"))
        // Continue and reply must defer identically: advance the session, hold only the
        // view. See DialogueDeferralStateTests for the behaviour this symbol backs.
        #expect(presenter.contains("DialogueDeferralState"))
        #expect(presenter.contains("deferral.note("))
        #expect(presenter.contains("deferral.resume()"))
        // Breakable skip and the walk choreography are no longer text in this
        // scene — they are `CutsceneCatalog.clientEntrance`, and the assertions
        // that used to grep for them live in `CutsceneCatalogTests`. What still
        // has to be true *here* is that the scene routes to that cutscene.
        #expect(scene.contains("trySkipActiveClientCutscene"))
        #expect(scene.contains("cutsceneDirector.play("))
        #expect(scene.contains("CutsceneCatalog.clientEntrance("))
        #expect(scene.contains("CutsceneCatalog.clientExit("))
        // Showing a node must not arm entrance (leave-gated only).
        #expect(!scene.contains("shouldStartClientEntrance(whenShowing:"))
        #expect(!scene.contains("shouldStartClientEntrance(whenLeaving:"))
        // The latch is gone: locomotion could not report *why* it stopped, so the
        // scene set a flag around the snap and read it back on the terminal path.
        // The runner hands the reason to the completion instead.
        #expect(!scene.contains("cutsceneBreakRequested"))
        #expect(!scene.contains("effectiveReason("))
        if let body = Self.methodBody(startingAt: "private func beginClientEntranceIfNeeded()", in: scene) {
            do {
                #expect(body.contains("clientArrivalRoute(in: navigation)"))
                #expect(body.contains("navigation.registerActor"))
                #expect(body.contains("cutsceneDirector.play("))
                // Must not re-show free-play rails when the walk finishes.
                #expect(!body.contains("setCutsceneChromeSuppressed(false)"))
            }
        }
    }

    /// The entrance still resumes the graph exactly where the authored node says,
    /// whether it plays out or the player breaks it. Previously this could only be
    /// asserted by grepping the scene for `resumeAfterCutscene(advancingTo:`.
    @Test func entranceCutsceneResumesTheAuthoredNodeOnBothPaths() throws {
        let resumeNode = try #require(
            EmptyCoatCaseIntroduction.nodes
                .first { $0.id == EmptyCoatCaseIntroduction.clientEntranceCueNodeID }?
                .nextNodeID
        )
        let cutscene = CutsceneCatalog.clientEntrance(
            route: OfficeNavigationLayout.clientArrivalPath,
            resumeDialogueNodeID: resumeNode
        )
        let resume = CutsceneCommand(.chrome, .resumeDialogue(nodeID: resumeNode))

        var natural = CutsceneRunner()
        var played = natural.begin(cutscene, at: 0).commands
        for _ in 0..<400 where natural.isPlaying {
            played += natural.advance(ticks: 1).commands
            for subject in cutscene.tracks.map(\.subject) {
                played += natural.noteCompleted(subject).commands
            }
        }
        #expect(played.contains(resume))

        var broken = CutsceneRunner()
        var interrupted = broken.begin(cutscene, at: 0).commands
        interrupted += broken.advance(ticks: 30).commands
        interrupted += broken.skip(at: 100).commands
        #expect(interrupted.contains(resume))
        #expect(broken.wasBroken)
    }

    @Test func doorFallKeepsOneContinuousTrajectoryThroughImpact() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sceneURL = root
            .appendingPathComponent("RainShadow Shared/Scenes/DetectiveOffice/DetectiveOfficeScene.swift")
        let scene = try String(contentsOf: sceneURL, encoding: .utf8)

        #expect(scene.contains("makeGeneratedFallenDoorTransition"))
        #expect(scene.contains(".move(to: fallenDoorRestPosition"))
        #expect(scene.contains("makeDoorFallShadow(at: fallenDoorRestPosition)"))
        #expect(scene.contains("entranceFallingTransitionScale"))
        #expect(!scene.contains(".moveBy(x: -135 * environment, y: -70 * environment"))
        #expect(scene.contains("Keep the old leaf visible beneath the transition art"))
    }
}

// MARK: - Condition reference validation

extension EmptyCoatCaseIntroductionTests {
    /// The failure mode that actually bites: a gate keyed on an id nothing ever sets.
    /// It does not crash, it does not warn — the choice simply never appears, which
    /// reads as intentional design. Every gate in the shipped intro is satisfiable by an
    /// action in the same graph.
    ///
    /// When evidence starts arriving from hotspots and other conversations this grows an
    /// allowlist of externally-supplied ids rather than being deleted.
    @Test func everyGateInTheShippedIntroIsSatisfiableFromWithinIt() {
        let report = EmptyCoatCaseIntroduction.graph.integrityReport()

        #expect(!report.conditionLeafIDs.isEmpty)
        #expect(
            report.externallySuppliedConditionIDs.isEmpty,
            "Gate ids no action sets: \(report.externallySuppliedConditionIDs)"
        )
        #expect(report.conditionLeafIDs.contains(EmptyCoatDialogueKeys.pressedHardOnStory))
        #expect(report.isSound)
    }

    /// Composite conditions are available to authors but the shipped graph has not
    /// needed one yet — every gate is still a single leaf.
    @Test func shippedIntroGatesStayFlat() {
        #expect(EmptyCoatCaseIntroduction.graph.integrityReport().maximumConditionDepth == 1)
    }
}

// MARK: - Source-grep support

extension EmptyCoatCaseIntroductionTests {
    /// Slice a method body out of Swift source by indentation rather than by an exact
    /// `"\n    private func "` literal, so a formatting change or a non-private
    /// neighbour does not silently widen the slice (or fail the suite outright).
    ///
    /// This is still a source grep, and it exists for one reason: `Package.swift` gives
    /// `RainShadowCore` `path: "RainShadow Shared/Gameplay/Navigation"`, so `UI/`,
    /// `Scenes/`, and `App/` are compiled into **no** test target. Greps are the only
    /// reach this suite has into scene wiring. Delete this helper — and the assertions
    /// that use it — the day a UI/Scenes test target exists.
    static func methodBody(startingAt signature: String, in source: String) -> String? {
        guard let start = source.range(of: signature) else { return nil }
        let lines = source[start.lowerBound...].split(
            separator: "\n",
            omittingEmptySubsequences: false
        )
        var body: [Substring] = []
        for (index, line) in lines.enumerated() {
            let startsNextMember = line.range(
                of: "^    (private |fileprivate |internal |public )?(static |lazy )?(func|var|let) ",
                options: .regularExpression
            ) != nil
            if index > 0, startsNextMember { break }
            body.append(line)
        }
        return body.joined(separator: "\n")
    }
}


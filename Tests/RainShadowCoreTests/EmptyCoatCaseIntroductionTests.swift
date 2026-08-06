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
        #expect(body.contains("harborpoint") || body.contains("sable"))
        // Monologue chain continues (not a choice beat).
        #expect(start.choices.isEmpty)
        #expect(start.nextNodeID != nil)

        // Full monologue sequence exists before Lila speaks and names what is about to happen.
        let monologueNodes = nodes.filter { $0.id.hasPrefix("voss.monologue") }
        #expect(monologueNodes.count >= 3)
        for node in monologueNodes {
            #expect(node.isInteriorMonologue)
        }
        let monologueText = monologueNodes.map(\.text).joined(separator: " ").lowercased()
        #expect(monologueText.contains("rain"))
        #expect(monologueText.contains("coat") || monologueText.contains("case") || monologueText.contains("dame"))
        #expect(monologueText.contains("about to happen"))
        #expect(monologueText.contains("dame") || monologueText.contains("door"))

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

        // Acceptance / key desk / longer-sentence prose lives on reply choices toward the plea.
        let acceptAnchors = ["all right, miss march", "key stays on this desk", "paper bag"]
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
            .appendingPathComponent("RainShadow Shared/UI/CaseIntroductionPresenter.swift")
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
        #expect(report.totalBodyCharacters >= 2_500)
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
        #expect(source.contains("present(\n            graph:") || source.contains("present(graph:"))
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
        for id in monologueIDs where id != cue {
            #expect(
                !EmptyCoatCaseIntroduction.shouldStartClientEntrance(whenLeaving: id),
                "Unexpected leave-entrance trigger on \(id)"
            )
            #expect(nodes.first { $0.id == id }?.onLeaveCue == nil)
        }
        #expect(!EmptyCoatCaseIntroduction.shouldStartClientEntrance(whenLeaving: "lila.entrance"))
        #expect(nodes.first { $0.id == "lila.entrance" }?.onLeaveCue == nil)

        // Cue text narratively introduces arrival (hallway / heels / door / dame).
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
            .appendingPathComponent("RainShadow Shared/UI/CaseIntroductionPresenter.swift")
        let scene = try String(contentsOf: sceneURL, encoding: .utf8)
        let presenter = try String(contentsOf: presenterURL, encoding: .utf8)

        // Monologue presents first; entrance is deferred until Continue *from* the leave cue.
        // PR3: scene maps `onLeaveCue` → cinematic (not Empty Coat node-id helpers).
        #expect(scene.contains("onLeaveCue"))
        #expect(scene.contains("OfficeDialogueCues.clientEntrance"))
        #expect(scene.contains("shouldDeferAdvance"))
        #expect(scene.contains("beginClientEntranceIfNeeded"))
        #expect(scene.contains("handleCaseIntroductionNodeShown"))
        #expect(scene.contains("onNodeShown"))
        #expect(scene.contains("pendingPostEntranceNodeID"))
        // Grok Voice plays on each node show; stops when dialogue finishes / cinematic starts.
        #expect(scene.contains("playVoiceOver"))
        #expect(scene.contains("stopVoiceOver"))
        #expect(scene.contains("node.voiceAssetName") || scene.contains("voiceAssetName"))
        #expect(scene.contains("EmptyCoatCaseIntroduction.graph"))
        // Door/entrance only inside the gated helper, not at the top of startCaseIntroduction before present.
        if let startRange = scene.range(of: "private func startCaseIntroduction()") {
            let afterStart = scene[startRange.lowerBound...]
            if let nextFunc = afterStart.range(
                of: "\n    private func ",
                options: [],
                range: afterStart.index(after: startRange.upperBound)..<afterStart.endIndex
            ) {
                let body = String(afterStart[..<nextFunc.lowerBound])
                #expect(body.contains("caseIntroductionPresenter.present"))
                #expect(body.contains("shouldDeferAdvance"))
                #expect(body.contains("onLeaveCue"))
                #expect(body.contains("OfficeDialogueCues.clientEntrance"))
                #expect(!body.contains("shouldStartClientEntrance"))
                #expect(!body.contains("animateDoorFalling()"))
                #expect(!body.contains("performEntrance"))
            }
        }
        #expect(presenter.contains("onNodeShown"))
        #expect(presenter.contains("shouldDeferAdvance"))
        #expect(presenter.contains("onLeaveCue"))
        #expect(presenter.contains("selectChoice") || presenter.contains("advanceContinue"))
        #expect(presenter.contains("present(\n        graph:") || presenter.contains("func present(\n        graph:"))
        // BG:EE keyboard: Space/Return = Continue/End only; 1–9 pick PC replies.
        #expect(scene.contains("activateCommandControl"))
        #expect(scene.contains("handleDialogueChoiceDigit"))
        #expect(scene.contains("selectChoice(at: digit - 1)") || scene.contains("selectChoice(at:"))
        #expect(!scene.contains("activateFocusedControl"))
        #expect(presenter.contains("func activateCommandControl"))
        #expect(presenter.contains("func selectChoice(at"))
        #expect(presenter.contains("!choiceRows.isEmpty") && presenter.contains("return"))

        // BG-classic: Continue from cue → hide dialogue + walk cinematic → resume next page.
        #expect(scene.contains("setCutsceneChromeSuppressed"))
        #expect(scene.contains("updateGameplayChromeVisibility"))
        #expect(scene.contains("setCutsceneSuppressed(true)"))
        #expect(scene.contains("resumeAfterCutscene(advancingTo:"))
        #expect(presenter.contains("setCutsceneSuppressed"))
        #expect(presenter.contains("resumeAfterCutscene(advancingTo:"))
        #expect(presenter.contains("isCutsceneSuppressed"))
        // Breakable skip: shared finish path + snap-to-end (BG SetCutSceneBreakable).
        #expect(scene.contains("finishClientEntrance(reason:"))
        #expect(scene.contains("trySkipActiveClientCutscene"))
        #expect(scene.contains("completeEntranceImmediately"))
        #expect(scene.contains("completeExitImmediately"))
        #expect(scene.contains("BreakableCutsceneGate"))
        #expect(scene.contains("ClientEntranceTerminalState"))
        #expect(scene.contains("setCutsceneLetterboxVisible"))
        // Showing a node must not arm entrance (leave-gated only).
        #expect(!scene.contains("shouldStartClientEntrance(whenShowing:"))
        #expect(!scene.contains("shouldStartClientEntrance(whenLeaving:"))
        if let entranceRange = scene.range(of: "private func beginClientEntranceIfNeeded()") {
            let afterEntrance = scene[entranceRange.lowerBound...]
            if let nextFunc = afterEntrance.range(
                of: "\n    private func ",
                options: [],
                range: afterEntrance.index(after: entranceRange.upperBound)..<afterEntrance.endIndex
            ) {
                let body = String(afterEntrance[..<nextFunc.lowerBound])
                #expect(body.contains("setCutsceneChromeSuppressed(true)"))
                #expect(body.contains("setCutsceneSuppressed(true)"))
                #expect(body.contains("finishClientEntrance(reason: .natural)"))
                #expect(body.contains("setCutsceneLetterboxVisible(true)"))
                // Must not re-show free-play rails when the walk finishes.
                #expect(!body.contains("setCutsceneChromeSuppressed(false)"))
            }
        }
        if let finishRange = scene.range(of: "private func finishClientEntrance(reason:") {
            let afterFinish = scene[finishRange.lowerBound...]
            if let nextFunc = afterFinish.range(
                of: "\n    private func ",
                options: [],
                range: afterFinish.index(after: finishRange.upperBound)..<afterFinish.endIndex
            ) {
                let body = String(afterFinish[..<nextFunc.lowerBound])
                #expect(body.contains("resumeAfterCutscene(advancingTo:"))
                #expect(body.contains("markCompleted()"))
                #expect(body.contains("ClientEntranceTerminalState"))
            }
        }
        if let applyRange = scene.range(of: "private func applyClientVisitAction") {
            let afterApply = scene[applyRange.lowerBound...]
            if let nextFunc = afterApply.range(
                of: "\n    private func ",
                options: [],
                range: afterApply.index(after: applyRange.upperBound)..<afterApply.endIndex
            ) {
                let body = String(afterApply[..<nextFunc.lowerBound])
                #expect(body.contains("case .unlockPlayerControl:"))
                #expect(body.contains("setCutsceneChromeSuppressed(false)"))
            }
        }
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

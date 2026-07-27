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

        // Spoken lines (Lila, case accept) are not monologue italics.
        let spoken = nodes.filter { $0.id.hasPrefix("lila.") || $0.id.hasPrefix("voss.accept") }
        #expect(!spoken.isEmpty)
        for node in spoken {
            #expect(!node.isInteriorMonologue)
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
        #expect(report.reachableNodeIDs.contains(EmptyCoatCaseIntroduction.caseOpenedNodeID))

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
        #expect(source.contains("EmptyCoatCaseIntroduction.nodes"))
        #expect(source.contains("EmptyCoatCaseIntroduction.startNodeID"))
        #expect(!source.contains("speaker: \"Vivian Hart\""))
        #expect(!source.contains("speaker: \"Elias Vale\""))
        #expect(!source.contains("vivian.opening"))
    }

    // MARK: - Entrance cue + voice openers (shipped pure helpers)

    @Test func monologueStartDoesNotTriggerClientEntrance() {
        // Intro presents monologue first; entrance is a separate late-monologue cue.
        #expect(startID == "voss.monologue.1")
        #expect(!EmptyCoatCaseIntroduction.shouldStartClientEntrance(whenShowing: startID))
        #expect(!EmptyCoatCaseIntroduction.shouldStartClientEntrance(whenShowing: "voss.monologue.2"))
        #expect(!EmptyCoatCaseIntroduction.shouldStartClientEntrance(whenShowing: "voss.monologue.3"))
        #expect(!EmptyCoatCaseIntroduction.shouldStartClientEntrance(whenShowing: "lila.entrance"))
        #expect(!EmptyCoatCaseIntroduction.shouldStartClientEntrance(whenShowing: EmptyCoatCaseIntroduction.caseOpenedNodeID))
    }

    @Test func clientEntranceCueIsSoleLateMonologueTrigger() {
        let cue = EmptyCoatCaseIntroduction.clientEntranceCueNodeID
        #expect(cue == "voss.monologue.4")
        #expect(EmptyCoatCaseIntroduction.shouldStartClientEntrance(whenShowing: cue))

        let monologueIDs = nodes
            .map(\.id)
            .filter { $0.hasPrefix("voss.monologue") }
        #expect(monologueIDs.contains(cue))
        #expect(monologueIDs.contains(startID))
        // Only the designated cue among monologue nodes starts entrance.
        for id in monologueIDs where id != cue {
            #expect(
                !EmptyCoatCaseIntroduction.shouldStartClientEntrance(whenShowing: id),
                "Unexpected entrance trigger on \(id)"
            )
        }

        // Cue text narratively introduces arrival (hallway / heels / door / dame).
        let cueNode = nodes.first { $0.id == cue }
        #expect(cueNode != nil)
        let body = (cueNode?.text ?? "").lowercased()
        #expect(body.contains("hallway") || body.contains("heels") || body.contains("door"))
        // Cue is before Lila speaks — monologue chain still continues.
        #expect(cueNode?.nextNodeID != nil)
        #expect(cueNode?.nextNodeID != EmptyCoatCaseIntroduction.lilaConversationStartNodeID || monologueIDs.count == 1)
        #expect(nodes.contains { $0.id == "voss.monologue.5" })
        #expect(cueNode?.nextNodeID == "voss.monologue.5")
    }

    @Test func dialogueNodesAreCurrentlySilentWithoutVoiceAssets() {
        // VO is parked for a later pass — openers and full graph must not schedule clips.
        #expect(EmptyCoatCaseIntroduction.voiceAssetName(for: startID) == nil)
        #expect(
            EmptyCoatCaseIntroduction.voiceAssetName(
                for: EmptyCoatCaseIntroduction.lilaConversationStartNodeID
            ) == nil
        )
        for node in nodes {
            #expect(node.voiceAssetName == nil, "Unexpected VO on \(node.id)")
            #expect(EmptyCoatCaseIntroduction.voiceAssetName(for: node.id) == nil)
        }
        // Reserved filenames remain documented for when VO returns.
        #expect(EmptyCoatCaseIntroduction.monologueOpenerVoiceAsset.hasSuffix(".m4a"))
        #expect(EmptyCoatCaseIntroduction.lilaEntranceVoiceAsset.hasSuffix(".m4a"))
    }

    @Test func officeIntroWiresEntranceCueWithoutVoicePlayback() throws {
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

        // Monologue presents first; entrance is armed from the cue callback — not at intro start.
        #expect(scene.contains("shouldStartClientEntrance"))
        #expect(scene.contains("beginClientEntranceIfNeeded"))
        #expect(scene.contains("handleCaseIntroductionNodeShown"))
        #expect(scene.contains("onNodeShown"))
        // VO playback is offline for now.
        #expect(!scene.contains("playVoiceOver"))
        #expect(scene.contains("EmptyCoatCaseIntroduction.startNodeID"))
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
                #expect(!body.contains("animateDoorFalling()"))
                #expect(!body.contains("performEntrance"))
            }
        }
        #expect(presenter.contains("onNodeShown"))
    }
}

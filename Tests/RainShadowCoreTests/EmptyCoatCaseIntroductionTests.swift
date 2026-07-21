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
}

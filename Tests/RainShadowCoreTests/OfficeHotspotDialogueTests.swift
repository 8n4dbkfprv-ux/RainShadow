import Foundation
import Testing
@testable import RainShadowCore

struct OfficeHotspotDialogueTests {
    private var authoredHotspotIDs: [String] {
        OfficeNavigationLayout.authoredHotspots.map(\.id)
    }

    @Test func catalogCoversEveryAuthoredOfficeHotspot() throws {
        let byID = try OfficeHotspotDialogue.allGraphs()
        #expect(byID.count == authoredHotspotIDs.count)
        for hotspotID in authoredHotspotIDs {
            let graphID = OfficeHotspotDialogue.graphID(forHotspotID: hotspotID)
            let graph = try #require(byID[graphID])
            #expect(graph.startNodeID == OfficeHotspotDialogue.startNodeID(forHotspotID: hotspotID))
            #expect(CaseDialogueGraph.report(graph: graph).isSound)
            // Inspect prose is observation, never a conversation: every node is a single
            // page that ends on Continue, with no player replies. Graphs may now hold
            // more than one such node so a second look can differ (entry scan), so the
            // invariant is per-node rather than "exactly one node".
            for node in graph.nodes {
                #expect(node.endsDialogue)
                #expect(node.choices.isEmpty)
                #expect(node.portraitName == OfficeHotspotDialogue.vossPortrait)
            }
            let node = try #require(graph.node(id: graph.startNodeID))
            #expect(node.endsDialogue)
        }
    }

    @Test func inspectProseMatchesLayoutObservations() throws {
        for item in OfficeNavigationLayout.authoredHotspots {
            let graph = OfficeHotspotDialogue.graph(forHotspotID: item.id)
            let node = try #require(graph.node(id: graph.startNodeID))
            #expect(node.speaker == item.name)
            #expect(node.text == item.observation)
        }
    }

    @Test func facadeGraphMatchesCatalogLookup() {
        for hotspotID in authoredHotspotIDs {
            let viaFacade = OfficeHotspotDialogue.graph(forHotspotID: hotspotID)
            let viaOptional = OfficeHotspotDialogue.graphIfPresent(forHotspotID: hotspotID)
            #expect(viaOptional == viaFacade)
            #expect(viaFacade.id == OfficeHotspotDialogue.graphID(forHotspotID: hotspotID))
        }
    }

    @Test func missingCatalogGraphThrows() {
        #expect(throws: DialogueGraphLoaderError.graphNotInCatalog(
            graphID: "inspect.office.missing",
            catalog: OfficeHotspotDialogue.catalogResourceName
        )) {
            try DialogueGraphLoader.loadFromCatalog(
                graphID: "inspect.office.missing",
                catalogResourceName: OfficeHotspotDialogue.catalogResourceName
            )
        }
    }

    @Test func officeSceneUsesHotspotDialogueFacadeNotInlineNodes() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sceneURL = root.appendingPathComponent(
            "RainShadow Shared/Scenes/DetectiveOffice/DetectiveOfficeScene.swift"
        )
        let source = try String(contentsOf: sceneURL, encoding: .utf8)
        #expect(source.contains("OfficeHotspotDialogue.graph(forHotspotID:"))
        // Inspect goes through the shared presentation door (which seeds the live case
        // and merges the result back), not a raw `present(graph:)` on the panel.
        #expect(source.contains("presentDialogue("))
        // Ad-hoc inspect constructors must not remain in the inspect path.
        if let range = source.range(of: "private func presentInspection") {
            let after = source[range.lowerBound...]
            if let next = after.range(
                of: "\n    private func ",
                options: [],
                range: after.index(after: range.upperBound)..<after.endIndex
            ) {
                let body = String(after[..<next.lowerBound])
                #expect(body.contains("OfficeHotspotDialogue.graph"))
                #expect(!body.contains("CaseDialogueNode("))
                #expect(!body.contains("hotspot.observation"))
            }
        }
    }

    @Test func catalogDecodeRejectsBadSchema() throws {
        let json = """
        {
          "schemaVersion": 9,
          "graphs": []
        }
        """
        #expect(throws: DialogueGraphLoaderError.unsupportedSchemaVersion(found: 9, supported: 1)) {
            try DialogueGraphLoader.decodeCatalog(Data(json.utf8))
        }
    }
}

// MARK: - Second look (IE NumTimesTalkedTo on observation)

extension OfficeHotspotDialogueTests {
    /// Shipped proof that the entry scan carries real content, not just fixtures: looking
    /// at the window a second time opens on a different node. The hotspot is its own
    /// conversation owner, so the scene's talk counter drives it.
    @Test func lookingAtTheWindowTwiceOpensADifferentNode() {
        let graph = OfficeHotspotDialogue.graph(forHotspotID: "office.window")
        #expect(graph.entryNodeIDs == ["inspection.office.window.again", "inspection.office.window"])

        var state = CaseState(caseID: EmptyCoatJournalContent.caseID)
        var context = DialogueRuntimeContext(
            caseState: state,
            dialogueState: DialogueState(graphID: graph.id)
        )

        let first = DialogueSession(graph: graph, context: context)
        #expect(first.currentNodeID == "inspection.office.window")
        let firstText = first.currentNode?.text ?? ""

        // The scene bumps the owner's talk count when the conversation ends.
        state.noteTalk(with: "office.window")
        context = DialogueRuntimeContext(
            caseState: state,
            dialogueState: DialogueState(graphID: graph.id)
        )

        let second = DialogueSession(graph: graph, context: context)
        #expect(second.currentNodeID == "inspection.office.window.again")
        #expect(second.currentNode?.text != firstText)
        #expect(second.currentNode?.text.isEmpty == false)
        // Prose resolves through the string table like every other shipped line.
        #expect(second.currentNode?.speaker == first.currentNode?.speaker)
    }

    /// Every inspect graph still opens somewhere and ends, entry list or not.
    @Test func everyInspectGraphIsSound() throws {
        for hotspotID in authoredHotspotIDs {
            let graph = OfficeHotspotDialogue.graph(forHotspotID: hotspotID)
            try graph.validateAuthoring()
            #expect(graph.integrityReport().isSound, "\(hotspotID) is not sound")
        }
    }
}


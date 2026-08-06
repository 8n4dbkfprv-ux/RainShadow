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
            #expect(graph.nodes.count == 1)
            let node = try #require(graph.node(id: graph.startNodeID))
            #expect(node.endsDialogue)
            #expect(node.choices.isEmpty)
            #expect(node.portraitName == OfficeHotspotDialogue.vossPortrait)
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
        #expect(source.contains("present(\n            graph:"))
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

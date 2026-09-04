import Foundation
import Testing
@testable import RainShadowCore

/// One test over **every shipped conversation resource**.
///
/// Per-graph integrity only ever saw one file at a time, and the presenter, scene wiring,
/// and facades all live outside any SPM target — so the suite's reach into shipped content
/// was a handful of source greps. This walks the real JSON instead: it loads what the game
/// loads, and asserts the same authoring rules the loader enforces. It is worth more than
/// every string match in this suite put together.
struct ShippedDialogueCatalogTests {
    /// Everything the game can present today.
    private func shippedCatalog() throws -> DialogueGraphCatalog {
        var graphs = [
            EmptyCoatCaseIntroduction.graph,
            OfficeCaseFileMonologue.graph
        ]
        graphs.append(contentsOf: try OfficeHotspotDialogue.allGraphs().values)
        return DialogueGraphCatalog(graphs: graphs)
    }

    @Test func everyShippedGraphLoadsAndPassesAuthoringValidation() throws {
        let catalog = try shippedCatalog()
        #expect(catalog.graphIDs.count == 7)

        for graph in catalog.graphs {
            try graph.validateAuthoring()
        }
    }

    @Test func theShippedCatalogIsSound() throws {
        let report = CaseDialogueGraph.report(catalog: try shippedCatalog())

        #expect(report.unsoundGraphIDs.isEmpty, "structurally unsound: \(report.unsoundGraphIDs)")
        #expect(
            report.missingDestinationGraphIDs.isEmpty,
            "cross-graph links to missing graphs: \(report.missingDestinationGraphIDs)"
        )
        #expect(
            report.missingCrossGraphNodeIDs.isEmpty,
            "cross-graph links to missing nodes: \(report.missingCrossGraphNodeIDs)"
        )
        #expect(
            report.graphIDsWithNoReachableEnding.isEmpty,
            "conversations that can never close: \(report.graphIDsWithNoReachableEnding)"
        )
        #expect(report.isSound)
    }

    /// No shipped graph has a duplicated node id — the case that used to *trap* rather
    /// than report.
    @Test func noShippedGraphDuplicatesANodeID() throws {
        for graph in try shippedCatalog().graphs {
            #expect(graph.duplicateNodeIDs.isEmpty, "\(graph.id) duplicates \(graph.duplicateNodeIDs)")
        }
    }

    /// Every gate reads an id something can produce. Talk counters are written by the
    /// scene when a conversation ends rather than by an action, so they are named here
    /// explicitly instead of being waved through.
    @Test func everyGateInShippedContentIsSatisfiable() throws {
        let sceneWrittenIDs: Set<String> = [
            CaseState.talkCounterID("office.window")
        ]

        for graph in try shippedCatalog().graphs {
            let unmet = Set(graph.integrityReport().externallySuppliedConditionIDs)
                .subtracting(sceneWrittenIDs)
            #expect(unmet.isEmpty, "\(graph.id) gates on ids nothing sets: \(unmet.sorted())")
        }
    }

    /// Composite conditions exist for authors, but nothing shipped needs deep nesting yet.
    @Test func shippedConditionsStayWellInsideTheAuthoringDepthLimit() throws {
        for graph in try shippedCatalog().graphs {
            let depth = graph.integrityReport().maximumConditionDepth
            #expect(depth <= DialogueCondition.maximumNestingDepth, "\(graph.id) nests \(depth) deep")
        }
    }

    /// Prose lives in the string table, not in the graph files. A node whose text still
    /// looks like a key means a missing entry resolved to its own id.
    @Test func everyShippedNodeResolvedRealProse() throws {
        for graph in try shippedCatalog().graphs {
            for node in graph.nodes {
                #expect(!node.text.isEmpty, "\(graph.id):\(node.id) has no text")
                #expect(!node.text.hasPrefix("dlg."), "\(graph.id):\(node.id) text is an unresolved key")
                #expect(!node.speaker.isEmpty, "\(graph.id):\(node.id) has no speaker")
                #expect(!node.speaker.hasPrefix("dlg."), "\(graph.id):\(node.id) speaker is an unresolved key")
            }
        }
    }

    /// The frozen classic-BG rule, applied across every shipped graph rather than only the
    /// intro: mid-conversation PC lines are reply options, never Continue-only speaker
    /// pages. Interior monologue is the documented exception (GDD §7.5).
    @Test func noShippedGraphDeliversMidConversationPCSpeechAsAContinuePage() throws {
        for graph in try shippedCatalog().graphs {
            for node in graph.nodes
            where node.speaker == EmptyCoatCaseIntroduction.vossSpeaker
                && !node.isInteriorMonologue
                && node.choices.isEmpty
                && node.nextNodeID != nil {
                Issue.record("\(graph.id):\(node.id) is a mid-conversation Voss Continue page")
            }
        }
    }
}

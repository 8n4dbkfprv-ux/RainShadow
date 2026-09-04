import Foundation

/// The set of graphs a conversation may jump between — RainShadow's answer to a folder
/// full of DLG files.
///
/// The walker stays pure: it never loads anything. Whoever starts the conversation hands
/// it the graphs that could be reached (from `DialogueGraphLoader`), and cross-graph
/// destinations resolve out of this value.
struct DialogueGraphCatalog: Equatable, Sendable {
    private var graphsByID: [String: DialogueGraph]

    static let empty = DialogueGraphCatalog()

    init(graphs: [DialogueGraph] = []) {
        var index: [String: DialogueGraph] = [:]
        index.reserveCapacity(graphs.count)
        for graph in graphs {
            index[graph.id] = graph
        }
        graphsByID = index
    }

    init(graphsByID: [String: DialogueGraph]) {
        self.graphsByID = graphsByID
    }

    var graphIDs: Set<String> { Set(graphsByID.keys) }

    var graphs: [DialogueGraph] {
        graphsByID.keys.sorted().compactMap { graphsByID[$0] }
    }

    var isEmpty: Bool { graphsByID.isEmpty }

    func graph(id: String) -> DialogueGraph? {
        graphsByID[id]
    }

    func adding(_ graph: DialogueGraph) -> DialogueGraphCatalog {
        var copy = self
        copy.graphsByID[graph.id] = graph
        return copy
    }

    func adding(contentsOf other: DialogueGraphCatalog) -> DialogueGraphCatalog {
        var copy = self
        copy.graphsByID.merge(other.graphsByID) { _, new in new }
        return copy
    }
}

extension CaseDialogueGraph {
    /// Whole-catalog authoring report.
    ///
    /// Per-graph integrity only ever saw one file, so a cross-graph destination could name
    /// a graph or node that does not exist and nothing would notice until a player took
    /// that reply. This is the check worth having even before anything uses EXTERN.
    struct CatalogIntegrityReport: Equatable, Sendable {
        /// Per-graph reports, keyed by graph id.
        var perGraph: [String: IntegrityReport]
        /// Cross-graph links whose target graph is not in the catalog, as
        /// `"graph:node->missingGraph:node"`, sorted.
        var missingDestinationGraphIDs: [String]
        /// Cross-graph links whose target graph exists but does not hold that node,
        /// same format, sorted.
        var missingCrossGraphNodeIDs: [String]
        /// Graphs from which no ending is reachable even after following cross-graph
        /// links, sorted. A conversation that enters one of these can never be closed.
        var graphIDsWithNoReachableEnding: [String]

        /// Every graph structurally sound, every cross-graph link resolvable, and every
        /// graph able to reach an ending — possibly via another file, which is exactly
        /// what per-graph `isSound` cannot see.
        var isSound: Bool {
            missingDestinationGraphIDs.isEmpty
                && missingCrossGraphNodeIDs.isEmpty
                && graphIDsWithNoReachableEnding.isEmpty
                && perGraph.values.allSatisfy(\.isStructurallySound)
        }

        /// Graph ids whose own structure is broken, sorted — for a readable failure message.
        var unsoundGraphIDs: [String] {
            perGraph.filter { !$0.value.isStructurallySound }.keys.sorted()
        }
    }

    static func report(catalog: DialogueGraphCatalog) -> CatalogIntegrityReport {
        var perGraph: [String: IntegrityReport] = [:]
        var missingGraphs: [String] = []
        var missingNodes: [String] = []

        for graph in catalog.graphs {
            perGraph[graph.id] = report(graph: graph)
            for node in graph.nodes {
                for choice in node.choices {
                    guard let targetGraphID = choice.destinationGraphID else { continue }
                    let link = "\(graph.id):\(node.id)->\(targetGraphID):\(choice.destinationID)"
                    guard let target = catalog.graph(id: targetGraphID) else {
                        missingGraphs.append(link)
                        continue
                    }
                    if target.node(id: choice.destinationID) == nil {
                        missingNodes.append(link)
                    }
                }
            }
        }

        return CatalogIntegrityReport(
            perGraph: perGraph,
            missingDestinationGraphIDs: missingGraphs.sorted(),
            missingCrossGraphNodeIDs: missingNodes.sorted(),
            graphIDsWithNoReachableEnding: graphIDsWithNoReachableEnding(
                in: catalog,
                perGraph: perGraph
            )
        )
    }

    /// Fixed point over "can a conversation entering this graph ever end?".
    ///
    /// Seed with the graphs that reach an ending on their own, then repeatedly add any
    /// graph with a cross-graph link into the set, until nothing new is added.
    private static func graphIDsWithNoReachableEnding(
        in catalog: DialogueGraphCatalog,
        perGraph: [String: IntegrityReport]
    ) -> [String] {
        var terminal = Set(perGraph.filter { $0.value.reachesEnding }.keys)
        var changed = true
        while changed {
            changed = false
            for graph in catalog.graphs where !terminal.contains(graph.id) {
                let reachable = perGraph[graph.id]?.reachableNodeIDs ?? []
                let handsOff = graph.nodes
                    .filter { reachable.contains($0.id) }
                    .flatMap(\.choices)
                    .compactMap(\.destinationGraphID)
                    .contains { terminal.contains($0) }
                if handsOff {
                    terminal.insert(graph.id)
                    changed = true
                }
            }
        }
        return catalog.graphIDs.subtracting(terminal).sorted()
    }
}

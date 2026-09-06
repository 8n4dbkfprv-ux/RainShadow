import Foundation
import Testing
@testable import RainShadowCore

struct DialogueGraphLoaderTests {
    private var fixtureURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Dialogue/fixture.tiny.dialogue.json")
    }

    private var fixtureData: Data {
        get throws {
            try Data(contentsOf: fixtureURL)
        }
    }

    // MARK: - Decode

    @Test func decodeFixtureGraph() throws {
        let graph = try DialogueGraphLoader.decode(fixtureData)
        #expect(graph.id == "fixture.tiny")
        #expect(graph.startNodeID == "npc.open")
        #expect(graph.nodes.count == 4)
        #expect(graph.node(id: "npc.open") != nil)
        #expect(graph.node(id: "end")?.endsDialogue == true)
    }

    @Test func decodePreservesConditionActionAndCue() throws {
        let graph = try DialogueGraphLoader.decode(fixtureData)
        let open = try #require(graph.node(id: "npc.open"))
        #expect(open.choices.count == 2)

        let press = try #require(open.choices.first { $0.gateDisclosure == "Press" })
        #expect(press.conditions == [.hasFlag("fixture.pressed-hard")])
        #expect(press.onSelect.count == 2)
        #expect(press.onSelect.contains(.setCaseFlag("fixture.case.opened")))
        #expect(
            press.onSelect.contains(
                .queueJournal(
                    QueuedJournalFragment(
                        id: "chrono.fixture-press",
                        kind: .chronology,
                        text: "Pressed the pier story."
                    )
                )
            )
        )
        #expect(press.tone == .sharp)

        let leaveNode = try #require(graph.node(id: "npc.press"))
        #expect(leaveNode.onLeaveCue == "office.clientEntrance")
        #expect(leaveNode.onShowCue == nil)

        let voiced = try #require(graph.node(id: "npc.more"))
        #expect(voiced.voiceAssetName == "vo_fixture_more.m4a")
    }

    @Test func decodeThenIntegrityReportIsSound() throws {
        let graph = try DialogueGraphLoader.decode(fixtureData)
        let report = CaseDialogueGraph.report(graph: graph)
        #expect(report.isSound)
        #expect(report.missingDestinationIDs.isEmpty)
        #expect(report.reachesEnding)
        #expect(report.gatedChoiceCount == 1)
        #expect(report.actionChoiceCount == 1)
    }

    @Test func roundTripEncodeDecodePreservesGraph() throws {
        let original = try DialogueGraphLoader.decode(fixtureData)
        let encoded = try DialogueGraphLoader.encode(original)
        let restored = try DialogueGraphLoader.decode(encoded)
        #expect(restored == original)
    }

    @Test func loadFromFileURL() throws {
        let graph = try DialogueGraphLoader.load(contentsOf: fixtureURL)
        #expect(graph.id == "fixture.tiny")
        #expect(graph.startNodeID == "npc.open")
    }

    // MARK: - Schema / validation errors

    @Test func unsupportedSchemaVersionThrows() throws {
        let json = """
        {
          "schemaVersion": 99,
          "id": "bad.schema",
          "startNodeID": "a",
          "nodes": [
            { "id": "a", "speaker": "S", "text": "T", "endsDialogue": true }
          ]
        }
        """
        let data = Data(json.utf8)
        #expect(throws: DialogueGraphLoaderError.unsupportedSchemaVersion(found: 99, supported: 1)) {
            try DialogueGraphLoader.decode(data)
        }
    }

    @Test func emptyGraphThrows() throws {
        let json = """
        {
          "schemaVersion": 1,
          "id": "empty",
          "startNodeID": "missing",
          "nodes": []
        }
        """
        let data = Data(json.utf8)
        #expect(throws: DialogueGraphLoaderError.emptyGraph(id: "empty")) {
            try DialogueGraphLoader.decode(data)
        }
    }

    @Test func missingStartNodeThrows() throws {
        let json = """
        {
          "schemaVersion": 1,
          "id": "no-start",
          "startNodeID": "gone",
          "nodes": [
            { "id": "a", "speaker": "S", "text": "T", "endsDialogue": true }
          ]
        }
        """
        let data = Data(json.utf8)
        #expect(throws: DialogueGraphLoaderError.missingStartNode(graphID: "no-start", startNodeID: "gone")) {
            try DialogueGraphLoader.decode(data)
        }
    }

    /// A duplicated node id silently shadows the earlier node in every lookup. The
    /// index used to be built with `Dictionary(uniqueKeysWithValues:)`, so an authoring
    /// typo **trapped** — the process died rather than reporting the mistake.
    @Test func duplicateNodeIDThrowsInsteadOfTrapping() throws {
        let json = """
        {
          "schemaVersion": 1,
          "id": "dupe.nodes",
          "startNodeID": "a",
          "nodes": [
            { "id": "a", "speaker": "S", "text": "First", "nextNodeID": "b" },
            { "id": "b", "speaker": "S", "text": "Second", "endsDialogue": true },
            { "id": "a", "speaker": "S", "text": "Shadow", "endsDialogue": true }
          ]
        }
        """
        #expect(throws: DialogueGraphLoaderError.duplicateNodeID(graphID: "dupe.nodes", nodeID: "a")) {
            try DialogueGraphLoader.decode(Data(json.utf8))
        }
    }

    /// The catalog path failed differently: `result[graph.id] = graph` was last-wins, so
    /// a duplicated graph id made one graph vanish and the facade's "fail fast if
    /// missing" lookup never fired.
    @Test func duplicateCatalogGraphIDThrowsInsteadOfVanishing() throws {
        let json = """
        {
          "schemaVersion": 1,
          "graphs": [
            {
              "id": "inspect.office.window",
              "startNodeID": "a",
              "nodes": [{ "id": "a", "speaker": "S", "text": "Rain.", "endsDialogue": true }]
            },
            {
              "id": "inspect.office.window",
              "startNodeID": "b",
              "nodes": [{ "id": "b", "speaker": "S", "text": "Shadow.", "endsDialogue": true }]
            }
          ]
        }
        """
        #expect(
            throws: DialogueGraphLoaderError.duplicateGraphID(
                catalog: "office.inspect",
                graphID: "inspect.office.window"
            )
        ) {
            try DialogueGraphLoader.decodeCatalog(Data(json.utf8), catalogName: "office.inspect")
        }
    }

    /// A graph carrying a duplicate is not sound even when every destination resolves.
    @Test func integrityReportFlagsDuplicateNodeIDs() {
        let nodes = [
            CaseDialogueNode(id: "a", speaker: "S", text: "First", nextNodeID: "b"),
            CaseDialogueNode(id: "b", speaker: "S", text: "Second", endsDialogue: true),
            CaseDialogueNode(id: "a", speaker: "S", text: "Shadow", endsDialogue: true)
        ]

        let report = CaseDialogueGraph.report(nodes: nodes, startID: "a")

        #expect(report.duplicateNodeIDs == ["a"])
        #expect(report.missingDestinationIDs.isEmpty)
        #expect(report.reachesEnding)
        #expect(!report.isSound)
    }

    @Test func missingDestinationSurfacesInIntegrityReport() throws {
        let json = """
        {
          "schemaVersion": 1,
          "id": "broken.dest",
          "startNodeID": "a",
          "nodes": [
            {
              "id": "a",
              "speaker": "S",
              "text": "Choose",
              "choices": [
                { "text": "Go nowhere", "destinationID": "does.not.exist" }
              ]
            },
            {
              "id": "end",
              "speaker": "S",
              "text": "Done",
              "endsDialogue": true
            }
          ]
        }
        """
        let graph = try DialogueGraphLoader.decode(Data(json.utf8))
        let report = CaseDialogueGraph.report(graph: graph)
        #expect(!report.missingDestinationIDs.isEmpty)
        #expect(report.missingDestinationIDs.contains("a->does.not.exist"))
        #expect(!report.isSound)
    }

    @Test func optionalFieldsDefaultWhenOmitted() throws {
        let json = """
        {
          "schemaVersion": 1,
          "id": "minimal",
          "startNodeID": "only",
          "nodes": [
            { "id": "only", "speaker": "S", "text": "Hi", "endsDialogue": true }
          ]
        }
        """
        let graph = try DialogueGraphLoader.decode(Data(json.utf8))
        let node = try #require(graph.node(id: "only"))
        #expect(node.choices.isEmpty)
        #expect(node.nextNodeID == nil)
        #expect(node.endsDialogue)
        #expect(!node.isInteriorMonologue)
        #expect(node.portraitName == nil)
        #expect(node.voiceAssetName == nil)
        #expect(node.onLeaveCue == nil)
        #expect(node.onShowCue == nil)
    }

    @Test func defaultResourceNameStripsCasePrefix() {
        #expect(
            DialogueGraphLoader.defaultResourceName(for: "case.empty-coat.intro")
                == "empty-coat.intro.dialogue"
        )
        #expect(
            DialogueGraphLoader.defaultResourceName(for: "fixture.tiny")
                == "fixture.tiny.dialogue"
        )
    }

    @Test func sessionWalksDecodedFixtureWithGate() throws {
        let graph = try DialogueGraphLoader.decode(fixtureData)
        var session = DialogueSession(
            graph: graph,
            context: DialogueRuntimeContext(
                caseState: CaseState(caseID: "fixture"),
                dialogueState: DialogueState(graphID: graph.id)
            )
        )
        #expect(session.visibleChoices.count == 1)

        session.context.dialogueState.setConversationFlag("fixture.pressed-hard")
        // hasFlag checks conversation or case flags via DialogueRuntimeContext
        #expect(session.visibleChoices.count == 2)

        let result = session.selectChoice(at: 1)
        guard case .showing(let node) = result else {
            Issue.record("Expected showing after press choice")
            return
        }
        #expect(node.id == "npc.press")
        #expect(session.context.caseState.hasFlag("fixture.case.opened"))
        #expect(session.context.caseState.queuedJournalFragments.count == 1)
    }

    // MARK: - Shipped resource packages (PR2)

    @Test func loadsEmptyCoatIntroFromDialogueResources() throws {
        let graph = try DialogueGraphLoader.load(
            id: EmptyCoatDialogueKeys.graphID,
            resourceName: EmptyCoatCaseIntroduction.resourceName
        )
        #expect(graph.id == EmptyCoatDialogueKeys.graphID)
        #expect(graph.startNodeID == EmptyCoatCaseIntroduction.startNodeID)
        #expect(graph.nodes.count >= EmptyCoatCaseIntroduction.legacyNodeCountFloor)
        #expect(CaseDialogueGraph.report(graph: graph).isSound)
        #expect(graph == EmptyCoatCaseIntroduction.graph)
    }

    @Test func loadsDeskMonologueFromDialogueResources() throws {
        let graph = try DialogueGraphLoader.load(
            id: OfficeCaseFileMonologue.graphID,
            resourceName: OfficeCaseFileMonologue.resourceName
        )
        #expect(graph.id == OfficeCaseFileMonologue.graphID)
        #expect(graph.startNodeID == OfficeCaseFileMonologue.startNodeID)
        #expect(graph.nodes.count == 3)
        #expect(CaseDialogueGraph.report(graph: graph).isSound)
        #expect(graph == OfficeCaseFileMonologue.graph)
    }

    @Test func emptyCoatCueNodeAuthorsClientEntranceLeaveCue() {
        let cue = EmptyCoatCaseIntroduction.graph.node(
            id: EmptyCoatCaseIntroduction.clientEntranceCueNodeID
        )
        #expect(cue?.onLeaveCue == OfficeDialogueCues.clientEntrance)
        #expect(
            EmptyCoatCaseIntroduction.shouldStartClientEntrance(
                whenLeaving: EmptyCoatCaseIntroduction.clientEntranceCueNodeID
            )
        )
    }

    @Test func emptyCoatFacadeNoLongerEmbedsProseConstructors() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let introURL = root.appendingPathComponent(
            "RainShadow Shared/Gameplay/Navigation/EmptyCoatCaseIntroduction.swift"
        )
        let deskURL = root.appendingPathComponent(
            "RainShadow Shared/Gameplay/Navigation/OfficeCaseFileMonologue.swift"
        )
        let intro = try String(contentsOf: introURL, encoding: .utf8)
        let desk = try String(contentsOf: deskURL, encoding: .utf8)
        #expect(!intro.contains("CaseDialogueNode("))
        #expect(!intro.contains("CaseDialogueChoice("))
        #expect(intro.contains("DialogueGraphLoader.loadCached"))
        #expect(intro.contains("empty-coat.intro.dialogue"))
        #expect(!desk.contains("CaseDialogueNode("))
        #expect(desk.contains("DialogueGraphLoader.loadCached"))
        #expect(desk.contains("empty-coat.desk-monologue.dialogue"))
    }
}

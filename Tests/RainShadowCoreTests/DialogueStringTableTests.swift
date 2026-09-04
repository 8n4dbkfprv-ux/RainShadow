import Foundation
import Testing
@testable import RainShadowCore

struct DialogueStringTableTests {
    @Test func loadsShippedEnglishTable() throws {
        let table = try DialogueStringTable.load()
        #expect(table.locale == "en")
        #expect(table.count >= 60)
        #expect(try table.string(for: "dlg.speaker.harlan_voss") == "Harlan Voss")
        #expect(try table.string(for: "dlg.speaker.lila_march") == "Lila March")
    }

    @Test func missingKeyThrows() {
        let table = DialogueStringTable(strings: ["a": "A"])
        #expect(throws: DialogueStringTableError.missingKey("missing")) {
            try table.string(for: "missing")
        }
    }

    @Test func resolvePrefersKeyOverInline() throws {
        let table = DialogueStringTable(strings: ["k": "from-table"])
        #expect(try table.resolve(inline: "inline", key: "k", field: "t") == "from-table")
        #expect(try table.resolve(inline: "inline", key: nil, field: "t") == "inline")
    }

    @Test func resolveAuthoredNodeWithKeys() throws {
        let table = DialogueStringTable(strings: [
            "s.voss": "Harlan Voss",
            "n.body": "Rain on the glass.",
            "c.reply": "Tell me more."
        ])
        let authored = AuthoredDialogueDocument(
            id: "t",
            startNodeID: "n1",
            nodes: [
                AuthoredDialogueNode(
                    id: "n1",
                    speakerKey: "s.voss",
                    textKey: "n.body",
                    choices: [
                        AuthoredDialogueChoice(textKey: "c.reply", destinationID: "end")
                    ]
                ),
                AuthoredDialogueNode(
                    id: "end",
                    speakerKey: "s.voss",
                    textKey: "n.body",
                    endsDialogue: true
                )
            ]
        )
        let graph = try table.resolve(authored)
        #expect(graph.node(id: "n1")?.speaker == "Harlan Voss")
        #expect(graph.node(id: "n1")?.text == "Rain on the glass.")
        #expect(graph.node(id: "n1")?.choices.first?.text == "Tell me more.")
    }

    @Test func emptyCoatIntroResolvesFromStringTable() throws {
        let graph = try DialogueGraphLoader.load(
            id: EmptyCoatDialogueKeys.graphID,
            resourceName: EmptyCoatCaseIntroduction.resourceName
        )
        #expect(graph == EmptyCoatCaseIntroduction.graph)
        let start = try #require(graph.node(id: EmptyCoatCaseIntroduction.startNodeID))
        #expect(start.speaker == "Harlan Voss")
        #expect(start.text.lowercased().contains("rain"))
        #expect(start.isInteriorMonologue)

        // Spot-check a journal action resolved from textKey.
        let acceptance = graph.nodes
            .flatMap(\.choices)
            .first { choice in
                choice.onSelect.contains {
                    if case .queueJournal(let f) = $0 {
                        return f.id == EmptyCoatDialogueKeys.clientRetainedJournalID
                    }
                    return false
                }
            }
        #expect(acceptance != nil)
        if let action = acceptance?.onSelect.first(where: {
            if case .queueJournal(let f) = $0 {
                return f.id == EmptyCoatDialogueKeys.clientRetainedJournalID
            }
            return false
        }), case .queueJournal(let fragment) = action {
            #expect(fragment.text.contains("Empty Coat"))
        }
    }

    @Test func hotspotCatalogResolvesSpeakersAndObservations() throws {
        let byID = try OfficeHotspotDialogue.allGraphs()
        for item in OfficeNavigationLayout.authoredHotspots {
            let graph = try #require(byID[OfficeHotspotDialogue.graphID(forHotspotID: item.id)])
            let node = try #require(graph.node(id: graph.startNodeID))
            #expect(node.speaker == item.name)
            #expect(node.text == item.observation)
        }
    }

    @Test func authoredJSONUsesKeysNotInlineProse() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let introURL = root.appendingPathComponent(
            "RainShadow Shared/Resources/Dialogue/empty-coat.intro.dialogue.json"
        )
        let data = try Data(contentsOf: introURL)
        let authored = try DialogueGraphLoader.decodeAuthoredDocument(data)
        let sample = try #require(authored.nodes.first)
        #expect(sample.text == nil)
        #expect(sample.textKey != nil)
        #expect(sample.speaker == nil)
        #expect(sample.speakerKey != nil)
        // At least one choice uses textKey.
        let keyedChoice = authored.nodes.flatMap(\.choices).first { $0.textKey != nil }
        #expect(keyedChoice != nil)
        #expect(keyedChoice?.text == nil)
    }

    @Test func unsupportedStringTableSchemaThrows() throws {
        let json = """
        { "schemaVersion": 3, "locale": "en", "strings": {} }
        """
        #expect(throws: DialogueStringTableError.unsupportedSchemaVersion(found: 3, supported: 1)) {
            try DialogueStringTable.decode(Data(json.utf8))
        }
    }
}

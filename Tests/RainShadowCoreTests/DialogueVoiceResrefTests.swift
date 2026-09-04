import Foundation
import Testing
@testable import RainShadowCore

struct DialogueVoiceResrefTests {
    @Test func companionVoiceKeyFromTextKey() {
        #expect(
            DialogueVoiceResref.companionVoiceKey(
                forTextKey: "dlg.empty-coat.intro.node.voss.monologue.1.text"
            ) == "dlg.empty-coat.intro.node.voss.monologue.1.voice"
        )
        #expect(DialogueVoiceResref.companionVoiceKey(forTextKey: "dlg.speaker.harlan_voss") == nil)
    }

    @Test func playableFileNameNormalizesResrefAndFilename() {
        #expect(DialogueVoiceResref.playableFileName(from: "vo_voss_monologue_1") == "vo_voss_monologue_1.m4a")
        #expect(DialogueVoiceResref.playableFileName(from: "vo_voss_monologue_1.m4a") == "vo_voss_monologue_1.m4a")
        #expect(DialogueVoiceResref.playableFileName(from: "  vo_x  ") == "vo_x.m4a")
    }

    @Test func companionOfTextKeyFillsVoiceAssetName() throws {
        let table = DialogueStringTable(strings: [
            "line.text": "Hello.",
            "line.voice": "vo_hello"
        ])
        let authored = AuthoredDialogueDocument(
            id: "t",
            startNodeID: "n",
            nodes: [
                AuthoredDialogueNode(
                    id: "n",
                    speaker: "S",
                    textKey: "line.text",
                    endsDialogue: true
                )
            ]
        )
        let graph = try table.resolve(authored)
        #expect(graph.node(id: "n")?.voiceAssetName == "vo_hello.m4a")
        #expect(graph.node(id: "n")?.text == "Hello.")
    }

    @Test func explicitVoiceKeyWinsOverCompanion() throws {
        let table = DialogueStringTable(strings: [
            "line.text": "Hello.",
            "line.voice": "vo_companion",
            "other.voice": "vo_explicit"
        ])
        let authored = AuthoredDialogueDocument(
            id: "t",
            startNodeID: "n",
            nodes: [
                AuthoredDialogueNode(
                    id: "n",
                    speaker: "S",
                    textKey: "line.text",
                    endsDialogue: true,
                    voiceKey: "other.voice"
                )
            ]
        )
        let graph = try table.resolve(authored)
        #expect(graph.node(id: "n")?.voiceAssetName == "vo_explicit.m4a")
    }

    @Test func missingCompanionIsSilentUnlessLegacyInline() throws {
        let table = DialogueStringTable(strings: [
            "line.text": "Silent."
        ])
        let silent = AuthoredDialogueDocument(
            id: "t",
            startNodeID: "n",
            nodes: [
                AuthoredDialogueNode(id: "n", speaker: "S", textKey: "line.text", endsDialogue: true)
            ]
        )
        #expect(try table.resolve(silent).node(id: "n")?.voiceAssetName == nil)

        let legacy = AuthoredDialogueDocument(
            id: "t2",
            startNodeID: "n",
            nodes: [
                AuthoredDialogueNode(
                    id: "n",
                    speaker: "S",
                    text: "Legacy inline.",
                    endsDialogue: true,
                    voiceAssetName: "vo_legacy.m4a"
                )
            ]
        )
        #expect(try table.resolve(legacy).node(id: "n")?.voiceAssetName == "vo_legacy.m4a")
    }

    @Test func emptyCoatVoiceComesFromStringTableNotGraphJSON() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let introURL = root.appendingPathComponent(
            "RainShadow Shared/Resources/Dialogue/empty-coat.intro.dialogue.json"
        )
        let stringsURL = root.appendingPathComponent(
            "RainShadow Shared/Resources/Dialogue/strings.en.json"
        )
        let authored = try DialogueGraphLoader.decodeAuthoredDocument(try Data(contentsOf: introURL))
        #expect(authored.nodes.allSatisfy { $0.voiceAssetName == nil })
        #expect(authored.nodes.contains { $0.textKey != nil })

        let tableDoc = try JSONDecoder().decode(
            DialogueStringTableDocument.self,
            from: Data(contentsOf: stringsURL)
        )
        let voiceKeys = tableDoc.strings.keys.filter { $0.hasSuffix(".voice") }
        #expect(voiceKeys.count == 33)

        let graph = EmptyCoatCaseIntroduction.graph
        let monologue = graph.nodes.filter { $0.id.hasPrefix("voss.monologue") }
        #expect(monologue.count == 5)
        for node in monologue {
            #expect(node.voiceAssetName != nil)
            #expect(node.voiceAssetName?.hasSuffix(".m4a") == true)
        }
        #expect(
            graph.node(id: "voss.monologue.1")?.voiceAssetName
                == EmptyCoatCaseIntroduction.monologueOpenerVoiceAsset
        )
    }

    @Test func missingExplicitVoiceKeyThrows() {
        let table = DialogueStringTable(strings: ["line.text": "Hi"])
        #expect(throws: DialogueStringTableError.missingKey("missing.voice")) {
            try table.resolveVoiceAssetName(
                voiceKey: "missing.voice",
                textKey: "line.text",
                legacyVoiceAssetName: nil,
                nodeID: "n"
            )
        }
    }
}

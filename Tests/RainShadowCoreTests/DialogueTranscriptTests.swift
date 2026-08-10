import Foundation
import Testing
@testable import RainShadowCore

/// BG:EE keeps the conversation readable — text accumulates in a scrolling area and each
/// line is echoed to the message log. RainShadow's panel scrolled only the *current*
/// node, so every prior line and every reply the player chose was discarded. On a 35-node
/// monologue that is most of the writing.
struct DialogueTranscriptTests {
    private func graph() -> DialogueGraph {
        DialogueGraph(
            id: "g",
            startNodeID: "a",
            nodes: [
                CaseDialogueNode(
                    id: "a",
                    speaker: "Lila March",
                    text: "You're Voss.",
                    choices: [
                        CaseDialogueChoice(text: "That's the name on the door.", destinationID: "b")
                    ]
                ),
                CaseDialogueNode(
                    id: "b",
                    speaker: "Lila March",
                    text: "Then you'll do.",
                    endsDialogue: true
                )
            ]
        )
    }

    @Test func nodesAndRepliesAccumulateInOrder() {
        var session = DialogueSession(graph: graph())
        session.playerSpeaker = "Harlan Voss"
        session.noteCurrentNodeShown()
        _ = session.selectChoice(at: 0)
        session.noteCurrentNodeShown()

        #expect(session.transcript.entries.map(\.text) == [
            "You're Voss.",
            "That's the name on the door.",
            "Then you'll do."
        ])
        #expect(session.transcript.entries.map(\.kind) == [.speech, .playerReply, .speech])
    }

    /// The reply is the PC speaking (IE transition text), so it must not be filed under
    /// the NPC whose node it hung from.
    @Test func repliesAreAttributedToThePlayerCharacter() {
        var session = DialogueSession(graph: graph())
        session.playerSpeaker = "Harlan Voss"
        session.noteCurrentNodeShown()
        _ = session.selectChoice(at: 0)

        let reply = session.transcript.entries.last
        #expect(reply?.kind == .playerReply)
        #expect(reply?.speaker == "Harlan Voss")
    }

    /// The presenter re-shows the same node on every layout rebuild and on resume from a
    /// cutscene. Neither may duplicate a line in the scroll-back.
    @Test func reShowingTheSameNodeDoesNotDuplicateIt() {
        var session = DialogueSession(graph: graph())
        session.noteCurrentNodeShown()
        session.noteCurrentNodeShown()
        session.noteCurrentNodeShown()
        #expect(session.transcript.entries.count == 1)
    }

    @Test func currentAndPriorEntriesSplitAtTheLiveLine() {
        var session = DialogueSession(graph: graph())
        session.noteCurrentNodeShown()
        _ = session.selectChoice(at: 0)
        session.noteCurrentNodeShown()

        #expect(session.transcript.currentEntry?.text == "Then you'll do.")
        #expect(session.transcript.priorEntries.map(\.text) == [
            "You're Voss.",
            "That's the name on the door."
        ])
    }

    @Test func interiorMonologueIsClassifiedForItalics() {
        let node = CaseDialogueNode(
            id: "m",
            speaker: "Harlan Voss",
            text: "The rain had opinions.",
            isInteriorMonologue: true
        )
        var transcript = DialogueTranscript()
        transcript.appendNode(node)
        #expect(transcript.currentEntry?.kind == .monologue)
    }

    @Test func titleSpeakerIsClassifiedAsACard() {
        var session = DialogueSession(
            graph: DialogueGraph(
                id: "g",
                startNodeID: "t",
                nodes: [
                    CaseDialogueNode(id: "t", speaker: "Case opened", text: "The Empty Coat", endsDialogue: true)
                ]
            )
        )
        session.titleSpeaker = "Case opened"
        session.noteCurrentNodeShown()
        #expect(session.transcript.currentEntry?.kind == .title)
    }

    /// A long conversation must not grow the label stack without bound.
    @Test func theRingCapDropsTheOldestLines() {
        var transcript = DialogueTranscript(maximumEntries: 3)
        for index in 0..<6 {
            transcript.appendNode(
                CaseDialogueNode(id: "n\(index)", speaker: "S", text: "line \(index)")
            )
        }
        #expect(transcript.entries.count == 3)
        #expect(transcript.entries.map(\.text) == ["line 3", "line 4", "line 5"])
    }

    /// Presentation state only: it never reaches `CaseState`, so it can never be merged
    /// into a save or leak between conversations.
    @Test func aNewConversationStartsWithAnEmptyTranscript() {
        var first = DialogueSession(graph: graph())
        first.noteCurrentNodeShown()
        #expect(!first.transcript.isEmpty)

        let second = DialogueSession(graph: graph())
        #expect(second.transcript.isEmpty)
    }

    @Test func resetClearsEverything() {
        var transcript = DialogueTranscript()
        transcript.appendNode(CaseDialogueNode(id: "a", speaker: "S", text: "T"))
        transcript.reset()
        #expect(transcript.isEmpty)
        #expect(transcript.currentEntry == nil)
    }
}

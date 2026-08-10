import Foundation

/// What the player has already read in the current conversation.
///
/// Baldur's Gate keeps conversation text in a scrolling area and echoes each line to the
/// message log, so a long exchange can be read back and — crucially — the player can see
/// the reply they chose. RainShadow's panel scrolled only the *current* node's body:
/// every prior line, and every reply the player picked, was discarded the moment the
/// conversation moved on. On a 35-node monologue that is most of the writing.
///
/// The model is pure and lives in Core so it can be asserted without SpriteKit; the
/// presenter renders it. It resets per conversation (BG:EE clears the window when a new
/// dialogue starts) and is never persisted — mid-conversation save is out of scope, and
/// IE does not save mid-dialogue either.
struct DialogueTranscript: Equatable, Sendable {
    struct Entry: Equatable, Sendable {
        /// Drives typography and the speaker nameplate. Replaces comparing `speaker`
        /// against literal strings like `"Case opened"`, which coupled presentation to
        /// one case's prose and would break under localisation.
        enum Kind: Equatable, Sendable {
            /// An NPC (or hotspot) speaking aloud.
            case speech
            /// Voss's interior narration — rendered in italics.
            case monologue
            /// A reply the player committed to.
            case playerReply
            /// A card like "Case opened", set in the title face.
            case title
        }

        var nodeID: String
        var speaker: String
        var text: String
        var kind: Kind
    }

    /// Ring cap. A conversation long enough to hit this has already given the player far
    /// more scroll-back than BG:EE's message window ever showed.
    static let defaultMaximumEntries = 60

    private(set) var entries: [Entry] = []
    var maximumEntries: Int = DialogueTranscript.defaultMaximumEntries

    init(maximumEntries: Int = DialogueTranscript.defaultMaximumEntries) {
        self.maximumEntries = maximumEntries
    }

    /// The entry currently being spoken — the one the panel renders at full strength.
    var currentEntry: Entry? { entries.last }

    /// Everything already read, oldest first. The panel dims these.
    var priorEntries: ArraySlice<Entry> { entries.dropLast() }

    var isEmpty: Bool { entries.isEmpty }

    /// Append the node now on screen. Re-showing the same node — which happens on every
    /// layout rebuild and on resume from a cutscene — must not duplicate it.
    mutating func appendNode(_ node: CaseDialogueNode, isTitle: Bool = false) {
        let entry = Entry(
            nodeID: node.id,
            speaker: node.speaker,
            text: node.text,
            kind: isTitle ? .title : (node.isInteriorMonologue ? .monologue : .speech)
        )
        if let last = entries.last, last.nodeID == node.id, last.kind == entry.kind {
            entries[entries.count - 1] = entry
            return
        }
        append(entry)
    }

    /// Echo the reply the player committed to, attributed to the PC rather than to the
    /// NPC whose node it hung from — IE transition text *is* the PC speaking.
    mutating func appendPlayerReply(_ choice: CaseDialogueChoice, speaker: String, fromNodeID: String) {
        append(
            Entry(
                nodeID: fromNodeID,
                speaker: speaker,
                text: choice.text,
                kind: .playerReply
            )
        )
    }

    mutating func reset() {
        entries.removeAll(keepingCapacity: true)
    }

    private mutating func append(_ entry: Entry) {
        entries.append(entry)
        if maximumEntries > 0, entries.count > maximumEntries {
            entries.removeFirst(entries.count - maximumEntries)
        }
    }
}

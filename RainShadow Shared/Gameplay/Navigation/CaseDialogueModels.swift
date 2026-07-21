import Foundation

/// Authoring tone triad for major response beats.
/// Not shown in UI — players read the line; tone is for writers, branching, and tests.
enum DialogueTone: String, Equatable, CaseIterable, Sendable {
    case goodHeroic = "Good/Heroic"
    case neutralPragmatic = "Neutral/Pragmatic"
    case cynicalSarcasm = "Cynical/Sarcasm"
}

struct CaseDialogueChoice: Equatable, Sendable {
    let text: String
    let destinationID: String
    /// When set, this is one leg of a Good / Neutral / Cynical triad beat (metadata only).
    let tone: DialogueTone?

    init(text: String, destinationID: String, tone: DialogueTone? = nil) {
        self.text = text
        self.destinationID = destinationID
        self.tone = tone
    }
}

struct CaseDialogueNode: Equatable, Sendable {
    let id: String
    let speaker: String
    let text: String
    let portraitName: String?
    let choices: [CaseDialogueChoice]
    let nextNodeID: String?
    let endsDialogue: Bool
    /// First-person interior narration (detective monologue). Presenter renders body text in italics.
    let isInteriorMonologue: Bool

    init(
        id: String,
        speaker: String,
        text: String,
        portraitName: String? = nil,
        choices: [CaseDialogueChoice] = [],
        nextNodeID: String? = nil,
        endsDialogue: Bool = false,
        isInteriorMonologue: Bool = false
    ) {
        self.id = id
        self.speaker = speaker
        self.text = text
        self.portraitName = portraitName
        self.choices = choices
        self.nextNodeID = nextNodeID
        self.endsDialogue = endsDialogue
        self.isInteriorMonologue = isInteriorMonologue
    }
}

/// Pure graph helpers used by tests and any tool that validates authored dialogue.
enum CaseDialogueGraph {
    struct IntegrityReport: Equatable, Sendable {
        var missingDestinationIDs: [String]
        var orphanNodeIDs: [String]
        var reachableNodeIDs: Set<String>
        var reachesEnding: Bool
        var triadChoiceBeats: Int
        var totalBodyCharacters: Int

        var isSound: Bool {
            missingDestinationIDs.isEmpty && reachesEnding
        }
    }

    static func report(nodes: [CaseDialogueNode], startID: String) -> IntegrityReport {
        let byID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        var missing: [String] = []
        var reachable: Set<String> = []
        var triadBeats = 0
        var bodyChars = 0

        for node in nodes {
            bodyChars += node.text.count
            let tones = Set(node.choices.compactMap(\.tone))
            if tones == Set(DialogueTone.allCases) && node.choices.count >= 3 {
                triadBeats += 1
            }
            for choice in node.choices {
                if byID[choice.destinationID] == nil {
                    missing.append("\(node.id)->\(choice.destinationID)")
                }
            }
            if let next = node.nextNodeID, byID[next] == nil {
                missing.append("\(node.id)->next:\(next)")
            }
        }

        var queue = [startID]
        if byID[startID] != nil {
            reachable.insert(startID)
        }
        var head = 0
        while head < queue.count {
            let id = queue[head]
            head += 1
            guard let node = byID[id] else { continue }
            var outs: [String] = node.choices.map(\.destinationID)
            if let next = node.nextNodeID {
                outs.append(next)
            }
            for dest in outs where !reachable.contains(dest) {
                if byID[dest] != nil {
                    reachable.insert(dest)
                    queue.append(dest)
                }
            }
        }

        let orphans = nodes.map(\.id).filter { !reachable.contains($0) }
        let reachesEnding = nodes.contains { reachable.contains($0.id) && $0.endsDialogue }

        return IntegrityReport(
            missingDestinationIDs: missing.sorted(),
            orphanNodeIDs: orphans.sorted(),
            reachableNodeIDs: reachable,
            reachesEnding: reachesEnding,
            triadChoiceBeats: triadBeats,
            totalBodyCharacters: bodyChars
        )
    }
}

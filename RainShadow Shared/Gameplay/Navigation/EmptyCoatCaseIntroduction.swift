import Foundation

/// Shipped **Empty Coat** office case-intro graph: Voss noir monologue → Lila March triad dialogue.
///
/// Prose, topology, VO names, conditions, and actions live in the versioned resource
/// `Resources/Dialogue/empty-coat.intro.dialogue.json`. This type is the stable facade
/// (IDs, speaker constants, entrance helpers) and loads that package into a `DialogueGraph`.
///
/// Portrait asset filenames keep retired working-name IDs until a later art migration.
/// On-screen speaker strings are GDD canon: Harlan Voss / Lila March.
///
/// **Classic Baldur’s Gate / Infinity Engine roles (frozen — GDD §7.5):**
/// - NPC speech = node body; multi-page NPC beats may use `nextNodeID` / Continue.
/// - PC (Voss) speech during the conversation = `CaseDialogueChoice` text the player selects
///   (even a single option). Do **not** reintroduce mid-convo Voss speaker nodes with empty
///   choices + `nextNodeID` (former `voss.accept` anti-pattern).
/// - Exception: pre-Lila `voss.monologue.*` interior monologue may be Continue-only.
enum EmptyCoatCaseIntroduction {
    static let startNodeID = "voss.monologue.1"
    static let caseOpenedNodeID = "case.opened"
    /// First spoken Lila beat after the monologue chain.
    static let lilaConversationStartNodeID = "lila.entrance"

    /// Late monologue beat that narratively introduces arrival (hallway / heels).
    /// Baldur’s Gate style: the player reads this page fully, then Continue starts the
    /// door-fall / client entrance cinematic with **no** dialogue panel; dialogue
    /// resumes on the next monologue page after the walk.
    static let clientEntranceCueNodeID = "voss.monologue.4"

    /// Shipped Grok Voice openers (Voss monologue is Sal; Lila graph is Ara).
    static let monologueOpenerVoiceAsset = "vo_voss_monologue_1.m4a"
    static let lilaEntranceVoiceAsset = "vo_lila_entrance.m4a"

    /// Baseline of the short pre-rewrite graph (8 nodes). New content must exceed this floor.
    static let legacyNodeCountFloor = 8
    /// Baseline body-character total of the short pre-rewrite graph (~450). New prose must clear this.
    static let legacyBodyCharacterFloor = 450

    static let vossSpeaker = "Harlan Voss"
    static let lilaSpeaker = "Lila March"

    /// Conversation owner for talk counting (IE `NumTimesTalkedTo`). Distinct from the
    /// display name so a localized speaker string can never move the counter.
    static let lilaOwnerID = "npc.lila-march"
    static let caseOpenedSpeaker = "Case opened"

    /// Portrait masters still use retired pipeline names.
    static let vossPortrait = "dialogue_portrait_harlan_voss_v01"
    static let lilaPortrait = "dialogue_portrait_lila_march_v02"

    /// Resource base name (without `.json`) for the intro graph package.
    static let resourceName = "empty-coat.intro.dialogue"

    /// The exact node list the office scene presents. Tests must call this same source.
    static var nodes: [CaseDialogueNode] {
        graph.nodes
    }

    /// Phase 4 multi-graph package for the shared dialogue session/presenter.
    /// Loaded once from `Resources/Dialogue/empty-coat.intro.dialogue.json`.
    static var graph: DialogueGraph {
        loadedGraph
    }

    private static let loadedGraph: DialogueGraph = {
        do {
            let graph = try DialogueGraphLoader.loadCached(
                id: EmptyCoatDialogueKeys.graphID,
                resourceName: resourceName
            )
            assert(
                graph.startNodeID == startNodeID,
                "Empty Coat JSON start node mismatch: \(graph.startNodeID)"
            )
            return graph
        } catch {
            preconditionFailure("Failed to load Empty Coat intro dialogue: \(error)")
        }
    }()

    /// Entrance is **not** armed on show — the cue page must remain fully readable.
    /// Scene wiring uses `node.onLeaveCue` only; this helper remains for pure tests.
    static func shouldStartClientEntrance(whenShowing nodeID: String) -> Bool {
        false
    }

    /// Whether Continue *from* this node should start the entrance cinematic (BG cutscene).
    /// Fully data-driven: true only when the authored node carries
    /// `onLeaveCue == OfficeDialogueCues.clientEntrance`.
    static func shouldStartClientEntrance(whenLeaving nodeID: String) -> Bool {
        graph.node(id: nodeID)?.onLeaveCue == OfficeDialogueCues.clientEntrance
    }

    /// Voice-over resource for a node, read from the shipped graph (nil when silent).
    static func voiceAssetName(for nodeID: String) -> String? {
        graph.node(id: nodeID)?.voiceAssetName
    }

    /// Grok Voice bundle filename for a dialogue node id (`voss.monologue.1` → `vo_voss_monologue_1.m4a`).
    static func bundledVoiceFileName(for nodeID: String) -> String {
        "vo_\(nodeID.replacingOccurrences(of: ".", with: "_")).m4a"
    }
}

// MARK: - Shared presentation cue IDs

/// Scene-level presentation cues authored on dialogue nodes (`onLeaveCue` / `onShowCue`).
/// Not game-state `DialogueAction`s — scenes map these to cinematics / chrome.
enum OfficeDialogueCues {
    /// Door-fall + Lila walk-in cutscene (Empty Coat monologue leave).
    static let clientEntrance = "office.clientEntrance"
}

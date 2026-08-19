import Foundation

/// The shipped area scripts, authored as Swift values.
///
/// Follows the frozen `CutsceneCatalog` pattern rather than introducing a
/// bytecode VM or a script file format: RainShadow's cutscenes are authored cue
/// lists in Swift and the reasons hold here too — the conditions and actions are
/// already types, the compiler checks them, and there is no content pipeline to
/// feed. An area names its script by id in its record, and this resolves it.
///
/// **What is deliberately not here.** The plan for this phase said
/// `OfficeClientVisitSequencer` would become the office's script. It should not.
/// That type maps a *lifecycle event* — the case dialogue finished, Lila cleared
/// the room — onto an ordered list of actions. A Baldur's Gate area script is
/// polled: it asks questions about world state every tick and has no notion of
/// "something just happened". Converting the sequencer would mean inventing
/// variables whose only job is to represent an event that already has a
/// perfectly good representation, and the ordering contract its tests assert
/// would become an emergent property of a poll loop. It stays as it is.
///
/// What belongs here is what BG actually uses an area script for: noticing a
/// state of the world and reacting to it.
enum AreaScriptCatalog {
    /// Variable an area sets the first time the player is ever inside it.
    ///
    /// BG's single most common area-script idiom — a guard variable that turns a
    /// polled block into a one-shot — and the reason area variables had to exist
    /// before scripts could.
    static let seenVariable = "SEEN"

    /// The office notices the first time Voss is ever in it.
    ///
    /// Deliberately small. It is a real script rather than a demonstration: the
    /// block is guarded so it fires once across the life of a save, the variable
    /// it writes is area-scoped and persisted, and it is the shape every larger
    /// script is built from.
    static let officeSuite = AreaScript(
        id: "office_suite",
        blocks: [
            AreaScriptBlock(
                id: "office.firstEntry",
                when: .not(.variableIsSet(seenVariable)),
                do: [.setVariable(seenVariable, .integer(1))]
            )
        ]
    )

    private static let scriptsByID: [String: AreaScript] = [
        officeSuite.id: officeSuite
    ]

    static func script(id: String) -> AreaScript? {
        scriptsByID[id]
    }

    /// The script an area names, if it names one.
    static func script(for area: AreaDefinition) -> AreaScript? {
        area.script.flatMap(script(id:))
    }

    static var allScripts: [AreaScript] {
        scriptsByID.values.sorted { $0.id < $1.id }
    }
}

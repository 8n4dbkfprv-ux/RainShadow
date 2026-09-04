import Foundation

/// Why the world is frozen, and who may unfreeze it.
///
/// BG:EE has two independent freezes and they behave differently. A modal one —
/// dialogue, the map, the journal — is owned by the thing that opened it and ends
/// when it closes. The player's own pause (Space, or the clock in the corner) is
/// owned by the player and survives everything else, which is the whole point of
/// it: you pause *because* the situation is bad, issue orders into the frozen
/// world, and unpause when you are ready.
///
/// These were previously two ad-hoc boolean expressions, one per scene, and a
/// player pause had nowhere to live among them.
///
/// Note the one deliberate asymmetry, carried over from the office scene: a
/// cutscene is not a freeze. BG:EE's `CutSceneMode` locks player *input* while
/// scripted actors keep walking, which is what lets Lila's entrance play out.
struct WorldPauseController: Equatable, Sendable {
    struct Reasons: OptionSet, Sendable {
        let rawValue: Int

        /// Dialogue is on screen and is not part of a scripted cutscene.
        static let dialogue = Reasons(rawValue: 1 << 0)
        /// A full-screen overlay owns the view (map, world map, journal, inventory).
        static let overlay = Reasons(rawValue: 1 << 1)
        /// The player pressed Space or the clock.
        static let player = Reasons(rawValue: 1 << 2)

        /// Everything a scene closing its overlays should be able to clear
        /// without disturbing a pause the player asked for.
        static let modal: Reasons = [.dialogue, .overlay]
    }

    private(set) var reasons: Reasons = []

    var isPaused: Bool { !reasons.isEmpty }

    /// True only when the player is holding the freeze. Drives the greyscale and
    /// the clock button's pressed state — an inventory screen should not recolour
    /// the world behind it.
    var isPausedByPlayer: Bool { reasons.contains(.player) }

    // MARK: - Mutation

    mutating func set(_ reason: Reasons, _ active: Bool) {
        if active {
            reasons.insert(reason)
        } else {
            reasons.remove(reason)
        }
    }

    /// Recomputes the modal half from the scene's live state, leaving `.player`
    /// alone. Scenes call this once per frame so overlay bookkeeping cannot drift.
    mutating func setModal(dialogue: Bool, overlay: Bool) {
        set(.dialogue, dialogue)
        set(.overlay, overlay)
    }

    /// Returns the new paused state so callers can drive feedback from it.
    @discardableResult
    mutating func togglePlayerPause() -> Bool {
        set(.player, !isPausedByPlayer)
        return isPaused
    }

    mutating func clearPlayerPause() {
        set(.player, false)
    }
}

import Foundation

/// Display preferences. Deliberately *not* part of `SaveSnapshot`.
///
/// `GameBootstrap.reset()` starts a new game by rebuilding the whole
/// `GameContext` — a fresh set of GLOBALs, as the Infinity Engine does — so
/// anything living in the save goes with it. A video option is not case
/// progress and must survive that. BG:EE agrees: `Zoom Lock` lives in
/// `baldur.lua` beside the other graphics options, not in the `.gam`.
@MainActor
final class GamePreferences {
    /// Versioned separately from the save key so a save-schema bump cannot
    /// silently reset the player's display options.
    static let zoomLockKey = "RainShadow.Preferences.ZoomLock.v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// BG:EE's `Zoom Lock`. When on, the wheel and pinch **pan** the viewport
    /// instead of zooming — GemRB's own fallback, which it notes matters most
    /// for trackpads, where two-finger scroll arrives as a wheel event and
    /// would otherwise ride the zoom through its whole band on one flick.
    ///
    /// Defaults to off, matching the engine. There is no options screen yet.
    var zoomLockEnabled: Bool {
        get { defaults.bool(forKey: Self.zoomLockKey) }
        set { defaults.set(newValue, forKey: Self.zoomLockKey) }
    }
}

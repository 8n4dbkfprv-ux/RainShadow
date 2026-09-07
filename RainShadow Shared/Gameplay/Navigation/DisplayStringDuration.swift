import Foundation

/// Hold time for GemRB `DisplayString` (InfoPoint examine text).
///
/// `OverheadTextNode.play(for:)` treats the value as **total** duration,
/// including the fade in and out on each end. The hold in the middle is
/// `seconds - 2 * fadeDuration`. Keep `fadeDuration` identical to the node.
enum DisplayStringDuration {
    /// Must match `OverheadTextNode`'s fade. Shared so a SpriteKit-free test
    /// can pin the formula without importing the node.
    static let fadeDuration: TimeInterval = 0.28
    /// Short observations still linger long enough to read.
    static let minimumHold: TimeInterval = 2.4
    static let secondsPerCharacter: TimeInterval = 0.04

    /// Total seconds to pass to `OverheadTextNode.play(for:)`.
    static func seconds(for text: String) -> TimeInterval {
        let hold = max(minimumHold, secondsPerCharacter * Double(text.utf16.count))
        return hold + fadeDuration * 2
    }
}

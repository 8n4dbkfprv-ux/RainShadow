import Foundation

/// Pure helpers for dialogue voice resrefs (IE TLK sound field analogue).
///
/// String-table values store resrefs without path; playback needs a bundle filename.
enum DialogueVoiceResref {
    static let defaultExtension = "m4a"
    private static let knownExtensions: Set<String> = ["m4a", "mp3", "wav", "caf", "aiff"]

    /// `dlg….node.x.text` → `dlg….node.x.voice` (nil if text key does not end in `.text`).
    static func companionVoiceKey(forTextKey textKey: String) -> String? {
        guard textKey.hasSuffix(".text") else { return nil }
        return String(textKey.dropLast(".text".count)) + ".voice"
    }

    /// Normalize resref or legacy filename to a playable bundle name.
    /// - `vo_x` → `vo_x.m4a`
    /// - `vo_x.m4a` → `vo_x.m4a` (no double extension)
    static func playableFileName(from resrefOrFile: String) -> String {
        let trimmed = resrefOrFile.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        let ext = (trimmed as NSString).pathExtension.lowercased()
        if !ext.isEmpty, knownExtensions.contains(ext) {
            return trimmed
        }
        return "\(trimmed).\(defaultExtension)"
    }
}

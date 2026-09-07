import Foundation

/// InfoPoint examine strings for office hotspots.
///
/// This is GemRB `DisplayString(trap)` on an `ST_TRIGGER` with an empty Dialog
/// resref — the region's Information text, not a DLG and not a bark. First-look
/// prose matches `OfficeNavigationLayout.authoredHotspots[].observation`. A
/// second look is an inspect-count branch (GDD observation stages), not
/// `NumTimesTalkedTo`.
enum OfficeHotspotInspect {
    /// String-table key for a hotspot's first look (`dlg.inspect.office.desk…`).
    static func firstLookTextKey(forHotspotID hotspotID: String) -> String {
        "dlg.inspect.\(hotspotID).node.inspection.\(hotspotID).text"
    }

    /// String-table key for a later look, when one is authored.
    static func againTextKey(forHotspotID hotspotID: String) -> String {
        "dlg.inspect.\(hotspotID).node.inspection.\(hotspotID).again.text"
    }

    /// Resolve the InfoString for this click. `alreadyInspected` must be the
    /// membership of `inspectedHotspotIDs` **before** this click is marked.
    /// Desk's later look is gated on retain — an area script would `SetInfo`
    /// once the case is open, not `NumTimesTalkedTo`.
    static func text(
        forHotspotID hotspotID: String,
        alreadyInspected: Bool,
        caseState: CaseState = CaseState(caseID: "")
    ) -> String {
        if alreadyInspected, let again = againText(forHotspotID: hotspotID, caseState: caseState) {
            return again
        }
        return firstLookText(forHotspotID: hotspotID)
    }

    static func firstLookText(forHotspotID hotspotID: String) -> String {
        let key = firstLookTextKey(forHotspotID: hotspotID)
        if let resolved = DialogueStringTable.shipped.stringIfPresent(for: key) {
            return resolved
        }
        if let layout = OfficeNavigationLayout.authoredHotspots.first(where: { $0.id == hotspotID }) {
            return layout.observation
        }
        preconditionFailure("Missing office hotspot inspect text for '\(hotspotID)' (\(key))")
    }

    static func againText(
        forHotspotID hotspotID: String,
        caseState: CaseState = CaseState(caseID: "")
    ) -> String? {
        if hotspotID == "office.desk",
           !caseState.hasFlag(EmptyCoatDialogueKeys.clientRetained) {
            return nil
        }
        return DialogueStringTable.shipped.stringIfPresent(for: againTextKey(forHotspotID: hotspotID))
    }
}

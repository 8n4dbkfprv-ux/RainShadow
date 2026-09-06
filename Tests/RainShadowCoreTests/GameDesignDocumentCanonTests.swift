import Foundation
import Testing

/// Structural canon checks against the shipped GDD artifact on disk.
/// These tests read `Documentation/GameDesignDocument.md` — not a copy — so a
/// broken or reverted narrative outline fails CI the same way broken code does.
struct GameDesignDocumentCanonTests {
    private var gddText: String {
        get throws {
            let root = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            let url = root.appendingPathComponent("Documentation/GameDesignDocument.md")
            return try String(contentsOf: url, encoding: .utf8)
        }
    }

    @Test func gddExistsAndNamesCanonLeads() throws {
        let text = try gddText
        #expect(text.contains("Harlan Voss"))
        #expect(text.contains("Lila March"))
        #expect(text.contains("Harborpoint"))
        #expect(text.contains("The Empty Coat"))
    }

    @Test func gddUsesNewNamesAsCanonAndMarksOldNamesSuperseded() throws {
        let text = try gddText
        // Canonical lead headings / locks.
        #expect(text.contains("Harlan Voss — player protagonist"))
        #expect(text.contains("Lila March — the dame / first client"))
        #expect(text.contains("Canon leads: **Harlan Voss**"))
        #expect(text.contains("**Lila March**"))
        #expect(text.contains("The woman in the doorway had better ones about my time."))
        #expect(text.contains("Lillian still sews her own hems. She would not leave a coat that cost her a week."))
        #expect(!text.contains("The dame in the doorway had better ones about my time."))

        // Retired working names appear only as explicit superseded notes.
        #expect(text.contains("Superseded working name:** Elias Vale"))
        #expect(text.contains("Superseded working name:** Vivian Hart"))

        // M01 beat sheet must not still cast the old dame name as active.
        #expect(!text.contains("Vivian Hart enters"))
        #expect(text.contains("**Lila March** enters from the office door"))
    }

    @Test func gddWorldStoryCoversCorruptionWitNoirCombatAndPoirot() throws {
        let text = try gddText
        #expect(text.contains("## 4. World, characters, and story"))
        #expect(text.contains("corruption") || text.contains("Corruption"))
        #expect(text.contains("structurally corrupt") || text.contains("Corruption is structural")
            || text.contains("corruption is structural") || text.contains("Power structure (corruption is structural)"))
        #expect(text.contains("Wit") || text.contains("wit"))
        #expect(text.contains("Noir tropes") || text.contains("noir tropes"))
        #expect(text.contains("real-time with pause") || text.contains("Real-time with pause")
            || text.contains("RTWP"))
        #expect(text.contains("Baldur"))
        #expect(text.contains("Poirot"))
        #expect(text.contains("summation") || text.contains("Summation"))
        #expect(text.contains("no random") || text.contains("No random")
            || text.contains("random combat") || text.contains("loot grind"))
    }

    @Test func gddClosesLeadIdentityOpenDecision() throws {
        let text = try gddText
        #expect(text.contains("Closed by §4:") || text.contains("Closed by §4"))
        #expect(text.contains("Harlan Voss / Lila March"))
        #expect(text.contains("Lillian March"))
        // Must not still list "Final protagonist identity" as open.
        #expect(!text.contains("Final protagonist identity, history, and core wound."))
    }

    @Test func gddEmptyCoatCaseDossierAnchors() throws {
        let text = try gddText
        #expect(text.contains("case dossier") || text.contains("Case dossier") || text.contains("#### 4.3.2 First case"))
        #expect(text.contains("case.empty-coat") || text.contains("`case.empty-coat`"))
        #expect(text.contains("Wharf Ladder"))
        #expect(text.contains("brass key") || text.contains("Brass key") || text.contains("**brass key**"))
        #expect(text.contains("Gray Man") || text.contains("gray overcoat"))
        #expect(text.contains("H. VOSS") || text.contains("PRIVATE INVESTIGATIONS"))
        #expect(text.contains("Journal UX contract") || text.contains("journal UX contract")
            || text.contains("##### Journal UX contract"))
        #expect(text.contains("Blue Room"))
        #expect(text.contains("Lillian March"))
        #expect(text.contains("Empty Coat case dossier") || text.contains("EmptyCoatJournalContent")
            || text.contains("M01 journal"))
    }
}

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
        // Must not still list "Final protagonist identity" as open.
        #expect(!text.contains("Final protagonist identity, history, and core wound."))
    }
}

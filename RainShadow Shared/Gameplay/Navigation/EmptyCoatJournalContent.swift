import Foundation

/// One casebook page: index row + detail body for the M01 journal surface.
///
/// Copy is authored against GDD §4.3.2 (The Empty Coat case dossier) and the
/// shipped intro graph in `EmptyCoatCaseIntroduction`. Do not invent unearned
/// plot (e.g. Blue Room) until the design awards it.
public struct CaseJournalEntry: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let eyebrow: String
    public let status: String
    public let summary: String
    public let body: [String]
    public let leads: [String]
    public let isNew: Bool

    public init(
        id: String,
        title: String,
        eyebrow: String,
        status: String,
        summary: String,
        body: [String],
        leads: [String],
        isNew: Bool
    ) {
        self.id = id
        self.title = title
        self.eyebrow = eyebrow
        self.status = status
        self.summary = summary
        self.body = body
        self.leads = leads
        self.isNew = isNew
    }
}

/// Collapsible index group in the case journal.
public struct CaseJournalSection: Equatable, Sendable {
    public let id: String
    public let title: String
    public let entries: [CaseJournalEntry]

    public init(id: String, title: String, entries: [CaseJournalEntry]) {
        self.id = id
        self.title = title
        self.entries = entries
    }
}

/// Canonical M01 journal text for **The Empty Coat**.
///
/// `JournalOverlay` renders this; tests assert naming and core facts without SpriteKit.
public enum EmptyCoatJournalContent {
    public static let caseID = "case.empty-coat"
    public static let caseTitle = "The Empty Coat"
    public static let agencyLetterhead = "H. VOSS  •  PRIVATE INVESTIGATIONS"
    public static let pageMark = "FILE 01  /  THE EMPTY COAT"
    public static let defaultSelectedEntryID = caseID

    /// Office hotspots that can yield field notes (GDD §9.5 / §4.3.2 journal contract).
    public static let fieldNoteHotspotIDs: [(id: String, title: String, observation: String)] = [
        ("office.window", "Rain on the Window", "The rain had been working the glass harder than I had worked a case."),
        ("office.desk", "A Clean Page", "Three old cases, two unpaid bills, one clean page. This case gets the clean page."),
        ("office.phone", "Silent Telephone", "Quiet. For once it had the decency to look guilty."),
        ("office.files", "The Closed Files", "Closed, abandoned, and one I still lied about.")
    ]

    public static func caseSections(inspectedHotspotIDs: Set<String>) -> [CaseJournalSection] {
        var sections = [
            CaseJournalSection(id: "active", title: "ACTIVE CASES", entries: [activeCase]),
            CaseJournalSection(id: "people", title: "PEOPLE", entries: people),
            CaseJournalSection(id: "evidence", title: "EVIDENCE & LEADS", entries: evidence)
        ]
        let notes = fieldNotes(inspectedHotspotIDs: inspectedHotspotIDs)
        if !notes.isEmpty {
            sections.append(CaseJournalSection(id: "notes", title: "FIELD NOTES", entries: notes))
        }
        return sections
    }

    public static func chronologySections(inspectedHotspotIDs: Set<String>) -> [CaseJournalSection] {
        var entries = chronologyBase
        if !inspectedHotspotIDs.isEmpty {
            let count = inspectedHotspotIDs.count
            let plural = count == 1 ? "" : "s"
            entries.append(
                CaseJournalEntry(
                    id: "log.office",
                    title: "Office searched",
                    eyebrow: "Wednesday · 12:10 AM",
                    status: "Voss's office",
                    summary: "Voss checks the office and records \(count) field observation\(plural).",
                    body: [
                        "Routine is useful. It tells you when something is out of place."
                    ],
                    leads: ["Field notes added to the case file."],
                    isNew: true
                )
            )
        }
        return [CaseJournalSection(id: "log", title: "CASE LOG · CHAPTER ONE", entries: entries)]
    }

    // MARK: - Case files

    private static let activeCase = CaseJournalEntry(
        id: caseID,
        title: caseTitle,
        eyebrow: "Active case · opened Tuesday, 11:40 PM",
        status: "Open / Priority",
        summary: "Lillian March vanished Tuesday night. Her coat came back from the river. She did not.",
        body: [
            "Harborpoint PD called the coat an answer—missing adult, probable drowning, case cooling before the ink dried. Lila March called it a prop. Someone wanted the search to end at the waterline.",
            "A brass key was sewn into the coat lining. Since Lila recovered it, a man in a gray overcoat and black gloves has been following her. The key is on this desk until it opens something that can answer back."
        ],
        leads: [
            "Identify what the brass key opens.",
            "Trace Lillian's Tuesday: Wharf Ladder shipping office to the river stones.",
            "Find or name the man in the gray overcoat."
        ],
        isNew: false
    )

    private static let people: [CaseJournalEntry] = [
        CaseJournalEntry(
            id: "person.lila",
            title: "Lila March",
            eyebrow: "Person of interest · client",
            status: "Interviewed",
            summary: "Lillian's sister—and the only person still insisting this is not a drowning.",
            body: [
                "Arrived after midnight, frightened but precise. She recovered the key from the lining before the coat fully left her hands. She believes she is being watched, and she is right."
            ],
            leads: ["Keep her address off the police paperwork."],
            isNew: false
        ),
        CaseJournalEntry(
            id: "person.lillian",
            title: "Lillian March",
            eyebrow: "Missing person",
            status: "Whereabouts unknown",
            summary: "Worked late on shipping manifests near Wharf Ladder. Last reliably seen Tuesday evening. Hated the river.",
            body: [
                "Left the office about nine with talk of one more errand uptown—no cab from the desk phone. By midnight her coat was on the stones below the old iron stairs, empty and arranged. No witness has placed her near the water of her own free will."
            ],
            leads: ["Build a last-known-movements timeline from the shipping office outward."],
            isNew: true
        ),
        CaseJournalEntry(
            id: "person.gray-man",
            title: "The Gray Man",
            eyebrow: "Unknown suspect",
            status: "Unidentified",
            summary: "Gray overcoat, black gloves. Watches Lila from across the street.",
            body: [
                "He turns away when she looks directly at him. Streetcar noise, doorway posts—professional habits. He wants to know where she takes the key. Not yet proven badge or private muscle."
            ],
            leads: ["Check the street outside Lila's rooms when the city opens."],
            isNew: true
        )
    ]

    private static let evidence: [CaseJournalEntry] = [
        CaseJournalEntry(
            id: "evidence.key",
            title: "Brass Key",
            eyebrow: "Physical evidence · item 01",
            status: "In possession",
            summary: "Sewn into Lillian's coat lining—old teeth, no hotel tag, no landlord number. Still faintly machine oil and river fog.",
            body: [
                "The hiding place was deliberate. Not a pocket find a night watchman could lose twice. No maker's mark, room number, or address. It stays on this desk until the lock talks."
            ],
            leads: [
                "Compare against Lillian's known addresses and work locks.",
                "Ask a locksmith to read the cut when one can be trusted."
            ],
            isNew: true
        ),
        CaseJournalEntry(
            id: "evidence.coat",
            title: "Riverside Coat",
            eyebrow: "Physical evidence · police custody",
            status: "Not examined",
            summary: "Left on the river stones below the old iron stairs as a conclusion someone expected the police to accept.",
            body: [
                "Pockets turned like a stage direction. Lila found the key before the garment fully entered the official bag. Placement and missing body point to staging—not a tidy accident."
            ],
            leads: [
                "Inspect the riverside recovery site.",
                "Request the constable's property log."
            ],
            isNew: false
        )
    ]

    private static func fieldNotes(inspectedHotspotIDs: Set<String>) -> [CaseJournalEntry] {
        fieldNoteHotspotIDs.compactMap { hotspotID, title, observation in
            guard inspectedHotspotIDs.contains(hotspotID) else { return nil }
            return CaseJournalEntry(
                id: "note.\(hotspotID)",
                title: title,
                eyebrow: "Field note · detective's office",
                status: "Recorded",
                summary: observation,
                body: [
                    "A small observation, but small observations are what survive when everyone starts lying."
                ],
                leads: [],
                isNew: true
            )
        }
    }

    // MARK: - Chronology (narrative order: leave-work → coat → key → follower → case open)

    private static let chronologyBase: [CaseJournalEntry] = [
        CaseJournalEntry(
            id: "log.leave-work",
            title: "Lillian leaves work",
            eyebrow: "Tuesday · ~9:00 PM",
            status: "Wharf Ladder",
            summary: "Lillian March leaves the shipping office near Wharf Ladder after late ledger work.",
            body: [
                "Told a clerk she had one more errand uptown. No cab from the desk phone. That is the last clean mark on the page."
            ],
            leads: ["Gap opens between nine and the river."],
            isNew: false
        ),
        CaseJournalEntry(
            id: "log.coat",
            title: "Coat recovered",
            eyebrow: "Tuesday · ~midnight",
            status: "Riverside",
            summary: "River watch finds Lillian's coat on the stones below the old iron stairs. No body.",
            body: [
                "The search begins and ends at the same convenient conclusion: probable drowning, case cooling."
            ],
            leads: ["The coat enters police custody."],
            isNew: false
        ),
        CaseJournalEntry(
            id: "log.key",
            title: "Key discovered",
            eyebrow: "Tuesday night · after recovery",
            status: "March custody",
            summary: "Lila finds a brass key sewn into the coat lining before the garment fully leaves her hands.",
            body: [
                "Someone hid the key where a hurried search would miss it and a sister would not."
            ],
            leads: ["Lila keeps the key out of the official property log."],
            isNew: false
        ),
        CaseJournalEntry(
            id: "log.followed",
            title: "Lila followed",
            eyebrow: "Tuesday night",
            status: "Lower city",
            summary: "A man in a gray overcoat and black gloves follows Lila after she recovers the key.",
            body: [
                "No conversation. Professional habits. He wants the key's destination, not a social call."
            ],
            leads: ["The follower now knows about Voss's office."],
            isNew: true
        ),
        CaseJournalEntry(
            id: "log.case-open",
            title: "Case opened",
            eyebrow: "Tuesday · 11:40 PM",
            status: "Voss's office",
            summary: "Harlan Voss accepts the March disappearance and takes possession of the brass key.",
            body: [
                "Working title: The Empty Coat. Harborpoint likes endings that fit in a paper bag. This one will not."
            ],
            leads: ["First objective: identify the lock."],
            isNew: true
        )
    ]
}

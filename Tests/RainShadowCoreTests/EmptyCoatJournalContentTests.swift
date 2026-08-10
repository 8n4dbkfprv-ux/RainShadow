import Foundation
import Testing
@testable import RainShadowCore

/// Canon checks for M01 journal case copy (GDD §4.3.2 dossier surface).
struct EmptyCoatJournalContentTests {
    private var caseSections: [CaseJournalSection] {
        EmptyCoatJournalContent.caseSections(inspectedHotspotIDs: [])
    }

    private var chronology: [CaseJournalEntry] {
        EmptyCoatJournalContent.chronologySections(inspectedHotspotIDs: []).flatMap(\.entries)
    }

    private var allCaseText: String {
        let entries = caseSections.flatMap(\.entries)
        return entries.map { entry in
            ([entry.title, entry.eyebrow, entry.status, entry.summary] + entry.body + entry.leads)
                .joined(separator: " ")
        }.joined(separator: "\n")
    }

    @Test func letterheadAndCaseIdentity() {
        #expect(EmptyCoatJournalContent.agencyLetterhead.contains("H. VOSS"))
        #expect(!EmptyCoatJournalContent.agencyLetterhead.contains("VALE"))
        #expect(EmptyCoatJournalContent.caseTitle == "The Empty Coat")
        #expect(EmptyCoatJournalContent.caseID == "case.empty-coat")
        #expect(EmptyCoatJournalContent.pageMark.contains("THE EMPTY COAT"))
    }

    @Test func activeCaseUsesLillianMarchAndCoreFacts() {
        let active = caseSections
            .first { $0.id == "active" }?
            .entries
            .first { $0.id == EmptyCoatJournalContent.caseID }
        #expect(active != nil)
        #expect(active?.title == "The Empty Coat")
        let blob = allCaseText
        #expect(blob.contains("Lillian March"))
        #expect(blob.contains("Lila March"))
        #expect(blob.contains("brass key") || blob.contains("Brass key") || blob.contains("Brass Key"))
        #expect(blob.contains("gray overcoat") || blob.contains("Gray Man"))
        #expect(blob.contains("Wharf Ladder") || blob.contains("shipping"))
        #expect(blob.contains("river") || blob.contains("Riverside"))
        #expect(!blob.contains("Lillian Hart"))
        #expect(!blob.contains("E. VALE"))
        #expect(!blob.contains("Blue Room"))
    }

    @Test func peopleAndEvidenceSectionsMatchDossierIDs() {
        let peopleIDs = Set(caseSections.first { $0.id == "people" }?.entries.map(\.id) ?? [])
        #expect(peopleIDs == Set(["person.lila", "person.lillian", "person.gray-man"]))

        let evidenceIDs = Set(caseSections.first { $0.id == "evidence" }?.entries.map(\.id) ?? [])
        #expect(evidenceIDs == Set(["evidence.key", "evidence.coat"]))
        #expect(!evidenceIDs.contains("evidence.matches"))
    }

    @Test func chronologyNarrativeOrderAndCaseOpen() {
        let ids = chronology.map(\.id)
        #expect(ids.contains("log.leave-work"))
        #expect(ids.contains("log.coat"))
        #expect(ids.contains("log.key"))
        #expect(ids.contains("log.followed"))
        #expect(ids.contains("log.case-open"))
        #expect(!ids.contains("log.office"))

        let leave = ids.firstIndex(of: "log.leave-work")!
        let coat = ids.firstIndex(of: "log.coat")!
        let key = ids.firstIndex(of: "log.key")!
        let followed = ids.firstIndex(of: "log.followed")!
        let opened = ids.firstIndex(of: "log.case-open")!
        #expect(leave < coat)
        #expect(coat < key)
        #expect(key < followed)
        #expect(followed < opened)

        let openEntry = chronology.first { $0.id == "log.case-open" }
        #expect(openEntry?.summary.contains("Harlan Voss") == true)
        #expect(openEntry?.body.joined().contains("Empty Coat") == true)
    }

    @Test func fieldNotesGateOnHotspotsAndOfficeLogAppears() {
        let emptyNotes = EmptyCoatJournalContent.caseSections(inspectedHotspotIDs: [])
            .first { $0.id == "notes" }
        #expect(emptyNotes == nil)

        let withWindow = EmptyCoatJournalContent.caseSections(inspectedHotspotIDs: ["office.window"])
        let notes = withWindow.first { $0.id == "notes" }?.entries ?? []
        #expect(notes.count == 1)
        #expect(notes[0].id == "note.office.window")
        #expect(notes[0].summary.contains("rain") || notes[0].summary.contains("Rain"))

        let chrono = EmptyCoatJournalContent.chronologySections(inspectedHotspotIDs: ["office.window", "office.desk"])
            .flatMap(\.entries)
        #expect(chrono.contains { $0.id == "log.office" })
        let office = chrono.first { $0.id == "log.office" }
        #expect(office?.summary.contains("2 field observation") == true)
    }

    @Test func dialogueFragmentsProjectIntoChronologyAfterCaseOpen() {
        let bare = EmptyCoatJournalContent.chronologySections(input: JournalProjectionInput())
            .flatMap(\.entries)
        #expect(!bare.contains { $0.id == "log.client-retained" })
        #expect(!bare.contains { $0.id == "log.pressed-hard" })

        let retainedOnly = EmptyCoatJournalContent.chronologySections(
            input: JournalProjectionInput(
                queuedJournalFragments: [
                    QueuedJournalFragment(
                        id: EmptyCoatDialogueKeys.clientRetainedJournalID,
                        kind: .chronology,
                        text: "Retained by Lila March. The Empty Coat is open."
                    )
                ]
            )
        ).flatMap(\.entries)
        #expect(retainedOnly.contains { $0.id == "log.client-retained" })
        #expect(!retainedOnly.contains { $0.id == "log.pressed-hard" })
        let retainedIndex = retainedOnly.firstIndex { $0.id == "log.client-retained" }!
        let caseOpenIndex = retainedOnly.firstIndex { $0.id == "log.case-open" }!
        #expect(caseOpenIndex < retainedIndex)

        let pressPath = EmptyCoatJournalContent.chronologySections(
            input: JournalProjectionInput(
                queuedJournalFragments: [
                    QueuedJournalFragment(
                        id: EmptyCoatDialogueKeys.pressedHardJournalID,
                        kind: .chronology,
                        text: "Pushed Lila on what the police finished too early."
                    ),
                    QueuedJournalFragment(
                        id: EmptyCoatDialogueKeys.clientRetainedJournalID,
                        kind: .chronology,
                        text: "Retained by Lila March. The Empty Coat is open."
                    )
                ]
            )
        ).flatMap(\.entries)
        #expect(pressPath.contains { $0.id == "log.pressed-hard" })
        #expect(pressPath.contains { $0.id == "log.client-retained" })
        #expect(pressPath.count == retainedOnly.count + 1)
    }

    @Test func dialoguePathsYieldDifferentActiveCaseLeads() {
        let noDialogue = EmptyCoatJournalContent.caseSections(input: JournalProjectionInput())
            .first { $0.id == "active" }?
            .entries.first { $0.id == EmptyCoatJournalContent.caseID }
        #expect(noDialogue?.leads.contains(where: { $0.contains("Client retained") }) != true)

        let retained = EmptyCoatJournalContent.caseSections(
            input: JournalProjectionInput(
                queuedJournalFragments: [
                    QueuedJournalFragment(
                        id: EmptyCoatDialogueKeys.clientRetainedJournalID,
                        kind: .chronology,
                        text: "Retained."
                    )
                ],
                caseFlags: [EmptyCoatDialogueKeys.clientRetained]
            )
        ).first { $0.id == "active" }?.entries.first { $0.id == EmptyCoatJournalContent.caseID }
        #expect(retained?.leads.contains(where: { $0.contains("Client retained") }) == true)
        #expect(retained?.leads.contains(where: { $0.localizedCaseInsensitiveContains("manifest") }) != true)

        let pressed = EmptyCoatJournalContent.caseSections(
            input: JournalProjectionInput(
                queuedJournalFragments: [
                    QueuedJournalFragment(
                        id: EmptyCoatDialogueKeys.pressedHardJournalID,
                        kind: .chronology,
                        text: "Pushed."
                    ),
                    QueuedJournalFragment(
                        id: EmptyCoatDialogueKeys.clientRetainedJournalID,
                        kind: .chronology,
                        text: "Retained."
                    )
                ],
                caseFlags: [EmptyCoatDialogueKeys.clientRetained]
            )
        ).first { $0.id == "active" }?.entries.first { $0.id == EmptyCoatJournalContent.caseID }
        #expect(pressed?.leads.contains(where: { $0.localizedCaseInsensitiveContains("manifest") }) == true)
    }

    @Test func dialogueThenOfficeSearchKeepsOfficeLogLast() {
        let entries = EmptyCoatJournalContent.chronologySections(
            input: JournalProjectionInput(
                inspectedHotspotIDs: ["office.window"],
                queuedJournalFragments: [
                    QueuedJournalFragment(
                        id: EmptyCoatDialogueKeys.clientRetainedJournalID,
                        kind: .chronology,
                        text: "Retained."
                    )
                ]
            )
        ).flatMap(\.entries)
        let retained = entries.firstIndex { $0.id == "log.client-retained" }!
        let office = entries.firstIndex { $0.id == "log.office" }!
        #expect(retained < office)
    }

    @Test func journalOverlaySourceDoesNotHardcodeRetiredLetterhead() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let overlay = root
            .appendingPathComponent("RainShadow Shared/UI/JournalOverlay.swift")
        let source = try String(contentsOf: overlay, encoding: .utf8)
        #expect(source.contains("EmptyCoatJournalContent"))
        #expect(source.contains("agencyLetterhead"))
        #expect(!source.contains("E. VALE"))
        #expect(!source.contains("Lillian Hart"))
        #expect(!source.contains("Blue Room"))
    }
}

import Foundation
import Testing
@testable import RainShadowCore

struct OfficeHotspotInspectTests {
    private var authoredHotspotIDs: [String] {
        OfficeNavigationLayout.authoredHotspots.map(\.id)
    }

    @Test func firstLookMatchesLayoutObservations() {
        for item in OfficeNavigationLayout.authoredHotspots {
            let text = OfficeHotspotInspect.text(
                forHotspotID: item.id,
                alreadyInspected: false
            )
            #expect(text == item.observation)
            #expect(
                OfficeHotspotInspect.firstLookText(forHotspotID: item.id) == item.observation
            )
        }
    }

    @Test func firstLookKeysResolveThroughTheStringTable() throws {
        let table = DialogueStringTable.shipped
        for item in OfficeNavigationLayout.authoredHotspots {
            let key = OfficeHotspotInspect.firstLookTextKey(forHotspotID: item.id)
            #expect(try table.string(for: key) == item.observation)
        }
    }

    @Test func aSecondLookAtTheWindowIsTheAuthoredAgainLine() throws {
        let first = OfficeHotspotInspect.text(
            forHotspotID: "office.window",
            alreadyInspected: false
        )
        let again = OfficeHotspotInspect.text(
            forHotspotID: "office.window",
            alreadyInspected: true
        )
        #expect(first == "The rain had been working the glass longer than I had. The sill-ward didn't care either way.")
        #expect(again == "Same rain, same glass. Now I had a client — and a key that hummed when the weather turned.")
        #expect(again != first)
        #expect(
            try DialogueStringTable.shipped.string(
                for: OfficeHotspotInspect.againTextKey(forHotspotID: "office.window")
            ) == again
        )
    }

    @Test func hotspotsWithoutAnAgainLineKeepTheFirstLook() {
        for hotspotID in authoredHotspotIDs
        where hotspotID != "office.window" && hotspotID != "office.desk" {
            let first = OfficeHotspotInspect.text(
                forHotspotID: hotspotID,
                alreadyInspected: false
            )
            let again = OfficeHotspotInspect.text(
                forHotspotID: hotspotID,
                alreadyInspected: true
            )
            #expect(first == again)
            #expect(OfficeHotspotInspect.againText(forHotspotID: hotspotID) == nil)
        }
    }

    @Test func aSecondLookAtTheDeskAfterRetainShowsTheKey() {
        var retained = CaseState(caseID: EmptyCoatJournalContent.caseID)
        retained.setFlag(EmptyCoatDialogueKeys.clientRetained)
        let first = OfficeHotspotInspect.text(
            forHotspotID: "office.desk",
            alreadyInspected: false,
            caseState: retained
        )
        let again = OfficeHotspotInspect.text(
            forHotspotID: "office.desk",
            alreadyInspected: true,
            caseState: retained
        )
        #expect(first == "Three cold cases, two debts the ledger still remembers, one page that hasn't learned a name yet.")
        #expect(again == "The key sits on the desk leather. Brass. Small teeth. No inn tag. Lamp oil, river water, and a quiet that isn't empty.")
    }

    @Test func aSecondLookAtTheDeskBeforeRetainKeepsTheFirstLook() {
        let unretained = CaseState(caseID: EmptyCoatJournalContent.caseID)
        let first = OfficeHotspotInspect.text(
            forHotspotID: "office.desk",
            alreadyInspected: false,
            caseState: unretained
        )
        let again = OfficeHotspotInspect.text(
            forHotspotID: "office.desk",
            alreadyInspected: true,
            caseState: unretained
        )
        #expect(first == again)
        #expect(OfficeHotspotInspect.againText(forHotspotID: "office.desk", caseState: unretained) == nil)
    }

    @Test func secondLookDoesNotUseATalkCounter() {
        let state = CaseState(caseID: EmptyCoatJournalContent.caseID)
        #expect(state.timesTalkedTo("office.window") == 0)
        let again = OfficeHotspotInspect.text(
            forHotspotID: "office.window",
            alreadyInspected: true
        )
        #expect(again == "Same rain, same glass. Now I had a client — and a key that hummed when the weather turned.")
        #expect(state.timesTalkedTo("office.window") == 0)
        #expect(state.counters[CaseState.talkCounterID("office.window")] == nil)
    }

    @Test func officeScenePresentsDisplayStringNotADialogueGraph() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sceneURL = root.appendingPathComponent(
            "RainShadow Shared/Scenes/DetectiveOffice/DetectiveOfficeScene.swift"
        )
        let source = try String(contentsOf: sceneURL, encoding: .utf8)
        #expect(source.contains("OfficeHotspotInspect.text("))
        #expect(source.contains("presentDisplayString("))
        #expect(!source.contains("OfficeHotspotDialogue"))
        if let range = source.range(of: "private func presentInspection") {
            let after = source[range.lowerBound...]
            if let next = after.range(
                of: "\n    private func ",
                options: [],
                range: after.index(after: range.upperBound)..<after.endIndex
            ) {
                let body = String(after[..<next.lowerBound])
                #expect(body.contains("OfficeHotspotInspect.text"))
                #expect(body.contains("presentDisplayString("))
                #expect(body.contains("alreadyInspected"))
                #expect(body.contains("caseState"))
                #expect(!body.contains("OfficeHotspotDialogue"))
                #expect(!body.contains("CaseDialogueNode("))
                #expect(!body.contains("hotspot.observation"))
                #expect(!body.contains("presentDialogue("))
                #expect(!body.contains("OfficeCaseFileMonologue"))
                #expect(!body.contains("dialogueIsActive"))
            }
        }
    }

    @Test func cityInspectUsesDisplayStringNotAHUDBanner() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sceneURL = root.appendingPathComponent(
            "RainShadow Shared/Scenes/CityDistrict/CityDistrictScene.swift"
        )
        let source = try String(contentsOf: sceneURL, encoding: .utf8)
        #expect(source.contains("presentDisplayString("))
        #expect(!source.contains("showInspectLine"))
        #expect(source.contains("showOverlayStatusLine"))
    }
}

struct DisplayStringDurationTests {
    @Test func shortLinesStillHoldTheFloor() {
        let seconds = DisplayStringDuration.seconds(for: "Quiet.")
        #expect(
            seconds == DisplayStringDuration.minimumHold + DisplayStringDuration.fadeDuration * 2
        )
    }

    @Test func longerLinesScaleWithCharacterCount() {
        let text = String(repeating: "a", count: 100)
        let seconds = DisplayStringDuration.seconds(for: text)
        #expect(
            seconds
                == DisplayStringDuration.secondsPerCharacter * 100
                + DisplayStringDuration.fadeDuration * 2
        )
    }

    @Test func overheadTextNodeFadesOnTheSameDuration() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root.appendingPathComponent(
            "RainShadow Shared/Core/Scene/CutsceneChromeNodes.swift"
        )
        let source = try String(contentsOf: url, encoding: .utf8)
        #expect(source.contains("let fade = DisplayStringDuration.fadeDuration"))
    }
}

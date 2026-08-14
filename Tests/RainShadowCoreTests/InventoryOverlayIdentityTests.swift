import Foundation
import Testing

struct InventoryOverlayIdentityTests {
    @Test func acquiredOccurrencesUseUniquePresentationKeysWithoutReplacingAuthoredIDs() throws {
        let source = try String(
            contentsOf: repositoryRoot()
                .appendingPathComponent("RainShadow Shared/UI/InventoryOverlay.swift"),
            encoding: .utf8
        )

        #expect(source.contains("let authoredID: String"))
        #expect(source.contains("carriedItems.enumerated().map"))
        #expect(source.contains("\"acquired.\\(carriedIndex).\\(authoredID)\""))
        #expect(source.contains("authoredID: stack.id"))
        #expect(source.contains("presentationID: Self.acquiredPresentationID("))
        #expect(source.contains("slotFramesByPresentationID[item.id, default: []].append(slot)"))
        #expect(source.contains("let selected = presentationID == selectedPresentationID"))

        for starterID in [
            "service-revolver",
            "case-notes",
            "brass-key",
            "flashlight",
            "wallet",
            "cigarette-case"
        ] {
            #expect(source.contains(
                "id: \"\(starterID)\",\n                authoredID: \"\(starterID)\""
            ))
        }
    }

    @Test func acquiredServiceRevolverIsPresentedAsCarriedButNotEquipped() throws {
        let source = try String(
            contentsOf: repositoryRoot()
                .appendingPathComponent("RainShadow Shared/UI/InventoryOverlay.swift"),
            encoding: .utf8
        )
        let acquiredFunction = try #require(source.range(of: "static func acquiredItem(\n        authoredID:"))
        let firearmStart = try #require(source.range(
            of: "case \"service-revolver\":",
            range: acquiredFunction.upperBound..<source.endIndex
        ))
        let nextCase = try #require(source.range(
            of: "case \"matchbook\":",
            range: firearmStart.upperBound..<source.endIndex
        ))
        let firearmPresentation = source[firearmStart.lowerBound..<nextCase.lowerBound]

        #expect(firearmPresentation.contains("category: .weapon"))
        #expect(firearmPresentation.contains("artName: \"inventory_item_service_revolver_v01\""))
        #expect(firearmPresentation.contains("carried in the case bag"))
        #expect(firearmPresentation.contains("Carried item · not equipped"))
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

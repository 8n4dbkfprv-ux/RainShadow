import Foundation
import Testing
@testable import RainShadowCore

/// The shipped area scripts.
struct AreaScriptCatalogTests {

    @Test func theOfficeNamesAScriptThatResolves() throws {
        let office = try AreaCatalogLoader.load(HarborpointAreas.office)
        let name = try #require(office.script, "the office names no script")
        #expect(AreaScriptCatalog.script(id: name) != nil, "'\(name)' resolves to nothing")
        #expect(AreaScriptCatalog.script(for: office)?.id == name)
    }

    /// A record naming a script the catalog does not have would be an
    /// area that silently does nothing.
    @Test func everyShippedAreaScriptNameResolves() throws {
        for area in try AreaCatalogLoader.load(HarborpointAreas.shippedIDs).allAreas {
            guard let name = area.script else { continue }
            #expect(
                AreaScriptCatalog.script(id: name) != nil,
                "'\(area.id)' names script '\(name)', which the catalog does not have"
            )
        }
    }

    @Test func scriptIDsAreUnique() {
        let ids = AreaScriptCatalog.allScripts.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    /// The office's block is a one-shot guarded on its own variable — BG's most
    /// common area-script idiom, and the reason variables had to exist first.
    @Test func theOfficeFirstEntryBlockFiresOnceAndThenStops() {
        let script = AreaScriptCatalog.officeSuite
        var context = AreaScriptContext(
            area: HarborpointAreas.office,
            variables: AreaVariables(),
            dialogue: DialogueRuntimeContext(
                caseState: CaseState(caseID: "test"),
                dialogueState: DialogueState(graphID: "test")
            )
        )

        let first = AreaScriptRunner.tick(script, in: context)
        #expect(first.blockID == "office.firstEntry")
        #expect(
            first.variables.isSet(AreaScriptCatalog.seenVariable, in: HarborpointAreas.office)
        )

        context.variables = first.variables
        #expect(
            !AreaScriptRunner.tick(script, in: context).didFire,
            "the guard did not hold; the block fired twice"
        )
    }

    /// The guard is area-scoped, so entering a different area does not consume
    /// the office's one-shot.
    @Test func anotherAreasSeenFlagDoesNotSatisfyTheOfficeGuard() {
        var variables = AreaVariables()
        variables.setFlag(true, AreaScriptCatalog.seenVariable, in: HarborpointAreas.sableRow)
        let context = AreaScriptContext(
            area: HarborpointAreas.office,
            variables: variables,
            dialogue: DialogueRuntimeContext(
                caseState: CaseState(caseID: "test"),
                dialogueState: DialogueState(graphID: "test")
            )
        )
        #expect(AreaScriptRunner.tick(AreaScriptCatalog.officeSuite, in: context).didFire)
    }
}

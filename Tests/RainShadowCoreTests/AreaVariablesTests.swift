import Foundation
import Testing
@testable import RainShadowCore

/// Area-scoped variables — what makes an area persist rather than be rebuilt.
struct AreaVariablesTests {

    @Test func aVariableIsScopedToItsArea() {
        var vars = AreaVariables()
        vars.setInteger(1, "SEEN", in: HarborpointAreas.office)
        #expect(vars.integer("SEEN", in: HarborpointAreas.office) == 1)
        // The same name in another area is a different variable. This is the
        // whole point of the namespace.
        #expect(vars.integer("SEEN", in: HarborpointAreas.sableRow) == 0)
        #expect(vars.integer("SEEN", in: AreaVariables.globalScope) == 0)
    }

    /// BG's `Global("x","AREA")` reads zero for a name never assigned, so an
    /// unset variable and one set to nothing must be indistinguishable.
    @Test func anUnsetVariableReadsAsZeroAndUnflagged() {
        let vars = AreaVariables()
        #expect(vars.integer("nope", in: HarborpointAreas.office) == 0)
        #expect(!vars.isSet("nope", in: HarborpointAreas.office))
        #expect(vars.text("nope", in: HarborpointAreas.office) == nil)
        #expect(vars.value("nope", in: HarborpointAreas.office) == nil)
        #expect(vars.isEmpty)
    }

    @Test func settingNilRemovesRatherThanStoringAnEmptyValue() {
        var vars = AreaVariables()
        vars.setFlag(true, "OPEN", in: HarborpointAreas.office)
        #expect(vars.isSet("OPEN", in: HarborpointAreas.office))
        vars.set(nil, "OPEN", in: HarborpointAreas.office)
        #expect(vars.value("OPEN", in: HarborpointAreas.office) == nil)
        #expect(vars.isEmpty)
    }

    /// BG has no boolean type — a flag is an int that is zero or not.
    @Test func aFlagIsAnIntegerLikeTheEngineStoresIt() {
        var vars = AreaVariables()
        vars.setFlag(true, "DONE", in: HarborpointAreas.office)
        #expect(vars.value("DONE", in: HarborpointAreas.office) == .integer(1))
        vars.setFlag(false, "DONE", in: HarborpointAreas.office)
        #expect(vars.value("DONE", in: HarborpointAreas.office) == .integer(0))
        #expect(!vars.isSet("DONE", in: HarborpointAreas.office))
    }

    @Test func incrementReturnsTheNewValue() {
        var vars = AreaVariables()
        #expect(vars.increment("VISITS", in: HarborpointAreas.sableRow) == 1)
        #expect(vars.increment("VISITS", in: HarborpointAreas.sableRow) == 2)
        #expect(vars.increment("VISITS", in: HarborpointAreas.sableRow, by: 5) == 7)
        #expect(vars.integer("VISITS", in: HarborpointAreas.sableRow) == 7)
    }

    @Test func textAndNumberValuesRoundTrip() {
        var vars = AreaVariables()
        vars.set(.text("lila"), "CALLER", in: HarborpointAreas.office)
        vars.set(.number(2.5), "RENT", in: HarborpointAreas.office)
        #expect(vars.text("CALLER", in: HarborpointAreas.office) == "lila")
        #expect(vars.integer("RENT", in: HarborpointAreas.office) == 2)
        #expect(vars.text("RENT", in: HarborpointAreas.office) == nil)
    }

    // MARK: - Persistence shape

    @Test func flatteningIsReversible() {
        var vars = AreaVariables()
        vars.setInteger(3, "VISITS", in: HarborpointAreas.office)
        vars.setFlag(true, "SEEN", in: HarborpointAreas.sableRow)
        vars.set(.text("noir"), "MOOD", in: AreaVariables.globalScope)

        let restored = AreaVariables(flattened: vars.flattened)
        #expect(restored == vars)
        #expect(restored.integer("VISITS", in: HarborpointAreas.office) == 3)
        #expect(restored.isSet("SEEN", in: HarborpointAreas.sableRow))
        #expect(restored.text("MOOD", in: AreaVariables.globalScope) == "noir")
    }

    /// The flat key is `<scope>/<name>`, split on the *first* slash — a scope
    /// cannot contain one, a variable name might.
    @Test func aVariableNameMayContainASlash() {
        var vars = AreaVariables()
        vars.setInteger(1, "quest/step", in: HarborpointAreas.office)
        let flat = vars.flattened
        #expect(flat["office_suite/quest/step"] == .integer(1))
        let restored = AreaVariables(flattened: flat)
        #expect(restored.integer("quest/step", in: HarborpointAreas.office) == 1)
    }

    @Test func malformedFlatKeysAreDroppedRatherThanCrashing() {
        let restored = AreaVariables(flattened: [
            "noslash": .integer(1),
            "scope/": .integer(2),
            "office_suite/GOOD": .integer(3)
        ])
        #expect(restored.integer("GOOD", in: HarborpointAreas.office) == 3)
        #expect(restored.populatedScopes == [HarborpointAreas.office])
    }

    @Test func theWholeStoreRoundTripsThroughJSON() throws {
        var vars = AreaVariables()
        vars.setInteger(7, "VISITS", in: HarborpointAreas.office)
        vars.set(.number(1.5), "RENT", in: AreaVariables.globalScope)
        let data = try JSONEncoder().encode(vars)
        #expect(try JSONDecoder().decode(AreaVariables.self, from: data) == vars)
    }
}

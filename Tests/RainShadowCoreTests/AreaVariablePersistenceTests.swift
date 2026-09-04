import Foundation
import Testing
@testable import RainShadowCore
@testable import RainShadowPersistence

/// Area variables across a save and load.
///
/// These stop at the save boundary because `GameSession` lives in the app
/// target, not the package — the same structural limit that kept the waypoint
/// queue untested until it moved. What is reachable is the part that can
/// silently corrupt a save: the flattening, the tag mapping, and the tolerance
/// for a file written before any of this existed.
@MainActor
struct AreaVariablePersistenceTests {

    private func freshStore() throws -> (SaveStore, String, UserDefaults) {
        let suiteName = "RainShadowTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        return (SaveStore(defaults: defaults, key: "save"), suiteName, defaults)
    }

    private func persisted(_ value: AreaVariableValue) -> PersistedAreaVariable {
        switch value {
        case .integer(let n): PersistedAreaVariable(kind: "integer", integer: n)
        case .number(let n): PersistedAreaVariable(kind: "number", number: n)
        case .text(let t): PersistedAreaVariable(kind: "text", text: t)
        }
    }

    private func restored(_ stored: PersistedAreaVariable) -> AreaVariableValue {
        switch stored.kind {
        case "number": .number(stored.number ?? 0)
        case "text": .text(stored.text ?? "")
        default: .integer(stored.integer ?? 0)
        }
    }

    @Test func everyValueKindSurvivesTheSaveFile() throws {
        let (store, suite, defaults) = try freshStore()
        defer { defaults.removePersistentDomain(forName: suite) }

        var vars = AreaVariables()
        vars.setInteger(3, "VISITS", in: HarborpointAreas.office)
        vars.set(.text("lila"), "CALLER", in: HarborpointAreas.office)
        vars.set(.number(1.5), "RENT", in: AreaVariables.globalScope)
        vars.setFlag(true, "VISITED", in: HarborpointAreas.sableRow)

        var snapshot = SaveSnapshot(hasSeenOpening: true)
        snapshot.areaVariables = vars.flattened.mapValues(persisted)
        store.save(snapshot)

        let loaded = store.load()
        let roundTripped = AreaVariables(flattened: loaded.areaVariables.mapValues(restored))
        #expect(roundTripped == vars)
        #expect(roundTripped.integer("VISITS", in: HarborpointAreas.office) == 3)
        #expect(roundTripped.text("CALLER", in: HarborpointAreas.office) == "lila")
        #expect(roundTripped.value("RENT", in: AreaVariables.globalScope) == .number(1.5))
        #expect(roundTripped.isSet("VISITED", in: HarborpointAreas.sableRow))
    }

    /// The namespace is the point: the same name in two areas is two variables,
    /// and neither leaks into the other across a save.
    @Test func twoAreasKeepTheirOwnCopyOfAName() throws {
        let (store, suite, defaults) = try freshStore()
        defer { defaults.removePersistentDomain(forName: suite) }

        var vars = AreaVariables()
        vars.setInteger(1, "SEEN", in: HarborpointAreas.office)
        vars.setInteger(2, "SEEN", in: HarborpointAreas.sableRow)

        var snapshot = SaveSnapshot()
        snapshot.areaVariables = vars.flattened.mapValues(persisted)
        store.save(snapshot)

        let out = AreaVariables(flattened: store.load().areaVariables.mapValues(restored))
        #expect(out.integer("SEEN", in: HarborpointAreas.office) == 1)
        #expect(out.integer("SEEN", in: HarborpointAreas.sableRow) == 2)
    }

    /// A save written before area variables existed must still load.
    @Test func aSaveWithoutAreaVariablesLoadsWithAnEmptyStore() throws {
        let (store, suite, defaults) = try freshStore()
        defer { defaults.removePersistentDomain(forName: suite) }

        store.save(SaveSnapshot(hasSeenOpening: true))
        let loaded = store.load()
        #expect(loaded.hasSeenOpening)
        #expect(loaded.areaVariables.isEmpty)
        #expect(AreaVariables(flattened: loaded.areaVariables.mapValues(restored)).isEmpty)
    }

    /// An unrecognised tag must not cost the player their save — it decodes as
    /// an integer rather than failing the whole load.
    @Test func anUnknownVariableKindDecodesRatherThanFailingTheLoad() throws {
        let (store, suite, defaults) = try freshStore()
        defer { defaults.removePersistentDomain(forName: suite) }

        var snapshot = SaveSnapshot(hasSeenOpening: true)
        snapshot.areaVariables = [
            "office_suite/WEIRD": PersistedAreaVariable(kind: "quaternion", integer: 9),
            "office_suite/GOOD": PersistedAreaVariable(kind: "integer", integer: 4)
        ]
        store.save(snapshot)

        let out = AreaVariables(flattened: store.load().areaVariables.mapValues(restored))
        #expect(out.integer("GOOD", in: HarborpointAreas.office) == 4)
        #expect(out.integer("WEIRD", in: HarborpointAreas.office) == 9)
        #expect(store.load().hasSeenOpening, "one odd variable cost the rest of the save")
    }

    /// The flat key a district visit is stored under, so the world-map fact and
    /// the area namespace cannot drift apart silently.
    @Test func aDistrictVisitIsStoredUnderItsOwnAreaScope() {
        var vars = AreaVariables()
        vars.setFlag(true, "VISITED", in: CityDistrictAreaAdapter.areaID(for: .wharfLadder))
        #expect(vars.flattened["city_wharf_ladder/VISITED"] == .integer(1))
        #expect(!vars.isSet("VISITED", in: CityDistrictAreaAdapter.areaID(for: .riverside)))
    }
}

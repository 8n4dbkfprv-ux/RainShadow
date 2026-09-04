import Foundation

/// A value stored against an area or against the game.
///
/// Baldur's Gate's `.ARE` variable entry carries a type tag — int, float,
/// script name, resref, strref, dword — and the engine's scripting reads and
/// writes them by name. This is the subset RainShadow needs, with the same
/// property that matters: a variable is a named scalar, not a structure.
enum AreaVariableValue: Hashable, Codable, Sendable {
    case integer(Int)
    case number(Double)
    case text(String)

    /// BG has no boolean type; a flag is an int that is zero or not. Kept as a
    /// convenience rather than a case so the storage stays the engine's.
    static func flag(_ isSet: Bool) -> AreaVariableValue { .integer(isSet ? 1 : 0) }

    var integerValue: Int? {
        switch self {
        case .integer(let value): value
        case .number(let value): Int(value)
        case .text: nil
        }
    }

    var isSet: Bool { (integerValue ?? 0) != 0 }

    var textValue: String? {
        if case .text(let value) = self { return value }
        return nil
    }
}

/// Named variables scoped to an area, plus a game-wide scope.
///
/// This is what makes an area *persist* rather than be rebuilt. Baldur's Gate
/// writes the modified `.ARE` into the save game, and its variables section is
/// namespaced on the six-character area resref — so `AR1000` can have a `SEEN`
/// of its own without colliding with anyone else's, and the engine's `GLOBAL`
/// scope sits beside it for anything the whole game shares.
///
/// **What this is deliberately not.** The plan for this phase listed four
/// `GameSession` fields to fold in here, and two of them do not belong:
///
/// - `cityFogByDistrict` is the *explored bitmask*, which BG stores as its own
///   `.ARE` section — "an array of bits, one bit for each 32x32 cell" — not as a
///   variable. It is a raster, and flattening a raster into a named scalar store
///   would lose the thing that makes it one.
/// - `groundPiles` is *items on the floor*, which BG keeps in the area's
///   container and item sections. Also its own section, also not a variable.
///
/// Both are already keyed by area, which is the property that mattered. Moving
/// them here would have made the namespace tidier and the model wronger.
struct AreaVariables: Equatable, Codable, Sendable {
    /// Scope for variables no single area owns — BG's `GLOBAL`.
    static let globalScope = AreaID("GLOBAL")

    private var scopes: [AreaID: [String: AreaVariableValue]]

    init(scopes: [AreaID: [String: AreaVariableValue]] = [:]) {
        self.scopes = scopes
    }

    var isEmpty: Bool { scopes.allSatisfy(\.value.isEmpty) }

    /// Every scope that holds at least one variable, for tests and tooling.
    var populatedScopes: [AreaID] {
        scopes.filter { !$0.value.isEmpty }.keys.sorted { $0.rawValue < $1.rawValue }
    }

    func names(in scope: AreaID) -> [String] {
        (scopes[scope] ?? [:]).keys.sorted()
    }

    // MARK: - Access

    func value(_ name: String, in scope: AreaID) -> AreaVariableValue? {
        scopes[scope]?[name]
    }

    /// Setting `nil` removes the variable rather than storing an empty one, so
    /// an unset name and a name set to nothing are the same thing — which is how
    /// the engine's `Global("x","AREA")` reads for a variable never assigned.
    mutating func set(_ value: AreaVariableValue?, _ name: String, in scope: AreaID) {
        if let value {
            scopes[scope, default: [:]][name] = value
        } else {
            scopes[scope]?.removeValue(forKey: name)
        }
    }

    // MARK: - Convenience

    func integer(_ name: String, in scope: AreaID) -> Int {
        value(name, in: scope)?.integerValue ?? 0
    }

    func isSet(_ name: String, in scope: AreaID) -> Bool {
        value(name, in: scope)?.isSet ?? false
    }

    func text(_ name: String, in scope: AreaID) -> String? {
        value(name, in: scope)?.textValue
    }

    mutating func setInteger(_ number: Int, _ name: String, in scope: AreaID) {
        set(.integer(number), name, in: scope)
    }

    mutating func setFlag(_ isSet: Bool, _ name: String, in scope: AreaID) {
        set(.flag(isSet), name, in: scope)
    }

    /// Increment and return the new value — BG's `IncrementGlobal`.
    @discardableResult
    mutating func increment(_ name: String, in scope: AreaID, by delta: Int = 1) -> Int {
        let next = integer(name, in: scope) + delta
        setInteger(next, name, in: scope)
        return next
    }

    // MARK: - Persistence

    /// Flat form for the save file: `"<scope>/<name>"` keys.
    ///
    /// A nested dictionary would encode as JSON objects keyed by `AreaID`, and
    /// `Codable` cannot key a dictionary on a non-`String` type without falling
    /// back to an array of alternating keys and values — which reads as noise in
    /// a save file anyone might have to inspect.
    var flattened: [String: AreaVariableValue] {
        var flat: [String: AreaVariableValue] = [:]
        for (scope, values) in scopes {
            for (name, value) in values {
                flat["\(scope.rawValue)/\(name)"] = value
            }
        }
        return flat
    }

    init(flattened: [String: AreaVariableValue]) {
        var scopes: [AreaID: [String: AreaVariableValue]] = [:]
        for (key, value) in flattened {
            // Split on the *first* slash only: a scope cannot contain one, a
            // variable name might.
            guard let separator = key.firstIndex(of: "/") else { continue }
            let scope = AreaID(String(key[key.startIndex..<separator]))
            let name = String(key[key.index(after: separator)...])
            guard !name.isEmpty else { continue }
            scopes[scope, default: [:]][name] = value
        }
        self.init(scopes: scopes)
    }
}

import Foundation

public enum CutsceneCompletionReason: String, Equatable, Sendable {
    case natural
    case skipped
}

/// BG:EE SetCutSceneBreakable / CutSceneBroken. Escape is accepted immediately
/// when explicitly enabled. Recovery is authored separately from interrupted work.
public struct BreakableCutsceneGate: Equatable, Sendable {
    public private(set) var isActive = false
    public private(set) var isCompleted = false
    public var isBreakable = false
    public private(set) var wasBroken = false

    public init() {}

    public mutating func begin(at now: TimeInterval, breakable: Bool = false) {
        isActive = true
        isCompleted = false
        wasBroken = false
        isBreakable = breakable
    }

    public func canSkip(at now: TimeInterval) -> Bool {
        isActive && isBreakable && !isCompleted && !wasBroken
    }

    public mutating func markBroken() {
        wasBroken = true
        isBreakable = false
    }

    @discardableResult
    public mutating func markCompleted(reason: CutsceneCompletionReason = .natural) -> Bool {
        guard isActive, !isCompleted else { return false }
        isCompleted = true
        isActive = false
        wasBroken = reason == .skipped
        return true
    }

    public mutating func reset() { self = Self() }
}

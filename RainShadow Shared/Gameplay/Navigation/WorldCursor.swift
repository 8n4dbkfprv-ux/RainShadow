import CoreGraphics
import Foundation

/// What the pointer is over, in the world.
///
/// BG derives this straight off the search map and then lets objects override it:
///
///     int Map::GetCursor(const Point& p) const {
///       if (!IsExplored(p)) return IE_CURSOR_INVALID;
///       switch (GetBlocked(p) & (PASSABLE | TRAVEL)) {
///         case IMPASSABLE: return IE_CURSOR_BLOCKED;
///         case PASSABLE:   return IE_CURSOR_WALK;
///         default:         return IE_CURSOR_TRAVEL;
///       } }
///
/// The consequence worth preserving is that hover feedback is exactly as honest
/// as pathing, because both read the same bytes. `GameControl::OnMouseUp` then
/// refuses to issue movement when the cursor came back blocked — the same
/// contract as this project's "a refused order is refused" rule, arrived at from
/// the other direction.
///
/// Both scenes had grown their own version of this as an inline ladder of
/// `NSCursor` assignments, and they disagreed: the office had no travel state at
/// all and the city drew portals with the same cursor as a lamp post.
enum WorldCursor: Equatable, Sendable {
    /// Over UI, or over nothing the world responds to.
    case normal
    /// Orderable ground.
    case walk
    /// Impassable, or unexplored — BG folds `IE_CURSOR_INVALID` into blocked so
    /// the fog does not leak information about what is behind it.
    case blocked
    /// An area transition.
    case travel
    /// A door, container, or inspectable hotspot.
    case interact
    /// A creature that can be talked to.
    case talk

    /// The base state, read from the search map alone.
    static func fromSearchMap(isExplored: Bool, isPassable: Bool, isTravel: Bool) -> WorldCursor {
        guard isExplored else { return .blocked }
        if isTravel { return .travel }
        return isPassable ? .walk : .blocked
    }

    /// Object hover wins over terrain, and a creature wins over an object — BG's
    /// order in `UpdateCursor`, where the actor check runs last and overwrites.
    ///
    /// Travel deliberately survives an `interact` override: a door that is also
    /// the way out of the district should read as the way out.
    func overridden(hasInteractable: Bool, hasTalkableActor: Bool) -> WorldCursor {
        if hasTalkableActor { return .talk }
        if hasInteractable, self != .travel { return .interact }
        return self
    }

    /// Whether an order issued here would be refused outright.
    var refusesOrders: Bool { self == .blocked }
}

/// A cursor plus BG's "right cursor, wrong moment" bit.
///
/// The engine does not swap icons when an action is momentarily illegal; it ORs
/// in `IE_CURSOR_GRAY` and draws the same cursor greyed. Keeping that as a
/// modifier rather than a seventh case means callers cannot forget to handle it.
struct WorldCursorState: Equatable, Sendable {
    var cursor: WorldCursor
    /// BG `IE_CURSOR_GRAY`.
    var isDisabled: Bool

    init(_ cursor: WorldCursor, isDisabled: Bool = false) {
        self.cursor = cursor
        self.isDisabled = isDisabled
    }

    static let normal = WorldCursorState(.normal)

    /// Resolves the whole thing in one call, in BG's order: terrain, then
    /// objects, then the disabled modifier.
    static func resolve(
        isExplored: Bool = true,
        isPassable: Bool,
        isTravel: Bool = false,
        hasInteractable: Bool = false,
        hasTalkableActor: Bool = false,
        isReachable: Bool = true
    ) -> WorldCursorState {
        let base = WorldCursor.fromSearchMap(
            isExplored: isExplored,
            isPassable: isPassable,
            isTravel: isTravel
        )
        let cursor = base.overridden(
            hasInteractable: hasInteractable,
            hasTalkableActor: hasTalkableActor
        )
        // An interactable behind a wall is the case the grey bit is for: the
        // cursor still says what the thing is, while saying you cannot have it.
        let disabled = !isReachable && cursor != .blocked
        return WorldCursorState(cursor, isDisabled: disabled)
    }
}

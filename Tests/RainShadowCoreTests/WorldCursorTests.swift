import Testing
@testable import RainShadowCore

/// Hover feedback derived from the search map. See `WorldCursor`.
struct WorldCursorTests {
    // MARK: - Terrain, straight off the map

    @Test func passableGroundWalksAndImpassableBlocks() {
        #expect(WorldCursor.fromSearchMap(isExplored: true, isPassable: true, isTravel: false) == .walk)
        #expect(WorldCursor.fromSearchMap(isExplored: true, isPassable: false, isTravel: false) == .blocked)
    }

    @Test func unexploredReadsAsBlockedNotAsWalkable() {
        // BG folds IE_CURSOR_INVALID into blocked so the fog does not leak what is
        // behind it — passable-but-unseen must not advertise itself.
        #expect(WorldCursor.fromSearchMap(isExplored: false, isPassable: true, isTravel: false) == .blocked)
    }

    @Test func travelBitWinsOverPlainPassability() {
        #expect(WorldCursor.fromSearchMap(isExplored: true, isPassable: true, isTravel: true) == .travel)
    }

    // MARK: - Overrides, in the engine's order

    @Test func creaturesOutrankObjectsAndTerrain() {
        // UpdateCursor checks the actor last and overwrites whatever came before.
        #expect(WorldCursor.walk.overridden(hasInteractable: true, hasTalkableActor: true) == .talk)
        #expect(WorldCursor.blocked.overridden(hasInteractable: false, hasTalkableActor: true) == .talk)
    }

    @Test func objectsOutrankTerrain() {
        #expect(WorldCursor.walk.overridden(hasInteractable: true, hasTalkableActor: false) == .interact)
        // A container against a wall still reads as a container.
        #expect(WorldCursor.blocked.overridden(hasInteractable: true, hasTalkableActor: false) == .interact)
    }

    @Test func travelSurvivesAnInteractableOverride() {
        // The office door is both a door and the way to the street; it should read
        // as the way out rather than as furniture.
        #expect(WorldCursor.travel.overridden(hasInteractable: true, hasTalkableActor: false) == .travel)
    }

    // MARK: - The grey bit

    @Test func unreachableInteractablesGreyRatherThanChangeIcon() {
        // BG ORs in IE_CURSOR_GRAY instead of swapping the cursor, so the player
        // still learns what the thing is.
        let state = WorldCursorState.resolve(
            isPassable: true,
            hasInteractable: true,
            isReachable: false
        )
        #expect(state.cursor == .interact)
        #expect(state.isDisabled)
    }

    @Test func blockedGroundIsNotAlsoGreyed() {
        // Blocked already says no; greying it would be saying it twice.
        let state = WorldCursorState.resolve(isPassable: false, isReachable: false)
        #expect(state.cursor == .blocked)
        #expect(!state.isDisabled)
    }

    @Test func reachableThingsAreNotGreyed() {
        let state = WorldCursorState.resolve(isPassable: true, hasInteractable: true)
        #expect(state.cursor == .interact)
        #expect(!state.isDisabled)
    }

    // MARK: - The contract that ties it to movement

    @Test func onlyBlockedRefusesOrders() {
        // GameControl::OnMouseUp returns early when the cursor is blocked. Frozen
        // rule 13 says the same thing from the other end, and both must agree or
        // hover feedback starts lying about what a click will do.
        #expect(WorldCursor.blocked.refusesOrders)
        for cursor in [WorldCursor.walk, .travel, .interact, .talk, .normal] {
            #expect(!cursor.refusesOrders)
        }
    }

    @Test func resolvedStateAgreesWithTheSearchMapSample() {
        // The point of the type: one sample drives hover and the order decision.
        for passable in [true, false] {
            let state = WorldCursorState.resolve(isPassable: passable)
            #expect(state.cursor.refusesOrders == !passable)
        }
    }
}

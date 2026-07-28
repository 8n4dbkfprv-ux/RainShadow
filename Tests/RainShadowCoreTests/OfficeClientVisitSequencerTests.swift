import Testing
@testable import RainShadowCore

struct OfficeClientVisitSequencerTests {
    @Test func finishIntroductionStartsExitWithoutReturningDoor() {
        let actions = OfficeClientVisitSequencer.actions(for: .finishCaseIntroductionStarted)

        #expect(actions == [.restoreCamera, .beginClientExit])
        #expect(!actions.contains(.returnDoor))
        #expect(!OfficeClientVisitSequencer.returnsDoor(on: .finishCaseIntroductionStarted))
    }

    @Test func doorReturnIsOnlyArmedAfterClientExitCompletes() {
        #expect(OfficeClientVisitSequencer.returnsDoor(on: .clientExitCompleted))
        #expect(!OfficeClientVisitSequencer.returnsDoor(on: .finishCaseIntroductionStarted))

        let afterExit = OfficeClientVisitSequencer.actions(for: .clientExitCompleted)
        #expect(afterExit.contains(.returnDoor))
        #expect(afterExit.first == .returnDoor)
    }

    @Test func exitCompletionReturnsDoorBeforeUnlockingPlayerControl() {
        let actions = OfficeClientVisitSequencer.actions(for: .clientExitCompleted)
        #expect(actions == [.returnDoor, .unlockPlayerControl])

        let doorIndex = actions.firstIndex(of: .returnDoor)
        let unlockIndex = actions.firstIndex(of: .unlockPlayerControl)
        #expect(doorIndex != nil)
        #expect(unlockIndex != nil)
        if let doorIndex, let unlockIndex {
            #expect(doorIndex < unlockIndex)
        }
    }

    @Test func fullPostDialogueOrderIsExitThenDoorThenControl() {
        // Drive the real shipped entry points in the same order the scene applies them.
        var timeline: [OfficeClientVisitSequencer.Action] = []
        timeline.append(contentsOf: OfficeClientVisitSequencer.actions(for: .finishCaseIntroductionStarted))
        timeline.append(contentsOf: OfficeClientVisitSequencer.actions(for: .clientExitCompleted))

        #expect(timeline == [
            .restoreCamera,
            .beginClientExit,
            .returnDoor,
            .unlockPlayerControl
        ])

        let exitStart = timeline.firstIndex(of: .beginClientExit)!
        let doorReturn = timeline.firstIndex(of: .returnDoor)!
        #expect(exitStart < doorReturn, "Door must not return until after exit has been started and completed")
    }

    @Test func clientDeparturePathStaysClearOfOfficeObstacles() {
        let grid = OfficeNavigationLayout.makeGrid()
        let path = OfficeNavigationLayout.clientDepartureRoute(in: grid)
        #expect(path.count >= 3)
        // The final point is deliberately outside the department; the preceding
        // leg crosses the fallen exterior door after all interior routing.
        #expect(path.dropLast().allSatisfy { !OfficeNavigationLayout.isBlocked($0) })

        guard let first = path.first, let interiorLast = path.dropLast().last else {
            #expect(Bool(false), "Departure path must have endpoints")
            return
        }
        let route = grid.path(from: first, to: interiorLast)
        #expect(route != nil)
        #expect(route?.allSatisfy { !OfficeNavigationLayout.isBlocked($0) } != false)

        // Every waypoint before the explicit exterior crossing is walkable.
        for point in path.dropLast() {
            #expect(grid.nearestWalkablePoint(to: point) != nil)
        }
    }
}

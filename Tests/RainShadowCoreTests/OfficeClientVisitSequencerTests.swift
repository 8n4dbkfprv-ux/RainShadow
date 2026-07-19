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
        let path = OfficeNavigationLayout.clientDeparturePath
        #expect(path.count == 3)
        #expect(path.allSatisfy { !OfficeNavigationLayout.isBlocked($0) })

        let grid = OfficeNavigationLayout.makeGrid()
        guard let first = path.first, let last = path.last else {
            #expect(Bool(false), "Departure path must have endpoints")
            return
        }
        let route = grid.path(from: first, to: last)
        #expect(route != nil)
        #expect(route?.allSatisfy { !OfficeNavigationLayout.isBlocked($0) } != false)
    }
}

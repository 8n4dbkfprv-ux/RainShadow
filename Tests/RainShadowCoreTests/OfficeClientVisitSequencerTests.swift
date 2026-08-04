import Testing
@testable import RainShadowCore

struct OfficeClientVisitSequencerTests {
    @Test func finishIntroductionStartsExitWithoutReturningDoor() {
        let actions = OfficeClientVisitSequencer.actions(for: .finishCaseIntroductionStarted)

        #expect(actions == [.restoreCamera, .beginClientExit])
        #expect(!actions.contains(.returnDoor))
        #expect(!OfficeClientVisitSequencer.returnsDoor(on: .finishCaseIntroductionStarted))
    }

    @Test func doorDoesNotReturnAfterClientExitCompletes() {
        #expect(!OfficeClientVisitSequencer.returnsDoor(on: .clientExitCompleted))
        #expect(!OfficeClientVisitSequencer.returnsDoor(on: .finishCaseIntroductionStarted))

        let afterExit = OfficeClientVisitSequencer.actions(for: .clientExitCompleted)
        #expect(!afterExit.contains(.returnDoor))
        #expect(afterExit == [.unlockPlayerControl])
    }

    @Test func exitCompletionUnlocksPlayerControlWithDoorStillOpen() {
        let actions = OfficeClientVisitSequencer.actions(for: .clientExitCompleted)
        #expect(actions == [.unlockPlayerControl])
        #expect(actions.firstIndex(of: .unlockPlayerControl) != nil)
        #expect(actions.firstIndex(of: .returnDoor) == nil)
    }

    @Test func fullPostDialogueOrderIsExitThenControl() {
        // Drive the real shipped entry points in the same order the scene applies them.
        var timeline: [OfficeClientVisitSequencer.Action] = []
        timeline.append(contentsOf: OfficeClientVisitSequencer.actions(for: .finishCaseIntroductionStarted))
        timeline.append(contentsOf: OfficeClientVisitSequencer.actions(for: .clientExitCompleted))

        #expect(timeline == [
            .restoreCamera,
            .beginClientExit,
            .unlockPlayerControl
        ])

        let exitStart = timeline.firstIndex(of: .beginClientExit)!
        let unlock = timeline.firstIndex(of: .unlockPlayerControl)!
        #expect(exitStart < unlock, "Player control unlocks only after exit has been started and completed")
        #expect(!timeline.contains(.returnDoor), "Door stays open for free-play city exit")
    }

    @Test func clientDeparturePathStaysClearOfOfficeObstacles() {
        // Departure runs after the leaf has fallen — door cells are open.
        let map = OfficeNavigationLayout.makeGrid(entranceDoorBlocking: false)
        let path = OfficeNavigationLayout.clientDepartureRoute(in: map)
        #expect(path.count >= 3)
        // The final point is deliberately outside the department; the preceding
        // leg crosses the fallen exterior door after all interior routing.
        #expect(path.dropLast().allSatisfy { !OfficeNavigationLayout.isBlocked($0) })

        // Interior legs (all but the authored exterior threshold) stay clear.
        for index in 0..<(path.count - 2) {
            let a = path[index]
            let b = path[index + 1]
            #expect(!OfficeNavigationLayout.isBlocked(a))
            #expect(!OfficeNavigationLayout.isBlocked(b))
        }

        // Every waypoint before the explicit exterior crossing is walkable.
        for point in path.dropLast() {
            #expect(map.nearestWalkablePoint(to: point) != nil)
        }
    }
}

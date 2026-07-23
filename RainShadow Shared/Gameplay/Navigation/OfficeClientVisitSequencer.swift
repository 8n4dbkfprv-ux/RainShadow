/// Pure ordering contract for Lila’s office visit: door fall → entrance →
/// dialogue → exit → door return → player control. The scene applies these
/// actions; tests assert the shipped sequence without re-implementing it.
enum OfficeClientVisitSequencer {
    enum Event: Equatable {
        /// Case-opening dialogue finished; Lila should leave.
        case finishCaseIntroductionStarted
        /// Lila finished the authored departure path (cleared the room).
        case clientExitCompleted
    }

    enum Action: Equatable {
        case restoreCamera
        case beginClientExit
        case returnDoor
        case unlockPlayerControl
    }

    /// Actions to perform for a visit-lifecycle event, in order.
    static func actions(for event: Event) -> [Action] {
        switch event {
        case .finishCaseIntroductionStarted:
            // Door must stay down while she walks out — do not return the leaf here.
            return [.restoreCamera, .beginClientExit]
        case .clientExitCompleted:
            return [.returnDoor, .unlockPlayerControl]
        }
    }

    /// True only when door return is part of the given event’s action list.
    static func returnsDoor(on event: Event) -> Bool {
        actions(for: event).contains(.returnDoor)
    }
}

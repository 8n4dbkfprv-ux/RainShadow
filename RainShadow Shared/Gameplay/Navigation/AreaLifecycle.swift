import CoreGraphics
import Foundation

/// Mutable ARE object state, separate from the immutable authored record.
/// GemRB AREImporter::PutDoors/PutRegions serialize the current flags, not
/// their initial values. Missing overrides mean this object has not changed.
struct AreaObjectState: Equatable, Sendable {
    var doorOpen: [String: Bool] = [:]
    var unlockedDoors: Set<String> = []
    var spentTriggers: Set<String> = []

    func isOpen(_ door: AreaDoor) -> Bool { doorOpen[door.id] ?? !door.startsClosed }

    func canOpen(_ door: AreaDoor, holdingKey: (String) -> Bool) -> Bool {
        var current = door
        if unlockedDoors.contains(door.id) { current.isLocked = false }
        return current.canOpen(holdingKey: holdingKey)
    }

    mutating func setDoor(_ door: AreaDoor, open: Bool) {
        doorOpen[door.id] = open
        // Door::SetDoorOpen: opening unlocks in BG (the PST/IWD2 exceptions
        // are not RainShadow's target). Restoring a save does not call this.
        if open { unlockedDoors.insert(door.id) }
    }
}

/// GlobalTimer::Update/Freeze and Scriptable::TickScripting at 1c45c185.
/// One update per elapsed timer interval, no catch-up burst after a stall.
/// GemRB integer-divides 1000 / 15; use its 66ms interval. RainShadow has one
/// active area and no global scriptable IDs, so its stagger phase is zero.
struct AreaLogicClock {
    static let interval: TimeInterval = 0.066
    private var lastUpdate: TimeInterval?
    private(set) var ticks: UInt64 = 0

    var pollsScript: Bool { ticks == 1 || ticks % 16 == 0 }

    mutating func advance(at time: TimeInterval, paused: Bool) -> Bool {
        guard time.isFinite else { return false }
        if paused {
            lastUpdate = time
            return false
        }
        if let lastUpdate, time >= lastUpdate,
           time - lastUpdate + 1e-9 < Self.interval { return false }
        lastUpdate = time
        ticks &+= 1
        return true
    }
}

struct AreaDoorChange {
    var accepted: Bool
    var relocatedActors: [String: CGPoint] = [:]
}

extension NavigationMap {
    /// Door::BlockedOpen/SetDoorOpen and Map::JumpActors. Only actor origins
    /// inside the impeded cells block a closing leaf; personal-space stamps
    /// alone do not. Opening cannot be refused. JumpActors runs BEFORE the
    /// tile switch upstream, using AdjustPositionNavmap's size=-1 query.
    func changeDoor(_ door: AreaDoor, open: Bool, force: Bool = false) -> AreaDoorChange {
        guard open || !door.cannotClose || force else { return .init(accepted: false) }
        let cells = Set(searchMap.impededCells(for: door.searchMapObstacle, open: open))
        let actors = occupancy.actors.values.filter {
            $0.blocksSearchMap && cells.contains(searchMap.cell(for: $0.position))
                && !searchMap.flags(at: searchMap.cell(for: $0.position)).intersection(.actor).isEmpty
        }.sorted { $0.id < $1.id }
        guard open || actors.isEmpty || door.isSliding || force else {
            return .init(accepted: false)
        }
        var changes = AreaDoorChange(accepted: true)
        for actor in actors {
            let point = occupancy.withStampLifted(id: actor.id) {
                pathFinder.adjustPositionNavmap(actor.position)
            }
            occupancy.updatePosition(id: actor.id, to: point)
            changes.relocatedActors[actor.id] = point
        }
        setDoor(door.id, open: open)
        return changes
    }
}

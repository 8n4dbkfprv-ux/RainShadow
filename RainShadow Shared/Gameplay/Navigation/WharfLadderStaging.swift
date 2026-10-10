import CoreGraphics

/// Temporary, stationary cinematic cast. Seat only on connected raster cells,
/// outside the player's footprint. The restored plates and geometry stay authoritative.
enum WharfLadderStaging {
    static func positions(near origin: CGPoint, count: Int, navigation: NavigationMap,
                          ignoringActorID: String? = nil) -> [CGPoint] {
        func seat(_ desired: CGPoint) -> CGPoint? {
            guard let identity = ignoringActorID else { return navigation.nearestWalkablePoint(to: desired) }
            return navigation.occupancy.withStampLifted(id: identity) {
                navigation.nearestWalkablePoint(to: desired)
            }
        }
        func reachable(_ point: CGPoint) -> Bool {
            // Pass identity through the whole query: lifting the raster stamp
            // alone still leaves a moving requester in the actor lookup table.
            let path = navigation.pathAvoidingActors(from: origin, to: point, identity: ignoringActorID)
            return navigation.searchMap.cell(for: path.destination ?? origin) == navigation.searchMap.cell(for: point)
        }
        var result: [CGPoint] = []
        var seatedIDs: [String] = []
        defer {
            seatedIDs.forEach { navigation.unregisterActor(id: $0) }
            navigation.occupancy.restampAll()
        }
        for radius in stride(from: CGFloat(64), through: 224, by: 32) {
            for index in 0..<16 {
                let angle = CGFloat(index) * .pi / 8
                let desired = CGPoint(x: origin.x + cos(angle) * radius,
                                      y: origin.y + sin(angle) * radius * 0.75)
                guard let point = seat(desired),
                      hypot(point.x - origin.x, (point.y - origin.y) / 0.75) >= 60,
                      result.allSatisfy({ hypot(point.x - $0.x, (point.y - $0.y) / 0.75) >= 60 }),
                      reachable(point) else { continue }
                let id = "wharf.staging.\(result.count)"
                guard canSeat(point, id: id, protecting: (ignoringActorID.map { [$0] } ?? []) + seatedIDs, in: navigation) else { continue }
                navigation.registerActor(id: id, kind: .npc, at: point)
                seatedIDs.append(id)
                result.append(point)
                if result.count == count { return result }
            }
        }
        return result
    }
    /// Test the actual stamps in both directions. A 60-unit centre separation
    /// can still overlap a neighbouring clearance cell on the 16×12 raster.
    private static func canSeat(_ point: CGPoint, id: String, protecting ids: [String], in map: NavigationMap) -> Bool {
        let previous = map.occupancy.actors[id]
        map.registerActor(id: id, kind: .npc, at: point)
        map.occupancy.restampAll()
        defer {
            map.unregisterActor(id: id)
            if let previous { map.occupancy.register(previous) }
            map.occupancy.restampAll()
        }
        return (ids + [id]).allSatisfy { identity in
            guard let actor = map.occupancy.actors[identity] else { return true }
            return map.occupancy.withStampLifted(id: identity) {
                map.searchMap.blockedInRadiusTile(at: actor.position, size: map.circleSize).contains(.passable)
            }
        }
    }

    /// Migration for encounters saved before bidirectional staging clearance.
    /// Keep Voss fixed and reseat only a crew member whose stamp traps a body.
    /// This is encounter placement, not an exception in pathfinding or collision.
    static func repairCrowdedPositions(playerID: String, crewIDs: [String], navigation map: NavigationMap) -> [String: CGPoint] {
        guard let player = map.occupancy.actors[playerID] else { return [:] }
        let clear = map.occupancy.withStampLifted(id: playerID) {
            map.searchMap.blockedInRadiusTile(at: player.position, size: map.circleSize).contains(.passable)
        }
        guard !clear else { return [:] }
        let originals = crewIDs.compactMap { map.occupancy.actors[$0] }
        originals.forEach { map.unregisterActor(id: $0.id) }
        map.occupancy.restampAll()
        defer {
            crewIDs.forEach { map.unregisterActor(id: $0) }
            originals.forEach { map.occupancy.register($0) }
            map.occupancy.restampAll()
        }
        // Do not try to cure a static wall/terrain problem by moving the cast.
        guard map.occupancy.withStampLifted(id: playerID, {
            map.searchMap.blockedInRadiusTile(at: player.position, size: map.circleSize).contains(.passable)
        }) else { return [:] }
        var protected = [playerID], result: [String: CGPoint] = [:]
        for actor in originals {
            let away = atan2((actor.position.y - player.position.y) / 0.75, actor.position.x - player.position.x)
            let candidates = [actor.position] + [CGFloat(16), 32, 48, 64, 96].flatMap { radius in
                (0..<16).map { step in
                    let angle = away + CGFloat(step) * .pi / 8
                    return CGPoint(x: actor.position.x + cos(angle) * radius,
                        y: actor.position.y + sin(angle) * radius * 0.75).rounded
                }
            }
            guard let point = candidates.first(where: { canSeat($0, id: actor.id, protecting: protected, in: map) }) else { return [:] }
            var placed = actor; placed.position = point
            map.occupancy.register(placed); map.occupancy.restampAll()
            protected.append(actor.id)
            if point != actor.position { result[actor.id] = point }
        }
        return result
    }

}

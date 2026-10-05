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
        for radius in stride(from: CGFloat(64), through: 224, by: 32) {
            for index in 0..<16 {
                let angle = CGFloat(index) * .pi / 8
                let desired = CGPoint(x: origin.x + cos(angle) * radius,
                                      y: origin.y + sin(angle) * radius * 0.75)
                guard let point = seat(desired),
                      hypot(point.x - origin.x, (point.y - origin.y) / 0.75) >= 60,
                      result.allSatisfy({ hypot(point.x - $0.x, (point.y - $0.y) / 0.75) >= 60 }),
                      reachable(point) else { continue }
                result.append(point)
                if result.count == count { return result }
            }
        }
        return result
    }
}

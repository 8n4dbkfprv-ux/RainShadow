import CoreGraphics
import Testing
@testable import RainShadowCore

struct NavigationMapTests {
    @Test func choosesDirectAnyAngleShortcut() {
        let map = makeMap()

        let path = map.path(
            from: CGPoint(x: 5, y: 5),
            to: CGPoint(x: 25, y: 25)
        )

        #expect(path == [CGPoint(x: 25, y: 25)])
    }

    @Test func routesAroundBlockedCells() {
        let wall = CGRect(x: 10, y: 0, width: 10, height: 30)
        let map = makeMap(obstacles: [wall])

        let path = map.path(
            from: CGPoint(x: 5, y: 5),
            to: CGPoint(x: 25, y: 5)
        )

        #expect(path != nil)
        guard let path else { return }
        #expect(!path.isEmpty)
        #expect(path.last == CGPoint(x: 25, y: 5))
        #expect(path.allSatisfy { !wall.contains($0) })
    }

    @Test func doesNotCutAcrossBlockedCorner() {
        let right = CGRect(x: 10, y: 0, width: 10, height: 10)
        let above = CGRect(x: 0, y: 10, width: 10, height: 10)
        let map = makeMap(obstacles: [right, above])

        let path = map.path(
            from: CGPoint(x: 5, y: 5),
            to: CGPoint(x: 15, y: 15)
        )

        #expect(path == nil)
    }

    @Test func selectsNearbyWalkablePointForBlockedTap() {
        let obstacle = CGRect(x: 10, y: 10, width: 10, height: 10)
        let map = makeMap(obstacles: [obstacle])

        let resolved = map.nearestWalkablePoint(to: CGPoint(x: 15, y: 15))

        #expect(resolved != nil)
        #expect(resolved != CGPoint(x: 15, y: 15))
        if let resolved {
            #expect(!obstacle.contains(resolved))
        }
    }

    @Test func sameCellRouteCannotCrossAThinObstacle() {
        let thinBarrier = CGRect(x: 5.4, y: 0, width: 0.2, height: 10)
        let map = NavigationMap(
            origin: .zero,
            columns: 1,
            rows: 1,
            cellSize: CGSize(width: 10, height: 10),
            obstacles: [thinBarrier]
        )

        #expect(map.path(
            from: CGPoint(x: 2, y: 5),
            to: CGPoint(x: 8, y: 5)
        ) == nil)
    }

    @Test func disconnectedDestinationFallsBackTowardCaller() {
        let sealedWall = CGRect(x: 20, y: 0, width: 10, height: 50)
        let map = NavigationMap(
            origin: .zero,
            columns: 5,
            rows: 5,
            cellSize: CGSize(width: 10, height: 10),
            obstacles: [sealedWall]
        )

        let route = map.route(
            from: CGPoint(x: 5, y: 25),
            to: CGPoint(x: 35, y: 25),
            maximumFallbackCellRadius: 2
        )

        #expect(route?.destinationWasAdjusted == true)
        #expect(route?.resolvedDestination.x ?? 100 < 20)
        #expect(route?.waypoints.last == route?.resolvedDestination)
    }

    @Test func fallbackSearchDoesNotJumpBeyondItsBoundedRing() {
        let sealedWall = CGRect(x: 20, y: 0, width: 10, height: 50)
        let map = NavigationMap(
            origin: .zero,
            columns: 5,
            rows: 5,
            cellSize: CGSize(width: 10, height: 10),
            obstacles: [sealedWall]
        )

        let route = map.route(
            from: CGPoint(x: 5, y: 25),
            to: CGPoint(x: 45, y: 25),
            maximumFallbackCellRadius: 1
        )

        #expect(route == nil)
    }

    @Test func actorFootprintRejectsGapThatOnlyFitsAPoint() {
        let lowerBlock = CGRect(x: 0, y: 0, width: 60, height: 22)
        let upperBlock = CGRect(x: 0, y: 28, width: 60, height: 22)
        let start = CGPoint(x: 5, y: 25)
        let target = CGPoint(x: 55, y: 25)
        let pointMap = NavigationMap(
            origin: .zero,
            columns: 6,
            rows: 5,
            cellSize: CGSize(width: 10, height: 10),
            obstacles: [lowerBlock, upperBlock]
        )
        let actorMap = NavigationMap(
            origin: .zero,
            columns: 6,
            rows: 5,
            cellSize: CGSize(width: 10, height: 10),
            obstacles: [lowerBlock, upperBlock],
            agentProfile: NavigationAgentProfile(halfWidth: 2, halfHeight: 4)
        )

        #expect(pointMap.path(from: start, to: target) == [target])
        #expect(actorMap.path(from: start, to: target) == nil)
    }

    @Test func actorFootprintTreatsNavigationBoundaryAsSolid() {
        let pointMap = NavigationMap(
            origin: .zero,
            columns: 4,
            rows: 4,
            cellSize: CGSize(width: 10, height: 10),
            obstacles: []
        )
        let actorMap = NavigationMap(
            origin: .zero,
            columns: 4,
            rows: 4,
            cellSize: CGSize(width: 10, height: 10),
            obstacles: [],
            agentProfile: NavigationAgentProfile(halfWidth: 4, halfHeight: 4)
        )
        let start = CGPoint(x: 15, y: 15)
        let edge = CGPoint(x: 1, y: 15)

        #expect(pointMap.path(from: start, to: edge) == [edge])
        #expect(actorMap.path(from: start, to: edge) == nil)
    }

    @Test func everyOfficeHotspotApproachIsReachable() {
        let map = OfficeNavigationLayout.makeGrid()

        for (hotspotID, destination) in OfficeNavigationLayout.approachPoints {
            // Scenes use route() so blocked taps can snap to a nearby stand point.
            let route = map.route(from: OfficeNavigationLayout.actorStart, to: destination)
            #expect(route?.waypoints.isEmpty == false, "Expected a route to \(hotspotID)")
        }
    }

    @Test func waypointsVisitingRoutesAroundAWall() {
        let wall = CGRect(x: 10, y: 0, width: 10, height: 30)
        let map = makeMap(obstacles: [wall])
        let anchors = [
            CGPoint(x: 5, y: 5),
            CGPoint(x: 15, y: 5),
            CGPoint(x: 25, y: 5)
        ]
        let path = map.waypoints(visiting: anchors)
        #expect(path != nil)
        guard let path else { return }
        #expect(path.count >= 2)
        #expect(path.allSatisfy { !wall.contains($0) })
        #expect(path.first == CGPoint(x: 5, y: 5))
        #expect(path.last == CGPoint(x: 25, y: 5))
    }

    @Test func officeClientArrivalCrossesPartitionApertureOnce() {
        let map = OfficeNavigationLayout.makeGrid(entranceDoorBlocking: false)
        let path = OfficeNavigationLayout.clientArrivalRoute(in: map)
        #expect(path.count >= 2)
        #expect(path.dropFirst().allSatisfy { !OfficeNavigationLayout.isBlocked($0) })

        let crossings = partitionMidlineCrossings(along: path)
        #expect(crossings.count == 1, "Arrival must cross the partition exactly once")
        if let crossingB = crossings.first {
            let door0 = OfficeNavigationLayout.Architecture.partitionDoorB0
            let door1 = OfficeNavigationLayout.Architecture.partitionDoorB1
            #expect(
                crossingB >= door0 && crossingB <= door1,
                "Partition crossing b=\(crossingB) must lie inside the painted aperture"
            )
        }

        for index in 0..<(path.count - 1) {
            let a = path[index]
            let b = path[index + 1]
            if isAuthoredExteriorDoorwayLeg(from: a, to: b) { continue }
            #expect(
                !segmentCrossesOfficeObstacle(from: a, to: b),
                "Arrival leg \(index) crossed an office obstacle"
            )
        }
    }

    @Test func officeClientDepartureRetracesInteriorThenCrossesExteriorDoor() {
        let map = OfficeNavigationLayout.makeGrid(entranceDoorBlocking: false)
        let path = OfficeNavigationLayout.clientDepartureRoute(in: map)
        #expect(path.count >= 2)
        #expect(path.dropLast().allSatisfy { !OfficeNavigationLayout.isBlocked($0) })
        guard path.count >= 2 else { return }

        let crossings = partitionMidlineCrossings(along: path)
        #expect(crossings.count == 1, "Departure must cross the partition exactly once")
        if let crossingB = crossings.first {
            let door0 = OfficeNavigationLayout.Architecture.partitionDoorB0
            let door1 = OfficeNavigationLayout.Architecture.partitionDoorB1
            #expect(crossingB >= door0 && crossingB <= door1)
        }
    }

    @Test func partitionApertureClearsPaintedFrameNotAdjacentWall() {
        let arch = OfficeNavigationLayout.Architecture.self
        let aFace = arch.partitionLineA + arch.partitionThicknessA
        let faceOriginX = arch.rearCorner.x + aFace * arch.axisNW.dx
        let stileB = (arch.internalHingePlateX - faceOriginX) / arch.axisNE.dx

        #expect(abs(stileB - 0.752) < 0.01)
        #expect(abs(arch.partitionDoorB0 - 0.752) < 0.001)
        #expect(abs(arch.partitionDoorB1 - 0.800) < 0.001)

        let map = OfficeNavigationLayout.makeGrid()
        for frameB: CGFloat in [0.760, 0.776, 0.790] {
            let frameProbe = OfficeInteriorScale.mapPoint(
                authoredPoint(a: aFace - 0.02, b: frameB)
            )
            #expect(
                !OfficeNavigationLayout.isBlocked(frameProbe),
                "Frame cell at b=\(frameB) must stay open"
            )
        }
        for glassB: CGFloat in [0.55, 0.62, 0.66, 0.686, 0.720, 0.850] {
            let glassProbe = OfficeInteriorScale.mapPoint(
                authoredPoint(a: aFace - 0.02, b: glassB)
            )
            #expect(
                OfficeNavigationLayout.isBlocked(glassProbe),
                "Glass at b=\(glassB) must stay blocked"
            )
        }

        for step in 1...8 {
            let b = arch.partitionDoorB1 + CGFloat(step) * 0.05
            guard b < 0.95 else { break }
            let waitingSide = OfficeInteriorScale.mapPoint(
                authoredPoint(a: arch.partitionLineA - 0.09, b: b)
            )
            let officeSide = OfficeInteriorScale.mapPoint(
                authoredPoint(a: aFace + 0.09, b: b)
            )
            guard !OfficeNavigationLayout.isBlocked(waitingSide),
                  !OfficeNavigationLayout.isBlocked(officeSide),
                  let crossed = map.path(from: waitingSide, to: officeSide) else { continue }
            for crossingB in partitionMidlineCrossings(along: crossed) {
                #expect(
                    crossingB >= arch.partitionDoorB0 && crossingB <= arch.partitionDoorB1,
                    "Crossing at b=\(b) walked the wall instead of the painted door frame"
                )
            }
        }
    }

    @Test func nearestWalkableSearchesPastLargeObstacles() {
        let obstacle = CGRect(x: 0, y: 0, width: 110, height: 110)
        let map = NavigationMap(
            origin: .zero,
            columns: 15,
            rows: 15,
            cellSize: CGSize(width: 10, height: 10),
            obstacles: [obstacle]
        )

        let resolved = map.nearestWalkablePoint(to: CGPoint(x: 55, y: 55))

        #expect(resolved != nil)
        if let resolved {
            #expect(!obstacle.contains(resolved))
        }
    }

    @Test func distinguishesAlreadyThereFromUnreachable() {
        let map = makeMap()
        #expect(map.path(from: CGPoint(x: 5, y: 5), to: CGPoint(x: 5, y: 5)) == [])

        let outside = map.path(
            from: CGPoint(x: 5, y: 5),
            to: CGPoint(x: -50, y: -50)
        )
        #expect(outside == nil)
    }

    @Test func officeUsesWorldSpaceSearchMapCells() {
        let map = OfficeNavigationLayout.makeGrid()
        #expect(map.searchMap.cellSize.width == SearchMap.defaultCellSize.width)
        #expect(map.searchMap.cellSize.height == SearchMap.defaultCellSize.height)
        #expect(map.searchMap.columns > 30)
        #expect(map.searchMap.rows > 30)
    }

    @Test func officeDoorObstacleIsPresentInShippedLayout() {
        #expect(OfficeNavigationLayout.obstacles.contains(where: { $0 == OfficeNavigationLayout.doorObstacle }))
        #expect(OfficeNavigationLayout.authoredDoorObstacle.width > 0)
        #expect(OfficeNavigationLayout.authoredDoorObstacle.height > 0)
    }

    @Test func fallenEntranceDoorClearsDoorStampWithoutRebuild() {
        let map = OfficeNavigationLayout.makeGrid(entranceDoorBlocking: true)
        let closedCount = map.impassableCellCount
        map.setEntranceDoorBlocking(false)
        let openCount = map.impassableCellCount
        #expect(closedCount > openCount)

        let closed = OfficeNavigationLayout.makeGrid(entranceDoorBlocking: true)
        let open = OfficeNavigationLayout.makeGrid(entranceDoorBlocking: false)
        #expect(closed.impassableCellCount > open.impassableCellCount)
    }

    @Test func cityDistrictIsMateriallyLargerThanTheOffice() {
        let cityArea = CityDistrictLayout.worldArtSize.width * CityDistrictLayout.worldArtSize.height
        let officeArea = OfficeInteriorScale.scaledArtSize.width * OfficeInteriorScale.scaledArtSize.height

        #expect(cityArea > officeArea)
        #expect(CityDistrictLayout.environmentScale == 1)
    }

    @Test func cityEntranceStartsOnWalkableStreet() {
        let map = CityDistrictLayout.makeGrid()
        let start = CityDistrictLayout.actorStart

        #expect(CityDistrictLayout.worldBounds.contains(start))
        #expect(!CityDistrictLayout.isBlocked(start))
        #expect(map.path(from: start, to: start) == [])
    }

    @Test func cityLandmarksAreReachableThroughStreetNetwork() {
        let map = CityDistrictLayout.makeGrid()
        for pointOfInterest in CityDistrictLayout.pointsOfInterest {
            let path = map.path(
                from: CityDistrictLayout.actorStart,
                to: pointOfInterest.worldPoint
            )
            #expect(path != nil, "Expected a route to \(pointOfInterest.label)")
        }
    }

    @Test func cityUsesIndependentBuildingAndStreetSprites() {
        let sprites = CityDistrictLayout.visualSprites
        let textureNames = sprites.map(\.textureName)

        #expect(sprites.count >= 15)
        #expect(textureNames.contains("city_building_voss_stoop"))
        #expect(textureNames.contains("city_building_tenement"))
        #expect(textureNames.contains("city_building_storefront"))
        #expect(textureNames.contains("city_door_voss_stoop"))
        #expect(textureNames.contains("city_door_tenement"))
        #expect(textureNames.contains("city_door_storefront"))
        #expect(textureNames.contains("city_prop_lamp"))
        #expect(textureNames.contains("city_prop_statue"))
        #expect(textureNames.contains("city_prop_bench"))
        #expect(textureNames.contains("city_prop_car_black"))
        #expect(textureNames.contains("city_prop_car_olive"))
        #expect(textureNames.contains("city_prop_car_maroon"))
        #expect(textureNames.contains("city_prop_kiosk"))
        #expect(textureNames.contains("city_prop_crates_mail"))
        #expect(textureNames.contains("city_prop_gate"))
        #expect(sprites.allSatisfy { CityDistrictLayout.worldBounds.contains($0.groundPoint) })
    }

    // MARK: - Theta* / occupancy / node budget

    @Test func thetaStarTakesAnyAngleShortcutWhenLOSIsClear() {
        let map = makeMap()
        let path = map.path(from: CGPoint(x: 5, y: 5), to: CGPoint(x: 35, y: 20))
        #expect(path == [CGPoint(x: 35, y: 20)])
    }

    @Test func nodeBudgetCutoffCanFailLongSearches() {
        let wall = CGRect(x: 20, y: 0, width: 10, height: 40)
        let map = NavigationMap(
            worldBounds: CGRect(x: 0, y: 0, width: 50, height: 50),
            obstacles: [wall],
            agentProfile: .point,
            maxNodes: 2
        )
        let path = map.path(from: CGPoint(x: 5, y: 25), to: CGPoint(x: 45, y: 25))
        #expect(path == nil)
    }

    @Test func actorOccupancyBlocksWhenActorsAreHardBlockers() {
        let map = makeMap()
        map.registerActor(
            id: "blocker",
            kind: .npc,
            at: CGPoint(x: 20, y: 5),
            radius: 4,
            isMoving: false
        )
        map.occupancy.setBumpable(id: "blocker", bumpable: false)

        let blocked = map.pathAvoidingActors(
            from: CGPoint(x: 5, y: 5),
            to: CGPoint(x: 35, y: 5)
        )
        // With a hard blocker on the direct line, path may go around or fail.
        if let blocked {
            #expect(blocked.allSatisfy { hypot($0.x - 20, $0.y - 5) > 3 })
        }
    }

    @Test func bumpRequestOffersSidestepForIdleActor() {
        let map = makeMap()
        map.registerActor(
            id: "mover",
            kind: .player,
            at: CGPoint(x: 5, y: 5),
            radius: 3,
            isMoving: true
        )
        map.registerActor(
            id: "idle",
            kind: .npc,
            at: CGPoint(x: 8, y: 5),
            radius: 3,
            isMoving: false
        )

        let bump = map.occupancy.bumpRequest(
            forMover: "mover",
            at: CGPoint(x: 8, y: 5),
            moverRadius: 3
        )
        #expect(bump?.actorID == "idle")
        #expect(bump != nil)
        if let bump {
            #expect(hypot(bump.sidestepPoint.x - bump.returnPoint.x,
                          bump.sidestepPoint.y - bump.returnPoint.y) > 0.5)
        }
    }

    @Test func congestionBackOffAfterRepeatedBlocks() {
        let occupancy = ActorOccupancy()
        occupancy.maxCongestionRetries = 3
        #expect(occupancy.recordCongestion(for: "mover") == false)
        #expect(occupancy.recordCongestion(for: "mover") == false)
        #expect(occupancy.recordCongestion(for: "mover") == true)
        occupancy.clearCongestion(for: "mover")
        #expect(occupancy.recordCongestion(for: "mover") == false)
    }

    @Test func minDistanceStopsShortOfBlockedGoal() {
        let obstacle = CGRect(x: 30, y: 0, width: 10, height: 40)
        let map = NavigationMap(
            origin: .zero,
            columns: 5,
            rows: 5,
            cellSize: CGSize(width: 10, height: 10),
            obstacles: [obstacle]
        )
        let finder = PathFinder(searchMap: map.searchMap)
        // Goal sits inside the wall; minDistance should stop on the near side.
        let path = finder.findPath(
            from: CGPoint(x: 5, y: 20),
            to: CGPoint(x: 35, y: 20),
            actorRadius: 0,
            minDistance: 12
        )
        #expect(path != nil)
        if let path, let last = path.last {
            #expect(hypot(last.x - 35, last.y - 20) >= 10)
            #expect(last.x < 30)
        }
    }

    // MARK: - Helpers

    private func authoredPoint(a: CGFloat, b: CGFloat) -> CGPoint {
        let arch = OfficeNavigationLayout.Architecture.self
        let x = arch.rearCorner.x + a * arch.axisNW.dx + b * arch.axisNE.dx
        let y = arch.rearCorner.y - a * arch.axisNW.dy - b * arch.axisNE.dy
        return CGPoint(x: x, y: y)
    }

    private func isAuthoredExteriorDoorwayLeg(from start: CGPoint, to end: CGPoint) -> Bool {
        let doorway = OfficeNavigationLayout.clientDoorwayPath
        return doorway.indices.dropLast().contains { index in
            let next = doorway.index(after: index)
            return (doorway[index] == start && doorway[next] == end)
                || (doorway[index] == end && doorway[next] == start)
        }
    }

    private func segmentCrossesOfficeObstacle(from start: CGPoint, to end: CGPoint) -> Bool {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = hypot(dx, dy)
        let samples = max(2, Int(ceil(length / 4)))
        for sample in 0...samples {
            let t = CGFloat(sample) / CGFloat(samples)
            let point = CGPoint(x: start.x + dx * t, y: start.y + dy * t)
            if OfficeNavigationLayout.isBlocked(point) {
                return true
            }
        }
        return false
    }

    private func officePlan(for authored: CGPoint) -> (a: CGFloat, b: CGFloat) {
        let arch = OfficeNavigationLayout.Architecture.self
        let artHeight: CGFloat = 2_304
        let rear = CGPoint(x: arch.rearCorner.x, y: artHeight - arch.rearCorner.y)
        let axisNW = arch.axisNW
        let axisNE = arch.axisNE
        let det = axisNW.dx * axisNE.dy - axisNE.dx * axisNW.dy
        let dx = authored.x - rear.x
        let dy = (artHeight - authored.y) - rear.y
        let a = (dx * axisNE.dy - axisNE.dx * dy) / det
        let b = (axisNW.dx * dy - dx * axisNW.dy) / det
        return (a, b)
    }

    private func partitionMidlineCrossings(along path: [CGPoint]) -> [CGFloat] {
        let arch = OfficeNavigationLayout.Architecture.self
        let aMid = arch.partitionLineA + arch.partitionThicknessA * 0.5
        var crossings: [CGFloat] = []
        for index in 0..<(path.count - 1) {
            let start = officePlan(for: OfficeInteriorScale.unmapPoint(path[index]))
            let end = officePlan(for: OfficeInteriorScale.unmapPoint(path[index + 1]))
            let deltaA = end.a - start.a
            guard abs(deltaA) > 1e-6 else { continue }
            if (start.a - aMid) * (end.a - aMid) > 0 { continue }
            let t = (aMid - start.a) / deltaA
            crossings.append(start.b + t * (end.b - start.b))
        }
        return crossings
    }

    private func makeMap(obstacles: [CGRect] = []) -> NavigationMap {
        NavigationMap(
            origin: .zero,
            columns: 4,
            rows: 4,
            cellSize: CGSize(width: 10, height: 10),
            obstacles: obstacles
        )
    }
}

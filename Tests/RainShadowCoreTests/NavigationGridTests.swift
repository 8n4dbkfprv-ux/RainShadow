import CoreGraphics
import Testing
@testable import RainShadowCore

struct NavigationGridTests {
    @Test func choosesShortestOpenDiagonal() {
        let grid = makeGrid()

        let path = grid.path(
            from: CGPoint(x: 5, y: 5),
            to: CGPoint(x: 25, y: 25)
        )

        #expect(path == [CGPoint(x: 25, y: 25)])
    }

    @Test func routesAroundBlockedCells() {
        let wall = CGRect(x: 10, y: 0, width: 10, height: 30)
        let grid = makeGrid(obstacles: [wall])

        let path = grid.path(
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
        let grid = makeGrid(obstacles: [right, above])

        let path = grid.path(
            from: CGPoint(x: 5, y: 5),
            to: CGPoint(x: 15, y: 15)
        )

        #expect(path == nil)
    }

    @Test func selectsNearbyWalkablePointForBlockedTap() {
        let obstacle = CGRect(x: 10, y: 10, width: 10, height: 10)
        let grid = makeGrid(obstacles: [obstacle])

        let resolved = grid.nearestWalkablePoint(to: CGPoint(x: 15, y: 15))

        #expect(resolved != nil)
        #expect(resolved != CGPoint(x: 15, y: 15))
        if let resolved {
            #expect(!obstacle.contains(resolved))
        }
    }

    @Test func sameCellRouteCannotCrossAThinObstacle() {
        let thinBarrier = CGRect(x: 5.4, y: 0, width: 0.2, height: 10)
        let grid = NavigationGrid(
            origin: .zero,
            columns: 1,
            rows: 1,
            cellSize: CGSize(width: 10, height: 10),
            obstacles: [thinBarrier]
        )

        // The cell center remains walkable, so only full-segment clearance can
        // catch the barrier between these two points.
        #expect(grid.blocked.isEmpty)
        #expect(grid.path(
            from: CGPoint(x: 2, y: 5),
            to: CGPoint(x: 8, y: 5)
        ) == nil)
    }

    @Test func disconnectedDestinationFallsBackToReachableSideOfWall() {
        let sealedWall = CGRect(x: 20, y: 0, width: 10, height: 50)
        let grid = NavigationGrid(
            origin: .zero,
            columns: 5,
            rows: 5,
            cellSize: CGSize(width: 10, height: 10),
            obstacles: [sealedWall]
        )

        let route = grid.route(
            from: CGPoint(x: 5, y: 25),
            to: CGPoint(x: 35, y: 25),
            maximumFallbackCellRadius: 2
        )

        #expect(route?.destinationWasAdjusted == true)
        #expect(route?.resolvedDestination == CGPoint(x: 15, y: 25))
        #expect(route?.waypoints.last == route?.resolvedDestination)
    }

    @Test func fallbackSearchDoesNotJumpBeyondItsBoundedRing() {
        let sealedWall = CGRect(x: 20, y: 0, width: 10, height: 50)
        let grid = NavigationGrid(
            origin: .zero,
            columns: 5,
            rows: 5,
            cellSize: CGSize(width: 10, height: 10),
            obstacles: [sealedWall]
        )

        let route = grid.route(
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
        let pointGrid = NavigationGrid(
            origin: .zero,
            columns: 6,
            rows: 5,
            cellSize: CGSize(width: 10, height: 10),
            obstacles: [lowerBlock, upperBlock]
        )
        let actorGrid = NavigationGrid(
            origin: .zero,
            columns: 6,
            rows: 5,
            cellSize: CGSize(width: 10, height: 10),
            obstacles: [lowerBlock, upperBlock],
            agentProfile: NavigationAgentProfile(halfWidth: 2, halfHeight: 4)
        )

        #expect(pointGrid.path(from: start, to: target) == [target])
        #expect(actorGrid.path(from: start, to: target) == nil)
    }

    @Test func actorFootprintTreatsNavigationBoundaryAsSolid() {
        let pointGrid = NavigationGrid(
            origin: .zero,
            columns: 4,
            rows: 4,
            cellSize: CGSize(width: 10, height: 10),
            obstacles: []
        )
        let actorGrid = NavigationGrid(
            origin: .zero,
            columns: 4,
            rows: 4,
            cellSize: CGSize(width: 10, height: 10),
            obstacles: [],
            agentProfile: NavigationAgentProfile(halfWidth: 4, halfHeight: 4)
        )
        let start = CGPoint(x: 15, y: 15)
        let edge = CGPoint(x: 1, y: 15)

        #expect(pointGrid.path(from: start, to: edge) == [edge])
        #expect(actorGrid.path(from: start, to: edge) == nil)
    }

    @Test func everyOfficeHotspotApproachIsReachable() {
        let grid = OfficeNavigationLayout.makeGrid()

        for (hotspotID, destination) in OfficeNavigationLayout.approachPoints {
            let path = grid.path(from: OfficeNavigationLayout.actorStart, to: destination)
            #expect(path?.isEmpty == false, "Expected a route to \(hotspotID)")
        }
    }

    @Test func waypointsVisitingRoutesAroundAWall() {
        let wall = CGRect(x: 10, y: 0, width: 10, height: 30)
        let grid = makeGrid(obstacles: [wall])
        // Three anchors: west of wall, (blocked midpoint on wall), east of wall.
        let anchors = [
            CGPoint(x: 5, y: 5),
            CGPoint(x: 15, y: 5),
            CGPoint(x: 25, y: 5)
        ]
        let path = grid.waypoints(visiting: anchors)
        #expect(path != nil)
        guard let path else { return }
        #expect(path.count >= 2)
        #expect(path.allSatisfy { !wall.contains($0) })
        #expect(path.first == CGPoint(x: 5, y: 5))
        #expect(path.last == CGPoint(x: 25, y: 5))
    }

    @Test func officeClientArrivalCrossesBothPaintedDoorsWithoutInteriorCollisions() {
        let grid = OfficeNavigationLayout.makeGrid()
        let path = OfficeNavigationLayout.clientArrivalRoute(in: grid)
        let doorway = OfficeNavigationLayout.clientDoorwayPath
        let exteriorDoor = OfficeInteriorScale.mapPoint(
            OfficeNavigationLayout.Architecture.entranceAnchor
        )

        #expect(path.count >= OfficeNavigationLayout.clientArrivalPath.count)
        #expect(path.first == doorway.first)
        #expect(path.dropFirst().allSatisfy { !OfficeNavigationLayout.isBlocked($0) })
        #expect(doorway.count == 2)
        guard doorway.count == 2, path.count >= 2 else { return }

        // Regression: the crossing must not merely hit the broad door/wall
        // obstacle; it must intersect the NE wall at the painted threshold.
        #expect(doorway[0].x > exteriorDoor.x)
        #expect(doorway[1].x < exteriorDoor.x)
        #expect(segmentCrossesOfficeObstacle(from: doorway[0], to: doorway[1]))
        let thresholdProgress =
            (exteriorDoor.x - doorway[0].x) / (doorway[1].x - doorway[0].x)
        let crossingY =
            doorway[0].y + (doorway[1].y - doorway[0].y) * thresholdProgress
        #expect(abs(crossingY - exteriorDoor.y) < 0.5)

        let internalDoorway = OfficeNavigationLayout.clientInternalDoorwayPath
        #expect(internalDoorway.count == 3)
        guard internalDoorway.count == 3,
              let thresholdIndex = path.firstIndex(of: internalDoorway[1]),
              thresholdIndex > 0,
              thresholdIndex + 1 < path.count else {
            #expect(Bool(false), "Production internal doorway must be present in the arrival route")
            return
        }
        #expect(internalDoorway[1] == OfficeInteriorScale.mapPoint(
            CGPoint(x: 1_820, y: 1_365)
        ))
        #expect(path[thresholdIndex - 1] == internalDoorway[0])
        #expect(path[thresholdIndex + 1] == internalDoorway[2])
        #expect(internalDoorway.allSatisfy { !OfficeNavigationLayout.isBlocked($0) })

        // The intermediate waiting-room anchors stay in the aisle between the
        // chair backs and the partition. The former a=0.100 detour was legal
        // for Lila's small contact core but put her rendered coat through the
        // exterior wall at the red-marked position.
        let waitingClearance = OfficeNavigationLayout.clientWaitingRoomPath
            .dropFirst()
            .dropLast()
            .map(authoredPlanCoordinates)
        #expect(waitingClearance.count == 3)
        for point in waitingClearance {
            #expect(point.x >= 0.260)
            #expect(point.x <= 0.280)
        }
        let expandedWaitingRoute = path
            .map(authoredPlanCoordinates)
            .filter { $0.y >= 0.260 && $0.y <= 0.760 }
        #expect(!expandedWaitingRoute.isEmpty)
        for point in expandedWaitingRoute {
            #expect(
                point.x >= 0.240 && point.x <= 0.300,
                "Expanded client route must not return to either waiting-room wall"
            )
        }

        // Every authored interior anchor survives expansion in order. This keeps
        // the route in the rear framed doorway and prevents the old foreground
        // cutaway → wall → desk recovery loop.
        var priorAnchorIndex = -1
        for anchor in OfficeNavigationLayout.clientInteriorArrivalPath {
            guard let anchorIndex = path.firstIndex(of: anchor) else {
                #expect(Bool(false), "Interior doorway anchor \(anchor) must remain in the route")
                return
            }
            #expect(anchorIndex > priorAnchorIndex)
            priorAnchorIndex = anchorIndex
        }

        // Every interior leg avoids the real partition and furniture. Only the
        // authored exterior crossing passes through the closed-leaf obstacle.
        for index in 0..<(path.count - 1) {
            let a = path[index]
            let b = path[index + 1]
            if isAuthoredExteriorDoorwayLeg(from: a, to: b) { continue }
            #expect(
                !segmentCrossesOfficeObstacle(from: a, to: b),
                "Arrival leg \(index) crossed an office obstacle"
            )
        }

        let authoredInterior = path.dropFirst().map(OfficeInteriorScale.unmapPoint)
        #expect(
            authoredInterior.allSatisfy { $0.y > 1_150 },
            "Arrival must remain in the rear corridor instead of diving to the foreground cutaway"
        )
        let routeLength = zip(path, path.dropFirst()).reduce(CGFloat.zero) { total, leg in
            total + hypot(leg.1.x - leg.0.x, leg.1.y - leg.0.y)
        }
        #expect(routeLength < 475, "Arrival should not restore the old wall/desk detour")
    }

    @Test func officeClientDepartureRetracesInteriorThenCrossesExteriorDoor() {
        let grid = OfficeNavigationLayout.makeGrid()
        let path = OfficeNavigationLayout.clientDepartureRoute(in: grid)
        #expect(path.count >= 2)
        #expect(path.dropLast().allSatisfy { !OfficeNavigationLayout.isBlocked($0) })
        guard path.count >= 2 else { return }

        for index in 0..<(path.count - 1) {
            if isAuthoredExteriorDoorwayLeg(from: path[index], to: path[index + 1]) { continue }
            #expect(!segmentCrossesOfficeObstacle(from: path[index], to: path[index + 1]))
        }
        #expect(segmentCrossesOfficeObstacle(
            from: path[path.count - 2],
            to: path[path.count - 1]
        ))
    }

    private func isAuthoredExteriorDoorwayLeg(from start: CGPoint, to end: CGPoint) -> Bool {
        let doorway = OfficeNavigationLayout.clientDoorwayPath
        return doorway.indices.dropLast().contains { index in
            let next = doorway.index(after: index)
            return (doorway[index] == start && doorway[next] == end)
                || (doorway[index] == end && doorway[next] == start)
        }
    }

    private func authoredPlanCoordinates(_ worldPoint: CGPoint) -> CGPoint {
        let point = OfficeInteriorScale.unmapPoint(worldPoint)
        let architecture = OfficeNavigationLayout.Architecture.self
        let dx = point.x - architecture.rearCorner.x
        let dy = architecture.rearCorner.y - point.y
        let determinant =
            architecture.axisNW.dx * architecture.axisNE.dy
            - architecture.axisNE.dx * architecture.axisNW.dy
        return CGPoint(
            x: (dx * architecture.axisNE.dy - architecture.axisNE.dx * dy)
                / determinant,
            y: (architecture.axisNW.dx * dy - dx * architecture.axisNW.dy)
                / determinant
        )
    }

    /// Sampled segment test against the authored (mapped) office obstacle list.
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

    @Test func dimetricProjectionRoundTripsAuthoredCells() {
        let projection = NavigationProjection.dimetric(
            origin: CGPoint(x: 100, y: 40),
            tileSize: CGSize(width: 128, height: 64)
        )

        for cell in [
            NavigationCell(column: 0, row: 0),
            NavigationCell(column: 7, row: 3),
            NavigationCell(column: 2, row: 9)
        ] {
            #expect(projection.cell(for: projection.point(for: cell)) == cell)
        }
    }

    @Test func nearestWalkableSearchesPastLargeObstacles() {
        let obstacle = CGRect(x: 0, y: 0, width: 110, height: 110)
        let grid = NavigationGrid(
            origin: .zero,
            columns: 15,
            rows: 15,
            cellSize: CGSize(width: 10, height: 10),
            obstacles: [obstacle]
        )

        let resolved = grid.nearestWalkablePoint(to: CGPoint(x: 55, y: 55))

        #expect(resolved != nil)
        if let resolved {
            #expect(!obstacle.contains(resolved))
        }
    }

    @Test func distinguishesAlreadyThereFromUnreachable() {
        let grid = makeGrid()
        #expect(grid.path(from: CGPoint(x: 5, y: 5), to: CGPoint(x: 5, y: 5)) == [])

        let outside = grid.path(
            from: CGPoint(x: 5, y: 5),
            to: CGPoint(x: -50, y: -50)
        )
        #expect(outside == nil)
    }

    @Test func officeUsesTwoToOneDimetricProjection() {
        let grid = OfficeNavigationLayout.makeGrid()
        #expect(grid.projection.kind == .dimetric)
        #expect(abs(grid.projection.tileSize.width / grid.projection.tileSize.height - 2) < 0.001)
    }

    @Test func officeDoorObstacleIsPresentInShippedLayout() {
        #expect(OfficeNavigationLayout.obstacles.contains(where: { $0 == OfficeNavigationLayout.doorObstacle }))
        #expect(OfficeNavigationLayout.authoredDoorObstacle.width > 0)
        #expect(OfficeNavigationLayout.authoredDoorObstacle.height > 0)
    }

    @Test func cityDistrictIsMateriallyLargerThanTheOffice() {
        let cityArea = CityDistrictLayout.worldArtSize.width * CityDistrictLayout.worldArtSize.height
        let officeArea = OfficeInteriorScale.scaledArtSize.width * OfficeInteriorScale.scaledArtSize.height

        #expect(cityArea > officeArea * 4)
        #expect(CityDistrictLayout.environmentScale == 2)
    }

    @Test func cityEntranceStartsOnWalkableStreet() {
        let grid = CityDistrictLayout.makeGrid()
        let start = CityDistrictLayout.actorStart

        #expect(CityDistrictLayout.worldBounds.contains(start))
        #expect(!CityDistrictLayout.isBlocked(start))
        #expect(grid.path(from: start, to: start) == [])
    }

    @Test func cityLandmarksAreReachableThroughStreetNetwork() {
        let grid = CityDistrictLayout.makeGrid()
        for pointOfInterest in CityDistrictLayout.pointsOfInterest {
            let path = grid.path(
                from: CityDistrictLayout.actorStart,
                to: pointOfInterest.worldPoint
            )
            #expect(path != nil, "Expected a route to \(pointOfInterest.label)")
        }
    }

    @Test func cityUsesIndependentBuildingAndStreetSprites() {
        let sprites = CityDistrictLayout.visualSprites
        let textureNames = sprites.map(\.textureName)

        #expect(sprites.count >= 30)
        #expect(textureNames.contains("city_building_nw"))
        #expect(textureNames.contains("city_building_central"))
        #expect(textureNames.contains("city_building_ne"))
        #expect(textureNames.contains("city_building_sw"))
        #expect(textureNames.contains("city_building_mid"))
        #expect(textureNames.contains("city_building_se"))
        #expect(textureNames.contains("city_lamp"))
        #expect(textureNames.contains("city_statue"))
        #expect(textureNames.contains("city_bench"))
        #expect(textureNames.contains("city_car_black"))
        #expect(textureNames.contains("city_car_olive"))
        #expect(textureNames.contains("city_car_maroon"))
        #expect(textureNames.contains("city_kiosk"))
        #expect(textureNames.contains("city_crates_mail"))
        #expect(textureNames.contains("city_gate"))
        #expect(sprites.allSatisfy { CityDistrictLayout.worldBounds.contains($0.groundPoint) })
    }

    private func makeGrid(obstacles: [CGRect] = []) -> NavigationGrid {
        NavigationGrid(
            origin: .zero,
            columns: 4,
            rows: 4,
            cellSize: CGSize(width: 10, height: 10),
            obstacles: obstacles
        )
    }
}

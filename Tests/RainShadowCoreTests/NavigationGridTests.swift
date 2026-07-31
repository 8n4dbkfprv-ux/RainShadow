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

        // Regression: the old start was already west of the doorway, so Lila
        // materialized through the left wall. The authored threshold leg now
        // straddles the painted exterior opening.
        #expect(doorway[0].x > exteriorDoor.x)
        #expect(doorway[1].x < exteriorDoor.x)
        #expect(segmentCrossesOfficeObstacle(from: doorway[0], to: doorway[1]))

        let internalDoorway = OfficeNavigationLayout.clientInternalDoorwayPath
        #expect(internalDoorway.count == 3)
        guard internalDoorway.count == 3,
              let thresholdIndex = path.firstIndex(of: internalDoorway[1]),
              thresholdIndex > 0,
              thresholdIndex + 1 < path.count else {
            #expect(Bool(false), "Production internal doorway must be present in the arrival route")
            return
        }
        // Shipping suite plate frosted doorway (painted clear width, hinge of
        // mid so the coat clears latch frost beside the open leaf).
        let thresholdPlan = officePlan(for: OfficeInteriorScale.unmapPoint(internalDoorway[1]))
        let door0 = OfficeNavigationLayout.Architecture.partitionDoorB0
        let door1 = OfficeNavigationLayout.Architecture.partitionDoorB1
        #expect(thresholdPlan.b > door0 && thresholdPlan.b < door1)
        #expect(abs(thresholdPlan.b - (door0 + (door1 - door0) * 0.40)) < 0.02)
        #expect(path[thresholdIndex - 1] == internalDoorway[0])
        #expect(path[thresholdIndex + 1] == internalDoorway[2])
        #expect(internalDoorway.allSatisfy { !OfficeNavigationLayout.isBlocked($0) })

        // Chair-side clearance ends on the aperture b before the door triad.
        let waitingAuthored = OfficeNavigationLayout.clientWaitingRoomPath.map(
            OfficeInteriorScale.unmapPoint
        )
        #expect(waitingAuthored.count >= 3)
        if let apertureApproach = waitingAuthored.dropLast().last {
            let clearanceB = officePlan(for: apertureApproach).b
            #expect(abs(clearanceB - thresholdPlan.b) < 0.02)
        }

        // Every authored interior anchor survives expansion in order.
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

        // Exactly one partition-midline crossing, and it must land inside the
        // painted aperture — catches the old tip-hole shortcut that never
        // touched a partition obstacle rect.
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

        let authoredInterior = path.dropFirst().map(OfficeInteriorScale.unmapPoint)
        #expect(
            authoredInterior.allSatisfy { $0.y > 1_100 },
            "Arrival must stay on the suite floor instead of diving into the cutaway void"
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

        let crossings = partitionMidlineCrossings(along: path)
        #expect(crossings.count == 1, "Departure must cross the partition exactly once")
        if let crossingB = crossings.first {
            let door0 = OfficeNavigationLayout.Architecture.partitionDoorB0
            let door1 = OfficeNavigationLayout.Architecture.partitionDoorB1
            #expect(crossingB >= door0 && crossingB <= door1)
        }
    }

    /// Painted aperture matches the clear opening (≈0.62–0.71).
    /// Glass on either side must stay blocked so Lila cannot path through it.
    @Test func partitionApertureClearsPaintedFrameNotAdjacentWall() {
        let arch = OfficeNavigationLayout.Architecture.self
        let aFace = arch.partitionLineA + arch.partitionThicknessA
        let faceOriginX = arch.rearCorner.x + aFace * arch.axisNW.dx
        let stileB = (arch.internalHingePlateX - faceOriginX) / arch.axisNE.dx

        #expect(abs(arch.partitionDoorB0 - stileB) < 0.005)
        #expect(abs(arch.partitionDoorB0 - 0.62) < 0.001)
        #expect(abs(arch.partitionDoorB1 - 0.71) < 0.001)
        #expect(arch.partitionReturnB1 > arch.partitionDoorB1)

        let grid = OfficeNavigationLayout.makeGrid()
        for frameB: CGFloat in [0.64, 0.66, 0.68] {
            let frameProbe = OfficeInteriorScale.mapPoint(
                authoredPoint(a: aFace - 0.02, b: frameB)
            )
            #expect(
                !OfficeNavigationLayout.isBlocked(frameProbe),
                "Frame cell at b=\(frameB) must stay open"
            )
        }
        // Hinge-side and latch-side frosted glass stay solid.
        for glassB: CGFloat in [0.50, 0.55, 0.78, 0.85] {
            let glassProbe = OfficeInteriorScale.mapPoint(
                authoredPoint(a: aFace - 0.02, b: glassB)
            )
            #expect(
                OfficeNavigationLayout.isBlocked(glassProbe),
                "Glass at b=\(glassB) must stay blocked"
            )
        }
        let apertureMid = OfficeInteriorScale.mapPoint(
            authoredPoint(a: aFace - 0.01, b: (arch.partitionDoorB0 + arch.partitionDoorB1) * 0.5)
        )
        var sawLatchJamb = false
        for rect in OfficeNavigationLayout.authoredPartitionSegments {
            let mapped = OfficeInteriorScale.mapRect(rect)
            let mid = CGPoint(x: mapped.midX, y: mapped.midY)
            let plan = officePlan(for: OfficeInteriorScale.unmapPoint(mid))
            #expect(
                plan.b < arch.partitionDoorB0 || plan.b > arch.partitionDoorB1,
                "Partition solid centre b=\(plan.b) must stay outside the door aperture"
            )
            #expect(
                !mapped.contains(apertureMid),
                "Partition AABB must not cover the aperture mid-point"
            )
            #expect(rect.width <= 40.5 && rect.height <= 20.5)
            if plan.b > arch.partitionDoorB1 && plan.b < arch.partitionDoorB1 + 0.12 {
                sawLatchJamb = true
            }
        }
        #expect(sawLatchJamb, "Latch-side glass must keep a partition solid just past the door")

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
                  let crossed = grid.path(from: waitingSide, to: officeSide) else { continue }
            for crossingB in partitionMidlineCrossings(along: crossed) {
                #expect(
                    crossingB >= arch.partitionDoorB0 && crossingB <= arch.partitionDoorB1,
                    "Crossing at b=\(b) walked the wall instead of the painted door frame"
                )
            }
        }
    }

    /// Inverse of `officePlan`: plan (a, b) back to an authored layout point (y-up).
    private func authoredPoint(a: CGFloat, b: CGFloat) -> CGPoint {
        let arch = OfficeNavigationLayout.Architecture.self
        // `Architecture.rearCorner` is already y-up (`ART_H - REAR`), matching
        // `office_room_plan.authored`. Do not flip y again.
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

    /// Plan-space (a, b) for an authored layout point. Matches
    /// `office_room_plan.authored_to_plan`.
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

    /// b-coordinates where a world-space polyline crosses the partition midline.
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

    @Test func fallenEntranceDoorOmitsLeafObstacleFromGrid() {
        let closed = OfficeNavigationLayout.makeGrid(entranceDoorBlocking: true)
        let open = OfficeNavigationLayout.makeGrid(entranceDoorBlocking: false)
        #expect(closed.blocked.count > open.blocked.count)
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

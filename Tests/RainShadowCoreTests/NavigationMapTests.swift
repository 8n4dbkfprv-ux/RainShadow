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

    /// The office must be one connected room at the *runtime* search-map
    /// resolution, and every authored approach exactly reachable.
    ///
    /// `office_layout_plan.py` validates its own 128x64 iso grid, which is 2.6x
    /// coarser across and 1.7x taller than the 16x12 world cells the game
    /// actually rasterises to. It once certified ALL CHECKS PASS on a layout
    /// where the detective could reach 174 of 4,694 walkable cells and could not
    /// reach the office door at all — the boundary solids overhung their cells
    /// and ate the floor, and the two partition jambs pinched the doorway shut.
    /// Nothing in Swift caught it because every test used `route`, which snaps to
    /// the nearest *reachable* point and so passes inside any pocket.
    ///
    /// This asserts the thing the planner cannot: connectivity as shipped.
    @Test func officeFloorIsOneConnectedRoomAtRuntimeResolution() {
        for doorBlocking in [true, false] {
            let map = OfficeNavigationLayout.makeGrid(entranceDoorBlocking: doorBlocking)
            let search = map.searchMap
            let radius = NavigationAgentProfile.officeDetective.radius

            var visited = Set<SearchMapCell>()
            var queue = [search.cell(for: OfficeNavigationLayout.actorStart)]
            visited.insert(queue[0])
            var index = 0
            while index < queue.count {
                let cell = queue[index]
                index += 1
                for (dx, dy) in [(1, 0), (0, 1), (-1, 0), (0, -1)] {
                    let next = SearchMapCell(column: cell.column + dx, row: cell.row + dy)
                    guard search.contains(next),
                          !visited.contains(next),
                          search.isPassable(at: search.center(of: next), radius: radius)
                    else { continue }
                    visited.insert(next)
                    queue.append(next)
                }
            }

            // The walkable floor is ~420 cells; 300 leaves room for prop tuning
            // while still failing loudly on a re-seal (the regression was 174).
            #expect(visited.count > 300)

            // Exactly reachable, not merely snap-reachable: scenes issue interact
            // approaches with `requiresExactDestination` and refuse a snapped one.
            for (id, approach) in OfficeNavigationLayout.approachPoints {
                #expect(
                    map.path(from: OfficeNavigationLayout.actorStart, to: approach) != nil,
                    "\(id) has no exact path with entranceDoorBlocking: \(doorBlocking)"
                )
            }
        }
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

        // The refit moved the partition doorway and widened it: b 0.338...0.505,
        // an aperture of 0.167 against the 0.048 these used to assert. The
        // planner's client crossing at b = 0.422 falls inside the new opening,
        // so the geometry is self-consistent at the new coordinates.
        // The painted stile and the navigable aperture are *not* the same
        // measurement and are not meant to match exactly. `office_layout_plan`
        // says so where it defines them: "The navigation partition and
        // `office_partition_opening.json` describe a different generated bake.
        // Keep those values for collision/pathing, but never use them to place
        // the two live leaf sprites against `office_suite_plate.png`."
        //
        // So requiring `stileB == partitionDoorB0` asserts something the design
        // contradicts — they sit 27 plate px apart by construction. What has to
        // hold is containment: the painted frame must fall *inside* the opening
        // the player can walk through, or there is visible door where there is
        // no passage.
        #expect(
            stileB >= arch.partitionDoorB0 && stileB <= arch.partitionDoorB1,
            "painted stile b=\(stileB) is outside the navigable aperture"
        )
        #expect(abs(arch.partitionDoorB0 - 0.338) < 0.001)
        #expect(abs(arch.partitionDoorB1 - 0.505) < 0.001)

        let map = OfficeNavigationLayout.makeGrid()
        // Probes inside the *current* aperture (b 0.338...0.505). These used to
        // sit at 0.760/0.776/0.790, the old opening, which the refit turned into
        // solid partition — so the check was asserting that a wall stays open.
        for frameB: CGFloat in [0.360, 0.420, 0.480] {
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
            // `path` returns the waypoints *after* the start, so the segment
            // that actually crosses the partition — the one from where the actor
            // stands, through the doorway — was never examined. What was measured
            // instead was the leg *leaving* the aperture toward the office side,
            // which naturally ends up at the destination's b and reads as walking
            // through the wall. The route was correct all along: at b 0.555 it
            // goes through the doorway at b 0.488.
            // Tolerance of half a search cell, expressed in plan units rather
            // than guessed: the aperture is authored in b, but the runtime walks
            // a 16x12 raster, so the *rasterised* opening is marginally wider
            // than the authored one and a route may clip its edge. Measured, the
            // worst crossing overshoots by 0.005 — 1.9 world units, an eighth of
            // a cell. Half a cell still catches a route that walks the wall,
            // which is what this is for, without failing on grid granularity.
            let cellB = SearchMap.defaultCellSize.width
                / OfficeInteriorScale.environment
                / abs(arch.axisNE.dx)
            let slack = cellB * 0.5
            for crossingB in partitionMidlineCrossings(along: [waitingSide] + crossed) {
                #expect(
                    crossingB >= arch.partitionDoorB0 - slack
                        && crossingB <= arch.partitionDoorB1 + slack,
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

    /// Every authored point a city district can put the detective on, or send him
    /// to, must be somewhere he can actually stand.
    ///
    /// Harborpoint PD shipped with `actorStart`, its `from.north` arrival spawn,
    /// and the STATION portal approach all *inside* the 820x680 station building —
    /// arriving there left him in a wall with 1 of 5,795 cells reachable. Nothing
    /// caught it because the district tests only checked landmarks via `route`,
    /// which snaps to the nearest reachable point and so passes from anywhere.
    @Test func everyCityDistrictSpawnAndApproachIsStandable() {
        for id in CityDistrictID.allCases {
            let district = CityDistrictCatalog.definition(for: id)
            let map = district.makeGrid()
            let radius = NavigationAgentProfile.detective.radius

            #expect(
                map.searchMap.isPassable(at: district.actorStart, radius: radius),
                "\(id) actorStart \(district.actorStart) is not standable"
            )
            for (key, spawn) in district.spawnByArrivalKey {
                #expect(
                    map.searchMap.isPassable(at: spawn, radius: radius),
                    "\(id) spawn \(key) \(spawn) is not standable"
                )
            }
            // Portal approaches are issued with `requiresExactDestination`, so a
            // snapped route is refused — they must path exactly.
            for portal in district.portals {
                #expect(
                    map.path(from: district.actorStart, to: portal.approachPoint) != nil,
                    "\(id) portal \(portal.id) approach \(portal.approachPoint) has no exact path"
                )
            }
        }
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

    @Test func sableRowOfficePortalApproachIsExact() {
        let district = CityDistrictCatalog.definition(for: .sableRow)
        let portal = district.portals.first { $0.id == "portal.office" }
        #expect(portal != nil)
        guard let portal else { return }

        let map = district.makeGrid()
        let exact = map.path(from: district.actorStart, to: portal.approachPoint)
        #expect(exact != nil)
        let route = map.route(from: district.actorStart, to: portal.approachPoint)
        #expect(route?.destinationWasAdjusted == false)
        #expect(route?.resolvedDestination == portal.approachPoint)
    }

    /// Goal point walkable, goal cell center inside an obstacle — exact path
    /// must still terminate at the requested destination (office door class).
    @Test func exactPathAcceptsDestinationWhenGoalCellCenterIsBlocked() {
        // 16×12 cells; place a thin obstacle over the goal cell center only.
        let cellSize = SearchMap.defaultCellSize
        let worldBounds = CGRect(x: 0, y: 0, width: cellSize.width * 6, height: cellSize.height * 4)
        // Goal in cell (4, 1): center at (4.5*16, 1.5*12) = (72, 18).
        let goalCenter = CGPoint(x: 72, y: 18)
        // Sit toward the east edge so LOS from cell (5, 1) clears the blob.
        let destination = CGPoint(x: 78, y: 22)
        let obstacle = CGRect(
            x: goalCenter.x - 2,
            y: goalCenter.y - 2,
            width: 4,
            height: 4
        )
        let map = NavigationMap(
            worldBounds: worldBounds,
            obstacles: [obstacle],
            agentProfile: .officeDetective,
            doorObstacles: [],
            entranceDoorBlocking: false,
            cellSize: cellSize
        )

        let radius = NavigationAgentProfile.officeDetective.radius
        #expect(map.searchMap.isPassable(at: destination, radius: radius))
        #expect(!map.searchMap.isPassable(at: goalCenter, radius: radius))

        let start = CGPoint(x: 8, y: 18)
        #expect(map.searchMap.isPassable(at: start, radius: radius))

        let path = map.path(from: start, to: destination)
        #expect(path != nil)
        #expect(path?.last == destination)

        let route = map.route(from: start, to: destination)
        #expect(route?.destinationWasAdjusted == false)
    }

    @Test func cityUsesIndependentBuildingAndStreetSprites() {
        let sprites = CityDistrictLayout.visualSprites
        let textureNames = sprites.map(\.textureName)

        #expect(sprites.count >= 15)
        #expect(textureNames.contains("city_sable_lot_harborWest"))
        #expect(textureNames.contains("city_sable_lot_harborVoss"))
        #expect(textureNames.contains("city_sable_lot_upperWest"))
        #expect(textureNames.contains("city_sable_lot_upperEast"))
        #expect(textureNames.contains("city_sable_lot_southWest"))
        #expect(textureNames.contains("city_sable_lot_southEast"))
        #expect(textureNames.contains("city_door_voss_stoop"))
        #expect(textureNames.contains("city_door_tenement"))
        #expect(textureNames.contains("city_door_storefront"))
        #expect(!textureNames.contains(where: { $0.hasPrefix("city_prop_") }))
        // Edge blocks are half off-plate by construction — the lattice's
        // outermost centres sit on the plate boundary — so their frontage is
        // anchored outside the bounds and only its inner half is visible. That
        // is how the plate edge gets buildings instead of bare ground. One
        // block half-diagonal is the most any of it can reach.
        let overhang = CityDistrictLayout.worldBounds.insetBy(
            dx: -CityBlockGrid.halfWidth, dy: -CityBlockGrid.halfHeight
        )
        #expect(sprites.allSatisfy { overhang.contains($0.groundPoint) })

        // Leaves are derived from their facade's aperture, not authored beside it,
        // so every door carries the shared threshold anchor rather than a per-sprite
        // guess. Registration itself is covered by CityDoorRegistrationTests.
        let leaves = sprites.filter { $0.textureName.hasPrefix("city_door_") }
        #expect(!leaves.isEmpty)
        #expect(leaves.allSatisfy { $0.anchorY == CityDistrictLayout.doorLeafAnchorY })
        for leaf in leaves {
            #expect(
                CityDistrictLayout.aperturesByLeafTexture[leaf.textureName] != nil,
                "\(leaf.textureName) has no measured aperture"
            )
        }
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
        let map = makeActorMap()
        let blockerAt = CGPoint(x: 320, y: 240)
        map.registerActor(
            id: "blocker",
            kind: .npc,
            at: blockerAt,
            radius: 16,
            isMoving: false
        )
        map.occupancy.setBumpable(id: "blocker", bumpable: false)

        let blocked = map.pathAvoidingActors(
            from: CGPoint(x: 80, y: 240),
            to: CGPoint(x: 560, y: 240)
        )
        // Avoidance may route around or give up, but it must never walk through
        // the blocker's painted footprint.
        if let blocked {
            #expect(blocked.allSatisfy {
                !map.searchMap.flags(at: $0).contains(.npcActor)
            })
        }
    }

    @Test func bumpRequestOffersSidestepForIdleActor() {
        let map = makeActorMap()
        map.registerActor(
            id: "mover",
            kind: .player,
            at: CGPoint(x: 240, y: 240),
            radius: 16,
            isMoving: true
        )
        let idleAt = CGPoint(x: 288, y: 240)
        map.registerActor(
            id: "idle",
            kind: .npc,
            at: idleAt,
            radius: 16,
            isMoving: false
        )

        let bump = map.occupancy.bumpRequest(
            forMover: "mover",
            at: idleAt,
            moverRadius: 16
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
        let matchesAuthoredPair = doorway.indices.dropLast().contains(where: { index in
            let next = doorway.index(after: index)
            return (doorway[index] == start && doorway[next] == end)
                || (doorway[index] == end && doorway[next] == start)
        })
        if matchesAuthoredPair { return true }
        // Arrival keeps the authored off-floor threshold start as its own leg;
        // the pathfinder may land on a nearby waiting-bay cell rather than the
        // exact second doorway anchor, but the leg still is the exterior cross.
        guard let thresholdStart = doorway.first else { return false }
        return hypot(start.x - thresholdStart.x, start.y - thresholdStart.y) <= 0.25
            || hypot(end.x - thresholdStart.x, end.y - thresholdStart.y) <= 0.25
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

    /// Fixture for anything that places an actor.
    ///
    /// `makeMap` is 40×40 world units — smaller than a single BG:EE personal
    /// space, which stamps `personalSpaceCells - 1` = 3 cells across. Actor tests
    /// on that fixture cannot be meaningful: one body's footprint covers the
    /// whole world, so every sidestep candidate is occupied and every avoidance
    /// query fails for the wrong reason. This is one BG screen at the engine's
    /// own 16×12 cell, which leaves room for two bodies and a gap.
    private func makeActorMap(obstacles: [CGRect] = []) -> NavigationMap {
        NavigationMap(
            origin: .zero,
            columns: 40,
            rows: 40,
            cellSize: SearchMap.defaultCellSize,
            obstacles: obstacles
        )
    }
}

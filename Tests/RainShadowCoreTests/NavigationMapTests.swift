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

        #expect(path.remainingPoints == [CGPoint(x: 25, y: 25)])
    }

    @Test func routesAroundBlockedCells() {
        let wall = CGRect(x: 10, y: 0, width: 10, height: 30)
        let map = makeMap(obstacles: [wall])

        let path = map.path(
            from: CGPoint(x: 5, y: 5),
            to: CGPoint(x: 25, y: 5)
        )

        #expect(path.isPresent)
        #expect(path.destination == CGPoint(x: 25, y: 5))
        #expect(path.remainingPoints.allSatisfy { !wall.contains($0) })
    }

    @Test func doesNotCutAcrossBlockedCorner() {
        let right = CGRect(x: 10, y: 0, width: 10, height: 10)
        let above = CGRect(x: 0, y: 10, width: 10, height: 10)
        let map = makeMap(obstacles: [right, above])

        let path = map.path(
            from: CGPoint(x: 5, y: 5),
            to: CGPoint(x: 15, y: 15)
        )

        #expect(path.isEmpty)
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
        ).isEmpty)
    }

    /// A goal walled off from the caller simply fails.
    ///
    /// The old bounded-ring fallback flood-filled every reachable cell and
    /// walked to the closest one instead. The engine has no such fallback:
    /// `AdjustPositionDirected` only fires when the goal is *itself* blocked, and
    /// a passable-but-disconnected goal is expanded toward until the open set
    /// runs dry. Returning "somewhere else entirely" for an unreachable click is
    /// the behaviour three shipped bugs hid behind.
    @Test func aPassableButDisconnectedDestinationSimplyFails() {
        let sealedWall = CGRect(x: 20, y: 0, width: 10, height: 50)
        let map = NavigationMap(
            origin: .zero,
            columns: 5,
            rows: 5,
            cellSize: CGSize(width: 10, height: 10),
            obstacles: [sealedWall]
        )
        let start = CGPoint(x: 5, y: 25)
        let beyond = CGPoint(x: 35, y: 25)

        #expect(map.isOrderableFloor(beyond), "the far side is standable, just not reachable")
        #expect(map.path(from: start, to: beyond).isEmpty)
        #expect(!map.reachesExactly(from: start, to: beyond))
        #expect(map.route(from: start, to: beyond) == nil)
    }

    /// `AdjustPositionDirected` — a goal that is itself blocked *is* relocated,
    /// by a sparse cone of five orientations cast back toward the caller.
    @Test func aBlockedDestinationIsRelocatedTowardTheCaller() {
        let block = CGRect(x: 20, y: 20, width: 10, height: 10)
        let map = NavigationMap(
            origin: .zero,
            columns: 5,
            rows: 5,
            cellSize: CGSize(width: 10, height: 10),
            obstacles: [block]
        )
        let start = CGPoint(x: 5, y: 25)
        let onTheBlock = CGPoint(x: 25, y: 25)

        #expect(!map.isOrderableFloor(onTheBlock))
        let route = map.route(from: start, to: onTheBlock)
        #expect(route?.destinationWasAdjusted == true)
        if let resolved = route?.resolvedDestination {
            #expect(!block.contains(resolved), "relocated inside the solid")
        }
    }

    /// A corridor one cell wide takes a small body and refuses a large one.
    ///
    /// The axis is `circleSize`, the only clearance the engine has:
    /// `GetBlockedInRadiusTile` tests a disc of `size - 2` cells, so size 2 asks
    /// about the cell alone and size 3 also wants its neighbours. This used to
    /// be written against a world-unit half-extent measured off the obstacle
    /// rectangles, which is the adaptation the literal port removed.
    ///
    /// The corridor is a whole cell tall on purpose. `SearchMap` rasterises
    /// conservatively, so a gap narrower than a cell is not a corridor at all —
    /// it is two solids touching, which is exactly what it looks like to a
    /// person.
    @Test func aOneCellCorridorFitsASmallBodyAndNotALargeOne() {
        let lowerBlock = CGRect(x: 0, y: 0, width: 60, height: 20)
        let upperBlock = CGRect(x: 0, y: 30, width: 60, height: 20)
        let start = CGPoint(x: 5, y: 25)
        let target = CGPoint(x: 55, y: 25)
        func map(circleSize: Int) -> NavigationMap {
            NavigationMap(
                origin: .zero,
                columns: 6,
                rows: 5,
                cellSize: CGSize(width: 10, height: 10),
                obstacles: [lowerBlock, upperBlock],
                agentProfile: NavigationAgentProfile(
                    halfWidth: 0,
                    halfHeight: 0,
                    circleSize: circleSize
                )
            )
        }

        #expect(map(circleSize: 2).reachesExactly(from: start, to: target))
        #expect(!map(circleSize: 3).reachesExactly(from: start, to: target))
    }

    /// The map boundary is solid, and a body wide enough to need its neighbours
    /// cannot stand in the outermost ring.
    ///
    /// There is no boundary inset any more — nothing measures a world-unit disc
    /// against `worldBounds`. The rule falls out of the raster on its own: a
    /// cell outside the grid reads impassable, so `GetBlockedInRadiusTile` on
    /// `circleSize` 3 fails for every edge cell, while `circleSize` 2 asks about
    /// the edge cell alone and is content.
    @Test func theMapBoundaryIsSolidForABodyThatNeedsItsNeighbours() {
        func map(circleSize: Int) -> NavigationMap {
            NavigationMap(
                origin: .zero,
                columns: 4,
                rows: 4,
                cellSize: CGSize(width: 10, height: 10),
                obstacles: [],
                agentProfile: NavigationAgentProfile(
                    halfWidth: 0,
                    halfHeight: 0,
                    circleSize: circleSize
                )
            )
        }
        let start = CGPoint(x: 15, y: 15)
        let edge = CGPoint(x: 5, y: 15)

        #expect(map(circleSize: 2).reachesExactly(from: start, to: edge))
        #expect(!map(circleSize: 3).reachesExactly(from: start, to: edge))
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

            // Exactly reachable as an authoring invariant: interaction range must
            // not hide an approach placed across a wall or in a sealed pocket.
            for (id, approach) in OfficeNavigationLayout.approachPoints {
                #expect(
                    map.reachesExactly(from: OfficeNavigationLayout.actorStart, to: approach),
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
        let points = path.remainingPoints
        #expect(points.count >= 2)
        #expect(points.allSatisfy { !wall.contains($0) })
        #expect(path.destination == CGPoint(x: 25, y: 5))
    }

    @Test func officeClientArrivalUsesClearOpenPlanFloor() {
        let map = OfficeNavigationLayout.makeGrid(entranceDoorBlocking: false)
        let path = OfficeNavigationLayout.clientArrivalRoute(in: map)
        #expect(path.count >= 2)
        #expect(path.dropFirst().allSatisfy { !OfficeNavigationLayout.isBlocked($0) })

        #expect(OfficeNavigationLayout.authoredPartitionSegments.isEmpty)

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

    @Test func officeClientDepartureRetracesOpenPlanInteriorToExteriorDoor() {
        let map = OfficeNavigationLayout.makeGrid(entranceDoorBlocking: false)
        let path = OfficeNavigationLayout.clientDepartureRoute(in: map)
        #expect(path.count >= 2)
        #expect(path.dropLast().allSatisfy { !OfficeNavigationLayout.isBlocked($0) })
        guard path.count >= 2 else { return }

        #expect(OfficeNavigationLayout.authoredPartitionSegments.isEmpty)
        #expect(path.last == OfficeNavigationLayout.clientDoorwayPath.first)
    }

    @Test func openPlanRetiresPartitionGeometryAndKeepsDirectRoute() {
        let arch = OfficeNavigationLayout.Architecture.self
        #expect(arch.partitionLineA == 0)
        #expect(arch.partitionThicknessA == 0)
        #expect(arch.partitionDoorB0 == 0 && arch.partitionDoorB1 == 0)
        #expect(OfficeNavigationLayout.authoredPartitionSegments.isEmpty)
        let map = OfficeNavigationLayout.makeGrid(entranceDoorBlocking: false)
        let start = OfficeNavigationLayout.clientDoorwayPath.last!
        let end = OfficeNavigationLayout.clientOfficeArrivalPath.last!
        #expect(map.path(from: start, to: end).isPresent)
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

    /// The engine does not distinguish "already there" from "nowhere to go".
    ///
    /// `FindPath` returns an empty `Path` for both, and every caller treats that
    /// the same way: do not start walking. The old three-valued `nil` / `[]` /
    /// points contract was ours, and it forced each caller to decide which of
    /// the two it had — a distinction the engine makes at the *order* layer
    /// instead (`WalkTo`'s same-cell head turn, and `isOrderableFloor`).
    @Test func anEmptyPathCoversBothAlreadyThereAndUnreachable() {
        let map = makeMap()
        #expect(map.path(from: CGPoint(x: 5, y: 5), to: CGPoint(x: 5, y: 5)).isEmpty)
        #expect(map.path(from: CGPoint(x: 5, y: 5), to: CGPoint(x: -50, y: -50)).isEmpty)
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
        #expect(map.path(from: start, to: start).isEmpty)
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
            // Portal approaches remain exact as an authoring invariant even
            // though the runtime action completes within `MinDistance`.
            for portal in district.portals {
                #expect(
                    map.reachesExactly(from: district.actorStart, to: portal.approachPoint),
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
            // An empty path is the engine's answer for "already standing
            // there" as well as for "no route", so a landmark on the spawn
            // point is not a failure.
            let alreadyThere = map.searchMap.cell(for: CityDistrictLayout.actorStart)
                == map.searchMap.cell(for: pointOfInterest.worldPoint)
            #expect(
                path.isPresent || alreadyThere,
                "Expected a route to \(pointOfInterest.label)"
            )
        }
    }

    @Test func sableRowOfficePortalApproachIsExact() {
        let district = CityDistrictCatalog.definition(for: .sableRow)
        let portal = district.portals.first { $0.id == "portal.office" }
        #expect(portal != nil)
        guard let portal else { return }

        let map = district.makeGrid()
        // Sable Row's office portal approach *is* the spawn point, so the
        // engine's answer is an empty path — already there. What matters is that
        // it is standable and not relocated.
        #expect(map.isOrderableFloor(portal.approachPoint))
        #expect(
            map.searchMap.cell(for: district.actorStart)
                == map.searchMap.cell(for: portal.approachPoint)
        )
        let exact = map.path(from: district.actorStart, to: portal.approachPoint)
        #expect(exact.isEmpty)
    }

    /// Goal walkable, goal *cell centre* inside an obstacle.
    ///
    /// Our old search had a special case for this (`acceptExactDestination`),
    /// added because it refused to ever move a goal and so could not terminate
    /// on a cell whose centre was blocked. The engine has no such case and needs
    /// none: `AdjustPositionDirected` relocates the goal to a cell the actor can
    /// stand in, and the route ends there. What must still hold is that the
    /// landing spot is standable and close by — the office-door class of
    /// approach, which is what this covers.
    @Test func aGoalWhoseCellCentreIsBlockedLandsOnStandableFloorNearby() {
        // 16×12 cells; place a thin obstacle over the goal cell centre only.
        let cellSize = SearchMap.defaultCellSize
        let worldBounds = CGRect(x: 0, y: 0, width: cellSize.width * 6, height: cellSize.height * 4)
        // Goal in cell (4, 1): centre at (4.5*16, 1.5*12) = (72, 18).
        let goalCentre = CGPoint(x: 72, y: 18)
        let destination = CGPoint(x: 78, y: 22)
        let obstacle = CGRect(
            x: goalCentre.x - 2,
            y: goalCentre.y - 2,
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

        let start = CGPoint(x: 8, y: 18)
        let path = map.path(from: start, to: destination)
        #expect(path.isPresent)
        guard let landed = path.destination else { return }
        #expect(!obstacle.contains(landed), "ended inside the solid")
        #expect(map.isOrderableFloor(landed))
        // Relocation is directed, not arbitrary: it lands within a cell or two.
        #expect(hypot(landed.x - destination.x, landed.y - destination.y) < cellSize.width * 3)
    }

    @Test func cityUsesIndependentBuildingAndStreetSprites() {
        // Sable Row is the IE outdoor pilot: one day plate, no modular stamps.
        #expect(CityDistrictCatalog.sableRow.visualSprites.isEmpty)
        #expect(CityDistrictCatalog.sableRow.groundTextureName == "city_sable_row_day_v01")

        // Other Act I wards still place modular facades + door leaves.
        let wharf = CityDistrictCatalog.wharfLadder.visualSprites
        #expect(wharf.contains { $0.textureName.hasPrefix("city_building_") })
        let leaves = wharf.filter { $0.textureName.hasPrefix("city_door_") }
        #expect(!leaves.isEmpty)
        #expect(leaves.allSatisfy { $0.anchorY == CityDistrictLayout.doorLeafAnchorY })
        for leaf in leaves {
            if CityDoorRegistrationTests.paintedPlateLeaves.contains(leaf.textureName) {
                continue
            }
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
        // `FindPath` terminates on the search node inside the goal cell, which
        // carries the *caller's* sub-cell offset — so a single-hop shortcut ends
        // at the grid point, not at the requested one. That is the engine's
        // resolution of a destination, not a snap.
        #expect(path.size == 1)
        #expect(map.searchMap.cell(for: path.destination!)
                    == map.searchMap.cell(for: CGPoint(x: 35, y: 20)))
    }

    /// `PathFinder::FindPath` has no node budget.
    ///
    /// The old `maxNodes` cap was ours; the engine bounds the search by wall
    /// clock instead, checking every 25 expansions. That difference matters:
    /// a node cap fails *deterministically* on a big map, which is why the
    /// office had to carry a budget three times the default and why long
    /// district routes were one obstacle away from failing. A time guard only
    /// fires on a search that has genuinely run away.
    @Test func aLongSearchAcrossAWholeDistrictCompletesWithoutANodeBudget() {
        let map = CityDistrictLayout.makeGrid()
        let start = CityDistrictLayout.actorStart
        // The furthest *reachable* cell on the largest shipped map — the case a
        // 32k node budget used to be able to exhaust. Measured by flood fill
        // rather than guessed from the bounds, because the far corner of a
        // district is usually a building.
        let reachable = map.reachableCellCenters(from: start)
        #expect(reachable.count > 10_000, "district is not one connected street network")
        let far = reachable.max {
            hypot($0.x - start.x, $0.y - start.y) < hypot($1.x - start.x, $1.y - start.y)
        }
        guard let far else { return }
        #expect(map.reachesExactly(from: start, to: far), "no route to \(far)")
        #expect(PathFinder.searchTimeThreshold == 15)
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
        #expect(blocked.remainingPoints.allSatisfy {
            map.searchMap.flags(at: $0).isDisjoint(with: .actor)
        })
    }

    /// `Movable::BumpAway` — the blocker steps off the spot and remembers it.
    ///
    /// The old model asked occupancy for a `BumpRequest` carrying a sidestep and
    /// a return point, and made the *scene* drive both legs. The engine gives
    /// both halves to the actor being pushed: `BumpAway` relocates it through
    /// `AdjustPositionNavmap`, `BumpBack` reclaims the spot once it is free.
    @Test func aBumpedActorStepsAsideAndRemembersWhereItStood() {
        let map = makeActorMap()
        let idleAt = CGPoint(x: 288, y: 240)
        map.registerActor(id: "idle", kind: .npc, at: idleAt, radius: 16, isMoving: false)

        var idle = Movable(
            map: map,
            identity: "idle",
            position: idleAt,
            circleSize: map.circleSize,
            blocksSearchMap: true
        )
        #expect(!idle.isBumped)

        idle.bumpAway()
        #expect(idle.isBumped)
        #expect(idle.oldPos == idleAt.rounded)
    }

    /// `Movable::BumpBack` — an unobstructed original spot is reclaimed at once.
    @Test func aBumpedActorReturnsOnceItsSpotIsFreeAgain() {
        let map = makeActorMap()
        let idleAt = CGPoint(x: 288, y: 240)
        var idle = Movable(
            map: map,
            identity: "idle",
            position: idleAt,
            circleSize: map.circleSize,
            blocksSearchMap: false
        )
        idle.bumpAway()
        #expect(idle.isBumped)

        // Nothing is stamped, so the old spot reads passable straight away.
        _ = idle.doStep(walkScale: MovableTestSupport.humanoidWalkScale, time: 2)
        #expect(!idle.isBumped)
        #expect(idle.position == idleAt.rounded)
    }

    /// `Movable::Backoff` — an unbumpable blocker makes the mover *wait*, with a
    /// randomised delay, rather than cancel. The engine calls the randomisation
    /// "inspired by network media access control algorithms": two actors
    /// blocking each other draw different waits and cannot deadlock in lockstep.
    @Test func backoffWaitsARandomisedNumberOfTicksAndKeepsTheRoute() {
        let map = MovableTestSupport.openMap()
        var walker = MovableTestSupport.movable(on: map, at: CGPoint(x: 24, y: 30))
        walker.walkTo(CGPoint(x: 300, y: 30), ticks: 1)
        let route = walker.remainingPoints

        walker.backoff()
        #expect(walker.isBackingOff)
        #expect(walker.remainingPoints == route, "backoff must not discard the route")

        var seen: Set<Int> = []
        for _ in 0..<200 {
            var other = walker
            other.backoff()
            seen.insert(other.randomBackoff)
        }
        #expect(seen.count > 1, "a fixed wait would deadlock two mutual blockers")
        #expect(seen.allSatisfy { (Movable.maxPathTries...(Movable.maxPathTries * 2)).contains($0) })
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
            circleSize: 1,
            minDistance: 12
        )
        #expect(path.isPresent)
        if let last = path.destination {
            #expect(last.x < 30, "stopped past the wall at \(last)")
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

import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore

/// Every authored point in every area must be somewhere the player can actually
/// stand, and actually reach.
///
/// Generalises `CityWorldExtentTests.everySpawnAndPortalHasAnExactPathOnTheShippedSearchMap`
/// from the six districts to the whole catalog, now that interiors and exteriors
/// are the same record. `AGENTS.md` records three bugs this class of test exists
/// to catch, all of which shipped green:
///
/// - the office floor sealed to 174 of 4,694 walkable cells,
/// - the office door with no exact path, so the exit to the city was unclickable,
/// - Harborpoint PD spawning the detective inside an 820×680 station, 1 of 5,795
///   cells reachable, on a district reachable from the world map.
///
/// All three hid behind `NavigationMap.route`, which flood-fills to the nearest
/// *reachable* cell and paths there — so it succeeds from inside a sealed pocket
/// and reports nothing wrong. These tests use `path`, which returns an honest
/// `nil`, plus a flood-fill of the runtime search map.
struct AreaReachabilityTests {

    /// Areas with a navigable floor. `opening_exterior` is a cinematic backdrop
    /// with no obstacles and no walking, so reachability says nothing about it.
    static let navigableIDs: [AreaID] = HarborpointAreas.shippedIDs.filter {
        $0 != HarborpointAreas.openingExterior
    }

    /// Four-way flood of the runtime search map, at the area's own agent radius.
    static func reachableCells(
        _ map: NavigationMap,
        from start: CGPoint,
        radius: CGFloat
    ) -> Set<SearchMapCell> {
        let search = map.searchMap
        var visited = Set<SearchMapCell>()
        var queue = [search.cell(for: start)]
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
        return visited
    }

    /// Every point an area authors as somewhere the player ends up.
    private static func authoredStandingPoints(
        _ area: AreaDefinition
    ) -> [(label: String, point: CGPoint)] {
        var points = area.entrances.map { (label: "entrance.\($0.name)", point: $0.point.cgPoint) }
        for region in area.regions {
            guard let approach = region.approachPoint else { continue }
            points.append((label: "approach.\(region.id)", point: approach.cgPoint))
        }
        for actor in area.actors {
            points.append((label: "actor.\(actor.id)", point: actor.point.cgPoint))
        }
        for container in area.containers {
            points.append((
                label: "container.\(container.id)",
                point: container.approachPoint.cgPoint
            ))
        }
        return points
    }

    @Test(arguments: navigableIDs)
    func everyAuthoredPointIsStandableAndReachable(_ id: AreaID) throws {
        let area = try AreaCatalogLoader.load(id)
        let map = area.makeNavigationMap()
        let radius = area.agentProfile.navigationProfile.radius

        let start = try #require(area.spawnPoint(entrance: nil))
        #expect(
            map.searchMap.isPassable(at: start, radius: radius),
            "\(id) default arrival \(start) is not standable"
        )

        let flood = Self.reachableCells(map, from: start, radius: radius)

        for (label, point) in Self.authoredStandingPoints(area) {
            #expect(
                map.searchMap.isPassable(at: point, radius: radius),
                "\(id) \(label) \(point) is not standable"
            )
            #expect(
                flood.contains(map.searchMap.cell(for: point)),
                "\(id) \(label) \(point) is not on the flood from the default arrival"
            )
            // `path`, not `route`: an approach point is issued with
            // `requiresExactDestination`, so a snapped arrival is a refusal at
            // runtime, not a near miss.
            #expect(
                map.path(from: start, to: point) != nil,
                "\(id) \(label) \(point) has no exact path from the default arrival"
            )
        }
    }

    /// A sealed pocket passes the per-point checks above — every authored point
    /// can be mutually reachable inside a room the rest of the area cannot get
    /// to. This is the check that catches that.
    ///
    /// The denominator is **walkable** cells, not total cells. Dividing by the
    /// whole frame was how this test first shipped, and it hid exactly the bug
    /// it exists to find: the office reaches 901 of 7,023 walkable cells, which
    /// is 12.8% of the floor but 11.6% of the frame, and so cleared a 10% bar
    /// while the room was in pieces. `qa_area_searchmap.py` measures the same
    /// ratio offline and reports the office as FRAGMENTED.
    static func connectedFraction(of area: AreaDefinition) throws -> Double {
        let map = area.makeNavigationMap()
        let radius = area.agentProfile.navigationProfile.radius
        let start = try #require(area.spawnPoint(entrance: nil))
        let reached = reachableCells(map, from: start, radius: radius).count

        // Counted at the agent's own radius, the same way the flood expands.
        // Counting by the `.passable` flag alone (radius 0) instead makes the
        // ratio meaningless: a 16-unit detective cannot enter the ring of cells
        // hugging every obstacle, so reached would always trail walkable and
        // every district would read as fragmented.
        var walkable = 0
        for row in 0..<map.searchMap.rows {
            for column in 0..<map.searchMap.columns {
                let cell = SearchMapCell(column: column, row: row)
                if map.searchMap.isPassable(at: map.searchMap.center(of: cell), radius: radius) {
                    walkable += 1
                }
            }
        }
        guard walkable > 0 else { return 0 }
        return Double(reached) / Double(walkable)
    }

    /// Districts: the street is one connected ward.
    @Test(arguments: navigableIDs.filter { $0 != HarborpointAreas.office })
    func theFloorIsOneConnectedSpace(_ id: AreaID) throws {
        let fraction = try Self.connectedFraction(of: AreaCatalogLoader.load(id))
        #expect(
            fraction > 0.90,
            "\(id) floor is in pieces — the entrance reaches \(fraction) of the walkable cells"
        )
    }

    /// The office is not, and that is a known defect rather than a surprise.
    ///
    /// Its obstacle set does not model the architecture: the room rasterises
    /// 90.6% walkable, and the props and boundary segments then cut what is left
    /// into pockets, so arriving at the desk reaches an eighth of the floor. The
    /// same root cause is behind the twelve red office geometry tests and behind
    /// a street entrance that read as standable on a wall crown. Pinned here so
    /// fitting a real floor diamond in `office_room_plan.py` shows up as this
    /// test failing rather than as a silent improvement.
    @Test func theOfficeFloorIsKnownToBeFragmented() throws {
        let fraction = try Self.connectedFraction(
            of: AreaCatalogLoader.load(HarborpointAreas.office)
        )
        #expect(
            fraction < 0.90,
            "the office floor is now \(fraction) connected — if a floor diamond landed, move it onto theFloorIsOneConnectedSpace and delete this"
        )
    }

    /// The pair that makes travel real: walk out of the office and you are in
    /// Sable Row at a standable point; walk back and you are inside the office
    /// door, not at the desk.
    @Test func travellingBetweenTheOfficeAndSableRowLandsOnStandableGround() throws {
        let catalog = try AreaCatalogLoader.load(HarborpointAreas.shippedIDs)

        for source in catalog.allAreas {
            for region in source.travelRegions {
                guard let travel = region.travel,
                      let destination = catalog.area(for: travel.destination),
                      destination.id != HarborpointAreas.openingExterior
                else { continue }

                let entrance = try #require(destination.entrance(named: travel.entrance))
                let map = destination.makeNavigationMap()
                let radius = destination.agentProfile.navigationProfile.radius
                #expect(
                    map.searchMap.isPassable(at: entrance.point.cgPoint, radius: radius),
                    "'\(source.id)' region '\(region.id)' arrives at '\(travel.entrance)' of '\(destination.id)', which is not standable"
                )
            }
        }
    }

    /// Arriving from the street must not put Voss where he starts a new game.
    /// The office discarded its arrival key for the whole of the prototype, so
    /// this is the specific regression worth naming.
    @Test func theOfficeStreetEntranceIsAtTheDoorRatherThanTheDefaultStart() throws {
        let office = try AreaCatalogLoader.load(HarborpointAreas.office)
        let fromCity = try #require(office.entrance(named: OfficeAreaAdapter.cityArrivalEntrance))
        let fallback = try #require(office.entrance(named: AreaEntrance.defaultName))
        #expect(
            fromCity.point != fallback.point,
            "the office street entrance is still the default start"
        )
        // Derived from the door's own centre line at the office's floor depth,
        // not from `approachPoints["office.door"]` — that point lies deeper into
        // the scene than the door leaf and renders the actor on the wall crown.
        let door = OfficeNavigationLayout.doorObstacle
        let point = fromCity.point.cgPoint
        #expect(
            abs(point.x - door.midX) < door.width,
            "the street entrance drifted off the door's centre line"
        )
        #expect(
            point.y < door.maxY,
            "the street entrance is behind the door leaf rather than in front of it"
        )
        // Snapped off the closed leaf, so it must clear the leaf's footprint.
        #expect(!door.contains(point), "the street entrance is inside the closed door")
        #expect(
            OfficeNavigationLayout.makeGrid().searchMap.isPassable(
                at: point,
                radius: NavigationAgentProfile.officeDetective.radius
            ),
            "the street entrance is not standable with the door shut"
        )
    }
}

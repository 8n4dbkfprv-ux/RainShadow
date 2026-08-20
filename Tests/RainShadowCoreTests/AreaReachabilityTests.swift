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
    /// to. This is the check that catches that, and it is deliberately expressed
    /// over *authored* points rather than over raw cell counts.
    ///
    /// Counting cells was tried first and reported the office at 12.8%, which
    /// reads like a room in pieces. It is not. Two things inflate the
    /// denominator, both by design:
    ///
    /// - The office plate is letterboxed, and `boundary_cell_rects()` seals only
    ///   a band hugging the floor, on the stated grounds that "everything beyond
    ///   it is unreachable once the band is sealed". That leaves **5,641** cells
    ///   of black margin marked walkable and correctly unreachable.
    /// - Inside the room, another **498** cells are passable at their centre but
    ///   unreachable to an agent with a body: the interior of a desk footprint,
    ///   the sliver behind a bookcase. Measured, they are scattered across the
    ///   whole room rather than forming a pocket.
    ///
    /// Both are healthy. What is not healthy is an authored point the player is
    /// meant to stand on that no other authored point can walk to — the shape of
    /// all three bugs in `AGENTS.md`. So the invariant is that every authored
    /// point lies in one connected component, which is a statement about the
    /// content rather than about the rasteriser's spare pixels.
    @Test(arguments: navigableIDs)
    func everyAuthoredPointSharesOneConnectedComponent(_ id: AreaID) throws {
        let area = try AreaCatalogLoader.load(id)
        let map = area.makeNavigationMap()
        let radius = area.agentProfile.navigationProfile.radius
        let points = Self.authoredStandingPoints(area)
        let anchor = try #require(points.first)
        let flood = Self.reachableCells(map, from: anchor.point, radius: radius)

        for (label, point) in points.dropFirst() {
            #expect(
                flood.contains(map.searchMap.cell(for: point)),
                "\(id) \(label) is in a different component from \(anchor.label)"
            )
        }
    }

    /// The raw ratio *is* meaningful for a district: a fully painted 4096x2304
    /// plate with no letterboxed margin, so there is no void to inflate the
    /// denominator. Kept as a regression guard on the ward geometry, and
    /// deliberately not applied to the office, where it measures the plate's
    /// black borders rather than its floor.
    @Test(arguments: navigableIDs.filter { $0 != HarborpointAreas.office })
    func aDistrictStreetIsOneConnectedWard(_ id: AreaID) throws {
        let area = try AreaCatalogLoader.load(id)
        let map = area.makeNavigationMap()
        let radius = area.agentProfile.navigationProfile.radius
        let start = try #require(area.spawnPoint(entrance: nil))
        let reached = Self.reachableCells(map, from: start, radius: radius).count

        // Counted at the agent's own radius, the same way the flood expands: a
        // detective with a body cannot enter the ring of cells hugging every
        // obstacle, so counting by the `.passable` flag alone would make even a
        // perfect ward read as fragmented.
        var walkable = 0
        for row in 0..<map.searchMap.rows {
            for column in 0..<map.searchMap.columns {
                let cell = SearchMapCell(column: column, row: row)
                if map.searchMap.isPassable(at: map.searchMap.center(of: cell), radius: radius) {
                    walkable += 1
                }
            }
        }
        let fraction = Double(reached) / Double(max(walkable, 1))
        #expect(
            fraction > 0.90,
            "\(id) street is in pieces — the arrival reaches \(fraction) of the walkable cells"
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
        // V08 uses the exact interior approach on the room side of the
        // camera-near cutaway. In authored y-up space that is above the leaf
        // stamp, not below it as the retired rear-wall door was.
        let door = OfficeNavigationLayout.doorObstacle
        let point = fromCity.point.cgPoint
        #expect(
            abs(point.x - door.midX) < door.width,
            "the street entrance drifted off the door's centre line"
        )
        #expect(
            point.y > door.maxY,
            "the street entrance is not on the interior side of the cutaway leaf"
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

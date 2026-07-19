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

    @Test func everyOfficeHotspotApproachIsReachable() {
        let grid = OfficeNavigationLayout.makeGrid()

        for (hotspotID, destination) in OfficeNavigationLayout.approachPoints {
            let path = grid.path(from: OfficeNavigationLayout.actorStart, to: destination)
            #expect(path?.isEmpty == false, "Expected a route to \(hotspotID)")
        }
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

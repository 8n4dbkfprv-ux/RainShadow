import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore

/// Opt-in validation of the staged Blender section. Reads the exact exported
/// rasters without placing an experimental area in the shipped catalog.
/// RAINSHADOW_SABLE_STAGE=/absolute/path/to/staged swift test --filter SableBlenderAreaValidation
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["RAINSHADOW_SABLE_STAGE"] != nil))
struct SableBlenderAreaValidationTests {
    private struct Points: Decodable {
        let anchors: [String: AreaPoint]
        let witnesses: [String: AreaPoint]
    }

    private var directory: URL {
        URL(fileURLWithPath: ProcessInfo.processInfo.environment["RAINSHADOW_SABLE_STAGE"]!)
    }

    private func data(_ name: String) throws -> Data {
        try Data(contentsOf: directory.appendingPathComponent(name))
    }

    private func fixture() throws -> (AreaDefinition, NavigationMap, Points) {
        let area = try AreaCatalogLoader.decodeArea(data("sable_court.area.json"))
        try AreaCatalogLoader.validateArea(area)
        let raster = try AreaSearchMapLoader.decode(data("sable_court.sr.png"))
        #expect(raster.columns == area.searchMapGridSize.columns)
        #expect(raster.rows == area.searchMapGridSize.rows)
        let search = SearchMap(worldBounds: area.worldBounds,
                               terrainIndices: raster.terrainIndices,
                               columns: raster.columns, rows: raster.rows)
        let map = NavigationMap(searchMap: search, agentProfile: area.agentProfile.navigationProfile)
        return (area, map, try JSONDecoder().decode(Points.self, from: data("validation_points.json")))
    }

    @Test func everyApproachIsExactlyReachableAndWalkedByTheRuntime() throws {
        let (area, map, points) = try fixture()
        let heights = try AreaSearchMapLoader.decode(data("sable_court.ht.png"))
        func heightOffset(_ point: CGPoint) -> CGFloat {
            AreaHeightMap.offset(from: heights, at: point, origin: .zero, cellSize: SearchMap.defaultCellSize)
        }
        var pairs = 0
        for (a, start) in points.anchors.sorted(by: { $0.key < $1.key }) {
            #expect(map.isOrderableFloor(start.cgPoint), "blocked anchor: \(a)")
            for (b, target) in points.anchors where a != b {
                #expect(map.reachesExactly(from: start.cgPoint, to: target.cgPoint), "\(a) → \(b) did not reach the requested cell")
                pairs += 1
            }
        }
        for name in ["voss_inside", "diner_inside", "tree_bed", "car_body"] {
            let p = try #require(points.witnesses[name]).cgPoint
            #expect(!map.isOrderableFloor(p), "\(name) must be solid")
        }
        let itinerary = ["street_start", "voss_approach", "intersection", "gate_outside",
                         "gate_inside", "courtyard", "bench_approach", "rear_court",
                         "gate_outside", "workshop_approach", "diner_approach", "east_street", "west_street"]
        var traces: [[String: Any]] = []
        for (a, b) in zip(itinerary, itinerary.dropFirst()) {
            let start = try #require(points.anchors[a]).cgPoint
            let target = try #require(points.anchors[b]).cgPoint
            var walker = Movable(map: map, identity: "sable.validation", position: start,
                                 circleSize: map.circleSize, blocksSearchMap: false)
            walker.walkTo(target, ticks: 1)
            var positions = [["x": walker.position.x, "y": walker.position.y]]
            var covered = [area.isCovered(walker.position)]
            var offsets = [heightOffset(walker.position)]
            for tick in 2..<10_000 {
                let outcome = walker.doStep(walkScale: MovableTestSupport.humanoidWalkScale, time: tick)
                if outcome.moved {
                    #expect(map.searchMap.terrain(at: walker.position).isWalkable, "\(a) → \(b) walked into solid terrain")
                    positions.append(["x": walker.position.x, "y": walker.position.y])
                    covered.append(area.isCovered(walker.position))
                    offsets.append(heightOffset(walker.position))
                }
                if !walker.isMoving || outcome.arrived || outcome.abandoned || outcome.backedOff { break }
            }
            #expect(map.searchMap.cell(for: walker.position) == map.searchMap.cell(for: target), "\(a) → \(b) movement stopped short")
            traces.append(["from": a, "to": b, "positions": positions,
                           "covered": covered, "heightOffsets": offsets])
        }
        let output: [String: Any] = ["orderedPairs": pairs, "traces": traces,
                                     "engine": "RainShadow NavigationMap / PathFinder / Movable",
                                     "circleSize": map.circleSize]
        try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appendingPathComponent("runtime_walks.json"))
    }

    @Test func theActualWallBakerPreservesTheFrontBehindDistinction() throws {
        let (area, _, points) = try fixture()
        let start = Date()
        let mask = area.makeWallStencil()
        let elapsed = Date().timeIntervalSince(start)
        #expect(!mask.isEmpty)
        #expect(max(mask.columns, mask.rows) <= AreaWallStencil.maximumMaskDimension)
        #expect(elapsed < 3, "section stencil took \(elapsed)s")
        for name in ["wall_front", "open_street"] {
            let p = try #require(points.witnesses[name]).cgPoint
            #expect(!area.isCovered(p), "\(name) incorrectly enables actor cover")
            #expect(mask.sample(at: p).g == 0, "\(name) masked open floor")
        }
        let behind = try #require(points.witnesses["wall_behind"]).cgPoint
        #expect(area.isCovered(behind))
        #expect(mask.sample(at: behind).g == 0x80)
        try Data(mask.rgba).write(to: directory.appendingPathComponent("wall_stencil.rgba"))
        let report: [String: Any] = ["columns": mask.columns, "rows": mask.rows,
                                     "worldWidth": area.worldSize.w, "worldHeight": area.worldSize.h,
                                     "rowOrder": "bottom-up", "seconds": elapsed,
                                     "polygonCount": area.wallPolygons.count,
                                     "channels": "R=dither128,G=cover128,B=255,A=128"]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appendingPathComponent("stencil_report.json"))
    }

    @Test func heightAndScaleUseTheRuntimeConventions() throws {
        let (area, _, points) = try fixture()
        let height = try AreaSearchMapLoader.decode(data("sable_court.ht.png"))
        #expect(height.columns == area.searchMapGridSize.columns)
        #expect(height.rows == area.searchMapGridSize.rows)
        for p in points.anchors.values {
            let offset = AreaHeightMap.offset(from: height, at: p.cgPoint, origin: .zero,
                                             cellSize: SearchMap.defaultCellSize)
            #expect(abs(offset) <= 6)
        }
        let projectedAdult: CGFloat = 69.847866
        #expect(abs(projectedAdult / OfficeInteriorScale.renderedStandingDetectiveBodyHeight - 1) < 0.01)
    }

    @Test func exportTheCurrentNativeAvatarForTheVisualWalkReview() throws {
        let sprite = try IEIndexedSprite.load(character: "Voss")
        let output = directory.appendingPathComponent("review_avatar", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        var frames: [[String: Any]] = []
        for frame in sprite.frames where frame.id.atlas == "VossWalk.atlas" && !frame.isEmpty {
            let filename = frame.id.name + ".rgba"
            try Data(sprite.rgba(for: frame)).write(to: output.appendingPathComponent(filename))
            frames.append(["name": frame.id.name, "file": filename,
                           "nativeWidth": frame.nativeSize.width, "nativeHeight": frame.nativeSize.height,
                           "worldWidth": Double(frame.size.width) * sprite.displayUnitsPerSourcePixel.x,
                           "worldHeight": Double(frame.size.height) * sprite.displayUnitsPerSourcePixel.y,
                           "anchorX": frame.normalizedPivot!.x, "anchorY": frame.normalizedPivot!.y])
        }
        #expect(frames.count >= 64)
        try JSONSerialization.data(withJSONObject: ["frames": frames], options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("frames.json"))
    }

    @Test func anAsymmetricCoverFaceKeepsItsActualOrientation() {
        let polygon = [AreaPoint(x: 10, y: 10), AreaPoint(x: 90, y: 10), AreaPoint(x: 10, y: 70)]
        let wall = AreaWallPolygon(id: "asymmetric", polygon: polygon)
        let mask = AreaWallStencil.bake(wallPolygons: [wall], worldFrame: CGRect(x: 0, y: 0, width: 100, height: 100))
        #expect(wall.contains(CGPoint(x: 65, y: 15)))
        #expect(!wall.contains(CGPoint(x: 65, y: 60)))
        #expect(mask.sample(at: CGPoint(x: 65, y: 15)).g == 128)
        #expect(mask.sample(at: CGPoint(x: 65, y: 60)).g == 0)
    }

}

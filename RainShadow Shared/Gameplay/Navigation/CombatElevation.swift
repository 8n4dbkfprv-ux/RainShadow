import Foundation
import CoreGraphics

/// A walkable plane authored in projected map coordinates. Actors, rings and
/// projectiles already stand on the painted surface: do not add its height to
/// their sprites a second time. Feet are rules data, independent of the legacy HT.
struct AreaElevationSurface: Hashable, Codable, Sendable {
    var id: String
    var origin: AreaPoint
    var axisU: AreaPoint
    var axisV: AreaPoint
    var baseFeet: Double
    var riseUFeet: Double
    var riseVFeet: Double

    func point(u: CGFloat, v: CGFloat) -> CGPoint {
        CGPoint(x: origin.x + axisU.x * u + axisV.x * v,
                y: origin.y + axisU.y * u + axisV.y * v)
    }
    func height(at point: CGPoint) -> Double? {
        let determinant = axisU.x * axisV.y - axisU.y * axisV.x
        guard abs(determinant) > 0.001 else { return nil }
        let x = point.x - origin.x, y = point.y - origin.y
        let u = (x * axisV.y - y * axisV.x) / determinant
        let v = (axisU.x * y - axisU.y * x) / determinant
        guard u >= -0.000001, u <= 1.000001, v >= -0.000001, v <= 1.000001 else { return nil }
        return baseFeet + Double(min(1, max(0, u))) * riseUFeet + Double(min(1, max(0, v))) * riseVFeet
    }
}

enum CombatElevation {
    // Cache authored planes once. No saved actor heights can become stale after
    // walking, forced movement, loading an old save, or approaching an attack.
    private static let wharf = (try? AreaCatalogLoader.load(WharfLadderStory.exterior).elevationSurfaces) ?? []
    private static let wharfLadders = (try? AreaCatalogLoader.load(WharfLadderStory.exterior).ladders) ?? []
    static func ladders(in area: String) -> [AreaLadder] {
        AreaID(area) == WharfLadderStory.exterior ? wharfLadders : []
    }
    static func surfaces(in area: String) -> [AreaElevationSurface] {
        AreaID(area) == WharfLadderStory.exterior ? wharf : []
    }
    static func feet(at point: CGPoint, in area: String) -> Double {
        surfaces(in: area).compactMap { $0.height(at: point) }.max() ?? 0
    }
    /// BG3: a difference of at least 10 ft / 3 m changes the ranged attack
    /// roll by two. This is not advantage, damage, or permission to ignore LOS.
    static func rangedModifier(attackerFeet: Double, targetFeet: Double) -> Int {
        let difference = attackerFeet - targetFeet
        return difference >= 10 ? 2 : difference <= -10 ? -2 : 0
    }
    static func firingPositions(in area: String) -> [CGPoint] {
        surfaces(in: area).filter { $0.baseFeet >= 10 && $0.riseUFeet == 0 && $0.riseVFeet == 0 }
            .flatMap { surface in [surface.point(u: 0.5, v: 0.5), surface.point(u: 0.35, v: 0.5), surface.point(u: 0.65, v: 0.5)] }
            .map(\.rounded)
    }
}

extension TacticalCombat {
    func elevationBonus(from attacker: CGPoint, to target: CGPoint, ranged: Bool) -> Int {
        ranged ? CombatElevation.rangedModifier(attackerFeet: CombatElevation.feet(at: attacker, in: areaID),
                                                targetFeet: CombatElevation.feet(at: target, in: areaID)) : 0
    }
    /// Do not melee, threaten or shove someone through a platform's vertical face.
    func canReachHeight(from attacker: CGPoint, to target: CGPoint) -> Bool {
        abs(CombatElevation.feet(at: attacker, in: areaID) - CombatElevation.feet(at: target, in: areaID)) <= 5
    }
}

extension CombatNavigation {
    /// Combat projectile policy over the shared raster. Walking passability is
    /// not a shot test: index 8 parapets and index 12 water admit projectiles.
    /// Supercover traversal includes both neighbours at an exact corner. No
    /// world geometry clearance queries or changes to GemRB's line walkers are involved.
    static func projectileLine(in map: SearchMap, from a: CGPoint, to b: CGPoint, overFacade: (CGPoint) -> Bool = { _ in false }) -> Bool {
        guard map.contains(a), map.contains(b) else { return false }
        var cell = map.cell(for: a)
        let end = map.cell(for: b)
        let dx = b.x - a.x, dy = b.y - a.y
        let sx = dx >= 0 ? 1 : -1, sy = dy >= 0 ? 1 : -1
        let dtX = dx == 0 ? CGFloat.infinity : map.cellSize.width / abs(dx)
        let dtY = dy == 0 ? CGFloat.infinity : map.cellSize.height / abs(dy)
        let nextX = map.origin.x + CGFloat(cell.column + (sx > 0 ? 1 : 0)) * map.cellSize.width
        let nextY = map.origin.y + CGFloat(cell.row + (sy > 0 ? 1 : 0)) * map.cellSize.height
        var tx = dx == 0 ? CGFloat.infinity : (nextX - a.x) / dx
        var ty = dy == 0 ? CGFloat.infinity : (nextY - a.y) / dy
        func clear(_ cell: SearchMapCell) -> Bool {
            guard map.contains(cell) else { return false }
            let flags = map.blockedTile(at: cell)
            guard flags.isDisjoint(with: [.door, .actor]) else { return false }
            let center = CGPoint(x: map.origin.x + (CGFloat(cell.column)+0.5)*map.cellSize.width,
                                 y: map.origin.y + (CGFloat(cell.row)+0.5)*map.cellSize.height)
            return overFacade(center) || (map.terrain(at: cell).allowsProjectiles && flags.isDisjoint(with: [.sidewall, .noSee]))
        }
        for _ in 0...(abs(end.column-cell.column) + abs(end.row-cell.row) + 2) {
            guard clear(cell) else { return false }
            if cell == end { return true }
            if abs(tx-ty) < 0.0000001 {
                guard clear(SearchMapCell(column: cell.column+sx, row: cell.row)),
                      clear(SearchMapCell(column: cell.column, row: cell.row+sy)) else { return false }
                cell = SearchMapCell(column: cell.column+sx, row: cell.row+sy); tx += dtX; ty += dtY
            } else if tx < ty {
                cell = SearchMapCell(column: cell.column+sx, row: cell.row); tx += dtX
            } else {
                cell = SearchMapCell(column: cell.column, row: cell.row+sy); ty += dtY
            }
        }
        return false
    }
}

/// Explicit traversal between two disconnected walkable floors. Ordinary routes
/// still use the GemRB port; no path node is sent through the building's wall.
struct AreaLadder: Hashable, Codable, Sendable {
    var id: String
    var bottom: AreaPoint
    var top: AreaPoint
    var costFeet: Double
    var facing: Int
    func ends(from point: CGPoint) -> (entry: CGPoint, exit: CGPoint) {
        let up = CombatNavigation.distance(point, bottom.cgPoint) < CombatNavigation.distance(point, top.cgPoint)
        return up ? (bottom.cgPoint.rounded, top.cgPoint.rounded) : (top.cgPoint.rounded, bottom.cgPoint.rounded)
    }
    func contains(_ point: CGPoint) -> Bool {
        let a = bottom.cgPoint, b = top.cgPoint
        let dx = b.x-a.x, dy = b.y-a.y
        let t = min(1, max(0, ((point.x-a.x)*dx+(point.y-a.y)*dy)/(dx*dx+dy*dy)))
        return hypot(point.x-a.x-t*dx, point.y-a.y-t*dy) < 25
    }
    func exitIsClear(in map: NavigationMap, actorID: String, from point: CGPoint) -> Bool {
        map.occupancy.withStampLifted(id: actorID) {
            map.searchMap.blockedInRadiusTile(at: ends(from: point).exit, size: map.circleSize).contains(.passable)
        }
    }
}

extension AreaElevationSurface {
    /// The roof's visible front faces are below the firing plane. A projected
    /// projectile may cross those faces without treating their ground wall as a
    /// ceiling. This applies only to rays with an endpoint on this roof; other
    /// walls, roof-floor obstructions, doors and creatures still block normally.
    func permitsElevatedShot(at point: CGPoint, from a: CGPoint, to b: CGPoint) -> Bool {
        guard height(at: a) != nil || height(at: b) != nil, height(at: point) == nil else { return false }
        // Shipping source camera: 39.0625 projected units per Blender metre.
        let lift = CGFloat(baseFeet * 0.3048 * 39.0625)
        return (1...32).contains { step in
            let x = point.x-origin.x, y = point.y + lift * CGFloat(step)/32-origin.y
            let det = axisU.x*axisV.y-axisU.y*axisV.x
            let u = (x*axisV.y-y*axisV.x)/det, v = (axisU.x*y-axisU.y*x)/det
            // Include the authored 0.45 m parapet and the conservative wall cell.
            return u >= -0.06 && u <= 1.06 && v >= -0.06 && v <= 1.06
        }
    }
}

import CoreGraphics

/// Authored IE-style outline helpers: axis-aligned quads and point-in-polygon.
enum HighlightGeometry {
    static func quad(from rect: CGRect) -> [CGPoint] {
        [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.maxY)
        ]
    }

    static func boundingBox(of polygon: [CGPoint]) -> CGRect {
        guard let first = polygon.first else { return .null }
        var minX = first.x
        var minY = first.y
        var maxX = first.x
        var maxY = first.y
        for point in polygon.dropFirst() {
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Even-odd ray test. Vertices on the edge count as inside, matching ARE
    /// polygon hover in the Infinity Engine.
    static func contains(_ point: CGPoint, polygon: [CGPoint]) -> Bool {
        guard polygon.count >= 3 else { return false }
        let box = boundingBox(of: polygon)
        guard box.insetBy(dx: -0.5, dy: -0.5).contains(point) else { return false }
        if isOnEdge(point, polygon: polygon) { return true }

        var inside = false
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let a = polygon[i]
            let b = polygon[j]
            let intersects = (a.y > point.y) != (b.y > point.y)
                && point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x
            if intersects { inside.toggle() }
            j = i
        }
        return inside
    }

    private static func isOnEdge(_ point: CGPoint, polygon: [CGPoint]) -> Bool {
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            if isOnSegment(point, a: polygon[i], b: polygon[j]) { return true }
            j = i
        }
        return false
    }

    private static func isOnSegment(_ point: CGPoint, a: CGPoint, b: CGPoint) -> Bool {
        let cross = (point.y - a.y) * (b.x - a.x) - (point.x - a.x) * (b.y - a.y)
        guard abs(cross) < 0.35 else { return false }
        let dot = (point.x - a.x) * (b.x - a.x) + (point.y - a.y) * (b.y - a.y)
        let lengthSquared = (b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y)
        return dot >= 0 && dot <= lengthSquared
    }
}

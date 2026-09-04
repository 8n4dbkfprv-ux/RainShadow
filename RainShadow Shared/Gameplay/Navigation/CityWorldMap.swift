import CoreGraphics
import Foundation

/// Cardinal direction used for district edge exits and arrival spawns.
enum CityMapEdge: String, CaseIterable, Equatable {
    case north
    case south
    case east
    case west

    var opposite: CityMapEdge {
        switch self {
        case .north: return .south
        case .south: return .north
        case .east: return .west
        case .west: return .east
        }
    }

    /// Arrival key written into `CityDistrictDefinition.spawnByArrivalKey`.
    var arrivalKey: String { "from.\(rawValue)" }

    var gridDelta: (col: Int, row: Int) {
        switch self {
        case .north: return (0, 1)
        case .south: return (0, -1)
        case .east: return (1, 0)
        case .west: return (-1, 0)
        }
    }
}

/// One cell on Harborpoint's 3×3 ward grid (BG:EE Classic city layout).
enum CityWorldMapCell: Equatable, Hashable {
    case district(CityDistrictID)
    /// Fog-washed unnamed ward reserved for later acts. Never travelable.
    case lockedWard(String)

    var shortLabel: String {
        switch self {
        case .district(let id):
            switch id {
            case .sableRow: return "SABLE ROW"
            case .wharfLadder: return "WHARF LADDER"
            case .riverside: return "RIVERSIDE"
            case .harborpointPD: return "HARBORPOINT PD"
            case .lilaStreet: return "LILA'S STREET"
            case .civicRecords: return "CIVIC RECORDS"
            }
        case .lockedWard:
            return ""
        }
    }

    var isLocked: Bool {
        if case .lockedWard = self { return true }
        return false
    }

    var districtID: CityDistrictID? {
        if case .district(let id) = self { return id }
        return nil
    }
}

/// Harborpoint world map: Baldur's Gate EE Classic 3×3 city travel rules.
enum CityWorldMap {
    /// Column 0 = west, column 2 = east. Row 0 = south, row 2 = north.
    struct GridPoint: Equatable, Hashable {
        let col: Int
        let row: Int

        init(col: Int, row: Int) {
            self.col = col
            self.row = row
        }

        func neighbor(toward edge: CityMapEdge) -> GridPoint {
            let delta = edge.gridDelta
            return GridPoint(col: col + delta.col, row: row + delta.row)
        }
    }

    static let gridColumns = 3
    static let gridRows = 3

    /// Locked wards drawn rain-obscured; no Blue Room / Wardour names until earned.
    static let lockedNorthwest = CityWorldMapCell.lockedWard("unmapped_nw")
    static let lockedNortheast = CityWorldMapCell.lockedWard("unmapped_ne")
    static let lockedSoutheast = CityWorldMapCell.lockedWard("unmapped_se")

    /// Row-major from north-west (visual top-left) for UI painting.
    /// Physical grid uses south-origin rows; this helper is presentation-only.
    static let cells: [[CityWorldMapCell]] = [
        // row 2 (north)
        [lockedNorthwest, .district(.civicRecords), lockedNortheast],
        // row 1 (middle)
        [.district(.wharfLadder), .district(.sableRow), .district(.lilaStreet)],
        // row 0 (south) — listed north-to-south for painting
        [.district(.riverside), .district(.harborpointPD), lockedSoutheast]
    ]

    private static let districtCoordinates: [CityDistrictID: GridPoint] = [
        .civicRecords: GridPoint(col: 1, row: 2),
        .wharfLadder: GridPoint(col: 0, row: 1),
        .sableRow: GridPoint(col: 1, row: 1),
        .lilaStreet: GridPoint(col: 2, row: 1),
        .riverside: GridPoint(col: 0, row: 0),
        .harborpointPD: GridPoint(col: 1, row: 0)
    ]

    private static let lockedCoordinates: [String: GridPoint] = [
        "unmapped_nw": GridPoint(col: 0, row: 2),
        "unmapped_ne": GridPoint(col: 2, row: 2),
        "unmapped_se": GridPoint(col: 2, row: 0)
    ]

    static func coordinate(for district: CityDistrictID) -> GridPoint {
        districtCoordinates[district]!
    }

    static func cell(at point: GridPoint) -> CityWorldMapCell? {
        guard point.col >= 0, point.col < gridColumns,
              point.row >= 0, point.row < gridRows else {
            return nil
        }
        // `cells` is painted north-to-south; invert row for lookup.
        let visualRow = (gridRows - 1) - point.row
        return cells[visualRow][point.col]
    }

    static func neighbor(of district: CityDistrictID, toward edge: CityMapEdge) -> CityWorldMapCell? {
        let next = coordinate(for: district).neighbor(toward: edge)
        return cell(at: next)
    }

    /// Edges of `district` that touch another grid cell (locked or playable).
    static func exitEdges(from district: CityDistrictID) -> [CityMapEdge] {
        CityMapEdge.allCases.filter { neighbor(of: district, toward: $0) != nil }
    }

    /// Edges that lead to a playable district (excludes locked-ward borders for travel).
    static func travelableExitEdges(from district: CityDistrictID) -> [CityMapEdge] {
        CityMapEdge.allCases.filter { edge in
            guard let cell = neighbor(of: district, toward: edge) else { return false }
            return cell.districtID != nil
        }
    }

    /// BG Classic reveal: travelable if visited, or orthogonally adjacent to a visited district.
    static func isTravelable(
        _ district: CityDistrictID,
        visited: Set<CityDistrictID>
    ) -> Bool {
        if visited.contains(district) { return true }
        let point = coordinate(for: district)
        for edge in CityMapEdge.allCases {
            let adjacent = point.neighbor(toward: edge)
            guard let cell = cell(at: adjacent),
                  let neighborID = cell.districtID else {
                continue
            }
            if visited.contains(neighborID) { return true }
        }
        return false
    }

    static func isRevealed(
        _ district: CityDistrictID,
        visited: Set<CityDistrictID>
    ) -> Bool {
        isTravelable(district, visited: visited)
    }

    /// Locked wards are never travelable; they reveal visually only when adjacent to a visit.
    static func isLockedWardRevealed(
        _ wardKey: String,
        visited: Set<CityDistrictID>
    ) -> Bool {
        guard let point = lockedCoordinates[wardKey] else { return false }
        for edge in CityMapEdge.allCases {
            let adjacent = point.neighbor(toward: edge)
            guard let cell = cell(at: adjacent),
                  let neighborID = cell.districtID else {
                continue
            }
            if visited.contains(neighborID) { return true }
        }
        return false
    }

    /// Arrival edge on the destination when leaving `from` across `exitEdge`.
    static func arrivalEdge(leavingVia exitEdge: CityMapEdge) -> CityMapEdge {
        exitEdge.opposite
    }

    static func arrivalKey(leavingVia exitEdge: CityMapEdge) -> String {
        arrivalEdge(leavingVia: exitEdge).arrivalKey
    }

    /// Edge of the destination to spawn on when traveling from `origin` to `destination`.
    static func arrivalEdge(
        from origin: CityDistrictID,
        to destination: CityDistrictID
    ) -> CityMapEdge? {
        let originPoint = coordinate(for: origin)
        let destinationPoint = coordinate(for: destination)
        for edge in CityMapEdge.allCases {
            if originPoint.neighbor(toward: edge) == destinationPoint {
                return edge.opposite
            }
        }
        return nil
    }

    static func arrivalKey(
        from origin: CityDistrictID,
        to destination: CityDistrictID
    ) -> String? {
        arrivalEdge(from: origin, to: destination)?.arrivalKey
    }

    /// All playable districts currently selectable on the world map.
    static func travelableDistricts(visited: Set<CityDistrictID>) -> Set<CityDistrictID> {
        Set(CityDistrictID.allCases.filter { isTravelable($0, visited: visited) })
    }

    // MARK: - Edge exit geometry (world space)

    /// Thickness of the BG-style edge exit strip inside world bounds.
    static let exitStripThickness: CGFloat = 96
    /// Inset from the corners so building obstacle blocks do not swallow the strip.
    static let exitStripCornerInset: CGFloat = 120

    static func exitHitArea(
        for edge: CityMapEdge,
        worldBounds: CGRect = CityDistrictDefinition.worldBounds
    ) -> CGRect {
        let inset = exitStripCornerInset
        let thickness = exitStripThickness
        switch edge {
        case .north:
            return CGRect(
                x: worldBounds.minX + inset,
                y: worldBounds.maxY - thickness,
                width: worldBounds.width - inset * 2,
                height: thickness
            )
        case .south:
            return CGRect(
                x: worldBounds.minX + inset,
                y: worldBounds.minY,
                width: worldBounds.width - inset * 2,
                height: thickness
            )
        case .east:
            return CGRect(
                x: worldBounds.maxX - thickness,
                y: worldBounds.minY + inset,
                width: thickness,
                height: worldBounds.height - inset * 2
            )
        case .west:
            return CGRect(
                x: worldBounds.minX,
                y: worldBounds.minY + inset,
                width: thickness,
                height: worldBounds.height - inset * 2
            )
        }
    }

    static func exitApproachPoint(
        for edge: CityMapEdge,
        worldBounds: CGRect = CityDistrictDefinition.worldBounds
    ) -> CGPoint {
        let area = exitHitArea(for: edge, worldBounds: worldBounds)
        return CGPoint(x: area.midX, y: area.midY)
    }

    /// Default edge spawn used when a catalog has not authored a finer point.
    static func defaultSpawnPoint(
        arrivingFrom edge: CityMapEdge,
        worldBounds: CGRect = CityDistrictDefinition.worldBounds
    ) -> CGPoint {
        let margin: CGFloat = 140
        switch edge {
        case .north:
            return CGPoint(x: worldBounds.midX, y: worldBounds.maxY - margin)
        case .south:
            return CGPoint(x: worldBounds.midX, y: worldBounds.minY + margin)
        case .east:
            return CGPoint(x: worldBounds.maxX - margin, y: worldBounds.midY)
        case .west:
            return CGPoint(x: worldBounds.minX + margin, y: worldBounds.midY)
        }
    }
}

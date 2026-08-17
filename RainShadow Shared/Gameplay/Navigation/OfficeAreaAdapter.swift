import CoreGraphics
import Foundation

/// Projects the office's Swift geometry onto the `AreaDefinition` record.
///
/// **Transitional**, for the same reason as `CityDistrictAreaAdapter`: it exists
/// so the office becomes an area file without being retyped, and it goes away
/// when `OfficeNavigationLayout` stops being a runtime type.
///
/// Unlike the districts, the office is only *partly* expressible today. Its
/// props are placed imperatively inside `DetectiveOfficeScene.buildScene()` —
/// texture names are string literals at ~60 call sites, not a data structure —
/// so `props` is exported empty and the scene keeps drawing them until Phase 5
/// lifts them out. Everything the office *does* hold as data (bounds, entrance,
/// obstacles, hotspots, containers, the entrance door) is exported in full.
///
/// All coordinates are exported in **world** space. `OfficeNavigationLayout`
/// authors in plate-art space and converts through `OfficeInteriorScale.mapPoint`
/// / `mapRect`; the record stores what the runtime actually uses, so nothing
/// downstream has to know the authoring frame exists.
enum OfficeAreaAdapter {

    /// Entrance used when arriving through the street door from Sable Row.
    /// Matches `CityDistrictAreaAdapter.officeArrivalEntrance`, which is the
    /// name the city's portal region travels to.
    static let cityArrivalEntrance = CityDistrictAreaAdapter.officeArrivalEntrance

    static func area() -> AreaDefinition {
        let bounds = OfficeNavigationLayout.navigationWorldBounds
        return AreaDefinition(
            id: HarborpointAreas.office,
            displayName: "THE OFFICE — HARBOR STREET",
            kind: .interior,
            arrivalHint: nil,
            worldOrigin: AreaPoint(bounds.origin),
            worldSize: AreaSize(bounds.size),
            plateTextureName: "office_suite_plate",
            mapTextureName: nil,
            // The V7 room is letterboxed on a 4096×2304 canvas with the rest
            // baked black; clamping the camera to the plate would let it swing
            // out over that margin.
            cameraClampRect: AreaRect(OfficeInteriorScale.paintedRoomBounds),
            searchMapName: nil,
            obstacles: OfficeNavigationLayout.obstacles.map(AreaRect.init),
            agentProfile: AreaAgentProfile(.officeDetective),
            entrances: entrances(),
            regions: hotspotRegions() + [streetDoorRegion()],
            // Phase 5: lifted out of `DetectiveOfficeScene.buildScene()`.
            props: [],
            actors: actors(),
            containers: containers(),
            doors: [
                AreaDoor(
                    id: "office.door",
                    textureName: "office_door_leaf",
                    closedObstacle: AreaRect(OfficeNavigationLayout.doorObstacle),
                    openObstacle: nil,
                    startsClosed: true
                )
            ],
            notes: [],
            ambients: [
                AreaAmbient(
                    id: "amb.rain",
                    assetName: "amb_rain_exterior",
                    volume: 0.34,
                    isLooping: true
                )
            ],
            // Phase 6: `OfficeClientVisitSequencer` becomes this script.
            script: nil
        )
    }

    // MARK: - Sections

    private static func entrances() -> [AreaEntrance] {
        let start = AreaPoint(OfficeNavigationLayout.actorStart)
        // Arriving from the street should put Voss at the door, not at the desk
        // chair. Until the door approach is authored and flood-filled, both
        // entrances resolve to the shipped start — `SceneRouter` currently
        // discards the arrival key entirely, so this is not a regression, and
        // Phase 2 re-derives `from.city` from `nearestWalkablePoint` on the
        // inside face of the door.
        return [
            AreaEntrance(name: AreaEntrance.defaultName, point: start),
            AreaEntrance(name: cityArrivalEntrance, point: start)
        ]
    }

    private static func hotspotRegions() -> [AreaRegion] {
        OfficeNavigationLayout.authoredHotspots.map { hotspot in
            AreaRegion(
                id: hotspot.id,
                kind: .info,
                label: hotspot.name,
                rect: OfficeInteriorScale.mapRect(hotspot.hitArea),
                approachPoint: OfficeNavigationLayout.approachPoints[hotspot.id]
                    .map(AreaPoint.init),
                observation: hotspot.observation
            )
        }
    }

    /// The way back out to Sable Row. The office door is a hotspot today; as a
    /// travel region it carries where it goes, which is what makes the exit
    /// symmetric with the city portal that arrives here.
    private static func streetDoorRegion() -> AreaRegion {
        AreaRegion(
            id: "office.exit",
            kind: .travel,
            label: "Street door",
            rect: OfficeNavigationLayout.doorObstacle,
            approachPoint: OfficeNavigationLayout.approachPoints["office.door"]
                .map(AreaPoint.init),
            travel: AreaTravel(
                destination: HarborpointAreas.sableRow,
                entrance: "from.office"
            ),
            requiresFlag: CityDistrictAreaAdapter.cityTravelOpenFlag,
            lockedLine: "The street stays closed until the case leaves the office."
        )
    }

    private static func actors() -> [AreaActor] {
        // Lila is placed by the client-visit cutscene rather than standing in
        // the room at load, so she is not an area actor yet. Phase 6 gives the
        // office an area script and she becomes one, gated on the case flag.
        []
    }

    private static func containers() -> [AreaContainer] {
        OfficeNavigationLayout.lootContainers.compactMap { loot in
            // A container needs a place to stand and something to click. Both
            // come from the hotspot of the same id — the office authors its
            // searchable furniture as hotspots first.
            guard let hotspot = OfficeNavigationLayout.authoredHotspots
                .first(where: { $0.id == loot.id }),
                let approach = OfficeNavigationLayout.approachPoints[loot.id]
            else { return nil }
            return AreaContainer(
                id: loot.id,
                label: hotspot.name,
                hitArea: AreaRect(OfficeInteriorScale.mapRect(hotspot.hitArea)),
                approachPoint: AreaPoint(approach),
                loot: loot
            )
        }
    }
}

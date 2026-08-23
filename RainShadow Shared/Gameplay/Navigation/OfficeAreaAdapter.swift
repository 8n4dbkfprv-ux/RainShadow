import CoreGraphics
import Foundation

/// Projects the office's Swift geometry onto the `AreaDefinition` record.
///
/// **Transitional**, for the same reason as `CityDistrictAreaAdapter`: it exists
/// so the office becomes an area file without being retyped, and it goes away
/// when `OfficeNavigationLayout` stops being a runtime type.
///
/// The whole room is expressible now. Its props used to be placed imperatively
/// inside `DetectiveOfficeScene.buildScene()`, with texture names as string
/// literals at some sixty call sites, and `props` was exported empty; they are
/// read out of a runtime dump instead and the scene builds them from the record.
/// Bounds, entrance, obstacles, hotspots, containers and the entrance door were
/// always exported in full.
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
            searchMapName: "\(HarborpointAreas.office.rawValue).sr",
            obstacles: OfficeNavigationLayout.obstacles.map(AreaRect.init),
            // The desk, the chairs and the wastebasket stop feet but not sight,
            // so the bake paints them index 8 and fog sees over them.
            sightPermeableObstacles: OfficeNavigationLayout.sightPermeableObstacles
                .map(AreaRect.init),
            // Floorboards throughout, which is what makes the office sound
            // different from the street without a per-scene constant saying so.
            defaultTerrain: .wood,
            agentProfile: AreaAgentProfile(.officeDetective),
            // A small room packed with ~750 obstacle rectangles: threading
            // furniture expands far more nodes per unit travelled than an open
            // street does, so the office has always run a wider budget than the
            // engine default. It was scene configuration; now it is the area's.
            pathSearchBudget: OfficeNavigationLayout.pathSearchBudget,
            entrances: entrances(),
            regions: hotspotRegions() + [streetDoorRegion()],
            props: props(),
            wallPolygons: wallPolygons(),
            actors: actors(),
            containers: containers(),
            doors: [
                AreaDoor(
                    id: "office.door",
                    visual: AreaDoorVisualRegistration(
                        // The generator converts measured plate y-down into
                        // authored y-up before publishing this anchor; mapPoint
                        // then performs only the authored-to-world transform.
                        position: AreaPoint(OfficeInteriorScale.mapPoint(
                            OfficeNavigationLayout.Architecture.entranceLeafAnchor
                        )),
                        canvasAnchor: AreaPoint(
                            OfficeNavigationLayout.Architecture.entranceLeafAnchorPoint
                        ),
                        scale: OfficeNavigationLayout.Architecture.entranceLeafDisplayScale,
                        closedTextureName: "office_door_leaf",
                        midTextureName: "office_door_leaf_mid",
                        openTextureName: "office_door_leaf_open",
                        closedHoverTextureName: "office_door_leaf_hover",
                        midHoverTextureName: "office_door_leaf_mid_hover",
                        openHoverTextureName: "office_door_leaf_open_hover"
                    ),
                    closedObstacle: AreaRect(OfficeNavigationLayout.doorObstacle),
                    openObstacle: nil,
                    startsClosed: true
                )
            ],
            notes: [],
            ambients: [
                // The office hears rain on *its window*, not the street bed the
                // districts play. The record said `amb_rain_exterior` at 0.34
                // because this adapter copied the city's ambient when the record
                // was first written; the scene has always played
                // `amb_rain_window` at 0.27, and wiring the record up without
                // checking would have shipped that as an audio change.
                AreaAmbient(
                    id: "amb.rain",
                    assetName: "amb_rain_window",
                    volume: 0.27,
                    isLooping: true
                )
            ],
            script: AreaScriptCatalog.officeSuite.id
        )
    }

    // MARK: - Sections

    /// The office's live overlays, read from what the renderer actually placed.
    ///
    /// `ArtSource/Generated/Office/office_props_v01.json` is written by
    /// `office_props_from_dump.py` from a `RAINSHADOW_DUMP_PROPS` run. Reading
    /// the scene graph rather than parsing `buildScene` is deliberate: placement
    /// runs through `OfficeInteriorScale.mapPoint`, several prop-relative scale
    /// tables and a dozen inline constructions, and re-deriving that in a parser
    /// means re-implementing it and hoping the two agree.
    ///
    /// Static scenery is composited into `office_suite_plate` by
    /// `bake_office_plate.py`, matching the Infinity Engine split: ordinary
    /// furniture is tileset pixels while only pieces that must sort against an
    /// actor survive as nodes. The desk, chair and occluders are that
    /// exception — the apron straddles a seated actor.
    ///
    /// Loaded at export time only. `AreaExportTests` runs in the package, where
    /// `ArtSource` is on disk; the app reads the resulting `.area.json`.
    static func props() -> [AreaProp] {
        guard let data = try? Data(contentsOf: propsSourceURL),
              let document = try? JSONDecoder().decode(PropsDocument.self, from: data)
        else {
            // Not an error in the app — only the exporter needs this file.
            return []
        }
        return document.props.filter { livePropIDs.contains($0.id) }
    }

    /// Must match `bake_office_plate.LIVE_PROP_IDS`. The generated bake
    /// manifest records both sides of the split for review and tests assert the
    /// shipped area contains this set exactly.
    private static let livePropIDs: Set<String> = [
        "office_desk_bare",
        "office_desk_chair",
        "office_desk_actor_occluder",
        "office_desk_front_occluder_v04",
        "office_desk_top_occluder"
    ]

    private struct PropsDocument: Decodable {
        let props: [AreaProp]
    }

    static var propsSourceURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Navigation
            .deletingLastPathComponent()   // Gameplay
            .deletingLastPathComponent()   // RainShadow Shared
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("ArtSource/Generated/Office/office_props_v01.json")
    }

    private static func entrances() -> [AreaEntrance] {
        var entrances = [
            AreaEntrance(
                name: AreaEntrance.defaultName,
                point: AreaPoint(OfficeNavigationLayout.actorStart)
            )
        ]
        // V08's sole entrance sits on the camera-near right cutaway. The
        // authored interaction approach is already the exact, tested interior
        // landing point, so city return and ordinary door interaction share one
        // reachable threshold-side coordinate.
        if let standable = OfficeNavigationLayout.approachPoints["office.door"] {
            entrances.append(
                AreaEntrance(name: cityArrivalEntrance, point: AreaPoint(standable))
            )
        }
        return entrances
    }

    private static func hotspotRegions() -> [AreaRegion] {
        OfficeNavigationLayout.authoredHotspots.compactMap { hotspot in
            // One registered record owns both the door's hover outline and its
            // travel payload. The old `.info` twin is deliberately omitted.
            guard hotspot.id != "office.door" else { return nil }
            return AreaRegion(
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

    /// The way back out to Sable Row. This is also the door's one hover/click
    /// outline: registered systems must not carry duplicate `office.door` and
    /// `office.exit` records for one physical opening.
    private static func streetDoorRegion() -> AreaRegion {
        let authored = OfficeNavigationLayout.authoredHotspots.first {
            $0.id == "office.door"
        }
        return AreaRegion(
            id: "office.door",
            kind: .travel,
            label: authored?.name ?? "Office door",
            rect: authored.map { OfficeInteriorScale.mapRect($0.hitArea) }
                ?? OfficeNavigationLayout.doorObstacle,
            approachPoint: OfficeNavigationLayout.approachPoints["office.door"]
                .map(AreaPoint.init),
            travel: AreaTravel(
                destination: HarborpointAreas.sableRow,
                entrance: "from.office"
            ),
            observation: authored?.observation
            // Deliberately ungated. The city's *edge* exits carry the
            // "street stays closed" gate, but the office door itself ships
            // unconditional — the intro cutscene opens city travel before the
            // player regains input, so the gate would be unreachable anyway.
            // Authoring one here would quietly add behaviour at Phase 5, when
            // this region starts driving the door.
        )
    }

    /// Scenery the player can stand behind, as cover outlines.
    ///
    /// `qa_area_wed_split.py` measured which of the office's 55 placed sprites
    /// have reachable floor further from the camera than their own ground point
    /// — 28 of them. Those are the ones that hide the actor today and that a
    /// Baldur's Gate area would cover with a WED wall polygon rather than sort
    /// against.
    ///
    /// Authored here from the *obstacle* each piece already declares, because a
    /// prop's blocking footprint is the part of it standing on the floor, and
    /// that is what the player walks behind. The outline is that footprint
    /// carried camera-far by the piece's own depth so an actor is covered for as
    /// long as it is visually behind the art, not merely while its feet overlap.
    ///
    /// Deliberately a starting set rather than all 28: the desk cluster is
    /// excluded because it owns hand-tuned apron ordering that already reads
    /// correctly, and the waiting-nook pieces are low enough to sit under the
    /// actor's head. Widening this is an art-direction call about which pieces
    /// read as one mass, and is best made against captures.
    private static func wallPolygons() -> [AreaWallPolygon] {
        // The V18 radiator edit repairs the old hearth to ordinary wall/floor
        // pixels. The baked radiators sit within the shell boundary and need no
        // actor cover of their own.
        []
    }

    /// How far camera-far of a piece's footprint it still covers an actor.
    /// One search-map row per 12 world units; three rows is about a body's
    /// depth on the 0.75 ground foreshortening.
    private static let coverDepth: CGFloat = 36

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

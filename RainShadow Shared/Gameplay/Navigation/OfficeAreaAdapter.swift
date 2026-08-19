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
            searchMapName: "\(HarborpointAreas.office.rawValue).sr",
            obstacles: OfficeNavigationLayout.obstacles.map(AreaRect.init),
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
            script: AreaScriptCatalog.officeSuite.id
        )
    }

    // MARK: - Sections

    /// The office's scenery, read from what the renderer actually placed.
    ///
    /// `ArtSource/Generated/Office/office_props_v01.json` is written by
    /// `office_props_from_dump.py` from a `RAINSHADOW_DUMP_PROPS` run. Reading
    /// the scene graph rather than parsing `buildScene` is deliberate: placement
    /// runs through `OfficeInteriorScale.mapPoint`, several prop-relative scale
    /// tables and a dozen inline constructions, and re-deriving that in a parser
    /// means re-implementing it and hoping the two agree.
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
        return document.props
    }

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
        // Arriving from the street lands on the floor in front of the street
        // door rather than at the desk.
        //
        // Both components are taken from shipped geometry rather than typed:
        // the door's own centre line, at the floor depth the office already
        // starts the player on. Deliberately *not*
        // `approachPoints["office.door"]`, which sits at y 1257.9 — deeper into
        // the scene than the door itself (y 1163.1–1218.0) and therefore behind
        // the waiting-nook wall, where it renders the actor standing on the wall
        // crown. `AGENTS.md` states the rule this follows: an approach belongs on
        // the walkable side the door faces, camera-near, never at the door art.
        //
        // The search map cannot referee this. The office rasterises as walkable
        // across essentially its whole painted rect (y 952–1414 at nearly every
        // column), so it reports the wall-crown point as standable — which is the
        // same permissiveness behind the office geometry suite that is currently
        // red on `main`.
        // Seeded on the door's own centre line and then snapped by
        // `nearestWalkablePoint`, because the seed lands on the closed leaf's
        // blocking edge and the leaf is stamped shut at load. `AGENTS.md`: take
        // what `nearestWalkablePoint` gives you, and do not tidy the result.
        let seed = CGPoint(
            x: OfficeNavigationLayout.doorObstacle.midX,
            y: OfficeNavigationLayout.actorStart.y
        )
        if let standable = OfficeNavigationLayout.makeGrid().nearestWalkablePoint(to: seed) {
            entrances.append(
                AreaEntrance(name: cityArrivalEntrance, point: AreaPoint(standable))
            )
        }
        return entrances
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
            )
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
        // Authored plate space -> world, like every other coordinate here.
        let tall: [(String, CGRect)] = [
            ("wall.bookshelf", OfficeNavigationLayout.authoredBookshelfObstacle),
            ("wall.filingCabinet", OfficeNavigationLayout.authoredFilingCabinetObstacle),
            ("wall.safe", OfficeNavigationLayout.authoredSafeObstacle)
        ].map { ($0.0, OfficeInteriorScale.mapRect($0.1)) }
        return tall.map { id, footprint in
            // Cover reaches camera-far of the footprint by the depth the piece
            // occupies on screen; standing level with it is not behind it.
            let outline = CGRect(
                x: footprint.minX,
                y: footprint.minY,
                width: footprint.width,
                height: footprint.height + coverDepth
            )
            return AreaWallPolygon(id: id, rect: outline)
        }
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

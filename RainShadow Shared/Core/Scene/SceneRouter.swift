import SpriteKit

/// What kind of place an area is, from the router's point of view.
///
/// Opening exterior is a backdrop. Playable areas are `GameAreaScene`
/// specialisations: the office still owns cutscenes and a seated NPC, a
/// district still owns edge exits and the world map. Everything that is the
/// ARE+WED bundle — plate, doors, ambients, animations, cover, light maps,
/// triggers, clock — lives on the shared class and is driven by `.area.json`.
@MainActor
enum AreaSceneKind: Equatable {
    case openingExterior
    case office
    case district(CityDistrictID)
    case cityInterior(CityInteriorID)
    #if DEBUG
    case sableBlender
    #endif

    init?(_ areaID: AreaID) {
        #if DEBUG
        if areaID == SableBlenderPlaytest.exteriorID {
            self = .sableBlender
            return
        }
        #endif
        if areaID == HarborpointAreas.openingExterior {
            self = .openingExterior
        } else if areaID == HarborpointAreas.office {
            self = .office
        } else if let districtID = CityDistrictAreaAdapter.district(for: areaID) {
            self = .district(districtID)
        } else if let interiorID = CityInteriorAreaAdapter.interior(for: areaID) {
            self = .cityInterior(interiorID)
        } else {
            return nil
        }
    }

    /// Crossfade length on arrival. The office is the slower one because it
    /// lands on a cinematic beat; street-to-street travel is brisk.
    var transitionDuration: TimeInterval {
        switch self {
        case .openingExterior: 0
        case .office: 1.15
        case .district, .cityInterior: 0.75
        #if DEBUG
        case .sableBlender: 0.75
        #endif
        }
    }

    func makeScene(context: GameContext, entrance: String?) -> BaseGameScene {
        switch self {
        case .openingExterior:
            OpeningExteriorScene(context: context)
        case .office:
            DetectiveOfficeScene(context: context, entrance: entrance,
                                 authoredArea: context.router.isSableBlenderPlaytest
                                    ? SableBlenderPlaytest.office(from: HarborpointAreas.requireArea(HarborpointAreas.office))
                                    : nil)
        case .district(let districtID):
            CityDistrictScene(context: context, districtID: districtID, entrance: entrance)
        case .cityInterior(let interiorID):
            CityDistrictScene(context: context, interiorID: interiorID, entrance: entrance)
        #if DEBUG
        case .sableBlender:
            makeSableBlenderScene(context: context, entrance: entrance)
        #endif
        }
    }

    #if DEBUG
    private func makeSableBlenderScene(context: GameContext, entrance: String?) -> BaseGameScene {
        do {
            var area = try AreaCatalogLoader.load(SableBlenderPlaytest.exteriorID)
            if entrance == SableBlenderPlaytest.returnEntrance {
                // Returning through this doorway leaves its exterior tiles open.
                for index in area.doors.indices where area.doors[index].id == SableBlenderPlaytest.apartmentRegionID {
                    area.doors[index].startsClosed = false
                }
            }
            try AreaCatalogLoader.validateArea(area)
            return CityDistrictScene(context: context, playtestArea: area, entrance: entrance)
        } catch {
            preconditionFailure("Sable Row playtest bundle failed to load: \(error)")
        }
    }
    #endif
}

@MainActor
final class SceneRouter {
    unowned let context: GameContext
    private weak var view: SKView?
    private(set) var isTransitioning = false
    private(set) var isSableBlenderPlaytest = false
    /// Entrance name the next scene should spawn at. Consumed by `present`.
    private var pendingEntrance: String?

    init(context: GameContext) {
        self.context = context
    }

    func start(in view: SKView) {
        self.view = view
        // QA hook: jump straight to a scene, e.g. RAINSHADOW_START_SCENE=office.
        // RAINSHADOW_START_ENTRANCE=from.city lands at the street door instead of
        // the default start, so an entrance can be reviewed in the real app.
        pendingEntrance = ProcessInfo.processInfo.environment["RAINSHADOW_START_ENTRANCE"]
        #if DEBUG
        if ProcessInfo.processInfo.environment["RAINSHADOW_START_SCENE"] == "sable_blender" {
            isSableBlenderPlaytest = true
            // This launch has its own save. A doorway test should enter free
            // play rather than restart the opening/client cinematic.
            context.session.markOpeningSeen()
            context.session.markOfficeCaseIntroCompleted()
            present(.sableBlender, transition: nil)
            return
        }
        #endif
        if ProcessInfo.processInfo.environment["RAINSHADOW_START_SCENE"] == "office" {
            context.session.markOpeningSeen()
            present(.office, transition: nil)
            return
        }
        if ProcessInfo.processInfo.environment["RAINSHADOW_START_SCENE"] == "city" {
            // RAINSHADOW_START_DISTRICT=wharf_ladder picks the ward; without it
            // you land in Sable Row as before.
            let slug = ProcessInfo.processInfo.environment["RAINSHADOW_START_DISTRICT"]
            let district = CityDistrictID.allCases.first { $0.slug == slug } ?? .sableRow
            context.session.markOpeningSeen()
            context.session.markCityTravelOpen()
            // `setCurrentCityDistrict` rather than `markCityDistrictVisited`: it
            // marks visited too, and it is what tells the world map and the fog
            // store which ward you are actually standing in. Marking only visited
            // left `currentCityDistrict` at its Sable Row default, so launching
            // into another ward reported the wrong one.
            context.session.setCurrentCityDistrict(district)
            present(.district(district), transition: nil)
            return
        }
        present(.openingExterior, transition: nil)
    }

    // MARK: - Travel

    /// Move the player to a named entrance of another area.
    ///
    /// This is the Infinity Engine's whole transition vocabulary: a travel
    /// region or world-map link names a destination area *and* an entry point in
    /// it, and the destination places the party there without knowing who sent
    /// them. RainShadow previously had one entry per destination kind, and the
    /// office's ignored its argument outright — `showOffice(arrivalKey:)` opened
    /// with `_ = arrivalKey`, so walking in from Sable Row put Voss wherever the
    /// office's fixed start happened to be rather than at the door he used.
    ///
    /// An unroutable area is an authoring error rather than a runtime condition;
    /// `AreaCatalogTests` already rejects a travel region pointing at an area
    /// that is not in the catalog.
    func travel(to areaID: AreaID, entrance: String = AreaEntrance.defaultName) {
        guard !isTransitioning else { return }
        guard let kind = AreaSceneKind(areaID) else {
            assertionFailure("SceneRouter has no scene for area '\(areaID)'")
            return
        }

        isTransitioning = true
        pendingEntrance = entrance

        switch kind {
        case .openingExterior:
            break
        case .office:
            context.session.markOpeningSeen()
        case .district(let districtID):
            context.session.markCityTravelOpen()
            context.session.setCurrentCityDistrict(districtID)
        case .cityInterior:
            break
        #if DEBUG
        case .sableBlender:
            break
        #endif
        }

        let duration = kind.transitionDuration
        let transition = SKTransition.crossFade(withDuration: duration)
        transition.pausesOutgoingScene = false
        transition.pausesIncomingScene = false
        present(kind, transition: transition)

        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.05) { [weak self] in
            self?.isTransitioning = false
        }
    }

    // MARK: - Presentation

    private func present(_ kind: AreaSceneKind, transition: SKTransition?) {
        guard let view else { return }
        let entrance = pendingEntrance
        pendingEntrance = nil

        let scene = AreaLoadTrace.measure("router.makeScene", "\(kind)") {
            kind.makeScene(context: context, entrance: entrance)
        }
        scene.scaleMode = .resizeFill
        if let transition, view.scene != nil {
            view.presentScene(scene, transition: transition)
        } else {
            view.presentScene(scene)
        }
    }
}

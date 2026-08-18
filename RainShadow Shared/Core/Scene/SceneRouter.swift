import SpriteKit

/// What kind of place an area is, from the router's point of view.
///
/// One decision, made once. Three scene classes still exist — the office carries
/// cutscenes, an NPC and containers; a district carries edge exits and the world
/// map; the exterior is a backdrop with no navigable floor — so something has to
/// choose between them. Answering "which kind" separately in three places
/// (can it be presented, how long is the fade, which class to build) is how
/// those answers drift apart, so they all derive from this.
///
/// `GameRoute` used to be an enum with one case per location, which meant adding
/// a place to the world meant editing the enum and every switch over it. A
/// destination is an area id — that is what BG's travel regions and world-map
/// links carry — and this is the lookup the engine does with it. When the
/// office's props become data and the classes collapse into one `GameAreaScene`,
/// this type is the only thing that has to go.
@MainActor
enum AreaSceneKind: Equatable {
    case openingExterior
    case office
    case district(CityDistrictID)

    init?(_ areaID: AreaID) {
        if areaID == HarborpointAreas.openingExterior {
            self = .openingExterior
        } else if areaID == HarborpointAreas.office {
            self = .office
        } else if let districtID = CityDistrictAreaAdapter.district(for: areaID) {
            self = .district(districtID)
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
        case .district: 0.75
        }
    }

    func makeScene(context: GameContext, entrance: String?) -> BaseGameScene {
        switch self {
        case .openingExterior:
            OpeningExteriorScene(context: context)
        case .office:
            DetectiveOfficeScene(context: context, entrance: entrance)
        case .district(let districtID):
            CityDistrictScene(context: context, districtID: districtID, entrance: entrance)
        }
    }
}

@MainActor
final class SceneRouter {
    unowned let context: GameContext
    private weak var view: SKView?
    private(set) var isTransitioning = false
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
            context.session.markCityDistrictVisited(district)
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

        let scene = kind.makeScene(context: context, entrance: entrance)
        scene.scaleMode = .resizeFill
        if let transition, view.scene != nil {
            view.presentScene(scene, transition: transition)
        } else {
            view.presentScene(scene)
        }
    }
}

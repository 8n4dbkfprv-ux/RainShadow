import SpriteKit

enum GameRoute {
    case openingExterior
    case detectiveOffice
    case cityDistrict(CityDistrictID)

    /// The area this route presents.
    ///
    /// Phase 5 collapses `GameRoute` into `case area(AreaID)` once one scene
    /// class runs every area. Until then this pair of conversions is the bridge:
    /// travel is expressed in areas and entrances, and the router translates.
    var areaID: AreaID {
        switch self {
        case .openingExterior:
            HarborpointAreas.openingExterior
        case .detectiveOffice:
            HarborpointAreas.office
        case .cityDistrict(let districtID):
            CityDistrictAreaAdapter.areaID(for: districtID)
        }
    }

    init?(areaID: AreaID) {
        switch areaID {
        case HarborpointAreas.openingExterior:
            self = .openingExterior
        case HarborpointAreas.office:
            self = .detectiveOffice
        default:
            guard let districtID = CityDistrictAreaAdapter.district(for: areaID) else {
                return nil
            }
            self = .cityDistrict(districtID)
        }
    }

    /// Crossfade length. The office arrival is the slower one because it lands
    /// on a cinematic beat; street-to-street travel is brisk.
    var transitionDuration: TimeInterval {
        switch self {
        case .openingExterior: 0
        case .detectiveOffice: 1.15
        case .cityDistrict: 0.75
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
            present(.detectiveOffice, transition: nil)
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
            present(.cityDistrict(district), transition: nil)
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
        guard let route = GameRoute(areaID: areaID) else {
            assertionFailure("SceneRouter has no route for area '\(areaID)'")
            return
        }

        isTransitioning = true
        pendingEntrance = entrance

        switch route {
        case .openingExterior:
            break
        case .detectiveOffice:
            context.session.markOpeningSeen()
        case .cityDistrict(let districtID):
            context.session.markCityTravelOpen()
            context.session.setCurrentCityDistrict(districtID)
        }

        let duration = route.transitionDuration
        let transition = SKTransition.crossFade(withDuration: duration)
        transition.pausesOutgoingScene = false
        transition.pausesIncomingScene = false
        present(route, transition: transition)

        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.05) { [weak self] in
            self?.isTransitioning = false
        }
    }

    // MARK: - Presentation

    private func present(_ route: GameRoute, transition: SKTransition?) {
        guard let view else { return }
        let entrance = pendingEntrance
        pendingEntrance = nil

        let scene: BaseGameScene
        switch route {
        case .openingExterior:
            scene = OpeningExteriorScene(context: context)
        case .detectiveOffice:
            scene = DetectiveOfficeScene(context: context, entrance: entrance)
        case .cityDistrict(let districtID):
            scene = CityDistrictScene(
                context: context,
                districtID: districtID,
                entrance: entrance
            )
        }

        scene.scaleMode = .resizeFill
        if let transition, view.scene != nil {
            view.presentScene(scene, transition: transition)
        } else {
            view.presentScene(scene)
        }
    }
}

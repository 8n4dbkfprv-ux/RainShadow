import SpriteKit
#if os(macOS)
import AppKit
#endif

/// Shared playable-area scene: plate, doors, cover, ambients, fog hooks.
///
/// `CityDistrictScene` and (later) a data-driven office both need the same ARE
/// bundle load. The office still has its own class for cutscenes and containers;
/// districts already call into this base.
@MainActor
class GameAreaScene: BaseGameScene {
    struct DoorUseResult {
        let walkTo: CGPoint
        let lockedLine: String?
    }

    let areaID: AreaID
    let areaEntranceName: String?

    private(set) var plateNode: SKSpriteNode?
    private var doorClosed: [String: Bool] = [:]
    private var doorOutlineOverlay: SKNode?
    private var showingDoorOutlines = false
    private var usesExtendedNight = false
    private var actorCoverLift: CGFloat = 0

    var area: AreaDefinition {
        guard let areaRuntime else {
            preconditionFailure("GameAreaScene read area before loadArea ran")
        }
        return areaRuntime.area
    }

    var navigation: NavigationMap {
        guard let areaRuntime else {
            preconditionFailure("GameAreaScene read navigation before loadArea ran")
        }
        return areaRuntime.navigation
    }

    init(
        context: GameContext,
        areaID: AreaID,
        entrance: String? = nil,
        artSize: CGSize
    ) {
        self.areaID = areaID
        self.areaEntranceName = entrance
        super.init(context: context, artSize: artSize)
        loadArea(AreaRuntime(
            area: HarborpointAreas.requireArea(areaID),
            playerActorID: Self.detectiveActorID
        ))
        for door in area.doors {
            doorClosed[door.id] = door.startsClosed
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("GameAreaScene is created programmatically")
    }

    /// Plate, ambients, door stamps — the ARE payload every playable area shares.
    func buildAreaBundle() {
        buildAmbients(from: area)
        installPlate(named: activePlateTextureName)
        applyDoorStamps()
    }

    /// Day plate by default; Extended Night swaps when a night plate is authored.
    var activePlateTextureName: String {
        if usesExtendedNight, let night = area.nightPlateTextureName {
            return night
        }
        return area.plateTextureName
    }

    /// Swap the background for the Extended Night plate (or back to day).
    ///
    /// Does not blue-multiply the day art. When `nightPlateTextureName` is
    /// missing, the call is a no-op and returns false so callers can say so.
    @discardableResult
    func setExtendedNight(_ enabled: Bool) -> Bool {
        guard area.nightPlateTextureName != nil else { return false }
        guard usesExtendedNight != enabled else { return true }
        usesExtendedNight = enabled
        installPlate(named: activePlateTextureName)
        return true
    }

    func door(matching id: String) -> AreaDoor? {
        area.doors.first { $0.id == id }
    }

    func useDoor(
        _ door: AreaDoor,
        from point: CGPoint,
        fallback: CGPoint
    ) -> DoorUseResult {
        let walkTo = door.walkTarget(from: point, fallback: fallback)
        return DoorUseResult(walkTo: walkTo, lockedLine: nil)
    }

    func openDoor(_ door: AreaDoor) {
        doorClosed[door.id] = false
        applyDoorStamps()
        if let sound = door.openSound {
            _ = GameSFX.play(sound, on: .voice)
        }
        doorVisibilityDidChange()
    }

    func closeDoor(_ door: AreaDoor) {
        doorClosed[door.id] = true
        applyDoorStamps()
        if let sound = door.closeSound {
            _ = GameSFX.play(sound, on: .voice)
        }
        doorVisibilityDidChange()
    }

    /// Scenes with fog override to `invalidateSight` — opening a street door must
    /// recompute LOS immediately, not wait for the next footstep.
    func doorVisibilityDidChange() {}

    func isDoorClosed(_ door: AreaDoor) -> Bool {
        doorClosed[door.id] ?? door.startsClosed
    }

    /// Outdoor BG:EE door outlines — Tab toggles cyan vertex polylines over
    /// every travel region's authored polygon (the ARE door click outline).
    override func handleHighlightInput() {
        toggleDoorOutlineHighlight()
    }

    func toggleDoorOutlineHighlight() {
        showingDoorOutlines.toggle()
        doorOutlineOverlay?.removeFromParent()
        doorOutlineOverlay = nil
        guard showingDoorOutlines else { return }
        let root = SKNode()
        root.name = "door.outlines"
        root.zPosition = 50
        for region in area.regions where region.kind == .travel || door(matching: region.id) != nil {
            let path = CGMutablePath()
            let points = region.polygon.map(\.cgPoint)
            guard let first = points.first else { continue }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            path.closeSubpath()
            let shape = SKShapeNode(path: path)
            shape.strokeColor = SKColor(red: 0.25, green: 0.92, blue: 0.95, alpha: 0.95)
            shape.lineWidth = 2.5
            shape.fillColor = .clear
            shape.glowWidth = 0.5
            root.addChild(shape)
        }
        debugRoot.addChild(root)
        doorOutlineOverlay = root
    }

    func applyActorCover(to actor: SKNode, at point: CGPoint) {
        let covered = areaRuntime?.isCovered(point) ?? false
        let lift = ActorCover.apply(to: actor, covered: covered)
        if lift != actorCoverLift {
            actorCoverLift = lift
        }
        updateDepth(of: actor, bias: lift)
    }

    func tickAreaSystems(listenerAt point: CGPoint, currentTime: TimeInterval) {
        _ = point
        _ = currentTime
        tickAreaScript()
    }

    /// Whether fog should use the outdoor-door shroud (explored-only beyond a
    /// closed sight-blocking leaf) instead of hard LOS stop.
    var outdoorDoorShroud: Bool { area.kind == .exterior }

    private func applyDoorStamps() {
        let closedDoors = area.doors.compactMap { door -> DoorObstacle? in
            guard doorClosed[door.id] ?? door.startsClosed else { return nil }
            return door.searchMapObstacle
        }
        navigation.setActiveDoorObstacles(closedDoors)
    }

    private func installPlate(named textureName: String) {
        plateNode?.removeFromParent()
        plateNode = nil
        guard let texture = GameArt.texture(named: textureName) else {
            assertionFailure("Missing area plate \(textureName)")
            return
        }
        texture.filteringMode = .linear
        let background = SKSpriteNode(texture: texture, size: artSize)
        background.name = textureName
        background.anchorPoint = .zero
        background.position = .zero
        backgroundRoot.addChild(background)
        plateNode = background
    }
}

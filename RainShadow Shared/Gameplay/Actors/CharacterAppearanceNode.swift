import SpriteKit

/// Reusable visual component for NPCs/enemies. The owning actor supplies its
/// Movable's facing and stance; class, AI, movement and hostility stay outside.
/// Frames are loaded lazily and retain their authored registration in every layer.
@MainActor
final class CharacterAppearanceNode: SKNode, WallStencilledActor {
    private(set) var definition: CharacterDefinition
    private(set) var currentAction: CharacterVisualAction = .idle
    private(set) var currentFacing: ActorFacing = .south
    private(set) var currentPhase = 0
    private var playback = IEActorAnimationPlayback()
    private let body = IEAvatarNode(frame: nil)
    private var equipmentNodes: [CharacterEquipmentCode: IEAvatarNode] = [:]
    private var resources: Resources
    private let contactShadow = ContactShadowFactory.make(kind: .npc)
    private var sceneLighting: ActorSceneLighting = .neutral
    private var footLight: AreaLightSample?
    private weak var stencil: WallStencilTexture?
    private weak var stencilScene: SKScene?

    var visualHeightOffset: CGFloat = 0 {
        didSet { layers.forEach { $0.position.y = visualHeightOffset } }
    }

    private var layers: [IEAvatarNode] { [body] + Array(equipmentNodes.values) }

    private struct Resources {
        let body: IEAvatarFrameLibrary
        let equipment: [CharacterEquipmentCode: IEAvatarFrameLibrary]
        let bowShot: IEAvatarFrameLibrary?

        init(appearance: CharacterAppearance) throws {
            try appearance.validate()
            body = try IEAvatarFrameLibrary.shared(appearance: appearance)
            var equipment: [CharacterEquipmentCode: IEAvatarFrameLibrary] = [:]
            for layer in appearance.equipment {
                let base = try IEAvatarFrameLibrary.shared(character: layer.item.character)
                try layer.item.validate(base.sprite)
                equipment[layer.item] = try IEAvatarFrameLibrary.shared(character: layer.item.character,
                    colors: layer.colors?.applying(to: base.colors) ?? base.colors)
            }
            self.equipment = equipment
            if appearance.body == .humanMale01 && Set(equipment.keys) == [.elvenCourtBow, .elvenCourtArrow] {
                let library = try IEAvatarFrameLibrary.shared(character: BowAttackAnimationSet.character,
                    colors: body.colors)
                try BowAttackAnimationSet.validate(library.sprite)
                bowShot = library
            } else { bowShot = nil }
        }

        func frames(appearance: CharacterAppearance, action: CharacterVisualAction,
                    facing: ActorFacing, phase: Int) throws -> (IEAvatarVisualFrame, [CharacterEquipmentCode: IEAvatarVisualFrame]) {
            if action == .shoot {
                guard let library = bowShot else {
                    throw CharacterAppearanceError.unsupportedAction(appearance.body, action)
                }
                let name = try appearance.body.frameName(action: action, facing: facing, phase: phase)
                guard let frame = library.frame(atlas: BowAttackAnimationSet.atlas, name: name) else {
                    throw CharacterAppearanceError.missingFrame(BowAttackAnimationSet.atlas, name)
                }
                return (frame, [:])
            }
            let name = try appearance.body.frameName(action: action, facing: facing, phase: phase)
            guard let frame = body.frame(atlas: appearance.body.atlas, name: name) else {
                throw CharacterAppearanceError.missingFrame(appearance.body.atlas, name)
            }
            var overlays: [CharacterEquipmentCode: IEAvatarVisualFrame] = [:]
            for (item, library) in equipment where item.supports(action: action) {
                let equipmentName = item == .ironHelmet
                    ? VossArmorAppearance.ironHelmet.frameName(matching: .init(atlas: appearance.body.atlas, name: name),
                        wearingMail: appearance.equipment.contains { $0.item == .splintMail }) ?? name
                    : name
                guard let overlay = library.frame(atlas: item.atlas, name: equipmentName) else {
                    throw CharacterAppearanceError.missingFrame(item.atlas, equipmentName)
                }
                overlays[item] = overlay
            }
            return (frame, overlays)
        }
    }

    init(definition: CharacterDefinition) throws {
        self.definition = definition
        resources = try Resources(appearance: definition.appearance)
        super.init()
        name = definition.id
        contactShadow.isHidden = resources.body.sprite.hasEmbeddedShadow
        addChild(contactShadow)
        addChild(body)
        body.name = "appearance.body"
        body.setScale(OfficeInteriorScale.ActorDisplay.spriteScale)
        rebuildEquipmentNodes()
        try present(action: .idle, facing: .south, phase: 0)
    }

    required init?(coder: NSCoder) { fatalError("CharacterAppearanceNode is created programmatically") }

    /// Validate and prepare the entire replacement before changing anything visible.
    /// Changing class/faction alone does not reload artwork or restart animation.
    func apply(_ definition: CharacterDefinition) throws {
        guard definition.appearance != self.definition.appearance else {
            self.definition = definition
            name = definition.id
            return
        }
        let replacement = try Resources(appearance: definition.appearance)
        let changedBody = definition.appearance.body != self.definition.appearance.body
        let phase = changedBody ? 0 : currentPhase
        let frames = try replacement.frames(appearance: definition.appearance, action: currentAction,
                                            facing: currentFacing, phase: phase)
        resources = replacement
        self.definition = definition
        name = definition.id
        if changedBody { playback = IEActorAnimationPlayback() }
        currentPhase = phase
        contactShadow.isHidden = resources.body.sprite.hasEmbeddedShadow
        rebuildEquipmentNodes()
        install(frames)
    }

    /// Explicit phase access also supports non-looping authored chair transitions.
    func present(action: CharacterVisualAction, facing: ActorFacing, phase: Int) throws {
        let frames = try resources.frames(appearance: definition.appearance,
                                           action: action, facing: facing, phase: phase)
        currentAction = action; currentFacing = facing; currentPhase = phase
        install(frames)
    }

    /// The same independent 15-fps clock used by Voss and Lila. Only looping
    /// stances enter this API; transition endpoints belong to the caller.
    func advance(action: CharacterVisualAction, facing: ActorFacing,
                 at time: TimeInterval, paused: Bool) throws {
        guard action == .idle || action == .walk || action == .seatedIdle else {
            throw CharacterAppearanceError.unsupportedAction(definition.appearance.body, action)
        }
        let count = try definition.appearance.body.frameCount(for: action, facing: facing)
        let key = "\(action.rawValue).\(facing.rawValue)"
        let phase = playback.frame(for: key, count: count, at: time, paused: paused)
        try present(action: action, facing: facing, phase: phase)
    }

    private func rebuildEquipmentNodes() {
        equipmentNodes.values.forEach { $0.removeFromParent() }
        equipmentNodes = [:]
        for item in resources.equipment.keys {
            let node = IEAvatarNode(frame: nil)
            node.name = "appearance." + item.rawValue
            node.zPosition = CGFloat(item.layerOrder) * 0.01
            node.setScale(OfficeInteriorScale.ActorDisplay.spriteScale)
            node.position.y = visualHeightOffset
            equipmentNodes[item] = node
            addChild(node)
        }
    }

    private func install(_ frames: (IEAvatarVisualFrame, [CharacterEquipmentCode: IEAvatarVisualFrame])) {
        body.apply(frames.0)
        for (item, node) in equipmentNodes {
            if let frame = frames.1[item] { node.apply(frame) } else { node.clear() }
        }
        refreshLighting()
        if let stencilScene { applyWallStencil(stencil, in: stencilScene) }
    }

    func applySceneLighting(_ lighting: ActorSceneLighting) {
        sceneLighting = lighting
        refreshLighting()
    }

    func applyFootLight(_ sample: AreaLightSample?) {
        footLight = sample
        refreshLighting()
    }

    /// Uses the existing engine tint operations without changing their arithmetic.
    private func refreshLighting() {
        var flags: IEBlitFlags = .blended
        var tint = IEColor.opaqueWhite
        if let footLight { flags.insert(.colorMod); tint = footLight.ieColor }
        IEBlit.applyGlobalTint(&tint, &flags, global: sceneLighting.globalTint)
        flags.formUnion((scene as? BaseGameScene)?.worldBlitFlags ?? [])
        for layer in layers {
            IEBlitShader.update(layer.blitShader, tint: tint, flags: flags)
            layer.shader = layer.blitShader
            layer.colorBlendFactor = 0
        }
        contactShadow.alpha = ContactShadowKind.npc.standingAlpha * sceneLighting.contactShadowAlphaScale
    }

    func applyWallStencil(_ stencil: WallStencilTexture?, in scene: SKScene) {
        self.stencil = stencil
        stencilScene = scene
        for layer in layers {
            if let stencil { stencil.apply(to: layer, in: scene) }
            else { WallStencilTexture.clear(on: layer) }
        }
    }
}

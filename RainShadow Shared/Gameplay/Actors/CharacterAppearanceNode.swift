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
    private(set) var currentTechnique: CombatManeuver?
    private(set) var currentStealth: StealthClip?
    private(set) var currentReaction: CombatReactionKind?
    private var playback = IEActorAnimationPlayback()
    private let body = IEAvatarNode(frame: nil)
    private var equipmentNodes: [CharacterEquipmentCode: IEAvatarNode] = [:]
    private var resources: Resources
    private var attackTrail: IEAvatarNode?
    func setCombatRecoil(_ angle: CGFloat) { layers.forEach { $0.zRotation = angle } }

    private let contactShadow = ContactShadowFactory.make(kind: .npc)
    private var sceneLighting: ActorSceneLighting = .neutral
    private var footLight: AreaLightSample?
    private weak var stencil: WallStencilTexture?
    private weak var stencilScene: SKScene?

    var visualHeightOffset: CGFloat = 0 {
        didSet { layers.forEach { $0.position.y = visualHeightOffset } }
    }

    private var layers: [IEAvatarNode] { [body] + Array(equipmentNodes.values) + [attackTrail].compactMap { $0 } }

    /// Transient sword motion is a separate layer, sharing actor registration,
    /// lighting and per-layer stencil handling without changing the sprite art.
    func setAttackTrail(_ layer: IEAvatarNode?) {
        attackTrail?.removeFromParent(); attackTrail = layer
        if let layer {
            layer.zPosition = -0.01
            layer.setScale(OfficeInteriorScale.ActorDisplay.spriteScale)
            layer.position.y = visualHeightOffset
            addChild(layer)
        }
        refreshLighting()
        if let stencilScene { applyWallStencil(stencil, in: stencilScene) }
    }

    private struct Resources {
        let body: IEAvatarFrameLibrary
        let bearRoar: IEAvatarFrameLibrary?
        let bearClaw: IEAvatarFrameLibrary?
        let equipment: [CharacterEquipmentCode: IEAvatarFrameLibrary]
        let bowShot: IEAvatarFrameLibrary?
        let bowEquipment: [CharacterEquipmentCode: IEAvatarFrameLibrary]
        let tripBody: IEAvatarFrameLibrary?
        let tripEquipment: [CharacterEquipmentCode: IEAvatarFrameLibrary]
        let wardBody: IEAvatarFrameLibrary?
        let wardEquipment: [CharacterEquipmentCode: IEAvatarFrameLibrary]
        let shoveBody: IEAvatarFrameLibrary?
        let shoveEquipment: [CharacterEquipmentCode: IEAvatarFrameLibrary]
        let defeatBody: IEAvatarFrameLibrary?
        let defeatEquipment: [CharacterEquipmentCode: IEAvatarFrameLibrary]
        let stealthBody: IEAvatarFrameLibrary?
        let stealthBow: IEAvatarFrameLibrary?
        let stealthEquipment: [CharacterEquipmentCode: IEAvatarFrameLibrary]
        let knockbackBody: IEAvatarFrameLibrary?
        let knockbackEquipment: [CharacterEquipmentCode: IEAvatarFrameLibrary]
        let tripReactionBody: IEAvatarFrameLibrary?
        let tripReactionEquipment: [CharacterEquipmentCode: IEAvatarFrameLibrary]
        let reactionBody: IEAvatarFrameLibrary?
        let reactionEquipment: [CharacterEquipmentCode: IEAvatarFrameLibrary]
        let meleeBody: IEAvatarFrameLibrary?
        let techniqueBody: IEAvatarFrameLibrary?
        let pinningShot: IEAvatarFrameLibrary?
        let techniqueEquipment: [CharacterEquipmentCode: IEAvatarFrameLibrary]
        let meleeEquipment: [CharacterEquipmentCode: IEAvatarFrameLibrary]

        init(appearance: CharacterAppearance) throws {
            try appearance.validate()
            body = try IEAvatarFrameLibrary.shared(appearance: appearance)
            if appearance.body == .bearGuardian {
                let library = try IEAvatarFrameLibrary.shared(character: BearRoarAnimationSet.character, colors: body.colors)
                try BearRoarAnimationSet.validate(library.sprite)
                bearRoar = library
                let claw = try IEAvatarFrameLibrary.shared(character: BearClawAnimationSet.character, colors: body.colors)
                try BearClawAnimationSet.validate(claw.sprite)
                bearClaw = claw
            } else { bearRoar = nil; bearClaw = nil }
            var equipment: [CharacterEquipmentCode: IEAvatarFrameLibrary] = [:]
            for layer in appearance.equipment {
                let base = try IEAvatarFrameLibrary.shared(character: layer.item.character)
                try layer.item.validate(base.sprite)
                equipment[layer.item] = try IEAvatarFrameLibrary.shared(character: layer.item.character,
                    colors: layer.colors?.applying(to: base.colors) ?? base.colors)
            }
            self.equipment = equipment
            var tripEquipment: [CharacterEquipmentCode: IEAvatarFrameLibrary] = [:]
            var wardEquipment: [CharacterEquipmentCode: IEAvatarFrameLibrary] = [:]
            var shoveEquipment: [CharacterEquipmentCode: IEAvatarFrameLibrary] = [:]
            var defeatEquipment: [CharacterEquipmentCode: IEAvatarFrameLibrary] = [:]
            var stealthEquipment: [CharacterEquipmentCode: IEAvatarFrameLibrary] = [:]
            var knockbackEquipment: [CharacterEquipmentCode: IEAvatarFrameLibrary] = [:]
            var tripReactionEquipment: [CharacterEquipmentCode: IEAvatarFrameLibrary] = [:]
            var reactionEquipment: [CharacterEquipmentCode: IEAvatarFrameLibrary] = [:]
            var meleeEquipment: [CharacterEquipmentCode: IEAvatarFrameLibrary] = [:]
            var techniqueEquipment: [CharacterEquipmentCode: IEAvatarFrameLibrary] = [:]
            if appearance.body == .humanMale01 {
                let trip = try IEAvatarFrameLibrary.shared(character: TripAnimationSet.body, colors: body.colors)
                try TripAnimationSet.validate(trip.sprite, character: TripAnimationSet.body)
                tripBody = trip
                for (item, base) in equipment {
                    guard let name = TripAnimationSet.equipment(item) else { continue }
                    let layer = try IEAvatarFrameLibrary.shared(character: name, colors: base.colors)
                    try TripAnimationSet.validate(layer.sprite, character: name)
                    tripEquipment[item] = layer
                }
                let ward = try IEAvatarFrameLibrary.shared(character: BladeWardAnimationSet.body, colors: body.colors)
                try BladeWardAnimationSet.validate(ward.sprite, character: BladeWardAnimationSet.body)
                wardBody = ward
                for (item, base) in equipment where item != .elvenCourtArrow && item != .elvenCourtBow {
                    let name = BladeWardAnimationSet.equipment(item)
                    let layer = try IEAvatarFrameLibrary.shared(character: name, colors: base.colors)
                    try BladeWardAnimationSet.validate(layer.sprite, character: name)
                    wardEquipment[item] = layer
                }
                let shove = try IEAvatarFrameLibrary.shared(character: ShoveAnimationSet.body, colors: body.colors)
                try ShoveAnimationSet.validate(shove.sprite, character: ShoveAnimationSet.body)
                shoveBody = shove
                for (item, base) in equipment where item != .elvenCourtArrow {
                    let name = ShoveAnimationSet.equipment(item)
                    let layer = try IEAvatarFrameLibrary.shared(character: name, colors: base.colors)
                    try ShoveAnimationSet.validate(layer.sprite, character: name)
                    shoveEquipment[item] = layer
                }
                let defeat = try IEAvatarFrameLibrary.shared(character: DefeatAnimationSet.body, colors: body.colors)
                try DefeatAnimationSet.validate(defeat.sprite, character: DefeatAnimationSet.body)
                defeatBody = defeat
                for (item, base) in equipment {
                    let name = DefeatAnimationSet.equipment(item)
                    let layer = try IEAvatarFrameLibrary.shared(character: name, colors: base.colors)
                    try DefeatAnimationSet.validate(layer.sprite, character: name)
                    defeatEquipment[item] = layer
                }
                let stealth = try IEAvatarFrameLibrary.shared(character: StealthAnimationSet.body, colors: body.colors)
                try StealthAnimationSet.validate(stealth.sprite, character: StealthAnimationSet.body)
                stealthBody = stealth
                for (item, base) in equipment {
                    let name = StealthAnimationSet.equipment(item)
                    let layer = try IEAvatarFrameLibrary.shared(character: name, colors: base.colors)
                    try StealthAnimationSet.validate(layer.sprite, character: name)
                    stealthEquipment[item] = layer
                }
                let tripReaction = try IEAvatarFrameLibrary.shared(character: CombatReactionAnimationSet.tripBody, colors: body.colors)
                try CombatReactionAnimationSet.validate(tripReaction.sprite, character: CombatReactionAnimationSet.tripBody)
                tripReactionBody = tripReaction
                for (item, base) in equipment {
                    guard let name = CombatReactionAnimationSet.tripEquipment(item) else { continue }
                    let layer = try IEAvatarFrameLibrary.shared(character: name, colors: base.colors)
                    try CombatReactionAnimationSet.validate(layer.sprite, character: name)
                    tripReactionEquipment[item] = layer
                }
                let reaction = try IEAvatarFrameLibrary.shared(character: CombatReactionAnimationSet.body, colors: body.colors)
                try CombatReactionAnimationSet.validate(reaction.sprite, character: CombatReactionAnimationSet.body)
                reactionBody = reaction
                let knockback = try IEAvatarFrameLibrary.shared(character: CombatReactionAnimationSet.knockbackBody, colors: body.colors)
                try CombatReactionAnimationSet.validate(knockback.sprite, character: CombatReactionAnimationSet.knockbackBody)
                knockbackBody = knockback
                for (item, base) in equipment {
                    let character = CombatReactionAnimationSet.equipment(item)
                    let layer = try IEAvatarFrameLibrary.shared(character: character, colors: base.colors)
                    try CombatReactionAnimationSet.validate(layer.sprite, character: character)
                    reactionEquipment[item] = layer
                    let knockbackName = CombatReactionAnimationSet.knockbackEquipment(item)
                    let knockbackLayer = try IEAvatarFrameLibrary.shared(character: knockbackName, colors: base.colors)
                    try CombatReactionAnimationSet.validate(knockbackLayer.sprite, character: knockbackName)
                    knockbackEquipment[item] = knockbackLayer
                }
                let library = try IEAvatarFrameLibrary.shared(character: MeleeAttackAnimationSet.body, colors: body.colors)
                try MeleeAttackAnimationSet.validate(library.sprite, character: MeleeAttackAnimationSet.body)
                meleeBody = library
                let technique = try IEAvatarFrameLibrary.shared(character: WeaponTechniqueAnimationSet.body, colors: body.colors)
                try WeaponTechniqueAnimationSet.validate(technique.sprite, character: WeaponTechniqueAnimationSet.body)
                techniqueBody = technique
                for (item, base) in equipment {
                    guard let character = MeleeAttackAnimationSet.equipment(item) else { continue }
                    let layer = try IEAvatarFrameLibrary.shared(character: character, colors: base.colors)
                    try MeleeAttackAnimationSet.validate(layer.sprite, character: character)
                    meleeEquipment[item] = layer
                    if let character = WeaponTechniqueAnimationSet.equipment(item) {
                        let technique = try IEAvatarFrameLibrary.shared(character: character, colors: base.colors)
                        try WeaponTechniqueAnimationSet.validate(technique.sprite, character: character)
                        techniqueEquipment[item] = technique
                    }
                }
            } else { tripReactionBody = nil; tripBody = nil; meleeBody = nil; techniqueBody = nil; reactionBody = nil; knockbackBody = nil; stealthBody = nil; defeatBody = nil; shoveBody = nil; wardBody = nil }
            self.tripReactionEquipment = tripReactionEquipment
            self.tripEquipment = tripEquipment
            self.wardEquipment = wardEquipment
            self.shoveEquipment = shoveEquipment
            self.defeatEquipment = defeatEquipment
            self.stealthEquipment = stealthEquipment
            self.reactionEquipment = reactionEquipment
            self.knockbackEquipment = knockbackEquipment
            self.techniqueEquipment = techniqueEquipment
            self.meleeEquipment = meleeEquipment
            var bowEquipment: [CharacterEquipmentCode: IEAvatarFrameLibrary] = [:]
            if appearance.body == .humanMale01 && equipment[.elvenCourtBow] != nil && equipment[.elvenCourtArrow] != nil {
                let library = try IEAvatarFrameLibrary.shared(character: BowAttackAnimationSet.character,
                    colors: body.colors)
                try BowAttackAnimationSet.validate(library.sprite)
                bowShot = library
                let sneak = try IEAvatarFrameLibrary.shared(character: StealthAnimationSet.bow, colors: body.colors)
                try StealthAnimationSet.validate(sneak.sprite, character: StealthAnimationSet.bow)
                stealthBow = sneak
                let pin = try IEAvatarFrameLibrary.shared(character: WeaponTechniqueAnimationSet.pinning, colors: body.colors)
                try WeaponTechniqueAnimationSet.validate(pin.sprite, character: WeaponTechniqueAnimationSet.pinning)
                pinningShot = pin
                for (item, base) in equipment {
                    guard let name = BowAttackAnimationSet.equipment(item) else { continue }
                    let layer = try IEAvatarFrameLibrary.shared(character: name, colors: base.colors)
                    try BowAttackAnimationSet.validateEquipment(layer.sprite, character: name)
                    bowEquipment[item] = layer
                }
            } else { bowShot = nil; pinningShot = nil; stealthBow = nil }
            self.bowEquipment = bowEquipment
        }

        private func bowOverlays(name: String) throws -> [CharacterEquipmentCode: IEAvatarVisualFrame] {
            var overlays: [CharacterEquipmentCode: IEAvatarVisualFrame] = [:]
            for (item, library) in bowEquipment {
                let atlas = BowAttackAnimationSet.equipment(item)! + ".atlas"
                guard let frame = library.frame(atlas: atlas, name: name) else {
                    throw CharacterAppearanceError.missingFrame(atlas, name)
                }
                overlays[item] = frame
            }
            return overlays
        }

        func stealthFrames(_ clip: StealthClip, facing: ActorFacing, phase: Int) throws -> (IEAvatarVisualFrame, [CharacterEquipmentCode: IEAvatarVisualFrame]) {
            let name = try StealthAnimationSet.name(clip, facing: facing, phase: phase)
            let character = clip == .sneakshoot ? StealthAnimationSet.bow : StealthAnimationSet.body
            guard let frame = (clip == .sneakshoot ? stealthBow : stealthBody)?.frame(atlas: character + ".atlas", name: name) else {
                throw CharacterAppearanceError.missingFrame(character, name)
            }
            var overlays = clip == .sneakshoot ? try bowOverlays(name: name) : [:]
            if clip != .sneakshoot {
                // Sneak stab is a shortsword move; the bow uses its separate crouched shot.
                for (item, library) in stealthEquipment where clip != .sneakstab || (item != .elvenCourtBow && item != .elvenCourtArrow) {
                    let atlas = StealthAnimationSet.equipment(item) + ".atlas"
                    guard let layer = library.frame(atlas: atlas, name: name) else { throw CharacterAppearanceError.missingFrame(atlas, name) }
                    overlays[item] = layer
                }
            }
            return (frame, overlays)
        }

        func reactionFrames(_ kind: CombatReactionKind, facing: ActorFacing, phase: Int) throws -> (IEAvatarVisualFrame, [CharacterEquipmentCode: IEAvatarVisualFrame]) {
            let name = try CombatReactionAnimationSet.name(kind, facing: facing, phase: phase)
            let character = kind == .tripFall ? CombatReactionAnimationSet.tripBody : kind.isKnockback ? CombatReactionAnimationSet.knockbackBody : CombatReactionAnimationSet.body
            let library = kind == .tripFall ? tripReactionBody : kind.isKnockback ? knockbackBody : reactionBody
            guard let frame = library?.frame(atlas: character + ".atlas", name: name) else {
                throw CharacterAppearanceError.missingFrame(character, name)
            }
            var overlays: [CharacterEquipmentCode: IEAvatarVisualFrame] = [:]
            for (item, library) in (kind == .tripFall ? tripReactionEquipment : kind.isKnockback ? knockbackEquipment : reactionEquipment) {
                let atlas = (kind == .tripFall ? CombatReactionAnimationSet.tripEquipment(item)! : kind.isKnockback ? CombatReactionAnimationSet.knockbackEquipment(item) : CombatReactionAnimationSet.equipment(item)) + ".atlas"
                guard let overlay = library.frame(atlas: atlas, name: name) else { throw CharacterAppearanceError.missingFrame(atlas, name) }
                overlays[item] = overlay
            }
            return (frame, overlays)
        }

        func frames(appearance: CharacterAppearance, action: CharacterVisualAction,
                    facing: ActorFacing, phase: Int, technique: CombatManeuver? = nil) throws -> (IEAvatarVisualFrame, [CharacterEquipmentCode: IEAvatarVisualFrame]) {
            if action == .roar, let library = bearRoar {
                let name = try appearance.body.frameName(action: action, facing: facing, phase: phase)
                guard let frame = library.frame(atlas: BearRoarAnimationSet.character + ".atlas", name: name) else {
                    throw CharacterAppearanceError.missingFrame(BearRoarAnimationSet.character, name)
                }
                return (frame, [:])
            }
            if action == .attack, let library = bearClaw {
                let name = try appearance.body.frameName(action: action, facing: facing, phase: phase)
                guard let frame = library.frame(atlas: BearClawAnimationSet.character + ".atlas", name: name) else {
                    throw CharacterAppearanceError.missingFrame(BearClawAnimationSet.character, name)
                }
                return (frame, [:])
            }
            if technique == .tripAttack, let library = tripBody {
                let name = try TripAnimationSet.name(facing: facing, phase: phase)
                guard let frame = library.frame(atlas: TripAnimationSet.body + ".atlas", name: name) else {
                    throw CharacterAppearanceError.missingFrame(TripAnimationSet.body, name)
                }
                var overlays: [CharacterEquipmentCode: IEAvatarVisualFrame] = [:]
                for (item, layer) in tripEquipment {
                    let atlas = TripAnimationSet.equipment(item)! + ".atlas"
                    guard let overlay = layer.frame(atlas: atlas, name: name) else { throw CharacterAppearanceError.missingFrame(atlas, name) }
                    overlays[item] = overlay
                }
                return (frame, overlays)
            }
            if let technique, technique != .aimedShot {
                let isBow = technique == .pinningShot
                guard action == (isBow ? .shoot : .attack), let library = isBow ? pinningShot : techniqueBody else {
                    throw CharacterAppearanceError.unsupportedAction(appearance.body, action)
                }
                let character = isBow ? WeaponTechniqueAnimationSet.pinning : WeaponTechniqueAnimationSet.body
                let name = try WeaponTechniqueAnimationSet.name(technique, facing: facing, phase: phase)
                guard let frame = library.frame(atlas: character + ".atlas", name: name) else {
                    throw CharacterAppearanceError.missingFrame(character, name)
                }
                var overlays = isBow ? try bowOverlays(name: name) : [:]
                if !isBow {
                    for (item, layer) in techniqueEquipment {
                        let atlas = WeaponTechniqueAnimationSet.equipment(item)! + ".atlas"
                        guard let overlay = layer.frame(atlas: atlas, name: name) else { throw CharacterAppearanceError.missingFrame(atlas, name) }
                        overlays[item] = overlay
                    }
                }
                return (frame, overlays)
            }
            if action == .ward, let library = wardBody {
                let name = try BladeWardAnimationSet.name(facing: facing, phase: phase)
                guard let frame = library.frame(atlas: BladeWardAnimationSet.body + ".atlas", name: name) else {
                    throw CharacterAppearanceError.missingFrame(BladeWardAnimationSet.body, name)
                }
                var overlays: [CharacterEquipmentCode: IEAvatarVisualFrame] = [:]
                for (item, layer) in wardEquipment {
                    let atlas = BladeWardAnimationSet.equipment(item) + ".atlas"
                    guard let frame = layer.frame(atlas: atlas, name: name) else { throw CharacterAppearanceError.missingFrame(atlas, name) }
                    overlays[item] = frame
                }
                return (frame, overlays)
            }
            if action == .shove, let library = shoveBody {
                let name = try ShoveAnimationSet.name(facing: facing, phase: phase)
                guard let frame = library.frame(atlas: ShoveAnimationSet.body + ".atlas", name: name) else {
                    throw CharacterAppearanceError.missingFrame(ShoveAnimationSet.body, name)
                }
                var overlays: [CharacterEquipmentCode: IEAvatarVisualFrame] = [:]
                for (item, layer) in shoveEquipment {
                    let atlas = ShoveAnimationSet.equipment(item) + ".atlas"
                    guard let frame = layer.frame(atlas: atlas, name: name) else { throw CharacterAppearanceError.missingFrame(atlas, name) }
                    overlays[item] = frame
                }
                return (frame, overlays)
            }
            if action == .die, let library = defeatBody {
                let name = try DefeatAnimationSet.name(facing: facing, phase: phase)
                guard let frame = library.frame(atlas: DefeatAnimationSet.body + ".atlas", name: name) else {
                    throw CharacterAppearanceError.missingFrame(DefeatAnimationSet.body, name)
                }
                var overlays: [CharacterEquipmentCode: IEAvatarVisualFrame] = [:]
                for (item, layer) in defeatEquipment {
                    let atlas = DefeatAnimationSet.equipment(item) + ".atlas"
                    guard let frame = layer.frame(atlas: atlas, name: name) else { throw CharacterAppearanceError.missingFrame(atlas, name) }
                    overlays[item] = frame
                }
                return (frame, overlays)
            }
            if action == .attack, let library = meleeBody {
                let name = try appearance.body.frameName(action: action, facing: facing, phase: phase)
                guard let frame = library.frame(atlas: MeleeAttackAnimationSet.body + ".atlas", name: name) else {
                    throw CharacterAppearanceError.missingFrame(MeleeAttackAnimationSet.body, name)
                }
                var overlays: [CharacterEquipmentCode: IEAvatarVisualFrame] = [:]
                for (item, layer) in meleeEquipment {
                    let atlas = MeleeAttackAnimationSet.equipment(item)! + ".atlas"
                    guard let overlay = layer.frame(atlas: atlas, name: name) else {
                        throw CharacterAppearanceError.missingFrame(atlas, name)
                    }
                    overlays[item] = overlay
                }
                return (frame, overlays)
            }
            if action == .shoot {
                guard let library = bowShot else {
                    throw CharacterAppearanceError.unsupportedAction(appearance.body, action)
                }
                let name = try appearance.body.frameName(action: action, facing: facing, phase: phase)
                guard let frame = library.frame(atlas: BowAttackAnimationSet.atlas, name: name) else {
                    throw CharacterAppearanceError.missingFrame(BowAttackAnimationSet.atlas, name)
                }
                return (frame, try bowOverlays(name: name))
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
                                            facing: currentFacing, phase: phase, technique: currentTechnique)
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
        currentStealth = nil
        currentReaction = nil
        currentTechnique = nil
        currentAction = action; currentFacing = facing; currentPhase = phase
        install(frames)
    }

    func presentTechnique(_ technique: CombatManeuver?, action: CharacterVisualAction, facing: ActorFacing, phase: Int) throws {
        let frames = try resources.frames(appearance: definition.appearance, action: action, facing: facing, phase: phase, technique: technique)
        currentStealth = nil
        currentReaction = nil
        currentTechnique = technique; currentAction = action; currentFacing = facing; currentPhase = phase
        install(frames)
    }

    func presentStealth(_ clip: StealthClip, facing: ActorFacing, phase: Int) throws {
        let frames = try resources.stealthFrames(clip, facing: facing, phase: phase)
        currentStealth = clip; currentReaction = nil; currentTechnique = nil
        currentAction = clip.action; currentFacing = facing; currentPhase = phase
        install(frames)
    }

    func presentReaction(_ kind: CombatReactionKind, facing: ActorFacing, phase: Int) throws {
        let frames = try resources.reactionFrames(kind, facing: facing, phase: phase)
        currentStealth = nil
        currentReaction = kind; currentTechnique = nil
        currentAction = .idle; currentFacing = facing; currentPhase = phase
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

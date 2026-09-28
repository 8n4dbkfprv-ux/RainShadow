import SpriteKit

/// Data-driven playable area. Office and district scenes are specialisations
/// of this: cutscenes and a world map still need their own subclasses, but the
/// ARE+WED bundle — plate, props, doors, ambients, animations, cover, light
/// maps, triggers, clock — is authored once and run here.
@MainActor
class GameAreaScene: BaseGameScene {
    let area: AreaDefinition
    let areaEntranceName: String?
    private var triggerTracker = AreaTriggerTracker()
    private var areaLogicClock = AreaLogicClock()
    private var areaTickPending = false
    private var lightMap: AreaLightMap?
    private var heightMap: AreaSearchMapLoader.Raster?
    private var ambientNodes: [String: SKAudioNode] = [:]
    private var ambientNextFire: [String: TimeInterval] = [:]
    private var ambientSequenceIndex: [String: Int] = [:]
    private var animationNodes: [String: SKSpriteNode] = [:]
    /// One `IEBlitShader` per area animation. Uniforms live on the shader, and
    /// two animations stand on different lightmap cells, so these cannot be shared.
    private var animationBlitShaders: [String: SKShader] = [:]
    private var doorVisualNodes: [String: SKSpriteNode] = [:]
    private var lastAmbientTick: TimeInterval = 0

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
        artSize: CGSize? = nil,
        authoredArea: AreaDefinition? = nil
    ) {
        let definition = AreaLoadTrace.measure("area.requireArea", areaID.rawValue) {
            authoredArea ?? HarborpointAreas.requireArea(areaID)
        }
        self.area = definition
        self.areaEntranceName = entrance
        super.init(
            context: context,
            artSize: artSize ?? CGSize(width: definition.worldSize.w, height: definition.worldSize.h)
        )
        AreaLoadTrace.measure("area.runtime", definition.id.rawValue) {
            let state = context.session.objectState(in: definition)
            loadArea(AreaRuntime(area: definition, playerActorID: Self.detectiveActorID, objectState: state))
            triggerTracker = AreaTriggerTracker(spentIDs: state.spentTriggers)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("GameAreaScene is created programmatically")
    }

    /// Plate, lighting channels, ambients, animations. Subclasses still place
    /// actors, HUD, and (for city) registered door leaves on top.
    private var usesExtendedNight = false
    private weak var plateNode: SKSpriteNode?
    private var platePager: AreaPlatePager?

    func buildAreaBundle() {
        buildAreaPlate()
        loadLightingChannels()
        buildAreaAmbients()
        buildAreaAnimations()
    }

    /// Day plate by default; Extended Night swaps when a night plate is authored.
    var activePlateTextureName: String {
        if usesExtendedNight, let night = area.nightPlateTextureName {
            return night
        }
        return area.plateTextureName
    }

    /// Swap the background for the Extended Night plate, or back to day.
    ///
    /// Infinity Engine areas ship a second painting for night rather than
    /// blue-multiplying the day art, so this repaints instead of tinting. Areas
    /// with no `nightPlateTextureName` return false so the caller can say the
    /// ward has no night painting yet.
    @discardableResult
    func setExtendedNight(_ enabled: Bool) -> Bool {
        guard area.areaType.contains(.extendedNight),
              area.nightPlateTextureName != nil
        else { return false }
        guard usesExtendedNight != enabled else { return true }
        usesExtendedNight = enabled
        lightMap = AreaLightMapLoader.loadIfPresent(named: enabled ? (area.nightLightMapName ?? area.resolvedLightMapName) : area.resolvedLightMapName)
        buildAreaPlate()
        for door in area.doors where door.backgroundTiles != nil {
            presentDoorVisual(door, open: areaRuntime?.openDoorIDs.contains(door.id) ?? !door.startsClosed)
        }
        return true
    }

    func buildAreaPlate() {
        let name = activePlateTextureName
        plateNode?.removeFromParent()
        plateNode = nil
        platePager?.removeFromParent()
        platePager = nil

        if let pager = AreaPlatePager(plateTextureName: name, expectedWorldSize: artSize) {
            backgroundRoot.addChild(pager)
            platePager = pager
            updateAreaPlatePaging()
            return
        }

        guard let texture = GameArt.texture(named: name) else {
            // Missing plate art is a packaging/resource bug; log instead of trapping so
            // a single absent PNG does not take down the whole session in Debug.
            print("Area plate '\(name)' failed to load — district will render without a background")
            return
        }
        texture.filteringMode = .linear
        let background = SKSpriteNode(texture: texture, size: artSize)
        background.name = name
        background.anchorPoint = .zero
        background.position = .zero
        backgroundRoot.addChild(background)
        plateNode = background
    }

    /// Keeps only the camera neighbourhood of a BG-sized district painting in
    /// memory. Monolithic office/interior plates have no pager and pay nothing.
    func updateAreaPlatePaging() {
        platePager?.update(
            cameraPosition: gameCamera.position,
            viewportSize: size,
            // Cutscenes can animate the camera independently of the normal
            // zoom ladder, so residency follows the camera's live scale.
            cameraScale: gameCamera.xScale
        )
    }

    func loadLightingChannels() {
        lightMap = AreaLightMapLoader.loadIfPresent(named: area.resolvedLightMapName)
        heightMap = AreaHeightMap.loadIfPresent(named: area.resolvedHeightMapName)
        // Bake Map::DrawStencil's active wall set. Authored background doors
        // select a different set and invalidate this buffer when toggled.
        wallStencil = WallStencilTexture.make(from: areaRuntime?.makeWallStencil() ?? area.makeWallStencil())
        // QA hook: draw the baked mask over the area so its placement can be
        // checked against the painted scenery. The stencil is the one part of
        // the render port with no in-app failure signal — a mask offset or
        // flipped still renders, just onto the wrong pixels — so this is how you
        // see it. `RAINSHADOW_DEBUG_STENCIL=1`, best with `_CAPTURE_MODE=room`.
        if ProcessInfo.processInfo.environment["RAINSHADOW_DEBUG_STENCIL"] == "1",
           let stencil = wallStencil {
            let overlay = SKSpriteNode(texture: stencil.texture)
            overlay.size = stencil.worldFrame.size
            overlay.position = CGPoint(x: stencil.worldFrame.midX, y: stencil.worldFrame.midY)
            overlay.zPosition = SceneLayer.occlusion.rawValue + 500
            overlay.alpha = 0.65
            addChild(overlay)
        }
    }

    /// Beds honour radius and schedule; one-shots fire on interval ± deviation.
    func buildAreaAmbients() {
        let clock = context.session.clock
        for ambient in area.ambients {
            guard clock.isActive(ambient.schedule) else { continue }
            if ambient.isLooping {
                let fileName = Self.audioFileName(ambient.assetName)
                let node = RainAudio.loopingAmbience(
                    fileNamed: fileName,
                    volume: Float(ambient.volume)
                )
                node.name = ambient.id
                node.isPositional = !ambient.isGlobal && ambient.point != nil
                addChild(node)
                ambientNodes[ambient.id] = node
            } else {
                ambientNextFire[ambient.id] = ambient.interval ?? 8
            }
        }
    }

    private struct FrameAnimation: Decodable {
        struct Frame: Decodable {
            let id: String
            let texture: String
            let worldSize: AreaSize
        }
        struct Sequence: Decodable {
            let id: String
            let frames: [String]
        }
        let frames: [Frame]
        let sequences: [Sequence]
    }

    func buildAreaAnimations() {
        let clock = context.session.clock
        for animation in area.animations {
            guard clock.isActive(animation.schedule) else { continue }
            let sprite: SKSpriteNode
            if let resource = animation.resourceName {
                guard let url = Bundle.main.url(forResource: resource + ".animation", withExtension: "json"),
                      let data = try? Data(contentsOf: url),
                      let manifest = try? JSONDecoder().decode(FrameAnimation.self, from: data),
                      let sequence = manifest.sequences.first(where: { $0.id == animation.sequenceName }),
                      let first = manifest.frames.first(where: { $0.id == sequence.frames.first }) else {
                    assertionFailure("Missing area animation: \(resource)"); continue
                }
                let frames = Dictionary(uniqueKeysWithValues: manifest.frames.map { ($0.id, $0) })
                let textures = sequence.frames.compactMap { id -> SKTexture? in
                    guard let frame = frames[id] else { return nil }
                    return GameArt.texture(named: (frame.texture as NSString).deletingPathExtension)
                }
                guard textures.count == sequence.frames.count, !textures.isEmpty else {
                    assertionFailure("Incomplete area animation: \(resource)"); continue
                }
                sprite = SKSpriteNode(texture: textures[0], size: CGSize(width: first.worldSize.w, height: first.worldSize.h))
                let action = SKAction.animate(with: textures, timePerFrame: 1 / Double(animation.frameRate), resize: false, restore: false)
                sprite.run(animation.loopChance == 0 ? action : .repeatForever(action), withKey: "area.frames")
            } else {
                guard let texture = GameArt.texture(named: animation.textureName) else { continue }
                texture.filteringMode = .linear
                sprite = SKSpriteNode(texture: texture)
            }
            sprite.name = animation.id
            sprite.position = animation.point.cgPoint
            sprite.anchorPoint = CGPoint(x: animation.anchorX, y: animation.anchorY)
            sprite.setScale(animation.scale)
            sprite.alpha = animation.alpha
            sprite.blendMode = blendMode(for: animation.blend)
            if animation.wallHides, area.hidesWallLockedAnimation(at: animation.point.cgPoint) {
                sprite.alpha = 0
            }
            depthWorldRoot.addChild(sprite)
            updateDepth(of: sprite)
            animationNodes[animation.id] = sprite
        }
    }

    /// Per-frame IE area services: script, triggers, ambients, light, height, cover.
    func tickAreaSystems(listenerAt point: CGPoint, currentTime: TimeInterval) {
        updateAreaPlatePaging()
        // GlobalTimer::Freeze never executes area scripts. Keep lighting and
        // paging alive while the simulation is frozen.
        areaTickPending = areaLogicClock.advance(at: currentTime, paused: pause.isPaused || context.router.isTransitioning)
        if areaTickPending && areaLogicClock.pollsScript {
            tickAreaScript(inside: triggerTracker.insideIDs)
        }
        tickAmbients(listenerAt: point, currentTime: currentTime)
        tickAreaAnimations()
        applyFootLighting(to: detective, at: point)
        applyHeightOffset(to: detective, at: point)
    }

    /// Map::UpdateScripts checks regions after stepping actors, and checks the
    /// freeze flag again because a script/action can have opened a modal.
    func finishAreaTick(at point: CGPoint) {
        guard areaTickPending else { return }
        areaTickPending = false
        guard !pause.isPaused, !context.router.isTransitioning else { return }
        tickProximityTriggers(at: point)
    }

    func tickAreaScript(inside: Set<String>) {
        guard let runtime = areaRuntime, let script = runtime.script else { return }
        let scriptContext = AreaScriptContext(
            area: runtime.id,
            variables: context.session.areaVariables,
            dialogue: DialogueRuntimeContext(
                caseState: context.session.caseState,
                dialogueState: DialogueState(graphID: script.id)
            ),
            insideRegionIDs: inside
        )
        applyScriptOutcome(AreaScriptRunner.tick(script, in: scriptContext))
    }

    func tickProximityTriggers(at point: CGPoint) {
        let fired = triggerTracker.evaluate(regions: area.regions, at: point) { region in
            guard let flag = region.requiresFlag else { return true }
            return context.session.caseState.flags.contains(flag)
                || context.session.areaVariables.isSet(flag, in: area.id)
        }
        guard !fired.isEmpty, let runtime = areaRuntime else { return }
        var variables = context.session.areaVariables
        for region in fired {
            variables.setFlag(true, "TRG_\(region.id)", in: runtime.id)
            if let blockID = region.scriptBlock, let script = runtime.script {
                let scriptContext = AreaScriptContext(
                    area: runtime.id,
                    variables: variables,
                    dialogue: DialogueRuntimeContext(
                        caseState: context.session.caseState,
                        dialogueState: DialogueState(graphID: script.id)
                    ),
                    insideRegionIDs: triggerTracker.insideIDs
                )
                let outcome = AreaScriptRunner.runBlock(blockID, of: script, in: scriptContext)
                applyScriptOutcome(outcome)
                variables = outcome.variables
            }
        }
        runtime.recordSpentTriggers(triggerTracker.spentIDs)
        context.session.recordObjectState(runtime.objectState, in: runtime.id)
        context.session.applyAreaScriptVariables(variables)
    }

    func tickAmbients(listenerAt point: CGPoint, currentTime: TimeInterval) {
        let clock = context.session.clock
        let dt: TimeInterval = lastAmbientTick == 0 ? 0 : currentTime - lastAmbientTick
        lastAmbientTick = currentTime
        for ambient in area.ambients {
            let volume = AreaAmbientPlayback.volume(
                ambient: ambient, listener: point, clock: clock
            )
            if let node = ambientNodes[ambient.id] {
                node.run(.changeVolume(to: Float(volume), duration: 0.12))
                continue
            }
            guard !ambient.isLooping, volume > 0.01, dt > 0 else { continue }
            let remaining = (ambientNextFire[ambient.id] ?? 0) - dt
            if remaining > 0 {
                ambientNextFire[ambient.id] = remaining
                continue
            }
            let index = ambientSequenceIndex[ambient.id] ?? 0
            let pick = AreaAmbientPlayback.pickSound(
                ambient: ambient, sequenceIndex: index, roll: CGFloat.random(in: 0...1)
            )
            ambientSequenceIndex[ambient.id] = pick.nextIndex
            ambientNextFire[ambient.id] = AreaAmbientPlayback.nextDelay(
                ambient: ambient, roll: CGFloat.random(in: 0...1)
            )
            GameSFX.play(Self.audioFileName(pick.name), on: .world)
        }
    }

    func tickAreaAnimations() {
        let clock = context.session.clock
        for animation in area.animations {
            guard let sprite = animationNodes[animation.id] else { continue }
            let scheduled = clock.isActive(animation.schedule)
            var alpha: CGFloat = scheduled ? animation.alpha : 0
            if scheduled, animation.wallHides,
               area.hidesWallLockedAnimation(at: animation.point.cgPoint) {
                alpha = 0
            }
            sprite.alpha = alpha
            // `Map::DrawMap` tints an area animation from the same lightmap it
            // tints an actor from, through the same `ShaderTint`. What this
            // replaced was a `colorBlendFactor` lerp toward the sample colour,
            // which brightens a dark pixel where the engine multiplies it down —
            // the same mistake `applyBodyTint` carried, and the reason the baked
            // maps were authored in a range no multiply could use.
            if !animation.isSelfIlluminated, let lightMap, scheduled {
                let sample = lightMap.sample(
                    at: animation.point.cgPoint,
                    origin: navigation.searchMap.origin,
                    cellSize: navigation.searchMap.cellSize
                )
                let shader: SKShader
                if let existing = animationBlitShaders[animation.id] {
                    shader = existing
                } else {
                    shader = IEBlitShader.make(tint: .opaqueWhite, flags: .blended)
                    animationBlitShaders[animation.id] = shader
                    sprite.shader = shader
                    sprite.colorBlendFactor = 0
                }
                IEBlitShader.update(
                    shader,
                    tint: sample.ieColor,
                    flags: IEBlitFlags([.blended, .colorMod]).union(worldBlitFlags)
                )
            }
        }
    }

    func applyFootLighting(to actor: DetectiveActorNode, at point: CGPoint) {
        guard let lightMap else { return }
        let sample = lightMap.sample(
            at: point,
            origin: navigation.searchMap.origin,
            cellSize: navigation.searchMap.cellSize
        )
        actor.applyFootLight(sample)
    }

    func applyFootLighting(to actor: ClientActorNode, at point: CGPoint) {
        guard let lightMap else { return }
        let sample = lightMap.sample(
            at: point,
            origin: navigation.searchMap.origin,
            cellSize: navigation.searchMap.cellSize
        )
        actor.applyFootLight(sample)
    }

    func applyHeightOffset(to actor: DetectiveActorNode, at point: CGPoint) {
        if actor.isDeskRegistered {
            actor.visualHeightOffset = 0
            return
        }
        guard let heightMap else {
            actor.visualHeightOffset = 0
            return
        }
        actor.visualHeightOffset = AreaHeightMap.offset(
            from: heightMap,
            at: point,
            origin: navigation.searchMap.origin,
            cellSize: navigation.searchMap.cellSize
        )
    }

    /// Walk to the nearer approach, honour lock/key, stamp, play the sound.
    func useDoor(
        _ door: AreaDoor,
        from point: CGPoint,
        fallback: CGPoint
    ) -> (walkTo: CGPoint, lockedLine: String?) {
        if !(areaRuntime?.objectState ?? AreaObjectState()).canOpen(door, holdingKey: { id in
            context.session.characterInventory.quantity(of: id) > 0
        }) {
            return (door.walkTarget(from: point, fallback: fallback), door.lockedLine ?? "Locked.")
        }
        return (door.walkTarget(from: point, fallback: fallback), nil)
    }

    func openDoor(_ door: AreaDoor) {
        guard changeDoorState(door, open: true) else { return }
        presentDoorVisual(door, open: true)
        if door.backgroundTiles != nil {
            wallStencil = WallStencilTexture.make(from: areaRuntime?.makeWallStencil() ?? area.makeWallStencil())
        }
        doorVisibilityDidChange()
        if let sound = door.openSound {
            GameSFX.play(sound, on: .world)
        }
    }

    func closeDoor(_ door: AreaDoor) {
        guard !door.cannotClose else { return }
        guard changeDoorState(door, open: false) else { return }
        presentDoorVisual(door, open: false)
        if door.backgroundTiles != nil {
            wallStencil = WallStencilTexture.make(from: areaRuntime?.makeWallStencil() ?? area.makeWallStencil())
        }
        doorVisibilityDidChange()
        if let sound = door.closeSound {
            GameSFX.play(sound, on: .world)
        }
    }

    private func changeDoorState(_ door: AreaDoor, open: Bool) -> Bool {
        guard let runtime = areaRuntime else { return false }
        let change = runtime.setDoor(door.id, open: open)
        guard change.accepted else { return false }
        for (id, point) in change.relocatedActors { relocateAreaActor(id, to: point) }
        context.session.recordObjectState(runtime.objectState, in: area.id)
        return true
    }

    /// Map::JumpActors hands the new ground point back to each live node.
    func relocateAreaActor(_ id: String, to point: CGPoint) {
        if id == Self.detectiveActorID { detective.relocateForDoor(to: point) }
    }

    func applyEntranceFacing() {
        if let orientation = area.resolvedEntrance(named: areaEntranceName)?.orientation {
            detective.setEntranceFacing(orientation)
        }
    }

    /// A door opening or closing changed what can be seen through it. Scenes that
    /// own a fog layer re-solve sight from here.
    func doorVisibilityDidChange() {}

    /// Whether fog shrouds beyond a closed door instead of stopping at it.
    ///
    /// `AT_OUTDOOR && !AT_CITY`, which is the engine's own test. A ward is both
    /// outdoor and city, so it stops — GemRB excludes cities "to avoid
    /// unnecessary shrouding", and a street door opens onto a different area
    /// rather than onto space you could have seen.
    var outdoorDoorShroud: Bool { area.areaType.shroudsBeyondClosedDoors }

    func door(matching regionID: String) -> AreaDoor? {
        area.doors.first { $0.id == regionID }
    }

    /// IE WED-style door visuals. Overlay closed leaves for districts that still
    /// use them; Sable Row bakes the closed leaf into the plate and only shows
    /// the open secondary tiles while the door is open.
    func buildAreaDoorVisuals() {
        for door in area.doors {
            if let tiles = door.backgroundTiles {
                let sprite = SKSpriteNode()
                sprite.name = "\(door.id).backgroundTiles"
                sprite.anchorPoint = .zero
                sprite.position = tiles.worldRect.cgRect.origin
                sprite.size = tiles.worldRect.cgRect.size
                sprite.zPosition = 1
                backgroundRoot.addChild(sprite)
                doorVisualNodes[door.id] = sprite
                presentDoorVisual(door, open: areaRuntime?.openDoorIDs.contains(door.id) ?? !door.startsClosed)
                continue
            }
            guard let registration = door.visual else { continue }
            let initialName = registration.closedIsBakedIntoPlate
                ? registration.openTextureName
                : registration.closedTextureName
            guard let texture = GameArt.texture(named: initialName) else { continue }
            texture.filteringMode = .linear
            let sprite = SKSpriteNode(texture: texture)
            sprite.name = "\(door.id).visual"
            sprite.anchorPoint = registration.canvasAnchor.cgPoint
            sprite.position = registration.position.cgPoint
            sprite.setScale(registration.scale)
            if registration.closedIsBakedIntoPlate {
                // Primary tiles are in the plate; hide secondary until open.
                sprite.isHidden = !(areaRuntime?.openDoorIDs.contains(door.id) ?? !door.startsClosed)
            }
            depthWorldRoot.addChild(sprite)
            updateDepth(of: sprite, bias: 24)
            doorVisualNodes[door.id] = sprite
            // The outline layer sits under `depthWorld`, matching GemRB — whose
            // doors are tilemap background, so nothing of theirs ever covers an
            // outline. Ours is a live sprite, so lift this door's outline over
            // its own leaf or the wash draws behind the art it traces.
            highlightOutlineLayer.setDrawOrder(id: door.id, zPosition: sprite.zPosition + 1)
            if areaRuntime?.openDoorIDs.contains(door.id) ?? !door.startsClosed {
                presentDoorVisual(door, open: true)
            }
        }
    }

    private func presentDoorVisual(_ door: AreaDoor, open: Bool) {
        setHighlightOpenState(id: door.id, isOpen: open)
        if let tiles = door.backgroundTiles, let sprite = doorVisualNodes[door.id] {
            let name = usesExtendedNight ? (tiles.nightOpenTextureName ?? tiles.openTextureName) : tiles.openTextureName
            sprite.texture = GameArt.texture(named: name)
            sprite.texture?.filteringMode = .linear
            sprite.size = tiles.worldRect.cgRect.size
            sprite.isHidden = !open
            return
        }
        guard let registration = door.visual,
              let sprite = doorVisualNodes[door.id]
        else { return }
        if registration.closedIsBakedIntoPlate {
            // Closed = plate alone; open = secondary empty-aperture tiles.
            guard let texture = GameArt.texture(named: registration.openTextureName) else { return }
            texture.filteringMode = .linear
            sprite.texture = texture
            sprite.size = texture.size()
            sprite.setScale(registration.scale)
            sprite.isHidden = !open
            return
        }
        let name = open ? registration.openTextureName : registration.closedTextureName
        guard let texture = GameArt.texture(named: name) else { return }
        texture.filteringMode = .linear
        sprite.texture = texture
        sprite.size = texture.size()
        sprite.setScale(registration.scale)
        sprite.isHidden = false
    }

    private func applyScriptOutcome(_ outcome: AreaScriptRunner.Outcome) {
        guard outcome.didFire else { return }
        context.session.applyAreaScriptVariables(outcome.variables)
    }

    private static func audioFileName(_ asset: String) -> String {
        asset.hasSuffix(".m4a") ? asset : "\(asset).m4a"
    }
}

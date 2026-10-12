#if DEBUG
import AppKit
import SpriteKit

/// Exercises shipped textures through SpriteKit, including palette changes and
/// combat presentation entry points. Uses no player save.
@MainActor enum TabletopMiniatureQA {
    struct Failure: Error { let message: String }
    /// Full opening through the real scene loop and cutscene/dialogue adapters.
    /// Uses a private save and exercises both natural playback and skip.
    static func runOpening(in view: SKView, output: URL) async {
        var checks: [String] = [], problems: [String] = []
        func check(_ yes: Bool, _ message: String) {
            if yes { checks.append(message) } else { problems.append(message) }
        }
        func wait(_ condition: () -> Bool, timeout: Double = 35) async throws {
            let deadline = ProcessInfo.processInfo.systemUptime + timeout
            while !condition() {
                guard ProcessInfo.processInfo.systemUptime < deadline else { throw Failure(message: "Opening timed out after \(checks.last ?? "startup")") }
                try await Task.sleep(for: .milliseconds(30))
            }
        }
        func capture(_ name: String) throws {
            guard let scene = view.scene, let texture = view.texture(from: scene),
                  let png = NSBitmapImageRep(cgImage: texture.cgImage()).representation(using: .png, properties: [:]) else { throw Failure(message: "Opening capture failed") }
            try png.write(to: output.appendingPathComponent(name + ".png"))
        }
        func body(_ node: SKNode) -> IEAvatarNode { node.children.compactMap { $0 as? IEAvatarNode }.first { !$0.isHidden }! }
        func base(_ node: SKNode) -> SKNode { node.childNode(withName: "miniature.base")! }
        func advanceDialogue(_ office: DetectiveOfficeScene) {
            let context = office.dialoguePresenter.runtimeContext
            let node = context.dialogueState.currentNodeID.flatMap { EmptyCoatCaseIntroduction.graph.node(id: $0) }
            if let node, !CaseDialogueGraph.visibleChoices(node.choices, in: context).isEmpty {
                office.handleDialogueChoiceDigit(1)
            } else { office.handleConfirmInput() }
        }
        do {
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            let store = SaveStore(key: "RainShadow.QA.TabletopOpening.\(UUID().uuidString)")
            defer { store.reset() }
            let context = GameContext(saveStore: store)
            view.window?.setContentSize(CGSize(width: 1100, height: 800))
            view.window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
            context.router.start(in: view)
            check(view.scene is OpeningExteriorScene, "Fresh game plays the exterior establishing shot")
            try await wait { view.scene is DetectiveOfficeScene && !context.router.isTransitioning }
            let office = view.scene as! DetectiveOfficeScene
            let voss = office.cutsceneActor(.detective) as! DetectiveActorNode
            let lila = office.cutsceneActor(.client) as! ClientActorNode
            try await Task.sleep(for: .milliseconds(350))
            check(body(voss).currentFrame!.id!.name.hasPrefix("idle_") && !voss.isDeskRegistered,
                  "Opening Voss is a rigid standing miniature, with no seated body layers")
            check(base(voss).position == body(voss).position && abs(base(voss).position.y - voss.visualHeightOffset) < 0.001,
                  "Opening Voss base is planted at terrain height (body \(body(voss).position), base \(base(voss).position), terrain \(voss.visualHeightOffset))")
            try capture("01-office-opening")
            for _ in 0..<20 where !lila.isLocomoting {
                advanceDialogue(office); try await Task.sleep(for: .milliseconds(180))
            }
            try await wait { lila.isLocomoting }
            var sawLift = false, rigid = true, registered = true
            let deadline = ProcessInfo.processInfo.systemUptime + 35
            while office.cutsceneDirector.isCutsceneMode {
                guard ProcessInfo.processInfo.systemUptime < deadline else { throw Failure(message: "Entrance stalled") }
                let sprite = body(lila)
                rigid = rigid && sprite.currentFrame!.id!.name.hasPrefix("idle_")
                registered = registered && base(lila).position == sprite.position
                if !sawLift && base(lila).position.y >= 5.9 {
                    sawLift = true; try capture("02-lila-entering")
                }
                try await Task.sleep(for: .milliseconds(30))
            }
            try await Task.sleep(for: .milliseconds(350))
            check(sawLift && rigid && registered, "Natural entrance lifts Lila and her base together in one rigid pose")
            check(office.pause.isPaused && base(lila).position.y == 0,
                  "Lila is fully placed before dialogue pauses the opening")
            try capture("03-opening-dialogue")
            for _ in 0..<180 where !lila.isLocomoting && !lila.isHidden {
                advanceDialogue(office); try await Task.sleep(for: .milliseconds(120))
            }
            try await wait { lila.isLocomoting || lila.isHidden }
            var exitRigid = true, sawExitLift = false
            let exitDeadline = ProcessInfo.processInfo.systemUptime + 35
            while !lila.isHidden {
                guard ProcessInfo.processInfo.systemUptime < exitDeadline else { throw Failure(message: "Exit stalled") }
                exitRigid = exitRigid && body(lila).currentFrame!.id!.name.hasPrefix("idle_")
                if !sawExitLift && base(lila).position.y >= 5.9 {
                    sawExitLift = true; try capture("04-lila-leaving")
                }
                try await Task.sleep(for: .milliseconds(30))
            }
            check(sawExitLift && exitRigid && !lila.isLocomoting, "Natural departure removes a rigid miniature after following the route")
            try await wait { !office.cutsceneDirector.isCutsceneMode }
            try capture("05-opening-complete")
            // Re-enter the opening with another isolated fresh save, then skip
            // Lila while she is lifted; dialogue must not freeze the old lift.
            let skipStore = SaveStore(key: "RainShadow.QA.TabletopOpeningSkip.\(UUID().uuidString)")
            defer { skipStore.reset() }
            skipStore.save(SaveSnapshot(hasSeenOpening: true))
            let skipContext = GameContext(saveStore: skipStore)
            skipContext.router.start(in: view)
            try await wait { view.scene is DetectiveOfficeScene && !skipContext.router.isTransitioning }
            let skipOffice = view.scene as! DetectiveOfficeScene
            let skipLila = skipOffice.cutsceneActor(.client) as! ClientActorNode
            for _ in 0..<20 where !skipLila.isLocomoting {
                advanceDialogue(skipOffice); try await Task.sleep(for: .milliseconds(180))
            }
            try await wait { skipLila.isLocomoting && base(skipLila).position.y >= 5.9 }
            try await Task.sleep(for: .milliseconds(1150))
            check(skipOffice.cutsceneDirector.trySkip(), "Entrance can be skipped while the miniature is lifted")
            try await Task.sleep(for: .milliseconds(350))
            check(!skipLila.isLocomoting && base(skipLila).position.y == 0 && body(skipLila).position == base(skipLila).position,
                  "Skipped entrance immediately plants Lila and her base together")
            try capture("06-skipped-entrance")
            try JSONSerialization.data(withJSONObject: ["passed":problems.isEmpty,"checks":checks,"problems":problems], options: [.prettyPrinted])
                .write(to: output.appendingPathComponent("opening-report.json"))
        } catch {
            try? JSONSerialization.data(withJSONObject: ["passed":false,"checks":checks,"problems":problems,"error":"\(error)"], options: [.prettyPrinted])
                .write(to: output.appendingPathComponent("opening-report.json"))
        }
    }
    static func run(in view: SKView, output: URL) {
        var checks: [String] = []
        func check(_ value: Bool, _ message: String) throws {
            guard value else { throw Failure(message: message) }; checks.append(message)
        }
        func body(_ node: CharacterAppearanceNode) -> IEAvatarNode {
            node.childNode(withName: "appearance.body") as! IEAvatarNode
        }
        do {
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            try check(TabletopMiniatureLibrary.directory.path.hasPrefix(Bundle.main.bundlePath), "Assets load from the built app, not the checkout")
            // A render clock observes a 15 Hz route. It must not interpret the
            // gaps between integral engine steps as separate bounces.
            for fps in [30, 60, 120] {
                var motion = TabletopMiniatureMotion()
                var cruise: [CGFloat] = []
                for frame in 0...fps * 2 {
                    let point = CGPoint(x: (frame * 15 / fps) * 4, y: 0)
                    let height = motion.update(position: point, at: Double(frame) / Double(fps), paused: false)
                    if frame > fps / 2 { cruise.append(height) }
                }
                try check(cruise.min()! == 0 && cruise.max()! > 11 && cruise.allSatisfy { $0 >= 0 && $0 <= TabletopMiniatureMotion.liftHeight }, "\(fps) fps: repeats bounded hops with planted landings between arcs")
                let beforePause = motion.height
                let held = motion.update(position: CGPoint(x: 120, y: 0), at: 9, paused: true)
                try check(held == beforePause, "\(fps) fps: pause freezes the lift")
                try check(motion.update(position: CGPoint(x: 120, y: 0), at: 10, paused: false) == held,
                          "\(fps) fps: resume does not spend paused time")
                var settle: [CGFloat] = []
                for frame in 1...fps {
                    settle.append(motion.update(position: CGPoint(x: 120, y: 0), at: 10 + Double(frame) / Double(fps), paused: false))
                }
                try check(settle.allSatisfy { $0 >= 0 && $0 <= TabletopMiniatureMotion.liftHeight } && settle.last == 0,
                          "\(fps) fps: finishes the final hop and stays planted after arrival")
                try check(motion.update(position: CGPoint(x: 1000, y: 0), at: 11.1, paused: false) == 0,
                          "\(fps) fps: teleport does not trigger a hop")
            }
            for definition in [CharacterDefinition.voss, .lila, .cityGuard] {
                let node = try CharacterAppearanceNode(definition: definition)
                for facing in ActorFacing.allCases {
                    try node.present(action: .idle, facing: facing, phase: 0)
                    let expected = body(node).texture
                    for action in [CharacterVisualAction.walk, .run, .dash] {
                        for phase in [0, 3, 9, 20] {
                            try node.present(action: action, facing: facing, phase: phase)
                            try check(body(node).texture === expected, "\(definition.id) \(facing.rawValue) \(action.rawValue)/\(phase): rigid pose")
                        }
                    }
                    try check(body(node).currentFrame?.native == nil, "\(definition.id) \(facing.rawValue): bypasses native pixel payload")
                    try check(body(node).texture!.size().height > 100, "\(definition.id) \(facing.rawValue): retains source render resolution")
                    for child in node.children.compactMap({ $0 as? IEAvatarNode }) {
                        try check(child.currentFrame?.id?.name.contains("idle_") == true, "\(definition.id): equipment stays on the rigid pose")
                    }
                }
                let original = body(node).texture
                let size = body(node).size, pivot = body(node).anchorPoint
                var changed = definition; changed.appearance.colors = .init(major: 46)
                try node.apply(changed)
                try check(body(node).texture !== original, "\(definition.id): palette changes refresh texture")
                try check(body(node).size == size && body(node).anchorPoint == pivot, "\(definition.id): palette changes preserve registration")
                try check(node.childNode(withName: "miniature.base") != nil, "\(definition.id): has physical base")
                let before = NSBitmapImageRep(cgImage: original!.cgImage())
                let after = NSBitmapImageRep(cgImage: body(node).texture!.cgImage())
                let key = body(node).currentFrame!.id!.name.replacingOccurrences(of: ".png", with: "")
                let paint = [UInt8](try Data(contentsOf: TabletopMiniatureLibrary.directory
                    .appendingPathComponent(definition.appearance.body.character).appendingPathComponent(key + ".paint")))
                var changedPixels = 0
                for y in 0..<before.pixelsHigh {
                    for x in 0..<before.pixelsWide {
                        let old = before.colorAt(x: x,y: y)!, new = after.colorAt(x: x,y: y)!
                        guard old != new else { continue }
                        changedPixels += 1
                        guard paint[(y*before.pixelsWide+x)*4] == 3 else {
                            throw Failure(message: "Palette change escaped major material on \(definition.id)")
                        }
                    }
                }
                try check(changedPixels > 30, "\(definition.id): palette changes pixels only inside the chosen material")
            }
            let detective = DetectiveActorNode()
            detective.beginOpenWorldStanding(); detective.relocateForDoor(to: .zero)
            detective.walk(path: Path(points: [CGPoint(x: 160,y: 0)], from: .zero))
            for step in 0..<50 {
                detective.updateLocomotion(at: Double(step)/60, worldIsPaused: false)
                detective.updateMiniatureMotion(at: Double(step)/60, paused: false)
            }
            let position = detective.position
            let detectiveBody = detective.children.compactMap { $0 as? IEAvatarNode }.first { !$0.isHidden }!
            try check(position.x > 0 && detectiveBody.currentFrame!.id!.name.hasPrefix("idle_"), "Voss moves on the real movement tick in a rigid pose")
            let detectiveBase = detective.childNode(withName: "miniature.base")!
            try check(detectiveBody.position.y > 0 && detectiveBase.position == detectiveBody.position,
                      "Voss's body, attached equipment and base lift together")
            try check(!detective.isDeskRegistered, "Lifted Voss is not mistaken for desk registration")
            detective.updateLocomotion(at: 3, worldIsPaused: true)
            detective.updateMiniatureMotion(at: 3, paused: true)
            try check(detective.position == position, "Paused tabletop movement remains stopped")
            try check(detectiveBase.position == detectiveBody.position && detectiveBase.position.y > 0, "Paused Voss keeps the same visual lift")
            for step in 181..<600 {
                detective.updateLocomotion(at: Double(step)/60, worldIsPaused: false)
                detective.updateMiniatureMotion(at: Double(step)/60, paused: false)
            }
            try check(detective.position == CGPoint(x: 160,y: 0), "Voss still arrives exactly at the route endpoint")
            try check(detectiveBase.position.y == 0 && detectiveBody.position.y == 0, "Voss settles fully at arrival")
            let client = ClientActorNode()
            client.performEntrance(along: [.zero,CGPoint(x: 160,y: 0)]) {}
            for step in 0..<50 {
                client.updateLocomotion(at: Double(step)/60, worldIsPaused: false)
                client.updateMiniatureMotion(at: Double(step)/60, paused: false)
            }
            let clientBody = client.children.compactMap { $0 as? IEAvatarNode }.first { !$0.isHidden }!
            try check(client.position.x > 0 && clientBody.currentFrame!.id!.name.hasPrefix("idle_"), "Lila's scripted entrance slides a rigid miniature")
            try check(clientBody.position.y > 0 && client.childNode(withName: "miniature.base")!.position == clientBody.position,
                      "Lila's scripted entrance lifts the whole miniature")
            for step in 50..<500 {
                client.updateLocomotion(at: Double(step)/60, worldIsPaused: false)
                client.updateMiniatureMotion(at: Double(step)/60, paused: false)
            }
            try check(client.position == CGPoint(x: 160,y: 0) && !client.isLocomoting, "Lila's entrance completes at the exact endpoint")
            try check(clientBody.position.y == 0 && client.childNode(withName: "miniature.base")!.position.y == 0,
                      "Lila settles fully at arrival")
            let equipped = try CharacterAppearanceNode(definition: .cityGuard)
            equipped.visualHeightOffset = 17
            for step in 0..<50 {
                equipped.position.x = CGFloat(step / 4 * 4)
                equipped.updateMiniatureMotion(at: Double(step)/60, paused: false)
            }
            var recolored = CharacterDefinition.cityGuard
            recolored.appearance.colors = .init(major: 46)
            try equipped.apply(recolored)
            equipped.visualHeightOffset = 21
            let equipmentLayers = equipped.children.compactMap { $0 as? IEAvatarNode }
            try check(equipmentLayers.count > 1 && equipmentLayers.allSatisfy { $0.position == body(equipped).position && $0.zRotation == body(equipped).zRotation } && body(equipped).position.y > 21,
                      "Equipped NPC holds registration through paint changes and terrain height while lifted")
            try check(equipped.childNode(withName: "miniature.base")!.position == body(equipped).position,
                      "NPC base shares terrain plus cosmetic lift")
            let shadow = equipped.childNode(withName: "miniature.base/miniature.groundShadow")!
            try check(abs(shadow.convert(.zero, to: equipped).y - 16) < 0.001, "Lift shadow remains on the terrain under the base")
            let motionStore = SaveStore(key: "RainShadow.QA.MiniatureMotion.\(UUID().uuidString)")
            defer { motionStore.reset() }
            let motionScene = BaseGameScene(context: GameContext(saveStore: motionStore), artSize: CGSize(width: 720, height: 420))
            var bearDefinition = CharacterDefinition.voss
            bearDefinition.appearance = .init(body: .bearGuardian)
            let bearPiece = try CharacterAppearanceNode(definition: bearDefinition)
            let group = SKNode(); motionScene.depthWorldRoot.addChild(group); group.addChild(bearPiece)
            bearPiece.visualHeightOffset = 21
            for step in 0..<50 {
                bearPiece.position.x = CGFloat(step / 4 * 4)
                motionScene.updateGroundCircles(at: Double(step)/60)
                motionScene.didFinishUpdate()
            }
            try check(bearPiece.childNode(withName: "miniature.base")!.position.y > 21,
                      "Scene finish-update lifts nested combat/bear actors without a selectable circle")
            let bearShadow = bearPiece.childNode(withName: "miniature.base/miniature.groundShadow")!
            try check(abs(bearShadow.convert(.zero, to: bearPiece).y - 11) < 0.001,
                      "Large base shadow stays on the board despite the doubled base scale")
            motionScene.pause.setModal(dialogue: false, overlay: true)
            motionScene.updateGroundCircles(at: 6); motionScene.didFinishUpdate()
            try check(bearPiece.childNode(withName: "miniature.base")!.position.y > 21,
                      "Scene pause freezes miniature presentation")
            motionScene.pause.setModal(dialogue: false, overlay: false)
            for step in 360..<420 {
                motionScene.updateGroundCircles(at: Double(step)/60); motionScene.didFinishUpdate()
            }
            try check(bearPiece.childNode(withName: "miniature.base")!.position.y == 21,
                      "Scene resume settles stationary pieces back onto terrain")
            let shaderScene = SKScene(size: CGSize(width: 100, height: 100))
            shaderScene.backgroundColor = .black
            let white = SKTexture(data: Data([255,255,255,255]), size: CGSize(width: 1,height: 1))
            let probe = SKSpriteNode(texture: white, size: CGSize(width: 100,height: 100))
            probe.position = CGPoint(x: 50,y: 50); probe.shader = TabletopMiniatureLibrary.shader()
            let mask = SKTexture(data: Data([128,255,0,255,0,0,0,0]), size: CGSize(width: 2,height: 1))
            mask.filteringMode = .nearest
            IEBlitShader.updateStencil(probe.shader!, texture: mask,
                spriteWorldRect: CGRect(x: 0,y: 0,width: 100,height: 100),
                stencilFrame: CGRect(x: 0,y: 0,width: 100,height: 100))
            shaderScene.addChild(probe); view.presentScene(shaderScene)
            let probeImage = NSBitmapImageRep(cgImage: view.texture(from: shaderScene)!.cgImage())
            let covered = probeImage.colorAt(x: 25,y: 50)!.usingColorSpace(.deviceRGB)!.redComponent
            let adjacent = probeImage.colorAt(x: 26,y: 50)!.usingColorSpace(.deviceRGB)!.redComponent
            let clear = probeImage.colorAt(x: 75,y: 50)!.usingColorSpace(.deviceRGB)!.redComponent
            try check(covered > 0.1 && covered < 0.85 && clear > 0.95,
                      "Compiled shader covers only overlapping pixels and preserves ungraded white")
            try check(abs(covered-adjacent) < 0.01, "Wall cover is smooth without checkerboard dithering")
            // Review the actual route-driven piece, sampled at 15 fps. No
            // presentation animation is authored separately for this preview.
            let movementScene = SKScene(size: CGSize(width: 720, height: 420))
            movementScene.scaleMode = .aspectFit
            movementScene.backgroundColor = SKColor(red: 0.11, green: 0.14, blue: 0.19, alpha: 1)
            let movingPiece = DetectiveActorNode()
            movingPiece.beginOpenWorldStanding()
            let start = CGPoint(x: 180, y: 115), end = CGPoint(x: 530, y: 115)
            movingPiece.relocateForDoor(to: start)
            movingPiece.setScale(2.7)
            movementScene.addChild(movingPiece)
            for point in [start, end] {
                let marker = SKShapeNode(ellipseOf: CGSize(width: 170, height: 127.5))
                marker.strokeColor = SKColor(white: 0.75, alpha: 0.3)
                marker.position = point; marker.zPosition = -2
                movementScene.addChild(marker)
            }
            let movementLabel = SKLabelNode(fontNamed: "HelveticaNeue")
            movementLabel.fontSize = 20; movementLabel.position = CGPoint(x: 360, y: 380)
            movementScene.addChild(movementLabel)
            let movementFolder = output.appendingPathComponent("movement-frames")
            try FileManager.default.createDirectory(at: movementFolder, withIntermediateDirectories: true)
            view.presentScene(movementScene)
            for step in 0..<480 {
                if step == 30 { movingPiece.walk(path: Path(points: [end], from: start)) }
                let time = Double(step) / 60
                movingPiece.updateLocomotion(at: time, worldIsPaused: false)
                movingPiece.updateMiniatureMotion(at: time, paused: false)
                let lifted = movingPiece.childNode(withName: "miniature.base")!.position.y > 0
                movementLabel.text = movingPiece.position == end ? (lifted ? "Set down" : "Placed") : (lifted ? "Rigid miniature hops" : "Pick up the piece")
                if step % 4 == 0 {
                    let png = NSBitmapImageRep(cgImage: view.texture(from: movementScene)!.cgImage())
                        .representation(using: .png, properties: [:])!
                    try png.write(to: movementFolder.appendingPathComponent(String(format: "%03d.png", step / 4)))
                }
            }
            try check(movingPiece.position == end && movingPiece.childNode(withName: "miniature.base")!.position.y == 0,
                      "Rendered movement preview finishes placed at its real route endpoint")
            for variant in ["armored", "helmet", "bow"] {
                let sheet = SKScene(size: CGSize(width: 1600, height: 600))
                sheet.backgroundColor = SKColor(red: 0.11, green: 0.14, blue: 0.19, alpha: 1)
                var definition = CharacterDefinition.cityGuard
                if variant == "helmet" { definition.appearance.equipment = [.init(item: .ironHelmet)] }
                if variant == "bow" { definition.appearance.equipment = [.init(item: .elvenCourtBow), .init(item: .elvenCourtArrow)] }
                for (index, facing) in ActorFacing.allCases.enumerated() {
                    let actor = try CharacterAppearanceNode(definition: definition)
                    try actor.present(action: .idle, facing: facing, phase: 0)
                    actor.position = CGPoint(x: 100+(index%8)*200, y: 400-(index/8)*280)
                    actor.setScale(2.2); sheet.addChild(actor)
                    let label = SKLabelNode(text: VossAnimationSet.direction(facing))
                    label.fontSize = 14; label.position = CGPoint(x: actor.position.x,y: actor.position.y-85)
                    sheet.addChild(label)
                }
                view.presentScene(sheet)
                let image = view.texture(from: sheet)!.cgImage()
                try NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
                    .write(to: output.appendingPathComponent("equipment-\(variant).png"))
            }
            let scene = SKScene(size: CGSize(width: 1100, height: 800))
            scene.scaleMode = .aspectFit
            scene.backgroundColor = SKColor(red: 0.11, green: 0.14, blue: 0.19, alpha: 1)
            let title = SKLabelNode(fontNamed: "Georgia")
            title.text = "RAINSHADOW  •  TABLETOP MINIATURES"; title.fontSize = 25
            title.position = CGPoint(x: 550, y: 750); scene.addChild(title)
            var greenVoss = CharacterDefinition.voss; greenVoss.appearance.colors = .init(major: 46)
            var bear = CharacterDefinition.voss; bear.appearance = .init(body: .bearGuardian)
            let definitions: [CharacterDefinition] = [.voss, .lila, .cityGuard, greenVoss, .bandit, bear]
            for (index, definition) in definitions.enumerated() {
                let actor = try CharacterAppearanceNode(definition: definition)
                actor.position = CGPoint(x: 185 + (index % 3)*360, y: 505 - (index/3)*330)
                actor.setScale(index == 5 ? 2.1 : 3.2)
                actor.miniatureAllegiance = index == 4 ? .hostile : (index == 2 ? .neutral : .ally)
                try actor.present(action: .idle, facing: index == 3 ? .northWest : .southWest, phase: 0)
                scene.addChild(actor)
                let label = SKLabelNode(fontNamed: "HelveticaNeue")
                label.text = ["Voss", "Lila", "Equipment · neutral", "Palette variant · rear", "Hostile · oxblood", "Bear · 50 mm base"][index]
                label.fontSize = 16; label.fontColor = .lightGray
                label.position = CGPoint(x: actor.position.x, y: actor.position.y-125)
                scene.addChild(label)
            }
            view.presentScene(scene)
            guard let texture = view.texture(from: scene),
                  let png = NSBitmapImageRep(cgImage: texture.cgImage()).representation(using: .png, properties: [:]) else {
                throw Failure(message: "SpriteKit capture failed")
            }
            try png.write(to: output.appendingPathComponent("miniatures.png"))
            try JSONSerialization.data(withJSONObject: ["passed":true,"checks":checks], options: [.prettyPrinted])
                .write(to: output.appendingPathComponent("report.json"))
        } catch {
            try? JSONSerialization.data(withJSONObject: ["passed":false,"error":"\(error)","checks":checks], options: [.prettyPrinted])
                .write(to: output.appendingPathComponent("report.json"))
        }
    }
}
#endif

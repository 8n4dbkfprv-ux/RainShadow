#if DEBUG
import AppKit
import SpriteKit

/// Exercises real equipment state, inventory presentation and live actor playback
/// with an isolated save. Invoke with RAINSHADOW_QA_WEAPON=<output directory>.
/// Set RAINSHADOW_QA_WEAPON_ITEM=elven-court-bow to review the bow instead of the sword.
@MainActor enum WeaponEquipmentQA {
    struct Failure: Error { let message: String }

    static func run(in view: SKView, output: URL) async {
        var checks: [String] = []
        let weaponID = ProcessInfo.processInfo.environment["RAINSHADOW_QA_WEAPON_ITEM"] ?? "lantern-shortsword"
        let exerciseArrow = weaponID == "elven-court-bow"
        let otherWeaponID = weaponID == "elven-court-bow" ? "lantern-shortsword" : "elven-court-bow"
        let store = SaveStore(key: "RainShadow.QA.Weapon.\(UUID().uuidString)")
        defer { store.reset(); SaveStore(key: "RainShadow.QA.Weapon.Bootstrap").reset() }
        func check(_ condition: Bool, _ message: String) throws {
            guard condition else { throw Failure(message: message) }
            checks.append(message)
        }
        func capture(_ scene: BaseGameScene, _ name: String) throws {
            for _ in 0..<4 { scene.didFinishUpdate() }
            let camera = scene.gameCamera
            let size = CGSize(width: scene.size.width*camera.xScale, height: scene.size.height*camera.yScale)
            let crop = CGRect(x: camera.position.x-size.width/2, y: camera.position.y-size.height/2,
                              width: size.width, height: size.height)
            guard let texture = view.texture(from: scene, crop: crop),
                  let png = NSBitmapImageRep(cgImage: texture.cgImage()).representation(using: .png, properties: [:]) else {
                throw Failure(message: "Could not capture \(name)")
            }
            try png.write(to: output.appendingPathComponent(name+".png"))
        }
        do {
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            guard let appearance = VossWeaponAppearance(rawValue: weaponID) else {
                throw Failure(message: "Unknown QA weapon: " + weaponID)
            }
            try check(Bundle.main.url(forResource: "avatar-v02", withExtension: "json",
                subdirectory: appearance.character) != nil, "Weapon bundle ships in the app")
            for name in ["inventory_item_elven_court_arrow_v01", "voss_paperdoll_elven_court_arrow", "inventory_item_elven_court_bow_v01", "voss_paperdoll_elven_court_bow",
                         "inventory_item_lantern_shortsword_v01", "inventory_item_iron_helmet_v01",
                         "inventory_item_splint_mail_v01", "voss_paperdoll_chmf",
                         "voss_paperdoll_lantern_shortsword", "voss_paperdoll_iron_helmet",
                         "voss_paperdoll_splint_mail", "voss_paperdoll_iron_helmet_unarmored"] {
                try check(Bundle.main.url(forResource: name, withExtension: "png") != nil,
                          "Inventory art is packaged: " + name)
            }
            // Exercise deferred migration with a genuinely full persisted bag.
            let bagCapacity = CarriedInventoryState.defaultTotalSlotCapacity
            store.save(SaveSnapshot(
                carriedItems: Array(repeating: .init(id: "dark-lantern", quantity: 1), count: bagCapacity),
                hasSeededStarterKit: true, hasReceivedArmorKit: true))
            let fullBag = GameContext(saveStore: store)
            try check(fullBag.session.carriedInventory.stacks.count == bagCapacity
                      && !fullBag.session.hasReceivedElvenCourtBow,
                      "A full bag defers the bow without losing carried items")
            try check(fullBag.session.dropCarriedItem(at: 0, in: "RS0100", at: .zero) != nil,
                      "A bag slot can be freed before the deferred grant")
            let roomForBow = GameContext(saveStore: store)
            try check(roomForBow.session.characterInventory.quantity(of: "elven-court-bow") == 1
                      && roomForBow.session.hasReceivedElvenCourtBow,
                      "The next load delivers the deferred bow exactly once")
            try check(!roomForBow.session.hasReceivedElvenCourtArrow, "A full bag defers the arrow after the bow grant")
            try check(roomForBow.session.dropCarriedItem(at: 0, in: "RS0100", at: .zero) != nil,
                      "Another bag slot can be freed for the arrow")
            let roomForArrow = GameContext(saveStore: store)
            try check(roomForArrow.session.characterInventory.quantity(of: "elven-court-arrow") == 1
                      && roomForArrow.session.hasReceivedElvenCourtArrow,
                      "The next load grants the deferred arrow exactly once")
            store.save(SaveSnapshot(
                lootContainers: ["qa.chest": [.item(id: "elven-court-arrow", quantity: 1)]],
                hasSeededStarterKit: true, hasReceivedArmorKit: true, hasReceivedElvenCourtBow: true))
            let storedArrow = GameContext(saveStore: store)
            try check(storedArrow.session.characterInventory.quantity(of: "elven-court-arrow") == 0
                      && storedArrow.session.hasReceivedElvenCourtArrow,
                      "Migration recognizes an arrow already stored in a container")
            store.save(SaveSnapshot(
                lootContainers: ["qa.chest": [.item(id: "elven-court-bow", quantity: 1)]],
                hasSeededStarterKit: true, hasReceivedArmorKit: true))
            let storedBow = GameContext(saveStore: store)
            try check(storedBow.session.characterInventory.quantity(of: "elven-court-bow") == 0
                      && storedBow.session.hasReceivedElvenCourtBow,
                      "Migration recognizes a bow already stored in a container")
            // Exercise upgrading an existing sword-only save as well as the live visuals.
            store.save(SaveSnapshot(carriedItems: [.init(id: "lantern-shortsword", quantity: 1)],
                                    hasSeededStarterKit: true))
            let context = GameContext(saveStore: store)
            try check(context.session.carriedInventory.stacks.map(\.id) == ["lantern-shortsword", "iron-helmet", "splint-mail", "elven-court-bow", "elven-court-arrow"],
                      "Existing sword-only save receives armor, one bow and one arrow")
            context.session.markOfficeCaseIntroCompleted()
            let scene = CityDistrictScene(context: context, districtID: .sableRow, entrance: "from.office")
            view.window?.setContentSize(CGSize(width: 1280, height: 800))
            view.presentScene(scene)
            view.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            try await Task.sleep(for: .seconds(1))
            let actor = scene.detective
            actor.setEntranceFacing(.south)
            guard let weapon = actor.childNode(withName: "//detective.equippedWeapon") as? IEAvatarNode,
                  let body = weapon.parent as? IEAvatarNode else { throw Failure(message: "Missing equipment node") }
            try check(weapon.currentFrame == nil && weapon.isHidden, "Carried weapon is not drawn")
            guard let index = context.session.carriedInventory.stacks.firstIndex(where: { $0.id == weaponID }) else {
                throw Failure(message: "Missing selected weapon")
            }
            try check(context.session.equipCarriedItem(at: index, to: .weapon1) == nil, "Equip succeeds through GameSession")
            scene.refreshInventoryOverlay()
            try check(weapon.currentFrame?.id?.name == body.currentFrame?.id?.name && !weapon.isHidden,
                      "Equipping shows the matching idle weapon frame immediately")
            try check(weapon.currentFrame?.native != nil, "Weapon uses the native compositor payload")
            try check(weapon.blitShader !== body.blitShader, "Weapon has its own blit and stencil uniforms")
            guard let ammunition = actor.childNode(withName: "//detective.equippedAmmunition") as? IEAvatarNode,
                  let ammoPortrait = scene.inventoryOverlay.childNode(withName: "//inventory.paperdoll.ammunition") as? SKSpriteNode else {
                throw Failure(message: "Missing ammunition layers")
            }
            try check(ammunition.isHidden && ammoPortrait.isHidden, "Carried arrow stays hidden even with a bow readied")
            if exerciseArrow {
                guard let arrowIndex = context.session.carriedInventory.stacks.firstIndex(where: { $0.id == "elven-court-arrow" }) else {
                    throw Failure(message: "Missing granted arrow")
                }
                try check(context.session.equipCarriedItem(at: arrowIndex, to: .quiver1) == nil, "Arrow equips into an ammunition slot with a two-handed bow")
                scene.refreshInventoryOverlay()
                try check(!ammunition.isHidden && ammunition.currentFrame?.id?.name == body.currentFrame?.id?.name,
                          "Equipped arrow displays the matching body frame")
                try check(ammunition.blitShader !== body.blitShader && ammunition.blitShader !== weapon.blitShader,
                          "Arrow has independent tint and stencil uniforms")
                try check(!ammoPortrait.isHidden && ammoPortrait.texture != nil, "Arrow appears in the other hand in the portrait")
                try check(store.load().hasReceivedElvenCourtArrow, "One-time arrow grant receipt persists")
            }
            // Inspect the uncovered hand before armor can obscure grip alignment.
            scene.setInventoryPresented(true)
            try await Task.sleep(for: .milliseconds(200))
            try capture(scene, "inventory_weapon_only")
            scene.setInventoryPresented(false)
            var armorNodes: [IEAvatarNode] = []
            for armor in VossArmorAppearance.allCases {
                guard let node = actor.childNode(withName: "//detective.equipped." + armor.rawValue) as? IEAvatarNode,
                      let index = context.session.carriedInventory.stacks.firstIndex(where: { $0.id == armor.rawValue }) else {
                    throw Failure(message: "Missing armor item or layer: " + armor.rawValue)
                }
                try check(node.isHidden, "Carried " + armor.rawValue + " is hidden")
                try check(context.session.equipCarriedItem(at: index, to: armor.slot) == nil,
                          "Equipped " + armor.rawValue + " in its own slot")
                scene.refreshInventoryOverlay()
                let expectedName = body.currentFrame?.id.flatMap {
                    armor.frameName(matching: $0, wearingMail: VossArmorAppearance.splintMail.isEquipped(in: context.session.characterInventory))
                }
                try check(!node.isHidden && node.currentFrame?.id?.name == expectedName,
                          armor.rawValue + " matches the idle frame and wearing variant")
                try check(node.currentFrame?.native != nil && node.blitShader !== body.blitShader,
                          armor.rawValue + " has native pixels and independent shading")
                armorNodes.append(node)
            }
            try check(context.session.defenceBonus == 7, "Equipped armor contributes seven defence")
            try check(store.load().hasReceivedArmorKit, "One-time armor grant is persisted")
            try check(store.load().hasReceivedElvenCourtBow, "One-time bow grant is persisted")
            let reloaded = GameContext(saveStore: store)
            try check(reloaded.session.characterInventory.equipped[.weapon1]?.id == weaponID,
                      "Selected weapon survives reload")
            if exerciseArrow {
                try check(reloaded.session.characterInventory.equipped[.quiver1]?.id == "elven-court-arrow",
                          "Equipped arrow survives reload")
            }
            try check(reloaded.session.carriedInventory.stacks.map(\.id) == (exerciseArrow ? [otherWeaponID] : [otherWeaponID, "elven-court-arrow"]),
                      "Reloading equipped armor does not duplicate it in the bag")
            scene.setInventoryPresented(true)
            try await Task.sleep(for: .milliseconds(300))
            guard let portrait = scene.inventoryOverlay.childNode(withName: "//inventory.paperdoll.weapon") as? SKSpriteNode else {
                throw Failure(message: "Missing inventory weapon layer")
            }
            try check(!portrait.isHidden && portrait.texture != nil, "Inventory portrait displays equipped weapon")
            for armor in VossArmorAppearance.allCases {
                guard let layer = scene.inventoryOverlay.childNode(withName: "//inventory.paperdoll." + armor.rawValue) as? SKSpriteNode else {
                    throw Failure(message: "Missing armor portrait layer")
                }
                try check(!layer.isHidden && layer.texture != nil, armor.rawValue + " appears in the portrait")
            }
            if let helmet = scene.inventoryOverlay.childNode(withName: "//inventory.paperdoll.iron-helmet") as? SKSpriteNode {
                try check(helmet.texture?.size() == CGSize(width: 768, height: 1344), "Tall helmet canvas ships without rescaling")
                try check(abs(helmet.anchorPoint.y - 535.5 / 1344) < 0.0001, "Tall helmet retains its source pivot")
                try check(abs(helmet.size.height / portrait.size.height - 1344.0 / 1088) < 0.0001,
                          "Armor and sword retain identical pixels-per-point")
            }
            try capture(scene, "inventory_equipped")
            scene.setInventoryPresented(false)
            try await Task.sleep(for: .milliseconds(200))
            scene.gameCamera.position = scene.convert(CGPoint(x: 0,y: 30), from: actor)
            try capture(scene, "idle_equipped")
            let start = actor.position
            let paths = [CGPoint(x: 200,y: 0),CGPoint(x: -200,y: 0),CGPoint(x: 0,y: 150),CGPoint(x: 0,y: -150)].map {
                scene.navigation.path(from: start, to: CGPoint(x: start.x+$0.x,y: start.y+$0.y), identity: "detective")
            }
            guard let path = paths.max(by: { $0.nodes.count < $1.nodes.count }), !path.isEmpty else {
                throw Failure(message: "No walking route for review")
            }
            actor.walk(path: path)
            var walkFrames: Set<String> = []
            for _ in 0..<24 {
                try await Task.sleep(for: .milliseconds(60))
                if let id = body.currentFrame?.id, id.name.hasPrefix("walk_") {
                    guard weapon.currentFrame?.id?.name == id.name else { throw Failure(message: "Weapon drifted from body frame") }
                    guard armorNodes.allSatisfy({ $0.currentFrame?.id?.name == id.name && !$0.isHidden }) else {
                        throw Failure(message: "Armor drifted from walking body frame")
                    }
                    if exerciseArrow && ammunition.currentFrame?.id?.name != id.name {
                        throw Failure(message: "Arrow drifted from walking body frame")
                    }
                    walkFrames.insert(id.name)
                }
            }
            try check(walkFrames.count >= 3, "Walking advances synchronized body and weapon frames")
            scene.gameCamera.position = scene.convert(CGPoint(x: 0,y: 30), from: actor)
            try capture(scene, "walking_equipped")
            actor.cancelMovement()
            try check(context.session.unequipItem(from: .coat) == nil, "Mail can be removed while keeping helmet equipped")
            scene.refreshInventoryOverlay()
            let helmetNode = actor.childNode(withName: "//detective.equipped.iron-helmet") as? IEAvatarNode
            try check(helmetNode?.currentFrame?.id?.name.hasPrefix("unarmored_") == true,
                      "Removing mail immediately selects the complete standalone helmet")
            scene.setInventoryPresented(true)
            try await Task.sleep(for: .milliseconds(200))
            try capture(scene, "inventory_helmet_only")
            guard let mailIndex = context.session.carriedInventory.stacks.firstIndex(where: { $0.id == "splint-mail" }) else {
                throw Failure(message: "Missing unequipped mail")
            }
            try check(context.session.equipCarriedItem(at: mailIndex, to: .coat) == nil, "Mail can be re-equipped")
            scene.refreshInventoryOverlay()
            try check(helmetNode?.currentFrame?.id?.name == body.currentFrame?.id?.name,
                      "Re-equipping mail immediately restores paired helmet occlusion")
            if exerciseArrow {
                try check(context.session.unequipItem(from: .quiver1) == nil, "Arrow can be unequipped without removing the bow")
                scene.refreshInventoryOverlay()
                try check(ammunition.isHidden && ammoPortrait.isHidden && !weapon.isHidden,
                          "Unequipping arrow clears both arrow layers and preserves bow")
                guard let index = context.session.carriedInventory.stacks.firstIndex(where: { $0.id == "elven-court-arrow" }) else {
                    throw Failure(message: "Arrow was lost when unequipping")
                }
                try check(context.session.equipCarriedItem(at: index, to: .quiver2) == nil, "Arrow can use another ammunition slot")
                scene.refreshInventoryOverlay()
                try check(!ammunition.isHidden && !ammoPortrait.isHidden, "Re-equipping restores the arrow")
                guard let sword = context.session.carriedInventory.stacks.firstIndex(where: { $0.id == "lantern-shortsword" }) else {
                    throw Failure(message: "Missing sword for swap check")
                }
                try check(context.session.equipCarriedItem(at: sword, to: .weapon1) == nil, "Sword can replace the bow while ammunition remains equipped")
                scene.refreshInventoryOverlay()
                try check(ammunition.isHidden && ammoPortrait.isHidden, "Readying sword hides the held arrow")
                guard let bow = context.session.carriedInventory.stacks.firstIndex(where: { $0.id == "elven-court-bow" }) else {
                    throw Failure(message: "Missing bow after swap")
                }
                try check(context.session.equipCarriedItem(at: bow, to: .weapon1) == nil, "Bow can be readied again")
                scene.refreshInventoryOverlay()
                try check(!ammunition.isHidden && !ammoPortrait.isHidden, "Readying bow restores equipped ammunition")
            }
            try check(context.session.unequipItem(from: .weapon1) == nil, "Unequip succeeds through GameSession")
            scene.refreshInventoryOverlay()
            try check(weapon.currentFrame == nil && weapon.isHidden, "Unequipping clears the world weapon immediately")
            try check(ammunition.isHidden && ammoPortrait.isHidden, "Removing the bow clears both held-arrow layers")
            scene.setInventoryPresented(true)
            try await Task.sleep(for: .milliseconds(300))
            try check(portrait.isHidden && portrait.texture == nil, "Unequipping clears the inventory weapon")
            for armor in VossArmorAppearance.allCases {
                try check(context.session.unequipItem(from: armor.slot) == nil, "Unequipped " + armor.rawValue)
                scene.refreshInventoryOverlay()
                let layer = scene.inventoryOverlay.childNode(withName: "//inventory.paperdoll." + armor.rawValue) as? SKSpriteNode
                try check(layer?.isHidden == true && layer?.texture == nil, "Removed " + armor.rawValue + " from portrait")
            }
            try check(armorNodes.allSatisfy { $0.isHidden && $0.currentFrame == nil }, "Unequipping clears both world armor layers")
            try check(context.session.defenceBonus == 0, "Removing armor restores base defence")
            try capture(scene, "inventory_unequipped")
            if let index = context.session.carriedInventory.stacks.firstIndex(where: { $0.id == "iron-helmet" }) {
                try check(context.session.dropCarriedItem(at: index, in: "RS0100", at: actor.position) != nil,
                          "Helmet can be dropped")
                let afterDrop = GameContext(saveStore: store)
                try check(!afterDrop.session.carriedInventory.stacks.contains { $0.id == "iron-helmet" },
                          "Dropped helmet is not granted again on reload")
            }
            if let bowIndex = context.session.carriedInventory.stacks.firstIndex(where: { $0.id == "elven-court-bow" }) {
                try check(context.session.dropCarriedItem(at: bowIndex, in: "RS0100", at: actor.position) != nil,
                          "Unequipped bow can be dropped")
                let afterDrop = GameContext(saveStore: store)
                try check(!afterDrop.session.carriedInventory.stacks.contains { $0.id == "elven-court-bow" },
                          "Dropped bow is not granted again on reload")
            }
            if exerciseArrow {
                try check(context.session.unequipItem(from: .quiver2) == nil, "Arrow can return to the bag after bow removal")
                guard let index = context.session.carriedInventory.stacks.firstIndex(where: { $0.id == "elven-court-arrow" }) else {
                    throw Failure(message: "Missing arrow for drop check")
                }
                try check(context.session.dropCarriedItem(at: index, in: "RS0100", at: actor.position) != nil, "Arrow can be dropped")
                let afterDrop = GameContext(saveStore: store)
                try check(afterDrop.session.characterInventory.quantity(of: "elven-court-arrow") == 0,
                          "Dropped arrow is not granted again on reload")
            }
            try JSONSerialization.data(withJSONObject: ["passed":true,"checks":checks,"walkingFrames":walkFrames.sorted()],
                options: [.prettyPrinted]).write(to: output.appendingPathComponent("report.json"))
        } catch {
            try? JSONSerialization.data(withJSONObject: ["passed":false,"checks":checks,"error":String(describing:error)],
                options: [.prettyPrinted]).write(to: output.appendingPathComponent("report.json"))
        }
        NSApp.terminate(nil)
    }
}
#endif

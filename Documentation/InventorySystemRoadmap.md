# Inventory system roadmap
- Status: Phases 0–4 shipped (item catalog, equipment model, encumbrance, live inventory window, ground piles + quick loot). Phase 5 apparel content and Phase 6 shops are docs only.
- Version: 0.1
- Date: 14 August 2026
- Related: GDD §7.2 (evidence model), §11 (UI direction), §12 (scope), §13 (accessibility), Technical Architecture §14.1 (core model types), §14.3 (saving), [Movement System Roadmap](MovementSystemRoadmap.md) (encumbrance bands), [Dialogue System Roadmap](DialogueSystemRoadmap.md) (the versioned-loader pattern this copies)

## Purpose

Give RainShadow the inventory the interface has been drawing since the noir Mac OS 9 window shipped: real item definitions, equipment slots that hold something, weight that costs speed, identification that can fail, and items that can leave the bag and come back off the floor. The window was painted first and wired second; this closes the gap between what it looks like it does and what it does.

This document does **not** propose importing Baldur's Gate's item economy. There are no shops, no gold-per-encounter curve, no level-scaled drops, and no random treasure beyond the coin tables that already ship. **Inventory here exists to carry case-relevant objects, not to be a reward loop** — the GDD says so three times (§1, §4.3.5, §12) and this system is built to keep that true. It also does not import the `.ITM` binary format, extended headers, feature blocks, or the class/race/alignment usability masks: RainShadow has one character and no spell system, so those would be empty fields pretending to be a design.

## Design target (classic BG:EE inventory, condensed)

Every claim below comes from a primary source — the IESDP file-format specifications, the shipped *Adventurer's Guide*, or an installed BG:EE UI definition. Not forum lore.

| Concern | Classic Infinity Engine / BG:EE | RainShadow target (shipped) |
|---|---|---|
| Slot table | 40 slots per creature: 0–8 worn, 9–12 weapons, 13–16 quivers, 17 cloak, 18–20 quick items, 21–36 backpack, 37–39 derived (`cre_v1.htm`) | `EquipmentSlot`: the 23 with a painted home, each carrying its engine index in `bgSlotIndex` |
| Item definition | `ITM` header: paired unidentified/identified name and description, category, weight, price, stack amount, lore-to-identify, inventory + ground icon (`itm_v1.htm`) | `ItemDefinition`, authored as JSON, same fields plus `defenceBonus` / damage band |
| Where an item may go | Item category decides the slot (`itm_v1.htm` 0x001c) | `EquipmentSlot.acceptedCategories`; one category, one home |
| Per-stack state | Identified / Unstealable / Stolen / Undroppable bits on the creature's item entry (`cre_v1.htm` 0x0010) | `CarriedItemStack.isIdentified` + `charges`; definition-level bits in `ItemFlags` |
| Interaction | Click lifts onto the cursor, click puts down. No drag. | `InventoryOverlay` held-item cursor |
| Identification | Auto against Lore on pickup, or right-click on demand; unidentified icons carry a blue watermark | `identifyEverythingKnown` on entry, right-click on demand, blue wash over the icon |
| Two limits | 16 backpack slots **and** a Strength weight allowance | `CarriedInventoryState` (16) and `EncumbranceRules` |
| Encumbrance | Over the allowance, "movement speed is halved"; more than 10% over "prevents them from moving altogether" (*Adventurer's Guide* p. 43) | `EncumbranceRules.band` → `MovementProfile.Encumbrance` |
| Warning band | The yellow weight readout is "meant strictly as a warning, nothing else" | `EncumbranceReadout.isWarning` — amber text, no mechanical effect |
| Stacking | Ammunition and quick-slot consumables stack; worn gear never does | `ItemStackLimits`, rejected at catalog load by `stackableWornItem` |
| Two-handed | A two-handed weapon suppresses the off-hand | `offHandBlockedByTwoHandedWeapon`, from any ready slot |
| Ground | Dropped items lie where they fell and persist | `GroundPileState`, keyed by area |
| Quick loot | Nearby ground items in a strip; scroll buttons appear past ten | `QuickLootBarNode` + `QuickLootPage` |

**Explicitly out of scope:** shops and prices-in-practice, containers-inside-containers (bag of holding, scroll case), party inventory and item transfer between characters, pickpocketing, item charges being spent, and weapon proficiency.

## Current baseline

| Piece | Status |
|---|---|
| Item definitions as data | **Shipped** — `ItemDefinition` + `harborpoint.items.json`, loaded by `ItemCatalogLoader` |
| Equipment slots | **Shipped** — `EquipmentSlot`, all 23, live in the window |
| Equip rules | **Shipped** — category gating, two-handed exclusion, cursed refusal |
| Case bag | **Shipped** — 16 slots, merging, splitting, reordering |
| Weight + encumbrance | **Shipped** — `EncumbranceRules` drives `DetectiveActorNode.movementProfile` |
| Identification | **Shipped** — Lore sweep on pickup, right-click on demand, blue wash |
| Ground piles | **Shipped** — `GroundPileState`, persisted per area |
| Quick-loot bar | **Shipped** — 10 slots, page chevrons, on the right-rail Search control |
| Persistence | **Shipped** — `equippedItems`, `groundPiles`, `hasSeededStarterKit`, all additive at `schemaVersion` 1 |
| Window geometry | **Shipped as pure data** — `InventoryScreenLayout`, unit-tested including a no-overlap invariant |
| Apparel content | **Not shipped** — the rules are tested against a fixture wardrobe; no coat/hat/ring item *art* exists, so nothing can currently be worn |
| Ammunition content | **Not shipped** — quiver slots accept `.ammunition`; no cartridges are authored |
| Authored item loot | **Not shipped** — every shipped `LootContainerDefinition` is still coins-only |
| Shops, containers-in-containers, party transfer | **Not shipped** — out of scope above |
| Quick-loot plate art | **Reused, not authored** — the bar borrows `hud_loot_container_panel_v02`; a dedicated plate is an outstanding Image Generator batch |

**Scale reality check.** The engine is well ahead of the content: seven authored items, one of them mysterious, and no wearable gear at all. The next real work is an art batch, not code.

## Frozen rules (do not regress)

1. **Inventory is not a reward loop.** No shops, no drop tables, no level-scaled loot. GDD §12 lists loot grinding as explicitly out of scope, and every addition here has to survive that sentence.
2. **A refused move is refused.** Nothing silently relocates an item to somewhere it *would* fit. `InventoryRefusal` says why, and both sides stay untouched — the same rule the navigation layer holds for unreachable ground.
3. **Coins never occupy a bag slot.** They credit the purse, as in BG.
4. **A recovered firearm is carried, never auto-equipped.** GDD §11.
5. **The warning band carries no penalty.** BG's yellow weight readout is a warning and nothing else; modelling it as a fourth encumbrance state would invent a penalty the engine does not have.
6. **Encumbrance bands are 100% and 110%**, from the shipped *Adventurer's Guide* p. 43 — not the 120% that circulates on wikis.
7. **Worn gear never stacks.** Rejected at catalog load, not at runtime.
8. **Identified and unidentified stacks do not merge.** They draw differently; merging would lose the distinction.
9. **The starter kit is real stacks.** It used to be a reserved slot count with nothing behind it, which is why the six painted items could not be equipped, dropped, or moved. `hasSeededStarterKit` promotes it once.
10. **Pure rules live in `RainShadow Shared/Gameplay/Navigation/`.** That directory is the SwiftPM target; anything outside it cannot be unit-tested, which is how the window's geometry went untested for four versions.
11. **All chrome is painted PNG.** Code owns layout, hit-testing, live text, and ephemeral tints only. When a surface has no art yet, reuse an existing plate and say so — do not invent procedural chrome.
12. **Save fields stay additive.** Every field added since v1 decodes with a default, so shipped saves stay at `schemaVersion` 1. Do not bump.

---

## Phase 0 — Item definitions as data

**Goal:** items stop being Swift literals in a UI file.

### Ship
- `ItemDefinition`, `ItemCategory`, `ItemFlags`, `EquipmentSlot` in RainShadowCore.
- `ItemCatalogLoader` mirroring `DialogueGraphLoader`: versioned document, typed errors, `.module` → `.main` → `#filePath` lookup, `NSLock` cache, duplicate rejection.
- `RainShadow Shared/Resources/Items/harborpoint.items.json`, carrying the seven authored items across verbatim.

### Exit criteria
- Unit tests: catalog load, duplicate rejection, unknown-id error, flag round trip, every slot index matches `cre_v1.htm`.
- An unknown item id **throws** rather than being title-cased into a plausible-looking item.

**Status: met** (`ItemCatalogTests`).

### Rationale
The catalog this replaced had a `default:` branch that turned any unrecognised id into a titled item with a generic silhouette. That is an authoring typo shipping as content.

---

## Phase 1 — The character inventory model

**Goal:** a CRE-shaped value type with the engine's equip rules.

### Ship
- `CharacterInventory`: equipped slots + case bag as one value, because every real operation crosses between them.
- `InventoryRefusal` with a reason per refusal.
- Stack merging, splitting, and reordering on `CarriedInventoryState`, gated by `ItemStackLimits`.
- `EncumbranceRules` + `CarryAllowance` + `EncumbranceReadout`.

### Exit criteria
- Unit tests for every equip rule, two-handed/off-hand exclusion in both directions, cursed refusal, bag-full refusal, stack merge and split boundaries, and each encumbrance band including immobile.
- A refused operation leaves the value exactly as it was.

**Status: met** (`CharacterInventoryTests`).

### Rationale
`MovementProfile.Encumbrance` shipped as inert data with no caller. Giving it a weight source is the whole of the Movement roadmap's P2 dependency.

---

## Phase 2 — Session state and persistence

**Goal:** equipment is real, persisted state.

### Ship
- `GameSession.characterInventory`, with `carriedInventory` kept as a passthrough so existing readers are untouched.
- Starter-kit promotion behind `hasSeededStarterKit`.
- Equip / unequip / move / split / identify / drop APIs, all copy-then-commit.
- `SaveSnapshot.equippedItems`, `groundPiles`, `hasSeededStarterKit` — additive.
- `DetectiveActorNode.movementProfile` recomputed on every inventory change.

### Exit criteria
- A save written before equipment existed still loads, keeps its wallet, and seeds the starter kit once.
- An unknown slot key is dropped on load rather than failing it.

**Status: met** (`InventoryPersistenceTests`).

---

## Phase 3 — The live inventory window

**Goal:** the painted slots do what they look like they do.

### Ship
- `InventoryScreenLayout` in RainShadowCore — the private `Metrics` table lifted out so it can be tested.
- Hit-testing for equipment slots and bag slots.
- Click-to-lift cursor, legal-destination highlight, refusal receipts.
- Description strip and all four stat rows driven by real data.
- Blue wash on unidentified icons; right-click to attempt identification.
- Shift-click to split a stack; click away from the sheet to drop.

### Exit criteria
- Unit tests: slot rects, the BG:EE Classic column constants, **no two slots share any pixels**, every slot inside the content rails.
- Visual proof at 1280×720 through the shipping renderer.

**Status: met** (`InventoryScreenLayoutTests`, `InventoryOverlayIdentityTests`; captures under `Documentation/Captures/InventoryV01/`).

### Rationale
The window's geometry was a private point table hand-matched to a Python-generated PNG, with no test able to reach it. The loot strip beside it had solved this already; this is the same move.

---

## Phase 4 — Ground piles and quick loot

**Goal:** items leave the bag and come back off the floor.

### Ship
- `GroundPileState` — per-area piles, persisted, identity-based removal.
- `QuickLootPage` — ten per row, chevrons past that.
- `QuickLootBarNode` on the right-rail Search control, which stops being a stub.
- Drop from the inventory window; undroppable items refuse.

### Exit criteria
- Unit tests: per-area separation, radius and nearest-first ordering, identity removal, page clamping, 44pt touch targets, arrows reclaiming their lane when unpaged.
- Visual proof of four dropped stacks in the strip.

**Status: met** (`GroundPileTests`).

### Rationale
Removal is by identity, not index: the bar sorts by distance, so an index would take whatever happened to be nearest instead of what was clicked.

---

## Phase 5 — Wearable content (not scheduled)

**Goal:** something to actually put in the ten paperdoll slots.

### Ship (sketch only)
- An Image Generator batch for `inventory_item_*` apparel: trench coat, fedora, gloves, shoes, belt, cloak, ring, charm.
- Authored `ItemDefinition`s with `defenceBonus` and weight.
- Authored `.item(...)` loot entries, so containers yield something other than coins.

### Exit criteria — defined when the art batch is scheduled
The rules are already tested against a fixture wardrobe in `CharacterInventoryTests`; this phase is content, not engine.

---

## Phase 6 — Shops and containers (deferred)

Out of scope per the GDD until a commerce design exists. Containers-inside-containers (bag of holding, scroll case) are the mechanism BG uses to dissolve early-game carry friction; adopting them would undo the only interesting decision weight creates, so they need a design reason, not just an implementation.

---

## Source map (implementation touch points)

| Path | Role |
|---|---|
| `RainShadow Shared/Gameplay/Navigation/ItemDefinition.swift` | The `ITM` header analogue |
| `RainShadow Shared/Gameplay/Navigation/EquipmentSlot.swift` | The `CRE` slot table |
| `RainShadow Shared/Gameplay/Navigation/ItemCatalogLoader.swift` | Versioned loader + `HarborpointItems` facade |
| `RainShadow Shared/Gameplay/Navigation/CharacterInventory.swift` | Equip rules, bag operations, derived stats |
| `RainShadow Shared/Gameplay/Navigation/EncumbranceRules.swift` | Weight → `MovementProfile.Encumbrance` |
| `RainShadow Shared/Gameplay/Navigation/GroundPileState.swift` | Ground piles + `QuickLootPage` |
| `RainShadow Shared/Gameplay/Navigation/InventoryScreenLayout.swift` | Window geometry |
| `RainShadow Shared/Gameplay/Navigation/InventoryItemPresentation.swift` | Stack + definition → view model |
| `RainShadow Shared/Gameplay/Navigation/LootSystem.swift` | Currency, containers, the case bag, stack limits |
| `RainShadow Shared/Gameplay/Navigation/HUDChromeLayout.swift` | Quick-loot bar geometry |
| `RainShadow Shared/UI/InventoryOverlay.swift` | The window |
| `RainShadow Shared/UI/QuickLootBarNode.swift` | The strip |
| `RainShadow Shared/UI/LootContainerPanelNode.swift` | The container strip |
| `RainShadow Shared/App/GameBootstrap.swift` | `GameSession` inventory APIs + persistence mapping |
| `RainShadow Shared/Core/Persistence/SaveStore.swift` | Persisted mirrors |
| `RainShadow Shared/Resources/Items/harborpoint.items.json` | Authored content |
| `Tests/RainShadowCoreTests/ItemCatalogTests.swift` | Catalog + slot table |
| `Tests/RainShadowCoreTests/CharacterInventoryTests.swift` | Equip rules, stacking, encumbrance |
| `Tests/RainShadowCoreTests/InventoryScreenLayoutTests.swift` | Geometry + no-overlap invariant |
| `Tests/RainShadowCoreTests/InventoryPersistenceTests.swift` | Additive schema |
| `Tests/RainShadowCoreTests/GroundPileTests.swift` | Piles, paging, bar geometry |
| `Tests/RainShadowCoreTests/InventoryOverlayIdentityTests.swift` | Presentation identity |

## Dependency notes

| Depends on | For |
|---|---|
| `MovementProfile.Encumbrance` | The speed penalty; already built and cited to the *Adventurer's Guide* |
| `PlayerTraits` (deferred, Technical Architecture §14.1) | A real Strength score. Until then `CarryAllowance.detective` is the 2e Strength 15 row (55 lb) and `GameSession.detectiveLore` is a constant |
| Image Generator | Apparel icons and a dedicated quick-loot plate |
| `EvidenceRecord` (deferred) | Bridging case evidence to carried items. **Evidence is not a flat collectibles list** (GDD §7.2); an evidence-category item and an evidence *record* are different objects and must not be conflated |

## What not to build yet

- **Containers-inside-containers.** They exist in BG to remove carry friction; adding them before the friction is interesting removes nothing.
- **Item charges being spent.** `CarriedItemStack.charges` is carried and persisted but nothing decrements it — there is no use verb yet.
- **Party inventory.** There is one actor. `PortraitBarNode.Utility.selectParty` is still a stub, correctly.
- **Pickpocketing.** `ItemFlags.unstealable` is authored and unused, waiting for a thieving system.

## Open questions (do not block shipped phases)

1. **Should Lore be a real stat?** *Current answer:* no. `GameSession.detectiveLore` is a constant matching the Resolve the character sheet shows. It becomes a lookup when `PlayerTraits` ships and nothing else moves.
2. **Should dropping be confirmable?** *Current:* no confirmation, because a drop requires deliberately lifting the item first, and case-critical items refuse outright.
3. **Does the quick-loot bar want its own plate?** *Current:* it borrows the container strip's. A dedicated plate is an art batch, not a blocker.

## Acceptance summary (roadmap done)

1. Every painted slot in the inventory window holds real state and refuses illegal moves with a reason.
2. Weight measurably changes how Voss walks, at the bands the shipped manual prints.
3. An item can be carried, worn, split, dropped, and picked up again, and all of it survives a relaunch.
4. Every rule is unit-tested in RainShadowCore; nothing load-bearing is asserted by searching source text.
5. Content — apparel, ammunition, authored item loot — is the only thing left between this and a complete inventory.

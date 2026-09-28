# Area logic comparison — 28 September 2026

This records the pre-implementation audit. The follow-up changes and validation are in [GemRB area lifecycle implementation](GemRBAreaLifecycleSep28.md).

RainShadow has the main IE spatial layers and destination/entrance model, but its area lifecycle is only a partial implementation. The clearest discrepancies are mutable door state, paused script execution, and enforcement of region flags. This is a source audit plus targeted Swift tests, not a visual certification or an exhaustive engine conformance test.

Reviewed working tree: HEAD `1599398` plus existing local changes. Current restored Sable Row, Wharf Ladder, Riverside, Lamp Ward and office records were used. No runtime, art, navigation, character or test files were changed by this audit.

The implementation reference is GemRB at the repository's pinned `1c45c185`, not BioWare's original executable source. The [IESDP ARE specification](https://gibberlings3.github.io/iesdp/file_formats/ie_formats/are_v1.htm) provides the file-format reference. The September 6 art audit describes older packages and must not be treated as a diagnosis of the current painting.

## Structure already present

| Area responsibility | RainShadow implementation | Assessment |
|---|---|---|
| Background and area content | `AreaDefinition`, paged plates, `GameAreaScene` | Custom formats with an IE-like separation of graphics and gameplay data. |
| Ground movement and terrain | `SearchMap`, `NavigationMap`, `PathFinder` | Existing documented GemRB ports; no new line-by-line navigation audit performed here. |
| Lighting, height, visual cover | Light/height maps, wall polygons, per-pixel stencil | Separate channels already exist; do not replace them with geometry or whole-actor transparency. |
| Doors | Per-state impeded cells, outlines, background patches and wall sets | Spatial state changes exist; lifecycle and occupant handling are incomplete. |
| Travel | Destination area ID plus named entrance | Implemented; actual city activation uses click/walk completions. |
| Exploration and local variables | Session-backed fog and area variables | Persisted, including office fog. `AreaRuntime`'s older comment saying rooms do not retain fog is stale. |
| Scripts | Ordered Swift blocks and a small action vocabulary | Deliberate custom scripting subset, not a BCS interpreter. |

The area records inspected contain no authored actors or proximity triggers. The office record has six containers; its actors are scene-managed. Missing general NPC, trap, party-travel and spawn behavior should be assessed against planned content, not confused with current movement failures.

## Confirmed discrepancies

### 1. Door state resets when an area is recreated

`Core/Scene/AreaRuntime.swift:46` initializes `openDoorIDs` from `startsClosed`. `SceneRouter.present` constructs a new scene on travel. `GameAreaScene.openDoor` and `closeDoor` update only that runtime, visuals and sound; `SaveSnapshot` has no door-state store.

GemRB saves mutable door flags in `AREImporter::PutDoors`: `ieDword flags = d->Flags;`. [Pinned importer](https://raw.githubusercontent.com/gemrb/gemrb/1c45c185/gemrb/plugins/AREImporter/AREImporter.cpp).

Consequently, an opened Wharf or Riverside exterior door returns to its authored initial state after leaving and returning through the normal router. The debug Sable route has a special return-opening adjustment, not general persistence. This is a code-path conclusion; this audit did not perform a live door round trip.

Recommended verification: open a door, leave, return, then save/reload; compare visuals, impeded cells and wall stencil in every state. Preserve explicit scripted resets where intended.

### 2. Area scripts keep executing during pause and use the render-frame cadence

`Scenes/CityDistrict/CityDistrictScene.swift:440` and `Scenes/DetectiveOffice/DetectiveOfficeScene.swift:895` invoke `tickAreaSystems` before determining `worldIsPaused`. That shared method unconditionally calls the script runner and proximity tracker. Pausing world-root SpriteKit nodes does not guard these direct Swift calls.

GemRB gates area-script execution through `Interface::GameLoop` and `GSUpdate`; its frozen branch calls `timer.Freeze()` and returns false. The timer also gates updates by its tick interval. [Pinned interface](https://raw.githubusercontent.com/gemrb/gemrb/1c45c185/gemrb/core/Interface.cpp), [pinned timer](https://raw.githubusercontent.com/gemrb/gemrb/1c45c185/gemrb/core/GlobalTimer.cpp).

A continuously satisfied increment block would therefore advance once per scene update, including while RainShadow movement is paused. The currently registered office script is guarded by `SEEN`, which limits today's visible impact. Logic should use a pause-aware simulation tick while presentation services can continue separately.

### 3. Deactivated travel regions remain clickable

`AreaDefinition.region(at:of:)` (`Gameplay/Navigation/AreaDefinition.swift:1695`) tests geometry and kind without checking `isDeactivated`. `CityDistrictScene.handleRegion` (`:605`) checks `requiresFlag` but does not reject deactivated regions. The highlight builder filters them, so removing their outline does not remove their behavior.

GemRB's `InfoPoint::CheckTravel` explicitly starts with `if (Flags & TRAP_DEACTIVATED) return CT_CANTMOVE;`. [Pinned InfoPoint](https://raw.githubusercontent.com/gemrb/gemrb/1c45c185/gemrb/core/Scriptable/InfoPoint.cpp).

This is a latent data-contract bug, not a claim that an inspected restored portal is currently marked deactivated. Verify with a disabled travel fixture: clicking its polygon must neither schedule travel nor change areas.

### 4. One-shot trigger memory does not survive a new scene

`AreaTriggerTracker.swift:12` stores `spentIDs` only in memory. A new `GameAreaScene` creates a fresh tracker. `tickProximityTriggers` writes `TRG_<id>` into persisted area variables, but neither the tracker nor the caller reads that flag before firing again. The comment promising save-lifetime suppression is therefore inaccurate. A named trigger block also runs through `runBlock`, which does not evaluate the block's condition.

GemRB serializes region flags and trap state in `AREImporter::PutRegions`, including `stream->WriteWord(ip->Trapped);`. [Pinned importer](https://raw.githubusercontent.com/gemrb/gemrb/1c45c185/gemrb/plugins/AREImporter/AREImporter.cpp).

RainShadow's generic trigger model is simpler than IE's trap/event machinery; the immediate issue is that it does not fulfill its own persistence promise. None of the seven inspected current records uses proximity triggers, so this is a future-content risk. Add a cross-visit and save/reload fixture before relying on one-shot rewards or events.

### 5. Entrance facing is stored but ignored

`AreaEntrance` contains `facing`, but `spawnPoint` returns only a point. Both city and office scene setup consume the position and use their normal actor initialization without applying entrance facing.

GemRB's `Map::MoveToNewArea` reads `face = ent->Face;` and passes it into the leave-area action. [Pinned Map](https://raw.githubusercontent.com/gemrb/gemrb/1c45c185/gemrb/core/Map.cpp).

None of the seven inspected current records authors a facing value, so this is incomplete support rather than a demonstrated wrong-facing arrival in those records. Verify with two entrances at the same location with different facings.

### 6. Door changes do not check actors occupying the new footprint

`GameAreaScene.closeDoor` (`:423`) checks `cannotClose`, then changes state. `NavigationMap.setDoor` (`:139`) stamps cells and restamps occupancy; neither implements a blocked-close decision or relocation of affected actors.

GemRB's `Door::BlockedOpen` checks the destination impeded cells, and `SetDoorOpen` uses that result to reject blocked closes and handle actor displacement. [Pinned Door](https://raw.githubusercontent.com/gemrb/gemrb/1c45c185/gemrb/core/Scriptable/Door.cpp).

RainShadow can therefore make a cell solid beneath an occupant if that configuration is reached. Whether current single-actor approach points permit it needs a live fixture; this audit does not claim an observed stuck actor. Test an actor standing in the closed footprint while another interaction requests closure.

## Adaptations requiring a decision, not an automatic fix

Correction after tracing the caller: GemRB's `Actor::CannotPassEntrance` requires both the selected `lastExit` and `IF_USEEXIT` before `Map::UpdateScripts` calls `InfoPoint::Entered`. Plain movement through an exit is therefore not sufficient upstream either. RainShadow retains an explicit, cancellable click/walk travel order. Its completion geometry is still an authored approach/entry adaptation rather than the full GemRB InfoPoint geometry model.

The current restored Sable and office entrances use static travel regions without animated door records. A travel region need not have a corresponding door in the IE data model. Reintroducing doors merely to satisfy an old test would be unjustified.

Party assembly, offscreen area simulation, general area NPCs, spawns and a full action/event interpreter were not exhaustively audited. Existing projection, navigation, stencil and VossCHMF contracts remain authoritative. There is no evidence from this review that those algorithms should be rewritten.

## Verification

Executed on macOS:

```sh
swift test --scratch-path /tmp/RainShadowSwiftPM --filter 'AreaTriggerTrackerTests|AreaDoorContractTests|AreaCatalogTests|RebuiltCityAreaTests|AreaParityTests|AreaScriptTests|AreaVariablePersistenceTests'
```

Result: 58 tests across seven suites; three failed tests, eight recorded issues; 56.668 seconds. Log: `/tmp/rainshadow-area-audit-tests.log`.

Passing coverage includes actual `Movable` walks to restored approaches/entrances in five areas, restored world-map identities and return links, save migration, area loading, office parity, in-visit trigger behavior, per-state door cells, script ordering and area-variable persistence.

Failures, all in `AreaDoorContractTests`:

- `theOfficeDoorAuthorsAnApproachPairAndSounds`: expects the removed `office.door` record.
- `everyCityPortalIsAlsoADoor`: assumes portal and door records are one-to-one, conflicting with static Sable travel.
- `everyLandmarkDoorEntersAnInteriorAndCanReturnToItsOwnThreshold`: assumes two approach points and door records on both sides, conflicting with current packages.

These are existing contract/content mismatches on the reviewed working tree, not newly introduced failures. Updating the tests should retain destination/entrance reachability while distinguishing static travel from stateful doors. The passing pure tests cannot validate the SpriteKit scene lifecycle findings above because `Core/Scene` and `Scenes` are outside the SwiftPM core target.

Priority: correct pause-aware script execution and area-state persistence, then enforce region flags and test door occupancy. Complete entrance-facing support before authoring directional arrivals. Review each change against the quoted upstream functions rather than broadly changing the protected port.

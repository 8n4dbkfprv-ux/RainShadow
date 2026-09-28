# GemRB area lifecycle — 28 September 2026

The six gaps from the area-logic audit are now addressed in the current shared
runtime, against GemRB `1c45c185`. This extends RainShadow's existing area
implementation; it does not replace its formats with a binary ARE/WED importer
or add the entire BCS/action interpreter.

The restored city packages, current office, VossCHMF assets, projection,
pathfinding and stencil algorithms remain unchanged. Existing local character
work was preserved. New save fields are additive and default to empty for old
saves; no spatial save migration or raster baseline changed.

## Behavior and upstream comparison

| Before | Pinned GemRB evidence | Implemented behavior |
|---|---|---|
| Every area visit rebuilt doors from authored flags. | `AREImporter::PutDoors`: `ieDword flags = d->Flags;` | Area-scoped open/closed overrides are restored into navigation, wall selection, highlights and door visuals before scene construction completes. |
| Opening with a key did not retain an unlocked state. | `Door::SetDoorOpen` calls `SetDoorLocked(false, playsound)` in BG. | Opening records an unlocked flag. Closing and losing the key do not relock it. Loading an initially open door does not implicitly unlock it. |
| Area scripts ran every SpriteKit frame, including pause. | `Interface::GSUpdate` freezes without running scripts; `Scriptable::TickScripting`: `Ticks % 16 != globalID % 16`. | Paused and transitioning scenes do not tick scripts/triggers. An area runs its first script tick immediately, then the staggered 16-tick cadence. Presentation services remain separate. |
| Trigger checks preceded the actor's movement. | `Map::UpdateScripts` steps actors before scanning InfoPoints. | The scene finishes the region tick after updating actor movement and occupancy. |
| Deactivation only removed an exit's outline. | `InfoPoint::CheckTravel`: `if (Flags & TRAP_DEACTIVATED) return CT_CANTMOVE;` | Region hit queries reject deactivated records; the city handler also guards its direct input. Office hotspots omit them. |
| Trigger consumption lived only in a scene-local set. | `AREImporter::PutRegions` writes the live region/trap flags. | One-shot consumption survives visits and save reloads. Legacy `TRG_` variables restore old consumption. Resetting hooks still rearm on reentry. |
| A named trigger block bypassed its condition. | IE region events are inputs to conditional scripts. | The selected hook still evaluates its condition before executing its actions. |
| Entrance facing was parsed but discarded. | `Map::MoveToNewArea`: `face = ent->Face;`. | A resolved named entrance supplies both position and facing to the live actor. Missing-name fallback retains both from the same entry. |
| A door could close through an occupant. | `Door::SetDoorOpen`: `if (BlockedOpen(Open, 0) && !Open)`. | An occupied ordinary close is rejected before visuals, sounds, persistence or collision change. Sliding/forced changes follow their separate branch. |
| Door displacement did not exist. | `Map::JumpActors`: `AdjustPositionNavmap(actor->Pos);`; `Movable::ImpedeBumping`: `oldPos = Pos; bumped = false;`. | Opening checks destination impeded cells, relocates affected live nodes through the existing navmap query, and cancels bump-back. |

Sources: [ARE importer](https://raw.githubusercontent.com/gemrb/gemrb/1c45c185/gemrb/plugins/AREImporter/AREImporter.cpp),
[Door](https://raw.githubusercontent.com/gemrb/gemrb/1c45c185/gemrb/core/Scriptable/Door.cpp),
[InfoPoint](https://raw.githubusercontent.com/gemrb/gemrb/1c45c185/gemrb/core/Scriptable/InfoPoint.cpp),
[Map](https://raw.githubusercontent.com/gemrb/gemrb/1c45c185/gemrb/core/Map.cpp),
[Scriptable](https://raw.githubusercontent.com/gemrb/gemrb/1c45c185/gemrb/core/Scriptable/Scriptable.cpp),
[GlobalTimer](https://raw.githubusercontent.com/gemrb/gemrb/1c45c185/gemrb/core/GlobalTimer.cpp),
[Interface](https://raw.githubusercontent.com/gemrb/gemrb/1c45c185/gemrb/core/Interface.cpp),
[Movable](https://raw.githubusercontent.com/gemrb/gemrb/1c45c185/gemrb/core/Scriptable/Movable.h).

The door change deliberately retains upstream's surprising ordering:
JumpActors runs **before** switching door tiles. It uses a passable-cell query,
not actor clearance. A test pins this rather than substituting a more plausible
post-switch displacement. The actor's origin must be inside a destination
impeded cell; a nearby personal-space stamp alone does not block a close.
`SearchMap.impededCells` reuses the same conservative raster enumeration as the
legacy rectangle stamp. No new world-space routing collision query was added.

## Explicit adaptations retained

- The timer uses GemRB's integer `1000 / 15` interval (66ms), one update per
  elapsed interval, with no catch-up burst after a stall. RainShadow has no
  global scriptable-ID allocator, so its single active area uses stagger phase
  zero after the immediate first update. This does not replace the existing
  actor locomotion clock.
- Mutable object state uses the existing JSON save envelope, keyed by stable
  area/object identity. It is separate from script variables, fog and items.
- Current trigger hooks are RainShadow's small Swift script vocabulary. Saved
  consumption corresponds to their one-shot payload; full IE trapped versus
  harmless event queues, disarming and NPC script scheduling are not introduced.
- Registered occupancy represents the live actors available to this runtime;
  it has no IE corpse/schedule/DONOTJUMP statistic system. Ghosts that do not
  stamp the map are excluded.
- Entrance facing is authored in world-space degrees and converted to the
  existing 16 orientation bins. Authored arrival coordinates already encode
  this game's approach registration; GemRB's additional party formation offset
  is not applied over those coordinates.
- Click/walk travel remains explicitly selected and cancellable. The original
  audit's suggestion that ordinary floor movement should automatically enter
  a region was incomplete: [Actor::CannotPassEntrance](https://raw.githubusercontent.com/gemrb/gemrb/1c45c185/gemrb/core/Scriptable/Actor.cpp)
  requires the matching selected exit and `IF_USEEXIT`. Party assembly and the
  full InfoPoint alternate-use-point model require systems RainShadow does not
  currently have.

## Verification

The focused macOS Swift run passes **105 tests in 11 suites**, including 14 new
lifecycle regressions, restored-area actual movement, portal links, save
migration, literal navigation-port checks and VossCHMF runtime checks.

Three older door tests were rewritten around current authored contracts:
Sable/office static travel has no invented door; Wharf/Riverside each retain
one stateful door with both outlines and reachable approaches; landmark
transitions retain named entrances and return links. Navigation assertions were
not relaxed to make inaccessible positions pass.

Both macOS Debug and iOS Simulator Debug builds succeed. All **35 live scene
checks pass**, using disposable saves and real pointer input through
`RebuiltCityTravelQA`.
The QA additionally exercises pause/resume script wiring, trigger save reload,
arrival facing, open/closed door save reload, and restored door wall selection.

Commands:

```sh
swift test --scratch-path /tmp/RainShadowSwiftPM --filter 'AreaLifecycleTests|AreaDoorContractTests|AreaTriggerTrackerTests|AreaScriptTests|AreaVariablePersistenceTests|RebuiltCityAreaTests|AreaCatalogTests|AreaParityTests|MovableTests|LiteralPortTests|VossCurrentRuntimeTests'
xcodebuild -project RainShadow.xcodeproj -scheme 'RainShadow macOS' -configuration Debug -derivedDataPath /tmp/RainShadowAreaLogicBuild CODE_SIGNING_ALLOWED=NO build
xcodebuild -project RainShadow.xcodeproj -scheme 'RainShadow iOS' -configuration Debug -sdk iphonesimulator -derivedDataPath /tmp/RainShadowAreaLogicIOSBuild CODE_SIGNING_ALLOWED=NO build
env RAINSHADOW_START_SCENE=city RAINSHADOW_START_DISTRICT=sable_row RAINSHADOW_START_ENTRANCE=from.office RAINSHADOW_QA_CITY_RESTORE=/tmp/rainshadow-area-runtime-final /tmp/RainShadowAreaLogicBuild/Build/Products/Debug/RainShadow.app/Contents/MacOS/RainShadow
```

Logs are `/tmp/rainshadow-area-focused-tests.log`,
`/tmp/rainshadow-area-macos-build.log`, and `/tmp/rainshadow-area-ios-build.log`.
The live report and native framebuffer captures are under
`/tmp/rainshadow-area-runtime-final`. iOS gameplay was not run.

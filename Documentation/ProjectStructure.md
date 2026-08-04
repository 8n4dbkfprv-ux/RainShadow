# RainShadow — Proposed Xcode Project Structure

- Status: proposed M01 structure
- Version: 0.1

## 1. Current workspace

The existing project is the stock cross-platform SpriteKit template:

```text
RainShadow.xcodeproj
RainShadow Shared/
├── GameScene.swift
├── GameScene.sks
├── Actions.sks
└── Assets.xcassets/
RainShadow iOS/
├── AppDelegate.swift
├── SceneDelegate.swift
├── GameViewController.swift
├── Info.plist
└── Base.lproj/Main.storyboard
RainShadow macOS/
├── AppDelegate.swift
├── GameViewController.swift
└── Base.lproj/Main.storyboard
RainShadow tvOS/
└── template app files
```

The template currently loads `GameScene.sks`, enables FPS/node overlays, and has iOS, macOS, and tvOS native targets. Deployment targets are currently 27.0.

## 2. Target strategy

| Target | Role | M01 status |
|---|---|---|
| `RainShadow iOS` | iPhone/iPad landscape app | Active |
| `RainShadow macOS` | Native macOS app | Active |
| `RainShadow tvOS` | Template target | Out of scope; no M01 shared resources |
| `RainShadowTests` | Shared model/geometry/system tests | Add in Phase 0 |
| Platform UI-test targets | Launch/input smoke tests | Add only if needed after shared integration harness |

Recommendations:

- Choose verified shipping minimums in Phase 0; proposed iOS/iPadOS 18.0 and macOS 15.0 instead of leaving the template's 27.0-only minimum.
- Use distinct reverse-DNS product bundle identifiers for iOS and macOS.
- Limit iOS M01 to landscape left/right.
- Keep a single shared code/resource group with explicit iOS and macOS target membership.
- Do not create a Swift package for game code yet. The project is small, all code ships together, and target membership is sufficient. Extract packages only when a genuinely reusable/testable boundary emerges.

## 3. Proposed workspace tree

```text
RainShadow/
├── RainShadow.xcodeproj/
├── Documentation/
│   ├── README.md
│   ├── GameDesignDocument.md
│   ├── TechnicalArchitecture.md
│   ├── AssetManifest.md
│   ├── Milestone01ImplementationPlan.md
│   └── ProjectStructure.md
├── RainShadow Shared/
│   ├── App/
│   │   ├── GameBootstrap.swift
│   │   ├── GameConfiguration.swift
│   │   └── GameContext.swift
│   ├── Core/
│   │   ├── Assets/
│   │   │   ├── AssetBundleID.swift
│   │   │   ├── AssetCatalog.swift
│   │   │   └── AssetPreloader.swift
│   │   ├── Audio/
│   │   │   ├── AudioBus.swift
│   │   │   └── AudioDirector.swift
│   │   ├── Input/
│   │   │   ├── GameInputEvent.swift
│   │   │   ├── InputConsumer.swift
│   │   │   └── InputRouter.swift
│   │   ├── Persistence/
│   │   │   ├── SaveEnvelope.swift
│   │   │   ├── SaveStore.swift
│   │   │   └── SettingsStore.swift
│   │   ├── Scene/
│   │   │   ├── BaseGameScene.swift
│   │   │   ├── SceneLifecycle.swift
│   │   │   ├── SceneRoute.swift
│   │   │   ├── SceneRouter.swift
│   │   │   ├── SceneDefinition.swift
│   │   │   └── TransitionSpec.swift
│   │   ├── Rendering/
│   │   │   ├── SceneLayer.swift
│   │   │   ├── DepthSortSystem.swift
│   │   │   ├── DepthSortableNode.swift
│   │   │   └── ViewportCoordinator.swift
│   │   └── Utilities/
│   │       ├── GameClock.swift
│   │       ├── Geometry+Codable.swift
│   │       └── ResourceError.swift
│   ├── GameModel/
│   │   ├── GameSession.swift
│   │   ├── WorldFlag.swift
│   │   ├── SceneObjectState.swift
│   │   └── Investigation/
│   │       ├── CaseState.swift
│   │       ├── EvidenceRecord.swift
│   │       ├── KnowledgeRecord.swift
│   │       ├── PlayerCondition.swift
│   │       └── PlayerTraits.swift
│   ├── Gameplay/
│   │   ├── Actors/
│   │   │   ├── ActorNode.swift
│   │   │   ├── ActorController.swift
│   │   │   ├── ActorState.swift
│   │   │   ├── SpriteAnimationClip.swift
│   │   │   ├── SpriteAnimationLibrary.swift
│   │   │   └── SpriteAnimationPlayer.swift
│   │   ├── Interaction/
│   │   │   ├── HotspotDefinition.swift
│   │   │   ├── HotspotNode.swift
│   │   │   ├── InteractionCommand.swift
│   │   │   ├── InteractionSystem.swift
│   │   │   └── HotspotActionExecutor.swift
│   │   ├── Navigation/
│   │   │   ├── SearchMap.swift
│   │   │   ├── PathFinder.swift
│   │   │   ├── ActorOccupancy.swift
│   │   │   ├── NavigationMap.swift
│   │   │   └── ActorLocomotion.swift
│   │   └── Weather/
│   │       ├── RainConfiguration.swift
│   │       ├── ExteriorRainSystem.swift
│   │       ├── InteriorRainSystem.swift
│   │       └── SurfaceSplashSystem.swift
│   ├── Scenes/
│   │   ├── OpeningExterior/
│   │   │   ├── OpeningExteriorScene.swift
│   │   │   ├── ExteriorCinematicDirector.swift
│   │   │   └── OpeningExteriorState.swift
│   │   ├── DetectiveOffice/
│   │   │   ├── DetectiveOfficeScene.swift
│   │   │   ├── OfficeAssembler.swift
│   │   │   └── OfficeStateController.swift
│   │   ├── AssetPreview/
│   │   │   └── AssetPreviewScene.swift
│   │   └── Recovery/
│   │       └── RecoveryScene.swift
│   ├── UI/
│   │   ├── ObservationPresenter.swift
│   │   ├── WorldTargetLabel.swift
│   │   ├── FirstRunHintNode.swift
│   │   ├── FocusRevealController.swift
│   │   └── PauseOverlayNode.swift
│   └── Resources/
│       ├── Art/
│       │   ├── Areas/
│       │   │   ├── OpeningExterior/
│       │   │   └── DetectiveOffice/
│       │   ├── Atlases/
│       │   │   ├── DetectiveCommon.atlas/
│       │   │   ├── VossSeatedIdle.atlas/
│       │   │   ├── VossSeatedArms.atlas/
│       │   │   ├── VossSeatTransitions.atlas/
│       │   │   ├── VossIdle.atlas/
│       │   │   ├── VossWalk.atlas/
│       │   │   ├── LilaArrival.atlas/
│       │   │   ├── WeatherCommon.atlas/
│       │   │   └── UICommon.atlas/
│       │   └── Assets.xcassets/
│       ├── Audio/
│       │   ├── Ambience/
│       │   ├── Foley/
│       │   ├── Music/
│       │   └── UI/
│       ├── Data/
│       │   ├── Scenes/
│       │   │   ├── opening_exterior.scene.json
│       │   │   └── detective_office.scene.json
│       │   ├── Navigation/
│       │   │   └── detective_office.nav.json
│       │   ├── Animation/
│       │   │   └── detective.animations.json
│       │   └── Art/
│       │       └── art_style_lock.json
│       └── Localization/
│           └── Localizable.xcstrings
├── RainShadow iOS/
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   ├── GameViewController.swift
│   ├── Platform/
│   │   └── IOSTouchInputBridge.swift
│   ├── Info.plist
│   └── Base.lproj/Main.storyboard
├── RainShadow macOS/
│   ├── AppDelegate.swift
│   ├── GameViewController.swift
│   ├── Platform/
│   │   └── MacPointerInputBridge.swift
│   └── Base.lproj/Main.storyboard
├── RainShadowTests/
│   ├── Fixtures/
│   ├── IsoProjectionTests.swift
│   ├── DepthSortSystemTests.swift
│   ├── PathfinderTests.swift
│   ├── AnimationPlayerTests.swift
│   ├── ActorStateTests.swift
│   ├── SceneDefinitionTests.swift
│   ├── SceneRouterTests.swift
│   └── SaveStoreTests.swift
└── ArtSource/                     excluded from all application targets
    ├── Generated/
    ├── Prompts/
    ├── Registration/
    ├── Masters/
    └── QA/
```

`ArtSource` can remain in the repository if storage policy allows, or use external/LFS-backed production storage later. It must never be copied into the application bundle.

## 4. Key Swift files to create first

### 4.1 First vertical slice of files

These are the minimum useful files for the graybox exterior-to-office proof:

| Order | File | Responsibility |
|---:|---|---|
| 1 | `GameConfiguration.swift` | Product constants, debug features, performance defaults, schema versions. |
| 2 | `GameContext.swift` | Holds long-lived services and model state passed to scenes. |
| 3 | `GameBootstrap.swift` | Constructs context and starts the first route. |
| 4 | `BaseGameScene.swift` | Shared roots, camera, lifecycle, input lock, update clock. |
| 5 | `SceneRoute.swift` | Typed route IDs and scene factory inputs. |
| 6 | `TransitionSpec.swift` | Duration, visual style, input/audio/lifecycle behavior. |
| 7 | `SceneRouter.swift` | Sole scene presenter and transition/preload coordinator. |
| 8 | `AssetCatalog.swift` | Logical resource lookup and validation. |
| 9 | `AssetPreloader.swift` | Bundle-level preload, residency, and release. |
| 10 | `GameInputEvent.swift` | Shared touch/mouse/keyboard event representation. |
| 11 | `InputRouter.swift` | Routes normalized input by modal priority. |
| 12 | `ViewportCoordinator.swift` | Aspect-safe camera scale and bounds. |
| 13 | `SceneLayer.swift` | Named z bands and root creation. |
| 14 | `OpeningExteriorScene.swift` | Exterior hierarchy and cinematic entry. |
| 15 | `DetectiveOfficeScene.swift` | Office hierarchy and scene systems. |
| 16 | `RecoveryScene.swift` | Safe critical-load fallback. |
| 17 | platform input bridges | Translate touch/mouse/keys without forking world behavior. |

Exit condition: both targets run placeholder exterior, transition, and office from shared code.

### 4.2 Second vertical slice of files

Add these for movement, depth, and one hotspot:

| Order | File | Responsibility |
|---:|---|---|
| 18 | `SceneDefinition.swift` | Codable placement/schema model. |
| 19 | `SearchMap.swift` | Raster passability/door/actor flag map and radius-line queries. |
| 20 | `NavigationMap.swift` | Scene-facing routing API, door stamping, actor registration. |
| 21 | `PathFinder.swift` | Deterministic Lazy Theta\* implementation. See [Pathfinding and NPC locomotion](PathfindingSystem.md). |
| 22 | `DepthSortableNode.swift` | Ground-pivot root and bias metadata. |
| 23 | `DepthSortSystem.swift` | Static/dynamic depth-key calculation. |
| 24 | `SpriteAnimationClip.swift` | Frame/duration/event model. |
| 25 | `SpriteAnimationPlayer.swift` | Deterministic clip playback. |
| 26 | `ActorNode.swift` | Body, contact shadow, root pivot, mirrored source-facing display. |
| 27 | `ActorController.swift` | Seat/stand/walk/idle command state. |
| 28 | `HotspotDefinition.swift` | Polygon, approach, facing, predicate, observation. |
| 29 | `InteractionSystem.swift` | Hit resolution and command production. |
| 30 | `OfficeAssembler.swift` | Builds graybox/final props and hotspots from data. |

Exit condition: one placeholder hotspot makes the seated actor stand, route around a desk, face the target, and present an observation.

### 4.3 Third vertical slice of files

Add weather, audio, persistence, and polish only after the first two slices are stable:

- `ExteriorRainSystem.swift`
- `InteriorRainSystem.swift`
- `SurfaceSplashSystem.swift`
- `ExteriorCinematicDirector.swift`
- `AudioDirector.swift`
- `GameSession.swift`
- `SaveStore.swift`
- `SettingsStore.swift`
- `ObservationPresenter.swift`
- `FocusRevealController.swift`
- `AssetPreviewScene.swift`

## 5. File responsibilities and boundaries

### App layer

Knows how to construct and start the game. It does not know office prop positions, evidence rules, or platform event classes.

### Core layer

Reusable engine-like services: scene routing, input normalization, assets, audio, rendering policy, persistence, geometry, and time. Core does not import scene-specific types.

### GameModel layer

Pure `Codable` values and rules with no SpriteKit nodes. This is where evidence/deduction foundations live even though M01 exposes only world flags.

### Gameplay layer

SpriteKit-backed actor, navigation, interaction, animation, and weather systems that can be used by several scenes.

### Scenes layer

Composition roots. A scene wires systems and content for one area; it does not reimplement routing, navigation algorithms, input translation, or saving.

### UI layer

Camera-attached SpriteKit nodes and presenters. Later dialogue/evidence screens belong here but are not scaffolded prematurely.

### Platform layer

Only the code that truly depends on UIKit/AppKit: lifecycle controller, touch/gesture adapter, pointer tracking, keys, and window/safe-area behavior.

## 6. Target-membership matrix

| Group | iOS | macOS | tvOS | Tests |
|---|:---:|:---:|:---:|:---:|
| `RainShadow Shared/App`, `Core`, `GameModel`, `Gameplay`, `Scenes`, `UI` | ✓ | ✓ | — | selected source under test |
| Shared runtime resources | ✓ | ✓ | — | fixture copies only |
| `RainShadow iOS` | ✓ | — | — | — |
| `RainShadow macOS` | — | ✓ | — | — |
| `RainShadow tvOS` | — | — | template only | — |
| `RainShadowTests` | — | — | — | ✓ |
| `ArtSource`, QA overlays, prompts, masters | — | — | — | — |

## 7. Resource organization rules

- Area plates and full-canvas environment overlays are standalone bundle PNGs under their area directory.
- Small props may share a scene atlas only after registration metadata is retained; large props remain standalone if atlas packing would exceed limits or force unwanted residency.
- The 140 stored detective frames use three functional atlases. The seven eastern facing bins are mirrored at runtime; no duplicate textures are exported.
- Effect frames are grouped by effect family, not by scene, when both scenes use them.
- JSON basenames are stable IDs and use lowercase snake case.
- Swift type/file names use UpperCamelCase; asset IDs use lowercase snake case.
- No generated text is baked into images; localized content lives in `.xcstrings`.
- Development/reference resources include `Target Membership: none`.

## 8. Template migration map

| Existing file | Planned action | Safe timing |
|---|---|---|
| `RainShadow Shared/GameScene.swift` | Replace its responsibilities with `GameBootstrap`, `BaseGameScene`, and real scenes; remove after both targets boot new path. | End of Phase 1 |
| `RainShadow Shared/GameScene.sks` | Remove from target and project after programmatic placeholder scenes work. | End of Phase 1 |
| `RainShadow Shared/Actions.sks` | Remove; animation actions are code/data-driven. | End of Phase 1 |
| `RainShadow iOS/GameViewController.swift` | Keep, reduce to SKView configuration, bootstrap, and iOS input bridge. | Phase 1 |
| `RainShadow macOS/GameViewController.swift` | Keep, reduce to SKView configuration, bootstrap, and macOS input bridge. | Phase 1 |
| Shared `Assets.xcassets` | Keep for app icons/colors and small UI images; add world resources under structured resource folders/atlases. | Throughout |
| tvOS target files | Leave untouched but exclude from M01 shared membership, or remove target in a separate explicit cleanup decision. | Phase 0 |

Do not delete the template scene files in the same change that first introduces the new bootstrap. First make both targets use the new path, then remove dead resources in a small verifiable change.

## 9. Initial build/configuration changes

Planned changes, not yet applied:

- add `RainShadowTests` target;
- choose supported deployment minimums after installed-SDK check;
- set iOS supported orientations to landscape left/right;
- establish distinct bundle identifiers;
- share M01 Swift/resource target membership only with iOS/macOS;
- enable asset-catalog/texture-atlas optimization for Release;
- keep FPS/node/draw debug flags driven by `GameConfiguration`, off in Release;
- add a build-phase or test validation that required logical asset IDs and JSON schema versions resolve;
- ensure release bundle excludes `ArtSource`, registration overlays, generation prompts, and flattened QA composites.

## 10. Testing structure

Tests should instantiate model/system types without an `SKView` where possible. SpriteKit-dependent tests run on the main actor and use tiny generated placeholder textures.

Priority test files:

- `IsoProjectionTests` — forward/inverse mapping and numeric tolerance.
- `DepthSortSystemTests` — near/far order, bias, stable tie-break.
- `PathfinderTests` — routes, corner rules, unreachable cells, approach points.
- `AnimationPlayerTests` — timing, loop, events, completion, delta clamp.
- `ActorStateTests` — queued movement from chair, interruption rules, idle facing.
- `SceneDefinitionTests` — current fixtures decode and invalid schema fails clearly.
- `SceneRouterTests` — lifecycle order and re-entry rejection.
- `SaveStoreTests` — versioned round trip and atomic replacement behavior.

Fixture JSON belongs in `RainShadowTests/Fixtures`, not copied from a mutable app save directory.

## 11. Structure acceptance gate

Accept the proposed structure when:

- app controllers contain only platform setup and bootstrap calls;
- no shared gameplay file imports UIKit or AppKit;
- no model file imports SpriteKit;
- only `SceneRouter` presents scenes;
- only the platform bridges inspect `UITouch`, `UIGestureRecognizer`, `NSEvent`, or tracking areas;
- office placement and navigation are data-driven;
- all world art and shared code have correct iOS/macOS membership and no tvOS membership;
- actor mirroring is isolated inside `ActorNode` and cannot flip the root pivot/contact shadow;
- source/master/generated/QA art cannot enter the Release bundle;
- both active targets build and the test target passes.

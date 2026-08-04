# RainShadow — Technical Architecture

- Status: proposed architecture
- Version: 0.1
- Scope: M01 exterior, transition, playable office, and foundations for later investigation systems

## 1. Architecture goals

The architecture must:

- render entirely as a 2D SpriteKit game on iOS/iPadOS and macOS;
- preserve a pre-rendered isometric art pipeline while keeping props, actors, doors, effects, and occlusion interactive;
- make the exterior-to-office transition cinematic and hitch-resistant;
- unify touch, mouse, hover, and keyboard without forking scene logic;
- support deterministic depth sorting for actors and props;
- make scene content data-driven enough to revise art placement without rewriting gameplay code;
- establish evidence, knowledge, and deduction data boundaries without implementing the full later UI;
- remain testable outside visual inspection wherever possible.

## 2. Constraints and explicit decisions

### 2.1 Runtime stack

- Swift 5 mode as currently configured, migrating to the current compiler language mode only as a separate verified change.
- SpriteKit is the only world renderer and scene graph.
- Foundation and CoreGraphics support data, geometry, files, and timing.
- AVFoundation may provide persistent audio crossfades because audio must survive scene replacement; it does not render game visuals.
- No SceneKit, `SK3DNode`, RealityKit, third-party engine, custom Metal renderer, or runtime 3D assets.
- M01 pathfinding is a small A* implementation over authored isometric navigation cells. GameplayKit is not required, keeping the “pure SpriteKit” runtime boundary unambiguous.

### 2.2 Current-project findings

The repository is a clean Xcode SpriteKit template with:

- `RainShadow Shared` containing `GameScene.swift`, `GameScene.sks`, `Actions.sks`, and the shared asset catalog;
- separate iOS, macOS, and tvOS application targets;
- platform view controllers that load the template `GameScene`;
- deployment targets currently set to iOS 27.0, macOS 27.0, and tvOS 27.0;
- debug FPS and node counters enabled in both app targets.

M01 will retain iOS and macOS, leave tvOS out of scope, replace the template scene entry point, and decide the shipping minimums before implementation. Proposed compatibility baseline is iOS/iPadOS 18.0 and macOS 15.0, subject to installed-SDK verification. The current 27.0 values are development settings, not an assumed product requirement.

### 2.3 Scene authoring

- Scene classes and hierarchy are created in Swift.
- Scene-specific coordinates, props, hotspots, navigation cells, occluders, and cinematic cues live in versioned JSON definitions.
- `.sks` files are allowed only for effect prototyping when they materially help tune an `SKEmitterNode`; gameplay identity and object placement do not depend on opaque archives.
- Large area plates are standalone textures, not packed into atlases.
- Animation frames and small effects use SpriteKit texture atlases. Apple documents atlases as reducing draw calls and improving texture-use efficiency: [SKTextureAtlas](https://developer.apple.com/documentation/spritekit/sktextureatlas).

## 3. Runtime composition

```text
Platform app target
    -> GameViewController
        -> GameBootstrap
            -> GameContext
                -> SceneRouter
                -> AssetPreloader
                -> AudioDirector
                -> GameSession
                -> SaveStore
                -> SettingsStore
            -> OpeningExteriorScene
                -> TransitionCoordinator
                    -> DetectiveOfficeScene
```

### 3.1 Ownership rules

- `GameViewController` owns the platform `SKView` and installs the relevant input bridge.
- `GameBootstrap` builds long-lived services once per app session.
- `SceneRouter` holds a weak `SKView` reference and is the only type allowed to present a new scene.
- Each `BaseGameScene` owns its SpriteKit nodes and short-lived systems.
- `GameSession`, `SettingsStore`, `SaveStore`, and `AudioDirector` outlive individual scenes.
- SpriteKit nodes never enter model objects. Models hold stable IDs and values, not scene references.
- All SpriteKit graph mutation occurs on the main actor. Current SpriteKit documentation annotates `SKNode` as main-actor isolated: [SKNode](https://developer.apple.com/documentation/spritekit/sknode).

## 4. Coordinate, camera, and aspect-ratio strategy

### 4.1 Logical art space

- One logical world unit equals one pixel in the baseline runtime export.
- Exterior art space: 3072×1728 units.
- Office V3 area plate: 4096×2304 pixels, rebuilt at a high 2:1 dimetric camera and mapped at 0.395 independently from the smaller runtime prop scales.
- Reference playable camera height: 911 units, so the 82-unit standing adult occupies 9% of playable height.
- Reference 16:9 viewport: approximately 1975×1111 world units.
- Narrow composition-safe viewport: central 1481×1111 world units, covering 4:3 landscape.
- Wide composition-safe viewport: approximately 2407×1111 world units, covering common wide phones.

Critical actors, paths, hotspots, and captions must remain readable in the central 1481-unit width. Wide framing reveals intentional environmental overscan rather than stretching or inventing content.

### 4.2 Scene and camera behavior

- `SKScene.scaleMode = .resizeFill` so the scene tracks the actual view in points.
- `SKCameraNode` is attached to the scene. A `ViewportCoordinator` computes camera scale from the desired visible world height and the current scene size.
- World content lives under `worldRoot`; camera-attached HUD content lives under `hudRoot`.
- Camera bounds are clamped against the art-space rectangle plus scene-specific safe margins.
- Interior play begins at the authored camera pose. Optional player zoom is constrained to a narrow quality-safe range.
- Rotation is never exposed.

Apple describes `SKCameraNode` as the node determining which portion of a scene is visible: [SKCameraNode](https://developer.apple.com/documentation/spritekit/skcameranode).

### 4.3 Isometric projection

The navigation grid uses a 2:1 dimetric projection with a 128×64 pixel diamond:

```swift
screenX = originX + (gridX - gridY) * 64
screenY = originY + (gridX + gridY) * 32 + elevation
```

The inverse transform is centralized in `IsoProjection`; no scene or actor reimplements it. Art placement is validated against an exported alignment grid. The background remains a single painted composition, but every reachable point and depth anchor aligns to the same projection.

## 5. Scene graph contract

Every world scene uses the same named root layers:

```text
BaseGameScene
├── backgroundRoot       opaque area plate
├── floorEffectRoot      puddle ripples, floor decals, low mist
├── rearFixtureRoot      fixed wall/window elements behind actors
├── depthWorldRoot       actors and depth-sorted floor props
├── occlusionRoot        authored desk fronts, walls, beams, near props
├── weatherRoot          rain layers that cross world elements as authored
├── cinematicRoot        scene-local fades, letterbox, match-cut overlay
├── camera
│   └── hudRoot          captions, hints, pause, accessibility overlays
└── debugRoot            navigation, anchors, hotspot polygons; debug only
```

Recommended z bands:

| Band | Range | Content |
|---|---:|---|
| Background | -10,000 | Area plate |
| Floor effects | -9,000…-8,000 | Wet sheen, floor-only effects |
| Rear fixtures | -5,000…-4,000 | Wall fixtures and rear window components |
| Depth world | 1,000…3,500 | Actor and floor-prop roots |
| Occlusion | 5,000…6,500 | Foreground cutouts intentionally over actors |
| Weather/cinematic | 7,000…8,500 | Near rain, fade, letterbox |
| HUD | 10,000+ | Input-independent UI |

Nodes must not use arbitrary z values outside their band's constants.

## 6. Depth sorting and occlusion

### 6.1 Depth-anchor model

Each depth-sorted object has a root positioned at its ground-contact anchor. The visible sprite is offset relative to that root. The object's logical “feet” are therefore always `root.position` even when its transparent canvas is large.

```swift
zPosition = depthWorldBase
          + (worldHeight - depthAnchorY) * depthScale
          + sortBias
```

With SpriteKit's bottom-left scene coordinates, lower screen Y is nearer the viewer and receives a larger z value. `sortBias` resolves deliberate cases such as a chair tucked under a desk. A stable tie-breaker derived from object load order prevents flicker when anchors match.

### 6.2 Dynamic and fixed sorting

- Static floor props are sorted once after scene construction.
- Moving actors recompute depth after their position changes.
- Multi-part actor children inherit the actor root's z and never sort independently.
- Wall-mounted fixtures stay in a fixed rear band.
- Tall props that an actor can pass both behind and in front of use an occlusion split: a depth-sorted base plus an authored transparent front cutout in `occlusionRoot`.
- The desk uses at least a base/back component and a front-edge occluder so the seated detective can sit behind it while a walking detective can pass correctly around it.

### 6.3 Debugging

`DepthDebugOverlay` can display:

- each root's depth anchor;
- current z value and bias;
- occlusion polygons;
- actor route and current cell;
- red warnings for equal depth keys without an explicit tie-break.

## 7. Scene lifecycle and transition system

### 7.1 Base lifecycle

`BaseGameScene` exposes explicit hooks:

```swift
prepare() async throws       // decode definition and preload required assets
buildScene() throws          // create the node graph on the main actor
sceneWillEnter()
sceneDidEnter()
sceneWillExit()
tearDown()
```

`didMove(to:)` does not perform heavy decoding. It completes view-dependent setup and begins the prepared timeline.

### 7.2 Scene router

`SceneRouter` accepts a `SceneRoute` and `TransitionSpec`. Responsibilities:

- reject re-entrant route requests;
- lock world input;
- request and validate incoming-scene preload;
- notify outgoing services;
- present the scene with the agreed transition;
- unlock input only after incoming `sceneDidEnter()`;
- release outgoing scene assets after the overlap window;
- route recoverable failures to an in-world-compatible loading/error curtain.

SpriteKit provides `SKView.presentScene(_:transition:)` and standard crossfade/fade transitions: [SKTransition](https://developer.apple.com/documentation/spritekit/sktransition) and [presentScene(_:transition:)](https://developer.apple.com/documentation/spritekit/skview/presentscene(_:transition:)). RainShadow wraps that primitive so loading, input, audio, and lifecycle cannot diverge between callers.

### 7.3 Exterior-to-office transition

1. Exterior assets load and the scene starts.
2. Office scene definition, area plate, required props, actor seated atlas, and ambience preload while the first exterior hold plays.
3. `CinematicDirector` runs the exterior camera push toward the identified warm office window.
4. At the match point, `TransitionCoordinator` raises a shadow/warm-window overlay and crossfades exterior and interior audio beds.
5. `SceneRouter` presents the already-built office using a short black/warm crossfade. Incoming scene animations are configured to begin at the intended point rather than running invisibly during a paused transition.
6. The office resolves at the corresponding window/lamp composition, completes the detective's idle beat, and unlocks input.

If preload is unexpectedly late, the overlay can hold on near-black while rain audio continues. The router never exposes an empty view or blocks the main thread on image decoding.

## 8. Scene-specific architecture

### 8.1 `OpeningExteriorScene`

Systems:

- `CinematicDirector` for a deterministic cue timeline;
- `ExteriorRainSystem` for far, middle, and near streak emitters;
- `SurfaceSplashSystem` for authored street/puddle spawn polygons;
- `LightingPulseController` for subtle sign/window variation;
- scene-local camera rail with reduced-motion alternative;
- skip recognizer available after 1.0 second;
- preload task for the office route.

The scene contains no actor navigation or investigation state. A skip still completes preload/lifecycle cleanup and uses the same router path.

### 8.2 `DetectiveOfficeScene`

Systems:

- `OfficeAssembler` builds the area plate, individual props, occluders, and hotspots from `office.scene.json`;
- `InteriorRainSystem` clips streaks and droplet loops to the glass using `SKCropNode`;
- `DepthSortSystem` maintains actor/prop ordering;
- `NavigationSystem` finds authored-cell paths;
- `ActorController` owns the detective state machine and movement;
- `InteractionSystem` resolves pointer target, approach, facing, and inspect action;
- `ObservationPresenter` shows short captions and accessibility announcements;
- `OfficeStateController` applies object state changes such as phone checked or door attempted.

## 9. Rain and environmental effects

### 9.1 Exterior rain

Use three `SKEmitterNode` layers:

- far rain: thin, low-alpha, slower apparent streaks behind foreground architecture;
- middle rain: main density and speed;
- near rain: sparse, larger streaks above most world art.

Parameters vary within narrow ranges to avoid uniform lines. Rain direction is consistent with the facade highlights and puddle splashes. Emitters use small grayscale streak textures tinted at runtime; they do not generate the entire wet look. Wetness and reflections are painted into the area plate and separated reflection overlays.

Street splashes and puddle ripples are bounded to authored polygons, not emitted across walls or windows. A small pool recycles sprite nodes to prevent allocation spikes.

### 9.2 Interior window rain

- Glass mask clips all moving rain.
- A low-frequency scrolling streak texture supplies continuous motion.
- Random droplet trails and impact sprites break repetition.
- Exterior flashes or traffic sweeps are optional low-alpha light overlays, not full-screen strobes.
- Near-room air remains still; no rain streaks appear over the detective or office floor.

### 9.3 Reduced-effects mode

Reduced rain intensity changes particle birth rate, near-streak opacity, splash frequency, and camera parallax. It never removes the wet art or the audio cue needed for narrative continuity.

## 10. Actor and animation architecture

### 10.1 Node composition

```text
ActorNode (position = ground pivot; participates in depth sort)
├── contactShadow
├── bodySprite
├── interactionAnchor
└── debugFacingIndicator
```

### 10.2 State machine

```text
seatedIdle
    -> standingUp
        -> standingIdle
            -> walking
                -> standingIdle
                    -> sittingDown
                        -> seatedIdle
```

- A navigation or distant-hotspot request while seated is queued.
- The initial seated pose is a visual child offset from a walkable actor root; standing animates that child back to the root before path traversal, so desk fit does not place navigation inside the desk obstacle.
- The stand-up animation completes before path traversal begins.
- A near hotspot can play its inspection while standing without walking.
- A new movement command replaces the remaining path after the current step reaches a safe interpolation point.
- Sitting is only permitted inside the authored chair approach cell and facing.

### 10.3 Animation playback

`SpriteAnimationPlayer` advances frames from delta time rather than nesting uncontrolled `SKAction` loops. Each clip manifest declares:

- state ID;
- direction;
- ordered texture names;
- per-frame duration or default FPS;
- loop mode;
- ground-pivot correction, normally zero;
- event markers such as `footstepLeft`, `footstepRight`, `chairCreak`, and `transitionComplete`.

This allows exact footstep timing, reduced-motion control, clean state interruption, deterministic tests, and frame holds for subtle idle motion.

### 10.4 Direction mapping

Movement velocity in projected screen space maps to one of 16 facing bins. A small hysteresis angle prevents rapidly alternating direction near sector boundaries. Nine source orientations—S through N on the western arc—are stored; the seven eastern orientations use a mirrored body sprite, reflecting the legacy BG2/BG:EE avatar convention. Mirroring occurs below the actor root so the ground pivot, hotspot anchor, and contact shadow never flip. The standing idle inherits the last walk direction.

## 11. Navigation

### 11.1 Authored navigation data

`office.nav.json` contains:

- projection origin and tile size;
- grid dimensions;
- blocked cells or compact row bitsets;
- per-cell movement cost;
- special approach cells and required facing for hotspots;
- optional door portal cells;
- camera-safe walkable bounds.

### 11.2 Pathfinding

- A* over eight-connected cells.
- Diagonal corner cutting is forbidden when either adjacent orthogonal cell is blocked.
- Heuristic uses projected Euclidean distance between cell centers, matching step costs in the same projected metric (not grid-index octile).
- Returned path is simplified only when a straight segment remains fully within walkable cells.
- Actor speed is measured in projected world distance so diagonal screen movement does not appear faster.
- M01 has no dynamic obstacle avoidance; the single detective is the only moving world actor.

### 11.3 Click/tap resolution

1. Convert view input to scene coordinates.
2. Query active hotspots by polygon, interaction priority, and z/depth.
3. If a hotspot wins, request its authored approach cell.
4. Otherwise inverse-project to the nearest walkable navigation cell.
5. If the cell is blocked, search a limited ring for the nearest reachable cell and show no move marker when none exists.
6. Build path and hand it to `ActorController`.

## 12. Cross-platform input

### 12.1 Common event model

Platform events normalize into:

```swift
enum GameInputEvent {
    case pointerDown(id: Int, scenePoint: CGPoint, kind: PointerKind)
    case pointerMoved(id: Int, scenePoint: CGPoint)
    case pointerUp(id: Int, scenePoint: CGPoint)
    case hover(scenePoint: CGPoint?)
    case cancel
    case focusReveal(isActive: Bool)
    case cameraPan(CGVector)
    case cameraZoom(CGFloat, anchor: CGPoint)
    case skip
}
```

`InputRouter` selects the active consumer in priority order: modal UI, HUD, cinematic, world interaction. Scenes never test `UITouch` or `NSEvent` inside gameplay systems.

### 12.2 Platform bridges

- iOS: `IOSTouchInputBridge` forwards touches and configured gestures from the SpriteKit view.
- macOS: `MacPointerInputBridge` owns tracking area, mouse moved/down/up/dragged, scroll, and key commands; it ensures the view/window accepts first responder.
- Both bridges convert locations through the active scene before emission.
- Test helpers can inject common events without constructing platform objects.

## 13. Interaction system

### 13.1 Hotspot definition

```text
HotspotDefinition
  id
  localizedNameKey
  polygon[]
  priority
  defaultVerb
  approachCell
  facing
  enabledPredicate
  observationSequence[]
  mutations[]
  accessibilityKey
```

Hotspots are invisible data nodes by default. Art nodes expose stable IDs but do not own narrative logic.

### 13.2 Command flow

```text
InputRouter
  -> InteractionSystem.resolve(point)
      -> InteractionCommand
          -> ActorController.approach(target)
              -> on arrival: HotspotActionExecutor.perform(command)
                  -> GameSession mutation
                  -> ObservationPresenter
                  -> AudioDirector
```

Input is not frozen during walking. A later command can replace the pending one, except during the non-interruptible stand-up frames and transition lock.

## 14. Data and game state

### 14.1 Core model types

Even though M01 exposes only a few flags, establish these value types early:

- `GameSession`
- `CaseState`
- `EvidenceRecord`
- `KnowledgeRecord`
- `DialogueState`
- `WorldFlag`
- `SceneObjectState`
- `PlayerTraits`
- `PlayerCondition`

All are `Codable`, versioned, and independent of SpriteKit.

**Dialogue roadmap Phase 0 (shipped):** `WorldFlag`, `CaseState`, `DialogueState`, and `DialogueRuntimeContext` live in `RainShadow Shared/Gameplay/Navigation/DialogueStateModels.swift` (RainShadowCore). They are not yet threaded through `CaseIntroductionPresenter` or `SaveSnapshot`. Full `EvidenceRecord` / `KnowledgeRecord` payloads and the remaining §14.1 types remain deferred.

#### Dialogue graph authoring (classic BG roles)

Shipped conversation data (`CaseDialogueNode` / `CaseDialogueChoice` in Navigation) follows **classic Baldur’s Gate / Infinity Engine DLG** roles (GDD §7.5):

- **Node body** = actor speech (NPC or case-title end). Multi-page NPC beats use `nextNodeID` + Continue.
- **Choice text** = player character speech. Mid-conversation PC lines must be choices, not Voss speaker nodes with empty choices and `nextNodeID`.
- **Exception:** `isInteriorMonologue` Continue chains before the NPC exchange (Empty Coat `voss.monologue.*` only for that pattern today).

Do not “simplify” PC acceptance or commitments into auto-Continue speaker states. See Dialogue System Roadmap frozen section and Empty Coat graph comments.

### 14.2 Scene definition schema

Each scene JSON includes:

- schema version and scene ID;
- art-space size and camera poses;
- required asset bundle IDs;
- prop instances with texture, position, anchor, depth behavior, and state variants;
- occluder instances;
- hotspot definitions;
- navigation file reference;
- environmental effect regions;
- audio zones and cinematic cues;
- debug reference markers.

Unknown schema versions fail in debug with a precise message. Release builds show a recoverable error curtain rather than crashing into a black scene.

### 14.3 Saving

M01 persists:

- `hasSeenOpening`;
- five office hotspot flags;
- detective seat/stand state normalized to a safe restore point;
- settings and accessibility preferences.

Save data uses a versioned `SaveEnvelope` and an atomic file replacement in the platform Application Support directory. Autosave occurs after the office becomes interactive and after a hotspot state mutation. iCloud and cross-device sync are later scope.

## 15. Asset loading and memory

### 15.1 Asset bundles

Logical bundles:

- `opening_exterior`
- `office_environment`
- `detective_seated`
- `detective_locomotion`
- `weather_common`
- `ui_common`
- `audio_opening`

`AssetCatalog` maps logical IDs to texture, atlas, audio, and JSON resource names. Scenes request bundles, never raw scattered filenames.

### 15.2 Preload policy

- App boot preloads only common UI, loading curtain, and the exterior.
- The office area plate, immediately visible props, seated animation, and audio preload during the exterior.
- Standing/walking atlases finish preloading before input unlock. If not ready, the detective's seated idle remains natural while loading completes.
- Exterior-only textures are released after the transition overlap.
- Large backgrounds stay outside atlases so they do not force unrelated sprites to remain resident.

### 15.3 Initial budgets

Targets to validate on a representative iPhone 13-class device and an Apple-silicon Mac:

| Metric | Exterior | Office steady | Transition peak |
|---|---:|---:|---:|
| Frame rate | 60 fps target | 60 fps target | no visible hitch |
| Live nodes | < 350 | < 300 | < 500 |
| Live rain particles | < 900 | < 250 | < 1,000 |
| Texture memory | < 120 MB | < 180 MB | < 280 MB |
| Main-thread frame | < 16.7 ms median | < 16.7 ms median | no frame > 50 ms caused by synchronous loading |

Budgets are gates, not promises; Instruments and actual target hardware decide final texture tiers and particle counts.

## 16. Audio architecture

`AudioDirector` is a long-lived service with buses for music, ambience, weather, dialogue, and UI/foley. Responsibilities:

- preload and loop long beds;
- randomized no-repeat one-shots;
- bus volume and accessibility settings;
- application background/foreground handling;
- exterior/interior rain crossfade independent of scene destruction;
- side-chain reduction of music/ambience during dialogue later.

World-positioned short effects may use scene-local `SKAudioNode`; persistent beds use AVFoundation so their playhead and fade survive `SKScene` replacement.

## 17. Application lifecycle

- Pause input, movement, animation clocks, and nonessential effects when the app resigns active.
- Fade persistent audio safely rather than abruptly stopping during interruption.
- Clamp simulation delta after resume to avoid actors jumping along paths.
- Rebuild camera layout on size/orientation/window changes.
- Save before entering background when state has changed.
- macOS window resizing is supported; rendering never stretches the art independently by axis.

## 18. Diagnostics and observability

Debug-only toggles:

- FPS, node count, draw count, and quad count;
- camera safe frame and art bounds;
- hotspot polygons and labels;
- navigation grid, current path, and approach cells;
- depth anchors, z bands, and occluders;
- asset-bundle residency and estimated texture memory;
- current actor state/direction/frame;
- current transition phase and input lock owner.

Release defaults disable SpriteKit performance overlays and debug shapes.

## 19. Testing strategy

### 19.1 Unit tests

- `IsoProjection` round-trip within tolerance.
- depth keys order near objects in front of far objects and honor bias.
- A* routes around the desk, forbids corner cutting, and rejects unreachable cells.
- actor state transitions queue movement correctly from seated state.
- animation player emits events once and handles large/resumed deltas.
- hotspot predicates and mutations are deterministic.
- scene, navigation, animation, and save JSON decode with the current schema.
- transition router rejects a second route while one is active.

### 19.2 Integration tests

- Bootstrap presents exterior on iOS and macOS test hosts.
- Skip and natural cinematic completion reach the same office state.
- Office input remains locked until actor locomotion assets are ready.
- Five hotspots can be inspected with injected common pointer events.
- Background/foreground cycle does not duplicate rain or audio nodes.
- Saved first-run state suppresses the hint and permits opening skip behavior.

### 19.3 Visual and performance QA

- Screenshot matrix: 4:3 iPad landscape, 16:9, wide iPhone landscape, resizable macOS window, 1×/2× scale.
- Inspect alpha edges over both warm and cool backgrounds.
- Walk behind/in front of desk, chair, cabinet, door frame, and foreground wall.
- Slow-motion capture of all 16 displayed walk facings, including mirrored transitions, for foot sliding, pivot drift, and coat discontinuity.
- Instruments run for allocations, leaks, frame pacing, texture residency, and particle load.
- Audio transition checked with headphones, phone speaker, and muted music.

## 20. Failure handling

- Missing optional prop: log and omit in release; assert in debug.
- Missing critical plate/actor atlas/scene definition: show `RecoveryScene` with retry and diagnostic code.
- Corrupt save: retain the file with a timestamp, start a new session only after presenting a clear choice in the full game; M01 debug builds surface the decode error.
- Route preload failure: keep outgoing/curtain scene alive and offer retry; never present an unbuilt scene.
- Unreachable hotspot: report in debug, show a short “can't reach it” observation in release, and do not deadlock input.

## 21. Security, privacy, and network stance

M01 has no account, analytics, remote content, microphone, camera, location, or network dependency. Save and settings data stay local. Generated art is shipped as normal application resources; no generation API is called at runtime.

## 22. Architecture acceptance gate

Architecture is accepted for M01 when a graybox proves:

- one shared `SceneRouter` can present exterior and office in both app targets;
- a preloaded transition completes without synchronous texture decoding on the cut;
- a placeholder actor starts seated, stands, walks an A* route, and changes 16-facing animation state from nine source orientations;
- depth ordering is correct around at least three split occluders;
- touch and mouse produce the same `InteractionCommand` for the same hotspot;
- all scene placement comes from decoded definitions;
- no SceneKit or runtime 3D dependency appears in either target.

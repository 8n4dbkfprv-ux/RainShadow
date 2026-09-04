# RainShadow — Technical Architecture

- Status: proposed architecture; §11 Navigation describes the shipped implementation
- Version: 0.2
- Scope: M01 exterior, transition, playable office, and foundations for later investigation systems
- Related: [Pathfinding and NPC Locomotion](PathfindingSystem.md) — authoritative navigation reference and NPC authoring rules

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
- `SKShader` is **in scope**: it is SpriteKit's own shader API, not a renderer of our own, and the rule above rules out hand-written Metal rather than per-pixel work. The engine's pixel shaders (`BlitFlags` tint / greyscale / sepia, and the wall stencil) are per-pixel operations with no `SKSpriteNode` property that expresses them — `colorBlendFactor` interpolates toward a colour where the engine multiplies — so they are written as `SKShader` fragment programs. See `RainShadow Shared/Core/Scene/IEBlitShader.swift`, which also records SpriteKit's measured opacity contract: `SKDefaultShading()` returns premultiplied RGBA with the node's `alpha` already folded in, and SpriteKit does **not** re-apply node `alpha` to a custom shader's output.
- Pathfinding is a self-contained Lazy Theta\* search over a raster search map built from authored obstacle geometry (§11). GameplayKit is not required, keeping the “pure SpriteKit” runtime boundary unambiguous.

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
- Office area plate: 4096×2304 pixels, Baldur's Gate: EE orthographic projection (elevation asin(0.75), ground axes ±0.75), mapped at environment **0.395** independently from body-locked prop scales (prop relative scales cancel the environment factor).
- V18 bakes only fixed office fixtures into those pixels: two steel casement
  windows and two 1950s cast-iron radiators on the window wall. The fireplace,
  hearth, firelight, collision and actor cover are retired. Window rain,
  near-window hover and interaction, the door-state family, and navigation
  remain separately registered.
- Playable camera scale at 100%: **1.0986328125 world units per logical view point**, derived from the unchanged 70.3125-unit Voss body divided by its 64 native rows. Voss is 64 points high at 100%; resizing reveals more world, rather than holding him at 9% of the window. Office, wards and city interiors share the scale. The old fixed 781.25-unit visible height is retired. See [native camera calibration](NativeSpriteCameraCalibration.md) for engine evidence and rounding/Retina limits.
- At a 2048×1152-point reference view, the 100% viewport is 2250×1265.625 world units. Smaller rooms may be surrounded by black; the existing engine clamp owns their framing.

Critical actors, paths, hotspots, and captions must remain readable in the central 1481-unit width. Wide framing reveals intentional environmental overscan rather than stretching or inventing content.

### 4.2 Scene and camera behavior

- `SKScene.scaleMode = .resizeFill` so the scene tracks the actual view in points.
- `SKCameraNode` is attached to the scene. `BaseGameScene` applies the shared native-sprite camera scale multiplied by the engine zoom percent. The opening exterior alone retains its fixed-height cinematic framing.
- World content lives under `worldRoot`; camera-attached HUD content lives under `hudRoot`.
- Camera bounds are clamped by `AreaViewport.clampedCenter`, a transliteration of GemRB's `MoveViewportTo`: ±64 units of overflow on x, a 50-unit pad on the far y edge, and the map centred once the viewport outgrows it. The 50-unit pad also biases the centring, so an area smaller than the viewport sits on `map.midY - 50` rather than on a true centre. That is upstream's, kept deliberately, and it moved the office's default framing by 50 units when it landed.
- Interior play begins at the authored camera pose. Player zoom is BG:EE's full 1…27 band in every area, indoor and outdoor alike; past the area edge the frame is void, which is Infinity Engine framing.
- Rotation is never exposed.

Apple describes `SKCameraNode` as the node determining which portion of a scene is visible: [SKCameraNode](https://developer.apple.com/documentation/spritekit/skcameranode).

### 4.3 Isometric projection

The target for area art and the navigation diamond is the Baldur's Gate: EE
orthographic ground projection (see `Documentation/InfinityEngineGroundProjection.md`
and `ArtSource/Processing/ie_projection.py`):

```text
elevation          asin(0.75) ≈ 48.59°
azimuth            45°
ground axes        36.87° from horizontal (slopes ±0.75)
ground foreshorten 0.750
height foreshorten ≈ 0.6614
nav diamond        128×96  (exactly 8×8 SearchMap cells of 16×12)
```

Forward projection in authored plate space:

```swift
screenX = originX + (gridX - gridY) * 64
screenY = originY + (gridX + gridY) * 48 + elevation
```

Shared Python helpers live in `ie_projection` (`cell_to_authored` /
`authored_to_cell`). Runtime scenes do not re-project per frame: the look is
baked into the painted plates, and world units map 1:1 from plate pixels (×
environment scale) under a uniform `SKCameraNode`. Locomotion already uses
`verticalProjectionScale = 0.75` and `SearchMap.defaultCellSize = (16, 12)`,
which match this camera.

`ie_projection.ACTIVE` is `BGEE`. The projection is a property of the painted
pixels, so a plate, its geometry manifest, generated room plan, search map, and
runtime registration must land together. V11's installed plate measures
+36.70°/−36.97°; the earlier staged-adoption history and rollback masters are
recorded in `Documentation/BGEEProjectionMasterRegen.md`.

## 5. Scene graph contract

Every world scene uses the same named root layers:

```text
BaseGameScene
├── backgroundRoot       opaque area plate
├── floorEffectRoot      puddle ripples, floor decals, low mist
├── rearFixtureRoot      registered light/effect overlays behind actors
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
| Rear fixtures | -5,000…-4,000 | Registered wall light/effect overlays; V11 window frames/blinds are plate pixels |
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

- `OfficeAreaAdapter`/`office_suite.area.json` provide the plate texture,
  regions/travel, props, registered door visual, obstacles, walls, actors,
  ambients, and camera bounds; the scene consumes that definition rather than
  duplicating the door or window in hardcoded scene data;
- `InteriorRainSystem` clips streaks and droplet loops to both baked windows
  through a full-plate registered glass mask using `SKCropNode`;
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

- One full-plate glass mask clips all moving rain to both baked steel casements;
  the camera-nearer window alone has an interactive region. Hover uses the
  Infinity Engine outline polygon for `office.window`, not a texture overlay.
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

Navigation follows Baldur's Gate: Enhanced Edition / Infinity Engine practice: a raster search map, Lazy Theta\* any-angle search, runtime actor and door stamping, and directed destination adjustment. This section is the architectural summary; [Pathfinding and NPC locomotion](PathfindingSystem.md) is the authoritative reference, including the NPC authoring convention.

### 11.1 Authored navigation data

No separate `office.nav.json` ships. For V11,
`office_v11_geometry.json` generates the office room/layout records and
`office_suite.area.json` exports the plate, obstacles, walls, door, and regions;
area-export parity tests prevent it drifting from `OfficeAreaAdapter` and
`OfficeNavigationLayout`. City layouts remain authored by `CityDistrictLayout`
and `CityDistrictCatalog`. The registered layouts declare:

- world bounds for the walkable area;
- static obstacle rects for walls, furniture, and fixtures, expressed with the floor-contact clearance already baked into the art;
- door obstacle rects, held separately so they can be stamped and cleared without rebuilding;
- hotspot approach anchors and the sparse anchors for scripted actor beats;
- the agent profile the scene's actors plan with.

Each layout exposes `makeGrid()`, which returns a configured `NavigationMap`.
The fireplace obstacle and cover polygon come from the same V11 fixture
footprint, while the door's closed stamp remains independently toggleable.

### 11.2 Search map

`SearchMap` is a byte-per-cell raster over world space, cells defaulting to 16×12 logical units to match the BG:EE cell aspect. Flag bits mirror GemRB's `PathMapFlags`: `passable`, `doorImpassable`, `playerActor`, `npcActor`. Static obstacles rasterize once at construction; doors and actors stamp into the same raster at runtime, so dynamic obstacles cost a stamp rather than a map rebuild.

Radius queries test authored obstacle geometry in addition to cell flags, so an agent with real clearance cannot pass a gap that only fits a point, and the map boundary is solid for any agent with radius greater than zero.

### 11.3 Pathfinding

- **Lazy Theta\*** (`PathFinder`, following GemRB's `Map::FindPath`): 4-connected expansion with lazy parent relinking whenever a line-of-sight check clears the direct segment. The any-angle polyline is produced by the search itself, so there is no separate string-pull pass.
- Heuristic weight is 1.5 (GemRB's default), trading strict optimality for responsiveness; equal-cost frontiers break on the cross product against the straight start-to-goal line, biasing paths toward the visual straight line rather than a staircase.
- Expansion is capped by a node budget (default 32 000, BG:EE's "Path Search Nodes"). Exceeding it fails the search instead of stalling a frame.
- The result is a `Path`. An empty one means *do not walk*, and covers both "already there" and "no route" — as it does in the engine. A non-empty one does **not** prove the requested point was reached, because a blocked goal is relocated inside the search; `NavigationMap.reachesExactly` is the strict question.
- Actor speed is not a scalar. `Movable.doStep` takes one `PathFinder.normalizeDeltas` step per 15 Hz tick, rounded up to whole world units per axis — 7 east-west, 6 north-south for an ordinary humanoid.
- Actors are stamped into the map by `ActorOccupancy`. Idle friendly actors are bumpable and traversable during planning; when a mover is blocked by one, `DoStep` either has the blocker `BumpAway` (it relocates itself and comes back) or backs off for a randomised wait. Failed *searches* are capped by `MAX_PATH_TRIES`.
- Scenes recompute the active route every 0.75 s while walking (`Actor::NewPath`, BG:EE "Enhanced Path Search"), so a bottleneck that clears mid-walk yields the shorter path. Rebuilding to `Destination` discards intermediate waypoints, as in the engine.

### 11.4 Click/tap resolution

1. Convert view input to scene coordinates.
2. Query active hotspots by polygon, interaction priority, and z/depth.
3. If a hotspot wins, request its authored approach anchor.
4. Otherwise check `NavigationMap.isOrderableFloor`. Impassable ground is refused outright — `GameControl::OnMouseUp` returns early on `IE_CURSOR_BLOCKED` — and shows the blocked marker. Ground with a body standing on it is still orderable; that is something to bump.
5. Issue the order through `DetectiveActorNode.issueOrder(via:to:...)`, which runs `MovementOrderQueue` against the actor's own `Movable`: `WalkTo` for a fresh order, `AddWayPoint` for a queued one, and the same-cell head turn for a click you already stand in.
6. Draw a reticle per pending waypoint and one at the destination. The waypoints come from the path itself, so there is no separate queue to keep in step.

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

### 13.3 Infinity Engine object highlights

World interactables use authored outline polygons (ARE-style), not baked `_hover` PNGs.

- `HighlightableObject` stores a world-space vertex ring and IE state flags (locked, empty, secret, trap). Doors carry two rings, as the ARE does (`0x002c/0x0030` open, `0x0034/0x0032` closed); `polygon` resolves them the way GemRB's `DoorTrigger::StatePolygon` does, and `GameAreaScene.presentDoorVisual` flips the state.
- Hit testing is point-in-polygon with GemRB priority: door first, then infopoint; a container overrides an infopoint at the same location. It is the ring, never the bounding box — `Highlightable::IsOver` is `outline->PointIn(place)` — so a tight ring is a tight click target by design.
- `HighlightResolver` assigns outline colours from BG2 `colors.2da`: cyan hover, red trap, green targetable lock, magenta Tab-door / found secret, cyan Tab-container, grey empty container.
- `HighlightOutlineLayer` draws each ring the way `Highlightable::DrawOutline` does — **two passes**: a `HALFTRANS` fill at half the outline colour's alpha across the whole silhouette, then the same colour solid on the edge, neither antialiased. IWD2's `GFFlags::HIGHLIGHT_OUTLINE_ONLY` (fill dropped) and PST's `MOD` fill blend are the two variants we do not ship. The edge is one screen point at every zoom: `lineWidth` is world units, so `BaseGameScene.applyCameraScale` rescales it beside `gameCamera.setScale`.
- The layer sits above the plate and below actors (`SceneLayer.highlightOutlines`), matching `Map::DrawHighlightables`, which runs after the tilemap and before the object queue. GemRB's doors are tilemap background so nothing covers them; ours are live sprites, so `setDrawOrder` lifts a door's ring over its own leaf.
- Tab hold (macOS) or the lantern utility (touch) reveals all doors and containers, matching GemRB Alt/Tab.

Office rings live in `OfficeHighlightOutlinePolygons`, drawn by hand over `office_suite_plate.png` by `ArtSource/Processing/generate_highlight_outline_polygons.py` — the V20 plate is a repaint, so the retired prop PNGs no longer register against it and the noir values do not segment. City rings live in `CityHighlightOutlinePolygons`, traced from each portal's RGBA door-leaf alpha and seated through the shipped `AreaDoorVisual` registration by `generate_city_highlight_outline_polygons.py`. Both scripts write a `--qa` composite over the shipped plate; that overlay is the acceptance gate, and `HighlightOutlineTests` fails any ring that is still its own bounding box.

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

**Dialogue roadmap Phase 0 (shipped):** `WorldFlag`, `CaseState`, `DialogueState`, and `DialogueRuntimeContext` live in `RainShadow Shared/Gameplay/Navigation/DialogueStateModels.swift` (RainShadowCore).

**Presenter wiring (shipped):** `DialoguePresenter` owns a pure `DialogueSession` and exposes `runtimeContext` for case-state merge after conversations. `BaseGameScene` owns the presenter and the single `presentDialogue(_:ownerID:onComplete:)` door, so any scene can converse — the panel used to be private to `DetectiveOfficeScene`.

`SaveSnapshot` persists the **whole** `CaseState`: flags, `knowledgeIDs`, `evidenceIDs`, queued journal fragments, and `counters` (including the reserved `talk.<ownerID>` counts). It previously stored flags alone, so evidence, knowledge, and earned casebook entries were merged into the live session and then lost on relaunch. Mid-conversation `DialogueState` is still **not** persisted, matching IE, which does not save mid-dialogue either. Full `EvidenceRecord` / `KnowledgeRecord` payloads and the remaining §14.1 types remain deferred.

#### Dialogue runtime stack

| Layer | Responsibility |
|---|---|
| **Resources** | Versioned JSON graphs / catalogs + `strings.en.json` under `RainShadow Shared/Resources/Dialogue/` |
| **Loader** | `DialogueGraphLoader` + `DialogueStringTable` — decode authored keys/inline prose, resolve keys at load, validate start node |
| **Runtime graph** | `DialogueGraph` of `CaseDialogueNode` / `CaseDialogueChoice` (resolved strings only) |
| **Walker** | `DialogueSession` — entry scan, conditions, actions, advance, cross-graph jumps, transcript (SpriteKit-free) |
| **Catalog** | `DialogueGraphCatalog` — the graphs a conversation may EXTERN into; supplied by the caller, never loaded by the walker |
| **View** | `DialoguePresenter` — panel, choices, Continue/End; hooks `onNodeShown`, `shouldDeferAdvance` |
| **Scene** | Maps presentation cues (`onLeaveCue` → cinematics), plays resolved `voiceAssetName` on show, presents graphs by facade |

Facades (`EmptyCoatCaseIntroduction`, `OfficeCaseFileMonologue`, `OfficeHotspotDialogue`) load cached graphs; they do not embed prose constructors.

#### Dialogue resource schema (v1)

**Single graph** (`*.dialogue.json`):

- `schemaVersion` (currently `1`), `id`, `startNodeID`, `nodes[]`
- Optional document-level `stringTable` resource override (default `strings.en`)
- Optional `entryNodeIDs[]` — ordered entry candidates, scanned first-true (IE `FindFirstState`). Absent means `[startNodeID]`, which is how every graph behaved before re-talk existed.
- Node fields: `id`, `speaker` **or** `speakerKey`, `text` **or** `textKey`, `portraitName`, `choices`, `nextNodeID`, `endsDialogue`, `isInteriorMonologue`, optional `voiceKey` (string-table voice resref), legacy `voiceAssetName` (deprecated inline filename), `onLeaveCue`, `onShowCue`, `entryWhen`
- `entryWhen` is the IE **state trigger**: it gates whether this node may *open* the conversation, and is ignored once the conversation is walking. The start node must not carry one — the entry fallback returns it unconditionally, so a gate there would silently never run, and the loader rejects it.
- **Voice (BGEE-style):** prose keys end in `.text`; optional companion keys end in `.voice` and hold a media **resref** (no extension). Loader resolves resref → playable `voiceAssetName` (default `.m4a`). Prefer companions over graph-inline filenames.
- Choice fields: `text` **or** `textKey`, `destinationID`, optional `destinationGraphID` (IE **EXTERN** — choices only, as in DLG), `tone`, `intention` (GDD §7.5: `open` / `press` / `feign` / `trade` / `observe` / `leave`), `conditions`, `gateDisclosure`, `onSelect`
- Conditions: tagged unions. Leaves are `hasFlag` / `hasEvidence` / `hasKnowledge`, the integer comparisons `counterAtLeast` / `counterAtMost` / `counterEquals` (IE `GlobalGT` / `GlobalLT` / `Global`), and `timesTalkedTo` (IE `NumTimesTalkedTo`, sugar over the reserved `talk.<ownerID>` counter). Composites are `not` (IE `!`) and `any` (IE `OR(n)`), plus `all` for nesting an AND inside an `any`. A choice's top-level `conditions` array is still ANDed. Nesting is capped at depth 8.
- Actions: tagged unions — `setCaseFlag` / `clearCaseFlag` / `setConversationFlag` / `clearConversationFlag`, `grantKnowledge` / `grantEvidence`, `setCounter` (IE `SetGlobal`) / `addToCounter` (IE `IncrementGlobal`), and `queueJournal`, which may use `textKey` and takes a typed `kind` (`chronology` / `lead` / `note` / `quest` / `questDone` — the IE DLG journal bits 6/7/8). Unknown kinds decode as `note`.

**Schema policy:** every field added since v1 is additive and optional, so all shipped resources stay at `schemaVersion: 1` and load byte-identically. New condition/action cases break *forward* compatibility (an old binary reading a new file), not backward — and there is exactly one binary. Do not bump.

**Catalog** (`*.dialogue-catalog.json`): `schemaVersion`, `graphs[]` (each entry is id + start + optional `entryNodeIDs` + nodes), optional `stringTable`. Duplicate graph ids and duplicate node ids are rejected at load rather than silently shadowing each other.

**String table** (`strings.en.json`): `schemaVersion`, `locale`, `strings` map (key → prose). IE TLK analogue without binary formats.

Unknown schema versions fail at load. Missing required string keys fail at resolve. Missing hotspot inspect graphs fail-fast in debug via facade `preconditionFailure`.

#### Dialogue graph authoring (classic BG roles)

Shipped conversation data follows **classic Baldur’s Gate / Infinity Engine DLG** roles (GDD §7.5):

- **Node body** = actor speech (NPC or case-title end). Multi-page NPC beats use `nextNodeID` + Continue.
- **Choice text** = player character speech. Mid-conversation PC lines must be choices, not Voss speaker nodes with empty choices and `nextNodeID`.
- **Exception:** `isInteriorMonologue` Continue chains before the NPC exchange (Empty Coat `voss.monologue.*` only for that pattern today).
- **Presentation vs game state:** VO and cinematics use node presentation fields / scene cue maps; case flags and journal writes use `DialogueAction` on choices.

Do not “simplify” PC acceptance or commitments into auto-Continue speaker states. See Dialogue System Roadmap frozen section and Empty Coat resource packages.

### 14.2 Area definition schema

`office_suite.area.json` includes:

- schema version and area ID;
- art-space size, plate texture, camera clamp, and environment scale;
- prop instances with texture, position, anchor, depth behavior, and state variants;
- information/travel regions with exact approach points;
- optional registered door visuals (position, anchor, scale, and
  closed/mid/open/hover textures) beside independent door obstacles;
- static obstacles and wall/cover polygons;
- actors, ambients, containers, and ground piles.

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

- `ie_projection` / layout-planner cell round-trip within tolerance on the active diamond, and every module follows `ACTIVE` (`qa_ie_projection.py`).
- depth keys order near objects in front of far objects and honor bias.
- pathfinding routes around the desk, takes any-angle shortcuts when line of sight is clear, forbids corner cutting, respects actor footprint clearance through thin gaps, and rejects unreachable destinations while distinguishing them from “already there”.
- actor occupancy blocks on unbumpable actors, offers a sidestep for idle bumpable ones, and backs off under repeated congestion.
- door cells stamp and clear in place without rebuilding the navigation map.
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
- a placeholder actor starts seated, stands, walks a pathfinder route, and changes 16-facing animation state from nine source orientations;
- depth ordering is correct around at least three split occluders;
- touch and mouse produce the same `InteractionCommand` for the same hotspot;
- all scene placement comes from decoded definitions;
- no SceneKit or runtime 3D dependency appears in either target.

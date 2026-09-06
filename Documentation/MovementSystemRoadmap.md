# Movement system roadmap

- Status: Phases 0–2 complete; Phase 3 locomotion shipped via the pathfinding rewrite; P3 control surface and P4–P6 not scheduled
- Version: 0.4
- Date: 11 August 2026
- Related: GDD §8 (Controls), Technical Architecture §10–12 (actors, navigation, input), [Pathfinding and NPC locomotion](PathfindingSystem.md) (shipped navigation stack and NPC authoring rules), Dialogue System Roadmap (pause / modal interaction patterns)

## Purpose

Close the highest-value gaps between RainShadow’s current single-actor office locomotion and classic **Baldur’s Gate / Infinity Engine** real-time movement: point-and-click walk orders, pause/stop/cancel, portrait-ordered formations, constant map speed with optional modifiers, and eventual multi-character pathing—without importing full IE pathfinding quirks or AD&D tabletop scale rules.

This document does **not** propose dual “classic vs modern” control schemes. Target is the **standard Infinity Engine point-and-click model retained in BG:EE**, adapted to RainShadow’s GDD, SpriteKit runtime, and investigation focus.

## Design target (classic BG:EE movement, condensed)

| Concern | Classic Infinity Engine / BG:EE | RainShadow target (this roadmap) |
|---|---|---|
| Move order | Left-click valid terrain → selected character(s) walk | Same: tap/click walkable cell → actor route |
| Selection | Box-drag, Shift/Ctrl, portraits, Select All | Single detective first; multi-select when companions exist |
| Pause | Space / clock; queue orders while paused | World pause + queue routes/actions; auto-pause options later |
| Stop / cancel | Multi-char Stop; R-click cancels attacks/spells | Explicit stop + cancel current route (and later actions) |
| Formations | ~12 presets; 5 quick slots; portrait order fills slots | Portrait-order slots when party size > 1; small preset set |
| Facing at dest | R-hold-drag rotates formation before advance | Optional destination facing for groups; single actor uses path facing |
| Regroup | Reissue group move under a formation | Same—no continuous auto-follow reform AI required early |
| Speed | `walkScale = 1500 / IE_MOVEMENTRATE`; step of `STEP_RADIUS × StepTime / walkScale` per 15 Hz tick, y scaled 0.75 | Same derivation, expressed scale-free — see "Movement model" below |
| Encumbrance | Str weight: 100–120% half speed; >120% immobile | Optional later; strength/inventory only if RPG weight ships |
| Fatigue | Long-term continuous-play exhaustion | Out of scope until rest/day systems exist |
| Time scale | 6 s personal rounds; same compression for combat & world | Investigation pacing first; combat round scale when combat ships |
| Pathfinding | Per-character any-angle search over a raster search map; weak multi-agent IE behavior | Same stack, shipped: Lazy Theta\* over a search map with actor stamping and bumping (see [Pathfinding and NPC locomotion](PathfindingSystem.md)); formations only when party moves |

**Explicitly out of scope for early phases:** full IE multi-agent doorway stacking fidelity, gamepad-only classic mappings, race/armor-scaled tabletop rates, outdoor yards vs indoor feet, continuous auto-reform while walking, free-form scripted movement AI.

### Research notes (source basis)

Findings derive from BG/BGII manuals, Beamdog EE guides (Amn Survival Guide, Mastering Melee & Magic), BG wiki secondary notes on formations/encumbrance, and RainShadow’s own navigation code/docs. Uncertainties that remain open for implementation:

- ~~Exact default facing when only left-clicking a group (no R-drag) is under-documented in manuals.~~ **Closed from source.** `GameControl::OnMouseUp` calls `InitFormation(p, false)` on a plain left-click, which sets `formationBaseAngle = AngleFromPoints(clickPoint, leaderPos)` — the formation orients along the direction of travel. The comment above it says so outright: "Ensure that left-click movement also orients the formation in the direction of movement."
- Automatic mid-path re-formation when pathfinding splits the party is **not** a named IE feature—community practice is manual regroup.
- ~~Exact 100%/120% encumbrance thresholds are secondary (wiki), not printed in manuals checked.~~ **Closed from the shipped manual.** *Adventurer's Guide* p. 43: over the weight allowed by Strength "their movement speed is halved"; "Carrying more than 10% more than a character's allowed weight prevents them from moving altogether." So the bands are 100% and 110%, not 120%. `MovementProfile.Encumbrance` uses those.
- **Right-click does not cancel movement.** The manual lists R-click as cancelling "attacks or spellcasting", and GemRB's right-click path only clears `targetMode` and resets the action bar. This settles the conflict between GDD §8.1's "Escape/two-finger tap: cancel current path" and frozen rule 14 in favour of rule 14 — the code was already right and the GDD text was wrong. GDD §8.1 has been corrected.
- Heuristic doc/code mismatch from early drafts was resolved in Phase 0 and then superseded by the pathfinding rewrite: the shipped search uses a weighted Euclidean heuristic (weight 1.5) with cross-product tie-breaking, matching GemRB's `Map::FindPath`. Technical Architecture §11.3 and `PathFinder` agree.

---

## Movement model (derived from the engine, not tuned by eye)

Every constant below comes from GemRB `master`, the maintained open-source
reimplementation of the engine BG:EE runs on. Read the code, not forum lore:

| Quantity | Value | GemRB source |
|---|---|---|
| Logic tick rate | **15 Hz** | `core/Interface.h`, `defaultTicksPerSec` |
| `StepTime` | **566** (BG2 default, from the game INI) | `core/Interface.cpp` |
| `IE_MOVEMENTRATE`, ordinary humanoid | **9** | `core/Scriptable/Actor.cpp` |
| `walkScale` | `1500 / rate` = **166.67** | `Actor::CalculateSpeedFromRate` |
| `STEP_RADIUS` | **2.0** | `Map::NormalizeDeltas`, `core/PathFinder.cpp` |
| Vertical step scale | **0.75** (= 12/16, the search-cell aspect) | `Map::NormalizeDeltas` |
| Orientations | **16**, nine authored + seven mirrored | `core/Orientation.h`, `SixteenToNine` |
| Turn rate when standing | **one bin per tick**, shorter arc | `GetNextFace` |
| `move_scale` / `ellipse` / `personal_space` | **9 / 16 / 3** | BG:EE `CHAAnim.bif`, every character animation INI (e.g. `6100.ini`) |
| Per-creature rate band | **5–10** | BG:EE `EXTSPEED.2da`; no character animation appears, so PCs take the default 9 |
| Actor stamp radius | `personal_space − 1` cells | `TileProps::PaintSearchMap` |
| Actor clearance radius | `personal_space − 2` cells | `Map::GetBlockedInRadiusTile` |
| Path search nodes | **32 000** | `Baldur.lua` `Path Search Nodes` |
| Script / idle stride | **16 ticks**, staggered per actor | `Scriptable::ProcessActions` (`Ticks % 16 != globalID % 16`) |
| Idle head-turn odds | **1 in 25** per script pass (≈ every 27 s) | `Actor::IdleActions` (`RAND(0, 24)`) |
| Footstep gate | previous **clip length**, not a contact frame | `Actor::PlayWalkSound` (`nextWalkSound = now + length`) |
| Bark ladder | 1 never / 2 once per selection / 3 50% / 4 80% / 5 always, + ~5% rare | `Actor::CommandActor`, `Actor::PlaySelectionSound` |
| Cursor | read straight off the search map, then object/actor overrides, `IE_CURSOR_GRAY` for "not now" | `Map::GetCursor`, `GameControl::UpdateCursor` |

Shipped BG:EE option defaults, read from a live `Baldur.lua`: `Footsteps = 1`,
`Command Sounds Frequency = 2`, `Selection Sounds Frequency = 3`,
`Greyscale On Pause = 1`, `Bored Timeout = 3000`, `Maximum Frame Rate = 30`,
`Mouse/Keyboard Scroll Speed = 40`, `Terrain Hugging = 0` (undocumented; not
replicated).

`StepTime` is per game in GemRB — `bg1 = 425`, `bgee/bg2/bg2ee = 566`,
`iwd = 637`, `pst = 472` — so targeting BG:EE means a gait about a third quicker
than original BG1. That is intended.

Per tick the engine walks `STEP_RADIUS × (StepTime / walkScale)` = 6.79 px
horizontally and 5.09 px vertically — 101.9 and 76.4 px/s. Against BG1's ~50-row
standing adult that is **2.04 body-heights/second**, which is how
`ActorLocomotionPacing` expresses it so the pace survives any sprite rebake.

Three consequences worth stating plainly:

1. **Movement and animation share the tick.** One tick is one step *and* one
   authored frame, so the walk cycle cannot drift against distance travelled.
   `LogicTickClock` drains wall-clock delta in whole ticks; there is no separate
   animation accumulator. (This also means a speed modifier such as Haste would
   foot-slide — as it genuinely does in BG.)
2. **Vertical travel is slower on screen.** Travel is metered in a projected
   metric, `hypot(dx, dy / 0.75)`. Anything comparing route lengths must use
   `ActorLocomotionPacing.projectedDistance`, or it is mixing currencies.
3. **Positions are integral, as BG's are.** `NormalizeDeltas` ceils each axis to
   a whole unit per tick and `PathFinder.normalizeDeltas` reproduces it, so the
   stride is 7 units east-west and 6 north-south. An earlier draft of this
   document called float positions "the one deliberate divergence in the step
   model"; the literal port removed it, and the quantisation is load-bearing —
   arrival is an exact `position == node.point` test, which only holds because
   every step lands on a whole unit. The *effective* vertical ratio a player sees
   is therefore 6/7, not the 0.75 the function multiplies by.

---

## Current baseline

| Piece | Status |
|---|---|
| Raster search map with BG-style flag bits; radius/line queries | **Shipped** (`SearchMap`) |
| Lazy Theta\* any-angle search; no diagonal corner cutting | **Shipped** (`PathFinder`) |
| Weighted heuristic (1.5) + cross-product tie-break; node budget 32 000 | **Shipped** |
| Any-angle path emitted by the search (no separate string-pull pass) | **Shipped** |
| Footprint clearance tested against obstacle geometry; boundary as solid | **Shipped** |
| Office dimetric search map + authored furniture/door/wall AABBs | **Shipped** (`OfficeNavigationLayout`) |
| Blocked floor click issues **no order** (BG refuses rather than snapping); blocked hover cursor | **Shipped** — floor clicks use `path`, not `route`; `route`'s bounded fallback remains for scripted/approach use only |
| Fixed 15 Hz logic tick shared by root motion and the walk cycle | **Shipped** (`LogicTickClock`) |
| Perspective-foreshortened step: vertical travel at 0.75× horizontal | **Shipped** (`ActorLocomotionPacing.projectedDistance`) |
| Waypoint following (`Movable::DoStep`, one quantised step per tick) | **Shipped** |
| New input **replaces** route (not append) for single actor | **Shipped** (plain click / tap) |
| Cancel route — **Escape only**; right-click / two-finger clear targeting instead | **Shipped** (`handleCancelInput` vs `handleClearTargetingInput`) |
| Gradual turn-in-place while standing (one 22.5° bin per tick); snap while walking | **Shipped** (`ActorFacing.stepped(toward:)`, `pendingFacing`) |
| Same-cell click = head turn, not a zero-length walk | **Shipped** (`turnToFace`) |
| Dialogue participants turn toward each other gradually | **Shipped** (office scene, on entrance completion) |
| Two-tier search: plan around actors first, through them only if needed | **Shipped** (`pathAvoidingActors` → `path`) |
| Collision probe **ahead along the path**, not around the mover | **Shipped** (`detectiveCollisionProbe`) |
| Randomised backoff wait when a blocker cannot be bumped | **Shipped** (`beginMovementBackoff`) |
| Abandon rather than shove when already near the goal | **Shipped** (`bumpAbandonDistance`) |
| Move-order ground feedback (`ui_move_marker_*` / blocked) | **Shipped** (painted 8-frame loop; coded ellipse fallback) |
| BG:EE waypoint queue — Shift+click (macOS) / long-press (iOS) via `appendRoute` | **Shipped** (`queuedMovementGoals` + `ui_waypoint_pip`); audited against `Movable::AddWayPoint`, see [Pathfinding](PathfindingSystem.md) for the rule list |
| Ground marker on every queued goal **and** the destination (`DrawTargetReticles`) | **Shipped** |
| Actor occupancy stamping (PC/NPC bits) for every floor actor | **Shipped** (`ActorOccupancy`) |
| Bumpable idle actors: sidestep-and-return on contact | **Shipped** |
| Replan budget — abandon the goal after N consecutive failed searches | **Shipped** (`recordCongestion` / `maxCongestionRetries` = 8, mirroring `Actor::NewPath`'s `MAX_PATH_TRIES`; reset on every new order as `WalkTo` resets `pathTries`) |
| Free/scrollable viewport: follow ⇄ free, edge scroll, middle-drag (two-finger on iOS), held arrow/WASD scroll | **Shipped** (`BaseGameScene.CameraMode`) |
| BG:EE zoom: 27 integer steps of 5 percentage points, default 100% (`20 + zoomLevel * 5`), wheel / `-` `=` / trackpad and touch pinch, `Zoom Lock` | **Shipped** (`CameraZoom`, `BaseGameScene.setZoomStep`). The whole 1…27 band in every area, indoor and outdoor alike |
| `MoveViewportTo`'s clamp: ±64 units of x overflow, a 50-unit far-edge y pad, the map centred once the viewport outgrows it | **Shipped** (`AreaViewport.clampedCenter`). Replaced a `fitStep` that narrowed the band per plate and per aspect — which left the office unable to zoom out at all at 16:9 and starting *below* 100% at 21:9 |
| Middle-click resets zoom to 100% when the press did not pan | **Shipped** (`BaseGameScene.otherMouseUp` → `resetZoom`). macOS only; iOS's two-finger tap is already the clear-targeting gesture |
| Double-click recentres the viewport on the click (`MoveViewportTo(p, true)`) | **Shipped** |
| Double-click a portrait to re-attach the viewport to the actor | **Shipped** |
| Detective rises to meet the client instead of interviewing from his chair | **Shipped** (empty-route seat egress during her walk-in) |
| Corrective repath while walking (0.75 s, "Enhanced Path Search") | **Shipped** |
| Door open/close stamps cells in place, no map rebuild | **Shipped** (`setEntranceDoorBlocking`) |
| Client NPC (Lila) on pathfinder + `Movable`, not `SKAction` | **Shipped** |
| Actor state machine (seated → stand → walk → sit) | **Shipped** |
| Projected-world speed so diagonals are not faster on screen | **Shipped** |
| 16-bin facing from velocity; 9 sources + mirror | **Shipped** |
| Click/tap → hotspot vs walk resolution | **Shipped** |
| World pause during modal dialogue / overlays | **Shipped** (`WorldPauseController`; `syncWorldNodePause` replaced three duplicated root lists that each passed only their own overlay's flag) |
| Player-driven tactical pause (queue moves while paused) | **Shipped** — Space (after modal first refusal) and the HUD clock, which is what BG:EE's clock is. Orders issued while frozen wait intact and walk on resume; the tick clock resets so a stale remainder cannot spend a step |
| Group stop / cancel route affordance (UI + input) | **Partial** — cancel shipped; dedicated IE Stop UI is P1 |
| Multi-select, party portraits as formation order | **UI chrome only** (party rail assets); no multi-actor runtime |
| Formations / destination facing drag | **Not shipped** |
| Anisotropic agent footprint (BG stamps `circleSize` in cell space = a 16:12 ellipse) | **Shipped for actor-vs-actor**, with BG's paint(`size−1`)/test(`size−2`) asymmetry, so a body can hug a wall but not another body. Static clearance still collapses half-extents with `max()`; see [Pathfinding](PathfindingSystem.md) |
| Per-creature movement rate (`IE_MOVEMENTRATE` / `moverate.2da`) | **Shipped** (`MovementProfile.moveScale`, humanoid 9, engine band 5–10). Both actors ship at 9, pinned to the previous `walkSpeed` so the change is provably inert |
| Encumbrance / Haste-style speed modifiers | **Shipped as inert data** (`MovementProfile.Encumbrance`, `hastened()`); nothing constructs anything but `.unencumbered` until inventory weight exists |
| Footsteps on BG's clip-length gate, terrain-set per scene, silent while paused / in dialogue | **Shipped** (`FootstepCadence`, `GameSFX`, `FootstepSurface`) |
| Order-acknowledgement and selection barks on BG's frequency ladder | **Shipped** (`BarkGate`, `MovementBarkPlayer`); only *accepted* orders acknowledge. Clips are Grok Voice Sal noir tropes from `generate_voss_barks_rex.py`, not macOS `say` |
| Idle head-turn on BG's 16-tick / 1-in-25 schedule (a glance ≈ every 27 s) | **Shipped** (`IdleBehaviourClock`) |
| Hover cursor read straight off the search map, with a travel state and BG's grey modifier | **Shipped** (`WorldCursor`); replaced two disagreeing per-scene `NSCursor` ladders |
| Greyscale on pause (`Greyscale On Pause = 1`) | **Not shipped** — the world roots are separate scene children, so an `SKEffectNode` wrap would rasterise the whole ≈2400×1400 unit plate (~13M px at 2× backing). The cheap path is a screen-sized snapshot taken at pause time and re-taken if the camera scrolls |
| Fatigue / rest-linked movement | **Not shipped** |

The pathfinding rewrite moved multi-actor *locomotion* forward of its original P3 slot: the detective and the client both path through the same stack, occupy the same search map, and resolve contact by bumping. What remains deferred is multi-actor *control* — selection sets, formations, portrait order, combat spacing, and party AI.

---

## Priority order

| Priority | Gap | Why this order |
|---|---|---|
| **P0** | Single-actor classic feel (stop, cancel, pause queue, path polish) | Unlocks IE-like control with zero party systems |
| **P1** | Input & selection model (pointer kinds, cancel vs move, HUD stop) | Shared event surface for later multi-select |
| **P2** | Speed model (base rate, modifiers, optional encumbrance hooks) | Data spine before combat/items change walk rate |
| **P3** | Multi-actor locomotion + independent search | **Locomotion shipped** with the pathfinding rewrite; selection/control remains |
| **P4** | Formations + portrait order + destination facing | Classic party identity once ≥2 selectable actors exist |
| **P5** | Party pathing polish (chokepoints, regroup, optional append routes) | Comfort and IE familiarity; not required for first companion beat |
| **P6** | Combat-time movement (initiative scale, engagement) | Only when combat ships |

P0 before multi-actor: one reliable IE-feeling detective walk is the M01 promise. Formations after multi-actor: empty formation UI is noise. Combat last: investigation pacing must not wait on round timers.

---

## Phase 0 — Single-actor classic feel

**Goal:** Detective walk feels like classic point-and-click IE locomotion: constant speed, replace-on-click, safe interrupt, predictable fallback.

### Ship

- Technical Architecture §11.3 and the pathfinder agree on the heuristic metric (originally projected Euclidean between cell centers; now the weighted Euclidean of `PathFinder` after the search-map rewrite)
- Explicit **cancel route**: Escape / right-click / two-finger → `cancelMovement()`; cancel also clears the live move-order feedback ring
- Mid-segment **retarget** via `replaceRoute` from the live interpolated position (pure tests cover cancel mid-route, replace discarding old tail, replace-after-cancel, zero-speed hold)
- Click-destination feedback: painted `ui_move_marker_*` / blocked converging loop (coded teal/red ellipse fallback if art missing)

### Exit criteria

- Unit tests: cancel clears waypoints; replace mid-route does not overshoot; unreachable taps fail or fall back within ring
- Manual: tap walk, retarget, cancel, stand-from-chair walk all feel deterministic on office map

**Status: met** (painted move markers + BG:EE waypoint queue shipped).

### Rationale

BG:EE movement is readable because speed and path ownership are simple. Polish here pays off for every later phase.

---

## Phase 1 — Input, pause queue, stop

**Goal:** Match classic tactical control: pause the world, issue orders, unpause; stop current action; cancel without a new move.

### Ship

- Player **tactical pause** (keyboard Space and/or HUD clock control) independent of dialogue modal pause
- While paused: accept move (and later action) orders; apply on unpause
- **Stop** command: clear route (and later pending actions) for selected actor(s)
- Normalize cancel vs move in `GameInputEvent` / `InputRouter` so platform code does not special-case SpriteKit
- Auto-pause hooks (on trap, on dialogue, on combat start)—stubs or settings flags only until those systems exist

### Exit criteria

- Unit or scene tests: pause freezes locomotion clocks; orders issued while paused execute only after unpause
- Stop mid-walk leaves actor in standingIdle at current cell
- iPad and macOS both expose cancel and stop without relying on mouse-only chords alone

### Rationale

Manuals emphasize pause + queued orders as the primary tactical layer. Without it, later combat and traps feel arcade rather than IE.

---

## Phase 2 — Speed model

**Goal:** One base constant map speed in projected world units, with a clean modifier stack for future Haste/gear/encumbrance.

### Ship

- `MovementProfile` (or equivalent): base speed, optional multipliers, min/max clamps
- Single shared player rate for exploration (and later combat maps)—no race table rates
- Hook points only for:
  - status effect multiplier (e.g. Haste = ×2 when that status exists)
  - encumbrance bands: normal / 100–120% → ×0.5 / >120% → 0 (data-driven; inactive until inventory weight ships)
- Fatigue **not** required; document as later systems dependency

### Exit criteria

- Pure tests: modifiers compose; zero speed cancels progress without corrupting waypoints
- No gameplay dependency on AD&D outdoor yards vs dungeon feet

### Rationale

IE kept one readable rate rather than tabletop exploration/combat dual scales. RainShadow should do the same so inventory and status work never retune every scene.

---

## Phase 3 — Multi-actor locomotion

**Goal:** A second (then N) actor can path independently with the same `Movable` / search stack.

### Shipped ahead of schedule (pathfinding rewrite)

- Per-actor path requests through one shared `NavigationMap`; the detective and client both use it
- Other actors are modelled as **search-map occupancy** rather than static obstacles: idle friendly actors are bumpable and traversable during planning, moving actors are not
- Contact resolution is BG:EE bumping — the idle blocker sidesteps and returns — with a congestion counter so a blocked mover waits instead of repathing forever
- Corrective repathing so a mover benefits when a blocker clears
- Client NPC migrated off `SKAction` polylines onto the pathfinder; `ClientActorNode` is the template for future NPCs (see [Pathfinding and NPC locomotion](PathfindingSystem.md), "How NPCs are written from here on")

### Still to ship

- Multiple `ActorController` (or shared controller + per-actor state) instances for *player-controlled* actors
- Selection set: who receives the next move order (default: player-controlled detective)
- Portrait bar (or existing party rail) selects active member; no formation required yet

### Exit criteria

- Two actors can each receive sequential move orders without shared route corruption — **met for scripted/reactive NPC movement; not yet exercised by player selection**
- Depth sort, facing, and footstep events remain correct per actor — **met**
- Companion can be ordered to a hotspot approach point for future dialogue staging — **available via `NavigationMap.route`; no ordering UI yet**

### Rationale

Classic IE is multi-select real-time, but the first companion beat only needs “send X there.” The rewrite delivered the locomotion and avoidance half because a second walking body (the client) needed it; what is left is control surface, and formations without a selectable second body are still pure UI cost.

---

## Phase 4 — Formations, portrait order, destination facing

**Goal:** When more than one member is selected, group move places them into a preset relative to the destination, filled by portrait order.

### Ship

- Portrait order = formation slot order (top portrait = slot #1 / leader marker when selected)
- Small preset library (start with 3–5: line, wedge, column, protect-caster, tight clump)—expand toward IE’s ~12 only if needed
- Quick-formation slots in HUD when multi-select is active
- Group left-click: compute destination anchors from active preset + optional facing
- Destination facing control: right-click–hold–drag (macOS) / long-press–drag (touch) at target before commit
- Reorder portraits reassigns slots across all presets
- **Regroup** = reissue group move under current preset (no continuous auto-follow)

### Exit criteria

- Selecting 2–6 members and clicking terrain yields stable slot placement without crossing permanently when open space allows
- Leader marker follows portrait rules when full-party leader is not selected
- Unit tests for slot assignment pure functions (order × preset × facing → offsets)

### Rationale

This is the signature IE party identity. RainShadow only pays for it once companions are real.

---

## Phase 5 — Party pathing polish

**Goal:** Reduce babysitting at doors and furniture without chasing full IE multi-agent research.

### Ship

- ~~Waypoint queue wired~~ **Shipped** (now `Movable::AddWayPoint`, marked inside the path) (Shift+click / long-press; plain click still replaces)
- Narrow-gap behavior: followers wait or repath when leader occupies choke cell (the primitive exists — occupancy congestion back-off; what is missing is party-level policy)
- Optional “gather to leader” command (one-shot regroup at leader position)
- Fail soft: if a slot is blocked, claim nearest free cell rather than cancel whole party move
- Debug overlays for multi-agent paths (dev only)

### Exit criteria

- Doorway test scene or office door: full party can pass without permanent soft-lock
- Documented known limits (no claim of perfect IE parity)

### Rationale

Community IE pain is multi-agent pathing. RainShadow should be **better where cheap**, not recreate classic stacking bugs on purpose.

---

## Phase 6 — Combat-time movement (deferred)

**Goal:** When combat exists, reuse the same locomotion with engagement rules and optional 6-second personal timing—without a separate “combat only” walker.

### Ship (sketch only)

- Same base speed on combat maps unless a status says otherwise
- Personal initiative / round compression only if combat systems need it for spells and attacks
- Opportunity / engagement rules TBD in a combat roadmap—not here
- Auto-pause options for enemy sighted, spell cast, character injured, etc.

### Exit criteria

- Defined when combat design is scheduled; not blocking investigation milestones

---

## Frozen rules (do not regress)

1. **Point-and-click owns movement.** WASD and the arrow keys pan the viewport and never move the actor (GDD §8.3). They were wired to synthesised move orders until the free-camera work; if an overlay is open it consumes them, otherwise they scroll.
2. **Replace route by default** for the primary click-to-move path; append is opt-in later.
3. **One base player map speed** for exploration; no hidden race/armor dual scales.
4. **Portrait order drives formation slots** when formations exist—not free-form drag-to-slot unless design revisits.
5. **No continuous auto-follow reform** as the primary party AI; regroup is reissue formation move.
6. **Single-agent correctness first**—multi-agent must not break detective-only office navigation tests.
7. **All floor-bound movement goes through `NavigationMap`.** No `SKAction` locomotion chains and no authored polyline consumed directly as a path; authored anchors are input to `waypoints(visiting:)`. See [Pathfinding and NPC locomotion](PathfindingSystem.md).
8. **Every floor-occupying actor registers with `ActorOccupancy`** while visible, and unregisters when hidden.
9. **Idle NPCs are bumpable, moving NPCs are not.** A body that must be immovable is authored as a static obstacle, never as an unbumpable actor.
10. **Dynamic geometry stamps in place.** Doors and equivalents toggle search-map cells; nothing rebuilds a navigation map to change one obstacle.
11. **Root motion and the walk cycle advance on the same logic tick.** Never reintroduce a separate animation timer — the shared tick is what keeps feet on the ground.
12. **Travel is measured in the projected metric.** Any code comparing path lengths or deriving durations uses `ActorLocomotionPacing.projectedDistance`, never raw `hypot`.
13. **A refused order is refused.** A floor click on unreachable ground shows the blocked marker and issues nothing; it is never silently redirected to a nearby tile. `NavigationMap.route`'s fallback is for scripted and approach moves only.
14. **Escape is the only Stop.** Right-click and two-finger tap clear targeting state; they must not cancel an active route.
15. **Actor occupancy is painted wider than it is tested.** Paint `personalSpace − 1` cells, test `personalSpace − 2`, both in cell space. Collapsing them back to one radius is what made walls and bodies feel the same. Static clearance stays on the world-unit profile.
16. **Occupancy membership is a disjointness test.** `SearchMapFlags.actor` is a two-bit mask; `contains` on it asks whether a cell holds a player *and* an NPC and is therefore always false. Use `SearchMap.containsActor`.
17. **Only accepted orders acknowledge.** A bark above the refusal guard makes a blocked click sound like a success.
18. **Footsteps are gated on clip length, floored by the stride.** Not on animation contact frames. See `FootstepCadence`.
19. **Hover and the order decision read the same search-map sample.** If they diverge, the cursor starts lying about what a click will do.
20. **The viewport is the player's.** Any manual scroll detaches the camera to `free` and it stays there until the player re-attaches (portrait double-click). Nothing may silently re-tether it to the actor — that is what made BG's double-click recentre meaningless here before.
21. **The viewport clamp is `MoveViewportTo`, void included.** `AreaViewport.clampedCenter` is the only place a camera position is bounded, and black past the area edge is Infinity Engine framing rather than a defect: once the viewport outgrows the area the engine centres the map and lets it show. Three things in it look wrong and are the engine — the x overflow is ±64 while y pads one side only, the y pad is on the *far* edge (world `minY`, engine-bottom) with the near edge flush, and the over-large centring carries the same pad so it lands on `map.midY - 50`, not on a true centre. That pad moved the office's default framing 50 units when it landed, and was kept deliberately. Do not square the axes up; do not reintroduce a per-plate zoom ceiling.
22. **Zoom is not a scroll.** Changing the step leaves `CameraMode` alone — zooming while following keeps following. It is suppressed outright while a cutscene owns the camera, and authored `cameraScale` cues multiply `baseCameraScale` (the 100% scale), so a player's zoom can never shift authored framing.

---

## Divergences introduced by this work

Deliberate, and each one is the direction that fails safe:

| | Engine | Here | Why |
|---|---|---|---|
| Footstep cadence | clip length alone | clip length, floored by the stride | BG's walk sounds were authored long enough to pace themselves; ours are not guaranteed to be, and a tight 0.1s sample fires six times a second. The gate is only sampled on logic ticks, and the stride is exactly four of them — so the shipped clips are 0.26s, under the stride, or footsteps drift 25% slow |
| Bark frequency | `Command Sounds Frequency = 2` (once per selection) | `.half`, and "selection" means re-acquiring the actor | Level 2 works for a six-portrait party where selection changes constantly. With one always-selected detective a literal port barks once per session |
| Idle head-turn | dedicated `IE_ANI_HEAD_TURN` stance | one bin out, hold, one bin back, using the gradual standing turn | No authored head-turn frames exist. The borrowed motion reads as looking around rather than as a new heading |
| Travel cursor | painted directional arrow | `NSCursor.dragLink` | The system set has no travel arrow. A painted cursor is art, not code |

## Suggested implementation map

| Phase | Primary code / docs homes |
|---|---|
| P0 | `SearchMap.swift`, `PathFinder.swift`, `ActorLocomotion.swift`, `NavigationMapTests`, Technical Architecture §11.2–11.4 |
| P1 | `GameInputEvent` / `InputRouter`, scene pause helpers in `DetectiveOfficeScene`, HUD clock/stop controls |
| P2 | New pure `MovementProfile` (RainShadowCore), `walkScale` wired into `Movable.doStep` |
| P3 | `ActorOccupancy.swift`, `NavigationMap.swift` (shipped); actor controllers, selection set, companion spawn/scene ownership (remaining) |
| P4 | Formation presets (pure math), party rail reorder, multi-select input |
| P5 | Multi-agent costs / wait policies (single-actor `appendRoute` input binding shipped) |
| P6 | Future combat roadmap |

---

## Dependency notes

| Depends on | For |
|---|---|
| Inventory weight + Strength (or equivalent) | Encumbrance bands (P2 optional) |
| Status / effect system | Haste-like multipliers (P2) |
| Second playable/controllable actor + content | P3–P5 |
| Combat design | P6 |
| Trap / detect system | Auto-pause “walked into trap” fidelity |

Dialogue modal pause (shipped patterns in office) should **share vocabulary** with tactical pause (P1) so players do not learn two freeze metaphors.

---

## Acceptance summary (roadmap done)

The movement roadmap is complete when:

1. Single detective remains the gold standard for click-to-move, cancel, and pause-queue.
2. A multi-member selection can group-move into portrait-ordered formations with destination facing.
3. Speed is data-driven and modifier-ready without tabletop dual scales.
4. Party chokepoints are usable without mandatory micro from the player every doorway.
5. Combat can adopt the same walker later without a second locomotion stack.

Until companions and combat are scheduled, **Phases 0–1** are the only movement work that should compete with investigation content for engineering time.

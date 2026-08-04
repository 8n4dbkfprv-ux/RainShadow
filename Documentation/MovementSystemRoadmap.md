# Movement system roadmap

- Status: Phase 0 complete; P1+ not scheduled
- Version: 0.2
- Date: 4 August 2026
- Related: GDD §8 (Controls), Technical Architecture §10–12 (actors, navigation, input), Dialogue System Roadmap (pause / modal interaction patterns)

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
| Speed | One constant map rate (~60′ AD&D-equivalent); Haste / gear | One base projected-world speed; later modifiers (status, gear) |
| Encumbrance | Str weight: 100–120% half speed; >120% immobile | Optional later; strength/inventory only if RPG weight ships |
| Fatigue | Long-term continuous-play exhaustion | Out of scope until rest/day systems exist |
| Time scale | 6 s personal rounds; same compression for combat & world | Investigation pacing first; combat round scale when combat ships |
| Pathfinding | Per-character A*; weak multi-agent IE behavior | Single-agent A* (shipped); multi-agent only when party moves |

**Explicitly out of scope for early phases:** full IE multi-agent doorway stacking fidelity, gamepad-only classic mappings, race/armor-scaled tabletop rates, outdoor yards vs indoor feet, continuous auto-reform while walking, free-form scripted movement AI.

### Research notes (source basis)

Findings derive from BG/BGII manuals, Beamdog EE guides (Amn Survival Guide, Mastering Melee & Magic), BG wiki secondary notes on formations/encumbrance, and RainShadow’s own navigation code/docs. Uncertainties that remain open for implementation:

- Exact default facing when only left-clicking a group (no R-drag) is under-documented in manuals.
- Automatic mid-path re-formation when pathfinding splits the party is **not** a named IE feature—community practice is manual regroup.
- Exact 100%/120% encumbrance thresholds are secondary (wiki), not printed in manuals checked.
- Heuristic doc/code mismatch from early drafts is **resolved in Phase 0**: Technical Architecture §11.2 and `NavigationGrid.heuristic` both use projected Euclidean distance between cell centers.

---

## Current baseline

| Piece | Status |
|---|---|
| A* over eight-connected cells; no diagonal corner cutting | **Shipped** (`NavigationGrid`) |
| String-pull / path simplify only on fully walkable segments | **Shipped** |
| Footprint-expanded AABB obstacles; boundary as solid | **Shipped** |
| Office dimetric nav grid + authored furniture/door/wall AABBs | **Shipped** (`OfficeNavigationLayout`) |
| Unreachable tap → nearest cell in bounded Chebyshev ring | **Shipped** (+ tests) |
| Constant-speed waypoint following (`RouteFollower`) | **Shipped** |
| New input **replaces** route (not append) for single actor | **Shipped** |
| Cancel route (Escape / right-click / two-finger) without new destination | **Shipped** (`handleCancelInput` → `cancelMovement`) |
| Move-order ground feedback (procedural teal/red ellipse) | **Shipped**; sprite `ui_move_marker_*` deferred |
| A* heuristic = projected Euclidean (docs + code aligned) | **Shipped (P0)** |
| `appendRoute` stub for future party waypoint queuing | **Modeled only** |
| Single detective pathfinding; no dynamic multi-agent avoidance | **Shipped (M01)** |
| Actor state machine (seated → stand → walk → sit) | **Shipped** |
| Projected-world speed so diagonals are not faster on screen | **Shipped** |
| 16-bin facing from velocity; 9 sources + mirror | **Shipped** |
| Click/tap → hotspot vs walk resolution | **Shipped** |
| World pause during modal dialogue / overlays | **Partial** (scene-level `isPaused` on roots) |
| Player-driven tactical pause (queue moves while paused) | **Not shipped** (P1) |
| Group stop / cancel route affordance (UI + input) | **Partial** — cancel shipped; dedicated IE Stop UI is P1 |
| Multi-select, party portraits as formation order | **UI chrome only** (party rail assets); no multi-actor runtime |
| Formations / destination facing drag | **Not shipped** |
| Encumbrance / Haste-style speed modifiers | **Not shipped** |
| Fatigue / rest-linked movement | **Not shipped** |

M01 intentionally paths only the detective. Companions, combat spacing, and party AI are deferred until multi-actor scenes exist.

---

## Priority order

| Priority | Gap | Why this order |
|---|---|---|
| **P0** | Single-actor classic feel (stop, cancel, pause queue, path polish) | Unlocks IE-like control with zero party systems |
| **P1** | Input & selection model (pointer kinds, cancel vs move, HUD stop) | Shared event surface for later multi-select |
| **P2** | Speed model (base rate, modifiers, optional encumbrance hooks) | Data spine before combat/items change walk rate |
| **P3** | Multi-actor locomotion + independent A* | Second walker without formations yet |
| **P4** | Formations + portrait order + destination facing | Classic party identity once ≥2 selectable actors exist |
| **P5** | Party pathing polish (chokepoints, regroup, optional append routes) | Comfort and IE familiarity; not required for first companion beat |
| **P6** | Combat-time movement (initiative scale, engagement) | Only when combat ships |

P0 before multi-actor: one reliable IE-feeling detective walk is the M01 promise. Formations after multi-actor: empty formation UI is noise. Combat last: investigation pacing must not wait on round timers.

---

## Phase 0 — Single-actor classic feel

**Goal:** Detective walk feels like classic point-and-click IE locomotion: constant speed, replace-on-click, safe interrupt, predictable fallback.

### Ship

- Technical Architecture §11.2 + `NavigationGrid.heuristic` both document/use **projected Euclidean** between cell centers (same metric as step cost)
- Explicit **cancel route**: Escape / right-click / two-finger → `cancelMovement()`; cancel also clears the live move-order feedback ring
- Mid-segment **retarget** via `replaceRoute` from the live interpolated position (pure tests cover cancel mid-route, replace discarding old tail, replace-after-cancel, zero-speed hold)
- Click-destination feedback: procedural teal (valid) / red (invalid) ellipse; authored `ui_move_marker_*` art remains optional later polish

### Exit criteria

- Unit tests: cancel clears waypoints; replace mid-route does not overshoot; unreachable taps fail or fall back within ring
- Manual: tap walk, retarget, cancel, stand-from-chair walk all feel deterministic on office map

**Status: met** (procedural marker; sprite move-marker art deferred).

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

**Goal:** A second (then N) actor can path independently with the same `RouteFollower` / A* stack.

### Ship

- Multiple `ActorController` (or shared controller + per-actor state) instances
- Selection set: who receives the next move order (default: player-controlled detective)
- Per-actor path requests; other actors are **static obstacles** first (simplest correct behavior)
- Optional: treat allies as soft costs later—not required for exit
- Portrait bar (or existing party rail) selects active member; no formation required yet

### Exit criteria

- Two actors can each receive sequential move orders without shared route corruption
- Depth sort, facing, and footstep events remain correct per actor
- Companion can be ordered to a hotspot approach cell for future dialogue staging

### Rationale

Classic IE is multi-select real-time, but the first companion beat only needs “send X there.” Formations without a second body are pure UI cost.

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

- `RouteFollower.appendRoute` wired for optional waypoint queue (IE-style queued clicks) behind an explicit input mode or modifier—not default if it fights replace-on-click muscle memory
- Narrow-gap behavior: followers wait or repath when leader occupies choke cell
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

1. **Point-and-click owns movement.** WASD must not become required actor locomotion (GDD §8: camera pan only).
2. **Replace route by default** for the primary click-to-move path; append is opt-in later.
3. **One base player map speed** for exploration; no hidden race/armor dual scales.
4. **Portrait order drives formation slots** when formations exist—not free-form drag-to-slot unless design revisits.
5. **No continuous auto-follow reform** as the primary party AI; regroup is reissue formation move.
6. **Single-agent correctness first**—multi-agent must not break detective-only office navigation tests.

---

## Suggested implementation map

| Phase | Primary code / docs homes |
|---|---|
| P0 | `NavigationGrid.swift`, `ActorLocomotion.swift`, `NavigationGridTests`, Technical Architecture §11.2 |
| P1 | `GameInputEvent` / `InputRouter`, scene pause helpers in `DetectiveOfficeScene`, HUD clock/stop controls |
| P2 | New pure `MovementProfile` (RainShadowCore), `RouteFollower.advance` speed parameter wiring |
| P3 | Actor controllers, selection set, companion spawn/scene ownership |
| P4 | Formation presets (pure math), party rail reorder, multi-select input |
| P5 | Multi-agent costs / wait policies, `appendRoute` input binding |
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

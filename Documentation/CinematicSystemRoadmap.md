# Cinematic System Roadmap

- Status: C0–C4 implemented. `CutsceneRunner` + `CutsceneDirector` ship; all three cutscenes are authored cue lists. C5 (JSON cues) and C6 (FMV) remain deferred
- Version: 0.3
- Date: 11 August 2026
- Scope: compare Baldur’s Gate: Enhanced Edition cinematic handling to RainShadow’s shipped prototype; propose a small, BG-shaped improvement path that fits SpriteKit and existing dialogue handoff

This document does **not** import Infinity Engine scripting (BCS, `.2da`, CLUA). It extracts the useful control, skip, and resume patterns and maps them onto RainShadow’s existing scene, dialogue, and camera code.

Related docs:

- [Game Design Document](GameDesignDocument.md) — exterior cinematic brief, camera language (§5.2, §9.2)
- [Technical Architecture](TechnicalArchitecture.md) — describes a `CinematicDirector` / cue timeline (§8). Shipped as `CutsceneRunner` + `CutsceneDirector`; the architecture doc still uses the older name
- [Dialogue System Roadmap](DialogueSystemRoadmap.md) — dialogue graph handoff (`shouldDeferAdvance`, resume)
- [Project Structure](ProjectStructure.md) — still lists `ExteriorCinematicDirector` (never built; the exterior runs on the shared runner)

---

## 1. Summary

Baldur’s Gate: Enhanced Edition splits cinematics into two tracks:

1. **Pre-rendered movies** (WebM / `.wbm` in EE; classic used Interplay `.mve`)
2. **In-engine cutscenes** (BCS scripts with explicit control lock, multi-actor beats, optional breakable skip, and safe completion)

RainShadow already mirrors the classic **dialogue → cutscene → dialogue** pattern for Empty Coat (office monologue → Lila entrance walk → resumed dialogue) and ships a non-interactive **opening exterior** camera cinematic with skip that converges on the same completion path as natural finish.

The architectural gap is **authorship and skip safety**: office cutscenes are scene-local Swift flags and one-off timelines rather than a reusable cue runner. The highest-value adoption of BG:EE patterns is:

1. A small **deterministic cue timeline** (wait, fade/letterbox, camera rail, actor path, door/search-map clear, resume dialogue)
2. **Breakable skip** that lands on the **same terminal state** as natural completion (dialogue node, HUD, camera, input locks)

That shipped in 0.3 as `CutsceneRunner` + `CutsceneDirector`, without importing IE script languages.

---

## 2. Baldur’s Gate: EE — how cinematics work

### 2.1 Pre-rendered movies

| Topic | EE behavior |
|-------|-------------|
| Format | WebM resources (`.wbm`, EE-only); classic used proprietary Interplay `.mve` |
| Catalog | Movies GUI mapping via `movidesc.2da` (`MOVIDESC`) |
| Content set | EE dropped original 3D CG for a smaller set of shorter hand-drawn WEBM animatics (~14: opening, ending, six area introductions, rest movies, Cloakwood flood, game over, Black Pits, etc.) |
| Script start | `StartMovie(resref)`; also `PlayMovie` from CLUA console |
| Gating | Often area globals on entry (e.g. palace movie when `EnteredPalace` is unset) |
| Subtitles | Player toggle (Options → Language → Show Subtitles); EE timing can desync if classic movies are restored |
| Resolutions (mod practice) | Multi-resolution packs (e.g. 1280×720 / 852×480 / 512×288) registered through `MOVIDESC.2DA` |

Primary references: [IESDP resource notes / movidesc](https://gibberlings3.github.io/iesdp/file_formats/general.htm), [IESDP StartMovie](https://gibberlings3.github.io/iesdp/scripting/actions/bgeeactions.htm), [BG Wiki — EE cinematics](https://baldursgate.fandom.com/wiki/Cinematics_(Baldur%27s_Gate:_Enhanced_Edition)).

### 2.2 In-engine cutscenes

Separate BCS path from movies:

| Action / trigger | Role |
|------------------|------|
| `StartCutSceneMode` | Remove player control and GUI interaction |
| `StartCutScene` | Run a named cutscene script |
| `CutSceneId` | Select the acting object for subsequent actions |
| `EndCutSceneMode` | Restore player control |
| `Wait` | Timed beats between actions |
| `FadeToColor` / `FadeFromColor` | Presentation chrome |
| `MoveViewPoint` / `MoveViewObject` | Camera / view scroll |
| `SetCutSceneBreakable` | Allow ESC to interrupt a prepared cutscene |
| `CutSceneBroken()` | Detect interruption so the game can finish safely |

Classic trigger shape:

```text
ClearAllActions
→ StartCutSceneMode
→ StartCutScene("scriptname")
→ … timed Wait / fade / MoveView / actor actions …
→ EndCutSceneMode
```

Breakable cutscenes often pair ESC with an OVERRIDE failsafe area script and a global such as `BD_CUTSCENE_BREAKABLE`, then use `CutSceneBroken()` so interrupted sequences still reach a consistent terminal state.

Multi-actor beats chain timed waits, fades, and view moves with `CutSceneId` selecting which creature is acting.

Two engine details the first research pass did not record, both load-bearing for the runner:

| Detail | Source | Why it matters |
|--------|--------|----------------|
| Blocks with **different** `CutSceneId`s run **in parallel**; actions inside one block are sequential and blocking. `ActionOverride(actor, action)` retargets one action but blocks the calling block. | [Pocketplane scripting guide](https://www.pocketplane.net/tutorials/simscript.html) | This *is* BG's concurrency model. It became `CutsceneTrack` (the block) and `.actionOverride` (the join). |
| `SmallWait(n)` counts **AI updates, 15 per second**; `Wait(n)` counts seconds. | [IESDP BG(2)EE actions](https://gibberlings3.github.io/iesdp/scripting/actions/bgeeactions.htm) | Identical to `LogicTickClock.ticksPerSecond`, which locomotion already runs on. `CutsceneBeat` collapses both onto that tick, so cutscene timing is frame-rate independent for the same reason the walk cycle is. |
| `scroll.ids` is a closed set — `INSTANT`(0), `SLOW`(1), `STANDARD`(2), `FAST`(3), `VERY_FAST`(4) — and **`VERY_FAST` is normal walking speed**. | [IESDP scroll.ids](https://gibberlings3.github.io/iesdp/files/ids/bg2/scroll.htm) | BG authors a camera *rate*, never a duration. `ScrollSpeed.veryFast` is derived from `ActorLocomotionPacing.walkSpeed` so the relationship survives an art rebake. |

Primary references: [IESDP BG(2)EE script actions](https://gibberlings3.github.io/iesdp/scripting/actions/bgeeactions.htm), [IESDP CutSceneBroken](https://gibberlings3.github.io/iesdp/scripting/triggers/bgeetriggers.htm).

### 2.3 What EE does *not* guarantee

- Not every in-world cutscene is ESC-skippable; breakability is a **content flag** (`SetCutSceneBreakable`), not a universal rule. Player reports of uneven skip coverage are consistent with that design.
- FMV skip UX (which key/click ends a pure movie) is less clearly documented than scripted cutscene breakability.
- Subtitle cue storage (muxed in WebM vs external engine tables/strrefs) is not fully specified in the sources used for this research.

---

## 3. RainShadow — current handling

### 3.1 Opening exterior cinematic

| Behavior | Implementation |
|----------|----------------|
| Form | Non-interactive SpriteKit scene (`OpeningExteriorScene`) |
| Camera | Ease/push toward warm office window for ~11.5s |
| Auto-complete | ~12s natural finish |
| Skip | Pointer-up / confirm after 1.0s |
| Convergence | Skip and natural finish share `completeCinematic` → office |
| GDD target | 10–14s establishing shot, skippable after the first second |

Cinematic content sits on the shared layer stack (`SceneLayer.cinematic`, z = 8000). Camera language in play is limited to slow pans, pushes, and restrained scale (GDD).

**Superseded in 0.3:** the exterior is now `CutsceneCatalog.openingExterior`, played by the shared `CutsceneDirector`. `ProjectStructure` still lists an `ExteriorCinematicDirector.swift` that was never built.

### 3.2 Scene transitions

All major scene changes go through `SceneRouter` (`SKView.presentScene`):

- `OpeningExteriorScene`
- `DetectiveOfficeScene`
- `CityDistrictScene`

Cross-fades: office ~1.15s, city ~0.75s, with re-entry guards. City has its own return-to-office fades in addition to the router API.

### 3.3 Dialogue ↔ cutscene handoff

| Piece | Role |
|-------|------|
| `DialogueSession` | Pure graph walker (conditions, onSelect actions, multi-graph) |
| `DialoguePresenter` | UI presenter; Continue/choices, VO hooks |
| `shouldDeferAdvance` | Cutscene handoff: leave a dialogue node without advancing the graph |
| Suppress / resume | Hide dialogue panel + HUD rails during cutscene; reopen on completion |

Empty Coat deliberately follows classic BG:

1. Continue on a monologue / cue page  
2. No-panel in-world walk (door fall + Lila entrance)  
3. Resume dialogue on the next node  

Office world-time policy (BG-like):

- **Dialogue mode:** pauses locomotion  
- **Cutscene mode:** does **not** pause the world for NPC locomotion; player input stays locked  

Shipped path in `DetectiveOfficeScene` / Empty Coat:

- Leaving monologue node `voss.monologue.4` defers dialogue advance  
- Hides panel and HUD rails  
- Plays door-fall + Lila entrance while the graph stays live  
- `resumeAfterCutscene` reopens dialogue and lifts the camera  

### 3.4 Skip coverage

| Sequence | Skip? | Input | Same terminal state as natural finish? |
|----------|-------|-------|----------------------------------------|
| Opening exterior | Yes (after 1.0s) | Tap / confirm / **Escape** | Yes — `CutsceneRunner.skip` |
| Lila entrance walk | Yes (after 1.0s) | Tap / confirm / **Escape** | Yes — `CutsceneRunner.skip` |
| Lila exit walk | Yes (after 1.0s) | Tap / confirm / **Escape** | Yes — `CutsceneRunner.skip` |
| Pre-rendered FMV | Not shipped | — | — |

All three run on one `CutsceneRunner` (which owns a `BreakableCutsceneGate`). Escape is the
BG:EE skip key, and in the office it is claimed *before* overlay-close and movement-cancel
so a running walk owns it.

`CutsceneCompletionReason` reaches the terminal apply instead of being discarded
(`CutSceneBroken()`), and it scales **presentation only** — a broken cutscene cuts to its
terminal pose (`chromeDuration(_:)` → 0) where a natural finish keeps the authored ease.

What changed in 0.3 is *how* the two paths stay identical. They used to be two pieces of
code — the natural completion and a hand-written snap — that had to be kept in step by
review. A skip now replays the unfinished cues in `terminal` form, so there is only ever
one list. `CutsceneRunnerTests` asserts it for every shipped cutscene at every tick it
could be broken at.

### 3.5 What shipped (2026-08-11)

Authorship is no longer the gap. The three cutscenes are `Cutscene` values in `CutsceneCatalog`:

| Piece | Type | Path |
|-------|------|------|
| Cue vocabulary | `Cutscene` / `CutsceneTrack` / `CutsceneCue` / `CutsceneBeat` / `ScrollSpeed` | `Gameplay/Navigation/Cutscene.swift` |
| Timeline | `CutsceneRunner` (pure, tick-driven, SpriteKit-free) | `Gameplay/Navigation/CutsceneRunner.swift` |
| Content | `CutsceneCatalog` | `Gameplay/Navigation/CutsceneCatalog.swift` |
| Execution | `CutsceneDirector` + `CutsceneStage` / `CutsceneActorDriving` | `Core/Scene/CutsceneDirector.swift` |
| Chrome | letterbox, fade overlay, overhead text on `cinematicRoot` | `Core/Scene/CutsceneChromeNodes.swift` |
| Actors | adapters over `RouteFollower` locomotion | `Gameplay/Actors/CutsceneActorAdapters.swift` |

Same split as `DialogueSession` / `DialoguePresenter`, and for the same payoff: the timing of every shipped cutscene is unit-tested without a render loop.

Three seams from §6 closed with it:

- **The `effectiveReason` latch is gone.** `performEntrance` could not report *why* it stopped, so the scene set `cutsceneBreakRequested`, snapped the actor, and read the flag back on the terminal path. The reason now travels on `CutsceneStep`.
- **`ClientEntranceTerminalState` is deleted.** It described by hand what skip and natural finish both had to produce. A skip now replays every unfinished cue in zero-duration terminal form, so the two paths cannot drift — the invariant is structural, and `CutsceneRunnerTests` asserts it at every tick of every shipped cutscene.
- **`cinematicRoot` is in use.** It was installed at z 8000 and parented to nothing; the office letterbox lived on `hudRoot` because of it. It now hangs off the camera like the HUD, so all three scenes can letterbox and fade.

Also: `cameraFollowSuspended` (an ownerless Bool two camera beats could race for) became `CutsceneDirector.cameraOverride(in:)`, `BaseGameScene` gained a `willMove(from:)` teardown so a router transition mid-cutscene cannot leave an armed gate, and a cutscene camera push now survives `layoutViewport()`.

### 3.6 Audio and planned directors

Runtime audio is scene-local `RainAudio` (`SKAudioNode` ambience beds and one-shot VO), not the long-lived multi-bus `AudioDirector` described in architecture docs.

Technical Architecture still describes:

- `CinematicDirector` for a deterministic cue timeline  
- Related coordinators (`TransitionCoordinator`, `ViewportCoordinator`) and fuller lifecycle hooks  

Whether those remain active targets vs outdated design is not formally deprecated; this roadmap treats the **cue timeline + breakable terminal state** as the live recommendation regardless of exact type names.

---

## 4. Comparison matrix

| Concern | BG:EE | RainShadow (shipped) | Gap |
|---------|-------|----------------------|-----|
| Movie vs in-engine split | Yes (WebM + BCS) | Exterior “movie-like” scene vs office in-world walks | Align conceptually; no FMV pipeline yet |
| Input lock during cutscene | `StartCutSceneMode` | Scene flags; presenter/HUD suppress | Align |
| Actors keep moving in cutscene | Yes | Yes (world not paused) | Align |
| Dialogue → cutscene → dialogue | Common pattern | Empty Coat / Lila entrance | Align by design |
| Authorship | Named reusable scripts + action vocabulary | `CutsceneCatalog` cue lists | Closed |
| Multi-actor selection | `CutSceneId` | `CutsceneTrack(subject:)` | Closed |
| Cross-actor join | `ActionOverride` (blocking) | `.actionOverride` | Closed |
| Beat units | `Wait` / `SmallWait` (15 Hz) | `CutsceneBeat` on `LogicTickClock` | Closed |
| Camera speed | `scroll.ids` rates | `ScrollSpeed`, `.veryFast` = walk speed | Closed |
| Camera + fade in script | `MoveView*` + `FadeTo*` | `.moveViewPoint` / `.moveViewObject` / `.fadeToColor` | Closed |
| Overhead text | `DisplayStringHead` | `.displayStringHead` | Closed |
| Breakable skip + safe end | `SetCutSceneBreakable` + `CutSceneBroken` | All three, one terminal path by construction | Closed |
| Subtitle toggle (movies) | Options language setting | N/A until FMV ships | Defer |
| Movies catalog UI | `movidesc` + Movies GUI | None | Defer until animatics exist |

---

## 5. Recommendations

### 5.1 Priority order

1. ~~Shared skip / complete terminal state~~ — done (C0–C2b)  
2. ~~Cue timeline runner~~ — done (C3)  
3. ~~Chrome cues: letterbox, fade, camera rails on `cinematicRoot`~~ — done (C4)  
4. **FMV / Movies catalog** only if pre-rendered animatics are actually shipped — still deferred  

Do **not** port BCS, `StartCutScene` string scripts, or IE globals. Keep authorship as Swift and/or small JSON cue lists owned by RainShadow.

### 5.2 The cue vocabulary (shipped)

`CutsceneCue`, grouped by the `CutsceneSubject` a track addresses. Every case maps to a documented Infinity Engine action.

| Subject | Cues | Engine equivalent |
|---------|------|-------------------|
| any | `.wait(CutsceneBeat)` | `Wait` / `SmallWait` |
| `.camera` | `.moveViewPoint(_, ScrollSpeed)`, `.moveViewObject(_, ScrollSpeed)`, `.releaseCamera` | `MoveViewPoint`, `MoveViewObject` |
| `.cameraZoom` | `.cameraScale(_, CutsceneBeat)` | none — BG has no zoom; GDD §5.2 restraint applies |
| `.chrome` | `.fadeToColor`, `.fadeFromColor`, `.letterbox`, `.setCutsceneMode`, `.suppressDialogue`, `.resumeDialogue(nodeID:)` | `FadeToColor` / `FadeFromColor`, `StartCutSceneMode` / `EndCutSceneMode` |
| `.actor(_)` | `.moveToPoint`, `.followPath(_, CutsceneWalkStyle)`, `.jumpToPoint`, `.face`, `.faceObject`, `.standUp`, `.displayStringHead`, `.playVoiceOver` | `MoveToPoint`, `JumpToPoint`, `Face`, `FaceObject`, `DisplayStringHead`, `PlaySound` |
| `.world` | `.setDoor(_, open:)`, `.setFlag` | search-map clear, `SetGlobal` |
| cross-actor | `.actionOverride(CutsceneActorID, CutsceneCue)` | `ActionOverride` — retargets and **blocks** the issuing track |

Held to:

- Cues are **deterministic** given the same start state, and the runner is tested without SpriteKit.
- Skip and natural completion converge by construction, not by two code paths (see §9).
- Dialogue graph position stays owned by `DialogueSession`; the runner only resumes the deferred session.
- Chrome sits on `cinematicRoot`, which is camera-parented alongside the HUD.
- Camera *rates*, never durations. Duration is distance over rate, resolved by the director.

### 5.3 Breakable skip (BG:EE-shaped)

Model after EE’s breakable cutscenes, not after unlimited free skip:

| Rule | Detail |
|------|--------|
| Opt-in per sequence | Longer office walks and exterior-style rails are breakable; tiny one-beat chrome may stay non-skippable |
| Grace window optional | Exterior already uses ~1.0s before skip is accepted |
| One terminal path | Skip must apply the same dialogue node, HUD visibility, camera resting pose, input locks, door/search-map state, and actor positions as natural finish |
| Prefer snap-to-end over mid-path freeze | Jump actors/camera/doors to authored end state; do not leave half-walked paths or dual HUD |
| Input | Match platform norms (tap / confirm / Escape on Mac) once a shared cutscene chrome exists |

Acceptance sketch:

- Skipping Lila entrance mid-walk lands on the same post-entrance dialogue node and camera as waiting out the path.  
- Double-complete is impossible (guarded completion flag).  
- Unit tests can assert terminal dialogue node id + suppress flags without running SpriteKit presentation.

### 5.4 Camera and chrome

Expand play cinematics modestly:

- Letterbox bars and short fades during in-office scripted beats  
- Short camera rails (not free-form IE-style view scripts)  
- Keep GDD restraint: slow pans/pushes/scale only; no flashy modern cinematic camera  

Exterior reduced-motion alternatives (if still listed in GDD/architecture) should be verified against shipped `OpeningExteriorScene` when implementing the runner.

### 5.5 Pre-rendered animatics (later)

Only if the project adds true FMV-style beats:

- Prefer multi-resolution packs and a simple Movies-style catalog for titles  
- Player subtitle toggle with **timing owned by the asset** (avoid EE’s classic-movie restore desync pain)  
- Register playback through a single presenter that still ends in one terminal game state (area entry, dialogue node, or menu)  

This is explicitly out of Milestone 01 slice scope unless product direction changes.

### 5.6 What not to do

- Do not add a BCS interpreter or IE action string DSL.  
- Do not pause world time during cutscene mode for NPCs that must walk (keep BG-like policy).  
- Do not bypass `NavigationMap` / `RouteFollower` for cutscene actor floor movement.  
- Do not treat skip as “abort without completing story state.” Terminal narrative state is mandatory.  
- Do not conflate router scene cross-fades with in-scene cutscene cues; keep `SceneRouter` for scene identity and the cutscene runner for in-scene beats.

---

## 6. Suggested implementation slices

Docs only until scheduled. Suggested order when work begins:

| Phase | Deliverable | Notes |
|-------|-------------|-------|
| **C0** | Inventory terminal states | **Done**, then superseded — `ClientEntranceTerminalState` was deleted once `CutsceneCue.terminal` made the convergence structural |
| **C1** | Shared completion API | **Done** — `finishClientEntrance` / `finishClientExit` (single-fire via gate) |
| **C2** | Breakable skip on Lila entrance | **Done** — grace 1.0s; snap-to-end via `completeEntranceImmediately`; same resume node as natural |
| **C2b** | Breakable skip on Lila exit | **Done** — `completeExitImmediately` → same unlock path |
| **C3** | Cue runner MVP | **Done** — `CutsceneRunner` + `CutsceneDirector`; all three cutscenes ported |
| **C4** | Chrome cues | **Done** — letterbox, fade overlay, and overhead text on `cinematicRoot` |
| **C5** | Optional JSON/data cues | Deferred |
| **C6** | FMV path | Deferred; multi-res + subtitles + catalog |

### Remaining seams

- `ClientActorNode` ships three strips — arrival SW, departure NE, departure NW. There is no
  turn-in-place art, so `.face` / `.faceObject` on `.client` trips an `assertionFailure`
  rather than picking a departure strip that would face her at the door she just used.
  Art-blocked, not code-blocked.
- `CityDistrictScene` has the director and the chrome but authors no cutscenes yet.
- `SceneRouter.isTransitioning` clears on a dispatch deadline rather than a transition
  completion, so a cutscene that drives a route change can still re-enter.

---

## 7. Source index

### External (BG:EE / IE)

- [IESDP — resource types / conventions](https://gibberlings3.github.io/iesdp/file_formats/general.htm)
- [IESDP — movidesc.2da (BGEE)](https://gibberlings3.github.io/iesdp/files/2da/2da_bgee/movidesc.htm)
- [IESDP — BG(2)EE script actions](https://gibberlings3.github.io/iesdp/scripting/actions/bgeeactions.htm) (`StartMovie`, `StartCutSceneMode`, `StartCutScene`, `EndCutSceneMode`, `CutSceneId`, `SetCutSceneBreakable`, fades, `MoveView*`)
- [IESDP — BG(2)EE triggers](https://gibberlings3.github.io/iesdp/scripting/triggers/bgeetriggers.htm) (`CutSceneBroken`)
- [IESDP — CLUA / PlayMovie](https://gibberlings3.github.io/iesdp/appendices/clua/bgee.htm)
- [Baldur’s Gate Wiki — EE cinematics](https://baldursgate.fandom.com/wiki/Cinematics_(Baldur%27s_Gate:_Enhanced_Edition))
- Beamdog forums / classic-movie restoration notes (subtitle toggle and desync when restoring classic movies)

### RainShadow (shipped code / docs)

- `RainShadow Shared/Scenes/OpeningExterior/OpeningExteriorScene.swift`
- `RainShadow Shared/Core/Scene/SceneRouter.swift`
- `RainShadow Shared/Core/Scene/BaseGameScene.swift`
- `RainShadow Shared/Core/Scene/SceneLayer.swift`
- `RainShadow Shared/Gameplay/Navigation/DialogueSession.swift`
- `RainShadow Shared/Scenes/CaseIntroduction/DialoguePresenter.swift` (or equivalent presenter path under Shared)
- `RainShadow Shared/Scenes/DetectiveOffice/DetectiveOfficeScene.swift`
- `RainShadow Shared/Gameplay/Navigation/EmptyCoatCaseIntroduction.swift`
- `RainShadow Shared/Gameplay/Audio/RainAudio.swift`
- `Documentation/GameDesignDocument.md`
- `Documentation/TechnicalArchitecture.md`
- `Documentation/DialogueSystemRoadmap.md`
- `Documentation/ProjectStructure.md`

---

## 8. Open questions / research gaps

These were left unresolved in the 2026-08 research pass; resolve when implementing C0–C3:

1. Whether EE still natively plays legacy `.mve` vs only WebM (IESDP action text still mentions MVE on some pages while resource tables document `.wbm`). **Still open** — not needed until an FMV path exists.  
2. Exact user control for pure FMV skip in EE. **Resolved enough to act on:** Escape is the skip key, and coverage is uneven because breakability is a per-sequence content flag — Beamdog deliberately made some sequences (e.g. its own NPC scenes) unskippable. That is why `BreakableCutsceneGate` now carries `isBreakable` (`SetCutSceneBreakable`) rather than treating every armed gate as skippable.  
3. How EE subtitle cue times are stored. **Still open** — deferred with the FMV path.  
4. ~~Whether planned `CinematicDirector` / lifecycle hooks remain targets~~ **Resolved:** shipped as a pure `CutsceneRunner` plus a SpriteKit `CutsceneDirector`. `TechnicalArchitecture` §7.3/§8.1 still describe the old single-type design and the unbuilt `TransitionCoordinator` / `ViewportCoordinator` / `AudioDirector`.  
5. Whether reduced-motion alternatives for the exterior camera push are wired. **Still open** — the push is now one `.cameraScale` track, so a reduced-motion variant is a catalog edit rather than a scene edit.  
6. Full city-district transition inventory vs office/opening (only partially inspected).  

---

## 9. Decision freeze (when implementation is scheduled)

Until a cinematic milestone is scheduled, the following remain **recommendations**, not frozen product rules:

- Prefer cue timeline + single terminal state over more scene-local one-offs.  
- Prefer breakable skip on long in-world walks.  
- Prefer SpriteKit/in-engine beats over FMV for case storytelling in the first slice.  
- Keep dialogue handoff on `shouldDeferAdvance` / suppress / resume rather than inventing a second dialogue stack.

**Frozen as of 0.3:**

- **Skip and natural completion share one terminal state.** Not a review item — a property of the
  design. `CutsceneCue.terminal` collapses duration without changing effect, and `CutsceneRunner.skip`
  replays every unfinished cue in that form, the in-flight one included. A cue added to a cutscene is
  covered by skip the moment it is authored.
- **Cutscene mode does not pause NPC locomotion**; dialogue mode may.
- **Cutscene timing is measured in logic ticks**, not seconds and not frames. `CutsceneBeat.seconds`
  is sugar over the same 15 Hz tick locomotion runs on.
- **Floor movement goes through `NavigationMap` / `RouteFollower`.** `.followPath` carries an authored
  polyline for the one route that must not be A*-expanded; it is still a route, never an `SKAction` chain.
- **Two tracks may not address one subject.** In BG that silently serialises them onto a single action
  list; here it is an authoring error, asserted in `begin` and pinned per shipped cutscene.

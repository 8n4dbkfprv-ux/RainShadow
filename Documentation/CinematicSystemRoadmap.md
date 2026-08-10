# Cinematic System Roadmap

- Status: Phase 1–3 implemented (breakable office walks + terminal-state contract + letterbox); Phase 4 `CutsceneRunner` still optional
- Version: 0.2
- Date: 5 August 2026
- Scope: compare Baldur’s Gate: Enhanced Edition cinematic handling to RainShadow’s shipped prototype; propose a small, BG-shaped improvement path that fits SpriteKit and existing dialogue handoff

This document does **not** import Infinity Engine scripting (BCS, `.2da`, CLUA). It extracts the useful control, skip, and resume patterns and maps them onto RainShadow’s existing scene, dialogue, and camera code.

Related docs:

- [Game Design Document](GameDesignDocument.md) — exterior cinematic brief, camera language (§5.2, §9.2)
- [Technical Architecture](TechnicalArchitecture.md) — planned `CinematicDirector` / cue timeline (§8)
- [Dialogue System Roadmap](DialogueSystemRoadmap.md) — dialogue graph handoff (`shouldDeferAdvance`, resume)
- [Project Structure](ProjectStructure.md) — planned `ExteriorCinematicDirector` (not yet a shipped type)

---

## 1. Summary

Baldur’s Gate: Enhanced Edition splits cinematics into two tracks:

1. **Pre-rendered movies** (WebM / `.wbm` in EE; classic used Interplay `.mve`)
2. **In-engine cutscenes** (BCS scripts with explicit control lock, multi-actor beats, optional breakable skip, and safe completion)

RainShadow already mirrors the classic **dialogue → cutscene → dialogue** pattern for Empty Coat (office monologue → Lila entrance walk → resumed dialogue) and ships a non-interactive **opening exterior** camera cinematic with skip that converges on the same completion path as natural finish.

The architectural gap is **authorship and skip safety**: office cutscenes are scene-local Swift flags and one-off timelines rather than a reusable cue runner. The highest-value adoption of BG:EE patterns is:

1. A small **deterministic cue timeline** (wait, fade/letterbox, camera rail, actor path, door/search-map clear, resume dialogue)
2. **Breakable skip** that lands on the **same terminal state** as natural completion (dialogue node, HUD, camera, input locks)

That matches planned `CinematicDirector` / JSON cinematic cues in Technical Architecture without importing IE script languages.

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

**Note:** `ProjectStructure` still lists `ExteriorCinematicDirector.swift`; the shipped exterior timeline is **inline** in `OpeningExteriorScene`, not a separate director type.

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

### 3.4 Skip coverage today

| Sequence | Skip? | Same terminal state as natural finish? |
|----------|-------|----------------------------------------|
| Opening exterior | Yes (after 1.0s) | Yes — shared `completeCinematic` |
| Lila entrance walk | Yes (after 1.0s) | Yes — shared `finishClientEntrance` + snap-to-end |
| Lila exit walk | Yes (after 1.0s) | Yes — shared `finishClientExit` + snap-to-end |
| Pre-rendered FMV | Not shipped | — |

### 3.5 Audio and planned directors

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
| Authorship | Named reusable scripts + action vocabulary | Scene-local Swift timelines | **Main gap** |
| Multi-actor selection | `CutSceneId` | Hard-coded actor nodes | Acceptable at slice scale; generalize later |
| Camera + fade in script | `MoveView*` + `FadeTo*` | Exterior rail; short office lift; router fades | Expand via shared cues |
| Breakable skip + safe end | `SetCutSceneBreakable` + `CutSceneBroken` | Exterior only | **Priority gap** for office walks |
| Subtitle toggle (movies) | Options language setting | N/A until FMV ships | Defer |
| Movies catalog UI | `movidesc` + Movies GUI | None | Defer until animatics exist |

---

## 5. Recommendations

### 5.1 Priority order

1. **Shared skip / complete terminal state** for office cutscenes (and any future long in-world walk)  
2. **Cue timeline runner** extracting exterior + Lila patterns into one API  
3. **Modest chrome cues**: letterbox, fade, short camera rails on `cinematicRoot`  
4. **FMV / Movies catalog** only if pre-rendered animatics are actually shipped  

Do **not** port BCS, `StartCutScene` string scripts, or IE globals. Keep authorship as Swift and/or small JSON cue lists owned by RainShadow.

### 5.2 Deterministic cue timeline

Adopt a small closed vocabulary, for example:

| Cue | Intent |
|-----|--------|
| `wait` | Timed beat |
| `fade` / `letterbox` | Presentation chrome |
| `cameraRail` | Slow pan/push/scale on the camera / cinematic root |
| `actorPath` | NPC/player locomotion via existing `NavigationMap` / `RouteFollower` (no free `SKAction` locomotion chains for floor movement) |
| `door` / search-map clear | Geometry and navigation stamping consistent with [Pathfinding System](PathfindingSystem.md) |
| `suppressDialogue` / `resumeDialogue` | Handoff with existing `shouldDeferAdvance` + presenter suppress/resume |
| `lockInput` / `unlockInput` | Cutscene mode boundary |

Requirements:

- Cues are **deterministic** given the same start state (testable without SpriteKit where possible).  
- Skip and natural completion call **one** `completeCutscene` (or equivalent) that applies terminal state once.  
- Dialogue graph position is owned by `DialogueSession`; the runner never invents nodes—only resumes the deferred session.  
- Prefer sitting on `BaseGameScene`’s existing layer contract (`cinematicRoot`, camera-owned HUD) rather than new free-form z stacks.

This is the planned `CinematicDirector` idea from Technical Architecture, whether kept under that name or as a leaner `CutsceneRunner`.

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
| **C0** | Inventory terminal states | **Done** — `ClientEntranceTerminalState` + `BreakableCutsceneGate` |
| **C1** | Shared completion API | **Done** — `finishClientEntrance` / `finishClientExit` (single-fire via gate) |
| **C2** | Breakable skip on Lila entrance | **Done** — grace 1.0s; snap-to-end via `completeEntranceImmediately`; same resume node as natural |
| **C2b** | Breakable skip on Lila exit | **Done** — `completeExitImmediately` → same unlock path |
| **C3** | Cue runner MVP | Optional later — office walks still scene-authored |
| **C4** | Chrome cues | **Partial** — letterbox on entrance/exit walks; camera lift unchanged |
| **C5** | Optional JSON/data cues | Deferred |
| **C6** | FMV path | Deferred; multi-res + subtitles + catalog |

### Shipped types (2026-08)

- `BreakableCutsceneGate` / `CutsceneCompletionReason` / `ClientEntranceTerminalState` — `RainShadow Shared/Gameplay/Navigation/BreakableCutsceneGate.swift`
- `ClientActorNode.completeEntranceImmediately()` / `completeExitImmediately()`
- `DetectiveOfficeScene.trySkipActiveClientCutscene()` + letterbox chrome on `hudRoot`

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

1. Whether EE still natively plays legacy `.mve` vs only WebM (IESDP action text still mentions MVE on some pages while resource tables document `.wbm`).  
2. Exact user control for pure FMV skip in EE.  
3. How EE subtitle cue times are stored.  
4. Whether planned `CinematicDirector` / lifecycle hooks in Technical Architecture remain targets or should be rewritten around a smaller `CutsceneRunner` name.  
5. Whether reduced-motion alternatives for the exterior camera push are wired in shipped `OpeningExteriorScene`.  
6. Full city-district transition inventory vs office/opening (only partially inspected).  

---

## 9. Decision freeze (when implementation is scheduled)

Until a cinematic milestone is scheduled, the following remain **recommendations**, not frozen product rules:

- Prefer cue timeline + single terminal state over more scene-local one-offs.  
- Prefer breakable skip on long in-world walks.  
- Prefer SpriteKit/in-engine beats over FMV for case storytelling in the first slice.  
- Keep dialogue handoff on `shouldDeferAdvance` / suppress / resume rather than inventing a second dialogue stack.

When C1–C2 ship, freeze:

- “Skip and natural completion share one terminal state” as a hard invariant for every breakable cutscene.  
- Cutscene mode does not pause NPC locomotion; dialogue mode may pause locomotion (already BG-like office policy).

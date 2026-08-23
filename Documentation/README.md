# RainShadow pre-production package

- Status: implemented prototype baseline
- Version: 0.1
- Date: 17 July 2026

This package defines the creative and technical baseline for RainShadow's first playable slice. The repository now includes production prototype code and generated game art derived from that baseline.

## Documents

1. [Game Design Document](GameDesignDocument.md) — game vision, design pillars, core loops, investigation and RPG systems, tone, controls, and the opening-sequence brief.
2. [Technical Architecture](TechnicalArchitecture.md) — SpriteKit runtime design, scene lifecycle, depth sorting, input, navigation, data, performance, testing, and the first two scenes.
3. [Initial Asset Manifest](AssetManifest.md) — exact first-pass image, animation, effect, data-mask, audio, naming, sizing, and generation requirements.
4. [Infinity Engine Ground Projection](InfinityEngineGroundProjection.md) — Baldur's Gate: EE orthographic camera lock for area art (elevation asin(0.75), 16:12 ground ellipse, 128×96 diamond).
5. [BG:EE Projection Master Regen](BGEEProjectionMasterRegen.md) — checklist to regenerate office/city/character masters after the projection adoption.
6. [Detective Office V11 production note](../ArtSource/Prompts/office_1950s_bgee_v11.md) — supplied-reference identity and role, uniform crop transform, exact ImageGen source requests and hashes, registered fixture contract, and measured staging gates for the 1950s rebuild.
7. [Milestone 01 Implementation Plan](Milestone01ImplementationPlan.md) — ordered planning-mode work breakdown, gates, acceptance criteria, risks, and definition of done.
8. [Proposed Xcode Project Structure](ProjectStructure.md) — target strategy, folder tree, key Swift files, resource organization, and migration map from the stock template.
9. [Dialogue System Roadmap](DialogueSystemRoadmap.md) — dialogue system vs Infinity Engine–class systems: Phases **0–5 shipped** (state, triggers, actions, journal, multi-graph, external JSON + string table, intention tags UI).
10. [Movement System Roadmap](MovementSystemRoadmap.md) — prioritized plan to close classic Baldur’s Gate / Infinity Engine movement gaps (pause/stop/cancel, speed model, multi-actor control, formations). Phase 0 and Phase 3 locomotion are shipped; the rest is docs only until a movement milestone is scheduled.
11. [Pathfinding and NPC Locomotion](PathfindingSystem.md) — **shipped**: the BG:EE-style navigation stack (raster search map, Lazy Theta\* any-angle search, actor occupancy and bumping, in-place door stamping, corrective repathing) and the frozen convention for how every future NPC is written.
12. [BGEE Character Sprite Redo Plan (V5)](BGEECharacterSpriteRedoPlan.md) — superseded plan document; the shipped V6 redesign (see `ArtSource/Prompts/character_prerendered_3d_v06.md`) regenerated the actors as Harlan Voss / Lila March with new BGEE-style identities at full AssetManifest density.
13. [Paperdoll → BGEE Sprite Redo Plan (V11)](PaperdollBGEESpriteRedoPlanV11.md) — superseded for Voss room sprites; Lila V11 bob/dress from this pass remains current.
14. [Paperdoll → BGEE Sprite Redo Plan (V12)](PaperdollBGEESpriteRedoPlanV12.md) — installed: Voss atlases re-locked to paperdoll identity + craft density through V7 BGEE preprocess (SE + NE desk); Lila untouched.
15. [Cinematic System Roadmap](CinematicSystemRoadmap.md) — **shipped**: the BG:EE-style cutscene stack (parallel `CutSceneId` tracks, `ActionOverride` joins, `scroll.ids` camera rates, `Wait`/`SmallWait` on the 15 Hz logic tick, breakable skip that converges by construction). All three cutscenes are authored cue lists in `CutsceneCatalog`. FMV and JSON cues remain deferred.
16. [Inventory System Roadmap](InventorySystemRoadmap.md) — the BG:EE inventory stack: **Phases 0–4 shipped** (JSON item catalog, `CRE`-shaped equipment slots, stack merging and splitting, Strength-style encumbrance driving `MovementProfile`, Lore identification, the live paperdoll window, ground piles, and the quick-loot bar). Wearable content and shops remain docs only.
17. [BG:EE Humanoid Pipeline](BGEEHumanoidPipeline.md) — measured BAM frame/palette research, RainShadow scale comparison, the active 64-row/64-colour `BGEE_V1` crunch, and the invariant 200px/70.3125-unit physical body contract.

## Decisions frozen for Milestone 01

- Runtime presentation is two-dimensional SpriteKit. There is no SceneKit, 3D runtime, Unity, or custom Metal renderer.
- The visual target is a late-1990s/early-2000s pre-rendered isometric CRPG production language: painterly area plates, crude era-authentic textured 3D meshes rendered into lightly pixelated 2D frames, fixed projection, baked chiaroscuro, authored foreground occlusion, and restrained live effects.
- Exterior is a short non-interactive establishing scene. The office becomes playable after the cinematic transition.
- The V18 office plate bakes only fixed architecture: floor/brick, two 1950s
  steel casement windows, and two period cast-iron radiators on the window wall.
  The former fireplace, hearth, glow, collision and cover are removed. Movable props remain independent.
  Window rain, cool/blind lighting, near-window hover and `office.window`, the
  registered door-state family and 16×12 navigation stay
  separate but share one geometry registration. V10 is retained as rollback
  provenance.
- `office_suite.area.json` is the office runtime authority for the plate,
  regions/travel, props, registered door visual, obstacles, wall polygons,
  actors, ambients, and camera bounds; generated Swift and exporter parity keep
  the runtime search map aligned with that data.
- The actor target adopts Baldur's Gate's pre-rendered-3D-to-2D technique with controlled era-appropriate raster texture: crude hundreds-of-triangles meshes, tiny diffuse maps, primitive Gouraud/vertex light, a measured 64-pixel native craft body, a restrained 64-color per-material ramp built from opaque pixels only, nearest upscaling to the fixed 200-pixel registered texture body, and linear play-zoom filtering. Locomotion resolves to 16 facing bins using nine source orientations plus seven mirrored eastern orientations, following the legacy character-animation convention. The rendered body remains 70.3125 world units; see [BG:EE Humanoid Pipeline](BGEEHumanoidPipeline.md).
- The playable interaction slice includes first client Lila March's authored front-view arrival and rear-view departure, a compact branching case conversation with response, Continue, and End Dialogue states, then inspection, standing, walking, inventory access, and five office hotspots. Evidence-gated Press options, journal-on-choice, multi-graph session, external dialogue JSON + string table, and GDD intention tags (`[Open]` / `[Press]` / …) on choices are **shipped**; broader case branching and the deduction UI remain later work.
- **Classic Baldur’s Gate dialogue roles (frozen):** during NPC conversation, Harlan Voss (PC) spoken lines are **player-selectable reply options**, never main-speaker nodes the player only Continues through. NPC multi-page speech may use Continue. Pre-conversation interior monologue (`voss.monologue.*`) is the only Continue-only Voss exception. Conversation topology and prose live under `RainShadow Shared/Resources/Dialogue/` (JSON graphs + `strings.en.json`). See GDD §7.5 and [Dialogue System Roadmap](DialogueSystemRoadmap.md).
- **Navigation and NPC locomotion (frozen):** movement runs on the Baldur's Gate: Enhanced Edition / Infinity Engine model — a raster search map, Lazy Theta\* any-angle search, actors stamped into the map with idle friendly actors bumpable, dynamic geometry stamped in place rather than rebuilt, and periodic corrective repathing. Every floor-bound actor, player or NPC, routes through `NavigationMap` and advances via `RouteFollower`; authored polylines and `SKAction` movement chains are not permitted for locomotion. See [Pathfinding and NPC Locomotion](PathfindingSystem.md).
- **Cutscenes (frozen):** authored as `Cutscene` values in `CutsceneCatalog` — parallel tracks addressing one subject each (BG's `CutSceneId` blocks), sequential blocking cues inside a track, `.actionOverride` to join on another actor's work. Beats are logic ticks (`Wait` / `SmallWait` at 15 Hz); camera moves take a rate from `ScrollSpeed` (`scroll.ids`), never a duration. A skip replays every unfinished cue in zero-duration terminal form, so breaking a cutscene and playing it out reach the same state by construction. See [Cinematic System Roadmap](CinematicSystemRoadmap.md) §9.
- **Inventory (frozen):** items are authored data (`RainShadow Shared/Resources/Items/`), not Swift literals; the slot table follows the Infinity Engine `CRE` layout and gates equipping on item category; a refused move is refused rather than silently relocated; coins never occupy a bag slot; a recovered firearm is carried, never auto-equipped; encumbrance uses the shipped *Adventurer's Guide* bands (100% halves speed, above 110% stops movement) and the warning band carries no penalty; worn gear never stacks. Inventory exists to carry case-relevant objects, never as a reward loop (§12). Pure rules live in the SwiftPM target so they stay testable. See [Inventory System Roadmap](InventorySystemRoadmap.md).
- The current project includes iOS, macOS, and tvOS template targets. Milestone scope is iOS/iPadOS and macOS; tvOS remains excluded from shared resource membership and release validation.

## Art-reference research summary

The supplied screenshots establish the three-quarter isometric view, maquette-derived body and equipment masses, multi-orientation animation, contact shadows, pre-lit rooms, strong value grouping, and foreground occlusion. RainShadow preserves that construction rather than deliberately reproducing the screenshots' low native resolution. External research supports the production technique:

- [PC Gamer's Infinity Engine history](https://www.pcgamer.com/how-the-innovation-of-the-infinity-engine-brought-baldurs-gate-to-life/) describes animated sprites over detailed pre-rendered isometric backdrops and the manual clipping/occlusion work that let actors pass behind walls.
- [GemRB's engine overview](https://www.gemrb.org/Engine-overview.html) describes Infinity Engine areas as painted or rendered static pictures with animated avatars and effects layered over them.
- [Beamdog's Planescape: Torment Enhanced Edition page](https://www.beamdog.com/games/planescape-torment-enhanced/) confirms the Enhanced Edition emphasis on a high-definition interface, area zooming, and interaction highlighting while preserving the original presentation.
- [Beamdog's Enhanced Edition postmortem](https://www.gamedeveloper.com/programming/postmortem-overhaul-games-i-baldur-s-gate-enhanced-edition-i-) says the team planned to take the original character models and re-render them at higher resolution with more frames and orientations; the lost source art prevented that HD path.
- [IESDP's creature-animation documentation](https://gibberlings3.github.io/iesdp/file_formats/ie_formats/ini_anim.htm) documents the legacy orientation cycles and the option for the engine to derive eastern facings from mirrored western-facing resources.

RainShadow uses those production principles, not copied locations, characters, interface elements, logos, or source assets. Its setting, compositions, silhouettes, prop designs, palette, and UI remain original.

## Working vocabulary

- **Area plate**: the opaque, pre-rendered architectural background for one location.
- **Prop**: a separate transparent object image placed in the world.
- **Depth anchor**: the ground-contact point used to decide whether a world node renders in front of another.
- **Occluder**: transparent foreground art that deliberately renders over an actor.
- **Hotspot**: a data-defined interactive region, independent of the visible prop bounds.
- **Logical point**: the scene-space unit used by code. Asset dimensions in the manifest are physical pixels.
- **Master**: high-resolution source retained outside the shipped asset catalog.
- **Runtime export**: the optimized image loaded by SpriteKit.

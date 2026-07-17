# RainShadow pre-production package

- Status: implemented prototype baseline
- Version: 0.1
- Date: 17 July 2026

This package defines the creative and technical baseline for RainShadow's first playable slice. The repository now includes production prototype code and generated game art derived from that baseline.

## Documents

1. [Game Design Document](GameDesignDocument.md) — game vision, design pillars, core loops, investigation and RPG systems, tone, controls, and the opening-sequence brief.
2. [Technical Architecture](TechnicalArchitecture.md) — SpriteKit runtime design, scene lifecycle, depth sorting, input, navigation, data, performance, testing, and the first two scenes.
3. [Initial Asset Manifest](AssetManifest.md) — exact first-pass image, animation, effect, data-mask, audio, naming, sizing, and generation requirements.
4. [Milestone 01 Implementation Plan](Milestone01ImplementationPlan.md) — ordered planning-mode work breakdown, gates, acceptance criteria, risks, and definition of done.
5. [Proposed Xcode Project Structure](ProjectStructure.md) — target strategy, folder tree, key Swift files, resource organization, and migration map from the stock template.

## Decisions frozen for Milestone 01

- Runtime presentation is two-dimensional SpriteKit. There is no SceneKit, 3D runtime, Unity, or custom Metal renderer.
- The visual target is a late-1990s/early-2000s pre-rendered isometric CRPG language: painterly area plates, coarse pre-rendered avatar sprites with chunky early-3D silhouettes, fixed projection, baked chiaroscuro, authored foreground occlusion, and restrained live effects.
- Exterior is a short non-interactive establishing scene. The office becomes playable after the cinematic transition.
- World props, the office door, the window treatment, the detective, foreground occluders, lighting overlays, and effects are separate runtime assets. The office architecture plate does not contain those objects.
- The actor target is explicitly the Baldur's Gate: Enhanced Edition in-game avatar look: a deliberately low-resolution, limited-palette, pre-rendered 3D-derived sprite rather than a smooth or realistically illustrated figure. Locomotion resolves to 16 facing bins using nine source orientations plus seven mirrored eastern orientations, following the legacy character-animation convention.
- The playable interaction slice includes first client Vivian Hart's authored front-view arrival and rear-view departure, a short player-advanced case conversation, then inspection, standing, walking, inventory access, and five office hotspots. Full branching dialogue and deduction UI remain later work.
- The current project includes iOS, macOS, and tvOS template targets. Milestone scope is iOS/iPadOS and macOS; tvOS remains excluded from shared resource membership and release validation.

## Art-reference research summary

The supplied screenshots show the essential characteristics to preserve: a three-quarter isometric view, very low native actor resolution, chunky maquette-like body and equipment masses, palette-banded shading, multi-orientation animation, contact shadows, pre-lit rooms, strong value grouping, and foreground architecture that can occlude actors. External research supports the same reading:

- [PC Gamer's Infinity Engine history](https://www.pcgamer.com/how-the-innovation-of-the-infinity-engine-brought-baldurs-gate-to-life/) describes animated sprites over detailed pre-rendered isometric backdrops and the manual clipping/occlusion work that let actors pass behind walls.
- [GemRB's engine overview](https://www.gemrb.org/Engine-overview.html) describes Infinity Engine areas as painted or rendered static pictures with animated avatars and effects layered over them.
- [Beamdog's Planescape: Torment Enhanced Edition page](https://www.beamdog.com/games/planescape-torment-enhanced/) confirms the Enhanced Edition emphasis on a high-definition interface, area zooming, and interaction highlighting while preserving the original presentation.
- [Beamdog's Enhanced Edition postmortem](https://www.gamedeveloper.com/programming/postmortem-overhaul-games-i-baldur-s-gate-enhanced-edition-i-) describes loading a character frame and orientation, then applying 256-color palette remapping; the missing source models prevented a clean high-resolution sprite rerender.
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

# Shared character appearances — October 3

Characters can reuse the current Voss and Lila sprite families with independent
material colours and compatible equipment. The player/client still resolve to
`VossCHMF` through `VossAnimationSet` and `LilaSentinel` through
`LilaAnimationSet`. No sprite bundles, Blender sources, movement algorithms,
animation-clock arithmetic, tint arithmetic or save formats changed.

## Codes and presets

`Gameplay/Navigation/CharacterAppearance.swift` defines the registry and Codable
content model. Codes are stable aliases; class and faction are independent,
optional content IDs. Assigning a class does not choose a sprite, and assigning
a faction does not itself change hostility or ground-circle colour.

| Code | Meaning |
|---|---|
| `HUM-M-01` | Current Voss body, all sixteen authored directions |
| `HUM-F-01` | Current Lila body, all sixteen authored directions |
| `PAL-AUTHORED` | Keep the selected bundle's seven authored colour ramps |
| `PAL-GUARD-01` | Minor/major clothing ramps 46/63; other regions stay authored |
| `PAL-BANDIT-01` | Minor/major clothing ramps 49/59; other regions stay authored |
| `iron-helmet` | Current Voss helmet layer |
| `splint-mail` | Current Voss mail layer |
| `lantern-shortsword` | Current Voss sword layer |

`CharacterDefinition.voss` and `.lila` preserve the named characters' appearance.
`.cityGuard`, `.bandit` and `.civilian` are reusable example presets, not new
placements in shipped areas. Give each spawned actor its own `id`.

## Authoring a character

Records decode using `JSONDecoder().decode(CharacterDefinition.self, from: data)`.
The example below can be stored in an NPC content record; there is no automatic
directory scanner or new world population/save system.

```json
{
  "id": "city_guard_014",
  "class": "fighter",
  "faction": "city-watch",
  "appearance": {
    "body": "HUM-M-01",
    "palette": "PAL-GUARD-01",
    "colors": { "hair": 1 },
    "equipment": [
      { "item": "iron-helmet" },
      { "item": "splint-mail", "colors": { "metal": 35 } },
      { "item": "lantern-shortsword" }
    ]
  }
}
```

Only `id`, `appearance` and its `body` are required. Omitting `palette` preserves
authored colours; omitting `equipment` means no visible equipment. Equipment
lists describe worn/readied layers, not backpack contents.

`colors` accepts `metal`, `minor`, `major`, `skin`, `leather`, `armor` and `hair`.
Values are integer gradient-table rows from 0 through 255, not RGB colours.
The palette preset is applied first; explicit overrides win. Unspecified
materials keep their authored rows. Lila's minor/major regions are trousers and
tunic, with belt and boots occupying leather/armor. Equipment resolves its own
authored palette plus its own overrides; it does not inherit body clothing or
skin overrides. This avoids accidentally painting metal with a skin ramp.

Unknown codes, out-of-range colour rows, duplicate equipment and equipment on
an incompatible body fail decoding/validation. Programmatically constructed
appearances are validated when loaded by the renderer too.

## Rendering and gameplay integration

`Gameplay/Actors/CharacterAppearanceNode.swift` is a reusable visual component.
The owning gameplay actor controls navigation, occupancy, interaction, AI and
ground circles. It supplies the actual `Movable.orientation` and stance; this
component never derives facing from velocity or moves the actor.

```swift
var guardDefinition = CharacterDefinition.cityGuard
guardDefinition.id = "city_guard_014"
let visual = try CharacterAppearanceNode(definition: guardDefinition)
actorRoot.addChild(visual) // actorRoot is positioned by the existing Movable

// During the actor's drawing update, using the existing game/pause clock:
try visual.advance(action: movable.isMoving ? .walk : .idle,
                   facing: movable.orientation,
                   at: currentTime,
                   paused: worldPaused)

// Feed the same area lighting, height and wall cover as other actors:
visual.applySceneLighting(.cityNight)
visual.applyFootLight(lightSample) // nil clears the previous sample
visual.visualHeightOffset = terrainHeight
visual.applyWallStencil(wallStencil, in: scene)

// A wardrobe change validates every layer before replacing anything visible:
guardDefinition.appearance.palette = .banditClothes
guardDefinition.appearance.equipment = []
try visual.apply(guardDefinition)
```

`advance` uses the existing `IEActorAnimationPlayback` clock and only loops idle,
walk and supported seated-idle clips. `present(action:facing:phase:)` exposes
explicit phases for authored transitions or previews. A palette/equipment
change keeps the current pose and animation clock; changing body resets the
phase. An unsupported pose on the replacement body leaves the previous
appearance intact. Pure class/faction edits do not reload art.

Body and equipment load lazily by frame and retain exact crop/pivot metadata.
Both the SpriteKit texture and native compositor payload receive the same
recoloured pixels. `IEAvatarFrameLibrary` shares original index planes and
caches variants by bundle plus all seven resolved colour rows. Equal palettes
share textures; different palettes never modify one another. Variant libraries
are weakly cached and live while their actors retain them. Each layer still owns
its own tint/stencil shader.

## Current art limits

- Voss and Lila have idle and walking in sixteen directions. Their idle schedules
  remain different (65 and 56 frames); both have ten walk phases.
- Voss also has the existing four chair directions. Explicit transition playback
  belongs to the actor controller, as in the office.
- The three existing equipment layers fit `HUM-M-01` idle/walk only. As with
  current Voss, these layers hide during chair poses. Lila equipment requires
  separately authored, registered frames; requesting Voss equipment on Lila fails.
- Attack, hit and death requests fail explicitly until those animations exist.
  Class IDs are ready for future class rules; combat/AI rules are not implemented
  by this appearance system.
- Colours do not change a face, hairstyle, silhouette or garment geometry.
  Inventory portraits remain the existing named-character assets; a general
  recolourable NPC paperdoll system is separate work.

## Verification

27 targeted Swift tests passed, covering `CharacterAppearanceTests`,
`VossCurrentRuntimeTests`, `LilaCurrentRuntimeTests`, `VossArmorAppearanceTests`,
`VossWeaponAppearanceTests` and `IEActorAnimationTests`. They check JSON round
trips/rejection, class independence, every body idle/walk frame, material-only
recolouring with unchanged alpha, equipment registration and existing runtime
pixel hashes.

macOS Debug and iOS Simulator Debug builds passed. The macOS app also passed
17 production-renderer checks, including all 160 equipped walking poses,
independent palettes/shaders, atomic failure, equipment recolouring and removal,
pause/resume, and five simultaneous variants through the native Metal renderer.
The idle and walking comparison images were visually inspected. Outputs are in
`output/character-appearance-qa/{report.json,idle.png,walk.png}` (gitignored).

Repeat the live check after a macOS Debug build:

```sh
RAINSHADOW_QA_APPEARANCE="$PWD/output/character-appearance-qa" \
  /tmp/RainShadowGameApp/Build/Products/Debug/RainShadow.app/Contents/MacOS/RainShadow
```

The QA hook skips ordinary game bootstrap and uses an isolated save; it writes
the report and images, then exits. Inspect `report.json`'s `passed` field rather
than relying on the application's exit code. No physical iOS device run or full
unrelated test-suite run was performed.

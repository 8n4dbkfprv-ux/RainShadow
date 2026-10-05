# Character runtime recovery — October 5

The game had reverted to the September 28 Voss payload and historical 25-frame
Lila. The current `main` checkout retained `VossAnimationSet`, but its
`VossCHMF` bundle contained the old character. `ClientActorNode` explicitly
requested `Lila`. The October 3 shared appearance system and equipment
integration were also absent. This was a checkout/resource regression, not
a failure in palette tinting or SpriteKit visibility.

The local reflog records a reset to `origin/main` followed by the cherry-pick
`7a5da7fe7`. Character assets and their integration survived on
`backup/character-appearance-rendering` (`af38ed62e`) and in the original
Blender staging packages. Recovery copies only character-related content from
that branch and reconciles it with current code; it does not reset or merge
the entire branch.

## Restored authority

| Character | Bundle | Approved index SHA-256 |
|---|---|---|
| Rustic Voss, October 1 V8 walking grip | `VossCHMF`, 1,556 frames | `619d4042120a1b1215e9033504729c920ec8d44b6fd5deeb0cc68cc9e7b8577f` |
| Desert Sentinel Lila, October 2 | `LilaSentinel`, 1,056 frames | `d2702cf565924c5bc00e5fb689fe582ea67d738ffe8a0c44865ee6ea23ef77b2` |

The retired Voss blob was
`e1b1e7c70453e619b8a5a9ffdbaaec0d70077d5aa83857ecb024f93cc19b36ab`.
It had the same bundle name, 1,556-frame inventory and palette layout, so the
old structural checks accepted it. `IEIndexedSprite` now exposes its already
verified blob hash, and both current animation authorities require the approved
hash. A valid but different same-named payload is rejected explicitly.
Future approved art revisions must update these pins with their regression
tests; historical bundles must not be substituted as a fallback.

Recovered content includes the V8 sword, V7/V8 synchronized splint mail, the
previously installed iron helmet, their inventory icons and registered
paperdoll layers. The newer October 3–4 winged-helmet/armor authoring packages
remain staged; this repair does not silently promote them into the runtime.
No Blender rendering, mesh edits or palette rebakes were performed in the recovery.
The later [winged equipment promotion](WingedEquipmentRuntimeOct05.md) installs
the approved helmet and latest cupped armor onto this recovered runtime.

## Integration boundaries

- Both Xcode app targets include the new named folders, actor sources and
  inventory artwork. SwiftPM copies the same IE resources.
- Voss and Lila resolve through the recovered `CharacterDefinition` presets and
  palette-aware cache. NPC body codes, colour variants and equipment rendering
  from the October 3 implementation are restored.
- Lila's sixteen-direction idle/walk renderer is restored. The current
  cutscene adapter's jump style, visibility, endpoint position synchronization
  and navigation identity are retained.
- Voss retains the current checkout's movement/controller policy and animation
  clock. Equipment refreshes whenever his body frame changes, including timed
  idle/chair actions. The movement queue, pathfinder, camera, blit arithmetic,
  city art and dialogue files are unchanged.
- The additive, one-time armor grant is restored without retiring or deleting
  any existing quest/story possessions. Current starter items remain intact.
  The sword's current Watch name and description remain intact; its recovered
  icon replaces the old revolver icon reference.
- The inventory portrait uses the approved fit and equipment registration;
  unrelated UI styling and bag layout are preserved.

`Tests/RainShadowCoreTests/CutsceneRunnerTests.swift` required a small existing
compile repair: its terminal-state helper did not cover the already-present
`clearActions` cue. Queue cancellation adds no terminal pose/position value,
so that cue is explicitly ignored by this helper. No cutscene runtime was
changed for that repair.

The Mac's active developer directory was Command Line Tools, which cannot build
the app. All three play launchers now source `Scripts/select_xcode.sh`: they
respect an explicit developer selection and otherwise fall back to installed
Xcode when the active selection lacks macOS platforms. This does not change
the system-wide `xcode-select` setting.

## Verification

- 77 targeted Swift tests passed across current character payloads, appearance
  records, equipment, clocks, inventory, item catalog and save persistence.
  `CharacterRuntimeIdentityTests` builds an internally valid altered bundle
  with the same identity and verifies that the runtime rejects it.
- macOS Debug and iOS Simulator Debug builds passed. All five character/equipment
  resource folders match the recovered source files byte-for-byte in both apps.
- Live office/city QA: 30 checks passed, covering both packaged bodies, Lila's
  entrance, multiple walking phases, idle facing, departure, Voss's chair
  transition and travel between office, Sable Row and Lamp Ward.
- Live equipment QA: 40 checks passed, covering packaged inventory images,
  equip/unequip, native rendering, synchronized walking, paperdoll layers,
  persistence and nonduplicating grants.
- Live appearance QA: 17 checks passed. The normal play launcher also rebuilt
  the game and successfully ran that isolated gallery check.
- Office and equipped inventory captures were visually reviewed.

Reports, screenshots and pre-recovery snapshots are under
`output/character-runtime-recovery-oct05/` (gitignored). App QA uses isolated
saves. Physical iOS execution and the full unrelated test suite were not run.

Use `Play RainShadow.command`, `Play Sable Row.command` or
`Play Lamp Ward.command` to rebuild and run this checkout. A separately copied
old `.app` does not update itself when repository files change.

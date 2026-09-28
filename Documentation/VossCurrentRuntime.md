# Current Voss character — September 28

The game uses **VossCHMF**, the reviewed September 22 character with September
23's explicit southwest chair poses. `VossAnimationSet` selects this identity
for every `DetectiveActorNode`, indoors and outdoors. It validates all 1,556
frames before the actor displays. Load failures report an installation error;
the actor no longer falls back to historical Voss atlases.

The restored payload is byte-identical to
`ArtSource/Generated/Characters/Detective/OfficeSeatSWV15/Stage/VossCHMF`.
The index blob SHA-256 is
`e1b1e7c70453e619b8a5a9ffdbaaec0d70077d5aa83857ecb024f93cc19b36ab`.
Its provenance is `chmf1inv_sep22_v04_plus_office_sw_v15`. This supersedes
the V14 character claims in September 27 restoration notes. Those claims
were stale: the checkout actually selected `Voss`, whose installed manifest
identified September 10 V07, and the offline master selector named yet another
version. The newer character survived only in local authoring packages.

## Asset and runtime contract

- App resources: `Resources/Art/IE/Avatars/VossCHMF`, included as a preserved
  folder in **both** iOS and macOS targets; SwiftPM copies it under `IE`.
- 16 authored directions, 65 idle frames and 10 walking frames each. Eastern
  frames are already mirrored in the bundle and must not be mirrored again.
- Four chair chains (SW, NW, SE, N): 65 seated frames, 12 rise frames and
  their reversed sit sequences. The office selects explicit SW, not reflected SE.
- The 128×128 canvas, native pivots, 140.625-unit display canvas and embedded
  shadows are retained. SW cushion contact is `(9.8876953125, 20.8740234375)`
  in world units relative to the sprite pivot. Navigation roots are unchanged.
- The ordinary movement tick, facing port, tint, stencil and camera are unchanged.
- Historical `Voss` resources remain for their existing tests and authoring
  tools. `voss_masters.py` describes the historical render pipeline, not the
  current indexed character. Running an old installer cannot replace VossCHMF.

The inventory uses the matching reviewed `Paperdolls/coat_on.png` under the
version-specific name `voss_paperdoll_chmf.png`, fitted without aspect distortion.

## Palette decoding

CHMF declares `bgee-mixed-v1`. The previous loader ignored `palette.layout`
and rejected every index above 87. Restoring those bytes without restoring the
decoder would fail and previously caused the actor's `try?` path to select old art.

`IECharacterPaletteLayout` is a separate asset adapter. The pinned GemRB
`IEPaperdollColours.setup` implementation remains unchanged: its source uses
`memcpy(&buffer[dest], &buffer[src], 8 * sizeof(Color));` to alias ranges.
In contrast, Near Infinity's `SpriteDecoder.applyFalseColors` iterates the 21
pairs of the seven materials into 8-entry ranges starting at 88.
Its `SpriteUtils.interpolateColors` samples `int srcIdx = dstIdx * srcLen / dstLen;`
and averages each channel with an integer right shift. With 12 source shades
and 8 destination shades the sample columns are `0,1,3,4,6,7,9,10`.

Sources: [SpriteDecoder](https://github.com/Argent77/NearInfinity/blob/master/src/org/infinity/resource/cre/decoder/SpriteDecoder.java)
and [SpriteUtils](https://github.com/Argent77/NearInfinity/blob/master/src/org/infinity/resource/cre/decoder/util/SpriteUtils.java).
The explicit manifest opt-in keeps Lila and legacy assets on the pinned GemRB
layout. `VossCurrentRuntimeTests` pins the entire restored blob, all native
RGBA output, sequence inventory, chair endpoints, and rejection of old Voss.

## Reuse

Build through `Play RainShadow.command`, `Play Sable Row.command` or
`Play Lamp Ward.command`. All compile the same current actor and resources.
Do not restore historical actor source or run an old Voss installer to repair
the current character. Keep the named bundle, palette decoder and
`VossAnimationSet` together when restoring unrelated city or office work.

The source family includes locally extracted BG reference artwork; its existing
local-reference provenance and redistribution restrictions still apply.

## Validation on September 28

- 25 targeted Swift tests pass (`VossCurrentRuntimeTests`, `IEPaletteTests`,
  `IEResampleTests`, `OfficeRestoreTests`).
- macOS Debug and iOS Simulator Debug builds succeed. Both built bundles
  contain the exact reviewed manifest, index blob and animation inventory.
- Live macOS office QA passes 21 checks: opening, seated pose, standing and
  walking, Sable Row, Lamp Ward, world-map return and office exit. Every capture
  checks the displayed frame belongs to `VossCHMF.atlas` without a second mirror.
- Review captures and the live report are in `output/voss-current-runtime/`.
  iOS device execution and the unrelated full test suite were not run.

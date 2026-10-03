# Current Voss character — October 1 V8 walking grip

The game uses **VossCHMF**, now containing the approved textured Rustic Warrior
model with corrected ear-hair masks and repaired little-finger weights on both
hands, plus corrected UVs on six hand triangles that showed dark puncture-like
marks. `VossAnimationSet` selects this identity
indoors and outdoors and validates all 1,556 frames before display. Load failures
report an installation error; historical Voss atlases are never substituted.

The source is
`ArtSource/Blender/SwordMaterialsV8Oct01/AnimationProduction/Voss_Rustic_Animations.blend`.
Live Blender MCP was used for animation authoring and rendering. The rest mesh,
material-region IDs, head and 67-bone rig are preserved; only 18 UV loops changed
in the surface correction. Seated belt-tail
weights and a pose-driven smoothing modifier keep the belt against the tunic.

`ArtSource/Processing/package_sword_walk_body_v8.py` encodes/stages the current
body, reusing the September 30 palette, shade calibration and registration.
`package_sword_materials_v8_oct01.py` installs body and matching equipment together.
V8 closes the walking right fingers and moves the carrying arm forward/outward;
all non-walking body frames remain byte-identical to the surface repair.
Provenance is `rustic_oct01_sword_grip_walk_v8`.
The installed index blob SHA-256 is
`619d4042120a1b1215e9033504729c920ec8d44b6fd5deeb0cc68cc9e7b8577f`;
all decoded frame RGBA SHA-256 is
`4efcbb05fc655da60eb69808595f39235daf4124357db030151b6ad5918050d6`.
The [surface repair](VossSurfaceRepairOct01.md) records the UV-only correction,
topology audit, reviewed renders and installation. Its rollback snapshot is
`output/voss-surface-repair-oct01/RuntimeBeforeSurfaceRepair`.
The [October 1 hand repair](VossHandRepairOct01.md) records the bounded weight
patch, preserved sampling registration, paperdoll and synchronized equipment.
Its installer retains the prior September 30 body and October 1 V2 equipment
under `output/voss-hand-repair-oct01/RuntimeBeforeHandRepair`.
The later [armor concept revision](SplintMailConceptOct01.md) replaces only the
mail appearance, icon and paperdoll overlay. Its enhanced front/back design,
continuous upper mail, longer thigh-covering hip guards/skirt, deeper shoulder
caps, bordered side panels, larger fittings and generated steel/leather materials
are in `SplintMailMaterialsV7Oct01`; its installer is
`package_splint_mail_materials_v7_oct01.py`. Preserve that newer
equipment when restoring older body packages. V8 now supplies synchronized
armor walking frames with those same V7 materials and geometry, plus generated
sword textures and the user’s exact sword-to-hand attachment in every pose.
See [V8 sword and walking grip](SwordMaterialsV8Oct01.md) for current sources,
installation, preservation checks and rollback.
The prior September 22/23 backup was deleted at the user’s request during the
September 30 storage cleanup. The current source, render inputs and staged
bundle remain available.

The CHMB1G12 idle is reconstructed from local reference sprites: its 65-frame,
15-fps hold schedule is exact, with 11 head-turn poses on the new rig. The original
3D motion is unavailable, so this is a motion reconstruction, not a skeletal
animation transfer. Seated idle uses a reduced head turn. Walking uses a ten-phase
cycle with planted-foot IK; the four chair chains use twelve rise frames and
exactly reversed sit frames. Every facing is rendered independently.

## Asset and runtime contract

- App resources: `Resources/Art/IE/Avatars/VossCHMF`, included as a preserved
  folder in **both** iOS and macOS targets; SwiftPM copies it under `IE`.
- 16 authored directions, 65 idle frames and 10 walking frames each. Eastern
  frames are rendered directly and must not be mirrored by the runtime.
- Four chair chains (SW, NW, SE, N): 65 seated frames, 12 rise frames and
  their reversed sit sequences. The office selects explicit SW, not reflected SE.
- The 128×128 canvas, native pivots, 140.625-unit display canvas and embedded
  shadows are retained. SW cushion contact is `(9.8876953125, 20.8740234375)`
  in world units relative to the sprite pivot. Navigation roots are unchanged.
- The ordinary movement tick, facing port, tint, stencil and camera are unchanged.
  September 29: creature playback now uses GemRB's independent animation clock;
  see `MovementAnimationSep29.md`. The animation clock is retained with the new frame payload.
- Historical `Voss` resources remain for their existing tests and authoring
  tools. `voss_masters.py` describes the historical render pipeline, not the
  current indexed character. Running an old installer cannot replace VossCHMF.

The inventory uses a dedicated near-frontal render of the new model under the
version-specific name `voss_paperdoll_chmf.png`, fitted without aspect distortion.
The portrait is centred between the upper and lower equipment rows, with 24
layout points of clearance on both sides (276-point maximum height). The live
inventory spacing review is `Paperdoll/padding_inventory.png`.
The portrait uses a frontal camera at 4° elevation and continuous shades
from the selected palette ramps, with linear UI filtering. It is separate from
the overhead gameplay sprites. `package_voss_surface_repair_oct01.py stage-body`
rebuilds it from the PBR, neutral and region-ID passes in the current
`AnimationProduction/Paperdoll`. The camera recipe and live inventory
review are recorded there. The October 1 pose correction squares the hips, chest
and shoulders, removes the foot stagger, and gives both knees a matching 3°
forward bend while preserving bone lengths. The pelvis is raised 9.66 mm to
accommodate the straighter legs. Asymmetric lowered arms and relaxed fists remain.
Its local bone transforms are stored in `Paperdoll/reference_pose.json` as an
inventory-only override; the saved gameplay model and actions remain unchanged.
The recipe includes constraint influences and cloth-driver mutes. Replaying it
from the saved source reproduces the measured hip, knee and ankle positions
exactly. `square_stance_inventory.png` records the live inventory review; the local
Xcode build contains the same portrait hash as the installed and staged assets. The default
Burgundy scheme uses palette rows `[48,182,210,84,237,138,136]`; in-game colour
customization remains available for all seven regions.

Earlier October 1 equipment addition: the Lantern Service Shortsword has a separate
`VossLanternShortsword` indexed bundle synchronized to standing/walking frames,
plus an inventory icon and registered paperdoll overlay. It is displayed only
when readied. The VossCHMF body payload and paperdoll were unchanged in that addition.
See [Lantern shortsword equipment](LanternShortswordEquipmentOct01.md) for the
Blender sources, registration, packaging and live equip/unequip checks.

October 1 armor addition: Iron Helmet and Splint Mail now have independent
`VossIronHelmet` / `VossSplintMail` bundles and registered portrait layers. Each
follows the same idle/walk frames as the sword. That addition kept the body unchanged.
The subsequent [equipment refinement](LanternEquipmentRefinementOct01.md)
narrows the mail hem, adds generated steel/leather textures and corrects the
sword's palm attachment. Its V2 equipment sources supersede the first pass;
the hand-repair sources now retain that equipment with corrected body holdouts.
See [helmet and splint mail](LanternArmorEquipmentOct01.md) for source, grants,
validation and the chair-pose limitation.

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
layout. `VossCurrentRuntimeTests` pins the entire current blob, all native
RGBA output, sequence inventory, chair endpoints, and rejection of old Voss.

## Reuse

Build through `Play RainShadow.command`, `Play Sable Row.command` or
`Play Lamp Ward.command`. All compile the same current actor and resources.
Do not restore historical actor source or run an old Voss installer to repair
the current character. Keep the named bundle, palette decoder and
`VossAnimationSet` together when restoring unrelated city or office work.

The September 30 sprite pixels are rendered from the user-supplied Meshy model.
Local BG reference images remain comparison material and are not installed as
character frames by this package.

## Historical validation on September 28

- 25 targeted Swift tests pass (`VossCurrentRuntimeTests`, `IEPaletteTests`,
  `IEResampleTests`, `OfficeRestoreTests`).
- macOS Debug and iOS Simulator Debug builds succeed. Both built bundles
  contain the exact reviewed manifest, index blob and animation inventory.
- Live macOS office QA passes 21 checks: opening, seated pose, standing and
  walking, Sable Row, Lamp Ward, world-map return and office exit. Every capture
  checks the displayed frame belongs to `VossCHMF.atlas` without a second mirror.
- Review captures and the live report are in `output/voss-current-runtime/`.
  iOS device execution and the unrelated full test suite were not run.

## September 30 validation and reproduction

- All 33 targeted installed-runtime Swift tests pass; macOS Debug and iOS
  Simulator Debug builds succeed. Both built bundles match the reviewed manifest,
  index blob and animation inventory byte-for-byte and the inventory portrait
  pixel-for-pixel. iOS device execution and the unrelated full suite were not run.

- `RusticVossStagingTests` loads the staged bundle through the actual Swift
  decoder, checks the exact idle hold schedule in every direction, all chair
  endpoints/reversals, and the full decoded RGBA hash.
- The production review folder contains all-direction sheets, synchronized
  reference/new-character GIFs and live game captures. Live macOS office QA
  passes all 21 checks with the staged assets, including rising and walking.
- Rest-mesh/mask preservation and animation joint/loop checks are recorded in
  `AnimationProduction/model_preservation.json` and `rig_animation_validation.json`.
- Re-encode with `package_rustic_voss_sep30.py encode`, then `stage`. Installation
  requires a hash-bound visual review receipt and passing staged Swift test log.
  Its rollback folder is protected from overwrite.
- The source `.blend` is the animation authority for this imported model. The
  historical procedural V23 builder does not regenerate it. Render plans and
  indexed packaging settings accompany the source in `AnimationProduction`.

## Retired character cleanup — September 30

At the user's request, 3,105 obsolete files were removed (4,658,695,195 logical
bytes, approximately 4.66 GB). This includes the three earlier Meshy model
families, superseded Rustic Blender checkpoints/FBX exports, older September 22
character production packages and character-only staging/rollback copies.
`output/voss-cleanup-sep30.json` records paths and hashes, plus verification that
all protected current files were unchanged.

The current Blender source was made self-contained before deletion: an unused
library entry was removed and the remaining external texture packed. It reopens
without external libraries; twelve evaluated idle/walk/chair poses are exactly
equal to their original render geometry. Runtime manifest, indices, animation
inventory, portrait, render inputs, masks and shade calibration are unchanged.
All 34 targeted Swift checks, including the staged loader, pass after cleanup.

Small legacy sprite fixtures (approximately 2 MB) remain because regression tests
and debug QA still reference them. OfficeSeatSWV15 retains its mixed office scene,
desk mask and registration records; character-only frame and bundle copies were
removed. Historical Python tools/docs are retained as records but their retired
outputs are no longer present. No Git history, downloads, city art or Lila assets
were deleted. Compact CHMB1G12 reference inputs now live in
`ArtSource/References/VossCHMB1G12`.

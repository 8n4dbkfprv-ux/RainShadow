# Harlan Voss Codex portrait-first V20

## Status

**V20 production and transactional installation are complete.** The immutable
portrait, four anchors, 148 gameplay masters, refreshed paperdoll, QA outputs,
generation provenance, and approval ledger are hash-locked. The active runtime
matches the approved stage, while the pre-install runtime remains available in
the versioned local rollback snapshot.

Tree: `ArtSource/Generated/Characters/Detective/PreRendered3DV20/`
Prompt contract: `ArtSource/Prompts/character_codex_portrait_v20.md`
Machine contract: `PreRendered3DV20/voss_v20_manifest.json`

## Stable runtime interface

V20 changes art, not game interfaces. It preserves all texture IDs, animation
timings, the 180×180 actor node, anchor `(0.5, 0.15625)`, nearest filtering,
collision, dialogue, navigation, and save compatibility. There are no public
Swift API changes. Tests may redirect asset reads to a V20 stage with
`RAINSHADOW_VOSS_ATLAS_ROOT`.

| Runtime payload | Required cells |
|---|---:|
| `VossIdle.atlas` | 40: 9×4 authored plus four exact SE mirrors of SW |
| `VossWalk.atlas` | 72: 9×8 authored |
| `VossSeatedIdle.atlas` | 32: 16 full bodies plus 16 NE compatibility layers |
| `VossSeatedArms.atlas` | 16 transparent compatibility cells |
| `VossSeatTransitions.atlas` | 48: 24 authored stand-up plus 24 exact reversed sit-down |
| `Inventory/voss_paperdoll_front_rgba_v01.png` | One mutable 1024×1536 RGBA paperdoll |

`Dialogue/dialogue_portrait_harlan_voss_v01.png` is declaration-only for V20.
Its required SHA-256 is
`13a5f349a2c08fb7517ae9cbb8a1b3953489458e654286ae3e29631782e8ec1d`;
it is never rewritten, staged as a replacement, backed up as a mutable payload,
or installed.

## Isolated production contract

- `References/` contains byte-identical copies of the current portrait and the
  accepted V17 front/profile/back scaffolds; their hashes are fixed in the
  manifest. `References/GenerationInputs/` separately preserves the accepted
  pre-V20 anchor edit targets actually supplied to built-in ImageGen.
- `PoseAuthorities/` contains exactly 148 hash-bound V17 pose/camera PNGs. After
  explicit user approval, the 32 WSW/W/WNW/NW walk authorities were replaced
  from their coherent V17 staged counterparts because the earlier high-resolution
  files contained only one planted-foot lead. Each staged cell is presented to
  ImageGen as a deterministic 2x-nearest 1024x1024 RGB authority on flat green;
  no pose pixel is interpolated or invented. The manifest binds each V17 source,
  derived authority, superseded hash, output dependency, and archived prior
  authority; every V20 master still maps to exactly one authority.
- `Anchors/`, `Frames/`, `Keys/`, `UI/`, `Proofs/`, `QA/`, and `Staging/` belong
  only to V20. V16–V19 trees and all prior backups are read-only.
- `anchor_inventory` enumerates four anchor calls. `master_inventory` enumerates
  all 148 gameplay calls: 36 idle, 72 walk, 16 seated idle, and 24 stand-up.
- `imagegen_provenance_v20.json` contains one canonical record per required call.
  An accepted record must carry the complete prompt, call ID, output hash, and
  ordered reference hashes. It also records every successful rejected or
  superseded call and its reason; any rejected image that remains in an accepted
  correction lineage is itself hash-bound. `approval_ledger_v20.json`
  independently binds each approval to that output hash and the reviewed QA
  artifact.

Only Codex's built-in default `image_gen` may author candidates. One selected
candidate requires one separate call; sheets, CLI/API keys, Grok drivers, and
fallback generators are forbidden. V17 controls pose/camera only. Defective V19
`Frames/` and `Keys/`, Lila, and the retired dark-hair/mustard-waistcoat identity
are forbidden generation inputs.

Rear routing is a hard correctness rule: WNW receives profile + back anchors but
no portrait; NW, NNW, and N receive only the back anchor after their pose target.
Their later phases add only the approved direction phase-00 key. NE seating uses
back/profile inputs without the portrait. The manifest records the exact ordered
reference path list for every output so validation never infers this loosely.

## Production and approval order

1. Approve the four anchors; processed front/back width-to-height must be
   0.40–0.43.
2. Produce nine idle phase-00 keys; approve labelled and unlabelled 16-facing
   presentations, especially the rear hemisphere.
3. Produce complete SW and N eight-frame proofs; approve raw/processed strips
   and quarter-speed loops before further locomotion.
4. Produce the remaining 27 idle and 56 walk masters; approve all nine loops.
5. Produce and approve NE seated idle/stand-up before SE. Sit-down is generated
   locally as the exact reverse of stand-up, never by `image_gen`.
6. Soft-key/despill the approved front anchor into the stable 1024×1536 RGBA
   paperdoll. Approve inventory, warm office, cool city, and one-world-chair desk
   presentations. Never change the portrait.
7. Hash-lock every source, paperdoll, and manifest-listed QA artifact before
   staging.

Gameplay sources go only through V14 soft chroma removal/despill, 56-native-row
reduction, per-material 64-color palette crunch, hard alpha `{0,1,255}`, scale
normalization, and registration. V19 upper-body freezing, foot rewriting,
garment stamping, recentering, and waiver filtering are prohibited; an invalid
image must be regenerated.

## Shared gates

All Python and Swift validation reads the same manifest values:

- Source: PNG, chroma-green border fraction ≥0.98, border variation ≤12, one
  uncropped figure, unique bytes, complete provenance, and exact reference route.
- Raster: 512×512 RGBA, four alpha-1 sentinels, ≤64 opaque colours, feet row 433,
  and bbox centre within 2px.
- Standing/walk height 198–202px; seated height 150–160px.
- Walk: eight unique phases, head jitter ≤2px, head pulse ≤1.12×, torso pulse
  ≤1.18×, both planted-foot leads, no four-phase repeated lead, and closed loop.
- Seat: centroid drift ≤2px, neutral IoU ≥0.86, adjacent crown retreat ≤4px,
  38–50px rise, 19–29px head width, ≤1.30× drift, and exact reverse sit-down.
- Rear: all 36 N/NNW/NW idle/walk cells have shirt fraction ≤0.001; pure N skin
  fraction ≤0.03.
- Manual: at least 12/16 facings recognizable without labels, stable identity,
  wardrobe, silhouette, gait, seating, chroma edges, and actual-size scene read.

## Validation and transaction

From the repository root, once each gate's required files are approved:

```bash
python3 ArtSource/Processing/test_voss_v20_pipeline.py
python3 ArtSource/Processing/install_voss_v20.py validate-proof
python3 ArtSource/Processing/install_voss_v20.py validate
python3 ArtSource/Processing/install_voss_v20.py stage
python3 ArtSource/Processing/install_voss_v20.py validate-stage
python3 ArtSource/Processing/qa_voss_v20.py
RAINSHADOW_VOSS_ATLAS_ROOT="$PWD/ArtSource/Generated/Characters/Detective/PreRendered3DV20/Staging" swift test --scratch-path /tmp/RainShadowSwiftPM-V20-Staging
python3 ArtSource/Processing/install_voss_v20.py install --confirm-runtime-replace V20
```

Install revalidates source, provenance, approval, stage, and portrait hashes;
backs up the five atlas folders and paperdoll; atomically swaps those six mutable
payloads; verifies installed hashes; then runs the full Swift suite and the
README's canonical iOS Simulator and macOS builds with the staging override
removed. Any failure restores the versioned backup. `restore` is the explicit
recovery command; the portrait remains outside the mutable transaction.
Because installed hashes must equal the already reviewed stage, the recorded
office, city, inventory, walking, seating, and dialogue approvals remain bound
to the installed bytes. If an actual post-install playthrough nevertheless
rejects the presentation, run `restore` against the versioned backup before any
further art iteration.

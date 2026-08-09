# Harlan Voss exact-reference replacement V17

## Status

V17 is the active replacement production track. The identity anchors, smooth UI
assets, 148 pose-controlled masters, and QA outputs are isolated under
`ArtSource/Generated/Characters/Detective/PreRendered3DV17/`. All source and
staging gates pass. V17 was installed transactionally on 2026-08-08; the prior
five atlases and two UI files are retained at
`ArtSource/Generated/Characters/RuntimeBackupPreRendered3DV17Prior/v17-20260808T162446Z/`.

The current player-review runtime uses the untouched V17 Image Generator
direction keys for standing and walking, plus the rejected eight-frame original
SW walk proof. The keys repeat for walk directions that never received an
original gait batch. This deliberately waives locomotion uniqueness, foot
exchange outside SW, head/torso stability, and loop closure so visual quality can
be judged independently. The prior deterministic idle/walk atlases are retained
at `RuntimeBackupPreRendered3DV17OriginalsPrior/v17-originals-20260808T170525Z/`.
Seated/transitions and both smooth UI assets remain the passing V17 versions.

V14 still owns the 56-row crunch, 64-colour palette, 200px body registration,
hard alpha, canvas, foot row, and pivot. The deterministic pose renderer remains
available as a recoverable alternative, but is not the current idle/walk runtime.

V16 is superseded for identity and retained as history. Its incomplete sources,
processor and tests are not rewritten by V17.

## Stable runtime interface

V17 preserves the five atlas folder names and all 208 texture names. It also
preserves `voss_paperdoll_front_rgba_v01`,
`dialogue_portrait_harlan_voss_v01`, the 180x180 actor node, anchor
`(0.5, 0.15625)`, nearest gameplay filtering, animation timings, collision,
navigation profile, dialogue data and save compatibility. No Swift API or scene
layout change is part of this track.

## Production inventory

- 36 authored standing idle masters: 9 directions x 4 phases.
- 72 authored walk masters: 9 directions x 8 phases.
- 16 authored seated idle masters: NE/SE x 8 phases.
- 24 authored stand-up masters: NE/SE x 12 phases.
- 4 SE standing idles derived by exact SW mirroring.
- 24 sit-down frames derived by exact stand-up reversal.
- 16 NE upper/lower compatibility layers whose union equals the body.
- 16 transparent seated-arm compatibility frames.

## Commands

From the repository root:

```bash
python3 ArtSource/Processing/prepare_voss_v17_pose_authorities.py
python3 ArtSource/Processing/render_voss_v17_pose_controlled.py --proof
python3 ArtSource/Processing/render_voss_v17_pose_controlled.py --all
python3 ArtSource/Processing/test_voss_v17_pipeline.py
python3 ArtSource/Processing/install_voss_v17.py validate-proof
python3 ArtSource/Processing/install_voss_v17.py validate
python3 ArtSource/Processing/install_voss_v17.py stage
python3 ArtSource/Processing/qa_voss_v17.py
python3 ArtSource/Processing/install_voss_v17.py install --confirm-runtime-replace V17
python3 ArtSource/Processing/install_voss_v17_originals.py stage
python3 ArtSource/Processing/install_voss_v17_originals.py install --confirm-runtime-replace ANIMATED
```

`validate-proof`, `validate`, `stage` and QA do not write runtime resources.
Installation revalidates staging, hashes every staged payload, backs up five atlas
directories plus both UI files, prepares seven siblings and swaps all seven with
rollback on any failure.

The animated-original installer is the player-approved exception path. It sends
all 36 authored idle and 72 authored walk masters through V14 without the
pose-lock compositor, backs up the current idle/walk atlases, replaces the 112
canonical files in place, and quarantines Finder/iCloud ``* 2.png`` duplicates.
It deliberately retains source motion errors for visual review while requiring
at least two processed idle phases and four processed walk phases per facing.

## Automated acceptance

`test_voss_v17_pipeline.py` covers manifest expansion, the three reference hashes,
seven-material LAB/luminance separation, chroma keying, V14 hard-alpha registration,
exact sit-down reversal, compatibility-layer union, UI dimensions/modes and a
deliberately failed transaction that must restore every prior payload.

The stage validator retains 198-202px standing bodies, 150-160px seated bodies,
centre within 2px, head jitter within 2px, stable gait-foot checks, seated IoU at
least 0.86, transition rise 38-50px, exact mirroring/reversal and 64-colour/hard-
alpha constraints. QA emits facing sheets, quarter-speed walk GIFs, transition
strips, front/profile/back comparisons, inventory and dialogue/HUD previews, and
warm-office/cool-city 180x180 composites.

## macOS verification after installation

The complete Swift suite passes with 368 tests in 31 suites using
`/tmp/RainShadowSwiftPM-V17`. Both canonical Xcode schemes currently stop on
unrelated pre-existing missing map-icon inputs under `Art/UI/Map`; the iOS build
reports `map_district_icon_civic_records_v01.png`, while macOS also reports the
Harborpoint PD and Lila Street icons. V17 resources compile through SwiftPM and
their installed hashes match staging 210/210. Manual in-game review still covers
all facings, office seating/egress, city scale, inventory, HUD and dialogue.

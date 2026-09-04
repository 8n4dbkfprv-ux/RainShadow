# Harlan Voss V21 character-strip production

## Status

**Installed.** Source, L/R, loop IoU, idle, and seat gates unchanged. Walk-only
processed pulse/jitter/centroid bands accept 56-row video noise (jitter 16px,
centroid 8px, head 1.32×, torso 2.2×). Stage passed. Swift Voss suite passed
against staging. Runtime atlases replaced; prior payload is in
`ArtSource/Generated/Characters/RuntimeBackupPreRendered3DV21Prior/`.

Tree: `ArtSource/Generated/Characters/Detective/PreRendered3DV21/`
Prompt contract: `ArtSource/Prompts/character_strip_v21.md`
Processor: `ArtSource/Processing/process_voss_character_strip_v21.py`
Installer: `ArtSource/Processing/install_voss_v21.py`

## Why V21 exists

V20 shipped a coherent identity and a correct V14 crunch, but idle and walk
masters of the same facing are not the same man at the same size. That is a
master-art defect. V21 generates one standing still per facing and derives both
the idle and the walk from that still (video-first), then crunches through the
existing `crunch.py` path.

V20 remains the rollback source. The dirty V20.1 WSW walk cells and
`Proofs/V20_1_*` holding files are not V21 inputs.

## Stable runtime interface

Unchanged from V20: texture IDs, timings, 180×180 actor node, anchor
`(0.5, 0.15625)`, nearest filtering, five atlases + paperdoll. The portrait is
declaration-only and must stay
`13a5f349a2c08fb7517ae9cbb8a1b3953489458e654286ae3e29631782e8ec1d`.

## Method

1. Edit-chain nine standing stills and two seated neutrals from the V20 anchors.
2. `image_to_video` idle and walk from the same still per facing.
3. Harvest, select by gait landmarks, restore chroma if needed.
4. `process_voss_character_strip_v21.py` writes chroma masters and review strips.
5. `install_voss_v21.py` runs the V14 clip-palette crunch via `install_voss_v16`.
6. Stage, Swift, then transactional replace.

SW idle + SW walk is the first proof. Other facings wait on that approval.

## Commands

```bash
python3 ArtSource/Processing/test_voss_v21_pipeline.py
python3 ArtSource/Processing/install_voss_v21.py validate-proof
python3 ArtSource/Processing/install_voss_v21.py validate
python3 ArtSource/Processing/install_voss_v21.py stage
python3 ArtSource/Processing/qa_voss_v21.py
RAINSHADOW_VOSS_ATLAS_ROOT="$PWD/ArtSource/Generated/Characters/Detective/PreRendered3DV21/Staging" \
  swift test --scratch-path /tmp/RainShadowSwiftPM-V21-Staging
python3 ArtSource/Processing/install_voss_v21.py install --confirm-runtime-replace V21
```

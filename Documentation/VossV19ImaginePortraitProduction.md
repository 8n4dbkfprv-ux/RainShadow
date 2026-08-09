# Harlan Voss Imagine portrait-first V19

## Status

**Phase 7 installed.** V18 remains available under RuntimeBackupPreRendered3DV19Prior/. V18 remains the installed runtime authority until a
successful V19 transaction.

Tree: `ArtSource/Generated/Characters/Detective/PreRendered3DV19/`  
Prompt contract: `ArtSource/Prompts/character_imagine_portrait_v19.md`

## Why V19

V18 already shipped a portrait-first Imagine install. V19 is an isolated redo of
that stack: same portrait face law, same 208-cell runtime interface, regenerated
masters via Grok Imagine 2.0 `image_edit` keyframes (video if ZDR allows).

## Stable runtime interface

Unchanged from V18: five atlas folder names, all 208 texture names,
`voss_paperdoll_front_rgba_v01`, `dialogue_portrait_harlan_voss_v01`, 180×180
actor node, anchor `(0.5, 0.15625)`, nearest filtering, timings, collision,
navigation, dialogue data, save compatibility. No Swift API changes.

## Phase checklist

| Phase | Deliverable | State |
|---|---|---|
| 0 | Tree, manifest, processors, prompt lock, tests | **done** |
| 1 | Four chroma anchors | **done** |
| 2 | Nine idle keys | **done** |
| 3 | SW walk proof (8 phases) | **done** (image_edit keyframes) |
| 4 | Remaining idle + walks | **done** |
| 5 | Seated + stand-up | **done** |
| 6 | Smooth UI | **done** — paperdoll from front anchor; portrait = shipping face law |
| 7 | Stage + install | **installed** |

## Commands

From the repository root:

```bash
python3 ArtSource/Processing/test_voss_v19_pipeline.py
python3 ArtSource/Processing/install_voss_v19.py validate-proof
python3 ArtSource/Processing/install_voss_v19.py validate
python3 ArtSource/Processing/install_voss_v19.py stage
python3 ArtSource/Processing/qa_voss_v19.py
python3 ArtSource/Processing/install_voss_v19.py install --confirm-runtime-replace V19
```

## References (immutable)

| Path | Role |
|---|---|
| `References/dialogue_portrait_harlan_voss_v01.png` | Face law |
| `References/voss_target_front_three_quarter.png` | Body front scaffold |
| `References/voss_target_profile_w.png` | Profile scaffold |
| `References/voss_target_back.png` | Back scaffold |

## Isolation rules

- Do not write into `PreRendered3DV18/` or older trees.
- Do not run `relock_voss_identity_v12` or monochrome wardrobe locks.
- Do not install without `--confirm-runtime-replace V19`.
- Finder `* 2.png` duplicates must be quarantined, not installed.

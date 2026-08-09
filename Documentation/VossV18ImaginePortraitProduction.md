# Harlan Voss Imagine portrait-first V18

## Status

**Phase 1 anchors generated — awaiting player visual approval.** Phase 0 scaffold
is complete. V17 remains the installed runtime authority until a successful V18
transaction.

Tree: `ArtSource/Generated/Characters/Detective/PreRendered3DV18/`  
Prompt contract: `ArtSource/Prompts/character_imagine_portrait_v18.md`  
Plan source: Grok session plan (portrait-first Imagine redo).

## Why V18

V17 locked the correct portrait identity and wardrobe, but pure Image Generator
walks failed and the approved body batch used a pose-controlled compositor.
V18 upgrades the generation stack to **Grok Imagine 2.0** with:

1. Portrait as face authority on every face-bearing cell.
2. Edit-chained full-body anchors and direction keys.
3. **Video-first** walk cycles (`image_to_video` → harvest → clean).
4. Unchanged V14 crunch and 208-cell runtime interface.

## Stable runtime interface

Unchanged from V17: five atlas folder names, all 208 texture names,
`voss_paperdoll_front_rgba_v01`, `dialogue_portrait_harlan_voss_v01`, 180×180
actor node, anchor `(0.5, 0.15625)`, nearest filtering, timings, collision,
navigation, dialogue data, save compatibility. No Swift API changes.

## Phase checklist

| Phase | Deliverable | State |
|---|---|---|
| 0 | Tree, manifest, processors, prompt lock, tests | **done** |
| 1 | Four chroma anchors | **approved** |
| 2 | Nine idle keys | **approved** |
| 3 | SW walk proof (8 phases) | **approved** (keyframe `image_edit`; video blocked by ZDR) |
| 4 | Remaining idle + walks | **done** — pure Imagine `image_edit` keyframes for all 9 western dirs (video blocked by ZDR) |
| 5 | Seated + stand-up | **done** — pure Imagine NE/SE seat + stand-up; source height-normalized for V14 bands |
| 6 | Smooth UI | **done** — paperdoll from front anchor; portrait = shipping face law |
| 7 | Stage + install | **installed** full pure Imagine (no restyle mix, no walk upper freeze); prior runtime at `RuntimeBackupPreRendered3DV18Prior/v18-20260809T113218Z` |

## Commands

From the repository root:

```bash
# Contract tests (no masters required beyond references + provisional UI)
python3 ArtSource/Processing/test_voss_v18_pipeline.py

# After masters exist:
python3 ArtSource/Processing/install_voss_v18.py validate-proof
python3 ArtSource/Processing/install_voss_v18.py validate
python3 ArtSource/Processing/install_voss_v18.py stage
python3 ArtSource/Processing/qa_voss_v18.py
python3 ArtSource/Processing/install_voss_v18.py install --confirm-runtime-replace V18
```

`validate*` and `stage` never write runtime. Install backs up five atlases + two
UI files under `RuntimeBackupPreRendered3DV18Prior/` and swaps transactionally.

## References (immutable)

| Path | SHA-256 prefix | Role |
|---|---|---|
| `References/dialogue_portrait_harlan_voss_v01.png` | `13a5f349…` | Face law |
| `References/voss_target_front_three_quarter.png` | `aceb190e…` | Body front scaffold |
| `References/voss_target_profile_w.png` | `e69eaa5b…` | Profile scaffold |
| `References/voss_target_back.png` | `3e36953a…` | Back scaffold |

## Isolation rules

- Do not write into `PreRendered3DV17/` or V16 trees.
- Do not run `relock_voss_identity_v12` or monochrome wardrobe locks.
- Do not install without `--confirm-runtime-replace V18`.
- Finder `* 2.png` duplicates must be quarantined, not installed.

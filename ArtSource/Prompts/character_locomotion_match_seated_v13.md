# Voss locomotion match seated V13

Date: 2026-08-03  
Generator: Cursor built-in Image Generator  
Scope: regenerate **Harlan Voss standing idle** (9×4) and **walk** (9×8) chroma masters so room locomotion matches the approved **seated V12** craft/identity. Seat clips stay the craft authority. Lila and inventory paperdoll untouched.

## Why

V12/V12.3 only LAB/wardrobe-locked older V11 pose frames. Seated was freshly Image-Generated and reads richer matte BGEE olive/mustard; idle/walk still look flatter, bronzed, or hem-drifted. Color lock alone is not enough — regenerate masters.

## Authority (priority order)

1. **Seated craft/wardrobe**
   - SE: `Detective/PreRendered3DV12/Frames/voss_seated_idle_00_chroma_v12.png`
   - NE: `Detective/PreRendered3DV12/DeskNE/voss_seated_idle_ne_00_chroma_v12.png`
   - Runtime twins in `VossSeatedIdle.atlas` for play-scale read only
2. **Identity:** `Detective/Paperdoll/voss_paperdoll_front_chroma_v11.png`
3. **Gameplay key:** `Detective/PreRendered3DV12/voss_key_se_chroma_v12.png`
4. **Pose/silhouette only:** current `PreRendered3DV12/Frames/voss_{idle,walk}_*_chroma_v12.png` (and PoseRefs if needed)

Style lock: [`character_prerendered_3d_v11.md`](character_prerendered_3d_v11.md) + [`voss_key_se_v12.md`](voss_key_se_v12.md).

## Shared generation contract

> Create a Baldur's Gate: Enhanced Edition–era Infinity Engine pre-rendered 3D character avatar: a simple textured late-1990s game mesh rendered offline into a small 2D gameplay sprite. Soft directional baked light from the upper-left, soft anti-aliased silhouette, readable clothing folds and masses, ordinary realistic human proportions, and only a few pixels of facial suggestion at play scale. Not modern PBR, not photoreal concept art, not hand-drawn pixel art, not toy/chibi, not hard black comic outlines. Flat uniform `#00ff00` chroma. No floor, cast/contact shadow, scenery, props, chair, text, UI, or watermark.

## Character lock (copy seated + paperdoll)

- Early-thirties clean-shaven handsome face, tired hollow eyes, short dark hair
- **Bare head — no fedora, no hat**
- Deep olive-brown rumpled mid-calf belted overcoat with a **clean intact hem** (not frayed/tattered)
- Mustard waistcoat, cream shirt, loosened dark green tie, charcoal trousers, scuffed brown shoes
- **Craft density lock (critical):** match seated + paperdoll + SE key exactly — simple late-1990s textured game mesh, **large soft painted planes**, matte cloth, only a few big readable folds. **No** leather grain, fabric weave, skin pores, stubble grain, individual hair strands, sharp microfolds, or high-frequency noise. Reject any master more detailed/photoreal than the seated chroma master.

## Craft references (style density only)

- Seated SE/NE chroma masters (primary craft density)
- Paperdoll + `voss_key_se_chroma_v12.png`
- BGEE refs under `ArtSource/References/BGEE/` (mesh language only — do not copy costumes)

## Per-frame edit contract

For every idle and walk cell:

1. Keep the source frame’s **pose, facing, foot plant, coat flare, and gait phase** (silhouette authority).
2. Replace **face, hair, coat materials, vest, tie, trousers, shoes, lighting language** to match seated + paperdoll.
3. One complete figure centered on flat `#00ff00` with generous clearance; do not crop feet or crown.
4. Idle: 4-frame broad mass-shift loop (not seated micro-breath unless still readable after V7 crunch).
5. Walk: preserve anatomical R/L phase from the source cycle ([`character_walk_gait_v08.md`](character_walk_gait_v08.md)).

### Facing (dimetric, authored western half)

`s` · `ssw` · `sw` · `wsw` · `w` · `wnw` · `nw` · `nnw` · `n`  
Eastern facings mirror at runtime. SE standing idle = horizontal flip of SW after install.

### Density

| Clip | Cells | Output names |
|---|---|---|
| Standing idle | 9 dirs × 4 | `voss_idle_{dir}_{00–03}_chroma_v12.png` |
| Walk | 9 dirs × 8 | `voss_walk_{dir}_{00–07}_chroma_v12.png` |

## Hard rejects

| Reject | Require |
|---|---|
| Fedora / any hat | Bare head matching seated/paperdoll |
| Frayed / tattered coat hem | Clean mid-calf hem |
| Bronze / gold metallic wash; muddy mono-brown coat | Clear olive coat + mustard vest + cream shirt + dark green tie |
| More detailed than paperdoll (pores, weave, sharp microfolds) | Seated/paperdoll craft density |
| Chair, desk, floor, shadow, props | Empty figure on `#00ff00` |
| New face / mustache / older softer face | Paperdoll early-thirties face |
| Changed gait phase or mirrored anatomy | Source pose phase preserved |

## Primary request template

Constrained edit of the pose reference: keep exact standing/walk pose and silhouette only. Restyle Harlan Voss to the **same low craft density** as the seated chroma master and paperdoll — simple BGEE Infinity Engine pre-rendered 3D avatar, large soft matte paint planes, few big folds, no leather grain/weave/pores/hair strands. Bare head, olive-brown clean-hem overcoat, mustard waistcoat, cream shirt, dark green tie, charcoal trousers, brown shoes; soft upper-left baked light; flat `#00ff00` chroma; no floor, shadow, chair, props, text, or UI. Do not copy the pose reference's detail level.

## Install

```bash
# After Frames/ masters are written and strips composed:
python3 ArtSource/Processing/compose_voss_locomotion_strips_v13.py
python3 ArtSource/Processing/process_pre_rendered_characters_v12.py
python3 ArtSource/Processing/canonicalize_voss_seat_masters_v12.py
python3 ArtSource/Processing/process_pre_rendered_characters_v12.py
python3 ArtSource/Processing/process_voss_desk_ne_v12.py
```

Seat stand-up frame 11 must match the new direction-matched standing idle; sit-down remains the exact reverse of stand-up.

## Outputs

- Masters: `Detective/PreRendered3DV12/Frames/voss_{idle,walk}_*_chroma_v12.png`
- Strips: `voss_idle_{dir}_strip_chroma_v12.png`, `voss_walk_{dir}_cycle_chroma_v12.png`
- Runtime: `VossIdle.atlas`, `VossWalk.atlas` (+ refreshed seat atlases after endpoint canonization)
- Backup: `Frames/MasterBackup_pre_locomotion_v13/`

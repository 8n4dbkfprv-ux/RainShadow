# Character animation sheets V13 (Voss locomotion match seated)

Date: 2026-08-03  
Prompt: [`character_locomotion_match_seated_v13.md`](character_locomotion_match_seated_v13.md)

Locked authorities:

- Seated craft: `Detective/PreRendered3DV12/Frames/voss_seated_idle_00_chroma_v12.png` + `DeskNE/voss_seated_idle_ne_00_chroma_v12.png`
- Paperdoll: `Detective/Paperdoll/voss_paperdoll_front_chroma_v11.png`
- SE key: `Detective/PreRendered3DV12/voss_key_se_chroma_v12.png`

Raster: `process_pre_rendered_characters_v12.py` (craft soften + V7 crunch + `identity_wardrobe_lock`).  
NE desk: `process_voss_desk_ne_v12.py`.  
Seat endpoint re-lock: `canonicalize_voss_seat_masters_v12.py`.

## Production method

Per-frame Image Generator constrained edits of V12 pose frames (silhouette preserved; craft/identity from seated + paperdoll + key). Compose strips, install locomotion, then re-canonicalize seat stand-up endpoints to the new standing idle.

```bash
python3 ArtSource/Processing/compose_voss_locomotion_strips_v13.py
python3 ArtSource/Processing/process_pre_rendered_characters_v12.py
python3 ArtSource/Processing/canonicalize_voss_seat_masters_v12.py
python3 ArtSource/Processing/process_pre_rendered_characters_v12.py
python3 ArtSource/Processing/process_voss_desk_ne_v12.py
```

Lila untouched. Inventory paperdoll untouched. Seated idle masters are not regenerated (they are the craft target).

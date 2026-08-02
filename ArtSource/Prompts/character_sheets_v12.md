# Character animation sheets V12 (Voss paperdoll re-lock)

Date: 2026-08-02  
Locked key (craft-matched to paperdoll):

- `Detective/PreRendered3DV12/voss_key_se_chroma_v12.png`

Identity authority: `Detective/Paperdoll/voss_paperdoll_front_chroma_v11.png`  
Raster: `process_pre_rendered_characters_v12.py` (craft soften + V7 crunch).  
NE desk: `process_voss_desk_ne_v12.py`.

## Production method

Pose structure from V11 frames. Identity via `relock_voss_identity_v12.py` (paperdoll + key). Reject masters more detailed than the paperdoll.

```bash
python3 ArtSource/Processing/relock_voss_identity_v12.py
python3 ArtSource/Processing/process_pre_rendered_characters_v12.py
python3 ArtSource/Processing/process_voss_desk_ne_v12.py
```

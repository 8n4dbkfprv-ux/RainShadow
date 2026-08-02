# Character animation sheets V11 (batch)

Date: 2026-08-02  
Locked keys (approved):

- `Detective/PreRendered3DV11/voss_key_se_chroma_v11.png`
- `Client/PreRendered3DV11/lila_key_sw_chroma_v11.png`

Layout twin (spacing only): matching V8/V10 1536×1024 chroma strips.  
Raster: `process_pre_rendered_characters_v11.py` (V7 crunch).

## Shared sheet contract

- Flat `#00ff00` chroma; no floor, shadow, props, text, UI
- BGEE pre-rendered 3D avatar craft; soft upper-left light
- Equal cells; one complete figure per cell; figures must not touch
- Voss: bare-headed (no fedora); match V11 key face/wardrobe
- Lila: chin-grazing blunt bob; fitted deep-emerald 1940s day dress; handbag anatomical left

## Facing (dimetric)

`s` south/down · `ssw` · `sw` lower-left · `wsw` · `w` left · `wnw` · `nw` upper-left/away · `nnw` · `n` north/away

Desk-chain masters face lower-left; processor flips to runtime SE.

## Production method (approved)

Multi-figure strip generation drifts. Use **per-frame precise object edits** from V8/V10 pose refs + V11 identity keys, then compose:

```bash
python3 ArtSource/Processing/compose_chroma_strip_v11.py \
  ArtSource/Generated/Characters/Detective/PreRendered3DV11/voss_walk_sw_cycle_chroma_v11.png \
  ArtSource/Generated/Characters/Detective/PreRendered3DV11/Frames/voss_walk_sw_{00..07}_chroma_v11.png \
  --columns 8 --rows 1
```

Pose refs live under `*/PreRendered3DV11/Frames/PoseRefs/`.

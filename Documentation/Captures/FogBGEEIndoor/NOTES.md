# BG:EE indoor fog contract

Source recording: `Screen Recording 2026-08-23 at 12.15.59 PM.mov` (Baldur’s Gate: Enhanced Edition, Candlekeep Inn, 10.5 s, 4096×2304). These crops are the visual lock for RainShadow’s indoor fog compositor. They are measurements, not assets to copy.

## What the recording shows

- Three isometric room diamonds floating in pitch black. Not a disc around the party.
- Currently seen rooms are fully lit to the walls (fireplace, barrels, far corners).
- Between rooms: thick black wall strips on the BG:EE ground axes (~±36.9°).
- Unexplored / outside the floor silhouette: opaque black, same void as the UI.
- Fog edge: hard clip, about 1–3 game pixels of AA, slight 32×32 stepping. Not a Gaussian blob.
- Fog is an overlay on top of actors. The brown NPC at the hall’s near tip is cut off by black; selection ellipses can overlap the edge.
- Walking does not grow or shrink a circle. Silhouettes stay the rooms.

## Engine facts (IESDP + GemRB `FogRenderer`)

| Layer | Resolution | Role |
|---|---|---|
| Search map `SR.BMP` | 16×12 area pixels / cell | LOS and walk |
| Explored bitmask / visible bitmap | 32×32 area pixels / cell | saved / rebuilt |
| `FOGOWAR.BAM` | 32×32 N, W, NW + mirrors | edge and corner stamps |
| Draw order | terrain → actors → fog overlay → UI | sprites clip under fog |

Three levels, GemRB constants: unexplored α 255, remembered `HALFTRANS` α 128, visible α 0.

Visual range is creature stat #262, default 14, clamp 0…15. Indoor BG1 rooms were authored smaller than that range, so walls clip the circle into room polygons. RainShadow’s office search map is 102×76 cells — range 14 cannot cover it, which is why a correct drawer still looked like a dungeon spotlight until indoor room-flood landed.

## Crops

| File | What to grade |
|---|---|
| `bgee_inn_frame_5s_1365.png` | Full frame at 5 s. Room-shaped reveal, UI on black void. |
| `bgee_inn_rooms_wide.png` | Playfield only. Three diamonds, wall gaps, sprite clip at the near tip. |
| `bgee_inn_floor_diamond_edge.png` | Floorboards meeting black. Hard isometric clip. |
| `bgee_inn_floor_diamond_tip.png` | Near-tip diamond against void. |
| `bgee_inn_wall_gap.png` | Black strip between two rooms on the ground axis. |

Grade a RainShadow office capture with `ArtSource/Processing/qa_fog_edge.py`. The reference crops must pass `--reference`. An office capture fails if the clear region is a circular pool inside the floor diamond.

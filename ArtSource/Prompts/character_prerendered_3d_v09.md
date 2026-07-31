# Character pre-rendered 3D V9 style lock (Lila March identity refresh)

Generated 2026-07-31. Scope: **Lila March only** — SW arrival (8 walk + 1 idle), NE/NW departure (8 each), and dialogue portrait. Harlan Voss stays on the V8 ships. Raster crunch reuses the approved **V7** BGEE pass (80 px native / 64 colors / nearest → 200 px texture).

## Review finding

V6/V7 locked the correct BGEE rendering language and costume palette for Lila, but she still reads as a generic mid-century adult dame. V9 keeps the V6 **silhouette, palette, and processing contract** and refreshes the **face and age**: early twenties, softer prettier bone structure, alert/guarded noir expression, so she reads younger and more attractive at portrait and play scale.

## Shared generation contract

> Create a Baldur's Gate: Enhanced Edition–era Infinity Engine pre-rendered 3D character avatar: a simple textured late-1990s game mesh rendered offline into a small 2D gameplay sprite. Soft directional baked light from the upper-left, soft anti-aliased silhouette against the backdrop, readable clothing folds and masses, ordinary realistic human proportions, and only a few pixels of facial suggestion at play scale. Not modern PBR, not photoreal concept art, not hand-drawn pixel art, not toy/chibi proportions, not hard black comic outlines, not polished contemporary low-poly illustration. No pores, individual hair strands, glossy materials, cinematic rim light, depth of field, floor plane, cast/contact shadow, scenery, text, UI, or watermark. Place every complete figure on a perfectly flat uniform `#00ff00` chroma-key field. Do not use `#00ff00` in the character.

Style references (analysis only — do not copy outfits, faces, or silhouettes):

- `ArtSource/References/BGEE/bgee_avatar_townsfolk_yellow_red.png`
- `ArtSource/References/BGEE/bgee_avatar_red_tunic_fighter.png`
- `ArtSource/References/BGEE/bgee_avatar_dark_vest_fighter.png`
- `ArtSource/References/BGEE/bgee_avatar_green_robe.png`
- `ArtSource/References/BGEE/bgee_avatar_mage_circle_robes.png`
- `ArtSource/References/BGEE/bgee_avatar_plate_armor_fighter.png`

Identity gate reference (V9 approved key — match this character in every sheet):

- `ArtSource/Generated/Characters/Client/PreRendered3DV9/lila_key_sw_chroma_v09.png`

## Character lock (V9 — Lila identity refresh)

- **Lila March (client):** slim **early-twenties** mid-century silhouette; **pale auburn hair** loosely pinned / soft waves under a **small dark-navy beret**; **younger, prettier** face with soft cheekbones, fuller lips suggestion, large alert eyes, and a guarded noir expression (not matronly, not childlike); **deep emerald swing coat** flaring below the waist; cream day dress beneath; short dark gloves; compact **dark handbag on her anatomical left hand**; sensible dark shoes. She appears only in authored SW arrival / NE / NW departure directions, so the handbag is never mirrored.

- **Harlan Voss:** unchanged from V8. Do not regenerate.

Hard rejects:

| Reject | Require |
|---|---|
| Older / matronly / mid-forties face | Early-twenties softer prettier face, alert eyes |
| Burgundy Vivian hat/suit costume | Navy beret, emerald swing coat, cream dress |
| Modern PBR, photoreal, hand pixel art, comic outlines | BGEE pre-rendered 3D avatar craft |
| Franchise / BG character copies | Original RainShadow Lila |
| Whole-figure horizontal flip of sheets | Preserve upper-left light and anatomical-left handbag |

Soft locks vs V6 key: same navy beret / emerald coat / cream dress / pale auburn / dark gloves / handbag-left palette and swing-coat silhouette; younger prettier face.

Sheet prompts change only direction, pose, and phase while retaining this contract and the matching V9 identity key.

## Camera and runtime contract

- Orthographic / 2:1 dimetric gameplay camera, looking down about 30–35 degrees; same RainShadow office projection as prior locks.
- Generator masters: flat `#00ff00` chroma, no floor or shadow.
- Processing: V6 key/slice/register flow pointed at `PreRendered3DV9/` masters, then **V7 crunch** (`process_pre_rendered_characters_v9.py`): 80 px native body, 64-color opaque-only palette, no dither, nearest → 200 px texture body on 512×512 (`FOOT_Y = 434`). SpriteKit nearest filtering at display size.
- Client arrival: 8 walk + 1 idle SW. Departure: 8 NE + 8 NW (path-segment facing; no runtime mirror).
- NE departure: authored rear three-quarter upper-right strip; handbag anatomical left (screen-left).
- NW departure: installed as a horizontal flip of the approved NE cells inside `process_pre_rendered_characters_v9.py` (no re-crunch) so face peek stays viewer-left and coat emerald matches NE exactly; anatomical-left handbag reads screen-right after the flip.
- Portrait shares identity but skips the nearest-pixelize gameplay pass (Lanczos → 512×512).

## Runtime naming (unchanged IDs)

| Clip | Frame names | Atlas |
|---|---|---|
| Client arrival | `lila_arrival_sw_{00–08}` (08 = idle) | `LilaArrival.atlas` |
| Client departure NE | `lila_departure_ne_{00–07}` | `LilaArrival.atlas` |
| Client departure NW | `lila_departure_nw_{00–07}` | `LilaArrival.atlas` |
| Dialogue portrait | `dialogue_portrait_lila_march_v01` | `UI/Dialogue/` |

## Gate assets

| Asset | Path |
|---|---|
| Lila SW key | `Client/PreRendered3DV9/lila_key_sw_chroma_v09.png` |
| Play-scale preview | `Generated/Characters/preview_characters_in_office_v09.png` |

Do not batch-generate animation sheets until the SW key passes play-scale review against the BGEE references and clearly reads as younger, prettier, and early-twenties while keeping the V6 costume palette.

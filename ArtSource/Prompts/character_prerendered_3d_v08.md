# Character pre-rendered 3D V8 style lock (Harlan Voss identity refresh)

Generated 2026-07-30. Scope: **Harlan Voss only** — full AssetManifest gameplay density + dialogue portrait + inventory paperdoll. Lila March stays on the V6/V7 ships. Raster crunch reuses the approved **V7** BGEE pass (80 px native / 64 colors / nearest → 200 px texture).

## Review finding

V6/V7 locked the correct BGEE rendering language and costume palette, but Voss still reads as a mid-forties mustached lead. V8 keeps the V6 **silhouette, palette, and processing contract** and refreshes the **face and wear**: early-thirties, clean-shaven, handsome bone structure with tired eyes, and visibly rumpled/lived-in clothing masses so he still feels broken down at portrait and play scale.

## Shared generation contract

> Create a Baldur's Gate: Enhanced Edition–era Infinity Engine pre-rendered 3D character avatar: a simple textured late-1990s game mesh rendered offline into a small 2D gameplay sprite. Soft directional baked light from the upper-left, soft anti-aliased silhouette against the backdrop, readable clothing folds and masses, ordinary realistic human proportions, and only a few pixels of facial suggestion at play scale. Not modern PBR, not photoreal concept art, not hand-drawn pixel art, not toy/chibi proportions, not hard black comic outlines, not polished contemporary low-poly illustration. No pores, individual hair strands, glossy materials, cinematic rim light, depth of field, floor plane, cast/contact shadow, scenery, text, UI, or watermark. Place every complete figure on a perfectly flat uniform `#00ff00` chroma-key field. Do not use `#00ff00` in the character.

Style references (analysis only — do not copy outfits, faces, or silhouettes):

- `ArtSource/References/BGEE/bgee_avatar_townsfolk_yellow_red.png`
- `ArtSource/References/BGEE/bgee_avatar_red_tunic_fighter.png`
- `ArtSource/References/BGEE/bgee_avatar_dark_vest_fighter.png`
- `ArtSource/References/BGEE/bgee_avatar_green_robe.png`
- `ArtSource/References/BGEE/bgee_avatar_mage_circle_robes.png`
- `ArtSource/References/BGEE/bgee_avatar_plate_armor_fighter.png`

Identity gate reference (V8 approved key — match this character in every sheet):

- `ArtSource/Generated/Characters/Detective/PreRendered3DV8/voss_key_se_chroma_v08.png`

## Character lock (V8 — Voss identity refresh)

- **Harlan Voss (detective):** taller lean **early-thirties** build; dark hair (no gray streaks) under a **slate-gray fedora** that is crushed / soft-brimmed / frayed at the edge; **clean-shaven** handsome face with tired hollow eyes (no mustache, no beard; faint five-o’clock shadow only if readable at portrait scale); deep **olive-brown belted overcoat** with wide lapels, hem at mid-calf — **must read visibly rumpled, rain-stained, dirt-smudged, and lived-in at play scale** (deep wrinkles, sagging pockets, muddy lower hem, uneven lapels; never neat or freshly pressed); **mustard waistcoat** creased; cream shirt with soft/askew collar; **dark green tie loosened and wrinkled**; charcoal trousers baggy with creases and lower grime; scuffed muddy dark brown shoes; no weapon in gameplay sprites. Keep the coat, hat, and stance near-bilateral so eastern runtime mirrors read correctly. Idle and seated poses may slump slightly to sell fatigue.

- **Lila March:** unchanged from V6. Do not regenerate.

Hard rejects:

| Reject | Require |
|---|---|
| Mustache, beard, gray-streaked “older” hair | Clean-shaven early-30s handsome face, tired eyes |
| Neat pressed coat / sharp new fedora | Rumpled, stained, lived-in V6 wardrobe pieces |
| Modern PBR, photoreal, hand pixel art, comic outlines | BGEE pre-rendered 3D avatar craft |
| Franchise / BG character copies | Original RainShadow Voss |

Soft locks vs V6 key: same olive / mustard / green / slate fedora / charcoal trousers palette and mid-calf belted overcoat silhouette; younger face; worn cloth.

Sheet prompts change only direction, pose, and phase while retaining this contract and the matching V8 identity key.

## Camera and runtime contract

- Orthographic / 2:1 dimetric gameplay camera, looking down about 30–35 degrees; same RainShadow office projection as prior locks.
- Generator masters: flat `#00ff00` chroma, no floor or shadow.
- Processing: V6 key/slice/register flow pointed at `PreRendered3DV8/` masters, then **V7 crunch** (`process_pre_rendered_characters_v7.py` / V8 wrapper): 80 px native body, 64-color opaque-only palette, no dither, nearest → 200 px texture body on 512×512 (`FOOT_Y = 434`). SpriteKit nearest filtering at display size.
- Standing/walk store nine source orientations: `s, ssw, sw, wsw, w, wnw, nw, nnw, n`. Eastern facings mirror at runtime.
- Walk: 8 frames/dir. Standing idle: 4 frames/dir. Seated idle + arms: 8 SE (+ NE desk chain). Stand-up / sit-down: 12 SE each (+ NE).
- Portraits and paperdoll share identity but skip the nearest-pixelize gameplay pass.

## Runtime naming (unchanged IDs)

| Clip | Frame names | Atlas |
|---|---|---|
| Walk | `voss_walk_{dir}_{00–07}` | `VossWalk.atlas` |
| Standing idle | `voss_standing_idle_{dir}_{00–03}` | `VossIdle.atlas` |
| Seated idle | `voss_seated_idle_se_{00–07}` (+ NE) | `VossSeatedIdle.atlas` |
| Seated arms | `voss_seated_arms_se_{00–07}` (+ NE) | `VossSeatedArms.atlas` |
| Stand-up / sit-down | `voss_{stand_up,sit_down}_{se,ne}_{00–11}` | `VossSeatTransitions.atlas` |
| Dialogue portrait | `dialogue_portrait_harlan_voss_v01` | `UI/Dialogue/` |
| Paperdoll | `voss_paperdoll_front_rgba_v01` (1024×1536) | `UI/Inventory/` |

## Gate assets

| Asset | Path |
|---|---|
| Voss SE key | `Detective/PreRendered3DV8/voss_key_se_chroma_v08.png` |
| Play-scale preview | `Generated/Characters/preview_characters_in_office_v08.png` |

Do not batch-generate animation sheets until the SE key passes play-scale review against the BGEE references and clearly reads as younger, clean-shaven, handsome, and worn while keeping the V6 costume palette.

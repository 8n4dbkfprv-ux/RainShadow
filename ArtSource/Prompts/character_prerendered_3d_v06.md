# Character pre-rendered 3D V6 style lock (BGEE avatar craft, new identities)

Generated 2026-07-23 with the built-in Image Generator. Scope: full AssetManifest density + character UI + full rename to the canonical dialogue names (see `Documentation/BGEECharacterSpriteRedoPlan.md`, superseded sections noted there, and the V6 plan).

## Review finding

V5 locked the correct BGEE rendering language but preserved the V4 costume identities (charcoal-trench/red-tie Elias Vale, burgundy-hat Vivian Hart) and the retired working names. V6 keeps the V5 **rendering** contract and replaces the **characters**: new original designs named from dialogue canon — **Harlan Voss** (detective) and **Lila March** (client) — that must read as clearly different characters from every shipped V4 sprite at play scale. The partially generated V5 identity keys (`det_key_se_*_v05`, `vivian_key_sw_*_v05`) are discarded; do not reference them in any V6 generation.

## Shared generation contract

> Create a Baldur's Gate: Enhanced Edition–era Infinity Engine pre-rendered 3D character avatar: a simple textured late-1990s game mesh rendered offline into a small 2D gameplay sprite. Soft directional baked light from the upper-left, soft anti-aliased silhouette against the backdrop, readable clothing folds and masses, ordinary realistic human proportions, and only a few pixels of facial suggestion at play scale. Not modern PBR, not photoreal concept art, not hand-drawn pixel art, not toy/chibi proportions, not hard black comic outlines, not polished contemporary low-poly illustration. No pores, individual hair strands, glossy materials, cinematic rim light, depth of field, floor plane, cast/contact shadow, scenery, text, UI, or watermark. Place every complete figure on a perfectly flat uniform `#00ff00` chroma-key field. Do not use `#00ff00` in the character.

Style references (analysis only — do not copy outfits, faces, or silhouettes):

- `ArtSource/References/BGEE/bgee_avatar_townsfolk_yellow_red.png`
- `ArtSource/References/BGEE/bgee_avatar_red_tunic_fighter.png`
- `ArtSource/References/BGEE/bgee_avatar_dark_vest_fighter.png`
- `ArtSource/References/BGEE/bgee_avatar_green_robe.png`
- `ArtSource/References/BGEE/bgee_avatar_mage_circle_robes.png`
- `ArtSource/References/BGEE/bgee_avatar_plate_armor_fighter.png`

## Character locks (V6 — new identities)

- **Harlan Voss (detective, replaces Elias Vale):** taller lean middle-aged build; gray-streaked dark hair swept back under a **slate-gray fedora** (worn in gameplay sprites — the old design was hatless); thin mustache, hollow-cheeked angular face; deep **olive-brown belted overcoat** with wide lapels, hem at mid-calf; **mustard waistcoat**; cream shirt; **dark green tie**; charcoal trousers; dark brown shoes; no weapon in gameplay sprites. Keep the coat, hat, and stance near-bilateral so eastern runtime mirrors read correctly.
- **Lila March (client, replaces Vivian Hart):** slim adult mid-century silhouette; **pale auburn hair pinned up** beneath a **small dark-navy beret**; alert, guarded face; **deep emerald swing coat** flaring below the waist; cream day dress beneath; short dark gloves; compact **dark handbag on her anatomical left hand**; sensible dark shoes. She appears only in authored SW arrival / NE departure directions, so the handbag is never mirrored.

Explicit divergence requirements versus the shipped V4 sprites (hard reject if violated):

| Old (V4, retired) | New (V6) |
|---|---|
| Elias: hatless, receding hair + short beard | Voss: fedora, mustache, no beard |
| Elias: charcoal trench coat, red tie | Voss: olive-brown belted overcoat, green tie, mustard waistcoat |
| Vivian: burgundy hat + burgundy skirt suit, charcoal raincoat | Lila: navy beret, emerald swing coat, cream dress |

Sheet prompts change only direction, pose, and phase while retaining this contract and the matching V6 identity key.

## Camera and runtime contract

- Orthographic / 2:1 dimetric gameplay camera, looking down about 30–35 degrees; same RainShadow office projection as prior locks.
- Generator masters: flat `#00ff00` chroma, no floor or shadow.
- `process_pre_rendered_characters_v6.py` removes the key, reduces each figure in premultiplied-alpha space to a 100-pixel native body, limits it to 96 colors without dithering, enlarges it 2× with nearest sampling onto a 512×512 registered frame (`FOOT_Y = 434`), and writes the full AssetManifest cell set under the new names. SpriteKit displays at 256 points with nearest filtering.
- Standing/walk store nine source orientations: `s, ssw, sw, wsw, w, wnw, nw, nnw, n`. Eastern facings mirror at runtime.
- Walk: 8 frames/dir. Standing idle: 4 frames/dir. Seated idle + arms: 8 SE. Stand-up / sit-down: 12 SE each. Client arrival: 8 walk + 1 idle SW; departure: 8 NE.
- Portraits and paperdoll share identity but skip the nearest-pixelize gameplay pass.

## Runtime naming (full rename)

| Clip | Frame names | Atlas |
|---|---|---|
| Walk | `voss_walk_{dir}_{00–07}` | `VossWalk.atlas` |
| Standing idle | `voss_standing_idle_{dir}_{00–03}` | `VossIdle.atlas` |
| Seated idle | `voss_seated_idle_se_{00–07}` | `VossSeatedIdle.atlas` |
| Seated arms | `voss_seated_arms_se_{00–07}` | `VossSeatedArms.atlas` |
| Stand-up | `voss_stand_up_se_{00–11}` | `VossSeatTransitions.atlas` |
| Sit-down | `voss_sit_down_se_{00–11}` | `VossSeatTransitions.atlas` |
| Client arrival | `lila_arrival_sw_{00–08}` (08 = idle) | `LilaArrival.atlas` |
| Client departure | `lila_departure_ne_{00–07}` | `LilaArrival.atlas` |
| Dialogue portraits | `dialogue_portrait_harlan_voss_v01`, `dialogue_portrait_lila_march_v01` | `UI/Dialogue/` |
| Paperdoll | `voss_paperdoll_front_rgba_v01` (1024×1536) | `UI/Inventory/` |

## Gate assets

| Asset | Path |
|---|---|
| Voss SE key | `Detective/PreRendered3DV6/voss_key_se_chroma_v06.png` |
| Lila SW key | `Client/PreRendered3DV6/lila_key_sw_chroma_v06.png` |
| Play-scale office preview | `Generated/Characters/preview_characters_in_office_v06.png` |

Do not batch-generate animation sheets until both keys pass play-scale review against the BGEE references, read as BGEE avatar craft, and are clearly distinct from the retired V4/V5 identities.

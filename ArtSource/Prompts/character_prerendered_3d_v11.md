# Character pre-rendered 3D V11 style lock (paperdoll-driven Voss + Lila wardrobe/hair)

Generated 2026-08-02. Scope: **Harlan Voss full AssetManifest gameplay density** + **Lila March arrival/departure** + dialogue portraits. Raster crunch reuses the approved **V7** BGEE pass (80 px native / 64 colors / nearest → 200 px texture). Inventory paperdoll pose V11 is already shipped and is the Voss identity authority.

## Review finding

Voss room sprites still follow the V8 SE key (fedora on every cell) while the inventory paperdoll is a better bare-headed BGEE “pre-rendered 3D” read. V11 regenerates all Voss gameplay cells from that paperdoll identity and drops the fedora. Lila drops the long hair and emerald swing coat for a chic chin-grazing blunt bob and a fitted 1940s day dress that is figure-flattering but still under-15 suitable.

## Shared generation contract

> Create a Baldur's Gate: Enhanced Edition–era Infinity Engine pre-rendered 3D character avatar: a simple textured late-1990s game mesh rendered offline into a small 2D gameplay sprite. Soft directional baked light from the upper-left, soft anti-aliased silhouette against the backdrop, readable clothing folds and masses, ordinary realistic human proportions, and only a few pixels of facial suggestion at play scale. Not modern PBR, not photoreal concept art, not hand-drawn pixel art, not toy/chibi proportions, not hard black comic outlines, not polished contemporary low-poly illustration. No pores, individual hair strands, glossy materials, cinematic rim light, depth of field, floor plane, cast/contact shadow, scenery, text, UI, or watermark. Place every complete figure on a perfectly flat uniform `#00ff00` chroma-key field. Do not use `#00ff00` in the character.

**Craft parity:** Voss and Lila must share one mesh language. Use `Detective/PreRendered3DV11/voss_key_se_chroma_v11.png` as the craft authority for both leads — broad planar folds, matte cloth, solid-shell hair, muted baked shading. Reject any Lila master that reads smoother, glossier, or more modern-3D than Voss.

Style references (analysis only — do not copy outfits, faces, or silhouettes):

- `ArtSource/References/BGEE/bgee_avatar_townsfolk_yellow_red.png`
- `ArtSource/References/BGEE/bgee_avatar_red_tunic_fighter.png`
- `ArtSource/References/BGEE/bgee_avatar_dark_vest_fighter.png`
- `ArtSource/References/BGEE/bgee_avatar_green_robe.png`
- `ArtSource/References/BGEE/bgee_avatar_mage_circle_robes.png`
- `ArtSource/References/BGEE/bgee_avatar_plate_armor_fighter.png`

## Character locks

### Harlan Voss (detective) — paperdoll-driven, bare-headed

Identity authority (copy face, hair, coat masses, palette, materials):

- `ArtSource/Generated/Characters/Detective/Paperdoll/voss_paperdoll_front_chroma_v11.png`
- runtime twin: `RainShadow Shared/Resources/Art/UI/Inventory/voss_paperdoll_front_rgba_v01.png`

Gameplay SE key gate (must pass before batch sheets):

- `ArtSource/Generated/Characters/Detective/PreRendered3DV11/voss_key_se_chroma_v11.png`

Lock:

- taller lean early-thirties build; **bare head** — short dark hair only (**no fedora, no hat**)
- clean-shaven handsome face with tired hollow eyes (no mustache/beard; faint five-o’clock shadow only if readable)
- deep olive-brown belted overcoat, mid-calf, visibly rumpled / rain-stained / lived-in
- mustard waistcoat, cream shirt, loosened dark green tie, charcoal trousers, scuffed brown shoes
- no weapon; keep coat and stance near-bilateral so eastern runtime mirrors read correctly

Hard rejects:

| Reject | Require |
|---|---|
| Fedora / any hat | Bare head matching paperdoll hair |
| Mustache, beard, gray “older” hair | Clean-shaven early-30s paperdoll face |
| Neat pressed coat | Rumpled lived-in overcoat |
| Modern PBR / photoreal / comic outlines | BGEE pre-rendered avatar craft |

### Lila March (client) — 1940s fitted dress + blunt bob

Gameplay SW key gate:

- `ArtSource/Generated/Characters/Client/PreRendered3DV11/lila_key_sw_chroma_v11.png`

Lock:

- slim early-twenties silhouette; pretty alert/guarded noir face
- **hair:** chic **chin-grazing textured blunt bob**; **soft side part**; **airy lived-in finish**; dark brown (no beret, no long hair, no auburn)
- **wardrobe:** fitted **deep-emerald 1940s day dress** with **nipped waist** and thin belt; **modest scoop neckline** (collarbone OK, **no cleavage**); cap or short sleeves; skirt length **knee to just below knee** with a soft flare that reads when she walks; dark pumps with a modest heel; compact **dark handbag on anatomical left**; **no gloves**, no swing coat, no raincoat over-layer in gameplay cells
- “more glamorous / figure-flattering” means silhouette and fit only — still suitable for under-15 audiences and period-correct for mid-1940s daywear

Hard rejects:

| Reject | Require |
|---|---|
| Long hair, beret, pinned waves | Chin-grazing textured blunt bob, soft side part |
| Emerald swing coat / cream day dress undercoat | Single fitted deep-emerald 1940s day dress |
| Deep V-neck, cleavage, lingerie, sheer blouse, mini skirt | Modest scoop; knee-length skirt; solid opaque dress |
| Modern glam / PBR / comic outlines | BGEE pre-rendered avatar craft |
| Whole-figure horizontal flip of authored sheets | Preserve upper-left light and anatomical-left handbag |

## Camera and runtime contract

- Orthographic / 2:1 dimetric gameplay camera, looking down about 30–35 degrees; same RainShadow office projection as prior locks. Paperdoll is inventory-front only — do not paste its camera into walk sheets.
- Generator masters: flat `#00ff00` chroma, no floor or shadow.
- Processing: V6 key/slice/register flow pointed at `PreRendered3DV11/` masters, then **V7 crunch** (`process_pre_rendered_characters_v11.py`): 80 px native body, 64-color opaque-only palette, no dither, nearest → 200 px texture body on 512×512 (`FOOT_Y = 434`). SpriteKit nearest filtering at display size.
- Voss standing/walk: nine source orientations `s, ssw, sw, wsw, w, wnw, nw, nnw, n`. Eastern facings mirror at runtime.
- Voss walk 8/dir; standing idle 4/dir; seated idle + arms 8 SE; stand-up / sit-down 12 SE each.
- Lila: SW arrival 8 walk + 1 idle; NE departure 8 authored; NW = horizontal flip of approved NE (no re-crunch).
- Portraits share identity but skip nearest-pixelize (Lanczos → 512×512). Paperdoll stays soft / linear-filtered.

## Runtime naming (unchanged IDs)

| Clip | Frame names | Atlas |
|---|---|---|
| Walk | `voss_walk_{dir}_{00–07}` | `VossWalk.atlas` |
| Standing idle | `voss_standing_idle_{dir}_{00–03}` | `VossIdle.atlas` |
| Seated idle | `voss_seated_idle_se_{00–07}` | `VossSeatedIdle.atlas` |
| Seated arms | `voss_seated_arms_se_{00–07}` | `VossSeatedArms.atlas` |
| Stand-up / sit-down | `voss_{stand_up,sit_down}_se_{00–11}` | `VossSeatTransitions.atlas` |
| Client arrival | `lila_arrival_sw_{00–08}` (08 = idle) | `LilaArrival.atlas` |
| Client departure NE/NW | `lila_departure_{ne,nw}_{00–07}` | `LilaArrival.atlas` |
| Dialogue portraits | `dialogue_portrait_harlan_voss_v01`, `dialogue_portrait_lila_march_v02` | `UI/Dialogue/` |
| Paperdoll | `voss_paperdoll_front_rgba_v01` (already V11 pose) | `UI/Inventory/` |

## Gate assets

| Asset | Path |
|---|---|
| Voss identity (paperdoll) | `Detective/Paperdoll/voss_paperdoll_front_chroma_v11.png` |
| Voss SE gameplay key | `Detective/PreRendered3DV11/voss_key_se_chroma_v11.png` |
| Lila SW key | `Client/PreRendered3DV11/lila_key_sw_chroma_v11.png` |
| Play-scale preview | `Generated/Characters/preview_characters_in_office_v11.png` |

Do not batch-generate animation sheets until both keys pass play-scale review against the BGEE references and the identity locks above.

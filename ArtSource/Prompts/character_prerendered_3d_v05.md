# Character pre-rendered 3D V5 style lock (BGEE avatar craft)

Generated 2026-07-23 with the built-in Image Generator. Scope: full AssetManifest density + character UI (see `Documentation/BGEECharacterSpriteRedoPlan.md`).

## Review finding

V4 correctly rejected modern PBR but pushed “500–900 triangle / mitten hands” wording into toy-blocky low-poly. V5 locks to **Baldur’s Gate: Enhanced Edition avatar craft** using the staged style references under `ArtSource/References/BGEE/`: soft pre-rendered 3D volumes, soft anti-aliased silhouettes, readable cloth masses at ~100 px body height, ordinary human proportions, and muted earth tones with restrained saturated accents. Costumes and faces remain original RainShadow identities—never copies of franchise characters.

## Shared generation contract

> Create a Baldur’s Gate: Enhanced Edition–era Infinity Engine pre-rendered 3D character avatar: a simple textured late-1990s game mesh rendered offline into a small 2D gameplay sprite. Soft directional baked light from the upper-left, soft anti-aliased silhouette against the backdrop, readable clothing folds and masses, ordinary realistic human proportions, and only a few pixels of facial suggestion at play scale. Not modern PBR, not photoreal concept art, not hand-drawn pixel art, not toy/chibi proportions, not hard black comic outlines, not polished contemporary low-poly illustration. No pores, individual hair strands, glossy materials, cinematic rim light, depth of field, floor plane, cast/contact shadow, scenery, text, UI, or watermark. Place every complete figure on a perfectly flat uniform `#00ff00` chroma-key field. Do not use `#00ff00` in the character.

Style references (analysis only—do not copy outfits, faces, or silhouettes):

- `ArtSource/References/BGEE/bgee_avatar_townsfolk_yellow_red.png`
- `ArtSource/References/BGEE/bgee_avatar_red_tunic_fighter.png`
- `ArtSource/References/BGEE/bgee_avatar_dark_vest_fighter.png`
- `ArtSource/References/BGEE/bgee_avatar_green_robe.png`

## Character locks

- **Elias Vale:** compact broad middle-aged build; receding dark hair; short dark beard; square weary face; charcoal trench coat; cream shirt; loosened dark-red tie; brown trousers; blunt brown shoes; **no hat**, no weapon in gameplay sprites.
- **Vivian Hart:** adult mid-century appearance; small burgundy hat; dark brown waved bob; worried face; charcoal raincoat; burgundy skirt suit; cream blouse; compact brown handbag on her **anatomical left** hand; sensible dark heels.

Sheet prompts change only direction, pose, and phase while retaining this contract and the matching V5 identity key.

## Camera and runtime contract

- Orthographic / 2:1 dimetric gameplay camera, looking down about 30–35 degrees; same RainShadow office projection as prior locks.
- Generator masters: flat `#00ff00` chroma, no floor or shadow.
- `process_pre_rendered_characters_v5.py` removes the key, reduces each figure in premultiplied-alpha space to a 100-pixel native body, limits it to 96 colors without dithering, enlarges it 2× with nearest sampling onto a 512×512 registered frame (`FOOT_Y = 434`), and writes the full AssetManifest cell set. SpriteKit displays at 256 points with nearest filtering.
- Standing/walk store nine source orientations: `s, ssw, sw, wsw, w, wnw, nw, nnw, n`. Eastern facings mirror at runtime.
- Walk: 8 frames/dir. Standing idle: 4 frames/dir. Seated idle + arms: 8 SE. Stand-up / sit-down: 12 SE each.
- Portraits and paperdoll share identity but skip the nearest-pixelize gameplay pass.

## Gate assets

| Asset | Path |
|---|---|
| Elias SE key | `Detective/PreRendered3DV5/det_key_se_chroma_v05.png` |
| Vivian SW key | `Client/PreRendered3DV5/vivian_key_sw_chroma_v05.png` |
| Play-scale office preview | `Generated/Characters/preview_characters_in_office_v05.png` |

Do not batch-generate animation sheets until both keys pass play-scale review against the BGEE references and remain recognizably Elias/Vivian.

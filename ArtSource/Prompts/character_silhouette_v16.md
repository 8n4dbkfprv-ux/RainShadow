# Harlan Voss silhouette V16 — Image Generator production contract

Date: 2026-08-08  
Generator: **Codex built-in/default Image Generator only**  
Output root: `ArtSource/Generated/Characters/Detective/PreRendered3DV16/`

This contract refits Harlan Voss's existing clothes around a stronger body. It does
not redesign him. Every selected output must be copied from Codex's generated-image
storage into the output root before it is reviewed or accepted. Do not use the
Image API, the ImageGen CLI, a Blender render, or a generated multi-frame sheet.
One requested cell equals one built-in Image Generator call and one PNG master.

## Reference authority — never blend these roles

| Input | Role | May supply | Must never supply |
|---|---|---|---|
| `References/anatomy_shape_front.png` | anatomy reference | shoulder breadth, upper-back mass, arm/forearm/hand thickness, leg thickness, waist taper, shoe mass | face, hair, skin treatment, clothing, palette, texture, camera, pose |
| `References/anatomy_shape_back.png` | anatomy reference | the same body geometry, seen from the rear | face, hair, skin treatment, clothing, palette, texture, camera, pose |
| `ArtSource/Generated/Characters/Detective/Paperdoll/voss_paperdoll_front_chroma_v11.png` and runtime `voss_paperdoll_front_rgba_v01.png` | identity/wardrobe reference | Voss's face, short hair, age, all garments, garment construction and material language | gameplay camera or animation pose |
| V12 seated and key masters | identity/craft reference | face continuity, soft mesh density, matte baked shading | a replacement gait phase |
| `References/voss_key_se_chroma_v13c_review.png` | craft-density reference | broad soft painted planes and restrained detail | its weaker monochrome wardrobe |
| `References/voss_key_se_chroma_v13d_review.png` | wardrobe reference | separated material hues and exact garment palette | extra micro-detail beyond V13c |
| matching V12/V13 locomotion or seat cell | **edit target and pose authority** | camera, framing, facing, pose, foot plant, coat motion and gait phase | identity, anatomy, wardrobe colours |
| BGEE references | period-craft reference only | late-1990s pre-rendered mesh/raster language | character, costume, pose or palette |

The two anatomy screenshots are not character references. If a result contains
their face, ginger hair, sleeveless tunic, arm wraps, trousers, boots, exposed
torso, decorative trim, or texture language, reject it even when the silhouette is
good.

## Shared lock — repeat in every call

> Use case: identity-preserve  
> Asset type: one full-body pre-rendered gameplay sprite master  
> Primary request: change only Harlan Voss's body silhouette and refit his same
> wardrobe around it. Preserve the edit target's exact pose, camera, facing, foot
> plant, coat movement, gait phase, framing and lighting direction.  
> Subject: the same early-thirties, clean-shaven Harlan Voss with the same tired
> face, short dark hair and bare head. Broader shoulders and upper back; thicker
> upper arms, sleeves, forearms and hands; thicker thighs and calves; a distinctly
> narrower belted waist; chunkier shoes. Strong but plausible adult proportions,
> not a bodybuilder and not heroic fantasy armour anatomy.  
> Wardrobe: the same open, clean-hem, mid-calf belted overcoat; cream shirt;
> mustard waistcoat; loosened dark-green tie; charcoal trousers; scuffed brown
> shoes. Refit these exact garments to the stronger body. Do not close, shorten,
> replace, tear or decorate the coat.  
> Style/medium: Baldur's Gate: Enhanced Edition-era Infinity Engine pre-rendered
> 3D avatar; simple late-1990s textured mesh rendered offline; large soft matte
> paint planes, a few broad readable folds, restrained craft detail, soft baked
> upper-left key light. Not modern PBR, not photoreal concept art, not hand-drawn
> pixel art.  
> Scene/backdrop: perfectly flat, uniform `#00ff00` chroma-key field. No floor
> plane or lighting variation in the backdrop. Do not use `#00ff00` in Voss.  
> Composition/framing: exactly one complete figure, centred, crown and shoes fully
> visible, generous green clearance on every side.  
> Constraints: preserve identity, facial structure, expression, hair, wardrobe,
> palette, materials and the target cell's animation geometry. Rear views show
> coat, trousers, shoes and hair only; never invent shirt, waistcoat or tie on his
> back.  
> Avoid: anatomy-reference face, ginger hair or clothes; hat; weapon; chair; desk;
> prop; floor; cast shadow; contact shadow; reflection; scenery; text; UI; logo;
> watermark; crop; duplicate figure; transparent or patterned background;
> microfolds; leather grain; cloth weave; pores; individual hair strands; glossy
> materials; cinematic rim light.

### Locked material colours

These are material identities, not a global colour grade. Lighting can change
value within each material, but it must not collapse one material onto another.

| Material | Locked midtone |
|---|---|
| cream shirt | `#CEC3AA` |
| skin | `#AC7E60` |
| mustard waistcoat | `#9C7730` |
| olive-brown coat | `#705E3C` |
| charcoal trousers | `#3A383E` |
| dark-green tie | `#364636` |
| scuffed brown shoes | `#4E3725` |
| dark cool-brown hair | `#3A2D25` |

The cream shirt stays cream in shadow; charcoal trousers stay neutral/cool under
the key light; mustard is yellow-ochre rather than light brown; coat is olive-brown
rather than orange; tie remains visible green. Do not add an amber wash.

## Generation order and exact names

All paths below are relative to `PreRendered3DV16/`. An optional discarded draft
may remain outside the project, but every selected/approved result belongs here.

### 1. Four anchors — four separate calls

| View | Edit/reference target | Selected output |
|---|---|---|
| front | paperdoll identity plus front anatomy reference | `Anchors/voss_anchor_front_chroma_v16.png` |
| profile | paperdoll identity plus profile pose authority and both anatomy references | `Anchors/voss_anchor_profile_w_chroma_v16.png` |
| back | rear Voss pose authority plus back anatomy reference | `Anchors/voss_anchor_back_chroma_v16.png` |
| gameplay dimetric | approved gameplay key plus both anatomy references | `Anchors/voss_anchor_dimetric_se_chroma_v16.png` |

For an anchor call, append:

> Anchor request: neutral standing anatomy/identity lock for the **{front | exact
> profile | back | gameplay dimetric}** view. The anatomy screenshot governs only
> the body geometry under the clothes. Preserve Voss's face and complete wardrobe.
> Make the shoulder-to-belt taper readable after reduction to a 200-pixel body.

Do not ask Image Generator for a front/profile/back montage. Compose the review
sheet locally from these four PNGs.

### 2. Nine neutral gameplay keys — nine separate calls

Author the western half in this order:

`s`, `ssw`, `sw`, `wsw`, `w`, `wnw`, `nw`, `nnw`, `n`

Each selected key is the actual idle phase 00 master:

`Frames/voss_idle_{dir}_00_chroma_v16.png`

Append to the shared lock:

> Key request: produce the neutral idle phase 00 for authored facing **{dir}**.
> Preserve the matching source cell's exact dimetric camera, facing, stance, foot
> placement, hand placement and coat hang. Apply the approved V16 body underneath
> Voss's unchanged wardrobe. This is one frame, not a sprite sheet.

The installed SE idle is derived by a lossless horizontal mirror of approved SW;
there is no generated `se` master.

### 3. Complete SW walk proof — eight separate calls

Before any other animation production, generate:

`Frames/voss_walk_sw_00_chroma_v16.png` through
`Frames/voss_walk_sw_07_chroma_v16.png`.

Append for each call:

> Walk-proof request: constrained edit of SW walk frame **{00…07}**. Preserve the
> source frame pixel-for-pixel in camera intent: exact facing, anatomical left/right
> phase, foot plant, stride length, arm counter-swing, torso lean, head placement
> and coat flare. Change only the V16 body mass and refit the unchanged wardrobe.
> Do not interpolate toward a neutral stance and do not mirror the anatomy.

Process all eight through V14 before approval. Review at 0.25× playback and at
actual 180×180 actor-node scale. The proof passes only if identity, body mass, coat
fit, material hues, foot plants, head scale and the first/last loop remain stable.
The approved proof PNGs are the final SW walk masters; do not regenerate them for
the full batch. `ProofSW/` may hold local contact sheets only, not substitute
masters.

### 4. Remaining individual production calls

The complete Image Generator inventory is exactly **148 selected masters** in one
flat `Frames/` directory:

| Clip | Directions | Frames | Count | Exact filename |
|---|---:|---:|---:|---|
| standing idle | 9 | 4 | 36 | `voss_idle_{dir}_{00..03}_chroma_v16.png` |
| walk | 9 | 8 | 72 | `voss_walk_{dir}_{00..07}_chroma_v16.png` |
| seated idle | `ne`, `se` | 8 | 16 | `voss_seated_idle_{ne|se}_{00..07}_chroma_v16.png` |
| stand-up | `ne`, `se` | 12 | 24 | `voss_stand_up_{ne|se}_{00..11}_chroma_v16.png` |

`36 + 72 + 16 + 24 = 148`. Idle phase 00 keys and the eight SW proof frames are
included in that total. Generate no separate sit-down masters: the installer must
derive each 12-cell sit-down as the exact reverse of stand-up. Generate no seated
arms masters: the installer emits transparent compatibility cells.

For idle phases 01–03 append:

> Idle request: constrained edit of **{dir}** idle frame **{01…03}**. Preserve the
> source cell's exact mass-shift phase, facing, feet, hands, head placement and coat
> movement. Match phase 00's V16 identity, shoulder width, waist, limb thickness,
> shoe mass, palette and craft density. No head/torso scale pulse.

For remaining walk cells append the SW proof wording, replacing the direction and
frame. For seated idle append:

> Seated-idle request: constrained edit of chairless **{ne|se}** seated frame
> **{00…07}**. Preserve exact camera, seated pose, crown position, feet, hands and
> micro-motion phase. Apply the approved V16 mass without changing apparent scale.
> Voss is sitting on an unseen scene chair: generate no chair and no shadow.

For stand-up append:

> Stand-up request: constrained edit of chairless **{ne|se}** transition frame
> **{00…11}**. Preserve exact rise phase, crown, feet, hands, body lean and coat
> clearance. Match seated V16 at frame 00 and direction-matched standing V16 at
> frame 11. Generate no chair and no shadow. Sit-down will be an exact local reverse.

## Per-call review checklist

Reject and regenerate a cell before processing if any answer is no:

1. Is this unmistakably the same early-thirties clean-shaven Voss?
2. Are the target cell's facing, pose, foot plant and gait/rise phase unchanged?
3. Is the shoulder/upper-back mass stronger, the belt narrower, and each limb and
   shoe chunkier without bodybuilder exaggeration?
4. Is the same open clean-hem coat refitted around him, with no costume transfer?
5. Are visible front materials distinct and locked to the eight-colour contract?
6. Does a rear view omit shirt, waistcoat and tie?
7. Is the craft no denser than V13c and the palette no flatter than V13d?
8. Is the backdrop uniform `#00ff00`, with no floor, shadow, chair or other object?
9. Is exactly one uncropped figure present with generous clearance?

After processing, the manifest/QA gates are authoritative: source front hue spread
at least 0.45; processed front/three-quarter hue spread at least 0.18; normalized
front/back width-to-body-height 0.40–0.43; 512×512 RGBA, binary body alpha plus four
alpha-1 corner sentinels, feet row 433, centre within 2 px, standing height
198–202 px, seated height 150–160 px. Preview the paperdoll at 220×315 and gameplay
at the real 180×180 node over both warm and cool office/city backgrounds.

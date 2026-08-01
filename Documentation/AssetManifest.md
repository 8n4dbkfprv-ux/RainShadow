# RainShadow — Initial Asset Manifest

- Status: generation specification
- Version: 0.1
- Scope: M01 exterior, transition, and playable office

## 1. Purpose

This manifest is the source of truth for the first production assets generated with the built-in Image Generator and then normalized for SpriteKit. It prevents three common failures: baking interactive objects into the office background, changing projection or light direction between generations, and accepting animation frames that do not share a stable ground pivot.

The Image Generator produces source material. Every result still passes registration, alpha cleanup, color, downsampling, filename, pivot, and in-engine scale QA before it becomes a runtime asset.

## 2. Global image specification

### 2.1 Visual brief

- Original film-noir location and character designs.
- Late-1990s/early-2000s pre-rendered isometric CRPG production language.
- Painterly realistic materials, dense but grouped detail, fixed three-quarter view, baked chiaroscuro, modest low-resolution softness after downsampling.
- No modern 3D camera depth of field, PBR gloss, cel shading, vector-flat shapes, intentional large pixel blocks, or generic fantasy ornament.
- No copied franchise UI, logos, character designs, rooms, weapons, clothing, symbols, or source assets.

### 2.2 Projection lock

- 2:1 dimetric floor grid.
- Visual plan rotation: 45 degrees.
- Visual elevation: approximately 30 degrees.
- Screen-space diamond: 128×64 pixels in baseline runtime art space.
- Camera remains orthographic/fixed. Props must be generated against the office shell registration image.
- Office environment art uses a desk-lamp key and cool window fill. Character sprites use one consistent neutral baked 3D rig; subtle runtime tint/light overlays and separate contact shadows integrate them with the room.

### 2.3 Files and color

- Master environment renders: PNG, sRGB, at least 2× runtime dimensions when the generator permits.
- Runtime environment exports: PNG, sRGB, 8-bit per channel.
- Transparent assets: straight-alpha source with RGB edge colors extended beneath transparent pixels; SpriteKit will premultiply on load.
- Audio: 48 kHz, 24-bit WAV masters; shipped format selected after loop and device QA.
- Never use `@2x`/`@3x` in world-art filenames. Logical world units deliberately map to the baseline pixel grid; quality-tier selection is explicit.
- Runtime texture dimensions must not exceed 4096 pixels on either axis for M01.
- Area plates do not enter texture atlases. Character and small-effect frames do.

### 2.4 Master/runtime policy

| Class | Master target | Runtime target | Notes |
|---|---:|---:|---|
| Exterior plate | 6144×3456 | 3072×1728 | Downsample with mild area resampling; preserve rain-free base. |
| Office shell | 3840×2160 V3 master | 4096×2304 | Empty 16:9 architecture rebuilt at the BG:EE tavern camera height and feature scale. |
| Full-canvas overlays | 2× listed runtime | Listed runtime | Preserve exact pixel registration with base. |
| Actor frame | Generator master | 512×512 | Reduce to an 80px native body, limit to a 64-color per-sprite ramp (opaque pixels only) without dithering, enlarge to the fixed 200px texture body with nearest sampling, and register at the doubled ground pivot. SpriteKit displays the frame at 256×256 points with nearest filtering. |
| Small effects | 2× listed runtime | Listed runtime | Generate as source sheets where practical, then slice. |
| UI | 2× listed runtime | Listed runtime | Original RainShadow design, high readability. |

Large transparent overlays may be losslessly trimmed only after an anchor manifest is written. Actor frames stay untrimmed.

## 3. Style-lock assets — generate before production

These assets are gates, not shippable final art. Do not generate the complete manifest until all four pass at final display scale.

| ID | Source size | Content | Pass condition |
|---|---:|---|---|
| `style_office_corner_v01` | 2048×1536 | One original office corner with empty worn floor, stained plaster, rain window, and desk-lamp test light; fixed projection. | Materials and value grouping read like a pre-rendered painted CRPG area, not a modern 3D render. |
| `style_desk_composite_v01` | 2048×1536 | Desk, chair, detective, papers, and lamp temporarily composed for scale/light review. | Actor scale, contact, and warm/cool lighting are coherent. |
| `voss_key_se_chroma_v06` | Generator master | Full-body Harlan Voss standing, facing SE, neutral pose; BGEE-era pre-rendered 3D avatar on removable chroma (supersedes `det_key_se_chroma_v04`). | Soft baked upper-left light, compact readable costume masses, and BGEE play-scale raster read are approved; modern PBR or hand-outlined art is rejected. |
| `style_play_scale_v01` | 2048×1152 | Mock gameplay frame with the style tests reduced to intended play size. | Primary shapes remain legible on phone and macOS; detail does not become noise. |

Freeze approved results as reference inputs for every later generation. Record palette swatches, actor pixel height, camera grid, light direction, and desk dimensions in `art_style_lock.json`.

## 4. Exterior environment assets

The exterior is cinematic but remains layered enough for parallax, rain placement, window glow, and the match transition.

| Priority | Runtime ID | Pixels | Alpha | Description |
|---|---|---:|---|---|
| P0 | `ext_apartment_base` | 3072×1728 | Opaque | Original rundown apartment facade, wet sidewalk and street, dark rainy night, inactive/dim windows, baked wet reflections, no falling rain, no people, no foreground lamppost, no title/text. |
| P0 | `ext_foreground_architecture` | 3072×1728 | Yes, registered | Near awning/lamppost/fire-escape silhouettes used for parallax and framing; no rain. Full canvas preserves alignment. |
| P0 | `ext_office_window_glow` | 512×512 | Yes | Dirty amber office-window glow and restrained bloom; contains only emission/light, not frame geometry. |
| P1 | `ext_neighbour_window_glows` | 1536×1024 | Yes, registered crop | Sparse varied warm/cool inhabited-window glows with no text or figures. |
| P1 | `ext_sign_emission` | 1024×512 | Yes | Failing sign or hall-lamp emission layer, original symbol-free design. |
| P1 | `ext_street_reflection_warm` | 2048×768 | Yes | Broken amber reflection aligned to street; additive/alpha pulse layer. |
| P1 | `ext_puddle_specular` | 2048×768 | Yes | Cool wet highlights and puddle glints, aligned to street; no ripple animation baked in. |
| P0 | `ext_grade_vignette` | 3072×1728 | Yes | Subtle cool-black edge and foreground grade; full-canvas overlay. |
| P0 | `transition_window_bloom` | 1024×1024 | Yes | Abstract dirty-amber window bloom used as the exterior/interior match shape. |

Exterior base acceptance:

- The office window is readable but not the brightest object until its glow overlay rises.
- Street reflections agree with architectural light sources.
- No rain streaks are baked into the base; live rain direction can be tuned.
- The central facade and office window remain inside 4:3 composition safety.
- Painterly detail survives reduction to a 2048×1152 viewport.

## 4b. Act I city districts (V2)

Harborpoint outdoor travel art locked to the detective-office 2:1 dimetric camera (`ArtSource/Prompts/city_perspective_lock_v02.md`). Generator: built-in Image Generator only. Process: `ArtSource/Processing/process_city_districts_v02.py`.

| Priority | Runtime ID pattern | Pixels | Alpha | Description |
|---|---|---:|---|---|
| P0 | `city_<district>_block_v02` | 2048×1152 | Opaque | Area-map / layout reference plate per district |
| P0 | `city_<district>_ground_v02` | 2048×1152 | Opaque | Play underlay (streets only); world scale 1× → 2048×1152 |
| P0 | `map_city_<district>_v02` | 1847×1040 | Opaque | HUD area-map crop |
| P0 | `city_building_*` / `city_prop_*` | 512×384–640 | Yes | Modular landmarks and shared street furniture |

Districts: `sable_row` (hub + Voss apartment return), `wharf_ladder`, `riverside`, `harborpoint_pd`, `lila_street`, `civic_records`. Blue Room excluded until earned.

## 5. Office shell, props, and lighting

### 5.1 Empty shell

The word **empty** is strict. The shell may contain built architecture, fixed wall grime, baseboards, floorboards, cracks, and the unglazed openings. It may not contain desk, chair, loose papers, files, phone, mug, ashtray, lamp, cabinet, boxes, wastebasket, radiator, bottle, photo, rug, door leaf, window glass/frame, detective, rain streaks, or prop shadows.

| Priority | Runtime ID | Pixels | Alpha | Description |
|---|---|---:|---|---|
| P0 | `office_shell_base` | 4096×2304 | Opaque | Empty original V3 office architecture, high 2:1 dimetric floor and walls, small door/window openings, baked low cool ambient only. |
| P0 | `office_floor_wear_decal` | 2048×1024 | Yes | Registered localized scuffs, damp footprints, stains, and repaired floor areas; no object silhouettes. |
| P0 | `office_foreground_wall_occluder` | 1024×1536 | Yes | Near wall/doorway cutout that can pass over the detective; shares shell registration. |

### 5.2 Window assembly

| Priority | Runtime ID | Pixels | Alpha | Description |
|---|---|---:|---|---|
| P0 | `office_window_exterior_view` | 1024×768 | No | Soft, dark exterior view from the office angle; no animated rain. |
| P0 | `office_window_frame` | 1024×768 | Yes | Worn frame and dirty fixed glass edge, aligned to shell opening. |
| P0 | `office_window_sill_occluder` | 1024×256 | Yes | Foreground sill/trim used to cover window effects or actor overlap if needed. |
| P0 | `office_window_glass_mask` | 1024×768 | Grayscale | White only where animated rain may appear; hard black elsewhere; runtime crop mask. |

### 5.3 Door assembly

| Priority | Runtime ID | Pixels | Alpha | Description |
|---|---|---:|---|---|
| P0 | `office_door_frame` | 640×896 | Yes | Worn jamb, threshold, hinges, and rear trim aligned to shell opening. |
| P0 | `office_door_leaf_closed` | 512×896 | Yes | Original battered wooden/frosted-glass office door, no readable business name or copyrighted lettering. |
| P1 | `office_door_leaf_ajar` | 512×896 | Yes | Same door opened approximately 15 degrees for a future/attempt state; fixed hinge and light continuity. |
| P0 | `office_door_foreground_jamb` | 256×896 | Yes | Near jamb cutout that occludes the actor during approach. |

The door leaf and frame must match projection, hinge position, texture, damage, and lighting exactly. Generate the ajar state by editing the approved closed state, not from a fresh prompt.

### 5.4 Desk island and small desk objects

| Priority | Runtime ID | Pixels | Alpha | Description |
|---|---|---:|---|---|
| P0 | `office_desk_bare` | 932×780 | Yes | Battered wooden desk shell with a completely clear top. The hidden rear/detective side contains the knee opening and drawers; the visible visitor side is a plain modesty panel. Ground anchor is `(0.5, 0.04)` and matches the earlier ensemble registration. |
| P0 | `office_desk_front_occluder_v04` | 932×780 registered | Yes | Camera-near (SW knee) half of the NE-facing V4 desk; used over the seated actor/near crossings. |
| P0 | `office_desk_floor_shadow` | 1024×512 | Yes | Soft painted floor/contact shadow only, placed below actors. |
| P0 | `office_chair` | 512×512 | Yes | Old swivel office chair, arms and torn upholstery, designed around seated actor pose. |
| P0 | `office_chair_floor_shadow` | 512×256 | Yes | Chair-only floor/contact shadow. |
| P0 | `office_desk_lamp` | 217×262 | Yes | Worn metal lamp with warm lit shade; 250px content height before the shared 0.1904 desk display scale. |
| P0 | `office_desk_phone` | 210×154 | Yes | Period wired desk telephone and readable coiled cord; 142px content height. |
| P1 | `office_desk_typewriter` | 280×200 | Yes | Black 1940s office typewriter with paper; desk-scale clutter, no legible text. |
| P1 | `office_desk_notebook` | 160×120 | Yes | Closed case notebook on the writing surface. |
| P0 | `office_desk_mug` | 104×135 | Yes | Chipped ceramic mug and dark coffee, no logo or text; 123px content height. |
| P0 | `office_desk_ashtray` | 115×85 | Yes | Battered metal ashtray with old stubs and ash; 73px content height. |
| P0 | `office_desk_files` | 240×190 | Yes | Dog-eared folders and worn ledger; no legible generated text; 178px content height. |
| P1 | `office_case_files_b` | 256×192 | Yes | Alternate smaller stack, same paper palette. |
| P0 | `office_desk_papers` | 345×252 | Yes | Registered scatter of bills/notes with one pencil; abstract marks only; 240px content height. |
| P1 | `office_pencil_tray` | 192×96 | Yes | Pencil, worn fountain pen, and shallow tray; no weapon. |

### 5.5 Remaining room props

| Priority | Runtime ID | Pixels | Alpha | Description |
|---|---|---:|---|---|
| P0 | `office_filing_cabinet` | 512×768 | Yes | Dented tall metal cabinet, closed drawers, original label shapes with no legible text. |
| P0 | `office_cabinet_floor_shadow` | 512×384 | Yes | Cabinet-only floor shadow. |
| P1 | `office_safe` | 256×280 | Yes | Small floor safe beside the filing cabinet. |
| P1 | `office_archive_box_a` | 384×384 | Yes | Closed, worn archive box with tied folder; no legible text. |
| P1 | `office_archive_box_b` | 384×384 | Yes | Sagging/open variant with paper edges; designed to stack near `a`. |
| P1 | `office_wastebasket` | 256×256 | Yes | Dented painted-metal 1940s office wastebasket with crumpled paper (V2 solo). |
| P1 | `office_coat_stand` | 384×768 | Yes | Leaning coat stand with an old hat/scarf, not the detective's active trench coat. Runtime ID ships as `office_coat_rack`. |
| P1 | `office_umbrella_stand` | 160×220 | Yes | Umbrella stand at the coat-rack foot with two closed umbrellas. |
| P1 | `office_waiting_chair_a` | 220×280 | Yes | Straight wood waiting chair (entrance cluster). |
| P1 | `office_waiting_chair_b` | 220×280 | Yes | Mismatched upholstered waiting chair. |
| P1 | `office_waiting_table` | 200×160 | Yes | Small side table between waiting chairs. |
| P1 | `office_newspaper` | 140×100 | Yes | Folded newspaper on the waiting table; no legible masthead. |
| P1 | `office_waiting_ashtray` | 115×85 | Yes | Second ashtray for the waiting table. |
| P1 | `office_entrance_runner` | 768×384 | Yes | Narrow worn runner from door toward desk; non-blocking floor decal. |
| P1 | `office_case_board` | 320×280 | Yes | Cork case board with pinned notes and string; no legible text. |
| P1 | `office_wall_city_map` | 280×240 | Yes | Framed wall city map (abstract streets). |
| P1 | `office_framed_licence` | 160×180 | Yes | Framed private investigator licence; abstract seals/lines only. |
| P1 | `office_wall_photos` | 220×160 | Yes | Cluster of pinned/framed wall photographs. |
| P1 | `office_window_blinds` | 180×220 | Yes | Venetian blinds registered to the window insert. |
| P0 | `office_radiator` | 640×384 | Yes | Chipped cast-iron radiator and short visible pipe. |
| P1 | `office_hidden_bottle` | 128×256 | Yes | Partly empty unlabeled bottle, staged below/behind desk rather than glamorized. |
| P1 | `office_framed_photo` | 256×256 | Yes | Small turned/obscured personal photo; faces need not be legible at play scale. |
| P1 | `office_worn_rug` | 1024×768 | Yes | Thin worn rug/floor decal under the desk island, no contact shadow, low contrast. |
| P1 | `office_floor_trash_a` | 256×192 | Yes | Crumpled page/envelope cluster. |
| P1 | `office_floor_trash_b` | 256×192 | Yes | Matchbook/string/paper cluster with no brands. |
| P1 | `office_floor_trash_c` | 256×192 | Yes | Small alternate cluster for composition balance. |

### 5.6 Lighting and grade overlays

| Priority | Runtime ID | Pixels | Alpha | Blend intent | Description |
|---|---|---:|---|---|---|
| P0 | `office_light_lamp_pool` | 1536×1024 | Yes | alpha/add | Warm irregular desk/floor pool with soft dust and strong falloff. |
| P0 | `office_light_window_spill` | 1536×1024 | Yes | alpha/add | Cool broken window light on floor/wall, aligned to frame. |
| P1 | `office_light_blind_stripes` | 1536×1024 | Yes | alpha/add | Cool blue-grey Venetian-blind stripe spill on floor/furniture. |
| P1 | `office_light_hallway` | 768×512 | Yes | alpha/add | Narrow warm hallway-light rectangle through the open door. |
| P1 | `office_shadow_ceiling_fan` | 1536×1024 | Yes | alpha | Soft ceiling-fan blade shadow; scene may rotate slowly. |
| P0 | `office_shadow_vignette` | 3072×2048 | Yes | multiply/alpha | Registered edge shadow and value grouping; must not crush hotspot silhouettes. |

The final room is composited from shell + registered overlays + independent props in SpriteKit. A flattened reference composite is exported for QA but is never shipped as the interactive office.

## 6. Detective character assets

### 6.1 Character lock

Before animation, approve:

- `detective_character_sheet_master` — 2048×2048, front/side/back/three-quarter views, clothing callouts, palette, face close-up, and ground scale; production reference only.
- `detective_turnaround_iso_master` — nine neutral source orientations on a 3×3 grid—S, SSW, SW, WSW, W, WNW, NW, NNW, N—each cell equivalent to a 768×768 master frame; production reference only. A second preview shows all 16 displayed facings after eastern mirroring.
- `detective_seated_fit_master` — detective seated in approved chair behind a neutral registration grid; production reference only.

Design continuity rules:

- same face, clean-shaven early-thirties features, hairline, body proportions, tie, coat silhouette, pocket placement, and shoe shape in every frame;
- the overcoat is designed as a few compact, nearly bilateral masses at sprite scale so legacy-style mirroring remains readable;
- the slate-gray fedora is part of the approved V6 Voss identity and appears in every actor sprite (the inventory paperdoll holds it in hand so the face reads);
- hands never gain/remove fingers or swap object silhouettes;
- no baked background or contact shadow;
- feet/seat use the same ground pivot across the sequence.

### 6.2 Runtime animation set

All stored runtime frames are 512×512 transparent PNGs with a 200px opaque body and a doubled ground pivot equivalent to the established `(128, 40)` point-space contract. SpriteKit displays every frame at 256×256 points, preserving the established 100-world-unit actor height while providing 2× texture density. The seated pose gets its apparent height from authored posture and desk occlusion and retains its −100pt visual offset into the chair/desk registration.

The body targets 9% of playable height from shoe sole to crown: about 104 screen pixels in the reference 2048×1152 rendered view, with an acceptable 8–11% band (92–127 pixels). Preserve broad baked 3D shading and low-detail geometry, then reduce each figure to an 80-pixel native body, limit it to a 64-color per-sprite ramp (opaque pixels only) without dithering, enlarge it to the fixed 200-pixel texture body with nearest sampling, and keep the shared alpha pivot. This is controlled pre-rendered sprite texture, not hand-authored pixel art.

Standing and walk clips store nine source orientations: `s, ssw, sw, wsw, w, wnw, nw, nnw, n`. SpriteKit mirrors them into `nne, ne, ene, e, ese, se, sse`, producing 16 displayed facing bins without additional texture frames.

| Priority | Clip | Stored directions | Frames per direction | Stored frames | Displayed facing/frame combinations | Playback target | Notes |
|---|---|---:|---:|---:|---:|---|---|
| P0 | `voss_seated_idle` | SE only | 8 | 8 | 8 | 5 fps with authored holds; 2.5–4.0 s perceived loop | Coarse breath/shoulder shift and brief rainward glance; avoid subpixel flutter. Ships with a derived `voss_seated_arms` desk-overlay layer per frame. |
| P0 | `voss_stand_up` | SE only | 12 | 12 | 12 | 10 fps, once | Clears chair/desk without pivot jump; event on final standing frame. |
| P1 | `voss_sit_down` | SE only | 12 | 12 | 12 | 10 fps, once | Authored sequence, not a reversed stand-up clip. |
| P0 | `voss_standing_idle` | 9 source / 16 displayed | 4 | 36 | 64 | 5 fps with long holds | Broad readable mass shift, not smooth high-resolution breathing. Mirrored SE copies are also stored for the desk chain. |
| P0 | `voss_walk` | 9 source / 16 displayed | 8 | 72 | 128 | 10 fps loop | Clear contact/pass cycle, stable simplified silhouette and crown. |

Required stored character texture frames: **140**. Required displayed facing/frame combinations, including runtime mirroring: **224**.

The first client uses a deliberately smaller authored set: `LilaArrival.atlas` contains eight southwest entrance walk phases, one southwest standing idle, eight rear three-quarter northeast departure phases, and eight rear three-quarter northwest departure phases (chair→door leg). Exit playback selects NE vs NW strips from path-segment facing without mirroring. All use the same 512×512, 200px-body, 2×-density contract and display at the detective's corrected 82-unit world height.

Filename examples:

```text
voss_seated_idle_se_00.png ... voss_seated_idle_se_07.png
voss_stand_up_se_00.png ... voss_stand_up_se_11.png
voss_standing_idle_s_00.png ... voss_standing_idle_n_03.png
voss_walk_s_00.png ... voss_walk_n_07.png
lila_arrival_sw_00.png ... lila_arrival_sw_08.png
lila_departure_ne_00.png ... lila_departure_ne_07.png
lila_departure_nw_00.png ... lila_departure_nw_07.png
```

Atlases (shipped set — Voss V8 identity + Lila V9 identity, both on V7 BGEE crunch):

- `VossSeatedIdle.atlas` — seated idle body frames.
- `VossSeatedArms.atlas` — derived seated forearm overlay (draws above the desk's front occluder).
- `VossSeatTransitions.atlas` — stand-up and sit-down clips.
- `VossIdle.atlas` — all standing idles (including mirrored SE copies).
- `VossWalk.atlas` — all walk directions.
- `LilaArrival.atlas` — Lila March V9 arrival, standing idle, and NE/NW departure.

Additional character texture:

| Priority | ID | Pixels | Description |
|---|---|---:|---|
| P0 | `det_contact_shadow_soft` | 256×128 | Neutral soft floor ellipse with slight directional tail; tinted/scaled at runtime. |

### 6.3 Animation QA tolerances

- Ground pivot movement: ≤ 2 runtime pixels except when intentional movement is represented by root motion; root motion is removed from walk frames.
- Standing head-height jitter: ≤ 2 runtime pixels.
- Apparent actor height at reference office pose: target 9% of playable height, with an acceptable 8–11% band (about 92–127 screen pixels in a 2048×1152 rendered view).
- Walk-cycle first/last continuity: no visible pop at 0.25× speed.
- Silhouette direction recognition: all 16 displayed facing bins sort into the correct quadrant and at least 12/16 are identified exactly without labels in internal review.
- Alpha-edge fringe: none over warm lamp light or cool window shadow.
- Coat, tie, face, and hand identity: no unmotivated frame-to-frame change.
- Sprite-style gate: runtime must show simplified faceted 3D volumes, broad baked light, minimal facial detail, and a restrained visible native raster; reject painterly, modern-PBR, overly smooth realistic, or chunky hand-authored pixel-art results.

## 7. Weather and ambient effect assets

Small repeated frames should be generated as high-resolution source sheets with equal cells, then sliced and normalized. The runtime files below are exact deliverables.

### 7.1 Exterior rain

| Priority | IDs | Count | Pixels each | Description |
|---|---|---:|---:|---|
| P0 | `fx_rain_far_01...04` | 4 | 8×64 | Thin soft grayscale streaks for far emitter. |
| P0 | `fx_rain_mid_01...04` | 4 | 16×128 | Main rain streak variants, slight length/brightness variation. |
| P0 | `fx_rain_near_01...04` | 4 | 32×256 | Sparse near streaks with soft breakup, never solid white rods. |
| P0 | `fx_street_splash_01_00...04_05` | 24 | 128×128 | Four six-frame impact crowns, transparent, fixed floor pivot. |
| P1 | `fx_puddle_ripple_01_00...03_07` | 24 | 256×128 | Three eight-frame isometric elliptical ripples. |
| P1 | `fx_drain_spray_00...07` | 8 | 256×256 | Eight-frame gutter/drain splash loop. |
| P1 | `fx_mist_wisp_01...02` | 2 | 1024×512 | Broad low-alpha street mist textures for slow drift. |

### 7.2 Window rain and interior air

| Priority | IDs | Count | Pixels each | Description |
|---|---|---:|---:|---|
| P0 | `fx_glass_flow_a`, `fx_glass_flow_b` | 2 | 1024×1024 | Tileable grayscale glass streak fields, vertically scrollable and cropped by mask. |
| P0 | `fx_glass_drop_01_00...04_07` | 32 | 128×512 | Four eight-frame downward droplet trails with alpha fade. |
| P1 | `fx_glass_impact_01_00...03_05` | 18 | 128×128 | Three six-frame small glass impact blooms. |
| P1 | `fx_dust_mote_01...03` | 3 | 32×32 | Soft lamp-lit mote variants. |

Effect acceptance:

- Rain angle matches across streak, splash, facade, and audio cues.
- Floor ripples use the scene's 2:1 ellipse, not circular top-down rings.
- Window effects never escape the glass mask.
- Effects support runtime tint and alpha without colored edge pixels.
- Loop seams are invisible at 0.25× and normal speed.

## 8. M01 interface assets

UI is original RainShadow art following Infinity Engine **layout hierarchy** with film-noir materials. Do not copy copyrighted Baldur’s Gate/Infinity Engine frames or icons. All visible chrome is Image Generator PNG; code owns layout, hit-testing, live text, and ephemeral hover/selection tints only.

| Priority | ID(s) | Count | Pixels each | Description |
|---|---|---:|---:|---|
| P0 | `ui_cursor_move`, `ui_cursor_inspect`, `ui_cursor_blocked` | 3 | 64×64 | macOS pointer states with clear hot point. |
| P0 | `ui_move_marker_00...07` | 8 | 128×64 | Muted isometric ground marker loop, optional on touch and click. |
| P0 | `ui_hotspot_focus_halo` | 1 | 512×512 | Neutral hand-painted halo, tintable, used only in focus mode. |
| P0 | `ui_observation_panel` | 1 | 768×256 | Nine-slice-compatible dark translucent caption backing. |
| P0 | `ui_skip_glyph` | 1 | 64×64 | Simple original skip glyph. |
| P0 | `ui_input_touch` | 1 | 128×128 | First-run touch hint symbol. |
| P0 | `ui_input_pointer` | 1 | 128×128 | First-run mouse hint symbol. |
| P0 | `hud_left_rail_plate_v03` | 1 | 256×2048 | Full-height left action rail plate; transparent button wells; rain-slicked gunmetal V03. |
| P0 | `hud_right_rail_plate_v03` | 1 | 320×2048 | Compact right party rail plate (letterboxed); portrait well + utility wells. |
| P0 | `hud_action_*_v03` | 12 | 128×128 | Painted noir action icons: menu, map, journal, inventory, character, leads, contacts, settings, rest, help, hide-ui, clock. Hover/pressed via code tint; disabled uses alpha. |
| P0 | `hud_party_*_v03` | 3 | 128×128 | Painted party utilities: search, lantern, select-party (stubs). |
| P0 | `hud_portrait_frame_v03` | 1 | 1086×1448 | Transparent portrait bezel matching v03 rail language; code owns HP text and condition tint. |
| P0 | `dialogue_outer_frame_overlay_v05` | 1 | 1720×730 | Original BG-hierarchy × noir dialogue plaque in blackened steel and smoked leather; compact TL portrait bezel; **transparent** text well + portrait window; **no painted scrollbar channel**. |
| P0 | `dialogue_command_button_plate_v04` | 1 | 512×128 | Matching rain-scratched noir END/CONTINUE command plate with an empty leather face; code draws label. |
| P0 | `dialogue_scroll_{up,down,up_pressed,down_pressed}_v06`, `dialogue_scroll_box_v06`, `dialogue_scroll_area_v06`, `dialogue_scroll_area_solid_v06` | 7 | 96×96 / 96×96 / 30×1024 | Exact Apple System 7 scrollbar grammar in RainShadow gunmetal: outlined arrowhead + stem handle (not Platinum solid triangles), fixed square scroll box, pixel-exact dithered gray area (solid when disabled), pressed arrow art, flush assembly, no grip ridges, no hover. |
| P0 | `dialogue_portrait_lila_march_v02` | 1 | 512×512 | Identity-locked hand-painted Lila March portrait for the dialogue crop (v02 clears a forehead generation speck). |
| P0 | `dialogue_portrait_harlan_voss_v01` | 1 | 512×512 | Identity-locked hand-painted Harlan Voss portrait for the dialogue crop. |
| P0 | `inventory_outer_frame_overlay_v03` | 1 | 1960×1080 | Full inventory hierarchy overlay (header, paperdoll chamber, slot rings, bag band, stats column) with transparent wells; no baked labels. |
| P0 | `inventory_slot_frame_v01` | 1 | 256×256 | Reusable alpha slot frame scaled to code-defined bounds. |
| P0 | `inventory_slot_silhouette_*_v03` | 8 | 256×256 | Painted empty-slot silhouettes (hat, coat, hands, feet, ring, weapon, item, bag). |
| P0 | `inventory_item_*_v01` | 7 | 512×512 | Original hand-painted service revolver, case notebook, brass key, matchbook, flashlight, wallet, and cigarette-case icons. |
| P0 | `inventory_coin_stack_v01` | 1 | 512×512 | Independent worn coin stack/scatter. |
| P0 | `inventory_case_bag_v01` | 1 | 512×512 | Independent investigator satchel. |
| P0 | `voss_paperdoll_front_rgba_v01` | 1 | 1024×1536 | Identity-locked Harlan Voss inventory paperdoll with transparent background. |
| P0 | `journal_casebook_plate_v03` | 1 | 1400×1600 | Open black-leather ledger with newsprint pages and tab/chapter wells; no baked copy. |
| P0 | `journal_row_marker_v03` | 1 | 64×64 | Small raven/bullet mark for journal list rows. |
| P0 | `ui_close_box_noir_v03` | 1 | 128×128 | Shared overlay close control in IE-noir language. |
| P0 | `map_chrome_top_bar_v03` | 1 | 1920×96 | Area-map top bar plate (title / toggle / world-map wells); code draws labels. |
| P0 | `map_detective_office_v03` | 1 | 1847×1040 | Layout-locked cramped-suite area map (shipping plate + modular props); code owns labels and position ring. |

Text is rendered by the game from localized strings; image generation must not produce interface copy.

## 9. Audio asset list

Audio is not generated by the Image Generator, but it is required for M01 and therefore belongs in the same production manifest.

### 9.1 Loops

| Priority | ID | Master duration | Loop requirement |
|---|---|---:|---|
| P0 | `amb_ext_heavy_rain` | 60–90 s | Seamless stereo; strong but leaves dialogue range. |
| P0 | `amb_ext_city_night` | 60–90 s | Distant traffic/rail/building bed, no obvious close events. |
| P0 | `amb_int_rain_on_window` | 60–90 s | Intimate glass impacts, shares tonal rain character with exterior. |
| P0 | `amb_int_office_roomtone` | 60–90 s | Quiet plaster room, radiator/pipe body, no periodic click. |
| P1 | `music_opening_noir` | 45–75 s | Sparse cue with clean skip tail and optional loop point. |

### 9.2 Randomized one-shots

| Priority | Family | Count | Target length | Notes |
|---|---|---:|---:|---|
| P0 | `sfx_ext_gutter_01...04` | 4 | 2–6 s | Water/gutter details. |
| P1 | `sfx_ext_vehicle_pass_01...03` | 3 | 4–8 s | Distant, no horn motif. |
| P1 | `sfx_ext_sign_buzz_01...03` | 3 | 1–4 s | Electrical sputter. |
| P0 | `sfx_int_pipe_01...05` | 5 | 0.5–3 s | Knock/tick/groan variety. |
| P0 | `sfx_det_chair_01...03` | 3 | 0.5–2 s | Seated shift and stand. |
| P0 | `sfx_det_cloth_01...04` | 4 | 0.3–1 s | Trench-coat movement. |
| P0 | `sfx_det_step_wood_01...06` | 6 | < 1 s | Worn shoe on floorboards, no heavy boot. |
| P0 | `sfx_phone_touch_01...02` | 2 | < 1 s | Receiver/body movement, no ring yet. |
| P1 | `sfx_paper_01...04` | 4 | 0.5–2 s | Files and loose pages. |
| P0 | `sfx_door_try_01...03` | 3 | 0.5–2 s | Handle, latch, wood response. |
| P1 | `sfx_lamp_hum_01` | 1 | 10–20 s | Low loop or long bed under lamp. |

## 10. Data and authoring assets

| Priority | File | Purpose |
|---|---|---|
| P0 | `opening_exterior.scene.json` | Art-space bounds, camera rail, overlay placement, emitter regions, audio cues, transition match cue. |
| P0 | `detective_office.scene.json` | Plate, prop instances, registered offsets, depth anchors/biases, hotspots, light overlays, rain mask placement. |
| P0 | `detective_office.nav.json` | Projection origin, grid dimensions, blocked/cost cells, actor start, chair approach, and hotspot approach cells. |
| P0 | `detective.animations.json` | Frame order, durations, events, loop modes, and directions. |
| P0 | `art_style_lock.json` | Projection, palette, light vector, actor scale, standard pivots, approved reference filenames. |
| P0 | `Localizable.xcstrings` entries | M01 hotspot names, observations, hint, skip/accessibility copy. |

Master-only QA overlays:

| File | Pixels | Purpose |
|---|---:|---|
| `office_registration_grid.png` | 3072×2048 | 128×64 projection diamonds, origin, camera safe frames, scene axes. |
| `office_flattened_reference.png` | 3072×2048 | Approved composite used to compare SpriteKit assembly. |
| `office_depth_reference.png` | 3072×2048 | Color-coded depth anchors and intended occluder splits. |
| `office_hotspot_reference.png` | 3072×2048 | Visible hotspot polygons and approach arrows. |
| `detective_pivot_reference.png` | 512×512 | Doubled ground pivot, 200px body bounds, head-height guide, and baked-light swatches. |

These overlays are excluded from release target membership.

## 11. Recommended generation order

### Batch 0 — lock the visual system

1. Generate the office-corner style test.
2. Generate the desk composite scale test.
3. Generate the detective SE key pose.
4. Build the play-scale mock frame and approve projection, actor scale, palette, and light.

Stop here if the look reads as generic AI art, modern 3D, pixel art, or a literal copy of a reference location.

### Batch 1 — build the registered environments

1. Generate `office_shell_base` first.
2. Overlay the registration grid and freeze camera/projection.
3. Generate desk, chair, door, window, cabinet, and their cutouts as edits using the shell and flattened reference.
4. Generate remaining props against the same reference.
5. Generate lighting overlays and flattened QA composite.
6. Generate exterior base, foreground, office-window glow, and transition bloom.

### Batch 2 — lock and animate the detective

1. Finalize character sheet and isometric turnaround.
2. Generate standing-idle key frames for the nine stored western-arc source orientations.
3. Generate one complete SW walk cycle; register it at 512×512 with a 200px body and test it in graybox at the 82-unit target scale.
4. Expand walking to the remaining eight source orientations, then review all 16 displayed/mirrored facings.
5. Generate seated idle and test behind the registered desk/chair.
6. Generate stand-up and sit-down transitions.
7. Downsample with premultiplied-alpha resampling, align doubled pivots, pack 2× atlases, and inspect at 0.25× speed.

Do not ask for all stored final frames in one unreferenced prompt. Use the approved low-detail 3D character image as the reference for every edit, change only pose/phase/direction, and reject identity drift immediately. High-resolution generations are registered through one shared premultiplied-alpha 2× downsample; palette reduction, dithering, and hard edge passes are prohibited.

### Batch 3 — effects, UI, and polish

1. Rain streak families.
2. One street splash and one window-droplet sequence; test emitter/loop behavior.
3. Remaining variation frames only after the first sequence passes.
4. Puddle, drain, glass, mist, and dust assets.
5. M01 interface assets.
6. Audio acquisition/design and final mix pass.

## 12. Prompt contracts

### 12.1 Environment base prompt skeleton

> Original film-noir detective game environment, fixed 2:1 dimetric isometric view, late-1990s pre-rendered CRPG visual language, richly painted realistic materials, dense lived-in detail grouped into readable shapes, strong baked chiaroscuro, muted blue-charcoal and tobacco-brown palette. [Scene-specific content.] Orthographic fixed camera, no perspective distortion, no characters, no falling rain, no interface, no text, no logos. Keep all interactive objects listed in the separation brief absent. Output as a clean registered area plate.

For the shell prompt, append the full forbidden-object list from section 5.1.

### 12.2 Prop prompt skeleton

> Create only [prop ID] as an original transparent-background isometric prop for the approved RainShadow office. Match the attached shell's exact 2:1 projection, pixel scale, warm desk-lamp key from [direction], cool rain-window fill, painterly pre-rendered CRPG texture, and material wear. Preserve the specified canvas and ground anchor. No room background, no extra objects, no text, no logo, no cropped silhouette, no halo.

Use an edit/reference chain rather than regenerating the room.

### 12.3 Character frame prompt skeleton

> The exact approved RainShadow detective, constructed as a genuinely crude 1998-era textured 3D VIDEO GAME MODEL captured from an old engine and baked into a sprite—not polished low-poly concept art. Use roughly 600–900 triangles, a face made from a few broad planar wedges, solid-shell hair, mitten-like hands, blunt shoes, broad rigid coat planes, tiny 32×32–64×64 diffuse maps, primitive vertex/Gouraud shading, one neutral directional light, and modest baked occlusion. Same face, stubble, hair, body, clothes, and colors. Fixed approved isometric camera. Pose: [animation/state/source orientation/frame phase]. Full body inside the shared transparent canvas, feet aligned to the approved ground pivot, no background, floor, contact shadow, props unless specified, text, added clothing, or identity change. Avoid PBR maps, pores, wrinkles, strands, fine weave, delicate seams, cinematic lighting, painterly illustration, cel shading, comic outlines, and hand-authored pixel art.

### 12.4 Effect prompt skeleton

> Transparent grayscale sprite-effect source sheet for [effect], painterly and restrained, designed for tinting in SpriteKit, [frame count] equal cells, fixed pivot and scale, no background, no colored fringe, no text. Isometric floor effects use a 2:1 ellipse.

## 13. Import and normalization checklist

For every generated image:

1. Preserve the untouched generation in `ArtSource/Generated/` outside release target membership.
2. Record generation date, prompt, reference IDs/files, intended runtime ID, and approval status.
3. Confirm the expected projection and light direction.
4. Remove unintended background pixels and extend RGB beneath alpha edges.
5. Resize to the exact runtime canvas without changing aspect ratio.
6. Align ground/registration pivot; do not individually center actor silhouettes.
7. Compare against the flattened room reference using difference/opacity overlay.
8. Downsample and apply one consistent restrained color/texture pass.
9. Export sRGB PNG with exact manifest filename.
10. Load in the SpriteKit asset harness on warm and cool test backgrounds.
11. Approve or reject; never silently patch a manifest dimension without updating this document and scene data.

## 14. Art acceptance gate

The first production generation batch is approved only when:

- the empty shell contains no listed interactive object;
- every major prop can be removed without leaving a painted duplicate or implausible baked shadow;
- the flattened runtime assembly matches the approved reference within registration tolerance;
- desk front, door jamb, window sill, and foreground wall correctly occlude the detective;
- all stored frames and displayed facing/frame combinations preserve identity, world scale, 2× pivot, projection, baked-light behavior, controlled native raster texture, and readable mirroring;
- rain and window effects loop without seams or mask leakage;
- the room reads coherently in both 2048×1152 (16:9) and 1536×1152 (4:3) rendered outputs at the shared 1,111-world-unit camera height;
- all content is original RainShadow content and contains no copied franchise assets, text, logos, or distinctive existing room composition.

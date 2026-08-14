# Harlan Voss character-strip V21

Video-first rebuild of every Voss gameplay animation from the approved V20
identity. Still-to-still edit-chain; never a fresh `image_gen` of Voss. Never a
multi-panel Imagine sheet. Assemble strips in Pillow, then run the V14 BGEE
crunch in `ArtSource/Processing/crunch.py`.

Tree: `ArtSource/Generated/Characters/Detective/PreRendered3DV21/`
Processor: `ArtSource/Processing/process_voss_character_strip_v21.py`
Installer: `ArtSource/Processing/install_voss_v21.py`

## Immutable identity

| Role | Path |
|---|---|
| Face law | `PreRendered3DV21/References/dialogue_portrait_harlan_voss_v01.png` (byte-identical V20 portrait; SHA-256 `13a5f349a2c08fb7517ae9cbb8a1b3953489458e654286ae3e29631782e8ec1d`) |
| Front | `References/voss_anchor_front_chroma_v20.png` |
| SW dimetric | `References/voss_anchor_dimetric_sw_chroma_v20.png` |
| W profile | `References/voss_anchor_profile_w_chroma_v20.png` |
| Back | `References/voss_anchor_back_chroma_v20.png` |

The portrait is never rewritten and never installed. V17 pose authorities are
gait/camera language only — they are not Imagine inputs.

## Prompt lock

Keep this exact detective — same stern face, pale blue-gray eyes, swept auburn
hair and long sideburns as the portrait. Full-body late-1990s Infinity Engine
pre-rendered avatar on a perfectly flat uniform `#00ff00` field: chocolate
double-breasted belted mid-calf trench with epaulettes and cuff straps, cream
open shirt, loose black tie, charcoal cuffed trousers, brown lace-ups. Soft
matte baked upper-left light, broad folds, restrained craft — not photoreal,
not modern PBR, not pixel art. {VIEW}. One complete uncropped figure with green
clearance; no chair, floor, shadow, hat, weapon, text, or scenery.

## Rear prompt lock

This is a true rear view. Show only swept auburn hair and the back of the
chocolate coat, including its storm flap and vent. Do not reveal a face,
sideburn, cream shirt, tie, front buttons, or front lapels.

## Side-map (viewer-relative)

| view | face | buttons / shirt | storm flap |
|---|---|---|---|
| S | full face, both sideburns | both columns + shirt/tie | hidden |
| SSW / SW | face, viewer-right sideburn stronger | right-of-figure stronger | SW: hint only |
| WSW / W | strict or near profile, viewer-left sideburn only | hidden; collar/tie edge only | hidden |
| WNW | hair + ear hint, no portrait | none | partial |
| NW / NNW / N | hair only, no face | none | centered flap + vent |

WNW / NW / NNW / N and NE seating never receive the portrait or the front
anchor.

## Scale lock

Idle and walk of one facing are two videos from the **same** standing still.
Head/shoulder ratio disagreement between that facing's idle and walk sources
must stay ≤ 0.06.

## Motion prompts (image_to_video, 6s, locked camera)

- Walk: the detective walks in place on the flat green field, alternating
  planted feet, coat hem swinging, camera locked, no travel across the frame.
- Idle: the detective stands in place and breathes, tiny weight shift only,
  camera locked.
- Seated idle: the chairless seated detective breathes, pelvis and feet fixed.
- Stand-up: the chairless detective rises from the seated pose to the standing
  idle of the same facing; no chair appears.

## Harvest

`ffmpeg -i clip.mp4 -vf fps=12 harvest/f%03d.png`. Select by foot contacts, not
even spacing. Walk = 8, standing idle = 4, seated idle = 8, stand-up = 12.
Sit-down is the exact reverse of processed stand-up. SE standing idle is the
exact horizontal mirror of processed SW.

## Hard rejects

Mustard waistcoat, green tie, olive coat, dark or black hair, hat, abbreviated
coat, face or shirt on rear views, photorealism, modern PBR, pixel art, chair,
prop, floor, contact or cast shadow, scenery, text, cropped crown, cropped shoes.

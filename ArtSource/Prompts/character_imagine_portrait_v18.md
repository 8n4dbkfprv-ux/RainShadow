# Harlan Voss portrait-first Imagine V18

Generated 2026-08-09. V18 is the Grok Imagine 2.0 replacement track for Harlan
Voss. Portrait identity is law. V17 remains installed and is never overwritten
by V18 scaffolding or failed proofs.

## Authoritative references

Immutable copies under `PreRendered3DV18/References/` (hashes in
`voss_v18_manifest.json`):

| File | Role |
|---|---|
| `dialogue_portrait_harlan_voss_v01.png` | **Face law** — eyes, bone structure, hair, sideburns, expression |
| `voss_target_front_three_quarter.png` | Body/wardrobe scaffold (front) |
| `voss_target_profile_w.png` | Body scaffold (profile) |
| `voss_target_back.png` | Body scaffold (back: coat construction only) |

Pose authorities (camera, feet, gait phase only) come from approved V17 keys /
runtime cells under `PoseAuthorities/` or the live atlases. They must never
supply face or wardrobe identity.

## Identity lock

Harlan is a stern adult detective with pale blue-gray eyes, swept-back auburn-
brown hair and pronounced auburn sideburns. He wears a dark chocolate-brown,
double-breasted, belted mid-calf trench coat with lapels, epaulettes, dark
buttons, buckled cuff straps, rear storm flap and vent; a cream open-collar
shirt; loose charcoal-black tie; charcoal cuffed trousers; and dark brown
lace-up shoes.

Hard rejects: mustard waistcoat, green tie, olive coat, hat, clean-shaven old
identity, abbreviated coat, modern PBR, chair, prop, floor, contact shadow,
cast shadow, scenery, text, border, non-uniform background, shirt/tie invented
on rear views.

## Generator contract (Grok Imagine 2.0)

| Output | Tool | References |
|---|---|---|
| Front / profile / back / dimetric anchors | `image_edit` | Portrait + matching body scaffold |
| Nine idle phase-00 keys | `image_edit` | Portrait + approved anchor + pose authority |
| Walk cycles | `image_to_video` then harvest | Direction key as frame 1; clean with `image_edit` |
| Idle micro-phases | `image_edit` (or short video) | Phase-00 key |
| Seated / stand-up | `image_edit` | Portrait + key + pose authority; chairless |
| Smooth UI | `image_edit` / derive | Front anchor → paperdoll; portrait kept unless face drifted |

Rules:

- One tool call per selected master. No multi-figure sheets from Imagine.
- Always restate style words on every edit (prevent photoreal drift).
- Gameplay masters: single full-body figure, flat uniform `#00ff00`, crown and
  shoes visible, generous green clearance.
- UI portrait and paperdoll stay smooth and **never** enter V14.
- Record every accepted output path + parent refs in
  `imagegen_provenance_v18.json`.

## Shared prompt lock (gameplay)

> Keep this exact detective — same stern face, pale blue-gray eyes, swept auburn
> hair and long sideburns as the portrait reference. Full-body pre-rendered
> late-1990s Infinity Engine avatar on a perfectly flat uniform #00ff00 field:
> dark chocolate double-breasted belted mid-calf trench with epaulettes and cuff
> straps, cream open shirt, loose black tie, charcoal cuffed trousers, brown
> lace-ups. Soft matte baked upper-left light, broad folds, restrained craft
> detail — not photoreal, not modern PBR, not pixel art. {pose sentence}. One
> complete uncropped figure with green clearance; no chair, floor, shadow, hat,
> weapon, text, or scenery.

### Walk video prompt

> The detective walks in place on a flat green backdrop, {facing} view, camera
> locked. Natural alternating gait, coat sways with each step; no travel, no
> zoom, no props.

## Side-map (asymmetry)

| View | Sideburns | Coat buttons | Storm flap |
|---|---|---|---|
| Front | both sides of face | double row visible | not visible |
| W profile | near-side (viewer-left) sideburn only | buttons not visible | not visible |
| Back | hair only, no face | not visible | centered rear flap + vent |
| SW dimetric | left sideburn more visible | right-of-figure button column reads stronger | partial |

Viewer-relative language only in prompts. SE idle is an exact horizontal mirror
of SW — never re-generated.

## Ordered approval gates

1. Four identity anchors (raw + V14 sheet vs portrait).
2. Nine phase-00 idle keys (+ SE mirror).
3. Complete eight-frame SW walk proof at 0.25× (video-first).
4. Remaining idle phases + eight walk directions.
5. NE/SE seated idle + stand-up; derive sit-down reverse.
6. Smooth paperdoll / portrait if needed.
7. Full stage → QA → transactional install (`--confirm-runtime-replace V18`).

No later gate starts from a failed earlier gate.

## Runtime processing

Gameplay only through V14: 56 native body rows, 64 per-material colours, hard
1-bit body alpha, nearest enlargement to 200px body, 512×512 canvas, feet on row
433. Wardrobe preservation on. Never run `relock_voss_identity_v12` or monochrome
seated locks.

Derived: 4 SE idle mirrors, 24 sit-down reverses, 16 NE upper/lower layers, 16
transparent seated-arm cells → 208 runtime PNGs under the existing five atlas
folder names.

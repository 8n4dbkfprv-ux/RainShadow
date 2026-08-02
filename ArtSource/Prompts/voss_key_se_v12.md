# Harlan Voss SE gameplay identity key V12

Date: 2026-08-02  
Generator: Cursor built-in Image Generator  
Scope: single SE standing identity key for V12 gameplay sheets. Locked harder to inventory paperdoll V11 after V11 room-sprite drift (tattered hem / over-weathered coat).

## Identity / style anchors (hard)

1. `ArtSource/Generated/Characters/Detective/Paperdoll/voss_paperdoll_front_chroma_v11.png` — face, hair, coat cut/hem, waistcoat, tie, trousers, shoes, materials, lighting language
2. Pose/camera structure only (do not copy wardrobe drift): `Detective/PreRendered3DV11/voss_key_se_chroma_v11.png`
3. Optional style-only BGEE refs under `ArtSource/References/BGEE/` — rendering craft only; do not copy costumes

## Camera / pose

- Fixed RainShadow office **2:1 dimetric** camera, looking down ~30–35°
- Standing **southeast (SE)** facing: figure’s chest and face toward the **lower-right** of frame (runtime SE / desk-chain convention)
- Neutral standing idle: feet planted about shoulder-width, weight even, arms relaxed at sides with soft elbow bend, empty hands
- Full figure centered with generous chroma clearance; no crop through feet or crown

## Character lock (copy paperdoll exactly)

- Early-thirties clean-shaven handsome face, tired hollow eyes, short dark hair
- **Bare head — no fedora, no hat**
- Olive-brown rumpled mid-calf belted overcoat with a **clean, intact hem** (not frayed, not tattered, not shredded)
- Mustard waistcoat, cream shirt, loosened dark green tie, charcoal trousers, scuffed brown shoes
- Lived-in rumple OK; heavy distress / leather shredding is not
- Soft upper-left baked light; BGEE pre-rendered 3D avatar craft (simple late-1990s game mesh, soft AA silhouette)

## Hard rejects

| Reject | Require |
|---|---|
| Frayed / tattered / shredded coat hem | Clean mid-calf hem matching paperdoll |
| Over-distressed leather / extreme weathering | Paperdoll coat materials |
| **More detailed than paperdoll** (pores, stubble grain, leather microtexture, sharp wrinkles, fabric weave) | **Same craft density as paperdoll** — broad soft planes, matte cloth, few facial features |
| Fedora / any hat | Bare head matching paperdoll |
| Inventory-front upright camera | Dimetric SE gameplay camera |
| New face / mustache / older softer face | Paperdoll early-thirties face |
| Photoreal / modern PBR / comic outlines / pixel art | BGEE pre-rendered avatar craft |
| Floor, shadow, props, weapon, UI, text | Empty figure on flat `#00ff00` |

## Primary request

Create one original Baldur's Gate: Enhanced Edition–era Infinity Engine pre-rendered 3D character avatar of private detective Harlan Voss as a simple late-1990s textured game mesh rendered offline into a single 2D gameplay sprite. Soft directional baked light from the upper-left, soft anti-aliased silhouette, readable clothing folds, ordinary human proportions. Match Image 1 (paperdoll) exactly for face, short dark hair, bare head (no hat), olive-brown rumpled overcoat with clean intact mid-calf hem, mustard waistcoat, cream shirt, dark green tie, charcoal trousers, and brown shoes — only change the camera to a fixed 2:1 dimetric southeast standing view facing lower-right with arms relaxed at sides (use Image 2 only for SE pose/camera structure). Flat uniform `#00ff00` chroma field. No floor, shadow, props, weapon, scenery, text, UI, or watermark. Not modern PBR, not photoreal, not hand-drawn pixel art, not comic outlines.

## Output

- Master: `ArtSource/Generated/Characters/Detective/PreRendered3DV12/voss_key_se_chroma_v12.png`
- Play-scale preview: `voss_key_se_playscale_v12.png` / `voss_key_se_runtime_v12.png`
- Do not batch animation sheets until this key passes play-scale V7 crunch review

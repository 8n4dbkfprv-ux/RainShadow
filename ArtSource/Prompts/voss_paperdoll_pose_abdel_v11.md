# Harlan Voss inventory paperdoll pose fix V11

Date: 2026-08-02  
Generator: Cursor built-in Image Generator  
Scope: inventory paperdoll only — posture correction. Identity, wardrobe, materials, lighting, and BGEE craft stay locked.

## Problem

Shipped `voss_paperdoll_front_rgba_v01` reads as a raised clenched fist at shoulder height. That is not the Baldur’s Gate inventory paperdoll stance.

## Pose reference (structure only)

User-supplied Baldur’s Gate inventory screenshot of Abdel (fighter with quarterstaff). Copy **stance geometry only** — not outfit, face, weapon, or UI.

Target unarmed translation of that inventory paperdoll pose:

- upright neutral heroic idle; weight even on both feet
- slight three-quarter body turn (same inventory read as Abdel)
- legs straight, feet planted about shoulder-width, toes slightly out
- anatomical **right** arm (viewer’s left): relaxed at the side with only a soft elbow bend; open/relaxed hand near the thigh/hip — **not** raised to shoulder, **not** a punch/fist guard
- anatomical **left** arm (viewer’s right): hangs naturally by the side, open/relaxed hand
- head facing mostly toward the viewer
- empty hands — no staff, weapon, fedora, props, or held objects

## Identity lock (copy exactly)

Use the current shipped Harlan Voss paperdoll as the hard identity/wardrobe/style anchor:

- `RainShadow Shared/Resources/Art/UI/Inventory/voss_paperdoll_front_rgba_v01.png`
- optional chroma master: `ArtSource/Generated/Characters/Detective/Paperdoll/voss_paperdoll_front_chroma_v10.png`

Keep: early-thirties clean-shaven face, short dark hair, olive-brown rumpled trench coat, mustard waistcoat, cream shirt, dark green tie, charcoal trousers, dark brown shoes, soft upper-left baked light, BGEE pre-rendered inventory resolution.

## Hard rejects

| Reject | Require |
|---|---|
| Raised fist / punch / combat-guard arm | Relaxed arms at sides (Abdel inventory idle without weapon) |
| New face, younger/older drift, mustache | Same Voss face as identity lock |
| Costume / palette change | Same olive/mustard/green/charcoal wardrobe |
| Photoreal / modern PBR / comic outlines | BGEE pre-rendered 3D paperdoll craft |
| Staff, gun, fedora-in-hand, floor, shadow, UI, text | Empty-handed figure on flat `#00ff00` |

## Output

- Master: `ArtSource/Generated/Characters/Detective/Paperdoll/voss_paperdoll_front_chroma_v11.png` (flat `#00ff00`)
- Processed runtime (unchanged ID): `RainShadow Shared/Resources/Art/UI/Inventory/voss_paperdoll_front_rgba_v01.png` at 1024×1536 RGBA

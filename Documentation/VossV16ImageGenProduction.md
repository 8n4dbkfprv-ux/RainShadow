# V16 ImageGen detective silhouette production

> **SUPERSEDED FOR PRODUCTION BY V17 (2026-08-08).** V16 is retained as
> incomplete historical work. The current exact-reference identity, isolated
> installer and acceptance status are documented in
> `VossV17ExactReferenceProduction.md` and
> `ArtSource/Prompts/character_exact_reference_v17.md`.

Status: production contract and validation infrastructure.  
Branch base: movement-parity commit `1d1f78cf`.  
Working branch: `codex/voss-v16-imagegen`.

V16 is a new, isolated Image Generator track. It must not consume or modify the
unfinished V15 Blender worktree, and it must not merge the later noisy local art
commit. The only assets selectively carried forward from that history are the two
approved V13 review keys stored under `PreRendered3DV16/References/`.

The copy/paste authoring contract, reference roles, exact palette, prompt templates
and 148 source filenames live in
[`character_silhouette_v16.md`](../ArtSource/Prompts/character_silhouette_v16.md).
This document records how those masters become the unchanged runtime interface.

## Immutable product contract

- Harlan Voss keeps his existing early-thirties clean-shaven face, short hair,
  open clean-hem mid-calf belted coat, cream shirt, mustard waistcoat, green tie,
  charcoal trousers and brown shoes.
- The supplied front/back screenshots are anatomy-only references. V16 borrows
  their broad shoulder/upper-back mass, thick arms/hands/legs, narrow belt and
  chunky shoes, never their person, clothing or texture.
- V16 uses the built-in/default Image Generator exclusively, one call per image.
  Selected project outputs are copied under
  `ArtSource/Generated/Characters/Detective/PreRendered3DV16/`; they may not remain
  only in Codex generated-image storage.
- Runtime atlas folders, texture identifiers, paperdoll ID
  `voss_paperdoll_front_rgba_v01`, anchor `(0.5, 40/256)`, nearest filtering,
  180×180 actor node, contact shadow and world chair stay unchanged.
- No Swift API, asset loader, target membership, collision radius, navigation
  profile or pathfinding change belongs to V16. Art clears the environment.

## Source and derived inventory

The manifest accepts 148 Image Generator masters from the flat `Frames/` folder:

| Authored masters | Count |
|---|---:|
| 9 directions × 4 standing-idle phases | 36 |
| 9 directions × 8 walk phases | 72 |
| NE/SE × 8 seated-idle phases | 16 |
| NE/SE × 12 stand-up phases | 24 |
| **Total Image Generator outputs** | **148** |

Local deterministic derivation adds four explicit SE idle cells by mirroring SW
and adds 24 sit-down cells by exact reversal of stand-up. That yields 176 primary
body presentations. The 16 NE upper/lower seated compatibility layers and 16
transparent seated-arm cells preserve the existing 208-file Voss atlas contract:

| Atlas | Runtime cells | Derivation |
|---|---:|---|
| `VossIdle.atlas` | 40 | 36 authored + 4 mirrored SE |
| `VossWalk.atlas` | 72 | authored |
| `VossSeatedIdle.atlas` | 32 | 16 authored full bodies + 16 compatibility layers |
| `VossSeatedArms.atlas` | 16 | transparent compatibility cells |
| `VossSeatTransitions.atlas` | 48 | 24 authored stand-up + 24 exact reversed sit-down |
| **Total** | **208** | public names unchanged |

## Production gates

Generation is deliberately serial at its approval points even though individual
calls remain separate:

1. Generate front, profile, back and dimetric anchors separately. Process through
   V14 and review the locally composed front/back identity-and-shape sheet.
2. Generate nine neutral gameplay keys (`s`, `ssw`, `sw`, `wsw`, `w`, `wnw`,
   `nw`, `nnw`, `n`). Each approved key is idle phase 00.
3. Review mirrored SE and authored rear-NW gameplay keys, the inventory paperdoll
   at 220×315, and office/city composites at the branch's actual 180×180 actor node.
4. Generate and process the complete eight-frame SW walk proof. Review identity,
   mass, coat fit, foot plants, loop closure, chroma edge and wardrobe stability at
   0.25× playback. The approved proof becomes the final SW walk source.
5. Only then generate the remaining masters as individual constrained edits. Each
   source cell remains the absolute authority for camera, pose, facing, foot plant,
   coat motion and animation phase.

No Image Generator call may produce a sprite sheet. Contact sheets, proof strips
and environment previews are deterministic local compositions.

## V14 processing lock

V16 reuses `ArtSource/Processing/crunch.py`: chroma removal and despill,
restrained craft softening, 56 native body rows, hard 1-bit figure alpha,
64 colours allocated as per-material ramps without dithering, nearest enlargement
to a 200-pixel body, and registration on a 512×512 RGBA canvas. Four alpha-1 corner
sentinels survive while every body-edge pixel is fully transparent or opaque.

Wardrobe preservation is mandatory. Installation must behave as if
`RAINSHADOW_PRESERVE_WARDROBE=1` is set and must fail closed if any legacy colour
lock would flatten or delete the shirt, waistcoat, trousers or tie. In particular,
never run `relock_voss_identity_v12.py`: its purpose is to restore the old body.
V12 processors may be parameterized or wrapped, but V12/V13 masters must not be
overwritten.

Installation is two-phase: validate and build every file in staging; create a
versioned backup of all current Voss atlases; replace atlases only after all gates
pass. A failed validation leaves the shipped atlas bytes untouched.

## Acceptance matrix

| Gate | Required result |
|---|---|
| shape | normalized front/back opaque width ÷ body height 0.40–0.43; readable shoulder-to-belt taper |
| canvas | 512×512 RGBA; four alpha-1 corners; no partial-alpha body fringe |
| registration | feet row 433; bbox centre within 2 px; standing 198–202 px; seated 150–160 px |
| wardrobe source | front key hue spread ≥0.45; eight locked material midtones |
| wardrobe runtime | front and front-three-quarter hue spread ≥0.18; rear never paints shirt/waistcoat/tie onto the back |
| movement | no head/torso pulse; ≤2 px head jitter; stable foot plant; clean eight-frame loop at 0.25×; ≥12/16 displayed facings readable without labels |
| seated idle | centroid drift ≤2 px; neutral IoU ≥0.86 |
| transition | adjacent crown retreat ≤4 px; total rise 38–50 px; head 19–29 px; head-width drift ≤1.30 |
| sit-down | every PNG exactly equals the reverse-index stand-up PNG |
| scene | exactly one visible world chair; art contains no chair or contact shadow |
| display | inventory 220×315; actor 180×180 in office and city over warm and cool backgrounds |

`VossWardrobeColorTests` intentionally checks the material palette and hue
separation rather than perpetuating the old single face/coat mean. Existing scale,
facing, locomotion, chair-egress and navigation tests remain in force.

## Verification sequence

Run the versioned manifest validator and V16 QA/contact-sheet generator before
installation. After atomic installation, run on macOS from outside any iCloud
resource-fork path:

```bash
swift test --scratch-path /tmp/RainShadowSwiftPM
```

Then run the README's canonical iOS Simulator and macOS `xcodebuild` commands and
perform the in-game office/city review. A portrait regeneration is not part of the
normal path. Keep the existing bust unless the processed 220×315 paperdoll exposes
an obvious face or visible-shoulder mismatch; if it does, regenerate only that bust
while preserving the current face.

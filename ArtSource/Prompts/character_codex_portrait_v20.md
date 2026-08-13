# Harlan Voss Codex portrait-first V20

V20 is a clean, portrait-first replacement made only with Codex's built-in
default `image_gen` tool. The production minimum is **152 separate calls**:
four identity anchors and 148 gameplay masters. A call produces one candidate
image; sprite sheets, CLI/API generation, external drivers, and silent generator
fallbacks are forbidden.

## Immutable authorities

The V20 copies below are byte-locked by `voss_v20_manifest.json`:

| Reference | SHA-256 | Role |
|---|---|---|
| `References/dialogue_portrait_harlan_voss_v01.png` | `13a5f349a2c08fb7517ae9cbb8a1b3953489458e654286ae3e29631782e8ec1d` | Face law; never rewritten or installed by V20 |
| `References/voss_target_front_three_quarter.png` | `aceb190e63a06b1ea3fadc9a4e971dab7e1f086e00f7752e6aeebe95823ac659` | Front construction and wardrobe scaffold |
| `References/voss_target_profile_w.png` | `e69eaa5bcf80a78cb2d36a90daaf960e0ee48d5ddd99c80b52fe8d15997cbf74` | W-profile construction scaffold |
| `References/voss_target_back.png` | `3e36953a2f7d653147c78c3f6c32f732ecfeacf3ad02c1b2c284aa5f9d964ef0` | Rear coat construction scaffold |

The 148 hashed PNGs in `PoseAuthorities/` are exact copies of V17 authorities.
They control pose, phase, feet, camera, and silhouette only; they never control
Voss's identity or wardrobe. V19 `Frames/` and `Keys/`, Lila, and the retired
dark-hair/mustard-waistcoat master are forbidden references.

## Identity and craft lock

Every face-bearing call must keep the portrait's stern angular adult face,
blue-gray eyes, swept auburn hair, and pronounced auburn sideburns. The outfit
is a chocolate double-breasted belted mid-calf trench with lapels, epaulettes,
dark buttons, cuff straps, rear storm flap and vent; cream open shirt; loose
black tie; charcoal cuffed trousers; and brown lace-up shoes.

Hard rejects: mustard waistcoat, green tie, olive coat, dark or black hair,
hat, abbreviated coat, invented shirt/tie/face on rear views, photorealism,
modern PBR, direct pixel art, chair, prop, floor, contact or cast shadow,
scenery, text, border, cropped crown, or cropped shoes.

## Shared gameplay prompt lock

Use this identity/craft block in every gameplay edit, followed by a precise
view and pose sentence derived from the inspected pose authority:

> Preserve the supplied pose target's exact camera, facing, gait phase, body
> silhouette, hand placement, and foot placement. Render Harlan Voss as one
> complete uncropped full-body late-1990s Infinity Engine pre-rendered game
> figure: stern angular face, blue-gray eyes, swept auburn hair, pronounced
> sideburns; chocolate double-breasted belted mid-calf trench, cream open shirt,
> loose black tie, charcoal cuffed trousers, brown lace-ups. Use smooth broad
> matte forms and restrained upper-left baked light, not direct pixel art,
> photorealism, or modern PBR. Place only the figure on a perfectly uniform flat
> `#00ff00` field with generous green clearance. No floor, shadow, chair, prop,
> weapon, text, border, or scenery.

For rear-facing calls, replace all face-bearing language with:

> This is a true rear view. Show only swept auburn hair and the back of the
> chocolate coat, including its storm flap and vent. Do not reveal a face,
> sideburn, cream shirt, tie, front buttons, or front lapels.

## Fixed reference routing

Reference order is contractual and is enumerated per output in
`master_inventory` and the provenance skeleton.

| Output family | Exact edit inputs |
|---|---|
| `s` | V17 pose target, immutable portrait, approved front anchor |
| `ssw`, `sw`, `wsw` | V17 pose target, immutable portrait, approved SW-dimetric anchor |
| `w` | V17 pose target, immutable portrait, approved W-profile anchor |
| `wnw` | V17 pose target, approved W-profile anchor, approved back anchor; **no portrait or front anchor** |
| `nw`, `nnw`, `n` | V17 pose target and approved back anchor only; **no portrait, front scaffold, front anchor, or dimetric anchor** |
| Idle phases 01–03 and every walk phase | The same fixed direction inputs plus that direction's approved idle phase-00 key; never the previous animation phase |
| NE seated idle / stand-up | V17 pose target, approved back and W-profile anchors, approved NE seated-neutral and mirrored-NW standing endpoints; no portrait/front inputs |
| SE seated idle / stand-up | V17 pose target, immutable portrait, approved SW-dimetric anchor, approved SE seated-neutral and mirrored-SW standing endpoints |

Anchor inputs are fixed and hash-recorded too. The initial front route is
portrait + accepted front edit target + front scaffold; a width-correction edit
may use only its hash-locked prior candidate plus the portrait. Profile uses
portrait + accepted W-profile edit target + profile scaffold. Back uses the
accepted rear edit target + back scaffold only, never the portrait or a front
anchor. SW dimetric uses the exact V17 `idle_sw_00` pose authority + portrait +
accepted dimetric wardrobe/craft target + front scaffold. These extra edit
targets live under `References/GenerationInputs/`, and every rejected iteration
that remains in an accepted candidate's lineage is hash-bound under
`Proofs/RejectedAnchors/`. The seated-neutral bootstrap call omits its
not-yet-existing self reference, then becomes the fixed seated endpoint for the
rest of that chain.

## Call and provenance procedure

For each target:

1. Inspect the local pose authority and all route-mandated references.
2. Make exactly one built-in edit-generation call for that candidate.
3. Copy the selected result from Codex generated-image storage to the exact
   V20 path; do not overwrite a prior-tree asset.
4. Record the full final prompt, generator call ID, output SHA-256, ordered
   reference paths, and reference SHA-256 values in
   `imagegen_provenance_v20.json`.
5. Record visual approval separately in `approval_ledger_v20.json`. A file's
   existence or provenance record does not approve it.

Rejected results belong under `Proofs/Rejected*` and never in `Frames/`,
`Keys/`, `UI/`, or `Staging/`.

## Ordered approval gates

1. Approve front, W-profile, back, and SW-dimetric anchors. Processed front and
   back width/height must each be 0.40–0.43.
2. Approve nine idle phase-00 keys and labelled/unlabelled 16-facing sheets,
   with explicit rear-hemisphere review.
3. Approve complete SW and N eight-frame walk proofs: raw/processed strips and
   quarter-speed loops.
4. Approve the remaining 27 idle and 56 walk masters, then all nine loops.
5. Approve the NE seated/stand-up chain before producing and approving SE;
   derive sit-down locally as the exact reverse.
6. Derive the 1024×1536 RGBA paperdoll from the approved front anchor with a
   soft matte/despill and approve inventory, warm-office, cool-city, and
   one-world-chair desk presentations. The portrait remains byte-identical.
7. Hash-lock all required source, UI, and QA outputs before staging or install.

Gameplay masters pass only through the V14 chroma/matte, 56-row reduction,
per-material 64-color crunch, hard-alpha, scale normalization, and registration
path. Wrong art is regenerated; V19 upper-body freezing, foot rewriting,
garment stamping, recentering repair, and permissive error filtering are banned.

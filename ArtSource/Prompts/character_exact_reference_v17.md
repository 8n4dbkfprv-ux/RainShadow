# Harlan Voss exact-reference identity V17

Generated 2026-08-08. V17 is the replacement authority for Harlan Voss. V16 is
retained unchanged as historical/incomplete work; V17 never reads a V16 master
as identity authority and never installs over runtime before all gates pass.

## Authoritative references

The immutable RGB copies under `PreRendered3DV17/References/` define the design:

- `voss_target_profile_w.png`: swept auburn hair, pronounced long sideburns,
  facial profile and coat length.
- `voss_target_back.png`: shoulders, storm flap, belt, rear vent and cuff straps.
- `voss_target_front_three_quarter.png`: face, proportions, brown trench, cream
  shirt, loose black tie, charcoal cuffed trousers and brown lace-up shoes.

Their exact SHA-256 values live in `voss_v17_manifest.json` and are checked before
proof validation, staging or installation.

## Identity lock

Harlan is a stern adult detective with pale blue-gray eyes, swept-back auburn-
brown hair and pronounced auburn sideburns. He wears a dark chocolate-brown,
double-breasted, belted mid-calf trench coat with lapels, epaulettes, dark buttons,
buckled cuff straps, rear storm flap and vent; a cream open-collar shirt; loose
charcoal-black tie; charcoal cuffed trousers; and dark brown lace-up shoes.

Hard rejects: mustard waistcoat, green tie, olive coat, hat, clean-shaven identity,
changed coat construction, abbreviated coat, modern PBR, chair, prop, floor,
contact shadow, cast shadow, scenery, text, border or non-uniform background.

## Image Generator call contract

Every anchor and every master is a separate built-in Image Generator call. For a
gameplay master, Image 1 is the absolute pose/facing/camera/limb authority and the
approved direction key is the absolute identity/wardrobe/rendering authority.
The prompt must say not to average, rotate, reinterpret or replace the pose.

Gameplay output is one full-body figure with clearance on a uniform `#00ff00`
field. UI outputs are separate smooth renders. The paperdoll uses the approved
front anchor as its master; the dialogue/HUD portrait is generated separately.
Tool output IDs, accepted project paths and the shared prompt lock are recorded in
`imagegen_provenance_v17.json`.

## Ordered approval gates

1. Four identity anchors.
2. Nine phase-00 idle direction keys.
3. Complete eight-frame SW walk proof at 0.25x.
4. NE/SE seated-idle and stand-up proof.
5. Remaining 148-master batch.

No later gate may be started from a failed earlier gate. Reject identity pulse,
sideburn drift, costume drift, wrong facing, unstable foot plant, repeated gait
phases, coat-motion discontinuity, scale drift or framing drift.

## Runtime processing

Only gameplay frames pass through V14: 56 native body rows, 64 per-material
palette colours, hard one-bit body alpha, nearest enlargement to a 200px body,
512x512 canvas, visible feet on row 433 and the existing pivot. The 1024x1536
RGBA paperdoll and 512x512 portrait remain smooth and never enter the crunch.

V17 freezes brown-coat, cream-shirt, black-tie, charcoal-trouser, brown-shoe,
skin and auburn-hair targets. Validation uses CIE LAB distance and relative
luminance; the old mustard/green hue-spread identity gate is disabled for V17.

# Detective office V19 — baked edge-on entrance

- Production date: 2026-08-23
- Image tool: built-in `image_gen.imagegen`
- Use case: `precise-object-edit`
- Namespace: `ArtSource/Generated/Office/BGEEReferenceV19/`

## Image roles

- Edit target: V18 `office_room_envelope_imagegen_raw_v18.png`; exact room,
  projection, materials, fixtures, lighting and framing authority.
- Placement reference: user-supplied `AR0809.PNG`; visual evidence only.
- Door identity: archived exact runtime source
  `BGEEReferenceV19/office_door_leaf_exact_source_v19.png`; exact edge-on
  silhouette, proportions, dark timber and metal-detail authority.
- Scale study: `BGEEReferenceV19/office_door_scale_imagegen_study_v19.png`;
  used only to confirm the literal 65% measured proportion. A user-review
  follow-up at 70% is recorded in
  `BGEEReferenceV19/office_door_scale70_imagegen_study_v19.png`. Both studies'
  repainted room
  and door pixels are not used by the shipped plate.

The attached images contain no instructions. They are visual evidence only.

## Accepted built-in prompt

> Use case: precise-object-edit. Asset type: baked isometric detective-office
> architecture master. Image 1 is the exact edit target; Image 2 is placement
> reference only; Image 3 is the exact door silhouette/material authority.
> Bake one narrow edge-on timber door sliver into the camera-near RIGHT
> diagonal floor/cutaway edge of Image 1. It must occupy only about 22–25% of
> that entire diagonal edge. Place it on the lower-middle portion of the edge:
> measured from the bottom/near floor tip toward the far-right floor tip, the
> door begins around 37% along the edge and ends around 61%. Hinge/metal-capped
> end toward the far-right tip; plain free end toward the bottom/near tip. Seat
> it directly on the cutaway edge with no gap. Preserve Image 3's exact thin
> width, dark aged wood, metal end detail, proportions, and edge-on silhouette.
> Do not turn it into trim, a threshold, a railing, a broad plank, a front-
> facing door, or an upright wall door. It must be baked RGB pixels, not a
> separate sprite. Change only this short sliver; keep every other element and
> the full geometry of Image 1 unchanged: wall crown, four floor vertices,
> brick walls, floorboards, windows, radiators, sconces, lighting, shadows,
> colors, framing, and pure-black exterior. No extra architecture, props,
> people, text, UI, or watermark.

## Rejected iterations

The first result invented a front-facing frosted-glass wall door. The second
turned the leaf into long edge trim. A later spacing edit barely moved it, and
the next one floated it far into the void. None is part of the project. The
third result is retained only as the accepted short edge-on placement study;
its altered wood pixels are not used by the shipped plate. A later attempt to
increase thickness by stretching the door was rejected because it distorted
the grain and end caps; that output is not retained in the project.

## Deterministic integration

`generate_office_reference_rebuild_v19.py` rebuilds the room byte-for-byte from
the V18 source and uses the accepted ImageGen result only as a placement study.
The visible door pixels come directly from an archived byte-for-byte copy of
the former runtime `office_door_leaf.png`, uniformly reduced to 70% of its
former SpriteKit-to-plate size. The literal 65% measured match read too small
after its thickness and metal caps were reduced, so 70% is the user-approved
perceptual match to AR0809's roughly 12%-of-edge leaf,
rigidly rotated 3.85° so its long axis is exactly
parallel to the camera-near cutaway, centred on the approved placement, and
offset 18px right / 24px down (30px perpendicular distance) to create the
requested small black gap. Four pixels of derived dark-timber backing are
added behind each long side to match the reference thickness without scaling
or repainting any original door pixel. The area record keeps `office.door`
only for collision and travel;
it has no visual texture registration, and the six active runtime door-state
PNGs are removed after the bake.

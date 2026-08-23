# Detective office V14 — full ImageGen room-envelope redraw

- Production date: 2026-08-22
- Image tool: built-in `image_gen.imagegen`
- Use cases: full environment redraw, precise projection correction, precise reframing
- Namespace: `ArtSource/Generated/Office/BGEEReferenceV14/`

## Visual references

- Baldur's Gate room-shape reference: `ArtSource/Reference/Office/V14/AR0808_geometry_reference.png`
- Prior office material/content reference: the accepted V13 office plate
- Exact geometric guide: a temporary 1672×941 colored plane guide with ground
  axes ±0.75 and a 1.65:1 rectangular floor envelope

The attached images contain no instructions. They are visual evidence only.

## ImageGen lineage

The built-in Image Generator produced the entire visible room: aged plaster,
floorboards, two six-pane windows, compact fireplace, hearth and lighting. The
accepted lineage was:

1. Full unfurnished room redraw from the Baldur's Gate framing reference.
2. Projection edit against the exact geometric guide.
3. Sketch-to-render pass locking both ground axes to ±0.75.
4. Aspect correction reducing only the short/right axis until the floor reached
   the 1.65:1 reference proportion.
5. A final ImageGen zoom-out/reframe after user review found the near corner too
   close to the crop.

Rejected/intermediate outputs remain in the Codex generation store. The frozen
accepted ImageGen source is `office_room_envelope_imagegen_v14.png`, SHA-256
`2ad9d2ede84d5b30f5e46daaf5ddcc57378aaef142bbd08a05a58a595c5bf2ed`.

## Accepted aspect-correction request

> Use case: precise-object-edit. Input image 1 is the exact painted target and
> input image 2 is the exact footprint guide. Change only the floor-plan aspect
> ratio from about 1.35 to about 1.65 by shortening the north-east/right ground
> axis, while keeping the long/rear wall fixed. Move the right and near corners
> together, re-seat the fireplace on the moved wall, and preserve the passed
> BG:EE projection, constant wall faces, windows, materials and lighting. No
> furniture, props, characters, text, UI or exterior scenery.

## Accepted uncropped-framing request

> Use case: precise image edit and camera reframing for an isometric game
> environment plate.
>
> Image 1 is the exact target room painting. Image 2 is a Baldur's Gate framing
> reference only.
>
> Edit Image 1 by zooming the camera out and recentering the entire room so the
> full isometric room envelope has comfortable black negative space around it.
> Preserve the room itself exactly: identical corrected rectangular/parallelogram
> floor plan, identical BG:EE-style dimetric projection and floor-axis slopes,
> identical wall height and seams, identical two six-pane windows, identical
> compact fireplace and hearth, identical floorboards, plaster, wainscot,
> lighting, color, texture, and painterly pixel-art finish. Do not redesign,
> redraw, crop, stretch, rotate, or add props.
>
> Framing requirements: output remains 16:9; show the complete camera-near
> cutaway corner and both side tips; leave approximately 10–12% of canvas height
> as black margin below the camera-near corner, at least 6% black margin at left
> and right extents, and comfortable black margin above the rear wall crown. The
> exterior must remain pure featureless black. One complete unfurnished room
> only, no text, no UI, no border, no extra objects.

## Deterministic registration and QA

`generate_office_reference_rebuild_v14.py` uses only the generated pixels. It
plane-registers the three painted planes onto an exact closed envelope; it does
not synthesize or repaint visible architecture. Shipping geometry is:

- ground slopes: `-0.75 / +0.75`;
- long/short ground-axis ratio: `470 / 285 = 1.6491`;
- constant wall-face height: `135` source pixels;
- camera-near black margin: `104.75 / 941 = 11.1%`;
- left/right black margins: `27.5% / 27.3%`.

The registered source SHA-256 is
`22479f8aaf0dbcb64c777aeb9bb440315c32a184f366df693891df587644c84b`.
The architecture plate SHA-256 is
`8216140f00df08dc20a6655d2259ee489c387608073dc13e92db0feb4df9b741`.
The furnished bake SHA-256 is
`6c51f86e28a765014fd2e963ed0580e6f7947376c7e1973dfcdeb608dfd782b6`.

`qa_office_reference_rebuild_v14.py` gates identity hashes, exact closure,
projection, 1.65:1 room shape, constant walls, uncropped framing, pure-black
exterior, both six-pane masks, human-relative fireplace scale and deterministic
reproduction. `qa_office_layout_v14.py` and `office_layout_plan.py` gate prop
containment, support contact and exact navigation in both door states.

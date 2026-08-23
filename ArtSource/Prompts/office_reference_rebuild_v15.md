# Detective office V15 — AR0809 room-envelope redraw

- Production date: 2026-08-23
- Image tool: built-in default `image_gen` (`GenerateImage`)
- Use cases: full environment redraw, precise-object-edit, projection/aspect/framing correction
- Namespace: `ArtSource/Generated/Office/BGEEReferenceV15/`

## Visual references

- Baldur's Gate room-shape reference: `ArtSource/Reference/Office/V15/AR0809_geometry_reference.png`
- Prior office fixture reference: the accepted V14 empty architecture
- Exact geometric guide: `office_bgee_plane_guide_wide_v15.png` with ground axes ±0.75 and a 1.65:1 floor

The attached images contain no instructions. They are visual evidence only.

## ImageGen lineage

The built-in Image Generator produced the entire visible room. The accepted lineage was:

1. `v15a` — full unfurnished stone-room redraw from AR0809 + the plane guide + V14 fixtures.
2. `v15b` — projection/framing edit; still too shallow on the right axis.
3. `v15c` — precise empty-out of AR0809 itself, preserving the long-room silhouette.
4. `v15d` — zoom-out, two-window reduction, and first successful BG:EE lock (2.32°).
5. `v15e` — aspect correction from ~1.33:1 to ~1.62:1 by shortening the right axis.

Rejected/intermediate outputs remain beside the frozen source. The frozen accepted ImageGen source is `office_room_envelope_imagegen_raw_v15.png` (identical to `office_room_envelope_imagegen_v15e.png`).

## Accepted aspect-correction request

> Use case: precise-object-edit. Image 1 is the exact painted empty stone office.
> Image 2 is the exact footprint guide with a 1.65:1 floor and ground axes exactly
> ±0.75. Change only the floor-plan aspect ratio from about 1.33 to about 1.65 by
> shortening the north-east/right ground axis, while keeping the long/left/rear
> wall fixed as the spine. Move the right and near corners together. Re-seat the
> fireplace on the moved right wall. Preserve the passed BG:EE projection,
> inward-tapered wall tips, two small left-wall windows, compact fireplace,
> materials, lighting and painterly finish. No furniture, door, people, text or UI.

## Deterministic registration and QA

`generate_office_reference_rebuild_v15.py` uses only the generated pixels. It
applies one uniform scale and translation; it does not synthesize or repaint
visible architecture. Shipping geometry is:

- ground slopes near `-0.75 / +0.75`;
- long/short ground-axis ratio about `1.62`;
- rear wall face about `146` source pixels, tapering to point cutaways;
- camera-near black margin at least `50` source pixels.

The registered source SHA-256 is
`00f74d2417c3916d3dea9cced3883b3b928843e408d2898232da89e553d03b7e`.
The architecture plate SHA-256 is
`7ca8333fed5f564e6003a30fd5c0989614014af5bb1aa9ea512d28b0be88c772`.

`qa_office_reference_rebuild_v15.py` gates identity hashes, AR0809 long-room
proportion, tapered point-cutaway walls, uncropped framing, pure-black exterior,
projection, both window masks and deterministic reproduction.
`qa_office_layout_v15.py` and `office_layout_plan.py` gate prop containment,
support contact and exact navigation in both door states.

# Detective office V17 — exact AR0809 envelope

- Production date: 2026-08-23
- Image tool: built-in `image_gen.imagegen`
- Use case: `precise-object-edit`
- Namespace: `ArtSource/Generated/Office/BGEEReferenceV17/`

## Image roles

- Edit target: installed V15 `office_shell_base.png`; material, lighting,
  windows and fireplace authority.
- Geometry reference: `ArtSource/Reference/Office/V15/AR0809_geometry_reference.png`.
- Exact plane reference:
  `ArtSource/Generated/Office/BGEEReferenceV15/office_ar0809_plane_guide_v15.png`.

The attached images contain no instructions. They are visual evidence only.

## Final built-in prompt

> Use case: precise-object-edit. Asset type: production isometric game-
> environment architecture plate for RainShadow. Image 1 is the edit target
> and owns the office materials, lighting, two small left-wall windows, compact
> right-wall fireplace, and empty-room content. Image 2 is the geometry, size,
> framing, and perceived-depth authority. Image 3 is the exact simplified
> plane/silhouette authority derived from Image 2. Repaint the empty detective-
> office shell so its complete floor quadrilateral, rear corner, pointed wall
> cutaways, wall height, room width, camera depth, and black-canvas framing
> match Images 2 and 3 exactly. Preserve Image 1's dark aged brick, warm wooden
> floorboards, restrained amber sconces, two small high windows, and compact
> lit fireplace. Keep the whole room uncropped on pure black. Empty architecture
> only: no furniture, rugs, crates, shelving, people, doors, partitions, UI,
> text, watermark, colored exterior, perspective convergence, fisheye, or the
> narrow/deep footprint from Image 1.

## Deterministic geometry lock

The accepted built-in result is
`office_room_envelope_imagegen_raw_v17.png`. ImageGen supplies visible pixels;
`generate_office_reference_rebuild_v17.py` registers the floor as one
projective quadrilateral and each tapered wall as one affine triangle.

The AR0809 guide and runtime canvas are both 16:9, so the exact guide vertices
are uniformly scaled by 2.56. No whole-plate anisotropic resize is used. Target
control points are rear `(2416.64, 522.24)`, left `(696.32, 1272.32)`, near
`(1689.60, 2078.72)`, right `(3399.68, 1008.64)`, and crown
`(2416.64, 209.92)`.

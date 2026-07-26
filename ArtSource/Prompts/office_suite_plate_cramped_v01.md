# Office suite plate — cramped (walls pulled in)

- Generated: 2026-07-26
- Mode: Image Generator only (no code cutaways / graybox placeholders).
- Intent: Same camera, materials, and prop-scale world as the approved suite, but the painted room footprint is shrunk so walls hug the existing furniture cluster.
- Best furnished review: `ArtSource/Generated/Office/office_interior_cramped_furnished_v02.png`
- Best empty architecture master: `ArtSource/Generated/Office/office_suite_plate_cramped_v03.png`
- Shipped tight plate: `office_suite_plate_cramped_tight_v01.png` — master placed at **`SUITE_PLATE_SCALE = 0.60`** on 4096×2304 so unchanged modular prop scale fills the floor
- Process: `ArtSource/Processing/process_office_suite_plate_cramped_v01.py --scale 0.60`
- Room plan: `SUITE_PLATE_SCALE`, fitted `REAR` / `AXIS_*` in `office_room_plan.py`

## Generation prompt

```text
Use case: stylized-concept
Asset type: production empty environment plate for a fixed-camera isometric CRPG
Primary request: Rebuild Image 2 (the RainShadow detective-office suite architecture) as ONE coherent empty architectural plate whose OUTER WALLS are pulled tightly inward around the furniture cluster shown in Image 1. The room must feel small, cramped, and claustrophobic — a tight 1940s private-eye office — not a large open floor. Minimize empty floor space. Keep the EXACT same camera view, angle, perspective, framing, lighting, art style, textures, materials, and atmosphere as Image 2. Do NOT shrink or enlarge any imagined furniture: the wall-to-furniture clearances in Image 1 define how close the new walls must sit; furniture itself must NOT be painted into this plate.
Input images: Image 1 is the furnished redesign preview — authoritative ONLY for the furniture cluster footprint and how tightly walls should wrap that cluster (desk+chairs+rug, records/bookshelf run, personal corner, waiting nook). Image 2 is the current empty suite plate — authoritative for camera registration, dimetric projection, two-tone stained plaster over dark wainscot, worn floorboards, window recess craft, exterior doorway craft, partition craft, pure-black exterior silhouette, and lighting.
Room shrink specification: Pull the camera-near cutaway edges substantially toward the furniture cluster so most of the large empty foreground floor disappears. Optionally bring the side walls slightly inward if needed so the private office and waiting wedge both read as tight. Keep a short interior partition with one doorway opening dividing private office (left) from a compact waiting nook (right), matching Image 2's partition materials and perspective — but the waiting nook must be small, not a wide empty hall. Preserve the left-wall raised window recess and the upper-right exterior doorway as built architecture at the SAME painted scale as Image 2 (do not enlarge or shrink openings relative to wall height).
Cutaway: same open camera-facing near edges as Image 2 (no full front wall blocking the view). Pure black only outside the building silhouette.
Scene/backdrop: empty 1940s private-detective suite after hours; worn dark wooden floorboards; stained two-tone plaster over dark wainscot; noir, lonely, lived-in, cramped; cooler light near the window, warmer residual light in the waiting nook.
Style/medium: richly pre-rendered late-1990s isometric PC CRPG environment art; painterly baked textures; modest native-resolution softness; no modern PBR gloss; texture scale must match Image 2.
Composition/framing: exact 16:9 landscape; keep the room silhouette centered similarly to Image 2, but with a much smaller floor diamond so the furniture cluster from Image 1 would nearly fill the room with only narrow walkways.
Constraints: EMPTY ARCHITECTURE ONLY. No desk, chairs, rug, bookshelf, filing cabinets, coat rack, boxes, radiator props, sink, fan, people, door leaves, window glass/sash props, UI, text, logos, watermark, selection circles, debug overlays, or modular graybox slabs. Do not invent a new camera angle. Do not zoom in as a cheat for "smaller" — actually paint a smaller room plan at the same projection scale.
Avoid: oversized empty floor; luxury open suite; waist-high railing walls; freestanding door frames; patch-composite seams; purple lighting; clean modern office look; painting any furniture.
```

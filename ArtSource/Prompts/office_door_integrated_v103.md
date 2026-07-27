# Office entrance V10.3 — integrated jamb, reveal, and floor-projected fall

- Generated: 2026-07-26
- Mode: built-in Image Generator edit
- Registered edit target: `tmp/door_rebuild_v103/current_suite_crop.png`
- Retained generator output: `ArtSource/Generated/Office/door_architecture_integrated_ig_v103.png`
- Registered runtime patch: `ArtSource/Generated/Office/door_architecture_integrated_patch_v103.png`
- Runtime suite plate: `RainShadow Shared/Resources/Art/Areas/DetectiveOffice/office_suite_plate.png`
- Runtime door edge: `RainShadow Shared/Resources/Art/Props/Office/office_door_leaf_thickness.png`

## Final prompt

```text
Use case: precise-object-edit
Asset type: registered architectural crop for a late-1990s pre-rendered isometric noir CRPG
Input image: Image 1 is the edit target and exact composition/registration authority.
Primary request: Repaint only the large black doorway area so it reads as a real open doorway built into the existing wall, not a pasted black polygon or freestanding picture frame. Preserve the exact doorway location, overall black clear-opening silhouette, floor contact, camera projection, crop framing, surrounding plaster wall, wainscot, adjacent foreground partition, and lighting.
Doorway construction: integrate slim battered dark-walnut jambs flush into the wall; add a visible inner reveal showing wall thickness on the side and header planes; add restrained plaster returns around the casing; add a thin worn wooden threshold seated on the floor; add subtle near-black ambient-occlusion/contact shadows where jambs meet plaster and floor. Keep the hallway beyond the clear opening nearly black, with only extremely faint depth falloff. The casing must feel embedded in the wall and share its perspective.
Style/medium: richly painted late-1990s isometric PC CRPG background, restrained painterly texture, non-photorealistic pre-rendered look matching the supplied room.
Lighting/mood: dim rain-soaked 1940s private office; very low warm edge light, deep shadows, no glowing orange wood.
Materials/textures: worn stained plaster, aged dark walnut, dull threshold, subtle chipped edges.
Constraints: change only doorway architecture and the immediately touching damaged wall pixels. No door leaf, no lettering, no knob, no hinges, no coat rack, no furniture, no character, no UI, no watermark. Do not move, resize, widen, shorten, rotate, or reinterpret the black clear opening. Do not alter the floorboards, left wall recess, or right foreground partition outside the doorway contact area.
Avoid: freestanding rectangular frame, bright orange trim, flat black pasted card, modern casing, perfect clean edges, extra openings, smeared horizontal bands, wall-panel seams.
```

## Runtime treatment

- The generated casing is feathered into the registered suite crop, then the approved black opening is re-punched from the architectural plan so its silhouette and navigation contract do not drift.
- The old freestanding frame sprite is no longer rendered; the wall plate owns the jamb, reveal, and threshold.
- The separate leaf uses a projective SpriteKit warp when it falls, plus a dark edge extrusion and a restrained floor contact shadow.
- The nearby coat rack is smaller and moved clear of the door so it cannot read as oversized hinge hardware.

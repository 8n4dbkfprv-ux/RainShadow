# BGEECrampedV09 material-generation record

The V09 room is a deterministic repaint, not an inpaint. Image generation is
restricted to the two flat source materials below. `office_v09_geometry.json`
and `office_cramped_architecture_mask_v09.png` own every architectural pixel.

## Floor prompt

Create one original, high-resolution, flat material painting for RainShadow's
V09 detective-office floor. Use the 3.27.22 PM reference only for the selected
small lower-right room's timber scale and period softness; use the 3.26.35 PM
and 11.57.57 AM references only for palette, lighting, material scale and
late-1990s pre-rendered softness. Ignore characters, green selection circles,
UI, dialogue, portraits, signs and screenshot bounds. Paint aged narrow tobacco
timber boards with muted amber, ingrained dirt, matte wear and subtle variation.
No room geometry, walls, rug, furniture, people, text, perspective convergence,
cast shadows, PBR gloss or photorealism.

Generated source:
`ArtSource/Generated/Office/BGEECrampedV09/floor_material_source_v09.png`

## Wall prompt

Create one original, high-resolution, flat material painting for RainShadow's
V09 detective-office walls. Use the same reference roles and contamination
rules. Paint smoke-stained olive-brown plaster above dark tobacco wainscoting,
with restrained water staining, rubbed age, muted dirty amber highlights, cool
green-brown shadows and late-1990s softly downsampled pre-rendered character.
No room geometry, floor, doors, windows, furniture, people, text, perspective,
cast shadows, PBR gloss or photorealism.

Generated source:
`ArtSource/Generated/Office/BGEECrampedV09/wall_material_source_v09.png`

The door edge-source files are the original RainShadow V08 generated timber
masters, carried forward without screenshot pixels and re-registered by V09's
single geometry manifest. Hover states change colour only.

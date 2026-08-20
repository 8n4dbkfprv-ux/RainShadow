# BGEETavernV10 material-generation record

The V10 room is a deterministic repaint, not an inpaint. Image generation and
procedural material painting supply only flat source textures.
`office_v10_geometry.json` and `office_tavern_architecture_mask_v10.png` own
every architectural pixel. Feldepost AR3351 and the 3:29 PM close-up are
measurement authorities only — their pixels never enter the plate.

## Floor prompt

Create one original, high-resolution, flat material painting for RainShadow's
V10 detective-office floor. Use the AR3351 tavern screenshot only for timber
scale and period softness; ignore characters, green selection circles, UI,
dialogue, portraits, pillars, furniture and screenshot bounds. Paint aged
narrow tobacco timber boards with muted amber, ingrained dirt, matte wear and
subtle variation. No room geometry, walls, rug, furniture, people, text,
perspective convergence, cast shadows, PBR gloss or photorealism.

Generated source:
`ArtSource/Generated/Office/BGEETavernV10/floor_material_source_v10.png`

## Wall prompt

Create one original, high-resolution, flat material painting for RainShadow's
V10 detective-office walls. Use the same reference roles and contamination
rules. Paint dark tobacco wood paneling with restrained smoke staining, rubbed
age, muted dirty amber highlights, cool green-brown shadows and late-1990s
softly downsampled pre-rendered character. No room geometry, floor, doors,
windows, furniture, people, text, perspective, cast shadows, PBR gloss or
photorealism.

Generated source:
`ArtSource/Generated/Office/BGEETavernV10/wall_material_source_v10.png`

## Column prompt

Create one original, high-resolution, flat material painting of stained square-column timber for RainShadow's V10 detective office. Dark tobacco boards, vertical grain, knots, matte wear, late-1990s softness. No column geometry, no room, no perspective, no PBR.

Generated source:
`ArtSource/Generated/Office/BGEETavernV10/column_material_source_v10.png`

## Door

The live leaf is not an upright office door. `process_office_door_bgee_tavern_v10.py` projects the wall timber onto the 3:29 PM close-up parallelogram: a long thin olive-brown sliver on the BG:EE wall axis (−0.75), top-edge highlight, no iron bands. Closed/mid/open are the same sliver at 282 / 360 / 442 px. Hover states change colour only. Screenshot pixels are never copied.

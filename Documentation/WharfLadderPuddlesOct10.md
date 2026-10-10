# Wharf Ladder puddle material — October 10

The current source is the subsequent **ShapesV2** revision below. It preserves
the approved texture and material, and replaces only the five puddle meshes.

The five existing `WL_Rain pool*` meshes use the original Image Generator
texture `wharf_puddle_bgee_albedo_v01.png` through their shared
`WL_Quay puddles` material. The reference was the small pools in the local
BG:EE `AR4000` area and its `WTLAKE` water tileset. Extracted reference pixels
remain in the ignored reference directory; they are not runtime assets.

The generated texture feeds sRGB base colour and a subtle bump, using planar
object coordinates at one repeat per four metres. Bump strength is 0.12 and
distance is 0.002 m, replacing the old coarse procedural relief. Roughness,
lighting, geometry, cameras and the existing puddle outlines are retained.

The source is based on the approved V19 geometry/V20 material bundle, saved as
`ArtSource/Generated/CityDistrict/WharfLadderPuddlesOct10/wharf_ladder_puddles_oct10.blend`.
The generated image is packed into that file. `application.json` records the
exact live Blender MCP material edit; `generation.json` holds the image prompt.
The historical V20 source remains available unchanged.

The day and dusk masters retain their native 10240×7680 framing and established
V19 page names. Package them with:

```sh
python3 ArtSource/Processing/package_wharf_puddles_oct10.py
python3 ArtSource/Processing/package_wharf_puddles_oct10.py --install-only
```

Before installation, inspect the native puddle crops under `Review/` and the
projection and outside-puddle image differences in `render_validation.json`.
The packager refuses a failed projection gate or significant renderer drift
outside the puddle bounds. It backs up replaced files and unlinks before copying
to avoid writing through historical hard links. The installation receipt hashes
the installed pages and protected area, avatar, shipping-office and door assets.

`restore_completed_city_areas.py` applies this package after V20 when the new
installation receipt is present, so an area restore retains the puddle update.

Validated installation: 43 art resources, with 230 protected files unchanged.
The day/dusk projection errors were 0.127°/0.172°. Outside padded puddle bounds,
the maximum channel differences from V20 were 3/2 levels out of 255, with mean
differences below 0.0004. Authored transforms, mesh geometry, cameras and light
parameters match V20 exactly; the comparison uses authored transforms because
inactive dusk lights initially have unevaluated cached world matrices.
The macOS Debug build passed, and all 43 bundled art hashes match the installed
payload. Runtime rendering was reviewed through the day/dusk source renders;
the game was not relaunched as part of this change.

## ShapesV2 — rounded outlines and shallow edges

The original puddles had a 30-segment perimeter and floated at z=0.054 m above
setts whose sampled tops are approximately 0.013–0.023 m. Each replacement has
an asymmetric, rounded outline with concave inlets, a flat centre at z=0.026 m,
and a 45 mm shallow rim descending to z=0.016 m. This seats the edges into the
existing stonework. The five silhouettes use separate variants. Each mesh has
368 vertices, 733 edges and 366 faces (550 triangles), with no degenerate
triangles or inverted faces. The original generated texture, mapping, bump and
material graph are unchanged.

The saved source is
`ArtSource/Generated/CityDistrict/WharfLadderPuddlesOct10/ShapesV2/wharf_ladder_puddle_shapes_v2.blend`.
`ShapesV2/application.json` records the live MCP geometry edit. The earlier
material-only source remains intact. Comparison against that source confirms
that only the five named meshes changed; transforms, other objects, cameras,
lights and the puddle material graph remain identical.

Native Blender region renders use 160 pixels of padding around each original
puddle. `seat_wharf_puddle_shapes_v2.py` places them on the approved day/dusk
masters with a 32-pixel outer blend for independent denoising. The changed water
shapes remain wholly within the unblended centre; pixels outside the ten render
regions are preserved. Region hashes and boundary checks are recorded in
`ShapesV2/seating_receipt.json`.

```sh
python3 ArtSource/Processing/seat_wharf_puddle_shapes_v2.py
python3 ArtSource/Processing/package_wharf_puddles_oct10.py --shapes-v2
python3 ArtSource/Processing/package_wharf_puddles_oct10.py --shapes-v2 --install-only
```

The restore tool applies the ShapesV2 receipt after the material-only receipt.

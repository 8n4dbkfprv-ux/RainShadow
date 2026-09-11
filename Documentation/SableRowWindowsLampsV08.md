# Sable Row V08 — readable window and lamp texture

V07 included window and lamp maps, but their visible effect was insufficient.
The first window map mostly changed roughness, and fine pitting on nearly black
posts filtered away at the area camera. The user requested a visible correction.

Two new 1254×1254 texture masters were generated with the built-in image_gen:

- `textures/window_readable.png`: broader rain trails, rubbed patches and soot.
- `textures/lamp_readable.png`: larger chipped enamel and weathered iron patches.

The maps are saved in the project and packed into the V08 Blender model. Exact
prompts are in `readable_texture_revision.json`; the initial material correction
is recorded separately in `live_visibility_edit.json`. Original V07 masters and
the other four generated material families are retained alongside these files.

The window map now contributes visible surface colour and roughness, plus
variation in the transmitted brightness of lit apartment panes. Storefront glass
retains clear regions. Lamp posts and fittings use a less crushed paint range,
and the opal globes carry surface variation instead of uniform emission. The
existing point lights continue to illuminate the street; their placement and
power have not been changed in this pass.

A native crop was reviewed before final rendering. No vertices, topology or
object world transforms changed, confirmed by `geometry_integrity.json`.
Materials and UVs are intentionally outside that hash. The previously validated
search, height and cover bundle is inherited from V06, not regenerated or claimed
as a fresh five-test run. This is still a staged courtyard, not a full ward install.

[Comparison](../ArtSource/Blender/SableRowStudyV08/reviews/comparison.html)

[Blender model](../ArtSource/Blender/SableRowStudyV08/sable_noir_court_v08.blend)

[Exact prompts](../ArtSource/Blender/SableRowStudyV08/readable_texture_revision.json)

## Final checks

The final native 6144×4608 Blender plates pass the 1.5° BG:EE projection gate:
day 0.19°, night 0.23°. The close-up and night plate were visually reviewed.

The optional fresh SpriteKit preview could not complete in the restricted
environment: the interpreter and separately compiled preview both exited 139.
No fresh gameplay screenshot or test pass is claimed for V08. Its geometry
and inherited navigation/cover records are unchanged.

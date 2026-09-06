# Sable Row Blender look study V01

6 September 2026. A first editable reconstruction of a generated 1950s noir street concept. This is a separate art prototype, not an installed replacement for Sable Row.

## Deliverables

All study files live in `ArtSource/Blender/SableRowStudyV01/`:

- `concepts/sable_noir_court_01.png`: initial generated rainy noir street concept.
- `concepts/sable_noir_court_02.png`: second generated reference with brighter lighting and a requested higher camera.
- `concept_prompts.json`: exact prompts, using built-in ImageGen.
- `sable_noir_court_v01.blend`: editable Blender scene, materials, camera and lights; the original default scene is preserved separately.
- `sable_court_day.png`: Blender-rendered daylight look study.
- `sable_court_night.png`: the same camera and geometry with night lighting, rendered at 1800×1350.
- `geometry_proxies.json`: 33 geometry-derived footprint and cover bounds, plus four approach anchors. These are explicitly provisional authoring data.
- `live_build_stages.json`: retained live MCP authoring batches, including material and geometry construction.
- `review_01.png`, `review_02.png`, `review_03.png`: intermediate Blender renders used to inspect and correct the model.

The source `.blend` contains real geometry for the L-shaped apartment, court enclosure and gate, Voss's stoop, window frames, fire escape, diner, service garage, street paving, drains, bins, lamps, telephone wires, tree, bench, laundry and two stylized period sedans. No generated concept image is used as a flat background or projected facade texture in the scene.

## Camera and authoring

The orthographic camera uses elevation `asin(0.75)` (48.5904 degrees) and equal x/y ground components. Ground axes therefore project at ±36.87 degrees. Vertical edges remain vertical. The generated references express mood and layout; their imperfect camera geometry is not the authority.

The scene uses meters for modeling: 3.1 m apartment floor spacing, roughly 2.4 m door leaves, roughly 5 m sedans and 4.8 m street lamps. The daylight render is 2400×1800. These are proof-render dimensions, not a claim of finished runtime source density across a full 5120×3840 ward.

A 1.8 m upright projects to 59.53 pixels at the daylight export resolution. Ground footprints are exported in model meters and normalized camera coordinates with a bottom-left origin. Cover proxies are convex bounds of selected meshes, not exact occlusion polygons; details such as railings, stairs and actor depth ordering still require authoring.

The final `sable_court_day.png` passed `qa_plate_projection.py` at +36.72°/−36.69°, worst error 0.18° against the ±36.87° target. This checks camera agreement, not finished composition, collision or material quality.

The `.blend` is the editable authority for this study. All changes were executed against the live Blender instance through MCP, with intermediate viewport and rendered-image inspection. `live_build_stages.json` records the batches, but is not yet a standalone regenerative build pipeline. The current character rig and game resources were not touched.

## What this proves and what remains

This prototype demonstrates a concept-to-editable-geometry workflow and a stable camera. It also makes day/night relighting possible without changing the architecture. Ground-footprint tags and projected geometry can be derived from the same scene rather than from an unrelated city plan.

It does **not** yet meet the finished surface richness of the generated references or Baldur's Gate's hand-finished backgrounds. The sedans are simplified, some repeated architectural trim remains too uniform, and the street/roof materials need further authored wear and local detail. The courtyard and intersection are the intended composition proof, not a finished whole district.

Before installation: decide the final composition and extent, improve the material finish at actual play scale, establish the actor-to-world export transform, author exact door/occlusion semantics, export terrain conservatively, and run the normal game navigation and in-motion cover review. Footprint and silhouette proxies alone are not a finished ARE/WED equivalent. No runtime navigation tests or in-game walk-through have been claimed for this art study.

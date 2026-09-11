# Sable Row material pass V03

6 September 2026. A material-only refinement of the validated V02 courtyard
section, responding to the comparison with Baldur's Gate's surface detail.

## Changes

- Asphalt now combines centimetre-scale aggregate, smaller worn patches and
  broader tar variation. Residue follows the authored kerbs, rather than being
  spread equally over every surface. Existing repair patches retain a darker mix.
- Paving retains its slab joints, with mottled mineral colour, fine pores and
  darker deposits along building bases and the courtyard wall.
- The existing packed brick image retains its physical scale. Directional
  rain/soot variation, lower-wall damp and sparse mineral deposits enrich it.
- Stone trim and diner ivory have pitting and rain staining. Roof felt and its
  repairs have different mineral dressing, runoff variation and roughness.
- Painted iron/enamel have sparse oxidation; sedan paint has subtle fading and
  lower-body road dirt. Chrome roughness and wood grain vary independently.

These changes are editable Blender shader nodes using physical world
coordinates. No generated concept painting is substituted for the render.
Bump affects shading only: there is no displacement, added geometry or alpha
change. The original V02 model and plates are preserved.

## Deliverables

Under `ArtSource/Blender/SableRowStudyV03/`:

- `sable_noir_court_v03.blend`: packed model with day/night scenes.
- `staged/sable_court_day.png`, `staged/sable_court_night.png`: native
  6144×4608 Cycles renders, 48 samples, original camera and lighting.
- `reviews/03_material_finish.png`: overview of the material pass.
- `reviews/walk_frames/`: selected SpriteKit views with current Voss pixels,
  existing runtime walk traces and the actual cover shader.
- `live_material_stages.json`: exact live MCP authoring batches and helpers.
- `geometry_invariance.json`: equal before/after SHA-256 for scene object
  identities/types, transforms, render visibility, mesh vertices/faces and
  orthographic camera transform/scale.

## Validation scope

Geometry and camera hashes are identical. Navigation, heights and cover are
copied byte-for-byte from V02; this pass does not re-author their data or change
the runtime. V02's movement and stencil results remain evidence for that same
geometry, not newly performed tests of this material pass.

The SpriteKit review helper now accepts `--study PATH --review-stills` to render
four comparable positions without regenerating the entire video. Default V02
behaviour is preserved.

This is still the courtyard section, not an installed replacement for the entire
Sable Row ward. The material pass improves surface richness; the repeated
architectural forms and larger district composition are separate remaining
art work. The projection gate does not measure visual finish.

The final day plate passes the 1.5° projection gate at 0.16° worst error.
The final night plate passes at 0.18° and was visually inspected after rendering.
Four SpriteKit frames were rendered and the entrance and courtyard views were
visually inspected. `swiftc -typecheck` passes for the updated review helper.
`inherited_validation.json` verifies all 83 inherited files byte-identical.
`reviews/comparison.html` presents matched V02/V03 gameplay views.

## Lamp reference question

The user's question during rendering exposed an unresolved historical detail:
the short cylindrical lanterns are generic modeled forms, not reproductions
of an identified 1950s product. Similar tubular lighting existed in Cambridge
in 1957, but that does not authenticate this exact design or its American
context. An acorn-globe design has documented prewar Los Angeles precedents.
The material pass retains the lamps; a geometry revision must update their
cover export instead of continuing to claim geometry invariance.

- [Historic England: Richardson's 1957 Cambridge lighting](https://historicengland.org.uk/listing/what-is-designation/heritage-highlights/candles-light-up-post-war-cambridge/)
- [Los Angeles: Hope Street streetlights](https://historicplacesla.lacity.org/report/a66cac17-bd73-41b9-90df-9141e56a3f63)

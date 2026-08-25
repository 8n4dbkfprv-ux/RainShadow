# City unified area V2

The six `ArtSource/Generated/CityDistrict/V2/UnifiedMasters/*.png` files were
created with the built-in Image Generator from the corresponding
`WardRebuild/*_review_full.png` image as a strict layout reference.
Human-scale takes use `UnifiedScaleAnchors/*_scale_anchor.png` (adult silhouette
at 140 px / 70.3 world units, door box at 1.15×) as the layout reference.

## Production prompt

> Repaint the complete 4:3 district as one continuous seamless pre-rendered
> Infinity-Engine-style 1950s outdoor area. Preserve the street topology,
> building positions, walkable widths and visible doorway positions. Keep an
> orthographic camera with symmetric +36.87/-36.87 degree ground axes. Remove
> every rectangular source boundary, mask, halo, duplicate ground patch and
> internal crop; complete all roofs; correct stretched proportions only at the
> whole-area level. Use one coherent rainy-night exposure and keep clear
> walkable pavement in front of every readable entrance. Human scale is locked:
> a standing adult is 140 pixels tall on the 8192-wide plate (70.3 world units).
> Every entrance door is 1.15 adult heights (162 pixels from threshold to lintel,
> band 1.05–1.35). Ground-floor storeys are about two adult heights. Cars,
> stoops, crates and awnings sit at true 1950s scale to that adult — not to the
> full facade. Green silhouettes on the layout reference mark adult height at
> each portal; yellow boxes mark the target door. Paint those openings to the
> yellow box, not to the first-floor cornice. No people, UI, watermark, isolated
> cutouts, modern objects or top-down perspective.

District-specific nouns (police station, riverfront, Lila Street, civic records,
etc.) were added without changing the camera, composition or human-scale
constraints. Layout references with adult silhouettes are built by
`compose_city_unified_scale_anchors.py`. Painted apertures are gated by
`qa_area_door_scale.py` (1.05–1.35× adult).

`build_city_unified_area_v02.py` is the authority after generation. It rejects
off-lock masters, corrects the complete plate with one transform, and restores
only high-frequency detail from the old 8K flatten. It never warps, masks or
seats an individual building. Doors are paint in that one image — the same
contract as an Infinity Engine TIS — and are gated by `qa_area_door_scale.py`.

Whole-block generates cannot hold a 1.15× door. Close-up portal neighbourhoods
are painted against `compose_city_portal_paintovers.py --extract` jigs (adult
silhouette + yellow 1.15× box on the installed plate) and feathered back into
that same plate with `--seat --install`. No overlay sprite and no procedural
wood stamp.

## Shared interior prompt

The built-in Image Generator also edited the locked `office_suite_plate.png`
reference with this production direction:

> Preserve the reference plate's exact 16:9 cutaway envelope, orthographic
> camera and symmetric +36.87/-36.87 degree floor axes. Repaint it as a generic
> 1950s public-building lobby at night: worn tile floor, dark wood reception
> counter, mail cubbies, radiator, waiting chairs, frosted street door and warm
> practical lamps. Keep one clear exterior doorway and a broad unobstructed
> walkable floor. No people, specific names, signage, UI, modern objects,
> top-down camera or perspective change.

`build_city_building_interior_v01.py` applies the same whole-image projection
gate and builds the shared SR/light/map support resources.

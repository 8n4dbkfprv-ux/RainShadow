# Lamp Ward and the Lamphouse — Blender source, 27 September 2026

The current editable model is `ArtSource/Generated/CityDistrict/LampWardNoirFantasySep27/TextureRevisionV09/lamp_ward_lamphouse_v09.blend`. V01 through V08 are retained for comparison. ArtSource is intentionally local and ignored by Git. This document records the delivery; it does not install the area into the game.

The file contains `Lamp_Ward_Day`, `Lamp_Ward_Dusk`, and `Lamphouse_Interior`, with 3200×2400 day/dusk renders and the unchanged interior render under `TextureRevisionV09/Renders/`, plus an exterior surface close-up. V07 retains the working-room and cell close-ups. All sixteen used original RainShadow texture images, including the five V09 generated maps, are packed. The existing Riverside Blender file was not overwritten. Collections separate architecture, furnishing, lighting, and authoring markers. Embedded Text blocks record the incremental live Blender MCP work; they are not a replayable generator. The saved model is the authority.

## Canon used

The main checkout was stale. The current definitions were retrieved directly from [GitHub PR 28](https://github.com/8n4dbkfprv-ux/RainShadow/pull/28), commit `0f2a6af37576b44f2cecf3fb81c58b47ae5eeeec`. Exact GDD, journal, district catalog, and both area records are pinned in the package's `References/` directory.

- Lamp Ward is `city_lamp_ward`; its landmark is `interior_lamphouse`, entered through `portal.lamphouseEntrance`.
- The Lamphouse belongs to the Lantern Company of Harborpoint: lanternmen, river lanterns, and lamp-sergeants. It is a civic law-and-investigation institution, not a lamplighters' guild.
- The district catalog establishes a walled landmark and forecourt. The model retains those features, adding an oil-lit gate, hand-rung bell tower, public notice board, adjoining night-books annex, neighboring trades, and service lanes.
- The journal directs Voss to request the Lamphouse property log. The interior provides a public counter and log, lamp-sergeant's desk, night-books room, and secured property store. The coat remains in Lantern custody and unexamined; the key stays with Voss. No identified culprit, key destination, new testimony, or resolution of Lillian's fate is implied.
- The user explicitly required preindustrial fantasy in the Baldur's Gate era. Older squad-car and clock references were therefore not carried into the art. Oil lamps, ravens, wax seals, a handcart, a marked tallow candle, and a sandglass supply the material vocabulary. No exact-time clue is invented.

## Local Baldur's Gate study

Viewed the extracted local `bg_AR0300.png`, `bg_AR1200.png`, and `bg_AR0809.png`: timber/plaster construction, layered civic massing, walled street edges, and a readable cutaway records interior. These are study references only. No BG pixels, textures, or meshes are embedded in the result. Surface maps reuse original RainShadow textures from the Wharf/Riverside source package.

## V02 reference-driven refinement

The initial version met the projection and canon requirements but its isolated houses, uniform paving, roof planes, faceted tree clusters and sparse interior fell short of the references. V02 addresses those visible weaknesses through incremental live Blender edits and rendered reviews:

| Reference quality | V02 change |
|---|---|
| Connected architectural masses in AR0300/AR1200 | Attached service wings, a rotated residence, galleries, varied rooflines, dormers and continuing outer street frontage |
| Layered roofs and civic masonry | Thick overlapping slate/tile courses, weathered material variants, a stepped civic parapet, tower ashlar, corner quoins and chimney pots |
| Mixed street surfaces and vegetation | Worn paving edges, distinct dirt yards, moss/grass patches, rubble, branches and individual leaf meshes |
| Warm working interior in AR0809 | Oak staff flooring and wall lining, irregular public flags, smaller table lanterns and wall candle pools |
| Varied records and furniture | Dense ledgers with mixed bindings, labels and stacks, desk drawers/hardware, woven runner detail and a civic lantern banner |

This is still an original 3D interpretation, not a reproduction of the references' painted finish or exact street plan. The frontage remains more orderly than BG's city areas. Canon and journal constraints above are unchanged. No new evidence, testimony or case resolution was introduced.

## V03 exterior lantern correction

The uniform slim iron street posts read as later municipal lighting. V03 removes all eight, replaces the two gate lamps with hanging cages on strapped oak standards and braced arms, and adds five wall-hung lanterns at selected entrances. Small forged brackets, suspension links, cloudy horn panels, oil reservoirs and shallow rain caps replace the old lantern heads. Mounting blocks seat each wall bracket into its façade. Seven exterior lanterns now replace ten, concentrating light at entrances and leaving longer dark intervals.

The V02 interior is unchanged. V03 keeps the same production cameras, geometry and case canon except for the exterior lighting assemblies. Twenty-one exterior door latches also stop sharing the old emissive lantern material and use unlit brass. The current source and exterior renders are in `LanternRevisionV03`; its README, validation and receipt describe this bounded revision. The V02 checks below remain the baseline for the broader district/interior refinement.

## V04 shared cutaway doorway

The Lamphouse entrance now uses the exact narrow strip shared by Voss’s V19 office and Lillian’s Wharf office: `WL_Office entrance strip V08`, imported from `WharfLadderNoirFantasySep25/MaterialsV20/wharf_ladder_materials_v20.blend`. The original mesh, UVs, and `WL_ThresholdV08 Voss V19 shared finish` material are retained. Placement and uniform XY scaling fit the existing 2.50 m entrance. The full-height foreground door assembly is removed and a local foundation notch preserves the dark separation beneath the strip. This is the cutaway entrance cue used by those other interiors.

`DoorwayRevisionV04/shared_doorway_provenance.json` confirms identical source/final mesh and UV hashes. The final interior render passes the unchanged 1.5° projection gate (worst deviation 0.19°); all six authoring markers remain connected, with their positions unchanged. The foundation is manifold and all eleven used images are packed. Exterior scene audits match V03 and its day/dusk renders are copied byte-for-byte. This revision changes source art only; it adds no case facts or runtime integration.

## V05 detention cells

Three barred cells now line the rear-right wall behind the sergeant’s working area, beside the night-books annex. Each has a stone floor, a separately hinged barred door, and a sleeping place: timber benches in two cells and a straw pallet in the middle. The cells are approximately 2.35 × 2.71 m clear, facing a 1.42 m corridor lit by two oil lanterns. A 1.25 m opening connects the corridor to the staff side of the hall. The separator is cut down in the isometric view, and the property folio cabinet moves against its existing partition so the row stays readable.

The V04 shared entrance strip and all six original marker positions are unchanged. Three new markers identify cell-door approaches without assigning prisoners, dialogue, evidence or case outcomes. Exterior audits match V04. All nine approaches connect in the Blender authoring check; each closed cell is isolated, and opening its actual hinged door makes it reachable while the other cells remain isolated. Doors are saved closed. All eleven used texture images are packed. Full-room and close-up renders, staged reviews, validation and checksums live under `CellsRevisionV05/`. Runtime installation remains separate.

## V06 interior lamp repair

The cell-lamp rings are correctly sized and seated against their caps, with connected forged hooks. The earlier scale pass missed their world-coordinate curves. All six interior caps now align with their corner ribs and have retaining rails around the horn panels. The counter lamp rests on the countertop; the property-store lamp is smaller and hangs from a bolted bracket on the existing gate post, clear of the cabinet and open gate.

An interior-only mottled horn finish replaces the flat uniform glow. Shadow visibility is disabled on the pane proxies so their enclosed point lights can illuminate the room, while the iron frames retain shadows; this is a render approximation. Reduced practical power keeps the light local. Complete lamp assemblies now keep their rings, mounts and sources together under one parent. All six have verified ring/cap seating and exactly one practical light. Table contact is within 1 mm. The nine approaches and all cell-door checks still pass; exterior audits and marker positions match V05. Source, rendered reviews and verification records are in `InteriorLampsRevisionV06/`.

## V07 reference finish

A further local-reference pass develops the interior’s finish toward AR0809: uneven ashlar courses and chipped joints replace broad slab-like wall faces, furniture profiles become finer, and mixed stacked folios, tied packets and parchment rolls interrupt the uniform shelf rows. Wear follows floor circulation and working areas. Table heights stay fixed, and props add no journal evidence or testimony.

Smaller lanterns preserve their mounting contacts. Two additional small wall candles, warmer floor illumination and a less dominant hearth bring the light distribution closer to the reference while keeping the cells subdued. Cell and property ironwork receive finish variation without changing the bar geometry. All nine approaches and individual cell-door checks pass; marker positions, the entrance-strip hash and exterior scene audits are preserved. The current source, full-room/detail renders and checks are in `BGFinishRevisionV07/`. This is source-art refinement, not runtime installation or an assertion of exact painted-style equivalence.

## V08 ward exterior refinement

The southern lodging moves closer to the civic approach, and the cobbler shifts west and north into a connected frontage with a new masonry tallow shop. A taller cooper stair house and low lodging stable provide different building heights; the merchant uses a hipped roof and shallow porch. The displaced tree moves with its branches and batched leaves.

Five authored route chains with changing widths replace the straight street strips. 10,490 worn setts, granular earth, short broken gutters and moss along foundations soften the transition between paving and yards. The forecourt gains coursed wall faces and a wash trough. A 1.74 m opening restores access through the scribe's yard wall. Grouped casks, hoop stock, workbenches, firewood, boxed stores and striped awnings give the trades readable working spaces. These props introduce no new case facts.

Twenty-seven exterior material copies isolate weathering from the finished interior. Nine selected domestic windows and two new complete wall-mounted oil lanterns make the dusk ward more inhabited while retaining the Lamphouse as the focal point. The production camera and existing authoring markers stay fixed.

The interior geometry/transform/material-assignment digest matches V07; all nine interior approaches and three cell-door checks pass. Thirteen exterior approaches connect on the source-art clearance grid with 0.23 m clearance. The three existing approach steps are explicitly walkable supports. This is an authoring check, not a runtime navigation claim. Both exterior renders pass the unchanged 1.5° projection gate (day 0.17°, dusk 0.15°). V08 contains staged render reviews, final renders, projection QA and the saved editable model. The district remains an original 3D interpretation rather than a reproduction of BG's painted finish.

## V09 image-generated exterior material pass

Five original material maps were created with the built-in image generator and applied in Blender: chipped lime plaster, weathered limestone, blue-gray slate, worn terracotta, and packed street grit. Native returned images are 1254 × 1254, saved unchanged under `TextureRevisionV09/Textures/` and packed into the model. The exact prompt set and provenance are in `prompts.json`; hashes, paths and physical repeat scales are in `texture_manifest.json`.

Seventeen wall/paving material copies, twenty roof material copies and one ground material isolate the pass from the interior. Neutral linear-light mean matching retains the established exposure range, with a more restrained tile palette. Explicit mapping from world position and face normal corrects texture stretching on rotated buildings. The roofing maps contain no painted tile rows, preserving the modeled roof structure. The new grit replaces the broad procedural soil pattern beneath the retained moss and damp masks. Shallow luminance-derived bump supplies surface relief without displacing geometry.

Staged renders and a close-up were visually reviewed before the final day/dusk render. Both final renders pass the unchanged 1.5° projection gate (day 0.22°, dusk 0.25°). The interior's geometry, transforms, material assignments and shader-node digest match V08 exactly. Production cameras and all authoring markers are unchanged. V09 changes source materials only; the street layout, cells, shared doorway strip, period lamps and journal constraints remain as established.

## Verification and integration boundary

Both cameras are orthographic at 48.59038° elevation; measured ground slopes are ±0.75. All three final V02 renders pass at the unchanged 1.5° tolerance, with a maximum measured deviation of 0.18°. Final V02 render measurements are recorded in `RefinementV02/projection_qa.txt`, using `qa_plate_projection.py` and its unchanged 1.5° tolerance.

`RefinementV02/validation.json` records current scene geometry and an interior authoring clearance check: all six markers connect to the street arrival on a 0.1 m grid with 0.18 m clearance. This is a Blender geometry check, **not** the runtime SearchMap validation or a shipped navigation claim. Successive rendered reviews corrected coplanar floor and wall intersections. The V02 validation record also confirms all ten used texture images are packed. V02 uses conservative object bounds across a 0.16–1.7 m body-height band for its interior clearance check; all six markers connect through 10,379 reachable grid cells.

The models use one Blender unit per metre. Runtime world registration, final source-density budgeting, search maps, light maps, wall stencils, door animation/state export, and exact runtime reachability remain integration work. No game resources, journal text, navigation implementation, or GDD were changed by this delivery.

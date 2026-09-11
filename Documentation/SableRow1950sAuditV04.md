# Sable Row: early-1950s period audit and corrections

User-confirmed setting: an early-1950s American port city, with older buildings
and equipment still in service. Audited the entire visible Blender courtyard
section, including objects outside the central courtyard, text objects, surface
materials and roof equipment. `scene_inventory.json` records the visible object
families. This is not an audit of the other wards, interiors or character assets.

The scene represents a fictional city. A documented period precedent establishes
plausibility, not an exact manufacturer, installation date or regional municipal
specification. No arbitrary story year, real state registration or brand identity
has been added.

## Audit decisions

| Component | Finding and action | Evidence / confidence |
|---|---|---|
| Six street lamps | Original short luminous cylinders with flat caps were insufficiently referenced and read as modern pedestrian lighting. Replaced with cast bases, fluted/tapered columns, retaining collars and opal acorn globes. Positions retained. | Prewar American globe/cast-column family documented by [LACMA's 1920s–30s lamps](https://unframed.lacma.org/2018/02/06/story-urban-light) and [Los Angeles' historical lighting collection](https://lights.lacity.gov/about/museum). New models are family interpretations, not certified replicas of one catalog number. |
| Two entrance lights | Replaced generic cylinders/caps with tapered glass, metal glazing bars, bottom retainers and pitched hoods. | Traditional framed-lantern construction appears in the [Los Angeles collection](https://lights.lacity.gov/about/museum). Exact wall-fixture manufacturer is unspecified. |
| Five refuse cans | They were named galvanized but used dark painted iron and smooth sides. Changed to weathered zinc/steel, pressed ribs, rolled rims, side bails and domed lid crowns. Existing lid handles retained. | [1942 federal manufacturing restrictions](https://tile.loc.gov/storage-services/service/ll/fedreg/fr007/fr007221/fr007221.pdf) explicitly address iron/steel garbage cans. Construction is a generic period metal-can interpretation. |
| Two sedans | Existing bodies were generic, despite “1950”/“1951” in their names. Added real wheel openings, visible divided glazing, vent-pane divisions, bright surrounds, wipers, shut lines, bumper guards, horizontal grille/medallion and metal license-plate blanks. Reduced metallic paint response. | Inspected [The Henry Ford's 1949 sedan](https://www.thehenryford.org/collections/explore/artifact/27335?AssetId=THF90472), including its photograph. Broad shape, chrome, round lamps and whitewalls are plausible. Four-door models here are **not** exact copies of that two-door Ford, and the old object names are not provenance. |
| Apartment masonry, stone courses, stoop, paneled door, transom, chimney pots | Retained as older urban fabric. No curtain-wall glazing, vinyl cladding or modern entrance system is modeled. | [NPS historic wood-window guide](https://www.nps.gov/articles/000/wood-windows-history-s-eyewitness.htm) supports the prewar facade/window family. Building arrangement is fictional rather than a surveyed historical tenement. |
| Sash windows and shades | Retained wood sash framing and varied fabric shades. Diner's narrow horizontal blind elements are generic, with no contemporary mechanism visible. | NPS window reference above; materials/construction are plausible. No claim that every decorative proportion is copied from a period catalog. |
| Exterior fire escapes and iron railings | Retained. No need to remove these as supposedly modern. | [1936–37 NYC Tenement House Department poster](https://www.loc.gov/pictures/collection/wpapos/item/98516613/) provides an explicit prewar fire-escape precedent. |
| Corner diner and signs | Retained low masonry/enamel storefront, large glass panes, chrome trim and plain DINER / COFFEE / LUNCH lettering. These are not contemporary LED panels. | [Library of Congress diner collection](https://www.loc.gov/free-to-use/diners-drive-ins-restaurants/) and [1943 roadside diner record](https://www.loc.gov/item/2017846238/). Generic neighborhood lunchroom; not represented as a specific prefabricated diner maker. |
| Workshop garage | Retained sectional leaf, clerestory and MOTOR SERVICE sign. An upward-opening garage door is not itself an anachronism. | [Overhead Door's company history](https://www.overheaddoor.com/about-us) dates its upward-lifting door to 1921 and opener to 1926. The modeled door has no modern glazed-aluminum system or electronic control panel. |
| Flat roofs, repairs, chimney and skylight | Retained as asphalt/coal-tar felt with mineral dressing and patches, metal flashing and wired glazing. No PVC, EPDM or solar panels. | [NPS treatment guidelines](https://www.nps.gov/orgs/1739/upload/treatment-guidelines-2017-part1-preservation-rehabilitation.pdf) distinguish late-19th-century built-up felt/tar roofing from later synthetic membranes. The material name “bitumen” does not mean modern modified-bitumen membrane. |
| Diner extract duct, caps and louvres | Kept simple fabricated metal shapes; changed the dark plastic-like surface to galvanized sheet metal. | [Greenheck's history](https://greenheckgroup.com/about-us/) establishes commercial air-movement work in 1947. This supports the technology, not the exact modeled assembly; no modern packaged HVAC unit is asserted. |
| Wooden rooftop tank and hoops | Retained as older infrastructure, not a new 1950s invention. | [Historical overview of wooden rooftop tanks](https://www.vitalcitynyc.org/nyc-wooden-water-tanks-architecture-history/) describes their older construction tradition. Its exact location/capacity is fictional, not a hydraulically validated installation. |
| Telephone poles, crossarms, insulators and sagging wires | Retained wood/porcelain/wire construction. No cellular equipment, fiber cabinet or contemporary cable hardware. | Generic established prewar utility construction; no telephone company's exact standard is claimed. |
| Asphalt, slab paving, stone kerbs/setts, drains and manhole | Retained ordinary older paving and cast-metal drainage. No tactile warning surfaces, plastic bollards or contemporary road symbols. | Generic period-compatible materials; exact municipal paving/grate patterns are fictional. |
| Bench, tree bed, ivy, planters and laundry | Retained wood/iron bench and ordinary planting. Clothesline remains textile/rope, without plastic baskets or modern fittings. | [1939 Library of Congress clothesline record](https://www.loc.gov/pictures/item/2017801056/) provides an explicit prewar precedent. Botanical season is an art choice, not a dating claim. |
| Crates, newspapers, number/sign plates | Retained timber crates, paper litter, number 24 and simple SABLE ROW enamel plate. No QR codes, modern logos, ZIP codes, websites, contemporary price or date text. | All five existing text objects were inspected directly. Newspapers are generic unreadable paper, not authenticated editions; license plates intentionally have no invented jurisdictional seal. |

No definite later-1950s or post-1950s invention remains identified in this section.
The strongest mismatches were generic construction/material cues, rather than
proof that cylindrical lighting or dark-painted metal could never have existed.
The corrections make the visible period language more specific without claiming
archival certainty for every bolt, grille or building dimension.

## Model and export

Work was performed through the live Blender MCP connection, in bounded edits
with viewport/render checks. V03 is preserved. V04 is at
`ArtSource/Blender/SableRowStudyV04/sable_noir_court_v04.blend`, with shared day
and night geometry. Original replaced objects remain hidden for inspection.
Wheel-well cutters remain hidden and are linked to both beauty scenes.

`live_period_stages.json` retains the actual authoring and export operations.
The model is the editable authority. No character rig, navigation algorithm,
camera projection or runtime renderer was modified.

Unlike V03, this version changes silhouettes. The evaluated geometry was
exported again, and the search map, height map and cover polygons rebuilt from
it. An independent white Workbench render uses newly evaluated meshes, not the
old V02 silhouette scene. Validation results are recorded alongside the staged
assets. The entire Sable Row ward is not installed by this courtyard study.

## Validation results

- All five `SableBlenderAreaValidationTests` pass against the V04 stage.
- All 132 directed approach pairs and 12 recorded journeys reach their targets.
- 7,833 cover polygons bake into the existing 1408×1056 mask budget in 0.72 s.
- The independently rendered silhouette agrees at 99.597% IoU; zero mismatch
  pixels lie more than three mask pixels from the reference boundary.
- Camera remains orthographic at the BG:EE ground projection. Final plates
  retain native 6144×4608 source resolution for the 2816×2112 world section.

The final gameplay close-up exposed glazing buried inside the approximate
sedan cabin. The final revision derives each pane from the actual cabin faces,
with separate dark glass, seals and fine chrome beads. Both vehicles received
the correction; the exported geometry, independent silhouette and all five
tests were rerun afterward. `glazing_fit_revision.json` preserves that edit.

Final day and night plates both pass the 1.5° projection gate: maximum axis
error is 0.16° by day and 0.17° at night. Both are native Cycles renders at
32 samples with denoising. The updated comparison is
[available here](../ArtSource/Blender/SableRowStudyV04/reviews/comparison.html).
`delivery_manifest.json` records SHA-256 hashes of the final deliverables.

# Sable Row V05 — diner and building lights

Setting: an early-1950s American port city. This updates the staged courtyard
study; it does not install a whole ward or add a playable diner interior.

## Lighting check

The warm apartment windows represent light coming from occupied rooms, not
luminous building panels. The stoop lanterns are framed glass fixtures with
incandescent bulbs. These technologies are period-compatible: the Smithsonian's
[Caldwell fixture collection](https://library.si.edu/digital-library/collection/caldwell/introduction)
documents electric fixtures from the late nineteenth through mid-twentieth
centuries. Their appearance alone does not establish an exact manufacturer.

Even fluorescent tubes would be possible in this setting. GE offered them for
sale in 1938, according to the Smithsonian's
[Inman and Thayer history](https://americanhistory.si.edu/lighting/bios/gi_rt.htm).
That does not make a contemporary LED strip or sealed LED fixture appropriate.
V05 uses modeled enamel-shaded incandescent pendants in the diner and a
shielded gooseneck incandescent fixture above the workshop door. Its light is
mounted against the measured wall, above the garage lintel. The diner's painted
lettering and metal trim do not emit light.

Blender's point sources and emissive shaders approximate bulb illumination;
their presence is not a claim that buildings had luminous surfaces or modern
lighting hardware. This is an art lighting setup, not a photometric simulation
of a specific historical bulb model.

## Diner completion

The supplied concept showed an inhabited diner behind a rounded storefront.
V04 had flat glowing panels over a filled building mass and lacked interior
furniture. V05 replaces that placeholder construction with:

- A continuous rounded corner, hollow lower walls and clear window sheets.
- A framed corner entrance with a pull, kick plate and curved canopy.
- Continuous chrome trim, enamel-panel joints and painted DINER/COFFEE signs.
- A tiled floor, window tables and chairs, booths, a lunch counter and stools.
- Crockery, menus, a mechanical till and coffee urns.
- Shaded incandescent pendants and a sheltered entrance bulb.
- Felt roof laps and patches around older metal ventilation equipment.

The [Library of Congress's diner history](https://blogs.loc.gov/picturethis/2026/04/the-classic-american-diner/)
includes a 1940 counter photograph; its
[1946 Greenbelt lunch-counter photograph](https://www.loc.gov/item/2002718649/)
provides another period precedent for the furniture family. The scene remains
a fictional design, not a replica of a specific diner. The attached concept is
an art reference, not historical evidence.

Interior furniture is modeled in three dimensions. The unchanged area camera
and opaque roof naturally conceal deeper equipment; front-window seating is
visible in the final render. Clear storefront glass uses a mostly transparent
surface with a small reflection contribution for legibility in the baked plate.

## Editable source and review

- [Blender model](../ArtSource/Blender/SableRowStudyV05/sable_noir_court_v05.blend)
- [Comparison](../ArtSource/Blender/SableRowStudyV05/reviews/comparison.html)
- [Recorded live edits](../ArtSource/Blender/SableRowStudyV05/live_diner_stages.json)

V04 is preserved. Changes were made through live Blender MCP in bounded stages,
with render checks between the storefront, furnishings and final corrections.
No character, navigation algorithm, runtime renderer or camera projection changed.
The changed outline and cover are exported again from evaluated geometry.

## Final validation

All five SableBlenderAreaValidationTests pass: 132 directed approach pairs and
12 recorded runtime walks. The revised 7,713 cover polygons bake in 0.67 seconds
into a 1408×1056 mask. Independent silhouette agreement is 99.617% IoU, with
zero mismatches more than three mask pixels from a reference boundary.

Native 6144×4608 day and night plates pass the 1.5° BG:EE projection gate,
with maximum errors of 0.20° and 0.28° respectively. Four SpriteKit review
frames were regenerated from the final day plate and revised exports.

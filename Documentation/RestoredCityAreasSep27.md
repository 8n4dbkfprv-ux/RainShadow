# Restored city areas — 27 September 2026

The standard world map now loads the reviewed native packages for Sable Row
(V30), Wharf Ladder (V19 geometry + V20 materials), and Riverside (V13). The
existing Lamp Ward/Lamphouse V12 integration is retained. Voss remains on the
current replacement V14 runtime; his office and actor assets were not replaced.

| World-map destination | Runtime area | Connected interior |
|---|---|---|
| Sable Row | `city_sable_row`, promoted from V30 `sable_noir` | Current `office_suite`, return via `from.office` |
| Wharf Ladder | `city_wharf_ladder` | Reviewed `interior_shipping_office` |
| Riverside | `city_riverside` | Reviewed `interior_iron_stairs` (Riverside Rooms) |
| Lamp Ward (retained) | `city_lamp_ward` | `interior_lamphouse` |

Lila's Street and Civic Records retain their existing areas. This restoration
does not claim those areas have received the new fantasy architecture.

## Runtime integration

`RebuiltCityAreas` reads the restored ARE records for the district catalogue,
navigation maps, portal outlines and directional arrival points. Street exits
use those points instead of the old rectangular plate edges. Stable district
and interior IDs keep normal world-map travel and office return routes intact.
The shared renderer now loads Sable's authored dusk light map when its night
plate is selected. The other packages use their authored neutral light maps.

Wharf and Riverside use their existing evaluated door tiles: the first click
walks to and opens the door; a subsequent click in the aperture enters; clicking
the open leaf closes it. Sable V30 has a static travel doorway and no animated
ARE door. Its click enters the current Voss office directly.

One authoring correction was needed: Riverside Rooms' `portal.return` approach
moves from `(328,210)` to `(344,222)`, the adjacent reachable arrival cell. The
painted threshold, search map and engine clearance rules are unchanged.

Riverside's two existing observations now appear as field notes when inspected.
The recovery-site note explicitly keeps Lillian's coat in police custody.
Outdoor inspections no longer incorrectly create an "Office searched" entry.

## Existing saves

Stable identity preserves case flags, evidence, inventory, wallet and journal.
On the first load of a save without `cityLayoutRevision = 1`, `SaveStore` keeps
the original raw envelope under `<save key>.BeforeCityLayoutV1`, clears explored
fog only for the five replaced areas, and moves their dropped item stacks to
reachable default arrivals. Items and quantities are preserved. Other areas'
fog and piles are retained. The migration runs once; fresh saves start at revision
1. Fog decoding now preserves the field that the old decoder omitted.

`Play Sable Row.command` builds and launches the same connected city with a
separate `RainShadow.Save.RestoredCity` playtest save. Normal game travel uses
the same installed resources and keeps the normal save.

## Reproduction and validation

`ArtSource/Processing/restore_completed_city_areas.py` verifies the archived
installation hashes before restoring resources and registering them in both
app targets. It preserves existing destination files under
`ArtSource/Generated/CityDistrict/RuntimeRestoreSep27/Before`. The current Swift
sources and original working-tree status were backed up before integration.
Restoring art is not a reason to restore historical actor or office source files.

The restoration receipt tracks 232 resources. Native art pixels are unchanged;
Sable's canonical ARE identity/arrivals and the Rooms approach are intentional
metadata changes. `Review/bundle_hashes.json` and `Review/ios_pixels.json`
validate built resources, accounting for iOS PNG recompression.

Validation artifacts are under `ArtSource/Generated/CityDistrict/RuntimeRestoreSep27/Review`:

- 94 targeted Swift tests pass: area catalogue and parity, reachability,
  world-map and scale contracts, retained Lamp Ward, actual `Movable` walks,
  projected cover bounds, save migration and Riverside journal observations.
- macOS and iOS Simulator Debug builds succeed. iOS gameplay was not run.
- `RebuiltCityTravelQA` uses disposable saves and real scene pointer input.
  Its 19 checks cover day/night pages, entering and returning from all three
  linked interiors, separate door opening for Wharf and Riverside, street exits,
  and world-map travel to retained Lamp Ward and back.
- Native framebuffer PNGs show the restored streets and interiors with the
  current actor. This is runtime integration verification, not a new art pass.

Measured circle-clearance flood baselines are 48,828 cells for Sable Row,
47,777 for Wharf Ladder, and 49,674 for Riverside. `ActorFootprintTests` pins
these measured replacement rasters; no navigation algorithm changed. The
area-profile-radius floods are separately exercised by `AreaReachabilityTests`.
Legacy modular scale fixtures remain tested separately from the restored ARE
apertures, including Sable V30's evaluated 89.33-unit vertical door jamb.

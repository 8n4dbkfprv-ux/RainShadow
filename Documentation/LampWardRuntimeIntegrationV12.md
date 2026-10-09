# Lamp Ward and Lamphouse runtime integration — V12

The accepted V11 Blender artwork is installed as two playable areas: `city_lamp_ward` and `interior_watchhouse`. Lamp Ward occupies the former Harborpoint PD world-map position, south of Sable Row and east of Riverside. The Lamphouse is the Lantern Company's civic/watch hall. No case evidence, testimony, journal state, or NPC dialogue was added.

Open `Play Lamp Ward.command` for direct access at the Lamphouse forecourt with a separate save. Normal city travel also reaches Lamp Ward. Click the facade doorway to enter; click the narrow interior entrance strip to return. The three cells remain barred and closed. These are baked travel entrances, not animated door leaves. On macOS, N switches the ward between day and night.

## Installed assets and authority

- `RainShadow Shared/Resources/Areas/city_lamp_ward.*` and `interior_watchhouse.*`: area records, search, light and height maps.
- Interior plate `RainShadow Shared/Resources/Art/Areas/LampWardV12/watchhouse_v12*`. The interior area record and plate were renamed from `interior_lamphouse` / `lamphouse_v12` to match the Watch canon (display name unchanged: THE WATCH-HOUSE); saves that still hold `interior_lamphouse` load into RS0401. The street door keeps its id `portal.lamphouseEntrance`.
- `RainShadow Shared/Resources/Art/Areas/LampWardV12/`: native cropped 2048-pixel pages, page manifests with SHA-256 hashes, and map previews. Both Xcode application targets include every asset.
- Source: `ArtSource/Generated/CityDistrict/LampWardNoirFantasySep27/RuntimeIntegrationV12/lamp_ward_lamphouse_runtime_v12.blend`. Its text block `export_runtime_v12.py` preserves the live MCP geometry export. V11 remains untouched.
- Converter: `ArtSource/Processing/integrate_lamp_ward_v12.py stage` then `install` (Pillow, numpy, Shapely 2.1). Source and native renders remain local under ArtSource, as with the existing art pipeline.

The exterior uses 9216×6912 source pixels over 4096×3072 world units; the interior uses 4096×3072 over 1664×1248. Pages are cropped, never enlarged or stretched. Projection measurements are 0.213° day, 0.307° night and 0.389° interior from the BG:EE target; installation requires ≤1.5°. A 1.8-metre source adult projects to 70.676 and 70.755 world units, within 1% of Voss's 70.3125. The visible facade leaf below its transom spans model z 0.530–2.725.

Search maps conservatively rasterize evaluated ground hulls. Curve control bounds are deliberately not used: the parcel strings' control bounds crossed open floor despite their evaluated geometry being small. Export rounding at 1e-5 world units left seams between touching room domains; a 0.001-unit domain union tolerance closes those subpixel seams before conservative rasterization. All final approach markers retain their original rounded authored positions; no nearest-reachable-point fallback is installed. Interior clearance uses the established office profile; outside uses the district profile. Vegetation batches do not become solid district-sized bounds. Cells and furniture remain solid.

Cover comes from camera-facing evaluated faces, preserving the openings between iron bars. Masks use the existing bounded stencil baker. Light maps use `bake_area_lightmap.to_engine_space`, with no runtime multiplier or shader changes. No shared navigation, projection, viewport or rendering port was modified.

`CityDistrictID.harborpointPD` and `CityInteriorID.policeStation` retain their serialized identities for saves. Public area IDs, labels and travel destinations use Lamp Ward and the Lamphouse. Legacy area-ID aliases and `from.portal.pdEntrance` still resolve. New ward street exits use their authored street-mouth coordinates. Other wards retain their existing artwork.

## Verification

`LampWardIntegrationTests` walks every exported approach using `Movable`, checks both travel directions, source scale, and inaccessible cell/counter witnesses. Existing reachability, catalog, world-map, scale, parity and stencil suites cover the installed records. The new exterior's measured engine-clearance flood is 39,725 cells; its baseline replaces the retired 53,857-cell ward. The different count follows the new world size and geometry, not a navigation change.

`RAINSHADOW_QA_LAMP_WARD=/tmp/LampWardTravelQA`, with `RAINSHADOW_START_SCENE=city`, `RAINSHADOW_START_DISTRICT=lamp_ward` and `RAINSHADOW_START_ENTRANCE=from.portal.lamphouseEntrance`, runs real macOS scene input, walking, entry/return/re-entry, day/night capture and world-map travel. It uses disposable saves and writes `report.json` plus native-framebuffer PNGs. `LampWardTravelQA.swift` is DEBUG-only.

Verified delivery: 97 automated tests across nine area/navigation suites pass; all 16 live macOS gameplay checks pass. Final macOS and iOS simulator builds succeed. The macOS bundle matches all 58 installed resources byte-for-byte; iOS art matches byte-for-byte and its optimized search/height/light PNGs match after decoding. Review captures, test output and hash-bound asset receipt are under `RuntimeIntegrationV12/reviews/runtime/` and `RuntimeIntegrationV12/integration_receipt.json`.

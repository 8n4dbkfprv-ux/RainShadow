# Sable Row district expansion V12

V12 expands the V11 courtyard study around its existing apartment, diner, workshop and neighbouring frontage. Nine new buildings, a cross street, shop fronts, loading areas and a small planted yard turn the section into a larger district scene.

## Size contract

The user-supplied `AR0100.PNG` is 4288×3328. Reading AR0100's WED resource from the local Baldur's Gate Enhanced Edition installation gives 67×50 background tiles of 64 pixels: **4288×3200**. The supplied PNG therefore includes 128 rows beyond the WED background. This measurement uses `extract_ie_reference.load_key` / `read_res`, not an estimate from the screenshot.

V12 adopts **4288×3200 game-world units**, versus the courtyard study's **2816×2112**: **2.307 times the rectangular area**, 1.523 times the width and 1.515 times the height. The original building models remain at the same metre scale. This matches the reference's engine-coordinate footprint; it is not a claim of identical walkable percentage, travel time, population or building count.

The orthographic camera scale increases from 48 to 73.090909 and shifts by (8,12,0) model metres to frame the additions. Elevation and azimuth remain locked. The final render is **9408×7020**, approximately 2.194 source pixels per world unit (the prior study was 2.182). The tiny difference between horizontal/vertical ratios comes from integer render dimensions; there is no post-render resizing or aspect warp. These dimensions are the new camera contract, not a relabelled V11 image.

## Added district content

| Building | Model centre | Footprint | Height |
| --- | --- | --- | --- |
| Dockside lodging | −23,35 | 13×10 m | 9.0 m |
| Union rooms | −10,34 | 9×9 m | 6.2 m |
| Corner grocer | 0.1,35 | 8.3×11 m | 6.6 m |
| Bonded warehouse | 17,36 | 14×13 m | 7.0 m |
| Freight annex | 28,41 | 6×10 m | 4.7 m |
| Harbor pharmacy | 28.4,5.4 | 6×10 m | 5.8 m |
| Mercer rooms | 35.5,5.8 | 7×11 m | 8.8 m |
| Radio repair | 43,5 | 6×9.5 m | 5.0 m |
| Marine electrical | 37.5,22 | 12×8 m | 4.2 m |

The new buildings have separate dimensions, frontages and roof heights. They share the existing construction/material library: masonry, painted timber, reflective glazing, coping and roofing. Distinguishing details include shop signs and awnings, warehouse loading doors, a raised roof monitor, water tank, roof repairs, ladders/landings, drainpipes, crates and drums. Six additional street lamps have independent day/night light sources. The original courtyard wall/window repair and removal of the lamp embedded in the apartment remain intact.

The ground and selected pavement extents were re-authored to accommodate the enlarged view and cross street. Buildings deliberately continue beyond some picture edges, as neighbouring city fabric. This is an original noir district layout, not a trace or composite of Baldur's Gate artwork.

## Review and verification

`ArtSource/Blender/SableRowDistrictV12/` contains the packed Blender scene, native day/night plates, three intermediate composition checks, the size contract and exact live MCP operations. `layout_validation.json` checks that the principal new buildings do not overlap one another or existing buildings and that the six new lamp bases do not intersect buildings. The original intentional joint between Voss's two wings is excluded. These are authoring checks, not pathfinding tests.

Projection measurements are saved under `reviews/` after rendering. Renders use Cycles, 64 samples and denoising. Review `reviews/comparison.html` at native size to inspect detail. New architecture uses modular construction and still has a more regular facade vocabulary than finished BioWare area art; matching map extent does not establish equivalent artistic finish.

Both final plates pass the 1.5° projection gate: day 0.22°, night 0.24° worst deviation. Native PNG dimensions were verified at 9408×7020. Full-image visual inspection used temporary uniformly reduced previews because the native PNGs exceeded the tool's image-transfer size limit; the original render files were not resized. Placement bounds and new-lamp/building intersection checks pass.

No gameplay installation was performed. V10/V11 had already changed geometry without runtime integration; V12 does not copy the older courtyard terrain, height, cover or test receipts and present them as district results. Full-area navigation, cover performance, lightmaps, travel links and interactive entrances must be authored and validated before installation. The existing shipped 5120×3840 Sable Row ward is a separate asset and was not replaced.

## Warehouse lettering correction

The BONDED STORAGE lettering originally sat at z=4.05 m, overlapping the window sills. It now sits at z=6.35 m on the brickwork above the windows. Evaluated world bounds place the lowest letter 0.3514 m above the highest lintel. The change moves only the lettering; windows, doors, footprint and camera are unchanged. `sign_fix.json` records the measurement, `live_sign_fix.json` records the edit, and `reviews/sign_fixed_closeup.png` is the checked crop. The original Blender scene is preserved as `sable_row_district_v12_before_sign_fix.blend`. Day/night plates and the main overview are refreshed for the correction; `district_before_sign_fix.png` retains the old overview for comparison.

## Freight detail correction — 7 September 2026

Rebuilt all 12 plain shipping crates with separate planks, face and side cleats, diagonal face braces, lid battens, square nail heads and modest consignment lettering. Replaced both solid loading platforms with 32 transverse deck boards apiece, longitudinal bearers, support blocks, fascia boards and deck nails. Platform footprint (8 × 1.3 m) and deck elevation (0.59 m) retained. Crate positions retained.

The built-in Image Generator supplied `textures/freight_timber.png`; the exact prompt is recorded in `textures/freight_timber_prompt.txt`. Per-board UVs orient the grain lengthwise; separate material grades give crates and docks different weathering. Texture is packed into the blend. Bounded live operations are recorded in `live_freight_detail.json`; a pre-edit blend backup is preserved. Native close-up reviewed before refreshing full day/night plates. This remains staged art, with no new navigation or cover validation claimed.

## Door recess correction — 7 September 2026

Nine new personnel entrances now occupy actual Boolean difference recesses cut 0.60 m into the building body and stone plinth, with their leaf fronts approximately 0.205 m behind the facade. Added painted timber jambs, heads, masonry lintels and seated thresholds, and cleared conflicting ground-window assemblies. The Marine Electrical personnel entrance moved 0.56 m left to clear its loading bay. Four loading leaves now sit 0.24 m behind their wall faces in framed openings, with thresholds aligned to the timber docks. The original workshop sectional garage and Voss entrance were similarly recessed, including the Voss solid entrance surround. The already-authored diner public entrance was retained.

Reviewed close-ups of Union Rooms, the bonded warehouse and Voss before final full-resolution day/night refresh. Geometry ray checks independently confirmed 0.60 m of wall removal for all nine newer personnel doors. Exact operations: `live_door_recesses.json`; measurements: `door_recess_validation.json`; pre-edit backup: `sable_row_district_v12_before_door_recesses.blend`. Boolean cutters are preserved but hidden from renders. This supplies real visible wall depth behind closed doors, not complete building interiors or interactive door animations. No runtime navigation/cover updates or gameplay validation are claimed.

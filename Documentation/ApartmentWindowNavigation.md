# Apartment window access

8 September 2026. The Sable Court playtest's apartment entrance loads
`office_suite`. Its old collision ring followed the inscribed BG:EE placement
diamond, cutting across visible floor between the two window-wall radiators.
The near-window interaction also approached from well inside the room.

The installed `office_suite_plate.png` is the visual authority. In its
4096×2304, y-down pixel coordinates, the clear wall/floor seam between the
radiators is approximately `y = 2000 - 0.65*x`. The new authored window bay
starts 25 pixels inside that seam and overlaps the existing floor. Its vertices
are `(1240,1219)`, `(1660,946)`, `(1760,1096)`, `(1340,1369)`.
The near-window approach is `(1300,1205)`. No projection, actor size, engine
clearance, path search or movement algorithm changes are involved.

`office_layout_plan.py` owns the floor extension and regenerates the boundary
rectangles in `OfficeNavigationLayout.swift`. `export_office_area_record.py`
carries those rectangles and the approach into the area record;
`bake_area_searchmap.py office_suite` rebuilds only the office raster.
The layout emitter's stale search-budget argument and observation text were
also brought into line with the existing Swift source before regeneration.

The closed-door reachable component grows from **1,000 to 1,052 cells**, with
52 added cells and none lost. With the door open it grows from **1,020 to
1,072**: the doorway still adds exactly 20 cells. This is an authored geometry
change; the conservative rasterisation rule is unchanged.

`OfficeWindowReachabilityTests` uses four independent measurements along the
visible window floor, plus negative samples on both walls/sills and radiator
footprints. All four floor positions failed both orderability and exact
reachability on the original map. All pass after the correction. The 33
selected Swift tests also cover area parity/reachability, actor clearance,
actual movement and the Sable Court apartment round trip. The projection and
office search-map QA pass, and the optimized Debug macOS build succeeds.

Before/after reachable-floor overlays are in
`ArtSource/Generated/Office/WindowNavigationQA/`. The real-scene door-travel
harness now additionally clicks clear floor at each window and checks arrival
in the exact requested search cell. All **20 real-scene checks pass**, including
both window walks, exit and re-entry. Both native-renderer window captures were
visually reviewed. The passing report and captures are under `game/` in that
directory. The built app's area record and search map match the corrected
workspace content.

## Wall visibility — Infinity Engine terrain

The follow-up screenshot exposed a separate defect: walking reached the bays,
but fog still hid the upper walls and windows. The old office SR contained
only wood (2), opaque obstacle (0), and see-through obstacle (8), with **zero
wall (10) cells**. Its wall-foot collision ring stopped sight before the upper
wall; the area beyond that ring was disconnected default wood.

The correction authors full painted wall faces as **SIDEWALL (index 10)**.
The source is `ArtSource/Processing/office_wall_terrain.py`, shared by the
layout generator and SR baker. The two plate-space envelopes cover the crowns
through the existing collision band. The layout clips new solids against the
authored floor, including the corrected window bay. The baker retains desk
and chair terrain 8. Runtime navigation, sight rays, fog rendering, lightmaps
and the existing indoor enclosure-fill setting are unchanged.

Upstream evidence: GemRB commit
`1c45c1850d9b5d61a23b3a569499ef57543e2c3f`, `gemrb/core/Map.cpp`,
`ExploreMapChunk`, lines 3058–3062:

```cpp
} else if (bool(type & PathMapFlags::SIDEWALL)) {
    sidewall = true;
} else if (sidewall) {
    block = true;
```

The run of wall cells is revealed before sight stops beyond it. The existing
Swift port already implements these branches; this correction supplies the
terrain they require.

Measured SR changes: **471 obstacle cells and 715 disconnected wood cells
become wall**, giving 1,186 wall cells. All 119 see-through furniture cells
remain unchanged. The playable components are identical cell-for-cell before
and after: **1,052 closed-door / 1,072 open-door**. The fallback geometry and
shipped search map still agree on their blocked-cell count.

The new regression checks both registered window faces with the literal
`visibleCells`/`ExploreMapChunk` path alone, without indoor enclosure or fog
expansion helpers, and verifies that sight stops beyond the wall. It failed
on the original SR and passes with the authored wall terrain. **75 selected
Swift tests pass**, including fog, visibility, parity, reachability, movement
and door travel. Projection and office SR QA pass. The optimized Debug macOS
build succeeds, and **all 22 real-scene checks pass**, including both window
apertures being visible through the actual fog layer, both walks, exit and
re-entry. Arrival, near-window and far-window captures were visually reviewed.

The terrain overlay, original SR, native-renderer captures and passing report
are in `ArtSource/Generated/Office/WindowVisibilityQA/` (`game/` for captures).

# Restored Voss office and living quarters — 27 September 2026

The normal opening and the Sable Row doorway both use `office_suite`. They were
loading the retired painting and geometry because the previous integration had
been reverted in this checkout. The browser preview was not the installed area.

The approved `EntranceStripV19/voss_office_v19_base.png` is now installed with
its measured V14 Blender floor registration: 5120×3840 source canvas,
0.20545935594106624 world units per pixel. V19 retains the furnished V18 room,
V17 bed, and revised narrow grey-brown cutaway entrance strip. The single travel
region leads to the restored Sable Row's `from.office` entrance; it has no
separate door leaf. The world map reaches the same office through Sable Row.

The restoration includes collision/search, light/height maps, cover polygons,
six container portraits, authored inspect silhouettes and fantasy observations,
and the hearth, desk-lamp and bedside-candle sequences (60 frames at 15fps).
The runtime now reads those animation manifests and their registered sizes.
An empty texture name no longer resolves an arbitrary bundled PNG.

`OfficeAreaAdapter` reads the area record directly. The old office planner must
not regenerate this geometry. `OfficeNavigationLayout` retains historical API
aliases for existing diagnostic callers but reads live routes and hotspots from
the authored record. Engine navigation, projection and viewport algorithms are
unchanged.

The currently installed Voss bundle actually declares `meshy_sep10_v07` in this
checkout. It was preserved byte-for-byte, rather than replacing it with the old
CHMF bundle used in the September 22 preview. The revised chair faces SW; the
complete existing SE seat/rise chain is reflected together for that view, with
SW standing handoff. Scale, character art and indexed resources are unchanged.
The approved registered desk cutout covers the seated lower body.

Existing saves get a one-time office layout migration: story, inventory, money
and loot remain; obsolete office exploration is cleared and dropped items move
to the new reachable default entry. The original save envelope is retained under
`.BeforeOfficeLayoutV19`.

Use `Play RainShadow.command` for the normal game with its existing save. It
builds before launching. `Play Sable Row.command` also includes this office and
continues to use its separate city-playtest save.

Validation artifacts: `ArtSource/Generated/Office/NoirFantasyBlenderSep22/RestoredSep27/`.
The native-app QA exercises normal opening → office, world-map travel → Sable
Row → office, strip exit, animated hearth, and rising from the desk to the exit.
The targeted Swift tests check area reachability, actual movement, area parity,
approved art hash, animation resources and old-save migration. The projection
gate measures +36.54°/−36.32° (worst deviation 0.55°).

Final result: 45 focused Swift tests pass; macOS and iOS Simulator builds pass.
`VerifiedQA/report.json` passes all 10 native-app checks. The reflected rise
endpoint equals the installed SW idle pixel-for-pixel; its seated endpoint equals
the seated idle. All nine indexed character/palette resource files are unchanged.

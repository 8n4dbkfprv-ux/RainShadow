# Voss Sep10 production sprites — V07 installed

The Sep10 masked character now replaces Voss in the game. All five atlases and
the native indexed bundle were installed together, and the macOS game was
rebuilt successfully. `voss_masters.ACTIVE_VERSION` is `meshy_sep10_v07`;
`ie_avatar.VOSS_MESHY_V07` holds its fitted palette.

The authority immediately before this installation was **Sep06 pose V05**, as
measured from the installed manifest and source selector. The V14 and V22
descriptions in AGENTS.md are historical. V07 preserves the installed 58 native
body rows, 163.125-unit compatibility canvas, native linear presentation, and
embedded index-1 shadow at alpha 128. No runtime rendering or navigation code
was changed for this installation.

## Production source

All delivery files live in
`ArtSource/Generated/Characters/Detective/MeshySep10ProductionV07/`.

- `voss_sep10_production_v07.blend`: saved production rig, corrective shapes,
  original textures, categorical mask materials, camera, lights and actions.
- `production_animation.json`: keyed production pose values and walk controls.
- `Frames/` and `Materials/`: 204 complete beauty/P-mode mask pairs.
- `Renders/`: 168 authored beauty, ID and projected-shadow source poses.
- `Staging/`: the exact reviewed 248-cell runtime delivery and indexed bundle.
- `Review/`: all-direction sheets, every-phase sheets, animated walk/seat
  previews, and seated/standing captures from the actual game renderer.
- `RuntimeBackupBeforeV07/`: all five previous atlases, previous indexed bundle,
  and previous master selector, retained for rollback.
- `source_authority.json`, `review_receipt.json`, `install_receipt.json`: source
  and delivery hashes binding the installed bytes to the review and tests.

This is the imported Sep10 rig, not the procedural V23 character. Production
actions were authored through the live Blender MCP connection, from its checked
standing and seated poses. The .blend and animation record preserve that work.
The original rest vertices, existing corrective keys, rest bones and texture
payloads match their pre-production snapshots (`source_preservation.json`).

Eight additive walking corrections ease the rear lower coat outward by up to
6 cm at the stride phases. They affect the lower rear coat only and fade between
phases using the rig's walk controls. The original hands and gloves remain
unchanged. A 173-sample source audit found no tested hand self contacts,
hand/coat contacts or coat/trouser intersections, and exact loop/end/reverse
pose agreement. This is a check of the authored production poses, not a claim
that arbitrary future poses cannot collide.

The renderer uses the BG:EE elevation, consistent source framing, and the
existing studio lighting. A mesh-projected cast shadow follows the authored
shadow direction. Seat chains share their standing endpoint's source projection;
there is no forced seated height or head-width warp. NE retains the office's
historical NW-handed convention; SE mirrors SW and its shadow together.

CIE94 fitting across all 168 authored poses chose palette rows
`[159, 222, 29, 157, 159, 159, 159]`. Equal gradient rows do not merge material
ownership: all seven categorical material runs remain separately recolourable.

## Validation and reproduction

`stage_voss_sep10_v07.py finalize`, `fit`, and `stage` reproduce the master pairs,
palette and runtime delivery from the saved renders. `review_voss_sep10_v07.py`
reads back the actual native byte planes and checks every one of the 248 cells
against its compatibility PNG. It also checks phase uniqueness, native head
width stability, loop closure, foot visibility/exchange, exact transition
endpoints, reverse frames, all seven material runs and all 68 rear frames.

One source-to-native height search oscillated between 57 and 59 rows for NW
walk phase 6. The finalizer resolves that last one-row ambiguity with a uniform
nearest resize of the paired native figure and categorical mask before palette
encoding. All standing and walking frames now measure exactly 58 body rows,
with the compatibility body's inclusive foot row at 433.

Rear shirt validation uses independently projected cuff and nape-collar mesh
regions, padded by one native sample in each axis for reduction rounding.
The source and concept expose these cream garment areas from behind. Shirt
pixels elsewhere and all rear tie pixels remain forbidden; the 3% rear skin
ceiling is unchanged. `anatomy-v07.json` carries these independent allowed
regions for Swift validation. No material pixels were relabelled to pass a gate.

The coat genuinely hides the far boot in some directions. Foot validation
therefore compares visible source boot area with native boot pixels and checks
the projected anatomical foot ordering across opposite contact phases. It does
not require a boot to show through cloth. Where both boots are visible, their
native forward separation must exchange sign too.

The four targeted Swift suites passed **28 tests**, both on the staged files
and after installation: `MeshyV04SpriteTests`, `VossWardrobeColorTests`,
`IEPaletteTests`, and `IEResampleTests`. The colour-isolation test now applies
the same translucent-shadow operation as runtime before comparing palettes;
previously it compared an opaque test shadow with a translucent runtime shadow.

```sh
RAINSHADOW_VOSS_ATLAS_ROOT="$PWD/ArtSource/Generated/Characters/Detective/MeshySep10ProductionV07/Staging" \
CLANG_MODULE_CACHE_PATH=/tmp/RainShadowVossModuleCache \
SWIFT_MODULECACHE_PATH=/tmp/RainShadowVossModuleCache \
swift test --disable-sandbox -c release \
  --scratch-path /tmp/RainShadowSwiftPMVossSep10 \
  --filter 'MeshyV04SpriteTests|VossWardrobeColorTests|IEPaletteTests|IEResampleTests'
```

The broader historical Voss baseline was already failing before installation:
34 tests reported 632 issues against the previously installed Sep06 V05. Those
include old 180-unit/no-embedded-shadow assumptions, screen-half foot detection,
and missing historical master manifests. Those suites have not been declared
green or relaxed here. Logs are retained alongside the delivery.

The macOS build succeeded, and the three bundled Voss files were hash-checked
against the reviewed stage. An isolated debug app with a separate bundle ID
rendered seated and standing captures using the candidate bundle. The office's
painted-chair/seat-anchor mismatch was subsequently corrected; see
[VossOfficeChairAlignment](VossOfficeChairAlignment.md).

`install_voss_sep10_v07.py review --test-log <passing-log>` binds a review receipt
to source and staged hashes. `install` checks those hashes, saves the rollback
snapshot, unlinks before copying to avoid hard-link corruption, replaces the
five atlases and bundle, and changes the master selector as one reversible
transaction. It refuses to overwrite the original backup or reinstall blindly.

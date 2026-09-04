# Replacement Voss V12 — projection-preserving sprite installation

Status on 2 September 2026: **installed**. All 248 compatibility PNGs and the
raw-index bundle match the reviewed stage; active masters/palette select V12.
The prior runtime is preserved at
`ImportedVossReplacementRuntimeV12/PriorRuntime/replacement-v12-20260902T190416Z`.
`installation_receipt.json` and `review_receipt.json` bind the install to its proof.

Verification: 32 Swift tests in five suites, 16 Python regressions, palette-port
and complete 204-pair encode QA passed. The historical installed V22 set passed
its 13 Swift asset checks before replacement. The macOS build passed; actual
renderer captures cover seated, midpoint and exact standing endpoint.

The user approved adapting seated sizing and registration while retaining the
replacement model's head proportions. V12 changes the sprite bake, not the mesh.
The V11 authority preserves V10's geometry, UVs and material assignments,
including the user's V09 manual masks. Original Blender/FBX files are untouched.

## Contract

Installer: `ArtSource/Processing/install_voss_replacement_v12.py`.
Masters: V11 `FullAnimationAudit`, all 204 source/mask pairs.
Palette rows: `(138, 248, 144, 159, 138, 100, 22)`, fitted in CIE94 against those
masters. Standing uses 64 native body rows, a 200px body on a 512px canvas, and
the existing 180-world-unit presentation. Runtime shadows remain separate.

Each seated direction shares ONE source-to-texture scale with its standing
reference: `200 / standing_source_body_height`. Seated bounds are not forced
to 155px. The projected source-bbox centre displacement is carried through the
crop into its canvas origin. No independent head scaling, torso widening or
per-phase fitting is applied.

The existing office `ne` filename is **NW-handed** in the runtime. V12 undoes
V11's NE source/mask mirror together and references standing NW. SE remains
the SW mirror; N references N. Standing endpoints reuse the exact native plane,
size and origin of their reference; seated endpoints match idle 00 exactly;
sit-down is the exact reverse of stand-up.

Measured body-height ranges, including the transition: NE 134–200px,
SE 200–206px, N 125–200px. A front-facing seated silhouette includes projected
forward legs and need not be shorter than standing. The crown rises correctly.

## Measurements and gates

`geometry_contract.json` records source bounds, hair-cap bounds, reference scale,
expected origin and native head measurements. The head witness is categorical
hair, not the old top-10%-of-body band (which includes shoulders in some views).
The main connected cap plus nearby strands defines the head region. Isolated
emission-ID edge specks on distant boots are excluded from **measurement only**;
material masks are not edited. Significant hair area outside the head fails.

Both source body size and head size must survive within one native sample plus
texture rounding (4.125px); measured worst head residual is 3.212px. Relative
head width remains in the 0.90–1.10 reference band plus one 3.125px sample.
Idle centroid drift ≤2px, silhouette IoU ≥0.85, adjacent crown retreat ≤4px,
foot exchange, loop closure, phase uniqueness and all 68 rear-material gates
remain enforced. Swift independently recomputes all 96 seated/transition
projections and exact endpoints. Historical V22 keeps its original seat gates.

There are 248 compatibility PNGs (224 visible, 24 blank arms), backed by one
versioned raw-index bundle. Every compatibility pixel must match Swift/Python
indexed rendering. The staged bundle marks `asset_authority: replacement_v12`.

## Review and installation

```sh
python3 ArtSource/Processing/install_voss_replacement_v12.py stage
python3 ArtSource/Processing/review_voss_replacement_v12.py
RAINSHADOW_VOSS_ATLAS_ROOT="$PWD/ArtSource/Generated/Characters/Detective/ImportedVossReplacementRuntimeV12/Staging" \
  swift test --scratch-path /tmp/RainShadowSwiftPM \
  --filter 'VossSeatScaleTests|VossAtlasV20ValidationTests|VossWardrobeColorTests|IEPaletteTests|IEResampleTests'
python3 ArtSource/Processing/install_voss_replacement_v12.py install --confirm-runtime-replace V12
```

Installation requires a review receipt bound to the exact bundle hash. It checks
source hashes and all staged payload hashes, then backs up and replaces the five
atlases and indexed bundle in one rollback transaction. `trial` is not installable.
The receipt records the exact backup. `install_voss_v22.py` remains explicitly
pinned to its historical V22 masters/palette/craft.

The macOS debug capture can inspect exact in-room poses with
`RAINSHADOW_CAPTURE_VOSS_POSE=seated_idle:0`, `stand_up:5`, or `stand_up:11`.
This only applies when the capture hook is called; normal animation is unchanged.

The review also exposed a bundle lookup defect: `IEIndexedSprite.load` still
requested `avatar-v01.json` while the current format is v02, so local builds
silently fell back to checkout art. It now derives the resource stem from
`manifestFileName`. A synthetic bundle with a distinctive colour row proves
that bundled v02 wins over the checkout fallback. No blitting/tinting math changed.

## Separate room-layout issue

The pre-install V22 capture already places Voss beside the painted desk without
a corresponding chair beneath him. The current office area has an empty live
`props` list; the desk/chairs are in its plate. V12 does not move navigation
anchors, change the plate, or invent a chair/occluder. This existing room-art
registration issue is not a sprite scale defect and remains separate work.

Review outputs and machine-readable receipts live under
`ArtSource/Generated/Characters/Detective/ImportedVossReplacementRuntimeV12`.

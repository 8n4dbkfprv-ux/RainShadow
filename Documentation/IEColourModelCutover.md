# IE colour model cutover — completion record

- Status: complete — authored masks, paired encode, transactional rebake,
  legacy-lock retirement, indexed runtime model, actor wiring and both-target
  project membership are in the tree
- Date: 29 August 2026
- Related: [BG:EE humanoid pipeline](BGEEHumanoidPipeline.md),
  [Third-party notices](ThirdPartyNotices.md), `AGENTS.md`

This is the ordered cutover record. Sections A–G say what landed, why the order
matters and which commands reproduce or verify it. The compatibility RGBA
atlases remain deliberately as an all-or-nothing fallback; the live actors
prefer the raw indexed bundles.

This cutover is for play-scale Voss and Lila sprites only. The inventory
paperdoll and portrait are not part of it and must not be passed through the
avatar encoder without their own authored material masks.

---

## What shipped

- The GemRB palette port and its BG:EE gradient data:
  `ie_palette.py`, `IEPalette.swift`, `IEPaperdollColours.swift`,
  `IEGradientTables.swift`, `pal16.bin` and `pal256.bin`.
- Strict P-mode material masks: **204 Voss** masters and **25 Lila** authorities.
- The paired raster/index encode path in `crunch.crunch_avatar`.
- The current bake authorities: `install_voss_v22.py` and
  `install_lila_ie_avatar.py`.
- The V22/Lila shipping path no longer calls the legacy wardrobe locks or
  re-finalises a clip palette after encoding.
- Compatibility RGBA atlases produced from the index planes, plus versioned
  raw indexed bundles at `Resources/Art/IE/Avatars/{Voss,Lila}/avatar-v01.*`.
- The cutover hash proof: **249 visible frames changed** and the **24 deliberately
  transparent `VossSeatedArms` cells remained identical**.
- The old RGB locks and invented clip-palette surface are gone;
  `qa_wardrobe_lock_preservation.py` was deleted and the stale V17 RGB gate was
  replaced with raw-index, palette, topology and exact round-trip assertions.
- `IEIndexedSprite` validates and resolves each character-owned palette;
  `IEAvatarNode`, `DetectiveActorNode` and `ClientActorNode` use the cropped
  frame size and pivot at runtime, with an atomic RGBA-atlas fallback.
- Both Xcode app targets include the two new Swift files and both character
  bundle directories.

---

## A. Author the material masks — complete

### A.1 What a mask is

The mask is a **P-mode indexed PNG at the exact source-master dimensions**.
Its palette index is the material; the RGB swatches only make it legible in an
editor. Every body pixel must be assigned indices 1–7. Index 0 is permitted
only outside the body silhouette: it is background/colour key, not an
"infer this pixel" escape hatch.

`author_material_masks.load_mask` rejects all of the following:

- RGB or greyscale files rather than P-mode PNGs;
- a changed first-eight-entry palette;
- values outside 0–7;
- the wrong dimensions;
- a nonzero pixel outside the master silhouette; or
- an index-0 hole anywhere inside the silhouette.

The material table is:

| index | swatch | IE slot | Voss assignment | Lila assignment |
|---:|---|---|---|---|
| 0 | black | — | background / colour key | background / colour key |
| 1 | magenta | `METAL` | shoes | shoes |
| 2 | cyan | `MINOR` | shirt | collar |
| 3 | yellow | `MAJOR` | tie | trim |
| 4 | orange | `SKIN` | skin | skin |
| 5 | blue | `LEATHER` | trousers | dress |
| 6 | green | `ARMOR` | coat + waistcoat | coat |
| 7 | red | `HAIR` | hair | hair |

Voss masks live in:

```
ArtSource/Generated/Characters/Detective/PreRendered3DV22/Materials/
<stem>_mask_v01.png
```

`<stem>` is the V22 master filename without `_chroma_v22.png`. The directory
must contain exactly 204 masks: no missing file and no stale extra.

Lila masks live in:

```
ArtSource/Generated/Characters/Client/IEAvatarV01/Materials/
<runtime-frame-stem>_mask_v01.png
```

Their exact inventory is nine `lila_arrival_sw` cells, eight
`lila_departure_ne` cells and eight `lila_departure_nw` cells: 25 total.

The optional `<stem>_conf_v01.png` is a Voss draft-review artefact. It is not
read by either installer and is not part of the material truth.

### A.2 How the Voss drafts were generated

From `ArtSource/Processing/`:

```sh
python3 author_material_masks.py --write --review
```

`--write` emits the 204 Voss drafts and confidence maps. `--review` emits
master · mask · confidence sheets under `ArtSource/Generated/IE/MaterialMasks/`.
`--list` reports without writing and `--limit N` limits a draft run.

This is a draft generator, not a merge tool. `--write` overwrites every Voss
mask unconditionally, including the accepted hand-authored masks now in the
tree. Do not run it against the accepted directory unless replacing those
masks intentionally.

### A.3 How to read the five confidence levels

| value | what the draft pass claimed | review obligation |
|---:|---|---|
| 255 | colour decided it with a margin over every rival | ordinary spot-check |
| 192 | measured geometry: head, shoe band or legs below the measured hem | spot-check |
| 128 | coat by elimination within the torso band | spot-check boundaries |
| 64 | within `HEM_BLUR` of the measured coat hem | paint/check manually |
| 0 | nothing was measured; the pose defeated the pass | paint manually |

The original draft measurement, retained as provenance, was:

```
204 masters: 4.3% colour · 7.2% measured geometry · 38.3% coat by elimination · 50.2% unresolved
  upright poses (108):        9.5% unresolved
  seated / transition (96):  96.1% unresolved
```

Those numbers describe the discarded drafts, not the accepted masks.

### A.4 The three Voss gaps and their recorded resolutions

**The 96 seated and transition masters.** The geometric pass cannot find a
standing neck or coat hem in these poses. Paint one authority per pose cluster,
not one independently invented answer per frame; propagate only within that
cluster, then correct individual phases wherever its silhouette or overlap
moves. One classifier result must never be copied blindly across a whole
animation.

**Three-quarter and rear faces.** Every phase of every affected direction was
reviewed. Visible faces use index 4; true rear views do not invent skin merely
to satisfy a global percentage.

**The waistcoat.** This was a wardrobe decision, not a defect. The three named
choices were `coat+waistcoat` in `ARMOR`, `shirt+waistcoat` in `MINOR`, or
`tie+waistcoat` in `MAJOR`. The accepted choice is `coat+waistcoat`: the two
brown outer garments recolour together and the maroon tie keeps `MAJOR` to
itself. `ie_avatar.VOSS` records that decision and pins Voss's seven gradient
rows to `(138, 171, 198, 84, 160, 237, 48)`.

Lila was separately authored across all 25 gameplay authorities. Her pinned
rows are `(22, 5, 253, 233, 193, 219, 234)`; they are not inferred from one
representative frame.

---

## B. Verify — complete and still mandatory

From `ArtSource/Processing/`:

```sh
python3 qa_ie_palette_port.py
python3 qa_ie_avatar_encode.py --sheet
```

Both printed `ALL CHECKS PASS` for the installed payload and must stay green.
The first gate checks the Python port against
the shipped BG:EE tables; `IEPaletteTests.swift` holds the Swift port to the
same fixtures. The second requires the exact 204 + 25
mask inventories and structurally validates every mask; for Voss it also grades
every phase of every authored direction, not five sampled clips.

`qa_ie_avatar_encode.py` distinguishes `FAIL` (code/data) from `ART` (a mask
needs painting). Both exit 1. Never relax `MAX_MEAN_RGB_ERROR`,
`MAX_MEAN_RGB_ERROR_MASKED`, `MIN_SKIN_SHARE` or `MAX_MATERIAL_SHARE` to make a
payload green.

The installer stages are an additional gate because they validate the exact
registered payload and raw bundle that will be installed:

```sh
python3 install_voss_v22.py stage
python3 install_lila_ie_avatar.py stage
```

The bake cutover was not allowed to begin until the encode gate was green; that
ordering remains the rule for every future mask or master revision.

---

## C. Cut the bake over — complete

### C.1 Raster craft that stayed

The colour model changed without moving the physical actor contract. The
explicit keep-list in `crunch.py` is raster craft only:

- `CrunchSpec`, `BGEE_V1` and the historical comparison specs;
- `soften`;
- `harden_alpha` and `_native_with_mask`;
- `widen_humanoid_geometry` and `widen_humanoid_geometry_with_mask`;
- `crunch_avatar` for paired shipping work; and
- `crunch` for historical geometry callers.

Those retain the 64-row native craft, row-wise humanoid widening and nearest
enlargement. Registration outside `crunch.py` retains the 512 compatibility
canvas, `TEXTURE_BODY_HEIGHT = 200` and `FOOT_Y = 433`.

`crunch.crunch_avatar` carries the RGBA figure and categorical material plane
through every crop, resize and width correction. Geometry may interpolate RGB;
the material plane always uses nearest-neighbour sampling. It calls
`ie_avatar.encode_frame` once, after geometry is final, and returns an
`AvatarFrame` whose 8-bit index plane is authoritative.

The public `crunch()` compatibility entry point still returns an RGBA
raster-craft figure because historical geometry generators register that
figure on their own compatibility canvas. It performs only crop, hard-alpha
convergence, 64-row native reduction, row-wise widening and nearest
enlargement; it does no colour classification, palette fitting or grading.
`crunch_avatar()` is the paired shipping authority and returns a byte-exact
index plane whose `AvatarFrame.to_rgba()` method supplies the compatibility
rendering.

### C.2 What replaced the clip palette

The authoritative result is not a P-mode PNG beside every atlas cell. The
installers write:

```
RainShadow Shared/Resources/Art/IE/Avatars/Voss/avatar-v01.json
RainShadow Shared/Resources/Art/IE/Avatars/Voss/avatar-v01.indices
RainShadow Shared/Resources/Art/IE/Avatars/Lila/avatar-v01.json
RainShadow Shared/Resources/Art/IE/Avatars/Lila/avatar-v01.indices
```

The `.indices` file is a versioned raw bundle with magic `RSIEAV1\0`, an
explicit little-endian header and top-down row-major `u8` frame payloads. The
JSON manifest records the schema/version, SHA-256, `colors[]`, frame name,
trimmed dimensions, byte offset/length, source-canvas registration and pivot.
This avoids ImageIO/CoreGraphics expanding or colour-managing an indexed PNG.

Compatibility RGBA atlas PNGs are rendered from those same index planes and
installed transactionally with the bundle. They remain as the all-or-nothing
fallback when a character bundle cannot be loaded; they are not the preferred
runtime source.

### C.3 What was deleted

These were the invented colour model, not raster craft, and were deleted from
`crunch.py`:

`_colour_centroids`, `_region_ramp`, `_quantise_medcut`,
`_quantise_material_clusters`, `_quantise_ramps`, `ClipPalette`,
`build_clip_palette`, `normalise_clip_exposure`, `_graded_body`,
`_grade_value_contrast`, `material_coverage`, `_labels_from_coverage`,
`_coat_mask`, `_skin_mask`, `_face_roi_mask`, `_coat_roi_mask`,
`_opaque_body_box`, and `finalise`.

The accompanying global lock surface was removed too: `PRESERVE_WARDROBE`,
`material_hue_spread`, `HUE_SPREAD_FLOOR`, `HUE_SPREAD_TARGET`, `WARDROBE` and
`has_material_separation`. Historical V16–V21 scripts remain as source history,
not runnable partial installers; current art may only be staged by the V22 and
indexed-Lila authorities in D.

The paperdoll is deliberately absent from this list of replacements. Although
`ie_avatar.encode_plt` and `PLTSprite.swift` describe the PLT model, the
play-scale cutover does not re-encode the current paperdoll or portrait.

### C.4 Visual proof was part of the gate

A single Voss clip was rebaked and inspected before the transactional install.
The first Lila attempt used colour inference, passed its numeric/format checks,
and visibly put brown/maroon streaks through her green coat. It was rejected,
all 25 Lila masks were authored, and only the corrected payload was installed.

That failure is why "rebake one clip and look at it" remains required. Both
failed classifiers passed every numeric check while producing visibly wrong
art.

---

## D. Rebake — complete; these are the authorities

The historical V12/V11 six-command sequence is superseded for current runtime
art. Reproduce the indexed cutover with the two transactional installers:

```bash
cd ArtSource/Processing
python3 qa_ie_palette_port.py
python3 qa_ie_avatar_encode.py
python3 install_voss_v22.py stage
python3 install_voss_v22.py install --confirm-runtime-replace V22
python3 install_lila_ie_avatar.py stage
python3 install_lila_ie_avatar.py install --confirm-runtime-replace LILA
```

The Voss install replaces five atlases and its bundle as one rollback
transaction. It emits 248 bundle records: 224 visible cells and 24 empty
`VossSeatedArms` cells. The Lila install replaces 25 visible atlas cells and
its bundle as one transaction.

The hash rule is intentionally inverted for the cutover, but the expected
result is **not** 273 changed frames:

- 249 visible atlas frames must change;
- 24 transparent `VossSeatedArms` frames must remain identical; and
- any other identical frame means the new colour path was not taken.

The recorded before/after inventory was 273 files both times, with exactly that
249/24 split. Future changes intended to be inert use the ordinary rule again:
all 273 atlas hashes must be identical.

---

## E. Retire the legacy locks — complete

The following is the exact removal ledger. Line numbers deliberately refer to
the frozen pre-cutover files, because successful removal means there is no
current definition to point at:

| pre-cutover file | removed symbols and sites |
|---|---|
| `process_pre_rendered_characters_v12.py` | `_match_region` 71; `play_scale_wardrobe_stats` 122; `paperdoll_wardrobe_stats` 147; `paperdoll_wardrobe_target` 153; `identity_wardrobe_lock` 158 with calls 248, 298, 433 and 439; `warm_brown_lock` 246 |
| `process_voss_desk_ne_v12.py` | `identity_wardrobe_lock` import 24 and calls 67, 71 |
| `install_voss_idle_walk_seated_match_v02.py` | `seated_authority_lock` 427 with its **five** calls 684, 870, 872, 891 and 1038; `wardrobe_match_to_idle` 976/call 1118; `lock_standup_handoff` 1105/call 1246; stale post-lock comment 1077 |
| `crunch.py` | `ClipPalette` 125; `_opaque_body_box` 286; `_coat_mask` 293; `_skin_mask` 309; `_face_roi_mask` 327; `_coat_roi_mask` 343; `material_coverage` 360; `_labels_from_coverage` 388; `HUE_SPREAD_FLOOR`/`HUE_SPREAD_TARGET` 401–402; `WARDROBE` 406; `_colour_centroids` 418; `material_hue_spread` 434; `PRESERVE_WARDROBE` 473; `has_material_separation` 476; `_graded_body` 511; `_grade_value_contrast` 542; `_quantise_medcut` 561; `_region_ramp` 578; `normalise_clip_exposure` 600; `build_clip_palette` 646; `_quantise_material_clusters` 704; `_quantise_ramps` 750; `finalise` 868 |
| `install_voss_v16.py` | environment/global arming 51, 54 and validation 305–306 |
| `install_voss_v17.py`, `install_voss_v18.py`, `install_voss_v19.py` | environment/global arming 65–66 in each file |
| `install_voss_v20.py` | save/arm/restore block 186–205 |
| `install_voss_v21.py` | save/arm/restore block 63–83 |
| `process_voss_character_strip_v22.py` | environment/global arming 21, 32 |
| `test_voss_v16_pipeline.py` | obsolete `PRESERVE_WARDROBE` assertion 59 |
| `qa_wardrobe_lock_preservation.py` | four `PRESERVE_WARDROBE` references 7, 34, 35 and 39, plus imports/calls of the removed locks; the file was deleted |

`install_voss_v22.py` also lost its `PRESERVE_WARDROBE` handling, monkey patch
of `_process_clip`, `build_clip_palette`/`finalise` calls and dead
`_restage_seats` path. The historical V12 desk/seat scripts are now
geometry/canvas-only; V16–V21 are source history rather than supported partial
installers. Removing the global rather than leaving it false is intentional:
there is no switch that may silently reactivate the obsolete colour model.

### E.2 The stronger Swift colour gate

The old `VossWardrobeColorTests` failed by construction after retirement. Its
test at lines 28–44 demanded `RAINSHADOW_PRESERVE_WARDROBE`; its
`VossMaterial.lockedRGB` table at 186–205 froze a near-black tie and charcoal
trousers that were already stale against V22's red tie `(128, 36, 42)` and
brown trousers `(70, 48, 32)`.

The replacement gate now asserts:

- exact inventories: Voss 248 records (224 visible + 24 empty arms), Lila 25;
- exact character `colors[]`, source canvas, display size and external-shadow
  metadata;
- exact atlas filename sets and allowed material-range indices, with index 1
  absent, every Voss slot used and Lila using every slot except `MINOR`;
- byte-exact reconstruction of all **273** compatibility PNGs from their raw
  index planes and character palettes, after removing only the four deliberate
  alpha-1 packing sentinels;
- changing Voss's `ARMOR` row changes only `ARMOR` RGB — never alpha, indices,
  crop or pivot; and
- direct index topology across all 36 rear idle/walk frames and all 32 north
  seat frames: no `MINOR` shirt, no `MAJOR` tie and at most 3% `SKIN` for the
  visible-hands allowance.

That is stronger than proximity to the V17 RGB table and cannot become green
merely because a later palette happens to move closer to a wrong garment.

---

## F. Runtime indexed sprite model — complete

SpriteKit has no paletted texture type. The runtime must read the versioned raw
bundle, resolve its indices through the character palette once per sprite
creation (or cached palette/frame pair), and create an RGBA texture. Do not load
the index plane through an indexed PNG.

The closest GemRB provenance is the avatar path in `BAMImporter` plus
`CharAnimations`' per-character palette setup. It is **not**
`PLTImporter::GetSprite2D`: PLT is the inventory-paperdoll `(intensity, range)`
format, and the paperdoll is outside this cutover.

That split is implemented as the pure bundle/parser model
`Gameplay/Navigation/IEIndexedSprite.swift` and the SpriteKit-facing
`Gameplay/Actors/IEAvatarNode.swift`. `DetectiveActorNode.swift` and
`ClientActorNode.swift` now select frames by atlas/name and atomically apply
each trimmed texture, display size and `pivot_from_crop_bottom_left_px`.
The old direct `SKTextureAtlas`/fixed-cell frame path and texture-only animation
steps are gone from the preferred path. An entire clip falls back to the RGBA
atlas together if its indexed inventory is unavailable or incomplete; indexed
and compatibility pivots are never mixed within one animation.

The manifest scale preserves the old 180-by-180 compatibility registration
without forcing every runtime texture back into a transparent 512-by-512 cell.
The 200px/70.3125-unit body and foot registration therefore did not move.

Keep `ContactShadowNode.swift` and `ActorSceneLighting.contactShadowAlphaScale`.
Neither installed bundle contains index 1; both manifests say the external
contact-shadow node owns the shadow. Retiring it now would remove the actors'
shadows rather than move them into the indexed sprite.

`VossSeatScaleTests` now loads the Voss manifest, asserts the common
`180 / 512` display scale, proves standing and seated crops differ, and
reconstructs the same source-canvas pivot from each crop's trim and local
pivot. It also holds the actor to `IEAvatarNode` and rejects the retired
`frameDisplaySizeConstant` scaffolding. The 200px/70.3125-unit body contract
remains exact.

### F.1 The Xcode include-list trap

`RainShadow.xcodeproj/project.pbxproj` has **two** relevant
`membershipExceptions` include lists for `RainShadow Shared`: one for the iOS
app target and one for the macOS app target. Every new Swift file and both
avatar resource-directory entries must appear in both lists:

```
Gameplay/Actors/IEAvatarNode.swift
Gameplay/Navigation/IEGradientTables.swift
Gameplay/Navigation/IEIndexedSprite.swift
Gameplay/Navigation/IEPalette.swift
Gameplay/Navigation/IEPaperdollColours.swift
Gameplay/Navigation/PLTSprite.swift
Resources/Art/IE/Avatars/Lila
Resources/Art/IE/Avatars/Voss
```

`ensure_shared_art_membership.py` only helps with `Resources/` paths. Swift
files under `Gameplay/` must be inserted directly, in sorted position, into
both lists. A one-target edit can compile one scheme while leaving the other
without code or bundle data; `LootUIAssetTests`' project-file check exists for
this class of failure.

---

## G. Final gate

Run all three commands from the repository root:

```sh
xcodebuild -project RainShadow.xcodeproj -scheme "RainShadow iOS" -configuration Debug -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
xcodebuild -project RainShadow.xcodeproj -scheme "RainShadow macOS" -configuration Debug CODE_SIGNING_ALLOWED=NO build
swift test --scratch-path /tmp/RainShadowSwiftPM
```

The scratch path must be outside the iCloud-synchronised checkout. Historical
installers use `shutil.copy2`, which can carry extended attributes into atlas
resources; `codesign` then rejects the test bundle for resource-fork/Finder
metadata even when the source is correct.

The pre-cutover baseline was **995 tests in 95 suites**. The completed cutover
still runs exactly **995 tests in 95 suites**, all green; replacing the stale
seven-test RGB suite with seven indexed-contract tests did not lower coverage.

The cutover verification built both app schemes successfully. The Lila and
Voss JSON/`.indices` directories were present in both built products and their
hashes were byte-identical to the source resources. Voss front/rear/transition
and every phase of both Lila departure directions were inspected after the
rebake; no numeric gate substituted for that visual pass.

After the builds, run the app and inspect Voss standing, walking in every
direction, sitting and standing, plus all three Lila clips. Confirm frame
pivots do not jump and the external contact shadows remain visible.

---

## Seven traps

1. **`author_material_masks.py --write` has no merge.** It overwrites accepted
   Voss masks; generate drafts away from the authoritative directory.
2. **A mask is categorical and complete.** Keep P mode, nearest-neighbour only,
   indices 0–7, and no index-0 holes inside the body.
3. **V17 is stale.** The removed `VossWardrobeColorTests.VossMaterial` table and
   the V17 installer are not wardrobe authorities; `ie_avatar.VOSS`, the raw
   bundles and V22/Lila masks are.
4. **One frame cannot stand for a direction.** Gate all 204 Voss masters and
   all 25 Lila authorities, then look at a rebaked clip; numeric checks missed
   both failed classifiers during this work.
5. **The cutover hash proof is 249 changed / 24 identical.** The only permitted
   identical cells are the transparent `VossSeatedArms`; "273 must change" is
   wrong.
6. **The runtime source is the raw bundle, and the shadow is still external.**
   Do not smuggle P-mode PNGs into `.atlas`, do not cite `PLTImporter` for BAM
   avatars, do not remove `ContactShadowNode`, and keep both avatar resource
   directories in both Xcode include lists.
7. **Generated-data hazards still apply.** Do not casually rerun
   `extract_ie_gradients.py`; a changed manifest hash means the BG:EE source
   data changed. Edit only un-suffixed scripts, because tracked `* 2.py` Finder
   duplicates exist, and keep SwiftPM's scratch path outside iCloud.

---

# Addendum: the enlargement, and why Voss still looks pixelated

- Added 29 August 2026, after the colour model landed and the bake was rebaked.

## What the problem actually is

Voss reads as chunky pixel art, and it is not the palette. `crunch_avatar`
reduces a master to the measured 64-row craft, encodes it to IE indices, and
then **nearest-enlarges the index plane x3.125** to the 200px registered body.
Every native pixel becomes a hard 3x3 block. A shipped
`voss_standing_idle_s_00.png` carried 40 colours with 81% of horizontally
adjacent body pixels byte-identical.

This matters on screen, not just in the atlas. On a Retina display the default
9% camera shows the body at ~104 **points**, which is ~208 physical pixels — so
the 200px texture is drawn at roughly 1:1 and the blocks are seen directly.
Measuring at 104 *pixels* suggests the problem is mild; that measurement is
wrong, and the render at 208/296 physical pixels is the one to look at.

## What is landed

**Switched on and shipped, 29 August 2026.** The sections below describe the
state before the cutover; the outcome is at the end of this addendum.

| landed | what |
|---|---|
| `ArtSource/Processing/ie_resample.py` | Super xBR + Lanczos, from Near Infinity |
| `RainShadow Shared/Gameplay/Navigation/IEResample.swift` | the same, for the runtime |
| `Tests/RainShadowCoreTests/IEResampleTests.swift` | pins the two together, pixel for pixel, at the 3.125 shipping scale |
| `ArtSource/Processing/ie_colorconvert.py` | CIE94 in CIELAB, from Near Infinity |
| `ArtSource/Processing/qa_superxbr_ab_v01.py` | the A/B, with a `--zoom` sheet |
| `crunch_avatar(..., resample=)` | `"nearest"` (default, unchanged) / `"superxbr"` / `"superxbr1"` |

CIE94 **is** live in `ie_avatar`, because it changes only which shade a pixel
picks and the gates got much tighter as a result:

| measurement | invented metric | CIE94 |
|---|---:|---:|
| worst frame, material inferred | 19.9 | **3.6** |
| worst frame, authored mask | 26.9 | **5.9** |
| `MAX_MEAN_RGB_ERROR` | 26 | **8** |
| `MAX_MEAN_RGB_ERROR_MASKED` | 32 | **12** |

`qa_ie_avatar_encode.py`'s separability check was re-derived at the same time.
It no longer compares anchors against a tuned 0.30; it compares **how close two
materials' ramps ever come** against **the median step along a ramp**, both in
CIE94 dE. On Voss V22 that is 1.8-2.7 against 6.4 — a pixel is likelier to land
on the wrong material than on the wrong shade of its own, so 11 of 21 pairs need
masks. Same conclusion as before, now measured rather than tuned.

The clip-drift check also gained a **relative** sample floor (0.5% of the body).
It was failing on `shirt` and `tie` in walk and seat clips, where Voss's coat
swings shut and the garment is 9 pixels in one frame and 93 in another; that
spread is the garment appearing, not the palette moving.

## Why it needed a bundle migration

> **Historical presentation record.** This section records the Super-xBR
> migration that originally introduced bundle v02. Voss stopped using that
> prefilter on 2 September 2026: its native v02 plane is now resolved directly
> and enlarged once by SpriteKit's linear sampler, matching BG:EE's current
> non-nearest creature path. Lila and compatibility fallbacks retain their
> existing behavior until separately reviewed.

Super xBR cannot run on an index plane — there is no colour halfway between
palette entry 37 and 52, the same reason `ie_avatar.resample_mask` is
nearest-only. So the render has to start from the **native** index plane, and
the shipped `.indices` bundle stores indices at *texture* resolution. Switching
the filter on therefore requires migrating the bundle, and the bundle is load
bearing: `IEAvatarNode` resolves it at runtime, and
`VossWardrobeColorTests.everyVossFrameRoundTripsExactlyToItsCompatibilityAtlasCell`
asserts the atlas PNG is exactly its palette resolution.

## The migration, as it was done

1. **Bundle v02.** `ArtSource/Processing/ie_avatar_bundle.py` writes
   `avatar-v01.{json,indices}` at texture resolution. v02 stores the **native**
   trimmed index plane plus the texture scale (`TEXTURE_BODY_HEIGHT /
   native_rows`, currently 3.125). Smaller, and it is the real BAM frame.
2. **`IEIndexedSprite.swift`.** Frame geometry — `sourceCanvasSize`,
   `trimOriginTopLeft`, the compatibility display vector — is currently in
   texture pixels. Decide per field whether it stays texture-space (likely, it
   feeds node sizing) or becomes native, and make `rgba(for:)` resolve native
   then call `IEResample.scaleSuperXBR`. This is the delicate part; the two
   spaces must not be mixed silently.
3. **`crunch_avatar` default** to `resample="superxbr"`, and `AvatarFrame.texture`
   becomes the atlas render. The plumbing is already there.
4. **Rebake**, then re-hash. Follow the current AGENTS.md rule, not a blanket
   count: the last non-inert rebake's proof was 249 visible frames changed and
   24 transparent `VossSeatedArms` frames identical.
5. **Round-trip tests stay exact.** They compare a Swift render against a Python
   render, and `IEResampleTests` already proves those agree. Do not relax them
   to a tolerance.
6. `VossSeatScaleTests` — re-measure the 198...202 body height and `footY == 433`.
   `crunch_avatar`'s superxbr path re-applies `harden_alpha` at 128 for exactly
   this reason, and the A/B measured height 200 and footY unchanged on
   `voss_idle_s_00`, but it must be re-derived across every clip.

## What the A/B showed

`python3 ArtSource/Processing/qa_superxbr_ab_v01.py`

| | colours | block-run |
|---|---:|---:|
| nearest | 40 | 0.814 |
| superxbr | 2880 | 0.053 |
| superxbr1 (one doubling) | 2637 | 0.079 |

At 3x magnification Super xBR looks soft and slightly melted on the coat, and
the single-doubling variant is not meaningfully different. **At the sizes the
game actually draws** — 208 and 296 physical pixels — it is decisively better:
nearest shows obvious stair-stepping, Super xBR reads as a pre-rendered sprite.
Judge it at those sizes, not at 3x.

One thing this will not fix: the masters are dark and near-monochrome, so Voss
will still not read like the green-robed and red-tunic figures in a BG2 frame.
That is wardrobe and lighting in the masters, not resampling.

---

## Outcome

Bundle **v02** ships: the index plane is native craft, `texture_px` and the trim
origin carry the render's placement, and `IEIndexedSprite.rgba(for:)` resolves
the plane and enlarges it with `IEResample.scaleSuperXBR`. Measured over the 273
shipped cells:

| | nearest (before) | Super xBR (now) |
|---|---:|---:|
| visible frames | 249 | 249 |
| transparent `VossSeatedArms` cells | 24 | 24 |
| block-run, median | ~0.81 | **0.058** |
| block-run, worst frame | — | 0.108 |
| distinct colours per frame, median | ~40 | 2231 |
| frames still blocky (>0.5) | 249 | **0** |

`footY` and the 200px registered body are untouched, which is what the
`harden_alpha` step after the filter is for.

### What had to change beyond the resampler

- **The silhouette is filtered from a colour-independent stencil.** Super xBR
  decides each blend from the luma of what it samples, so an alpha taken from
  the colour pass depends on the palette — recolouring Voss's coat moved his
  edge. The stencil pass restores the contract that recolouring cannot move the
  silhouette, which `changingOneCharacterColourChangesOnlyThatMaterialRun`
  asserts.
- **Two baselines were re-derived, both recorded at the assertion.** The seated
  neutral-IoU gate went 0.86 → 0.85 (`install_voss_v20.exact_gates`, the V22
  manifest, and the Swift fallback), because a nearest enlargement quantised
  head widths onto multiples of about three and made neighbouring frames
  register identically by accident; the same SE frames, aligned, still match at
  0.9352 against 0.9361. `MAX_MEAN_RGB_ERROR` went 26 → 8 and its masked twin
  32 → 12, tightened because CIE94 improved the worst frame from 19.9 to 4.3.
- **Head-width correction is clip-uniform for idles, per-frame for
  transitions.** An idle is a rigid body and a transition is a ramp; those are
  different contracts and they now have different corrections.

### Art debt this exposed

The SE seated idle's head width genuinely varies across the clip — 22, 22, 19,
21, 21, 22, 22, 21 in canvas pixels. That variation was always in the V22
masters; a blocky enlargement hid it. Fixing it in the masters is what would let
the neutral-IoU gate go back to 0.86.

# Voss head refinement V02

2026-08-31. Staged head study, not installed. The user liked the V01 body
direction and requested a less round, more BG-like head. This is an art
interpretation, not a reconstruction of a particular BioWare model.

`ArtSource/Blender/build_voss_head_proof_v02.py` authors a replacement head on
the V01 proof's exact body and neck. It narrows the temples, defines the cheek
and jaw transition, replaces the spherical nose with a straight bridge/wedge,
reduces crown height above the brow, and adds a shorter side-parted hair shape.
The generated `.blend` is output, not source.

The builder asserts exact equality of all 4,628 body/neck vertices and 4,025
faces, including their weights, vertex colours and material assignments. Only
head-weighted vertices are replaced. The existing materials, skeleton, idle,
walk, camera and lighting are reused. The revised mesh totals 5,595 vertices
and 4,892 faces; these are offline render costs.

## Comparisons

Outputs are isolated in
`ArtSource/Generated/Characters/Detective/HeadArtProofV02/`:

- `head_comparison.png`: identical source-coordinate head crops plus native
  figures enlarged by the same 3.125× direct bilinear sampling.
- `native_head_pixels.png`: 12× nearest head pixels and 1× figures.
- `walk.gif`, `walk_contact_sheet.png`, `direction_checks.png`: all eight SW
  walk phases and four standing directions.
- `comparison.png`: the existing V22 / V23 / proof / recoloured BG reference
  comparison. The BG figure has a different costume and pose.
- `head_geometry_checks.json`, `rig_checks.json`, `proof_manifest.json`:
  assertions, measurements and remaining scope limits.

The V01 palette `[248, 226, 243, 162, 138, 23, 23]` and 89×107 native canvas
are frozen, not re-fitted to this head. SW standing remains 64 body rows.
This prevents the head change from resizing or recolouring the accepted body.
Changed head lighting can naturally change the shadow it casts; that is not
a different body mesh or a change to the renderer.

## Verification

All twelve masks pass categorical coverage and indexed encoding checks;
native PNG indices survive exact round trips. The standing anchor, shadow
presence, unclipped source and pure-N trim checks pass. All eight gait phases
still have grounded support soles and neither shoe below the floor. All 250
installed Voss file hashes match the V01 proof's runtime baseline.

The small reuse hooks in the V01 scripts were verified by rebuilding,
rendering, finalising and reviewing V01 again: **41/41 finalised images,
indexed frames and review artifacts remained byte-identical**. The 24 raw
Blender pass PNG files were regenerated and are not included in that byte
identity claim.

This does not approve all facings, seat transitions, runtime timing or night
grading. The V01 rear-quarter collar issue is still open. No runtime files,
active master set, palette authority, navigation or renderer ports changed.

## Reproduce

V01 must already be rendered/reviewed; it supplies the frozen comparison.
Run from the repository root on macOS:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background \
  --python-exit-code 1 --python ArtSource/Blender/build_voss_head_proof_v02.py
/Applications/Blender.app/Contents/MacOS/Blender --background \
  ArtSource/Generated/Characters/Detective/HeadArtProofV02/voss_head_proof_v02.blend \
  --python-exit-code 1 --python ArtSource/Processing/render_voss_sprite_proof_v01.py \
  -- --head-v02
python3 -B ArtSource/Processing/render_voss_sprite_proof_v01.py --finalise --head-v02
python3 -B ArtSource/Processing/review_voss_head_proof_v02.py
/Applications/Blender.app/Contents/MacOS/Blender --background \
  ArtSource/Generated/Characters/Detective/HeadArtProofV02/voss_head_proof_v02.blend \
  --python-exit-code 1 --python ArtSource/Blender/qa_voss_sprite_proof_v01.py \
  -- --head-v02
```

There is no runtime install command for this study.

## Nose-only follow-up V03

The user found the V02 nose unnatural. It projected abruptly from the brow and
ended in a thin wedge. `ArtSource/Blender/build_voss_nose_proof_v03.py` replaces
only that feature with a flush root, a less projecting bridge and a softened
tip/base. All 5,588 non-nose vertices and 4,886 non-nose faces (including
colours, weights, material assignments and reindexed topology) are asserted
exactly equal to V02. The original V02 wedge remains reproducible.

Output is isolated in `ArtSource/Generated/Characters/Detective/NoseArtProofV03`.
`head_comparison.png` compares V02 with V03; `native_head_pixels.png` exposes
the actual reduced pixels. The palette and 89×107 native canvas are frozen
from V02. All twelve mask/encoding checks, the 64-row standing anchor, pure-N
trim and eight-phase grounded-foot checks pass. All 250 installed Voss hashes
remain unchanged. The existing full-facing/seat/runtime limitations still apply.
Rebuilding V02 through the refactored helpers preserved all 43 finalised and
review images byte-for-byte. In the SW native idle, V03 changes only five
indices in the nose's 2×3-pixel region.

Reproduce with the same render and QA scripts, selecting `--nose-v03`:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background \
  --python-exit-code 1 --python ArtSource/Blender/build_voss_nose_proof_v03.py
/Applications/Blender.app/Contents/MacOS/Blender --background \
  ArtSource/Generated/Characters/Detective/NoseArtProofV03/voss_nose_proof_v03.blend \
  --python-exit-code 1 --python ArtSource/Processing/render_voss_sprite_proof_v01.py \
  -- --nose-v03
python3 -B ArtSource/Processing/render_voss_sprite_proof_v01.py --finalise --nose-v03
python3 -B ArtSource/Processing/review_voss_nose_proof_v03.py
/Applications/Blender.app/Contents/MacOS/Blender --background \
  ArtSource/Generated/Characters/Detective/NoseArtProofV03/voss_nose_proof_v03.blend \
  --python-exit-code 1 --python ArtSource/Blender/qa_voss_sprite_proof_v01.py \
  -- --nose-v03
```

## Face/hair shading follow-up V04

The user correctly identified a stronger gradient in the BG reference hair.
The comparison shared the same palette rows, **not the same surface shading**.
The BAM pixels establish the baked shading, not what texture maps BioWare used
in its original 3D authoring. No BG texture was copied into Voss.

The material-index audit of `CEFC4G12`, cycle 20, phase 0, frame 193, against
the SW standing V03 proof reads the top 20% of each native figure's body height.
Shade 0 is brightest and 11 darkest; the skin alias B0-B7 is handled explicitly.

| Native head pixels | BG | V03 | V04 |
|---|---|---|---|
| Hair shades present | 2–10 (9 shades) | 5–9 (5 shades) | 3,4,5,6,8,9,10 (7 shades) |
| Hair upper/lower mean shade | 3.86 / 6.50 | 6.27 / 6.88 | 3.80 / 7.00 |
| Skin shades present | 4–10 | 6–11 | 4–11 |

`ArtSource/Blender/build_voss_shading_proof_v04.py` adds broad face/hair vertex
colour shading: a concentrated diffuse crown highlight fading into a darker
lower hair mass, and brighter forehead/cheek planes. The existing side part,
eye/mouth marks and nose remain. It does not add random grain or screen-space
post-processing. The palette, lights, camera, clothing and all 5,716 vertices
and 5,000 faces remain unchanged; neck and hand shading are untouched.

Output is isolated in `ArtSource/Generated/Characters/Detective/ShadingArtProofV04`.
`bg_shading_comparison.png` shows BG / V03 / V04 at equal displayed body height,
plus equally magnified native heads. `shading_audit.json` records all twelve
proof frames, the source comparison, and the checks. It is still a visual
candidate, not an installed avatar or an exact reconstruction of the BG head.

Verification: all twelve **raw rendered** material masks are pixel-identical
to V03. Final categorical masks legitimately differ on a few head-edge pixels:
the existing finaliser snaps to colour-dependent keyed beauty alpha. The audit
allows only skin/hair ↔ background changes adjacent to background, never a
changed interior material. Native silhouettes, shadow indices and all pixels
below the head region remain exact. Normal mask completeness, palette round
trips, native 64-row anchor and grounded eight-phase walk checks pass; 250
installed Voss files remain unchanged. Full-facing, seating and in-scene
approval are still outside this proof.

Reproduce using the V04 builder and the existing isolated render/QA wrappers:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background \
  --python-exit-code 1 --python ArtSource/Blender/build_voss_shading_proof_v04.py
/Applications/Blender.app/Contents/MacOS/Blender --background \
  ArtSource/Generated/Characters/Detective/ShadingArtProofV04/voss_shading_proof_v04.blend \
  --python-exit-code 1 --python ArtSource/Processing/render_voss_sprite_proof_v01.py \
  -- --shading-v04
python3 -B ArtSource/Processing/render_voss_sprite_proof_v01.py --finalise --shading-v04
python3 -B ArtSource/Processing/review_voss_shading_proof_v04.py
/Applications/Blender.app/Contents/MacOS/Blender --background \
  ArtSource/Generated/Characters/Detective/ShadingArtProofV04/voss_shading_proof_v04.blend \
  --python-exit-code 1 --python ArtSource/Blender/qa_voss_sprite_proof_v01.py \
  -- --shading-v04
```

## Hair and neck–shoulder silhouette follow-up V05

The user approved refining the hair silhouette and neck–shoulder transition
after the V04 shading review. `ArtSource/Blender/build_voss_silhouette_proof_v05.py`
flattens and slightly broadens the crown, cuts back the temples and adds a
small off-centre forelock. It flares the neck base, lifts the inner coat yoke,
reduces the sleeve-top bulges and brings the collar sides closer to the neck.
The sleeve tops blend towards spine weighting so the seam stays attached
during the existing walk. The raised rear collar height is retained.

This is an isolated geometry proof, not a claim to reconstruct the BG model.
It retains V04's vertex colours, material assignments, palette and lighting;
changed surface normals naturally change the rendered shading. The face and
V03 nose are untouched, as are the hands, shoes, limb lengths and lower coat.
The builder checks the scope by connected mesh component: 629 vertices or
weights change, 5,087 remain exact, and all 5,000 faces remain unchanged.
Skeleton and actions are unchanged.

Outputs are in `ArtSource/Generated/Characters/Detective/SilhouetteArtProofV05`.
`silhouette_comparison.png` shows identical-coordinate V04/V05 upper-body
crops and equally magnified native sprites. All twelve categorical-mask and
indexed-encoding checks pass, together with the frozen 89×107 canvas,
64-row SW standing anchor and pure-N trim gate. Native lower-body material
pixels remain identical in every proof frame. All eight walk phases pass
the grounded-support-foot check. All 250 installed Voss hashes are unchanged.

The V04 output-directory hook was checked by rebuilding, rendering, finalising
and reviewing V04 again: all 43 finalised, indexed and review PNGs remained
byte-identical. Raw Blender pass PNG metadata is excluded from that claim.

This does not install a new avatar or approve unrendered facings, seating or
in-scene grading. The existing NW collar limitation remains outside approval.

Reproduce after the V04 proof is available:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background \
  --python-exit-code 1 --python ArtSource/Blender/build_voss_silhouette_proof_v05.py
/Applications/Blender.app/Contents/MacOS/Blender --background \
  ArtSource/Generated/Characters/Detective/SilhouetteArtProofV05/voss_silhouette_proof_v05.blend \
  --python-exit-code 1 --python ArtSource/Processing/render_voss_sprite_proof_v01.py \
  -- --silhouette-v05
python3 -B ArtSource/Processing/render_voss_sprite_proof_v01.py --finalise --silhouette-v05
python3 -B ArtSource/Processing/review_voss_silhouette_proof_v05.py
/Applications/Blender.app/Contents/MacOS/Blender --background \
  ArtSource/Generated/Characters/Detective/SilhouetteArtProofV05/voss_silhouette_proof_v05.blend \
  --python-exit-code 1 --python ArtSource/Blender/qa_voss_sprite_proof_v01.py \
  -- --silhouette-v05
```

## Brow, sockets and cheek planes V06

The user requested the remaining smooth-face issue be addressed, followed by
a final review against the BG reference. V06 is isolated in
`ArtSource/Generated/Characters/Detective/FaceArtProofV06`, authored by
`ArtSource/Blender/build_voss_face_proof_v06.py`.

The builder inserts an orbital ring in the existing facial shell, recesses
the surface beneath each brow, brings the cheekbone planes forward slightly
and tapers the transition towards the jaw. The original eyes and brows follow
that surface, with the brows on the upper rim. Their strips are subdivided
only enough to conform: a four-corner panel can intersect a curved face between
its endpoints. Placement samples Blender's actual tessellated surface, not
bilinear loft interpolation. No eye whites, eyeballs or texture noise are added.

87 existing vertex positions change; 24 orbital vertices and 80 surface-strip
vertices are added. Total geometry is 5,820 vertices and 5,104 faces. Existing
vertex colours and weights remain exact. New vertices interpolate the existing
grade or use the existing eye/brow colours. Nose, mouth, hair cap, shoulders,
neck, clothing, hands and shoes retain their exact V05 coordinates and topology.
Materials, camera, lights, rig and actions remain unchanged. Rendering naturally
responds to the changed surface normals; unchanged authored shading does not
mean identical resulting face pixels.

### Verification and artifacts

- All twelve frames pass mask completeness, indexed encoding, palette round
  trips, frozen 89×107 native canvas, 64-row SW body and pure-N trim checks.
- The SW idle changes 11 native indices; S changes 16. The eight SW walk phases
  change 9–14 each. Pure N and NW native frames remain identical to V05.
- Non-head body pixels remain exact in every proof frame. All eight walk
  phases retain grounded support soles and neither shoe below the floor.
- All 250 installed Voss hashes remain unchanged. Full facings, seats,
  in-scene grading and the existing rear-quarter collar issue are not approved.
- Rebuilding V05 through its new output-directory parameter preserved all
  41 finalised, indexed and review PNGs byte-for-byte; raw Blender PNG metadata
  is outside this claim.
- `head_comparison.png` compares V05/V06 at identical source coordinates;
  `native_head_pixels.png` exposes the actual reduction. `bg_final_comparison.png`
  compares BG / initial V01 / final V06 at equal displayed body height.
- `face_geometry_checks.json`, `face_audit.json`, `proof_manifest.json` and
  `rig_checks.json` contain the scope assertions and measurements.

### Final reference review

The comparison uses actual locally decoded `CEFC4G12`, cycle 20, phase 0,
frame 193: not generated BG-like art. It matches SW facing and displayed body
height, but costume and limb stance differ. The BG frame is recoloured with
the proof's palette to isolate shading; this is not a claim about its original
character customisation or source texture maps.

The cumulative improvement is a more structured face and jaw, a restrained
nose, a crown-to-side hair gradient and less disconnected coat shoulders.
The head now reads through broad planes rather than additional tiny features.
The BG comparison still has a broader apparent head relative to body height:
skin/hair in the top 20% spans 8 native pixels over 52 body rows, versus
7 over 64 for V06. These are image-space measurements, not recovered 3D
dimensions; pose, projection and sampling affect them.

V06's SW hair uses seven shades (3,4,5,6,8,9,11), versus BG's nine (2–10);
both have brighter crowns and darker lower masses. BG's skin range is 4–10,
V06's 5–11 in this frame. The reference still has more abrupt local highlights
and shadow changes. Voss's coat and sleeves read broader and more uniformly
shaded than the reference's armour. Costume and pose prevent attributing all
of that difference to anatomy. Further tiny facial detail is not the priority;
head-to-body presentation and broad clothing shading would matter more.

### Reproduce

V05 must already be rendered/reviewed; it supplies the frozen baseline.

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background \
  --python-exit-code 1 --python ArtSource/Blender/build_voss_face_proof_v06.py
/Applications/Blender.app/Contents/MacOS/Blender --background \
  ArtSource/Generated/Characters/Detective/FaceArtProofV06/voss_face_proof_v06.blend \
  --python-exit-code 1 --python ArtSource/Processing/render_voss_sprite_proof_v01.py \
  -- --face-v06
python3 -B ArtSource/Processing/render_voss_sprite_proof_v01.py --finalise --face-v06
python3 -B ArtSource/Processing/review_voss_face_proof_v06.py
/Applications/Blender.app/Contents/MacOS/Blender --background \
  ArtSource/Generated/Characters/Detective/FaceArtProofV06/voss_face_proof_v06.blend \
  --python-exit-code 1 --python ArtSource/Blender/qa_voss_sprite_proof_v01.py \
  -- --face-v06
```

## Paperdoll-informed skull and hair mass V07

The user supplied `CHMC4INV00000.PNG` and `CHMC4INV00001.PNG` after identifying
a remaining head-shape mismatch. Both files are exact native indexed frames
from the local BG:EE `CHMC4INV` resource (upper and lower inventory halves,
cycle phases 0 and 2). Their SHA-256 values and the pixel-identity checks are
recorded in `HeadMassArtProofV07/headmass_audit.json`.

The inventory camera cannot reveal hidden 3D depth, so V07 does not pretend to
recover the original BG mesh. It uses the front paperdoll as a silhouette guide:
a flatter crown plane, straighter temple walls, closer hair volume and a jaw
which retains more of the cheek width. The local `CHMC4G12`, cycle 20, phase 0,
frame 193 supplies the matching southwest in-game check. This corrects the
earlier comparison against another avatar family; its 29% width difference is
not used as a target.

`ArtSource/Blender/build_voss_headmass_proof_v07.py` changes 1,025 existing
vertex positions and leaves 4,795 exact. Topology, material assignments,
weights and vertex colours remain unchanged at 5,820 vertices / 5,104 faces.
All 128 V03 nose vertices are exact. V06 facial Y/Z relief below the hairline
is exact, preserving the orbital depth; widening changes X only there. Body,
neck, shoulders and mouth remain exact. The hair keeps V04's attached authored
gradient while its geometry is reshaped.

The matching SW reference and V07 both occupy eight native head-material pixels
in the measured top-20%-of-body window; V06 occupied seven. This is a useful
image-space check, not proof that the hidden meshes are identical. The BG body
is 61 rows in this frame and Voss remains on its frozen 64-row contract.

All twelve proof frames pass categorical masks, indexed encoding, shadow,
frozen 89×107 canvas, 64-row SW scale and trim checks. V07 changes 36–52 native
indices per proof frame while every non-head body pixel remains exact. All
eight walking phases retain grounded support soles and neither foot passes
below the floor. All 250 installed Voss hashes remain unchanged. Full-facing,
seat-chain, in-scene grade and runtime-install approval remain outside scope.

The V06 output-directory hook required for the derived proof was verified by
rebuilding, rendering, finalising and reviewing V06 again: all 44 finalised,
indexed and review PNGs remained byte-identical. Raw Blender pass PNG metadata
is excluded from that identity claim.

Key outputs are isolated in
`ArtSource/Generated/Characters/Detective/HeadMassArtProofV07`:

- `head_comparison.png`: V06/V07 at identical source coordinates and native scale.
- `paperdoll_head_study.png`: the supplied paperdoll beside matching front Voss crops.
- `bg_headmass_comparison.png`: matching CHMC4 world frame / V06 / V07 at
  equal displayed body height and palette.
- `direction_checks.png`, `walk_contact_sheet.png`, `headmass_geometry_checks.json`,
  `headmass_audit.json`, `proof_manifest.json` and `rig_checks.json`: remaining QA.

Reproduce after V06 is available:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background \
  --python-exit-code 1 --python ArtSource/Blender/build_voss_headmass_proof_v07.py
/Applications/Blender.app/Contents/MacOS/Blender --background \
  ArtSource/Generated/Characters/Detective/HeadMassArtProofV07/voss_headmass_proof_v07.blend \
  --python-exit-code 1 --python ArtSource/Processing/render_voss_sprite_proof_v01.py \
  -- --headmass-v07
python3 -B ArtSource/Processing/render_voss_sprite_proof_v01.py --finalise --headmass-v07
python3 -B ArtSource/Processing/review_voss_headmass_proof_v07.py
/Applications/Blender.app/Contents/MacOS/Blender --background \
  ArtSource/Generated/Characters/Detective/HeadMassArtProofV07/voss_headmass_proof_v07.blend \
  --python-exit-code 1 --python ArtSource/Blender/qa_voss_sprite_proof_v01.py \
  -- --headmass-v07
```

## Paperdoll-informed hair and nose V08

V08 keeps the accepted V07 skull and applies the remaining front-view cues from
the supplied `CHMC4INV` paperdoll. Its hair is no longer a nearly symmetric cap:
one forehead side opens slightly, the opposite fringe sweeps lower, the crown
mass shifts towards that side and a restrained side/back lock reaches the jaw
behind the ear. The new lock uses the existing hair material, V04 gradient and
head bone; it is geometry rather than painted silhouette.

The paperdoll nose reads as a wider continuous bridge and rounder alar/tip plane.
V08 widens 120 of the 128 V03 nose vertices in X only. Their Y and Z coordinates,
and therefore the established length, vertical placement and forward projection,
remain exact. This limit is deliberate: the front inventory view has no authority
for hidden depth. The matching local `CHMC4G12` southwest frame remains the
isometric check.

`ArtSource/Blender/build_voss_hairnose_proof_v08.py` changes 189 existing hair
vertices and 120 nose vertices. It adds a 60-vertex / 50-face hair lock, bringing
the proof to 5,880 vertices and 5,154 faces. V07 skull shell, eyes, brows, sockets,
cheeks, jaw, mouth, ears, neck, shoulders and body remain exact. All existing
colours, weights, topology and material assignments remain exact; camera, lights,
rig, actions, palette and source-to-native scale are unchanged.

All twelve proof frames pass categorical masks, indexed encoding, palette round
trip, shadow, frozen 89×107 canvas, 64-row SW scale and trim checks. The native
change is deliberately small: 17–29 indices per frame, all inside the head; every
non-head body pixel is exact. All eight walk phases retain grounded support soles
with neither shoe below the floor. All 250 installed Voss hashes remain unchanged.

The V07 output-directory hook needed by this derived proof was regression-tested
by rebuilding, rendering, finalising and reviewing V07 again. All 46 non-raw-pass
PNG hashes were byte-identical. Full facings, seat-chain, in-scene grade and a
runtime install remain outside this proof.

Key outputs are isolated in
`ArtSource/Generated/Characters/Detective/HairNoseArtProofV08`:

- `paperdoll_hairnose_study.png`: exact supplied paperdoll head beside identical
  V07/V08 front source crops.
- `bg_hairnose_comparison.png`: matching CHMC4 world frame / V07 / V08 at equal
  displayed body height and shared palette.
- `head_comparison.png`: identical-camera V07/V08 source and native comparison.
- `direction_checks.png`, `walk_contact_sheet.png`, `hairnose_geometry_checks.json`,
  `hairnose_audit.json`, `proof_manifest.json` and `rig_checks.json`: remaining QA.

Reproduce after V07 is available:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background \
  --python-exit-code 1 --python ArtSource/Blender/build_voss_hairnose_proof_v08.py
/Applications/Blender.app/Contents/MacOS/Blender --background \
  ArtSource/Generated/Characters/Detective/HairNoseArtProofV08/voss_hairnose_proof_v08.blend \
  --python-exit-code 1 --python ArtSource/Processing/render_voss_sprite_proof_v01.py \
  -- --hairnose-v08
python3 -B ArtSource/Processing/render_voss_sprite_proof_v01.py --finalise --hairnose-v08
python3 -B ArtSource/Processing/review_voss_hairnose_proof_v08.py
/Applications/Blender.app/Contents/MacOS/Blender --background \
  ArtSource/Generated/Characters/Detective/HairNoseArtProofV08/voss_hairnose_proof_v08.blend \
  --python-exit-code 1 --python ArtSource/Blender/qa_voss_sprite_proof_v01.py \
  -- --hairnose-v08
```

# Armor concept revision — October 1

Current October 1 V8 source/install authority: [sword materials and walking grip](SwordMaterialsV8Oct01.md). V8 synchronizes armor/body walking frames to the corrected carrying hand while retaining V7 armor geometry/materials and the existing armor paperdoll/icon.

## Generated materials and reflectivity — V7

`ArtSource/Blender/SplintMailMaterialsV7Oct01` is a material-only revision of V6.
The built-in Image Generator produced two flat texture masters: fine forged
steel and worn umber leather. Originals and exact prompts are retained under
`Textures/`; both images are packed into the paperdoll and animation sources.
`materials_via_live_mcp.txt` reproduces the shader changes against V6's saved
paperdoll without changing mesh geometry, UVs, skin weights, rig or actions.

Steel plates use fully metallic reflectance with texture-driven roughness of
0.34–0.48; rolled edges use 0.23–0.32 for more polished highlights. Chain links
and fasteners retain distinct, darker metallic materials. Fine texture relief
is shallow, and 12 mm local occlusion adds restrained darkness at actual seams.
No directional highlights or shadows are painted into the generated masters.
Leather uses no metal or clearcoat, varied matte roughness and fine surface
grain. The lower skirt now has a connected color texture and warm brown leather
finish instead of its previous flat color. Shader remapping uses the images'
linear-light ranges so their detail does not clip into a constant value.

The armor remains 180,790 vertices / 362,152 edges / 181,780 faces / 360,744
triangles. `model_preservation.json` verifies identical armor geometry, UVs and
weights against V6, identical protected body/equipment and all actions, and
closed consistent armor topology. V6's longer coverage and pose clearance are
retained. Scene lighting and camera registration are unchanged.

Use `package_splint_mail_materials_v7_oct01.py` for this revision. Sources,
material/render/verification recipes and source views are in the V7 folder;
review and rollback outputs are under `output/splint-mail-materials-v7-oct01`.
`Before_Materials_Revision.blend` preserves the initial live scene.

V7 is installed in the paperdoll, icon and all 1,200 idle/walk frames. All 118
selected Swift tests and 33 live desktop equipment checks pass. macOS and iOS
Simulator Debug builds succeed, and both built apps match the installed bundles
and checked UI images. Protected runtime art remains byte-identical. No iOS
device execution was performed. The armor index SHA-256 is `4d335e666a591179b1c37027257ab9c42968297124c4494a686c0eb97a67d9e5`.
`materials-before-after.png` compares the registered full-body portraits.

## Shoulder construction and fittings — V6 (superseded)

`ArtSource/Blender/SplintMailDetailsV6Oct01` retains V5's longer thigh coverage
and improves the three largest remaining construction differences: deeper,
downward-sloping shoulder caps, four bordered flank panels under the diagonal
straps, and larger rivets, collar links, strap rings and rear belt loops.
The shoulder crown retains tunic clearance. Upper straps and their rings sit
0.035 model units lower to clear the deeper caps during the arm swing.

The mesh has 180,790 vertices, 362,152 edges and 181,780 faces (360,744 triangles).
The 22-pose audit passes with zero detected cloth penetrations. Shoulder faces
are explicitly recorded and checked against sleeves; side panels retain expected
sleeve occlusion. Topology has zero boundary, non-manifold or inconsistent-winding
edges. Body geometry, UVs, weights, bones, actions, sword and helmet compare equal
to the current surface-repaired source.

The two saved `Voss_SplintMail_*.blend` files and live MCP recipes reside in the
V6 folder. `Before_Details_Revision.blend` preserves the initial live scene.
Rebuild with the saved paperdoll pose active. Use
`package_splint_mail_details_v6_oct01.py` for staging and installation; review
and rollback resources are under `output/splint-mail-details-v6-oct01`.

V6 is installed in the paperdoll, inventory icon and all 1,200 idle/walk frames.
All 118 selected Swift tests and 33 live desktop equipment checks pass; macOS
and iOS Simulator Debug builds succeed. Built bundle and UI pixel checks match
the installed resources. Protected runtime art remains byte-identical. No iOS
device execution was performed. The armor index SHA-256 is `7e497a57f83c2ccecd76a2905c6c53390eb597a771b97d32179253ac1052a5b3`.
`details-before-after.png` compares the registered full-body portraits.

## Longer thigh coverage — V5 (superseded)

`ArtSource/Blender/SplintMailLengthV5Oct01` follows the user's BG:EE paperdoll
length reference (`bgee_paperdoll_length.png` in the reference folder). The
under-skirt is extended by 0.14 model units, from a rest-space front hem of
0.78 to 0.64, compared with Voss's knee joint at 0.49 and body height of 1.75.
The steel guards extend by 0.085–0.099 units, preserving their angled hems.
The belt and upper armor retain V4's design and position.

The longer lower panels blend into the existing thigh bones below 0.85, with
additional side/rear clearance to prevent the tunic or trousers cutting through
them during idle and walking. Front and rear splits remain. The expanded
22-pose clearance audit now includes trousers as well as the tunic; all poses
pass. The mesh counts and closed topology are unchanged from V4. Body geometry,
UVs, rig, actions, hands, sword and helmet are preserved.

Saved sources, live MCP recipes and verification reports are in the V5 folder;
`Before_Length_Revision.blend` preserves V4. Use
`package_splint_mail_length_v5_oct01.py` for staging and installation. Review
and rollback resources are under `output/splint-mail-length-v5-oct01`.

V5 is installed in the paperdoll, inventory icon and 1,200 idle/walk frames.
The icon camera was reframed to retain the complete extended hem. All 118
selected Swift tests, 33 live desktop equipment checks and both macOS/iOS
Simulator Debug builds passed. Built bundles and checked UI images match the
installed resources. Protected runtime art remains byte-identical. The armor
index hash is `0bb22e3d550201b691018a717b788810211d8e777584eb594df95ca999bd9f9c`.
`length-before-after.png` compares the registered full-body portraits.

## Enhanced front/back reference — V4 (superseded)

`ArtSource/Blender/SplintMailFrontBackV4Oct01` uses both supplied enhanced
drawings, preserved as `enhanced_front.png` and `enhanced_back.png` in
`ArtSource/References/IEComposition/SplintMail`. It adds the shaped central
backplate and lower rear plate, widens and chamfers the breastplate, lowers the
inner corners of the shoulder caps, and adds collar links, circular strap
fittings, an angular front buckle and distinct rear belt loops.

Two continuous hip guards now flare outward with sloping lower edges. A longer
split, bound leather skirt lies beneath them. Leather is a material interpretation
of the monochrome reference. The existing tunic can still show below the armor.
The enhanced views show front and rear guards but do not establish whether a
side seam divides them; continuous halves remain the authored interpretation.

Upper mail reaches the collar underside and shoulder caps at both front and
back, closing the exposed tunic wedge reported during review. Strap rings are
seated on the revised front/rear strap paths, and the hip trim no longer pokes
through the belt. Shoulder weights blend 70% chest / 30% upper arm to avoid
the previous full arm rotation cutting the cap through the upper mail. The
skirt and guards use the existing tunic bones with smooth pelvis transitions.
No rig, body, head, hand, UV, action, sword or helmet changes are included.

The armor mesh has 173,486 vertices, 347,464 edges and 174,356 faces (346,216
triangles). `model_preservation.json` verifies unchanged protected geometry,
UVs, weights, bones and actions, and zero armor boundary, non-manifold or
inconsistent-winding edges. The 22-pose clearance audit covers both outward
steel and the new skirt; expected sleeve occlusion is classified separately.
Front/back and both side views, plus extreme walking poses, were reviewed.

The two `Voss_SplintMail_*.blend` sources and live MCP reproduction recipes
reside in the V4 directory; `Before_Front_Back_Revision.blend` preserves V3.
Rebuild with the saved paperdoll pose active so the shoulder recipe can remove
its blended pose transform. Use `package_splint_mail_front_back_v4_oct01.py`
for staging and installation. Review outputs and rollback copies are under
`output/splint-mail-front-back-v4-oct01`.

V4 is installed: all 118 selected Swift tests and 33 live desktop equipment
checks passed, and macOS/iOS Simulator Debug builds succeeded. Both built
apps match the installed bundles and seven checked UI images. Protected body,
sword, helmet and other inventory assets remain byte-identical. The armor
index hash is `934441e1e1543efdba8eecc91941a2da6052300298a6a3cedeec3c510b44e8a2`.
`front-back-review.png` and `both-sides-review.png` show the final construction.

## Collar and hip-guard fit — V3 (superseded)

`ArtSource/Blender/SplintMailFitV3Oct01` supersedes V2. The concept shows two
prominent hip guards; its lower outlines can be read as an underlying garment.
There is no rear view, so their rear construction is an adaptation, not a
confirmed detail of the drawing. V3 uses exactly two continuous half-shells,
one per hip, wrapping from front to back with front and rear splits. Separate
rear panels and the extra lower steel tier are removed. The collar's outer
shoulder edge is raised and widened locally to clear the tunic; the V2 edge
intersected it by up to 26 mm. Character proportions are unchanged.

The mesh has 135,410 vertices, 271,124 edges and 135,916 faces (270,416
triangles), with zero boundary, non-manifold or inconsistent-winding edges.
`model_preservation.json` confirms unchanged body geometry, UVs, weights,
rest bones, actions, sword and helmet against the repaired canonical source.
`tunic_clearance_audit.json` checks outward steel faces in the paperdoll and
all 21 distinct idle/walk poses. It separates expected sleeve occlusion from
torso intersections and uses three-direction ray parity to reject misleading
nearest-normal signs around folded cloth. No torso penetrations were found;
the extreme-stride hip close-ups were also reviewed.

Use `package_splint_mail_fit_v3_oct01.py` to stage/install. The two saved
`Voss_SplintMail_*.blend` files and live MCP recipes reside in the V3 folder;
`Before_Fit_Repair.blend` preserves the preceding model. Rebuild geometry only
with the saved paperdoll pose active, because the shoulder recipe removes that
pose's arm transform before skinning. Review and rollback outputs are under
`output/splint-mail-fit-v3-oct01`.

V3 is installed in the armor index bundle, paperdoll overlay and item icon.
All 118 selected Swift tests, 33 live desktop equipment checks, and macOS/iOS
Simulator Debug builds passed. Both built apps match the installed bundles
and seven checked UI images (decoded pixels for iOS PNGs). Other runtime art
remains byte-identical. The armor index hash is
`b9a89fb474606f7deff2d1fe017be5f7c36ee6169ab87d6cca3ec738891e9e62`.
`hip-guards-before-after.png` records the rear comparison; the visible rear
sections are the ends of the two continuous guards, not additional plates.

## V2 refinement (superseded)

The second pass in `ArtSource/Blender/SplintMailConceptV2Oct01` supersedes the
first interpretation below. It narrows and lengthens the central breastplate,
adds its paired fluting and fasteners, gives the shoulders broad angled front
faces with a flatter crown, tightens the armor waist, and replaces the single
hip plates with longer underplates and shorter overlapping guards. The edge
bands, round steel studs and collar clasps follow the selected top-right sketch
more closely. The result adapts that drawing to Voss's unchanged proportions
and rig; it is not a pixel-exact reproduction of the drawing.

Use `package_splint_mail_concept_v2_oct01.py` for this version. The two
`Voss_SplintMail_*.blend` files, live MCP recipes and preservation report are in
the V2 source folder. `Before_Refinement.blend` preserves the preceding model.
The V2 mesh has 139,330 vertices, 278,964 edges and 139,864 faces (278,200
triangles); its boundaries, non-manifold edges and inconsistent winding counts
are zero. Body geometry, UVs, weights, rig, actions, sword and helmet compare
equal to the repaired canonical source. V2 validation and rollback resources
are recorded under `output/splint-mail-concept-v2-oct01`.
The refined install passed all 118 selected Swift tests, 33 live desktop
equipment checks, and macOS/iOS Simulator Debug builds. Both built applications
match the installed assets; protected body, sword, helmet and other inventory
resources remain byte-identical. The V2 armor index hash is
`51f619ef007aa8952bb24635b39b2b38cde3131f3c1c1d528c0a5f22b32dcc2b`.
`before-after.png` compares the paperdoll revisions. The isolated icon uses a
higher viewing angle to expose the shoulder caps and neckline as in the sketch;
the registered paperdoll and world cameras are unchanged.

## First concept pass (superseded)

The equipped armor now follows the user's selected **top-right ICHAN08 generic
chainmail** drawing from the supplied BG2 concept sheet. This supersedes the
earlier CHAN04-inspired vertical-splint draft in the same work session. The
existing `splint-mail` item ID, statistics, save data and equip behaviour are
unchanged; this is an appearance replacement.

The design has rounded shoulder caps, a shield-shaped breastplate, two smaller
abdominal plates, visible iron links over leather, diagonal retaining straps,
a narrow collar, and four curved hip guards. The collar overlaps the chest
plate. The divided lower guards retain walking clearance. All geometry is
original; reference images are confined to `ArtSource/References` and are not
part of the game resources.

## Sources and reproduction

`ArtSource/Blender/SplintMailBGEEOct01/Voss_SplintMail_Paperdoll.blend` and
`Voss_SplintMail_Animations.blend` are the self-contained final sources.
`build_armor_via_live_mcp.txt` plus `concept_geometry.txt` reproduce the armor
through the live Blender MCP connection with the paperdoll pose active.
`Before_Armor_Revision.blend` preserves the scene, including its unsaved state,
before this task. `Before_Concept_Revision.blend` records the earlier draft.

`render_ui_via_live_mcp.txt` renders the registered paperdoll layer and isolated
item icon. `transfer_via_live_mcp.txt` copies only the armor into the current
surface-repaired animation source. `render_via_live_mcp.txt` renders 336 idle
and walk source views using the current Voss body as a holdout. The packager
expands the held idle poses into **1,200 registered frames** on the existing
128×128 canvas. Equipment remains hidden for the seated/chair sequences.

Run `package_splint_mail_bgee_oct01.py stage`, review the actual indexed
`equipped_idle_all_directions.png`, `equipped_walk_all_directions.png` and
`paperdoll_equipped_review.png`, then write the hash-bound `review_receipt.json`
and run `install`. Installation replaces only the armor bundle, its paperdoll
overlay and its inventory icon, with rollback copies in
`output/splint-mail-bgee-oct01/originals`.

The mesh contains 158,714 vertices and 158,838 faces (317,124 triangles), mostly
the individually modeled chain links. It is rendered offline; runtime remains
the same sprite-layer path. `model_preservation.json` verifies closed,
consistently wound armor and unchanged body geometry, UVs, skin weights, bones,
actions, helmet and sword. The October 1 finger and surface repairs remain in
both sources, and the installed VossCHMF body hash remains
`237cf80bb0ef6de755c635c369a30e50997c42829a72f71cce58c8d81f31b47e`.

Do not reinstall older equipment bundles over this revision when restoring
the body. `package_voss_surface_repair_oct01.py` still records the preceding
body-and-equipment release; this armor packager owns the newer mail appearance.

Final validation results are recorded in `output/splint-mail-bgee-oct01`.
All 118 selected Swift tests in 11 suites passed, both macOS Debug and iOS
Simulator Debug builds succeeded, and all 33 live desktop equipment checks
passed. The actual inventory and walking captures were reviewed. Both built
applications match the installed body/equipment bundles and seven checked UI
images (decoded pixels for iOS PNGs). No iOS device execution was performed.
The final armor index hash is
`af490f551da20b6add60fa6291e06044eefaaa52303d7bc822c0a32a95815288`.

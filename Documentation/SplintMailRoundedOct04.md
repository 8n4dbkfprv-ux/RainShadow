# Splint-mail silhouette refinement — October 4

The later cupped-shoulder and attachment revision is recorded in
`Documentation/SplintMailCuppedOct04.md`; its Blender masters supersede these
sources for the current armor authoring work.

The user requested a less boxy armor silhouette against the supplied front and
three-quarter drawings, then requested a further pass on both shoulders and torso.
This revision starts from `WingedHelmetReferenceFitOct04` and changes only
`Lantern_Splint_Mail` through the live Blender MCP connection.

## Shape

The shoulder caps now have a continuous curved crown, narrower depth toward the
upper arms, and a raised outer lower edge. Their front cheeks taper into an
angled outline instead of extending a rectangular shelf around the sleeve.
The rear retains additional clearance for the asymmetric posed sleeves. Inner
attachments blend into the original shoulder/neck fit.

The upper breastplate and its mail, trim, fasteners and connecting pieces move
inward together, reaching a maximum 48 mm reduction in front projection. The
central back and lower back/waist move inward by up to 30 mm. Smooth spatial
falloffs preserve the existing rear collar fit and side seams. The chest retains
its transverse curvature; this is not a uniform object scale.

38,136 vertices move. The original 180,790 vertices, 362,152 edges, 181,780 faces
and 360,744 triangles are retained. UVs, skin weights, materials and rig topology
are not rebuilt. Body, head, helmet, sword and animation actions are outside the
edit. Detailed recipes and measurements are under
`ArtSource/Blender/SplintMailRoundedOct04/`.

## Source files and reproduction

- `Voss_SplintMail_Paperdoll.blend`: revised detailed paperdoll master.
- `Voss_SplintMail_Animations.blend`: matching armor mesh on the existing animation source.
- `Before_Armor_Revision.blend`: untouched source backup.
- `Before_Second_Pass.blend`: retained first-round shoulder revision.

Open `Before_Armor_Revision.blend` in the live Blender instance, then execute
`round_shoulders_second_pass_via_live_mcp.txt` followed by
`fit_torso_via_live_mcp.txt`. Save to the revised paperdoll path, then execute
`transfer_via_live_mcp.txt`. The earlier `round_shoulders_via_live_mcp.txt` records
the first pass and is not the final shoulder recipe.

Run `check_paperdoll_via_live_mcp.txt` on the paperdoll and
`check_final_fit_via_live_mcp.txt` on the animation source. Wait for the timer to
complete before changing files. `verify_via_live_mcp.txt` compares protected
geometry, UVs, weights, transforms, rig and actions with the original sources.
`render_review_via_live_mcp.txt` renders matching before/after views; its temporary
camera/render state must not be saved over a master.

The paperdoll has zero shoulder/body intersections and zero armor/helmet
intersections. Its existing armor/body intersections elsewhere are unchanged:
6,105 polygon pairs, with zero added or removed pairs. These are source fitting
measurements, not a claim that the entire pre-existing outfit is intersection-free.
All 21 distinct idle/walk poses also have zero added or removed body intersection
pairs and zero armor/helmet intersections. Animation measurements are recorded
per pose in `animation_fit.json`. All 30 preservation checks pass across the two
source files, including the nine original actions.

These are Blender source revisions. Sprite bundles have not been re-rendered or
installed, and the game's VossCHMF runtime remains unchanged.

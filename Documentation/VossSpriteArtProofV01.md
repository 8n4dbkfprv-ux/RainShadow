# Voss sprite-art proof V01

2026-08-31. **Staged visual candidate, not approved or installed.**

The user requested the focused art proof proposed after comparing Voss with
BG:EE: one three-quarter standing pose and a short walk, judged at final sprite
size. This is not a full character replacement. The V22 runtime, V23 authorities,
active gradient rows, renderer ports, camera and world-scale contracts are
unchanged. Existing unrelated worktree changes were preserved.

Follow-up: the user liked this body direction and requested a less round head.
The isolated revision is recorded in [VossHeadArtProofV02.md](VossHeadArtProofV02.md).
V01 remains the unchanged comparison baseline.

## Review artifacts

All outputs are under
`ArtSource/Generated/Characters/Detective/SpriteArtProofV01/`:

- `comparison.png`: V22 source, V23, the new proof and a BG reference at equal
  body heights. All four use the same direct bilinear display sampling, so this
  isolates source art rather than reproducing the shipped Super xBR path.
- `walk.gif`: eight SW walking phases at one fixed scale and ground origin.
- `walk_contact_sheet.png`: every walk phase, not a representative sample.
- `direction_checks.png`: S, SW, NW and N stills.
- `filter_comparison.png`: nearest, direct bilinear and Super xBR from the same
  native indexed art. No runtime filter was changed.
- `Native/`: proof-only indexed PNGs, not runtime atlas assets.
- `proof_manifest.json`, `rig_checks.json`: actual checks and scope limits.

The BG reference is the user's local `~/BG/CEFC4A500000.PNG`. It is recoloured
through the proof's palette and explicitly labelled as such. Its different
costume, body and pose make it a craft reference, not an anatomical or camera
measurement. It is never copied into game resources.

## Source and decisions

`ArtSource/Blender/build_voss_sprite_proof_v01.py` is the model authority for
this experiment. Its `.blend` is generated, not the editable source. It reuses
V23's 18-bone skeleton and the existing camera/pass infrastructure, but authors
a separate mesh and two actions:

- rounded, tapered limbs with blended joint weights;
- a continuous fitted coat shell, shaped lapels, waistcoat, shirt collar and
  material-separated red tie;
- tapered hands, thumb silhouettes and shaped shoes;
- a shaped face and hair cap;
- roughness/specular differences and broad cloth ridges;
- an asymmetric idle and analytically solved walk legs, with support soles on
  the ground and a shaped cast shadow from the evaluated mesh.

The model has 7,668 vertices and 6,831 faces. This is an offline rendering cost,
not a runtime polygon budget. Neither that count nor the shader model is claimed
to reconstruct BioWare's original authoring setup.

The original seven material IDs remain categorical. CIE94 fitting uses the
existing fitter and all twelve proof masters. The resulting proof-only rows
are `[248, 226, 243, 162, 138, 23, 23]`; they do not modify `ie_avatar.VOSS`.

The SW standing anchor resolves to 64 body rows on a fixed 89×107 native canvas.
That same source-to-native scale is used for the entire proof; individual poses
are not stretched to erase gait or perspective changes. The comparison sheet
normalises stills to equal visible heights solely for visual inspection.

## Checks and limitations

The review script validates the exact 12-frame proof inventory, P-mode masks,
palette entries, categorical labels, complete silhouettes, allowed native
indices, saved native-index round trips, cast-shadow presence, unclipped
masters and the pure-N trim threshold of 0.1%. It hashes 250 installed Voss
files before and after to verify that the review has not changed them.

The Blender QA checks all eight walk phases: the support sole stays on z=0
within 0.00001 metres and neither shoe goes below the floor. This is an in-place
gait proof, not a test of stride speed against runtime movement.

**Still open:** the NW/rear-quarter collar reveals some trim (about 0.44% of the
master body). That is recorded, not waived as a full-facing acceptance pass.
The rear collar and coat silhouette need visual approval/cleanup before any
full-facing installation. The pure-N check is not a substitute for the full
rear-hemisphere gates. Seat transitions, all nine authored facings, animation
timing in the game, and the night scene grade remain outside this proof.

## Reproduce

From the repository root on macOS:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background \
  --python-exit-code 1 --python ArtSource/Blender/build_voss_sprite_proof_v01.py
/Applications/Blender.app/Contents/MacOS/Blender --background \
  ArtSource/Generated/Characters/Detective/SpriteArtProofV01/voss_sprite_proof_v01.blend \
  --python-exit-code 1 --python ArtSource/Processing/render_voss_sprite_proof_v01.py
python3 -B ArtSource/Processing/render_voss_sprite_proof_v01.py --finalise
python3 -B ArtSource/Processing/review_voss_sprite_proof_v01.py
/Applications/Blender.app/Contents/MacOS/Blender --background \
  ArtSource/Generated/Characters/Detective/SpriteArtProofV01/voss_sprite_proof_v01.blend \
  --python-exit-code 1 --python ArtSource/Blender/qa_voss_sprite_proof_v01.py
```

These commands write only the isolated proof directory. There is deliberately
no install command or active-authority switch in this experiment.

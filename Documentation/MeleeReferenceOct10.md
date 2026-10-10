# Normal melee reference pass — October 10

The normal human sword cut now has a tighter preparation, a planted lead step,
more weight over the bent lead leg at contact, and a visible withdrawal back to
the original resting pose. Body, shortsword, splint mail and helmet were rendered
together as registered layers in all 16 facings. The separate Power Strike,
Feinting Cut, Trip Attack and Sneak Attack animations retain their existing art.

## Reference and interpretation

Visually inspected Bryan Noter's [BG3 weapon animation reel](https://www.youtube.com/watch?v=ZL91_JyB5A4),
including the dual wield movement around 00:36–37.6 and the one-handed piercing
sequence around 00:40.6–42.0. Noter is also featured in [Larian's official art showcase](https://magazine.artstation.com/2023/09/larian-studios-baldurs-gate-3-art-blast/).

The useful observations were the widened stance, leg-driven commitment, torso
following the weapon and readable return to guard. RainShadow keeps its diagonal
shortsword cut; this adapts those principles rather than reproducing the reel's
rapier thrust. These are original poses on our existing rig. No Larian animation
or artwork was extracted. The reel contains held poses and edits, so its duration
was not treated as a measurement of an individual in-game attack.

The existing presentation clock remains 1.1 seconds: 0.4 seconds preparation,
0.2 seconds through the fast cut, and 0.5 seconds recovery. Contact remains phase
6 at approximately 0.533 seconds, with damage, reaction and sword trail driven by
the same `WeaponTechniqueMotion` clock. The trail's normal-cut endpoints were
resampled from the evaluated, bone-parented weapon at every revised pose.

## Authoring and installation

The existing `SwordRefinementOct07/Sword_Authored.blend` was appended into a
separate live Blender scene through MCP. An incremental `Before.blend` was saved.
The changes affect pose transforms only: no rig topology, body proportions,
geometry, materials, UVs, equipment attachment or locomotion was replaced.

The lead foot advances 0.22 model units during preparation, plants through the
cut, then lifts slightly during withdrawal. The rear foot remains planted.
At commitment, the pelvis lowers 0.035 units and the torso adds approximately
9 degrees of forward lean. Connected wrist joints and the existing hilt grip
are preserved; the largest measured wrist gap after baking was below 0.000001
model units. First and final indexed poses match exactly in every facing/layer.

Local source and output (intentionally ignored by repository art policy):

- `ArtSource/Blender/MeleeReferenceOct10/Melee_Pose_Source.py`: original pose recipe,
  executed in the inspected live scene using the existing sword pose solver.
- `Melee_Authored.blend`: baked action `MeleeReferenceOct10_attack`.
- `render_mcp_source.py` and `render_plan.json`: fixed projection and registered
  neutral, material ID, sword, mail and helmet renders.
- `blade_paths.json`, `pose_metrics.json`, `baked_metrics.json`: sampled evidence.
- `FinalRenders/`, `Stage/`, `Review/`, `validation.json`: generated assets and QA.
- `PreviousRuntime/`: original four bundles retained before installation.
- `ArtSource/Processing/package_melee_reference_oct10.py`: stage/review recipe;
  `--install` replaces only those four layers after validation, unlinking first.

Each layer retains 192 frames, the existing palettes, a 160×160 canvas, (80,60)
bottom-left pivot and 175.78125-unit display size. No per-pose fitting is used.
Neutral/material silhouettes have 1.000 intersection-over-union; all body facings
have 11 distinct poses, with the twelfth returning exactly to rest. Runtime
authority is `MeleeAttackAnimationSet`, with the following new payloads:

| Bundle | SHA-256 |
|---|---|
| HumanMelee | `a582910f48c390eee38810b484fe956273bdd6168e0c8bb81eefc012ed9b7232` |
| HumanMeleeSword | `403ec19ec91bd27683e8d4c8a2da5d3db40cfd0c1959273a525964e66bb10f72` |
| HumanMeleeMail | `7a846cd1c6fc7fde1dd500be4d3aa617dd683c82a77334fbea71b4a3f874ce19` |
| HumanMeleeHelmet | `097aee9aad0d574c828ff616db5069d99dee83cb7bdc446384fc01f9a8fed779` |

## Verification

The indexed preview is `ArtSource/Blender/MeleeReferenceOct10/Review/melee_reference_preview.gif`.
It uses the runtime phase clock for both armored and unarmored playback.
Validation completed against the installed payloads:

- 22 focused Swift tests passed across melee, technique timing, trip and reaction
  suites, including the approved VossCHMF and LilaSentinel authority checks.
- 103 live melee checks passed: sword, armor, unarmed, miss, knockout and enemy
  attacks, synchronized contact and return to idle.
- 175 live pacing checks passed across normal, Power Strike, Feinting Cut and
  Trip Attack in both armor configurations: pause, shared pose/contact clock,
  damage/reaction timing, trail visibility and fade, input lock, recovery and save.
- macOS Debug and iOS Simulator Debug builds succeeded. Both app bundles contain
  the four exact payload hashes above. iOS was compiled, not played.

Native captures and reports are in `output/melee-reference-oct10/` and
`output/melee-reference-pacing-oct10/`. The former includes a sword-trail closeup;
the latter includes timed game GIFs and impact captures for each move.

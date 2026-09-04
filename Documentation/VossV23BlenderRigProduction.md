# Harlan Voss V23 — the masters become a 3D rig

## Status

**Masters, pipeline and gates landed. Runtime art not yet replaced.**
V22 remains the shipped runtime; the transactional installer is the remaining
step and is scoped at the end of this document.

| | path |
|---|---|
| Rig (script, not a binary) | `ArtSource/Blender/build_voss_v23.py` → `voss_v23.blend` |
| Shared contract | `ArtSource/Blender/voss_rig_spec.py` |
| Render driver | `ArtSource/Processing/render_voss_v23.py` |
| Masters | `ArtSource/Generated/Characters/Detective/PreRendered3DV23/` |
| Gradient fit | `ArtSource/Processing/fit_voss_v23_gradients.py` |
| Gates | `qa_voss_v23_camera.py`, `qa_ie_shadow.py`, `qa_ie_avatar_encode.py` |

## Why V23 exists

Every version from V11 to V22 fought the same defect, and V21's production log
names it: *"idle and walk masters of the same facing are not the same man at the
same size."* The cause was upstream of everything the repo had been fixing.
`voss_v22_manifest.json` declares its authority as `"3D model turnaround lock +
ImageGen stills"`, and a search of the tree finds **no geometry at all** — no
`.blend`, `.obj`, `.usd`, `.fbx`, `.glb`, no SceneKit. Nine independently
generated stills per pose are nine different men, and no amount of downstream
gating can make them one.

Three measurements, against the local Baldur's Gate dump in `~/BG` (135 frames
of the `CEFC4A50` false-colour export):

| | Baldur's Gate | V22 shipped | V23 |
|---|---:|---:|---:|
| silhouette width / height (walk, median) | **0.427** | 0.368 | **0.421** |
| shade index in ramp — p5 / p50 / p95 | **3 / 6 / 10** | 5 / 8 / 11 | **5 / 7 / 10** |
| distinct shades per frame (median) | **12 / 12** | 10 / 12 | **12 / 12** |
| baked cast shadow at palette index 1 | yes, 0.32× body | none | yes, **0.35×** |
| master body luma p5 / p50 / p95 | — | 6 / 28 / 71 | **24 / 66 / 125** |
| crunched coat mean RGB | — | 45 / 28 / 18 (whole figure) | **84 / 59 / 45** |

1. **The camera was wrong.** `ArtSource/Prompts/character_camera_lock_bgee_v01.md`
   has specified the right camera since 2026-08-15 — orthographic, elevation
   `asin(0.75)` ≈ 48.59° — but its status still reads *"follow-up — character
   masters are regenerated after the office and city plates are approved."*
   Those plates landed at ≤1.5°; the characters never followed, and stayed on
   the retired ~30° dimetric camera. That is the 0.427 → 0.357 gap, and
   `crunch.py`'s `torso_width_scale = 1.15` was invented to hide it. V23 renders
   on the lock and the correction is gone.
2. **The masters were three shade steps too dark and used half the ramp.**
   `IEColourModelCutover.md` called this qualitatively — "the masters are dark
   and near-monochrome … that is wardrobe and lighting in the masters, not
   resampling". The table above is the number.
3. **The shadow was a soft ellipse.** Every BG creature BAM bakes a shaped cast
   shadow into the frame at palette index 1. `ContactShadowNode`'s blob is one
   of the clearer "this is not 1998" tells.

## The rig

Modelled in a script so it is reviewable and diffable: **468 triangles, 312
vertices, 18 bones, 4 actions**. Parts are hexahedra, every vertex binds to
exactly one bone at weight 1.0, shading is a bare Diffuse BSDF with Gouraud
normals and no maps. The head is several hexahedra (jaw, cranium, nose, ears,
hair shell), not one box — a single cube under this camera is a beige
table-top, and BG still resolves a face at 64 rows. The coat body stops at the
shoulder, not the jaw, so the downward camera does not paint a rectangle
around the head. Smooth skinning would be sanded off by the crunch and cost
render time to produce.

**Camera.** Orthographic, `rotation_euler.x = 90° − 48.59° = 41.41°`. The pitch
is the *complement* of the elevation and confusing the two is the obvious
mistake here. `ortho_scale` 2.30, canvas 1280×1536.

**Facings.** Nine authored western strips at 22.5°, mirrored to sixteen —
`s, ssw, sw, wsw, w, wnw, nw, nnw, n` at Z rotations 0 … −180. Note the camera
lock document's table says 45°/eight directions; that predates the 16-facing
runtime in `Orientation.sixteenToNine` and is wrong. Independently corroborated
by [IE-AutoSpriter](https://github.com/Incrementis/IE-AutoSpriter-), whose
`retrieveCameraPosFolderNames` enumerates the same nine western names and
mirrors the eastern seven.

**Light.** One shadow-casting sun fixed in world space, azimuth −115°, elevation
60°, plus a shadowless fill at 16° from the opposite side and a low warm
ambient. Fixed is the point: the figure rotates underneath, so the cast shadow
keeps one screen direction across all nine facings, exactly as BioWare's did.
The near-overhead key alone lit every facing about equally and produced nine
identical pale figures; the fill is what puts a value break down the body.

## The three passes

1. **Beauty** — anti-aliased, `Standard` view transform, composited over flat
   `(0,255,0)`. The view transform matters more than it looks: Blender's default
   `AgX` rolls off highlights and desaturates, which is precisely the defect
   being fixed. `install_voss_v16.key_chroma` keys it unchanged.
2. **Material ID** — every material swapped for a flat emission from
   `spec.MASK_COLORS` with the reconstruction filter off, then classified by
   exact nearest match. **This replaces 204 hand-authored masks.** Material stops
   being inferred from colour, which `qa_ie_avatar_encode.py` had demonstrated is
   impossible for Voss — four of his seven materials are warm browns separated
   only by value, and 11 of 21 material pairs came closer to each other than one
   step along their own ramp.
3. **Shadow** — the *evaluated* mesh projected onto `z = 0` along the sun ray and
   rendered flat. A shadow-catcher render would be soft and noisy; BG's baked
   shadows are hard masses at one palette index, and a projection gives that
   deterministically.

`Frames/` and `Materials/` hold **204 files each** — 168 rendered plus the 36
`sit_down` masters derived as the exact reversal of `stand_up`, matching V22's
tree shape so gates and installers need a path change rather than a rewrite.

## Pipeline changes

- **`crunch.BGEE_V2`** (`ACTIVE`) — `torso_width_scale` back to 1.00,
  `soften_radius` 1.8 → 1.2. 1.8 was sized to remove ImageGen microdetail a
  flat-shaded render does not have; at 1.8 it eats the coat's own facet edges,
  which are the figure's only value structure. `BGEE_V1` is retained.
- **`crunch._body_rows`** — the native-row convergence now solves on the
  **body**, not the alpha bounding box. See the trap below.
- **`ie_avatar.encode_frame`** — mask label 8 routes to `ie_palette.SHADOW_INDEX`.
- **`author_material_masks.MASK_PALETTE`** — a ninth entry for the shadow. The
  first eight are required of every mask; the ninth only of a mask that uses it,
  so Lila's 25 pre-shadow masks stay valid.
- **`ie_avatar.VOSS.colors`** re-fitted; **`VOSS_V22`** retained.
- **`voss_masters.py`** — one declaration of which master set is active.
- **`install_voss_v22.py`** pinned to `VOSS_V22` and `BGEE_V1` so it still
  rebakes V22 exactly.

## Two traps this cost real time to find

**The gradient rows and the masters are one unit.** A character's `colors[]`
picks one 12-shade `MPALETTE` row per material, and that row *is* the material's
entire value range. Measured out of `setup_paperdoll_colours`, three of V22's
seven rows are unusable for correctly lit art:

| material | row | shade 0 luma | shade 11 luma | span | monotonic |
|---|---:|---:|---:|---:|---|
| coat+waistcoat | 237 | **84** | 6 | 78 | yes |
| trousers | 160 | **82** | 17 | 65 | yes |
| tie | 198 | 89 | 26 | 63 | **no** |

The coat can never be brighter than luma 84 on row 237 whatever the render does,
and the tie's row is not monotonic — shade 11 is brighter than shade 5. Those
rows are a faithful fit to art that was three shade steps too dark, so they are
stale by construction the moment the art stops being dark. Left alone they
*invert* the fix: against a ramp topping out at 84 a correctly lit coat clamps
to the bright end and the figure encodes at shade 0/2/8 where BG sits at 3/6/10.
`fit_voss_v23_gradients.py` re-fits under four criteria, and three of them were
added only after the one before it produced a wrong-looking figure that passed:

1. **Monotonic in luma, span ≥ 120** — or the target is unreachable.
2. **Scored in CIE94, not Euclidean RGB.** RGB is dominated by
   luma and reproduced a warm brown coat with a khaki whose blue channel fell
   away twice as fast: the coat came back olive and the face grey. CIE94 is also
   what `_shade_within` uses at encode time, so the fit and the encoder agree
   about "nearest".
3. **Chroma ≥ 62% of the master's**, over the shades actually used. Mean CIE94
   over a whole material under-weights desaturation, because most of a coat's
   pixels are dark where an absolute chroma error is small. Many `MPALETTE` rows
   drift toward neutral as they darken and the fit walked straight into one:
   the crunched coat measured mean RGB (102, 85, 73) — a warm grey — against the
   V22 sprite's (45, 28, 18).
4. **Centred on BG's median shade of 6.** Colour error does not care *where* on
   a ramp a material lands. A dark render against a bright ramp reproduces the
   colour perfectly while piling every pixel into shades 9–11 — the same
   compressed read V22 had, at the other end. That is exactly what happened:
   median shade 10 of 12. The penalty is 0.40 dE per step off centre, small
   enough that colour still decides between unlike rows.

Mean dE per material is 2.3–4.5. **Value range and colour identity are separate
knobs and it is easy to confuse them:** an earlier pass raised every base colour
to satisfy an invented body-luma band, hit BG's shade distribution, and washed
the character out. The lighting *ratio* gives the range; the base colour gives
the identity.

**A baked shadow breaks the native-row solve.** `native_rows = 64` is a contract
about the *figure*, against `CHMB1G11`'s measured 52–60. The shadow runs along
the ground well past the feet, so converging on the alpha bounding box fits body
*plus* shadow into 64 rows and silently shrinks the registered body — which
`standing_height [198, 202]` then reports as a scale error rather than as the
measurement bug it is. Every gate that means "the body" has to read mask indices
1–7, not alpha.

## Verification

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background \
    --python ArtSource/Blender/build_voss_v23.py
/Applications/Blender.app/Contents/MacOS/Blender --background \
    ArtSource/Blender/voss_v23.blend \
    --python ArtSource/Processing/render_voss_v23.py
python3 ArtSource/Processing/render_voss_v23.py --finalise

cd ArtSource/Processing
python3 qa_voss_v23_camera.py     # camera, shadow area, value range
python3 qa_ie_shadow.py           # the shadow label in three modules, index 1
python3 qa_ie_palette_port.py
python3 qa_ie_avatar_encode.py    # 204 masks, every phase of every direction
```

All four pass. The full render is 168 frames × 2 passes in about 85 seconds.
Rebuild the `.blend` after touching `voss_rig_spec` — material colours are baked
into it at build time, and re-rendering without rebuilding silently produces the
previous wardrobe.
`swift test --scratch-path /tmp/RainShadowSwiftPM-V23` passes 1062 tests — the
shipped runtime is deliberately untouched by this landing.

Each gate takes `--baseline` and re-derives its bands from `~/BG` rather than
carrying tuned numbers.

## What remains

The transactional install, which is mechanical but must not be rushed:

1. `install_voss_v23.py`, cloned from `install_voss_v22.py` and keeping its
   structure exactly — `V22Cell.mirrored`/`.split` re-render the **plane** and
   call `_reframe`, because Super xBR's three passes read the buffer they write,
   so `flip(render(p)) != render(flip(p))`.
2. `ie_avatar_bundle` writes `shadow.embedded: true`.
   `IEIndexedSprite.swift` already carries `hasEmbeddedShadow`, inventories
   `containsShadowIndex` and cross-checks the two, so no schema bump is needed.
   `ie_palette.py:97` already half-transes index 1.
3. Stop attaching `ContactShadowNode` for Voss in `DetectiveActorNode`; Lila
   keeps it until she migrates.
4. Re-derive, do not relax, every geometry baseline that currently reads the
   alpha bbox: `FOOT_Y`, `standing_height`, `seated_height`, `transition_rise`,
   `head_width`, and `VossSeatScaleTests`.
5. Re-run `qa_superxbr_ab_v01.py` on the new masters. The 29 August decision to
   ship Super xBR was made on masters that were dark, flat and off-camera.

Known art debt, measured rather than guessed:

* **The p5 shade is 5 where BG's is 3** — BG's figures put 5% of their pixels
  near the bright end of a ramp and V23 does not, because the rig shades with a
  bare Diffuse BSDF and has no specular at all. A small specular term is the
  obvious next experiment, and it is not a betrayal of the "primitive Gouraud"
  target: 1998 renders had highlights.
* **Hands and lapels are still mittens and slabs.** The head is no longer a
  single box (jaw / cranium / nose / ears / hair shell), and the coat top no
  longer sits at jaw height. What still reads crude at 64 rows is the mitten
  hands and the unshaped lapels.

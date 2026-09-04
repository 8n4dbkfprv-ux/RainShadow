# Render pipeline — the GemRB port

- Status: **in progress.** Blit flags and pixel shaders shipped; lightmap sprite
  tint shipped for actors and area animations, with all eight light maps re-baked
  into engine space; `BlitFlags::GREY` shipped for the paused world; the per-pixel
  wall stencil shipped. The draw order turned out to be **already correct** and
  is now pinned to upstream by test rather than rewritten — see below.
- Upstream revision: `1c45c1850d9b5d61a23b3a569499ef57543e2c3f`, the same one the
  navigation and colour-model ports track.
- Related: [Third-party notices](ThirdPartyNotices.md),
  [Technical architecture](TechnicalArchitecture.md) §2.1,
  [Navigation open questions](NavigationOpenQuestions.md) §1, `AGENTS.md`.

RainShadow already reproduced GemRB's *rendering data model* faithfully —
`AreaWallPolygon` carries WED flag bits, `AreaAnimation` carries `wallHides` and
`isSelfIlluminated`, `AreaLightMap` is `LM.BMP` at search-map resolution — but
drew it with invented approximations. This is the record of replacing those with
the engine's own answers, and of the places where the target forced an
adaptation.

## What shipped

### Blit flags and pixel shaders

`IEBlit.swift` is `enum BlitFlags` plus `ShaderTint` / `ShaderGreyscale` /
`ShaderSepia` and `Game::ApplyGlobalTint`, in integer arithmetic.
`IEBlitShader.swift` is the same three shaders again in GLSL, because a fragment
shader is the only place SpriteKit lets us touch a pixel.

### Lightmap sprite tint

`DetectiveActorNode.applyBodyTint` and `ClientActorNode.applyBodyTint` now run
`Map::DrawMap`'s composition: the lightmap sample under the actor's ground point
becomes the tint, the authored scene grade multiplies in through
`ApplyGlobalTint`, and `ShaderTint` applies it.

Area animations run the same path — `Map::DrawMap` tints them from the same
lightmap through the same `ShaderTint` — replacing a `colorBlendFactor = 0.35`
lerp toward the sample colour.

What it replaced was a `0.45 + 0.55 * footLight` curve pushed through
`colorBlendFactor`. Both halves were wrong: the curve was invented, and
`colorBlendFactor` *interpolates toward* a colour where the engine multiplies by
it. A lerp brightens a dark pixel toward the tint; a multiply can only darken.
That is the difference between a character standing in an unlit room and one
floating over it. It also meant the light maps could be authored in a range no
multiply could use — see below.

## The lightmaps had to be re-baked, and why

Landing the multiply exposed that **the shipped light maps were not in the
engine's space.** `bake_area_lightmap.py`'s own docstring described what it did:
downsample the area plate, "shift it cool and dark", add lamp pools. That is a
darkened copy of the plate — *relative* lighting, saying where an area is
brighter and darker. `LM.BMP` is a **multiplier**: `c.r = (tint.r * c.r) >> 8`.

All eight shipped maps sat at mean 0.03–0.18, max 0.30–0.73. Multiplying a
sprite by 0.12 is a black silhouette, and that is exactly what rendered.

The old runtime never noticed because it never multiplied: it remapped with an
undocumented `0.45 + 0.55 * sample` curve and applied the result as a
`colorBlendFactor` lerp at weight 0.30, so 0.09 became 0.50 and then barely
registered. The numbers never had to mean anything. They do now.

**The port was not at fault, and this was checked rather than assumed.** A shader
variant doing un-premultiply → byte quantise → re-premultiply with *no tint*
rendered byte-identical to the unshaded sprite (mean luma 29.91 both ways), so
the round-trip is lossless and the fault was entirely in the input data.

`to_engine_space` in `bake_area_lightmap.py` is the fix. It keeps the authored
spatial structure — plate variation and lamp pools, which are real art direction
— and maps it onto a multiplier band:

| | R | G | B |
|---|---|---|---|
| `ENGINE_FLOOR` (deepest shadow) | 0.34 | 0.38 | 0.48 |
| `ENGINE_CEIL` (full lamp) | 0.92 | 0.90 | 0.86 |

Cool at the floor, warm at the ceiling, because what lifts a cell toward the
ceiling is a lamp. Normalisation is on **luminance**, not per channel: per
channel would stretch each to the same range and flatten the colour cast the
authored pass just created. Percentiles are 2/98 rather than min/max because the
office plate is three-quarters black void and one void cell would otherwise pin
the whole room to the floor.

`build_city_building_interior_v01.py` imports the same function rather than
defining its own — two definitions of "engine space" would drift, and the
failure would be one area lit unlike every other.

Measured result in the office, on Voss: mean luma 27.37 shipped → **21.34**
engine-space multiply, against 29.91 untinted. A 22% darkening that seats him in
the floor's value range, where the faithful multiply over the *old* maps gave
15.72 — a near-black silhouette.

### `bake_area_lightmap.py` does not reproduce its committed output

Checked before changing it, per `AGENTS.md`. On `main`, running the baker
untouched rewrites **six city `.lm.png` and six `.ht.png`** files, and *invents*
`.lm.png` / `.ht.png` for five `interior_*` areas that have never shipped one —
which would silently opt those areas into lightmap tinting. Only `office_suite`
and `city_building_interior_v01` came back identical.

This is the third generator in the repo with this property; `AGENTS.md` already
records `office_layout_plan.py` and `generate_office_zone_props_v01.py`. Two
consequences:

- **Verify inertness against the generator's output, not the committed file**, or
  pre-existing drift gets attributed to your change.
- The baker now **skips any area with no shipped `.lm.png`** rather than
  inventing one. The `.ht.png` drift is untouched and still open — height maps
  are not part of the render port, and the six that differ were left as they are
  on `main`.

### `BlitFlags::GREY` for the paused world

`WorldPauseController` said it "drove the greyscale" and nothing did. It does now,
using the ported `>> 2` arithmetic rather than a `CIFilter` saturation of zero —
the engine's grey peaks at 189 and is a visibly different, darker image.

Only `isPausedByPlayer` recolours the world. An inventory screen also pauses, and
greying the world behind it would read as a state the player did not ask for —
the same distinction the clock button already draws.

**It is a per-object flag, not a post-process.** Upstream sets it per drawn
object (`if (game->TimeStoppedFor(actor)) flags |= BlitFlags::GREY;`), and so does
this. Wrapping the world in one `SKEffectNode` is the obvious alternative and is
the wrong shape twice over: the layer roots are siblings of the scene rather than
one subtree (52 references across the codebase), and Sable Row's plate is
8192x6144, so it would rasterise the whole world every frame to save a walk that
only runs when the pause changes.

Two kinds of sprite are involved. Plates and props have no shader, so they borrow
a shared grey-only one for the duration. Actors and area animations already own an
`IEBlitShader` carrying their lightmap tint, so they only need the flag — and this
is where the first attempt was wrong in a way worth recording:

> **A uniform written directly onto a shared shader does not survive.** An actor
> rewrites every one of its uniforms from `applyBodyTint` on each step, so a grey
> toggle poked onto its shader is erased by the next tint update. The first
> attempt did exactly that and rendered Voss at saturation 6.24 instead of 0 —
> partly grey, which reads as a rendering bug rather than a missed flag.

`BaseGameScene.worldBlitFlags` is the fix: one value that both the walk and every
per-object update derive from, so they cannot disagree. Measured in the office:
Voss's mean saturation 20.93 unpaused → **0.00** paused, and the whole world's
saturation 13.48 → 0.02 with the peak channel dropping 234 → 127.

### Per-pixel wall stencil

`AreaWallStencil` bakes `Map::DrawStencil`'s four-channel encoding — red `0x80`
for `WF_DITHER` and `0xFF` without it, green following red for `WF_COVERANIMS`,
blue always `0xFF`, alpha always `0x80` — and `IEBlitShader`'s `STENCIL_DITHER`
path reads it per fragment.

What it replaced was `ActorCover`'s flat alpha of 0.42 over the *whole* actor
whenever their ground point fell inside a covering outline. Upstream masks only
the pixels the wall overlaps, so a character half-behind a pillar keeps their
exposed half opaque; ours went translucent head to toe. The old file's reasoning
was half right — "SpriteKit has no stencil blit" — but SpriteKit does have
`SKShader` sampling a baked mask. The depth lift it also applied was correct and
survives: upstream likewise draws the actor after the background and lets the
stencil put the wall back in front.

`AreaWallPolygon` gained `dithers` (`WF_DITHER`, WED bit 1, value 2), the flag
`DrawStencil` reads for the red channel and the one field the data model was
missing. It defaults **true**, because RainShadow's covering polygons have always
shown the actor through; a wall that should hide outright now has to say so.

**Two decisions that are not the same decision**, which the flat-alpha version
conflated:

- *Which walls are in front of this actor* is answered from the ground point, as
  upstream answers it from `scriptable->Pos` in `WallsIntersectingRegion`.
- *Which of its pixels the wall hides* is answered per pixel by the stencil.

**Deviations.** The mask is baked once per area in area space rather than rebuilt
per viewport — RainShadow's covering outlines are authored world geometry that
never moves, so a per-frame rebuild would recompute a constant. The cost is that
a future openable wall polygon would need the mask invalidating; there is none
today. And `bake` takes a **reference** actor height to honour
`AreaWallPolygon.height` (a kerb must not stipple a standing adult), so a child
NPC and an adult get the same mask; upstream has no equivalent problem because it
uses a wall baseline and asks per object at draw time.

Note `ActorCover.depthLift` stays at `SceneLayer.occlusion`'s underside on
purpose. `occlusion` is authored foreground that covers unconditionally, which is
not what a wall polygon means.

### The bake froze area entry, and how it was found

Shipped and immediately regressed area transitions. The first `bake` rasterised a
**full world-sized buffer per polygon** at one world unit per cell. The office
(1617x910, three covering walls) was fine at 0.31 s. A ward is 5120x3840 with 86
covering masses — 1.69 billion cell operations and a 78 MB mask — and took
**119.55 s**. In play that is the game hanging on every area change.

Measured, not guessed, and the first comparison was worthless: timing the working
tree showed no difference because the fix was already in it. Building each commit
in a worktree gave the real picture.

| Build | Sable Row load |
|---|---|
| Before the port | 134.7 s |
| As first committed | 253.3 s |
| After the fix | 133.5 s |

Two changes. Each polygon now rasterises into a tile covering only its own
bounding box, so cost is the sum of polygon areas rather than walls times world
area. And `maximumMaskDimension` caps the longest edge at 2048 cells, coarsening
a ward to about 2.5 world units per cell — roughly 2.3 points at play zoom, a
staircase you have to look for. The dither is screen-space, so the mask only has
to resolve *edges*, not the pattern. Result: 119.55 s and 78 MB become **0.30 s
and 8 MB**, and the office is small enough to stay at one unit per cell.

`aWardBakesSmallAndFast` pins both halves. The agreement test had to be reframed
at the same time: at one unit per cell the office agrees with `isCovered`
*exactly*, but a ward at three units cannot near a wall edge — that is what
rasterising is. It now requires exact agreement **away from edges** rather than
tolerating a flat percentage, because a percentage would also tolerate a
systematic offset, which is the fault worth catching.

**Separately, and not from this port: area load is slow on its own.** The
pre-port baseline is ~135 s for a ward and ~156 s for the office in a Debug
build. That is untouched here and is its own problem.

### Three bugs this phase produced, and what caught each

Worth recording, because two of them fail silently:

1. **The mask was vertically flipped.** `CGBitmapContext` stores row 0 as the
   *top*; the mask is row-major y-up from the world's minimum corner, matching
   `AreaSearchMapLoader` and `AreaLightMap`. Caught by
   `theMaskIsYUpFromTheWorldMinimumCorner`, and it would have applied cover to
   the mirror image of the scenery — plausible-looking in a symmetric room.
2. **One shader per actor could not carry a per-sprite stencil.** The lookup is
   composed from each sprite's own world rect, and an actor's layers differ in
   size and anchor, so a shared instance pointed all three at whichever layer
   wrote last. Shaders are per layer now, on `IEAvatarNode`.
3. **An unbound sampler silently disables the whole shader.** Adding
   `u_ie_stencil` without binding a texture made SpriteKit fall back to default
   shading — which shows up as *the tint quietly not applying*, not as an error.
   `IEBlitShader.blankStencil` is bound whenever no real mask is. Caught by the
   QA harness's colour checks going from pass to `got == input`.

### The draw queue was already right

The plan for this port called for replacing `BaseGameScene.updateDepth`'s z
formula with a port of `GenerateQueues` / `SortQueues`, on the premise that
"area animations, props and piles sit in fixed `SceneLayer` bands and can never
interleave with actors by ground point."

**That premise is false.** Checked before writing anything:

- `depthWorld` props go through `updateDepth` (`BaseGameScene.makeProp`).
- Area animations go through `updateDepth` (`GameAreaScene.buildAreaAnimations`).
- Ground piles have no scene node at all — `GroundPileState` is model-only.

So every depth-sorted object already shares one continuous z space keyed on the
ground point, and interleaves exactly as upstream's single queue makes it. The
rewrite would have invalidated every hand-tuned bias in the office (`-60`, `-70`,
`24`, `deskSortBias`) and put the documented additive-light-cast ordering at risk,
in exchange for no behavioural change. `AGENTS.md`'s bar — *a diff against GemRB,
quoted* — cuts against the rewrite here, not for it.

What was genuinely missing was any **statement of direction**. The formula's sign
was not asserted anywhere, and a sign nobody can check is a sign that can silently
invert — every individual still frame looks plausible either way. `DrawQueue` now
carries `Map::SortQueues`' comparator as the stated authority, `updateDepth`
computes through it, and `DrawQueueTests` holds the two to each other across the
whole range.

**The axis flip is the substance.** Upstream's `Pos.y` is screen space, y down: a
larger `y` is nearer the camera, its comparator sorts descending, and `DrawMap`
walks the queue backwards so drawing runs far-to-near. RainShadow's world is
SpriteKit, y up: a larger `y` is *further*. Same relationship, opposite sign.

One deliberate divergence: `std::sort` is unstable, so upstream's order for two
objects on the same `Pos.y` is unspecified. Ours keeps input order, because
`makeProp` records the office's five additive light casts rendering a step apart
per channel between two builds whose scene graphs were provably identical — the
view runs `ignoresSiblingOrder`, and an order nobody states is an order that can
change under you.

## Deliberate deviations

Each of these is a place the port does not match upstream, with the reason.

| Deviation | Why |
|---|---|
| GLSL flags are separate float toggles, not a packed bitfield | SpriteKit compiles a GLSL ES 1.0 subset, which has **no bitwise operators**. `flags & BlitFlags::GREY` cannot be written. `IEBlitFlags` stays the authority and is unpacked at the boundary. |
| The GLSL works in byte space (scale to 0...255, floor, operate, scale back) | A float `* 0.25` is not a truncating `>> 2`. Working in unit floats would land within a rounding error of the engine rather than on it. |
| The GLSL un-premultiplies alpha first | `SKTexture` pixels are premultiplied; the engine's `Color` is straight. Tint and greyscale are linear and survive the difference; sepia's `+ 21` and `- 32` are absolute byte offsets and would land wrong on a partially transparent pixel. |
| `ActorSceneLighting.globalTint` folds a blend weight into the tint | Upstream has no blend weight — its global tint *is* a multiplier, authored as one. `bodyBlend` exists only because the grade used to go through `colorBlendFactor`. Folding it in keeps three hand-tuned grades working. Re-authoring them as direct multipliers and deleting `bodyBlend` would be closer to upstream and is a separate art decision. |

## SpriteKit's opacity contract, measured

Three facts decide how any of these shaders has to be written. They were
measured, not assumed, because getting the middle one wrong double-applies every
fade in the game:

1. `SKDefaultShading()` returns **premultiplied** RGBA — a white texel at alpha
   128 comes back with `.r == 128`, not 255.
2. It **already includes the node's `alpha`** — a node at `alpha = 0.5` over an
   opaque texture yields `texel.a == 0.5`.
3. SpriteKit does **not** re-apply node `alpha` to a custom shader's output. A
   shader writing a constant `vec4(1, 0, 0, 1)` renders fully opaque red at
   `alpha = 0.5`.

So node opacity reaches a shader through `texel.a` and nowhere else. A shader
must carry `texel.a` through to `gl_FragColor`, and must **not** also take an
opacity uniform. An early draft of `IEBlitShader` had one; it would have
multiplied every fade in twice.

## Verification

The GLSL is a second transliteration and `swift test` cannot reach it, so it has
its own gate — the same shape as `qa_ie_palette_port.py` for the colour model:

```sh
swift ArtSource/Processing/qa_ie_blit_shader.swift
```

It reads the shader source verbatim out of `IEBlitShader.swift`, renders it
through SpriteKit, and compares against the integer port across the boundary
values (0, 31, 32, 33, 254, 255) in every flag combination. Run it after touching
either copy.

It also renders the `STENCIL_DITHER` path against a three-band mask and checks
that an uncovered pixel is untouched, a `WF_DITHER` wall shows through at ~50%
**as a per-pixel checker rather than a flat blend**, and a wall without it hides
outright. Measured: 251.8 / 126.3 / 0.5 out of 255.

`Tests/RainShadowCoreTests/IEBlitTests.swift` holds the integer copy to
upstream's arithmetic, and `AreaWallStencilTests.swift` holds the mask to
`DrawStencil`'s encoding — including that it agrees with `AreaDefinition.isCovered`
across both shipped areas, which is the real regression risk in replacing
`ActorCover` with a different mechanism.

The mask has no in-app failure signal — offset or flipped, it still renders, just
onto the wrong pixels. To see where it actually lands:

```sh
RAINSHADOW_START_SCENE=office RAINSHADOW_SKIP_INTRO=1 \
RAINSHADOW_DEBUG_STENCIL=1 RAINSHADOW_CAPTURE_MODE=room \
RAINSHADOW_CAPTURE=/tmp/mask.png <app>
```

## Two answers that look like bugs

Both are upstream's, both are pinned by tests, and both are the thing a later
reader is most likely to "fix":

- **Tinting by white is not identity.** `(255 * 255) >> 8` is 254. Upstream gates
  the tint behind `COLOR_MOD` rather than ever passing white, which is why
  `ActorSceneLighting.globalTint` returns `nil` — not white — for no grade.
- **Greyscale peaks at 189**, and is an unweighted average rather than Rec. 709
  luma. The engine's grey is deliberately darker than a desaturate, so a
  `CIFilter` saturation of zero is not a substitute for it.

## Not ported, and why

Not oversights — each is a decision, in the shape `PathfindingSystem.md` records
its own.

- **The renderer itself.** `gemrb/core/Video/` and the `SDLVideo` plugin are not
  embedded. Doing so would replace SpriteKit, breach
  `TechnicalArchitecture.md` §2.1, need an SDL2 host view on both platforms, and
  take the whole shipped app to GPL-2.0 rather than the ported files alone.
- **The IE data formats.** `WEDImporter` / `TISImporter` / `MOSImporter` /
  `BAMImporter` would let areas render as real tilesets with animated overlay
  tiles. That retires the ArtSource painted-plate pipeline, which the projection
  lock is built on.
- **Projectiles, spell VFX and `Particles.cpp`.** `RainSystem` already covers the
  one weather effect this game has.
- **`WF_DISABLED` wall polygons.** Upstream can disable a door's polygon at
  runtime, which is part of why it rebuilds the stencil per frame. RainShadow has
  no openable covering geometry, so the mask is baked once. Adding one means
  invalidating the mask, not un-baking it.
- **Per-actor stencil height.** The mask is baked against a reference actor
  height, so a shorter NPC gets the adult's answer. Upstream has no equivalent
  problem because it uses a wall baseline and asks per object at draw time. The
  fix, if a short actor ever needs one, is a second mask.


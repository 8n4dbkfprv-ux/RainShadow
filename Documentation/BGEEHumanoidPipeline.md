# BG:EE humanoid pipeline

**Status: `BGEE_V1` raster craft and the indexed IE colour model are active end
to end: authored masks, bake, raw bundle parser, SpriteKit adapter and Voss/Lila
actor wiring.**

## Measured reference

Infinity Engine BAM cells are variable-sized frames with their own width,
height, and centre coordinates; they are not fixed 512px squares. The format
also stores an indexed palette and a compressed-colour/transparency index. The
implementation used for cross-checking is GemRB's
[`BAMImporter.cpp`](https://github.com/gemrb/gemrb/blob/master/gemrb/plugins/BAMImporter/BAMImporter.cpp),
with field layout checked against the GitHub-hosted
[`BAM V1` IESDP specification](https://github.com/gibberlings3/iesdp/blob/master/file_formats/ie_formats/bam_v1.htm).

GemRB ships a representative medium-human BG walk resource,
[`CHMB1G11.BAM`](https://github.com/gemrb/gemrb/blob/master/demo/override/CHMB1G11.BAM),
in its public demo data. It was decoded frame by frame rather than judged from
a screenshot:

| Measurement | Result |
|---|---:|
| Stored frame | 44×71px |
| Walk frames measured | 90 |
| Nontransparent bounding-box height, including shadow | 53–67px |
| Crown to ground anchor | 52–60px; median 55px |
| Non-shadow silhouette width / height | median 0.427 |
| Nontransparent palette indices per frame | 44–59 |
| Nontransparent palette indices across the clip | 76 |

Those values are a representative craft target, not a claim that every IE
creature has one universal size. BAM frames are explicitly variable.

The measurement is repeatable without checking the reference BAM into this
repository:

```bash
python3 ArtSource/Processing/qa_infinity_bam_humanoid.py /path/to/CHMB1G11.BAM
```

## RainShadow comparison

Before this change, V15 retained all 200 vertical body samples and up to 128
colours. It preserved more source detail than the measured humanoid animation.
The runtime body itself was already correctly registered: a 200px visible body
inside a 512px cell displayed on a 180-unit node is **70.3125 world units**.
Changing that would invalidate door, furniture, desk, camera, and seated-pose
registration.

`BGEE_V1` therefore changes craft density without changing physical size:

| Contract | BG reference | RainShadow active |
|---|---:|---:|
| Native crown-to-ground craft | 52–60px (median 55) | 64px |
| Palette use | 44–59 indices/frame | seven 12-shade material ranges in one 256-entry character palette |
| Alpha | indexed transparent colour | index 0 transparency; hard 1-bit silhouette |
| Runtime cell | variable | trimmed raw indexed frame plus 512×512 RGBA fallback cell |
| Registered standing body | variable | unchanged 200px |
| Runtime world height | game-specific | unchanged 70.3125 units |

The earlier RainShadow figures had the correct height but read too slender next
to the decoded reference. The active correction widens torso/coat rows by 15%
on the 64-row native craft, ramps in below the head, and ramps back to 1.0x at
the legs. It is not a stretch of the finished 512px atlas cell. Measured across
the installed animations:

| Runtime set | Before median width / height | Active median width / height |
|---|---:|---:|
| Voss standing idle | 0.352 | 0.383 |
| Voss walk | 0.375 | 0.398 |
| Lila arrival/departure | 0.345 | 0.360 |

The decoded `CHMB1G11` median is 0.427, but that is one male outfit and facing
mix rather than a universal humanoid width. The active figures now sit within
ordinary outfit/pose variation while retaining their distinct builds. Voss's
median head widths remain exactly 22px idle / 19px walk; every standing cell
remains 200px high with its foot at row 433.

64 rows is the smallest grid near the measured range that preserves Voss's
left/right planted-foot exchange in every one of RainShadow's nine authored
directions. A 56-row trial lost the WNW gait and repeated NNW foot leads. The
four-row margin over the reference maximum is therefore a motion-integrity
choice, not a scale increase: the result is still enlarged into the same 200px
registered body.

At 100% play zoom, the native standing body displays at **64 logical points**,
independent of window height. Step 10 (70%) shows about **91.4 points**. The
old fixed 9%-of-window calibration is retired; resizing now reveals more world.
The world-space body and animation registration are unchanged. See
`NativeSpriteCameraCalibration.md` for the precise contract and its limits.
GemRB's EE-compatible 27-step zoom and five-percentage-point stride
are implemented in
[`GameControl.cpp`](https://github.com/gemrb/gemrb/blob/master/gemrb/core/GUI/GameControl.cpp)
and its 100% default is declared in
[`GameControl.h`](https://github.com/gemrb/gemrb/blob/master/gemrb/core/GUI/GameControl.h).

## Active recipe and invariants

- `native_rows = 64`, hard alpha, and a complete authored material mask carried
  through the same geometry as the figure.
- The 64-row index plane is resolved directly at native resolution and sampled
  once by SpriteKit's **linear** texture filter into the unchanged 200px
  registered geometry. The play camera cancels that registration enlargement
  at 100%, leaving a 64-point standing body. This follows the native-frame /
  whole-view zoom principle; it is not a pixel-exact reproduction of Beamdog's
  renderer. Near Infinity's Super xBR is no longer in Voss's runtime path.
- `soften_radius = 1.8`, with value contrast `1.00` (no extra value grade),
  followed by one indexed encode into the character's seven 12-shade ranges.
- `torso_width_scale = 1.15`, ramped below the unchanged head and back to
  `lower_width_scale = 1.0` for the lower legs, feet, height, and ground contact.
- Compatibility atlases retain 512×512 cells, a 200px standing body and foot
  row 433. The raw bundle trims each frame and records the equivalent pivot and
  display scale; the physical world registration is unchanged.
- SpriteKit uses linear filtering for the native craft at both registered body
  scale and play zoom; there is no pre-enlargement filter in Voss's indexed
  runtime path.
- Voss V22 and all 25 Lila cells are rebuilt through the same paired
  raster/material recipe. Voss has 204 strict source masks; Lila has 25.

Voss V22 source validation also runs
`ArtSource/Processing/qa_voss_v22_master_consistency.py` before staging.  It
enumerates all 168 authored gameplay masters and rejects a forbidden cool-colour
fraction above 0.1%, a within-sequence luma ratio above 1.25, or a texture-gradient
ratio above 1.60. These are pre-crunch master-art gates: they catch isolated
material recolours and one-frame texture/exposure changes that a valid shared
character palette could otherwise conceal.

```bash
python3 ArtSource/Processing/qa_voss_v22_master_consistency.py
python3 ArtSource/Processing/install_voss_v22.py stage
```

Do not compare `native_rows / actor_world_height` with an area plate's
ground-plane pixels per world unit. Those pixels describe different projected
axes. Re-evaluate the native grid against decoded humanoid frames and motion QA,
while using the 200px registered body for physical scale.

---

# The character colour model is now a GemRB port

**Status: the port, authored masks, indexed bake, raw runtime resources, bundle
parser, SpriteKit adapter, actor wiring and legacy-lock retirement are landed.**
The ordered completion record and repeatable gates are in
[IE colour model cutover](IEColourModelCutover.md).

The palette half of this pipeline used to be invented here. `crunch.py` clustered
each frame's own colours (`_colour_centroids`), median-cut each cluster into a
ramp (`_region_ramp`), guessed materials from masks written for a monochrome
Voss, and then spent `ClipPalette`, `normalise_clip_exposure`,
`_grade_value_contrast`, `identity_wardrobe_lock` and `seated_authority_lock`
undoing the drift that caused.

The Infinity Engine answers the same question with two lookups, and that answer
is now ported rather than approximated. See `Documentation/ThirdPartyNotices.md`
for the file-by-file map.

## What the engine actually does

A character is **seven gradient indices**, one per material slot
(`METAL, MINOR, MAJOR, SKIN, LEATHER, ARMOR, HAIR`). `SetupPaperdollColours`
writes each slot's 12 shades into the palette at `0x04 + slot * 12`, aliases
several 8-colour ranges above `0x58`, and sets index 1 to black for the shadow.
Index 0 is the colour key. A frame is 8-bit indices into that palette, so the
palette belongs to the **character**, not to the clip — and no frame of an
animation can drift off it by construction. RainShadow's current avatar bundles
do not author index 1: `ContactShadowNode` remains the shadow owner.

Two engine formats, and the split is the engine's, not ours:

| | stores | transparency | shades |
|---|---|---|---|
| BAM avatar (play scale) | 8-bit palette index | index 0 | 12 per material |
| PLT paperdoll | `(intensity, range)` per pixel | `intensity == 0xff` | 256 per material |

The play-scale cutover uses the BAM-style row only. The current inventory
paperdoll and portrait were not re-encoded and require their own masks before
any later PLT cutover.

## The `0x04` is not an error

`SetupPaperdollColours` carries an upstream FIXME asking whether its `0x04`
offset shifts every material by a slot. It does not, and
`ArtSource/Processing/qa_ie_palette_port.py` settles it from shipped data rather
than from reasoning: BG:EE's creature BAMs carry a **false-colour marker
palette**, one saturated ramp per material, and its runs sit at exactly
`0x04` (grey), `0x10` (cyan), `0x1c` (magenta), `0x28` (yellow), `0x34` (red),
`0x40` (blue) and `0x4c` (green), ending at `0x57` where the alias region
begins. The port keeps the FIXME because a port records upstream as written.

## The one thing that is not a port

GemRB has no encoder, because the Infinity Engine never had one: BioWare
pre-rendered its avatars offline with in-house tools, and a BAM's material
assignment was **painted by an artist**, range by range. Recovering it from a
pre-render is our problem.

For Voss V22 it cannot be recovered from colour, and that is measured rather
than asserted. `qa_ie_avatar_encode.py` reports the seven anchors' pairwise
separation in the material feature:

| pair | separation |
|---|---:|
| coat / hair | 0.144 |
| shoes / trousers | 0.146 |
| trousers / coat | 0.171 |
| trousers / hair | 0.235 |

Lighting alone moves a material 0.2–0.3 within a single frame, so those four are
one warm brown. This is the figure the retired `_coat_mask` had been written
for and swallowed whole. Two classifiers were tried and both failed in
ways worth not repeating: a nearest-**anchor** rule gave the red tie 30% of a
front-facing idle and streaked the coat maroon, and the nearest-**ramp** rule
that replaced it gave hair up to 54% of the body.

So the material assignment is authored, as it was upstream.
`ArtSource/Processing/author_material_masks.py` writes a first Voss draft per
master plus a confidence map, and the confidence map is the review artefact:

| level | meaning |
|---|---|
| 255 | decided on colour, with a margin over every rival |
| 192 | measured geometry — head band, shoe band, legs below the measured hem |
| 128 | coat, by elimination from the torso band |
| 64 | within `HEM_BLUR` of the measured coat hem |
| 0 | nothing measured; the pose defeated the pass |

Across all 204 Voss masters the original draft was 4.3% decided on colour, 7.2%
on measured geometry, 38.3% coat by elimination, and 50.2% unresolved — the
last figure being almost entirely the seated and transition clips. Those
numbers describe the discarded draft, not the accepted material truth.

The three limits were resolved as follows:

- **Non-upright poses.** All 96 seated, sit-down and stand-up masks were
  authored by pose cluster and corrected per phase. There is no neck rise or
  standing coat hem for the draft tool to recover.
- **Three-quarter and rear faces.** Skin only wins on colour from the front. On
  a `sw` or `nw` facing the head band calls the whole head hair, so visible
  faces were painted and true rear facings were allowed to have no skin.
- **The waistcoat.** Voss wears one and the seven-slot wardrobe has no name for
  it. The recorded decision is `coat+waistcoat` in `ARMOR`; the maroon tie alone
  occupies `MAJOR`.

The exact accepted inventories are 204 Voss masks and 25 Lila masks. Index 0 is
background only; `author_material_masks.load_mask` rejects any unassigned body
pixel. `install_voss_v22.py` and `install_lila_ie_avatar.py` are the current
bake authorities. They write a versioned JSON manifest plus raw, top-down
row-major `u8` index blob outside the `.atlas` directories; the P-mode authoring
masks are never runtime texture resources.

`IEIndexedSprite.swift` validates that manifest/blob pair and resolves its
indices through the character palette. `IEAvatarNode.swift` caches the resulting
textures and applies a cropped frame's texture, display size and pivot together;
`DetectiveActorNode.swift` and `ClientActorNode.swift` use that path first and
fall back one whole clip at a time to the 512-cell RGBA atlases. The current
bundles contain no index 1, so the existing `ContactShadowNode` remains the
shadow authority.

## Deliberately not ported

In the style of `PathfindingSystem.md`'s section of the same name — these are
decisions, so that finding them missing does not read as an oversight.

- **BAM RLE encoding and the BAM container.** `qa_infinity_bam_humanoid.py`
  *decodes* BAM V1 to measure real craft, and RainShadow's manifest preserves
  the useful variable-frame/pivot model, but nothing writes a `.bam` or ports
  BAM RLE. RainShadow ships a small versioned raw bundle plus compatibility
  PNG atlases.
- **`CharAnimations`' stance and orientation machinery.** `AddMHRSuffix`,
  `IE_ANI_*`, `stances.2da`, the shadow-animation table and `NINE_FRAMES_PALETTE`
  all resolve *which* BAM to draw. RainShadow has its own nine authored
  directions and its own atlas naming; only the colour model was wanted.
- **PST's colour slots.** `SetupColors` has a separate path for Planescape,
  where `Colors[6]` is a `COLORCOUNT` stat and the palette is written from
  `256 - colorcount * 32`. RainShadow is on the BG line; the BG path is ported
  and the PST one is not.
- **`Palette32` / `LoadPalette<32>`.** BG:EE ships no `PAL32` resource at all,
  so upstream's `LoadPalette<32>` returns false there and nothing reads it.
  `extract_ie_gradients.py` therefore extracts 16 and 256 only.
- **`RGBModifier` / `SetupRGBModification`.** The engine's per-actor tint and
  colour-cycling animation. RainShadow tints scenes through
  `ActorSceneLighting`, which already documents itself as standing in for the
  area lightmap.
- **The paperdoll/portrait cutover.** `PLTSprite.swift` and the PLT palette model
  are present, but no current paperdoll or portrait has an accepted material
  mask. Play-scale avatar completion does not author one by implication.

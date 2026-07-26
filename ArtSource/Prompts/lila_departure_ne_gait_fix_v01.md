# Lila March NE departure gait fix V1

Generated 2026-07-25 with the built-in Image Generator.

## Defect

After the NE facing fix (`lila_departure_ne_facing_fix_v01.md`), the shipped
departure strip still reads as a **one-leg limp**: one anatomical leg keeps the
leading role across all eight frames while the other stays planted behind.
`qa_current_atlas_feet.png` under `DepartureFacingFixV1/GaitFixV1/` shows the
legs never exchange lead. Whole-figure flips of NW backups (`gaitfix_v10`) did
not restore a true two-leg cycle and violate the handbag/light contract.

Do **not** fix with a horizontal flip: the handbag stays on anatomical left and
must never be mirrored; upper-left baked light must stay upper-left.

## Shared style lock

Reuse the V6 BGEE avatar contract from `character_prerendered_3d_v06.md`:

> Create a Baldur's Gate: Enhanced Edition–era Infinity Engine pre-rendered 3D
> character avatar: a simple textured late-1990s game mesh rendered offline into
> a small 2D gameplay sprite. Soft directional baked light from the upper-left,
> soft anti-aliased silhouette against the backdrop, readable clothing folds and
> masses, ordinary realistic human proportions, and only a few pixels of facial
> suggestion at play scale. Not modern PBR, not photoreal concept art, not
> hand-drawn pixel art, not toy/chibi proportions, not hard black comic outlines,
> not polished contemporary low-poly illustration. No pores, individual hair
> strands, glossy materials, cinematic rim light, depth of field, floor plane,
> cast/contact shadow, scenery, text, UI, or watermark. Place every complete
> figure on a perfectly flat uniform `#00ff00` chroma-key field. Do not use
> `#00ff00` in the character.

## Identity lock (Lila March)

Slim adult mid-century silhouette; pale auburn hair pinned up beneath a small
dark-navy beret; alert, guarded face (mostly unseen from rear); deep emerald
swing coat flaring below the waist; cream day dress beneath; short dark gloves;
compact **dark handbag on her anatomical left hand**; sensible dark shoes.

## Direction lock (hard reject if violated)

- Camera: orthographic / 2:1 dimetric, looking down about 30–35 degrees.
- Pose: **rear three-quarter northeast** — back of coat and beret dominant.
- Travel: every figure faces and walks toward the **upper-right** of its cell
  (NE). Reject upper-left / NW facing.
- Handbag remains on anatomical left (never mirrored).
- Soft baked light from the upper-left of the frame.
- Do **not** mirror or turn the whole character between poses.

## Anatomical phase contract (hard reject if violated)

Generate **individual single-figure poses** (not an ambiguous 8-wide strip).
Locked-view opposite-leg ownership from `character_walk_gait_v06.md` plus the
V8 right/left contract from `character_walk_gait_v08.md`:

1. anatomical **right leg forward** planted, left leg extended back;
2. right leg supporting, **left leg passing** low (both shoes move);
3. anatomical **left leg forward** planted, right leg extended back
   (missing half — reject if absent);
4. left leg supporting, **right leg passing** low (both shoes move).

Expand to eight runtime frames with mid-stride variants of the same four phases
(slight restrained bob). Ordinary walk only: no high knee, rear kick, run, idle,
or duplicated leg ownership. Both shoes must change location across contact
pairs.

Pose-guide language for the generator:

> RED means anatomical RIGHT leg; BLUE means anatomical LEFT. Frame ownership
> must match the phase list above. Keep the exact locked NE rear camera,
> identity, outfit, body scale, common ground line, and restrained ordinary walk.

## Construction (approved path)

1. Lock identity from the approved NE rear key.
2. Generate individual chroma poses. Full strips and most single poses collapse
   to the same lead (image-right foot higher / farther). Reject any set that
   lacks a true opposite contact.
3. Accept opposite contact only when the **image-left foot is higher** than the
   image-right foot after chroma extract (`dy = y_left - y_right < 0`) with a
   wide stride **and** the handbag stays on the NE bag side (screen-left of body
   mid). Reject opposite contacts that flip the bag to screen-right — those read
   as wrong-facing mid-cycle at play scale (gaitfix_v12 frames 03–05 defect).
4. Composite eight equal cells on `#00ff00` with an explicit lead exchange, e.g.
   R-R-R-L-L-L-R-R, into
   `DepartureFacingFixV1/lila_departure_ne_strip_combined_gen.png`.
5. Run `process_lila_departure_facing_fix_v01.py` (arrival untouched).
6. Re-check registered atlas cells: bag side constant across all 8; lead still
   exchanges. V7 preserves opposite lead when the source pose is genuine.

Shipped provenance: `DepartureFacingFixV1/GaitFixV1/lila_departure_ne_strip_gaitfix_v14_chroma.png`
(reinstates unique opposite half from `gaitfix_v12`; rejects `gaitfix_v13` which
duplicated frames 03–05 and froze mid-cycle). QA: `preview_v14_ne.gif`,
`qa_v14_atlas.png`.

## NW departure strip (chair→door)

`clientDeparturePath` seg 0 travels **NW**. Author a separate rear three-quarter
**upper-left** strip `lila_departure_nw_{00–07}` (bag stays anatomical left —
on NW rear that reads screen-right). Do not flip the NE strip. Processor:
`process_lila_departure_nw_v01.py`. Runtime `ClientActorNode.performExit` swaps
NE/NW strips per path segment via `ActorFacing` bins without mirroring.

## References

- Identity / scale: `Generated/Characters/Client/PreRendered3DV6/lila_key_sw_chroma_v06.png`
- NE facing key: `Generated/Characters/Client/PreRendered3DV6/DepartureFacingFixV1/lila_departure_ne_key_gen.png`
- Costume continuity: `Generated/Characters/Client/PreRendered3DV6/lila_arrival_sw_strip_rgba_v06.png`
- Broken one-leg shipping master (do not copy gait):
  `Generated/Characters/Client/PreRendered3DV6/lila_departure_ne_strip_chroma_v06.png`

## Outputs

| Asset | Path |
|---|---|
| Combined gen source | `Client/PreRendered3DV6/DepartureFacingFixV1/lila_departure_ne_strip_combined_gen.png` |
| Chroma master | `Client/PreRendered3DV6/lila_departure_ne_strip_chroma_v06.png` |
| RGBA master | `Client/PreRendered3DV6/lila_departure_ne_strip_rgba_v06.png` |
| Registered cells | `lila_departure_ne_{00–07}.png` in `Registered_v07/` + `LilaArrival.atlas` |
| Provenance / QA | `Client/PreRendered3DV6/DepartureFacingFixV1/GaitFixV1/` |
| Processor | `ArtSource/Processing/process_lila_departure_facing_fix_v01.py` |

## Final prompt nucleus (single pose)

> Same Lila March identity and BGEE pre-rendered avatar craft as the approved NE
> rear key. One complete figure on flat `#00ff00` chroma. Rear three-quarter
> northeast: back of emerald coat and navy beret dominant; faces and travels
> toward the **upper-right**. Handbag on anatomical left. Soft upper-left baked
> light. Ordinary restrained walk pose with the specified anatomical leg
> ownership (right-forward contact, left pass, left-forward contact, or right
> pass). Both shoes must be clearly placed. No floor, shadow, scenery, text, UI,
> high knee, rear kick, run, or whole-figure flip. Do not face upper-left /
> northwest.

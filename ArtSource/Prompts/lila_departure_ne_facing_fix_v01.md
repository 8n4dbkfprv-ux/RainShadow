# Lila March NE departure facing fix V1

Generated 2026-07-25 with the built-in Image Generator.

## Defect

The shipped V6 master `lila_departure_ne_strip_chroma_v06.png` is a rear walk
cycle, but every figure faces **upper-left (NW)** instead of **upper-right (NE)**.
`clientDeparturePath` travels NE toward the exterior door, so the exit sprites
read as facing against the path.

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

## Sheet contract

- Single horizontal row of **8 equal cells** on flat `#00ff00` chroma.
- Ordinary contact/pass walk gait with both legs alternating across the cycle.
- Shared ground line, body scale, and restrained bob; no high knee, rear kick,
  run, idle phase, or duplicated leg ownership.
- If the generator fails to pack 8 coherent cells, generate two 4-frame sheets
  (phases 0–3 and 4–7) with the same locked camera and identity.

## References

- Identity / scale: `Generated/Characters/Client/PreRendered3DV6/lila_key_sw_chroma_v06.png`
- Costume continuity: `Generated/Characters/Client/PreRendered3DV6/lila_arrival_sw_strip_rgba_v06.png`
- Wrong facing (same identity, opposite compass — do not copy direction):
  `Generated/Characters/Client/PreRendered3DV6/lila_departure_ne_strip_chroma_v06.png`
  (archived under `DepartureFacingFixV1/` after replacement)

## Generation note

Full 8-wide strips repeatedly collapsed to NW in the Image Generator. The approved
path was: lock a single NE rear key, generate two 4-frame NE halves from that key,
composite them into an 8-cell chroma master, then V7-process. Rejected NW 8-wides
remain under `DepartureFacingFixV1/` for provenance.

## Outputs

| Asset | Path |
|---|---|
| New chroma master | `Client/PreRendered3DV6/lila_departure_ne_strip_chroma_v06.png` |
| Combined gen source | `Client/PreRendered3DV6/DepartureFacingFixV1/lila_departure_ne_strip_combined_gen.png` |
| Archived wrong NW master | `Client/PreRendered3DV6/DepartureFacingFixV1/lila_departure_ne_strip_chroma_v06_nw_wrong.png` |
| Registered cells | `lila_departure_ne_{00–07}.png` in `Registered_v07/` + `LilaArrival.atlas` |
| Processor | `ArtSource/Processing/process_lila_departure_facing_fix_v01.py` |

## Final prompt nucleus

> Same Lila March identity and BGEE pre-rendered avatar craft as the approved SW
> key. Eight equal cells in one horizontal row on flat `#00ff00` chroma. Rear
> three-quarter northeast walk cycle: back of emerald coat and navy beret
> dominant; every figure faces and travels toward the **upper-right** of its
> cell. Handbag stays on anatomical left. Soft upper-left baked light. Ordinary
> alternating contact/pass gait, shared ground line, no floor, shadow, scenery,
> text, or UI. Do not face upper-left / northwest.

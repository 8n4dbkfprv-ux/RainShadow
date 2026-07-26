# Lila March NW departure strip V1

Generated 2026-07-25 with the built-in Image Generator.

## Defect

`clientDeparturePath` seg 0 (chair → internal door) travels **northwest**, but
exit playback only had `lila_departure_ne_*`. NE rear art on an NW path reads as
facing the wrong way.

## Contract

Reuse the V6 BGEE style lock from `character_prerendered_3d_v06.md` and Lila
identity from `lila_departure_ne_facing_fix_v01.md`, except:

- Pose: **rear three-quarter northwest** — faces/travels **upper-left**.
- Handbag stays on anatomical left (on NW rear this reads toward screen-right).
- Soft upper-left baked light; **no whole-figure flip** of the NE strip.
- Eight equal cells, alternating contact/pass gait.

## Outputs

| Asset | Path |
|---|---|
| Combined gen | `DepartureFacingFixV1/DepartureNW/lila_departure_nw_strip_combined_gen.png` |
| Chroma / RGBA | `lila_departure_nw_strip_{chroma,rgba}_v01.png` |
| Atlas cells | `LilaArrival.atlas/lila_departure_nw_{00–07}.png` |
| Processor | `ArtSource/Processing/process_lila_departure_nw_v01.py` |

Runtime: `ClientActorNode.performExit` selects NW vs NE strips from path-segment
`ActorFacing` bins without mirroring.

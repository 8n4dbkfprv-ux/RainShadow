# Office partition plate V1 — full-height authored wall + doorframe

- Status: shipping architecture path (replaces strip-painter `process_office_architecture_v01`)
- Process: `ArtSource/Processing/process_office_partition_plate_v01.py`
- Runtime: `office_partition_wall.png`, `office_partition_cutaway_mask.png`, `office_internal_door_leaf.png`

## Contract

One coherent alpha-backed plate registered to the shell (`4096×2304`), containing:

- Continuous **full-height** partition from the rear T-junction through and past the doorway
- Plaster, dark wainscot, chair rail, thin top trim matched to the shell
- Doorway **cut into** the wall (jambs, header, threshold, recess) — not a freestanding frame
- Transparent doorway opening (leaf is a separate prop)
- No baked half-height / waist-high continuation

Camera cutaway is a **separate mask**, not a physically shorter wall.

## Generation prompt (Image Generator)

```text
Use case: stylized-concept
Asset type: production registered architecture overlay for a fixed-camera isometric CRPG
Primary request: Paint ONE continuous full-height interior partition wall with an integrated doorway, registered to Image 1 (the RainShadow empty office shell). The partition runs from a clean T-junction on the rear wall toward the camera, parallel to the shell's north-east wall. The doorway is cut into the wall — left jamb, right jamb, header, threshold, wall-thickness recess — not a separate frame prop. Leave the door opening transparent/empty; the door leaf is a separate sprite. The entire partition stays full shell wall height for its whole length. Do not paint a low half-wall, railing, or waist-high continuation.
Input images: Image 1 is the approved RainShadow office_shell_base (authoritative for camera, plaster, wainscot, trim scale, grime, lighting, black exterior).
Registration: exact 4096×2304 (or 16:9 matching Image 1). Partition face on the shell floor-plan axis parallel to the right/rear doorway wall; doorway opening sized like the shell's exterior door.
Materials: match Image 1 plaster crack scale, wainscot height, chair-rail timber, thin top cap, grime density, contrast, and highlight direction. Soft late-1990s CRPG pre-render; no sharper/busier plaster than the shell.
Constraints: EMPTY ARCHITECTURE ONLY. No furniture, people, door leaf, UI, text, logos, watermark. Transparent outside the partition silhouette and inside the doorway opening. Pure black not required outside the wall — use transparency.
Avoid: half-height walls; freestanding door frames; graybox slabs; oversized caps; sharper plaster than Image 1; screen-axis rectangles; pasted module look.
```

## Outputs

| File | Role |
|---|---|
| `office_partition_wall.png` | Full-height visual plate |
| `office_partition_cutaway_mask.png` | Visibility mask (white = keep, black = hide upper camera-facing wall) |
| `office_partition_wall_cutaway.png` | Plate with mask applied (default gameplay) |
| `office_internal_door_leaf.png` | Leaf sized from the plate opening |
| `office_partition_opening.json` | Opening / hinge metrics for layout |

## QA

- Mask off: one coherent full-height wall; doorway cut into it
- Mask on: camera cutaway, not a real half-wall
- Leaf pivots on hinge jamb; dimensions match opening
- Rear T-junction reads constructed; materials match shell

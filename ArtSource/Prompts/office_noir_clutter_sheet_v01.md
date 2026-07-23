# Office noir clutter sheet V1

- Generated: 2026-07-23
- Mode: built-in Image Generator + Python normalize
- Retained master: `ArtSource/Generated/Office/Props/office_noir_clutter_sheet_chroma_v01.png`
- Shell dependency: `office_shell_base` for projection/light only

## Runtime IDs

| ID | Canvas | Notes |
|---|---:|---|
| `office_archive_box_a` | 384×384 | Closed worn archive box with tied folder; no legible text |
| `office_archive_box_b` | 384×384 | Sagging/open variant with paper edges; stacks near `a` |
| `office_wastebasket` | 256×256 | Dented wire or metal wastebasket with crumpled paper |
| `office_floor_trash_a` | 256×192 | Crumpled page/envelope cluster |
| `office_floor_trash_b` | 256×192 | Matchbook/string/paper cluster; no brands |
| `office_floor_trash_c` | 256×192 | Small alternate cluster for composition balance |
| `office_framed_photo` | 256×256 | Small turned/obscured personal photo; faces illegible at play scale |
| `office_hidden_bottle` | 128×256 | Partly empty unlabeled bottle |
| `office_pencil_tray` | 192×96 | Pencil, worn fountain pen, and shallow tray; no weapon |

## Layout

Strict **3×3** production sheet on flat chroma green `#00FF00`, equal cells, one prop per cell:

| | Col 0 | Col 1 | Col 2 |
|---|---|---|---|
| **Row 0** | archive box A (closed) | archive box B (open/sagging) | wastebasket |
| **Row 1** | floor trash A | floor trash B | floor trash C |
| **Row 2** | framed photo | hidden bottle | pencil tray |

Ground contact near the bottom of each cell. Upright props use a soft ground pivot near `(0.5, 0.04)` of the cell. Floor trash sits flat on the cell floor plane (2:1 dimetric ellipse footprint).

## Prompt

```text
Use case: RainShadow detective office P1 clutter prop sheet
Asset type: transparent isometric game props on chroma key
Primary request: Strict 3x3 production sheet of nine original film-noir detective-office clutter props on flat chroma green #00FF00. Equal cells. One prop per cell. Fixed 2:1 dimetric CRPG camera matching the attached RainShadow office shell. Painterly late-1990s pre-rendered CRPG materials, muted blue-charcoal and tobacco-brown palette, warm desk-lamp key from upper-left and cool rain-window fill. Row0: closed worn cardboard archive box with tied folder (no text); sagging open archive box with paper edges (no text); dented metal wire wastebasket with crumpled paper. Row1: three small distinct floor trash clusters (crumpled page/envelope; matchbook/string/paper with no brands; tiny alternate paper cluster). Row2: small wooden picture frame with turned/obscured personal photo (faces not legible); partly empty unlabeled dark glass bottle; shallow pencil tray with one pencil and one worn fountain pen. Each prop isolated in its cell, readable silhouette, modest wear, no baked contact shadows under floor trash.
Style/medium: late-1990s pre-rendered isometric CRPG prop art
Constraints: exact 3x3 grid; flat #00FF00 background only; no room walls, furniture, people, UI, logos, readable text, brands, weapons, or franchise copies; no perspective distortion; no modern PBR gloss
Avoid: labels, watermarks, extra objects, scenery, shadows baked as room ellipses, modern 3D look
```

## Processing

`ArtSource/Processing/process_office_noir_clutter_v01.py` slices cells, chroma-keys, trims, and writes manifest canvases under `RainShadow Shared/Resources/Art/Props/Office/`.

## Acceptance

- Each cell contains only its listed prop.
- No legible text, brands, or faces.
- Projection matches shell 2:1 dimetric.
- Reads as pre-rendered CRPG prop at play scale, not modern 3D.

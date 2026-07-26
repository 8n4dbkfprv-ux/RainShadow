# Office furniture core V2

- Generated: 2026-07-24
- Mode: built-in Image Generator + Python normalize
- Retained master: `ArtSource/Generated/Office/Props/office_furniture_core_sheet_chroma_v02.png`
- Shell dependency: `office_shell_base` (V6) for projection/light only
- Supersedes: secondary-sheet chair/cabinet/visitor chair + wall-props bookshelf V1

## Runtime IDs

| ID | Canvas | Notes |
|---|---:|---|
| `office_desk_chair` | 512×768 | Battered wooden swivel/office chair; rear-three-quarter matching NE desk |
| `office_filing_cabinet` | 512×768 | Dented tall four-drawer metal cabinet; closed drawers; no legible labels |
| `office_visitor_armchair` | 512×512 | Worn leather/wood visitor armchair; client-side of desk |
| `office_bookshelf` | 512×768 | Tall battered bookshelf with illegible book spines |

## Layout

Strict **2×2** production sheet on flat chroma green `#00FF00`, equal cells, one prop per cell:

| | Col 0 | Col 1 |
|---|---|---|
| **Row 0** | desk chair | filing cabinet |
| **Row 1** | visitor armchair | bookshelf |

Ground contact near the bottom of each cell. Soft ground pivot near `(0.5, 0.04)` of the cell for upright props.

## Prompt

```text
Use case: RainShadow detective office core furniture sheet V2
Asset type: transparent isometric game props on chroma key
Primary request: Strict 2x2 production sheet of four original film-noir private-detective office furniture props on flat chroma green #00FF00. Equal cells. One prop per cell. Fixed 2:1 dimetric CRPG camera matching the attached RainShadow V6 office shell. Painterly late-1990s pre-rendered CRPG materials, muted blue-charcoal and tobacco-brown palette, warm desk-lamp key from upper-left and cool rain-window fill. Row0 Col0: battered wooden detective desk chair (swivel or caster office chair), empty, rear-three-quarter view matching a NE-facing desk, modest wear. Row0 Col1: dented tall four-drawer metal filing cabinet, closed drawers, original blank label plates with no legible text. Row1 Col0: worn leather-and-wood visitor armchair, empty, classic private-eye client chair. Row1 Col1: tall battered wooden bookshelf packed with old books whose spines are illegible at play scale. Each prop isolated in its cell, readable silhouette, lived-in film-noir wear, no baked contact shadows.
Style/medium: late-1990s pre-rendered isometric CRPG prop art
Constraints: exact 2x2 grid; flat #00FF00 background only; no room walls, floors, other furniture, people, UI, logos, readable text, brands, or franchise copies; no perspective distortion; no modern PBR gloss
Avoid: labels, watermarks, extra objects, scenery, heavy baked floor ellipses, modern 3D look, ornate Victorian furniture
```

## Processing

`ArtSource/Processing/process_office_furniture_v02.py` slices cells, chroma-keys, trims, and writes manifest canvases under `RainShadow Shared/Resources/Art/Props/Office/`.

If `ArtSource/Generated/Office/Props/office_desk_chair_solo_chroma_v04.png` (or older solo fallbacks) is present, that solo plate replaces sheet cell 0 so the standing chair matches the NE seated bake (straight wooden 4-slat back, no swivel/casters).

## Acceptance

- Each cell contains only its listed prop.
- No legible text or brands.
- Projection matches shell 2:1 dimetric.
- Reads as pre-rendered CRPG prop at play scale, not modern 3D.
- Materials lock to V6 shell (tobacco wood, dented metal, worn leather).

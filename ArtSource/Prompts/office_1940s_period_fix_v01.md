# Office 1940s period-fix props V1

- Generated: 2026-07-29
- Mode: built-in Image Generator (edit/reference) + Python normalize
- Script: `ArtSource/Processing/process_office_1940s_period_fix_v01.py`

## Why

Runtime office props were period-checked against a 1940s private-eye suite.
Four anachronisms were remastered:

| Prop | Problem | Fix |
|---|---|---|
| `office_desk_ashtray` | Orange cork/filter-tip butts (mid-1950s+) | Unfiltered crushed white paper stubs |
| `office_waiting_ashtray` | Same (derived from desk) | Re-derived cool recolor of new desk ashtray |
| `office_wastebasket` | Styrofoam packing-peanut-like junk (1960s+) | Crumpled paper + torn envelope only |
| `office_case_board` | Red-string conspiracy web (modern TV trope) | Pinned photos/notes only, no string |
| `office_personal_washbasin` | No faucet/taps | Dual cross-handle aged brass taps + spout |

## Retained masters

- `ArtSource/Generated/Office/Props/DeskItems/office_desk_ashtray_1940s_chroma_v05.png`
- `ArtSource/Generated/Office/Props/office_wastebasket_1940s_chroma_v03.png`
- `ArtSource/Generated/Office/Props/office_case_board_1940s_chroma_v02.png`
- `ArtSource/Generated/Office/Props/office_personal_washbasin_1940s_chroma_v02.png`

## Runtime canvases

| ID | Canvas | Content height |
|---|---:|---:|
| `office_desk_ashtray` | 115×85 | 73 |
| `office_waiting_ashtray` | 115×85 | derived |
| `office_wastebasket` | 256×256 | native fit |
| `office_case_board` | 320×280 | native fit |
| `office_personal_washbasin` | 280×300 | 210 |

## Generation notes

Prompts locked to existing runtime props as style references, flat `#00FF00`
chroma, late-1990s pre-rendered isometric CRPG materials, and explicit 1940s
material constraints (no plastic, no filter tips, no red yarn, period plumbing).

## Acceptance

- No orange/cork filter tips in either ashtray.
- Wastebasket contains only paper/envelope clutter.
- Case board has no connecting string/yarn.
- Washbasin shows dual taps on the backsplash.
- Projection/scale matches prior runtime canvases.

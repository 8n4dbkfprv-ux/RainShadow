# Office window assembly V1

- Generated: 2026-07-23
- Mode: built-in Image Generator + Python normalize
- Shell dependency: `office_shell_base_v04` unglazed recess

## Runtime IDs

| ID | Canvas | Source |
|---|---:|---|
| `office_window` / `office_window_frame` | fitted alpha | `office_window_frame_gen_v01.png` |
| `office_window_exterior_view` | 1024×768 | derived dark rain fill behind glass |
| `office_window_glass_mask` | matched to frame | white where rain may draw |
| `office_window_sill_occluder` | fitted alpha | sill band from frame |

## Prompt (frame)

```text
Transparent isometric prop on flat chroma green #00FF00: worn wooden window frame with dirty fixed glass, rain-dark night exterior through panes, modest sill. Fixed 2:1 dimetric CRPG view. Painterly late-1990s pre-rendered noir office prop. No room walls, furniture, people, UI, or text. Glass opening ~ adult height.
```

## Processing

`ArtSource/Processing/process_office_window_door_v04.py` keys chroma, trims floor spill, writes runtime props and hover sources.

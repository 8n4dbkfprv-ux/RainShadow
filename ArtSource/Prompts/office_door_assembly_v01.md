# Office door assembly V1

- Generated: 2026-07-23
- Mode: built-in Image Generator + Python normalize
- Scale authority: BG:EE doorway/adult ratio **1.94** from `tmp/imagegen/bg_tavern_ref_door_close_v04.png`
- Shell dependency: `office_shell_base_v04` doorway opening (~375 px on 3840×2160 master)

## Runtime IDs

| ID | Canvas | Notes |
|---|---:|---|
| `office_door_frame` | 640×896 | Jamb/lintel/threshold ring |
| `office_door_leaf_closed` | 512×896 | Manifest closed leaf |
| `office_door_leaf` | fitted alpha | Legacy runtime name used by scene |
| `office_door_foreground_jamb` | 256×896 | Near occluder |

## Acceptance

- Leaf opaque height lands in body-multiple band **1.80–2.20** at `standardPropDisplayScale` (0.22).
- No readable business lettering on glass.
- Projection matches shell 2:1 dimetric doorway.

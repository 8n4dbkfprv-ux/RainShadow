# Office atmosphere overlays V1

- Generated: 2026-07-23
- Mode: built-in Image Generator + Python normalize
- Shell dependency: `office_shell_base` registration / light only

## Runtime IDs

| ID | Canvas | Blend | Notes |
|---|---:|---|---|
| `office_shadow_vignette` | 3072×2048 | multiply/alpha | Edge crush; keep desk island readable |
| `office_light_lamp_pool` | 1536×1024 | add | Warm irregular desk/floor pool |
| `office_light_window_spill` | 1536×1024 | add | Cool broken spill from west window |
| `office_floor_wear_decal` | 2048×1024 | alpha | Scuffs/stains; no object silhouettes |
| `office_desk_floor_shadow` | 1024×512 | alpha | Soft contact shadow under desk |
| `office_cabinet_floor_shadow` | 512×384 | alpha | Soft contact shadow under cabinet |

## Prompts

See generation calls; each asset is isolated on transparent or near-black field as appropriate.

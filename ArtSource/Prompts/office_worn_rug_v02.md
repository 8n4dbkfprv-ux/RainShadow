# Office worn rug V2

- Generated: 2026-07-24
- Mode: built-in Image Generator + Python normalize
- Retained master: `ArtSource/Generated/Office/Props/office_worn_rug_chroma_v02.png`
- Runtime: `RainShadow Shared/Resources/Art/Props/Office/office_worn_rug.png`
- Shell dependency: `office_shell_base` (V6) for projection/light only
- Supersedes: `office_worn_rug_v01`

## Runtime ID

| ID | Canvas | Notes |
|---|---:|---|
| `office_worn_rug` | 1024×768 | Thin worn rectangular/oval client meeting pad; low contrast; no contact shadow |

## Prompt

```text
Use case: RainShadow detective office client meeting rug decal V2
Asset type: transparent isometric floor prop on chroma key
Primary request: Single thin worn rectangular detective-office rug on flat chroma green #00FF00. Fixed 2:1 dimetric CRPG floor plane matching the attached RainShadow V6 office shell. Sized as a client meeting pad that can sit under a visitor armchair and the near edge of a detective desk. Threadbare tobacco-brown / muted oxblood weave with a faded quieter center and frayed edges, low contrast so it reads as a floor decal under furniture. Painterly late-1990s pre-rendered CRPG material. No furniture on the rug, no people, no baked contact shadow, no high-contrast medallion pattern that becomes noise at play scale.
Style/medium: late-1990s pre-rendered isometric CRPG prop art
Constraints: one rug only; flat #00FF00 background; soft alpha edges; no text, logos, ornate bright medallions, modern PBR pile, or room scenery
Avoid: heavy shadows, furniture silhouettes, high-contrast patterns, perspective distortion, tiny scatter rugs
```

## Processing

`ArtSource/Processing/process_office_furniture_v02.py` chroma-keys, trims, and fits to 1024×768.

## Acceptance

- Flat floor registration (not an upright prop).
- Low contrast; no baked contact shadow.
- Large enough to ground the visitor chair / desk foreleg meeting zone.
- Survives reduction to play scale without becoming noise.

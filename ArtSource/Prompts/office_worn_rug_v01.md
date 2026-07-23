# Office worn rug V1

- Generated: 2026-07-23
- Mode: built-in Image Generator + Python normalize
- Retained master: `ArtSource/Generated/Office/Props/office_worn_rug_chroma_v01.png`
- Runtime: `RainShadow Shared/Resources/Art/Props/Office/office_worn_rug.png`
- Shell dependency: `office_shell_base` for projection/light only

## Runtime ID

| ID | Canvas | Notes |
|---|---:|---|
| `office_worn_rug` | 1024×768 | Thin worn rug / floor decal; low contrast; no contact shadow |

## Prompt

```text
Use case: RainShadow detective office floor rug decal
Asset type: transparent isometric floor prop on chroma key
Primary request: Single thin worn oval/rectangular detective-office rug on flat chroma green #00FF00. Fixed 2:1 dimetric CRPG floor plane matching the attached RainShadow office shell. Threadbare tobacco-brown / muted oxblood weave with faded center and frayed edges, low contrast so it reads as a floor decal under furniture. Painterly late-1990s pre-rendered CRPG material. No furniture on the rug, no people, no baked contact shadow, no pattern that becomes noise at play scale.
Style/medium: late-1990s pre-rendered isometric CRPG prop art
Constraints: one rug only; flat #00FF00 background; soft alpha edges; no text, logos, ornate medallions, modern PBR pile, or room scenery
Avoid: heavy shadows, furniture silhouettes, high-contrast patterns, perspective distortion
```

## Processing

`ArtSource/Processing/process_office_noir_clutter_v01.py` chroma-keys, trims, and fits to 1024×768.

## Acceptance

- Flat floor registration (not an upright prop).
- Low contrast; no baked contact shadow.
- Survives reduction to play scale without becoming noise.

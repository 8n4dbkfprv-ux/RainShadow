# Dialogue command button V07 (sidebar-matched, no half-circles)

Date: 2026-08-01  
Generator: Cursor default Image Generator  
Idle master: `dialogue_command_button_plate_v07_gen.png`  
Runtime: `dialogue_command_button_plate_v07{,_hover,_pressed}.png` — 1024×116 RGBA

## Intent

Redo the CONTINUE / END DIALOGUE plate so it matches the V08 dialogue frame /
left HUD sidebar hammered gunmetal. No sunburst caps, half-circles, scallops, or
rounded corner flourishes. Runtime owns the label. Hover and pressed are
deterministic luminance/bevel derivatives of the idle silhouette so geometry
never drifts.

## Idle generator prompt

```text
Use case: ui-mockup
Asset type: production 2D game UI CONTINUE/END dialogue command-button plate.
Input images: Image 1 material authority (sidebar/frame gunmetal); Image 2 proportion authority (~8.8:1).
Primary request: Brand-new empty command plate cut from the same hammered gunmetal sheet. Thick multi-ridge beveled rectangular frame, dark calm face for a live label, sharp square/stepped corners only.
CRITICAL: NO half-circles, semicircles, sunburst caps, fans, scallops, or curved ornaments. Straight right angles only.
Background: flat uniform #00FF00 outside the plate. Text: none.
Avoid: gems, gold, leather squiggles, warm brown, attached frame, watermark.
```

## Deterministic states

`process_dialogue_command_v07()` chroma-keys the idle master, stretches to
1024×116, tone-matches to `hud_left_rail_plate_v03`, then derives:

- **hover** — lift face + boost bevel highlights
- **pressed** — darken face, invert local bevel polarity, 1px content inset

## Runtime wiring

`CaseIntroductionPresenter` prefers v07 idle/hover/pressed textures and tracks
command press through pointer down/drag/up.

# City district modular sprites V1

Generated 2026-07-19 with the built-in Image Generator. `city_district_block_v01.png` is the retained visual/layout reference. The original city plate is preserved for the map; the playable district uses a clean underlay plus isolated, depth-sorted modules. Baldur's Gate references were used only to study compact tactical-camera density and fog-of-war scale—never to copy UI, art, maps, or composition.

## Clean ground underlay

```text
Use case: stylized-concept
Asset type: 2:1 SpriteKit city-ground underlay
Create a clean empty version of this exact rain-soaked dimetric 1930s noir city block. Preserve the 2:1 composition, streets, curbs, sidewalks, cobbles, drains, wet blue reflections, amber reflection pools and navigation lanes. Remove every building, car, lamp, bench, statue, kiosk, crate, mailbox, fence, gate, sign and character completely. Leave only wet street and pavement surfaces, with natural empty contact areas for separate props. No fog, no UI, no text, no labels, no grid, no horizon, no watermark. Keep the same compact human-scale painted CRPG material language: dark charcoal, wet slate, midnight blue, restrained amber.
```

## Building sheet

```text
Use case: stylized-concept
Asset type: modular isometric architecture sprite sheet
Create one 3-column × 2-row production sheet of six isolated rain-darkened 1930s noir city buildings: a narrow fire-escape tenement, a corner storefront block, a long rowhouse, a low gate-side structure, a compact shopfront, and the detective-office corner building. Use the exact same fixed 2:1 dimetric camera, cool rain-wet brick, slate roofs, amber windows and compact CRPG density as the supplied city reference. Every building must be fully inside its own cell with generous empty green chroma surround. There may be no ground plane, street, shadow, character, car, lamp, bench, sign text, UI, border, label, watermark, or copied franchise element. Props must read at human scale; buildings should look like a dense playable block, not giant set dressing.
```

## Street-prop sheet

```text
Use case: stylized-concept
Asset type: modular isometric street-furniture sprite sheet
Create one clean 3-column × 3-row production sheet on a uniform vivid green chroma background. Cells, left-to-right/top-to-bottom: a tall cast-iron amber street lamp; a compact dark bronze statue on a stone plinth; a wet wooden bench; black 1930s sedan; olive-green 1930s sedan; deep maroon 1930s sedan; small newspaper kiosk; blue mailbox with three crates; short wrought-iron gate. Use one fixed 2:1 dimetric/isometric camera and the supplied rain-dark noir city material language: wet charcoal, blue reflections, worn brass and small amber light. Each prop must be entirely contained in its own cell, isolated with generous green clearance and no shared shadows. No street, building, scenery, character, UI, labels, readable text, logo, watermark, borders, or copied game assets. All objects must be compact enough to sit naturally beside a roughly 100-point player character at runtime.
```

The underlay output is `exec-2216f8c7-6126-45c0-a012-4cb7885c53ac.png`; the building sheet is `exec-b8ab5c22-4af9-4619-8a11-fb9f024c831c.png`; the prop sheet is `exec-e3921c1e-3356-4aab-b925-90f40da304b3.png`. Masters, chroma crops, and alpha derivatives live under `ArtSource/Generated/CityDistrict/ModularV1/`. The runtime underlay is `Resources/Art/Areas/CityDistrict/city_district_ground_v01.png`; fifteen independent modules are under `Resources/Art/Props/CityDistrict/`.

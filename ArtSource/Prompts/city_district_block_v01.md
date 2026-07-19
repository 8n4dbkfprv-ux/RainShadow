# City district block V1

Generated 2026-07-19 with the built-in Image Generator. The existing RainShadow office composite was the visual/material reference. Baldur's Gate exploration screenshots were used only to study tactical-camera density, the compact human-scale of environment props, and the semantics of a local fog-of-war reveal; no game UI, asset, map, or specific composition was copied.

```text
Use case: stylized-concept
Asset type: SpriteKit full-area background for a noir detective CRPG city district
Primary request: Create a single wide 2:1 dimetric/isometric game environment plate of a rain-soaked 1930s noir city block at night, with the detective's office entrance at the lower-right side and several connected walkable streets, an alley, a small square, stoops, shop awnings, fire escapes, lampposts, parked period cars, crates, newspaper stand, drainage grates, and wet cobblestones. The city must be materially larger than a single detective office: an open district with at least four times the navigable footprint, and multiple routes around blocking architecture.
Input images: Existing office image is a style reference; tactical CRPG exploration view guides the small human-scale environmental density and compact reveal radius, without copying a named game's assets or UI.
Scene/backdrop: dark rainy city at midnight, black unlit edges naturally suitable for a fog-of-war overlay.
Style/medium: painted high-detail isometric CRPG environment art, grounded film-noir realism, hand-painted textures, readable miniature street furniture.
Composition/framing: 2:1 dimetric angle; fill the entire 2:1 canvas with a cohesive neighborhood; no horizon, no UI, no labels, no framing, no characters; leave broad clear cobblestone navigation lanes between dense building footprints.
Lighting/mood: cool blue rain reflections with sparse warm amber lamps and windows.
Color palette: charcoal, wet slate, midnight blue, tarnished brass, restrained amber.
Materials/textures: wet cobblestones, cracked asphalt, brick facades, dark wood awnings, rusted metal fire escapes, rain sheen.
Constraints: Buildings and props must read small against a roughly 100-pixel-tall player character at runtime; doors about twice the character height, car height around one character, lampposts around three character heights. Architecture should be dense but all objects should retain small believable city scale. No oversized furniture or monumental street props. No readable text, logos, watermarks, people, monsters, or vehicles dominating the frame.
Avoid: any existing game UI, visible grid, title, text, oversized assets, aerial city panorama, close camera, fog painted over the center.
```

Runtime uses the generated 1774×887 plate at a 2× environment scale (3548×1774 world points), with a procedural black fog mask rather than baked fog. The generated master is retained at `ArtSource/Generated/CityDistrict/city_district_block_v01.png`; the app copy is `RainShadow Shared/Resources/Art/Areas/CityDistrict/city_district_block_v01.png`.

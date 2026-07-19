# RainShadow noir map icon V2

Date: 2026-07-19  
Generator: built-in Image Generator  
Generated source: `exec-411a33e4-1b87-40af-9fe9-c4ece5393141.png`

## Reference role

- Supplied vertical toolbar screenshot: compact landscape button proportion and compass-map concept only. No source pixels are shipped.

## Final prompt

```text
Use case: stylized-concept
Asset type: high-resolution game UI icon
Primary request: Redesign only the Map button from Image 1—the second icon from the top, showing a compass rose with a central letter N—as one standalone landscape icon for a noir detective game. Preserve its instantly recognizable compass-and-N concept while raising the detail, material quality, and noir atmosphere.
Input images: Image 1 is the sole style and composition reference; do not recreate any other buttons or the vertical toolbar.
Subject: an elegant eight-point compass rose forged from tarnished silver, with one large uppercase letter N centered over it. The N must be exactly "N", highly legible, and rendered only once. Add restrained engraved Art Deco linework to the compass points, appropriate to a mature 1930s–1940s detective-noir world.
Style/medium: highly detailed hand-painted game UI asset; grounded gothic-noir realism; polished production art, not a flat vector logo.
Composition/framing: a single horizontal 3:2 rectangular button, straight-on orthographic view, filling the canvas; clipped/beveled corners like the reference; thick battered pewter outer frame; deep recessed black inner plate; compass rose centered with generous breathing room; bold silhouette and readable values when reduced to roughly 165 by 110 pixels. No square canvas and no surrounding interface.
Lighting/mood: severe noir chiaroscuro; narrow cold sidelight catching the raised N and compass edges; black crushed shadows; subtle rain-slick gleam; ominous but refined.
Color palette: nearly monochrome charcoal, gunmetal, oxidized silver, smoked black; no bright colors and no gold.
Materials/textures: pitted pewter, fine scratches, oxidized recesses, dark aged enamel or leather backing; controlled edge wear, not excessive grunge.
Text (verbatim): "N"
Constraints: keep the old PC adventure-game tactile character of the reference; one icon only; perfectly centered; no map parchment, no scroll, no street map, no navigation pin; no other letters or numbers; no words; no watermark; no logo; no people; no toolbar; no background scene outside the button.
```

## Runtime contract

- Source master: `Generated/UI/Map/map_icon_noir_v02.png`, 1536×1024.
- Runtime derivative: `Resources/Art/UI/Map/map_icon_noir_v02.png`, 768×512.
- SpriteKit displays the texture linearly filtered at 108×72 points inside the existing 108×108 map-button hit target.
- Code retains hover scaling and adds a restrained highlight without altering the generated pixels.

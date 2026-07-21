# Character pre-rendered 3D V2 style lock

## Direction

RainShadow characters are authored as deliberately low-detail 3D maquettes, rendered offline into 2D orthographic sprite frames. The runtime look sits between painted pixel art and a modern high-detail 3D character:

- simplified, visibly faceted character geometry;
- low-resolution diffuse textures with broad tonal planes;
- baked diffuse light and ambient occlusion;
- smooth antialiased silhouettes with restrained raster softness;
- realistic, simplified anatomy rather than exaggerated pixel-sprite proportions;
- no hand-placed pixels, indexed-palette reduction, nearest-neighbor scaling, painterly brushwork, or modern high-detail PBR rendering.

The shared runtime contract uses a 512×512 transparent frame with a 200-pixel opaque standing body, displayed by SpriteKit at 256×256 points. This preserves the established 100-world-unit actor height while supplying 2× texture density for Retina rendering.

## Elias Vale key-pose prompt

Use case: style-transfer
Asset type: gameplay-scale style-lock render for a fixed-camera 2D isometric noir adventure game
Primary request: Re-render Elias Vale as a deliberately low-detail late-1990s/early-2000s 3D game maquette that has been rendered offline into a 2D sprite. Keep his identity, costume, southeast pose, camera, and chroma background, but simplify the model and materials substantially. Aim exactly between painted pixel art and a modern high-detail 3D render.
Style/medium: authentic low-detail 3D model source; simplified faceted head, hands, coat and shoes; modest polygon count; low-resolution diffuse texture maps; baked diffuse lighting and ambient occlusion; broad tonal planes; restrained texture detail. Rendered offline with clean but slightly soft antialiasing, then gently reduced as a 2D sprite.
Constraints: full-body orthographic 2:1 dimetric view on a perfectly flat #00ff00 chroma field; no floor, shadow, props, text, or watermark.
Avoid: modern PBR detail, painterly illustration, pixel art, nearest-neighbor edges, palette banding, posterization, outlines, cel shading, toy proportions, oversized hands or shoes, fedora, gun, or halo.


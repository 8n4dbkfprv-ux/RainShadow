# Sable Row window materials V11

V11 uses two new built-in Image Generator masters: `painted_wood_v11.png` and `glass_reflection_v11.png`, saved under `ArtSource/Blender/SableRowStudyV11/textures`. Exact generation prompts and original image paths are in `prompts.json` there. Both images are packed into the V11 Blender scene.

The frame shader now uses visible weathered brush-painted timber, roughness 0.82 and specular IOR level 0.22, with shallow relief. Existing UV grain follows each frame member. This replaces the uniform-looking V09 paint finish.

Inspection found that apartment backing panes had zero transmission, and roller blinds were in front of them. V11 retains those backings as the implied interior and adds 58 thin glazing sheets behind the projecting sash members but ahead of the blinds. A transparent/glass blend (glass IOR 1.52) carries a generated reflection-art layer; dark windows use more reflection than lit windows so warm interiors remain readable. Reflections are deliberately authored for the fixed game camera, not an exact physically traced image of the street. Their low emission strength is 0.04 in final plates; the initial checked crop used 0.18.

Historical basis: painted wooden sash and traditional glazing putty are documented by the National Park Service in [Wood Windows, History’s Eyewitness](https://www.nps.gov/articles/000/wood-windows-history-s-eyewitness.htm). These are plausible retained materials for older apartments in an early-1950s American district. The slight glass waviness and weathering are art-direction choices, not a claim that every 1950s pane was wavy or dirty. No PVC, modern insulated-glass spacer or tinted curtain-wall detailing was introduced.

The V10 wall clearance and embedded-lamp removal are preserved. No original mesh shape or building footprint was changed in V11; the new glazing surfaces are recorded in `glazing_record.json`. Live MCP operations are recorded alongside the scene. Day and night plates render at 6144×4608 with Cycles 64 samples and denoising; projection measurements are in `reviews/`.

This is a staged art deliverable. No runtime installation, fresh navigation bake or cover validation is claimed.

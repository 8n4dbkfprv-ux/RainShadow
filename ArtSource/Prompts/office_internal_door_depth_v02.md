# Plain internal door with hinge depth V02

- Generated: 2026-07-30
- Mode: built-in Image Generator edit + chroma-key removal
- Use case: `precise-object-edit`
- Runtime asset: `Resources/Art/Props/Office/office_internal_door_leaf.png`
- Runtime contract: 177×467 RGBA, matching the previous sprite canvas and anchor footprint

## Reference roles

- `RainShadow Shared/Resources/Art/Props/Office/office_internal_door_leaf.png` (pre-V02): edit target, projection, material, and texture authority.
- User office close-up (`Screenshot 2026-07-30 at 11.16.49 AM.png`): in-game scale and placement authority.

## Final prompt

Use case: precise-object-edit

Asset type: production 2D isometric/dimetric game sprite for the RainShadow detective office

Primary request: Redo only the open internal brown door so it reads as a solid hinged door with real depth instead of a flat billboard. Remove all lettering from the frosted upper pane. Keep it a plain, unmarked period office door.

Subject: The same 1940s dark brown wooden door leaf, same narrow open-door angle, same upper frosted-glass pane, same lower recessed wood panel, and same aged brass round knob. The knob is on the left; therefore the hinge edge is on the right. Add a narrow, clearly shaded wooden return/thickness face along the right hinge edge, a readable top edge thickness, and three small period-correct aged brass hinge barrels/knuckles on the right edge. Hinges must connect naturally into the door stile and project subtly so the pivot side is unmistakable. Use restrained highlights and contact shadows to show volume.

Style/medium: preserve the exact pre-rendered 3D painterly noir game-art style, aged wood grain, warm amber lighting, dimetric/isometric projection, pixel density, and realism of the edit target.

Composition/framing: isolated complete door leaf, full object visible with generous padding; maintain the same tall narrow proportions and perspective/skew as the edit target. Do not add a wall, frame, jamb, floor, room, plaque, or surrounding scenery.

Text: none. Absolutely no letters, names, numbers, signage, or writing anywhere.

Background: perfectly flat solid `#00ff00` chroma-key background for background removal. The background must be one uniform color with no shadows, gradient, texture, reflections, floor plane, or lighting variation. Do not use `#00ff00` on the subject.

Constraints: preserve the existing door design and silhouette closely except for the intentional right-edge depth and hinges; plain frosted/dirty amber glass with no decoration; crisp clean game-sprite edges; no cast shadow outside the object; no watermark.

Avoid: billboard/sign appearance, readable text, signage, oversized decorative hinges, modern hardware, front-on rectangular door, closed door, duplicate knob, door frame, environment, green spill.

## Outputs and fitting

- Chroma master: `Generated/Office/Props/office_internal_door_leaf_depth_chroma_v02.png`
- Keyed RGBA master: `Generated/Office/Props/office_internal_door_leaf_depth_rgba_v02.png`
- Fitted source: `Generated/Office/Props/office_internal_door_leaf_depth_fitted_v02.png`
- Canonical generated + runtime files: `Generated/Office/Props/office_internal_door_leaf.png` and `Resources/Art/Props/Office/office_internal_door_leaf.png`

The built-in chroma helper sampled the border field, applied a soft matte, and despilled the edge. The opaque subject was cropped and Lanczos-fitted back into the exact previous 177×467 canvas (visible bounds y=3…464), preserving the scene anchor and door-scale contract.

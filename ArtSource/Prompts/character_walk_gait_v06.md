# Character walk gait V6 correction

Generated on 2026-07-21 with the built-in Image Generator.

## Defect

V5 obtained its second half-cycle by rendering the opposite camera direction and
mirroring the complete figure. At final sprite scale, that construction still read
as the same screen-side leg repeating the contact and pass poses.

## Corrected construction

V6 keeps each diagonal/side camera locked and asks specifically for the two poses
of the opposite anatomical leg:

1. far/occluded leg forward contact, camera-side leg extended behind;
2. far leg bearing weight, camera-side knee and shoe swinging forward.

Those two poses follow the retained V5 camera-side contact/pass pair. South and
north remain valid under horizontal reflection because their camera axes are
bilaterally symmetric. Eastern gameplay facings continue to mirror the matching
western atlas in SpriteKit.

Because opposite anatomical contacts share nearly the same silhouette in a fixed
side or three-quarter camera, the processor also reverses the baked depth cue in
frames three and four: the far leading leg is deliberately darker, while the
camera-side returning leg is lighter. This prevents the two halves from reading as
the same screen-side leg repeating, especially after the 100px native downsample.

## Final prompt pattern

> Keep the exact character and exact locked directional orthographic view. Output
> exactly two separated figures: first, the far/occluded anatomical leg plants
> forward while the camera-side leg extends behind; second, the far leg bears
> weight while the camera-side knee and shoe swing forward. Both shoes must change
> location. Preserve identity, wardrobe, proportions, camera, scale, lighting, and
> the crude textured 500–900 triangle 1998 game-mesh style. Do not mirror or turn
> the whole character. Use a flat green chroma field with no floor or shadow.

The generated chroma and RGBA masters, registered cells, and previews live under
`Generated/Characters/Detective/WalkGaitV6/` and
`Generated/Characters/Client/GaitFixV6/`. The runtime still uses four frames per
direction, a 100px native body, 96 colors, 2x nearest storage, and 512x512 pivot
registration.

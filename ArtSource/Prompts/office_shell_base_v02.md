# Office shell V2 — panoramic Baldur's Gate-scale expansion

- Generated: 2026-07-19
- Mode: built-in Image Generator (`precise-object-edit`)
- Generator output: `exec-acbc7bd1-f24f-4ff6-93d7-f933acca91b1.png`
- Retained master: `ArtSource/Generated/Office/office_shell_base_v02.png` (1774×887)
- Runtime derivative: `RainShadow Shared/Resources/Art/Areas/DetectiveOffice/office_shell_base.png` (4096×2048)

## References

- RainShadow V1 empty shell, used as the authoritative material, projection, and feature-scale target.
- [Beamdog UI-scale discussion](https://forums.beamdog.com/discussion/72885/scale-the-ui-without-resolution-change), used to analyse Baldur's Gate: Enhanced Edition room-to-screen scale and multi-room footprint.
- [Beamdog Infinity Engine map-upscaling discussion](https://forums.beamdog.com/discussion/73868/upscaling-infinity-engine-maps-with-ai), used to analyse the irregular black fog-of-war silhouette.
- The first generated expansion study (`exec-d81083ba-e69c-4a74-a548-0b2ec5cb9c89.png`), used only as a floor-plan extension reference for the final targeted pass.

The Baldur's Gate images were style-analysis references only. The generated architecture is an original RainShadow location and does not copy a franchise room, prop, UI, or character.

## Final prompt

```text
Use case: precise-object-edit
Asset type: final empty 4096×2048 panoramic office environment plate
Primary request: Outpaint only the two solid-black vertical side gutters of Image 1. Continue the existing RainShadow office floor and built architecture into those gutters so the playable shell is wider at the same exact visual scale.
Input images: Image 1 is the edit target: a 4096×2048 canvas whose protected central 3072×2048 office must remain pixel-identical; only the 512-pixel black gutter on the left and the 512-pixel black gutter on the right may change. Image 2 is the previous generated expansion study for ideas about connected floor-plan extensions only. Image 3 is a Baldur's Gate: Enhanced Edition room-scale/footprint reference. Image 4 is an irregular fog-of-war edge reference; fog itself must not be painted into this base.
Scene/backdrop: extend the same original 1940s rainy film-noir office architecture.
Composition/framing: exact 2:1 panoramic canvas. Seamlessly continue the current 2:1 dimetric floorboards, wall lines, trim, cool/warm light falloff, and material texture outward into both side gutters. The added areas should read as modest connected side-office/corridor extensions at the same orthographic scale, providing more traversable floor. The protected center already contains the sole registered left window opening and right doorway opening; do not move, repaint, resize, duplicate, obscure, or reinterpret either opening.
Style/medium: match Image 1 exactly: original RainShadow late-1990s richly pre-rendered painterly isometric CRPG environment art, realistic worn wood and plaster, grouped detail and modest baked softness.
Constraints: Modify only the solid-black side gutters. Keep every pixel of the central 3072×2048 region unchanged with exact registration. No desk, desktop objects, furniture, chairs, cabinet, coat rack, radiator, door leaf, rugs, papers, files, boxes, wastebasket, bottles, photographs, people, characters, UI, fog overlay, selection circles, text, logos, or watermark. The added architecture must contain no movable-prop silhouettes or prop shadows. Preserve exact floorboard width, wall height, trim thickness, feature scale, camera projection, and lighting direction from Image 1.
Avoid: changing the protected middle; zooming; shrinking architecture; black gutters remaining inside the architectural footprint; extra windows or doors beside the protected registrations; copied Baldur's Gate room content; fantasy ornament; modern PBR or 3D-render sheen.
```

## Runtime treatment

- The generated 2:1 result is resized to the 4096×2048 SpriteKit area-plate limit.
- Existing prop and actor scales remain unchanged.
- The V1 3072-wide authoring coordinate system remains stable; the V2 plate extends 512 source pixels on each side.
- Fog-of-war is a separate runtime alpha mask with persistent reveal samples, solid-black unexplored space, and a feathered irregular edge.

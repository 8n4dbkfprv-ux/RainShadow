# Dash wind — October 11

Replaces the nine thin procedural arcs in `DashVisual` with five translucent,
textured ribbons. Two expanding sweeps surround the boots (the far sweep sits
behind the body); three smaller, staggered wisps drift up the sides. The texture
uses ordinary alpha blending, keeping the character readable without additive
bloom. Bear form retains its 1.35 scale. The longer dissipation completes within
the existing 0.9-second activation; movement rules and character atlases are
unchanged.

Every transform and opacity is sampled from the combat presentation clock.
Tactical pause and inventory therefore freeze the effect with the body. There
are no autonomous actions or emitters. One shared texture supplies five sprites.
Quads stay axis-aligned for the existing native world's direct sprite compositor;
the painted curve, mirroring, translation and expansion supply the motion.

## Generated asset

- Built-in `image_gen` tool, transparent-background generation (not CLI).
- Installed unchanged, including the original alpha, as
  `RainShadow Shared/Resources/Art/Combat/dash_wind_wisp_v01.png`.
- 1920 × 819 RGBA; alpha ranges from 0 to 253. Registered in both macOS and iOS.
- SHA-256: `78e7364d0709e0d600b0db98f4b1de1a12284503bf71e1e3f5aa48dbcdca77a7`.
- The native Dash QA additionally captures `dash-wind-<kit>.png` before the
  tactical pause colour grade, for inspecting the actual effect colours.

## Validation

- macOS Debug and iOS Simulator Debug builds pass.
- Native `DashAnimationQA`: 190 checks pass in
  `output/dash-wind-oct11-final/report.json`, including all seven equipment/form
  fixtures, loaded textures, pause/inventory, cleanup, run transitions and enemy
  Dash. Human and bear colour screenshots were inspected at gameplay zoom.
- `git diff --check` passes. Existing unrelated concurrency warnings remain in
  the build; no navigation, native renderer or approved character payload changed.

### Final prompt

Use case: stylized-concept. Asset type: transparent game VFX sprite for a brief wind gust around the feet and torso of a small isometric fantasy character. Generate ONE isolated horizontally elongated crescent of flowing pale ivory and faint icy blue wind, on a genuinely transparent background. A delicate, painterly ribbon of moving air, made of several fine flowing tapered filaments with a soft translucent mist body. Broad shallow upward curve like a swept brushstroke, fine tapered ends, irregular organic breakup, tiny detached wisps near the ends. Open airy interior; it is a curved streak, not a complete ring or vortex. Tasteful subdued fantasy RPG realism. Centered with generous transparent padding, occupies middle 75 percent of width and about 35 percent of height. No character, scenery, ground, objects, text, glow bloom, hard outline, sparkles, or opaque smoke cloud. Preserve subtle semitransparent feathered edges for alpha blending over dark and light game backgrounds.

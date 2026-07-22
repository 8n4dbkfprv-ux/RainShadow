# Character walk gait V7 correction

Generated on 2026-07-21 with the built-in Image Generator.

## Defect

V6 changed depth shading but retained nearly identical leg geometry in the side
and diagonal views. At runtime, the same screen-side knee or foot still appeared
to move in both halves of the cycle.

## Corrected construction

V7 requires a visible geometric change in frames 02/03:

- detective southwest and client southwest lift the opposite screen-side knee;
- detective west uses an alternate rear toe-off instead of repeating the forward
  knee pose;
- detective northwest and client northeast use an opposite-side rear toe-off,
  with the lifted heel outside the coat silhouette.

This makes both legs visibly participate even in projections where an anatomical
leg swap would otherwise produce the same silhouette. No lower-body compositing
or shading-only workaround is used. South and north keep their already-correct
bilateral alternation. Runtime eastern detective facings continue to mirror the
western atlas cells.

## Selected generator outputs

- Detective SW: `exec-a997a1d0-14ab-42e6-a399-a8abf7b2a921.png`
- Detective W: `exec-de2a4abb-0ad4-4e0f-82a3-7fb8c2dd56b0.png`
- Detective NW: `exec-20a979d0-27ce-473c-a905-0c6bce0413dd.png`
- Client arrival SW: `exec-e5d60705-7c94-4758-b555-2b9fbf2b125b.png`
- Client departure NE: `exec-a6243f15-ac21-40f4-bc3d-850bca61fbc0.png`

## Final prompt pattern

> Preserve the exact character, wardrobe, low-poly 1998 game-mesh rendering,
> scale, lighting, and locked camera. Produce exactly two complete sprites on a
> flat #00ff00 field. Do not repeat the supplied raised-knee silhouette. The
> alternate phase must visibly move the other screen-side leg: keep one leg
> planted while the other makes a clear rear toe-off with its bent knee and heel
> visible outside the coat silhouette. Do not mirror or rotate the torso.

Chroma and RGBA masters, registered cells, and previews live under
`Generated/Characters/Detective/WalkGaitV7/` and
`Generated/Characters/Client/GaitFixV7/`. `process_character_gait_v5.py` keys the
flat green source and retains the established 100px native body, 96-color ramp,
2x nearest storage, and 512x512 pivot registration.

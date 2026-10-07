# Physical barrel fragments — October 7

Barrels now break into fourteen independently moving pieces: six wooden staves,
four splinters, two lid halves and two iron hoops. Physical strikes scatter them
away from the attacker; explosions apply stronger outward and upward impulses.
Igniting a previously broken barrel lifts its existing pieces from their saved
resting positions. Fire, damage, chain reactions and character knockback retain
the existing combat rules.

## Simulation

`Gameplay/Navigation/BarrelDebrisPhysics.swift` is RainShadow cosmetic physics,
not a change to the GemRB navigation port. It integrates horizontal velocity,
height, gravity and angular velocity at 120 Hz. Ground impacts use restitution;
air drag, ground friction and angular damping dissipate energy until pieces sleep.
Iron bounces slightly more than wood. Small circular proxies allow landed pieces
to nudge one another. Terrain contacts reflect the blocked velocity component
and reduce spin. Substeps limit travel to three ground units to prevent tunneling.

The simulation uses the existing search-map cells for walls, map boundaries and
closed doors. It ignores actor occupancy, does not create new actor stamps, and
cannot cause damage, push characters, obstruct movement or ignite another barrel.
Walls are treated as vertical barriers; pieces do not jump over scenery. Cosmetic
fragment positions are continuous and separate from the port's integral actor
positions. No navigation, renderer, viewport or character-bundle authority changed.

The visual is a lightweight 2.5D simulation rendered with sprite fragments,
contact shadows and billboard tumbling, rather than mesh fracture or full 3D
rigid-body geometry. Each piece is depth-sorted by its ground position; height
raises only its image. Oil and scorch marks use overlapping soft patches.

## Timing and persistence

An accepted break simulates a bounded trajectory once against current terrain.
It stores final fragment poses in the optional `CombatBarrel.debris` field before
checkpointing the action. Cosmetic randomness uses a stable stream derived from
the barrel ID and break type, independently of combat's attack/damage RNG.

`CombatBarrelVisual` samples this trajectory from the same paused combat clock
as the bow and blast. Fragments appear at arrow impact, or when the physical
strike is accepted. Turns remain locked until fragments settle. Ignition can
relaunch a saved spill's pieces, including after reloading.

Reload goes straight to the accepted resting poses and does not replay physics
or damage. Older broken-barrel saves without poses keep their existing static
pile until another explosion creates physical fragments. Debris stays in the
current scene after combat, but post-encounter area re-entry does not persist it.
At most fourteen bodies per barrel and three seconds of trajectory samples are
allocated; playback releases the trajectory when complete and retains the sprites.

## Artwork

Built-in ImageGen produced the four-cell transparent atlas saved at
`RainShadow Shared/Resources/Art/Combat/oil_barrel_fragments_v01.png`.
The intact barrel was a material/style reference. The generated image is copied
unchanged; SpriteKit samples its four equal quadrants directly. There is no
image post-processing or character-art change. Both app targets include it.

Final generation prompt:

> Use case: stylized-concept. Asset: ONE transparent 2-by-2 sprite atlas for barrel destruction in a painted isometric fantasy RPG. Use the attached intact oil barrel as MATERIAL AND PAINTING STYLE REFERENCE ONLY; make a new atlas, do not include an intact barrel. Square canvas divided into exactly four equal invisible cells. Each cell contains exactly ONE separate isolated fragment centered within its quadrant, with generous transparent margins and no overlap across the central horizontal or vertical boundaries. TOP LEFT: a long slightly curved weathered brown oak barrel stave with jagged splintered ends, nearly vertical. TOP RIGHT: one shorter sharp oak splinter with fresh pale broken edges, diagonal. BOTTOM LEFT: one broken semicircular barrel lid piece assembled from three connected oak boards, visible thickness. BOTTOM RIGHT: one dark iron barrel hoop broken open into a C shape, bent, rusty with subtle edge highlights. Entire hoop fits its cell. All four pieces shown in shallow isometric perspective, camera elevated about 49 degrees, detailed realistic hand-painted oak grain and charcoal iron matching the reference, neutral daylight from upper left. True transparent background throughout, including holes inside the hoop. No floor, no cast shadows, no labels, no grid lines, no borders, no text, no flames or smoke. Four separate objects total, one per equal quadrant. The atlas will be sampled at exact half-width and half-height boundaries.

## Verification

Core tests cover gravity, repeated bounces, spin, friction, settling, stronger
explosions, walls, closed/open doors, map edges, several cosmetic seeds and strike
directions, deterministic samples, unchanged occupancy/combat RNG, saved endpoint
round-trips and relaunching a spill's existing pieces.

Live QA captures airborne fragments, physical-strike fragments and settled
remains. It checks impact timing, saved final poses, pause freezing both physics
samples and visible nodes, turn locking, matching final rendered/saved positions,
reload without relaunch, and player/enemy environmental attacks.


Validation passed: **75 core tests in eight suites**, **41 live checks**, and
both **macOS Debug** and **iOS Simulator Debug** builds. Live QA was on macOS;
iOS was compile-verified. The reviewed report and captures are under
`output/barrel-physics-final-qa`, including `barrel-fragments-airborne.png`,
`barrel-smash-fragments.png` and `barrel-aftermath.png`. The final endpoint-sampling
rounding safeguard is additionally covered across the 24-seed core regression.

Play using `Play Explosive Barrels.command`: click a nearby intact barrel for a
physical break, or select Fire arrow [5] and shoot an intact barrel or oil spill.

## Character-style contact shadows

Intact barrels, legacy debris piles and individual fragments now reuse
`ContactShadowFactory` and its shared soft texture. Opacity follows the NPC
contact-shadow weight and the same daylight/interior scene multiplier as the
encounter's characters. Footprints are sized to the barrel or fragment kind.
Fragment shadows stay at ground level, widen and fade with height, then tighten
and darken on landing. This replaces the original hard `SKShapeNode` ellipses.
Shadows sample the paused debris clock and are reconstructed on reload. The
character shadow factory, embedded character shadows and renderer ports are
unchanged. No new artwork is required.

Shadow verification: macOS and iOS Simulator Debug builds pass, and the existing
41 live barrel checks pass. Intact, airborne and settled shadows were visually
reviewed in `output/barrel-shadows-qa`; the change adds no physics or combat rules.

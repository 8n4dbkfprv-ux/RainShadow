# Explosive barrels and player fire arrows — October 7

The destruction visuals now use physical fragments; see
[BarrelDestructionPhysicsOct07.md](BarrelDestructionPhysicsOct07.md) for the current
simulation, artwork and persistence behavior. Static debris below records the
earlier implementation and remains the fallback for older saves.

New Wharf Ladder gate encounters stage two oil barrels where raster clearance,
actor spacing and firing lanes allow (one if no second clear location exists).
They have their own occupancy stamps and can be targeted by both sides.
Hovering previews the 120-unit blast radius and any reachable chain reaction.

## Playing

Use `Play Explosive Barrels.command` for a separate persistent demo save. This
preserves the main save and earlier combat playtest saves. Enter the shipping
office gate encounter, select **Fire arrow [5]**, then click a barrel or rival.
Clicking an intact barrel without aiming breaks it when within melee reach and
with a standard action available. This leaves broken wood and a flammable oil
spill. Select Fire arrow [5] to ignite either an intact barrel or spilled oil;
press 5 again to cancel aiming. The orange radius preview includes chained barrels;
walls can shield targets inside the displayed radius.

The encounter supplies the player bow action and implicit ammunition, matching
the lookout's initial ammunition policy. It does not consume or alter inventory
equipment. The shot temporarily presents the separate approved bow clip, then
restores Voss, his carried equipment and ground decorations. This first clip
supports unarmored human Voss; armor/helmet and Bear Form are explicitly rejected
instead of displaying incompatible equipment over the animation. Existing
combat saves retain their original barrels and weapon flags.

## Rules

- A stationary barrel is ignited automatically by a valid fire-arrow action.
  Range must exceed the existing 105-unit melee reach and not exceed 640 units;
  the shot requires a clear line and one standard action.
- Each barrel explodes once, dealing 3–5 nonlethal damage to every conscious
  combatant within 120 ground units with clear terrain between it and the blast.
  Friendly fire includes the shooter. Bear endurance absorbs damage first.
- A physical strike breaks an intact barrel without blast damage, spends a
  standard action, and removes its solid occupancy stamp. Human and bear forms
  can both break barrels; spilled oil remains targetable by fire arrows.
- Every conscious survivor is pushed up to 80 ground units (ten feet, about
  three metres), once per chain, away from the first blast that hit them. The
  entire chain deals damage at the original positions before any displacement.
  A straight raster query stops the push at walls, occupied space or map edges;
  it cannot route around a corner. Earlier endpoints reserve space for later
  pushes. Forced movement costs no movement allowance. Knocked-out actors keep
  the existing nonlethal removal behavior.
- Nearby barrels chain only across clear terrain. A visited set prevents cycles
  and repeat explosions. Each barrel in a chain has its own damage event, so
  overlapping blasts can hit the same actor more than once.
- Shot lines include other actors/props as blockers. Blast and chain lines use
  the same search-map raster with occupancy temporarily lifted: walls shield,
  people do not. The GemRB navigation/render ports are unchanged.
- The AI shoots a barrel only when the entire chain threatens an opponent and
  no conscious ally, including itself. Otherwise it uses its normal bow/melee
  policy.

Accepted actions save the broken/exploded states, HP, knockback endpoints,
budget and RNG together
before presentation. Barrel visuals, occupancy and visible damage change at
arrow impact. Fire, flash, expanding blast and smoke share the paused combat
clock, including the 0.35-second survivor push; turn advancement waits for the
effects to finish. The push updates the player movement origin as well as the
visible actor. Both forms keep their current footprint clearance. Reload uses the saved
endpoint without replaying damage or rearming barrels. Old saves decode absent
barrel data as an empty layout.

Broken debris survives active-combat save/reload and stays in the current scene
after combat ends. Post-encounter debris is visual only and is not restored on a
later area visit. There is no lingering ground-fire damage, barrel pickup,
smokepowder barrel variant or ragdoll simulation. Human physical strikes use the
existing brawl facing feedback; bears use their authored attack animation.
The existing game remains nonlethal: zero HP means knocked out, not killed.

## Artwork

The built-in ImageGen tool produced
`RainShadow Shared/Resources/Art/Combat/oil_barrel_v01.png`, retaining its alpha.
The original is also retained in Codex's generated-images folder. Runtime size
is 60×72 world units including transparent padding; the bottom anchor accounts
for that padding. The original character bundles remain unchanged.

Generation prompt: “Use case: stylized-concept. Asset type: single transparent
game prop sprite for a detailed painted isometric fantasy RPG. Primary request:
ONE upright squat wooden oil barrel, weathered oak staves, three dark iron hoops,
small faded ochre flame warning emblem painted on its front, closed wooden lid.
Camera orthographic, elevated 48.59 degrees above horizontal; visible circular
lid projects to an ellipse height 75% of its width. Warm neutral daylight from
upper left, subdued brown wood and charcoal iron, hand-painted realistic texture
that reads cleanly at 60 pixels high. Center the complete barrel with generous
transparent padding, no floor, no cast shadow, no other objects, no fire yet,
no text, no border, no watermark. This is a cutout prop, not a scene.
Transparent background.”

## Verification

Core tests cover rejection without spending/rolling, chain uniqueness, friendly
fire, wall shielding, bear endurance and accepted-action/legacy save behavior.
Live tests cover targeting, the player bow animation, pre-impact persistence,
pause, visual/occupancy cleanup, reload and the enemy's environmental targeting.
All **60 core tests**, **65 full live encounter checks**, and **19 focused live
targeting checks** pass. The final focused run includes player and enemy barrel
shots, explosion pause, raster cleanup and reload. Reports and visually reviewed
captures are under `output/barrel-combat-qa` and `output/barrel-targeting-qa-final`.
Both macOS Debug and iOS Simulator Debug builds pass. iOS is compile-verified;
the live playthrough was on macOS.

## Broken-barrel artwork and knockback verification

The built-in ImageGen tool produced the transparent debris sprite saved at
`RainShadow Shared/Resources/Art/Combat/oil_barrel_debris_v01.png`. The generated
PNG is preserved without pixel edits; runtime registration sizes it to 100×67
units and darkens it after ignition. Oil/scorch marks use a ground ellipse.

Generation prompt: “Use case: stylized-concept. Asset: one transparent isometric
fantasy RPG ground prop, the broken remains of a small weathered oak oil barrel.
Orthographic camera elevated 48.59 degrees, ground circles project to 4:3
ellipses. A compact low pile of splintered brown wooden staves, a broken circular
barrel bottom, two bent dark iron hoops lying partly flat, readable realistic
hand-painted texture matching a medieval dockside RPG. Entire debris pile
centered, lying on ground, much lower than an intact barrel. Neutral warm daylight
upper left. Isolated true transparent background, no floor, no shadow beyond tiny
contact darkness inside debris, no flames, no smoke, no characters, no text, no
border. Modest irregular silhouette with generous transparent margin. One object
only.”

The combat adapter handles same-cell visibility explicitly because the unchanged
GemRB line walker visits no cells for coincident endpoints. A character standing
on oil is therefore still exposed to its blast. The core tests cover physical
strikes, spill ignition and save/reload, survivor-only displacement, one push per
chain, unchanged movement budget, walls, occupancy, map edges and projected push
distance. No navigation-port behavior or character bundle was changed.

Final knockback/spill validation: **67 core tests in seven suites** and **32 live
checks** pass. Both macOS Debug and iOS Simulator Debug builds pass. The focused
live report and reviewed captures are in `output/barrel-spill-knockback-qa`,
including `barrel-aftermath.png`, `barrel-spill.png`, and
`player-knockback-aftermath.png`. This run covers both player and enemy pushes,
physical break and spill ignition, paused movement, matching visible/movement/
raster endpoints, and active-combat reload. The earlier 60/65/19 counts above
record the original fire-arrow release before this extension.
# Area scenery lifecycle — October 12

Oil barrels load with Wharf Ladder and the shipping-office interior, before
dialogue or enemy staging. The exterior uses fixed street seats at (1840,1840)
and (1920,1810); the interior retains the reviewed (430,410) floor position.
Actors route around their occupancy from the moment the scene is built.
Combat adopts those same nodes and states rather than spawning new barrels
around whichever position the player happened to approach from.

`CityDistrictScene` owns the scenery; `TacticalCombatDirector` borrows its nodes
for targeting and destruction. Combat completion returns the settled states to
the scene without removing intact barrels. `SaveSnapshot.areaBarrels` stores
area-keyed core payloads, alongside the tactical checkpoint, so destroyed props
stay destroyed after fleeing, finishing combat, loading or re-entering an area.
Round-based fire expires when combat ends, as before; wood and spilled oil remain.
Older saves default to unseeded scenery, and an active combat checkpoint takes
precedence over the area's stored state. Existing indoor placement repair runs
before the scenery is installed so its own occupancy cannot move it again.

Verification: 46 placement, persistence, explosion, debris and hazard tests pass.
Both macOS and iOS simulator builds pass. The native scenery test passes 12
checks covering arrival, dialogue, identical node handoff, destruction reload,
combat completion and return visits. Reviewed before/after images and the report
are in `output/barrel-scenery-oct12`.

The extended native destruction run is not fully verified. Its old fixture
assumed combat-generated barrels beside an enemy; the revised fixture explicitly
places a target beside fixed scenery with a certified knockback lane. The first
run confirmed fire-arrow impact, saved fragment endpoints, airborne debris and
reaction animation, but sampled a terrain-shortened shove after it stopped.
After correcting that fixture and pausing before the screenshot, two subsequent
launches timed out at initial area loading (before any checks). See
`output/barrel-scenery-destruction-oct12-complete/report.json`. No explosion or
knockback runtime was changed to accommodate the fixture.

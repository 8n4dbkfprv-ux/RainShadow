# Crowded combat staging — October 10

Reproduced from the user's round-two lane encounter: Voss at (1849,1935),
Hand 1 at (1912,1938), Hand 2 at (1848,1986). With all three occupancy records
present, lifting Voss's own stamp still left NPC flags (128) in his size-three
clearance disc. Routes west, south and southwest all failed despite open goals.

The staging adapter accepted centre distances of 60 units without testing the
combined actor stamps. Grid alignment meant those centres could still overlap
another actor's clearance cells. This is an encounter placement defect, not a
pathfinder defect.

WharfLadderStaging now temporarily stamps each proposed seat and checks the new
actor and all protected actors with their own stamp lifted. Accepted temporary
seats remain present during subsequent placement checks; all temporary records
are removed and real stamps restored before returning.

For existing saved fights, TacticalCombatDirector detects a blocked player
clearance caused by the crew (not static terrain). It keeps Voss fixed and
reseats only conflicting crew at nearby raster-certified positions before
presenting/checkpointing the fight. The screenshot fixture requires no more
than 32 world units per changed enemy. Health, initiative, round, random state
and action budget remain unchanged. An already-safe layout is unchanged.

No GemRB port behavior, actor footprint sizes, terrain, or pathfinding
clearance was changed. Enemy-occupied destinations remain blocked.

Validation: 118 tests across 17 suites; native verification of a separate copy
of the user's exact save; macOS and iOS Simulator Debug builds. Native report
and images: output/combat-movement-repair-oct10/. The user's save was read only;
its automatic spacing repair takes effect when reopened by the updated app.

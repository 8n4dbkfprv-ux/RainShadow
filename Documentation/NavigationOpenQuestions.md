# Navigation — open questions after the literal port

- Status: open; nothing here is blocking, nothing here is decided
- Date: 28 August 2026
- Related: [Pathfinding and NPC Locomotion](PathfindingSystem.md), [Third-party notices](ThirdPartyNotices.md), `AGENTS.md`

These are the things the GemRB literal port (`1b4c3cb2`) either uncovered or
deliberately left standing. Each says what is true today, why it was left, and
what a decision would look like — so this can be picked up cold rather than
re-derived.

Ordered by how much they could cost, not by how interesting they are.

---

## 1. The GPL derivation has no answer yet

**What is true.** The navigation stack is a transliteration of GemRB, which is
GPL-2.0-or-later. Not "inspired by" — the structures, control flow, constants and
much of the comment reasoning are ported. `Documentation/ThirdPartyNotices.md`
lists the files. RainShadow has no `LICENSE` file of its own.

**Why it is open.** Behaviour, algorithms and engine constants are not
copyrightable; expression is, and these files copy expression. Copyleft carries
obligations on distribution. This was flagged before the port and the instruction
was to proceed and record the provenance, which is done — but recording is not
deciding.

**What a decision looks like.** Either (a) accept GPL-2.0-or-later for the
project, or (b) get advice on whether the navigation module can be separated, or
(c) commission a genuinely independent implementation of the ~9 files, which
means giving up the fidelity that is the whole point of them. Worth real legal
input before shipping commercially, not a judgement to make from inside the repo.

**Update — the derivation has widened to the render path.** It now also covers
`IEBlit.swift`, `IEBlitShader.swift` and the per-actor tint in the two actor
nodes (`Documentation/ThirdPartyNotices.md`, "render pipeline"), with the wall
stencil and the draw queue planned to follow. Nothing about the question changes,
but **the cost of option (b) does**: a navigation module is a plausible thing to
lift out behind an interface, and a renderer is not. The ported pixel shaders sit
directly on the sprites the game draws, so separating them means separating the
thing that puts pixels on screen. If (b) was the intended answer, it is cheaper
to establish that now than after the stencil and the queue land.

**Update — and now to the camera.** `CameraZoom.swift` was already a
transliteration of `GameControl`'s zoom ladder; `AreaViewport.swift` adds
`MoveViewportTo`'s clamp. That is the viewport itself — where the player is
looking, at what magnification — so the derivation now reaches the three things
a player continuously touches: where the actor walks, what the sprites look
like, and what is on screen. Option (b) is not narrowing any further. Nothing
else about the question changes.

---

## 2. The six city `.sr.png` rasters are stale, and nobody owns them

**What is true.** `ArtSource/Processing/bake_area_searchmap.py` does not
reproduce the committed `city_*.sr.png` files, and **did not on `main` before this
change either** — I checked out `HEAD`'s version of the baker, ran it, and all six
rasters came back modified. They also carry roof and world-map-exit terrain that
baker cannot produce at all, so it is not simply out of date: it is not the
generator. Several other scripts write `.sr.png` (`build_city_ie_area_v04.py`,
`build_city_ie_monolith_v06.py`, `generate_city_ward_rebuild_v01.py`,
`city_ie_street_plan.py`, `build_city_ie_80x60_pages_v01.py`), and which one
produced the shipped rasters was not established.

Measured disagreement against a fresh conservative bake, per district: about
**9,100 cells blocked that the committed raster leaves open**, and about **8,700
blocked in the committed raster that the rectangles do not account for**. That is
mutual, so it is not a one-directional staleness — the raster and the authored
rectangles describe different cities in places.

**Why it does not bite today.** The runtime unions the authored rectangles into
the painted raster at load (`SearchMap.init(worldBounds:terrainIndices:…)`), so
whatever the raster says, every authored solid is also blocking. All six
districts are fully connected and every portal is exactly reachable.

**Why it is still a problem.** ~8,700 cells per district are blocked by the
raster alone, with no rectangle behind them. Nobody can currently say what those
are or regenerate them. If a plate is re-cut or a ward re-laid, there is no way
to re-derive the search map to match.

**What a decision looks like.** Find the owning generator, or declare the painted
rasters authored artefacts and stop pretending they are derived. `AGENTS.md`
records the "do not re-bake a city area" rule in the meantime.

---

## 3. Search is synchronous, and GemRB stopped being synchronous for a reason

**What is true.** A district-crossing search is ~23 ms in Release and ~4 s in a
`-Onone` build. The engine's 15-second wall-clock guard is the only bound. The
navmap-space line walk that `isWalkableTo` needs samples every cell a Theta\*
shortcut crosses, which is several times the tile walk it replaced.

**Why it was left.** Async is a threading strategy, not movement logic, and with
one or two actors it buys nothing. Porting `PathFinderScheduler`,
`FindPathRequestId`, the priority queues and the `FindPathScheduled` state is a
large architectural change to solve a problem we do not have yet.

**When it will bite.** Two ways. A 23 ms hitch is one dropped frame at 30 fps and
is fine for a player click; **N actors repathing on the same tick is not** —
`MovementOrderQueue.correctiveRepath` runs every 0.75 s per actor, so a crowd
scene multiplies it directly. And the debug figure sits inside the 15 s guard
with about 4× headroom; a larger map or a slower machine under parallel test load
could trip it, which reads as "the actor refuses to move" rather than as a
timeout.

**Cheaper things to try first.** Stagger `correctiveRepath` across actors the way
`Scriptable::ProcessActions` staggers scripts (`Ticks % 16 != globalID % 16`);
that is engine-faithful and costs nothing. Failing that, port the scheduler.

---

## 4. Resolved: interactions use `MinDistance`

**What is true.** `GetBlockedInRadiusTile` clears `PASSABLE` wherever an actor is
stamped, so `FindPath` moves a destination somebody is standing on rather than
walking onto it and bumping for the spot. This is the engine. RainShadow
previously tolerated an `ACTOR`-occupied goal on purpose, and the comment that
did so predicted this exact consequence.

**What it looks like in play.** In the office, the shared `office.desk` /
`office.phone` approach while the client stands over it: the walk ends one cell
short, 17–21 world units off. That is inside arm's reach.
`ActorFootprintTests.occupiedOfficeStillReachesEveryApproach` pins "on or beside".

**Decision — 4 September 2026.** RainShadow interactions now use `minDistance`,
matching the engine's weapon/dialogue/action range model. The authored approach
is still held exact by QA so proximity cannot conceal a point placed across a
wall, but runtime completion accepts two search-cell diagonals (40 world units),
GemRB's `MAX_OPERATING_DISTANCE` at the pinned upstream revision.
An interaction already in range completes without walking; an abandoned walk
does not run its completion. Plain floor clicks still refuse blocked terrain at
the cursor layer.

---

## 5. The north city arrival was moved by measurement, not by eye

**What is true.** `CityStreetPlan.arrivalPoint(from: .north)` moved from
`(4160, 3620)` to `(3368, 3620)`. The old point sat in the north-east plaza,
which the block grid closes off with a run of lots meeting corner to corner —
widest gap **11.6 units**, narrower than one 16×12 search cell and far narrower
than a person. Centre-sampled rasterisation left the odd cell centre free in that
seam, so the plaza read as connected; it never was, for anything person-shaped.

**What was not checked.** Whether the new point reads correctly *on the plate* —
that the detective arrives somewhere that looks like arriving from the north, at
a sensible spot in the painting, facing sensibly. It is on the north–south street
at the same 220-unit inset from the north edge, and it is exactly reachable, but
that is a navigation answer, not an art one.

**Also unresolved.** The plaza itself is now a sealed 1,569-cell enclosure. It is
the only authored point that was on the wrong side of it, so nothing else is
stranded — but if that space is meant to be reachable, the lots need widening,
not the arrival moving.

---

## 6. `circleSize` derivation is the one surviving adaptation

**What is true.** `NavigationAgentProfile.circleSize(forRadius:)` derives the
clearance disc from each profile's tuned world radius, rather than using
`personal_space` (4) the way the engine uses one number for both static clearance
and actor spacing.

**Why.** Routing 4 into static clearance replaces the office's 3-unit footprint
with a 32-unit disc and seals the room. BG can share one number because its
solids are authored at cell resolution and ours are an order of magnitude finer —
which was also the justification for the geometry conjunct that just came out.

**Worth revisiting** now that the raster is conservative and therefore coarser
than it was: the reason the two numbers had to differ is weaker than it was.
Measure before changing it; `officeReachabilityIsWhatTheRasterSays` is the gate.

---

## 7. Vestigial and duplicated state

Small, but they will confuse the next reader.

- **`NavigationAgentProfile.halfWidth` / `.halfHeight` no longer route.** They are
  persisted in `AreaDefinition`, they derive `circleSize` when one is not given,
  and QA measures with them — but the pathfinder never sees them. Removing them
  is a persisted-schema change, so it was left. Anyone reading the profile will
  reasonably assume they still matter.
- **The office has two navigation sources.** `OfficeNavigationLayout.makeGrid()`
  rasterises AABBs; `office_suite.area.json` loads a painted raster and unions the
  same AABBs in. They now agree cell-for-cell (`AreaParityTests` asserts it), but
  only because the load-time burn makes them. One of the two should eventually
  stop existing.
- **`SearchMap.segmentCrossesObstacle` / `discOverlapsObstacle` have no routing
  caller.** Kept for authoring and QA. They are the obvious thing to reach for
  the next time something clips, and reaching for them is the mistake — see
  `AGENTS.md`.

---

## 8. Not ported, listed here so it is not re-discovered

Full reasoning in `Documentation/PathfindingSystem.md` under "Deliberately not
ported". Summarised: the async scheduler (§3 above); `Actor::WalkTo`'s
`ResetPathTries`, which is an upstream bug that makes `MAX_PATH_TRIES`
unreachable; `BumpBack`'s `IE_EA < EA_GOODCUTOFF` gate, which needs an alignment
axis RainShadow does not have; and `RandomWalk`'s action-queue branches, which
need an action queue RainShadow does not have.

`moveLine`, `randomWalk` and `runAwayFrom` are ported and tested but have **no
caller yet**. They exist so the next NPC behaviour does not have to invent them.

---

## 9. Shipping BG:EE gradient tables is a decision, not a question

**What is true.** `RainShadow Shared/Resources/Art/IE/pal16.bin` and
`pal256.bin` are BG:EE's `MPALETTE` and `MPAL256` gradient tables, extracted
byte-for-byte from a retail install by
`ArtSource/Processing/extract_ie_gradients.py` and shipped in the app bundle.
They are Beamdog/BioWare data. Nothing about them is original.

They are there because the character colour model is a literal port of GemRB's,
and GemRB's `SetupPaperdollColours` colours a character by indexing exactly
these tables. Deriving equivalent gradients from our own art was the alternative
and was explicitly not chosen.

**Why it is listed here.** This contradicts a rule the project had already
written down. `ArtSource/Processing/extract_ie_reference.py`'s docstring says
its output is "composition reference only … never composite, trace or ship any
part of it", and that "everything under `RainShadow Shared/Resources/` must be
original". That rule still holds for area art; it no longer holds for these two
files, and the exception was made knowingly rather than overlooked.

**What a decision would look like.** Either (a) accept the exception and record
it in whatever licence the project eventually adopts alongside the GPL question
in §1 — noting these are *data*, distributed unmodified, which is a different
kind of claim from the GPL derivation; or (b) refit the seven gradients per
character from RainShadow's own masters using GemRB's `Palette(color, back)`
interpolation, which is already ported in `IEPalette.swift`, and delete the
`.bin` files. (b) costs a rebake and some craft; nothing else depends on the
choice.

Note that §1 and this are **separate** exposures: §1 is about copying GPL'd
*expression*, this is about redistributing a publisher's *data*. Answering one
does not answer the other.

---

## 10. Near Infinity adds a third licence, and it is not GemRB's

**What is true.** `ArtSource/Processing/ie_resample.py`,
`ArtSource/Processing/ie_colorconvert.py` and
`RainShadow Shared/Gameplay/Navigation/IEResample.swift` are transliterations of
Near Infinity, which is **LGPL-2.1**. The navigation and colour-model ports are
transliterations of GemRB, which is **GPL-2.0-or-later**. The gradient tables in
`RainShadow Shared/Resources/Art/IE/` are BioWare data (§9).

Three distinct obligations now, from three sources, in one binary.

**Why it is listed here rather than decided.** LGPL-2.1 is usually described as
the "linking" licence, and that framing does not apply cleanly to what was done
here: this is not linking against a library, it is copying expression out of one
and rewriting it in another language. A transliteration of LGPL source is a
derivative work of it in the same way the navigation stack is of GemRB's. Whether
LGPL-2.1's relink provisions can be satisfied by a project that has *inlined* the
code rather than linked it is exactly the question, and §1 does not answer it
because GPL-2.0-or-later and LGPL-2.1 are different instruments.

**What a decision would look like.** Either (a) settle all three together when
the project picks a licence — noting GPL-2.0-or-later is the strictest of them
and would likely dominate; or (b) drop the Near Infinity derivation specifically.
(b) is cheaper than it sounds and cheaper than the GemRB equivalent: Super xBR is
one enlargement step with a measured alternative already in the tree (nearest,
which is what ships today), and CIE94 is a published formula whose Near Infinity
implementation is a straightforward reading of it. Neither is load-bearing for
correctness — they are load-bearing for how the character *looks*.

Nothing here blocks the bake. It is on the record so it is not discovered later.

# Combat movement preview and explicit Dash — October 9

The final movement overlay uses a thin white route, red excess distance, a simple
projected destination circle, and compact white text with a dark shadow. It is
inspired by BG3’s PC preview. The earlier ornamental brass ring, warm colours,
pulse, and framed caption have been replaced. The parchment action bar remains.

`UI/CombatMovementPreview.swift` renders the exact points returned by
`CombatNavigation.route`, including its actual endpoint. Distance uses
`CombatNavigation.distance` with the 0.75 ground projection and eight world units
per foot. No pathfinder, collision, or movement interpolation behaviour changes.
Only already available movement is shown in white. Over-range destinations stay
red until the player explicitly uses Dash; clicking an unaffordable destination
rejects the whole move without spending movement or actions.

## Dash

The labelled Dash button appears in both human and bear action bars. It costs
one standard action and adds the actor’s current movement speed, including
slow effects, to the remaining movement. A fresh normal-speed turn has 30 ft,
becoming 60 ft after Dash. Partial movement is preserved. Dash cannot be used
again without another action, and it does not move the actor automatically.
Its tooltip explains the cost; the control dims once the action is spent.

`CombatBudget` retains the pinned TemplePlus transition table unchanged. The
RainShadow adapter now offers a move charge only when it preserves the standard
action; `dash(speed:)` explicitly spends that action and credits movement.
Existing Codable fields hold the result, so old mid-turn saves keep their spent
actions and remaining movement. A new turn resets normally. This is a deliberate
RainShadow gameplay adaptation, not a claim that TemplePlus itself uses BG3 rules.
Existing full-turn attacks retain their established cost.

Enemy melee pursuit explicitly chooses Dash when it cannot attack and a certified
approach route exists. It never relies on `move` silently converting an attack.

The preview clears during attack targeting, invalid ground, HUD hover, inventory,
pause, movement playback, enemy turns, and encounter completion. Stroke widths
and text compensate for camera scale. Mouse/pointer hover is the existing input
mechanism; touch-only devices do not gain a new two-tap movement mode.

## Art provenance

The earlier generated `combat_destination_ring_v01.png` and exact prompt in
`CombatPathlineArtOct09.json` are retained as prototype artifacts. The final
simple circle is drawn in code and does not load or bundle that artwork.

## Verification

- Both macOS and iOS Simulator app targets build.
- Focused core tests cover explicit action spending, atomic move rejection,
  partial movement, Dash before/after movement, invalid/repeated Dash,
  save/reload, enemy turns, bear form, slowed speed, and old budget snapshots.
- `RAINSHADOW_QA_PATHLINE_ONLY=1` runs native route geometry, preview clearing,
  real movement cost, Dash button, repeated-click, and playback checks.
- `RAINSHADOW_QA_ACTION_BAR_ONLY=1` checks all seventeen human controls, seven
  bear controls, tooltips, and narrow layouts.

Final October 9 results: 67 focused core tests, 33 native movement/Dash checks,
and 43 native action-bar checks passed. Captures and reports are in
`output/combat-dash-oct09/` and `output/combat-dash-actionbar-oct09/`.

Use `Play Combat.command` to rebuild and test. An already running process must
be relaunched. Hover over the ground during your turn; click Dash on the action
bar to extend the white part of the route, then click a reachable destination.

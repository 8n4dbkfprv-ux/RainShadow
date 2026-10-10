# Move then attack — October 10

Selecting a weapon attack and hovering a visible rival now previews an approach
when the attack cannot be performed from the current position. The existing
white route and destination ring show the walk and stopping position. The
parchment card shows its movement cost and the attack's hit chance/damage from
that destination. Clicking once walks there and then performs that same attack.
Ordinary enemy clicks use the same melee approach behavior.

`CombatAttackPlanner` is an adapter above the unchanged GemRB navigation port.
It proposes deterministic endpoints around the target, then uses the existing
`CombatNavigation.route` and `clearLine` to certify the route and firing lane.
It evaluates movement/action costs and the arrival forecast on a copy of the
combat state. Human and bear clearances use their existing navigation profiles.
Target-hover plans are cached against the combat state and exact attack order;
a click recomputes the plan before committing.

- Movement never silently spends the attack action or activates Dash.
- Aimed Shot cannot approach: it requires the full turn before moving.
- Ordinary bow attacks can seek a clear firing position, including backing away
  from a too-close target under the current bow minimum-range rule.
- Sneak Attack keeps its existing automatic weapon selection. Its forecast
  accounts for losing stealth along the route and recomputes advantage and
  eligibility at the destination.
- Weapon techniques and selected ammunition stay attached to the pending order.
- Failed plans cause no partial movement or resource expenditure.
- Arrival checks the actual position, target, line, equipment/action eligibility
  again. It never starts another approach if movement stopped early.
- Escape/right-click during the walk cancels the follow-up attack; already
  accepted movement finishes and remains spent. Opening inventory also cancels
  the pending attack. Combat pause freezes the existing movement presentation.
- As with ordinary movement, saves checkpoint its accepted endpoint and cost.
  The pending attack is presentation-local: reloading restores the movement but
  does not fire an unperformed attack or replay an already resolved attack.

This applies to combatant weapon attacks and bear claws. Shove, barrels and
self/area abilities retain their existing interaction.

Validation: `CombatAttackPlanTests` covers arrival forecasts, occupancy/RNG
preservation, full-turn restrictions, range/cover, insufficient resources, bow
retreat, and stealth lost on approach. The native `RAINSHADOW_QA_APPROACH_ONLY=1`
branch verifies the displayed destination against actual arrival, a single-click
walk/attack, delayed attack spending, technique preservation and cancellation.
Screenshots and report: `output/combat-approach-oct10/`.

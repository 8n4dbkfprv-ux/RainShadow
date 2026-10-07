# Fire-arrow Burning — October 7, 2026

Successful ordinary fire-arrow hits now apply Burning to a surviving target.
This is a RainShadow combat rule inspired by the requested distinction between
an impact flash and a continuing fire condition; it is not a BG3 rules port.

- The initial strike keeps its existing damage. Burning rolls 1d4 at the end of
  each of the affected actor's next two turns. There is no real-time HP drain.
- Another fire-arrow hit refreshes the two ticks instead of stacking burns.
  Misses, Aimed Shot, Pinning Shot and explicitly selected Sneak Attack do not
  ignite the target. Existing barrel explosions keep their existing rules.
- The HUD labels Burning and its remaining ticks. Extinguish spends one standard
  action and immediately removes the condition. An enemy at eight or fewer HP
  uses this option when it has an action available. Burning prevents Hide.
- Bear endurance absorbs burn damage before human HP, including forced reversion
  when the temporary pool reaches zero. Damage preserves the encounter's
  nonlethal knockout rules and skips unconscious actors in initiative.

`TacticalCombat.swift` owns damage, duration, action costs and the optional
`Combatant.burningTurns` checkpoint field. Older saves omit it. Durations outside
1–2 are rejected. An accepted arrow strike saves Burning before animation begins;
loading resumes the accepted result without replaying either impact or a tick.
The optional `endTurn(burningHit:)` callback reports the exact rolled tick to
presentation, including damage absorbed by Bear Form.

`BowShotPresentation.swift` adds a 0.45-second flame burst to successful fire
impacts and defines `CharacterBurningVisual`: a fixed pool of flame, smoke and
ember sprites sampled by the combat clock. The director reveals the persistent
effect at impact and reparents it to the visible actor, reaction, weapon or bear
proxy. Flames move with the character. Pause freezes all particle motion; the
existing world greyscale remains active during tactical pause. Expiry,
extinguishing, knockout and encounter completion remove the effect. No emitters,
wall-clock damage timers, new character atlases or changed navigation/render-port
algorithms are involved.

## Verification

- 88 focused core tests passed, including seven new Burning tests covering hits,
  misses, ordinary-arrow techniques, delayed ticks, expiry, refresh, action
  rejection, Bear Form absorption/reversion, knockout, legacy saves, invalid
  durations and deterministic save/reload.
- macOS and iOS Simulator builds succeeded.
- Live SpriteKit QA: `RAINSHADOW_QA_BURNING_ONLY=1` with `RAINSHADOW_QA_COMBAT` set
  to an output directory exercises both player and enemy hits, impact timing,
  visible reaction proxies, pause, in-flight checkpoints, reload, Extinguish,
  enemy self-preservation, walking and natural expiry.
- Final live results: 33 checks passed in `output/burning-qa-final/report.json`;
  48 existing barrel, destruction and knockback checks passed in
  `output/burning-barrels-regression/report.json`. Colour captures were visually
  reviewed, including the resting player and the enemy impact.

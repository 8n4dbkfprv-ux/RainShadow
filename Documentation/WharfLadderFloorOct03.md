# RainShadow · Act I Beat 3 · Wharf Ladder A1 floor: pre-fight exchanges (approved 3 Oct 2026)

**October 5 runtime update:** These graphs are now registered and playable through Story combat. See [integration, state contracts and validation](WharfLadderStoryCombatOct05.md). The October 3 integration-gap notes below are retained as the original writing hand-off.

**Status in the repo (branch `grokbot/wharf-ladder-floor`, based on main `d5d183f`):** the three graphs ship in `RainShadow Shared/Resources/Dialogue/` and their 40 keys are merged into `strings.en.json`. Like `case.wharf-ladder` (PR #32), they're **unregistered**: there's no Swift facade, they aren't in the shipped catalog test, and nothing presents them. The GDD change is applied directly in the same PR. The same PR adds one Warm-path Merrick line to `wharf-ladder.dialogue.json` that grants the tide-gap timing.
There are three graphs: `case.wharf-ladder.gate`, `case.wharf-ladder.lane` and `case.wharf-ladder.clockroom` (22 nodes in all), plus 40 new string keys (none clashing with main). In the design pack, the GDD change is `gdd-a1-order.patch`. This script is generated from the JSON by `render_floor_script.py`.

**How to read this.** `(thinking)` marks Voss's interior monologue; otherwise Voss speaks only through his reply choices (GDD §7.5). `[tone/intention]` is metadata. "sets" lists the case flags a choice writes. Every ending hands off to the fight resolver, or on a return visit to a quiet crossing.

## First visit order (Laurens's decision)

Night gate (A1) → lost-crate lane (A1) → clock room (A1 core) → Merrick (`case.wharf-ladder`, opens only after `combat.a1.clockroom.done`) → back room (E1, Ketch and Bram).

On the first visit the gate, the lane and the clock room **always fight**. Each group gets a short exchange first: 2 or 3 bark lines, one Warm/Dry/Sharp reply, then one answering line. All three replies lead to the fight; the reply only colours how it starts.

## Head counts (confirmed by Laurens)

| Group | Heads | Notes |
|---|---|---|
| A1 gate | **2** | Two tally-men. Both speak. |
| A1 lane | **2** | Two crate hands. The outer groups stay lighter than the core. The crate chit with the crate mark drops on the first lane fight only. |
| A1 clock room | **3** | Hobb (working name), the man paid to keep the clock fast, and two hands. One hand speaks. |
| E1 | **2** | Ketch and Bram (unchanged). |

## Flags for the resolver

| Flag | Set by | Meaning for the resolver |
|---|---|---|
| `combat.a1.<group>.trigger` | every first-visit reply (and any return visit without the quiet condition) | Start this group's fight now (or auto-resolve it). `<group>` is `gate`, `lane` or `clockroom`. |
| `combat.a1.<group>.opening.firstBlow` | the Sharp reply | Voss strikes first: a free opening action, or initiative to Voss. |
| `combat.a1.<group>.opening.rattled` | Dry at the gate and the lane, Warm in the clock room | One enemy starts rattled. His morale breaks a step early: he quits when the first man drops. In the clock room it's Hobb, who wavers. |
| *(no opening flag)* | Warm at the gate and the lane, Dry in the clock room | A standard start. The crew takes the courtesy, or the joke, as weakness. |
| `combat.a1.gate.walkedPast` | the return-visit Merrick route | No fight. Merrick walks him past. Mark the gate done. |
| `combat.a1.lane.slip` | the return-visit tide-gap route | Run the lane as a sightline slip (GDD §4.3.5: a peeled outer group is a slip). If he's seen, start the lane fight. |
| `combat.a1.clockroom.letPass` | the return-visit interval route | No fight. Hobb steps out. |
| `combat.a1.gate.done`, `combat.a1.lane.done`, `combat.a1.clockroom.done` | **the resolver** | The group is crossed. `combat.a1.clockroom.done` is the flag the Merrick conversation already waits for. **It's set whether the clock room is won or lost.** On a loss, Voss wakes bruised outside the clock room and can still go on to Merrick. |
| `evidence.a1.lane.chit` *(working id)* | **the resolver**, first lane fight only | The chalk chit with the crate mark. Return-visit lane fights drop nothing (repeat crews drop nothing). |
| `evidence.a1.clockroom.chalk` *(working id)* | **the resolver**, clock-room fight won | The night's chalk (peels the Act II yard). The fight does **not** grant the interval. |
| `knowledge.nightClock.interval` *(working id)* | **side case 04** | The interval: the minutes Hobb is away. It opens the clock room's return-visit quiet route. |
| `knowledge.wharfLadder.tideGap` *(working id)* | **Merrick, Warm path** (`merrick.tidegap` in `case.wharf-ladder`) | The tide-gap timing. It opens the lane's return-visit slip. |

Only one opening flag is ever set per fight. Knockout is the default throughout.

## Judgement calls

1. **Three graphs, not one with three entry points.** The loader picks the first entry node whose condition passes. One graph can't tell which door Voss is standing at without extra location flags. Three graphs let the scene open the right one by id. Each graph's start node is the first-visit bark (start nodes can't carry conditions), and its single entry candidate is the return-visit quiet route.
2. **"First visit" means `wharf-ladder.case.visited` isn't set.** The Merrick graph sets that flag at the end of the first talk. Every quiet entry also requires it, so a quiet route can never fire on the first visit, even if knowledge somehow arrives early.
3. **The quiet routes are entry nodes, not hidden choices.** When the condition holds, the group lets Voss through, or for the lane Voss times the gap, without a menu option to start the fight anyway. Each has one reply and one closing line, so the format can record a flag; an ending node can't set flags.
4. **The gate's quiet route needs only `wharf-ladder.case.merrick-paid50`.** In the merged Merrick graph, paying always leads to the Warm branch, and every Warm exit avoids E1. So a paid Merrick is never a Merrick who saw a fight.
5. **The clock room plants the night's chalk** ("The chalk on that wall says tonight's a fast night"). The dialogue grants nothing. The fight buys only the chalk; the interval comes from side case 04 (decision 3).
6. **One working name: Hobb.** He's the clock-keeper and the core's named man, and he may recur in side case 04's clock loft. I checked the name against the GDD and `strings.en.json`. The gate and lane crews stay unnamed ("Tally-man", "Crate hand") because they're replaced by morning.
7. **New working ids:** `knowledge.wharfLadder.tideGap`, written by Merrick's new Warm-path line, and `knowledge.nightClock.interval`, which side case 04 still has to write.
8. **Reused design-pack lines.** "Your clock's a liar. Three minutes' worth." (Voss, Dry, from the combat-02 pack) is used. "Office is closed. Clock says so." isn't.
9. **Placeholder portraits:** `dialogue_portrait_chalk_crew_v01` (shared by the crews) and `dialogue_portrait_hobb_v01`. Merrick reuses his existing placeholder key. No VO.
10. **Typography.** Dialogue strings use straight quotes, as `strings.en.json` does. The GDD patch keeps the GDD's own curly quotes and em dashes so the document stays consistent.

## Open questions (all decided by Laurens, 3 Oct 2026)

1. ~~**Who teaches the tide-gap?**~~ **Decided:** Merrick gets one short Warm-path line in `case.wharf-ladder`. The new reply on `merrick.whisper`, "Next time I'd rather skip the lane.", leads to `merrick.tidegap`: "Then come at the tide-gap. One minute when the river drowns the lane and the crate hands curse their wheels. That one's free. Free is a one-time price." It grants `knowledge.wharfLadder.tideGap`, then returns to the whisper.
2. ~~**Where does the interval come from?**~~ **Decided:** the first-visit clock-room fight grants only the night's chalk. The interval comes from side case 04.
3. ~~**What exactly is the interval?**~~ **Decided:** the minutes Hobb is away.
4. ~~**Does the lane still drop the chit on a return-visit fight?**~~ **Decided:** no. The crate chit drops on the first lane fight only.
5. ~~**Losing the clock room on the first night?**~~ **Decided:** a loss still sets `combat.a1.clockroom.done`; Voss wakes bruised outside.
6. ~~**Head counts?**~~ **Decided:** gate 2, lane 2, clock room 3 (Hobb plus two hands), E1 2.

No open questions remain.

## GDD changes (applied in this PR)

- **Beat 3 text:** "The night floor, then the back room." The order is gate, lane, clock room (the core), then Merrick, then E1, and on the first visit all three A1 groups fight.
- **Scene card:**
  - A new **Order (first visit)** line with head counts, the short pre-fight exchanges, return-visit-only quiet routes, and the Merrick gate on `combat.a1.clockroom.done`.
  - A new **Floor (A1)** cast row: the chalk crews and Hobb (working), not the Watch, knockout by default.
  - The E1 Dry bluff now works only if Voss told the Watch-house night runner.
  - `combat.a1.clockroom.done` is added to the flag list.
  - The tone lock now says the whole A1 floor (gate, lane, clock room), not just the clock room, can't be avoided on the first visit.
- **Act I lead summary:** "Cross the night gate and the lost-crate lane; the clock room keeps the alibi."
- **Act I ledger:**
  - Head counts are added to the A1 and E1 "Where" cells.
  - The A1 gate and lane quiet routes are marked **return visits only**, and "the first visit fights".
  - The clock room says "Return visits only, once he knows the interval (the minutes the clock-keeper is away; side case 04)". Its "what the blades buy" cell is now only the night's chalk.
  - The lane's crate chit is marked "(first fight only)".
  - The E1 bluff now reads "works only if Voss told the Watch-house night runner", with no side case 03.
  - A **Wharf Ladder order** note covers the order and head counts.
  - The no-quiet-route sentence now covers the first visit's gate, lane and clock room.
- **Counts:** Act I's group count is **unchanged at 13**: each A1 row is still one group, and head counts aren't groups. The totals of 58 and 64 are unchanged. **The quietest path goes from 21 to 23**, because the gate and the lane can no longer be slipped on the only visit that path makes. The list is renumbered, and "Twenty-one is the floor" becomes "Twenty-three".
- **Story combat table:** an "A1 gate, A1 lane (first visit)" row is added (won, knocked out; the lane gives the chit, first fight only). "A1 clock (first night)" becomes "A1 clock (first visit)": won, the night's chalk, Voss bruised. A played loss still sets `combat.a1.clockroom.done`, and Voss wakes bruised outside.
- **Side case 04:** the interval is now defined as the minutes the clock-keeper (Hobb) is away.
- **Side case 03:** it no longer claims to make the E1 bluff true; it still makes the sergeant's one ask reachable the same night.

## A. The night gate (A1 gate · 2 tally-men)

_Graph `case.wharf-ladder.gate` → `wharf-ladder.gate.dialogue.json`. The first visit opens at `gate.bark`. The return-visit quiet route, `gate.merrick`, opens only when its condition holds._

**`gate.bark`** · TALLY-MAN
> Gate's shut. Night tally.
- (Continue) → `gate.bark.b`

**`gate.bark.b`** · SECOND TALLY-MAN
> Chalk says nobody comes through tonight. You look like somebody.
- 1. *"Evening. I'm only after a clerk. I'll be quick, and I'll be quiet."* `[warm/open]` → `gate.warm`
    - sets `combat.a1.gate.trigger`
- 2. *"Somebody. That's a promotion. Who do I see about the paperwork?"* `[dry/observe]` → `gate.dry`
    - sets `combat.a1.gate.trigger`, `combat.a1.gate.opening.rattled`
- 3. *"Then rub me off the chalk."* `[sharp/press]` → `gate.sharp`
    - sets `combat.a1.gate.trigger`, `combat.a1.gate.opening.firstBlow`

**`gate.warm`** · TALLY-MAN
> Quick and quiet. That's how we like it too.
- **[END: hand-off to the fight or crossing]**

**`gate.dry`** · SECOND TALLY-MAN
> He's making jokes. I hate it when they make jokes.
- **[END: hand-off to the fight or crossing]**

**`gate.sharp`** · TALLY-MAN
> Funny. Hold still. This'll smudge.
- **[END: hand-off to the fight or crossing]**

**`gate.merrick`** · MERRICK
> *Return visit only. Opens instead of the bark when:* a return visit (the first Merrick talk is done) AND Voss paid Merrick 50 silver (Warm)
> Evening, lads. He's with me, and he's paid up. Chalk him down as weather.
- 1. *"Evening. Wet, isn't it?"* `[warm/open]` → `gate.merrick.b`
    - sets `combat.a1.gate.walkedPast`

**`gate.merrick.b`** · TALLY-MAN
> Weather. Right. Mind the puddle, weather.
- **[END: hand-off to the fight or crossing]**


## B. The lost-crate lane (A1 lane · 2 crate hands)

_Graph `case.wharf-ladder.lane` → `wharf-ladder.lane.dialogue.json`. The first visit opens at `lane.bark`. The return-visit quiet route, `lane.slip`, opens only when its condition holds._

**`lane.bark`** · CRATE HAND
> Lane's working. Crates moving. Go round.
- (Continue) → `lane.bark.b`

**`lane.bark.b`** · SECOND CRATE HAND
> Too late for round. He's seen the crates. Crates don't like being seen.
- 1. *"I've seen nothing. I'm famous for it. Ask anyone at the Watch-house."* `[warm/open]` → `lane.warm`
    - sets `combat.a1.lane.trigger`
- 2. *"Lost crates. Shame. Want a hand looking for them?"* `[dry/observe]` → `lane.dry`
    - sets `combat.a1.lane.trigger`, `combat.a1.lane.opening.rattled`
- 3. *"Put the hook down before I find somewhere to put it."* `[sharp/press]` → `lane.sharp`
    - sets `combat.a1.lane.trigger`, `combat.a1.lane.opening.firstBlow`

**`lane.warm`** · CRATE HAND
> Famous men get remembered. We're paid to forget.
- **[END: hand-off to the fight or crossing]**

**`lane.dry`** · SECOND CRATE HAND
> He knows they're lost. How does he know they're lost?
- **[END: hand-off to the fight or crossing]**

**`lane.sharp`** · CRATE HAND
> Got a mouth on him. Shut it for him.
- **[END: hand-off to the fight or crossing]**

**`lane.slip`** · VOSS (thinking)
> *Return visit only. Opens instead of the bark when:* a return visit (the first Merrick talk is done) AND Voss knows the tide-gap timing [working id]
> The tide-gap came on time: a minute when the river took every sound on the lane and kept it. The crate hands were busy hating a stuck wheel.
- 1. *"Walk through the gap."* `[leave]` → `lane.slip.b`
    - sets `combat.a1.lane.slip`

**`lane.slip.b`** · VOSS (thinking)
> Nobody counted me. On this lane, that's as good as a pass.
- **[END: hand-off to the fight or crossing]**


## C. The clock room (A1 core · Hobb and 2 hands)

_Graph `case.wharf-ladder.clockroom` → `wharf-ladder.clockroom.dialogue.json`. The first visit opens at `clock.bark`. The return-visit quiet route, `clock.interval`, opens only when its condition holds._

**`clock.bark`** · HOBB
> Don't touch the clock. It's three minutes from right, and I'm paid to keep it there.
- (Continue) → `clock.bark.b`

**`clock.bark.b`** · CLOCK-ROOM HAND
> He came through the gate and the lane, Hobb.
- (Continue) → `clock.bark.c`

**`clock.bark.c`** · HOBB
> I know. I'm still more scared of the man who pays for the minutes. The chalk on that wall says tonight's a fast night. The chalk is never wrong. Unlike the clock.
- 1. *"Then be scared of him somewhere else. Nobody has to know I was here."* `[warm/open]` → `clock.warm`
    - sets `combat.a1.clockroom.trigger`, `combat.a1.clockroom.opening.rattled`
- 2. *"Your clock's a liar. Three minutes' worth."* `[dry/observe]` → `clock.dry`
    - sets `combat.a1.clockroom.trigger`
- 3. *"Then you'd better hope he pays for teeth."* `[sharp/press]` → `clock.sharp`
    - sets `combat.a1.clockroom.trigger`, `combat.a1.clockroom.opening.firstBlow`

**`clock.warm`** · HOBB
> He'd know. He always knows the minute. Sorry about this.
- **[END: hand-off to the fight or crossing]**

**`clock.dry`** · CLOCK-ROOM HAND
> It's not lying. It's paid. There's a difference, and it's three minutes.
- **[END: hand-off to the fight or crossing]**

**`clock.sharp`** · HOBB
> He does. He pays for everything. Hold him still.
- **[END: hand-off to the fight or crossing]**

**`clock.interval`** · HOBB
> *Return visit only. Opens instead of the bark when:* a return visit (the first Merrick talk is done) AND Voss knows the interval [working id]
> You know the interval. Then you know I'm due somewhere else for the next three minutes.
- 1. *"Don't let me keep you."* `[dry/leave]` → `clock.interval.b`
    - sets `combat.a1.clockroom.letPass`

**`clock.interval.b`** · HOBB
> I was never here. Neither was the clock.
- **[END: hand-off to the fight or crossing]**

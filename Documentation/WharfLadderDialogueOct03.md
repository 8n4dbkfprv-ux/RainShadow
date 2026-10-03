# RainShadow · Act I Beat 3 · Wharf Ladder shipping office: dialogue script (approved 3 Oct 2026)

Graph `case.wharf-ladder` → `wharf-ladder.dialogue.json` (53 nodes) + `wharf-ladder.strings.en.json` (122 keys).
Revision 3: Writing Bot's humour pass (strings v2, all 10 lines kept, including "Polite. Wiped their feet, even.") plus Laurens's decisions on every open question (D1 to D10). Revision 4 (3 Oct 2026, branch `grokbot/wharf-ladder-floor`) adds one Warm-path Merrick line, `merrick.tidegap`, which grants `knowledge.wharfLadder.tideGap` for the A1 lane's return-visit slip (see `Documentation/WharfLadderFloorOct03.md`). The v1 originals are in `wharf-ladder.strings.en.v1.json` and `wharf-ladder-script.v1.md`.
Sources: GDD §4.3.2 Act I beat 3 scene card, §4.2, §4.3.5, §7.5, side cases 03/04 (§4.3.8); design pack combat-02 and sidequest-04.

**Status in the repo (PR #32, branch `grokbot/wharf-ladder-dialogue`):** the graph ships as `RainShadow Shared/Resources/Dialogue/wharf-ladder.dialogue.json`, and its 122 keys are merged into `strings.en.json`. It is **not registered** yet: there's no Swift facade, it isn't in `ShippedDialogueCatalogTests.shippedCatalog()`, it isn't in the Xcode target's resource list, and nothing presents it. The code follow-ups are listed under "Engine and format gaps" below. This script is generated from the JSON by the design-pack tool `render_script.py`, so the two can't drift apart. The `wharf-ladder.strings.en*.json` file names refer to the design pack; in the repo, those keys live in `strings.en.json`.

**How to read this.** `VOSS (thinking)` = interior monologue page. Lines in *italics* after a number are Voss's reply choices (per §7.5, Voss speaks only through choices). `[tone/intention]` is metadata, never shown to the player. "only if" = the choice is hidden unless the condition holds. "set (this talk only)" = conversation flag, cleared when the talk ends; plain "set" = case flag that persists. **HAND-OFF** flags are where dialogue stops and the E1 fight (or story auto-resolve) takes over.

## Decided by Laurens (3 Oct 2026)

D1 to D3 are Laurens's answers. D4 to D10 are the proposed picks, which Laurens accepted.

- **D1. Coin: 50 silver.** Paying Merrick on the Warm path costs 50 silver of Lila's two hundred. Voss names the sum ("Fifty silver buys talk."), and a new thinking page, `voss.paid`, gives the dry aside ("A quarter of Lila's two hundred, spent on one clerk's memory..."). Authored dialogue has no money action, so the choice sets the case flag `wharf-ladder.case.merrick-paid50`. **Code still has to deduct the 50 silver, once, when it sees that flag.** It's a case flag, not a conversation flag, so it's still there after the talk ends. The conversation flag `wharf-ladder.dialogue.merrick-paid` still drives the Warm branch.
- **D2. The A1 clock-room fight happens before this conversation.** The graph assumes A1 is done. `voss.arrival.b` opens with "The clock room was behind me now..." and a clerk "white as a fresh manifest". A new Merrick node, `merrick.shaken` ("You came out of the clock room. On your feet..."), comes before the greeting, which now starts "Right. Well. We're shut." Nothing suggests a paid Merrick walks Voss past the clock room. **External, scene-side gate:** open this conversation only after `combat.a1.clockroom.done` is set. The graph itself doesn't read that flag; see the format gaps below.
- **D3. The Dry bluff works only if Voss told the night runner.** "The Watch knows I'm here" now depends on `wharf-ladder.case.watch-told` alone. The side-case-03 route and the `sidecase.03.ravens-restored` gate are gone. Without the runner, Ketch calls the bluff and the fight starts.

- **D4. Side case 04 flag name:** `sidecase.04.merrick-won-back` is the canonical id.
- **D5. The Dry favour binds Voss.** The Dry price now also sets the case flag `wharf-ladder.case.clock-promise`, which lasts after the talk. If Voss later exposes the clock in side case 04, he breaks that promise, and Merrick calls it that. **Follow-up for side case 04:** read `wharf-ladder.case.clock-promise` and give Merrick a broken-promise line when Voss exposes the clock.
- **D6. Ketch and Bram's orders stay vague:** "the gray gent" and "you heard the man". No change.
- **D7. The tally drops only if Bram is knocked down.** This is a resolver rule: the E1 resolver grants `evidence.payTally.crateMark` only when Bram goes down. The dialogue's tally payoff (`aftermath.won` → `aftermath.tally`) is already gated on that evidence. A won fight without it goes straight to `aftermath.cost`.
- **D8. A lost fight costs the seal scrap.** On `combat.e1.outcome.lost`, the resolver strips `evidence.sealMark.scrap`. Authored dialogue can't revoke evidence; the `aftermath.lost` text already says "Whatever I'd taken off her desk had been taken back, or burned."
- **D9. Lila outside.** If the earlier office beat had Lila wait outside, an optional reply on the arrival page, "Leave Lila the dry side of the doorway.", leads to a short thinking page, `voss.lila` ("...a threshold she trusted than a clerk she didn't. Fair. I hadn't met him yet."). **No office flag exists for this yet** (the shipped intro sets only `empty-coat.case.client-retained`), so it's gated on the clearly named external flag `lila.waitsOutside.wharfLadder`, which the office beat still has to set. Otherwise her only mention is "Lila's two hundred". "Go in." is always offered.
- **D10. The Civic visitor:** no more than "Polite. Wiped their feet, even." No change.

## Judgement calls (please check)

1. **Approach = price.** Warm = coin (outbids the gray gent). Dry = a favour (Voss keeps the night-clock racket to himself, and that promise binds him, D5). Sharp = a threat (Dock Authority). The Sharp threat costs Voss the witness, which is the GDD's "threat that costs Voss": Merrick rings the bell.
2. **Making the Dry bluff true (now decided, see D3).** Voss can ask the Watch-house night runner to tell the night sergeant he's here. That's the only way the Dry bluff works.
3. **The bluff looks the same either way.** The true and false versions use identical text. The player can't tell from the menu whether it's a real threat or a bluff (it's tagged `press` vs `feign`).
4. **The crate mark is cut off mid-word** ("chalked with the—") so I don't invent the mark. The real mark is only revealed by Bram's tally, after a won fight in which Bram is knocked down (D7).
5. **Ketch gives the order, Bram asks the dumb question.** In the overheard line, Ketch is relaying orders he was given, and nobody else enters. The GDD's Ketch and Bram replace the pack's three hands plus a foreman.
6. **"Silver an hour", not "dollar".** This is the pack line re-coined.
7. **Overhearing is opt-in on the Warm path.** "Then I was never here" leaves straight away, with the scrap if Voss took it and without the Tallow Stair. "Ring it, I'll be behind the wax" gets the overheard line and `knowledge.muscle.tallowStair`. Both mark E1 as avoided.
8. **The Gray Man sighting.** On the Warm path it's optional ("Look long enough to remember him"). On the Sharp path it's always set, because Merrick's reaction forces Voss to see him. On the Dry path he doesn't appear. He never speaks and never enters; he only shifts his weight across the quay.
9. **"Step off the desk" isn't a quiet way out.** Per the scene card, on Dry the fight starts unless the Watch line is true. Voss can ask who's paying, but every other reply leads to the fight.
10. **The seal bite.** "Seals that bite" is an optional examine choice ("Open it anyway"). It sets `wharf-ladder.case.seal-bitten` only. It doesn't remove the scrap and isn't the named injury.
11. **Watch attention.** The dialogue only reads Watch attention; it never writes it. The fight resolver adds +1, as in the scene card ("noise brings Dock Authority night-men"). The aftermath line changes at 2 or more ("the Watch-house will start closing doors").
12. **Fight hand-off is by flags, not a cue.** The two hand-off nodes end the conversation after setting `combat.e1.trigger.desk` or `.sealroom`. The scene or resolver reads those flags, runs E1 (or auto-resolves it), writes `combat.e1.outcome.won`/`.lost`, then reopens the graph. The aftermath entry nodes pick it up from there.
13. **`combat.e1.outcome` is split into three flags** (`.avoided`, `.won`, `.lost`), because authored conditions only test flags, not string values.
14. **The night clock.** Merrick says it "runs three minutes fast when the night crew wants an alibi, and nobody asks me which nights". Nothing says it was fast on Tuesday (side case 04 keeps that open). Voss's journal note is careful: "So nine is a rumour". It grants `knowledge.nightClock.fast` and the side-case-04 hook lead.
15. **Canon.** "The Watch" throughout. Money is silver, and the Warm price is 50 of the 200 (D1). Gray overcoat. Retainer 200 ("Lila's two hundred"). Tuesday. "This week", rather than counting nights. Voss mentions river-watch slips to the runner, but never Pell Street. Lila stays outside the office, at most (D9).
16. **Placeholder portraits and no VO.** The portraits are placeholders (`dialogue_portrait_merrick_v01`, `_ketch_`, `_bram_`, `_night_runner_`), and there are no voice keys.

## Open questions (all decided)

1. ~~**Coin.**~~ **Decided (D1):** 50 silver.
2. ~~**The A1 clock-room fight.**~~ **Decided (D2):** A1 comes before this conversation. The scene gates entry on `combat.a1.clockroom.done`.
3. ~~**Bluff routes.**~~ **Decided (D3):** only the night runner counts. Side case 03 is not a route.
4. ~~**Side-case 04 flag name.**~~ **Decided (D4):** `sidecase.04.merrick-won-back`.
5. ~~**The Dry favour.**~~ **Decided (D5):** it binds Voss; flag `wharf-ladder.case.clock-promise`.
6. ~~**Ketch and Bram's orders.**~~ **Decided (D6):** they stay vague.
7. ~~**The tally.**~~ **Decided (D7):** it drops only if Bram is knocked down (resolver rule).
8. ~~**Losing the fight.**~~ **Decided (D8):** the resolver strips `evidence.sealMark.scrap`.
9. ~~**Lila outside.**~~ **Decided (D9):** an optional arrival line, gated on `lila.waitsOutside.wharfLadder`.
10. ~~**The Civic visitor.**~~ **Decided (D10):** "Polite. Wiped their feet, even." and nothing more.

No open questions remain.

## Engine and format gaps (things the current format can't express)

- **Watch attention.** There's no authored counter action (`addToCounter`), so dialogue can't raise Watch attention. Only the resolver or scene can.
- **Removing evidence.** There's no authored way to revoke evidence. On a lost fight, the resolver strips `evidence.sealMark.scrap` (D8).
- **Resolver tally rule.** The E1 resolver grants `evidence.payTally.crateMark` only if Bram is knocked down (D7).
- **Side case 04 promise.** Side case 04 reads `wharf-ladder.case.clock-promise`; if Voss exposes the clock, Merrick calls it a broken promise (D5).
- **Lila-outside flag.** The earlier office beat must set `lila.waitsOutside.wharfLadder` when Lila chooses to wait outside (D9).
- **External gate ids.** `ShippedDialogueCatalogTests.everyGateInShippedContentIsSatisfiable` would fail on six ids that are written outside this graph: `combat.e1.outcome.won`, `combat.e1.outcome.lost`, `evidence.payTally.crateMark`, `watch.attention`, `sidecase.04.merrick-won-back` and `lila.waitsOutside.wharfLadder`. Each needs a writer, or an allow-list in that test.
- **Fight hand-off.** There's no scene handler that turns `combat.e1.trigger.*` into a fight or auto-resolve. `onShowCue` would assert in the office scene, so I didn't use any cues.
- **Shipping it.** Shipping needs a Swift facade, registration in the shipped catalog, and the catalog count in the test raised from 2. The strings are already merged into `strings.en.json` (PR #32).
- **Money.** There's no authored money action. The Warm price is the flag `wharf-ladder.case.merrick-paid50`, and code has to deduct 50 silver from the retainer exactly once (D1).
- **A1 gate.** `combat.a1.clockroom.done` is written by the A1 fight. The office scene checks it before opening this graph (D2). I kept it out of `entryWhen` because the start node can't be conditional, and an in-graph "not yet" node would be dead content.
- **Portraits.** Merrick, Ketch, Bram and the runner have no portrait art; the game shows an empty dark frame.

## 1. Arrival (after the A1 clock-room fight)

_The scene opens this conversation only once the external flag combat.a1.clockroom.done is set. The arrival text assumes A1 has already happened._

**`voss.arrival`** · VOSS (thinking)
> Wharf Ladder after dark. The rain worked the tin roof harder than it ever bothered to on Sable Row. Lila's two hundred sat warm in my coat. Nothing else in it was. The key still hummed somewhere in my memory.
- 1. *"Go in."* `[open]` → `voss.arrival.b`
- 2. *"Leave Lila the dry side of the doorway."* `[observe]` · only if Lila is waiting outside [external: set by the earlier office beat] → `voss.lila`

**`voss.lila`** · VOSS (thinking)
> Lila stayed outside, under a lintel with an old ward-mark that still held. She said she'd rather wait on a threshold she trusted than a clerk she didn't. Fair. I hadn't met him yet.
- (Continue) → `voss.arrival.b`

**`voss.arrival.b`** · VOSS (thinking)
> The clock room was behind me now, quieter than when I'd gone in. Out front: brass seal-presses, an empty raven cage, a clock ticking like it had somewhere better to be. One clerk behind the counter, white as a fresh manifest. A Watch-house runner dripping on the mat.
- (Continue) → `merrick.shaken`

**`merrick.shaken`** · MERRICK
> You came out of the clock room. On your feet. Most people who go in there come out on somebody else's.
- 1. *"It had its say. I had mine."* `[dry/observe]` → `merrick.greet`

**`merrick.greet`** · MERRICK
> Right. Well. We're shut. Unless you're the Watch, and you're not the Watch. The Watch wipes its feet.
- 1. *"Harlan Voss. I find people. I'm here about Lillian March."* `[open]` → `merrick.price`
- 2. *"Your other customer was first. I'll wait. I've nowhere drier to be."* `[observe]` → `runner.hello`


## 2. Optional: the Watch-house night runner

_Reached only if Voss chooses to wait. Telling the runner is one way to make the Dry bluff true later._

**`runner.hello`** · NIGHT RUNNER
> Don't mind me. Night slips for the Watch-house. I carry paper. I don't read it. Reading's a different wage.
- 1. *"River slips still logged by the bell, not the tide? I used to sign those."* `[dry/observe]` → `runner.softfile`
- 2. *"Tell your night sergeant Harlan Voss is at Wharf Ladder tonight. He knows the name."* `[trade]` → `runner.told`
    - set Voss told the night runner to tell the Watch
- 3. *"Don't let me keep you."* `[leave]` → `merrick.price`

**`runner.softfile`** · NIGHT RUNNER
> River watch? Then you know the tide speech. The March coat's filed soft. The sergeant gave it the whole speech, tides and what the river keeps. He does it well. He's had practice.
- 1. *"Tell him Harlan Voss is at Wharf Ladder tonight. He'll sigh."* `[trade]` → `runner.told`
    - set Voss told the night runner to tell the Watch
- 2. *"Mind the clock on your way out. It's keen."* `[leave]` → `merrick.price`

**`runner.told`** · NIGHT RUNNER
> I'll tell him. He'll sigh. He sighs at most names. Yours might get two.
- 1. *"Two's a compliment. Now, clerk. Lillian March."* `[open]` → `merrick.price`


## 3. Merrick's price (Warm coin / Dry favour / Sharp threat)

_The approach chosen here decides the E1 branch in scene 6._

**`merrick.price`** · MERRICK
> Everyone's here about Lillian March this week. Silence is a silver an hour, Mr. Voss. Talk is dearer, and it doesn't keep.
- 1. *"Fifty silver buys talk. More than whoever's paying you to be quiet."* `[warm/trade]` → `voss.paid`
    - set (this talk only) Voss paid Merrick (Warm); set PAID 50 SILVER (code must deduct 50 from Lila's 200, once)
- 2. *"No coin. A favour. Your clock stays your business. Nobody hears about it from me."* `[dry/trade]` → `merrick.favour`
    - set (this talk only) Voss offered the clock favour (Dry); set Voss promised Merrick silence about the clock (side case 04 reads this)
- 3. *"Here's my price. Talk, or Dock Authority hears you sell their silence twice."* `[sharp/press]` → `merrick.threat`
    - set (this talk only) Voss threatened Merrick (Sharp)

**`voss.paid`** · VOSS (thinking)
> Fifty silver. A quarter of Lila's two hundred, spent on one clerk's memory. I didn't ask for a receipt. He'd have charged for it.
- (Continue) → `merrick.paid`

**`merrick.paid`** · MERRICK
> That's more than the gray gent paid. He tips like a man buying rope. All right. Talk.
- (Continue) → `merrick.tuesday`

**`merrick.favour`** · MERRICK
> A finder who keeps quiet about clocks. They'll put you under glass at the Civic hall. Fine. A favour buys you the short version.
- (Continue) → `merrick.tuesday`

**`merrick.threat`** · MERRICK
> Dock Authority. You say it like it's a name, Mr. Voss. Down here it's weather. Fine. Fine. You'll get your talk.
- (Continue) → `merrick.tuesday`


## 4. Objective: the last shift

**`merrick.tuesday`** · MERRICK
> Tuesday she left at nine. Said she had one more errand in the upper city. No name. No coach, either. Look at the desk slate. Clean. Cleanest thing in the building.
- 1. *"Did she say what the errand was?"* `[warm/open]` → `merrick.errand`
    - set lillian.lastShift.wharfLadder; journal (chronology): "Wharf Ladder: Lillian left on Tuesday at nine. One more errand in the upper city. No coach on the desk slate."
- 2. *"Nine by which clock?"* `[dry/press]` → `merrick.clock`
    - set lillian.lastShift.wharfLadder; journal (chronology): "Wharf Ladder: Lillian left on Tuesday at nine. One more errand in the upper city. No coach on the desk slate."
- 3. *"Clean slates are usually cleaned."* `[sharp/press]` → `merrick.slate`
    - set lillian.lastShift.wharfLadder; journal (chronology): "Wharf Ladder: Lillian left on Tuesday at nine. One more errand in the upper city. No coach on the desk slate."

**`merrick.errand`** · MERRICK
> Upper city. She said it the way people say "the tooth-drawer." Somewhere you don't want to go, and go anyway.
- (Continue) → `merrick.ferry`

**`merrick.clock`** · MERRICK
> By that one. Don't trust it. It runs three minutes fast when the night crew wants an alibi, and nobody asks me which nights.
- 1. *"So nine is a rumour."* `[dry/observe]` → `merrick.ferry`
    - learn knowledge.nightClock.fast; journal (lead): "Wharf Ladder's night clock runs three minutes fast when the night crew wants an alibi. Somebody sets it. Clocks don't volunteer."

**`merrick.slate`** · MERRICK
> Nobody wipes that slate but me, and I didn't. It's clean because she never wrote on it. She walked. Or she went with somebody who doesn't need a slate.
- (Continue) → `merrick.ferry`

**`merrick.ferry`** · MERRICK
> She never missed the morning ferry. That night she did everything twice. Checked the seal, checked it again.
- 1. *"Show me the second check."* `[dry/press]` → `merrick.desk`


## 5. Objective: Lillian's desk (seal-mark scrap, the night clock)

_A hub: either inspect can be done once, in any order. The clock check is hidden if Merrick already told Voss about the clock._

**`merrick.desk`** · MERRICK
> Her desk. I haven't touched it. I don't touch anything in here I'm not paid to. Touching is how this office bites.
- 1. *"Then I'll touch it. Carefully."* `[observe]` → `desk.hub`

**`desk.hub`** · VOSS (thinking)
> Lillian's desk. Ledgers squared to the edge. A pen laid parallel to the blotter, as if it expected an inspection. The kind of tidy that is either a habit or a warning.
- 1. *"Run a thumb along the desk-leather edge."* `[observe]` · only if NOT (has evidence.sealMark.scrap) → `desk.edge`
- 2. *"Wait for the ferry horn. Check the clock against it."* `[observe]` · only if NOT (knows knowledge.nightClock.fast) → `desk.clock`
- 3. *"Merrick. Her last manifest pull. Where is it?"* `[press]` → `merrick.sealroom`

**`desk.edge`** · VOSS (thinking)
> A smear on the leather edge, brown as old tea, shaped like a glove that touched the wrong thing. Under the blotter, a scrap of seal-wax with the mark still sharp. The second check, or what was left of it.
- 1. *"Pocket it. Gently. It still looks hungry."* `[observe]` → `desk.hub`
    - gain evidence evidence.sealMark.scrap

**`desk.clock`** · VOSS (thinking)
> The ferry horn went for the hour. The night clock was already three minutes past it, and looked pleased with itself.
- 1. *"Three minutes fast. Somebody winds that clock with an opinion."* `[dry/observe]` → `desk.hub`
    - learn knowledge.nightClock.fast; journal (lead): "Wharf Ladder's night clock runs three minutes fast when the night crew wants an alibi. Somebody sets it. Clocks don't volunteer."


## 6. Objective: the scrubbed reading-rights, where E1 splits

_Exactly one choice shows, matching the approach from scene 3._

**`merrick.sealroom`** · MERRICK
> Her last pull's in the seal-room. Someone from Civic came for the reading-rights after. Polite. Wiped their feet, even. The folios still hurt if you touch the wrong line.
- 1. *"After she vanished. Show me."* `[warm/open]` · only if Voss paid Merrick (Warm) → `sealroom.folio`
    - learn knowledge.readingRights.scrubbed; journal (lead): "Someone from Civic scrubbed the reading-rights on Lillian's last manifest pull after she vanished. Politely. Civic Spine keeps the records."
- 2. *"After she vanished. Show me."* `[dry/open]` · only if Voss offered the clock favour (Dry) → `merrick.stall`
    - learn knowledge.readingRights.scrubbed; journal (lead): "Someone from Civic scrubbed the reading-rights on Lillian's last manifest pull after she vanished. Politely. Civic Spine keeps the records."
- 3. *"After she vanished. Who from Civic? Show me."* `[sharp/press]` · only if Voss threatened Merrick (Sharp) → `sealroom.folio`
    - learn knowledge.readingRights.scrubbed; journal (lead): "Someone from Civic scrubbed the reading-rights on Lillian's last manifest pull after she vanished. Politely. Civic Spine keeps the records."


## 6a. Seals that bite (Warm and Sharp)

**`sealroom.folio`** · VOSS (thinking)
> The seal-room. Shelves of folios with wax on them like teeth. Her last pull sat on top. The reading-rights stamp had been scraped back to bare card. The seal under it was awake.
- 1. *"Read the margin. Leave the seal alone."* `[observe]` → `sealroom.margin`
- 2. *"Open it anyway."* `[press]` → `sealroom.bite`
    - set the seal bit Voss

**`sealroom.margin`** · VOSS (thinking)
> The margin had carried a rights-line once. Now it carried a scratch where a name had been, neat as a clerk's apology. Whoever scrubbed it had manners, and a better pen than mine.
- 1. *"Merrick. What now?"* `[open]` · only if Voss paid Merrick (Warm) → `merrick.whisper`
- 2. *"Merrick. Who else came asking?"* `[press]` · only if Voss threatened Merrick (Sharp) → `merrick.cratemark`

**`sealroom.bite`** · VOSS (thinking)
> The seal bit. Not hard. Hard enough to make its point, and draw a little blood to underline it. Out front, Merrick made the noise of a man watching his evening get worse.
- 1. *"It's a scratch, Merrick. Breathe."* `[open]` · only if Voss paid Merrick (Warm) → `merrick.bitten`
- 2. *"Merrick. Who else came asking?"* `[press]` · only if Voss threatened Merrick (Sharp) → `merrick.cratemark`

**`merrick.bitten`** · MERRICK
> You opened it. Of course you opened it. Hold your hand up. You'll drip on the manifests.
- (Continue) → `merrick.whisper`


## 7. E1 Warm: the whisper, the back door, the overheard order

**`merrick.whisper`** · MERRICK
> Listen. They come at the bell. The gray gent's men. I'm paid to ring it if anyone asks about her folios. You paid more. I'm loyal like that. Back door's behind the presses.
- 1. *"Then I was never here."* `[leave]` → `warm.backdoor`
    - set E1 avoided; set Wharf Ladder visited
- 2. *"Ring it. I'll be behind the wax. I want to hear what they're paid to say."* `[observe]` → `warm.hide`
- 3. *"Next time I'd rather skip the lane."* `[warm/trade]` · only if NOT (knows the tide-gap timing for the lost-crate lane) → `merrick.tidegap`
    - learn the tide-gap timing for the lost-crate lane

**`merrick.tidegap`** · MERRICK
> Then come at the tide-gap. One minute when the river drowns the lane and the crate hands curse their wheels. That one's free. Free is a one-time price.
- 1. *"Noted. Now, the bell."* `[dry/observe]` → `merrick.whisper`

**`warm.hide`** · VOSS (thinking)
> I folded myself behind a shelf of wax that would have liked me dead. Merrick rang the bell like a man apologising to it. Boots came in. Two pairs. One heavy, one in a hurry.
- (Continue) → `ketch.overheard`

**`ketch.overheard`** · KETCH
> Right. You heard the man. Burn the March folio. The gray gent pays at the Tallow Stair.
- (Continue) → `bram.overheard`

**`bram.overheard`** · BRAM
> All of it? Even the bit that bites?
- (Continue) → `ketch.overheard.b`

**`ketch.overheard.b`** · KETCH
> Especially the bit that bites.
- 1. *"Time to leave by the door nobody paid to watch."* `[leave]` → `warm.backdoor`
    - learn knowledge.muscle.tallowStair; journal (lead): "Ketch and Bram were told to burn the March folio. The gray gent pays at the Tallow Stair."; set E1 avoided; set Wharf Ladder visited

**`warm.backdoor`** · VOSS (thinking)
> The back door let me out onto the quay. Across the water, under a lamp that had decided to be dim, a man in a gray overcoat stood very still. He didn't come closer. He didn't need to.
- 1. *"Look long enough to remember him."* `[observe]` → `wharf.exit`
    - set sighting.grayMan.quay
- 2. *"Don't look. Walk."* `[leave]` → `wharf.exit`


## 8. E1 Dry: Merrick stalls; they walk in at the desk

_The true and false bluff look identical to the player; the condition decides which one shows._

**`merrick.stall`** · MERRICK
> The pull. Yes. It's filed. Under. Somewhere. Give me a minute. Minutes are cheap in here. We make our own.
- 1. *"I'll wait at her desk. Take three."* `[dry/observe]` → `ketch.enter`

**`ketch.enter`** · KETCH
> Evening. We're here for paper, not for you. Step off the desk.
- 1. *"The Watch knows I'm here."* `[press]` · only if Voss told the night runner to tell the Watch → `ketch.backoff`
    - set E1 avoided; set Wharf Ladder visited
- 2. *"The Watch knows I'm here."* `[feign]` · only if NOT (Voss told the night runner to tell the Watch) → `ketch.callsbluff`
- 3. *"Who's paying for the paper?"* `[press]` → `ketch.who`
- 4. *"Step off? I've only just got comfortable."* `[sharp/press]` → `e1.handoff.desk`
    - set HAND-OFF: E1 starts at Lillian's desk; set Wharf Ladder visited

**`ketch.who`** · KETCH
> Someone who pays in chalk and doesn't ask how it's spent. Desk, Mr. Finder.
- 1. *"The Watch knows I'm here."* `[press]` · only if Voss told the night runner to tell the Watch → `ketch.backoff`
    - set E1 avoided; set Wharf Ladder visited
- 2. *"The Watch knows I'm here."* `[feign]` · only if NOT (Voss told the night runner to tell the Watch) → `ketch.callsbluff`
- 3. *"Make me."* `[sharp/press]` → `e1.handoff.desk`
    - set HAND-OFF: E1 starts at Lillian's desk; set Wharf Ladder visited

**`ketch.backoff`** · KETCH
> Does it. Then the Watch can have you. Paper keeps. Come on, Bram. Door's this way.
- 1. *"So does the Watch. Mostly."* `[dry/observe]` → `dry.after`

**`dry.after`** · VOSS (thinking)
> They left the way weather leaves: not far. Merrick came out from behind the counter and found something urgent to file. The seal-room could wait until I had the rights to read it.
- 1. *"Leave while the leaving's good."* `[leave]` → `wharf.exit`

**`ketch.callsbluff`** · KETCH
> No, it doesn't. Nobody tells the Watch anything in this office. That's what the office is for.
- 1. *"Worth a try. Cheaper than silver."* `[observe]` → `e1.handoff.desk`
    - set HAND-OFF: E1 starts at Lillian's desk; set Wharf Ladder visited

**`e1.handoff.desk`** · KETCH
> Bram. Mind the lamp. Mr. Finder's leaving by the floor.
- **[END OF CONVERSATION]**


## 9. E1 Sharp: the crate mark, the quay, the bell

**`merrick.cratemark`** · MERRICK
> Civic. Polite. Then nobody. Then everybody. Ask the lost-crate lane about the crates chalked with the—
- (Continue) → `voss.quay`

**`voss.quay`** · VOSS (thinking)
> He stopped. His eyes went past me, through the window, to the quay. Under a lamp that had gone dim on purpose, a man in a gray overcoat shifted his weight. That was all. It was enough. Merrick's hand found the bell cord.
- 1. *"Merrick. Don't."* `[warm/open]` → `merrick.bell`
    - set sighting.grayMan.quay; journal (lead): "Merrick started to name a crate mark from the lost-crate lane, saw the quay, and stopped. Dock Authority keeps the lost-crate numbers."
- 2. *"Ring that and you'll need a new office."* `[sharp/press]` → `merrick.bell`
    - set sighting.grayMan.quay; journal (lead): "Merrick started to name a crate mark from the lost-crate lane, saw the quay, and stopped. Dock Authority keeps the lost-crate numbers."

**`merrick.bell`** · MERRICK
> I'm sorry. They pay me to be frightened of them first.
- 1. *"Then I'd better find the back of this room."* `[observe]` → `e1.handoff.sealroom`
    - set HAND-OFF: E1 starts, Voss cornered in the seal-room; set Wharf Ladder visited

**`e1.handoff.sealroom`** · KETCH
> Bell says somebody's asking. Seal-room's a bad place to be somebody.
- **[END OF CONVERSATION]**


## 10. Exit

**`wharf.exit`** · VOSS (thinking)
> Outside, the rain had found the tin roof again and was taking it personally. The river stones were next, where somebody had arranged a coat. Unless the gray overcoat had plans for tonight.
- **[END OF CONVERSATION]**


## 11. After the fight, and coming back (checked before scene 1, in this order)

_The fight/auto-resolve writes the E1 outcome flag, grants the tally, raises Watch attention, then reopens this conversation._

**`aftermath.won`** · VOSS (thinking)
> *Opens the conversation when:* E1 won [external: fight/auto-resolve] AND NOT (fight aftermath already shown)
> When it was over, the floor was mine and nobody wanted it. Ketch went down like freight off a bad crane. Bram held his knife like a pen and ran out of courage before he ran out of room.
- 1. *"Read the tally Bram dropped."* `[observe]` · only if has the pay tally Bram dropped [external: granted by resolver] → `aftermath.tally`
- 2. *"Count what's left."* `[observe]` · only if NOT (has the pay tally Bram dropped [external: granted by resolver]) → `aftermath.cost`

**`aftermath.tally`** · VOSS (thinking)
> A chalk pay tally. Somebody's wages in somebody's hand, and a crate mark in the corner. The first thing tonight that tied the gray gent's money to a lost crate.
- (Continue) → `aftermath.cost`

**`aftermath.cost`** · VOSS (thinking)
> Lamps were coming along the quay. Dock Authority night-men, the kind who count heads before reasons. By morning the Watch would have my name for brawling at Wharf Ladder, in ink for once. Merrick was gone. So was any chance he'd say it twice.
- 1. *"Two marks in the night book now. The Watch-house will start closing doors."* `[observe]` · only if Watch attention >= 2 → `wharf.exit`
    - set fight aftermath already shown; set Wharf Ladder visited
- 2. *"Leave by the dark side of the quay. There's no shortage."* `[leave]` · only if Watch attention <= 1 → `wharf.exit`
    - set fight aftermath already shown; set Wharf Ladder visited

**`aftermath.lost`** · VOSS (thinking)
> *Opens the conversation when:* E1 lost [external: fight/auto-resolve] AND NOT (fight aftermath already shown)
> I woke on the quay boards with rain in one ear and my pockets lighter. Whatever I'd taken off her desk had been taken back, or burned. The boards weren't saying.
- 1. *"Get up. Slowly. Count what's still true."* `[observe]` → `aftermath.lost.b`
    - set fight aftermath already shown; set Wharf Ladder visited

**`aftermath.lost.b`** · VOSS (thinking)
> Nine o'clock. One more errand in the upper city. A slate nobody wrote on. And the river stones, where somebody had arranged a coat.
- **[END OF CONVERSATION]**

**`merrick.closed`** · MERRICK
> *Opens the conversation when:* (E1 won [external: fight/auto-resolve] OR E1 lost [external: fight/auto-resolve]) AND NOT (side case 04 won Merrick back [external, name TBD])
> No. Not for silver, not for favours, not for you. Come back when you've got a clock that tells the truth.
- **[END OF CONVERSATION]**

**`merrick.again`** · MERRICK
> *Opens the conversation when:* Wharf Ladder visited
> The hour's up, Mr. Voss. Come back with a new question or an old coin.
- **[END OF CONVERSATION]**

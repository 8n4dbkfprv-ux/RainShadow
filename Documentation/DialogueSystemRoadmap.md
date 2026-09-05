# Dialogue system roadmap

- Status: Phase 0–9 complete (state → journal → multi-graph → external resources → intention tags UI → conditions/counters/entry scan → transcript + talk-to-actor → EXTERN + catalog integrity → typed journal kinds)
- Version: 0.9
- Date: 10 August 2026
- Related: GDD §7.5 (Dialogue), Technical Architecture §14.1 (core model types), M01 deferred dialogue scope

## Purpose

Close the highest-value gaps between the shipped RainShadow intro dialogue and Infinity Engine–class conversation logic, in an order that unlocks real play: gated options, case-state consequences, reusable multi-conversation graphs, then **data/runtime separation** for authored content.

This document does **not** propose importing full IE/WeiDU script languages. Stay RainShadow-shaped: GDD §7.5 **intentions**, evidence/knowledge/trait gates, and case flags. Typed `DialogueCondition` / `DialogueAction` remain the control DSL (not free-form script strings).

## Current baseline

| Piece | Status |
|---|---|
| String-id graph (`CaseDialogueNode` / `CaseDialogueChoice`) | Shipped |
| Intro presenter walker (`DialoguePresenter`) | Shipped — view over pure `DialogueSession` |
| Linear Continue via `nextNodeID`; end via `endsDialogue` | Shipped |
| Author tone triad metadata (`DialogueTone`) | Shipped (not UI) |
| `onNodeShown` side channel (VO / presentation) | Shipped |
| Graph integrity helpers (`CaseDialogueGraph.report`) | Shipped |
| Static case journal dossier (`EmptyCoatJournalContent`) | Shipped (hotspot-driven notes + dialogue projection) |
| VO on nodes | **Shipped** — string-table `.voice` companions (IE TLK analogue); resolved to `voiceAssetName` at load; played on `onNodeShown` |
| `DialogueState` / `CaseState` / `WorldFlag` (Technical Architecture §14.1) | **Shipped (P0)** — pure value types in `DialogueStateModels.swift`; presenter holds `DialogueSession` / runtime context |
| Choice conditions + filtered UI + gate disclosure | **Shipped (P1)** — `DialogueCondition`, presenter filters, Empty Coat Press gate |
| Transition `onSelect` actions | **Shipped (P2)** — `DialogueAction` + pure applicator |
| Queued journal fragments on case state | **Shipped (P2 store)** |
| Journal-on-transition projection | **Shipped (P3)** — `JournalProjectionInput`, session merge, Press vs accept paths |
| Multi-graph session + presenter | **Shipped (P4)** — `DialogueGraph` / `DialogueSession`; desk monologue second graph |
| Versioned JSON graph loader | **Shipped (P4.5)** — `DialogueGraphLoader` + `AuthoredDialogueDocument` |
| Presentation leave/show cues | **Shipped (P4.5)** — `onLeaveCue` / `onShowCue`; office entrance uses `OfficeDialogueCues.clientEntrance` |
| Hotspot inspect graphs | **Shipped (P4.5)** — `office.hotspot-inspect.dialogue-catalog.json` via `OfficeHotspotDialogue` |
| String table (IE strref analogue) | **Shipped (P4.5)** — `strings.en.json` + `DialogueStringTable`; graphs use `textKey` / `speakerKey` |
| Intention tags (GDD §7.5) | **Shipped (P5)** — `DialogueIntention` on choices; `[Open]` / `[Press]` / … in choice rows |
| Composite conditions (`not` / `any` / `all`) | **Shipped (P6)** — IE `!` and `OR(n)` |
| Integer counters + comparisons | **Shipped (P6)** — IE `Global` / `GlobalGT` / `IncrementGlobal` |
| Talk counters + first-true entry scan | **Shipped (P6)** — `entryWhen` + `entryNodeIDs`, IE `FindFirstState` / `NumTimesTalkedTo` |
| Conversation transcript (scroll-back) | **Shipped (P7)** — `DialogueTranscript`; prior lines and player replies stay readable |
| Talk to an actor (approach → face → converse) | **Shipped (P7)** — `DialogueApproach`; NPC facing art-blocked |
| Presenter available to every scene | **Shipped (P7)** — `BaseGameScene` owns the panel and `presentDialogue` |
| Cross-graph EXTERN + catalog integrity | **Shipped (P8)** — `destinationGraphID`, `DialogueGraphCatalog`, `report(catalog:)` |
| Typed journal kinds | **Shipped (P9)** — `JournalEntryKind`, IE DLG bits 6/7/8 |
| Full case state persisted | **Shipped (fix)** — knowledge, evidence, journal, counters; previously lost on relaunch |

Empty Coat remains the compact M01 case opener. Broader evidence-gated branching beyond the Press path is deferred after M01 (see Milestone 01 plan §7 and Documentation README).

**Scale reality check:** the engine is considerably further along than the content — 7 shipped graphs, ~44 nodes, 14 player choices. Phases 6–8 were built with proving content where content existed (the office window's second look) and left dormant where it did not (Lila is hidden once her visit ends, so talk-to-actor has nobody to talk to yet).

## Frozen: classic Baldur’s Gate PC speech (do not regress)

**Canonical rule (GDD §7.5):** During an NPC conversation, **player-character lines are reply options (`CaseDialogueChoice`), not main-speaker Continue pages.**

This matches classic **Baldur’s Gate / Infinity Engine DLG** roles:

- **State** = actor (NPC) speech → may use `nextNodeID` / Continue for multi-page NPC beats.
- **Transition** = what the PC says → always a selectable choice, even when there is only one option.

| Anti-pattern (forbidden mid-convo) | Correct classic-BG pattern |
|---|---|
| `CaseDialogueNode(speaker: Harlan Voss, choices: [], nextNodeID: …)` delivering spoken acceptance / commitment | Same prose on `CaseDialogueChoice.text` attached to the preceding **NPC** state; `destinationID` → next NPC beat |

**Shipped reference:** Empty Coat formerly used `voss.accept` / `voss.accept.b` as PC Continue states; those were removed. Acceptance is now authored as choice text on the `lila.reply.*3.b` nodes → `lila.plea`, in `empty-coat.intro.dialogue.json` (the old `caseAcceptanceChoice` Swift constant no longer exists — prose moved to JSON in Phase 4.5).

**Exception:** `voss.monologue.*` interior monologue before Lila speaks may remain Continue-only.

**Guardrail:** `EmptyCoatCaseIntroductionTests.midConversationPCLinesAreReplyOptionsNotContinueStates` fails if mid-convo PC Continue states return, and `ShippedDialogueCatalogTests.noShippedGraphDeliversMidConversationPCSpeechAsAContinuePage` now applies the same rule to **every** shipped graph, so a new conversation is covered the day it ships.

Roadmap phases (triggers, actions, multi-graph) must **preserve** this authoring model—not reintroduce auto-delivered PC speaker states for convenience.

## Priority order

| Priority | Gap | Why this order |
|---|---|---|
| **P0** | Shared case / dialogue state | Conditions and actions need a place to read and write |
| **P1** | Choice / node **triggers** (conditions) | Unlocks evidence-gated lines — GDD’s core dialogue promise |
| **P2** | Transition **actions** (side effects) | Makes choices matter beyond which node you land on |
| **P3** | **Journal-on-transition** | Player-visible consequence of P2; reuses existing journal UI |
| **P4** | **Multi-graph / reusable runtime** | Second conversation without forking the intro presenter |
| **P4.5** | **External dialogue resources + string table** | IE-like data/runtime split; topology and prose out of Swift modules |
| **P5** | Intentions UI (+ remaining VO polish) | Player-facing GDD taxonomy; not required for branching logic |

Triggers before journal: journal entries without conditions stay static (current behavior). Multi-graph before externalization: one solid walker for many dialogues is cheaper than migrating content twice. String tables after graphs: resolve keys at load so the walker never sees keys.

## Design constraint vs Infinity Engine

Both systems treat conversation as a directed graph of actor states plus player transitions that advance or end the talk.

The table below was rebuilt against primary sources rather than memory: the IESDP **DLG V1.0** binary spec, the **BG:EE trigger/action lists**, the **WeiDU .D** authoring format, and GemRB's runtime `DialogHandler.cpp`.

| Concern | Infinity Engine | RainShadow |
|---|---|---|
| Graph topology | External **DLG** state/transition tables | Versioned **JSON** graphs / catalogs under `Resources/Dialogue/` |
| Text | Strrefs → **TLK** | `textKey` / `speakerKey` → `strings.en.json` (resolved at load) |
| **Entry selection** | Scan states from index 0, open on the **first whose state trigger passes** (`FindFirstState`); WeiDU `WEIGHT` exists only to reorder that scan | Explicit ordered `entryNodeIDs` + node `entryWhen`, falling back to `startNodeID`. Same first-true semantics, stated outright instead of implied by file order |
| Re-talk | `NumTimesTalkedTo` / `GT` / `LT`, engine-maintained | `timesTalkedTo(ownerID:atLeast:)` over the reserved `talk.<ownerID>` counter, bumped when a conversation **ends** |
| Variables | Integer `Global(name, scope, value)` with `GlobalGT` / `GlobalLT`, `SetGlobal`, `IncrementGlobal`; GLOBAL / LOCALS / area scopes | Boolean `flags` **and** integer `counters` on `CaseState`; `counterAtLeast` / `AtMost` / `Equals`, `setCounter` / `addToCounter`. Case scope only — IE's LOCALS has no analogue yet |
| Boolean logic | `OR(n)` block, `!` prefix | `.any([...])`, `.not(...)`, plus `.all([...])` for nesting; top-level `conditions` stays an AND list |
| Conditions | Script trigger **strings** | Typed `DialogueCondition` tagged union (deliberately not a script language) |
| Side effects | Script action **strings** on transitions | Typed `DialogueAction` on choices. IE has no state actions either — parity, not a gap |
| Transition flags | bit0 text · bit1 trigger · bit2 action · bit3 **terminates** · bit4 journal · bit5 interrupt · bit6/7/8 unsolved-quest / note / solved-quest · bit9 immediate-exec · bit10 clear-actions | `endsDialogue` on nodes; typed `JournalEntryKind` covers bits 6/7/8. Interrupt and immediate/delayed action bits remain out of scope |
| "Continue" | A transition with **no text** is not selectable; the engine opens the continue window (`DF_OPENCONTINUEWINDOW`) | `nextNodeID` with no visible choices renders CONTINUE; Space/Return never auto-picks a reply |
| Cross-file jumps | Transition carries `Next Dialog Resref` + state index (**EXTERN**); GemRB re-targets the actor owning that DLG | `destinationGraphID` + `destinationID` on choices, resolved from a `DialogueGraphCatalog` supplied by the caller. Conversation-local flags and history survive the jump, as they do in IE |
| Journal | Text + type flags on transitions | Earned fragments with a typed `kind`, projected into the casebook |
| Transcript | Text accumulates in a scrolling area and echoes to the message log | `DialogueTranscript` on the session; prior lines and the player's own replies stay scrolled back, dimmed |
| Talk flow | Click actor → walk into range → face → converse; target's action queue stopped | `DialogueApproach` + scene dispatch; PC turns to face. NPC facing is art-blocked, not code-blocked |
| World freeze | `DF_FREEZE_SCRIPTS` unless interrupt bits set; `nonPausing` DLGs exist | World pauses while the panel is up, except during cutscene mode. No non-pausing mode |
| Walker vs UI | Engine evaluates DLG; presentation separate | Pure `DialogueSession`; `DialoguePresenter` is the view, owned by `BaseGameScene` |

**Explicitly out of scope:** free-form script strings, binary DLG/TLK formats, WeiDU tooling, weighted first-true state selection *by file order* (we list candidates instead), hostile interrupt headers, BGEE immediate/delayed action bit parity, non-pausing dialogue, global timers (`GlobalTimerExpired` needs a game clock that does not exist), and party banters (see below).

---

## Phase 0 — State spine

**Goal:** Codable, SpriteKit-free value types so later phases have a shared context.

### Ship

- `WorldFlag` or a simple flag set (string keys; typed Empty Coat keys allowed)
- `CaseState` (case id + flags + optional knowledge/evidence ids)
- `DialogueState` (graph id, node id, conversation-local flags; optional choice history)
- Persist only if the save envelope already has a natural home; in-memory is acceptable for the first dialogue milestone

### Exit criteria

- Pure unit tests: set/get flags, Codable round-trip
- No presenter changes required

**Status: met** (`DialogueStateModels.swift` + `DialogueStateModelsTests`; presenter untouched).

### Rationale

IE triggers and actions are meaningless without a world they evaluate against. The journal already filters by `inspectedHotspotIDs` — same pattern, generalized.

---

## Phase 1 — Conditions / triggers

**Goal:** Hide or show player options (and optionally entry lines) based on case state. Highest gameplay value.

### Ship

Small condition DSL on choices (and optionally nodes), for example:

- `hasEvidence(id)`
- `hasFlag(id)` / `hasKnowledge(id)`
- `traitAtLeast(...)` (when traits exist)
- later: prior intention / tone used in this conversation

**Runtime rule (IE-like, RainShadow-simple):**

1. Build candidate choices for the current node.
2. Drop any whose conditions fail.
3. Optionally disclose the main reason for a special option, e.g. `[Evidence: Tram Receipt]` (GDD §7.5).
4. If zero choices remain and there is no `nextNodeID` / end path — fail soft in debug (authoring error).

**Node-level (optional second slice of Phase 1):**

- `entryWhen` for re-talk openings.
- Prefer **explicit start-node selection** from scene code over IE’s weighted state-0 scan until multi-entry graphs are required.

### Touch points

| Area | Change |
|---|---|
| `CaseDialogueModels.swift` | `DialogueCondition` + fields on choice (and maybe node) |
| Presenter or extracted walker | Filter choices before building rows |
| `CaseDialogueGraph.report` | Validate condition references where possible; still check destinations |
| Empty Coat graph | At least one intentional gated choice (stub evidence/flag is fine) |
| Tests | Visible vs hidden choices under flag fixtures |

### Exit criteria

- A triad (or follow-up) node can hide a Press-class option until a flag is set
- UI can show why a special option is available
- Graph integrity still requires an ungated path to an ending (document that gated-only endings need a fallback)

### Defer

- IE transition auto-take, WEIGHT, hostile interrupt flags

**Status: met** (`DialogueCondition` + presenter filtering + Empty Coat Press gate on `lila.triad.key` after cynical triad-1; pure tests in `DialogueConditionTests`).

---

## Phase 2 — Transition actions

**Goal:** Selecting a reply mutates case/dialogue state, not only the next node id.

### Ship

Optional `onSelect: [DialogueAction]` on `CaseDialogueChoice` (and later `onEnter` on nodes if needed).

Minimal action set:

| Action | Purpose |
|---|---|
| `setFlag` / `clearFlag` | Case / world state |
| `grantKnowledge` / `grantEvidence` | Feeds gates and journal |
| `setRelationship` / `adjustThreshold` | Stub interface early if needed; full rules later |
| `queueJournal` | Payload for Phase 3 |
| End dialogue | Prefer existing `endsDialogue` — avoid dual end systems |

### Runtime order (document one and keep it)

1. Evaluate choice availability.
2. Apply actions.
3. Advance to `destinationID`.
4. Fire presentation hooks (`onNodeShown`) for the new node.

Keep scene-level `onNodeShown` for **presentation** (voice-over). Game-state effects live on choice `onSelect`. Cinematic leave cues are **data** on the node (`onLeaveCue`), not hard-coded node ids in the scene.

### Exit criteria

- Selecting a line sets a flag that Phase 1 conditions can read later in the same conversation
- Unit tests cover action application without SpriteKit

### Defer

- BGEE immediate vs delayed action bits
- Free-form script strings

**Status: met** (`DialogueAction` / `DialogueActionRuntime`, Empty Coat cynical → conversation flag and acceptance → case flag + `queueJournal`; tests in `DialogueActionTests`).

---

## Phase 3 — Journal-on-transition

**Goal:** Dialogue outcomes update the casebook the way IE transitions can write journal text.

### Baseline

`EmptyCoatJournalContent` + `JournalOverlay` already project **hotspot** state into field notes and chronology. Extend that pattern to **dialogue**.

### Ship

- Journal update descriptors authored on choices (or as actions from Phase 2):
  - add chronology beat
  - append lead / body paragraph
  - mark entry status (e.g. unsolved / updated — light IE-like types)
  - clear `isNew` on read if not already handled
- `CaseState` (or a journal projection) stores **earned** fragments, not only static copy
- Intro graph: at least one choice writes a chronology line (e.g. client retained / Empty Coat opened)

### UX contract

- Prefer silent accumulate during conversation; optional toast later
- Optional batch apply on END DIALOGUE if mid-conversation flicker is a concern
- Do not invent unearned plot (existing journal rule: no Blue Room until design awards it)

### Exit criteria

- Completing intro with different paths can leave different journal leads
- Tests assert journal sections without opening SpriteKit

**Status: met** (`JournalProjectionInput` + chronology/lead projection; session merge on intro complete; Press queues `chrono.pressed-hard` vs acceptance-only `chrono.client-retained`; pure tests in `EmptyCoatJournalContentTests`).

---

## Phase 4 — Multi-graph architecture

**Goal:** Reuse one walker/presenter for any authored graph; support a second conversation without a special-case fork.

### Ship

1. **`DialogueGraph` value type**
   - `id`, `startNodeID`, `nodes: [CaseDialogueNode]`
   - Empty Coat becomes e.g. `EmptyCoatCaseIntroduction.graph`

2. **`DialogueWalker` / `DialogueSession` (pure)**
   - Holds `nodesByID`, `currentNodeID`
   - Evaluates conditions; applies actions
   - Presenter becomes a **view** over session state

3. **Presenter generalization**
   - `present(graph:session:onComplete:)` (rename `DialoguePresenter` → `DialoguePresenter` when cheap)
   - Keep Empty Coat chrome/layout; do not special-case monologue in the walker

4. **Cross-graph chaining (light EXTERN)**
   - Destination may be a node in the current graph **or** `graphID + nodeID`
   - Scene layer owns which NPC graph loads; full multi-file EXTERN tooling waits until a second speaker needs it

### Exit criteria

- Empty Coat behavior unchanged under golden / integrity tests
- A second stub graph (re-talk, hotspot monologue, etc.) runs through the same presenter
- Save may restore mid-conversation via `DialogueState` only if product needs it; otherwise persist “intro completed” only

**Status: met** (`DialogueGraph` + `DialogueSession`; presenter `present(graph:)`; Empty Coat `.graph`; `OfficeCaseFileMonologue` on desk after client retained; pure tests in `DialogueSessionTests`).

---

## Phase 4.5 — External dialogue resources (data / runtime split)

**Goal:** Match Baldur’s Gate EE’s separation of conversation **content** from **engine**: graphs and prose live as versioned resources; `DialogueSession` remains the pure walker; the presenter stays a view.

### Ship

1. **Codable graph model + loader**
   - `DialogueDocument` / `AuthoredDialogueDocument` (`schemaVersion: 1`)
   - `DialogueGraphLoader` (decode, validate, bundle + development resource paths, cache)
   - Optional node presentation fields: `onLeaveCue`, `onShowCue`

2. **Migrate shipped graphs out of Swift constructors**
   - `empty-coat.intro.dialogue.json` — Empty Coat monologue + Lila triad
   - `empty-coat.desk-monologue.dialogue.json` — post-retain desk monologue
   - Facades (`EmptyCoatCaseIntroduction`, `OfficeCaseFileMonologue`) load + cache only

3. **Data-driven presentation cues**
   - Client entrance: monologue cue node authors `onLeaveCue: "office.clientEntrance"`
   - `DetectiveOfficeScene` maps `from.onLeaveCue == OfficeDialogueCues.clientEntrance` (not node-id helpers)

4. **Hotspot inspect packages**
   - Catalog: `office.hotspot-inspect.dialogue-catalog.json`
   - Facade: `OfficeHotspotDialogue.graph(forHotspotID:)` — fail-fast if missing
   - Scene inspect path presents graphs; no ad-hoc `CaseDialogueNode` constructors

5. **String table (IE strref analogue)**
   - `strings.en.json` + `DialogueStringTable`
   - Authored fields: `text` **or** `textKey`, `speaker` **or** `speakerKey`; `queueJournal` may use `textKey`
   - Keys resolve at **load time** into runtime `DialogueGraph` (walker/UI see only strings)

### Resource layout

```text
RainShadow Shared/Resources/Dialogue/
  strings.en.json
  empty-coat.intro.dialogue.json
  empty-coat.desk-monologue.dialogue.json
  office.hotspot-inspect.dialogue-catalog.json
```

SPM `RainShadowCore` copies this folder for pure tests; Xcode app targets include the same files in Shared membership.

### Authoring conventions

| Item | Convention |
|---|---|
| Graph id | e.g. `case.empty-coat.intro`, `inspect.office.desk` |
| Resource base name | `defaultResourceName(for:)` → `empty-coat.intro.dialogue` (+ `.json`) |
| String keys | `dlg.speaker.*`, `dlg.<graphShort>.node.<id>.text`, `dlg.journal.<fragmentID>` |
| Leave cinematic | `onLeaveCue` string id; scene registers handlers |
| Classic BG PC speech | Still frozen — PC mid-convo lines are choices in JSON, not Continue speaker nodes |

### Exit criteria

- Empty Coat + desk monologue + hotspot inspect prose live under `Resources/Dialogue/`
- Facades load JSON; Swift modules do not embed multi-line dialogue constructors
- Entrance cinematic fires from `onLeaveCue`, not hard-coded monologue node id in the scene
- String table resolves for shipped packages; pure tests cover loader, catalog, and key resolution
- Existing integrity / BG PC-speech / journal projection tests remain green

**Status: met** (`DialogueGraphLoader`, `DialogueStringTable`, facades, office cue wiring, hotspot catalog; tests in `DialogueGraphLoaderTests`, `DialogueStringTableTests`, `OfficeHotspotDialogueTests`, Empty Coat suite).

---

## Phase 5 — Intentions, tone, and remaining VO polish

| Item | Approach | Status |
|---|---|---|
| **Intention tags** (Open / Press / Feign / Trade / Observe / Leave) | `DialogueIntention` on choices; player-facing `[Open]` / `[Press]` / … prefixes via `labeledBodyText` | **Shipped** |
| **Tone** | Writer/test metadata only (`DialogueTone`) — not shown in UI | Shipped (metadata) |
| **UI** | Intention prefixes + Phase 1 gate disclosure (`[Evidence: …]`); matching intention/gate labels dedupe | **Shipped** |
| **VO** | `voiceAssetName` on show via `onNodeShown` | **Shipped** for Empty Coat monologue + Lila graph (Press node may stay silent) |
| **Docs / architecture** | Align Technical Architecture with session-backed presenter + external resources | **Shipped** |

### Ship (intentions)

- `DialogueIntention` enum (`open` / `press` / `feign` / `trade` / `observe` / `leave`) with GDD display labels
- Optional `intention` on runtime + authored choices; JSON field `intention`
- Row text: intention first, then gate disclosure (`[Press]  [Evidence: Tram Receipt]  …`); drop gate when it equals the intention label
- Empty Coat: all player choices tagged (triads + acceptance); Press option uses `intention: press`

**Status: met** (`DialogueIntention`, Empty Coat tags, `DialogueIntentionTests`, disclosure tests extended).

---

---

## Phase 6 — Conditions, counters, and the entry scan

**Goal:** Close the authoring gaps that made conversations frozen in time — no "unless", no "either", no integers, and one fixed opening node per graph.

### Ship

1. **Composite conditions** — `.not` (IE `!`) and `.any` (IE `OR(n)`), plus `.all` for nesting an AND under an `any`. `DialogueCondition` becomes `indirect`; the top-level `conditions` array keeps AND semantics so every shipped file is untouched. Nesting capped at depth 8.
2. **Gate-reference validation** — `IntegrityReport.conditionLeafIDs` / `actionWrittenStateIDs` / `externallySuppliedConditionIDs`. This is the "validate condition references" Phase 1 promised and never delivered, and it catches the failure mode that actually bites: a gate keyed on an id nothing sets, which reads as a choice that is simply never there.
3. **Integer counters** — `CaseState.counters`, conditions `counterAtLeast` / `counterAtMost` / `counterEquals`, actions `setCounter` / `addToCounter`. Flags stay for boolean intent; `hasFlag(x)` ≡ IE `Global(x,"GLOBAL",1)`.
4. **Talk counters** — `timesTalkedTo(ownerID:atLeast:)` over the reserved `talk.<ownerID>` namespace, bumped when a conversation **ends** so `atLeast: 1` reads as "has talked before" with no off-by-one.
5. **Entry scan** — node `entryWhen` (IE state trigger) + graph `entryNodeIDs`, scanned first-true with `startNodeID` as the guaranteed fallback.

### Authoring rules the loader enforces

- The start node must carry **no** `entryWhen`. The fallback returns it unconditionally, so a gate there would silently never run.
- Entry candidates must exist.
- Reachability seeds from **every** candidate, or an alternate opening reports as an orphan.

### Exit criteria

- A second look at the office window opens on a different node (shipped content, not a fixture)
- Every shipped gate id is one some action — or a named scene write — can produce

**Status: met** (`DialogueConditionCompositionTests`, `DialogueCounterTests`, `DialogueEntryScanTests`, `OfficeHotspotDialogueTests.lookingAtTheWindowTwiceOpensADifferentNode`).

---

## Phase 7 — Transcript and talk-to-actor

**Goal:** Stop discarding the writing, and let a click on a person start a conversation.

### Ship

1. **`DialogueTranscript`** — pure, session-owned, ring-capped at 60, reset per conversation, never persisted. Records each node **and the reply the player committed to**, which BG:EE shows and RainShadow made invisible. `Entry.Kind` (`speech` / `monologue` / `playerReply` / `title`) drives typography, replacing the `node.speaker == "Case opened"` string compare.
2. **Presenter stack** — prior lines render above the live one in the same scroll region at ~55% alpha; body height is the stack sum; new lines scroll to the bottom. `applyBodyScrollOffset` gains the upper clamp it never had.
3. **`DialogueApproach`** — pure approach solver requiring `reachesExactly`, never a merely present path (which may relocate and park the detective across a wall from the person he is talking to).
4. **`BaseGameScene` owns the panel** and the single `presentDialogue(_:ownerID:onComplete:)` door, so any scene can converse.

### Known limits

NPC facing on approach is **art-blocked**: `ClientActorNode`'s atlas is an arrival idle plus two departure bins, with no "turns to look at you" frame. The PC turns; the NPC does not. Do not fake it by reusing a departure frame as an idle.

Lila is bound as a talkable actor, but in the shipped Act-I flow she is hidden the moment her visit ends, so the path is dormant by construction — it is the generalisation the next NPC needs.

**Status: met** (`DialogueTranscriptTests`, `DialogueApproachTests`).

---

## Phase 8 — EXTERN and catalog integrity

**Goal:** Let a conversation hand off between graphs, and check the whole shipped body of content rather than one file at a time.

### Ship

1. **`DialogueGraphCatalog`** — the graphs a conversation may jump into. The walker never loads anything; the caller supplies the reachable set.
2. **`destinationGraphID` on choices** — IE EXTERN. Choices only, as in DLG, where only a transition can jump files. Conversation flags and choice history survive the jump.
3. **`CaseDialogueGraph.report(catalog:)`** — resolves cross-graph links, and computes ending-reachability *across* the catalog by fixed point. A graph whose only exit is an EXTERN cannot satisfy per-graph `reachesEnding` and is not broken for it, so per-graph soundness splits into `isStructurallySound` + `reachesEnding`.
4. **`ShippedDialogueCatalogTests`** — one suite that loads every shipped resource the way the game does and asserts the loader's own authoring rules over it.

An unresolvable jump ends the conversation rather than wedging the panel, and deliberately does **not** assert: the catalog report catches it in tests over shipped content, which is earlier and stricter than a debug trap that only fires if a player picks that reply.

**Status: met** (`DialogueCrossGraphTests`, `ShippedDialogueCatalogTests`).

---

## Phase 9 — Typed journal kinds

`QueuedJournalFragment.kind` becomes `JournalEntryKind` (`chronology` / `lead` / `note` / `quest` / `questDone`) — the IE DLG journal bits 6/7/8 — with a tolerant decoder mapping unknown values to `.note` so a newer build's save cannot brick the casebook. A free string meant `"chronolgy"` was a silent no-op.

**Deferred:** the unsolved→solved *status transition* and a `setJournalStatus` action, until there are quests to mark solved.

**Status: met** (`DialogueActionTests`).

## Suggested milestone slices

| Slice | Scope | Status |
|---|---|---|
| **M-dialogue-A** | Phase 0 + Phase 1 (flags + gated choices) | Met |
| **M-dialogue-B** | Phase 2 + Phase 3 (actions + journal writes) | Met |
| **M-dialogue-C** | Phase 4 (walker extract + second graph) | Met |
| **M-dialogue-data** | Phase 4.5 (JSON graphs, cues, hotspots, string table) | Met |
| **M-dialogue-D** | Phase 5 (intentions UI polish) | Met |
| **M-dialogue-fix** | Correctness pass (see below) | Met |
| **M-dialogue-E** | Phase 6 (conditions, counters, entry scan) | Met |
| **M-dialogue-F** | Phase 7 (transcript, talk-to-actor) | Met |
| **M-dialogue-G** | Phase 8 (EXTERN, catalog integrity) | Met |
| **M-dialogue-H** | Phase 9 (typed journal kinds) | Met |

## Dependency sketch

```text
CaseState / flags
       │
       ▼
  conditions on choices  ──────►  filtered UI + [Evidence: …]
       │
       ▼
  actions on select  ───────────►  flags / knowledge
       │
       ▼
  journal projections  ─────────►  casebook updates
       │
       ▼
  DialogueSession + multi-graph  ─►  re-talk / desk monologue
       │
       ▼
  external JSON + string table  ─►  data/runtime split (P4.5)
       │
       ▼
  intention tags on choices  ───►  [Open] / [Press] / … row UI (P5)
```

## What not to build yet

- Full IE script language / trigger tables as strings
- Weighted state selection by file order (superseded by explicit `entryNodeIDs`)
- Full BG2/EE journal bit-type parity — `quest` / `questDone` kinds exist, but the unsolved→solved **status transition** waits until there are quests to mark solved
- Global timers — `GlobalTimerExpired` needs a game clock RainShadow does not have
- IE's LOCALS (per-actor) variable scope — nothing has needed a conversation-scoped integer
- Non-pausing dialogue, interrupt bits, immediate/delayed action bits
- Deduction board as a hard dependency (hypotheses may **set flags** that feed conditions later; do not block dialogue on the board)

### Barks, interjections, and banters — blocked on companions, not on dialogue

IE's ambient conversation layer is a **party** mechanic: `Interact()` fires banter, `BANTTIMG.2DA` sets frequency and probability, `B*.DLG` holds the lines, and WeiDU's `INTERJECT` guards each one with a once-only global so it plays a single time per game.

RainShadow has no party. Companions are deferred to Movement Roadmap Phase 4 (formations, portrait order, selection sets), and until an NPC can walk beside Voss there is nobody to banter *with*. A stub protocol with no implementation would be a maintenance tax rather than staging, so none exists. Revisit when companions are real; the IE reference above is the starting point.

## Source map (implementation touch points)

| Path | Role today |
|---|---|
| `RainShadow Shared/Gameplay/Navigation/CaseDialogueModels.swift` | Runtime node/choice schema, `DialogueCondition` / `DialogueAction`, graph integrity |
| `RainShadow Shared/Gameplay/Navigation/DialogueSession.swift` | `DialogueGraph` (+ entry scan, authoring validation) + pure `DialogueSession` walker |
| `RainShadow Shared/Gameplay/Navigation/DialogueGraphCatalog.swift` | EXTERN target set + whole-catalog integrity report |
| `RainShadow Shared/Gameplay/Navigation/DialogueTranscript.swift` | Conversation scroll-back model (presentation state, never persisted) |
| `RainShadow Shared/Gameplay/Navigation/DialogueDeferralState.swift` | Holds a step's *view* while a cinematic owns the screen |
| `RainShadow Shared/Gameplay/Navigation/DialogueApproach.swift` | Where the PC stands to talk to somebody |
| `RainShadow Shared/Core/Scene/BaseGameScene.swift` | Owns the presenter and the one `presentDialogue` door |
| `RainShadow Shared/Gameplay/Navigation/DialogueGraphLoader.swift` | Versioned JSON load/encode, catalogs, resource resolution, cache |
| `RainShadow Shared/Gameplay/Navigation/DialogueStringTable.swift` | String table + authored document models + key / voice resolution |
| `RainShadow Shared/Gameplay/Navigation/DialogueVoiceResref.swift` | Companion `.voice` keys + resref → playable filename |
| `RainShadow Shared/Gameplay/Navigation/DialogueStateModels.swift` | P0 state spine: `WorldFlag`, `CaseState`, `DialogueState`, `DialogueRuntimeContext` |
| `RainShadow Shared/Gameplay/Navigation/EmptyCoatCaseIntroduction.swift` | Facade: IDs + load Empty Coat intro graph |
| `RainShadow Shared/Gameplay/Navigation/OfficeCaseFileMonologue.swift` | Facade: desk monologue graph |
| `RainShadow Shared/Gameplay/Navigation/OfficeHotspotDialogue.swift` | Facade: inspect catalog by hotspot id |
| `RainShadow Shared/Resources/Dialogue/` | Shipped graphs, catalog, `strings.en.json` |
| `RainShadow Shared/UI/DialoguePresenter.swift` | Presentation view over session; `onNodeShown` / `shouldDeferAdvance` |
| `RainShadow Shared/Scenes/DetectiveOffice/DetectiveOfficeScene.swift` | Cue map (`onLeaveCue` → entrance), VO, present graphs |
| `RainShadow Shared/Gameplay/Navigation/EmptyCoatJournalContent.swift` | Static + hotspot journal projection |
| `Tests/RainShadowCoreTests/DialogueGraphLoaderTests.swift` | Loader, schema, catalog, shipped package load |
| `Tests/RainShadowCoreTests/DialogueStringTableTests.swift` | String table + key resolution contracts |
| `Tests/RainShadowCoreTests/DialogueIntentionTests.swift` | GDD intention taxonomy + Empty Coat tags + row prefixes |
| `Tests/RainShadowCoreTests/OfficeHotspotDialogueTests.swift` | Inspect catalog coverage vs layout observations |
| `Tests/RainShadowCoreTests/EmptyCoatCaseIntroductionTests.swift` | Graph integrity, BG PC-speech, entrance cue contracts |
| `Tests/RainShadowCoreTests/ShippedDialogueCatalogTests.swift` | **Every shipped resource** through the loader and catalog report |
| `Tests/RainShadowCoreTests/DialogueEntryScanTests.swift` | `FindFirstState` analogue, talk counters, entry authoring guards |
| `Tests/RainShadowCoreTests/DialogueTranscriptTests.swift` | Scroll-back model |
| `Tests/RainShadowCoreTests/DialogueCrossGraphTests.swift` | EXTERN + catalog soundness |
| `Tests/RainShadowCoreTests/DialogueApproachTests.swift` | Approach solver (proves `route` would have lied) |
| `Documentation/TechnicalArchitecture.md` §14.1 | Core state types + dialogue resource schema |
| `Documentation/GameDesignDocument.md` §7.5 | Intentions and gate disclosure |

## Correctness pass (defects found while auditing against IE)

Reviewing the shipped code against the DLG spec turned up four defects that had nothing to do with parity — they were silently discarding player state:

| Defect | Effect | Fix |
|---|---|---|
| `GameSession.persist()` wrote only `caseState.flags` | Knowledge, evidence, and earned journal fragments were merged into the live session and **lost on relaunch**, so evidence-gated dialogue could not work | `SaveSnapshot` persists the whole `CaseState`; `load()` accepts any envelope at or below current, so an additive field never wipes a save |
| `mergeCaseStateFromDialogue` used `formUnion` | `clearCaseFlag` was a permanent no-op at session level | `CaseState.applying(_:wasSeeded:)` — a seeded result is authoritative |
| Hotspot inspect never merged its result | Any action authored on an inspect graph was silently dropped | One `presentDialogue` door that seeds and merges as a pair |
| Continue deferred *before* advancing; choices advanced *then* deferred | A deferred Continue parked the session on the node just left; `onLeaveCue` was unauthorable anywhere but a Continue-only node | `DialogueDeferralState` — both paths advance, then hold only the view |

Also: duplicate node ids **trapped** (`Dictionary(uniqueKeysWithValues:)`) instead of reporting, duplicate catalog graph ids silently last-won, and `onShowCue` was decoded, carried onto every node, and read by nobody.

## Comparison snapshot (IE vs shipped local)

Both systems are directed graphs of actor states + player transitions. RainShadow externalizes topology (JSON) and prose (string table keys), with typed conditions/actions instead of IE script strings, and now matches IE on the mechanics that carry reactivity: first-true entry selection, talk counters, integer variables with comparisons, `!`/`OR` composition, EXTERN, and a readable conversation transcript.

Remaining deliberate divergences: no script-string DSL, no interrupt/immediate-action bits, no non-pausing dialogue, no global timers, no LOCALS scope, no banters (blocked on companions), and no mid-conversation save — which IE does not do either.

## Open questions (do not block shipped phases)

1. Are GDD §7.5 intention tags meant to approximate IE trigger/action scripting, or a deliberately different player-facing taxonomy? Current answer: **taxonomy + gates**, not script language.
2. Should journal updates apply mid-conversation or only on END DIALOGUE? Prefer silent mid-conversation accumulate; batch if UX requires. **Current:** accumulate on choice select via `queueJournal`.
3. Will later cases reuse the same presenter for non-intro graphs? **Yes** — Phase 4 + 4.5 assume `present(graph:)`.
4. Is mid-conversation save required? Default **no** — only flags and “intro completed” unless product expands `SaveSnapshot`.
5. Additional locales: add `strings.<locale>.json` and a locale picker on `DialogueStringTable.load`; graphs keep stable keys. Note `DialogueGraphLoader.graphCache` and `DialogueStringTable.tableCache` are process-lifetime, so a locale switch needs cache-busting.
6. Should the transcript survive a cross-graph EXTERN? Currently **yes** — an EXTERN is the same conversation in IE, so the scroll-back continues. It resets only when a new conversation is presented.
7. NPC facing on talk approach is art-blocked (see Phase 7). Revisit when an NPC atlas ships idle facing bins.

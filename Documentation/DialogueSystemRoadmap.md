# Dialogue system roadmap

- Status: Phase 0–5 complete (state → journal → multi-graph → external resources → intention tags UI)
- Version: 0.8
- Date: 6 August 2026
- Related: GDD §7.5 (Dialogue), Technical Architecture §14.1 (core model types), M01 deferred dialogue scope

## Purpose

Close the highest-value gaps between the shipped RainShadow intro dialogue and Infinity Engine–class conversation logic, in an order that unlocks real play: gated options, case-state consequences, reusable multi-conversation graphs, then **data/runtime separation** for authored content.

This document does **not** propose importing full IE/WeiDU script languages. Stay RainShadow-shaped: GDD §7.5 **intentions**, evidence/knowledge/trait gates, and case flags. Typed `DialogueCondition` / `DialogueAction` remain the control DSL (not free-form script strings).

## Current baseline

| Piece | Status |
|---|---|
| String-id graph (`CaseDialogueNode` / `CaseDialogueChoice`) | Shipped |
| Intro presenter walker (`CaseIntroductionPresenter`) | Shipped — view over pure `DialogueSession` |
| Linear Continue via `nextNodeID`; end via `endsDialogue` | Shipped |
| Author tone triad metadata (`DialogueTone`) | Shipped (not UI) |
| `onNodeShown` side channel (VO / presentation) | Shipped |
| Graph integrity helpers (`CaseDialogueGraph.report`) | Shipped |
| Static case journal dossier (`EmptyCoatJournalContent`) | Shipped (hotspot-driven notes + dialogue projection) |
| `voiceAssetName` on nodes | **Shipped** — Empty Coat monologue + Lila nodes via `onNodeShown` |
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

Empty Coat remains the compact M01 case opener. Broader evidence-gated branching beyond the Press path is deferred after M01 (see Milestone 01 plan §7 and Documentation README).

## Frozen: classic Baldur’s Gate PC speech (do not regress)

**Canonical rule (GDD §7.5):** During an NPC conversation, **player-character lines are reply options (`CaseDialogueChoice`), not main-speaker Continue pages.**

This matches classic **Baldur’s Gate / Infinity Engine DLG** roles:

- **State** = actor (NPC) speech → may use `nextNodeID` / Continue for multi-page NPC beats.
- **Transition** = what the PC says → always a selectable choice, even when there is only one option.

| Anti-pattern (forbidden mid-convo) | Correct classic-BG pattern |
|---|---|
| `CaseDialogueNode(speaker: Harlan Voss, choices: [], nextNodeID: …)` delivering spoken acceptance / commitment | Same prose on `CaseDialogueChoice.text` attached to the preceding **NPC** state; `destinationID` → next NPC beat |

**Shipped reference:** Empty Coat formerly used `voss.accept` / `voss.accept.b` as PC Continue states; those were removed. Acceptance lives on `caseAcceptanceChoice` on `lila.reply.*3.b` nodes → `lila.plea`.

**Exception:** `voss.monologue.*` interior monologue before Lila speaks may remain Continue-only.

**Guardrail:** `EmptyCoatCaseIntroductionTests.midConversationPCLinesAreReplyOptionsNotContinueStates` fails if mid-convo PC Continue states return. Keep that class of assertion on future graphs.

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

| Concern | Infinity Engine (DLG V1) | RainShadow (shipped) |
|---|---|---|
| Graph topology | External **DLG** state/transition tables | Versioned **JSON** graphs / catalogs under `Resources/Dialogue/` |
| Text | Strrefs → **TLK** | **textKey / speakerKey → `strings.en.json`** (resolved at load) |
| Conditions | Script trigger strings on states/transitions | Small typed `DialogueCondition` set |
| Side effects | Script action strings on transitions | Small typed `DialogueAction` set (`queueJournal` text keyable) |
| Presentation cues | Separate from game-state actions | Node `onLeaveCue` / `onShowCue` (scene maps cue IDs) |
| Chaining | Within-file and cross-DLG (GOTO / EXTERN) | In-graph ids first; light `graphID + nodeID` later |
| Journal | Text / type flags on transitions | Earned fragments projected into casebook |
| Entry | Often state 0 + first-true triggers / WEIGHT | Explicit start node (+ optional `entryWhen` later) |
| Walker vs UI | Engine evaluates DLG; presentation separate | Pure `DialogueSession`; `CaseIntroductionPresenter` is the view |

**Explicitly out of scope:** free-form script strings, binary DLG/TLK formats, WeiDU tooling, weighted first-true state selection from state 0, hostile interrupt headers, BGEE immediate/delayed action bit parity, full multi-NPC EXTERN interjection tooling.

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
   - `present(graph:session:onComplete:)` (rename `CaseIntroductionPresenter` → `DialoguePresenter` when cheap)
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

## Suggested milestone slices

| Slice | Scope | Status |
|---|---|---|
| **M-dialogue-A** | Phase 0 + Phase 1 (flags + gated choices) | Met |
| **M-dialogue-B** | Phase 2 + Phase 3 (actions + journal writes) | Met |
| **M-dialogue-C** | Phase 4 (walker extract + second graph) | Met |
| **M-dialogue-data** | Phase 4.5 (JSON graphs, cues, hotspots, string table) | Met |
| **M-dialogue-D** | Phase 5 (intentions UI polish) | Met |

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
- Cross-DLG EXTERN with interrupt/hostility headers
- Weighted first-true state selection from state 0
- Full BG2/EE journal bit-type parity
- Deduction board as a hard dependency (hypotheses may **set flags** that feed conditions later; do not block dialogue on the board)

## Source map (implementation touch points)

| Path | Role today |
|---|---|
| `RainShadow Shared/Gameplay/Navigation/CaseDialogueModels.swift` | Runtime node/choice schema, `DialogueCondition` / `DialogueAction`, graph integrity |
| `RainShadow Shared/Gameplay/Navigation/DialogueSession.swift` | `DialogueGraph` + pure `DialogueSession` walker |
| `RainShadow Shared/Gameplay/Navigation/DialogueGraphLoader.swift` | Versioned JSON load/encode, catalogs, resource resolution, cache |
| `RainShadow Shared/Gameplay/Navigation/DialogueStringTable.swift` | String table + authored document models + key resolution |
| `RainShadow Shared/Gameplay/Navigation/DialogueStateModels.swift` | P0 state spine: `WorldFlag`, `CaseState`, `DialogueState`, `DialogueRuntimeContext` |
| `RainShadow Shared/Gameplay/Navigation/EmptyCoatCaseIntroduction.swift` | Facade: IDs + load Empty Coat intro graph |
| `RainShadow Shared/Gameplay/Navigation/OfficeCaseFileMonologue.swift` | Facade: desk monologue graph |
| `RainShadow Shared/Gameplay/Navigation/OfficeHotspotDialogue.swift` | Facade: inspect catalog by hotspot id |
| `RainShadow Shared/Resources/Dialogue/` | Shipped graphs, catalog, `strings.en.json` |
| `RainShadow Shared/UI/CaseIntroductionPresenter.swift` | Presentation view over session; `onNodeShown` / `shouldDeferAdvance` |
| `RainShadow Shared/Scenes/DetectiveOffice/DetectiveOfficeScene.swift` | Cue map (`onLeaveCue` → entrance), VO, present graphs |
| `RainShadow Shared/Gameplay/Navigation/EmptyCoatJournalContent.swift` | Static + hotspot journal projection |
| `Tests/RainShadowCoreTests/DialogueGraphLoaderTests.swift` | Loader, schema, catalog, shipped package load |
| `Tests/RainShadowCoreTests/DialogueStringTableTests.swift` | String table + key resolution contracts |
| `Tests/RainShadowCoreTests/DialogueIntentionTests.swift` | GDD intention taxonomy + Empty Coat tags + row prefixes |
| `Tests/RainShadowCoreTests/OfficeHotspotDialogueTests.swift` | Inspect catalog coverage vs layout observations |
| `Tests/RainShadowCoreTests/EmptyCoatCaseIntroductionTests.swift` | Graph integrity, BG PC-speech, entrance cue contracts |
| `Documentation/TechnicalArchitecture.md` §14.1 | Core state types + dialogue resource schema |
| `Documentation/GameDesignDocument.md` §7.5 | Intentions and gate disclosure |

## Comparison snapshot (IE vs shipped local)

Both systems are directed graphs of actor states + player transitions. RainShadow now also externalizes topology (JSON) and prose (string table keys), with typed conditions/actions instead of IE script strings. Remaining gaps vs IE for later work: cross-graph EXTERN tooling, weighted entry selection, intentions UI (Phase 5), and mid-conversation save if product requires it.

## Open questions (do not block shipped phases)

1. Are GDD §7.5 intention tags meant to approximate IE trigger/action scripting, or a deliberately different player-facing taxonomy? Current answer: **taxonomy + gates**, not script language.
2. Should journal updates apply mid-conversation or only on END DIALOGUE? Prefer silent mid-conversation accumulate; batch if UX requires. **Current:** accumulate on choice select via `queueJournal`.
3. Will later cases reuse the same presenter for non-intro graphs? **Yes** — Phase 4 + 4.5 assume `present(graph:)`.
4. Is mid-conversation save required? Default **no** — only flags and “intro completed” unless product expands `SaveSnapshot`.
5. Additional locales: add `strings.<locale>.json` and a locale picker on `DialogueStringTable.load`; graphs keep stable keys.

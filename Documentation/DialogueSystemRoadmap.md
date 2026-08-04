# Dialogue system roadmap

- Status: Phase 0–4 complete (state → journal → multi-graph session); P5 still planning
- Version: 0.6
- Date: 4 August 2026
- Related: GDD §7.5 (Dialogue), Technical Architecture §14.1 (core model types), M01 deferred dialogue scope

## Purpose

Close the highest-value gaps between the shipped RainShadow intro dialogue and Infinity Engine–class conversation logic, in an order that unlocks real play: gated options, case-state consequences, then reusable multi-conversation graphs.

This document does **not** propose importing full IE/WeiDU script languages. Stay RainShadow-shaped: GDD §7.5 **intentions**, evidence/knowledge/trait gates, and case flags.

## Current baseline

| Piece | Status |
|---|---|
| String-id graph (`CaseDialogueNode` / `CaseDialogueChoice`) | Shipped |
| Intro presenter walker (`CaseIntroductionPresenter`) | Shipped |
| Linear Continue via `nextNodeID`; end via `endsDialogue` | Shipped |
| Author tone triad metadata (`DialogueTone`) | Shipped (not UI) |
| `onNodeShown` side channel (e.g. entrance cues) | Shipped |
| Graph integrity helpers (`CaseDialogueGraph.report`) | Shipped |
| Static case journal dossier (`EmptyCoatJournalContent`) | Shipped (hotspot-driven notes + dialogue projection) |
| `voiceAssetName` on nodes | Modeled; Empty Coat VO wired via `onNodeShown` in office |
| `DialogueState` / `CaseState` / `WorldFlag` (Technical Architecture §14.1) | **Shipped (P0)** — pure value types in `DialogueStateModels.swift` |
| Choice conditions + filtered UI + gate disclosure | **Shipped (P1)** — `DialogueCondition`, presenter filters, Empty Coat Press gate |
| Transition `onSelect` actions | **Shipped (P2)** — `DialogueAction` + pure applicator; P1 flag bridge removed |
| Queued journal fragments on case state | **Shipped (P2 store)** |
| Journal-on-transition projection | **Shipped (P3)** — `JournalProjectionInput`, session merge, Press vs accept paths |
| Multi-graph session + presenter | **Shipped (P4)** — `DialogueGraph` / `DialogueSession`; desk monologue second graph |

Empty Coat is intentionally compact. Broader evidence-gated branching is deferred after M01 (see Milestone 01 plan §7 and Documentation README).

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
| **P5** | Intentions UI + VO | Polish and GDD labeling; not required for branching logic |

Triggers before journal: journal entries without conditions stay static (current behavior). Multi-graph before VO: one solid walker for many dialogues is cheaper than wiring audio twice.

## Design constraint vs Infinity Engine

Both systems treat conversation as a directed graph of actor states plus player transitions that advance or end the talk.

| Concern | Infinity Engine (DLG V1) | RainShadow target (this roadmap) |
|---|---|---|
| Text | Strrefs → TLK | Authored strings (later localization if needed) |
| Conditions | Script trigger strings on states/transitions | Small typed `DialogueCondition` set |
| Side effects | Script action strings on transitions | Small typed `DialogueAction` set |
| Chaining | Within-file and cross-DLG (GOTO / EXTERN) | In-graph ids first; light `graphID + nodeID` later |
| Journal | Text / type flags on transitions | Earned fragments projected into casebook |
| Entry | Often state 0 + first-true triggers / WEIGHT | Explicit start node (+ optional `entryWhen` later) |

**Explicitly out of scope for early phases:** free-form script strings, weighted first-true state selection, hostile interrupt headers, BGEE immediate/delayed action bit parity, full multi-NPC EXTERN interjection tooling.

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

Keep scene-level `onNodeShown` for **presentation** (entrance cues). Move **game-state** effects onto the choice so authors do not depend on scene callbacks.

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

## Phase 5 — Intentions, tone, and VO

| Item | Approach |
|---|---|
| **Intention tags** (Open / Press / Feign / Trade / Observe / Leave) | Player-facing taxonomy per GDD §7.5; can replace or complement `DialogueTone` |
| **Tone** | May remain writer/test metadata only |
| **UI** | Optional small label/icon; gate reason disclosure already from Phase 1 |
| **VO** | Wire `voiceAssetName` through the dialogue bus on node show; Empty Coat may stay silent until assets exist |
| **Docs / architecture** | Align Technical Architecture `DialogueState` with the implemented model; remove or implement any phantom type |

---

## Suggested milestone slices

| Slice | Scope |
|---|---|
| **M-dialogue-A** | Phase 0 + Phase 1 (flags + gated choices) |
| **M-dialogue-B** | Phase 2 + Phase 3 (actions + journal writes) |
| **M-dialogue-C** | Phase 4 (walker extract + second graph) |
| **M-dialogue-D** | Phase 5 (intentions UI, VO, doc cleanup) |

**M-dialogue-A alone** closes the largest design gap vs BG (“why can’t I say that yet?”) and matches the README’s deferred “evidence-gated dialogue.”

## First vertical slice (recommended kickoff when implementation starts)

1. Add `DialogueCondition.hasFlag(String)` and `DialogueAction.setFlag(String)`.
2. Thread a mutable dialogue/case context (flag set) into the conversation runtime.
3. On Empty Coat, gate **one** extra choice or post-triad beat on a flag set earlier in the same graph.
4. On END DIALOGUE, if that flag is set, append one chronology entry in journal content.
5. Tests: condition filter + action + journal fragment.

That is the smallest path through **triggers → side effects → journal** without multi-graph extraction.

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
  extract DialogueWalker  ──────►  multi-graph + re-talk
       │
       ▼
  intentions + VO
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
| `RainShadow Shared/Gameplay/Navigation/CaseDialogueModels.swift` | Node/choice schema, `DialogueCondition`, graph integrity + visibleChoices |
| `RainShadow Shared/Gameplay/Navigation/DialogueSession.swift` | P4 `DialogueGraph` + pure `DialogueSession` walker |
| `RainShadow Shared/Gameplay/Navigation/OfficeCaseFileMonologue.swift` | P4 stub second graph (desk monologue) |
| `RainShadow Shared/Gameplay/Navigation/DialogueStateModels.swift` | P0 state spine: `WorldFlag`, `CaseState`, `DialogueState`, `DialogueRuntimeContext` |
| `Tests/RainShadowCoreTests/DialogueConditionTests.swift` | P1 condition filter / disclosure / Empty Coat Press gate |
| `Tests/RainShadowCoreTests/DialogueActionTests.swift` | P2 action apply + Empty Coat acceptance journal queue |
| `RainShadow Shared/Gameplay/Navigation/EmptyCoatCaseIntroduction.swift` | Authored Empty Coat graph |
| `RainShadow Shared/UI/CaseIntroductionPresenter.swift` | Presentation + walk |
| `RainShadow Shared/Scenes/DetectiveOffice/DetectiveOfficeScene.swift` | `onNodeShown` / entrance sequencing |
| `RainShadow Shared/Gameplay/Navigation/EmptyCoatJournalContent.swift` | Static + hotspot journal projection |
| `Tests/RainShadowCoreTests/EmptyCoatCaseIntroductionTests.swift` | Graph and presenter contracts |
| `Documentation/TechnicalArchitecture.md` §14.1 | Named `DialogueState` et al. |
| `Documentation/GameDesignDocument.md` §7.5 | Intentions and gate disclosure |

## Comparison snapshot (IE vs shipped local)

See deep-research comparison (session research): both systems are directed graphs; IE adds strrefs, script triggers/actions, cross-resource chaining, and journal-on-transition. Local system is a single in-memory string-id graph with Continue paging, tone metadata, and a decoupled journal. Gaps listed above map to Phases 1–5.

## Open questions (do not block Phase 0–1)

1. Are GDD §7.5 intention tags meant to approximate IE trigger/action scripting, or a deliberately different player-facing taxonomy? Current answer for this roadmap: **taxonomy + gates**, not script language.
2. Should journal updates apply mid-conversation or only on END DIALOGUE? Prefer silent mid-conversation accumulate; batch if UX requires.
3. Will later cases reuse the same presenter for non-intro graphs? Phase 4 assumes yes.
4. Is mid-conversation save required for M-dialogue-A? Default **no** — only flags and “intro completed.”

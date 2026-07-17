# RainShadow — Game Design Document

- Status: pre-production baseline
- Version: 0.1
- Milestone covered: M01 — The Office in the Rain

## 1. High-level vision

RainShadow is a film-noir detective role-playing game built around close observation, human pressure, incomplete evidence, and deductions the player must be willing to own. It combines the tactile clarity of a point-and-click investigation with light RPG expression in dialogue, temperament, and consequence.

The player inhabits a weary private detective in his mid-forties: capable, broke, observant, and carrying the accumulated damage of cases that did not end cleanly. The city is not a puzzle box waiting for the correct answer. It is a wet, compromised place where evidence can be true but incomplete, people can lie for defensible reasons, and the player's chosen interpretation matters.

### Elevator pitch

In a rain-strangled city, a down-on-his-luck detective studies scenes, questions people, connects imperfect evidence, and makes deductions that change both the case and the person he becomes.

### Player promise

- Every important conclusion is rooted in something the player saw, heard, inferred, or chose to trust.
- Observation matters more than pixel hunting.
- Dialogue choices express method and temperament, not merely good/evil alignment.
- Failure changes the investigation; it does not simply stop it.
- The city feels hand-authored, painterly, damp, and physically inhabited.

## 2. Design pillars

### 2.1 Read the room

Spaces tell stories before characters do. Object placement, wear, lighting, sound, and environmental contradictions form the first layer of evidence. Hotspots reveal authored observations, but the game avoids making every object glow by default.

### 2.2 People are evidence, not vending machines

Witnesses have motives, thresholds, memories, and relationships. The useful question is not only “Are they lying?” but “What are they protecting, from whom, and why?” Tone, prior knowledge, presented evidence, and the detective's current condition influence conversations.

### 2.3 Deduction is commitment

The player connects facts into hypotheses. Several hypotheses may fit the known evidence. Committing to one opens some routes, closes others, and can create consequences before certainty is possible.

### 2.4 Noir with a pulse

The tone is bruised and unsentimental, but not empty cynicism. Small acts of care, humor, dignity, and restraint make the darkness meaningful. Violence is possible, rarely clean, and never the default reward loop.

### 2.5 Painterly clarity

Detailed pre-rendered locations and deliberately coarse, chunky avatar sprites evoke Baldur's Gate: Enhanced Edition specifically. The actor is not a smooth high-resolution illustration: he reads like a low-resolution early-3D miniature rendered into directional frames, with simplified body masses, palette-banded shading, and minimal facial information. Interactive objects remain readable through silhouette, value, controlled highlights, cursor feedback, and authored occlusion—not through modern neon outlines everywhere.

## 3. Audience, rating, and format

- Audience: players who enjoy narrative detective games, classic CRPGs, point-and-click adventures, and slow-burn noir.
- Intended rating: mature themes, alcohol/tobacco references, crime-scene material, restrained violence, and morally difficult decisions. Avoid exploitative framing.
- Play format: premium, single-player, offline-first.
- Session shape: 20–45 minute investigative sequences, with natural breaks after conversations, location exits, and major deductions.
- Platforms: iPhone, iPad, and macOS.
- Presentation: fixed three-quarter isometric 2D scenes rendered in SpriteKit.

## 4. World and tone

### 4.1 Setting

An original mid-century-inspired city with no exact historical date. Architecture, clothing, vehicles, paper records, wired telephones, and radio place it in an analogue world, while selective anachronism keeps the fiction from becoming a history simulation.

Rain is both atmosphere and theme: it obscures, reflects, cleans, erodes, and makes private lives visible through lit windows. The city should feel dense beyond the current frame—pipes knock in walls, trains pass unseen, signs hum, neighbors argue through plaster.

### 4.2 The detective

Working description for M01:

- Male, mid-forties.
- Unshaven stubble, tired eyes, once-careful haircut grown out.
- Rumpled dark trench coat over a loosened shirt and tie; worn shoes; no glamorous silhouette.
- Economical movements, guarded posture, capable hands.
- Seated idle communicates fatigue without making him inert: breathing, a small shift, rubbing a thumb along a mug, checking the rain, or suppressing a cough.
- Voice: dry, observant, occasionally compassionate, never omniscient.

The protagonist's final name, exact history, ethnicity, and voice casting remain narrative decisions; the visual pipeline should use a stable working design sheet before animation generation.

### 4.3 Tonal rules

- Favor implication over exposition.
- Let humor come from character and weary specificity, not genre parody.
- Avoid constant purple prose. Internal narration is brief and concrete.
- Use silence and ambient sound as dramatic beats.
- Do not make every authority corrupt or every victim saintly.
- The detective can be harsh, but the game does not confuse cruelty with competence.

## 5. Visual direction

### 5.1 Production language

The target is the production language associated with classic Infinity Engine games and their Enhanced Editions:

- richly painted or pre-rendered static area art;
- a fixed three-quarter isometric/dimetric projection;
- low-resolution, pre-rendered 3D-derived avatar sprites with chunky simplified anatomy, broad readable clothing/equipment masses, limited palette ramps, and multi-orientation animation;
- baked environmental lighting plus selective live overlays;
- ground-contact shadows that keep sprites attached to the room;
- separate doors, actors, effects, and interactive props;
- foreground cutouts and depth anchors that allow characters to pass convincingly behind furniture and architecture;
- dense texture at the source, read through strong value shapes at play scale.

The goal is equivalent visual density and staging, not literal duplication of any copyrighted location, character, interface, or prop.

### 5.2 Camera and composition

- Fixed projection: 2:1 dimetric grid, approximately 45-degree plan rotation and 30-degree visual elevation.
- No perspective camera rotation during play.
- Cinematic movement is limited to slow SpriteKit camera pans, pushes, and restrained scale changes.
- The office composition must read at full view and at the minimum supported iPhone view.
- The detective's feet and navigable floor stay within the composition-safe region across 4:3, 16:9, and wide phone aspect ratios.
- Exterior and interior share one distinctive warm office-window shape to motivate the transition.

### 5.3 Palette and lighting

Primary palette:

- rain black and blue-charcoal;
- dirty plaster gray-green;
- wet asphalt violet;
- tobacco brown and old-paper cream;
- oxidized metal and muted burgundy;
- one controlled pool of nicotine amber from the desk lamp.

Lighting rules:

- One clear warm key source in the office: the desk lamp.
- One cool environmental source: rain-window spill.
- Deep but readable shadows; black values retain texture on calibrated displays.
- Highlights describe wetness, glass, metal, and paper edges rather than coating every surface.
- Environment objects must obey the scene's fixed light direction. The BG:EE-style actor uses one consistent neutral baked sprite rig and limited palette; subtle runtime tint, a lamp overlay, and the separate contact shadow integrate it without turning it into a smoother scene-relit illustration.

### 5.4 Texture and detail

- Painterly, pre-rendered realism with visible material separation: damp brick, crazed varnish, worn wood, dented metal, fogged glass, paper fibers.
- Avoid crisp vector edges, modern physically based 3D gloss, cel shading, chunky intentional pixel art, or generic “AI fantasy” ornament.
- Downsample from larger masters to unify texture and soften generation artifacts.
- Assess every asset at final on-screen scale. Detail that turns into noise must be regrouped, not merely sharpened.

### 5.5 Character presentation — Baldur's Gate: Enhanced Edition avatar target

The in-world detective must match the supplied Baldur's Gate sprite references more closely than the higher-resolution portraits or environment art. The defining contrast is intentional: a richly rendered area contains a visibly coarser animated avatar.

- Source construction should look like an early low-poly 3D maquette rendered to 2D, then reduced—not like a hand-painted full-resolution figure.
- Proportions are compact and game-readable rather than anatomically delicate: roughly 6.5–7 heads tall, slightly top-heavy, with broad shoulders, thick forearm/hand shapes, sturdy shoes, and a trench coat simplified into a few strong masses. This is not super-deformed or cute.
- At the reference 2048×1152 view, the standing body is only about 125–145 screen pixels tall. Facial stubble and age read as a few controlled value clusters; they are not portrait-level details.
- Shading uses a restricted shared sprite palette, obvious light/dark ramps, restrained dithering, and a slightly hard raster edge. Avoid smooth painterly gradients, high-frequency cloth texture, modern subpixel hair, or high-resolution antialiasing.
- Clothing colors form large, legible zones like the robe/armor color blocks in the references. The coat silhouette matters more than buttons or seams.
- Locomotion resolves to 16 facing bins. Nine source orientations—S, SSW, SW, WSW, W, WNW, NW, NNW, N—supply the remaining seven eastern orientations by horizontal mirroring, echoing the legacy BG2/BG:EE convention.
- The detective design is kept near-bilateral at sprite scale so mirroring does not expose a swapped holster, lapel badge, or other continuity-breaking prop.
- Sprite lighting is a consistent neutral baked rig suited to palette/tint adjustment, not a new scene-specific high-resolution relight for every frame. The office integrates him with subtle tint, lamp overlay, and contact shadow.
- A shared ground pivot sits under the midpoint between the feet. A separate soft contact-shadow sprite is not baked into each animation frame.
- Do not bake a heavy black outline. Edge separation comes from the limited palette; an optional outline/ring is reserved for accessibility and debug display.

This specification is grounded in Beamdog's description of orientation-specific character frames and 256-color palette remapping in the [Baldur's Gate: Enhanced Edition postmortem](https://www.gamedeveloper.com/programming/postmortem-overhaul-games-i-baldur-s-gate-enhanced-edition-i-) and the legacy orientation/mirroring behavior documented by [IESDP](https://gibberlings3.github.io/iesdp/file_formats/ie_formats/ini_anim.htm).

## 6. Core gameplay loops

### 6.1 Moment-to-moment investigation loop

1. **Observe** — scan the space, listen, notice composition and behavior.
2. **Approach** — tap/click a destination or interaction target.
3. **Inspect** — receive a concise sensory observation or manipulate the object.
4. **Interpret** — add a fact, question, inconsistency, or personal impression to the case record.
5. **Apply** — use knowledge in dialogue, examine another object, or test a hypothesis.
6. **Choose** — commit to a response or deduction that changes the available path.

### 6.2 Case loop

1. Receive a client, summons, or disturbance.
2. Establish the apparent question.
3. Visit locations and interview people.
4. Build a record of facts, testimony, material evidence, and contradictions.
5. Form working hypotheses.
6. Test them through new questions or actions.
7. Make an irreversible commitment: accuse, conceal, expose, bargain, or walk away.
8. See immediate fallout and later echoes in the city and the detective's condition.

### 6.3 Character loop

The detective changes through repeated method, not XP grinding:

- **Composure** — remain controlled under pressure; notice without reacting.
- **Empathy** — read emotional stakes and create trust.
- **Nerve** — confront danger, authority, or personal shame.
- **Instinct** — make fast pattern-based inferences from incomplete information.

These are low-range traits with occasional checks, dialogue affordances, and consequence modifiers. They should unlock different approaches rather than establish one dominant build.

## 7. Investigation mechanics

### 7.1 Hotspots and discovery

Each hotspot has:

- stable ID and localized display name;
- interaction polygon independent of the art's alpha bounds;
- default verb and optional contextual verbs;
- reach point and facing direction;
- one or more observation stages;
- state predicates and state mutations;
- accessibility label;
- optional evidence or knowledge payload.

Discovery rules:

- Important objects are compositionally legible without a permanent outline.
- Hover on macOS shows a restrained label and cursor change after a short delay.
- Touch uses generous hit regions and a brief label on first tap; a second tap or contextual button confirms only when ambiguity requires it.
- A hold-to-focus accessibility option reveals known or currently reachable hotspots with muted, hand-painted halos.
- No progression-critical clue relies on a tiny unmarked pixel.

### 7.2 Evidence model

Evidence is not a flat collectibles list. A record contains:

- `id` and case association;
- title and short factual summary;
- source: observed, physical, testimony, document, or inference;
- provenance: where, when, and from whom it was acquired;
- reliability: verified, credible, uncertain, compromised, or false;
- subject tags and timeline tags;
- facts directly supported;
- facts apparently contradicted;
- follow-up questions exposed;
- media: icon, close-up, transcript excerpt, or sketch;
- player annotations or pin state.

The UI distinguishes what the detective directly observed from what somebody claimed. Reliability can change without deleting the original record.

### 7.3 Knowledge and contradiction

Knowledge flags capture things the detective can act on even when they are not physical evidence: a name, habit, relationship, route, code phrase, or observed reaction.

A contradiction appears when two records make claims that cannot both be true under the current timeline. The game may flag that a contradiction exists, but the player decides why it exists: error, lie, mistaken identity, altered evidence, or an incorrect assumption.

### 7.4 Deduction board

The deduction board is a focused reasoning workspace, not a freeform physics toy.

- The player pins evidence and knowledge cards into a case-specific workspace.
- Authored connection prompts appear between compatible cards: supports, contradicts, places, motivates, identifies, or excludes.
- Completing a valid connection creates a **premise**.
- Two or more premises can unlock one or several **hypotheses**.
- A hypothesis shows confidence and unresolved questions, not an omniscient “correct” badge.
- Committing a hypothesis writes a case-state flag and can change dialogue, access, surveillance, or endings.
- Incorrect but plausible commitments fail forward. Impossible connections receive a short in-character rejection and do not consume resources.

### 7.5 Dialogue

Dialogue choices are tagged by intention rather than morality:

- **Open** — invite detail, acknowledge, or wait.
- **Press** — challenge, corner, or expose a contradiction.
- **Feign** — bluff knowledge, conceal motive, or misdirect.
- **Trade** — offer information, safety, money, or discretion.
- **Observe** — say little and watch the reaction.
- **Leave** — end or defer without a false choice.

Choice availability can depend on evidence, knowledge, traits, prior tone, time pressure, and the speaker's current threshold. The UI should disclose the main reason for a special option, such as `[Evidence: Tram Receipt]`, without revealing the outcome.

### 7.6 Pressure, condition, and failure-forward play

The detective has a situational **strain** state rather than a survival meter. Threats, sleeplessness, alcohol, injury, and morally difficult choices can raise strain. High strain changes animation, internal narration, and the cost or availability of some approaches; it does not randomly erase clues.

Failed checks produce information with a cost, a changed relationship, time loss, exposure, or a narrowed option. Critical case progress always has at least one non-check route.

## 8. Interaction and controls

### 8.1 Shared interaction grammar

- Tap/click navigable floor: walk there.
- Tap/click hotspot: select and approach; interact on arrival when unambiguous.
- Tap/click actor: approach or begin conversation.
- Drag/pinch or scroll: camera pan/zoom only when a scene permits it.
- Escape/two-finger tap: cancel current path, dismiss overlay, or step back one UI level.
- Hold focus key/long press: optional hotspot reveal.

### 8.2 iOS and iPadOS

- Single tap: select, move, or interact.
- Drag: camera pan when not beginning on a UI control.
- Pinch: constrained camera zoom.
- Long press: focus reveal or contextual actions, configurable.
- Minimum interactive target: 44×44 points even when the visible object is smaller.
- Important controls remain clear of safe-area insets and the home indicator.

### 8.3 macOS

- Left click: select, move, or interact.
- Right click or Escape: cancel/back.
- Pointer hover: target label and cursor affordance.
- WASD/arrow keys: optional camera pan; not required for actor movement.
- Return/Space: confirm focused dialogue or UI choice.
- Tab: hold/toggle hotspot focus according to accessibility setting.
- Command-minus/plus or wheel modifier: constrained zoom.

## 9. Opening sequence — M01 “The Office in the Rain”

### 9.1 Narrative purpose

Before the first case arrives, the opening establishes three facts without exposition:

1. The city is larger and colder than the detective.
2. His office is both workplace and refuge, and neither is in good condition.
3. He is waiting, tired enough to leave, broke enough to stay.

### 9.2 Exterior beat sheet

Target duration: 10–14 seconds, skippable after the first second.

| Time | Picture | Sound | Function |
|---|---|---|---|
| 0.0–2.0 s | Black lifts into wet street and the lower face of a rundown apartment building. Rain cuts across frame. | Heavy rain, distant traffic, drain gurgle. | Establish weather and scale. |
| 2.0–6.0 s | Slow upward/diagonal camera push. Puddles catch a failing sign. A fire escape divides the facade. | One passing car; low musical tone enters. | Build spatial rhythm and noir silhouette. |
| 6.0–9.0 s | A few windows glow; most are dark. The office window is a small dirty amber rectangle. | Rain remains dominant; faint radiator/room tone begins under it. | Identify destination by contrast. |
| 9.0–12.0 s | Camera eases toward the office window. Exterior foreground darkens. | Exterior rain filters; interior window patter and lamp hum become clearer. | Motivate the transition. |
| 12.0–14.0 s | Warm window shape fills enough of frame to match the office window or lamp pool. Crossfade through shadow. | Seamless ambience crossfade. | Move inside without a hard loading beat. |

No title card should obscure the best establishing composition. If a title is used, place it during the first hold in small, restrained typography and support disabling it during repeat play.

### 9.3 Interior composition

The office is a single isometric room with enough floor for a short path loop. Required story zones:

- **Desk island**: detective, battered desk, chair, lamp, phone, mug, ashtray, files, pencil, unpaid notices.
- **Rain window**: visible animated rain, condensation, intermittent water trail, cool spill on the floor.
- **Door**: visibly usable, worn jamb, opaque hall beyond for M01.
- **Case storage**: dented filing cabinet and leaning archive boxes.
- **Personal residue**: coat hook, old photograph or framed clipping turned partly away, wastebasket, bottle hidden rather than showcased.
- **Negative space**: a navigable floor wedge that makes walking and depth sorting visible.

The room should feel cluttered but compositionally controlled. The lamp, detective silhouette, window, and door must remain readable at phone scale.

### 9.4 Interior beat sheet

1. The interior resolves while rain continues over the window.
2. The lamp pool reveals the seated detective at his desk.
3. He completes one authored seated-idle beat: breath, small shoulder shift, brief glance toward the rain.
4. Vivian Hart enters from the office door and crosses to the visitor side of the desk.
5. A short player-advanced exchange establishes her missing sister, a coat found by the river, a concealed brass key, and the first case: **The Empty Coat**.
6. Vivian leaves the key, turns away from the desk, and walks back through the office door using a dedicated rear northeast cycle.
7. Input becomes active; a minimal unobtrusive hint appears only on first run.
8. The player can inspect the window, lamp/desk, phone, case files, and door.
9. Selecting a floor destination or the door makes the detective stand, transition to standing idle, and walk.

### 9.5 M01 hotspot set

| ID | Display name | First observation | State effect |
|---|---|---|---|
| `office.window` | Rain-streaked window | “The rain had been working the glass harder than I had worked a case.” | Sets `noticedWeather`; demonstrates environmental hotspot. |
| `office.desk` | Desk | “Three old cases, two unpaid bills, one clean page.” | Adds `officeUnpaidBills` knowledge; establishes inspect staging. |
| `office.phone` | Telephone | “Quiet. For once it had the decency to look guilty.” | Sets `checkedPhone`; reserves later incoming-call state. |
| `office.files` | Case files | “Closed, abandoned, and one I still lied about.” | Adds `oldCaseReference`; seeds later narrative. |
| `office.door` | Office door | “The hall smelled worse, but at least it led somewhere.” | Makes detective approach; door stays locked to M02 with an authored response. |

Copy is provisional and should be revised with the narrative voice pass.

## 10. Audio direction

### 10.1 Principles

- Rain is layered, spatial, and continuous across the scene transition.
- Music supports dread and exhaustion without filling every second.
- Interior sound is intimate: window patter, radiator ticks, lamp hum, chair creak, cloth movement, distant plumbing.
- Repetition must be difficult to detect; loops use long beds plus randomized one-shots.
- Dialogue remains intelligible on phone speakers and supports subtitles.

### 10.2 M01 mix layers

- Exterior heavy-rain stereo bed.
- Exterior detail emitters: gutter, puddle impacts, distant traffic, sign/electrical buzz.
- Interior rain-on-glass bed.
- Interior room tone and radiator/pipe one-shots.
- Detective foley: chair, cloth, shoes, breath.
- Door, paper, phone, mug, and lamp interaction one-shots.
- One sparse music cue with a clean loop or tail for skipping.

The exterior-to-interior transition crossfades beds while preserving a shared rain transient so the cut feels spatial, not like an audio restart.

## 11. UI direction

- UI is diegetically sympathetic but not a reproduction of an Infinity Engine chrome frame.
- Use charcoal, oxidized brass, dirty paper, and restrained burgundy accents.
- Body text prioritizes readability over distressed styling.
- World labels are short and placed near the target without obscuring it.
- Dialogue and deduction panels can become more substantial later; M01 uses only a small observation caption and optional first-run hint.
- Support Dynamic Type-equivalent scaling within designed bounds, subtitles, reduced motion, reduced rain intensity, high-contrast hotspots, and independent audio sliders.

## 12. Scope boundaries

### In M01

- Exterior establishing scene and rain.
- Cinematic transition into the office.
- Complete office visual composition with separate props.
- Seated idle, stand-up, standing idle, and 16-facing legacy-style walk presentation.
- Tap/click movement and five inspectable hotspots.
- Correct isometric depth sorting and foreground occlusion.
- Shared iOS/macOS scene code with platform input adapters.
- Core ambience, interaction captions, skip, pause/background handling, and accessibility basics.

### Designed now, implemented later

- Evidence inventory and full case journal UI.
- Deduction board and hypothesis commitment.
- Branching dialogue UI and relationship thresholds.
- Trait advancement and strain consequences.
- Multiple connected locations, NPC schedules, save slots, localization pipeline, voice-over, combat or chase systems.

### Explicitly out of scope for the game vision

- Loot grinding, random combat encounters, or level-scaled enemies.
- Procedurally generated cases replacing authored mystery logic.
- Fully rotatable 3D environments.
- Pixel-perfect copying of existing game assets or interface frames.

## 13. Accessibility and usability baseline

- Subtitles/captions on by default for important non-speech cues.
- Text size presets and high-contrast text backing.
- Reduced motion: removes camera push, flash, aggressive parallax, and dense foreground rain while retaining the scene transition.
- Rain intensity slider to reduce visual noise without muting sound.
- Hotspot focus mode and adjustable hold/toggle behavior.
- Touch targets at least 44×44 points.
- Full M01 playability with touch only or mouse only; keyboard shortcuts are additive.
- Do not encode evidence categories by color alone.
- Save state before any irreversible deduction or major dialogue commitment.

## 14. Success criteria

M01 succeeds when a first-time player can:

- identify the office window during the exterior shot;
- experience a transition with no obvious loading hitch or rain discontinuity;
- immediately understand the office's navigable floor and primary props;
- see the detective read as tired, middle-aged, and physically grounded at the desk;
- make him stand, walk in any needed direction, pass correctly behind/in front of the desk and foreground occluders, and return to idle;
- inspect all five hotspots using touch on iOS and mouse on macOS;
- run the scene at the agreed performance target with no stretched sprites, edge halos, unsafe UI, or aspect-ratio-critical crop.

The art gate is qualitative but strict: at final display scale, the office must read as one coherently pre-lit, painterly isometric render even though its interactive pieces are separate.

## 15. Open design decisions after M01

- Final protagonist identity, history, and core wound.
- Whether the first full case arrives by phone, visitor, or an object pushed under the door.
- Exact trait names and whether strain is visible numerically.
- Case-board visual metaphor: desk papers, wall board, or abstract journal.
- Degree of camera control in later, larger areas.
- Save-slot presentation and cross-device strategy.

None of these decisions blocks the opening-sequence architecture.

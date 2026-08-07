# RainShadow — Game Design Document

- Status: pre-production baseline
- Version: 0.3
- Milestone covered: M01 — The Office in the Rain
- Canon leads: **Harlan Voss** (player detective), **Lila March** (first client / the dame)
- Case dossier: **The Empty Coat** (§4.3.2) — Act I structure + M01 journal surface

## 1. High-level vision

RainShadow is a film-noir detective role-playing game built around close observation, human pressure, incomplete evidence, and deductions the player must be willing to own. It combines the tactile clarity of a point-and-click investigation with light RPG expression in dialogue, temperament, and consequence—and, when the city refuses to talk, rare **Baldur’s Gate–style real-time-with-pause combat** that is authored, high-stakes, and never a loot grind.

The player inhabits **Harlan Voss**, a weary private detective in his early thirties: capable, broke, observant, and carrying the accumulated damage of cases that did not end cleanly. The city is not a puzzle box waiting for the correct answer. It is a wet, **structurally corrupt** place where evidence can be true but incomplete, people can lie for defensible reasons, institutions protect themselves first, and the player's chosen interpretation matters.

### Elevator pitch

In rain-strangled Harborpoint, private detective Harlan Voss studies scenes, questions people, connects imperfect evidence, survives the rare fight he cannot talk past, and makes deductions that change both the case and the man he becomes—until a Poirot-like summation forces every lie into the open.

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

### 2.5 Pre-rendered clarity

Detailed pre-rendered locations and crude era-authentic 3D character meshes evoke the production logic of classic Infinity Engine games. Characters are modeled, rigged, lit, and rendered offline into directional 2D frames. Their geometry and textures remain deliberately simple, then resolve through a small native raster and restrained palette so the play-scale result is lightly pixelated without becoming hand-authored pixel art. Interactive objects remain readable through silhouette, value, controlled highlights, cursor feedback, and authored occlusion—not through modern neon outlines everywhere.

## 3. Audience, rating, and format

- Audience: players who enjoy narrative detective games, classic CRPGs, point-and-click adventures, and slow-burn noir.
- Intended rating: mature themes, alcohol/tobacco references, crime-scene material, restrained violence, and morally difficult decisions. Avoid exploitative framing.
- Play format: premium, single-player, offline-first.
- Session shape: 20–45 minute investigative sequences, with natural breaks after conversations, location exits, and major deductions.
- Platforms: iPhone, iPad, and macOS.
- Presentation: fixed three-quarter isometric 2D scenes rendered in SpriteKit.

## 4. World, characters, and story

This section is the **narrative canon** for Harborpoint, the two established leads, and the spine of the campaign. The retired working names (**Elias Vale**, **Vivian Hart**) were fully migrated to the canon names with the V6 BGEE-style character redesign: sprites, atlases, portraits, UI text, and code identifiers now all use the names below. Design, dialogue, and new writing use only these names.

### 4.1 World — Harborpoint under the rain

**Harborpoint** is an original mid-century-inspired port city with no exact historical date. Architecture, clothing, vehicles, paper records, wired telephones, and radio place it in an analogue world; selective anachronism keeps the fiction from becoming a history simulation. The player never gets a tourist map of the whole metropolis—only rain-cut fragments that feel continuous beyond the frame: pipes knock in walls, trains pass unseen, signs hum, neighbors argue through plaster.

**Rain** is atmosphere and theme at once. It obscures footprints, reflects neon into puddles, rinses blood off stone too slowly, erodes cheap paint, and makes private lives visible through lit windows. Every district smells slightly different when wet: coal and brine on the docks, printer’s ink and cigarette ash downtown, wet wool and cooking oil in the tenements.

#### Power structure (corruption is structural)

Corruption in RainShadow is not a mood filter or a single crooked cop. It is **how Harborpoint keeps running**:

| Layer | What it pretends to be | What it actually is |
|---|---|---|
| **Municipal hall** | Civic order, permits, “progress” | Kickbacks on contracts; zoning that relocates poverty instead of solving it; records that go missing on purpose |
| **Harborpoint PD** | Law and investigation | Political pressure, selective blindness, and a few honest officers trapped inside a machine that punishes curiosity |
| **Dock Authority & unions** | Labor and trade | Smuggling corridors, “lost” cargo, and silence bought with overtime and threats |
| **Press & radio** | Public truth | Ownership strings; editors who know which names never print; one or two reporters who still dig |
| **Old money & new industry** | Philanthropy, jobs | Private armies in better coats; charity balls that launder reputation; factories that own whole blocks of votes |
| **Street networks** | Crime as chaos | Predictable tribute systems that feed upward into “respectable” ledgers |

The player feels this structure through locked doors, altered reports, witnesses who suddenly change their minds, and evidence that is **true but incomplete** because someone above the case needed it that way. Not every authority figure is rotten, and not every victim is pure—but **institutions default to self-preservation**. Voss survives by reading which layer he has just kicked.

#### Districts (playable texture, not open-world tourism)

- **Sable Row** — mixed tenements and small shops; Voss’s office building sits in this rain-dark block. First city expansion uses its modular streets.
- **The Docks / Wharf Ladder** — cargo, warehouses, boarding houses, and the river mouth where empty coats wash up.
- **Civic Spine** — courthouse, central station house, records annex; marble that still looks clean in the rain.
- **Printers’ Quarter** — newspapers, radio offices, cheap cafés that never close; gossip as a second economy.
- **Ashfield Yards** — industry, company housing, blacked-out windows; the city’s muscle and its smog.

Immersion comes from **authored density**: specific smells, recurring NPCs who remember what Voss said last visit, newspapers that react to case commitments, and weather that changes investigation readability (not merely a particle effect).

### 4.2 Characters — the two established leads

RainShadow’s first cast is deliberately small and sharp. Supporting players (cops, dockers, reporters, siblings, fixers) appear as needed; only two identities are locked as **series leads** for the outline.

#### Harlan Voss — player protagonist

- **Role:** Private detective; the player’s body, voice, and moral weather.
- **Age / look:** Male, early thirties. Clean-shaven handsome face with tired hollow eyes; short dark hair, bare-headed (no fedora). Lived-in olive-brown belted overcoat over a mustard waistcoat, cream shirt, and loosened dark green tie; charcoal trousers; scuffed brown shoes. Handsome but broken down—no glamorous silhouette. Economical movements, guarded posture, capable hands.
- **Temperament:** Dry wit sharpened by fatigue. Observant before he is brave. Occasionally compassionate, never omniscient. He can be harsh; the game never confuses cruelty with competence.
- **Core wound (working):** A prior case he closed “correctly” on paper and wrong in human terms—someone paid for his certainty. Harborpoint still files him as useful and disposable.
- **Method:** Reads rooms before people. Prefers questions that make liars do the work. Will fight when cornered, but treats violence as a confession that talk failed.
- **Voice sample (design target):** “The rain had opinions about my rent. The dame in the doorway had better ones about my time.”
- **Superseded working name:** Elias Vale (retired; the V6 redesign renamed all art, portraits, and code identifiers to Voss).

Seated idle for M01 communicates fatigue without inertia: breathing, a small shift, rubbing a thumb along a mug, checking the rain, suppressing a cough.

#### Lila March — the dame / first client

- **Role:** Client who forces the first case into Voss’s office; romantic-noir **dame** archetype played straight and human, not as a costume.
- **Age / look:** Early-twenties adult woman with a chic chin-grazing textured blunt bob (soft side part, airy lived-in finish) and a fitted deep-emerald 1940s day dress—nipped waist, modest scoop neckline, knee-length soft flare, dark pumps, compact handbag. Figure-flattering period daywear without crossing under-15 suitability. Composed enough that the cracks show only if Voss presses.
- **Temperament:** Witty under pressure, precise with what she withholds, capable of genuine fear and calculated charm in the same breath. She is not a trophy or a pure victim, and not automatically a traitor—**the player must earn which**.
- **Apparent need:** Her sister **Lillian March** is missing. A coat was found by the river. Inside a lining, a concealed brass key. She wants the sister found and will pay what she can (which may not be money alone).
- **Deeper tension:** She knows more than the first conversation admits—about Lillian’s work near Wharf Ladder, about men who “help” at the docks, about why the coat was empty. Her secrets protect someone; the story’s job is to make the player discover **whom**, and at what cost.
- **Relationship to Voss:** Professional first. Attraction, trust, or rupture are **player-shaped**, not a mandatory romance track. Wit is their shared language; silence is their shared weapon.
- **Superseded working name:** Vivian Hart (retired; the V6 redesign renamed the arrival/departure atlas, dialogue portrait, and narrative copy to March).

#### Supporting cast (named only as needed by the outline)

Do not expand into full sheets here. Story beats may introduce: a tired sergeant who still returns Voss’s calls; a dock clerk who sells silence by the hour; a society fixer who never gets rain on their shoes; the missing sister as presence-through-absence until the endgame allows her truth—alive, dead, or worse—to land.

### 4.3 Story outline

#### Premise

Harborpoint sells the public a city that works. **Harlan Voss** rents an office that barely does. When **Lila March** walks out of the rain with a key and a coat that no longer has a body in it, the apparent missing-person case becomes a vertical cut through the city’s corrupt layers—from Sable Row up to ledgers that were never meant to be read aloud.

#### Design commitments woven into the plot

| Commitment | How the story delivers it |
|---|---|
| **Wit** | Voss’s internal captions and dialogue stay dry, specific, and human. Lila matches him beat for beat. Humor comes from weary precision and character, never spoof-noir or constant purple prose. |
| **Noir tropes** | Dame in the doorway; rain as accomplice; empty coat / missing person; double books and double lives; the honest cop in a bad system; the “helpful” official; the river that keeps secrets; a private eye too broke to refuse the case and too stubborn to stop. Tropes are **played**, not winking pastiches. |
| **Corruption** | Each act peels a higher institutional layer. Evidence is altered by people with badges, letterheads, and good manners—not only by street thugs. |
| **Combat (BG-like)** | When investigation turns kinetic, encounters use **real-time-with-pause**, tactical positioning, and small allied or temporary party composition in the Infinity Engine spirit—**authored set pieces**, not random trash fights or loot-grind loops. See §4.3.5. |
| **Immersion** | Continuous rain beds, reactive districts, NPCs who remember, case journal that feels like Voss’s mind on paper, and environmental storytelling before exposition. |
| **Poirot-like conclusion** | Endgame is a **summation scene**: key suspects and stakeholders gathered (office, private club, station house, or warehouse made formal by force of will). Voss lays out the **full chain of deduction**—what was seen, what was lied, what the empty coat meant—before the final moral choice of who pays. |

#### 4.3.1 Act structure (campaign spine)

**Act I — The Empty Coat (M01 and first case)**  
Lila arrives. Voss takes the case. The office, the key, and the river coat establish method: observe, inspect, interview, commit. Early noir beats land hard—the dame, the rain, the first polite door that will not open. The player learns that Harborpoint’s smallest mysteries already have municipal fingerprints.

**Act II — Follow the key**  
The brass key opens more than a locker: a chain of storage slips, union marks, and names that appear in both police blotters and charity donor lists. Witnesses contradict each other on purpose. Voss’s strain rises. Optional and required combat set pieces appear when a warehouse watch, a night alley, or a “quiet chat” turns into an ambush—still sparse, always motivated.

**Act III — The city answers back**  
Commitments on the deduction board close routes. Lila’s partial truths come due. A faction above the docks tries to buy Voss off, bury him in paperwork, or remove him. Allies may join for a fight or a testimony. Corruption is no longer ambient; it has a face, a budget, and a preferred ending in which nobody important is embarrassed.

**Act IV — Summation (Poirot close)**  
Voss engineers (or is forced into) a gathering of the remaining principals. In a controlled space, he reconstructs the timeline: the sister’s last movements, who emptied the coat, which institution needed the silence, and which personal betrayal made the machine efficient. The player’s prior hypotheses and failed-forward choices color **how complete and how merciful** the reveal is—but the design center is always the **dramatic laying-out of the chain**, not a sudden unearned twist from nowhere. After the truth is spoken, a final irreversible commitment: accuse, expose, bargain, or walk away—and live with Harborpoint’s echo.

#### 4.3.2 First case — “The Empty Coat” (case dossier)

This section is the **authoritative case structure** for Act I and the M01 case journal. Runtime journal copy (`EmptyCoatJournalContent`) must stay consistent with it. Dialogue may paraphrase; it must not invent facts the dossier has not established for that beat.

##### Seed (campaign spine)

1. **Lila March**’s sister **Lillian March** is missing.
2. A coat is recovered by the river—**empty** in a way that feels arranged, not merely abandoned.
3. A concealed **brass key** is sewn into the lining (not left where a hurried search would “find” it).
4. Someone with institutional reach wanted the coat found without a body, or the body gone without the coat.
5. Voss’s office becomes the first board where facts, testimony, and distrust share a desk lamp.

M01 ships the arrival, the key handoff, office freeroam, and the **case journal surface**. Later milestones open the river, docks, and civic records that turn the seed into a full investigation.

##### Case header

| Field | Value |
|---|---|
| Case ID | `case.empty-coat` |
| Title | The Empty Coat |
| Client | Lila March |
| Missing person | Lillian March |
| Status at M01 end | Open / Priority |
| Apparent question | Where is Lillian March, and why was her coat left as a finished story? |
| Working thesis (player-facing, uncertain) | Someone with institutional reach staged a drowning conclusion; the key is the thread they failed to cut. |
| Journal letterhead | **H. VOSS · PRIVATE INVESTIGATIONS** |

##### Known facts at case open (M01 intro must establish)

Aligned to the shipped Empty Coat intro graph:

1. Lillian vanished Tuesday night after work at a shipping office near **Wharf Ladder** (ledgers, manifests).
2. Last known: left work about nine; told a clerk she had one more errand uptown; no cab called from the desk phone.
3. By midnight, river watch found her coat on the stones below the old iron stairs—empty, arranged; no body.
4. Harborpoint PD soft-file: missing adult, no struggle, coat recovered, probable drowning; case cooling before the ink dried.
5. Coat pockets turned as if to show nothing left to steal; **brass key sewn into the lining**—recovered by Lila before the garment fully left her hands.
6. Since the key: a **Gray Man** (gray overcoat, black gloves) follows Lila; professional habits (streetcar noise, doorway posts); he turns away when met with a direct look.
7. Voss accepts the case; the key stays in his care.

##### People

| ID | Name | Role | Status at M01 | Notes |
|---|---|---|---|---|
| `person.lila` | Lila March | Client | Interviewed | Precise under pressure; withholds deeper dock/sister secrets until pressed with evidence |
| `person.lillian` | Lillian March | Missing person | Whereabouts unknown | Shipping-office ledgers; hated the river; hated unfinished books; last seen Tuesday evening |
| `person.gray-man` | The Gray Man | Unknown watcher | Unidentified | Not yet proven badge vs private muscle; knows Lila came to Voss |
| *(Act I later)* | Night sergeant / river watch | Institutional | Not interviewed in M01 | Soft close: coffee, tides, politeness with teeth |
| *(Act I later)* | Shipping-office clerk | Witness | Not interviewed in M01 | Last conversation with Lillian; “errand uptown” |

##### Evidence

| ID | Item | Custody | Reliability | M01 journal? | Leads |
|---|---|---|---|---|---|
| `evidence.key` | Brass key from coat lining | Voss | Credible physical | Yes | What lock? Faint machine oil and river fog |
| `evidence.coat` | Riverside coat | Police / described by Lila | Uncertain / possibly staged | Yes | Recovery site; constable property log |
| `evidence.pd-file` | Soft missing-person file | Harborpoint PD | Compromised / incomplete | No (later) | Ally sergeant; dual ledgers |
| `evidence.blue-room` | Blue Room matchbook (Wardour Street) | Unearned in M01 | — | **No** | Act I seed only—do not show in M01 journal until the player earns it |

##### Objectives / leads (organized doubt, not quest checkboxes)

**M01 (office only)**
- Keep the key safe; case file open in the journal.
- Record office field notes via hotspot inspections.
- Journal leads (destinations still locked): identify the lock; build Lillian’s Tuesday timeline; find or name the Gray Man; re-check the river stones when the city opens.

**Act I beyond M01 (design roadmap; non-spoiler)**
- River recovery site + constable log.
- Wharf Ladder shipping office / manifests Lillian was reading.
- Gray Man identification or pressure.
- Civic records / dual ledgers if she was reading the wrong books.
- Lila’s partial truths due when the player presses with evidence.
- Optional later seed: Blue Room on Wardour Street (matchbook or testimony)—only after earned.

##### Chronology (case log · approximate Voss notation)

Prefer **narrative order** (coat → key → follower → office). Times are detective notation, not a forensic clock.

| Approx. time | Event | Journal entry ID |
|---|---|---|
| Tue ~9:00 PM | Lillian leaves Wharf Ladder shipping office | `log.leave-work` |
| Tue night | Gap: “errand uptown” / unknown | folded into movements |
| Tue ~midnight | Coat recovered riverside (old iron stairs) | `log.coat` |
| After recovery | Lila finds brass key in lining | `log.key` |
| Same night | Lila followed by the Gray Man | `log.followed` |
| Tue ~11:40 PM | Case opened at Voss’s office | `log.case-open` |
| Wed ~12:10 AM | Office field notes (if hotspots inspected) | `log.office` |

##### Open mysteries (writer hooks; not journal spoilers)

- Who emptied the coat, and why leave the key?
- What lock answers the brass key?
- Is Lillian alive, dead, or “worse” (held / erased from ledgers)?
- Which institutional layer benefits from a tidy drowning?

##### Journal UX contract

- Voice: Voss’s dry, concrete notes; short paragraphs. No green-checkmark quest language.
- Status strings: Open, Interviewed, Unidentified, Not examined, Recorded—not “Complete.”
- Sections: **ACTIVE CASES** · **PEOPLE** · **EVIDENCE & LEADS** · **FIELD NOTES** (hotspot-gated) · Chronology tab **CASE LOG**.
- M01 journal surface is the case-facing UI; full deduction board remains later (§7.4).
- Field notes appear only after corresponding office hotspot IDs (`office.window`, `office.desk`, `office.phone`, `office.files`).

#### 4.3.3 Noir tropes (checklist for writers)

Use these as **load-bearing beats**, not window dressing:

- The client who hires honesty and practices omission.
- The coat / photograph / key as a mute witness.
- Rain that erases tracks and forces people indoors where they can be overheard.
- A bar or café where everyone lies better after the second drink.
- The “routine inquiry” that is actually a warning.
- Files that exist twice—once for the public, once for the drawer that does not open.
- A romantic possibility that investigation may destroy.
- Violence as punctuation, not vocabulary.

#### 4.3.4 Wit and voice

- Internal narration: short, concrete, occasionally funny because it is accurate.
- Dialogue intentions (Open / Press / Feign / Trade / Observe / Leave) carry **tone**, not morality meters.
- Lila and Voss can out-dry each other; supporting cast get one sharp line rather than constant quips.
- Avoid genre parody, cartoon hardboiled, and monologues that explain the theme.

#### 4.3.5 Combat — Baldur’s Gate spirit, RainShadow stakes

Combat is a **designed system**, not the primary loop:

- **Model:** Real-time with pause (RTWP). The player issues orders, pauses to reassess, repositions, and uses the environment (cover, chokepoints, rain-slick floors, breakable lights) in the spirit of Infinity Engine party tactics—even when the “party” is Voss alone plus a temporary ally.
- **Frequency:** Rare. Authored. High-stakes. No random street trash packs, no level-scaled loot treadmill, no grinding for XP (see §12).
- **Triggers:** Ambush after a dangerous deduction, failed escape from a corrupt raid, defending a witness, or forcing entry when all civil routes are sealed.
- **Expression:** Strain, injury, and reputation matter more than gear score. Winning a fight can still lose a witness or expose Voss to the wrong newspaper.
- **Tone:** Ugly, brief when possible, and narratively accountable. A gunshot should change the next conversation.

#### 4.3.6 Immersion checklist

- Continuous spatial audio of rain across exterior→office and later district transitions.
- Hotspots that yield sensory writing before inventory icons.
- NPCs with thresholds, schedules, and memory of prior tone.
- Case journal / deduction board as Voss’s organized doubt, not a quest log of green checkmarks.
- Districts that feel economically linked (dock money in civic marble; tenement silence bought downtown).

#### 4.3.7 Poirot-like conclusion (endgame contract)

The finale must satisfy:

1. **Gathering** — relevant living suspects, clients, and institutional faces in one scene (voluntary or compelled).
2. **Chain of deduction** — Voss recounts evidence the player could have found, marks which claims were lies, and shows how the empty coat, the key, and the sister’s fate interlock.
3. **Fair play** — no essential killer identity that depended on unobtainable content; optional details may deepen but not sole-source the truth.
4. **Human cost** — the reveal wounds someone Voss or Lila might have preferred to spare.
5. **Final commitment** — the player chooses the legal, moral, or pragmatic aftermath; Harborpoint reacts in epilogue texture (press, PD, docks), not a binary credits slide alone.

### 4.4 Tonal rules

- Favor implication over exposition.
- Let humor come from character and weary specificity, not genre parody.
- Avoid constant purple prose. Internal narration is brief and concrete.
- Use silence and ambient sound as dramatic beats.
- Do not make every authority corrupt or every victim saintly—but do show **systems** that reward looking away.
- Harlan Voss can be harsh; the game does not confuse cruelty with competence.
- Lila March is a person under archetype pressure, never a prop.

## 5. Visual direction

### 5.1 Production language

The target is the production language associated with classic Infinity Engine games and their Enhanced Editions:

- richly painted or pre-rendered static area art;
- a fixed three-quarter isometric/dimetric projection;
- crude hundreds-of-triangles 3D avatar meshes rendered offline into lightly pixelated 2D sprite frames with readable clothing/equipment masses and multi-orientation animation;
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
- Environment objects must obey the scene's fixed light direction. Actors use one consistent neutral baked sprite rig; subtle runtime tint, a lamp overlay, and the separate contact shadow integrate them without requiring per-frame scene relighting.

### 5.4 Texture and detail

- Painterly, pre-rendered realism with visible material separation: damp brick, crazed varnish, worn wood, dented metal, fogged glass, paper fibers.
- Avoid crisp vector edges, modern physically based 3D gloss, cel shading, chunky intentional pixel art, or generic “AI fantasy” ornament.
- Downsample from larger masters to unify texture and soften generation artifacts.
- Assess every asset at final on-screen scale. Detail that turns into noise must be regrouped, not merely sharpened.

### 5.5 Character presentation — crude era-authentic pre-rendered 3D target

The in-world detective and clients use the same historical production principle as the supplied Baldur's Gate references—3D source models rendered into 2D directional frames—with a restrained play-scale raster treatment that recalls the original era without imitating hand-drawn pixel art.

- Source construction must read as a crude 1998-era textured game mesh rendered offline, not as hand-painted art, polished modern low-poly concept art, or a high-detail PBR character. Prompt for the production technology explicitly: hundreds rather than thousands of triangles, broad planar faces, solid-shell hair, mitten hands, tiny diffuse maps, and primitive vertex/Gouraud lighting.
- Proportions use simplified realistic anatomy: readable shoulders and coat masses, but ordinary-sized head, hands, and shoes rather than a top-heavy pixel-sprite silhouette.
- At the reference 2048×1152 rendered view, the **rendered** standing body (≈70.3 world units from the 200px texture on a 180pt node) targets 13% of playable height—about 150 screen points—with an acceptable 11.5–14.5% band. Camera visible height is derived from that rendered body, not the legacy 82-unit locomotion height. This matches the original Baldur's Gate playfield density (a ~50px adult on a 512×384 view) rather than BG:EE's wider zoomable framing, and it is the same rendered body every prop and door is measured against.
- Shading uses broad baked diffuse planes, low-resolution texture maps, restrained ambient occlusion, and limited muted color ramps. Generator masters are reduced to a 56-pixel native body with 1-bit alpha hardened at 50%, limited to per-material 64-entry ramps (skin/hair/metal/leather/coat, derived from opaque pixels only) without dithering, and nearest-upscaled to the fixed 200-pixel texture body; SpriteKit resolves them with nearest filtering. See `PaperdollBGEESpriteRedoPlanV14.md` for the V7→V14 crunch, which matched BG1's ~50-row adult and its opaque BAM v1 sprites. Avoid hand-placed pixels, coarse decorative pixel clusters, painterly brushwork, and modern pore/strand-level detail.
- Clothing colors form large, legible zones. The coat silhouette matters more than buttons or seams.
- Locomotion resolves to 16 facing bins. Nine source orientations—S, SSW, SW, WSW, W, WNW, NW, NNW, N—supply the remaining seven eastern orientations by horizontal mirroring, echoing the legacy BG2/BG:EE convention.
- The detective design is kept near-bilateral at sprite scale so mirroring does not expose a swapped holster, lapel badge, or other continuity-breaking prop.
- Sprite lighting is a consistent neutral baked rig suited to subtle tint adjustment, not a new scene-specific relight for every frame. The office integrates him with a lamp overlay and contact shadow.
- A shared ground pivot sits under the midpoint between the feet. A separate soft contact-shadow sprite is not baked into each animation frame.
- Do not bake a heavy black outline. Edge separation comes from value and material contrast; an optional outline/ring is reserved for accessibility and debug display.

This specification is grounded in Beamdog's description of the lost 3D character models it had planned to re-render at higher resolution in the [Baldur's Gate: Enhanced Edition postmortem](https://www.gamedeveloper.com/programming/postmortem-overhaul-games-i-baldur-s-gate-enhanced-edition-i-) and the legacy orientation/mirroring behavior documented by [IESDP](https://gibberlings3.github.io/iesdp/file_formats/ie_formats/ini_anim.htm).

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

Harlan Voss changes through repeated method, not XP grinding:

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

#### Classic Baldur’s Gate / Infinity Engine conversation roles (frozen)

RainShadow case dialogue follows **classic Baldur’s Gate (Infinity Engine DLG) roles**, not free-form visual-novel paging for player speech:

| Role | Who speaks | How the player advances |
|---|---|---|
| **State** (main speaker / body text) | NPC (or case-title end plate) | **Continue** only when the *same actor* keeps talking across pages |
| **Transition** (response list) | **Player character (Harlan Voss)** | Player **selects a reply option**—even when there is only one line |

**Do not** deliver mid-conversation Voss (PC) lines as main-speaker nodes the player only Continues through (`speaker: Harlan Voss`, empty `choices`, `nextNodeID` set). That is **not** classic BG. In IE, actor response text is the state; “what the player character says” is transition text (IESDP DLG V1).

**Correct pattern (shipped Empty Coat acceptance):** Lila’s last triad-3 NPC state offers Voss’s acceptance prose as **`CaseDialogueChoice` text**; selecting it advances to the next NPC beat (`lila.plea`). See `EmptyCoatCaseIntroduction.caseAcceptanceChoice` and tests `midConversationPCLinesAreReplyOptionsNotContinueStates`.

**Allowed exception:** the **pre-conversation interior monologue** (`voss.monologue.*`, `isInteriorMonologue`) may use Continue-only Voss pages. That is noir framing *before* the NPC exchange, not a DLG-style PC reply.

Future authors and tools must preserve this convention when adding graphs. Reverting PC speech to auto-Continue speaker states is a design regression.

#### Intentions

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
- Return/Space: confirm Continue / End Dialogue or non-dialogue UI (inventory/map). Player dialogue **replies** use click or number keys **1–9** (classic BG:EE); Space does not auto-pick a reply.
- Tab: hold/toggle hotspot focus according to accessibility setting.
- Command-minus/plus or wheel modifier: constrained zoom.

## 9. Opening sequence — M01 “The Office in the Rain”

### 9.1 Narrative purpose

Before the first case arrives, the opening establishes three facts without exposition:

1. Harborpoint is larger and colder than Harlan Voss.
2. His office is both workplace and refuge, and neither is in good condition.
3. He is waiting, tired enough to leave, broke enough to stay—and then **Lila March** makes leaving impossible.

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

- **Zone 1 — Detective work area**: NE-facing desk island with Voss’s chair, two client chairs, anchoring rug, wastebasket, lamp, black phone, typewriter, notebook, mug, ashtray, case folders, and unpaid notices. Keep at least one tile of movement clearance around the cluster.
- **Zone 2 — Archive and case wall**: bookcase, filing cabinet, and small safe as one west-wall storage run; consolidated archive boxes; cork case board, city map, framed licence, and pinned photographs on the plaster behind the desk; rain window with Venetian blinds and radiator below; cool blind-striped spill on the floor.
- **Zone 3 — Entrance and waiting**: door with coat stand and umbrella stand beside it; two mismatched waiting chairs and a small table (newspaper + ashtray) against the right wall; narrow worn runner from the entrance toward the desk; doorway kept clear of boxes.
- **Negative space**: a navigable floor wedge in the lower foreground; warm amber lamp key against cold window light and a narrow warm hallway slit through the open door.

The room should feel used and cramped but compositionally controlled. Every major prop belongs to a recognizable cluster. The lamp, Voss silhouette, window, and door must remain readable at phone scale.

### 9.4 Interior beat sheet

1. The interior resolves while rain continues over the window.
2. The lamp pool reveals seated Harlan Voss at his desk.
3. He completes one authored seated-idle beat: breath, small shoulder shift, brief glance toward the rain.
4. **Lila March** enters from the office door and crosses to the visitor side of the desk.
5. A short player-advanced exchange establishes her missing sister, a coat found by the river, a concealed brass key, and the first case: **The Empty Coat** (see §4.3.2).
6. Lila leaves the key, turns away from the desk, and walks back through the office door using a dedicated rear northeast cycle.
7. Input becomes active; a minimal unobtrusive hint appears only on first run.
8. The player can inspect the window, lamp/desk, phone, case files, and door.
9. Selecting a floor destination or the door makes Voss stand, transition to standing idle, and walk.

### 9.5 M01 hotspot set

| ID | Display name | First observation | State effect |
|---|---|---|---|
| `office.window` | Rain-streaked window | “The rain had been working the glass harder than I had worked a case.” | Sets `noticedWeather`; demonstrates environmental hotspot. |
| `office.desk` | Desk | “Three old cases, two unpaid bills, one clean page.” | Adds `officeUnpaidBills` knowledge; establishes inspect staging. |
| `office.phone` | Telephone | “Quiet. For once it had the decency to look guilty.” | Sets `checkedPhone`; reserves later incoming-call state. |
| `office.files` | Case files | “Closed, abandoned, and one I still lied about.” | Adds `oldCaseReference`; seeds later narrative. |
| `office.door` | Office door | “The hall smelled worse, but at least it led somewhere.” | Makes Voss approach; door stays locked to M02 with an authored response. |

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
- Voss foley: chair, cloth, shoes, breath.
- Door, paper, phone, mug, and lamp interaction one-shots.
- One sparse music cue with a clean loop or tail for skipping.

The exterior-to-interior transition crossfades beds while preserving a shared rain transient so the cut feels spatial, not like an audio restart.

## 11. UI direction

- Infinity Engine layout hierarchy is intentional: vertical left action rail, right party/portrait rail, bottom dialogue plaque, paperdoll inventory, and ledger journal.
- Materials and iconography remain original RainShadow film-noir craft (rain-slicked gunmetal, smoked leather, oxblood accents, Art Deco filigree). Do not copy copyrighted Baldur’s Gate/Infinity Engine frames or icons. V03 chrome ships heavier BG-like bevel weight under that material lock.
- All visible chrome is painted Image Generator PNG art; code owns layout, hit-testing, live text, and ephemeral hover/selection tints only—no SF Symbols or decorative procedural chrome.
- Use charcoal, oxidized brass, dirty paper, and restrained burgundy accents for text and tints.
- Body text prioritizes readability over distressed styling.
- World labels are short and placed near the target without obscuring it.
- Dialogue and deduction panels can become more substantial later; M01 ships the BG-noir chrome surfaces with stubs for unbuilt systems.
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
- Multiple connected locations, NPC schedules, save slots, localization pipeline, voice-over.
- **Authored combat / chase systems** in the Baldur’s Gate RTWP spirit (§4.3.5): pause-friendly tactics, temporary allies, high-stakes set pieces only.
- Full **Poirot-style summation** scene framework for the campaign finale (§4.3.7).

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
- see Harlan Voss read as tired, early-thirties, and physically grounded at the desk;
- make him stand, walk in any needed direction, pass correctly behind/in front of the desk and foreground occluders, and return to idle;
- experience Lila March’s arrival, Empty Coat handoff, and departure as the first case seed;
- inspect all five hotspots using touch on iOS and mouse on macOS;
- run the scene at the agreed performance target with no stretched sprites, edge halos, unsafe UI, or aspect-ratio-critical crop.

The art gate is qualitative but strict: at final display scale, the office must read as one coherently pre-lit, painterly isometric render even though its interactive pieces are separate.

## 15. Open design decisions after M01

- Full biography and casting notes for **Harlan Voss** beyond the core wound and visual lock in §4.2 (ethnicity detail, pre-Harborpoint history, VO direction).
- Full biography for **Lila March** beyond the dame/client outline (romance branch density; Lillian’s employment is locked as Wharf Ladder shipping office in §4.3.2).
- Exact trait names and whether strain is visible numerically.
- Case-board visual metaphor for the later deduction board (desk papers vs wall board); M01 case surface is the journal.
- Degree of camera control in later, larger areas.
- Save-slot presentation and cross-device strategy.
- Which physical room hosts the campaign’s Poirot summation by default (and which player failures force a harsher venue).
- First combat set-piece location and temporary-ally roster for Act II.

**Closed by §4:** lead names (Harlan Voss / Lila March); missing sister **Lillian March**; first-case arrival by visitor (Lila); first case title **The Empty Coat**; Empty Coat case dossier + M01 journal contract (§4.3.2); corruption as structural world force; RTWP authored combat intent; Poirot-like finale contract.

None of the remaining open decisions blocks the opening-sequence architecture.

# RainShadow — Game Design Document

- Status: pre-production baseline
- Version: 0.3
- Milestone covered: M01 — The Office in the Rain
- Canon leads: **Harlan Voss** (player hired finder), **Lila March** (first client / the dame)
- Case dossier: **The Empty Coat** (§4.3.2) — Act I structure + M01 journal surface

## 1. High-level vision

RainShadow is a film-noir detective role-playing game built around close observation, human pressure, incomplete evidence, and deductions the player must be willing to own. It combines the tactile clarity of a point-and-click investigation with light RPG expression in dialogue, temperament, and consequence—and, when the city refuses to talk, rare **Baldur’s Gate–style real-time-with-pause combat** that is authored, high-stakes, and never a loot grind.

The player inhabits **Harlan Voss**, a weary hired finder in his early thirties: capable, broke, observant, and carrying the accumulated damage of cases that did not end cleanly. The city is not a puzzle box waiting for the correct answer. It is a wet, **structurally corrupt** place where evidence can be true but incomplete, people can lie for defensible reasons, institutions protect themselves first, and the player's chosen interpretation matters.

### Elevator pitch

In rain-strangled Harborpoint, hired finder Harlan Voss studies scenes, questions people, connects imperfect evidence, survives the rare fight he cannot talk past, and makes deductions that change both the case and the man he becomes—until a Poirot-like summation forces every lie into the open.

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

#### The city in one breath

**Harborpoint** is a rain-locked **fantasy-noir** port that runs on ledgers, silence, and small magics nobody bothers to call magic. Hardboiled attitude; light fantasy texture—not high fantasy speech and not a mid-century Earth lock. Coin moves. Ravens move. Bodies move when someone higher needs a problem to look like weather. Rain, charcoal coats, and wet wool sit beside **wards**, hush-charms, sill-wards, and message birds as ordinary city infrastructure—the same way a desk lamp is ordinary. There are no wired telephones or broadcast-radio civilisation locks in Empty Coat canon; when someone needs word across town, a bird or a runner does the work. The player never sees the whole map—only wet fragments that imply more city beyond the frame: pipes knock in walls, carts rattle unseen, signs hum, neighbours argue through plaster.

#### How fantasy works here

- **Wards / hush-charms / sill-wards** — household and office utilities. Cheap ones fail in rain. Expensive ones lie on purpose. An apartment’s hush-ward that “hadn’t tripped” is evidence, not flavour text.
- **Ravens** — message birds with iron perches and droppings on desk leather. A live bird is a line open; a dead raven is a broken line and a threat. Voss’s office inspects an empty perch, not a telephone.
- **Seals that bite** — dock and shipping magic: manifests that hurt if read wrong; **reading-rights** the Watch can smile about and withhold.
- **Thresholds** — boarding-house locks that “hold” are partly carpenter, partly charm. A pause outside a door—like someone testing a threshold—is not only manners.

Magic is never a sparkly skill tree in M01. It is damp, bureaucratic, and for sale.

#### The rain

Theme and mechanic at once. It obscures footprints, reflects lamp-glow into puddles, rinses blood off stone too slowly, erodes cheap paint, and makes lit windows into accusations. Every district smells slightly different when wet: brine and coal on the docks; printer’s ink and tobacco in Printers’ Quarter; cooking oil and wet wool in the tenements.

#### Power structure (corruption is structural)

Corruption is the **operating system**, not a villain’s hobby. Not a mood filter or a single crooked watchman—**how Harborpoint keeps running**:

| Layer | What it pretends to be | What it actually is |
|---|---|---|
| **Municipal hall** | Civic order, permits, “progress” | Kickbacks on contracts; zoning that relocates poverty instead of solving it; records that vanish on purpose |
| **Harborpoint Watch** | Law and investigation (watch house, night books, sergeants, river watch) | Political pressure, selective blindness, soft files; a few honest officers trapped inside a machine that punishes curiosity |
| **Dock Authority & unions** | Labor and trade | Smuggling corridors, “lost” cargo, overtime as hush money |
| **Press & broadsheets** | Public truth | Ownership strings; editors who know which names never print; one or two diggers who still risk ink |
| **Old money & new industry** | Philanthropy, jobs | Private armies in better coats; charity balls that launder reputation; factories that own whole blocks of votes |
| **Street networks** | Crime as chaos | Predictable tribute systems that feed upward into “respectable” ledgers |

The player feels this through locked doors, altered reports, witnesses who suddenly change their minds, and evidence that is **true but incomplete** because someone above the case needed it that way. Not every authority figure is rotten, and not every victim is pure—but **institutions default to self-preservation**. Voss survives by reading which layer he has just kicked.

#### Districts (playable texture, not open-world tourism)

- **Sable Row** — Voss’s block. Tenements, small shops, pipes that argue. First expansion streets. Wet wool and other people’s dinners; unpaid notices on the door.
- **Wharf Ladder / the Docks** — cargo, boarding houses, warehouses, river mouth where coats arrive arranged. Seals that bite, night crews, shipping-office clocks that run three minutes fast when someone wants an alibi the wards will swear to.
- **Civic Spine** — magistrate’s hall, central watch house, records annex. Marble that stays clean in the rain on purpose.
- **Printers’ Quarter** — broadsheets, ink shops, cafés that never close. Lila’s orbit (boarding house, friends with real locks). Gossip as second currency.
- **Ashfield Yards** — industry, company housing, blacked-out windows. Muscle and smog; later wound-seeds live here (not M01 dumps).

Immersion comes from **authored density**: specific smells, recurring NPCs who remember what Voss said last visit, broadsheets that react to case commitments, and weather that changes investigation readability (not merely a particle effect).

#### Institutions Voss actually touches

- **River watch** — drownings, recovered coats, tide speeches offered with coffee and a soft file.
- **Night books** — who was where when the clock lied; duty rosters that read cleaner than the street.
- **Reading-rights** — files the Watch smiles about and does not share; manifests Lillian should not have finished reading.
- **One sergeant** who still answers ravens — useful, compromised, not a mentor arc in Act I.

#### Everyday economy

Good coin vs dock-ledger chalk. Two hundred now is real weight (Lila’s retainer). Unpaid notices are civic and personal. Charter work—hired finder, not Watch badge—sits in the gap between Watch indifference and private revenge. Rent listens; whatever listens for rent in Voss’s building is not purely figurative.

#### Tone rules for world writing

Specific over mythic. Name a bakery doorway before you name a god. Let fantasy show in failed wards, humming keys, and seals that bite. Never explain the cosmology in M01—only how it inconveniences a finder and a sister. Fantasy-noir voice: hardboiled attitude + light fantasy texture; not purple high fantasy and not Earth-analogue phone/radio lock.

#### Seeds (later cases — not M01 dumps)

Mark clearly as **later**. Do not surface in M01 journal or Empty Coat intro as earned facts:

- A broadsheet that printed Voss’s old docker case wrong and will not retract.
- Dock Authority “lost” crates that share seal-marks with Lillian’s last night.
- Ashfield company housing where the docker’s sister still keeps an empty chair.
- A municipal ward-license racket that sells “thresholds that hold” to boarding houses that don’t.
### 4.2 Characters — the two established leads

RainShadow’s first cast is deliberately small and sharp. Supporting players (watchmen, dockers, reporters, siblings, fixers) appear as needed; only two identities are locked as **series leads** for the outline.

#### Harlan Voss — player protagonist

Full canon sheet. Fantasy-noir; specific over mythic. M01 dialogue may paraphrase; it must not invent facts this sheet has not established for that beat. Wound-hint monos and desk stings in `strings.en.json` are the locked M01 voice for the core wound.

##### Who he is now

- **Role:** Independent **hired finder**—charter and coin, not a Watch badge. The player’s body, voice, and moral weather. Clients find him when the watch house has already filed something soft and called it finished.
- **Age / look:** Male, early thirties. Stern angular face with tired pale blue-gray eyes, swept-back auburn-brown hair and pronounced long auburn sideburns; bare-headed. Dark chocolate-brown double-breasted belted mid-calf trench coat with lapels, epaulettes, cuff straps, rear storm flap and vent; cream open-collar shirt, loose black tie, charcoal cuffed trousers and brown lace-up shoes. Economical movements, guarded posture, capable hands.
- **Station:** The Watch still knows his name; they do not miss him. Office on **Sable Row**—hearth ticks, unpaid notices, empty raven perch, case papers he still lies about. Rent—and whatever listens for rent in the building—keeps him seated.

Seated idle for M01 communicates fatigue without inertia: breathing, a small shift, rubbing a thumb along a mug, checking the rain, suppressing a cough.

##### How he works

He reads rooms before people. He lets silence do half the interrogation. He takes cases he half-believes are already dead, because rent does not care about his standards. He writes clean notes and keeps dirty doubts. He will lie to a sergeant if the truth would bury a living person under a tidy coat. Will fight when cornered, but treats violence as a confession that talk failed.

##### The Watch years (backstory spine)

River watch for six years, then night books at the Wharf Ladder annex. Good at drownings that were not drownings. The break: a missing **docker** he “closed” on a coat and a tide chart. Paper said suicide. A sister said otherwise. He chose the paper. She was right. He left before the Watch could make him choose paper again. That case is the wound Empty Coat rhymes with—Lila walks in wearing the shape of his old mistake.

##### Core wound

He closed a case correctly on the ledger and wrong in the world. Someone paid for his certainty. He will not say the docker’s name in M01, but the unpaid notices on his desk are not only about money—they are about work he will not touch because it smells like that file.

Shipped wound hints (do not drift these quotes without updating the string table):

- Mono 3: “Same as yesterday — and the night I trusted a tide chart more than a sister.”
- Mono 4: “…Like someone who had already been told the river was answer enough.”
- Mono 5: “I already hated how familiar that shape felt.”
- Desk 2: “I have closed a case on less — and been wrong in a way ink doesn't show.”
- Desk end: “I am done calling coats an ending.”

##### How he sounds

Short sentences. Weather and objects before feelings. Dry enough to pass for cruel until you notice he is measuring cost, not scoring points. Dry wit sharpened by fatigue. Observant before he is brave. Occasionally compassionate, never omniscient. He can be harsh; the game never confuses cruelty with competence. Fantasy sits in the seams (wards, ravens, coin that never warms) without turning him into a mage or a prophet. He notices magic the way he notices damp: as evidence.

- **Voice sample (design target):** “The rain had opinions about my rent. The woman in the doorway had better ones about my time.”
- **Shipped mono 1 texture:** “Rain had been working the glass since afternoon. The ward on the sill hadn't bothered to argue.”

##### Temperament levers (for dialogue)

| Tone | How he plays it |
|---|---|
| **Warm** | Protects the client first; softens facts without falsifying them |
| **Dry** | Inventory and timeline; trusts ledgers more than tears |
| **Sharp** | Tests the story for exits; assumes everyone is selling something, including him |

##### Relationships

- **Harborpoint Watch:** Useful contacts, no loyalty. One tired sergeant still answers his ravens. Most of the house treats him as a man who quit when it got hard.
- **Lila March:** Not romance in M01—**recognition**. She is the sister who did not accept the coat. That frightens him more than the gray greatcoat does. Attraction, trust, or rupture remain **player-shaped** beyond M01.
- **The city:** He loves Harborpoint the way you love a building that is trying to kill you slowly: you know every stair that creaks.

##### What he wants (stacked)

1. Coin enough to keep the sill-ward fed and the notices quiet.
2. A case he can finish without filing a comfortable lie.
3. *(Buried)* Proof he is not still the man who chose the ledger over the sister.

##### What he must not become

Omniscient. Soft-boiled. A chosen one. A Watch reform arc in Act I. He is good; he is not clean.

##### Seeds for later (not M01 dumps)

- The docker’s sister still lives in Ashfield Yards.
- His old river-watch logbook is missing three nights.
- The sergeant who answers ravens wants a favor that will cost a name.
- Something in his office hush-ward was set by a person who is not him.

- **Superseded working name:** Elias Vale (retired; the V6 redesign renamed all art, portraits, and code identifiers to Voss).

#### Lila March — the dame / first client

Full canon sheet. Fantasy-noir; specific over mythic. M01 dialogue may paraphrase; it must not invent facts this sheet has not established for that beat.

##### Who she is

- **Role:** Client who forces the first case into Voss’s office; romantic-noir **dame** archetype played straight and human, not as a costume.
- **Age / look:** Mid-to-late twenties. Chic chin-grazing textured blunt bob (soft side part, airy lived-in finish) and a fitted deep-emerald day dress—nipped waist, modest scoop neckline, knee-length soft flare, dark pumps, compact handbag. Figure-flattering period daywear without crossing under-15 suitability. Composed enough that the cracks show only if Voss presses.
- **Station:** Not Watch, not Dock Authority, not money. Boarding house near **Printers’ Quarter**. By day she keeps books for a small **ink-and-paper shop**; she reads other people’s ledgers when she has to. She hired Voss because the Watch offered coffee and tides—and she has run out of polite rooms.
- **Orbit:** Friends with real locks and thresholds that hold; gossip as second currency; ink-shop books as honest work that also teaches her how manifests hide.

##### Bond with Lillian

**Lillian March** is older by three years—the steady one. Ledgers, manifests, seals at Wharf Ladder. Lila is the one who argues. They share a mother who left early and a habit of sewing their own hems because coin spent on a tailor is coin that should have been food. Lila does not romanticize Lillian. She is furious at her for being the kind of person who would chase an unfinished book into danger—and terrified that fury is the last true thing she still has.

##### What she knows (and what she holds back)

She knows the coat was **arranged**. She knows the key **hummed**. She knows Lillian was reading manifests that made someone nervous. In M01 she admits the manifests only under **pressure**—not coy for sport, but because names without proof get people followed, and she is already being followed. The **gray greatcoat** is not a rumor invented for leverage: she has timed him (eleven to one, bakery doorway). She is exhausted and still precise.

##### How she sounds

Complete sentences when she is selling the case. Shorter when she is cornered. She matches Voss’s dry register without mimicking him—she is not performing noir; she is trying not to shake. Fantasy texture enters as **fact** (hush-ward, reading-rights, seals that bite), never as wonder. She does not find magic interesting. She finds it inconvenient and real.

- **Voice sample (design target):** “Lillian still sews her own hems. She would not leave a coat that cost her a week.”
- **How she talks:** More precise than emotional. Answers the question you didn’t ask. Charm is control. She also says one ordinary, slightly ugly thing—a fee, a lock, a sister’s bad habit—that no poster would print. If a line could go on the poster, it isn’t Lila yet.

##### Money

Two hundred now is not a flourish. It is most of what she can liquidate without selling the boarding-house bond. Good coin, not dock-ledger chalk. “The rest when you find her” is faith and threat in one line—if Voss takes the coin and files soft, she will not go quietly to another office.

##### Temperament against Voss’s levers

| His tone | How she answers |
|---|---|
| **Warm** | Softens; pays faster; offers the follower clean |
| **Dry** | Becomes a clerk of her own grief—times, places, the coat in the paper bag |
| **Sharp** | Goes cold and useful; the gated manifests line is her refusing to be handled |

##### What she wants (stacked)

1. Lillian alive—or a truth that is not a coat.
2. The gray greatcoat off her stairs.
3. *(Buried)* Not to become the sister who accepted the ledger’s answer, the way someone once did to another family.

##### What she must not become

The dame as prize. A quest-giver with no interior. A liar for twist’s sake. If she withholds, it costs her—**fear, not cleverness**. She is not a trophy or a pure victim, and not automatically a traitor—**the player must earn which**.

##### Relationship to Voss

Professional first. Attraction, trust, or rupture are **player-shaped**, not a mandatory romance track. Wit is their shared language; silence is their shared weapon. Competence that is not charm: she sews; she can read a shipping roster; she found the key the Watch never felt for. Loyalty that can hurt him: she will protect Lillian’s dock work before she protects his case. Bad at his game, once: a pause, a too-fast money answer, or a fee she names awkwardly—when she lies, the lie is small and checkable, so the dock truth is never “the dame was the twist.”

##### Seeds for later (not M01 dumps)

- The ink-shop owner saw the gray greatcoat two days before Lila did.
- Lila has a partial copy of one manifest line she will not show until she trusts Voss not to sell it.
- She and Lillian fought the night before the vanishing—about whether to burn a page.
- Printers’ Quarter friend with “real locks” owes her a favor she hates using.

- **Superseded working name:** Vivian Hart (retired; the V6 redesign renamed the arrival/departure atlas, dialogue portrait, and narrative copy to March).

#### Supporting cast (named only as needed by the outline)

Do not expand into full sheets here. Story beats may introduce: a tired Watch sergeant who still answers Voss’s ravens; a dock clerk who sells silence by the hour; a society fixer who never gets rain on their shoes; the missing sister as presence-through-absence until the endgame allows her truth—alive, dead, or worse—to land.

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
The brass key opens more than a locker: a chain of storage slips, union marks, and names that appear in both Watch night books and charity donor lists. Witnesses contradict each other on purpose. Voss’s strain rises. Optional and required combat set pieces appear when a warehouse watch, a night alley, or a “quiet chat” turns into an ambush—still sparse, always motivated.

**Act III — The city answers back**  
Commitments on the deduction board close routes. Lila’s partial truths come due. A faction above the docks tries to buy Voss off, bury him in paperwork, or remove him. Allies may join for a fight or a testimony. Corruption is no longer ambient; it has a face, a budget, and a preferred ending in which nobody important is embarrassed.

**Act IV — Summation (Poirot close)**  
Voss engineers (or is forced into) a gathering of the remaining principals. In a controlled space, he reconstructs the timeline: the sister’s last movements, who emptied the coat, which institution needed the silence, and which personal betrayal made the machine efficient. The player’s prior hypotheses and failed-forward choices color **how complete and how merciful** the reveal is—but the design center is always the **dramatic laying-out of the chain**, not a sudden unearned twist from nowhere. After the truth is spoken, a final irreversible commitment: accuse, expose, bargain, or walk away—and live with Harborpoint’s echo.

#### 4.3.2 First case — “The Empty Coat” (case dossier)

This section is the **authoritative case structure** for Act I and the M01 case journal. Runtime journal copy (`EmptyCoatJournalContent`) must stay consistent with it. Dialogue may paraphrase; it must not invent facts the dossier has not established for that beat.

**Terminology lock:** the follower wears a **gray greatcoat**. Lillian’s garment and the case title stay **coat** / **THE EMPTY COAT**.

##### Logline

In rain-strangled Harborpoint, hired finder Harlan Voss takes a sister’s coin after the Watch called a humming key and an empty coat an ending—and discovers the missing ledger-keeper was reading seals someone needed unread.

##### Theme

Comfortable lies vs unfinished books. Coats are alibis. Sisters refuse them. Voss has been both men.

##### Dramatic question (Act I)

Can Voss find Lillian—or the truth that isn’t a drowning—before the gray greatcoat finishes the ritual the key was meant for?

##### Scope gate (M01 vs Act I runway)

| Beats | Scope | Status |
|---|---|---|
| **1–2** Cold open + first office loop | **Shipped M01** | Office only: intro, retain, key, inspect, journal surface |
| **3–7** Wharf Ladder → Act I break | **Act I runway beyond M01** | Design roadmap; do not silently inflate M01 scope |

##### Seed (campaign spine)

1. **Lila March**’s sister **Lillian March** is missing.
2. A coat is recovered by the river—**empty** in a way that feels arranged, not merely abandoned.
3. A concealed **brass key** is sewn into the lining (not left where a hurried search would “find” it); it hummed once.
4. Someone with institutional reach wanted the coat found without a body, or the body gone without the coat.
5. Voss’s office becomes the first board where facts, testimony, and distrust share a desk lamp.

M01 ships the arrival, the key handoff, office freeroam, and the **case journal surface**. Later milestones open the river, docks, and civic records that turn the seed into a full investigation.

##### Act I structure

###### 1. Cold open — Office in the rain *(shipped M01)*

Voss alone. Wound hints (tide chart / sister). Threshold pause. Lila enters. Branching retain. Key on desk leather. Case opened: **THE EMPTY COAT**.

**Emotional payload:** Recognition, not romance. He sees his old mistake walking in with good coin.

###### 2. First loop — Office as tool *(shipped M01)*

Inspect hotspots. Desk monologue. Journal: retained; optional pressed-hard on manifests. Player learns the room is a character: raven perch, case papers, sill-ward, unpaid notices.

###### 3. Lead one — Wharf Ladder shipping office *(Act I beyond M01)*

Lillian’s desk, night clock that runs fast, clerk who sold silence by the hour. Evidence: seal-mark scrap; “one more errand uptown”; someone scrubbed reading-rights on her last manifest pull.

**Scene card — Wharf Ladder shipping office** *(design runway; not M01)*

**Case:** The Empty Coat · Beat 3 (Act I runway beyond M01 office slice)  
**Location:** Shipping office near the river mouth; ledgers, seals, a clock that runs three minutes fast when the night crew wants an alibi the wards will swear to.  
**Scope:** Design only. Does not inflate M01 implementation. Follower = **gray greatcoat**. Case garment / title = **coat** / **THE EMPTY COAT**.

**Purpose:** Give the player Lillian as a worker, not only a missing sister. Plant seal-magic and scrubbed reading-rights. Introduce a human obstacle who sells silence by the hour.

**Entry:** Voss arrives with Lila’s two hundred still warm and the key’s hum in memory. Optional: Lila waits outside (threshold that holds) or stays at Printers’ Quarter—player choice from prior beat.

**Cast on stage:**

| Role | Who | Notes |
|---|---|---|
| PC | Harlan Voss | Dry first; Watch past helps or hurts depending on tone |
| Obstacle | Dock clerk (working name: Merrick) | Sells silence; knows Lillian’s last night; afraid of seals |
| Absent pressure | Gray greatcoat | Seen across the quay once—does not enter yet |
| Optional | Night watch runner | Mentions soft file / tide speech if Voss flashes old river-watch habits |

**Objectives:**

1. Confirm last sighting: left at nine, “one more errand uptown,” no hired coach on the desk slate.
2. Find seal-mark scrap or bitten-glove smear on her desk-leather edge.
3. Learn reading-rights on her last manifest pull were scrubbed after she vanished.
4. Exit with a lead toward Civic Spine records or Dock Authority lost-crate numbers.

**Obstacles:** Clerk won’t talk without coin, a favor, or a threat that costs Voss something (Warm / Dry / Sharp gates). Seals that bite: inspecting the wrong folio without reading-rights = pain / alarm / clerk panic. Night clock lies; timeline must be reconstructed, not trusted.

**Evidence / journal payoffs (Act I flags — not M01):** `lillian.lastShift.wharfLadder`; `evidence.sealMark.scrap`; `knowledge.readingRights.scrubbed`; optional `sighting.greatcoat.quay`.

**Dialogue spine (not full script):**

- Clerk: “She never missed the morning ferry. That night she did everything twice — checked the seal, checked it again.”
- Voss (dry): “Show me the second check.”
- Clerk (if pressed): “Someone from Civic came for the reading-rights after. Polite. The folios still hurt if you touch the wrong line.”
- If sharp: clerk names a crate mark then clamms; greatcoat across the quay shifts.

**Failure / soft fail:** Leave with only the ferry/nine facts (already known) and a frightened clerk. No seal scrap—Act I still playable via river stones, but Civic Spine lead is weaker.

**Success:** Seal scrap + scrubbed rights + uptown errand sharpened. Player owns a deduction: Lillian wasn’t drowning bait; she was reading something someone needed unread.

**Tone locks:** No combat required. Magic = bitten seals and scrubbed rights, not fireballs. Greatcoat is silhouette, not boss fight. Voss does not confess the docker wound here.

**Art / audio notes:** Oil lamps, wet wool, brass seal-presses, raven cage in the corner (empty). Clock tick slightly off. Distant ferry horn. Rain on tin roof harder than on Sable Row glass.

**Exit:** To river stones / iron stairs (Beat 4) or straight to pressure if the player saw the greatcoat on the quay.

###### 4. Lead two — River stones / iron stairs *(Act I beyond M01)*

Where the coat was found, arranged. River watch repeats the tide speech. Soft file smells of political pressure, not incompetence alone.

###### 5. Pressure — The gray greatcoat *(Act I beyond M01)*

Not a jump scare: professional habits. Streetlamps dim. He wants the key, not Lila’s life—yet. Choice: protect Lila’s threshold / bait with a false key rumor / ask the sergeant who still answers ravens (costs a favor).

###### 6. Mid-Act turn — The page they almost burned *(Act I beyond M01)*

Lila admits the fight: Lillian wanted to burn a manifest line; Lila wanted a copy. Partial line surfaces (trust gate). Names point toward Dock Authority “lost” crates and a Civic Spine reading-rights signature.

###### 7. Act I break *(Act I beyond M01)*

Voss holds the key’s true shape (not inn, not desk—a seal-locker or ward-safe uptown). Lillian is likely alive *or* made to look drowned for a reason that still needs her handwriting. The Watch will not help without a sacrifice. The greatcoat stops pretending to only watch.

##### Character arcs (Act I only)

| Character | Starts | Ends Act I |
|---|---|---|
| **Voss** | Avoiding missing-person rhymes | Committed to a case he can’t file soft |
| **Lila** | Buying help with two hundred and fury | Partner in risk; still not a prize |
| **Lillian** | Absence / coat | Presence through handwriting, seals, unfinished book |
| **Gray greatcoat** | Follower | Active claimant on the key |

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

1. Lillian vanished **two nights past** after work at a shipping office near **Wharf Ladder** (ledgers, manifests, seals that bite if you read them wrong).
2. Last known: left work about nine; told a clerk she had one more errand uptown; no hired coach chalked on the desk slate.
3. By midnight, river watch found her coat on the stones below the old iron stairs—empty, arranged; no body. Like an offering someone wanted found.
4. **Harborpoint Watch** soft-file: missing adult, no struggle, coat recovered, probable drowning; case cooling before the ink dried. Polite; no reading-rights on the file.
5. Coat pockets turned as if to show nothing left to steal; **brass key sewn into the lining**—recovered by Lila before the garment fully left her hands; faint lamp oil and river water on the metal.
6. Since the key: a **Gray Man** (gray greatcoat, black gloves) follows Lila; professional habits (cart noise, doorway posts); he turns away when met with a direct look; streetlamps dim a fraction when he stands under them.
7. Voss accepts the case; the key stays in his care on the desk leather.

##### People

| ID | Name | Role | Status at M01 | Notes |
|---|---|---|---|---|
| `person.lila` | Lila March | Client | Interviewed | Precise under pressure; withholds deeper dock/sister secrets until pressed with evidence |
| `person.lillian` | Lillian March | Missing person | Whereabouts unknown | Shipping-office ledgers; hated the river; hated unfinished books; last seen two nights past |
| `person.gray-man` | The Gray Man | Unknown watcher | Unidentified | Gray greatcoat, black gloves; not yet proven badge vs private muscle; knows Lila came to Voss |
| *(Act I later)* | Night sergeant / river watch | Institutional | Not interviewed in M01 | Soft close: coffee, tides, politeness with teeth |
| *(Act I later)* | Shipping-office clerk | Witness | Not interviewed in M01 | Last conversation with Lillian; “errand uptown” |

##### Evidence

| ID | Item | Custody | Reliability | M01 journal? | Leads |
|---|---|---|---|---|---|
| `evidence.key` | Brass key from coat lining | Voss | Credible physical | Yes | What lock? Faint lamp oil and river fog |
| `evidence.coat` | Riverside coat | Watch / described by Lila | Uncertain / possibly staged | Yes | Recovery site; constable property log |
| `evidence.pd-file` | Soft missing-person file | Harborpoint Watch | Compromised / incomplete | No (later) | Ally sergeant; dual ledgers |
| `evidence.blue-room` | Blue Room matchbook (Wardour Street) | Unearned in M01 | — | **No** | Act I seed only—do not show in M01 journal until the player earns it |

##### Objectives / leads (organized doubt, not quest checkboxes)

**M01 (office only — beats 1–2)**
- Keep the key safe; case file open in the journal.
- Record office field notes via hotspot inspections.
- Journal leads (destinations still locked): identify the lock; build Lillian’s timeline from two nights past; find or name the Gray Man; re-check the river stones when the city opens.

**Act I beyond M01 (beats 3–7 — design roadmap; non-spoiler)**
- Wharf Ladder shipping office / manifests Lillian was reading (seal-mark scrap; scrubbed reading-rights).
- River recovery site + constable / river-watch soft file.
- Gray greatcoat pressure (threshold / bait / sergeant favor).
- Mid-act trust gate: the page they almost burned; partial manifest line.
- Civic Spine / Dock Authority “lost” crates signatures.
- Optional later seed: Blue Room on Wardour Street (matchbook or testimony)—only after earned.

##### Chronology (case log · approximate Voss notation)

Prefer **narrative order** (coat → key → follower → office). Times are detective notation, not a forensic clock. Empty Coat does not use Earth weekday names in player-facing copy—“two nights past” is the lock.

| Approx. time | Event | Journal entry ID |
|---|---|---|
| Two nights past · ~9:00 PM | Lillian leaves Wharf Ladder shipping office | `log.leave-work` |
| Two nights past · night | Gap: “errand uptown” / unknown | folded into movements |
| Two nights past · ~midnight | Coat recovered riverside (old iron stairs) | `log.coat` |
| After recovery | Lila finds brass key in lining | `log.key` |
| Same night | Lila followed by the Gray Man (gray greatcoat) | `log.followed` |
| Two nights past · ~11:40 PM | Case opened at Voss’s office | `log.case-open` |
| After retain | Office field notes (if hotspots inspected) | `log.office` |

##### Open mysteries (writer hooks; not journal spoilers)

Kept open on purpose through Act I:

- What the humming key opens (seal-locker / ward-safe uptown—shape earned at Act I break).
- Who benefited if Lillian stopped reading manifests.
- Who emptied the coat, and why leave the key?
- Is Lillian alive, dead, or “worse” (held / erased from ledgers / made to look drowned for handwriting)?
- Which institutional layer benefits from a tidy drowning?
- Whether the docker’s old case and this one share a ledger hand (**hint only**—no dump in M01 or early Act I).

##### Tone locks (Act I)

Fantasy is bureaucratic damp. No chosen-one prophecy. Combat rare and authored if it appears. Deductions the player owns.

##### What M01 must teach

Observe → pressure dialogue → journal commitment → leave the office with a live case and a live wound.

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

- Internal narration: short, concrete, occasionally funny because it is accurate. The house voice is the §9.5 inspect captions: one image, no lecture. If an intro page is longer and prettier than those five captions, it has already failed.
- Dialogue intentions (Open / Press / Feign / Trade / Observe / Leave) are **author method**, not player-facing labels and not a second morality meter. The player reads the line. Baldur’s Gate replies are numbered prose.
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
5. **Final commitment** — the player chooses the legal, moral, or pragmatic aftermath; Harborpoint reacts in epilogue texture (press, Watch, docks), not a binary credits slide alone.

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
- a fixed three-quarter isometric projection (Baldur's Gate: EE orthographic camera);
- crude hundreds-of-triangles 3D avatar meshes rendered offline into lightly pixelated 2D sprite frames with readable clothing/equipment masses and multi-orientation animation;
- baked environmental lighting plus selective live overlays;
- ground-contact shadows that keep sprites attached to the room;
- separate doors, actors, effects, and interactive props;
- foreground cutouts and depth anchors that allow characters to pass convincingly behind furniture and architecture;
- dense texture at the source, read through strong value shapes at play scale.

The goal is equivalent visual density and staging, not literal duplication of any copyrighted location, character, interface, or prop.

### 5.2 Camera and composition

- Fixed projection, targeting the Baldur's Gate: EE orthographic camera — elevation `asin(0.75)` ≈ 48.59°, azimuth 45°, ground axes at 36.87° (slopes ±0.75), height foreshortening ≈ 0.6614, nav diamond 128×96. `ie_projection.ACTIVE` is BGEE; each plate's measured runtime/staging status is recorded in `Documentation/InfinityEngineGroundProjection.md` and `Documentation/BGEEProjectionMasterRegen.md`.
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
- At 100% play zoom, Voss's 64-row native body displays at 64 logical screen points. The camera scale is the unchanged 70.3125-unit world body divided by 64; window resizing reveals more world without enlarging him. Player zoom scales the whole scene. The old 9%-of-window target is retired; prop and door proportions remain tied to the same world body. See `NativeSpriteCameraCalibration.md` for the engine evidence and SpriteKit/Retina limits.
- Shading uses broad baked diffuse planes, low-resolution texture maps, restrained ambient occlusion, and limited muted color ramps. Generator masters are rasterised through `BGEE_V1`: a 64-row craft body with 1-bit alpha hardened at 50%, per-material 64-entry ramps without dithering, highlight-side value expansion, and a 1.15x torso/coat width correction that leaves the head unchanged and ramps back to 1.0x through the lower body without changing height or pivot. The 64-row choice is calibrated against a representative BG humanoid BAM's measured 52–60-row crown-to-ground span and is the smallest nearby grid that preserves every authored Voss gait. The indexed plane is resolved at native size and enlarged directly into the unchanged registered body by SpriteKit's linear sampler, matching BG:EE's non-nearest creature mode without a Super-xBR prefilter. See `BGEEHumanoidPipeline.md`; V14/V15 remain historical comparisons. Avoid hand-placed pixels, coarse decorative pixel clusters, painterly brushwork, and modern pore/strand-level detail.
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

**Correct pattern (shipped Empty Coat acceptance):** Lila’s last triad-3 NPC state offers Voss’s acceptance prose as **`CaseDialogueChoice` text**; selecting it advances to the next NPC beat (`lila.plea`). The acceptance prose lives in `empty-coat.intro.dialogue.json` (it is no longer a Swift constant); the rule is held by tests `midConversationPCLinesAreReplyOptionsNotContinueStates` and, across every shipped graph, `noShippedGraphDeliversMidConversationPCSpeechAsAContinuePage`.

**Allowed exception:** the **pre-conversation interior monologue** (`voss.monologue.*`, `isInteriorMonologue`) may use Continue-only Voss pages. That is noir framing *before* the NPC exchange, not a DLG-style PC reply.

Future authors and tools must preserve this convention when adding graphs. Reverting PC speech to auto-Continue speaker states is a design regression.

#### Intentions

Dialogue choices are tagged by intention rather than morality. The tags are **writer method** — they are not painted on the reply row. Tone (`warm` / `dry` / `sharp`) is the temperament of the line, metadata-only — not a Good/Neutral/Cynical meter. Intention is the system.

- **Open** — invite detail, acknowledge, or wait.
- **Press** — challenge, corner, or expose a contradiction.
- **Feign** — bluff knowledge, conceal motive, or misdirect.
- **Trade** — offer information, safety, money, or discretion.
- **Observe** — say little and watch the reaction.
- **Leave** — end or defer without a false choice.

Do not invent a Leave option to fill the taxonomy. Empty Coat ships with **no** `intention: leave`: M01 must seed the case through Lila’s handoff, so a refuse-the-job Leave would skip the intro, and a Leave that still retains her is a false choice. Keep `leave` for later conversations that can actually end or defer. Empty Coat’s only extra gate is Press.

Choice availability can depend on evidence, knowledge, traits, prior tone, time pressure, and the speaker's current threshold. The UI may disclose the main reason for a special option, such as `[Evidence: Tram Receipt]`, without revealing the outcome. Do **not** prefix replies with `[Open]`, `[Press]`, or the other intention names.

### 7.6 Pressure, condition, and failure-forward play

The detective has a situational **strain** state rather than a survival meter. Threats, sleeplessness, alcohol, injury, and morally difficult choices can raise strain. High strain changes animation, internal narration, and the cost or availability of some approaches; it does not randomly erase clues.

Failed checks produce information with a cost, a changed relationship, time loss, exposure, or a narrowed option. Critical case progress always has at least one non-check route.

## 8. Interaction and controls

### 8.1 Shared interaction grammar

- Tap/click navigable floor: walk there.
- Tap/click hotspot: select and approach; interact on arrival when unambiguous.
- Tap/click actor: approach or begin conversation.
- Drag/pinch or scroll: camera pan/zoom only when a scene permits it.
- Escape: stop the current path, dismiss an overlay, or step back one UI level. Two-finger tap / right-click clears targeting state and does **not** stop a walk — the *Sword Coast Survival Guide* lists R-click as cancelling "attacks or spellcasting", and the engine's right-click path only clears target mode.
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
- Escape: stop/back. Right click: clear targeting (never stops a walk).
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
| 6.0–9.0 s | A few windows glow; most are dark. The office window is a small dirty amber rectangle. | Rain remains dominant; faint hearth/room tone begins under it. | Identify destination by contrast. |
| 9.0–12.0 s | Camera eases toward the office window. Exterior foreground darkens. | Exterior rain filters; interior window patter and lamp hum become clearer. | Motivate the transition. |
| 12.0–14.0 s | Warm window shape fills enough of frame to match the office window or lamp pool. Crossfade through shadow. | Seamless ambience crossfade. | Move inside without a hard loading beat. |

No title card should obscure the best establishing composition. If a title is used, place it during the first hold in small, restrained typography and support disabling it during repeat play.

### 9.3 Interior composition

The office is a single isometric room with enough floor for a short path loop. Required story zones:

- **Zone 1 — Detective work area**: NE-facing desk island with Voss’s chair, two client chairs, anchoring rug, wastebasket, lamp, **raven perch**, typewriter, notebook, mug, ashtray, case papers/folios, and unpaid notices. Keep at least one tile of movement clearance around the cluster.
- **Zone 2 — Archive and case wall**: bookcase, filing cabinet, and small safe as one west-wall storage run; consolidated archive boxes; cork case board, city map, framed licence, and pinned photographs on the plaster behind the desk; rain window with Venetian blinds and **hearth** heat on the window wall; cool blind-striped spill on the floor.
- **Zone 3 — Entrance and waiting**: door with coat stand and umbrella stand beside it; two mismatched waiting chairs and a small table (newspaper + ashtray) against the right wall; narrow worn runner from the entrance toward the desk; doorway kept clear of boxes.
- **Negative space**: a navigable floor wedge in the lower foreground; warm amber lamp key against cold window light and a narrow warm hallway slit through the open door.

The room should feel used and cramped but compositionally controlled. Every major prop belongs to a recognizable cluster. The lamp, Voss silhouette, window, and door must remain readable at phone scale.

### 9.4 Interior beat sheet

1. The interior resolves while rain continues over the window.
2. The lamp pool reveals seated Harlan Voss at his desk.
3. He completes one authored seated-idle beat: breath, small shoulder shift, brief glance toward the rain.
4. **Lila March** enters from the office door and crosses to the visitor side of the desk.
5. A short player-advanced exchange establishes her missing sister, a coat found by the river, a concealed brass key, and the first case: **The Empty Coat** (see §4.3.2). Pages must not out-pretty the five inspect captions in §9.5.
6. Lila leaves the key, turns away from the desk, and walks back through the office door using a dedicated rear northeast cycle.
7. Input becomes active; a minimal unobtrusive hint appears only on first run.
8. The player can inspect the window, lamp/desk, raven perch, case papers, and door.
9. Selecting a floor destination or the door makes Voss stand, transition to standing idle, and walk.

### 9.5 M01 hotspot set

| ID | Display name | First observation | State effect |
|---|---|---|---|
| `office.window` | Rain-streaked window | “The rain had been working the glass longer than I had. The sill-ward didn't care either way.” | Sets `noticedWeather`; demonstrates environmental hotspot. Second look (after retain): client + humming key. |
| `office.desk` | Desk | “Three cold cases, two debts the ledger still remembers, one page that hasn't learned a name yet.” | Adds `officeUnpaidBills` knowledge; establishes inspect staging. After retain, second look shows the key on the desk leather. |
| `office.phone` | Raven perch | “Empty iron perch. Droppings on the desk-leather edge. For once the bird had the decency to stay gone — and look guilty doing it.” | Sets `checkedPhone` (legacy flag id); reserves later raven-message state. Hotspot id stays `office.phone`. |
| `office.files` | Case papers | “Sealed. Abandoned. And one folio I still lied about — to the client, and to whatever keeps the cabinet shut.” | Adds `oldCaseReference`; seeds later narrative. |
| `office.door` | Office door | “The hall smelled worse — damp wool, old wards, someone else's business. At least it led somewhere.” | Makes Voss approach; door stays locked to M02 with an authored response. |

These five captions are the **locked house voice** and must match `strings.en.json` / `OfficeHotspotInspect`. Do not drift them in docs without updating the string table.

## 10. Audio direction

### 10.1 Principles

- Rain is layered, spatial, and continuous across the scene transition.
- Music supports dread and exhaustion without filling every second.
- Interior sound is intimate: window patter, hearth ticks, lamp hum, chair creak, cloth movement, distant plumbing.
- Repetition must be difficult to detect; loops use long beds plus randomized one-shots.
- Dialogue remains intelligible on phone speakers and supports subtitles.

### 10.2 M01 mix layers

- Exterior heavy-rain stereo bed.
- Exterior detail emitters: gutter, puddle impacts, distant traffic, sign/electrical buzz.
- Interior rain-on-glass bed.
- Interior room tone and hearth/pipe one-shots.
- Voss foley: chair, cloth, shoes, breath.
- Door, paper, raven-perch, mug, and lamp interaction one-shots.
- One sparse music cue with a clean loop or tail for skipping.

The exterior-to-interior transition crossfades beds while preserving a shared rain transient so the cut feels spatial, not like an audio restart.

## 11. UI direction

- Infinity Engine layout hierarchy is intentional: vertical left action rail, right party/portrait rail, bottom dialogue plaque, paperdoll inventory, and ledger journal.
- Deliberately opening a searchable container uses a compact, non-modal BG2-style transfer panel. The left 3×2 grid is the persisted source; the centre identifies Voss's case bag and capacity; the right 2×2 viewport is his real carried inventory; and the far edge is the party purse. Coins bypass the bag into the purse. Ordinary items—including firearms—move bidirectionally between source and bag when capacity permits, and Take All transfers everything that can fit while leaving the remainder persisted. A recovered firearm is carried, never auto-equipped, though it can now be readied by hand from the inventory window. Closing or issuing another world command never discards contents. Quick Loot is shipped: the right-rail Search control opens a non-modal strip listing every stack lying within reach of Voss, ten to a row with page chevrons past that, and one click lifts a stack straight into the case bag. Items dropped from the inventory window land at his feet and persist there per area. Ammo and condition still wait for the weapon model.
- Frames and the broader icon system remain original RainShadow film-noir craft (rain-slicked gunmetal, smoked leather, oxblood accents, Art Deco filigree). The opened-container Take All control deliberately reconstructs the red diamond in the user's BG2/BGII:EE screenshot with newly generated pixels; no shipped BAM or surrounding BG frame is extracted. The matching installed BG:EE `WORLD_CONTAINER` definition separately identifies that control as `ROUNDBUT` and its action as Take All. V03 chrome ships heavier BG-like bevel weight under that material lock.
- All visible chrome is painted Image Generator PNG art; code owns layout, hit-testing, live text, and ephemeral hover/selection tints only—no SF Symbols or decorative procedural chrome.
- Use charcoal, oxidized brass, dirty paper, and restrained burgundy accents for text and tints; the saturated red Take All diamond is the deliberate contextual-control exception.
- Body text prioritizes readability over distressed styling.
- World labels are short and placed near the target without obscuring it.
- Dialogue and deduction panels can become more substantial later; M01 ships the BG-noir chrome surfaces with stubs for unbuilt systems.
- Support Dynamic Type-equivalent scaling within designed bounds, subtitles, reduced motion, reduced rain intensity, high-contrast hotspots, and independent audio sliders.

## 12. Scope boundaries

### In M01

- Exterior establishing scene and rain.
- Cinematic transition into the office.
- Complete plate-first office composition: static furniture is painted into the
  area master; the seated desk cluster and registered entrance-door states stay live.
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

- Ethnicity detail, pre-Harborpoint childhood, and VO casting notes for **Harlan Voss** beyond the full §4.2 canon sheet.
- Romance-branch density and Act II+ casting notes for **Lila March** beyond the full §4.2 canon sheet (Lillian’s employment remains Wharf Ladder shipping office per §4.3.2).
- Exact trait names and whether strain is visible numerically.
- Case-board visual metaphor for the later deduction board (desk papers vs wall board); M01 case surface is the journal.
- Degree of camera control in later, larger areas.
- Save-slot presentation and cross-device strategy.
- Which physical room hosts the campaign’s Poirot summation by default (and which player failures force a harsher venue).
- First combat set-piece location and temporary-ally roster for Act II.

**Closed by §4:** lead names (Harlan Voss / Lila March); missing sister **Lillian March**; first-case arrival by visitor (Lila); first case title **The Empty Coat**; Empty Coat case dossier + M01 journal contract (§4.3.2); Harborpoint world bible (§4.1); full Harlan Voss and Lila March character bibles (§4.2); corruption as structural world force; RTWP authored combat intent; Poirot-like finale contract.

None of the remaining open decisions blocks the opening-sequence architecture.

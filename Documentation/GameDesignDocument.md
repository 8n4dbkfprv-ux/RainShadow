# RainShadow — Game Design Document

- Status: pre-production baseline
- Version: 0.5
- Milestone covered: M01 — The Office in the Rain
- Canon leads: **Harlan Voss** (player hired finder), **Lila March** (first client / the dame)
- Case dossier: **The Empty Coat** (§4.3.2) — Act I structure + M01 journal surface

## 1. High-level vision

RainShadow is a film-noir detective role-playing game built around close observation, human pressure, incomplete evidence, and deductions the player must be willing to own. It combines the tactile clarity of a point-and-click investigation with light RPG expression in dialogue, temperament, and consequence, and with **Baldur’s Gate–style real-time-with-pause combat**: authored, common once the city is open, and never a loot grind.

The player inhabits **Harlan Voss**, a weary hired finder in his early thirties: capable, broke, observant, and carrying the accumulated damage of cases that did not end cleanly. The city is not a puzzle box waiting for the correct answer. It is a wet, **structurally corrupt** place where evidence can be true but incomplete, people can lie for defensible reasons, institutions protect themselves first, and the player's chosen interpretation matters.

### Elevator pitch

In rain-strangled Harborpoint, hired finder Harlan Voss studies scenes, questions people, connects imperfect evidence, fights the rooms the city has staffed against those questions, and makes deductions that change both the case and the man he becomes—until a Poirot-like summation forces every lie into the open.

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

This section is the **narrative canon** for Harborpoint, the two established leads, and the spine of the campaign. The leads’ retired working names (footnoted under each sheet) were fully migrated to the canon names with the V6 BGEE-style character redesign: sprites, atlases, portraits, UI text, and code identifiers now all use the names below. Design, dialogue, and new writing use only these names.

### 4.1 World — Harborpoint under the rain

#### The city in one breath

**Harborpoint** is a rain-locked **fantasy-noir** port that runs on ledgers, silence, and small magics nobody bothers to call magic. Hardboiled attitude; light fantasy texture—not high fantasy speech and not a mid-century Earth lock. Coin moves. Ravens move. Bodies move when someone higher needs a problem to look like weather. Rain, charcoal coats, and wet wool sit beside **wards**, hush-charms, sill-wards, and message birds as ordinary city infrastructure—the same way a desk lamp is ordinary. There are no wired telephones or broadcast-radio civilisation locks in Empty Coat canon; when someone needs word across town, a bird or a runner does the work. The player never sees the whole map—only wet fragments that imply more city beyond the frame: pipes knock in walls, carts rattle unseen, signs hum, neighbours argue through plaster.

#### How fantasy works here

- **Wards / hush-charms / sill-wards** — household and office utilities. Cheap ones fail in rain. Expensive ones lie on purpose. The hush-ward on her rooms that “hadn’t tripped” is evidence, not flavour text.
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
| **The City Watch of Harborpoint** (the Watch) | Law and investigation (the Watch-house, night books, night sergeants, watchmen, the river watch) | Political pressure, selective blindness, soft files; a few honest officers trapped inside a machine that punishes curiosity |
| **Dock Authority & unions** | Labor and trade | Smuggling corridors, “lost” cargo, overtime as hush money |
| **Press & broadsheets** | Public truth | Ownership strings; editors who know which names never print; one or two diggers who still risk ink |
| **Old money & new industry** | Philanthropy, jobs | Private armies in better coats; charity balls that launder reputation; factories that own whole blocks of votes |
| **Street networks** | Crime as chaos | Predictable tribute systems that feed upward into “respectable” ledgers |

The player feels this through locked doors, altered reports, witnesses who suddenly change their minds, evidence that is **true but incomplete** because someone above the case needed it that way, and rooms staffed by the people each layer pays to keep a page unread. Not every authority figure is rotten, and not every victim is pure—but **institutions default to self-preservation**. Voss survives by reading which layer he has just kicked.

#### Districts (playable texture, not open-world tourism)

**Shipped 3×3 world map** (`CityWorldMap` on main) is the travel truth. Column 0 = west, column 2 = east. Row 0 = south, row 2 = north:

| | West | Centre | East |
|---|---|---|---|
| **North** | *(locked)* | **Civic Records** | *(locked)* |
| **Middle** | **Wharf Ladder** | **Sable Row** | **Lila’s Street** |
| **South** | **Riverside** | **Lamp Ward** | *(locked)* |

Playable districts (player-facing names). Code ids in parentheses only where they differ:

- **Sable Row** (`sableRow`) — centre of the middle row; Voss’s block and the office. Harbor Street (the office’s street) runs through it. Tenements, small shops, pipes that argue. Wet wool and other people’s dinners; unpaid notices on the door. Orthogonally adjacent to Wharf Ladder (west), Lila’s Street (east), Civic Records (north) and Lamp Ward (south).
- **Wharf Ladder** (`wharfLadder`) — west of Sable Row; the docks. Cargo, lodging-houses, warehouses, river mouth where coats arrive arranged. Seals that bite, night crews, shipping-office clocks that run three minutes fast when someone wants an alibi the wards will swear to. Interior: the shipping office. Borders Riverside (south).
- **Lila’s Street** (`lilaStreet`) — east of Sable Row; **its own ward**, not a vague “Centre”. Lila’s rooms sit here. Prose may note it sits on the Printers’ Quarter fringe (Printers’ Quarter itself is not on the grid yet). Interior: Lila’s rooms. Gossip as second currency.
- **Riverside** (`riverside`) — southwest. Iron stairs and river stones, where coats are recovered. Borders Wharf Ladder (north) and Lamp Ward (east). Interior: iron stairs / riverside rooms.
- **Lamp Ward** (`harborpointPD`) — south of Sable Row; holds the Watch-house. Player-facing names are **Lamp Ward** and **the Watch-house**; the code id is not renamed in this sync. Shipped map and door labels still predate the Watch rename (§15). Interior: the Watch-house. Borders Riverside (west); locked SE to the east.
- **Civic Records** (`civicRecords`) — north of Sable Row; the records annex. Marble that stays clean in the rain on purpose. Interior: the records annex. Locked NW and NE on either side. Together with Lamp Ward, this is the current-play footprint of what design still calls the Civic Spine.

Locked corner wards (NW, NE, SE) are rain-obscured and never travelable; they reveal visually only when adjacent to a visited district.

**Later-act / design names** (not on the grid until art exists; keep for story writing):

- **Market Cross** — the old market square where the harbour road, the civic spine and the dock lanes meet in the story: stalls under oilcloth, a dry fountain nobody fixes, a posting pillar thick with notices. Working name; easy to change. **Not a cell on the shipped 3×3**, and travel does not hub through it.
- **Printers’ Quarter** — broadsheets, print shops, and houses that keep a lamp on. Lila’s Street sits on its fringe in prose. Not on the grid yet.
- **Civic Spine** — design umbrella for magistrate’s hall, the Watch-house and the records annex. In current play those functions live in **Civic Records** (annex) and **Lamp Ward** (Watch-house); the umbrella name stays for later-act writing.
- **Ashfield Yards** — industry, company housing, blacked-out windows. Muscle and smog; later case seeds live here (not M01 dumps). Not on the grid yet.

**Travel (shipped).** Travel is only to an orthogonally neighbouring playable ward. There is no `CityWorldMap.roads` and no non-grid link: the old quay-road shortcut is retired until a road system returns. From Sable Row the player can travel west to Wharf Ladder, east to Lila’s Street, north to Civic Records and south to Lamp Ward. Riverside borders Wharf Ladder and Lamp Ward. Reveal / travelability follows BG Classic rules: a district is travelable if visited, or orthogonally adjacent to a visited one.

**Plate size.** Every shipped district is one 5120×3840 world-unit plate (19,660,800 sq units; 80×60 tiles of 64, 320×320 search/light/height cells). The walkable plate stays at the shared size until wider art ships: a doubled plate and page set, 640×320 `.sr`/`.lm`/`.ht` rasters, an extended street plan and obstacle set, and per-district world size in code (see `AssetManifest.md`). The old “Market Cross twice the area of Sable Row” stamp is retired until Market Cross exists as art.

Immersion comes from **authored density**: specific smells, recurring NPCs who remember what Voss said last visit, broadsheets that react to case commitments, and weather that changes investigation readability (not merely a particle effect).

#### Institutions Voss actually touches

- **The river watch** — drownings, recovered coats, tide speeches offered with tea and a soft file.
- **Night books** — who was where when the clock lied; duty rosters that read cleaner than the street.
- **Reading-rights** — files the Watch smiles about and does not share; manifests Lillian should not have finished reading.
- **One night sergeant** who still answers ravens — useful, compromised, not a mentor arc in Act I. He helps once in the case, and his price is a name (§4.2 seeds; side case 10). There is no favour economy.

#### Everyday economy

Good coin vs dock-ledger chalk. Two hundred now is real weight (Lila’s retainer). Unpaid notices are civic and personal. Charter work—hired finder, not Watch badge—sits in the gap between Watch indifference and private revenge. Rent listens; whatever listens for rent in Voss’s building is not purely figurative.

#### Tone rules for world writing

Specific over mythic. Name a bakery doorway before you name a god. Let fantasy show in failed wards, humming keys, and seals that bite. Never explain the cosmology in M01—only how it inconveniences a finder and a sister. Fantasy-noir voice: hardboiled attitude + light fantasy texture; not purple high fantasy and not Earth-analogue phone/radio lock.

#### Seeds (later cases — not M01 dumps)

Mark clearly as **later**. Do not surface in M01 journal or Empty Coat intro as earned facts:

- Dock Authority “lost” crates that share seal-marks with Lillian’s last night.
- A municipal ward-license racket that sells “thresholds that hold” to lodging-houses that don’t.
### 4.2 Characters — the two established leads

RainShadow’s first cast is deliberately small and sharp. Supporting players (watchmen, dock hands, reporters, siblings, fixers) appear as needed; only two identities are locked as **series leads** for the outline.

#### Harlan Voss — player protagonist

Full canon sheet. Fantasy-noir; specific over mythic. M01 dialogue may paraphrase; it must not invent facts this sheet has not established for that beat. Wound-hint monos and desk stings in `strings.en.json` are the M01 voice for the core wound; mono 3 still carries the retired wound and is due a rewrite (below).

##### Who he is now

- **Role:** Independent **hired finder**—charter and coin, not a Watch badge. The player’s body, voice, and moral weather. Clients find him when the Watch-house has already filed something soft and called it finished.
- **Age / look:** Male, early thirties. Stern angular face with tired pale blue-gray eyes, swept-back auburn-brown hair and pronounced long auburn sideburns; bare-headed. Dark chocolate-brown double-breasted belted mid-calf trench coat with lapels, epaulettes, cuff straps, rear storm flap and vent; cream open-collar shirt, loose black tie, charcoal cuffed trousers and brown lace-up shoes. Economical movements, guarded posture, capable hands.
- **Station:** The Watch still knows his name; it does not miss him. Office on **Sable Row**—hearth ticks, unpaid notices, empty raven perch, case papers he still lies about. Rent—and whatever listens for rent in the building—keeps him seated.

Seated idle for M01 communicates fatigue without inertia: breathing, a small shift, rubbing a thumb along a mug, checking the rain, suppressing a cough.

##### How he works

He reads rooms before people. He lets silence do half the interrogation. He takes cases he half-believes are already dead, because rent does not care about his standards. He writes clean notes and keeps dirty doubts. He will lie to a night sergeant if the truth would bury a living person under a tidy coat. He will fight when a room is kept against the question, and he still treats the first blow as a sign that the quieter door was missed, or that this door was never going to open.

##### The Watch years (backstory spine)

The river watch for six years, then night books at the Wharf Ladder watch-house. Good at drownings that were not drownings, and at watching soft files get written over them. He left the Watch for a charter and his own door; why he left stays his own business in Act I. The Watch years are texture, not the wound. The wound came later, as a finder, on **Pell Street** (below). That case is the wound Empty Coat rhymes with—Lila walks in wearing the shape of his old mistake.

##### Core wound

**Pell Street** (locked). Voss closed a missing-person / intimidation chain that was correct on paper and wrong in human terms: he handed the Watch a clean file; two streets over, someone he had cleared was still afraid of a man he had not bothered to frighten enough. The boarder (or kitchen that paid for his certainty) is not a talkative companion beat and is not named in player-facing M01 beyond the monologue’s kitchen image. Harborpoint still files him as useful and disposable. He treats “probable,” “closed,” and soft institutional endings as personal weather. The unpaid notices on his desk are not only about money—they are about work he will not touch because it smells like that file.

Pell Street is his only core wound. It may surface in strain captions, one office inspect aside, or later Act I pressure—never as a second tutorial quest—and it gets no case dossier until a later milestone opens it. Voice stays dry fragments; the wound shows as avoidance of tidy closings, not confession speeches to Lila.

Locked monologue target (the wound’s only M01 spend): “I told myself I was done with missing persons after Pell Street. I had handed them a clean chain and a closed file. Correct on paper. Wrong in a kitchen two streets over, where somebody I’d cleared was still afraid of a man I hadn’t bothered to frighten enough.”

Shipped wound hints (do not drift these quotes without updating the string table):

- Mono 3: “Same as yesterday — and the night I trusted a tide chart more than a sister.” **Disagrees with the Pell Street lock** (it belongs to the retired wound). Due a rewrite and a VO re-record in the next string pass; until then this quote documents shipped copy, not canon.
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

- **The Watch:** Useful contacts, no loyalty. One tired night sergeant still answers his ravens. Most of the Watch-house treats him as a man who quit when it got hard.
- **Lila March:** Not romance in M01—**recognition**. She is the sister who did not accept the coat. That frightens him more than the gray overcoat does. Attraction, trust, or rupture remain **player-shaped** beyond M01.
- **The city:** He loves Harborpoint the way you love a building that is trying to kill you slowly: you know every stair that creaks.

##### What he wants (stacked)

1. Coin enough to keep the sill-ward fed and the notices quiet.
2. A case he can finish without filing a comfortable lie.
3. *(Buried)* Proof he is not still the man who chose the ledger over the sister.

##### What he must not become

Omniscient. Soft-boiled. A chosen one. A Watch reform arc in Act I. He is good; he is not clean.

##### Seeds for later (not M01 dumps)

- His old river-watch logbook is missing three nights.
- The night sergeant who answers ravens wants a favor that will cost a name (side case 10, §4.3.8).
- Something in his office hush-ward was set by a person who is not him.

- **Superseded working name:** Elias Vale (retired; the V6 redesign renamed all art, portraits, and code identifiers to Voss).

#### Lila March — the dame / first client

Full canon sheet. Fantasy-noir; specific over mythic. M01 dialogue may paraphrase; it must not invent facts this sheet has not established for that beat.

##### Who she is

- **Role:** Client who forces the first case into Voss’s office; romantic-noir **dame** archetype played straight and human, not as a costume.
- **Age / look:** Early twenties. Chic chin-grazing textured blunt bob (soft side part, airy lived-in finish) and a fitted deep-emerald day dress—nipped waist, modest scoop neckline, knee-length soft flare, dark pumps, compact handbag. Figure-flattering period daywear without crossing under-15 suitability. Composed enough that the cracks show only if Voss presses.
- **Station:** Not the Watch, not Dock Authority, not money. Boarding house on a side street off **Market Cross**, at the Printers’ Quarter edge. By day she keeps the books for a small Printers’ Quarter **bindery** (working); she reads other people’s ledgers when she has to. She hired Voss because the Watch offered tea and tides—and she has run out of polite rooms.
- **Orbit:** Friends with real locks and thresholds that hold; gossip as second currency; bindery books as honest work that also teaches her how manifests hide.

##### Bond with Lillian

**Lillian March** is older by three years—the steady one. Ledgers, manifests, seals at Wharf Ladder. Lila is the one who argues. They share a mother who left early and a habit of sewing their own hems because coin spent on a tailor is coin that should have been food. Lila does not romanticize Lillian. She is furious at her for being the kind of person who would chase an unfinished book into danger—and terrified that fury is the last true thing she still has.

##### What she knows (and what she holds back)

She knows the coat was **arranged**. She knows the key **hummed**. She knows Lillian was reading manifests that made someone nervous. In M01 she admits the manifests only under **pressure**—not coy for sport, but because names without proof get people followed, and she is already being followed. The **gray overcoat** is not a rumor invented for leverage: she has timed him (eleven to one, bakery doorway). She is exhausted and still precise.

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
| **Dry** | Becomes a clerk of her own grief—times, places, the coat in its paper wrap |
| **Sharp** | Goes cold and useful; the gated manifests line is her refusing to be handled |

##### What she wants (stacked)

1. Lillian alive—or a truth that is not a coat.
2. The gray overcoat off her stairs.
3. *(Buried)* Not to become the sister who accepted the ledger’s answer, the way someone once did to another family.

##### What she must not become

The dame as prize. A quest-giver with no interior. A liar for twist’s sake. If she withholds, it costs her—**fear, not cleverness**. She is not a trophy or a pure victim, and not automatically a traitor—**the player must earn which**.

##### Relationship to Voss

Professional first. Attraction, trust, or rupture are **player-shaped**, not a mandatory romance track. Wit is their shared language; silence is their shared weapon. Competence that is not charm: she sews; she can read a shipping roster; she found the key the Watch never felt for. Loyalty that can hurt him: she will protect Lillian’s dock work before she protects his case. Bad at his game, once: a pause, a too-fast money answer, or a fee she names awkwardly—when she lies, the lie is small and checkable, so the dock truth is never “the dame was the twist.”

##### When it turns violent

Lila is the **first temporary ally** (§4.3.5): E3a if Voss holds her stair, otherwise the Act I break (E5). She is not a blade, and she **can be injured with lasting consequences**: Steady / Hurt / Badly hurt carry into trust, dialogue, and which later scenes she can join (§4.3.5, “Ally injury”). She is not killed by default. Her injuries show in posture and in shorter lines, never in a speech about them.

##### Seeds for later (not M01 dumps)

- The bindery owner (working) saw the gray overcoat two days before Lila did.
- Lila has a partial copy of one manifest line she will not show until she trusts Voss not to sell it.
- She and Lillian fought the night before the vanishing—about whether to burn a page.
- Printers’ Quarter friend with “real locks” owes her a favor she hates using.

- **Superseded working name:** Vivian Hart (retired; the V6 redesign renamed the arrival/departure atlas, dialogue portrait, and narrative copy to March).

#### Supporting cast (named only as needed by the outline)

Do not expand into full sheets here. Story beats may introduce: a tired night sergeant who still answers Voss’s ravens; a dock clerk who sells silence by the hour; a society fixer who never gets rain on their shoes; the missing sister as presence-through-absence until the endgame allows her truth—alive, dead, or worse—to land.

### 4.3 Story outline

#### Premise

Harborpoint sells the public a city that works. **Harlan Voss** rents an office that barely does. When **Lila March** walks out of the rain with a key and a coat that no longer has a body in it, the apparent missing-person case becomes a vertical cut through the city’s corrupt layers—from Sable Row up to ledgers that were never meant to be read aloud.

#### Design commitments woven into the plot

| Commitment | How the story delivers it |
|---|---|
| **Wit** | Voss’s internal captions and dialogue stay dry, specific, and human. Lila matches him beat for beat. Humor comes from weary precision and character, never spoof-noir or constant purple prose. |
| **Noir tropes** | Dame in the doorway; rain as accomplice; empty coat / missing person; double books and double lives; the honest watchman in a bad system; the “helpful” official; the river that keeps secrets; a private eye too broke to refuse the case and too stubborn to stop. Tropes are **played**, not winking pastiches. |
| **Corruption** | Each act peels a higher institutional layer. Evidence is altered by people with badges, letterheads, and good manners—not only by street thugs. |
| **Combat (BG-like)** | Kept floors, pressures, and set pieces use **real-time-with-pause**, tactical positioning, and a small temporary party, in the Infinity Engine spirit. Fights are frequent because the case walks through staffed rooms. Every group is authored. None of it is a loot grind. A **story-mode auto-resolve** setting lets any fight resolve without being played; its consequences still land. See §4.3.5. |
| **Immersion** | Continuous rain beds, reactive districts, NPCs who remember, case journal that feels like Voss’s mind on paper, and environmental storytelling before exposition. |
| **Poirot-like conclusion** | Endgame is a **summation scene**: key suspects and stakeholders gathered (office, private club, Watch-house, or warehouse made formal by force of will). Voss lays out the **full chain of deduction**—what was seen, what was lied, what the empty coat meant—before the final moral choice of who pays. |

#### 4.3.1 Act structure (campaign spine)

**Act I — The Empty Coat (M01 and first case)**  
Lila arrives. Voss takes the case. The office, the key, and the river coat establish method: observe, inspect, interview, commit. Early noir beats land hard—the dame, the rain, the first polite door that will not open. The player learns that Harborpoint’s smallest mysteries already have municipal fingerprints. From Wharf Ladder on, the rooms that hold those fingerprints are staffed, and crossing them is the combat of Act I (§4.3.5). M01 itself, the office, ships no fights.

**Act II — Follow the key**  
Act II opens without the lock. Voss knows the key’s true shape (a seal-locker or ward-safe, uptown), not which lock it fits or what that lock holds; that stays open (§15). The crate mark Act I put in his hands—on the pay tally, the chalk chit, and the hook’s brand—names the next door: the numbered shed on Wharf Ladder, where Dock Authority crates marked lost sit beside a union tally and storage slips that lead to names in both a Watch night book and a charity donor roll. The shed is staffed to keep the slips. The Watch-house service stair is staffed to move the margins the public file will never show. The Osric Rest, a charity for the river-dead with a house on Wardour Street, is staffed to keep the roll. Between those floors the Rest sends coats for the pages. Witnesses contradict each other on purpose. Voss’s strain rises because a night spent healing is a night the Rest uses. The encounter plan is §4.3.5.

**Act III — The city answers back**  
Commitments on the deduction board close routes. Lila’s partial truths come due. The signature on the roll has a house, a budget, and a preferred ending in which the coat stays a drowning. The patron can buy Voss off, bury him in a soft file, or send men to remove him. Ashfield Yards holds the same crate mark on a company store. A ward-license stall sells the thresholds that keep **Hearth Court** shut. Hearth Court is an upper-city lodging-house where Lillian’s handwriting is being kept: she is alive, and she is refusing to sign the next lost crate into a donation. Delay, a public body, or a dawn spent on a wound can empty that house before Voss arrives. The pages still prove the scheme if the chair is empty. Her life is the stake of how fast, and how quietly, he crossed the earlier floors.

**Act IV — Summation (Poirot close)**  
Voss engineers (or is forced into) a gathering of the remaining principals. Getting them into one room is a staffed door if the Watch-house will not compel them. In a controlled space, he reconstructs the timeline: the sister’s last movements, who emptied the coat, which institution needed the silence, and which personal betrayal made the machine efficient. The player’s prior hypotheses and failed-forward choices color **how complete and how merciful** the reveal is—but the design center is always the **dramatic laying-out of the chain**, not a sudden unearned twist from nowhere. The room becomes a fight only when a hole in that chain still gives someone a reason to reach for a blade. After the truth is spoken, a final irreversible commitment: accuse, expose, bargain, or walk away—and live with Harborpoint’s echo. If the Gray Man was never brought in, he is on the iron stairs once more, and walking past him is allowed.

#### 4.3.2 First case — “The Empty Coat” (case dossier)

This section is the **authoritative case structure** for Act I and the M01 case journal. Runtime journal copy (`EmptyCoatJournalContent`) must stay consistent with it. Dialogue may paraphrase; it must not invent facts the dossier has not established for that beat.

**Terminology lock:** the follower wears a **gray overcoat**. Lillian’s garment and the case title stay **coat** / **THE EMPTY COAT**. The police are **the Watch** (the City Watch of Harborpoint: the Watch-house, night sergeants, watchmen, the river watch).

##### Logline

In rain-strangled Harborpoint, hired finder Harlan Voss takes a sister’s coin after the Watch called a humming key and an empty coat an ending—and discovers the missing ledger-keeper was reading seals someone needed unread.

##### Theme

Comfortable lies vs unfinished books. Coats are alibis. Sisters refuse them. Voss has been both men.

##### Dramatic question (Act I)

Can Voss find Lillian—or the truth that isn’t a drowning—before the gray overcoat finishes the ritual the key was meant for?

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

Voss alone. Wound hints (Pell Street; shipped mono 3 still says tide chart / sister and is due a rewrite, §4.2). Threshold pause. Lila enters. Branching retain. Key on desk leather. Case opened: **THE EMPTY COAT**.

**Emotional payload:** Recognition, not romance. He sees his old mistake walking in with good coin.

###### 2. First loop — Office as tool *(shipped M01)*

Inspect hotspots. Desk monologue. Journal: retained; optional pressed-hard on manifests. Player learns the room is a character: raven perch, case papers, sill-ward, unpaid notices.

###### 3. Lead one — Wharf Ladder shipping office *(Act I beyond M01)*

Lillian’s desk, night clock that runs fast, clerk who sold silence by the hour. Evidence: seal-mark scrap; “one more errand in the upper city”; someone scrubbed reading-rights on her last manifest pull. **The night lane, then the back room.** Three tally groups keep the fast clock and the lost-crate lane (floor **A1** in §4.3.5). The clock-room group is the core and will fight the first night. Behind them, Merrick sold his silence twice, and the Gray Man’s hired men come for the folio Voss is reading. That second fight is **E1**, and it can be left unfought.

**Scene card — Wharf Ladder shipping office** *(design runway; not M01)*

**Case:** The Empty Coat · Beat 3 (Act I runway beyond M01 office slice)  
**Location:** Shipping office near the river mouth; ledgers, seals, a clock that runs three minutes fast when the night crew wants an alibi the wards will swear to.  
**Scope:** Design only. Does not inflate M01 implementation. Follower = **gray overcoat**. Case garment / title = **coat** / **THE EMPTY COAT**.

**Purpose:** Give the player Lillian as a worker, not only a missing sister. Plant seal-magic and scrubbed reading-rights. Introduce a human obstacle who sells silence by the hour. Introduce the Gray Man’s **hired muscle**, so the threat has hands before it has a face.

**Entry:** Voss arrives with Lila’s two hundred still warm and the key’s hum in memory. Optional: Lila waits outside (threshold that holds) or stays in her rooms off Market Cross—player choice from prior beat.

**Cast on stage:**

| Role | Who | Notes |
|---|---|---|
| PC | Harlan Voss | Dry first; Watch past helps or hurts depending on tone |
| Obstacle | Dock clerk (working name: Merrick) | Sells silence; knows Lillian’s last night; afraid of seals |
| Absent pressure | The Gray Man (gray overcoat) | Seen across the quay once—does not enter yet, does not speak |
| Threat | Hired muscle (working names: **Ketch**, a big cargo-hook man; **Bram**, young, a knife he holds wrong) | Paid by the job in dock-ledger chalk to fetch Lillian’s last folio and frighten Merrick. They are not told why |
| Optional | Watch-house night runner | Mentions soft file / tide speech if Voss flashes old river-watch habits |

**Objectives:**

1. Confirm last sighting: left at nine, “one more errand in the upper city,” no hired coach on the desk slate.
2. Find seal-mark scrap or bitten-glove smear on her desk-leather edge.
3. Learn reading-rights on her last manifest pull were scrubbed after she vanished.
4. Exit with a lead toward Civic Spine records or Dock Authority lost-crate numbers.

**Obstacles:** Clerk won’t talk without coin, a favor, or a threat that costs Voss something (Warm / Dry / Sharp gates). Seals that bite: inspecting the wrong folio without reading-rights = pain / alarm / clerk panic. Night clock lies; timeline must be reconstructed, not trusted.

**The fight (E1 — back room, avoidable):** Merrick already took the Gray Man’s coin to ring the tin bell over the back door if anyone came asking about Lillian’s folios. What happens depends on how Voss handled him:

- **Warm / paid more than the Gray Man did:** Merrick whispers “they come at the bell” and lets Voss out the back with the scrap. No fight. Voss can hide in the seal-room and **overhear** Ketch and Bram being told to “burn the March folio, the gray gent pays at the Tallow Stair.” Best lead, no blood.
- **Dry:** Merrick stalls. Ketch and Bram walk in while Voss is still at Lillian’s desk. One line to talk them off (“The Watch knows I’m here”; works only if Voss really told someone—side case 03 can make it true) or the fight starts.
- **Sharp / threatened:** Merrick panics and rings the bell. The fight starts with Voss cornered in the seal-room.

The room is the weapon: shelves of seals that bite (shove a man into them and he is stunned and burned), one oil lamp to kick over (dark, fire risk to the evidence), a narrow back door that makes it one-at-a-time. Ketch hits hard and slow; Bram breaks and runs if Ketch goes down.

**What the fight reveals:** Knock Bram down and he drops a chalk pay tally with a crate mark on it: the first physical link between the Gray Man’s money and Dock Authority “lost” crates. **What it costs:** the noise brings Dock Authority night-men; by morning the Watch has Voss’s name for brawling at Wharf Ladder (**Watch attention +1**). Merrick will not speak to Voss again unless side case 04 wins him back. Any wound carries into Beat 4. **If Voss loses:** he wakes on the quay boards, bruised and short the seal scrap (taken or burned). The Civic Spine lead survives only through the overheard line or the river stones.

**Evidence / journal payoffs (Act I flags — not M01):** `lillian.lastShift.wharfLadder`; `evidence.sealMark.scrap`; `knowledge.readingRights.scrubbed`; optional `sighting.grayMan.quay`; `knowledge.muscle.tallowStair` (overheard) or `evidence.payTally.crateMark` (fight won); `combat.e1.outcome` (avoided / won / lost).

**Dialogue spine (not full script):**

- Clerk: “She never missed the morning ferry. That night she did everything twice — checked the seal, checked it again.”
- Voss (dry): “Show me the second check.”
- Clerk (if pressed): “Someone from Civic came for the reading-rights after. Polite. The folios still hurt if you touch the wrong line.”
- If sharp: clerk names a crate mark then clams up; the gray overcoat across the quay shifts. Merrick’s hand goes to the bell cord.
- Ketch (walking in): “Evening. We’re here for paper, not for you. Step off the desk.”

**Failure / soft fail:** Leave with only the ferry/nine facts (already known) and a frightened clerk. No seal scrap—Act I still playable via river stones, but Civic Spine lead is weaker.

**Success:** Seal scrap + scrubbed rights + upper-city errand sharpened. Player owns a deduction: Lillian wasn’t drowning bait; she was reading something someone needed unread.

**Tone locks:** E1 can be left unfought. The clock room on the way in cannot, the first night. Each fight is short, ugly, and in one room. Magic = bitten seals and scrubbed rights, not fireballs. The Gray Man is silhouette, not boss fight—he watches from the quay, never enters, and does not speak. Voss does not confess the Pell Street wound here.

**Art / audio notes:** Oil lamps, wet wool, brass seal-presses, raven cage in the corner (empty). Clock tick slightly off. Distant ferry horn. Rain on tin roof harder than on Sable Row glass.

**Exit:** To river stones / iron stairs (Beat 4) or straight to pressure if the player saw the Gray Man on the quay.

###### 4. Lead two — River stones / iron stairs *(Act I beyond M01)*

Where the coat was found, arranged. The river watch repeats the tide speech. Soft file smells of political pressure, not incompetence alone.

**The danger in uniform is the Watch.** Raising a hand to a watchman is the worst move in Act I: it turns Voss into the easiest answer the Watch-house has (arrest; case taken; soft fail back to the office with the property log closed). The scene teaches restraint. The men who placed the coat are not watchmen. If Voss asks about the coat in the open on the stones, two scroungers who were paid to arrange it try to take the questions off him (**A2**). Asking only the watchman leaves that pair unfought, and their testimony waits for a later page.

**Encounter E2 — the iron stairs (conditional, avoidable):** If E1 was loud, *or* Voss told the river watch he would come back after dark, Ketch waits on the old iron stairs at night: slick steps, one lamp, the river underneath. Only the river watch knew when Voss would come, so the ambush itself proves someone at the river post talks to the Gray Man.

- **Talk:** Ketch is paid to frighten, not to kill. Voss can Trade: hand him a false place where the key is kept. He takes it and leaves, and the lie becomes the bait option in Beat 5.
- **Avoid:** come by day with a watchman on the stones, or spot Ketch from the top of the stairs (Observe) and walk away.
- **Fight:** the stairs are a choke point. Rain makes footing a gamble for both men, and the fall into the river is real for either. Win and Ketch’s cargo hook carries a Dock Authority tally brand: the muscle is dock labour. **Cost:** the river watch arrives at the noise; “private finder brawling at a recovery site” goes in the night book (**Watch attention +1**). At attention 2 the Watch-house refuses the property log unless Voss still has the night sergeant’s one ask to spend. A man in the river is a body the Watch will hang on Voss.

###### 5. Pressure — The gray overcoat *(Act I beyond M01)*

Not a jump scare: professional habits. Streetlamps dim. He wants the key, not Lila’s life—yet. Choice: protect Lila’s threshold / bait with a false key rumor / ask the night sergeant who still answers ravens (costs a favor: his one ask in the case, and his price is a name—§4.2 seeds, side case 10). The Gray Man does not speak in this beat.

This is where the Gray Man stops paying people to watch and pays them to take. He sends Ketch, Bram (if they are still on his books) and one new hire to Lila’s rooms off Market Cross, the night after Voss’s first visit to the river. He stays in the square himself; the lamps around him dim. Reaching her street after dark means the bakery-doorway post she timed (**A3**), unless Voss takes the long way through Printers’ Quarter and gives the Gray Man that hour. Each choice at the rooms leads to a different fight or none:

- **Protect the threshold (E3a — the stair siege):** the Act I set piece. Lila’s ward holds only while the door stays shut from inside, so the fight happens on the narrow stair and landing. Lila joins as the first temporary ally, not a fighter: she can bar the second door, throw the lamp, or wake the house, and she can be hurt (Steady / Hurt / Badly hurt, §4.3.5). A threshold re-seated in side case 02 holds for the whole fight. **Reveals:** a downed hireling can be questioned: “the gray gent pays in Civic scrip.” **Costs:** injury; the rooms are known and wrecked, so Lila has to move (Voss’s office or a Printers’ Quarter friend), and the neighbours saw a finder bleeding on the stair (**Watch attention +1**). Lila’s injury state carries forward.
- **Bait with a false key rumour (E3b — Voss picks the ground):** needs the lie planted in E2 or a word dropped with Merrick. The hirelings go to an empty rented locker at the edge of Market Cross. Voss can simply watch: no fight, but he sees the Gray Man’s face by lamplight for the first time (`sighting.grayMan.face`). Or he springs it with the advantage (dark, first blow, one exit).
- **Call in the night sergeant (no fight):** watchmen walk Lila’s street all night and nobody comes. **Costs:** the sergeant’s one ask (his price, a name, comes due in side case 10), and the Watch-house now knows there is a key. In Beat 6 a watchman asks, politely, to add it to the property log.
- **Mercy pays later:** if Bram was spared or paid in E1/E3, he can be turned here. He warns Lila and walks off the job, and becomes a witness for the summation.
- **The office stair (A4):** once someone has seen Voss keep the key and carry the case back to Sable Row, two chalk-paid men try his own stair. The sill-ward holds the door. The fight is the stair. Sleeping at the Printers’ Quarter friend’s, or anywhere but Sable Row, means they find an empty landing. A raven that comes to the office that night finds him gone.

###### 6. Mid-Act turn — The page they almost burned *(Act I beyond M01)*

Lila admits the fight: Lillian wanted to burn a manifest line; Lila wanted a copy. Partial line surfaces (trust gate). Names point toward Dock Authority “lost” crates and a Civic Spine reading-rights signature.

Lila has kept the copy on her since the night of that fight; it is not hidden in a shop, and nobody sets a fire for it. The Gray Man learns it exists (from the watchman’s visit if Voss used the sergeant’s ask, from a questioned hireling if one got away, or from Merrick). That raises the stakes of the Act I break: he comes for the key, and for the copy if she still holds it (E5).

Bringing the copy to Voss’s office after dark means the lane behind the Printers’ Quarter shops, where one group of night carriers is paid to lose a bundle (**A5**). Bram’s warning, if he was turned in Beat 5, includes them. Going to her by day for it means the lane is never walked.

###### 7. Act I break *(Act I beyond M01)*

Voss holds the key’s true shape (not inn, not desk—a seal-locker or ward-safe in the upper city). **Which lock, and what it holds, is not found in Act I.** Lillian is likely alive *or* made to look drowned for a reason that still needs her handwriting. The Watch will not help without a sacrifice. The gray overcoat stops pretending to only watch.

The true shape comes out of the records annex, shut to the public after the halls close. Two groups of civic porters keep it (**A6**). They are not the Watch. The outer porter lets a man through when Voss’s Watch reputation is still clean and Watch attention is still 0. The clerk who scrubbed Lillian’s reading-rights will not. He is the core. He keeps a second register, and the register is why the annex is a fight: it holds her pull and the line that replaced it, and its ward-stamp pages read the key’s teeth as upper-city issue, for a seal-locker or a ward-safe. They do not say which, or where.

**Encounter E5 — Lila’s threshold (the Gray Man himself):** the night after the annex, the Gray Man stops paying people to take and comes for the key himself, with whatever muscle is left. He comes to wherever Lila is sleeping: her rooms if E3a never happened, the Printers’ Quarter friend’s real lock, or Voss’s office. He is better at this than Voss: trained, patient, and his charm dims every lamp in the room. This is a **hold-and-escape** fight, not a duel. Voss wins by keeping the key and getting Lila through the night, not by putting the Gray Man down. Talk can shorten the room. Talk cannot cancel it.

- **Talk first:** naming the Civic Spine signature from Beat 6 makes him hesitate: Voss knows too much to be quietly erased, and a dead finder is a louder story than a drowned clerk. That buys one exchange. Use it to bargain (give up the copy, keep the key) or to get Lila to the back stair.
- **Bluff:** if the false-key rumour was planted, Voss can offer him a fake key. He half-believes it.
- **Fight:** outcomes are graded. Keep the key with Lila Steady or Hurt; keep the key with Lila Badly hurt; or lose the room and retreat down the back stair with the key, while the copy is taken if she still held it. By default Voss ends Act I carrying an injury into Act II. **Reveals:** not who pays him, and not whether he carries a badge (that stays open, §15). If the threshold holds when he tests it, it bites his hand and one black glove catches in it (`evidence.grayMan.glove`); what the glove leads to is an Act II design choice. **Costs:** the Watch arrives after, and Voss’s Watch attention decides whether they take his statement or take him.
- **His one line.** The Gray Man is silent through Act I except for one line, here, when the room breaks: “It was never hers, Mr. Voss. It isn’t yours. I’m only the one who’s patient about it.” No name, no employer, no badge.

##### Character arcs (Act I only)

| Character | Starts | Ends Act I |
|---|---|---|
| **Voss** | Avoiding missing-person rhymes | Committed to a case he can’t file soft |
| **Lila** | Buying help with two hundred and fury | Partner in risk; still not a prize. First temporary ally; her injury state (Steady / Hurt / Badly hurt) carries into Act II |
| **Lillian** | Absence / coat | Presence through handwriting, seals, unfinished book |
| **The Gray Man** (gray overcoat) | Follower | Active claimant on the key; meets Voss face to face at Lila’s threshold (E5) and speaks his one line. Badge or private muscle still open |
| **Ketch / Bram (hired muscle)** | Hands paid by the job | Ketch: recurring threat until beaten or bought off. Bram: turnable witness if Voss shows mercy. Named edge of a larger book (§4.3.5) |

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
| Journal letterhead | **H. VOSS · FINDER OF THE LOST** |

##### Known facts at case open (M01 intro must establish)

Aligned to the shipped Empty Coat intro graph, except the timing: the graph and journal still say “two nights past” (string drift, §15). The dossier timing below wins.

1. Lillian vanished on **Tuesday** night after work at a shipping office near **Wharf Ladder** (ledgers, manifests, seals that bite if you read them wrong). Lila walks into Voss’s office on **Friday** night, a few nights later.
2. Last known: left work about nine; told a clerk she had one more errand in the upper city; no hired coach chalked on the desk slate.
3. By midnight that Tuesday, the river watch found her coat on the stones below the old iron stairs—empty, arranged; no body. Like an offering someone wanted found.
4. **The Watch** soft-files: a woman gone, no struggle, coat recovered, probable drowning; case cooling before the ink dried. Polite; no reading-rights on the file.
5. Coat pockets turned as if to show nothing left to steal; **brass key sewn into the lining**—found by Lila at home, after the Watch returned the coat to her in a paper wrap; faint lamp oil and river water on the metal.
6. Since the key: a **Gray Man** (gray overcoat, black gloves) follows Lila; professional habits (cart noise, doorway posts); he turns away when met with a direct look; streetlamps dim a fraction when he stands under them.
7. Voss accepts the case; the key stays in his care on the desk leather.

##### People

| ID | Name | Role | Status at M01 | Notes |
|---|---|---|---|---|
| `person.lila` | Lila March | Client | Interviewed | Precise under pressure; withholds deeper dock/sister secrets until pressed with evidence |
| `person.lillian` | Lillian March | Missing person | Whereabouts unknown | Shipping-office ledgers; hated the river; hated unfinished books; last seen Tuesday night |
| `person.gray-man` | The Gray Man | Unknown watcher | Unidentified | Gray overcoat, black gloves; not yet proven badge vs private muscle (open through Act I); silent in Act I except one line at E5; knows Lila came to Voss |
| *(Act I later)* | Night sergeant / river watch | Institutional | Not interviewed in M01 | Soft close: tea, tides, politeness with teeth |
| *(Act I later)* | Shipping-office clerk | Witness | Not interviewed in M01 | Last conversation with Lillian; “errand in the upper city” |
| *(Act I later)* | Ketch and Bram | The Gray Man’s hired muscle | Not met in M01 | Dock labour paid in chalk; recurring threat from Beat 3; Bram can be turned. The rest of the book — tally crews, civic porters, Rest coats — is §4.3.5 and does not appear in M01 |

##### Evidence

| ID | Item | Custody | Reliability | M01 journal? | Leads |
|---|---|---|---|---|---|
| `evidence.key` | Brass key from coat lining | Voss | Credible physical | Yes | What lock? Faint lamp oil and river fog |
| `evidence.coat` | Riverside coat | Lila (the Watch returned it in a paper wrap) / described by Lila | Uncertain / possibly staged | Yes | Recovery site; Watch-house property log |
| `evidence.watch-file` | Soft missing-person file | The Watch | Compromised / incomplete | No (later) | The night sergeant (side case 10); dual ledgers |
| `evidence.paid-notice` | The drowning notice was **paid copy** | Earned in side case 07 | Credible (the original slip) | No (Act II) | Who paid stays gated |
| `evidence.grayMan.glove` | One black glove caught in Lila’s threshold | Earned at E5 if the threshold holds | Credible physical | No (Act I break) | Open: what it leads to is an Act II choice |
| `evidence.blue-room` | Blue Room token: a stamped brass tavern token (Wardour Street) | Unearned in M01 | — | **No** | Act I seed only—do not show in M01 journal until the player earns it |

##### Objectives / leads (organized doubt, not quest checkboxes)

**M01 (office only — beats 1–2)**
- Keep the key safe; case file open in the journal.
- Record office field notes via hotspot inspections.
- Journal leads (destinations still locked): identify the lock; build Lillian’s timeline from Tuesday night; find or name the Gray Man; re-check the river stones when the city opens.

**Act I beyond M01 (beats 3–7 — design roadmap; non-spoiler)**
- Wharf Ladder shipping office / manifests Lillian was reading (seal-mark scrap; scrubbed reading-rights). Cross the night lane; the clock room keeps the alibi. Get out before Ketch and Bram arrive, or deal with them.
- River recovery site + watchman / river-watch soft file; find out who at the river post talks to the Gray Man. Asking about the coat in the open brings the men who placed it.
- Gray overcoat pressure (threshold / bait / the night sergeant’s one ask); keep Lila and the key out of his hands. The bakery post and, once the key has been seen home, the office stair are part of this beat.
- Mid-act trust gate: the page they almost burned; partial manifest line; get Lila’s copy to the office without losing it in the lane behind the shops.
- Records annex after hours: the scrubber’s second register and the key’s true shape. Then the Act I break: hold Lila’s threshold when the Gray Man comes for the key. The lock itself is not found in Act I.
- Civic Spine / Dock Authority “lost” crates signatures.
- Optional later seed: Blue Room on Wardour Street (brass house token or testimony)—only after earned.

##### Chronology (case log · approximate Voss notation)

Prefer **narrative order** (coat → key → follower → office). Times are detective notation, not a forensic clock. The case log uses weekday names: Lillian vanished on **Tuesday**; Lila walks into the office on **Friday** night, a few nights later. (The shipped intro and journal copy still say “two nights past”; that copy is due a rewrite, §15.)

| Approx. time | Event | Journal entry ID |
|---|---|---|
| Tue · ~9:00 PM | Lillian leaves Wharf Ladder shipping office | `log.leave-work` |
| Tue · night | Gap: “errand in the upper city” / unknown | folded into movements |
| Tue · ~midnight | Coat recovered riverside by the river watch (old iron stairs) | `log.coat` |
| After the Watch returns the coat | Lila finds the brass key in the lining, at home | `log.key` |
| From the key on | Lila followed by the Gray Man (gray overcoat) | `log.followed` |
| Fri · ~11:40 PM | Case opened at Voss’s office | `log.case-open` |
| Sat · ~12:10 AM (after retain) | Office field notes (if hotspots inspected) | `log.office` |

##### Open mysteries (writer hooks; not journal spoilers)

Kept open on purpose through Act I:

- What the humming key opens (seal-locker / ward-safe in the upper city—the shape is earned at the annex before the Act I break; which lock, where, and what it holds stay open past Act I).
- Who benefited if Lillian stopped reading manifests.
- Who emptied the coat, and why leave the key?
- Is Lillian alive, dead, or “worse” (held / erased from ledgers / made to look drowned for handwriting)?
- Which institutional layer benefits from a tidy drowning?
- Whether the Gray Man carries a badge or is private muscle (open through Act I).
- Who paid for the drowning notice (it was paid copy, side case 07; the payer stays gated).

##### Tone locks (Act I)

Fantasy is bureaucratic damp. No chosen-one prophecy. Combat is brutal and authored, and common once Voss leaves the office. A truth-seeking playthrough crosses a few dozen staffed rooms (§4.3.5), each caused by the coat, the key, or the ledger. Talk, coin, and mercy open outer doors. The inner door of a kept floor still has to be crossed. A public blow leaves a mark: a wound, a lost lead, a name in the night book, a dawn spent. Voss is a finder, not a hero. Deductions the player owns.

##### What M01 must teach

Observe → pressure dialogue → journal commitment → leave the office with a live case and a live wound.

##### Journal UX contract

- Voice: Voss’s dry, concrete notes; short paragraphs. No green-checkmark quest language.
- Status strings: Open, Interviewed, Unidentified, Not examined, Recorded—not “Complete.”
- Sections: **ACTIVE CASES** · **PEOPLE** · **EVIDENCE & LEADS** · **FIELD NOTES** (hotspot-gated) · Chronology tab **CASE LOG**. From the Act I runway (not M01): **OTHER BUSINESS** lists side cases (§4.3.8) with statuses Open, Settled, Dropped, Gone cold—never “Complete”.
- M01 journal surface is the case-facing UI; full deduction board remains later (§7.4).
- Field notes appear only after corresponding office hotspot IDs (`office.window`, `office.desk`, `office.phone`, `office.files`).

#### 4.3.3 Noir tropes (checklist for writers)

Use these as **load-bearing beats**, not window dressing:

- The client who hires honesty and practices omission.
- The coat / photograph / key as a mute witness.
- Rain that erases tracks and forces people indoors where they can be overheard.
- A tavern where everyone lies better after the second cup.
- The “routine inquiry” that is actually a warning.
- Files that exist twice—once for the public, once for the drawer that does not open.
- A romantic possibility that investigation may destroy.
- Violence as a way a ledger keeps a room: ugly, remembered, and priced in the next conversation.

#### 4.3.4 Wit and voice

- Internal narration: short, concrete, occasionally funny because it is accurate. The house voice is the §9.5 inspect captions: one image, no lecture. If an intro page is longer and prettier than those five captions, it has already failed.
- Dialogue intentions (Open / Press / Feign / Trade / Observe / Leave) are **author method**, not player-facing labels and not a second morality meter. The player reads the line. Baldur’s Gate replies are numbered prose.
- Lila and Voss can out-dry each other; supporting cast get one sharp line rather than constant quips.
- Avoid genre parody, cartoon hardboiled, and monologues that explain the theme.

#### 4.3.5 Combat — Baldur’s Gate spirit, RainShadow stakes

Combat is a **designed system** inside the case. The primary loop is still observation, pressure, and a deduction the player owns. The city answers a lot of those questions with a staffed room, and a staffed room is played in **real-time with pause**.

Baldur’s Gate puts hostile ground between its towns and then fills each plot dungeon with the faction that owns it. Harborpoint has no wilderness, so the same density sits in the floors this case opens. The old cap — five Act I encounters, every one avoidable or shortenable by talk — is retired. A group below is one cluster of two to four people, the size of a Baldur’s Gate encounter. The tables count those groups.

**Status: design target.** The codebase has **no combat system yet**. What exists is groundwork only: `GameSession.currentHealth` / `maximumHealth` (12/12, never changed during play), the portrait-bar health readout, inventory stat badges (defence, vitality, resolve, damage), equipment slots with a weapon slot and two-hand rule, and `ItemDefinition.damageBand` on the starter weapon (the one-handed service shortsword Voss kept from his Watch years, 2–7; its shipped item name and text predate the Watch rename, §15). There are no enemies, attacks, damage resolution, AI, hostility, combat mode or injury handling. Combat-time movement is deferred (`MovementSystemRoadmap.md`, Phase 6). M01 ships no fights. Until the system exists, each group below can resolve as a dialogue or cut-scene outcome using the same flags. The 12 health and the 2–7 sword are placeholders: when combat is built, a careful night has to be able to clear a core on one pool of health by using the choke, the lamp, the seal, and morale. This section is an encounter count, not a damage budget.

##### How a fight gets into the case

Three kinds. All authored. All employed by the empty coat.

- **Kept floors.** The page is in a place that has a night shift. Wharf Ladder’s clock, the numbered shed, the records annex, the Osric Rest, Hearth Court. Outer groups can be peeled by work done earlier. The core group is paid more than Voss has, or is more afraid of their employer than of him, and will fight. Crossing is played in combat mode even on a quiet attempt: sightlines and pause. Being seen starts the fight.
- **Pressures.** Someone comes because of what he now knows. He can pick the ground. He does not pick whether they come.
- **Set pieces.** One room, a human choice, a reveal, a cost. E1 through E5 stay this kind. They are the punctuation inside a much longer vocabulary.

**The book.** One machine hires three crews. Repetition is the crew’s identity.

- **Chalk crews** — Dock Authority labour and tally-men, paid in dock-ledger chalk. Ketch, Bram, and **Sedge** (working name), tally-captain of the numbered shed. Morale breaks when the named man drops.
- **Civic porters and scrubbers** — they keep annexes and reading-rights. They are not the badged Watch. Drawing on a badged watchman sets Watch attention straight to arrest.
- **Rest coats** — private watch of the **Osric Rest**, a charity for the river-dead with a house on Wardour Street, paid in Civic scrip. Morale breaks when the factor in that room falls.
- **Pye** (working name) sells ward-licenses off Market Cross: thresholds that hold, sold to houses that do not. Pye is for rent, once. Bought, Pye drops one threshold. Crossed, the stall joins the next floor.

**What earlier scenes can change.** A quiet path is earned inside an earlier scene. Merrick’s coin, the clock-room chalk, Bram alive and turned, Lila’s introduction, the night sergeant’s one ask. The ask can be spent once in the whole case, and its price is a name that comes due in side case 10. There is no favour economy beyond that one ask. An outer group peeled this way is a slip, played through sightlines. A core is not for sale. Killing a named man removes him: Ketch dead means no E2, and the Gray Man hires a lock-charmer from Pye’s stall who is meaner and less loyal. Bram dead means no warning, no held door, no summation witness.

**Knockout is the default.** Killing is possible and always costs: a body the Watch will hang on Voss, a witness gone, and inside Act III a dawn. No random encounters, no loot from enemies beyond the story chit that scene already names, no XP. Repeat crews drop nothing. A recovered weapon can be carried, as the inventory rules already allow, and is never the reason to fight.

**Watch attention** rises when violence is seen: a watchman, a neighbour, a survivor who talks, a badged man touched, a body left where the morning will find it, a bell. A quiet knockout on a closed night floor does not raise it. At 1 a watchman asks questions. At 2 the Watch-house closes doors (property log, night books). At 3 Voss is picked up and the case is taken off him, a soft fail with a costly recovery. The old rule that every blow was +1 belonged to the five-fight cap. It would arrest him before Act II under this cadence.

**Health, injury, dawns.** Rest at the office or a bought bed fills health and leaves a named injury. A named injury comes from a core, a set piece, or a defeat: bruised ribs slow him, a cut hand makes seal-reading and locks harder, a head knock makes Observe harder. A bonesetter in Printers’ Quarter clears one injury and charges the retainer twenty the first time and forty after. That is a person and a price, not a shop. He treats temporary allies too, at the same prices. Withdrawal from a floor is allowed. By morning the outer groups are replaced and the core is still there. Once the Act III clock is running, a withdrawal, a bonesetter, or a delay each spend one dawn.

**Lillian’s clock.** Sedge’s consignee book (B1 cage) includes a schedule: a donation landing every third night. Osric offers to buy the case once the donor roll has been seen — in person, or by letter if the study’s factor did not walk out. Taking the coin files the coat as a drowning. Lila leaves. There is no rescue, and a summation forced afterward speaks his bargain back to him. Refusing starts the clock, as does showing the roll to anyone if the offer somehow never landed. After the **second dawn**, Hearth Court’s upper rooms hold a second coat and no Lillian. The journal records the schedule in his words. Lila or the sergeant says the second-dawn rule in the refusal scene, so the stake is spoken before he spends it. Dawns spent before that window do not empty the house. They replace chalk-men with coats, so a loud Act I makes Act III harder. The scheme itself is on the pages either way: warehouse consignee, donor roll, annex register. Her life is the stake of speed. Fair play (§4.3.7) does not require a winning fight at Hearth Court to know who staged the coat.

##### Act I ledger — the cheap book

E1–E5 remain the set pieces of §4.3.2. A1–A6 are the floors and pressures around them. E3a and E3b are one choice; a playthrough includes one.

| ID | Groups | Where | Why these people are here | Quiet route | What the blades buy |
|---|---|---|---|---|---|
| A1 gate | 1 | Wharf Ladder night gate | The fast clock needs a door | Paid Merrick walks him past | — |
| A1 lane | 1 | Lost-crate lane | The alibi’s crates are moving tonight | Tide-gap timing, taught by Merrick or the stones that same visit | A chalk chit with the crate mark |
| A1 clock | 1 | Clock room | One man is paid to keep the clock three minutes fast | A later visit, once he knows the interval. The first night fights | The night’s chalk (peels the Act II yard) and the interval |
| E1 | 1 | Shipping-office back room | Ketch and Bram, sent to burn the March folio | Pay or Warm, and the back door; hide and overhear; a bluff that the Watch knows, which works only if it does (side case 03) | Pay tally with the crate mark. Noise brings night-men: attention +1. Losing wakes him on the quay, scrap gone |
| A2 | 1 | River stones | Scroungers paid to arrange the coat | Ask only the watchman | They were told how to fold it. A chalk crew, not a tide |
| E2 | 1 | Iron stairs at night | Ketch, to warn him off the recovery | By day; spot him and leave; Trade a false key place, which plants E3b | Tally brand on the hook. The river post leaks. Noise: attention +1. A man in the river is an arrest |
| A3 | 1 | Bakery doorway | The post Lila timed | The long way through Printers’ Quarter. The Gray Man gains the hour | The relief’s pay is Civic scrip |
| E3a | 1 | Lila’s stair | Take the key, or take Lila | The bait, or the night sergeant’s one ask | “Paid in Civic scrip.” A named injury. Lila’s injury state. She has to move. Neighbours: attention +1 |
| E3b | 1 | Empty locker, Market Cross edge | They believed the rumour | Watch only. He sees the gray face and is not seen | The same scrip, on his ground. The Gray Man learns Voss lies if the trap is sprung |
| A4 | 1 | Sable Row office stair | The key was seen going home | Sleep at the Printers’ Quarter friend’s. A raven finds an empty office | They came to his door. The sill-ward held. A waking neighbour is attention +1 |
| A5 | 1 | Lane behind the Printers’ Quarter shops | Carriers paid to lose the copy on its way to the office | Bram’s warning, or Voss goes to her by day | Charity scrip in their pay. The house name is not readable yet |
| A6 porter | 1 | Records annex door | The scrubbed rights stay scrubbed | Attention still 0, and his Watch reputation still clean; or a reading-rights token from side case 05 at attention 1 | — |
| A6 clerk | 1 | The second register | He is the man who scrubbed her pull | None | The register: her line, and the line that replaced it. The key’s true shape, not which lock |
| E5 | 1 | Lila’s threshold, wherever she sleeps that night | The Gray Man comes for the key himself | Shorten only. Name the Civic signature, or offer a fake key | The key kept; his one line; his glove if the threshold holds. Voss injured into Act II; Lila’s injury state; her copy lost if the room falls |

Act I authors **13** groups if every conditional fires and the player fights one of the two E3 rooms. The first night’s clock room, the annex clerk, and E5 have no quiet route. E4 is retired and its ID is not reused.

##### Act II ledger — follow the key

The Act I crate mark names the numbered shed. Sedge’s book consigns the “lost” crates to the Osric Rest as donations, and one slip in Lillian’s hand, dated after the coat, is addressed to **Hearth Court**. The Watch-house service stair is moving the night-book margins that name which watchman was told to find a coat. The donor roll on Wardour Street, signed **Ivo Osric** (working name), matches those night-book names. The Blue Room on the same street is where chalk becomes a receipt. Osric is the signature. The Gray Man is the deniable hand, and does not know every name on the roll. Whether he carries a badge stays open (§15).

| ID | Groups | Where | Why these people are here | Quiet route | What the blades buy |
|---|---|---|---|---|---|
| B1 yard | 2 | Numbered shed, outer watch | Sedge keeps a door | Chalk taken from the clock room, or Bram if he was turned | — |
| B1 rows | 4 | Between the crates | The slips move through the rows | Burning the seal scrap as an alarm pulls one group. The scrap’s lead then lives in the annex register | The Hearth Court slip |
| B1 cage | 2 | Sedge’s count room, then the seal cage | The consignee book is here | None | Lost crates donated to the Osric Rest. The union name for B2 |
| B2 | 1 | Union stair | The named man will not talk in the hall | Trade Sedge’s book | He confirms the river-post leak |
| B3 | 2 | Watch-house service stair | A copy crew is moving the margins | The night sergeant’s one ask, if it is still unspent. The public roster is the thin file | Which watchman was told to find the coat |
| B4 | 1 | Quay road or Market Cross | Rest coats, the night after the cage, sent for the pages | He chooses which road. They come on one of them | The factor’s order: the roll is on Wardour Street |
| B5 kitchen | 1 | Osric Rest | A door that does not open for finders | Lila’s bindery name takes him in as a temporary clerk (not while she is Badly hurt) | — |
| B5 hall | 1 | The hall | The roll is upstairs | She walks him as staff, played on sightlines. A hand on the wrong door brings this group in | — |
| B5 study | 1 | The study | The factor and one coat are with the roll | Talk buys a minute. The minute is the opening of the fight | Ivo Osric’s signature on names that match the night book |
| B6 | 2 | Blue Room, optional | Chalk is exchanged for donation receipts | Skip the tavern. Earning the token and using it replaces the hall walk with this room | The receipt book |

Act II authors **16** groups on the token route (the yard, the rows, the cage, the union stair, the copy crew, the road, the kitchen, the study, and the Blue Room in place of the hall: 2+4+2+1+2+1+1+1+2). The hall route is 15. The cage and the study have no quiet route.

##### Act III ledger — the city answers

Ashfield’s company store carries the same crate mark, and the store’s own tally book carries the honest count. Skipping the yard leaves the summation without that book; the scheme is already proved without it. Pye’s stall is how a bought charm drops Hearth Court’s upper threshold. Skipping Pye means the door bites during the core. The donation landing is the machine in motion, on the night the schedule names. The roof sees the wagon. The ground gets the brand.

Hearth Court is three landings. The court is Rest coats checking a bond in the Rest’s name. The stair is chalk-men who know his face. The upper rooms are the Gray Man’s own, and her door. The house accepts two holds. A hold is one stair landing (Bram, four groups) or one door (Lila unless she is Badly hurt, or the sergeant on the street door; he will not come inside). Two doors count. Two landings do not. A lamp in Lila’s hand still works inside a fight she is not holding.

| ID | Groups | Where | Why these people are here | Quiet route | What the blades buy |
|---|---|---|---|---|---|
| C0 | 1 | The refusal | Escorts for a man who said no | Take the coin. Rescue ends | The steps, on the way out |
| C1 | 3 | Ashfield company housing | The store wears the crate mark | Skip the yard. A Watch habit and attention under 2 peels the gate only; the inner two are Rest-paid | The store’s tally book: the crate mark, counted honestly |
| C2 | 3 | Pye’s stall | Licenses for doors that “hold” | Skip. The upper door bites | Pye, bought once |
| C3 | 4 | Donation landing | A lost crate walked into a Rest wagon | The roof. He sees the wagon and not the brand | The brand that matches the scrap |
| C4 court | 4 | Hearth Court yard | The bond is being checked | The sergeant on the street door removes one group | The bond, in the Rest’s name |
| C4 stair | 4 | The stair | Chalk-men from the sheds | One ally holds one landing, or Lila holds one door | — |
| C4 upper | 4 | The upper rooms | Her handwriting is the donation | None | Lillian, alive and unsigned. Or the second coat, if the second dawn has passed |

A same-night run from the refusal to Hearth Court meets C0 and not a second party. Waiting brings a two-wave removal on the next road, counted as one more encounter, and spends a dawn. Act III authors **24** groups if he refuses, delays, and clears every floor (1+3+3+4+12+1).

##### Act IV ledger — the room, then the stairs

The summation is the chain, spoken (§4.3.7). Combat around it is the door, the break, and one last meeting.

| ID | Groups | Where | Why these people are here | Quiet route | What the blades buy |
|---|---|---|---|---|---|
| D1 | 3 | Osric’s street door | The guests will not come because a finder asked | The sergeant compels them if attention is under 2 and Voss can show even the thin roster | The room |
| D2 | 1 | The summation | A hole in the chain still leaves someone a lie | A complete chain: consignee, donor roll, annex register, and Lillian or the pages | The break. Lamp, seals, the coat on a chair |
| D3 | 1 | The iron stairs | The Gray Man lived, and was not in the room | Name him and have him brought. Or walk past | The meeting E5 would not give him |

Act IV authors **5** groups. A complete chain and a compelled room is zero.

##### What one playthrough actually fights

The tables sum to **58** authored groups (13+16+24+5). That is the campaign if every staffed room is met, including the delay party and the Blue Room.

The quietest path that still reaches Lillian inside the two dawns, and still has a fair chain, fights **21**:

1. The clock room. 2. The annex clerk. 3. E5, shortened. 4–8. The shed: yard slipped with the clock-room chalk, one row pulled by burning the scrap, three row groups and both cage groups remaining. 9. The road. 10. The study, after Lila has walked the kitchen and the hall. 11. The refusal steps. 12–21. Hearth Court with the sergeant on the street door and Lila on one inner door, and without Bram: ten groups, upper landing included.

That path is legal and expensive. The sergeant’s one ask went to the night-book margins, so Lila’s stair was not cleared by the sergeant; it was avoided by watching E3b from hiding, which means sleeping away from Sable Row afterward so A4 never sees the key go home. Voss went to Lila by day for the copy, so the lane was never walked. Ashfield was not visited. The upper door bites. Most playthroughs land between these floors: outers they did not prepare, cores they cannot skip, and the rooms they chose to enter. Twenty-one is the floor under the design, so talk cannot shrink the case back to five fights. Fifty-eight is the house with every lamp lit. Side cases (§4.3.8) add up to **6** optional groups outside these tables, so the house with every side case fought is **64**.

##### Temporary allies

Nobody stands in the portrait bar for the whole campaign. An ally joins for a floor and leaves at the exit.

- **Lila** is the first temporary ally (E3a, or E5 if E3a was never fought). She is not a blade. She bars a door, throws a lamp, wakes a house, and can walk him into the Rest as a clerk. She can be injured (below).
- **Bram**, if spared and turned, holds a landing, warns her, and can stand as a summation witness.
- **The night sergeant** will not draw on a badge. He will be seen on a street, and he helps once; the price is a name (side case 10).
- **Pye**, if bought, drops one threshold and does not join the portrait bar.
- **Agnes Tully** (working; side case 02) can hold Lila’s door at E5 in Lila’s place. **Joss Harrow** (working; side case 08) can join one Act II floor as a blade. Neither counts as a Hearth Court hold.

**Ally injury.** A temporary ally can be hurt, and it lasts. Lila sets the pattern; the same states apply to every ally.

| State | How | What carries forward |
|---|---|---|
| **Steady** | Not downed | Nothing |
| **Hurt** | Downed once in a fight | Joins the next floor but cannot bar or hold a door (it takes two hands) until a rest or the bonesetter. Shorter, cornered lines. Lila’s trust drops only if Voss put her there without her consent; otherwise Voss takes strain |
| **Badly hurt** | Downed twice in one fight, or downed while Hurt | Out of the portrait bar until the bonesetter has seen her (his usual price; in Act III, a dawn). Until then Lila cannot walk him into the Osric Rest (B5) or hold a Hearth Court door. Trust drops regardless; her warmest trust state is delayed, not closed |
| **Killed** | **Not possible by default** | Open question (§15) |

Her first scene after a fight opens on the injury, never on a speech about it.

**The Gray Man in Act I.** He watches, posts, and pays. He does not speak in Act I except for one line at the Act I break (E5): “It was never hers, Mr. Voss. It isn’t yours. I’m only the one who’s patient about it.”

##### Story combat (auto-resolve)

An accessibility setting, **Story combat**, lets any fight resolve without being played. It is offered when a fight starts and can be switched on or off in settings at any time. It never removes a choice made before the fight (pay, talk, slip, bait, walk away); those still happen in dialogue and on sightlines. A started fight resolves to its **won** outcome, and every consequence lands as if it had been fought: what the blades buy, the room’s named injury on Voss, Hurt on an unprepared ally, Watch attention if the room was witnessed, a dawn where one would be spent. Auto-resolve knocks out and never kills. A core with no quiet route still has to be crossed; auto-resolve crosses it at that cost.

| Fight | Auto-resolve outcome |
|---|---|
| A1 clock (first night) | Won. The night’s chalk and the interval. Voss bruised |
| E1 | Won. Pay tally with the crate mark. Merrick will not speak again. Watch attention +1 |
| E2 | Won. Tally brand on the hook. Nobody goes in the river. Watch attention +1 |
| E3a | Won. “Paid in Civic scrip.” Voss takes a named injury. Lila Hurt unless the threshold was re-seated (side case 02). She moves. Attention +1 |
| E3b (sprung) | Won on his ground. The same scrip. The Gray Man learns Voss lies |
| A6 clerk | Won. The register and the key’s true shape. Voss bruised |
| E5 | The key kept. Voss injured into Act II. Lila Hurt unless the threshold holds or the night was prepared. The glove only if the threshold holds. The one line still plays |
| Other groups and cores (B1 cage, B5 study, C4 upper, D2 break) | Won, with that room’s named injury; in Act III each still spends what a fought one would |
| Side-case fights | As each §4.3.8 entry states |

##### What the combat system would need (not yet built)

- A combat mode that enters and leaves cleanly from exploration: real-time with pause, auto-pause on sighting and injury, and the existing pause affordances. A quiet crossing of a kept floor uses the same mode.
- Hostility and allegiance on actors (neutral to hostile on trigger), plus temporary allies with limited orders: hold a door, throw a lamp, follow. Lila never receives a weapon order.
- Enemy actors with simple authored AI: advance, flank a choke point, break and flee under morale loss, surrender. Chalk crews break when their named man drops. Rest coats break when that room’s factor drops. Porters do not break for a bribe.
- Attack resolution using the equipped weapon's `damageBand`, defence from worn gear, and hit/miss feedback; an unarmed or improvised attack path (shove into seals, kick the lamp). Tune the placeholders so one night’s health can clear a core if the room is used.
- Damage that drives `GameSession.currentHealth` and the portrait bar, with **knockout vs lethal** intent and downed-not-dead as the default for Voss (defeat is a story outcome: he loses the thing he came for, or he is thrown out and a dawn passes).
- Rest that fills health and leaves named injuries. A bonesetter who clears one injury, at the prices above. The two-dawn clock as case state the journal can read.
- Watch attention advanced only by witnessed violence, as above.
- Environmental interactions: lamps that can be broken or dimmed (the Gray Man's charm), biting seal shelves, slick stairs, doors that can be barred, a threshold that bites if Pye was not bought.
- Dialogue hooks both ways: dialogue actions that start, avoid, shorten, or end a fight, and combat outcomes written back as case flags (`combat.e1.outcome` and the same pattern for each id here: slipped / won / lost / shortened / auto-resolved; plus `watch.attention`, wounds, and `ally.<id>.injury`) that dialogue conditions and the journal can read.
- Save and restore of that state, and an autosave before each authored floor.
- The Story combat setting: per-fight auto-resolve that writes the same case flags a played fight would, including injuries and attention.
- Ally injury states (Steady / Hurt / Badly hurt) that dialogue conditions, scene availability, and the journal can read.
- Combat-time movement from `MovementSystemRoadmap.md` Phase 6 (formation-free single hero plus ally, choke-point pathing).
- Art and audio: combat animations for Voss (strike, shove, hit, downed); three crew bodies (chalk, porter, Rest coat) plus Sedge, the Gray Man, and a factor; impact and lamp-dim audio. Named men can wear the crew body.

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
5. **Final commitment** — the player chooses the legal, moral, or pragmatic aftermath; Harborpoint reacts in epilogue texture (press, the Watch, docks), not a binary credits slide alone.

#### 4.3.8 Side cases — other business in Harborpoint

Side cases make Harborpoint less linear without becoming a checklist. Each one opens from an Act I–III location or character, is optional, and **pays back into the main case**: evidence, an ally, a quiet route, a way round a fight, strain or reputation. In the journal they sit under **OTHER BUSINESS**, in Voss’s voice, with no green checkmarks.

Rules:

- Each side case is grounded in an existing district, faction, or seed (§4.1, §4.2) and uses Harborpoint’s bureaucratic-damp humour.
- Each one changes at least one main-case scene, fight, or deduction.
- Side cases introduce **no new canon facts about the case** without sign-off. The only approved addition so far: **the drowning notice was paid copy** (side case 07). Who paid stays gated.
- They respect the gates: no protectee name, no early truth about Lillian, no answer to the Gray Man’s badge or employer, no early Blue Room, no Pell Street dossier.
- New supporting characters carry **(working)** names until a casting pass.
- Side-case fights are authored groups outside the §4.3.5 tables (6 in all). Each states its auto-resolve outcome.

| # | Side case | Opens | Where | Pays into the main case | Fight · auto-resolve |
|---|---|---|---|---|---|
| 01 | Day-Old | Act I, after the intro | The bakery doorway across from Lila’s stairs (A3) | Mrs. Pruett (working), the baker, has logged the Gray Man’s habits for bread money: his hours, the cart-noise trick, the gloves that never come off. Peels A3 without the long way; Voss gets the first move at E3a; a lookout’s warning before E5. No money trail, no badge clue | None |
| 02 | Thresholds That Hold | Act I (finale can slip to early Act II) | Lila’s boarding house → Pye’s stall off Market Cross | The landlady’s threshold came from Pye’s racket (§4.1 seed). Agnes Tully (working), the Printers’ Quarter friend with real locks, re-seats Lila’s ward: at E3a and E5 it holds for the whole fight, so Lila is far less likely to be Hurt and the glove can drop at E5. Agnes can hold Lila’s door at E5. Pye’s one sale is not spent here | Optional: rent-day collectors on a Sable Row stair (1 group) · won; the collectors back off; Voss bruised |
| 03 | Return to Sender | Act I, first return to the office after Wharf Ladder | Voss’s raven perch → Dock Authority rookery | Wenna Coyle (working) keeps the rookery. A lost raven with a Dock Authority ring; mending the line restores Voss’s ravens to the night sergeant, so the E1 bluff (“the Watch knows I’m here”) can be true and the sergeant’s one ask can be reached the same night. The stray message gives a lost-crate number for side case 06. **Main-case evidence payoff: to be decided** | None |
| 04 | The Clock That Runs Fast | Act I, after the first Wharf Ladder visit | Silas Teague’s (working) clock shop on Sable Row → the Wharf Ladder clock loft | Teague’s work-orders prove the night clock is set fast on order (shipped canon made evidence). The interval makes a later A1 clock visit quiet. Wins Merrick back as a witness after E1. Whether a Tuesday order is in the book: **open** | Optional: the clock loft (1 group) · won; the work-book, singed; Voss bruised |
| 05 | Reading-Rights in Triplicate | Late Act I / Act II | Civic Spine records annex, day counter | Registrar Pim (working). A legal reading-rights token: Wharf Ladder seals stop biting; the A6 porter lets Voss through at Watch attention 1. Confirms the scrub was an act of office (existing canon only) | None (a route around fights) |
| 06 | Window Three | Act II (early) | Dock Authority lost-cargo office | Fen Aldous (working), an old stevedore claiming a lost chest. Lost crates with seal-marks matching Lillian’s last night (§4.1 seed); a quiet route for the B1 yard in place of the chalk or Bram; a look at the shed register | Optional: the shed watch (1 group) · won; the register; attention +1 if a night-man sees |
| 07 | Paid Copy | Act II | Printers’ Quarter newsroom | Nell Garrity (working), a reporter who still digs. **The drowning notice was paid copy** (`evidence.paid-notice`); the original slip is on the spike; who paid stays gated. A press ally for the “expose” ending and the epilogue’s press texture (§4.3.7) | None (a fight-avoidance beat in the composing room) |
| 08 | The Smoker | Act II (mid) | Ashfield Yards company hall | Joss Harrow (working), a company fighter told to throw a fixed fight. Joss joins one Act II floor as a blade, **or** Voss takes the bookie’s book (**payoff to be defined**) | Ring fight (1) and an optional outside brawl (1) · ring: narrow honest win, Joss joins, Voss takes a named injury; brawl: won, Voss bruised |
| 09 | The Morning Ferry | Act III (early) | Wharf Ladder ferry quay | Merrick wants out. Protect him as a summation witness, or take a sworn statement before he goes. Taken after the refusal, it spends a dawn | Optional: the gangway (1 group) · he boards; Voss bruised; the ally Hurt unless a quiet route was set up |
| 10 | The Sergeant’s Price | Act III (mid) | The Watch-house | The night sergeant’s price comes due: the Watch file on Lillian (`evidence.watch-file`) for a name. If Voss already used the one ask, this is where it is paid; if not, it is a straight trade. Giving up a witness echoes Pell Street. Whether a second, “drawer” version of the file exists: **open** | None (a stealth alternative) |

Fuller cards live in the design pack (`combat-sidequests/sidequest-NN-*.md`). They were drafted against an earlier GDD and are superseded where they differ from this table.

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
- The detective design is kept near-bilateral at sprite scale so mirroring does not expose a swapped scabbard, lapel badge, or other continuity-breaking prop.
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

- **Zone 1 — Detective work area**: NE-facing desk island with Voss’s chair, two client chairs, anchoring rug, wastebasket, lamp, **raven perch**, writing set (quill, inkpot and ledger), notebook, mug, ashtray, case papers/folios, and unpaid notices. Keep at least one tile of movement clearance around the cluster.
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
| `office.desk` | Writing desk | “Three cold cases, two debts the ledger still remembers, and a clean page under the quill that hasn't learned a name yet.” | Adds `officeUnpaidBills` knowledge; establishes inspect staging. After retain, second look shows the key on the desk leather. |
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
- Deliberately opening a searchable container uses a compact, non-modal BG2-style transfer panel. The left 3×2 grid is the persisted source; the centre identifies Voss's case bag and capacity; the right 2×2 viewport is his real carried inventory; and the far edge is the party purse. Coins bypass the bag into the purse. Ordinary items—including weapons—move bidirectionally between source and bag when capacity permits, and Take All transfers everything that can fit while leaving the remainder persisted. A recovered weapon is carried, never auto-equipped, though it can now be readied by hand from the inventory window. Closing or issuing another world command never discards contents. Quick Loot is shipped: the right-rail Search control opens a non-modal strip listing every stack lying within reach of Voss, ten to a row with page chevrons past that, and one click lifts a stack straight into the case bag. Items dropped from the inventory window land at his feet and persist there per area. Ammo and condition still wait for the weapon model.
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
- **Authored combat / chase systems** in the Baldur’s Gate RTWP spirit (§4.3.5): pause-friendly tactics, temporary allies, kept floors, pressures, and set pieces. The campaign encounter plan and the system requirements are listed there (no combat code exists yet), including the Story combat auto-resolve setting and ally injury.
- **Side cases** (§4.3.8): ten optional cases that open from Act I–III locations and pay into the main case.
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
- **Story combat** (auto-resolve): any fight can be resolved without being played; its outcome and consequences still apply (§4.3.5).

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
- Can a temporary ally die? Default: injured, never killed (§4.3.5). Confirm, or allow it for some allies.
- Which lock the brass key fits, where, and what it holds. Act I ends on the true shape only; Act II opens from the crate mark.
- When the Gray Man’s badge-or-private question is answered, and what his glove (E5) leads to.
- Side-case payoffs still to define: side case 03’s evidence, side case 08’s bookie’s book, whether side case 04’s orders include Tuesday, and whether side case 10’s file has a drawer version.
- Lila’s day job is a Printers’ Quarter bindery (working); confirm or replace.
- Shipped copy that predates these locks (dialogue strings, journal copy, item text, area labels: the Watch, gray overcoat, Friday/Tuesday timing, mono 3’s wound) needs a string pass with VO re-records.

**Closed by §4:** lead names (Harlan Voss / Lila March); missing sister **Lillian March**; first-case arrival by visitor (Lila); first case title **The Empty Coat**; Empty Coat case dossier + M01 journal contract (§4.3.2); Harborpoint world bible (§4.1); full Harlan Voss and Lila March character bibles (§4.2); corruption as structural world force; RTWP authored combat intent; campaign combat cadence, the numbered shed as Act II’s first floor, and the temporary-ally roster (§4.3.5); Poirot-like finale contract; police named **the Watch**; Voss’s core wound is **Pell Street** only; Lila March in her early twenties; Lillian vanished Tuesday and the case opens **Friday** night; Lila found the key at home after the Watch returned the coat; follower in a **gray overcoat**; the drowning notice was paid copy; Lila as first temporary ally with lasting injury; the Gray Man’s one Act I line; Story combat auto-resolve; side cases (§4.3.8).

None of the remaining open decisions blocks the opening-sequence architecture.

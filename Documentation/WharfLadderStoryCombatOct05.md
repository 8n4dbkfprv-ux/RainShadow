# Wharf Ladder Story combat — October 5

PR #33's A1 content is integrated with the city scene, existing dialogue presenter,
shared character appearances, cutscene director, and save store. It remains Story
combat: no attack simulation or attack/hit animation is added.

## Playing the sequence

After completing the office introduction, travel to Wharf Ladder. Open the shipping
office's painted door, then click its opening. The gate and lane exchanges run on
the exterior. Entering the office plays an approach walk, the clock-room exchange,
and then Merrick's conversation. The existing shipping-office plate stages both
indoor beats; this change does not author a separate clock-room map or new art.
The cast uses independently recoloured HUM-M-01 bodies with no equipment. Named
NPC portrait keys from the writing PR remain placeholders.

Warm/Dry/Sharp opening choices are retained. A started fight resolves nonlethally
to victory after a short, skippable cut away. Its aftermath stays on screen until
acknowledged. The lane gives its chit on its first fight only. The clock room gives
the night's chalk and records Voss bruised, but never invents the interval: that
knowledge remains side case 04's responsibility. Bruising is persistent case state
and a journal entry; health budgets and injury stat penalties await combat rules.

The E1 desk and seal-room hand-offs both work. Story combat knocks Bram down,
grants his tally, increments Watch attention once, and reopens the existing
victory aftermath. Warm exits and the truthful night-runner bluff still avoid E1.
The resolver also supports a future played loss: the clock room still permits
progress; losing E1 removes the seal scrap. Story mode never randomly picks a loss.
Watch consequences beyond these flags/lines are not a new arrest system.

Returning from the office ends the visit. A subsequent visit reopens the three
floor checks; paid Merrick and learned tide-gap timing enable their authored quiet
entries. The lane's earned slip is narrated successfully in Story mode; detection
and tactical sightline crossing await playable combat. The clock-room quiet entry
stays locked until side case 04 writes `knowledge.nightClock.interval`.

## State and money

`WharfLadderStory` is the pure outcome authority. `WharfLadderDirector` presents it.
A visit number and each group's last crossed visit prevent retriggering the same
fight during door clicks or reloads. Dialogue first saves its trigger; the resolver
saves the outcome and pending aftermath together. The aftermath is acknowledged in
a later transaction. Closing the game during a fade therefore replays presentation
without losing the encounter or double-granting rewards. Mid-conversation saves
remain intentionally unsupported, as in the existing dialogue system.

Transient trigger, quiet-crossing and opening flags are consumed. A named last
opening flag records the chosen approach without carrying its modifier into another
fight. Durable evidence, knowledge, injuries, journal entries and counters use the
existing SaveSnapshot fields; there is no schema bump.

Laurens confirmed one silver equals one shilling (12 pence). Completing the office
intro credits Lila's 200 silver once. Loading an older completed-intro save applies
the same guarded grant. Merrick's paid choice requires 600 pence; completion settles
that charge and its receipt in one save. Live wallet balance seeds each dialogue.

## Verification

Use Xcode's matching toolchain on this machine:

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH=/tmp/wharf-clang-cache \
swift test --disable-sandbox --scratch-path /tmp/RainShadowSwiftPM \
  --filter 'WharfLadderStoryTests|ShippedDialogueCatalogTests|SaveStoreTests'
```

The live macOS harness uses a disposable save and drives the actual door, dialogue
input, cinematic director, room travel and SaveStore reload:

```sh
RAINSHADOW_QA_WHARF="$PWD/output/wharf-story-qa" \
  /tmp/RainShadowWharfApp/Build/Products/Debug/RainShadow.app/Contents/MacOS/RainShadow
```

Validation on October 5: 28 targeted Swift tests passed, and macOS Debug and iOS
Simulator Debug builds passed with signing disabled. All 14 live full-flow checks
passed, including the three-person clock-room cast, natural and skipped cinematics,
save reload, evidence grants, attention and crew cleanup. Placement tests also cover
the moving player record present during the approach-walk completion callback;
the staging query passes that actor's identity to the existing pathfinder.

Read `output/wharf-story-qa/report.json`; process exit alone is not a pass. Gate,
clock-room and aftermath PNGs capture the live presentation. The harness alternates
natural and skipped combat cinematics and checks that crew occupancy is removed.

The broader existing `CutsceneRunnerTests` include expectations for blocking
`actionOverride` behavior that disagree with the current runner. That runner and
those tests are unchanged by this integration. The new cinematic uses a sequential
track and has dedicated skip-at-every-active-tick coverage.

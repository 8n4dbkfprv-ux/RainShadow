# Armored Voss bow attacks — October 9

This records the initial armor integration. The subsequent
[distinct bow animation update](DistinctBowAnimationsOct09.md) replaces Pinning
Shot and ranged Sneak Attack, expands the bow equipment bundles to 960 frames,
and records the current hashes and validation. Ordinary-shot frames are retained.

Ranged Attack, Aimed Shot, Pinning Shot and ranged Sneak Attack now keep equipped
splint mail and the iron helmet visible throughout their authored animation.
Either piece can be worn independently. The player bow proxy refreshes its
appearance from equipped inventory before each shot, including equipment changes
made through the combat inventory. Armor no longer disables ranged targeting or
ranged techniques. A bow in an equipped weapon slot and human form are still
required; ammunition, action costs, release markers and flight paths are unchanged.

## Art authority

`ArtSource/Blender/ArmoredBowOct09/author_armor.py` runs through the live Blender
MCP connection. It appends copies of the approved normal shot, Pinning Shot and
stealth bow scenes, plus the current armor from `BladeWard_Authored.blend`.
The existing armor weights bind to the matching Rustic Warrior skeleton: every
rest-bone matrix matches exactly. No body, weapon, action or armature is edited.
`binding_audit.json` records the source actions and unchanged mesh counts.

`ArmoredBow_Authored.blend` retains the three scenes. `render_mcp_source.py`
produces equipment-only passes using the body, bow, string and arrow as holdouts.
Each clip has 18 phases in 16 facings; mail and helmet total 1,728 rendered layers.
The fixed 0.75 projection, density and registered 160×160 canvas match the
existing bow body bundles. No per-frame fitting or resizing of Voss is performed.

`ArtSource/Processing/package_armored_bow.py` packages two additive indexed
bundles, `HumanBowMail` and `HumanBowHelmet`, with 864 frames each. It uses the
established equipment palette and registration pipeline. `BowAttackAnimationSet`
pins their payload hashes and validates all three frame inventories. Both app
targets include the named bundles. The approved `VossCHMF`, existing shot bodies,
base equipment and Lila payloads remain unchanged.

Run the packager with the bundled Python that has Pillow and numpy. `--install`
copies only the two new bundles. `Review/` contains all-frame sheets and animated
previews for every facing. `validation.json` records hashes and visibility counts.

## Verification

Core regression: `BowAttackTests`, `RangedAmmunitionTests`, `CharacterAppearanceTests`,
`VossArmorAppearanceTests`, `WeaponTechniqueMotionTests`, and `StealthAnimationTests`.

The live ammunition QA also exercises armored outfits when launched with
`RAINSHADOW_QA_AMMUNITION_ONLY=1 RAINSHADOW_QA_ARMORED_BOW=1` and
`RAINSHADOW_QA_COMBAT=<output directory>`. It samples every shot frame in all
facings for full armor, mail only, helmet only and no armor. It then exercises
normal/fire arrows, misses, inventory pause, barrels, Aimed Shot, Pinning Shot
and ranged Sneak Attack through the combat UI.

Validated October 9: 32 core tests across six suites, 51 live combat checks,
and successful macOS/iOS simulator builds. Live captures and the report are in
`output/armored-bow-oct09/`. The live frame audit samples 3,456 poses across four
outfit combinations. An old generic appearance test still classified human death
as unsupported; it now explicitly verifies the existing death clip instead.

Initial indexed payload hashes (superseded by the distinct-animation update):

- Mail: `93bd4dfba9291a969ecf0bebf512357d7163d8f236ca66d5f76202d5236a3684`
- Helmet: `06f5a90553701b8e1fc94c62817767d62e4e230b73281c29a525d991ef701a9c`

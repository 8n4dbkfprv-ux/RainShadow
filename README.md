# RainShadow

RainShadow is a shared Swift/SpriteKit noir detective RPG prototype for iOS/iPadOS and macOS. The current slice contains a rainy apartment establishing shot, a cinematic transition, a playable modular isometric detective office, and the arrival of Lila March with the first case.

## Open and run

1. Open `RainShadow.xcodeproj` in Xcode.
2. Select **RainShadow iOS** or **RainShadow macOS**.
3. Run in landscape. Tap/click to skip the exterior after one second. Lila then enters with the case. Select a numbered response (click the line, or on macOS press **1–9**), use **Continue** for the next passage, and finish with **End Dialogue**. On macOS, arrows/WASD move reply focus for reading; **Return/Space** only activates Continue/End Dialogue (classic BG:EE — Space does not pick a player reply).
4. After the introduction, tap/click the office floor to move and select its objects to inspect them.
5. Out in the world, **Space** or the pocket-watch button on the left rail pauses (BG:EE's clock *is* the pause control). Orders issued while paused are walked when you unpause. **Escape** stops a walk; right-click and two-finger tap clear targeting without stopping one.
6. Open the inventory by clicking or tapping Voss's portrait on the right-side HUD. On macOS, `I` also toggles the inventory, arrows/WASD move its selection, and Return/Space/Escape closes it.
7. Open the current area map with the compass button on the left-side HUD. On macOS, `M` also toggles the map; Return/Space/Escape closes it.

Minimum targets are iOS/iPadOS 18.0 and macOS 15.0. The legacy tvOS template target is outside this milestone.

Lamp Ward and the Lamphouse are connected to normal city travel. For direct macOS access, open [Play Lamp Ward.command](Play%20Lamp%20Ward.command); it starts at the Lamphouse forecourt with a separate save. Click the doorway to enter and the narrow interior entrance strip to leave. See [the integration record](Documentation/LampWardRuntimeIntegrationV12.md) for asset sources and verification.

Voss uses the current Baldur’s Gate reference character in every area, including his explicit southwest seated poses. See [the character authority and regression checks](Documentation/VossCurrentRuntime.md).

Playable nonlethal Wharf Ladder combat is available through normal city travel.
For direct access, open [Play Combat.command](Play%20Combat.command); it uses a
separate persistent save at the shipping-office entrance. Click the ground to
move, select Melee Attack (or click an opponent directly) to strike, and use
Blade Ward, End Turn or Flee Combat. Flee requires 60 feet from every conscious
enemy; escape preserves remaining health and leaves the encounter unresolved. See the
[TemplePlus combat integration](Documentation/TemplePlusCombatOct06.md) for scope
and verification.

Combat turn order appears as a portrait initiative bar. Blue borders identify
Voss, red borders identify enemies, and a gold marker identifies the active
turn. Completed turns dim until the next round; defeated combatants leave the
bar. Portraits show rolled initiative, health and current conditions, and Voss's
portrait changes with Bear Form. The bar uses the presented combat state so
damage and defeats appear at the animation's impact marker.
The initiative UI playtest runs with `RAINSHADOW_QA_INITIATIVE_ONLY=1` alongside
`RAINSHADOW_QA_COMBAT=<output-directory>`.
Frame and dockhand portrait artwork were created with the built-in image
generator; [exact prompts and installed paths](Documentation/InitiativeArtOct08.json)
are recorded alongside the code. Voss and bear portraits reuse their existing art.

Blade Ward replaces Defend: **1** casts the protective cantrip for one standard
action. It halves incoming physical attack damage (rounded down) until the start
of the caster's second following turn. Burning and barrel fire damage are unchanged.
The hand gesture forms a ward at its midpoint; the persistent shimmer flashes on
blocked hits, pauses with combat/inventory, and ends with the condition. A ward
can carry into Bear Form, but the bear cannot cast it. Existing saves remain readable.

## Verification

During combat, press **I** or click the inventory/character button or portrait
to open the inventory. Combat pauses while it is open; **I**, **Escape**,
**Enter**, or the close button returns to the same turn. An existing tactical
pause stays active after closing the inventory.

Bear Form is available in the Wharf Ladder combat encounters. Open
`Play Bear Form.command` for an isolated playtest save; press **4** in combat
to transform on open ground, or to revert. See
[Bear Form](Documentation/BearFormOct06.md) for rules, art authority and checks.

```sh
xcodebuild -project RainShadow.xcodeproj -scheme "RainShadow iOS" -configuration Debug -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
xcodebuild -project RainShadow.xcodeproj -scheme "RainShadow macOS" -configuration Debug CODE_SIGNING_ALLOWED=NO build
swift test --scratch-path /tmp/RainShadowSwiftPM
```

Use a `/tmp` scratch path for SwiftPM on file-provider-managed Desktop folders; this avoids Finder metadata interfering with ad-hoc signing of the test bundle.

Design, architecture, asset, and milestone documents are indexed in `Documentation/README.md`. Generated-source lineage is recorded in `ArtSource/Prompts/GenerationLog.md`.

The restored Sable Row V30, Wharf Ladder V20, and Riverside V13 now replace their old world-map areas, with their linked interiors and the current Lamp Ward retained. `Play Sable Row.command` launches the connected city with a separate playtest save. See [restoration and validation](Documentation/RestoredCityAreasSep27.md). Area identities now use permanent short codes such as `RS0100` (Sable Row) and `RS0101` (office); [the code table](Documentation/AreaShortCodes.md) documents aliases and automatic save migration.

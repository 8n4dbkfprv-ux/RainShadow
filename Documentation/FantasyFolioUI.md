# Fantasy folio UI — September 28

Inventory, journal and map windows use Image Generator parchment with aged
bronze fittings matching the generated inventory slots. Palatino body text and Copperplate headings use sepia ink;
journal selections use burgundy with light lettering. The left HUD rail uses matching
generated parchment and medieval icons; the right rail and loot trays retain dark leather. Dialogue
uses a paper content well and a warm tint on its authored frame.

`UITheme` owns the colors and fonts. `UIPaintedChrome.assetTexture` maps structural
parchment plates to the generated outer folio, square card and horizontal strip.
`configure(_:for:)` applies nine-slice centers so bronze corners retain their
proportions at each panel size. All three inventory cards share one master.
Dialogue samples the undecorated parchment interior. Right-rail and loot-tray leather
remain in the cached Core Graphics path; parchment is no longer drawn procedurally.

`ClassicMacCloseButtonNode` draws an empty square with a raised outer bevel and
inset face, inspired by Mac OS 9. Its 100-point transparent hit area is retained.
Inventory moves its title and close fitting inward from the outer rule.

## Verification

The macOS Debug target builds with code signing disabled. The focused
InventoryScreenLayoutTests, HUDChromeLayoutTests and DialoguePanelLayoutTests
run 73 tests: 72 pass. The existing
`dialogueCameraFramingKeepsMoreOfBothCharactersThanLegacyDrop` test fails its two
camera-drop expectations at lines 706–707; this UI change does not modify the
camera calculation or office scale.

Live SpriteKit captures can be made with `RAINSHADOW_CAPTURE=<absolute PNG path>`,
`RAINSHADOW_START_SCENE=office`, `RAINSHADOW_SKIP_INTRO=1` and
`RAINSHADOW_CAPTURE_SIZE=1440x900`. Use `RAINSHADOW_CAPTURE_INVENTORY=1` for
inventory. The Debug-only `RAINSHADOW_CAPTURE_OVERLAY` accepts `journal`, `map`,
`worldmap` or `dialogue`. Dialogue uses the authored desk monologue in the
presenter's local session. Capture launches terminate automatically.

## Image-generated inventory slots

The `inventory_slot_*_fantasy_v01` family is generated with the built-in Image
Generator: one bronze/leather empty well and thirteen separate transparent
placeholders (sword, armor, helmet, gauntlets, boots, amulet, cloak, belt, ring,
shield, potion, pouch and arrows). These are empty-slot cues; the existing item
catalog and saved equipment identities are preserved. The ammunition row uses
arrows and is labeled AMMUNITION. Empty equipment cues render at 34% opacity;
empty bag cues use 16% so they cannot be mistaken for carried items.

Full prompts, source paths and hashes are recorded in
`ArtSource/Generated/UI/FantasySlotsV01/generation.json`, alongside the original
RGBA masters in `masters/`. `ArtSource/Processing/install_fantasy_slots_v01.py`
installs uniformly downsampled 256×256 RGBA PNGs into
`RainShadow Shared/Resources/Art/UI/Inventory/`. The art is not repainted or
recolored during installation. Both app targets include every new asset.

Validated with the macOS build, 16 inventory-layout/loot-asset tests, PNG alpha
and target-membership checks, and a live inventory capture at 1440×900.


## Generated parchment masters

The built-in Image Generator used the accepted fantasy slot frame as a material
reference. Three new RGBA masters contain quiet ivory vellum, narrow aged-bronze
rims and small matching corner engravings, with no baked text or internal panels.
Full prompts and source hashes live in
`ArtSource/Generated/UI/FantasyParchmentV01/generation.json`; full-size originals
are preserved in that family's `masters/` directory. Reinstall with
`python3 ArtSource/Processing/install_fantasy_parchment_v01.py`.

Packaging trims transparent exterior padding and downsamples uniformly using
`sips`, preserving aspect and alpha. It does not repaint the art. Runtime files
are `ui_folio_{outer,card,strip}_fantasy_v01.png` in
`RainShadow Shared/Resources/Art/UI/Common/`, included in both app targets.


## Generated fantasy action sidebar

The left action rail and all twelve icons use built-in Image Generator artwork,
using the accepted slot frame as the bronze, ivory and leather style reference.
The icon set uses a crowned shield (menu), folded map, leather journal, satchel,
knight helmet, sealed quest scroll (leads), hooded companions, crossed hammer/key
(settings), campfire (rest), lore book (help), eye (hide UI), and hourglass (pause).
Existing action bindings, disabled states, hover/press behavior and hit targets
remain intact. Rail corners are nine-sliced within the existing HUD geometry.

Prompts, originals and hashes are retained in
`ArtSource/Generated/UI/FantasySidebarV01/generation.json` and `masters/`.
`ArtSource/Processing/install_fantasy_sidebar_v01.py` packages the art without
repainting: it trims the rail's transparent margins and uniformly downsamples
that master to 512 pixels tall and each square icon to 256 pixels. The thirteen
`*_fantasy_v01.png` assets in `RainShadow Shared/Resources/Art/UI/HUD/` are
included in both app targets and preloaded by `GameArt`.

Sidebar button wells reuse `inventory_slot_frame_fantasy_v01`, with the new
icons inset to 82% of their former extent to keep the painted rims clear.

## Generated dialogue frame and Mac OS 9 button

The built-in Image Generator created `dialogue_frame_fantasy_v01.png` and
`dialogue_button_fantasy_v01.png`, using the accepted parchment card as a material
reference. They live in `RainShadow Shared/Resources/Art/UI/Dialogue/` and are
included in both app targets. The frame is a complete paper backing, nine-sliced
behind the cropped dialogue text and portrait. The portrait bezel reuses the
generated inventory slot. Continue and End Dialogue use a compact rounded
rectangle with the raised double bevel of a Mac OS 9 push button, dark ink,
and parchment/bronze materials. Hover and press use dedicated Image Generator variants of the idle master,
with a brighter raised bevel and a darker recessed face respectively.

Masters and full prompts are in `ArtSource/Generated/UI/FantasyDialogueV01/`.
Reinstall with `python3 ArtSource/Processing/install_fantasy_dialogue_v01.py`;
this trims transparent padding and uniformly downsamples without repainting.
The command layout uses the installed button's 512×123 aspect ratio and fits it
uniformly inside its hit target. The frame layering regression now checks that
text and portraits sit above the opaque paper instead of below an aperture overlay.

Validation: macOS Debug build succeeds; 50 dialogue layout/scrollbar tests pass.
The already documented `dialogueCameraFramingKeepsMoreOfBothCharactersThanLegacyDrop`
failure was excluded. The 1440×900 live dialogue capture was visually reviewed.

The hover/pressed masters share the idle crop `[40, 110, 2131, 613]` and all
three installed button textures are 512×123 RGBA. The installer records
`fixed_crop` for interaction states to preserve registration. Both new variants
are preloaded and included in iOS/macOS. The macOS build passes; live pointer
hover/down paths were captured and visually reviewed using
`RAINSHADOW_CAPTURE_OVERLAY=dialogue` and
`RAINSHADOW_CAPTURE_DIALOGUE_BUTTON=hover|pressed`.

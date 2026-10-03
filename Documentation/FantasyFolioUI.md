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

## Sidebar V02 — Baldur’s Gate reference silhouettes

Twelve new Image Generator icons follow the user's September 28 sidebar
reference while retaining bronze/ivory materials: dragon head, compass N,
quill/inkwell, backpack/sword, profile bust, open book, scroll, cogwheel,
book/arrow, question mark, closed eyelid, and sun/moon clock. Runtime action
bindings are unchanged. The parchment rail and generated slot frame remain.

`HUDChromeLayout.LeftRail` now uses equal 0.070-height center spacing in the
upper eight and lower three controls, a 0.140 group break, and a separate bottom
clock. Slots share one size. The existing layout regression checks equal group
spacing and non-overlap across representative viewports.

Masters, prompts and hashes: `ArtSource/Generated/UI/FantasySidebarV02/`.
Installer: `ArtSource/Processing/install_fantasy_sidebar_v02.py`.
Runtime: `RainShadow Shared/Resources/Art/UI/HUD/hud_action_*_fantasy_v02.png`.
All twelve are 256×256 RGBA, preloaded and included in both app targets.
macOS Debug build and all 18 HUD layout tests pass. Live 1440×900 capture reviewed.

### Reference margins and padding

The left rail now meets the viewport's left, top and bottom edges, preserving
the 264:2550 reference ratio at every viewport size. Slots are rectangular,
79% of rail width and 5.5% of rail height; equal side margins are 10.5% each.
The first center is 4.3% from the top, with 7.2% pitch in groups and a 14.4%
group break. Icons use the full 90% inner-height allowance without the previous
extra 18% shrink. Artwork remains square, and existing bindings remain intact.
macOS build and all 18 HUD layout tests pass; live 1440×900 capture reviewed.

### Dedicated sidebar slot

`hud_action_slot_fantasy_v01.png` replaces stretched inventory frames on the
left rail. The built-in Image Generator used the supplied BG screenshot for
simple chamfered geometry and the inventory frame only for bronze material.
Nine-slicing preserves the bevel while fitting the rectangular slot. Icons
remain undistorted; pointer hit testing now covers the full slot plus padding.
Masters/prompts are in `ArtSource/Generated/UI/FantasySidebarSlotsV01/`; install
with `ArtSource/Processing/install_fantasy_sidebar_slots_v01.py`. The asset is
preloaded and included in both app targets. macOS build and live capture pass.

### Open-ended sidebar — September 29

The rail now samples the central 80% of the generated parchment texture, omitting
both decorated end caps. Horizontal nine-slicing retains the bronze side edges;
the paper and side rails continue uninterrupted to the top and bottom screen
boundaries. Icon slots and their geometry are unchanged. macOS build and all
18 HUD layout tests pass; live capture visually verified.

### Sidebar reference refinement — September 29

The built-in Image Generator produced three new masters in
`ArtSource/Generated/UI/FantasySidebarRefinementV01`: a thinner bronze slot,
a separate clock housing with a ribbed upper-right fitting, and an open-ended
parchment rail with quieter side edging. `generation.json` records prompts,
source/master paths, alpha crops and hashes. Package with
`ArtSource/Processing/install_fantasy_sidebar_refinement_v01.py`; packaging only
trims transparent padding and downsamples. SpriteKit nine-slicing fits the frames.

The supplied full-screen BG reference informed regular centers at 5.5% through
55.9% of viewport height (7.2% pitch), utility centers at 70%, 77.2%, 84.4%, and
clock center at 93.8%. Regular wells are 77% of rail width and 5.4% of viewport
height; the clock housing is 90% and 7%, shifted slightly outward. Icon artwork
scales independently of hit wells to compensate for transparent source padding
and let prominent silhouettes meet or overlap rims. These are reference-based
proportions, not a pixel-identical reproduction.

Validation: macOS Debug build, 18 HUDChromeLayoutTests, and an in-game office
capture (`fantasy-sidebar-refined.png`). Existing interactions remain as before.

Clock clearance correction: the last housing is now centered and reduced from
90% to 80% of rail width, leaving 10% clearance on each side instead of overlapping
the painted outer edging. Its taller shape and generated artwork are retained.
The macOS build and all 18 HUD layout tests pass.

### Book typography — September 29

UITheme now uses Baskerville for body copy, Baskerville-SemiBold for headings,
commands and small labels, and Baskerville-Italic for narration. Dialogue run
styling and measurement use the same family. Remaining Courier/Avenir labels in
maps, captions and scene chrome now use shared typography. Inventory headings
also follow the theme. The built-in macOS font names were verified before use.
The macOS build passes and the inventory was checked in a runtime capture.
The multiline layout stress fixture uses a compact 220-point column to exercise
wrapping with the new narrower glyphs.

### Generated inventory stat badges — September 29

The four right-card stat icons now use a matching built-in Image Generator
family: a bronze shield for Defence, a heart with laurel for Vitality, an
etched sun medallion for Resolve, and crossed swords behind a ring for Damage.
Their transparent centers retain live game-rendered values. Square source
canvases and alpha are preserved; runtime PNGs are uniformly downsampled to
256×256 and displayed at the existing 84-point badge size.

Masters and the exact prompt set are saved in
`ArtSource/Generated/UI/FantasyInventoryStatsV01/generation.json` and `masters/`.
Reinstall with `ArtSource/Processing/install_fantasy_inventory_stats_v01.py`.
Runtime filenames are `inventory_stat_badge_{defence,vitality,resolve,damage}_fantasy_v01.png`
under `RainShadow Shared/Resources/Art/UI/Inventory`. Both app targets include
the new resources; prior badges remain available.

Validation: macOS Debug build succeeded, and the inventory runtime capture
`fantasy-inventory-stats.png` confirms that all four assets load, their live
values remain legible, and badges stay clear of neighboring text and card edges.

### Sword-and-shield equipment placeholder — October 2

The empty paperdoll equipment slot beside the character now shows a combined
sword-and-shield symbol, following the user's BG inventory reference. The
built-in Image Generator matched the existing pale parchment-gold silhouettes.
`InventoryScreenLayout.emptySilhouetteArtName(for:)` maps `.holster` to
`inventory_slot_silhouette_sword_shield_fantasy_v01`. The existing 62% icon size
and 0.34 placeholder alpha are retained. Both app targets include the new PNG.

The master and exact prompt are saved in
`ArtSource/Generated/UI/FantasySwordShieldSlotV01/generation.json` and `masters/`.
Package with `ArtSource/Processing/install_fantasy_sword_shield_slot_v01.py`;
packaging only downsamples the square RGBA master to 256 pixels.

Validation: macOS Debug build succeeded using the installed Xcode-beta developer
directory. Runtime inventory capture `fantasy-sword-shield-slot.png` confirms
the combined placeholder fits beside the character and matches the other cues.

### Inventory wording and gold coins — October 2

The inventory status reads “Paused” and the “CASE BAG” heading is removed.
The wallet display omits the pound sign during initial construction and refresh;
the stored amount and existing denomination formatting are preserved.
`inventory_coin_stack_gold_fantasy_v01.png` replaces the silver coin illustration.
The built-in Image Generator produced warm gold stacks with sun embossing and
transparent surroundings; the runtime preserves alpha and downsamples to a
256-pixel longest edge. Both app targets include the resource.

The master and exact prompt are in
`ArtSource/Generated/UI/FantasyGoldCoinsV01/generation.json` and `masters/`.
Reinstall with `ArtSource/Processing/install_fantasy_gold_coins_v01.py`.

Validation: macOS Debug build succeeded. Runtime capture
`fantasy-inventory-gold-coins.png` confirms the new status wording, absent bag
heading, gold coins and wallet amount without a pound sign.

### Two-row bag — October 2

The bag now contains two rows of sixteen slots (32 total). Slots retain their
70-point size and 84-point pitch. The panel is 218 points tall, centered at
Y=-386; row centers are Y=20 and -64 locally. The count label sits above the
first row. Existing generated parchment chrome is nine-sliced to the new size.

`CarriedInventoryState.defaultTotalSlotCapacity` is also 32, so taking loot,
unequipping and splitting stacks can use the extra row. Existing saves recreate
the bag at the current default capacity; no stored items or currency are altered.
Capacity tests now fill the expanded bag before checking overflow refusal.

Validation: macOS Debug build, 81 inventory/layout/transfer/persistence tests,
and runtime capture `fantasy-inventory-two-rows.png`. A broader name filter also
selected an unrelated Voss native-scale test which currently fails against its
old 3.125 baseline; character rendering was not changed for this inventory edit.

### Classic Mac OS 9 parchment scrollbars — October 2

The dialogue body and choices scrollbars use straight rectangular Platinum-style
chrome with square triangle buttons, a recessed channel, and a proportional thumb
with three centered grip lines. Shape reference: Apple's
[Platinum scroll bars, page 40](https://dev.os9.ca/techpubs/mac/pdf/HIGOS8Guidelines.pdf).
The thumb follows the visible content ratio, with a square minimum pointer target.
Existing arrow, page, wheel and drag controls use the same offset/callback path.
Pressing a button or thumb reverses its bevel and slightly offsets its symbol.

The five assets were produced with the built-in Image Generator. Masters, exact
prompts, alpha crop bounds and hashes are saved in
`ArtSource/Generated/UI/FantasyScrollbarV01/generation.json` and `masters/`.
Reinstall with `ArtSource/Processing/install_fantasy_scrollbar_v01.py`.
The installer crops transparent padding and downsamples without repainting.
Runtime assets are `dialogue_scroll_{up,down,thumb,track,grip}_fantasy_v01.png`
under `RainShadow Shared/Resources/Art/UI/Dialogue`; both app targets include them.

The first implementation stretched a rounded painted frame and did not match the
requested classic shape. The correction renders constant-width rectangular
bevels in `ScrollbarPlateNode` and uses only the generated thumb asset's central
paper material. Paper tiles remain 24 points square, with partial tiles cropped;
the frame, arrows and grip are independent geometry. The paper crop is flattened
into its own texture before tiling because nested SpriteKit subtextures resolved
against the original framed image in the runtime capture. The five originals and
their provenance remain available, but their old framed shapes are no longer drawn.

Validation: all 10 `DialogueScrollbarGeometryTests` pass and the macOS Debug
build succeeds. Runtime captures `fantasy-scrollbar-v2.png` and
`fantasy-scrollbar-v2-minimum.png` verify the long and minimum-size thumb with
consistent grain, square corners, fixed bevel widths and grip size.
For repeatable visual QA, use the existing DEBUG capture flow with
`RAINSHADOW_CAPTURE_OVERLAY=dialogue` and `RAINSHADOW_CAPTURE_SCROLLBAR=1`.
Set `RAINSHADOW_CAPTURE_SCROLLBAR_PARAGRAPHS=100` for the minimum-size thumb;
the default is 16 paragraphs.
This supplies repeated sample text through the shipping presenter without
changing the authored dialogue.

# Winged helmet and cupped armor runtime — October 5

The winged helmet is promoted from authoring into the recovered V8 game runtime,
together with the latest cupped-shoulder armor and its separate shoulder fasteners.
The source authority is `ArtSource/Blender/SplintMailCuppedOct04/`, which already
contains the approved helmet and adjusted rear collar. Installing the older
`WingedHelmetReferenceFitOct04` armor would discard the later shoulder and torso
refinements; this promotion renders the newer source instead.

## Equipment and presentation

- `iron-helmet` retains its save identity, slot and defence bonus. Its displayed
  name is **Winged Iron Helmet**, with matching icon and description.
- `VossIronHelmet` contains 2,400 frames: 1,200 paired with the matching armor and
  1,200 `unarmored_` frames without armor holdouts. Removing or equipping mail
  changes the helmet variant immediately. This also applies to the shared NPC
  appearance renderer. Masked pixels in the paired export cannot safely serve
  as a standalone helmet.
- `VossSplintMail` contains 1,200 frames, including the latest rounded torso,
  cupped shoulders, rear join and suspension fasteners.
- The existing idle/walk contract and sixteen facing directions remain intact.
  Equipment is still hidden during the pre-existing unsupported chair poses.
- Armor portrait layers use the authored 768 × 1344 canvas, including 256 pixels
  of top padding. Their bottom-based registration is (362.5, 535.5) pixels, with
  the same pixels-per-point as the unchanged 768 × 1088 sword layer.
- The portrait scales and centers the body, sword and worn layers together when
  the helmet is equipped. Its extra 110 source pixels above the body fit within
  the existing 24-point equipment-slot clearance. Bare-head framing is retained.
- One-time additive grants and save ownership are unchanged. Items deliberately
  dropped earlier are not silently reissued, and existing story items are retained.

Both armor authorities pin their reviewed payload hashes, extending the character
recovery safeguard to equipment. The approved VossCHMF, LilaSentinel and sword
index payloads are preserved byte-for-byte.

## Reproduction and rollback

`ArtSource/Blender/WingedEquipmentRuntimeOct05/` contains live MCP render recipes,
1,008 independent source renders, registered paperdoll layers, staged bundles,
validation and installation records. Render with the saved cupped-armor masters;
the recipes make only temporary camera, visibility and holdout-material changes.
Do not save their render state over the approved masters. Existing source review
hashes are checked before staging.

Use the workspace Python runtime to run:

```sh
python ArtSource/Processing/install_winged_equipment_oct05.py stage
python ArtSource/Processing/install_winged_equipment_oct05.py install
```

Review the staged contact sheets before installation. The installer requires the
approved V8 body hash, validates both equipment bundles and their source hashes,
and replaces files through new inodes rather than writing through possible hard
links. It preserves original equipment/UI files once under
`output/winged-equipment-runtime-oct05/before-install/`. Body, Lila and sword hashes
are compared before and after installation.

Both Xcode targets package the same named equipment bundles and portrait variants.
Use the repository play launchers to rebuild the current app. A separately copied
older application does not acquire changed resources automatically.

## Verification

The targeted checks cover extended portrait registration and slot clearance,
all paired/standalone idle and walk frames, rejection of an altered but internally
valid equipment payload, independent equip/unequip, grants and persistence.
Live `WeaponEquipmentQA` additionally checks packaged textures, synchronized
walking, helmet-only selection, removal/re-equipping of mail and inventory captures.
`CharacterAppearanceQA` checks all 160 standalone helmet walk poses on an NPC.
Final verification passed:

- 101 targeted Swift tests: 15 layout, 65 inventory/catalog/persistence, and 21
  current-character/appearance/equipment tests.
- macOS Debug and iOS Simulator Debug builds.
- 48 live equipment checks and 177 shared-appearance checks, including all 160
  standalone helmet walking poses.
- All 11 checked resources match their source payloads in each app. Xcode
  optimizes iOS PNG encoding, so those four images were decoded through ImageIO;
  their premultiplied RGBA pixels match exactly. Indexed bundles are byte-identical.
- Inventory with full equipment, helmet alone, and live walking were visually
  reviewed. All 1,008 source renders have at least 51 pixels of edge clearance.

Build logs, live reports and captures are under
`output/winged-equipment-runtime-oct05/`. `review_receipt.json` in the production
folder records the final asset hashes. Physical iOS execution and unrelated tests
were not run.

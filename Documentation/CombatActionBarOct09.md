# Combat action bar — October 9

The combat button grid is replaced by a compact, painted parchment-and-brass bar.
Melee uses a sword, ranged uses an arrow, and their techniques have distinct
weapon symbols. Hide uses a hood, Flee footprints, and human reversion a face with
a return arrow; no action uses a full human figure. Bear, claw and roar retain
animal symbols. These are original generated assets, not extracted BG3 art.

`CombatActionBar.swift` reuses inventory's `ui_folio_strip_fantasy_v01` parchment
master with nine-slicing. The current 5×4 icon sheet is
`combat_action_inkwash_v02`: generated black-and-gray brushwork on white, with
pooled pigment, dry-brush breaks and irregular tonal washes. The shader converts
that painted density to warm ink opacity, revealing the actual parchment through
diluted strokes. No metallic bevel, edge light or synthetic color ramp remains.
Each cell is cached as a standalone runtime texture. The original flat symbols
remain available as the composition reference; the current prompt and source
paths are recorded in `CombatInkWashArtOct09.json`.
Buttons use the shared folio paper surface with restrained ochre (melee), slate
blue (ranged), plum (ward/stealth), moss (bear) and terracotta (End Turn) washes,
reduced to 24% strength so the shaded symbols are the focus.
Labels and tooltips use the same ink palette, and selected targeting gets a
thicker deep-teal outline. Exact original built-in image generator prompts are in
`CombatActionBarArtOct09.json`. The original leather frame is retained as a source
asset but is no longer used by the runtime bar.

The existing command names, shortcuts, action costs and targeting logic stay in
`TacticalCombatDirector`. Human form has sixteen commands. Bear form displays
Claw, Roar, Human Form, Extinguish, End Turn and Flee. Portrait and health follow
the presented combat state, including the separate bear health pool. The ammo
button switches its symbol and count with the chosen ammunition.

Desktop layout has a portrait, two icon rows and a separate End Turn control.
Narrow layouts wrap the same controls into additional rows. Hover or tap provides
a title and action description; unavailable actions dim. Painted chrome consumes
clicks, and inventory hides the bar. Existing combat-start and initiative UI stay
above it.

The focused macOS harness uses `RAINSHADOW_QA_ACTION_BAR_ONLY=1` with
`RAINSHADOW_QA_COMBAT` pointing to its output directory. It exercises pointer
targeting, tooltips, ammunition, inventory, narrow hit areas, bear actions and End
Turn, and captures the actual SpriteKit rendering.

Validation: macOS Debug and iOS Simulator Debug builds passed. The reviewed live
run passed 42 checks, including painted-frame bounds and non-overlapping hit
areas at 820, 560 and 320 points. Captures and report:
`output/combat-action-bar-reviewed-oct09/`. Human, bear and narrow captures were
visually inspected. Nine-slice cap scaling lives on a parent node so assigning
the SpriteKit sprite's size cannot reset the scale and enlarge the frame.

Parchment revision: both builds passed again, along with 43 live checks. Human,
tooltip and narrow renders were visually reviewed in
`output/combat-action-parchment-oct09/`. This revision reuses the inventory's
existing generated art; it introduces no new raster artwork.

Icon-shading revision: both builds and all 43 live checks passed. Full-size and
narrow renders were inspected in `output/combat-action-ink-gradients-oct09/`;
the shading now spans each individual sword, arrow and ability symbol.

Ink-wash artwork revision: macOS and iOS builds and all 43 live checks passed.
Actual-size, narrow and enlarged live-shader captures were visually inspected in
`output/combat-action-inkwash-oct09/`; `ink-symbol-detail.png` shows the painted
pigment on the same parchment used at runtime.

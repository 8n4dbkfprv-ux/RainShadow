# Sword-only inventory — October 1

Voss's starting loadout now contains only the Lantern Service Shortsword.
The notebook, brass key and old modern props no longer occupy inventory slots.
The decorative briefcase is removed from both the inventory and loot panels;
weight/capacity information and usable fantasy slots remain.

Schema-1 saves explicitly discard the previous loadout's non-weapon item IDs
from carried stacks, equipment, ground piles and resolved loot containers.
Both original modern IDs and their period renames are covered. The sword,
money, case evidence/knowledge/journal progress and unknown future item IDs
survive. The three evidence definitions remain available to the item system,
but are not seeded into the current loadout. Historical empty-slot artwork is
unchanged.

The flashlight, wallet, cigarette-case and decorative briefcase runtime PNGs
and their packaging/preload references are removed. Recoverable originals are
in `output/inventory-modern-cleanup/originals`.

Validation: 90 catalog, save, inventory and weapon tests pass. The save regression
checks all former loadout IDs in every saved item location, preservation of case
progress and money, and an idempotent save/load round trip. The live weapon QA
also checks that the starting inventory is exactly the sword.

macOS and iOS Simulator builds succeeded. Live desktop QA passed all 12 checks;
`output/inventory-modern-cleanup/live/inventory_equipped.png` shows the sword
readied with an empty case bag and no briefcase decoration. Idle/walking weapon
synchronization and equip/unequip remain verified in that same run.

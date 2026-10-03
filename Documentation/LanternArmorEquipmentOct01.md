# Iron Helmet and Splint Mail — October 1

The current loadout is the Lantern Service Shortsword, Iron Helmet and Splint
Mail. New games carry all three; equip the helmet in the helmet slot and splint
mail in the armor slot. Each independently changes the inventory portrait and
standing/walking character. The helmet adds 1 defence, splint mail adds 6;
carrying them adds no defence. Weight is 3 lb and 20 lb respectively.

Existing saves receive the two new items once. The additive schema-1 field
`hasReceivedArmorKit` prevents repeat grants after dropping or moving them.
Before granting, the session checks carried, equipped, ground and resolved
container stacks for an existing copy. A full bag defers missing pieces until
a later load with room, rather than discarding them. The retired modern items remain retired.
Money and case progress are unchanged.

## Art authority

The current appearance is the subsequent fitted/textured V2 revision. Use
`LanternEquipmentOct01V2/Voss_Equipment_Animations.blend` and
`Voss_Equipment_Paperdoll.blend`, and the combined V2 packager. See
[equipment refinement](LanternEquipmentRefinementOct01.md) for the smaller
tasset hem, generated surface textures and corrected sword grip. The paths
and measurements below document the first armor pass.

`ArtSource/Blender/LanternArmorOct01/Voss_Armor_Animations.blend` and
`Voss_Armor_Paperdoll.blend` are self-contained equipment authoring files made
through live Blender MCP from the current sword/character scenes. The helmet
is an open iron skullcap with brow reinforcement and a nasal guard. Splint mail
has 28 vertical strips around the torso and lower skirt, dark leather straps,
and brass rivets. It is a separate mesh, fitted over the existing tunic.

The helmet follows the existing `head` bone. Splint mail follows existing
pelvis/spine/chest bones with smoothly blended weights. Neither changes Voss's
body geometry, head, UVs, bone lengths, actions, VossCHMF bundle or palette
support. The sword mesh and shipped assets remain unchanged.

Each equipment item has 336 source views: 11 idle poses and 10 walking poses
across 16 directions. Body holdout materials retain correct arm/face occlusion
without baking the body into either item. Four-sample Cycles renders at 256²
are reduced through the same body-derived crop rounding as the sword. The
native palette uses steel, brass and leather ramps. No equipment shadow is
baked; the existing body/ground shadow remains the authority.

`ArtSource/Processing/package_lantern_armor.py stage` writes 1,200 registered
frames for each of `VossIronHelmet` and `VossSplintMail`, respecting all 65 idle
holds. `install` copies the validated bundles and UI images. Source canvas is
128², y-up pivot (64,46), display size 140.625 units, as for VossCHMF. All source
views and every encoded frame are validated; no directions are mirrored.

Paperdoll renders retain their 768×1088 canvas and the existing body crop
registration (136,69)–(589,1036). Icons are separate 384² renders. Runtime
children each own their tint/stencil state; they take the current body frame
rather than running an independent clock. Native compositor traversal includes
the new child layers automatically.

Like the sword, this first equipment set is authored for idle and walking.
Equipment overlays hide during chair transitions and seated poses. Those poses
retain the current unarmored body; no attack sprites are included.

## Verification

Core checks cover slot restrictions, independent equip/unequip, defence,
one-time grant defaults and save round trips, every registered frame and idle
hold. The current Voss regression tests protect the body bundle. Live QA via
`RAINSHADOW_QA_WEAPON=<output directory>` upgrades an isolated sword-only save,
equips all three items, checks portrait and world layers, follows real walking,
unequips them, and verifies dropping a helmet does not grant another on reload.
Review sheets and sources are in `ArtSource/Blender/LanternArmorOct01`; build
logs, test logs and live captures are in `output/lantern-armor`.

Final validation passed: 97 Swift tests in eight suites, macOS Debug and iOS
Simulator Debug builds, and all 33 live desktop equipment checks. The shared
reducer reproduces all 336 existing sword source planes byte-for-byte. Both
built apps contain the correct armor/sword bundles and UI pixels (including
iOS PNG optimization). No iOS device execution was performed. The equipped
inventory review is `output/lantern-armor/live/inventory_equipped.png`.

# Wharf Ladder lantern clearance — October 10

Three entry lanterns pierced the canvas awnings: Rope and sail loft, Tide tavern,
and Chandler. Move the complete lantern assemblies, their wall brackets and
both day/dusk point lights sideways onto exposed facade. The loft and tavern
move +2.3 m along x; Chandler moves −4.4 m, keeping its lantern inside the map
edge. Each lantern cap clears its awning horizontally by 0.42 m.

The source is
`ArtSource/Generated/CityDistrict/WharfLadderLampsOct10/wharf_ladder_lamps_oct10.blend`.
The incremental `wharf_ladder_lamps_before.blend` preserves the original live
scene. The source comparison allows precisely 30 transformed objects; all
19,717 other object records retain their transforms and geometry, including
the approved ShapesV2 puddles. Materials and lamp energy were not edited.

The scene-wide mesh intersection audit checks 168 lamp/lantern/bracket meshes
against 44 cloth/canvas meshes. No intersections remain. Review images and
the object audit are in the package's `Review` directory.

Six native Cycles renders update the three buildings in day and dusk. They are
seated into the approved ShapesV2 masters with expanded lighting margins and
a 32-pixel outer feather for independent denoising. Map-edge pixels are not
feathered against obsolete art. Boundary mean differences are below 0.66/255;
pixels outside the rendered regions remain identical. Projection deviations
are 0.131° day and 0.171° dusk, both passing the existing gate.

```sh
python3 ArtSource/Processing/seat_wharf_lamps_oct10.py
python3 ArtSource/Processing/package_wharf_lamps_oct10.py
python3 ArtSource/Processing/package_wharf_lamps_oct10.py --install-only
```

Packaging retains the V19 page names and world rectangles. Installation backs
up current files, unlinks before copying, and verifies the area records,
navigation rasters, character assets, shipping-office art and door sprites.
The restore tool overlays this receipt after the puddle ShapesV2 receipt.

The macOS Debug build passed. All 43 bundled art hashes match the installed
package, and 230 protected runtime files retain their hashes. Day/dusk source
renders were visually reviewed; the game was not relaunched during this fix.

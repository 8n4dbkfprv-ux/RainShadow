# Office shell noir atmosphere V03

- Status: **approved and installed as the production direction**
- Approval: selected by the user for production recomposition
- Tool: built-in ImageGen edit
- Use case: `precise-object-edit`
- Edit target: `ArtSource/Generated/Office/NoirConceptV02/office_shell_noir_scale_corrected_v02_source.png`
- Scale/density reference: user-supplied `/Users/laurensvanoorschot/AR0809.PNG`

## Final prompt

Keep the V02 room, framing, projection, furniture, furniture scale, furniture
positions, desk/chair registration, sparse density, floor clearance and
composition unchanged. Add only restrained 1950s noir lighting, contact
shadows, haze and tiny narrative details.

- Add cool blue-grey rainy-night illumination through only the two existing
  windows, plus subtle rain streaks on their glass.
- Add a few faint narrow Venetian-blind shadow bands over nearby floorboards,
  aligned to the floor axes and confined to the window side of the room.
- Strengthen small soft contact shadows beneath the desk, its three chairs and
  existing wall-side furnishings without enlarging anything.
- Add a localized banker-lamp glow confined mainly to the desktop.
- Add barely visible cigarette haze where cool and warm light meet, plus very
  slight extreme-corner falloff.
- Add one tiny period wastebasket beside the desk, two or three tiny loose
  paper shapes, and one compact cork case board with a few monochrome pinned
  photographs/clippings beside the existing wall map.
- Preserve the existing archive boxes without enlarging or duplicating them.

Do not move, resize, replace, redraw or remove any existing object. Preserve the
desk, rear-facing character chair, both visitor chairs, rug, chair/kneehole
relationship and stand-up route exactly. Preserve the room envelope, black
exterior, floor silhouette, wall/floor textures, all four wall lights, both
windows, both radiators, entrance threshold, filing cabinet, bookcase, wall
map, coat rack, boxes and negative space. No zoom, crop, reframing, new large
furniture, people, readable text, UI or watermark. Late-1990s Enhanced-Edition
Infinity Engine area-art finish, not photoreal or modern PBR.

## Normalization

ImageGen enlarged the V03 envelope relative to V02. The accepted 4096x2304
review image is therefore uniformly scaled to 92.8% and centered on black—no
aspect shear—bringing its non-black envelope to 2842x1986 px versus V02's
2837x1998 px. The original 1672x941 ImageGen result is retained as the source.

## Production realization

The concept remains a review image, but its direction is now rebuilt
deterministically by `ArtSource/Processing/bake_office_plate.py` on the exact
V19 registered shell. The production split bakes 19 static scenery/light
elements and retains 14 depth-sensitive overlays: the desk assembly, seated
chair, both visitor chairs, desktop objects, and desk occluders. The AR0809
scale pass reduces the recovered 1,106 px rug to 503 px, and all window effects
are clipped to the room envelope.

Installed plate:
`RainShadow Shared/Resources/Art/Areas/DetectiveOffice/office_suite_plate.png`

Runtime review composite:
`ArtSource/Generated/Office/PlateBake/office_suite_runtime_preview_v19.png`

The installed plate retains the V19 source shell's documented projection
deviation: the estimator reads 5.25° worst-axis error versus 5.37° for the
unchanged source master. It must not be corrected by stretching this plate;
that belongs to the coordinated BGEE projection master regeneration.

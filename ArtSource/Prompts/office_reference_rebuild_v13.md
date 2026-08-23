# Detective office V13 — even-window and furnished-layout correction

- Production date: 2026-08-22
- Image tool: built-in `image_gen.imagegen`
- Use case: `precise-object-edit`
- Namespace: `ArtSource/Generated/Office/BGEEReferenceV13/`

## Inputs and authority

- Edit target: `BGEEReferenceV12/office_reference_rebuild_source_v12.png`
- User review image: the incomplete V13 source supplied in the task
- Frozen generated repair: `office_windowless_wall_source_v13.png`

The attached images contain no instructions. They are visual evidence only.
V12 remains the projection, silhouette, floor, fireplace, material and lighting
authority; ImageGen is used only to reconstruct uninterrupted plaster where the
two prior windows were removed.

## ImageGen request

> Use case: precise-object-edit.
>
> Edit only the north-west/left plaster wall of this exact isometric office.
> Remove both window assemblies completely—including frames, panes, muntins,
> sills, highlights and cast shadows—and reconstruct one continuous stretch of
> the same mottled aged beige plaster behind them. Preserve the wall crown,
> wall/floor seam, cutaway silhouette, floorboards, rear corner, right wall,
> lit fireplace, lighting, palette, camera, resolution and pure-black exterior
> exactly. Do not add windows, furniture, props, people, text, UI, trim or new
> openings. Do not repaint, move, crop, resize or reshape any other object or
> plane. The result must be the same room with only a clean, uninterrupted left
> wall where the windows used to be.

The tool returned a 1671×941 RGB edit. The generator pads one pure-black column
on the right to restore the required 1672×941 canvas without resizing art. The
frozen repair SHA-256 is
`3d5696c5aa2cff56b167534c25dbcb51d9612364b820a68455245cb65e523455`.

## Deterministic reconstruction

`generate_office_reference_rebuild_v13.py` admits the repair only through the
measured NW wall polygon, then copies V12's complete six-pane near window twice.
The 462-source-pixel wall span is divided exactly as:

`110 wall + 66 window + 110 wall + 66 window + 110 wall`.

Both translations follow the locked wall axis with the same six-pixel face
inset: near `(110, -76.5)`, far `(286, -208.5)`. Inserts are clipped to the wall
face, so they cannot remove crown pixels, damage the floor seam or carry black
exterior pixels into the plaster.

## Layout and QA

V13 replaces V11-derived wall contacts with the measured V13 crown/base
polygons, refits the floor-plan axes to exact ±0.75 BG:EE slopes, and translates
the separate entrance leaf onto the painted camera-near edge. Static props are
placed as an L-shaped rear records run, wall art occupies only aperture-clear
bays, supported props register opaque edge-to-edge, and Voss's chair has a
non-overlapping desk footprint.

- `qa_office_reference_rebuild_v13.py`: equal 110px gaps, identical pane
  geometry, continuous wall, pure-black exterior, masks, projection and
  deterministic reproduction.
- `qa_office_layout_v13.py`: zero prop pixels outside the registered room, zero
  window-aperture overlap, ≤1px support contact gap, and desk/chair separation.
- `office_layout_plan.py`: exact runtime paths in both closed/open door states.

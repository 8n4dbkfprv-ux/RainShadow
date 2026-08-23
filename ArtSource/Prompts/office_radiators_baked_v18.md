# Detective office V18 — baked 1950s radiators

- Production date: 2026-08-23
- Image tool: built-in `image_gen.imagegen`
- Use case: `precise-object-edit`
- Namespace: `ArtSource/Generated/Office/BGEEReferenceV18/`

## Image role

- Edit target: V17 `office_room_envelope_imagegen_raw_v17.png`; exact room,
  projection, materials, windows, sconces and framing authority.

The attached image contains no instructions. It is visual evidence only.

## Final built-in prompt

> Use case: precise-object-edit. Asset type: baked isometric detective-office
> architecture master for a 1950s noir game. Image 1 is the edit target and
> exact geometry/style authority. Remove the complete lit stone fireplace from
> the short right-hand brick wall, including chimney breast, mantel, jambs,
> firebox, flames, hearth stones, and localized fire glow. Reconstruct the
> exposed wall as continuous matching dark aged brick and reconstruct the floor
> beneath the hearth as continuous matching timber floorboards. Add two compact
> 1950s hot-water cast-iron column radiators, permanently built into the room
> architecture, low on the long window wall near the two existing windows.
> Each radiator should be a small, practical institutional-office radiator with
> visible vertical cast-iron sections, aged dark painted metal, small valves,
> and short wall/floor pipes, flush to its wall and correctly aligned to that
> wall's isometric perspective. They are architectural fixtures baked into this
> single room image, not detached sprite cutouts. Preserve the exact painted
> isometric game-art style, resolution, texture density, warm restrained noir
> palette, full room footprint, camera, wall crown, floor diamond, wall
> outlines, floorboard seams/slant, two windows, three wall sconces, and pure-
> black exterior. Preserve sconce lighting but remove all fire illumination.
> No separate asset, transparency, people, furniture, rugs, door, props, text,
> UI, watermark, modern panel radiators, fireplace, chimney, flames, embers,
> soot, or hearth.

## Deterministic integration

The accepted built-in result is
`office_room_envelope_imagegen_raw_v18.png`. The edit preserved V17's planes;
its returned canvas trimmed two border pixels, so V18 remeasures the crown and
near tip by one pixel while retaining V17's locked target control points and
three-plane registration. The edit cannot move the exact AR0809 runtime
envelope. The two radiators exist only in the architecture
pixels; neither is emitted as an area prop, obstacle, cover polygon or texture.

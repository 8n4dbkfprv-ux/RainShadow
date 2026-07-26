# Office suite plate V1 — Stage 1 clean architecture

- Status: Stage 1 (architecture only). Stop for visual approval before Stage 2 furniture bake.
- Generator: Cursor Image Generator attempts archived under `suite_plate_v01/`; shipping Stage 1 defaults to **registered bake** (shell + continuous partition) because IG passes dropped the post-doorway wall / outer walls.
- Registration lock: `ArtSource/Generated/Office/suite_plate_v01/registration/`
- Process: `ArtSource/Processing/process_office_suite_plate_v01.py` (default bake; `--ig` for IG resize)
- Runtime: `RainShadow Shared/Resources/Art/Areas/DetectiveOffice/office_suite_plate.png` (4096×2304)
- Partition rule: full-height through doorway to `suite_full_b=0.48`; only extreme tip cut away (not the old `b_return1` cliff).

## Hard rules

- One painted plate. No separate partition strips, cap strips, or freestanding door frames.
- Match Image 1 (shell) camera, axes, exterior door, window recess, materials, black exterior.
- Cutaway painted into the art (camera-facing walls omitted or reduced). No runtime half-wall railing.
- Empty architecture: no furniture, characters, door leaves, UI, text, watermarks.
- Built-ins allowed: window recess, fixed radiator mass if it reads as architecture, trim, floor, partition with opening.

## Generation prompt

```text
Use case: stylized-concept
Asset type: production empty environment plate for a fixed-camera isometric CRPG
Primary request: Reconstruct Image 1 (the approved RainShadow detective-office empty shell) as ONE coherent painted suite interior that also includes a full interior partition dividing a private office (left) from a waiting room (right). KEEP every outer perimeter wall from Image 1 — left/NW wall with the raised window recess, right/NE wall with the exterior doorway, and the rear wall runs. Do NOT omit, shorten, or open the NE waiting-room exterior wall; that wall must run the full length of the waiting room as in Image 1. The partition is an ADDED interior wall, not a replacement for the NE wall. Paint the partition as continuous architecture with the shell — same plaster, wainscot, trim, thickness, lighting, and perspective. Cut a single doorway opening into the partition with integrated jambs, header, and threshold (no freestanding frame prop, no door leaf).
Input images: Image 1 is office_shell_base — authoritative for camera angle, floor plan footprint, materials, exterior door, window recess, pure-black exterior silhouette, and registration.
Partition specification: one CONTINUOUS interior wall from a clean T-junction on the rear wall all the way toward the camera, parallel to the shell's north-east (right) wall, roughly one-third of the way across from the right. CRITICAL — do NOT stop the partition at the doorway. Sequence along the wall: (1) full-height run from rear T-junction to the doorway, (2) doorway opening cut INTO the wall, (3) full-height continuation PAST the doorway that clearly encloses the waiting room against the NE exterior wall for most of the room depth, (4) only at the extreme camera-near tip, a short finished cutaway return (not a waist-high railing). The waiting room is the wedge BETWEEN the continuous partition and the full NE exterior wall — both walls must exist for nearly the full depth. Doorway sized like a human door matching Image 1 exterior door scale; opening empty (no leaf).
Cutaway: ONLY the camera-facing front/near OUTER walls (same open edges as Image 1) plus the extreme near tip of the partition. Never remove the left NW wall, the right NE wall, the rear walls, or the mid-room partition run past the doorway. Pure black only outside the building silhouette, matching Image 1.
Scene/backdrop: empty 1940s private-detective suite after hours; worn dark wooden floorboards; stained two-tone plaster over dark wainscot; noir, lonely, lived-in; baked contact shadows where walls meet floor; cooler light near the window, warmer residual light in the waiting room.
Style/medium: richly pre-rendered late-1990s isometric PC CRPG environment art; painterly baked textures; modest native-resolution softness; no modern PBR gloss; texture scale and crack detail must match Image 1 (not sharper).
Composition/framing: exact 16:9 landscape matching Image 1 registration as closely as possible. Imagined standing adult about 170–190 pixels tall on a 3840×2160 master (or proportional on 16:9).
Constraints: EMPTY ARCHITECTURE ONLY. No desk, chairs, rugs, cabinets, coat rack, people, door leaves, window glass/sash props, UI, text, logos, watermark, selection circles, debug overlays, or modular graybox slabs. Do not assemble the partition from separate rectangles or pasted wall modules.
Avoid: waist-high railing walls; freestanding door frames; patch-composite seams; changing the exterior door or window position; changing the camera or room footprint; purple lighting; clean modern office look.
```

## QA (Stage 1)

- Reads as one artist / one plate
- Partition T-junction clean; doorway cut into wall
- Cutaway readable without giant foreground barriers
- Exterior door + window still match shell registration
- No furniture / leaves / UI

#!/usr/bin/env python3
"""V12 paperdoll-lock for Voss NE desk chain + shared-scale V7 install.

Requires the 20 bare-headed, chairless ``*_chroma_v12.png`` masters under
PreRendered3DV12/DeskNE. Legacy fedora/chair strips are deliberately rejected.

Writes ONLY ``*_ne_*`` atlas cells so SE desk frames from
process_pre_rendered_characters_v12.py are not clobbered.
"""

from __future__ import annotations

from pathlib import Path
import sys

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))

import process_voss_desk_ne_v01 as ne  # noqa: E402
from process_character_gait_v5 import remove_green_screen  # noqa: E402
from process_pre_rendered_characters_v12 import (  # noqa: E402
    identity_wardrobe_lock,
    soften_for_paperdoll_craft,
)

V12_NE = ROOT / "ArtSource/Generated/Characters/Detective/PreRendered3DV12/DeskNE"
IDLE_ATLAS = ROOT / "RainShadow Shared/Resources/Art/Atlases/VossSeatedIdle.atlas"
ARMS_ATLAS = ROOT / "RainShadow Shared/Resources/Art/Atlases/VossSeatedArms.atlas"
TRANS_ATLAS = ROOT / "RainShadow Shared/Resources/Art/Atlases/VossSeatTransitions.atlas"
STANDING_ATLAS = ROOT / "RainShadow Shared/Resources/Art/Atlases/VossIdle.atlas"
OFFICE = ROOT / "RainShadow Shared/Resources/Art/Props/Office"


def load_chroma_cells(pattern: str, count: int) -> list[Image.Image] | None:
    """Load keyed figures from ``pattern`` with ``{i:02d}``; None if any missing."""
    cells: list[Image.Image] = []
    for i in range(count):
        chroma = V12_NE / pattern.format(i=i)
        if not chroma.exists():
            return None
        rgba = chroma.with_name(chroma.name.replace("_chroma_v12.png", "_rgba_tmp.png"))
        remove_green_screen(chroma, rgba)
        cells.append(ne.trim_alpha(Image.open(rgba).convert("RGBA")))
        rgba.unlink(missing_ok=True)
    return cells


def main() -> None:
    IDLE_ATLAS.mkdir(parents=True, exist_ok=True)
    ARMS_ATLAS.mkdir(parents=True, exist_ok=True)
    TRANS_ATLAS.mkdir(parents=True, exist_ok=True)
    V12_NE.mkdir(parents=True, exist_ok=True)

    # Bare-headed, chairless per-frame chroma masters are authoritative. A
    # missing cell is a generation failure; never fall back to old chair art.
    stand_src_cells = load_chroma_cells("voss_stand_up_ne_{i:02d}_chroma_v12.png", 12)
    idle_src_cells = load_chroma_cells("voss_seated_idle_ne_{i:02d}_chroma_v12.png", 8)
    if stand_src_cells is None or idle_src_cells is None:
        raise FileNotFoundError(f"Missing one or more required NE V12 chroma masters under {V12_NE}")

    ne.validate_source_camera_scale("NE V12 chairless source", idle_src_cells + stand_src_cells)
    stand_ref_h = ne.source_opaque_height(stand_src_cells[-1])

    stand_cells = [
        identity_wardrobe_lock(ne.register_shared(soften_for_paperdoll_craft(c), stand_ref_h))
        for c in stand_src_cells
    ]
    idle_cells = [
        identity_wardrobe_lock(ne.register_shared(soften_for_paperdoll_craft(c), stand_ref_h))
        for c in idle_src_cells
    ]
    standing_reference = Image.open(
        STANDING_ATLAS / "voss_standing_idle_nw_00.png"
    ).convert("RGBA")
    ne.validate_shared_scale_chain(
        "NE V12",
        idle_cells,
        stand_cells,
        standing_reference,
        # Re-baselined for the V14 crunch. A 1-bit silhouette at 56 native rows
        # puts the head about 6 native pixels across, so one pixel of edge is
        # ~17% of its width and the band cannot be as tight as the 80-row soft
        # bake's (24, 31). Measured 21...26 across the NE chain.
        head_bounds=(19, 29),
    )
    sit_cells = list(reversed(stand_cells))

    for i, cell in enumerate(idle_cells):
        cell.save(V12_NE / f"voss_seated_idle_ne_{i:02d}.png")
        cell.save(IDLE_ATLAS / f"voss_seated_idle_ne_{i:02d}.png")
        # Do NOT write SE aliases — SE owned by process_pre_rendered_characters_v12
        upper, lower = ne.split_upper_lower(cell)
        upper.save(V12_NE / f"voss_seated_upper_ne_{i:02d}.png")
        lower.save(V12_NE / f"voss_seated_lower_ne_{i:02d}.png")
        upper.save(IDLE_ATLAS / f"voss_seated_upper_ne_{i:02d}.png")
        lower.save(IDLE_ATLAS / f"voss_seated_lower_ne_{i:02d}.png")

    empty = ne.lock_atlas_canvas(Image.new("RGBA", (ne.FRAME, ne.FRAME), (0, 0, 0, 0)))
    for i in range(8):
        empty.save(V12_NE / f"voss_seated_arms_ne_{i:02d}.png")
        empty.save(ARMS_ATLAS / f"voss_seated_arms_ne_{i:02d}.png")

    for i, cell in enumerate(stand_cells):
        cell.save(TRANS_ATLAS / f"voss_stand_up_ne_{i:02d}.png")
        cell.save(V12_NE / f"voss_stand_up_ne_{i:02d}.png")
    for i, cell in enumerate(sit_cells):
        cell.save(TRANS_ATLAS / f"voss_sit_down_ne_{i:02d}.png")
        cell.save(V12_NE / f"voss_sit_down_ne_{i:02d}.png")

    if (OFFICE / "office_desk_bare.png").exists() and (
        OFFICE / "office_desk_front_occluder_v04.png"
    ).exists():
        ne.build_actor_occluder(
            OFFICE / "office_desk_bare.png",
            IDLE_ATLAS / "voss_seated_idle_ne_00.png",
            OFFICE / "office_desk_actor_occluder.png",
        )
        ne.build_desk_top_occluder(
            OFFICE / "office_desk_bare.png",
            OFFICE / "office_desk_front_occluder_v04.png",
            OFFICE / "office_desk_top_occluder.png",
        )

    print(
        f"NE V12 installed: idle={len(idle_cells)} stand={len(stand_cells)} "
        "from required chairless chroma cells (NE-only; SE desk cells preserved)"
    )


if __name__ == "__main__":
    main()

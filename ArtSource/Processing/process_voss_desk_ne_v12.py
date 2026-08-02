#!/usr/bin/env python3
"""V12 paperdoll-lock for Voss NE desk chain + shared-scale V7 install.

Identity-relocks DeskNEV1 rear strips toward paperdoll V11 + SE key V12, then
registers with the same shared-scale V7 contract as process_voss_desk_ne_v01.

Writes ONLY ``*_ne_*`` atlas cells so SE desk frames from
process_pre_rendered_characters_v12.py are not clobbered.
"""

from __future__ import annotations

from pathlib import Path
import shutil
import sys

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))

import process_voss_desk_ne_v01 as ne  # noqa: E402
from relock_voss_identity_v12 import (  # noqa: E402
    extract_figure_rgba,
    figure_stats,
    is_chroma_green,
    pull_regions,
    region_means,
    reinhard_transfer,
    smooth_lower_hem,
)
from process_pre_rendered_characters_v12 import soften_for_paperdoll_craft  # noqa: E402

GEN = ROOT / "ArtSource/Generated/Characters/Detective/DeskNEV1"
V12_NE = ROOT / "ArtSource/Generated/Characters/Detective/PreRendered3DV12/DeskNE"
PAPERDOLL = ROOT / "ArtSource/Generated/Characters/Detective/Paperdoll/voss_paperdoll_front_chroma_v11.png"
KEY = ROOT / "ArtSource/Generated/Characters/Detective/PreRendered3DV12/voss_key_se_chroma_v12.png"
IDLE_ATLAS = ROOT / "RainShadow Shared/Resources/Art/Atlases/VossSeatedIdle.atlas"
ARMS_ATLAS = ROOT / "RainShadow Shared/Resources/Art/Atlases/VossSeatedArms.atlas"
TRANS_ATLAS = ROOT / "RainShadow Shared/Resources/Art/Atlases/VossSeatTransitions.atlas"
OFFICE = ROOT / "RainShadow Shared/Resources/Art/Props/Office"


def relock_strip(src: Path, dest: Path, tgt_mean, tgt_std, targets) -> Path:
    """Slice a chroma/RGBA strip, identity-lock each cell, recompose on green."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    sheet = Image.open(src).convert("RGBA")
    # If already keyed (has transparency), flatten green first for slice_strip
    px = np.asarray(sheet).copy()
    if (px[..., 3] < 250).mean() > 0.05:
        # RGBA with holes — paint green behind
        rgb = Image.new("RGB", sheet.size, (0, 255, 0))
        rgb.paste(sheet, mask=sheet.split()[-1])
        tmp = dest.with_name(dest.stem + "_flat_src.png")
        rgb.save(tmp)
        cells = ne.slice_strip(tmp, expected_min=4)
        tmp.unlink(missing_ok=True)
    else:
        # Ensure pure green field
        g = is_chroma_green(px[..., :3].astype(np.int16))
        px[g] = (0, 255, 0, 255)
        flat = dest.with_name(dest.stem + "_flat_src.png")
        Image.fromarray(px, "RGBA").convert("RGB").save(flat)
        cells = ne.slice_strip(flat, expected_min=4)
        flat.unlink(missing_ok=True)

    locked_cells: list[Image.Image] = []
    for cell in cells:
        # cell is RGBA trimmed figure
        arr = np.asarray(cell.convert("RGBA")).copy()
        mask = arr[..., 3] > 40
        if not mask.any():
            locked_cells.append(cell)
            continue
        transferred = reinhard_transfer(arr[..., :3], mask, tgt_mean, tgt_std)
        pulled = pull_regions(transferred, mask, targets, strength=0.55)
        arr[..., :3] = pulled
        arr[~mask, 3] = 0
        locked = smooth_lower_hem(Image.fromarray(arr, "RGBA"))
        locked_cells.append(locked)

    # Compose horizontal strip on chroma
    max_h = max(c.height for c in locked_cells)
    max_w = max(c.width for c in locked_cells)
    pad = 24
    cell_w = max_w + pad * 2
    cell_h = max_h + pad * 2
    strip = Image.new("RGB", (cell_w * len(locked_cells), cell_h), (0, 255, 0))
    for i, cell in enumerate(locked_cells):
        x = i * cell_w + (cell_w - cell.width) // 2
        y = cell_h - cell.height - pad // 2
        strip.paste(cell.convert("RGBA"), (x, y), cell.split()[-1])
    dest.parent.mkdir(parents=True, exist_ok=True)
    # Snap fringe greens
    out = np.asarray(strip).copy()
    g = is_chroma_green(out.astype(np.int16))
    r, gg, b = out[..., 0].astype(np.int16), out[..., 1].astype(np.int16), out[..., 2].astype(np.int16)
    fringe = (gg > 120) & (gg > r + 30) & (gg > b + 30)
    out[g | fringe] = (0, 255, 0)
    Image.fromarray(out, "RGB").save(dest, optimize=True)
    return dest


def main() -> None:
    paper = extract_figure_rgba(PAPERDOLL)
    key = extract_figure_rgba(KEY)
    p_mean, p_std = figure_stats(paper)
    k_mean, k_std = figure_stats(key)
    tgt_mean = 0.7 * p_mean + 0.3 * k_mean
    tgt_std = 0.7 * p_std + 0.3 * k_std
    targets = region_means(paper)
    key_targets = region_means(key)
    for name in targets:
        targets[name] = 0.75 * targets[name] + 0.25 * key_targets[name]

    idle_src = GEN / "voss_seated_idle_ne_rear_strip_v08.png"
    stand_src = GEN / "voss_stand_up_ne_rear_strip_v08.png"
    if not idle_src.exists():
        idle_src = GEN / "voss_seated_idle_ne_rear_strip_v03.png"
    if not stand_src.exists():
        stand_src = GEN / "voss_stand_up_ne_rear_strip_v03.png"
    if not idle_src.exists() or not stand_src.exists():
        raise FileNotFoundError(f"Missing NE desk strips under {GEN}")

    idle_v12 = V12_NE / "voss_seated_idle_ne_rear_strip_v12.png"
    stand_v12 = V12_NE / "voss_stand_up_ne_rear_strip_v12.png"
    relock_strip(idle_src, idle_v12, tgt_mean, tgt_std, targets)
    relock_strip(stand_src, stand_v12, tgt_mean, tgt_std, targets)

    IDLE_ATLAS.mkdir(parents=True, exist_ok=True)
    ARMS_ATLAS.mkdir(parents=True, exist_ok=True)
    TRANS_ATLAS.mkdir(parents=True, exist_ok=True)
    V12_NE.mkdir(parents=True, exist_ok=True)

    stand_src_cells = ne.expand_to(ne.slice_strip(stand_v12, 8), 12)
    stand_ref = stand_src_cells[-1]
    stand_ref_h = stand_ref.height
    stand_ref_head = ne.head_width(stand_ref)

    idle_src_cells = ne.expand_to(ne.slice_strip(idle_v12, 4), 8)
    idle_head = ne.head_width(idle_src_cells[0])
    idle_ref_h = max(1, round(idle_head * stand_ref_h / max(1, stand_ref_head)))
    probe = ne.register_shared(soften_for_paperdoll_craft(idle_src_cells[0]), idle_ref_h)
    probe_head = ne.head_width(probe)
    stand_out_head = max(1, round(stand_ref_head * ne.TEXTURE_BODY_HEIGHT / stand_ref_h))
    if probe_head < stand_out_head * 0.85 or probe_head > stand_out_head * 1.15:
        idle_ref_h = stand_ref_h

    idle_cells = [
        ne.register_shared(soften_for_paperdoll_craft(c), idle_ref_h) for c in idle_src_cells
    ]
    idle_ref = idle_cells[0]
    idle_cells = [ne.lock_cycle_scale(c, idle_ref) for c in idle_cells]
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

    stand_cells = [
        ne.register_shared(soften_for_paperdoll_craft(c), stand_ref_h) for c in stand_src_cells
    ]
    sit_cells = list(reversed(stand_cells))
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
        f"(NE-only; SE desk cells preserved)"
    )


if __name__ == "__main__":
    main()

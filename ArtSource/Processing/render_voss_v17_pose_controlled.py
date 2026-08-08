#!/usr/bin/env python3
"""Deterministically restyle authoritative Voss poses into V17 chroma masters.

The existing V12/V14-ready cells own pose, facing, silhouette, scale, foot plant,
and seat geometry.  This renderer keeps that alpha geometry byte-for-byte while
replacing the retired olive/mustard/green material identity with the frozen V17
brown/cream/black/charcoal/auburn contract.  A directional head treatment extends
auburn hair into the pronounced sideburn shape without generative pose drift.

``--proof`` writes only the eight SW walk masters.  ``--all`` writes the complete
148-master manifest inventory.  Existing V17 files are backed up before overwrite.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import math
from pathlib import Path
import shutil
from typing import Any, Sequence

import numpy as np
from PIL import Image
from scipy import ndimage


PROCESSING_DIR = Path(__file__).resolve().parent
ROOT = PROCESSING_DIR.parents[1]
V16_ROOT = ROOT / "ArtSource/Generated/Characters/Detective/PreRendered3DV16"
V17_ROOT = ROOT / "ArtSource/Generated/Characters/Detective/PreRendered3DV17"
INVENTORY_PATH = V16_ROOT / "frame_inventory_v16.json"
V11_FRAMES = ROOT / "ArtSource/Generated/Characters/Detective/PreRendered3DV11/Frames"
OUTPUT_ROOT = V17_ROOT / "Frames"
BACKUP_ROOT = V17_ROOT / "RendererBackup"

GREEN = np.asarray((0, 255, 0), dtype=np.uint8)

OLD = {
    "shirt": (206, 195, 170),
    "skin": (172, 126, 96),
    "waistcoat": (156, 119, 48),
    "coat": (112, 94, 60),
    "tie": (54, 70, 54),
    "shoes": (78, 55, 37),
    "trousers": (58, 56, 62),
    "hair": (58, 45, 37),
}

NEW = {
    "coat": (101, 59, 38),
    "shirt": (211, 194, 160),
    "tie": (31, 30, 31),
    "trousers": (55, 55, 59),
    "shoes": (75, 47, 35),
    "skin": (202, 143, 108),
    "hair": (112, 50, 29),
}

CLASS_NAMES = tuple(OLD)
CLASS_INDEX = {name: index for index, name in enumerate(CLASS_NAMES)}


def _visible_mask(rgb: np.ndarray, alpha: np.ndarray) -> np.ndarray:
    red, green, blue = (rgb[..., index].astype(np.int16) for index in range(3))
    chroma = (green > 90) & (green > red + 25) & (green > blue + 25)
    return (alpha >= 16) & ~chroma


def _linear_luminance(rgb: np.ndarray) -> np.ndarray:
    values = np.asarray(rgb, dtype=np.float64) / 255.0
    linear = np.where(values <= 0.04045, values / 12.92, ((values + 0.055) / 1.055) ** 2.4)
    return linear @ np.asarray((0.2126, 0.7152, 0.0722))


def _material_classes(rgb: np.ndarray, mask: np.ndarray) -> np.ndarray:
    """Classify old wardrobe by chroma/value, then apply body-region priors."""
    pixels = rgb.astype(np.float64)
    sample_chroma = pixels / np.maximum(pixels.sum(axis=2, keepdims=True), 1.0)
    sample_value = np.maximum(pixels.mean(axis=2), 1.0)
    costs: list[np.ndarray] = []
    for name in CLASS_NAMES:
        target = np.asarray(OLD[name], dtype=np.float64)
        target_chroma = target / target.sum()
        chroma = np.linalg.norm(sample_chroma - target_chroma, axis=2)
        value = np.abs(np.log(sample_value / target.mean()))
        costs.append(chroma * 4.0 + value * 0.11)
    classes = np.argmin(np.stack(costs, axis=2), axis=2)

    ys, xs = np.where(mask)
    if not len(xs):
        return classes
    x0, x1, y0, y1 = int(xs.min()), int(xs.max()), int(ys.min()), int(ys.max())
    yy, xx = np.indices(mask.shape)
    ry = (yy - y0) / max(1, y1 - y0)
    rx = (xx - x0) / max(1, x1 - x0)
    saturation = pixels.max(axis=2) - pixels.min(axis=2)

    # Shoes and trousers are strongly position-bound at play scale.
    shoe_like = (
        mask & (ry >= 0.82) & (pixels[..., 0] > pixels[..., 1] * 1.06)
        & (pixels[..., 1] >= pixels[..., 2] * 0.92)
    )
    classes[shoe_like] = CLASS_INDEX["shoes"]
    trouser_like = mask & (ry >= 0.52) & (saturation <= 24) & (sample_value <= 120)
    classes[trouser_like] = CLASS_INDEX["trousers"]

    # Hair lives only in the crown band. Warm face pixels below it remain skin.
    crown = mask & (ry <= 0.13) & (rx >= 0.12) & (rx <= 0.88)
    dark_crown = crown & (sample_value <= 125)
    classes[dark_crown] = CLASS_INDEX["hair"]
    warm = (
        mask & (pixels[..., 0] > pixels[..., 1]) & (pixels[..., 1] > pixels[..., 2])
        & ((pixels[..., 0] - pixels[..., 2]) >= 12) & (sample_value >= 62)
    )
    face = warm & (ry <= 0.28) & (rx >= 0.08) & (rx <= 0.92) & ~dark_crown
    classes[face] = CLASS_INDEX["skin"]

    # Lock the garment construction geometrically. Bright coat highlights can
    # be closer to the old cream shirt than the old olive coat in RGB space;
    # without this outer-garment prior they turn whole sleeves beige. Cream is
    # confined to the central shirt opening, black to its narrow tie, and every
    # other coat/shirt/waistcoat/tie candidate in the torso becomes brown coat.
    garment = mask & np.isin(
        classes,
        [
            CLASS_INDEX["shirt"],
            CLASS_INDEX["waistcoat"],
            CLASS_INDEX["coat"],
            CLASS_INDEX["tie"],
        ],
    )
    torso_garment = garment & (ry >= 0.13) & (ry <= 0.82)
    classes[torso_garment] = CLASS_INDEX["coat"]
    chest = torso_garment & (ry >= 0.16) & (ry <= 0.52) & (rx >= 0.37) & (rx <= 0.63)
    creamish = chest & (sample_value >= 108) & (saturation <= 82)
    old_yellow = chest & (pixels[..., 0] > pixels[..., 1] * 1.08) & (pixels[..., 1] > pixels[..., 2] * 1.22)
    old_green = chest & (rx >= 0.45) & (rx <= 0.55) & (sample_value < 118)
    classes[creamish | old_yellow] = CLASS_INDEX["shirt"]
    classes[old_green] = CLASS_INDEX["tie"]
    return classes


def _shade_to_target(source: np.ndarray, old: tuple[int, int, int], new: tuple[int, int, int]) -> np.ndarray:
    old_luma = float(_linear_luminance(np.asarray(old)))
    new_rgb = np.asarray(new, dtype=np.float64)
    source_luma = _linear_luminance(source)
    # Preserve broad baked illumination while compressing extreme source noise.
    ratio = np.clip(source_luma / max(old_luma, 1e-5), 0.48, 1.72)
    ratio = np.power(ratio, 0.82)
    return np.clip(new_rgb * ratio[..., None], 0, 255)


def _add_sideburns(rgb: np.ndarray, classes: np.ndarray, mask: np.ndarray) -> None:
    ys, xs = np.where(mask)
    if not len(xs):
        return
    x0, x1, y0, y1 = int(xs.min()), int(xs.max()), int(ys.min()), int(ys.max())
    height = y1 - y0 + 1
    head_limit = y0 + max(4, round(height * 0.255))
    head = mask.copy()
    head[head_limit:, :] = False
    hair = head & (classes == CLASS_INDEX["hair"])
    skin = head & (classes == CLASS_INDEX["skin"])
    if int(hair.sum()) < 4 or int(skin.sum()) < 4:
        return

    # Downward-only dilation makes sideburns without turning the forehead or
    # cheeks into hair. Directional cells naturally expose one or both sides.
    reach = max(2, round(height * 0.075))
    grown = hair.copy()
    frontier = hair.copy()
    for _ in range(reach):
        frontier = ndimage.shift(frontier, shift=(1, 0), order=0, mode="constant", cval=0) > 0
        grown |= frontier
    edge = ndimage.binary_dilation(hair, iterations=max(1, round(height * 0.012)))
    sideburn = grown & ~edge & skin
    # Keep the vertical face margins; never paint the nose/central face.
    skin_y, skin_x = np.where(skin)
    if len(skin_x):
        left, right = np.percentile(skin_x, (22, 78))
        xx = np.indices(mask.shape)[1]
        sideburn &= (xx <= left) | (xx >= right)
    source = rgb[sideburn].astype(np.float64)
    if len(source):
        rgb[sideburn] = _shade_to_target(source, OLD["hair"], NEW["hair"]).astype(np.uint8)


def restyle(source_path: Path, *, front: bool = False, rear: bool = False) -> Image.Image:
    with Image.open(source_path) as opened:
        rgba = np.asarray(opened.convert("RGBA")).copy()
    rgb, alpha = rgba[..., :3], rgba[..., 3]
    mask = _visible_mask(rgb, alpha)
    classes = _material_classes(rgb, mask)
    if rear:
        for name in ("shirt", "waistcoat", "tie"):
            classes[classes == CLASS_INDEX[name]] = CLASS_INDEX["coat"]
    output = rgb.copy()
    mapping = {
        "shirt": "shirt",
        "skin": "skin",
        "waistcoat": "shirt",
        "coat": "coat",
        "tie": "tie",
        "shoes": "shoes",
        "trousers": "trousers",
        "hair": "hair",
    }
    for old_name, new_name in mapping.items():
        region = mask & (classes == CLASS_INDEX[old_name])
        if not region.any():
            continue
        output[region] = _shade_to_target(
            rgb[region].astype(np.float64), OLD[old_name], NEW[new_name]
        ).astype(np.uint8)
    _add_sideburns(output, classes, mask)
    if front:
        ys, xs = np.where(mask)
        if len(xs):
            x0, x1, y0, y1 = int(xs.min()), int(xs.max()), int(ys.min()), int(ys.max())
            yy, xx = np.indices(mask.shape)
            ry = (yy - y0) / max(1, y1 - y0)
            half_width = max(1, round((x1 - x0 + 1) * 0.025))
            tie = (
                mask & (ry >= 0.20) & (ry <= 0.50)
                & (np.abs(xx - round((x0 + x1) / 2)) <= half_width)
            )
            output[tie] = np.asarray(NEW["tie"], dtype=np.uint8)
    output[~mask] = GREEN
    return Image.fromarray(output, "RGB")


def _selected_calls(inventory: dict[str, Any], proof: bool) -> list[dict[str, Any]]:
    calls = inventory["generated_calls"]
    return [call for call in calls if call["id"].startswith("walk_sw_")] if proof else calls


def _destination(call: dict[str, Any]) -> Path:
    name = Path(call["selected_master"]).name.replace("_v16.png", "_v17.png")
    return OUTPUT_ROOT / name


def _pose_source(call: dict[str, Any]) -> Path:
    """Select the most complete authored pose authority for this V17 cell.

    V16 deliberately reduced walk authoring to two extreme proof poses. V17
    needs the complete eight-cell gait, so locomotion takes geometry from the
    corresponding V11 authored master. All non-walk clips retain the selected
    V16 pose authority, including its exact seated and transition geometry.
    """
    if call["category"] == "walk":
        return V11_FRAMES / (
            f"voss_walk_{call['direction']}_{int(call['phase']):02d}_chroma_v11.png"
        )
    return ROOT / call["pose_source"]["path"]


def _registered_walk_master(master: Image.Image, authority: Image.Image) -> Image.Image:
    """Use one per-facing upper-body authority while retaining authored legs."""
    pixels = np.asarray(master.convert("RGB")).copy()
    authority_pixels = np.asarray(authority.convert("RGB"))
    alpha = np.full(pixels.shape[:2], 255, dtype=np.uint8)
    mask = _visible_mask(authority_pixels, alpha)
    ys = np.where(mask)[0]
    if not len(ys):
        raise ValueError("walk authority contains no visible figure")
    crown, height = int(ys.min()), int(ys.max() - ys.min() + 1)
    seam = crown + round(height * 0.64)
    pixels[:seam] = authority_pixels[:seam]
    return Image.fromarray(pixels, "RGB")


def render(*, proof: bool) -> dict[str, Any]:
    inventory = json.loads(INVENTORY_PATH.read_text(encoding="utf-8"))
    calls = _selected_calls(inventory, proof)
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    backup = BACKUP_ROOT / timestamp
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    written: list[str] = []
    backed_up: list[str] = []
    walk_authorities: dict[str, Image.Image] = {}
    for call in calls:
        source = _pose_source(call)
        destination = _destination(call)
        if destination.exists():
            backup.mkdir(parents=True, exist_ok=True)
            backup_path = backup / destination.name
            shutil.copyfile(destination, backup_path)
            backed_up.append(str(backup_path.relative_to(ROOT)))
        master = restyle(
            source,
            front=call["direction"] == "s",
            rear=call["direction"] == "n",
        )
        if call["category"] == "walk":
            direction = call["direction"]
            authority = walk_authorities.get(direction)
            if authority is None:
                authority_call = {**call, "phase": 0}
                authority = restyle(
                    _pose_source(authority_call),
                    front=direction == "s",
                    rear=direction == "n",
                )
                walk_authorities[direction] = authority
            master = _registered_walk_master(master, authority)
        master.save(destination, format="PNG", optimize=True)
        written.append(str(destination.relative_to(ROOT)))
    report = {
        "renderer": "v17 deterministic pose-controlled material transfer",
        "mode": "proof" if proof else "all",
        "written": written,
        "backed_up": backed_up,
        "pose_inventory": str(INVENTORY_PATH.relative_to(ROOT)),
        "rendered_at_utc": datetime.now(timezone.utc).isoformat(),
    }
    report_path = V17_ROOT / ("render_report_sw_proof_v17.json" if proof else "render_report_all_v17.json")
    report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return report


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--proof", action="store_true", help="render only eight SW walk masters")
    group.add_argument("--all", action="store_true", help="render all 148 masters")
    args = parser.parse_args(argv)
    report = render(proof=args.proof)
    print(
        f"Rendered {len(report['written'])} V17 masters; "
        f"backed up {len(report['backed_up'])} prior files"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

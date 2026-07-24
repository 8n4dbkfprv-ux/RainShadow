"""Bake office hotspot hover textures from the shipped transparent prop art.

Runtime code only swaps PNG textures.  The teal wash and cyan silhouette rim
are authored here so the office does not need shaders, SpriteKit colour
blending, or CPU texture generation while the game is running.
"""

from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
OFFICE = ROOT / "RainShadow Shared" / "Resources" / "Art" / "Props" / "Office"

SOURCE_NAMES = (
    "office_window",
    "office_door_leaf",
    "office_desk_bare",
    "office_desk_actor_occluder",
    "office_desk_front_occluder_v04",
    "office_desk_top_occluder",
    "office_desk_phone",
    "office_desk_files",
)

ALPHA_THRESHOLD = 46  # 0.18 * 255, matching the former runtime evaluator.
RIM_STEP = 3
BLEND = 0.40
WASH = np.array((0.12, 0.48, 0.55), dtype=np.float32)


def shifted(alpha: np.ndarray, dx: int, dy: int) -> np.ndarray:
    """Return alpha sampled at x+dx/y+dy, with clear pixels out of bounds."""
    height, width = alpha.shape
    result = np.zeros_like(alpha)
    source_x0 = max(0, dx)
    source_x1 = min(width, width + dx)
    source_y0 = max(0, dy)
    source_y1 = min(height, height + dy)
    target_x0 = max(0, -dx)
    target_x1 = target_x0 + (source_x1 - source_x0)
    target_y0 = max(0, -dy)
    target_y1 = target_y0 + (source_y1 - source_y0)
    result[target_y0:target_y1, target_x0:target_x1] = alpha[
        source_y0:source_y1, source_x0:source_x1
    ]
    return result


def bake(source_path: Path, output_path: Path, outline_source_path: Path | None = None) -> None:
    source = np.asarray(Image.open(source_path).convert("RGBA"), dtype=np.uint8)
    alpha = source[:, :, 3]
    outline_source_path = outline_source_path or source_path
    outline_alpha = np.asarray(
        Image.open(outline_source_path).convert("RGBA"), dtype=np.uint8
    )[:, :, 3]
    neighbours = np.stack(
        [
            shifted(outline_alpha, dx, dy)
            for dx, dy in (
                (-RIM_STEP, 0),
                (RIM_STEP, 0),
                (0, -RIM_STEP),
                (0, RIM_STEP),
                (-RIM_STEP, -RIM_STEP),
                (RIM_STEP, -RIM_STEP),
                (-RIM_STEP, RIM_STEP),
                (RIM_STEP, RIM_STEP),
            )
        ],
        axis=0,
    )
    neighbour_min = neighbours.min(axis=0)
    neighbour_max = neighbours.max(axis=0)
    opaque = alpha >= ALPHA_THRESHOLD
    outline_opaque = outline_alpha >= ALPHA_THRESHOLD
    inner_rim = outline_opaque & (neighbour_min < ALPHA_THRESHOLD)
    outer_rim = ~outline_opaque & (neighbour_max >= ALPHA_THRESHOLD)
    rim = inner_rim | outer_rim

    output = source.copy()
    factors = (1.0 - BLEND) + BLEND * WASH
    output[:, :, :3] = np.clip(
        source[:, :, :3].astype(np.float32) * factors,
        0,
        255,
    ).astype(np.uint8)
    output[~opaque] = 0

    rim_alpha = np.where(inner_rim, outline_alpha, neighbour_max).astype(np.uint8)
    output[rim, 0] = 0
    output[rim, 1] = 255
    output[rim, 2] = 255
    output[rim, 3] = rim_alpha[rim]

    Image.fromarray(output, mode="RGBA").save(output_path, optimize=True)


def main() -> None:
    for name in SOURCE_NAMES:
        # Both desk occluders are partial render layers. Their transparent cut edges
        # are not object edges, so use the full bare desk silhouette for the cyan rim.
        outline_name = (
            "office_desk_bare"
            if name in {
                "office_desk_actor_occluder",
                "office_desk_front_occluder_v04",
                "office_desk_top_occluder",
            }
            else name
        )
        bake(
            OFFICE / f"{name}.png",
            OFFICE / f"{name}_hover.png",
            OFFICE / f"{outline_name}.png",
        )


if __name__ == "__main__":
    main()

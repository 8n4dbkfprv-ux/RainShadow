#!/usr/bin/env python3
"""Render the V11 registered edge-on door family from one frozen hinge.

Closed is the screenshot-sized authority after the manifest's uniform 16:9
transform. Mid and open keep the hinge, angle, material, and 68px maximum
thickness while retracting along the same axis. The plate is not an input.
"""

from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[2]
STAGE = ROOT / "ArtSource/Generated/Office/BGEE1950sV11"
OUT = STAGE / "Props"
GEOMETRY_PATH = STAGE / "office_v11_geometry.json"
FLOOR_WOOD = STAGE / "floor_material_source_v11.png"
WALL_MATERIAL = STAGE / "wall_material_source_v11.png"


def _bilinear(texture: np.ndarray, u: np.ndarray, v: np.ndarray) -> np.ndarray:
    height, width = texture.shape[:2]
    x = np.clip(u, 0.0, 1.0) * (width - 1)
    y = np.clip(v, 0.0, 1.0) * (height - 1)
    x0 = np.floor(x).astype(np.int32)
    y0 = np.floor(y).astype(np.int32)
    x1 = np.minimum(x0 + 1, width - 1)
    y1 = np.minimum(y0 + 1, height - 1)
    fx = (x - x0)[..., None]
    fy = (y - y0)[..., None]
    top = texture[y0, x0] * (1.0 - fx) + texture[y0, x1] * fx
    bottom = texture[y1, x0] * (1.0 - fx) + texture[y1, x1] * fx
    return top * (1.0 - fy) + bottom * fy


def _timber() -> np.ndarray:
    floor = Image.open(FLOOR_WOOD).convert("RGB").resize((1024, 1024), Image.Resampling.LANCZOS)
    wall = Image.open(WALL_MATERIAL).convert("RGB").resize((1024, 1024), Image.Resampling.LANCZOS)
    floor_rgb = np.asarray(floor, dtype=np.float32)
    wall_rgb = np.asarray(wall, dtype=np.float32)
    # V10's timber method is retained, but V11 uses its own generated sources
    # and cooler 1950s institutional varnish.
    wood = floor_rgb * 0.82 + wall_rgb * 0.18
    return np.clip(wood * np.array([0.80, 0.74, 0.66]) + np.array([9.0, 7.0, 5.0]), 0, 255)


def _half_width(t: np.ndarray, maximum: float) -> np.ndarray:
    """Pointed end caps keep the exact axis endpoints on a compact canvas."""
    ramp = 0.022
    return maximum * np.minimum.reduce(
        [np.ones_like(t), np.clip(t / ramp, 0.0, 1.0), np.clip((1.0 - t) / ramp, 0.0, 1.0)]
    )


def _state_image(
    canvas_size: tuple[int, int],
    hinge: np.ndarray,
    direction: np.ndarray,
    length: float,
    thickness: float,
    wood: np.ndarray,
) -> Image.Image:
    width, height = canvas_size
    yy, xx = np.mgrid[0:height, 0:width]
    dx = xx.astype(np.float32) - hinge[0]
    dy = yy.astype(np.float32) - hinge[1]
    normal = np.asarray([-direction[1], direction[0]], dtype=np.float32)
    along = dx * direction[0] + dy * direction[1]
    across = dx * normal[0] + dy * normal[1]
    t = np.clip(along / max(length, 1e-6), 0.0, 1.0)
    half = _half_width(t, thickness * 0.5)
    mask = (along >= 0.0) & (along <= length) & (np.abs(across) <= half)

    u = np.mod(t * 2.2, 1.0)
    v = np.clip(across / np.maximum(2.0 * half, 1.0) + 0.5, 0.0, 1.0)
    rgb = _bilinear(wood, u, v)
    top_edge = np.clip((v - 0.74) / 0.26, 0.0, 1.0)
    lower_edge = np.clip((0.24 - v) / 0.24, 0.0, 1.0)
    rgb *= (0.76 + 0.26 * top_edge[..., None] - 0.12 * lower_edge[..., None])
    rgb += top_edge[..., None] * np.array([20.0, 17.0, 12.0])

    # The leaf lies almost exactly along the camera-near floor edge. A dark
    # internal silhouette is therefore part of the registered door artwork,
    # not a plate shadow: without it the brown leaf optically joins the floor
    # cutaway and reads as if the room has no door at all.
    mask_image = Image.fromarray((mask.astype(np.uint8) * 255), "L")
    interior = np.asarray(mask_image.filter(ImageFilter.MinFilter(7))) > 0
    silhouette_edge = mask & ~interior
    rgb[silhouette_edge] *= np.array([0.32, 0.29, 0.25])
    centre_reveal = mask & (np.abs(across) < 1.15)
    rgb[centre_reveal] *= np.array([0.58, 0.54, 0.48])

    alpha = np.zeros((height, width), dtype=np.uint8)
    alpha[mask] = 255
    alpha = np.asarray(Image.fromarray(alpha, "L").filter(ImageFilter.GaussianBlur(0.38)))
    rgba = np.zeros((height, width, 4), dtype=np.uint8)
    rgba[:, :, :3] = np.where((alpha > 0)[..., None], np.clip(rgb, 0, 255), 0).astype(np.uint8)
    rgba[:, :, 3] = alpha
    image = Image.fromarray(rgba, "RGBA")

    # Small period brass hinge plates stay on the registered hinge end and do
    # not alter the leaf silhouette or state geometry.
    draw = ImageDraw.Draw(image, "RGBA")
    plate_center = hinge + direction * min(18.0, length * 0.08)
    draw.ellipse(
        (
            plate_center[0] - 3,
            plate_center[1] - 3,
            plate_center[0] + 3,
            plate_center[1] + 3,
        ),
        fill=(104, 91, 59, 205),
    )
    return image


def _hover(image: Image.Image) -> Image.Image:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.uint8).copy()
    alpha = rgba[:, :, 3].copy()
    opaque = alpha > 16
    rgb = rgba[:, :, :3].astype(np.float32)
    rgb = np.clip(rgb * np.array([0.91, 1.07, 1.10]) + np.array([2.0, 20.0, 24.0]), 0, 255)
    padded = np.pad(opaque, 1, mode="constant")
    eroded = np.stack(
        [
            padded[1:-1, :-2],
            padded[1:-1, 2:],
            padded[:-2, 1:-1],
            padded[2:, 1:-1],
        ],
        axis=0,
    ).all(axis=0)
    rim = opaque & ~eroded
    rgb[rim] = np.array([16.0, 238.0, 242.0])
    rgba[:, :, :3] = np.where(opaque[..., None], rgb, 0).astype(np.uint8)
    rgba[:, :, 3] = alpha
    return Image.fromarray(rgba, "RGBA")


def _opaque_bounds(image: Image.Image) -> list[int]:
    alpha = np.asarray(image.getchannel("A"))
    ys, xs = np.where(alpha > 16)
    if not len(xs):
        raise ValueError("door state has no opaque pixels")
    return [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]


def main() -> None:
    geometry = json.loads(GEOMETRY_PATH.read_text(encoding="utf-8"))
    door = geometry["door"]
    canvas = tuple(int(v) for v in door["liveCanvas"])
    hinge = np.asarray(door["hingePixels"], dtype=np.float32)
    plate_hinge = np.asarray(door["targetHinge"], dtype=np.float64)
    plate_free = np.asarray(door["targetFreeEnd"], dtype=np.float64)
    closed_vector = plate_free - plate_hinge
    closed_length = float(np.linalg.norm(closed_vector))
    direction = (closed_vector / closed_length).astype(np.float32)
    angle = math.degrees(math.atan2(direction[1], -direction[0]))
    if abs(closed_length - float(door["targetLength"])) > 0.25:
        raise RuntimeError("target door length disagrees with transformed endpoints")
    if abs(angle - float(door["targetAngleDegrees"])) > 0.01:
        raise RuntimeError("target door angle disagrees with transformed endpoints")

    OUT.mkdir(parents=True, exist_ok=True)
    wood = _timber()
    manifest: dict[str, object] = {
        "version": "BGEE1950sV11",
        "canvas": list(canvas),
        "hingeImageXY": [float(v) for v in hinge],
        "anchorFromBottomLeft": door["anchor"],
        "displayScale": door["displayScale"],
        "plateHinge": door["targetHinge"],
        "closedPlateFreeEnd": door["targetFreeEnd"],
        "angleDegrees": angle,
        "maximumThickness": door["targetThickness"],
        "stateSemantics": "closed is full reference length; mid/open retract toward the fixed hinge",
        "sourcePolicy": "original V11 timber materials with a registered dark silhouette; screenshot contributes measurements only",
        "states": {},
    }
    ratios = door["stateLengthRatios"]
    for state in ("closed", "mid", "open"):
        ratio = float(ratios[state])
        length = closed_length * ratio
        image = _state_image(canvas, hinge, direction, length, float(door["targetThickness"]), wood)
        base_path = OUT / f"office_door_leaf_{state}_v11.png"
        hover_path = OUT / f"office_door_leaf_{state}_hover_v11.png"
        image.save(base_path, format="PNG", optimize=False)
        _hover(image).save(hover_path, format="PNG", optimize=False)
        image_free = hinge.astype(np.float64) + direction.astype(np.float64) * length
        plate_free_for_state = plate_hinge + closed_vector * ratio
        manifest["states"][state] = {
            "file": base_path.name,
            "hoverFile": hover_path.name,
            "lengthRatio": ratio,
            "targetAxisLength": length,
            "registeredImageAxisEndpoints": [
                [float(v) for v in hinge],
                [float(v) for v in image_free],
            ],
            "registeredPlateAxisEndpoints": [
                [float(v) for v in plate_hinge],
                [float(v) for v in plate_free_for_state],
            ],
            "opaqueBounds": _opaque_bounds(image),
            "maximumThickness": door["targetThickness"],
        }

    family_path = OUT / "office_door_family_v11.json"
    family_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"wrote 3 base and 3 hover door states to {OUT.relative_to(ROOT)}")
    print(
        f"hinge={tuple(hinge)} anchor={door['anchor']} displayScale={door['displayScale']} "
        f"closedLength={closed_length:.3f}px angle={angle:.3f}°"
    )


if __name__ == "__main__":
    main()

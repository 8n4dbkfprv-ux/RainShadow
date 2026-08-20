"""Extract the generated BG:EE edge-on door family with one hinge register.

Closed/mid/open are the same wall-axis timber sliver at increasing lengths.
The source is original ImageGen wall wood projected onto the 3:29 PM close-up
parallelogram (hinge upper-right, free end lower-left, slope −0.75). Screenshot
pixels are never copied.
"""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "ArtSource/Generated/Office/BGEETavernV10"
OUT = SOURCE / "Props"
GEOMETRY = json.loads((SOURCE / "office_v10_geometry.json").read_text(encoding="utf-8"))
CANVAS = tuple(GEOMETRY["door"]["liveCanvas"])
HINGE = tuple(GEOMETRY["door"]["hingePixels"])
WALL_WOOD = SOURCE / "wall_material_source_v10.png"
FLOOR_WOOD = SOURCE / "floor_material_source_v10.png"
WALL_AXIS_ANGLE = 36.86989765

# Closed length ≈ openingPixels[0] / display scale (125 / 0.443 ≈ 282) so the
# installed sliver spans the cutaway instead of reading as an 88px 5° stub.
STATES = {
    "closed": (SOURCE / "door_closed_edge_source_v10.png", 282, WALL_AXIS_ANGLE),
    "mid": (SOURCE / "door_mid_edge_source_v10.png", 360, WALL_AXIS_ANGLE),
    "open": (SOURCE / "door_open_edge_source_v10.png", 442, WALL_AXIS_ANGLE),
}


def _bilinear(texture: np.ndarray, u: np.ndarray, v: np.ndarray) -> np.ndarray:
    h, w = texture.shape[:2]
    x = np.clip(u, 0.0, 1.0) * (w - 1)
    y = np.clip(v, 0.0, 1.0) * (h - 1)
    x0 = np.floor(x).astype(np.int32)
    y0 = np.floor(y).astype(np.int32)
    x1 = np.minimum(x0 + 1, w - 1)
    y1 = np.minimum(y0 + 1, h - 1)
    fx = (x - x0)[..., None]
    fy = (y - y0)[..., None]
    top = texture[y0, x0] * (1.0 - fx) + texture[y0, x1] * fx
    bottom = texture[y1, x0] * (1.0 - fx) + texture[y1, x1] * fx
    return top * (1.0 - fy) + bottom * fy


def _write_timber_sliver(path: Path, wood: np.ndarray) -> None:
    """Paint a thin edge-on leaf: pale-gray field, dark timber parallelogram."""
    width, height = 1400, 900
    canvas = np.full((height, width, 3), 214.0, dtype=np.float32)
    hinge = np.array([1188.0, 78.0], dtype=np.float32)
    direction = np.array([-1.0, 0.75], dtype=np.float32)
    direction /= float(np.linalg.norm(direction))
    length = 1020.0
    thickness = 92.0
    perp = np.array([-direction[1], direction[0]], dtype=np.float32)
    if perp[1] > 0:
        perp = -perp

    p0 = hinge
    p1 = hinge + direction * length
    p2 = p1 + perp * thickness
    p3 = p0 + perp * thickness
    pts = np.stack([p0, p1, p2, p3])

    x0 = max(0, int(np.floor(pts[:, 0].min())) - 1)
    x1 = min(width, int(np.ceil(pts[:, 0].max())) + 2)
    y0 = max(0, int(np.floor(pts[:, 1].min())) - 1)
    y1 = min(height, int(np.ceil(pts[:, 1].max())) + 2)
    yy, xx = np.mgrid[y0:y1, x0:x1]
    origin = xx.astype(np.float32) - hinge[0]
    along = yy.astype(np.float32) - hinge[1]
    u = origin * direction[0] + along * direction[1]
    v = origin * perp[0] + along * perp[1]
    mask = (u >= 0.0) & (u <= length) & (v >= 0.0) & (v <= thickness)

    tu = np.clip(u / length, 0.0, 1.0)
    tv = np.clip(v / thickness, 0.0, 1.0)
    rgb = _bilinear(wood, tu * 0.92 + 0.04, tv * 0.55 + 0.22)
    # Top-edge highlight and underside shadow, matching the close-up.
    highlight = np.clip(1.0 - tv / 0.18, 0.0, 1.0)
    shade = np.clip(tv / 0.85, 0.0, 1.0)
    rgb = rgb * (0.82 + 0.48 * highlight[..., None] - 0.18 * shade[..., None])
    rgb += highlight[..., None] * np.array([42.0, 26.0, 10.0])
    patch = canvas[y0:y1, x0:x1]
    patch[mask] = np.clip(rgb[mask], 0, 255)

    Image.fromarray(np.clip(canvas, 0, 255).astype(np.uint8), "RGB").save(path)


def _extract(path: Path) -> tuple[Image.Image, tuple[int, int]]:
    rgb = np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]], axis=0)
    background = np.median(border, axis=0)
    distance = np.linalg.norm(rgb - background, axis=2)
    alpha = np.clip((distance - 14.0) * 11.0, 0.0, 255.0)
    hard = alpha > 32
    ys, xs = np.where(hard)
    if len(xs) == 0:
        raise ValueError(f"no timber silhouette found in {path}")
    x0, x1 = max(0, xs.min() - 3), min(rgb.shape[1], xs.max() + 4)
    y0, y1 = max(0, ys.min() - 3), min(rgb.shape[0], ys.max() + 4)
    rgba = np.dstack([rgb, alpha]).astype(np.uint8)[y0:y1, x0:x1]
    image = Image.fromarray(rgba, "RGBA")

    local_alpha = np.asarray(image.getchannel("A"))
    ly, lx = np.where(local_alpha > 48)
    right_band = lx >= lx.max() - max(2, round(image.width * 0.012))
    hinge_x = int(np.median(lx[right_band]))
    hinge_y = int(np.median(ly[right_band]))
    return image, (hinge_x, hinge_y)


def _registered(path: Path, target_length: int, target_angle: float) -> Image.Image:
    image, source_hinge = _extract(path)
    alpha = np.asarray(image.getchannel("A"))
    ys, xs = np.where(alpha > 48)
    vectors = np.column_stack((xs - source_hinge[0], ys - source_hinge[1]))
    source_length = float(np.linalg.norm(vectors, axis=1).max())
    scale = target_length / source_length
    size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
    image = image.resize(size, Image.Resampling.LANCZOS)
    image = image.filter(ImageFilter.GaussianBlur(0.18))
    hinge = (round(source_hinge[0] * scale), round(source_hinge[1] * scale))
    left = HINGE[0] - hinge[0]
    top = HINGE[1] - hinge[1]
    canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    canvas.alpha_composite(image, (left, top))
    points = np.column_stack(np.where(np.asarray(canvas.getchannel("A")) > 16)[::-1])
    far = points[np.linalg.norm(points - np.asarray(HINGE), axis=1).argmax()]
    vector = far - np.asarray(HINGE)
    current_angle = np.degrees(np.arctan2(vector[1], -vector[0]))
    return canvas.rotate(
        target_angle - current_angle,
        resample=Image.Resampling.BICUBIC,
        center=HINGE,
    )


def _hover(image: Image.Image) -> Image.Image:
    rgba = np.asarray(image, dtype=np.uint8).copy()
    rgb = rgba[:, :, :3].astype(np.float32)
    alpha = rgba[:, :, 3]
    lift = np.array([4.0, 22.0, 22.0], dtype=np.float32)
    rgb = np.clip(rgb * np.array([0.96, 1.08, 1.08]) + lift, 0, 255)
    opaque = alpha >= 46
    padded = np.pad(opaque, 1, mode="constant")
    neighbour_min = np.stack(
        [
            padded[1:-1, 0:-2],
            padded[1:-1, 2:],
            padded[:-2, 1:-1],
            padded[2:, 1:-1],
        ],
        axis=0,
    ).min(axis=0)
    inner_rim = opaque & ~neighbour_min
    rgb[inner_rim] = np.array([0.0, 252.0, 252.0])
    rgba[:, :, :3] = np.where(opaque[..., None], rgb, 0).astype(np.uint8)
    rgba[:, :, 3] = alpha
    return Image.fromarray(rgba, "RGBA")


def main() -> None:
    wood_path = WALL_WOOD if WALL_WOOD.exists() else FLOOR_WOOD
    floor_path = FLOOR_WOOD if FLOOR_WOOD.exists() else wood_path
    wall = np.asarray(Image.open(wood_path).convert("RGB"), dtype=np.float32)
    floor = np.asarray(Image.open(floor_path).convert("RGB"), dtype=np.float32)
    wood = np.clip(floor * 0.62 + wall * 0.38, 0, 255)
    wood = np.clip(wood * 1.18 + np.array([22.0, 12.0, 2.0]), 0, 255)
    for path, _, _ in STATES.values():
        _write_timber_sliver(path, wood)

    OUT.mkdir(parents=True, exist_ok=True)
    manifest: dict[str, object] = {
        "canvas": list(CANVAS),
        "hingeImageXY": list(HINGE),
        "anchorFromBottomLeft": [HINGE[0] / CANVAS[0], 1.0 - HINGE[1] / CANVAS[1]],
        "states": {},
        "sourcePolicy": "original ImageGen wall timber; close-up used for hinge/angle/thickness only",
    }
    for state, (path, length, angle) in STATES.items():
        image = _registered(path, length, angle)
        state_path = OUT / f"office_door_leaf_{state}_v10.png"
        image.save(state_path)
        if state in {"closed", "open"}:
            _hover(image).save(OUT / f"office_door_leaf_{state}_hover_v10.png")
        alpha = np.asarray(image.getchannel("A"))
        ys, xs = np.where(alpha > 16)
        manifest["states"][state] = {
            "source": path.name,
            "file": state_path.name,
            "opaqueBounds": [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())],
            "opaquePixels": int((alpha > 16).sum()),
            "targetLength": length,
            "targetAngleDegrees": angle,
        }
    (OUT / "office_door_family_v10.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    print(f"wrote {len(STATES)} registered states to {OUT.relative_to(ROOT)}")
    print(f"hinge={HINGE} anchor={manifest['anchorFromBottomLeft']}")


if __name__ == "__main__":
    main()

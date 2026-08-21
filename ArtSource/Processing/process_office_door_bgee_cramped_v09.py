"""Extract the generated BG:EE edge-on door family with one hinge register."""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "ArtSource/Generated/Office/BGEECrampedV09"
OUT = SOURCE / "Props"
GEOMETRY = json.loads((SOURCE / "office_v09_geometry.json").read_text(encoding="utf-8"))
CANVAS = tuple(GEOMETRY["door"]["liveCanvas"])
HINGE = tuple(GEOMETRY["door"]["hingePixels"])  # image coordinates, y down

STATES = {
    "closed": (SOURCE / "door_closed_edge_source_v09.png", 88, 5.0),
    "mid": (SOURCE / "door_mid_edge_source_v09.png", 278, 21.0),
    # The 36.87° state is the longest silhouette that fits below the fixed
    # upper-right hinge on the 512×320 contract without changing the canvas.
    "open": (SOURCE / "door_open_edge_source_v09.png", 442, 36.86989765),
}


def _extract(path: Path) -> tuple[Image.Image, tuple[int, int]]:
    rgb = np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)
    lum = rgb.mean(axis=2)
    # Built-in generation sometimes paints a checker preview instead of alpha.
    # The checker is near-white; the timber is comfortably below this range.
    alpha = np.clip((218.0 - lum) * 9.0, 0.0, 255.0)
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
    rgba[:, :, :3] = np.where((alpha > 0)[..., None], rgb, 0).astype(np.uint8)

    # V09 hover is colour treatment only: geometry and alpha are invariant.
    rgba[:, :, 3] = alpha
    return Image.fromarray(rgba, "RGBA")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    manifest: dict[str, object] = {
        "canvas": list(CANVAS),
        "hingeImageXY": list(HINGE),
        "anchorFromBottomLeft": [HINGE[0] / CANVAS[0], 1.0 - HINGE[1] / CANVAS[1]],
        "states": {},
    }
    for state, (path, length, angle) in STATES.items():
        image = _registered(path, length, angle)
        state_path = OUT / f"office_door_leaf_{state}_v09.png"
        image.save(state_path)
        if state in {"closed", "open"}:
            _hover(image).save(OUT / f"office_door_leaf_{state}_hover_v09.png")
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
    (OUT / "office_door_family_v09.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    print(f"wrote {len(STATES)} registered states to {OUT.relative_to(ROOT)}")
    print(f"hinge={HINGE} anchor={manifest['anchorFromBottomLeft']}")


if __name__ == "__main__":
    main()

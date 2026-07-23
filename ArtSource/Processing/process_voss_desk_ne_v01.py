"""Slice/chroma/register Voss NE seated desk chain into runtime atlases."""

from __future__ import annotations

import shutil
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
ASSETS = Path(
    "/Users/laurensvanoorschot/.cursor/projects/"
    "Users-laurensvanoorschot-Desktop-RainShadow/assets"
)
GEN = ROOT / "ArtSource" / "Generated" / "Characters" / "Detective" / "DeskNEV1"
IDLE_ATLAS = ROOT / "RainShadow Shared" / "Resources" / "Art" / "Atlases" / "VossSeatedIdle.atlas"
ARMS_ATLAS = ROOT / "RainShadow Shared" / "Resources" / "Art" / "Atlases" / "VossSeatedArms.atlas"
TRANS_ATLAS = ROOT / "RainShadow Shared" / "Resources" / "Art" / "Atlases" / "VossSeatTransitions.atlas"
OFFICE = ROOT / "RainShadow Shared" / "Resources" / "Art" / "Props" / "Office"

FRAME = 512
# Runtime atlases carry a 200px opaque body at 2x texture density
# (matches the original SE seated/transition registration: bbox 234..433).
BODY_H = 200
# Ground pivot y in 512 canvas (matches prior Voss registration band).
FOOT_Y = 433


def chroma_key(im: Image.Image, key=(0, 255, 0), tol=50.0, soft=18.0) -> Image.Image:
    rgba = np.array(im.convert("RGBA"), dtype=np.float32)
    rgb = rgba[:, :, :3]
    dist = np.linalg.norm(rgb - np.array(key, dtype=np.float32), axis=2)
    alpha = np.clip((dist - tol) / soft * 255.0, 0, 255)
    g, r, b = rgb[:, :, 1], rgb[:, :, 0], rgb[:, :, 2]
    greenish = (g > r + 18) & (g > b + 18) & (g > 40)
    mx, mn = rgb.max(axis=2), rgb.min(axis=2)
    green_dom = (g == mx) & ((g - mn) > 20) & (g > 35)
    alpha = np.where(greenish | green_dom, 0, alpha)
    spill = np.clip(1.0 - dist / (tol + soft + 40.0), 0, 1)
    lum = rgb.mean(axis=2, keepdims=True)
    rgb = rgb * (1.0 - spill[..., None] * 0.85) + lum * (spill[..., None] * 0.85)
    rgb = np.where(alpha[..., None] < 8, 0, rgb)
    return Image.fromarray(np.dstack([rgb, alpha]).astype(np.uint8), "RGBA")


def trim_alpha(im: Image.Image, threshold: int = 30, pad: int = 2) -> Image.Image:
    a = np.array(im.split()[-1])
    ys, xs = np.where(a > threshold)
    if len(xs) == 0:
        return im
    return im.crop(
        (
            max(0, int(xs.min()) - pad),
            max(0, int(ys.min()) - pad),
            min(im.width, int(xs.max()) + 1 + pad),
            min(im.height, int(ys.max()) + 1 + pad),
        )
    )


def slice_strip(path: Path, expected_min: int = 4) -> list[Image.Image]:
    sheet = chroma_key(Image.open(path))
    arr = np.array(sheet)
    a = arr[:, :, 3]
    # Column occupancy
    col = (a > 40).any(axis=0)
    cells: list[Image.Image] = []
    in_run = False
    start = 0
    for x, occ in enumerate(col):
        if occ and not in_run:
            in_run = True
            start = x
        elif not occ and in_run:
            in_run = False
            cell = trim_alpha(Image.fromarray(arr[:, start:x], "RGBA"))
            if cell.width * cell.height > 400:
                cells.append(cell)
    if in_run:
        cell = trim_alpha(Image.fromarray(arr[:, start:], "RGBA"))
        if cell.width * cell.height > 400:
            cells.append(cell)
    if len(cells) < expected_min:
        # Equal-width fallback
        n = max(expected_min, 4)
        w = sheet.width // n
        cells = [trim_alpha(chroma_key(sheet.crop((i * w, 0, (i + 1) * w, sheet.height)))) for i in range(n)]
    return cells


def register(im: Image.Image) -> Image.Image:
    im = trim_alpha(im)
    a = np.array(im.split()[-1])
    ys = np.where(a > 40)[0]
    h = max(1, int(ys.max() - ys.min() + 1))
    scale = BODY_H / h
    nw = max(1, int(round(im.width * scale)))
    nh = max(1, int(round(im.height * scale)))
    resized = im.resize((nw, nh), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    x = (FRAME - nw) // 2
    # Put feet near FOOT_Y
    y = FOOT_Y - nh
    y = max(0, min(FRAME - nh, y))
    out.alpha_composite(resized, (x, y))
    return out


def expand_to(frames: list[Image.Image], count: int) -> list[Image.Image]:
    if not frames:
        return frames
    if len(frames) >= count:
        return frames[:count]
    out = list(frames)
    i = 0
    while len(out) < count:
        out.append(frames[i % len(frames)])
        i += 1
    return out


def split_upper_lower(cell: Image.Image, lap_frac: float = 0.78) -> tuple[Image.Image, Image.Image]:
    """Split a registered seated cell on a horizontal feet seam.

    Upper = torso/fedora/arms + chair back (must stay camera-near / in front of
    the desk). Lower = only the under-desk feet / front chair legs that the
    kneehole apron should hide. Both keep the same 512 feet registration.
    """
    arr = np.array(cell.convert("RGBA"))
    a = arr[:, :, 3]
    ys = np.where(a > 40)[0]
    if len(ys) == 0:
        empty = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
        empty.putpixel((FRAME // 2, FRAME // 2), (0, 0, 0, 1))
        return empty.copy(), empty.copy()
    y0, y1 = int(ys.min()), int(ys.max())
    # Low seam: keep chair back with the upper layer for rear-view.
    seam = y0 + int((y1 - y0) * lap_frac)
    upper = arr.copy()
    upper[seam:, :, 3] = 0
    lower = arr.copy()
    lower[:seam, :, 3] = 0
    return Image.fromarray(upper, "RGBA"), Image.fromarray(lower, "RGBA")


def opaque_bbox(im: Image.Image, threshold: int = 40) -> tuple[int, int, int, int]:
    a = np.array(im.split()[-1])
    ys, xs = np.where(a > threshold)
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


def register_arms(im: Image.Image, idle_ref: Image.Image) -> Image.Image:
    """Register an arms-only cell as a small hands-band overlay.

    Contract from the original SE pair (idle body bbox 98w x 200h at 234..433;
    arms bbox 80w x 76h at 276..351): arms width ~0.82 of body width, bottom of
    the arms ~58.5% down the body, centered slightly left of the body center.
    """
    bx0, by0, bx1, by1 = opaque_bbox(idle_ref)
    body_w = bx1 - bx0 + 1
    body_h = by1 - by0 + 1
    body_cx = (bx0 + bx1) / 2

    im = trim_alpha(im)
    scale = (body_w * 0.82) / im.width
    nw = max(1, int(round(im.width * scale)))
    nh = max(1, int(round(im.height * scale)))
    resized = im.resize((nw, nh), Image.Resampling.LANCZOS)

    out = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    x = int(round(body_cx - 4 - nw / 2))
    y = int(round(by0 + body_h * 0.585 - nh))
    out.alpha_composite(resized, (max(0, x), max(0, y)))
    return out


def build_actor_occluder(bare_path: Path, seated_path: Path, out_path: Path) -> None:
    bare = np.array(Image.open(bare_path).convert("RGBA"))
    seated = Image.open(seated_path).convert("RGBA")
    # Place seated in the SW knee well (slightly left of desk center, low).
    canvas = Image.new("RGBA", (bare.shape[1], bare.shape[0]), (0, 0, 0, 0))
    target_h = int(bare.shape[0] * 0.50)
    scale = target_h / seated.height
    sw = max(1, int(seated.width * scale))
    sh = max(1, int(seated.height * scale))
    seated_r = seated.resize((sw, sh), Image.Resampling.LANCZOS)
    x = bare.shape[1] // 2 - sw // 2 - int(bare.shape[1] * 0.04)
    y = bare.shape[0] - sh - int(bare.shape[0] * 0.04)
    canvas.alpha_composite(seated_r, (max(0, x), max(0, y)))
    seated_a = np.array(canvas)[:, :, 3] > 40
    bare_a = bare[:, :, 3] > 40
    yy = np.arange(bare.shape[0])[:, None]
    # Tight lap band only (lower ~30% of seated silhouette) so the pedestal
    # cannot paint over the rear-view torso/fedora when this layer is in front.
    seated_ys = np.where(seated_a.any(axis=1))[0]
    if len(seated_ys) == 0:
        mask = bare_a & (yy > bare.shape[0] * 0.70)
    else:
        s0, s1 = int(seated_ys.min()), int(seated_ys.max())
        lap_cut = s0 + int((s1 - s0) * 0.70)
        lap = seated_a & (yy >= lap_cut)
        mask = bare_a & lap
    if mask.mean() < 0.005:
        mask = bare_a & (yy > bare.shape[0] * 0.72)
    out = bare.copy()
    out[:, :, 3] = np.where(mask, bare[:, :, 3], 0)
    Image.fromarray(out, "RGBA").save(out_path)
    print("actor occluder opaque%", float(mask.mean()))


def main() -> None:
    GEN.mkdir(parents=True, exist_ok=True)
    IDLE_ATLAS.mkdir(parents=True, exist_ok=True)
    ARMS_ATLAS.mkdir(parents=True, exist_ok=True)
    TRANS_ATLAS.mkdir(parents=True, exist_ok=True)

    # V2 rear-view strips: detective faces NE (into the desk, away from camera),
    # so the camera sees his back three-quarter — hands are part of the body.
    idle_src = ASSETS / "voss_seated_idle_ne_rear_strip_v02.png"
    stand_src = ASSETS / "voss_stand_up_ne_rear_strip_v02.png"
    for src in (idle_src, stand_src):
        if src.exists():
            shutil.copy(src, GEN / src.name)

    idle_cells = [register(c) for c in slice_strip(idle_src, 4)]
    idle_cells = expand_to(idle_cells, 8)
    for i, cell in enumerate(idle_cells):
        cell.save(GEN / f"voss_seated_idle_ne_{i:02d}.png")
        cell.save(IDLE_ATLAS / f"voss_seated_idle_ne_{i:02d}.png")
        # Keep SE names as aliases for any leftover references during transition.
        cell.save(IDLE_ATLAS / f"voss_seated_idle_se_{i:02d}.png")
        upper, lower = split_upper_lower(cell)
        upper.save(GEN / f"voss_seated_upper_ne_{i:02d}.png")
        lower.save(GEN / f"voss_seated_lower_ne_{i:02d}.png")
        upper.save(IDLE_ATLAS / f"voss_seated_upper_ne_{i:02d}.png")
        lower.save(IDLE_ATLAS / f"voss_seated_lower_ne_{i:02d}.png")

    # Rear view: the body sprite carries its own hands; the foreground-arms
    # overlay (front-view desk hands) must be empty or it doubles the arms.
    empty = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    # Single near-invisible pixel keeps atlas packing tools happy.
    empty.putpixel((FRAME // 2, FRAME // 2), (0, 0, 0, 1))
    for i in range(8):
        empty.save(GEN / f"voss_seated_arms_ne_{i:02d}.png")
        empty.save(ARMS_ATLAS / f"voss_seated_arms_ne_{i:02d}.png")
        empty.save(ARMS_ATLAS / f"voss_seated_arms_se_{i:02d}.png")

    stand_cells = [register(c) for c in slice_strip(stand_src, 8)]
    stand_cells = expand_to(stand_cells, 12)
    sit_cells = list(reversed(stand_cells))
    for i, cell in enumerate(stand_cells):
        cell.save(TRANS_ATLAS / f"voss_stand_up_ne_{i:02d}.png")
        cell.save(TRANS_ATLAS / f"voss_stand_up_se_{i:02d}.png")
    for i, cell in enumerate(sit_cells):
        cell.save(TRANS_ATLAS / f"voss_sit_down_ne_{i:02d}.png")
        cell.save(TRANS_ATLAS / f"voss_sit_down_se_{i:02d}.png")

    build_actor_occluder(
        OFFICE / "office_desk_bare.png",
        IDLE_ATLAS / "voss_seated_idle_ne_00.png",
        OFFICE / "office_desk_actor_occluder.png",
    )
    print("idle", len(idle_cells), "stand", len(stand_cells))


if __name__ == "__main__":
    main()

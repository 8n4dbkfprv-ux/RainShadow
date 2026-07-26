"""Raise V6 shell wall crowns + NE exterior doorway to classic BG ~1.94× adult.

Registration-locked edit of the approved V6 runtime plate:
  - grow wall face 348 → 440 (plaster band stretched upward)
  - cut NE doorway to plan size (~179×394, H/W ≈ 2.2) with wood casing
  - sample hall/plaster/wood from the existing plate (no pasted doorway modules)

Writes:
  ArtSource/Generated/Office/office_shell_base_v08.png
  RainShadow Shared/Resources/Art/Areas/DetectiveOffice/office_shell_base.png
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import office_room_plan as rp

ROOT = Path(__file__).resolve().parents[2]
SRC_RUNTIME = (
    ROOT
    / "RainShadow Shared"
    / "Resources"
    / "Art"
    / "Areas"
    / "DetectiveOffice"
    / "office_shell_base.png"
)
SRC_V06 = ROOT / "ArtSource/Generated/Office/office_shell_base_v06.png"
OUT_MASTER = ROOT / "ArtSource/Generated/Office/office_shell_base_v08.png"
OUT_RUNTIME = SRC_RUNTIME

ART_W, ART_H = 4096, 2304
OLD_FACE_H = 348.0
OLD_PLASTER_H = 227.0
RAISE = 92.0  # WALL_FACE_H 348 → 440
TARGET_DOOR_H = float(rp.BAKED_DOORWAY_H)
EXTERIOR_DOOR_B = 0.425
DOOR_HALF_B = rp.EXTERIOR_DOOR_OPENING_B * 0.5
WOOD = np.array([48.0, 34.0, 22.0], np.float32)
WOOD_LIT = np.array([78.0, 58.0, 38.0], np.float32)


def load_source() -> np.ndarray:
    if not SRC_V06.exists():
        raise SystemExit("Missing V6 shell master")
    master = Image.open(SRC_V06).convert("RGB")
    if master.size != (3840, 2160):
        master = master.resize((3840, 2160), Image.Resampling.LANCZOS)
    return np.asarray(master.resize((ART_W, ART_H), Image.Resampling.LANCZOS), np.float32)


def raise_wall_column(
    src: np.ndarray, dst: np.ndarray, x: int, top_fn, raise_px: float
) -> None:
    old_top = top_fn(float(x))
    base = old_top + OLD_FACE_H
    new_top = old_top - raise_px
    old_plaster_bot = old_top + OLD_PLASTER_H
    new_plaster_bot = new_top + OLD_PLASTER_H + raise_px

    y0 = max(0, int(np.floor(new_top)))
    y1 = min(ART_H, int(np.ceil(base)) + 1)
    for y in range(y0, y1):
        if y >= new_plaster_bot:
            t = (y - new_plaster_bot) / max(1e-3, base - new_plaster_bot)
            src_y = old_plaster_bot + t * (base - old_plaster_bot)
        else:
            t = (y - new_top) / max(1e-3, new_plaster_bot - new_top)
            src_y = old_top + t * (old_plaster_bot - old_top)
        sy = int(np.clip(round(src_y), 0, ART_H - 1))
        dst[y, x] = src[sy, x]


def sample_hall_color(src: np.ndarray) -> np.ndarray:
    samples = []
    for b in np.linspace(
        EXTERIOR_DOOR_B - DOOR_HALF_B * 0.7, EXTERIOR_DOOR_B + DOOR_HALF_B * 0.7, 9
    ):
        x, y = rp.plan(0.012, float(b))
        xi, yi = int(round(x)), int(round(y - 90))
        if 0 <= xi < ART_W and 0 <= yi < ART_H:
            samples.append(src[yi, xi])
    if not samples:
        return np.array([8.0, 7.0, 5.0], np.float32)
    return np.mean(samples, axis=0).astype(np.float32)


def _poly_mask(pts: list[tuple[float, float]], blur: float = 0.6) -> np.ndarray:
    im = Image.new("L", (ART_W, ART_H), 0)
    draw = ImageDraw.Draw(im)
    draw.polygon([(float(x), float(y)) for x, y in pts], fill=255)
    if blur > 0:
        im = im.filter(ImageFilter.GaussianBlur(blur))
    return np.asarray(im, np.float32) / 255.0


def enlarge_exterior_doorway(src: np.ndarray, dst: np.ndarray) -> None:
    """Cut a character-scale doorway shell with wood jambs / lintel / threshold."""
    hall = sample_hall_color(src)
    b0 = EXTERIOR_DOOR_B - DOOR_HALF_B
    b1 = EXTERIOR_DOOR_B + DOOR_HALF_B
    a_face, a_back = 0.0, 0.018

    # Ground + lintel corners on the NE wall face.
    g0 = rp.plan(a_face, b0)
    g1 = rp.plan(a_face, b1)
    # Keep floor contact on the pre-raise base so threshold stays on the boards.
    base0 = (0.463 * g0[0] + (-1290.0)) + OLD_FACE_H
    base1 = (0.463 * g1[0] + (-1290.0)) + OLD_FACE_H
    top0 = base0 - TARGET_DOOR_H
    top1 = base1 - TARGET_DOOR_H

    # Dark hall opening.
    hole = _poly_mask(
        [
            (g0[0], base0),
            (g1[0], base1),
            (g1[0], top1),
            (g0[0], top0),
        ],
        blur=0.5,
    )
    noise = (((np.mgrid[0:ART_H, 0:ART_W][0] * 7 + np.mgrid[0:ART_H, 0:ART_W][1] * 13) % 17) - 8) * 0.35
    hall_fill = np.clip(hall[None, None, :] + noise[..., None], 0, 45)
    a = hole[..., None]
    dst[:] = dst * (1.0 - a) + hall_fill * a

    # Wood casings (face trim).
    casing = 14.0
    jamb_w = 11.0
    # Header casing
    header = _poly_mask(
        [
            (g0[0] - 3, top0),
            (g1[0] + 3, top1),
            (g1[0] + 3, top1 - casing),
            (g0[0] - 3, top0 - casing),
        ],
        blur=0.4,
    )
    # Jamb casings
    j0 = _poly_mask(
        [
            (g0[0], base0),
            (g0[0] - jamb_w, base0 - jamb_w * 0.46),
            (g0[0] - jamb_w, top0 - jamb_w * 0.46),
            (g0[0], top0),
        ],
        blur=0.35,
    )
    j1 = _poly_mask(
        [
            (g1[0], base1),
            (g1[0] + jamb_w, base1 + jamb_w * 0.46),
            (g1[0] + jamb_w, top1 + jamb_w * 0.46),
            (g1[0], top1),
        ],
        blur=0.35,
    )
    # Threshold
    thresh = _poly_mask(
        [
            (g0[0] - 2, base0 + 2),
            (g1[0] + 2, base1 + 2),
            (g1[0] + 2, base1 + 10),
            (g0[0] - 2, base0 + 10),
        ],
        blur=0.5,
    )

    for mask, color in (
        (header, WOOD_LIT),
        (j0, WOOD),
        (j1, WOOD * 1.08),
        (thresh, WOOD * 0.85),
    ):
        m = mask[..., None]
        dst[:] = dst * (1.0 - m) + color[None, None, :] * m

    # Inner reveal (slightly lighter wood) for depth.
    reveal = _poly_mask(
        [
            (g0[0] + 2, base0 - 2),
            (g1[0] - 2, base1 - 2),
            (g1[0] - 2, top1 + 2),
            (g0[0] + 2, top0 + 2),
        ],
        blur=0.3,
    )
    # Only keep a thin ring: reveal minus eroded hole.
    ring = np.clip(reveal - hole * 0.92, 0, 1)
    m = ring[..., None] * 0.55
    dst[:] = dst * (1.0 - m) + (WOOD_LIT * 0.7)[None, None, :] * m


def raise_shell(src: np.ndarray) -> np.ndarray:
    dst = src.copy()
    for x in range(2400, 4000):
        top = 0.463 * x + (-1290.0)
        mid_y = int(np.clip(round(top + 40), 0, ART_H - 1))
        if float(src[mid_y, x].mean()) < 3.0:
            continue
        raise_wall_column(src, dst, x, lambda xx: 0.463 * xx + (-1290.0), RAISE)

    for x in range(200, 2600):
        top = -0.419 * x + 867.0
        mid_y = int(np.clip(round(top + 40), 0, ART_H - 1))
        if float(src[mid_y, x].mean()) < 3.0:
            continue
        raise_wall_column(src, dst, x, lambda xx: -0.419 * xx + 867.0, RAISE)

    enlarge_exterior_doorway(src, dst)

    im = Image.fromarray(np.clip(dst, 0, 255).astype(np.uint8), "RGB")
    blur = im.filter(ImageFilter.GaussianBlur(0.55))
    blur_a = np.asarray(blur, np.float32)
    for x in range(200, 4000):
        for top_fn in (
            lambda xx: 0.463 * xx + (-1290.0) - RAISE,
            lambda xx: -0.419 * xx + 867.0 - RAISE,
        ):
            top = top_fn(float(x))
            y0 = max(0, int(top) - 2)
            y1 = min(ART_H, int(top + OLD_PLASTER_H + RAISE * 0.35))
            if y1 <= y0:
                continue
            mid = src[int(np.clip(top + RAISE + 40, 0, ART_H - 1)), x].mean()
            if mid < 3.0:
                continue
            dst[y0:y1, x] = dst[y0:y1, x] * 0.7 + blur_a[y0:y1, x] * 0.3
    return dst


def measure_doorway(rgb: np.ndarray) -> float:
    x, _ = rp.plan(0.012, EXTERIOR_DOOR_B)
    xi = int(round(x))
    old_top = 0.463 * x + (-1290.0)
    base = old_top + OLD_FACE_H
    dark_top = None
    for y in range(int(base), max(0, int(base - 520)), -1):
        if float(rgb[y, xi].mean()) < 28:
            dark_top = y
        elif dark_top is not None and (base - dark_top) > 80:
            break
    if dark_top is None:
        return 0.0
    return float(base - dark_top)


def main() -> None:
    src = load_source()
    out = raise_shell(src)
    im = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB")
    OUT_MASTER.parent.mkdir(parents=True, exist_ok=True)
    im.save(OUT_MASTER)
    im.save(OUT_RUNTIME)
    h = measure_doorway(out)
    print(f"wrote {OUT_MASTER}")
    print(f"wrote {OUT_RUNTIME}")
    print(f"measured doorway opening H ≈ {h:.1f} px (target {TARGET_DOOR_H})")
    print(
        f"plan opening W≈{rp.EXTERIOR_DOOR_OPENING_B * rp.AXIS_NE[0]:.0f} "
        f"H/W≈{TARGET_DOOR_H / (rp.EXTERIOR_DOOR_OPENING_B * rp.AXIS_NE[0]):.2f}"
    )


if __name__ == "__main__":
    main()

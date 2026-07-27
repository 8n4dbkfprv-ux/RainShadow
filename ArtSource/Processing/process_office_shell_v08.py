"""Raise V6 shell wall crowns + NE exterior doorway from the shipped detective.

Registration-locked edit of the approved V6 runtime plate:
  - derive Voss's visible plate height from his real 200/512 × 232 presentation
  - grow the wall face 348 → 505 (plaster band stretched upward)
  - cut the clear doorway to ~202×445 (1.94× Voss, H/W ≈ 2.2)
  - leave decorative casing to the independent `office_door_frame` prop, so
    shell pixels and a freestanding frame do not draw two competing door shells
  - sample hall/plaster from the existing plate (no pasted doorway modules)

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
RAISE = float(rp.WALL_RAISE_FROM_V06)
TARGET_DOOR_H = float(rp.BAKED_DOORWAY_H)
EXTERIOR_DOOR_B = 0.425
DOOR_HALF_B = rp.EXTERIOR_DOOR_OPENING_B * 0.5


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
    """Cut the detective-relative aperture behind the independent frame prop."""
    hall = sample_hall_color(src)
    b0 = EXTERIOR_DOOR_B - DOOR_HALF_B
    b1 = EXTERIOR_DOOR_B + DOOR_HALF_B
    a_face, a_back = 0.0, 0.018

    # Ground + lintel corners on the NE wall face.
    g0 = rp.plan(a_face, b0)
    g1 = rp.plan(a_face, b1)
    # Keep floor contact on the pre-raise base so threshold stays on the boards.
    base0 = rp.ne_wall_base(g0[0])
    base1 = rp.ne_wall_base(g1[0])
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

    # A narrow recess shadow stays behind the generated frame. It gives the
    # opening wall thickness when the leaf is open without reading as a second
    # decorative jamb/header around the independent frame.
    reveal = _poly_mask(
        [
            (g0[0] - 3, base0 + 3),
            (g1[0] + 3, base1 + 3),
            (g1[0] + 3, top1 - 3),
            (g0[0] - 3, top0 - 3),
        ],
        blur=0.35,
    )
    ring = np.clip(reveal - hole, 0, 1)
    m = ring[..., None] * 0.55
    recess_color = np.clip(hall * 1.75, 0, 54)
    dst[:] = dst * (1.0 - m) + recess_color[None, None, :] * m


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
    base = rp.ne_wall_base(x)
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

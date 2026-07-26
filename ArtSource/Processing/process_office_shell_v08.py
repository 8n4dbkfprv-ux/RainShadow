"""Raise V6 shell wall crowns + NE exterior doorway to classic BG ~1.94× adult.

Registration-locked edit of the approved V6 runtime plate:
  - grow wall face 348 → 440 (plaster band stretched upward)
  - enlarge NE doorway opening to ~403 plate px
  - sample hall/plaster/wood from the existing plate (no pasted doorway modules)

Writes:
  ArtSource/Generated/Office/office_shell_base_v08.png
  RainShadow Shared/Resources/Art/Areas/DetectiveOffice/office_shell_base.png
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

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
TARGET_DOOR_H = 403.0
EXTERIOR_DOOR_B = 0.425
DOOR_HALF_B = rp.EXTERIOR_DOOR_OPENING_B * 0.5


def load_source() -> np.ndarray:
    """Prefer current runtime if it is still V6-sized; else resize V6 master."""
    if SRC_RUNTIME.exists():
        im = Image.open(SRC_RUNTIME).convert("RGB")
        if im.size == (ART_W, ART_H):
            return np.asarray(im, np.float32)
    if not SRC_V06.exists():
        raise SystemExit("Missing V6 shell master and runtime")
    master = Image.open(SRC_V06).convert("RGB")
    if master.size != (3840, 2160):
        master = master.resize((3840, 2160), Image.Resampling.LANCZOS)
    runtime = master.resize((ART_W, ART_H), Image.Resampling.LANCZOS)
    return np.asarray(runtime, np.float32)


def raise_wall_column(
    src: np.ndarray, dst: np.ndarray, x: int, top_fn, raise_px: float
) -> None:
    """Stretch plaster upward; keep wainscot height; floor contact fixed."""
    old_top = top_fn(float(x))
    base = old_top + OLD_FACE_H
    new_top = old_top - raise_px
    old_plaster_bot = old_top + OLD_PLASTER_H
    new_plaster_bot = new_top + OLD_PLASTER_H + raise_px

    y0 = max(0, int(np.floor(new_top)))
    y1 = min(ART_H, int(np.ceil(base)) + 1)
    for y in range(y0, y1):
        if y >= new_plaster_bot:
            # Wainscot / rail: same distance from base as before.
            src_y = base - (base - y)
            # Map new wainscot band onto old wainscot band.
            t = (y - new_plaster_bot) / max(1e-3, base - new_plaster_bot)
            src_y = old_plaster_bot + t * (base - old_plaster_bot)
        else:
            # Stretch old plaster into taller plaster.
            t = (y - new_top) / max(1e-3, new_plaster_bot - new_top)
            src_y = old_top + t * (old_plaster_bot - old_top)
        sy = int(np.clip(round(src_y), 0, ART_H - 1))
        dst[y, x] = src[sy, x]


def sample_hall_color(src: np.ndarray) -> np.ndarray:
    """Mean dark hall colour from the existing doorway void."""
    samples = []
    for b in np.linspace(EXTERIOR_DOOR_B - DOOR_HALF_B * 0.7, EXTERIOR_DOOR_B + DOOR_HALF_B * 0.7, 9):
        x, y = rp.plan(0.012, float(b))
        xi, yi = int(round(x)), int(round(y - 90))
        if 0 <= xi < ART_W and 0 <= yi < ART_H:
            samples.append(src[yi, xi])
    if not samples:
        return np.array([8.0, 7.0, 5.0], np.float32)
    return np.mean(samples, axis=0).astype(np.float32)


def sample_lintel_color(src: np.ndarray) -> np.ndarray:
    x, y = rp.plan(0.01, EXTERIOR_DOOR_B)
    xi = int(round(x))
    # Just above current short opening.
    yi = int(round(rp.ne_wall_base(x) - 230))
    yi = int(np.clip(yi, 0, ART_H - 1))
    xi = int(np.clip(xi, 0, ART_W - 1))
    return src[yi, xi].copy()


def enlarge_exterior_doorway(src: np.ndarray, dst: np.ndarray) -> None:
    hall = sample_hall_color(src)
    lintel = sample_lintel_color(src)
    wood = np.array([42.0, 30.0, 18.0], np.float32)
    b0 = EXTERIOR_DOOR_B - DOOR_HALF_B
    b1 = EXTERIOR_DOOR_B + DOOR_HALF_B

    # Slightly overscan in b so jambs stay clean.
    for b in np.linspace(b0 - 0.004, b1 + 0.004, 220):
        # Face just inside the NE wall.
        for a in (0.0, 0.008, 0.016, 0.024):
            x, y_ground = rp.plan(a, float(b))
            xi = int(round(x))
            if not (0 <= xi < ART_W):
                continue
            base = rp.ne_wall_base(x) if a < 0.001 else y_ground + 4.0
            # When plan constants still say OLD face, use geometric base from V6 top.
            old_top = 0.463 * x + (-1290.0)
            base = old_top + OLD_FACE_H
            open_top = base - TARGET_DOOR_H
            # Doorway interior band.
            inside = b0 + 0.006 <= b <= b1 - 0.006
            for y in range(max(0, int(open_top)), min(ART_H, int(base) + 1)):
                if inside and y >= open_top + 10:
                    # Soft noise so hall is not a flat fill.
                    n = ((xi * 13 + y * 7) % 17) - 8
                    dst[y, xi] = np.clip(hall + n * 0.35, 0, 40)
                elif inside and open_top <= y < open_top + 10:
                    # Header / lintel strip.
                    t = (y - open_top) / 10.0
                    dst[y, xi] = lintel * (1.0 - t) + wood * t * 0.55 + hall * t * 0.45
                elif not inside and open_top - 6 <= y < base:
                    # Jamb trim.
                    dst[y, xi] = wood * 0.85 + lintel * 0.15


def raise_shell(src: np.ndarray) -> np.ndarray:
    dst = src.copy()
    # NE wall run (where exterior door lives).
    for x in range(2400, 4000):
        # Only edit columns that still look like wall / room (not pure exterior black).
        top = 0.463 * x + (-1290.0)
        base = top + OLD_FACE_H
        mid_y = int(np.clip(round(top + 40), 0, ART_H - 1))
        if float(src[mid_y, x].mean()) < 3.0:
            continue
        raise_wall_column(src, dst, x, lambda xx: 0.463 * xx + (-1290.0), RAISE)

    # NW wall run (keep window recess relative: stretch plaster above sill only).
    for x in range(200, 2600):
        top = -0.419 * x + 867.0
        mid_y = int(np.clip(round(top + 40), 0, ART_H - 1))
        if float(src[mid_y, x].mean()) < 3.0:
            continue
        raise_wall_column(src, dst, x, lambda xx: -0.419 * xx + 867.0, RAISE)

    enlarge_exterior_doorway(src, dst)

    # Mild blur on the raised crown seam to avoid a hard stretch band.
    im = Image.fromarray(np.clip(dst, 0, 255).astype(np.uint8), "RGB")
    blur = im.filter(ImageFilter.GaussianBlur(0.6))
    blur_a = np.asarray(blur, np.float32)
    # Blend blur only near new crowns.
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
            dst[y0:y1, x] = dst[y0:y1, x] * 0.65 + blur_a[y0:y1, x] * 0.35

    return dst


def measure_doorway(rgb: np.ndarray) -> float:
    x, _ = rp.plan(0.012, EXTERIOR_DOOR_B)
    xi = int(round(x))
    old_top = 0.463 * x + (-1290.0)
    base = old_top + OLD_FACE_H
    # After raise, base stays; opening top is darker.
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
    # If runtime was already raised, rebuild from V6 master.
    if SRC_V06.exists():
        master = Image.open(SRC_V06).convert("RGB")
        if master.size != (3840, 2160):
            master = master.resize((3840, 2160), Image.Resampling.LANCZOS)
        src = np.asarray(master.resize((ART_W, ART_H), Image.Resampling.LANCZOS), np.float32)

    out = raise_shell(src)
    im = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB")
    OUT_MASTER.parent.mkdir(parents=True, exist_ok=True)
    im.save(OUT_MASTER)
    im.save(OUT_RUNTIME)
    h = measure_doorway(out)
    print(f"wrote {OUT_MASTER}")
    print(f"wrote {OUT_RUNTIME}")
    print(f"measured doorway opening H ≈ {h:.1f} px (target {TARGET_DOOR_H})")
    print(f"wall face target {OLD_FACE_H + RAISE:.0f} px")


if __name__ == "__main__":
    main()

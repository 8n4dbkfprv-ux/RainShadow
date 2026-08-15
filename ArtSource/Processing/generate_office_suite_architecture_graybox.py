"""Paint partitioned-suite graybox architecture from shell materials.

Clean BG:EE orthographic wall planes only (see ie_projection):
  - One continuous low cutaway foreground wall (left shell → partition → right shell)
  - One straight partition plane with constant thickness and a framed doorway
  - Frosted internal door leaf aligned to the same plane
  - Lower wainscot band matching shell language

No triangular spikes, zigzag caps, or disconnected beams.
Doorway gap is authored by omission (draw wall segments only) — never AABB-punched.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import ie_projection as ie

ROOT = Path(__file__).resolve().parents[2]
SHELL = ROOT / "RainShadow Shared/Resources/Art/Areas/DetectiveOffice/office_shell_base.png"
OUT_FINAL = ROOT / "RainShadow Shared/Resources/Art/Props/Office/office_suite_architecture.png"
OUT_GRAYBOX = ROOT / "RainShadow Shared/Resources/Art/Props/Office/office_suite_architecture_graybox.png"
GEN = ROOT / "ArtSource/Generated/Office/Props/office_suite_architecture.png"
GEN_GRAYBOX = ROOT / "ArtSource/Generated/Office/Props/office_suite_architecture_graybox.png"
LEGACY_BEAM = ROOT / "RainShadow Shared/Resources/Art/Props/Office/office_foreground_wall_graybox.png"

ART_W, ART_H = 4096, 2304

FG_X0, FG_Y0, FG_W, FG_H = 1_100, 400, 2_100, 200
PART_X, PART_W = 2_480, 100
PART_Y0, PART_Y1 = 650, 1_720
DOOR_Y0, DOOR_Y1 = 1_100, 1_450

# ~18% lower than the approved graybox face so the cutaway frames without dominating.
# Face heights are screen-space (already foreshortened under the BG:EE camera).
FG_FACE_H = 88
PART_FACE_H = 260


def iy(ay: float) -> float:
    return ART_H - ay


def sample(shell: np.ndarray, box: tuple[int, int, int, int]) -> tuple[int, int, int]:
    x0, y0, x1, y1 = box
    mean = shell[y0:y1, x0:x1, :3].astype(np.float32).mean(axis=(0, 1))
    return int(mean[0]), int(mean[1]), int(mean[2])


def shade(rgb: tuple[int, int, int], delta: int) -> tuple[int, int, int]:
    return tuple(max(0, min(255, c + delta)) for c in rgb)  # type: ignore[return-value]


def iso_box_ew(
    draw: ImageDraw.ImageDraw,
    x0: float,
    x1: float,
    y_ground: float,
    face_h: float,
    thick: float,
    plaster: tuple[int, int, int],
    wainscot: tuple[int, int, int],
    trim: tuple[int, int, int],
    wain_frac: float = 0.46,
) -> None:
    """East–west cutaway wall: constant height, flat top, square ends."""
    shear = ie.ground_shear_for_height(face_h)
    g0 = (x0, iy(y_ground))
    g1 = (x1, iy(y_ground))
    s0 = (x0 - shear, iy(y_ground) - face_h)
    s1 = (x1 - shear, iy(y_ground) - face_h)
    n0 = (x0 - shear, iy(y_ground + thick) - face_h)
    n1 = (x1 - shear, iy(y_ground + thick) - face_h)
    ng0 = (x0, iy(y_ground + thick))
    ng1 = (x1, iy(y_ground + thick))

    draw.polygon([s0, s1, n1, n0], fill=shade(plaster, -22) + (250,))
    draw.polygon([g0, g1, s1, s0], fill=plaster + (252,))
    wh = face_h * wain_frac
    w_shear = ie.ground_shear_for_height(wh)
    w0 = (x0 - w_shear, iy(y_ground) - wh)
    w1 = (x1 - w_shear, iy(y_ground) - wh)
    draw.polygon([g0, g1, w1, w0], fill=wainscot + (254,))
    draw.polygon([g0, ng0, n0, s0], fill=shade(plaster, -12) + (252,))
    draw.polygon([g1, ng1, n1, s1], fill=shade(plaster, -8) + (252,))
    draw.line([w0, w1], fill=trim + (255,), width=3)
    draw.line([s0, s1], fill=trim + (255,), width=3)


def iso_box_ns(
    draw: ImageDraw.ImageDraw,
    x: float,
    y0: float,
    y1: float,
    face_h: float,
    thick: float,
    plaster: tuple[int, int, int],
    wainscot: tuple[int, int, int],
    trim: tuple[int, int, int],
    wain_frac: float = 0.34,
    draw_south_cap: bool = True,
    draw_north_cap: bool = True,
) -> None:
    """North–south partition segment: constant thickness, flat top, square caps."""
    if y1 < y0:
        y0, y1 = y1, y0
    shear = ie.ground_shear_for_height(face_h)
    g0 = (x, iy(y0))
    g1 = (x, iy(y1))
    t0 = (x - shear, iy(y0) - face_h)
    t1 = (x - shear, iy(y1) - face_h)
    eg0 = (x + thick, iy(y0))
    eg1 = (x + thick, iy(y1))
    et0 = (x + thick - shear, iy(y0) - face_h)
    et1 = (x + thick - shear, iy(y1) - face_h)

    draw.polygon([t0, t1, et1, et0], fill=shade(plaster, -22) + (250,))
    draw.polygon([g0, g1, t1, t0], fill=plaster + (252,))
    wh = face_h * wain_frac
    w_shear = ie.ground_shear_for_height(wh)
    w0 = (x - w_shear, iy(y0) - wh)
    w1 = (x - w_shear, iy(y1) - wh)
    draw.polygon([g0, g1, w1, w0], fill=wainscot + (254,))
    draw.polygon([eg0, eg1, et1, et0], fill=shade(plaster, -14) + (252,))
    if draw_south_cap:
        draw.polygon([g0, eg0, et0, t0], fill=shade(plaster, -10) + (252,))
    if draw_north_cap:
        draw.polygon([g1, eg1, et1, t1], fill=shade(plaster, -6) + (252,))
    draw.line([w0, w1], fill=trim + (255,), width=3)
    draw.line([t0, t1], fill=trim + (255,), width=3)


def main() -> None:
    shell_im = Image.open(SHELL).convert("RGBA")
    if shell_im.size != (ART_W, ART_H):
        shell_im = shell_im.resize((ART_W, ART_H), Image.Resampling.LANCZOS)
    shell = np.array(shell_im)

    plaster = sample(shell, (620, 420, 980, 780))
    wainscot = sample(shell, (640, 980, 980, 1280))
    trim = sample(shell, (700, 1280, 980, 1380))
    plaster = (min(255, plaster[0] + 10), min(255, plaster[1] + 6), min(255, plaster[2] + 4))
    wainscot = (max(0, wainscot[0] - 4), max(0, wainscot[1] - 3), max(0, wainscot[2] - 2))

    im = Image.new("RGBA", (ART_W, ART_H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im, "RGBA")

    fg_ground = float(FG_Y0 + FG_H)
    fg_x1 = float(FG_X0 + FG_W)

    # Continuous foreground cutaway (left shell → partition → right shell)
    iso_box_ew(
        draw,
        float(FG_X0),
        fg_x1,
        fg_ground,
        FG_FACE_H,
        float(FG_H) * 0.55,
        plaster,
        wainscot,
        trim,
    )

    # Partition solids — doorway exists by omission (no AABB punch)
    iso_box_ns(
        draw,
        float(PART_X),
        float(PART_Y0),
        float(DOOR_Y0),
        PART_FACE_H,
        float(PART_W),
        plaster,
        wainscot,
        trim,
        draw_north_cap=True,  # square jamb face at doorway
    )
    iso_box_ns(
        draw,
        float(PART_X),
        float(DOOR_Y1),
        float(PART_Y1),
        PART_FACE_H,
        float(PART_W),
        plaster,
        wainscot,
        trim,
        draw_south_cap=True,  # square jamb face at doorway
    )

    # Lintel: short face + flat top across the opening (no extrusion into the gap)
    lintel_face = 48.0
    lintel_shear = ie.ground_shear_for_height(lintel_face)
    lx0 = float(PART_X)
    lx1 = float(PART_X + PART_W)
    ly = float(DOOR_Y1)
    g0 = (lx0, iy(ly))
    g1 = (lx1, iy(ly))
    t0 = (lx0 - lintel_shear, iy(ly) - lintel_face)
    t1 = (lx1 - lintel_shear, iy(ly) - lintel_face)
    t2 = (lx1 + PART_W - lintel_shear, iy(ly) - lintel_face)
    t3 = (lx0 + PART_W - lintel_shear, iy(ly) - lintel_face)
    draw.polygon([g0, g1, t1, t0], fill=plaster + (252,))
    draw.polygon([t0, t1, t2, t3], fill=shade(plaster, -22) + (250,))
    draw.line([t0, t1], fill=trim + (255,), width=3)

    # Door leaf is a separate runtime prop (`office_internal_door_leaf`) so the
    # wall plate stays a clean partition + FG cutaway only.

    im = im.filter(ImageFilter.GaussianBlur(radius=0.2))
    arr = np.array(im)
    a = arr[:, :, 3]
    arr[:, :, 3] = np.where(a > 8, np.maximum(a, 240), 0)
    im = Image.fromarray(arr, "RGBA")

    OUT_FINAL.parent.mkdir(parents=True, exist_ok=True)
    GEN.parent.mkdir(parents=True, exist_ok=True)
    im.save(OUT_FINAL)
    im.save(OUT_GRAYBOX)  # keep graybox alias for any leftover loaders
    im.save(GEN)
    im.save(GEN_GRAYBOX)
    Image.new("RGBA", (ART_W, ART_H), (0, 0, 0, 0)).save(LEGACY_BEAM)

    a = np.array(im)[:, :, 3]
    ys, xs = np.where(a > 20)
    gap = a[int(iy(DOOR_Y1 - 20)) : int(iy(DOOR_Y0 + 20)), PART_X + 20 : PART_X + PART_W - 20]
    print(
        f"wrote {OUT_FINAL.name} opaque={(a > 20).sum()} "
        f"authoredY={ART_H - ys.max()}..{ART_H - ys.min()} "
        f"doorGapOpaque={(gap > 20).mean():.3f}"
    )


if __name__ == "__main__":
    main()

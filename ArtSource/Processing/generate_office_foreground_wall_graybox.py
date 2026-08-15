"""Paint a temporary L-shaped foreground wall graybox from shell materials.

Footprint matches OfficeNavigationLayout foreground obstacles. Visual height is
kept short so the wall frames ~lower 20–25% of the play view, not half the plate.
Uses the Baldur's Gate: EE ground slope from ie_projection.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import ie_projection as ie

ROOT = Path(__file__).resolve().parents[2]
SHELL = ROOT / "RainShadow Shared/Resources/Art/Areas/DetectiveOffice/office_shell_base.png"
OUT = ROOT / "RainShadow Shared/Resources/Art/Props/Office/office_foreground_wall_graybox.png"
GEN = ROOT / "ArtSource/Generated/Office/Props/office_foreground_wall_graybox.png"

ART_W, ART_H = 4096, 2304

# Authored SK y-up footprint (must match OfficeNavigationLayout).
# Kept camera-near so the face stays in the lower ~20–25% of play view.
NEAR = (1_080, 360, 1_780, 220)  # x, y, w, h → y 360–580
WEST = (1_080, 580, 200, 220)  # x 1080–1280, y 580–800
# Screen extrusion in image pixels (short — framing strip, not half-room).
NEAR_HEIGHT = 130
WEST_HEIGHT = 120


def to_img_y(authored_y: float) -> float:
    return ART_H - authored_y


def sample_shell(shell: np.ndarray, box: tuple[int, int, int, int]) -> tuple[int, int, int]:
    x0, y0, x1, y1 = box
    patch = shell[y0:y1, x0:x1, :3].astype(np.float32)
    mean = patch.mean(axis=(0, 1))
    return int(mean[0]), int(mean[1]), int(mean[2])


def wall_run(
    draw: ImageDraw.ImageDraw,
    x0: int,
    y0_auth: int,
    x1: int,
    y1_auth: int,
    height: int,
    plaster: tuple[int, int, int],
    wainscot: tuple[int, int, int],
    trim: tuple[int, int, int],
) -> None:
    """Draw a BG:EE wall segment along a ground line in authored space."""
    g0 = (x0, to_img_y(y0_auth))
    g1 = (x1, to_img_y(y1_auth))
    shear = ie.ground_shear_for_height(height)
    # Top edge parallel, shifted up on screen by `height` with ground-slope shear.
    t0 = (g0[0] - shear, g0[1] - height)
    t1 = (g1[0] - shear, g1[1] - height)
    # Face
    draw.polygon([g0, g1, t1, t0], fill=plaster + (245,))
    # Wainscot band along lower third of face
    wain_h = int(height * 0.38)
    w_shear = ie.ground_shear_for_height(wain_h)
    w0 = (g0[0] - w_shear, g0[1] - wain_h)
    w1 = (g1[0] - w_shear, g1[1] - wain_h)
    draw.polygon([g0, g1, w1, w0], fill=wainscot + (250,))
    # Trim line
    draw.line([w0, w1], fill=trim + (255,), width=4)
    # Top cap
    draw.line([t0, t1], fill=trim + (255,), width=3)
    # End caps (join to shell side walls)
    draw.polygon(
        [g0, t0, (t0[0] - 18, t0[1] + 10), (g0[0] - 12, g0[1] + 6)],
        fill=tuple(max(0, c - 18) for c in plaster) + (240,),
    )


def main() -> None:
    shell_im = Image.open(SHELL).convert("RGBA")
    if shell_im.size != (ART_W, ART_H):
        shell_im = shell_im.resize((ART_W, ART_H), Image.Resampling.LANCZOS)
    shell = np.array(shell_im)

    plaster = sample_shell(shell, (620, 420, 980, 780))
    wainscot = sample_shell(shell, (640, 980, 980, 1280))
    trim = sample_shell(shell, (700, 1280, 980, 1380))
    # Nudge toward readable graybox (slightly cooler plaster)
    plaster = (min(255, plaster[0] + 8), min(255, plaster[1] + 6), min(255, plaster[2] + 4))
    wainscot = (max(0, wainscot[0] - 10), max(0, wainscot[1] - 8), max(0, wainscot[2] - 6))

    im = Image.new("RGBA", (ART_W, ART_H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im, "RGBA")

    nx, ny, nw, nh = NEAR
    wall_run(draw, nx, ny, nx + nw, ny + nh, NEAR_HEIGHT, plaster, wainscot, trim)

    wx, wy, ww, wh = WEST
    wall_run(draw, wx, wy, wx + ww, wy + wh, WEST_HEIGHT, plaster, wainscot, trim)

    # Soften edges; keep footprint opaque
    im = im.filter(ImageFilter.GaussianBlur(radius=0.6))
    arr = np.array(im)
    a = arr[:, :, 3]
    arr[:, :, 3] = np.where(a > 12, np.maximum(a, 235), 0)
    im = Image.fromarray(arr, "RGBA")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    GEN.parent.mkdir(parents=True, exist_ok=True)
    im.save(OUT)
    im.save(GEN)
    ys, xs = np.where(arr[:, :, 3] > 20)
    print(
        f"wrote {OUT} opaque={(arr[:,:,3]>20).sum()} "
        f"authoredY={ART_H-ys.max()}..{ART_H-ys.min()} x={xs.min()}..{xs.max()}"
    )


if __name__ == "__main__":
    main()

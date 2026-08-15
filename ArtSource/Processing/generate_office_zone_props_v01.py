"""Generate missing 3-zone office props + lighting overlays as runtime PNGs.

Produces late-1990s isometric CRPG-readable sprites (noir palette, soft baked
shading) for props that have no Image-Generator masters yet. Box geometry uses
the Baldur's Gate: EE ground foreshortening from ie_projection. Outputs land in
Resources/Art/Props/Office/ and also copy RGBA masters under ArtSource/Generated.
"""

from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import ie_projection as ie


ROOT = Path(__file__).resolve().parents[2]
RUNTIME = ROOT / "RainShadow Shared" / "Resources" / "Art" / "Props" / "Office"
GEN = ROOT / "ArtSource" / "Generated" / "Office" / "Props"


def save(im: Image.Image, name: str) -> None:
    RUNTIME.mkdir(parents=True, exist_ok=True)
    GEN.mkdir(parents=True, exist_ok=True)
    path = RUNTIME / f"{name}.png"
    im.save(path)
    im.save(GEN / f"{name}_rgba_v01.png")
    print(f"wrote {path.relative_to(ROOT)} ({im.size[0]}x{im.size[1]})")


def canvas(size: tuple[int, int]) -> Image.Image:
    return Image.new("RGBA", size, (0, 0, 0, 0))


def shade(base: tuple[int, int, int], factor: float) -> tuple[int, int, int, int]:
    return (
        max(0, min(255, int(base[0] * factor))),
        max(0, min(255, int(base[1] * factor))),
        max(0, min(255, int(base[2] * factor))),
        255,
    )


def iso_box(
    draw: ImageDraw.ImageDraw,
    cx: int,
    cy: int,
    w: int,
    d: int,
    h: int,
    color: tuple[int, int, int],
) -> None:
    """BG:EE box: top + left + right faces. (cx, cy) = near ground center.

    `h` is screen-space height (already foreshortened). Ground extents use
    foreshortening 0.75 so a square footprint reads as a 16:12 rhombus.
    """
    pts = ie.iso_box_points(cx, cy, w, d, h)
    draw.polygon([pts["fl"], pts["nl"], pts["gnl"], pts["gfl"]], fill=shade(color, 0.55))
    draw.polygon([pts["nl"], pts["nr"], pts["gnr"], pts["gnl"]], fill=shade(color, 0.78))
    draw.polygon([pts["nr"], pts["fr"], pts["gfr"], pts["gnr"]], fill=shade(color, 0.65))
    draw.polygon([pts["fl"], pts["fr"], pts["nr"], pts["nl"]], fill=shade(color, 1.12))


def draw_typewriter() -> Image.Image:
    im = canvas((280, 200))
    d = ImageDraw.Draw(im)
    # Body
    iso_box(d, 140, 170, 160, 90, 55, (48, 46, 42))
    # Platen
    d.ellipse((90, 70, 210, 100), fill=(28, 28, 30, 255))
    d.rectangle((95, 78, 205, 92), fill=(70, 68, 62, 255))
    # Keys grid
    for row in range(3):
        for col in range(8):
            x = 70 + col * 16 + row * 2
            y = 110 + row * 12
            d.ellipse((x, y, x + 10, y + 8), fill=(22, 22, 24, 255))
            d.ellipse((x + 1, y + 1, x + 8, y + 5), fill=(90, 88, 80, 255))
    # Paper
    d.polygon([(120, 40), (180, 35), (185, 85), (125, 90)], fill=(210, 200, 175, 255))
    d.line([(130, 55), (170, 50)], fill=(40, 40, 45, 180), width=1)
    d.line([(132, 65), (172, 60)], fill=(40, 40, 45, 160), width=1)
    return im.filter(ImageFilter.SMOOTH_MORE)


def draw_notebook() -> Image.Image:
    im = canvas((160, 120))
    d = ImageDraw.Draw(im)
    d.polygon([(40, 30), (120, 25), (130, 90), (50, 95)], fill=(42, 55, 70, 255))
    d.polygon([(45, 35), (115, 30), (122, 85), (52, 90)], fill=(230, 220, 195, 255))
    for i in range(4):
        y = 45 + i * 10
        d.line([(55, y), (110, y - 3)], fill=(80, 90, 110, 140), width=1)
    d.ellipse((48, 50, 58, 62), fill=(120, 90, 50, 255))  # elastic band knot
    return im


def draw_safe() -> Image.Image:
    im = canvas((256, 280))
    d = ImageDraw.Draw(im)
    iso_box(d, 130, 240, 140, 100, 150, (55, 58, 62))
    # Door face inset
    d.polygon([(80, 90), (160, 70), (160, 200), (80, 220)], fill=(40, 42, 46, 255))
    d.ellipse((105, 130, 145, 170), fill=(90, 85, 70, 255))
    d.ellipse((115, 140, 135, 160), fill=(30, 30, 32, 255))
    d.rectangle((148, 140, 158, 175), fill=(100, 95, 75, 255))  # handle
    return im.filter(ImageFilter.SMOOTH)


def draw_case_board() -> Image.Image:
    im = canvas((320, 280))
    d = ImageDraw.Draw(im)
    # Cork board
    d.rounded_rectangle((20, 20, 300, 260), radius=6, fill=(120, 88, 52, 255))
    d.rounded_rectangle((28, 28, 292, 252), radius=4, fill=(148, 110, 68, 255))
    # Pins / notes / string
    notes = [
        ((50, 50, 110, 100), (230, 220, 180)),
        ((130, 60, 200, 120), (210, 200, 160)),
        ((210, 45, 270, 95), (200, 190, 150)),
        ((70, 140, 140, 200), (220, 210, 170)),
        ((160, 150, 250, 220), (205, 195, 155)),
    ]
    for box, col in notes:
        d.rectangle(box, fill=(*col, 255))
        d.ellipse((box[0] + 20, box[1] - 4, box[0] + 28, box[1] + 4), fill=(140, 30, 30, 255))
    d.line([(80, 90), (165, 90), (230, 70), (200, 180), (100, 170)], fill=(30, 30, 35, 200), width=2)
    return im


def draw_city_map() -> Image.Image:
    im = canvas((280, 240))
    d = ImageDraw.Draw(im)
    d.rectangle((16, 16, 264, 224), fill=(55, 50, 40, 255))
    d.rectangle((24, 24, 256, 216), fill=(70, 85, 75, 255))
    # Streets
    for i in range(5):
        y = 50 + i * 30
        d.line([(30, y), (250, y + (i % 2) * 8)], fill=(40, 50, 48, 220), width=3)
    for i in range(4):
        x = 60 + i * 45
        d.line([(x, 30), (x - 10, 210)], fill=(40, 50, 48, 200), width=2)
    d.ellipse((140, 100, 160, 120), outline=(160, 50, 40, 255), width=2)
    return im


def draw_framed_licence() -> Image.Image:
    im = canvas((160, 180))
    d = ImageDraw.Draw(im)
    d.rectangle((20, 20, 140, 160), fill=(70, 50, 30, 255))
    d.rectangle((30, 30, 130, 150), fill=(225, 215, 190, 255))
    d.rectangle((40, 45, 120, 70), fill=(40, 40, 45, 255))  # title bar abstract
    for i in range(5):
        y = 80 + i * 10
        d.line([(42, y), (118, y)], fill=(120, 110, 95, 200), width=1)
    d.ellipse((70, 125, 95, 145), outline=(90, 70, 40, 255), width=2)  # seal
    return im


def draw_wall_photos() -> Image.Image:
    im = canvas((220, 160))
    d = ImageDraw.Draw(im)
    frames = [
        (10, 20, 80, 100, (45, 40, 35)),
        (70, 10, 140, 90, (50, 42, 36)),
        (130, 30, 210, 120, (40, 38, 34)),
        (40, 90, 110, 150, (48, 40, 32)),
        (115, 95, 185, 155, (42, 38, 34)),
    ]
    for x0, y0, x1, y1, frame in frames:
        d.rectangle((x0, y0, x1, y1), fill=(*frame, 255))
        d.rectangle((x0 + 5, y0 + 5, x1 - 5, y1 - 5), fill=(90, 95, 100, 255))
        d.ellipse((x0 + 12, y0 + 14, x0 + 28, y0 + 30), fill=(70, 65, 60, 255))
    return im


def draw_blinds() -> Image.Image:
    """Venetian blinds overlay for the window insert (~same footprint as window)."""
    im = canvas((180, 220))
    d = ImageDraw.Draw(im)
    # Slightly tilted slats
    for i in range(14):
        y = 18 + i * 13
        shade_v = 35 + (i % 3) * 8
        d.polygon(
            [(18, y), (162, y - 6), (162, y + 4), (18, y + 10)],
            fill=(shade_v, shade_v + 4, shade_v + 10, 210),
        )
    # Cord
    d.line([(150, 20), (150, 200)], fill=(180, 170, 140, 220), width=2)
    return im


def draw_umbrella_stand() -> Image.Image:
    im = canvas((160, 220))
    d = ImageDraw.Draw(im)
    # Stand cylinder
    d.ellipse((50, 170, 110, 205), fill=(50, 45, 40, 255))
    d.rectangle((55, 100, 105, 185), fill=(60, 55, 48, 255))
    d.ellipse((50, 90, 110, 120), fill=(70, 65, 55, 255))
    # Umbrellas
    d.polygon([(70, 30), (95, 55), (78, 160), (62, 160)], fill=(35, 45, 70, 255))
    d.polygon([(95, 25), (120, 50), (105, 155), (88, 155)], fill=(70, 35, 35, 255))
    d.line([(78, 30), (78, 20)], fill=(180, 170, 140, 255), width=2)
    d.line([(105, 25), (105, 15)], fill=(180, 170, 140, 255), width=2)
    return im.filter(ImageFilter.SMOOTH)


def draw_waiting_chair(variant: str) -> Image.Image:
    im = canvas((220, 280))
    d = ImageDraw.Draw(im)
    if variant == "a":
        wood = (78, 55, 35)
        seat = (90, 70, 50)
        # Straight wood chair
        iso_box(d, 110, 200, 100, 70, 40, seat)
        d.rectangle((70, 60, 90, 170), fill=shade(wood, 0.9))
        d.rectangle((130, 55, 150, 165), fill=shade(wood, 0.8))
        d.rectangle((70, 55, 150, 75), fill=shade(wood, 1.1))
        d.rectangle((75, 80, 145, 120), fill=(100, 95, 80, 255))  # splat back
    else:
        # Upholstered mismatched seat
        iso_box(d, 110, 205, 110, 80, 45, (55, 60, 70))
        d.polygon([(60, 70), (150, 55), (155, 150), (65, 165)], fill=(70, 75, 85, 255))
        d.polygon([(65, 75), (145, 62), (148, 140), (68, 152)], fill=(90, 50, 48, 255))
        d.rectangle((72, 180, 88, 240), fill=(40, 40, 42, 255))
        d.rectangle((130, 175, 146, 235), fill=(40, 40, 42, 255))
    return im.filter(ImageFilter.SMOOTH)


def draw_waiting_table() -> Image.Image:
    im = canvas((200, 160))
    d = ImageDraw.Draw(im)
    iso_box(d, 100, 130, 120, 80, 50, (70, 52, 36))
    d.ellipse((85, 55, 115, 75), fill=shade((70, 52, 36), 1.1))  # hint of lamp/top clutter shadow
    return im


def draw_newspaper() -> Image.Image:
    im = canvas((140, 100))
    d = ImageDraw.Draw(im)
    d.polygon([(20, 25), (120, 18), (125, 80), (25, 88)], fill=(220, 210, 185, 255))
    d.rectangle((30, 30, 95, 42), fill=(40, 40, 45, 255))
    for i in range(4):
        y = 48 + i * 8
        d.line([(32, y), (110, y - 2)], fill=(90, 85, 75, 200), width=1)
    return im


def draw_runner() -> Image.Image:
    """Narrow worn runner — dimetric diamond strip."""
    im = canvas((768, 384))
    arr = np.zeros((384, 768, 4), dtype=np.float32)
    cy, cx = 192, 384
    for y in range(384):
        for x in range(768):
            # Diamond band along NE–SW
            lx = (x - cx) / 320.0
            ly = (y - cy) / 90.0
            # Thin corridor along diagonal
            along = lx * 0.85 + ly * 0.15
            across = -lx * 0.25 + ly
            if abs(across) < 0.55 and abs(along) < 1.15:
                wear = 0.55 + 0.25 * math.sin(along * 9) * math.sin(across * 11)
                edge = max(0.0, 1.0 - abs(across) / 0.55)
                a = edge * edge * 180 * wear
                arr[y, x] = [62, 48, 38, a]
    im = Image.fromarray(arr.astype(np.uint8), "RGBA")
    return im.filter(ImageFilter.GaussianBlur(radius=1.2))


def draw_blind_stripes() -> Image.Image:
    """Cool blue-grey blind shadow stripes for additive/alpha floor light."""
    w, h = 1536, 1024
    arr = np.zeros((h, w, 4), dtype=np.float32)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    # Soft elliptical spill
    nx = (xx - w * 0.38) / (w * 0.28)
    ny = (yy - h * 0.42) / (h * 0.28)
    r = np.sqrt(nx * nx + ny * ny)
    falloff = np.clip(1.0 - r, 0, 1)
    falloff = falloff * falloff
    # Diagonal stripes (blind angle)
    stripe = 0.35 + 0.65 * ((np.sin((xx * 0.35 + yy * 0.55) * 0.09) + 1) * 0.5)
    stripe = np.where(stripe > 0.55, 1.0, 0.15)
    intensity = falloff * stripe
    arr[:, :, 0] = 90 * intensity
    arr[:, :, 1] = 120 * intensity
    arr[:, :, 2] = 160 * intensity
    arr[:, :, 3] = 200 * intensity
    return Image.fromarray(arr.astype(np.uint8), "RGBA").filter(ImageFilter.GaussianBlur(1.5))


def draw_hallway_light() -> Image.Image:
    """Narrow warm rectangle from the open door."""
    w, h = 768, 512
    arr = np.zeros((h, w, 4), dtype=np.float32)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    # Trapezoid beam from top-right toward center-left
    nx = (xx - w * 0.72) / (w * 0.22)
    ny = (yy - h * 0.35) / (h * 0.35)
    # Thin wedge
    along = -nx * 0.7 + ny * 0.3
    across = nx * 0.35 + ny
    mask = (np.abs(across) < (0.18 + 0.25 * np.clip(along, 0, 1))) & (along > -0.2) & (along < 1.2)
    fall = np.clip(1.0 - along * 0.55, 0, 1) * np.clip(1.0 - np.abs(across) * 2.5, 0, 1)
    intensity = np.where(mask, fall, 0)
    arr[:, :, 0] = 220 * intensity
    arr[:, :, 1] = 150 * intensity
    arr[:, :, 2] = 70 * intensity
    arr[:, :, 3] = 170 * intensity
    return Image.fromarray(arr.astype(np.uint8), "RGBA").filter(ImageFilter.GaussianBlur(2.0))


def draw_ceiling_fan_shadow() -> Image.Image:
    w, h = 1536, 1024
    arr = np.zeros((h, w, 4), dtype=np.float32)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    cx, cy = w * 0.5, h * 0.48
    # Four soft blades
    for angle in (0.2, 0.2 + math.pi / 2, 0.2 + math.pi, 0.2 + 3 * math.pi / 2):
        ca, sa = math.cos(angle), math.sin(angle)
        lx = ((xx - cx) * ca + (yy - cy) * sa) / (w * 0.28)
        ly = (-(xx - cx) * sa + (yy - cy) * ca) / (h * 0.08)
        blade = np.clip(1.0 - np.abs(ly), 0, 1) * np.clip(1.0 - np.abs(lx), 0, 1)
        blade = blade * blade
        arr[:, :, 3] = np.maximum(arr[:, :, 3], blade * 90)
    arr[:, :, 0] = 12
    arr[:, :, 1] = 14
    arr[:, :, 2] = 20
    return Image.fromarray(arr.astype(np.uint8), "RGBA").filter(ImageFilter.GaussianBlur(3.0))


def derive_second_ashtray() -> Image.Image:
    src = RUNTIME / "office_desk_ashtray.png"
    if src.exists():
        im = Image.open(src).convert("RGBA")
        # Slight recolor for table variant
        arr = np.array(im, dtype=np.float32)
        arr[:, :, 0] = np.clip(arr[:, :, 0] * 0.92, 0, 255)
        arr[:, :, 2] = np.clip(arr[:, :, 2] * 1.08, 0, 255)
        return Image.fromarray(arr.astype(np.uint8), "RGBA")
    im = canvas((115, 85))
    d = ImageDraw.Draw(im)
    d.ellipse((20, 30, 95, 70), fill=(40, 40, 42, 255))
    d.ellipse((30, 35, 85, 60), fill=(70, 65, 55, 255))
    return im


def main() -> None:
    props = {
        "office_desk_typewriter": draw_typewriter(),
        "office_desk_notebook": draw_notebook(),
        "office_safe": draw_safe(),
        "office_case_board": draw_case_board(),
        "office_wall_city_map": draw_city_map(),
        "office_framed_licence": draw_framed_licence(),
        "office_wall_photos": draw_wall_photos(),
        "office_window_blinds": draw_blinds(),
        "office_umbrella_stand": draw_umbrella_stand(),
        "office_waiting_chair_a": draw_waiting_chair("a"),
        "office_waiting_chair_b": draw_waiting_chair("b"),
        "office_waiting_table": draw_waiting_table(),
        "office_newspaper": draw_newspaper(),
        "office_entrance_runner": draw_runner(),
        "office_waiting_ashtray": derive_second_ashtray(),
        "office_light_blind_stripes": draw_blind_stripes(),
        "office_light_hallway": draw_hallway_light(),
        "office_shadow_ceiling_fan": draw_ceiling_fan_shadow(),
    }
    for name, im in props.items():
        save(im, name)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Paint Sable Row's four south-face terraces at 2.00 px/unit.

One continuous block face per WardBlock — not a row of 512×640 cubes. Door holes
are punched at the exact texture pixels recorded in
`CityDistrictLayout.SourceDoorAperture.terraceSable*`. Verticals stay vertical;
end-returns and eaves follow the BG:EE ground slope ±0.75.

    python3 ArtSource/Processing/generate_sable_terraces_v01.py

Writes ArtSource/Generated/CityDistrict/V2/Terraces/ and the runtime props.
Do not call process_city_districts_v02.main().
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_city_grounds_world_scale_v05 import flatten_interior_alpha

ROOT = Path(__file__).resolve().parents[2]
PROPS = ROOT / "RainShadow Shared/Resources/Art/Props/CityDistrict/V2"
OUT = ROOT / "ArtSource/Generated/CityDistrict/V2/Terraces"

# Authored canvases — 2.00 px per world unit. World size is one lot: 1120×420.
TERRACES = {
    "sw": {"name": "city_terrace_sable_sw.png", "size": (2240, 840), "kind": "tenement_shop"},
    "se": {"name": "city_terrace_sable_se.png", "size": (2240, 840), "kind": "gate_voss"},
    "nw": {"name": "city_terrace_sable_nw.png", "size": (2240, 840), "kind": "storefront"},
    "ne": {"name": "city_terrace_sable_ne.png", "size": (2240, 840), "kind": "rowhouse"},
}

# Must match CityDistrictLayout.SourceDoorAperture.terraceSable*.
HOLES = {
    "sw": [
        {"name": "tenement", "cx": 987, "ty": 692, "h": 110, "w": 78},
        {"name": "shop", "cx": 1523, "ty": 716, "h": 176, "w": 103},
    ],
    "se": [
        {"name": "gatehouse", "cx": 800, "ty": 730, "h": 129, "w": 80},
        {"name": "voss", "cx": 1506, "ty": 628, "h": 115, "w": 70},
        {"name": "garage", "cx": 1780, "ty": 680, "h": 141, "w": 140},
    ],
    "nw": [
        {"name": "storefront", "cx": 1540, "ty": 627, "h": 89, "w": 60},
    ],
    "ne": [
        {"name": "rowhouse", "cx": 967, "ty": 673, "h": 131, "w": 58},
    ],
}

SLOPE = 0.75  # BG:EE ground-axis slope
WALL_FOOT = 708
CORNICE_Y = 188
ROOF_TOP = 56
END_W = 92


def _load(name: str) -> Image.Image:
    return Image.open(PROPS / f"{name}.png").convert("RGBA")


def _crop_opaque(im: Image.Image, box: tuple[int, int, int, int]) -> np.ndarray:
    arr = np.array(im.crop(box), dtype=np.uint8)
    if arr.shape[2] == 4:
        mask = arr[:, :, 3] > 40
        if mask.any():
            return arr
    return arr


def _sample_palette(im: Image.Image, box: tuple[int, int, int, int]) -> np.ndarray:
    arr = np.array(im.crop(box), dtype=np.uint8)
    rgb = arr[:, :, :3].reshape(-1, 3)
    a = arr[:, :, 3].reshape(-1)
    rgb = rgb[a > 40]
    if len(rgb) == 0:
        return np.array([[48, 42, 40]], dtype=np.uint8)
    return rgb


def _fill_rect(dest: np.ndarray, x0: int, y0: int, x1: int, y1: int, rgb: np.ndarray) -> None:
    h, w = dest.shape[:2]
    x0, x1 = max(0, x0), min(w, x1)
    y0, y1 = max(0, y0), min(h, y1)
    if x1 <= x0 or y1 <= y0:
        return
    dest[y0:y1, x0:x1, :3] = rgb
    dest[y0:y1, x0:x1, 3] = 255


def _stamp(dest: np.ndarray, src: np.ndarray, x: int, y: int, alpha: float = 1.0) -> None:
    sh, sw = src.shape[:2]
    h, w = dest.shape[:2]
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(w, x + sw), min(h, y + sh)
    sx0, sy0 = x0 - x, y0 - y
    if x1 <= x0 or y1 <= y0:
        return
    patch = src[sy0 : sy0 + (y1 - y0), sx0 : sx0 + (x1 - x0)]
    dst = dest[y0:y1, x0:x1]
    sa = (patch[:, :, 3:4].astype(np.float32) / 255.0) * alpha
    dst[:, :, :3] = np.clip(
        patch[:, :, :3].astype(np.float32) * sa + dst[:, :, :3].astype(np.float32) * (1 - sa),
        0,
        255,
    ).astype(np.uint8)
    dst[:, :, 3] = np.clip(
        dst[:, :, 3].astype(np.float32) + sa[:, :, 0] * 255 * (1 - dst[:, :, 3].astype(np.float32) / 255.0),
        0,
        255,
    ).astype(np.uint8)
    dest[y0:y1, x0:x1] = dst


def _tile_patch(
    dest: np.ndarray,
    patch: np.ndarray,
    x0: int,
    y0: int,
    x1: int,
    y1: int,
    rng: np.random.Generator,
    jitter: int = 3,
) -> None:
    ph, pw = patch.shape[:2]
    if ph < 4 or pw < 4:
        return
    h, w = dest.shape[:2]
    x0, x1 = max(0, x0), min(w, x1)
    y0, y1 = max(0, y0), min(h, y1)
    yy = y0
    row = 0
    while yy < y1:
        xx = x0 - (row * 7) % max(1, pw // 3)
        while xx < x1:
            ox = int(rng.integers(-jitter, jitter + 1)) if jitter else 0
            oy = int(rng.integers(-jitter, jitter + 1)) if jitter else 0
            _stamp(dest, patch, xx + ox, yy + oy)
            xx += pw - 2
        yy += ph - 2
        row += 1


def _brick_courses(
    dest: np.ndarray,
    x0: int,
    y0: int,
    x1: int,
    y1: int,
    palette: np.ndarray,
    rng: np.random.Generator,
    mortar: tuple[int, int, int] = (28, 26, 24),
    bh: int = 10,
    bw: int = 22,
) -> None:
    h, w = dest.shape[:2]
    x0, x1 = max(0, x0), min(w, x1)
    y0, y1 = max(0, y0), min(h, y1)
    if x1 <= x0 or y1 <= y0:
        return
    # Mortar bed.
    dest[y0:y1, x0:x1, 0] = mortar[0]
    dest[y0:y1, x0:x1, 1] = mortar[1]
    dest[y0:y1, x0:x1, 2] = mortar[2]
    dest[y0:y1, x0:x1, 3] = 255
    row = 0
    y = y0
    while y < y1:
        shift = (row % 2) * (bw // 2)
        x = x0 - shift
        while x < x1:
            x_a, x_b = max(x0, x + 1), min(x1, x + bw - 1)
            y_a, y_b = y + 1, min(y1, y + bh - 1)
            if x_b > x_a and y_b > y_a:
                col = palette[int(rng.integers(0, len(palette)))]
                shade = 1.0 + float(rng.normal(0, 0.07))
                rgb = np.clip(col.astype(np.float32) * shade, 0, 255).astype(np.uint8)
                dest[y_a:y_b, x_a:x_b, :3] = rgb
                dest[y_a:y_b, x_a:x_b, 3] = 255
            x += bw
        y += bh
        row += 1


def _stone_courses(
    dest: np.ndarray,
    x0: int,
    y0: int,
    x1: int,
    y1: int,
    palette: np.ndarray,
    rng: np.random.Generator,
    bh: int = 16,
    bw: int = 28,
) -> None:
    _brick_courses(dest, x0, y0, x1, y1, palette, rng, mortar=(22, 22, 24), bh=bh, bw=bw)


def _paint_window(
    dest: np.ndarray,
    x: int,
    y: int,
    w: int,
    h: int,
    lit: bool,
    rng: np.random.Generator,
    sash: tuple[int, int, int] = (38, 40, 44),
) -> None:
    # Stone frame.
    _fill_rect(dest, x - 3, y - 3, x + w + 3, y + h + 3, np.array([62, 60, 58], dtype=np.uint8))
    _fill_rect(dest, x - 1, y - 1, x + w + 1, y + h + 1, np.array(sash, dtype=np.uint8))
    if lit:
        glow = np.array(
            [210 + int(rng.integers(-12, 13)), 160 + int(rng.integers(-16, 12)), 70 + int(rng.integers(-10, 16))],
            dtype=np.int16,
        )
        glow = np.clip(glow, 0, 255).astype(np.uint8)
        _fill_rect(dest, x, y, x + w, y + h, glow)
        # Mullions.
        _fill_rect(dest, x + w // 2 - 1, y, x + w // 2 + 1, y + h, np.array(sash, dtype=np.uint8))
        _fill_rect(dest, x, y + h // 2 - 1, x + w, y + h // 2 + 1, np.array(sash, dtype=np.uint8))
        # Soft interior falloff.
        yy, xx = np.mgrid[0:h, 0:w]
        fall = 0.72 + 0.28 * (1 - ((yy / max(h - 1, 1) - 0.35) ** 2 + (xx / max(w - 1, 1) - 0.5) ** 2))
        region = dest[y : y + h, x : x + w, :3].astype(np.float32)
        region *= fall[:, :, None]
        dest[y : y + h, x : x + w, :3] = np.clip(region, 0, 255).astype(np.uint8)
    else:
        pane = np.array([18 + int(rng.integers(0, 8)), 20 + int(rng.integers(0, 8)), 24 + int(rng.integers(0, 8))])
        _fill_rect(dest, x, y, x + w, y + h, pane.astype(np.uint8))
        _fill_rect(dest, x + w // 2 - 1, y, x + w // 2 + 1, y + h, np.array(sash, dtype=np.uint8))
        _fill_rect(dest, x, y + h // 2 - 1, x + w, y + h // 2 + 1, np.array(sash, dtype=np.uint8))


def _paint_shop_window(
    dest: np.ndarray, x: int, y: int, w: int, h: int, rng: np.random.Generator
) -> None:
    _fill_rect(dest, x - 4, y - 4, x + w + 4, y + h + 6, np.array([58, 56, 52], dtype=np.uint8))
    glow = np.array([186, 142, 64], dtype=np.uint8)
    _fill_rect(dest, x, y, x + w, y + h, glow)
    # Vertical sash bars.
    for i in range(1, 4):
        sx = x + i * w // 4
        _fill_rect(dest, sx - 1, y, sx + 1, y + h, np.array([36, 34, 32], dtype=np.uint8))
    _fill_rect(dest, x, y + h - 10, x + w, y + h, np.array([42, 36, 30], dtype=np.uint8))
    # Awning lip.
    _fill_rect(dest, x - 6, y - 10, x + w + 6, y - 2, np.array([48, 28, 24], dtype=np.uint8))


def _paint_roof(
    dest: np.ndarray,
    x0: int,
    x1: int,
    top: int,
    cornice: int,
    palette: np.ndarray,
    rng: np.random.Generator,
    pitched: bool,
) -> None:
    h, w = dest.shape[:2]
    x0, x1 = max(0, x0), min(w, x1)
    # Parapet / roof deck.
    for y in range(top, cornice):
        t = (y - top) / max(cornice - top, 1)
        col = palette[int(rng.integers(0, len(palette)))].astype(np.float32)
        col *= 0.72 + 0.18 * t
        dest[y, x0:x1, :3] = np.clip(col, 0, 255).astype(np.uint8)
        dest[y, x0:x1, 3] = 255
    if pitched:
        # Receding eave on +0.75 (right) and −0.75 (left) — a shallow iso roof.
        ridge = top + 10
        for x in range(x0, x1):
            mid = (x0 + x1) / 2
            drop = int(abs(x - mid) * SLOPE * 0.08)
            y0 = ridge + drop
            y1 = min(cornice, y0 + 18)
            dest[y0:y1, x, :3] = (34, 36, 40)
            dest[y0:y1, x, 3] = 255
    # Cornice moulding.
    _fill_rect(dest, x0, cornice - 8, x1, cornice, np.array([72, 68, 62], dtype=np.uint8))
    _fill_rect(dest, x0, cornice - 3, x1, cornice + 4, np.array([50, 48, 44], dtype=np.uint8))


def _paint_end_return(
    dest: np.ndarray,
    side: str,
    foot: int,
    top: int,
    palette: np.ndarray,
    rng: np.random.Generator,
) -> None:
    """Camera-side return. Verticals vertical; top/bottom on slope ±0.75."""
    h, w = dest.shape[:2]
    if side == "left":
        for i in range(END_W):
            drop = int(i * SLOPE)
            x = END_W - 1 - i
            y0 = top + drop
            y1 = foot + drop // 6
            y0, y1 = max(0, y0), min(h, y1)
            if y1 <= y0:
                continue
            col = palette[int(rng.integers(0, len(palette)))].astype(np.float32) * 0.72
            dest[y0:y1, x, :3] = np.clip(col, 0, 255).astype(np.uint8)
            dest[y0:y1, x, 3] = 255
    else:
        for i in range(END_W):
            drop = int(i * SLOPE)
            x = w - END_W + i
            if x >= w:
                break
            y0 = top + drop
            y1 = foot + drop // 6
            y0, y1 = max(0, y0), min(h, y1)
            if y1 <= y0:
                continue
            col = palette[int(rng.integers(0, len(palette)))].astype(np.float32) * 0.78
            dest[y0:y1, x, :3] = np.clip(col, 0, 255).astype(np.uint8)
            dest[y0:y1, x, 3] = 255


def _paint_chimney(dest: np.ndarray, x: int, top: int, palette: np.ndarray, rng: np.random.Generator) -> None:
    _fill_rect(dest, x, top - 28, x + 28, top + 18, palette[int(rng.integers(0, len(palette)))])
    _fill_rect(dest, x - 3, top - 34, x + 31, top - 24, np.array([44, 42, 40], dtype=np.uint8))


def _paint_stoop(dest: np.ndarray, cx: int, ty: int, w: int, steps: int = 3) -> None:
    stone = np.array([86, 80, 70], dtype=np.uint8)
    dark = np.array([48, 44, 38], dtype=np.uint8)
    step_h = 10
    for i in range(steps):
        hw = w // 2 + 8 + i * 6
        y0 = ty + i * step_h
        y1 = y0 + step_h - 1
        _fill_rect(dest, cx - hw, y0, cx + hw, y1, stone if i % 2 == 0 else dark)
        # Riser lip.
        _fill_rect(dest, cx - hw, y1 - 2, cx + hw, y1, np.array([30, 28, 24], dtype=np.uint8))
    # Rail stubs.
    _fill_rect(dest, cx - w // 2 - 10, ty - 36, cx - w // 2 - 6, ty + steps * step_h, np.array([70, 66, 58], dtype=np.uint8))
    _fill_rect(dest, cx + w // 2 + 6, ty - 36, cx + w // 2 + 10, ty + steps * step_h, np.array([70, 66, 58], dtype=np.uint8))


def _paint_door_frame(dest: np.ndarray, cx: int, ty: int, hole_w: int, hole_h: int, wide: bool = False) -> None:
    x0 = cx - hole_w // 2
    y0 = ty - hole_h
    stone = np.array([78, 74, 68], dtype=np.uint8)
    dark = np.array([36, 34, 30], dtype=np.uint8)
    pad = 14 if wide else 10
    _fill_rect(dest, x0 - pad, y0 - 12, x0 + hole_w + pad, y0, stone)  # lintel
    _fill_rect(dest, x0 - pad, y0, x0, ty + 2, stone)  # left jamb
    _fill_rect(dest, x0 + hole_w, y0, x0 + hole_w + pad, ty + 2, stone)
    _fill_rect(dest, x0 - pad, ty, x0 + hole_w + pad, ty + 4, dark)  # threshold lip


def punch_holes(im: Image.Image, holes: list[dict]) -> Image.Image:
    """Cut registered apertures to fully transparent (no baked leaves)."""
    arr = np.array(im.convert("RGBA"))
    h, w = arr.shape[:2]
    for hole in holes:
        x0 = int(hole["cx"] - hole["w"] / 2)
        y0 = int(hole["ty"] - hole["h"])
        x1 = int(hole["cx"] + hole["w"] / 2)
        y1 = int(hole["ty"])
        x0, x1 = max(0, x0), min(w, x1)
        y0, y1 = max(0, y0), min(h, y1)
        arr[y0:y1, x0:x1] = 0
    return Image.fromarray(arr, "RGBA")


def _window_grid(
    dest: np.ndarray,
    x0: int,
    x1: int,
    y_rows: list[int],
    rng: np.random.Generator,
    ww: int = 36,
    wh: int = 48,
    gap: int = 28,
    lit_p: float = 0.35,
) -> None:
    x = x0 + 18
    col = 0
    while x + ww < x1 - 12:
        for y in y_rows:
            lit = float(rng.random()) < lit_p
            # Keep a few dark for rhythm.
            if col % 5 == 2:
                lit = False
            _paint_window(dest, x, y, ww, wh, lit, rng)
        x += ww + gap + int(rng.integers(-4, 5))
        col += 1


def _paint_party_piers(
    dest: np.ndarray, xs: list[int], y0: int, y1: int, palette: np.ndarray, rng: np.random.Generator
) -> None:
    for x in xs:
        _fill_rect(dest, x - 6, y0, x + 6, y1, palette[int(rng.integers(0, len(palette)))])
        _fill_rect(dest, x - 2, y0, x + 2, y1, np.array([32, 30, 28], dtype=np.uint8))


def paint_terrace(face: str, spec: dict) -> Image.Image:
    w, h = spec["size"]
    kind = spec["kind"]
    rng = np.random.default_rng({"sw": 11, "se": 23, "nw": 37, "ne": 47}[face])
    dest = np.zeros((h, w, 4), dtype=np.uint8)

    tenement = _load("city_building_tenement")
    voss = _load("city_building_voss_stoop")
    shop = _load("city_building_shop")
    store = _load("city_building_storefront")
    row = _load("city_building_rowhouse")
    gate = _load("city_building_gatehouse")

    brick_red = _sample_palette(tenement, (230, 280, 350, 430))
    brick_brown = _sample_palette(row, (240, 300, 340, 420))
    brick_voss = _sample_palette(voss, (230, 260, 340, 400))
    stone_grey = _sample_palette(gate, (180, 360, 280, 460))
    slate = _sample_palette(tenement, (200, 90, 360, 160))
    shop_wood = _sample_palette(shop, (200, 300, 320, 400))
    store_stone = _sample_palette(store, (220, 280, 340, 400))

    wall_x0, wall_x1 = END_W, w - END_W
    foot, cornice, roof_top = WALL_FOOT, CORNICE_Y, ROOF_TOP

    if kind == "tenement_shop":
        split = int(w * 0.62)
        _brick_courses(dest, wall_x0, cornice, split, foot, brick_red, rng, bh=11, bw=24)
        _brick_courses(dest, split, cornice, wall_x1, foot, shop_wood, rng, mortar=(30, 26, 22), bh=12, bw=26)
        _paint_roof(dest, wall_x0, wall_x1, roof_top, cornice, slate, rng, pitched=False)
        _paint_end_return(dest, "left", foot, roof_top, brick_red, rng)
        _paint_end_return(dest, "right", foot, roof_top, shop_wood, rng)
        _window_grid(dest, wall_x0 + 20, split - 20, [220, 300, 380, 470], rng, lit_p=0.4)
        # Shop ground-floor windows on the right, upper sash above.
        _window_grid(dest, split + 24, wall_x1 - 16, [230, 320], rng, ww=32, wh=42, gap=22, lit_p=0.55)
        sx = split + 30
        while sx + 110 < wall_x1 - 20:
            if not (2160 - 80 < sx < 2160 + 80):
                _paint_shop_window(dest, sx, 500, 100, 170, rng)
            sx += 150
        _paint_party_piers(dest, [split], cornice, foot, brick_red, rng)
        for cx in (420, 980, 1500, 2000, 2500):
            _paint_chimney(dest, cx, roof_top + 8, brick_red, rng)
        # Ground-floor string course.
        _fill_rect(dest, wall_x0, 490, wall_x1, 498, np.array([64, 58, 50], dtype=np.uint8))

    elif kind == "gate_voss":
        split = 980
        _stone_courses(dest, wall_x0, cornice + 40, split, foot, stone_grey, rng, bh=18, bw=30)
        _brick_courses(dest, split, cornice, wall_x1, foot, brick_voss, rng, bh=11, bw=22)
        _paint_roof(dest, wall_x0, split, roof_top + 36, cornice + 40, slate, rng, pitched=True)
        _paint_roof(dest, split, wall_x1, roof_top, cornice, slate, rng, pitched=False)
        _paint_end_return(dest, "left", foot, roof_top + 36, stone_grey, rng)
        _paint_end_return(dest, "right", foot, roof_top, brick_voss, rng)
        # Gatehouse is shorter — fill the crown with a pyramidal cap hint.
        _fill_rect(dest, wall_x0 + 40, cornice + 20, split - 20, cornice + 48, np.array([50, 52, 56], dtype=np.uint8))
        _window_grid(dest, wall_x0 + 30, split - 30, [280, 380], rng, ww=30, wh=38, gap=36, lit_p=0.15)
        _window_grid(dest, split + 24, wall_x1 - 20, [220, 300, 380, 470], rng, ww=34, wh=46, gap=26, lit_p=0.45)
        _paint_party_piers(dest, [split], cornice, foot, stone_grey, rng)
        # Garage surround — stone quoins, hole punched later.
        gx0, gx1 = 2360 - 100, 2360 + 100
        _fill_rect(dest, gx0, 520, gx1, foot, np.array([70, 68, 64], dtype=np.uint8))
        for cx in (1200, 1680, 2140, 2580):
            _paint_chimney(dest, cx, roof_top + 6, brick_voss, rng)
        _fill_rect(dest, split, 490, wall_x1, 498, np.array([58, 54, 50], dtype=np.uint8))
        # Iron balcony hint on the Voss bay.
        _fill_rect(dest, 1700, 430, 1940, 438, np.array([28, 28, 30], dtype=np.uint8))
        for bx in range(1710, 1930, 18):
            _fill_rect(dest, bx, 430, bx + 3, 468, np.array([24, 24, 26], dtype=np.uint8))

    elif kind == "storefront":
        _stone_courses(dest, wall_x0, cornice, wall_x1, foot, store_stone, rng, bh=14, bw=26)
        _paint_roof(dest, wall_x0, wall_x1, roof_top + 8, cornice, slate, rng, pitched=False)
        _paint_end_return(dest, "left", foot, roof_top + 8, store_stone, rng)
        _paint_end_return(dest, "right", foot, roof_top + 8, store_stone, rng)
        _window_grid(dest, wall_x0 + 16, wall_x1 - 16, [230, 320], rng, ww=34, wh=44, gap=20, lit_p=0.6)
        sx = wall_x0 + 40
        while sx + 130 < wall_x1 - 20:
            if not (1440 - 90 < sx < 1440 + 90):
                _paint_shop_window(dest, sx, 495, 118, 180, rng)
            sx += 200
        # Bay rhythm piers, not full cube gaps.
        _paint_party_piers(dest, [wall_x0 + 520, wall_x0 + 1040, wall_x0 + 1560, wall_x0 + 2080], cornice, foot, store_stone, rng)
        for cx in (360, 1100, 1840, 2500):
            _paint_chimney(dest, cx, roof_top + 12, store_stone, rng)
        _fill_rect(dest, wall_x0, 478, wall_x1, 486, np.array([80, 72, 58], dtype=np.uint8))

    else:  # rowhouse
        _brick_courses(dest, wall_x0, cornice, wall_x1, foot, brick_brown, rng, bh=11, bw=23)
        _paint_roof(dest, wall_x0, wall_x1, roof_top, cornice, slate, rng, pitched=True)
        _paint_end_return(dest, "left", foot, roof_top, brick_brown, rng)
        _paint_end_return(dest, "right", foot, roof_top, brick_brown, rng)
        _window_grid(dest, wall_x0 + 20, wall_x1 - 20, [230, 320, 420], rng, ww=34, wh=46, gap=30, lit_p=0.38)
        _paint_party_piers(
            dest,
            [wall_x0 + 460, wall_x0 + 920, wall_x0 + 1380, wall_x0 + 1840],
            cornice,
            foot,
            brick_brown,
            rng,
        )
        for cx in (480, 960, 1500, 2100, 2520):
            _paint_chimney(dest, cx, roof_top + 4, brick_brown, rng)
        _fill_rect(dest, wall_x0, 500, wall_x1, 508, np.array([60, 54, 48], dtype=np.uint8))

    # Shared plinth along the south face — no cobble island.
    _fill_rect(dest, wall_x0, foot - 14, wall_x1, foot, np.array([54, 50, 44], dtype=np.uint8))
    _fill_rect(dest, wall_x0, foot - 3, wall_x1, foot + 2, np.array([28, 26, 22], dtype=np.uint8))

    # Door frames and stoops before the hole punch so jambs survive.
    for hole in HOLES[face]:
        wide = hole["name"] == "garage"
        _paint_door_frame(dest, hole["cx"], hole["ty"], hole["w"], hole["h"], wide=wide)
        if hole["name"] != "garage":
            steps = 4 if hole["name"] == "voss" else 3
            _paint_stoop(dest, hole["cx"], hole["ty"], hole["w"], steps=steps)

    im = Image.fromarray(dest, "RGBA")
    im = punch_holes(im, HOLES[face])
    # Slight painterly soften — matches the modest native-resolution softness of the cubes.
    rgb = im.convert("RGB").filter(ImageFilter.SMOOTH_MORE)
    out = Image.merge("RGBA", (*rgb.split(), im.split()[-1]))
    return flatten_interior_alpha(out, floor=24)


def write_terraces() -> list[Path]:
    OUT.mkdir(parents=True, exist_ok=True)
    PROPS.mkdir(parents=True, exist_ok=True)
    written: list[Path] = []
    for face, spec in TERRACES.items():
        im = paint_terrace(face, spec)
        gen = OUT / spec["name"]
        runtime = PROPS / spec["name"]
        im.save(gen, "PNG", compress_level=4)
        im.save(runtime, "PNG", compress_level=4)
        print(f"wrote {spec['name']} {im.size}  holes={[h['name'] for h in HOLES[face]]}")
        written.append(runtime)
    return written


def main() -> int:
    write_terraces()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

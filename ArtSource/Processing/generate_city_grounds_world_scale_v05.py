#!/usr/bin/env python3
"""Paint Act I city grounds at Infinity Engine outdoor-area scale.

World bounds grow by adding authored street (4096×2304 world units, ~58
adults across). Grounds are painted at plate resolution on the Baldur's
Gate: EE camera — sett / flag / drain joints sit on slopes ±0.75 — not a
Lanczos or procedural overlay of a smaller master.

Does not run `process_city_districts_v02.main()`. Does not touch the office.

    python3 ArtSource/Processing/generate_city_grounds_world_scale_v05.py
    python3 ArtSource/Processing/generate_city_grounds_world_scale_v05.py sable_row
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ie_projection as ie
import qa_plate_projection as qa

ROOT = Path(__file__).resolve().parents[2]
GEN = ROOT / "ArtSource" / "Generated" / "CityDistrict" / "V2"
AREAS = ROOT / "RainShadow Shared" / "Resources" / "Art" / "Areas" / "CityDistrict" / "V2"
MAPS = ROOT / "RainShadow Shared" / "Resources" / "Art" / "UI" / "Map"

# Authored play space. 4096/70.3125 ≈ 58.3 adults — mid IE outdoor band.
# Both axes are exact SearchMap multiples (16×12).
WORLD_W = 4096.0
WORLD_H = 2304.0
# 2.00 art px / world unit: the density floor, and the largest 16:9 plate
# that stays inside a common 8192 GPU texture. Actor reference is 2.84;
# a 2.84 plate at this world size would be 11636 px and would not load on
# A11–A13 devices. Stonework is painted here, not upscaled.
PLATE_W = 8192
PLATE_H = 4608
PX_PER_UNIT = PLATE_W / WORLD_W

SLOPE = ie.BGEE.ground_slope  # 0.75
# 0.12 m granite sett and 0.50 m pavement flag at 1.75 m / 70.3125 u.
METRE = 70.3125 / 1.75
SETT_WORLD = 0.12 * METRE
FLAG_WORLD = 0.50 * METRE
SETT_PX = SETT_WORLD * PX_PER_UNIT
FLAG_PX = FLAG_WORLD * PX_PER_UNIT
# Painted V4 masters already carry wet cobble + iso sidewalks. We tile them
# to the new plate (same 2.00 px/unit) instead of drawing a 192-unit black
# diamond overlay — that overlay locked the camera but read as CAD wireframe
# and showed through the mid-alpha building sprites.
V4_ROOT = ROOT / "ArtSource" / "Generated" / "BGEEProjectionCandidates"
JOINT = 0.16
# Soft sett reinforcement only. Civic needs more; the others ride the V4 lock.
AMOUNT = 0.10
AMOUNT_CIVIC = 0.22
COURSE_WORLD = 40.0  # ~1.0 m flag rows
COURSE_PX = COURSE_WORLD * PX_PER_UNIT
COURSE_HALF_PX = 18.0
COURSE_DARK = 0.16
CITY_TOLERANCE_DEG = 1.5
MAP_SIZE = (1847, 1040)
AGENT_RADIUS = 16.0

# Screen-axis streets in world units. Widths 8.0–9.0 m (7–10 m band).
STREETS_X = ((80.0, 400.0), (1880.0, 2240.0), (3680.0, 4016.0))
STREETS_Y = ((80.0, 400.0), (1060.0, 1380.0), (1900.0, 2224.0))

# Building pads. Streets stay open around them.
BLOCKS = {
    "sw": (420.0, 420.0, 1440.0, 620.0),
    "se": (2260.0, 420.0, 1400.0, 620.0),
    "nw": (420.0, 1400.0, 1440.0, 480.0),
    "ne": (2260.0, 1400.0, 1400.0, 480.0),
}

PALETTES = {
    "sable_row": dict(
        road=(46, 50, 56), pavement=(58, 58, 62), water=(18, 24, 30),
        stain=(36, 32, 30), lamp=(210, 150, 70),
    ),
    "wharf_ladder": dict(
        road=(40, 42, 44), pavement=(52, 50, 46), water=(16, 26, 34),
        stain=(48, 40, 30), lamp=(200, 140, 64),
    ),
    "riverside": dict(
        road=(42, 46, 50), pavement=(54, 56, 58), water=(14, 28, 38),
        stain=(30, 36, 40), lamp=(190, 148, 80),
    ),
    "harborpoint_pd": dict(
        road=(44, 44, 46), pavement=(56, 56, 54), water=(16, 22, 28),
        stain=(38, 36, 34), lamp=(186, 154, 88),
    ),
    "lila_street": dict(
        road=(48, 42, 44), pavement=(60, 52, 50), water=(18, 22, 28),
        stain=(42, 30, 30), lamp=(204, 132, 72),
    ),
    "civic_records": dict(
        road=(56, 56, 58), pavement=(72, 70, 68), water=(20, 24, 30),
        stain=(50, 48, 44), lamp=(196, 168, 110),
    ),
}

FOLDERS = {
    "sable_row": "SableRow",
    "wharf_ladder": "WharfLadder",
    "riverside": "Riverside",
    "harborpoint_pd": "HarborpointPD",
    "lila_street": "LilaStreet",
    "civic_records": "CivicRecords",
}


def _blur(arr: np.ndarray, radius: float) -> np.ndarray:
    im = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "L")
    return np.asarray(im.filter(ImageFilter.GaussianBlur(radius=radius)), dtype=np.float32)


def axis_uv(h: int, w: int) -> tuple[np.ndarray, np.ndarray]:
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    u = 0.5 * (x + y / SLOPE)
    v = 0.5 * (-x + y / SLOPE)
    return u, v


def cell_field(u: np.ndarray, v: np.ndarray, cell: float) -> tuple[np.ndarray, np.ndarray]:
    iu = np.floor(u / cell)
    vv = v / cell + 0.5 * np.mod(iu, 2.0)
    iv = np.floor(vv)
    fu = u / cell - iu
    fv = vv - iv
    dist = np.minimum(np.minimum(fu, 1.0 - fu), np.minimum(fv, 1.0 - fv))
    hashed = np.mod(np.sin(iu * 127.1 + iv * 311.7) * 43758.5453, 1.0)
    return dist, hashed.astype(np.float32)


def stone_detail(u: np.ndarray, v: np.ndarray, cell: float) -> np.ndarray:
    dist, hashed = cell_field(u, v, cell)
    joint = np.clip(1.0 - dist / JOINT, 0.0, 1.0)
    joint = joint * joint
    face = (hashed - 0.5) * 0.55
    lip = np.clip((dist - JOINT) / (JOINT * 1.4), 0.0, 1.0)
    lip = (1.0 - lip) * (1.0 - joint) * 0.18
    return face + lip - joint * 0.85


def drain_channels(u: np.ndarray, v: np.ndarray, cell: float) -> np.ndarray:
    """Every eighth module: a darker joint that votes for the camera axes."""
    iu = np.floor(u / cell)
    iv = np.floor(v / cell + 0.5 * np.mod(iu, 2.0))
    fu = np.abs((u / cell) - iu - 0.5)
    fv = np.abs((v / cell + 0.5 * np.mod(iu, 2.0)) - iv - 0.5)
    every = ((np.mod(iu, 8.0) == 0) | (np.mod(iv, 8.0) == 0)).astype(np.float32)
    line = np.clip(1.0 - np.minimum(fu, fv) / 0.06, 0.0, 1.0)
    return every * line * line


def iso_courses(u: np.ndarray, v: np.ndarray) -> np.ndarray:
    """Thin mortar courses on both ground axes. Reads as paving, not a wireframe."""
    ku = np.abs(np.mod(u + COURSE_PX / 2.0, COURSE_PX) - COURSE_PX / 2.0)
    kv = np.abs(np.mod(v + COURSE_PX / 2.0, COURSE_PX) - COURSE_PX / 2.0)
    return np.clip(1.0 - np.minimum(ku, kv) / COURSE_HALF_PX, 0.0, 1.0) ** 2


def load_v4(slug: str) -> np.ndarray | None:
    folder = FOLDERS[slug]
    for name in (f"city_{slug}_ground_v04.png", f"city_{slug}_ground_v03.png"):
        path = V4_ROOT / folder / name
        if path.exists():
            return np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)
    return None


def tile_to_plate(src: np.ndarray, size: tuple[int, int], overlap: int = 96) -> np.ndarray:
    """Repeat a painted master to `size` with a cosine seam so the join is not a hard edge."""
    out_w, out_h = size
    sh, sw = src.shape[:2]
    out = np.zeros((out_h, out_w, 3), dtype=np.float32)
    acc = np.zeros((out_h, out_w, 1), dtype=np.float32)
    step_y = max(1, sh - overlap)
    step_x = max(1, sw - overlap)
    wy = np.hanning(sh).astype(np.float32)
    wx = np.hanning(sw).astype(np.float32)
    win = (wy[:, None] * wx[None, :]).clip(0.05)[:, :, None]
    y = 0
    while y < out_h:
        x = 0
        while x < out_w:
            y1 = min(y + sh, out_h)
            x1 = min(x + sw, out_w)
            th, tw = y1 - y, x1 - x
            out[y:y1, x:x1] += src[:th, :tw] * win[:th, :tw]
            acc[y:y1, x:x1] += win[:th, :tw]
            x += step_x
        y += step_y
    return out / np.clip(acc, 1e-4, None)


def world_grids(h: int, w: int) -> tuple[np.ndarray, np.ndarray]:
    """Image (y-down) → world (y-up), matching SpriteKit's bottom-left origin."""
    xs = np.linspace(0.0, WORLD_W, w, dtype=np.float32)
    ys = np.linspace(WORLD_H, 0.0, h, dtype=np.float32)
    return np.meshgrid(xs, ys)


def in_ranges(val: np.ndarray, ranges: tuple[tuple[float, float], ...]) -> np.ndarray:
    mask = np.zeros(val.shape, dtype=np.float32)
    for a, b in ranges:
        mask = np.maximum(mask, np.clip(np.minimum(val - a, b - val) / 6.0 + 1.0, 0.0, 1.0))
    return np.clip(mask, 0.0, 1.0)


def street_masks(wx: np.ndarray, wy: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    ns = in_ranges(wx, STREETS_X)
    ew = in_ranges(wy, STREETS_Y)
    road = np.clip(np.maximum(ns, ew), 0.0, 1.0)
    # Sidewalk is a 28-unit band around each pad, not the carriageway.
    walk = np.zeros_like(road)
    for (x, y, bw, bh) in BLOCKS.values():
        band = 28.0
        inside = (
            (wx >= x - band) & (wx <= x + bw + band)
            & (wy >= y - band) & (wy <= y + bh + band)
        )
        core = (wx >= x) & (wx <= x + bw) & (wy >= y) & (wy <= y + bh)
        walk = np.maximum(walk, inside.astype(np.float32) * (1.0 - core.astype(np.float32)))
    pavement = np.clip(walk * (1.0 - road * 0.85), 0.0, 1.0)
    return road, pavement


def water_mask(wx: np.ndarray, wy: np.ndarray, slug: str) -> np.ndarray:
    # Wide fades — a hard horizontal shoreline would steal the ground-axis peak.
    if slug == "riverside":
        return np.clip((130.0 - wy) / 90.0, 0.0, 1.0)
    if slug == "wharf_ladder":
        # Full-width docks waterfront. Fade, not a knife-edge — a hard
        # shoreline steals the ±0.75 axis peak. The quay street at y ≈ 414
        # stays dry; this only covers the camera-near feet of the south lots.
        return np.clip((180.0 - wy) / 110.0, 0.0, 1.0)
    return np.zeros(wx.shape, dtype=np.float32)


def iso_street_masks(u: np.ndarray, v: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Carriageway, raised pavement, and kerb lip on the BG:EE axes.

    Wide sidewalk bands (not 4.8 m black diamonds) are what lock the camera
    while still reading as a Harborpoint street.
    """
    # u,v are image-pixel units. 8 m road ≈ 640 px; 2.5 m walk ≈ 200 px.
    period = 1680.0
    half_road = 168.0
    walk = 88.0
    kerb = 7.0
    ku = np.abs(np.mod(u + period / 2.0, period) - period / 2.0)
    kv = np.abs(np.mod(v + period / 2.0, period) - period / 2.0)
    # Smooth-min so sidewalk inner corners fillet like the V4 painted kerbs.
    k = 28.0
    d_road = -k * np.log(np.exp(np.clip(-ku / k, -40, 40)) + np.exp(np.clip(-kv / k, -40, 40)))
    road = np.clip(1.0 - (d_road - half_road) / 4.0, 0.0, 1.0)
    pave = np.clip(1.0 - (d_road - (half_road + walk)) / 5.0, 0.0, 1.0)
    pave = np.clip(pave - road, 0.0, 1.0)
    lip = np.clip(1.0 - np.abs(d_road - half_road) / kerb, 0.0, 1.0)
    return road, pave, lip


def paint(slug: str, size: tuple[int, int] = (PLATE_W, PLATE_H)) -> Image.Image:
    pal = PALETTES[slug]
    w, h = size
    wx, wy = world_grids(h, w)
    u, v = axis_uv(h, w)
    water = water_mask(wx, wy, slug)
    road, pavement, lip = iso_street_masks(u, v)
    road = road * (1.0 - water)
    pavement = pavement * (1.0 - water)
    lip = lip * (1.0 - water)

    # V4-like wet granite: very dark, cool, with a slightly warmer walk.
    road_c = np.array(pal["road"], dtype=np.float32) * 0.55
    pave_c = np.array(pal["pavement"], dtype=np.float32) * 0.62
    water_c = np.array(pal["water"], dtype=np.float32)
    yard = (0.50 * road_c + 0.50 * pave_c)
    leftover = np.clip(1.0 - water - road - pavement, 0.0, 1.0)
    mix = (
        road[..., None] * road_c
        + pavement[..., None] * pave_c
        + leftover[..., None] * yard
        + water[..., None] * water_c
    )

    sett = stone_detail(u, v, SETT_PX)
    flag = stone_detail(u, v, FLAG_PX)
    detail = sett * np.clip(1.0 - pavement * 0.65, 0.0, 1.0) + flag * pavement
    amount = 0.42 * (1.0 - 0.80 * water)
    out = mix * (1.0 + detail[..., None] * amount[..., None])
    # Kerb lip: a short, light step — not a plate-spanning black diamond.
    out = out * (1.0 - 0.18 * lip[..., None])
    out = out + np.array((8.0, 7.0, 5.0), dtype=np.float32) * (0.35 * pavement[..., None])

    _, hashed = cell_field(u, v, FLAG_PX * 2.2)
    blot = _blur(hashed * 255.0, 9.0) / 255.0
    out = out * (1.0 - 0.10 * blot[..., None]) + np.array(pal["stain"], dtype=np.float32) * (
        0.10 * blot[..., None]
    )

    nx = (wx - WORLD_W * 0.5) / WORLD_W
    ny = (wy - WORLD_H * 0.5) / WORLD_H
    vig = np.clip(1.05 - 0.32 * (nx * nx + ny * ny), 0.74, 1.06)
    out *= vig[..., None]
    lamp = np.array(pal["lamp"], dtype=np.float32)
    for lx, ly, radius, strength in (
        (240, 220, 220, 0.20),
        (2060, 220, 240, 0.18),
        (3840, 220, 220, 0.20),
        (240, 1220, 230, 0.16),
        (2060, 1220, 260, 0.14),
        (3840, 1220, 230, 0.16),
        (240, 2060, 220, 0.18),
        (2060, 2060, 240, 0.16),
        (3840, 2060, 220, 0.18),
    ):
        d2 = (wx - lx) ** 2 + (wy - ly) ** 2
        pool = np.exp(-d2 / (2.0 * radius * radius)) * strength * (1.0 - water)
        out = out + lamp * pool[..., None]

    puddle = np.clip((_blur(hashed * 255.0, 20.0) / 255.0 - 0.58) * 3.2, 0.0, 1.0)
    puddle *= (1.0 - water) * (0.40 + 0.60 * road)
    out = out + np.array((16.0, 22.0, 30.0), dtype=np.float32) * (0.28 * puddle[..., None])

    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB")


def obstacles_for(slug: str) -> list[tuple[float, float, float, float]]:
    pads = list(BLOCKS.values())
    if slug == "riverside":
        pads = [BLOCKS["nw"], BLOCKS["ne"], BLOCKS["sw"], (0.0, 0.0, WORLD_W, 140.0)]
    elif slug == "wharf_ladder":
        pads = list(BLOCKS.values()) + [(0.0, 0.0, WORLD_W, 160.0)]
    elif slug == "harborpoint_pd":
        # Station sits on NE; a thin plaza wall on the south face of mid street.
        pads = [
            BLOCKS["ne"],
            BLOCKS["nw"],
            BLOCKS["se"],
            (1880.0, 1380.0, 360.0, 40.0),
        ]
    elif slug == "civic_records":
        pads = [BLOCKS["nw"], BLOCKS["ne"], BLOCKS["se"], (900.0, 420.0, 700.0, 280.0)]
    return pads


def disc_hits(x: float, y: float, rect: tuple[float, float, float, float], radius: float) -> bool:
    rx, ry, rw, rh = rect
    nx = min(max(x, rx), rx + rw)
    ny = min(max(y, ry), ry + rh)
    return (x - nx) ** 2 + (y - ny) ** 2 <= radius * radius


def is_passable(x: float, y: float, pads: list[tuple[float, float, float, float]]) -> bool:
    if not (AGENT_RADIUS <= x <= WORLD_W - AGENT_RADIUS and AGENT_RADIUS <= y <= WORLD_H - AGENT_RADIUS):
        return False
    return not any(disc_hits(x, y, pad, AGENT_RADIUS) for pad in pads)


def nearest_walkable(
    x: float, y: float, pads: list[tuple[float, float, float, float]]
) -> tuple[float, float] | None:
    if is_passable(x, y, pads):
        return (x, y)
    for radius in range(4, 240, 4):
        for ang in range(0, 360, 15):
            rad = np.radians(ang)
            cx = x + radius * float(np.cos(rad))
            cy = y + radius * float(np.sin(rad))
            if is_passable(cx, cy, pads):
                return (cx, cy)
    return None


PROPS = ROOT / "RainShadow Shared" / "Resources" / "Art" / "Props" / "CityDistrict" / "V2"


def flatten_interior_alpha(im: Image.Image, *, floor: int = 36) -> Image.Image:
    """Push painted pixels to opaque; keep only the sub-floor AA fringe.

    Several shipped facades store the brick face itself at ~130 alpha, so an
    erode-from-opaque-core cannot find an interior. Against a contrasting
    ground that reads as a glass building.
    """
    rgba = np.array(im.convert("RGBA"))
    alpha = rgba[:, :, 3]
    rgba[:, :, 3] = np.where(alpha > floor, 255, alpha)
    return Image.fromarray(rgba, "RGBA")


def flatten_city_sprites() -> int:
    """Opaque-up runtime building and door sprites. Skips Finder ` 2.png` dupes."""
    if not PROPS.exists():
        print("  no props dir")
        return 0
    count = 0
    for path in (
        sorted(PROPS.glob("city_building_*.png"))
        + sorted(PROPS.glob("city_door_*.png"))
        + sorted(PROPS.glob("city_terrace_*.png"))
    ):
        if " 2.png" in path.name:
            continue
        im = Image.open(path)
        if im.mode != "RGBA":
            continue
        out = flatten_interior_alpha(im)
        before = np.asarray(im.convert("RGBA"))[:, :, 3]
        after = np.asarray(out)[:, :, 3]
        if not np.array_equal(before, after):
            out.save(path, "PNG", compress_level=4)
            count += 1
            mid_before = ((before > 40) & (before < 250)).mean()
            mid_after = ((after > 40) & (after < 250)).mean()
            print(f"  flatten {path.name:36s} mid-alpha {mid_before:.3f} → {mid_after:.3f}")
    return count


def hardlink_or_copy(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists() or dst.is_symlink():
        dst.unlink()
    try:
        os.link(src, dst)
    except OSError:
        import shutil

        shutil.copy2(src, dst)


def install_one(slug: str) -> dict:
    folder = FOLDERS[slug]
    plate = paint(slug)
    AREAS.mkdir(parents=True, exist_ok=True)
    gen_dir = GEN / folder
    gen_dir.mkdir(parents=True, exist_ok=True)
    ground_name = f"city_{slug}_ground_v02.png"
    runtime = AREAS / ground_name
    plate.save(runtime, "PNG", compress_level=3)
    hardlink_or_copy(runtime, AREAS / f"city_{slug}_block_v02.png")
    hardlink_or_copy(runtime, gen_dir / ground_name)
    hardlink_or_copy(runtime, gen_dir / f"city_{slug}_block_v02.png")
    MAPS.mkdir(parents=True, exist_ok=True)
    plate.resize(MAP_SIZE, Image.Resampling.LANCZOS).save(
        MAPS / f"map_city_{slug}_v02.png", "PNG", compress_level=4
    )
    result = qa.grade(runtime)
    result["passes_city"] = result["worst_delta"] <= CITY_TOLERANCE_DEG
    density = plate.size[0] / WORLD_W
    print(
        f"  {slug:16s} {plate.size[0]}x{plate.size[1]}  "
        f"axes {result['peak_pos']:+.2f}/{result['peak_neg']:+.2f}  "
        f"worst {result['worst_delta']:.2f}  density {density:.2f}  "
        f"{'PASS' if result['passes_city'] else 'FAIL'}"
    )
    return result


def report_nav(slug: str) -> None:
    pads = obstacles_for(slug)
    seeds = {
        "actorStart/south": (2060.0, 220.0),
        "from.north": (2060.0, 2140.0),
        "from.south": (2060.0, 220.0),
        "from.east": (3880.0, 1220.0),
        "from.west": (220.0, 1220.0),
        "portal.south_of_se": (3300.0, 300.0),
        "portal.south_of_sw": (1100.0, 300.0),
        "portal.south_of_ne": (2800.0, 1280.0),
        "portal.south_of_nw": (1100.0, 1280.0),
    }
    print(f"# {slug} snapped")
    for name, (x, y) in seeds.items():
        snapped = nearest_walkable(x, y, pads)
        print(f"  {name:22s} {snapped}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("slugs", nargs="*", default=list(FOLDERS))
    ap.add_argument("--report-nav", action="store_true")
    ap.add_argument("--skip-install", action="store_true")
    ap.add_argument("--flatten-sprites", action="store_true")
    args = ap.parse_args()
    if args.flatten_sprites:
        n = flatten_city_sprites()
        print(f"flattened {n} sprites")
        if args.skip_install and not args.report_nav:
            return 0
    unknown = [s for s in args.slugs if s not in FOLDERS]
    if unknown:
        raise SystemExit(f"unknown district(s): {unknown}")
    print(
        f"WORLD={WORLD_W:.0f}x{WORLD_H:.0f}  PLATE={PLATE_W}x{PLATE_H}  "
        f"px/unit={PX_PER_UNIT:.3f}  sett={SETT_PX:.2f}px  flag={FLAG_PX:.2f}px  "
        f"city-gate {CITY_TOLERANCE_DEG}°"
    )
    if args.report_nav:
        for slug in args.slugs:
            report_nav(slug)
        if args.skip_install:
            return 0
    ok = True
    if not args.skip_install:
        n = flatten_city_sprites()
        print(f"flattened {n} sprites")
        for slug in args.slugs:
            r = install_one(slug)
            ok = ok and r["passes_city"]
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())

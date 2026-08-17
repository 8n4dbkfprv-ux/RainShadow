#!/usr/bin/env python3
"""Process Act I city masters into runtime plates and modular props.

Masters must be painted under `ArtSource/Prompts/city_perspective_lock_v03.md`
(Baldur's Gate: EE orthographic camera). This script has no projection math —
it only copies/resizes district block + ground plates to 4096×2304 and slices
chroma (or corner-keyed) building/prop sheets into Props/CityDistrict/V2.

After regenerating V3 masters: re-measure door apertures, re-derive street-side
portal approaches, and flood-fill every spawn (see
`Documentation/BGEEProjectionMasterRegen.md`).

Do not run `main()` to refresh grounds. A 1536 V3 master resized to
`PLATE_SIZE` is a naked upscale and would pass `qa_plate_density.py`
dishonestly. Use `install_city_grounds_density_v04.py`.
"""

from __future__ import annotations

import shutil
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ASSETS = Path.home() / ".cursor" / "projects" / "Users-laurensvanoorschot-Desktop-RainShadow" / "assets"
GEN = ROOT / "ArtSource" / "Generated" / "CityDistrict" / "V2"
RUNTIME_AREAS = ROOT / "RainShadow Shared" / "Resources" / "Art" / "Areas" / "CityDistrict" / "V2"
RUNTIME_PROPS = ROOT / "RainShadow Shared" / "Resources" / "Art" / "Props" / "CityDistrict" / "V2"
RUNTIME_MAP = ROOT / "RainShadow Shared" / "Resources" / "Art" / "UI" / "Map"

PLATE_SIZE = (8192, 4608)
MAP_SIZE = (1847, 1040)

DISTRICTS = [
    ("sable_row", "SableRow", 3, 2, [
        "city_building_voss_stoop",
        "city_building_tenement",
        "city_building_storefront",
        "city_building_rowhouse",
        "city_building_shop",
        "city_building_gatehouse",
    ]),
    ("wharf_ladder", "WharfLadder", 2, 2, [
        "city_building_shipping_office",
        "city_building_warehouse",
        "city_building_boarding",
        "city_building_dock_shed",
    ]),
    ("riverside", "Riverside", 2, 2, [
        "city_building_iron_stairs",
        "city_building_river_watch",
        "city_building_rail_lamp",
        "city_building_abutment",
    ]),
    ("harborpoint_pd", "HarborpointPD", 2, 2, [
        "city_building_pd_station",
        "city_building_pd_annex",
        "city_building_pd_alley",
        "city_building_pd_plaza_wall",
    ]),
    ("lila_street", "LilaStreet", 2, 2, [
        "city_building_lila_rooms",
        "city_building_lila_neighbor",
        "city_building_lila_opposite",
        "city_building_lila_alcove",
    ]),
    ("civic_records", "CivicRecords", 2, 2, [
        "city_building_records_annex",
        "city_building_records_wing",
        "city_building_records_colonnade",
        "city_building_records_plaza",
    ]),
]

PROP_CELLS = [
    "city_prop_lamp",
    "city_prop_bench",
    "city_prop_car_black",
    "city_prop_car_olive",
    "city_prop_car_maroon",
    "city_prop_kiosk",
    "city_prop_crates_mail",
    "city_prop_gate",
    "city_prop_statue",
]

SOLOS = [
    # Prefer empty-aperture solos (door leaves are separate city_door_* props).
    ("city_voss_stoop_solo_v04.png", "city_building_voss_stoop", "SableRow"),
    ("city_voss_stoop_solo_v03.png", "city_building_voss_stoop", "SableRow"),
    ("city_shipping_office_solo_v03.png", "city_building_shipping_office", "WharfLadder"),
    ("city_shipping_office_solo_v02.png", "city_building_shipping_office", "WharfLadder"),
    ("city_iron_stairs_solo_v03.png", "city_building_iron_stairs", "Riverside"),
    ("city_iron_stairs_solo_v02.png", "city_building_iron_stairs", "Riverside"),
]

# Per-building empty-aperture masters (precise-object-edit). Override sheet slices.
EMPTY_APERTURE_BUILDINGS = [
    ("city_building_voss_stoop_empty_v01.png", "city_building_voss_stoop", "SableRow"),
    ("city_building_tenement_empty_v01.png", "city_building_tenement", "SableRow"),
    ("city_building_storefront_empty_v01.png", "city_building_storefront", "SableRow"),
    ("city_building_rowhouse_empty_v01.png", "city_building_rowhouse", "SableRow"),
    ("city_building_shop_empty_v01.png", "city_building_shop", "SableRow"),
    ("city_building_gatehouse_empty_v01.png", "city_building_gatehouse", "SableRow"),
    ("city_building_shipping_office_empty_v01.png", "city_building_shipping_office", "WharfLadder"),
    ("city_building_warehouse_empty_v01.png", "city_building_warehouse", "WharfLadder"),
    ("city_building_boarding_empty_v01.png", "city_building_boarding", "WharfLadder"),
    ("city_building_dock_shed_empty_v01.png", "city_building_dock_shed", "WharfLadder"),
    ("city_building_iron_stairs_empty_v01.png", "city_building_iron_stairs", "Riverside"),
    ("city_building_river_watch_empty_v01.png", "city_building_river_watch", "Riverside"),
    ("city_building_pd_station_empty_v01.png", "city_building_pd_station", "HarborpointPD"),
    ("city_building_pd_annex_empty_v01.png", "city_building_pd_annex", "HarborpointPD"),
    ("city_building_pd_alley_empty_v01.png", "city_building_pd_alley", "HarborpointPD"),
    ("city_building_lila_rooms_empty_v01.png", "city_building_lila_rooms", "LilaStreet"),
    ("city_building_lila_neighbor_empty_v01.png", "city_building_lila_neighbor", "LilaStreet"),
    ("city_building_lila_opposite_empty_v01.png", "city_building_lila_opposite", "LilaStreet"),
    ("city_building_lila_alcove_empty_v01.png", "city_building_lila_alcove", "LilaStreet"),
    ("city_building_records_annex_empty_v01.png", "city_building_records_annex", "CivicRecords"),
    ("city_building_records_wing_empty_v01.png", "city_building_records_wing", "CivicRecords"),
    ("city_building_records_colonnade_empty_v01.png", "city_building_records_colonnade", "CivicRecords"),
]

DOOR_SOLOS = [
    ("city_door_voss_stoop_v01.png", "city_door_voss_stoop"),
    ("city_door_voss_stoop_garage_v01.png", "city_door_voss_stoop_garage"),
    ("city_door_tenement_v01.png", "city_door_tenement"),
    ("city_door_storefront_v01.png", "city_door_storefront"),
    ("city_door_rowhouse_v01.png", "city_door_rowhouse"),
    ("city_door_shop_v01.png", "city_door_shop"),
    ("city_door_gatehouse_v01.png", "city_door_gatehouse"),
    ("city_door_shipping_office_v01.png", "city_door_shipping_office"),
    ("city_door_warehouse_v01.png", "city_door_warehouse"),
    ("city_door_boarding_v01.png", "city_door_boarding"),
    ("city_door_dock_shed_v01.png", "city_door_dock_shed"),
    ("city_door_iron_stairs_v01.png", "city_door_iron_stairs"),
    ("city_door_river_watch_v01.png", "city_door_river_watch"),
    ("city_door_pd_station_v01.png", "city_door_pd_station"),
    ("city_door_pd_annex_v01.png", "city_door_pd_annex"),
    ("city_door_pd_alley_v01.png", "city_door_pd_alley"),
    ("city_door_lila_rooms_v01.png", "city_door_lila_rooms"),
    ("city_door_lila_rooms_b_v01.png", "city_door_lila_rooms_b"),
    ("city_door_lila_neighbor_v01.png", "city_door_lila_neighbor"),
    ("city_door_lila_opposite_v01.png", "city_door_lila_opposite"),
    ("city_door_lila_alcove_v01.png", "city_door_lila_alcove"),
    ("city_door_records_annex_v01.png", "city_door_records_annex"),
    ("city_door_records_wing_v01.png", "city_door_records_wing"),
    ("city_door_records_colonnade_v01.png", "city_door_records_colonnade"),
]


def find_source(name: str) -> Path | None:
    search_roots = (
        ASSETS,
        GEN / "Doors",
        GEN / "Shared",
        *(GEN / d for _, d, *_ in DISTRICTS),
    )
    for base in search_roots:
        candidate = base / name
        if candidate.exists():
            return candidate
    for path in GEN.rglob(name):
        return path
    return None


def chroma_or_corner_key(im: Image.Image, tol: float = 42.0, soft: float = 16.0) -> Image.Image:
    rgba = np.array(im.convert("RGBA"), dtype=np.float32)
    rgb = rgba[:, :, :3]
    h, w = rgb.shape[:2]
    corners = np.stack([
        rgb[2, 2], rgb[2, w - 3], rgb[h - 3, 2], rgb[h - 3, w - 3]
    ]).mean(axis=0)
    # Prefer vivid green when present
    g = rgb[:, :, 1]
    r = rgb[:, :, 0]
    b = rgb[:, :, 2]
    greenish = (g > r + 25) & (g > b + 25) & (g > 80)
    green_ratio = float(greenish.mean())
    if green_ratio > 0.08:
        key = np.array([0.0, 255.0, 0.0], dtype=np.float32)
    else:
        key = corners.astype(np.float32)
    dist = np.linalg.norm(rgb - key, axis=2)
    alpha = np.clip((dist - tol) / soft * 255.0, 0, 255)
    # Also kill near-white sheet backgrounds
    near_white = (rgb.min(axis=2) > 220) & (rgb.mean(axis=2) > 235)
    alpha = np.where(near_white, 0, alpha)
    if green_ratio > 0.08:
        alpha = np.where(greenish, 0, alpha)
    spill = np.clip(1.0 - dist / (tol + soft + 40.0), 0, 1)
    lum = rgb.mean(axis=2, keepdims=True)
    rgb = rgb * (1.0 - spill[..., None] * 0.7) + lum * (spill[..., None] * 0.7)
    rgb = np.where(alpha[..., None] < 8, 0, rgb)
    return Image.fromarray(np.dstack([rgb, alpha]).astype(np.uint8), "RGBA")


def trim_alpha(im: Image.Image, threshold: int = 28, pad: int = 4) -> Image.Image:
    a = np.array(im.split()[-1])
    ys, xs = np.where(a > threshold)
    if len(xs) == 0:
        return im
    return im.crop((
        max(0, int(xs.min()) - pad),
        max(0, int(ys.min()) - pad),
        min(im.width, int(xs.max()) + 1 + pad),
        min(im.height, int(ys.max()) + 1 + pad),
    ))


def fit_canvas(im: Image.Image, canvas: tuple[int, int], target_h: int | None = None) -> Image.Image:
    cw, ch = canvas
    if im.width == 0 or im.height == 0:
        return Image.new("RGBA", canvas, (0, 0, 0, 0))
    a = np.array(im.split()[-1])
    ys, xs = np.where(a > 28)
    content_h = int(ys.max() - ys.min() + 1) if len(ys) else im.height
    if target_h and content_h > 0:
        scale = min((target_h / content_h) * 0.98, (cw * 0.94) / im.width, (ch * 0.94) / im.height)
    else:
        scale = min(cw / im.width, ch / im.height) * 0.94
    nw = max(1, int(round(im.width * scale)))
    nh = max(1, int(round(im.height * scale)))
    resized = im.resize((nw, nh), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", canvas, (0, 0, 0, 0))
    x = (cw - nw) // 2
    y = max(0, ch - nh - 4)
    out.alpha_composite(resized, (x, y))
    return out


def slice_grid(sheet: Image.Image, cols: int, rows: int, inset: float = 0.03) -> list[Image.Image]:
    cw, ch = sheet.width // cols, sheet.height // rows
    cells = []
    for row in range(rows):
        for col in range(cols):
            x0 = int(col * cw + cw * inset)
            y0 = int(row * ch + ch * inset)
            x1 = int((col + 1) * cw - cw * inset)
            y1 = int((row + 1) * ch - ch * inset)
            cells.append(sheet.crop((x0, y0, x1, y1)))
    return cells


# A master whose aspect differs from the runtime plate cannot be resized
# straight to it: scaling x and y by different factors multiplies every ground
# slope by sy/sx, so an on-lock 0.75 master silently lands off the BG:EE lock.
# A 3:2 master taken straight to 4096×2304 shears 36.87° down to 31.7°.
# Centre-crop to the target aspect first, then scale uniformly.
ASPECT_EPSILON = 0.002


def fit_to_aspect(im: Image.Image, size: tuple[int, int]) -> Image.Image:
    """Centre-crop to the target aspect, then scale uniformly.

    For a master already at the target aspect this is a no-op crop followed by
    the same resize the caller would have done, so output is unchanged.
    """
    tw, th = size
    target = tw / th
    source = im.width / im.height
    if abs(source - target) > ASPECT_EPSILON:
        if source > target:
            cw, ch = int(round(im.height * target)), im.height
        else:
            cw, ch = im.width, int(round(im.width / target))
        left, top = (im.width - cw) // 2, (im.height - ch) // 2
        print(
            f"  aspect {source:.4f} != {target:.4f}: centre-cropping to "
            f"{cw}x{ch} before scaling (a direct resize would shear the "
            f"ground axes by {source / target:.3f}x)"
        )
        im = im.crop((left, top, left + cw, top + ch))
    return im.resize(size, Image.Resampling.LANCZOS)


def resize_plate(src: Path, dst: Path, size: tuple[int, int]) -> None:
    im = Image.open(src).convert("RGB")
    out = fit_to_aspect(im, size)
    dst.parent.mkdir(parents=True, exist_ok=True)
    out.save(dst, "PNG", optimize=True)
    print(f"plate {dst.relative_to(ROOT)} {out.size}")


def retain_master(src: Path, district_dir: Path, name: str) -> Path:
    district_dir.mkdir(parents=True, exist_ok=True)
    dst = district_dir / name
    if src.resolve() != dst.resolve():
        shutil.copy2(src, dst)
    return dst


def process_district(slug: str, folder: str, cols: int, rows: int, names: list[str]) -> None:
    gen_dir = GEN / folder
    block_name = f"city_{slug}_block_v02.png"
    ground_name = f"city_{slug}_ground_v02.png"
    sheet_name = f"city_{slug}_buildings_sheet_v02.png"

    block_src = find_source(block_name)
    ground_src = find_source(ground_name)
    sheet_src = find_source(sheet_name)
    if not block_src or not ground_src:
        raise SystemExit(f"Missing block/ground for {slug}: {block_src} {ground_src}")

    retain_master(block_src, gen_dir, block_name)
    retain_master(ground_src, gen_dir, ground_name)

    resize_plate(block_src, RUNTIME_AREAS / f"city_{slug}_block_v02.png", PLATE_SIZE)
    resize_plate(ground_src, RUNTIME_AREAS / f"city_{slug}_ground_v02.png", PLATE_SIZE)
    # Area-map texture (HUD-sized)
    resize_plate(block_src, RUNTIME_MAP / f"map_city_{slug}_v02.png", MAP_SIZE)

    if sheet_src:
        retain_master(sheet_src, gen_dir, sheet_name)
        sheet = chroma_or_corner_key(Image.open(sheet_src))
        sheet.save(gen_dir / f"city_{slug}_buildings_sheet_rgba_v02.png")
        cells = slice_grid(sheet, cols, rows)
        RUNTIME_PROPS.mkdir(parents=True, exist_ok=True)
        for name, cell in zip(names, cells):
            prop = fit_canvas(trim_alpha(cell), (512, 640), target_h=480)
            out = RUNTIME_PROPS / f"{name}.png"
            prop.save(out, "PNG", optimize=True)
            prop.save(gen_dir / f"{name}.png", "PNG")
            print(f"building {out.name}")


def process_shared_props() -> None:
    src = find_source("city_shared_street_props_sheet_v02.png")
    if not src:
        raise SystemExit("Missing shared street props sheet")
    shared = GEN / "Shared"
    retain_master(src, shared, src.name)
    sheet = chroma_or_corner_key(Image.open(src))
    sheet.save(shared / "city_shared_street_props_sheet_rgba_v02.png")
    cells = slice_grid(sheet, 3, 3)
    RUNTIME_PROPS.mkdir(parents=True, exist_ok=True)
    for name, cell in zip(PROP_CELLS, cells):
        canvas = (512, 512) if "lamp" in name or "statue" in name else (512, 384)
        target = 420 if "lamp" in name else 280
        prop = fit_canvas(trim_alpha(cell), canvas, target_h=target)
        out = RUNTIME_PROPS / f"{name}.png"
        prop.save(out, "PNG", optimize=True)
        prop.save(shared / f"{name}.png", "PNG")
        print(f"prop {out.name}")


def process_solos() -> None:
    shipped: set[str] = set()
    for filename, runtime_name, folder in SOLOS:
        if runtime_name in shipped:
            continue
        src = find_source(filename)
        if not src:
            print(f"skip solo {filename}")
            continue
        gen_dir = GEN / folder
        retain_master(src, gen_dir, filename)
        prop = fit_canvas(trim_alpha(chroma_or_corner_key(Image.open(src))), (512, 640), target_h=500)
        out = RUNTIME_PROPS / f"{runtime_name}.png"
        RUNTIME_PROPS.mkdir(parents=True, exist_ok=True)
        prop.save(out, "PNG", optimize=True)
        prop.save(gen_dir / f"{runtime_name}_solo.png", "PNG")
        shipped.add(runtime_name)
        print(f"solo override {out.name} <- {filename}")


def process_empty_aperture_buildings() -> None:
    """Ship precise-object-edit facades with door leaves removed."""
    for filename, runtime_name, folder in EMPTY_APERTURE_BUILDINGS:
        src = find_source(filename)
        if not src:
            print(f"skip empty aperture {filename}")
            continue
        gen_dir = GEN / folder
        retain_master(src, gen_dir, filename)
        src_im = Image.open(src).convert("RGBA")
        alpha = np.array(src_im.split()[-1])
        # Keep true alpha masters; otherwise key flat black/green surrounds.
        keyed = src_im if float((alpha < 8).mean()) > 0.05 else chroma_or_corner_key(src_im)
        prop = fit_canvas(trim_alpha(keyed), (512, 640), target_h=500)
        out = RUNTIME_PROPS / f"{runtime_name}.png"
        RUNTIME_PROPS.mkdir(parents=True, exist_ok=True)
        prop.save(out, "PNG", optimize=True)
        prop.save(gen_dir / f"{runtime_name}_empty.png", "PNG")
        print(f"empty aperture {out.name}")


def process_doors() -> None:
    """Ship separate dimetric outdoor door leaves."""
    doors_dir = GEN / "Doors"
    doors_dir.mkdir(parents=True, exist_ok=True)
    for filename, runtime_name in DOOR_SOLOS:
        src = find_source(filename)
        if not src:
            print(f"skip door {filename}")
            continue
        retain_master(src, doors_dir, filename)
        keyed = chroma_or_corner_key(Image.open(src))
        prop = fit_canvas(trim_alpha(keyed), (256, 384), target_h=280)
        out = RUNTIME_PROPS / f"{runtime_name}.png"
        RUNTIME_PROPS.mkdir(parents=True, exist_ok=True)
        prop.save(out, "PNG", optimize=True)
        prop.save(doors_dir / f"{runtime_name}.png", "PNG")
        print(f"door {out.name}")


def main() -> None:
    RUNTIME_AREAS.mkdir(parents=True, exist_ok=True)
    RUNTIME_PROPS.mkdir(parents=True, exist_ok=True)
    for slug, folder, cols, rows, names in DISTRICTS:
        process_district(slug, folder, cols, rows, names)
    process_shared_props()
    process_solos()
    process_empty_aperture_buildings()
    process_doors()
    # Compatibility aliases used by Sable Row hub (primary playable names)
    shutil.copy2(
        RUNTIME_AREAS / "city_sable_row_block_v02.png",
        ROOT / "RainShadow Shared" / "Resources" / "Art" / "Areas" / "CityDistrict" / "city_district_block_v02.png",
    )
    shutil.copy2(
        RUNTIME_AREAS / "city_sable_row_ground_v02.png",
        ROOT / "RainShadow Shared" / "Resources" / "Art" / "Areas" / "CityDistrict" / "city_district_ground_v02.png",
    )
    print("done")


if __name__ == "__main__":
    import sys

    if len(sys.argv) > 1 and sys.argv[1] == "doors":
        RUNTIME_PROPS.mkdir(parents=True, exist_ok=True)
        process_empty_aperture_buildings()
        process_doors()
        print("doors pass done")
    else:
        main()

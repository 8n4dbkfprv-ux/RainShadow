#!/usr/bin/env python3
"""Install on-lock V3 city grounds + sliced landmark/door sheets.

Does not run `process_city_districts_v02.main()` and does not touch the office
or flip `ie_projection.ACTIVE`. Riverside was installed earlier by
`install_riverside_bgee_v03.py` and is skipped unless --include-riverside.

Grounds go through `composite_city_ground_density_v04` before landing at
`PLATE_SIZE` (4096×2304). A naked `fit_to_aspect` of the 1536 V3 master
would pass `qa_plate_density.py` by adding empty pixels.
"""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import composite_city_ground_density_v04 as dens
import process_city_districts_v02 as proc
import qa_plate_projection as qa

ROOT = Path(__file__).resolve().parents[2]
CAND = ROOT / "ArtSource" / "Generated" / "BGEEProjectionCandidates"
GEN = ROOT / "ArtSource" / "Generated" / "CityDistrict" / "V2"
AREAS = ROOT / "RainShadow Shared" / "Resources" / "Art" / "Areas" / "CityDistrict" / "V2"
PROPS = ROOT / "RainShadow Shared" / "Resources" / "Art" / "Props" / "CityDistrict" / "V2"
MAPS = ROOT / "RainShadow Shared" / "Resources" / "Art" / "UI" / "Map"
DOORS = GEN / "Doors"

DISTRICTS = {
    "sable_row": {
        "folder": "SableRow",
        "ground": "city_sable_row_ground_v03.png",
        "buildings": (
            "city_sable_buildings_sheet_v03.png",
            3,
            2,
            [
                "city_building_voss_stoop",
                "city_building_tenement",
                "city_building_storefront",
                "city_building_rowhouse",
                "city_building_shop",
                "city_building_gatehouse",
            ],
        ),
        "doors": (
            "city_sable_doors_sheet_v03.png",
            [
                "city_door_voss_stoop",
                "city_door_voss_stoop_garage",
                "city_door_tenement",
                "city_door_storefront",
                "city_door_rowhouse",
                "city_door_shop",
                "city_door_gatehouse",
            ],
        ),
    },
    "wharf_ladder": {
        "folder": "WharfLadder",
        "ground": "city_wharf_ladder_ground_v03.png",
        "buildings": (
            "city_wharf_buildings_sheet_v03.png",
            2,
            2,
            [
                "city_building_shipping_office",
                "city_building_warehouse",
                "city_building_boarding",
                "city_building_dock_shed",
            ],
        ),
        "doors": (
            "city_wharf_doors_sheet_v03.png",
            [
                "city_door_shipping_office",
                "city_door_warehouse",
                "city_door_boarding",
                "city_door_dock_shed",
            ],
        ),
    },
    "harborpoint_pd": {
        "folder": "HarborpointPD",
        "ground": "city_harborpoint_pd_ground_v03.png",
        "buildings": (
            "city_pd_buildings_sheet_v03.png",
            2,
            2,
            [
                "city_building_pd_station",
                "city_building_pd_annex",
                "city_building_pd_alley",
                "city_building_pd_plaza_wall",
            ],
        ),
        "doors": (
            "city_pd_doors_sheet_v03.png",
            [
                "city_door_pd_station",
                "city_door_pd_annex",
                "city_door_pd_alley",
            ],
        ),
    },
    "lila_street": {
        "folder": "LilaStreet",
        "ground": "city_lila_street_ground_v03.png",
        "buildings": (
            "city_lila_buildings_sheet_v03.png",
            2,
            2,
            [
                "city_building_lila_rooms",
                "city_building_lila_neighbor",
                "city_building_lila_opposite",
                "city_building_lila_alcove",
            ],
        ),
        "doors": (
            "city_lila_doors_sheet_v03.png",
            [
                "city_door_lila_rooms",
                "city_door_lila_rooms_b",
                "city_door_lila_neighbor",
                "city_door_lila_opposite",
                "city_door_lila_alcove",
            ],
        ),
    },
    "civic_records": {
        "folder": "CivicRecords",
        "ground": "city_civic_records_ground_v03.png",
        "buildings": (
            "city_civic_buildings_sheet_v03.png",
            2,
            2,
            [
                "city_building_records_annex",
                "city_building_records_wing",
                "city_building_records_colonnade",
                "city_building_records_plaza",
            ],
        ),
        "doors": (
            "city_civic_doors_sheet_v03.png",
            [
                "city_door_records_annex",
                "city_door_records_wing",
                "city_door_records_colonnade",
            ],
        ),
    },
}


def content_height(im: Image.Image) -> int:
    a = np.array(im.split()[-1])
    ys, _ = np.where(a > 28)
    return int(ys.max() - ys.min() + 1) if len(ys) else im.height


def install_plate(src: Path, dst: Path, size: tuple[int, int]) -> None:
    im = Image.open(src).convert("RGB")
    out = proc.fit_to_aspect(im, size)
    dst.parent.mkdir(parents=True, exist_ok=True)
    out.save(dst, "PNG", optimize=True)
    print(f"  plate {dst.relative_to(ROOT)} {out.size}")


def install_prop(src_im: Image.Image, dst: Path, canvas: tuple[int, int], target_h: int) -> Image.Image:
    keyed = proc.chroma_or_corner_key(src_im)
    prop = proc.fit_canvas(proc.trim_alpha(keyed), canvas, target_h=target_h)
    dst.parent.mkdir(parents=True, exist_ok=True)
    prop.save(dst, "PNG", optimize=True)
    print(f"  prop  {dst.name} content_h={content_height(prop)}")
    return prop


def slice_grid(sheet: Image.Image, cols: int, rows: int) -> list[Image.Image]:
    return proc.slice_grid(proc.chroma_or_corner_key(sheet), cols, rows)


def slice_door_row(sheet: Image.Image, expected: int) -> list[Image.Image]:
    """Split a chroma door strip into left-to-right blobs."""
    keyed = proc.chroma_or_corner_key(sheet)
    a = np.array(keyed.split()[-1])
    col = (a > 28).any(axis=0)
    blobs: list[tuple[int, int]] = []
    x = 0
    w = col.shape[0]
    while x < w:
        while x < w and not col[x]:
            x += 1
        if x >= w:
            break
        x0 = x
        while x < w and col[x]:
            x += 1
        if x - x0 > 12:
            blobs.append((x0, x))
    if len(blobs) != expected:
        print(f"  warn: door strip found {len(blobs)} blobs, expected {expected}")
    cells = []
    for x0, x1 in blobs[:expected]:
        pad = 4
        cells.append(keyed.crop((max(0, x0 - pad), 0, min(w, x1 + pad), keyed.height)))
    return cells


def install_district(slug: str, spec: dict) -> bool:
    src_dir = CAND / spec["folder"]
    gen_dir = GEN / spec["folder"]
    gen_dir.mkdir(parents=True, exist_ok=True)
    DOORS.mkdir(parents=True, exist_ok=True)
    PROPS.mkdir(parents=True, exist_ok=True)

    ground = src_dir / spec["ground"]
    if not ground.exists():
        raise SystemExit(f"missing {ground}")
    master = Image.open(ground)
    plate = dens.composite(master, proc.PLATE_SIZE)
    dens.assert_not_naked_upscale(master, plate)
    plate.save(AREAS / f"city_{slug}_ground_v02.png", "PNG", optimize=True)
    plate.save(AREAS / f"city_{slug}_block_v02.png", "PNG", optimize=True)
    plate.save(gen_dir / f"city_{slug}_ground_v02.png", "PNG", optimize=True)
    plate.save(gen_dir / f"city_{slug}_block_v02.png", "PNG", optimize=True)
    install_plate(ground, MAPS / f"map_city_{slug}_v02.png", proc.MAP_SIZE)

    sheet_name, cols, rows, names = spec["buildings"]
    sheet_src = src_dir / sheet_name
    shutil.copy2(sheet_src, gen_dir / sheet_name)
    cells = slice_grid(Image.open(sheet_src), cols, rows)
    for name, cell in zip(names, cells):
        prop = install_prop(cell, PROPS / f"{name}.png", (512, 640), 500)
        prop.save(gen_dir / f"{name}.png", "PNG")

    door_name, door_names = spec["doors"]
    door_src = src_dir / door_name
    shutil.copy2(door_src, DOORS / door_name)
    door_cells = slice_door_row(Image.open(door_src), len(door_names))
    for name, cell in zip(door_names, door_cells):
        prop = install_prop(cell, PROPS / f"{name}.png", (256, 384), 280)
        prop.save(DOORS / f"{name}.png", "PNG")

    r = qa.grade(AREAS / f"city_{slug}_ground_v02.png")
    tag = "PASS" if r["passes"] else "FAIL"
    print(
        f"  installed {slug} axes {r['peak_pos']:+.2f} / {r['peak_neg']:+.2f}  "
        f"worst {r['worst_delta']:.2f}  {tag}"
    )
    return r["passes"]


def main() -> int:
    slugs = [s for s in DISTRICTS if s != "riverside"]
    if len(sys.argv) > 1:
        slugs = sys.argv[1:]
    ok = True
    for slug in slugs:
        print(f"== {slug} ==")
        ok = install_district(slug, DISTRICTS[slug]) and ok
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())

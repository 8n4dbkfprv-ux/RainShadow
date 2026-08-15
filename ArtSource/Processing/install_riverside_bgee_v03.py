#!/usr/bin/env python3
"""Install the on-lock Riverside V3 masters into runtime art.

Does not run `process_city_districts_v02.main()` — that walks every district
and would clobber the other five. This copies only Riverside plates and the
four riverside landmarks + two door leaves.

Masters live in `ArtSource/Generated/BGEEProjectionCandidates/Riverside/`.
The pipeline camera (`ie_projection.ACTIVE`) stays on LEGACY_V2; only these
pixels switch.
"""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import process_city_districts_v02 as proc
import qa_plate_projection as qa

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "ArtSource" / "Generated" / "BGEEProjectionCandidates" / "Riverside"
GEN = ROOT / "ArtSource" / "Generated" / "CityDistrict" / "V2" / "Riverside"
DOORS = ROOT / "ArtSource" / "Generated" / "CityDistrict" / "V2" / "Doors"
AREAS = ROOT / "RainShadow Shared" / "Resources" / "Art" / "Areas" / "CityDistrict" / "V2"
PROPS = ROOT / "RainShadow Shared" / "Resources" / "Art" / "Props" / "CityDistrict" / "V2"
MAPS = ROOT / "RainShadow Shared" / "Resources" / "Art" / "UI" / "Map"

BUILDINGS = [
    ("city_building_iron_stairs_empty_v03.png", "city_building_iron_stairs", 500),
    ("city_building_river_watch_empty_v03.png", "city_building_river_watch", 500),
    ("city_building_rail_lamp_v03.png", "city_building_rail_lamp", 480),
    ("city_building_abutment_v03.png", "city_building_abutment", 480),
]
DOORS_IN = [
    ("city_door_iron_stairs_v03.png", "city_door_iron_stairs"),
    ("city_door_river_watch_v03.png", "city_door_river_watch"),
]


def install_plate(src: Path, dst: Path, size: tuple[int, int]) -> None:
    im = Image.open(src).convert("RGB")
    out = proc.fit_to_aspect(im, size)
    dst.parent.mkdir(parents=True, exist_ok=True)
    out.save(dst, "PNG", optimize=True)
    print(f"plate {dst.relative_to(ROOT)} {out.size}")


def install_prop(src: Path, dst: Path, canvas: tuple[int, int], target_h: int) -> Image.Image:
    keyed = proc.chroma_or_corner_key(Image.open(src))
    prop = proc.fit_canvas(proc.trim_alpha(keyed), canvas, target_h=target_h)
    dst.parent.mkdir(parents=True, exist_ok=True)
    prop.save(dst, "PNG", optimize=True)
    print(f"prop  {dst.name} {prop.size}")
    return prop


def content_height(im: Image.Image) -> int:
    import numpy as np
    a = np.array(im.split()[-1])
    ys, _ = np.where(a > 28)
    return int(ys.max() - ys.min() + 1) if len(ys) else im.height


def main() -> int:
    ground_src = SRC / "city_riverside_ground_v03.png"
    if not ground_src.exists():
        raise SystemExit(f"missing {ground_src}")

    GEN.mkdir(parents=True, exist_ok=True)
    DOORS.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ground_src, GEN / "city_riverside_ground_v02.png")

    install_plate(ground_src, AREAS / "city_riverside_ground_v02.png", proc.PLATE_SIZE)
    # Block / map start as the empty ground; compose_city_district_preview
    # overwrites them with the assembled district after sprites land.
    install_plate(ground_src, AREAS / "city_riverside_block_v02.png", proc.PLATE_SIZE)
    install_plate(ground_src, MAPS / "map_city_riverside_v02.png", proc.MAP_SIZE)
    shutil.copy2(AREAS / "city_riverside_block_v02.png", GEN / "city_riverside_block_v02.png")

    for filename, runtime, target in BUILDINGS:
        src = SRC / filename
        prop = install_prop(src, PROPS / f"{runtime}.png", (512, 640), target)
        prop.save(GEN / f"{runtime}.png", "PNG")
        print(f"      content_h={content_height(prop)}")

    for filename, runtime in DOORS_IN:
        src = SRC / filename
        prop = install_prop(src, PROPS / f"{runtime}.png", (256, 384), 280)
        prop.save(DOORS / f"{runtime}.png", "PNG")
        print(f"      content_h={content_height(prop)}")

    r = qa.grade(AREAS / "city_riverside_ground_v02.png")
    tag = "PASS" if r["passes"] else "FAIL"
    print(
        f"installed ground axes {r['peak_pos']:+.2f} / {r['peak_neg']:+.2f}  "
        f"worst {r['worst_delta']:.2f}  {tag}"
    )
    return 0 if r["passes"] else 1


if __name__ == "__main__":
    raise SystemExit(main())

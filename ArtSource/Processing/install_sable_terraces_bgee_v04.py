#!/usr/bin/env python3
"""Install V4 lot-filling Sable terraces onto 2240×840 (2.00 px/unit).

Does not touch city_terrace_sable_se (Voss door lock). Does not call
process_city_districts_v02.main(). Does not stamp V2 cubes into the canvas.

    python3 ArtSource/Processing/install_sable_terraces_bgee_v04.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_city_grounds_world_scale_v05 import flatten_interior_alpha
from install_sable_terraces_iso import (
    OUT,
    PROPS,
    key_black,
    measure_openings,
    scale_fit,
    stamp,
    trim,
)

ROOT = Path(__file__).resolve().parents[2]
SESSION = Path(
    "/Users/laurensvanoorschot/.grok/sessions/"
    "%2FUsers%2Flaurensvanoorschot%2FRainShadow/01a00a59-62cb-7180-b70f-62227c6a37e1/images"
)
CANVAS = (2240, 840)

# Session image → dest name. SE is intentionally absent.
JOBS = {
    "3.jpg": "city_terrace_sable_sw.png",
    "1.jpg": "city_terrace_sable_nw.png",
    "2.jpg": "city_terrace_sable_ne.png",
    "7.jpg": "city_terrace_sable_south_w.png",
    "5.jpg": "city_terrace_sable_south_e.png",
    "6.jpg": "city_district_sable_north_skyline.png",
    "8.jpg": "city_district_sable_corner_shops.png",
    "9.jpg": "city_terrace_sable_far_a.png",
    "10.jpg": "city_terrace_sable_far_b.png",
}


def compose(src: Path) -> Image.Image:
    dest = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    master = flatten_interior_alpha(trim(key_black(Image.open(src))), floor=24)
    fitted = scale_fit(master, (CANVAS[0], CANVAS[1] - 8))
    x = (CANVAS[0] - fitted.width) // 2
    stamp(dest, fitted, x, CANVAS[1] - 4)
    return flatten_interior_alpha(dest, floor=24)


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    report = {}
    for src_name, dest_name in JOBS.items():
        src = SESSION / src_name
        if not src.exists():
            print(f"skip missing {src_name}")
            continue
        im = compose(src)
        holes = measure_openings(im)
        report[dest_name] = {"size": list(im.size), "openings": holes, "src": src_name}
        (OUT / dest_name).parent.mkdir(parents=True, exist_ok=True)
        im.save(OUT / dest_name, "PNG", compress_level=4)
        im.save(PROPS / dest_name, "PNG", compress_level=4)
        print(f"wrote {dest_name} {im.size}  openings={len(holes)}")
        for hole in holes:
            print(f"    cx={hole['cx']} ty={hole['ty']} {hole['w']}x{hole['h']}")
    (OUT / "bgee_v04_openings.json").write_text(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

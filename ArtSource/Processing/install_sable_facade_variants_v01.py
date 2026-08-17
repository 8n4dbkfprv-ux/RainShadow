#!/usr/bin/env python3
"""Install the varied Sable facades (new SW volume + two near-side blocks).

Does not touch SE / NW / NE. Uniform scale onto 2240×840 (2.00 px/unit).
Does not call process_city_districts_v02.main().

    python3 ArtSource/Processing/install_sable_facade_variants_v01.py
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
    SESSION,
    key_black,
    measure_openings,
    scale_fit,
    stamp,
    trim,
)

CANVAS = (2240, 840)

JOBS = {
    "sw": {
        "src": SESSION / "34.jpg",
        "dest": "city_terrace_sable_sw.png",
    },
    "south_w": {
        "src": SESSION / "33.jpg",
        "dest": "city_terrace_sable_south_w.png",
    },
    "south_e": {
        "src": SESSION / "32.jpg",
        "dest": "city_terrace_sable_south_e.png",
    },
}


def compose_one(src: Path) -> Image.Image:
    dest = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    master = flatten_interior_alpha(trim(key_black(Image.open(src))), floor=24)
    fitted = scale_fit(master, (CANVAS[0], CANVAS[1] - 8))
    x = (CANVAS[0] - fitted.width) // 2
    stamp(dest, fitted, x, CANVAS[1] - 4)
    return flatten_interior_alpha(dest, floor=24)


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    report = {}
    for key, job in JOBS.items():
        if not job["src"].exists():
            raise SystemExit(f"missing master {job['src']}")
        im = compose_one(job["src"])
        assert im.size == CANVAS, (key, im.size)
        holes = measure_openings(im)
        report[key] = {"size": list(im.size), "openings": holes, "src": job["src"].name}
        im.save(OUT / job["dest"], "PNG", compress_level=4)
        im.save(PROPS / job["dest"], "PNG", compress_level=4)
        print(f"wrote {job['dest']} {im.size}  openings={len(holes)}")
        for h in holes:
            print(f"    cx={h['cx']} ty={h['ty']} {h['w']}x{h['h']}")
    (OUT / "facade_variant_openings.json").write_text(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

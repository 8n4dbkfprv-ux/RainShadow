#!/usr/bin/env python3
"""Install V4-density city grounds: 4096×2304 with native sett detail.

Does not run `process_city_districts_v02.main()` and does not retouch
buildings, doors, or the office. Each V3 1536×1024 ground is centre-cropped
to 16:9 and given a high-frequency sett/flag overlay
(`composite_city_ground_density_v04.py`) so `qa_plate_density.py` is not
passed by a naked upscale.

Usage:
    python3 ArtSource/Processing/install_city_grounds_density_v04.py
    python3 ArtSource/Processing/install_city_grounds_density_v04.py sable_row
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import composite_city_ground_density_v04 as dens
import process_city_districts_v02 as proc
import qa_plate_projection as qa

ROOT = Path(__file__).resolve().parents[2]
CAND = ROOT / "ArtSource" / "Generated" / "BGEEProjectionCandidates"
GEN = ROOT / "ArtSource" / "Generated" / "CityDistrict" / "V2"
AREAS = ROOT / "RainShadow Shared" / "Resources" / "Art" / "Areas" / "CityDistrict" / "V2"
MAPS = ROOT / "RainShadow Shared" / "Resources" / "Art" / "UI" / "Map"

GROUNDS = {
    "sable_row": ("SableRow", "city_sable_row_ground_v03.png"),
    "wharf_ladder": ("WharfLadder", "city_wharf_ladder_ground_v03.png"),
    "riverside": ("Riverside", "city_riverside_ground_v03.png"),
    "harborpoint_pd": ("HarborpointPD", "city_harborpoint_pd_ground_v03.png"),
    "lila_street": ("LilaStreet", "city_lila_street_ground_v03.png"),
    "civic_records": ("CivicRecords", "city_civic_records_ground_v03.png"),
}


def install_one(slug: str) -> bool:
    folder, name = GROUNDS[slug]
    src = CAND / folder / name
    if not src.exists():
        raise SystemExit(f"missing {src}")
    master = Image.open(src)
    plate = dens.composite(master, proc.PLATE_SIZE, fine=slug not in dens.COARSE_DISTRICTS)
    delta = dens.assert_not_naked_upscale(master, plate)
    gen_dir = GEN / folder
    gen_dir.mkdir(parents=True, exist_ok=True)
    AREAS.mkdir(parents=True, exist_ok=True)
    MAPS.mkdir(parents=True, exist_ok=True)

    cand = CAND / folder / f"city_{slug}_ground_v04.png"
    plate.save(cand, "PNG", optimize=True)
    plate.save(gen_dir / f"city_{slug}_ground_v02.png", "PNG", optimize=True)
    plate.save(AREAS / f"city_{slug}_ground_v02.png", "PNG", optimize=True)
    # Block starts as the empty ground, same as the V3 installer.
    plate.save(AREAS / f"city_{slug}_block_v02.png", "PNG", optimize=True)
    plate.save(gen_dir / f"city_{slug}_block_v02.png", "PNG", optimize=True)
    # HUD map stays at MAP_SIZE — it is not drawn at world scale.
    proc.resize_plate(src, MAPS / f"map_city_{slug}_v02.png", proc.MAP_SIZE)

    r = qa.grade(AREAS / f"city_{slug}_ground_v02.png")
    tag = "PASS" if r["passes"] else "FAIL"
    print(
        f"  {slug:16s} {plate.size[0]}x{plate.size[1]}  "
        f"axes {r['peak_pos']:+.2f}/{r['peak_neg']:+.2f}  "
        f"worst {r['worst_delta']:.2f}  vs-upscale {delta:.2f}  {tag}"
    )
    return r["passes"]


def main() -> int:
    slugs = list(GROUNDS)
    if len(sys.argv) > 1:
        slugs = sys.argv[1:]
        unknown = [s for s in slugs if s not in GROUNDS]
        if unknown:
            raise SystemExit(f"unknown district(s): {unknown}")
    print(f"PLATE_SIZE={proc.PLATE_SIZE}  overlay setts={dens.SETT_PX}px flags={dens.FLAG_PX}px")
    ok = True
    for slug in slugs:
        ok = install_one(slug) and ok
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())

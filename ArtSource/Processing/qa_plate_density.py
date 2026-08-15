#!/usr/bin/env python3
"""Measure how much painted detail an area plate carries per world unit.

`qa_plate_projection.py` answers "is this plate on the camera?". It cannot see
the other way a plate goes wrong: a plate can sit exactly on the lock and still
be painted at a lower resolution than the sprites standing on it, so every
cobble and kerb is magnified at play zoom while the actor beside it is native.
That reads as a street built out of oversized stones, and nothing in the
pipeline measured it.

The unit is **art pixels per world unit**. A plate is drawn to a fixed world
size (`SKSpriteNode(texture:, size:)`), so this is fixed at install and does not
move with the camera. The reference is the actor's own texture density, because
the actor is what the player is comparing the ground against:

    Voss: a 512 px canvas displayed over 180 world units = 2.844 px/unit

    python3 ArtSource/Processing/qa_plate_density.py
    python3 ArtSource/Processing/qa_plate_density.py --display-scale 2.0

Exit code is non-zero when any plate is under `FLOOR_PX_PER_UNIT`, so this can
gate an install alongside the projection grade.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]

# Actor reference: OfficeInteriorScale.ActorDisplay — a 512 px texture canvas
# shown on a 180-unit node. Everything the player sees beside the ground.
ACTOR_PX_PER_UNIT = 512.0 / 180.0

# A plate under this is magnified more than ~1.6x at play zoom on a 2x display,
# which is where painted stonework starts reading as chunky rather than soft.
FLOOR_PX_PER_UNIT = 2.0

# Play framing: DefaultPlayZoom shows this many world units of height, over a
# viewport whose device-pixel height is `view points x backing scale`.
VISIBLE_WORLD_HEIGHT = 70.3125 / 0.13

# (path, world width the plate is drawn over, note)
# Office: 4096 art px x OfficeInteriorScale.environment (0.395).
# City:   CityDistrictDefinition.environmentScale is 1, so 1 art px = 1 unit.
PLATES: list[tuple[str, float, str]] = [
    ("Resources/Art/Areas/DetectiveOffice/office_suite_plate.png", 4096 * 0.395, "office"),
    ("Resources/Art/Areas/DetectiveOffice/office_shell_base.png", 4096 * 0.395, "office"),
] + [
    (f"Resources/Art/Areas/CityDistrict/V2/city_{slug}_ground_v02.png", 2048.0, "city ground")
    for slug in (
        "sable_row", "wharf_ladder", "riverside",
        "harborpoint_pd", "lila_street", "civic_records",
    )
]

BASE = ROOT / "RainShadow Shared"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--view-height", type=float, default=982.0,
        help="viewport height in points (default: a 14in MacBook Pro window)",
    )
    ap.add_argument("--display-scale", type=float, default=2.0, help="backing scale factor")
    args = ap.parse_args()

    device_px_per_unit = args.view_height * args.display_scale / VISIBLE_WORLD_HEIGHT
    print(
        f"actor reference {ACTOR_PX_PER_UNIT:.2f} art px/unit; "
        f"floor {FLOOR_PX_PER_UNIT:.2f}; play zoom delivers "
        f"{device_px_per_unit:.2f} device px/unit"
    )
    print(f"{'plate':44} {'canvas':>11} {'px/unit':>8} {'vs actor':>9} {'magnified':>10}  verdict")
    print("-" * 96)

    worst = None
    failures = 0
    for rel, world_w, note in PLATES:
        path = BASE / rel
        if not path.exists():
            print(f"{Path(rel).name:44} {'MISSING':>11}")
            failures += 1
            continue
        w, h = Image.open(path).size
        px_per_unit = w / world_w
        magnification = device_px_per_unit / px_per_unit
        ok = px_per_unit >= FLOOR_PX_PER_UNIT
        failures += 0 if ok else 1
        if worst is None or px_per_unit < worst[1]:
            worst = (Path(rel).name, px_per_unit)
        print(
            f"{Path(rel).name:44} {f'{w}x{h}':>11} {px_per_unit:8.2f} "
            f"{px_per_unit / ACTOR_PX_PER_UNIT:8.2f}x {magnification:9.2f}x  "
            f"{'PASS' if ok else 'FAIL — magnified, reads coarse'}"
        )

    print("-" * 96)
    if worst:
        print(f"lowest density: {worst[0]} at {worst[1]:.2f} px/unit")
    if failures:
        print(
            f"\n{failures} plate(s) under the floor. A plate is drawn to a fixed world\n"
            "size, so this cannot be fixed by zooming or by rescaling on install —\n"
            "an upscale adds pixels, not detail. Regenerate the master larger."
        )
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())

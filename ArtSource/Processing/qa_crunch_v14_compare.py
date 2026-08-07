#!/usr/bin/env python3
"""Before/after sheets for the V14 crunch, at the real 13% play camera.

Compares the shipped atlases against the V13 runtime snapshot taken before the
rebake. Read-only apart from the two sheets it writes.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

from qa_pixelation_ab_v02 import (
    OUTPUT,
    ROOT,
    grid,
    labelled,
    office_tile,
    screen_plate,
    zoom_tile,
)

ATLASES = ROOT / "RainShadow Shared/Resources/Art/Atlases"
BACKUP = ROOT / "ArtSource/Generated/Characters/RuntimeBackupPreRendered3DV13"

CELLS = [
    ("VossIdle.atlas", "voss_standing_idle_sw_00.png", "Voss idle SW"),
    ("VossIdle.atlas", "voss_standing_idle_s_00.png", "Voss idle S"),
    ("VossWalk.atlas", "voss_walk_sw_00.png", "Voss walk SW 00"),
    ("VossWalk.atlas", "voss_walk_w_02.png", "Voss walk W 02 (blended)"),
    ("VossSeatTransitions.atlas", "voss_stand_up_se_11.png", "Voss stand-up SE 11"),
    ("VossSeatedIdle.atlas", "voss_seated_idle_ne_00.png", "Voss seated NE 00"),
    ("LilaArrival.atlas", "lila_arrival_sw_08.png", "Lila arrival SW 08"),
    ("LilaArrival.atlas", "lila_departure_ne_00.png", "Lila departure NE 00"),
]


def main() -> None:
    plate = screen_plate()
    play: list[Image.Image] = []
    zoom: list[Image.Image] = []

    for atlas, name, label in CELLS:
        for base, tag in ((BACKUP, "V7 before"), (ATLASES, "V14 after")):
            path = base / atlas / name
            if not path.exists():
                continue
            frame = Image.open(path).convert("RGBA")
            play.append(labelled(office_tile(frame, plate), f"{tag}  {label}"))
            zoom.append(labelled(zoom_tile(frame), f"{tag}  {label}"))

    grid(play, columns=2).convert("RGB").save(OUTPUT / "qa_v14_playscale_before_after.png", optimize=True)
    grid(zoom, columns=2).convert("RGB").save(OUTPUT / "qa_v14_zoom_before_after.png", optimize=True)
    print(f"Wrote {OUTPUT.relative_to(ROOT)}/qa_v14_{{playscale,zoom}}_before_after.png")


if __name__ == "__main__":
    main()

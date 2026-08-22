#!/usr/bin/env python3
"""Refit office prop placements and retire lighting contradicted by the V12 plate.

The resulting manifest is the authority for both sides of the plate/live split:
`bake_office_plate.py` composites static scenery and `OfficeAreaAdapter` exports
only the desk interaction cluster.
"""

from __future__ import annotations

import json
from pathlib import Path

import migrate_office_1950s_v11 as v11


ROOT = Path(__file__).resolve().parents[2]
PROP_MANIFEST = ROOT / "ArtSource/Generated/Office/office_props_v01.json"
AREA_RECORD = ROOT / "RainShadow Shared/Resources/Areas/office_suite.area.json"

RETIRED_COOL_LIGHTS = {
    "office_light_window_spill",
    "office_light_blind_stripes",
    "office_light_blind_stripes_wall",
}


def migrate(props: list[dict]) -> list[dict]:
    result = v11.migrate(props)
    desk_chair = v11.layout.PROP_BY_KEY["deskChair"]
    desk_chair.measure()
    for prop in result:
        prop_id = prop.get("id")
        if prop_id in RETIRED_COOL_LIGHTS:
            prop["alpha"] = 0.0
        elif prop_id == "office_light_hallway":
            prop["alpha"] = min(float(prop.get("alpha", 1.0)), 0.18)
        elif prop_id == "office_desk_chair":
            # The seated atlas contains no chair. Keep the stable live-prop ID
            # and actor-sort contract, but give it the broad leather executive
            # chair authored by the V12 layout so its back and arms stay visible.
            prop["textureName"] = desk_chair.art
            prop["scale"] = round(desk_chair.display_scale, 6)
    return result


def _atomic_json_write(path: Path, document: dict) -> None:
    temporary = path.with_name(path.name + ".v12-installing")
    temporary.write_text(json.dumps(document, indent=2, sort_keys=True) + "\n")
    temporary.replace(path)


def main() -> None:
    manifest = json.loads(PROP_MANIFEST.read_text())
    manifest["props"] = migrate(manifest["props"])
    area_record = json.loads(AREA_RECORD.read_text())
    # The installed area now contains only the live desk cluster, while the
    # source manifest intentionally retains every static prop needed by the
    # plate bake. Migrate the complete authority once, then project the area's
    # existing live IDs from it; running V11's completeness gate on the 12-item
    # subset would correctly complain that the 36 baked props were absent.
    migrated_by_id = {prop["id"]: prop for prop in manifest["props"]}
    area_ids = [prop["id"] for prop in area_record["area"]["props"]]
    missing = set(area_ids) - set(migrated_by_id)
    if missing:
        raise RuntimeError(f"area props missing from source manifest: {sorted(missing)}")
    area_record["area"]["props"] = [migrated_by_id[prop_id] for prop_id in area_ids]
    _atomic_json_write(PROP_MANIFEST, manifest)
    _atomic_json_write(AREA_RECORD, area_record)
    print(f"wrote {PROP_MANIFEST.relative_to(ROOT)} ({len(manifest['props'])} props)")
    print(f"wrote {AREA_RECORD.relative_to(ROOT)} ({len(area_record['area']['props'])} props)")


if __name__ == "__main__":
    main()

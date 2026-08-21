#!/usr/bin/env python3
"""Refit live office props and retire lighting contradicted by the V12 plate."""

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
    for prop in result:
        prop_id = prop.get("id")
        if prop_id in RETIRED_COOL_LIGHTS:
            prop["alpha"] = 0.0
        elif prop_id == "office_light_hallway":
            prop["alpha"] = min(float(prop.get("alpha", 1.0)), 0.18)
    return result


def _atomic_json_write(path: Path, document: dict) -> None:
    temporary = path.with_name(path.name + ".v12-installing")
    temporary.write_text(json.dumps(document, indent=2, sort_keys=True) + "\n")
    temporary.replace(path)


def main() -> None:
    manifest = json.loads(PROP_MANIFEST.read_text())
    manifest["props"] = migrate(manifest["props"])
    area_record = json.loads(AREA_RECORD.read_text())
    area_record["area"]["props"] = migrate(area_record["area"]["props"])
    _atomic_json_write(PROP_MANIFEST, manifest)
    _atomic_json_write(AREA_RECORD, area_record)
    print(f"wrote {PROP_MANIFEST.relative_to(ROOT)} ({len(manifest['props'])} props)")
    print(f"wrote {AREA_RECORD.relative_to(ROOT)} ({len(area_record['area']['props'])} props)")


if __name__ == "__main__":
    main()

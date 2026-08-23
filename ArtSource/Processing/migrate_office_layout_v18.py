#!/usr/bin/env python3
"""Rebuild the V18 prop manifest with all radiator sprites retired.

The two V18 radiators are pixels in the area master. This migration preserves
the V17 desk-only runtime split while removing the obsolete radiator record
from the broader source-lineage manifest as well.
"""

from __future__ import annotations

import json
from pathlib import Path

import migrate_office_layout_v17 as v17


ROOT = Path(__file__).resolve().parents[2]
PROP_MANIFEST = ROOT / "ArtSource/Generated/Office/office_props_v01.json"
AREA_RECORD = ROOT / "RainShadow Shared/Resources/Areas/office_suite.area.json"


def main() -> None:
    document = json.loads(v17.SOURCE.read_text(encoding="utf-8"))
    document["props"] = [
        prop for prop in document["props"] if prop["id"] != "office_radiator"
    ]
    # The shared V11 migration predates baked radiators and requires every id
    # in this table to have a layout placement. Retire the id before asking it
    # to migrate the remaining source records.
    v17.migration.PROP_ID_TO_KEY.pop("office_radiator", None)
    document["props"] = v17.migration.migrate(document["props"])
    document["authoringVersion"] = "V18"
    document["authoringSource"] = str(v17.SOURCE.relative_to(ROOT))
    temporary = PROP_MANIFEST.with_name(PROP_MANIFEST.name + ".v18-installing")
    temporary.write_text(json.dumps(document, indent=2, sort_keys=True) + "\n")
    temporary.replace(PROP_MANIFEST)

    area = json.loads(AREA_RECORD.read_text(encoding="utf-8"))
    area["area"]["props"] = [
        prop for prop in document["props"] if prop["id"] in v17.LIVE_PROP_IDS
    ]
    area_temporary = AREA_RECORD.with_name(AREA_RECORD.name + ".v18-installing")
    area_temporary.write_text(json.dumps(area, indent=2, sort_keys=True) + "\n")
    area_temporary.replace(AREA_RECORD)
    print(f"retired office_radiator from {PROP_MANIFEST.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

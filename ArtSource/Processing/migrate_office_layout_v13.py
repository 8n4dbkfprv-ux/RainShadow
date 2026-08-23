#!/usr/bin/env python3
"""Install V13 prop positions idempotently from frozen source metadata."""

from __future__ import annotations

import json
from pathlib import Path

import migrate_office_1950s_v11 as migration


ROOT = Path(__file__).resolve().parents[2]
SOURCE = (
    ROOT
    / "ArtSource/Generated/Office/BGEEReferenceV13"
    / "office_props_source_v13.json"
)
PROP_MANIFEST = ROOT / "ArtSource/Generated/Office/office_props_v01.json"
AREA_RECORD = ROOT / "RainShadow Shared/Resources/Areas/office_suite.area.json"

# Static scenery is baked into the V13 plate.  The area record retains only
# the desk pieces that must sort dynamically around seated Voss; this set must
# match bake_office_plate.LIVE_PROP_IDS and OfficeAreaAdapter.livePropIDs.
LIVE_PROP_IDS = {
    "office_desk_bare",
    "office_desk_chair",
    "office_desk_actor_occluder",
    "office_desk_front_occluder_v04",
    "office_desk_top_occluder",
    "office_desk_lamp",
    "office_desk_phone",
    "office_desk_typewriter",
    "office_desk_notebook",
    "office_desk_papers",
    "office_desk_ashtray",
    "office_desk_files",
}


def _atomic_json_write(path: Path, document: dict) -> None:
    temporary = path.with_name(path.name + ".v13-installing")
    temporary.write_text(json.dumps(document, indent=2, sort_keys=True) + "\n")
    temporary.replace(path)


def main() -> None:
    clean = json.loads(SOURCE.read_text(encoding="utf-8"))
    clean_props = clean["props"]
    migrated = migration.migrate(clean_props)

    manifest = dict(clean)
    manifest["props"] = migrated
    manifest["authoringVersion"] = "V13"
    manifest["authoringSource"] = str(SOURCE.relative_to(ROOT))
    _atomic_json_write(PROP_MANIFEST, manifest)

    area_record = json.loads(AREA_RECORD.read_text(encoding="utf-8"))
    migrated_by_id = {prop["id"]: prop for prop in migrated}
    missing_live = LIVE_PROP_IDS - set(migrated_by_id)
    if missing_live:
        raise RuntimeError(f"live desk props missing from V13 source: {sorted(missing_live)}")
    area_record["area"]["props"] = [
        prop for prop in migrated if prop["id"] in LIVE_PROP_IDS
    ]
    _atomic_json_write(AREA_RECORD, area_record)
    print(f"wrote {PROP_MANIFEST.relative_to(ROOT)} ({len(migrated)} props)")
    print(f"wrote {AREA_RECORD.relative_to(ROOT)} ({len(LIVE_PROP_IDS)} live props)")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Install V17 prop positions idempotently from the frozen V14 prop source."""

from __future__ import annotations

import json
from pathlib import Path

import migrate_office_1950s_v11 as migration


ROOT = Path(__file__).resolve().parents[2]
SOURCE = (
    ROOT
    / "ArtSource/Generated/Office/BGEEReferenceV14"
    / "office_props_source_v14.json"
)
PROP_MANIFEST = ROOT / "ArtSource/Generated/Office/office_props_v01.json"
AREA_RECORD = ROOT / "RainShadow Shared/Resources/Areas/office_suite.area.json"

# V03 embeds the complete room, so no legacy prop survives as a runtime node.
LIVE_PROP_IDS: set[str] = set()


def _atomic_json_write(path: Path, document: dict) -> None:
    temporary = path.with_name(path.name + ".v17-installing")
    temporary.write_text(json.dumps(document, indent=2, sort_keys=True) + "\n")
    temporary.replace(path)


def main() -> None:
    if not LIVE_PROP_IDS:
        area_record = json.loads(AREA_RECORD.read_text(encoding="utf-8"))
        area_record["area"]["props"] = []
        _atomic_json_write(AREA_RECORD, area_record)
        print(f"preserved {PROP_MANIFEST.relative_to(ROOT)} as migration history")
        print(f"wrote {AREA_RECORD.relative_to(ROOT)} (0 live props)")
        return

    clean = json.loads(SOURCE.read_text(encoding="utf-8"))
    migrated = migration.migrate(clean["props"])

    manifest = dict(clean)
    manifest["props"] = migrated
    manifest["authoringVersion"] = "V17"
    manifest["authoringSource"] = str(SOURCE.relative_to(ROOT))
    _atomic_json_write(PROP_MANIFEST, manifest)

    area_record = json.loads(AREA_RECORD.read_text(encoding="utf-8"))
    migrated_by_id = {prop["id"]: prop for prop in migrated}
    missing_live = LIVE_PROP_IDS - set(migrated_by_id)
    if missing_live:
        raise RuntimeError(f"live desk props missing from source: {sorted(missing_live)}")
    area_record["area"]["props"] = [
        prop for prop in migrated if prop["id"] in LIVE_PROP_IDS
    ]
    _atomic_json_write(AREA_RECORD, area_record)
    print(f"wrote {PROP_MANIFEST.relative_to(ROOT)} ({len(migrated)} props)")
    print(f"wrote {AREA_RECORD.relative_to(ROOT)} ({len(LIVE_PROP_IDS)} live props)")


if __name__ == "__main__":
    main()

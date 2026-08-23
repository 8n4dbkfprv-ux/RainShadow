#!/usr/bin/env python3
"""Refit retained live office props onto the registered V11 architecture.

The two windows and cold fireplace are plate pixels.  The exterior door is an
`AreaDoor` visual registration.  None of those fixtures may survive as a
general area prop; rain/light/hover remain separately registered effects.
"""

from __future__ import annotations

import json
from pathlib import Path

import office_layout_plan as layout
import office_room_plan as room

ROOT = Path(__file__).resolve().parents[2]
PROP_MANIFEST = ROOT / "ArtSource/Generated/Office/office_props_v01.json"
AREA_RECORD = ROOT / "RainShadow Shared/Resources/Areas/office_suite.area.json"

RETIRED_PROP_IDS = {
    "office_window",
    "office_door_leaf",
    "office_door_leaf_thickness",
    "office_internal_door_leaf",
}

PROP_ID_TO_KEY = {
    "office_safe": "safe",
    "office_filing_cabinet": "filingCabinetB",
    "office_filing_cabinet_open": "filingCabinet",
    "office_bookshelf": "bookshelf",
    "office_archive_box_b": "archiveBoxOnCabinet",
    "office_archive_stack": "archiveStackOnCabinet",
    "office_archive_box_a": "archiveBoxA",
    "office_radiator": "radiator",
    "office_personal_sideboard": "personalSideboard",
    "office_hidden_bottle": "personalBottle",
    "office_personal_glass": "personalGlass",
    "office_personal_fan": "personalFan",
    "office_desk_chair": "deskChair",
    "office_visitor_armchair": "visitorArmchair",
    "office_visitor_armchair_2": "visitorArmchairB",
    "office_wastebasket": "wastebasket",
    "office_coat_rack": "coatRack",
    "office_umbrella_stand": "umbrellaStand",
    "office_waiting_chair_a": "waitingChairA",
    "office_waiting_table": "waitingTable",
    "office_waiting_chair_b": "waitingChairB",
    "office_newspaper": "newspaper",
    "office_waiting_ashtray": "waitingAshtray",
}

DESK_FOLLOWERS = {
    "office_floor_wear_decal",
    "office_shadow_ceiling_fan",
    "office_light_lamp_pool",
    "office_worn_rug",
    "office_desk_floor_shadow",
    "office_desk_bare",
    "office_desk_lamp",
    "office_desk_phone",
    "office_desk_typewriter",
    "office_desk_notebook",
    "office_desk_papers",
    "office_desk_ashtray",
    "office_desk_files",
    "office_desk_actor_occluder",
    "office_desk_front_occluder_v04",
    "office_desk_top_occluder",
}


def map_point(point: tuple[float, float]) -> dict[str, float]:
    """Authored plate point -> runtime world point, with no coordinate rounding."""
    focus_x, focus_y = 2048.0, 1152.0
    environment = room.ENVIRONMENT_SCALE
    return {
        "x": focus_x + (point[0] - focus_x) * environment,
        "y": focus_y + (point[1] - focus_y) * environment,
    }


def authored_from_plate(point: tuple[float, float]) -> tuple[float, float]:
    return (point[0], room.ART_H - point[1])


def relocated_ground_points(props: list[dict]) -> dict[str, dict[str, float]]:
    points = {
        prop_id: map_point(layout.PROP_BY_KEY[key].authored)
        for prop_id, key in PROP_ID_TO_KEY.items()
    }
    # Scene registration keeps the empty chair's legacy sprite-derived baseline
    # correction; retain the exact arithmetic rather than serialising a rounded
    # approximation.
    points["office_desk_chair"]["y"] += 16.0 * (180.0 / 232.0)

    old_desk = next(
        prop["groundPoint"] for prop in props if prop.get("id") == "office_desk_bare"
    )
    new_desk = map_point(layout.PROP_BY_KEY["deskEnsemble"].authored)
    desk_delta = (new_desk["x"] - old_desk["x"], new_desk["y"] - old_desk["y"])
    for prop in props:
        if prop.get("id") in DESK_FOLLOWERS:
            old = prop["groundPoint"]
            points[prop["id"]] = {
                "x": old["x"] + desk_delta[0],
                "y": old["y"] + desk_delta[1],
            }

    points.update(
        {
            "office_light_window_spill": map_point(
                authored_from_plate(layout.FLOOR_DECALS["windowSpill"])
            ),
            "office_light_blind_stripes": map_point(
                authored_from_plate(layout.FLOOR_DECALS["blindStripes"])
            ),
            "office_light_hallway": map_point(
                authored_from_plate(layout.FLOOR_DECALS["hallwayLight"])
            ),
            "office_entrance_runner": map_point(
                authored_from_plate(layout.FLOOR_DECALS["entranceRunner"])
            ),
            "office_cabinet_floor_shadow": map_point(
                layout.PROP_BY_KEY["filingCabinet"].authored
            ),
            "office_floor_trash_a": map_point(
                authored_from_plate(layout.FLOOR_DECALS["floorTrashA"])
            ),
            "office_floor_trash_b": map_point(
                authored_from_plate(layout.FLOOR_DECALS["floorTrashB"])
            ),
            "office_light_blind_stripes_wall": map_point(
                layout.window_anchor_authored()
            ),
            "office_wall_photos": map_point(
                authored_from_plate(layout.WALL_ART["wallPhotos"].plate)
            ),
            "office_case_board": map_point(
                authored_from_plate(layout.WALL_ART["caseBoard"].plate)
            ),
            "office_wall_city_map": map_point(
                authored_from_plate(layout.WALL_ART["wallCityMap"].plate)
            ),
            "office_framed_licence": map_point(
                authored_from_plate(layout.WALL_ART["framedLicence"].plate)
            ),
        }
    )
    return points


def migrate(props: list[dict]) -> list[dict]:
    positions = relocated_ground_points(props)
    result = []
    for prop in props:
        prop_id = prop.get("id")
        if prop_id in RETIRED_PROP_IDS:
            continue
        relocated = dict(prop)
        if prop_id in positions:
            relocated["groundPoint"] = positions[prop_id]
        result.append(relocated)

    surviving_ids = {prop.get("id") for prop in result}
    retired = surviving_ids & RETIRED_PROP_IDS
    if retired:
        raise RuntimeError(f"retired fixture props survived V11 migration: {sorted(retired)}")
    missing = set(PROP_ID_TO_KEY) - surviving_ids
    if missing:
        raise RuntimeError(f"retained gameplay props missing after migration: {sorted(missing)}")
    return result


def _atomic_json_write(path: Path, document: dict) -> None:
    temporary = path.with_name(path.name + ".v11-installing")
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
    print(
        f"wrote {AREA_RECORD.relative_to(ROOT)} "
        f"({len(area_record['area']['props'])} props)"
    )


if __name__ == "__main__":
    main()

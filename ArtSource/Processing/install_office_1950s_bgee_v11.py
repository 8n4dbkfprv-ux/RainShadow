#!/usr/bin/env python3
"""Read-only preflight and explicit atomic installer for the V11 office art."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
STAGE = ROOT / "ArtSource/Generated/Office/BGEE1950sV11"
PROPS = STAGE / "Props"
AREA_ART = ROOT / "RainShadow Shared/Resources/Art/Areas/DetectiveOffice"
RUNTIME_PROPS = ROOT / "RainShadow Shared/Resources/Art/Props/Office"
GENERATED_OFFICE = ROOT / "ArtSource/Generated/Office"
MAP_SOURCE = ROOT / "ArtSource/Generated/UI/Map/map_detective_office_v11.png"
MAP_RUNTIME = ROOT / "RainShadow Shared/Resources/Art/UI/Map/map_detective_office_v08.png"
AREA_MANIFEST = ROOT / "RainShadow Shared/Resources/Areas/office_suite.area.json"
PROP_MANIFEST = GENERATED_OFFICE / "office_props_v01.json"

PLATE = STAGE / "office_1950s_plate_v11.png"
GLASS = STAGE / "office_window_glass_mask_v11.png"
HOVER = STAGE / "office_window_near_hover_overlay_v11.png"
GEOMETRY = STAGE / "office_v11_geometry.json"
METRICS = STAGE / "office_1950s_metrics_v11.json"
FAMILY = PROPS / "office_door_family_v11.json"

# This is the complete mutation allowlist.  The installer cannot discover or
# glob targets, so untracked V8/V9 work and every other runtime asset are out of
# scope by construction.
ALLOWLIST: tuple[tuple[Path, Path], ...] = (
    (PLATE, AREA_ART / "office_suite_plate.png"),
    (PLATE, AREA_ART / "office_shell_base.png"),
    (PLATE, GENERATED_OFFICE / "office_suite_plate.png"),
    (PLATE, GENERATED_OFFICE / "office_shell_base.png"),
    (PLATE, GENERATED_OFFICE / "office_suite_plate_bgee_v11_installed.png"),
    (GLASS, RUNTIME_PROPS / "office_window_glass_mask.png"),
    (HOVER, RUNTIME_PROPS / "office_window_hover_overlay.png"),
    (PROPS / "office_door_leaf_closed_v11.png", RUNTIME_PROPS / "office_door_leaf.png"),
    (PROPS / "office_door_leaf_closed_hover_v11.png", RUNTIME_PROPS / "office_door_leaf_hover.png"),
    (PROPS / "office_door_leaf_mid_v11.png", RUNTIME_PROPS / "office_door_leaf_mid.png"),
    (PROPS / "office_door_leaf_mid_hover_v11.png", RUNTIME_PROPS / "office_door_leaf_mid_hover.png"),
    (PROPS / "office_door_leaf_open_v11.png", RUNTIME_PROPS / "office_door_leaf_open.png"),
    (PROPS / "office_door_leaf_open_hover_v11.png", RUNTIME_PROPS / "office_door_leaf_open_hover.png"),
    (GEOMETRY, GENERATED_OFFICE / "office_v11_geometry.json"),
    (METRICS, GENERATED_OFFICE / "office_1950s_metrics_v11.json"),
    (FAMILY, GENERATED_OFFICE / "office_door_family_v11.json"),
    (MAP_SOURCE, MAP_RUNTIME),
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _area_payload() -> dict[str, object]:
    payload = json.loads(AREA_MANIFEST.read_text(encoding="utf-8"))
    return payload.get("area", payload)


def integration_preflight() -> dict[str, object]:
    for manifest in (AREA_MANIFEST, PROP_MANIFEST):
        if not manifest.exists():
            raise RuntimeError(f"missing integration manifest: {manifest.relative_to(ROOT)}")
    area = _area_payload()
    props_payload = json.loads(PROP_MANIFEST.read_text(encoding="utf-8"))
    generated_props = props_payload.get("props", props_payload)
    area_props = area.get("props", [])
    visible_windows = [
        prop.get("id")
        for prop in list(generated_props) + list(area_props)
        if prop.get("id") == "office_window" or prop.get("textureName") == "office_window"
    ]
    if visible_windows:
        raise RuntimeError(f"separate office_window remains in prop manifests: {visible_windows}")

    regions = {region["id"]: region for region in area.get("regions", [])}
    if "office.exit" in regions:
        raise RuntimeError("duplicate office.exit travel region remains")
    if "office.window" not in regions:
        raise RuntimeError("near baked office.window region is missing")
    door_region = regions.get("office.door")
    if not door_region or door_region.get("kind") != "travel" or not door_region.get("travel"):
        raise RuntimeError("office.door is not the single registered travel region")

    doors = {door["id"]: door for door in area.get("doors", [])}
    registered = doors.get("office.door", {}).get("visual")
    if not registered:
        raise RuntimeError("office.door visual registration is missing")
    expected = {
        "closedTextureName": "office_door_leaf",
        "midTextureName": "office_door_leaf_mid",
        "openTextureName": "office_door_leaf_open",
        "closedHoverTextureName": "office_door_leaf_hover",
        "midHoverTextureName": "office_door_leaf_mid_hover",
        "openHoverTextureName": "office_door_leaf_open_hover",
    }
    drift = {key: (registered.get(key), value) for key, value in expected.items() if registered.get(key) != value}
    if drift:
        raise RuntimeError(f"door visual texture registration drifted: {drift}")

    if area.get("plateTextureName") != "office_suite_plate":
        raise RuntimeError(f"unexpected area plate alias: {area.get('plateTextureName')}")
    return {
        "areaManifest": str(AREA_MANIFEST.relative_to(ROOT)),
        "propManifest": str(PROP_MANIFEST.relative_to(ROOT)),
        "windowRegion": "office.window",
        "travelRegion": "office.door",
        "separateWindowProps": 0,
    }


def preflight() -> dict[str, object]:
    missing = [str(source.relative_to(ROOT)) for source, _ in ALLOWLIST if not source.exists()]
    if missing:
        raise RuntimeError("missing V11 allowlist inputs: " + ", ".join(missing))

    subprocess.run(
        [sys.executable, str(ROOT / "ArtSource/Processing/qa_office_reference_lock_v11.py")],
        cwd=ROOT,
        check=True,
    )

    with Image.open(MAP_SOURCE) as map_image:
        if map_image.format != "PNG" or min(map_image.size) < 256:
            raise RuntimeError(f"V11 map art is invalid: {map_image.size} {map_image.format}")

    targets = [target.resolve() for _, target in ALLOWLIST]
    if len(targets) != len(set(targets)):
        raise RuntimeError("V11 installer allowlist contains duplicate targets")
    for target in targets:
        try:
            target.relative_to(ROOT.resolve())
        except ValueError as error:
            raise RuntimeError(f"allowlist target escapes repository: {target}") from error

    geometry = json.loads(GEOMETRY.read_text(encoding="utf-8"))
    family = json.loads(FAMILY.read_text(encoding="utf-8"))
    if family["displayScale"] != geometry["environmentScale"]:
        raise RuntimeError("door and plate display scales disagree")

    return {
        "version": "BGEE1950sV11",
        "mode": "read-only preflight unless --install is supplied",
        "integration": integration_preflight(),
        "allowlist": [
            {
                "source": str(source.relative_to(ROOT)),
                "target": str(target.relative_to(ROOT)),
                "sha256": sha256(source),
            }
            for source, target in ALLOWLIST
        ],
    }


def _stage_atomic_copies() -> list[tuple[Path, Path]]:
    staged: list[tuple[Path, Path]] = []
    try:
        for source, target in ALLOWLIST:
            target.parent.mkdir(parents=True, exist_ok=True)
            temporary = target.with_name(target.name + ".v11-installing")
            # Copy bytes only. `copy2` also carries Finder/iCloud xattrs, which
            # can make an otherwise valid app bundle fail code signing.
            shutil.copyfile(source, temporary)
            subprocess.run(["xattr", "-c", str(temporary)], check=True)
            if sha256(temporary) != sha256(source):
                raise RuntimeError(f"staged copy hash mismatch: {target.relative_to(ROOT)}")
            staged.append((temporary, target))
    except Exception:
        for temporary, _ in staged:
            temporary.unlink(missing_ok=True)
        raise
    return staged


def _commit_atomic_copies(staged: list[tuple[Path, Path]]) -> None:
    """Replace the whole allowlist or restore every previous target."""
    committed: list[tuple[Path, Path | None]] = []
    try:
        for temporary, target in staged:
            backup = target.with_name(target.name + ".v11-rollback")
            backup.unlink(missing_ok=True)
            if target.exists():
                target.replace(backup)
                previous: Path | None = backup
            else:
                previous = None
            temporary.replace(target)
            committed.append((target, previous))
    except Exception:
        for target, previous in reversed(committed):
            target.unlink(missing_ok=True)
            if previous is not None:
                previous.replace(target)
        for temporary, _ in staged:
            temporary.unlink(missing_ok=True)
        raise
    else:
        for _, previous in committed:
            if previous is not None:
                previous.unlink(missing_ok=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--install", action="store_true", help="replace only the explicit runtime allowlist")
    parser.add_argument("--list", action="store_true", help="print the explicit source/target allowlist")
    args = parser.parse_args()

    if args.list:
        for source, target in ALLOWLIST:
            print(f"{source.relative_to(ROOT)} -> {target.relative_to(ROOT)}")
        if not args.install:
            return

    provenance = preflight()
    if not args.install:
        print(f"V11 preflight passed for {len(ALLOWLIST)} allowlisted targets")
        print("no runtime files changed (use --install)")
        return

    staged = _stage_atomic_copies()
    _commit_atomic_copies(staged)

    provenance["installed"] = [str(target.relative_to(ROOT)) for _, target in ALLOWLIST]
    provenance_path = STAGE / "office_1950s_install_v11.json"
    provenance_path.write_text(json.dumps(provenance, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"installed {len(ALLOWLIST)} exact V11 allowlist targets")
    print(f"wrote {provenance_path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

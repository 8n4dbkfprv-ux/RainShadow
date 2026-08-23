#!/usr/bin/env python3
"""Read-only preflight and atomic installer for the V19 baked-door office."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys

import install_office_reference_rebuild_v17 as installer


ROOT = installer.ROOT
STAGE = ROOT / "ArtSource/Generated/Office/BGEEReferenceV19"
BAKE = ROOT / "ArtSource/Generated/Office/PlateBake"
AREA_ART = ROOT / "RainShadow Shared/Resources/Art/Areas/DetectiveOffice"
RUNTIME_PROPS = ROOT / "RainShadow Shared/Resources/Art/Props/Office"
GENERATED_OFFICE = ROOT / "ArtSource/Generated/Office"

BASE_PLATE = STAGE / "office_reference_rebuild_plate_v19.png"
BAKED_PLATE = BAKE / "office_suite_plate_baked_v19.png"
BAKE_MANIFEST = BAKE / "office_plate_bake_manifest_v19.json"
GLASS = STAGE / "office_window_glass_mask_v19.png"
HOVER = STAGE / "office_window_near_hover_overlay_v19.png"
METRICS = STAGE / "office_reference_rebuild_metrics_v19.json"

ALLOWLIST = (
    (BAKED_PLATE, AREA_ART / "office_suite_plate.png"),
    (BASE_PLATE, AREA_ART / "office_shell_base.png"),
    (BAKED_PLATE, GENERATED_OFFICE / "office_suite_plate.png"),
    (BASE_PLATE, GENERATED_OFFICE / "office_shell_base.png"),
    (BAKED_PLATE, GENERATED_OFFICE / "office_suite_plate_bgee_v19_installed.png"),
    (GLASS, RUNTIME_PROPS / "office_window_glass_mask.png"),
    (HOVER, RUNTIME_PROPS / "office_window_hover_overlay.png"),
    (METRICS, GENERATED_OFFICE / "office_reference_rebuild_metrics_v19.json"),
)


def preflight() -> dict[str, object]:
    missing = [str(source.relative_to(ROOT)) for source, _ in ALLOWLIST if not source.exists()]
    if missing:
        raise RuntimeError("missing V19 allowlist inputs: " + ", ".join(missing))
    for script in ("qa_office_reference_rebuild_v19.py", "office_layout_plan.py"):
        subprocess.run(
            [sys.executable, str(ROOT / "ArtSource/Processing" / script)],
            cwd=ROOT,
            check=True,
        )
    manifest = json.loads(BAKE_MANIFEST.read_text(encoding="utf-8"))
    if manifest.get("version") != 19:
        raise RuntimeError("V19 installer requires the V19 bake manifest")
    if manifest.get("basePlateSHA256") != installer.sha256(BASE_PLATE):
        raise RuntimeError(
            "V19 bake is stale relative to its base plate; run "
            "bake_office_plate.py before installing"
        )
    if manifest.get("bakedPlateSHA256") != installer.sha256(BAKED_PLATE):
        raise RuntimeError("V19 baked plate no longer matches its manifest")
    return {
        "version": "BGEEReferenceV19",
        "mode": "read-only preflight unless --install is supplied",
        "allowlist": [
            {
                "source": str(source.relative_to(ROOT)),
                "target": str(target.relative_to(ROOT)),
                "sha256": installer.sha256(source),
            }
            for source, target in ALLOWLIST
        ],
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--install", action="store_true")
    parser.add_argument("--list", action="store_true")
    args = parser.parse_args()
    if args.list:
        for source, target in ALLOWLIST:
            print(f"{source.relative_to(ROOT)} -> {target.relative_to(ROOT)}")
        if not args.install:
            return

    provenance = preflight()
    if not args.install:
        print(f"V19 preflight passed for {len(ALLOWLIST)} allowlisted targets")
        print("no runtime files changed (use --install)")
        return

    installer.ALLOWLIST = ALLOWLIST
    staged = installer._stage_atomic_copies()
    installer._commit_atomic_copies(staged)
    provenance["installed"] = [str(target.relative_to(ROOT)) for _, target in ALLOWLIST]
    provenance_path = STAGE / "office_reference_rebuild_install_v19.json"
    provenance_path.write_text(json.dumps(provenance, indent=2, sort_keys=True) + "\n")
    print(f"installed {len(ALLOWLIST)} exact V19 allowlist targets")
    print(f"wrote {provenance_path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Read-only preflight and atomic installer for the furnished V15 office."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
STAGE = ROOT / "ArtSource/Generated/Office/BGEEReferenceV15"
BAKE = ROOT / "ArtSource/Generated/Office/PlateBake"
AREA_ART = ROOT / "RainShadow Shared/Resources/Art/Areas/DetectiveOffice"
RUNTIME_PROPS = ROOT / "RainShadow Shared/Resources/Art/Props/Office"
GENERATED_OFFICE = ROOT / "ArtSource/Generated/Office"
MAP_SOURCE = ROOT / "ArtSource/Generated/UI/Map/map_detective_office_v15.png"
MAP_RUNTIME = ROOT / "RainShadow Shared/Resources/Art/UI/Map/map_detective_office_v08.png"

BASE_PLATE = STAGE / "office_reference_rebuild_plate_v15.png"
BAKED_PLATE = BAKE / "office_suite_plate_baked_v15.png"
BAKE_MANIFEST = BAKE / "office_plate_bake_manifest_v15.json"
GLASS = STAGE / "office_window_glass_mask_v15.png"
HOVER = STAGE / "office_window_near_hover_overlay_v15.png"
METRICS = STAGE / "office_reference_rebuild_metrics_v15.json"

ALLOWLIST: tuple[tuple[Path, Path], ...] = (
    (BAKED_PLATE, AREA_ART / "office_suite_plate.png"),
    (BASE_PLATE, AREA_ART / "office_shell_base.png"),
    (BAKED_PLATE, GENERATED_OFFICE / "office_suite_plate.png"),
    (BASE_PLATE, GENERATED_OFFICE / "office_shell_base.png"),
    (BAKED_PLATE, GENERATED_OFFICE / "office_suite_plate_bgee_v15_installed.png"),
    (GLASS, RUNTIME_PROPS / "office_window_glass_mask.png"),
    (HOVER, RUNTIME_PROPS / "office_window_hover_overlay.png"),
    (METRICS, GENERATED_OFFICE / "office_reference_rebuild_metrics_v15.json"),
    (MAP_SOURCE, MAP_RUNTIME),
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def preflight() -> dict[str, object]:
    missing = [
        str(source.relative_to(ROOT))
        for source, _ in ALLOWLIST
        if not source.exists()
    ]
    if missing:
        raise RuntimeError("missing V15 allowlist inputs: " + ", ".join(missing))

    for script in (
        "qa_office_reference_rebuild_v15.py",
        "qa_office_layout_v15.py",
        "office_layout_plan.py",
    ):
        subprocess.run(
            [sys.executable, str(ROOT / "ArtSource/Processing" / script)],
            cwd=ROOT,
            check=True,
        )

    bake_manifest = json.loads(BAKE_MANIFEST.read_text(encoding="utf-8"))
    if bake_manifest.get("version") != 15:
        raise RuntimeError("V15 installer requires the V15 bake manifest")
    if bake_manifest.get("bakedPlateSHA256") != sha256(BAKED_PLATE):
        raise RuntimeError("V15 baked plate no longer matches its manifest")

    targets = [target.resolve() for _, target in ALLOWLIST]
    if len(targets) != len(set(targets)):
        raise RuntimeError("V15 installer allowlist contains duplicate targets")
    for target in targets:
        target.relative_to(ROOT.resolve())

    return {
        "version": "BGEEReferenceV15",
        "mode": "read-only preflight unless --install is supplied",
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
            temporary = target.with_name(target.name + ".v15-installing")
            shutil.copyfile(source, temporary)
            subprocess.run(["xattr", "-c", str(temporary)], check=True)
            if sha256(temporary) != sha256(source):
                raise RuntimeError(
                    f"staged copy hash mismatch: {target.relative_to(ROOT)}"
                )
            staged.append((temporary, target))
    except Exception:
        for temporary, _ in staged:
            temporary.unlink(missing_ok=True)
        raise
    return staged


def _commit_atomic_copies(staged: list[tuple[Path, Path]]) -> None:
    committed: list[tuple[Path, Path | None]] = []
    try:
        for temporary, target in staged:
            backup = target.with_name(target.name + ".v15-rollback")
            backup.unlink(missing_ok=True)
            previous: Path | None = None
            if target.exists():
                target.replace(backup)
                previous = backup
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
        print(f"V15 preflight passed for {len(ALLOWLIST)} allowlisted targets")
        print("no runtime files changed (use --install)")
        return

    staged = _stage_atomic_copies()
    _commit_atomic_copies(staged)
    provenance["installed"] = [
        str(target.relative_to(ROOT)) for _, target in ALLOWLIST
    ]
    provenance_path = STAGE / "office_reference_rebuild_install_v15.json"
    provenance_path.write_text(
        json.dumps(provenance, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(f"installed {len(ALLOWLIST)} exact V15 allowlist targets")
    print(f"wrote {provenance_path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

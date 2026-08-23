#!/usr/bin/env python3
"""Read-only preflight and atomic installer for the V17 AR0809 office."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
STAGE = ROOT / "ArtSource/Generated/Office/BGEEReferenceV17"
BAKE = ROOT / "ArtSource/Generated/Office/PlateBake"
AREA_ART = ROOT / "RainShadow Shared/Resources/Art/Areas/DetectiveOffice"
RUNTIME_PROPS = ROOT / "RainShadow Shared/Resources/Art/Props/Office"
GENERATED_OFFICE = ROOT / "ArtSource/Generated/Office"

BASE_PLATE = STAGE / "office_reference_rebuild_plate_v17.png"
BAKED_PLATE = BAKE / "office_suite_plate_baked_v17.png"
BAKE_MANIFEST = BAKE / "office_plate_bake_manifest_v17.json"
GLASS = STAGE / "office_window_glass_mask_v17.png"
HOVER = STAGE / "office_window_near_hover_overlay_v17.png"
METRICS = STAGE / "office_reference_rebuild_metrics_v17.json"

ALLOWLIST: tuple[tuple[Path, Path], ...] = (
    (BAKED_PLATE, AREA_ART / "office_suite_plate.png"),
    (BASE_PLATE, AREA_ART / "office_shell_base.png"),
    (BAKED_PLATE, GENERATED_OFFICE / "office_suite_plate.png"),
    (BASE_PLATE, GENERATED_OFFICE / "office_shell_base.png"),
    (BAKED_PLATE, GENERATED_OFFICE / "office_suite_plate_bgee_v17_installed.png"),
    (GLASS, RUNTIME_PROPS / "office_window_glass_mask.png"),
    (HOVER, RUNTIME_PROPS / "office_window_hover_overlay.png"),
    (METRICS, GENERATED_OFFICE / "office_reference_rebuild_metrics_v17.json"),
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def preflight() -> dict[str, object]:
    missing = [str(source.relative_to(ROOT)) for source, _ in ALLOWLIST if not source.exists()]
    if missing:
        raise RuntimeError("missing V17 allowlist inputs: " + ", ".join(missing))

    for script in (
        "qa_office_reference_rebuild_v17.py",
        "qa_office_layout_v17.py",
        "office_layout_plan.py",
    ):
        subprocess.run(
            [sys.executable, str(ROOT / "ArtSource/Processing" / script)],
            cwd=ROOT,
            check=True,
        )

    manifest = json.loads(BAKE_MANIFEST.read_text(encoding="utf-8"))
    if manifest.get("version") != 17:
        raise RuntimeError("V17 installer requires the V17 bake manifest")
    if manifest.get("bakedPlateSHA256") != sha256(BAKED_PLATE):
        raise RuntimeError("V17 baked plate no longer matches its manifest")

    targets = [target.resolve() for _, target in ALLOWLIST]
    if len(targets) != len(set(targets)):
        raise RuntimeError("V17 installer allowlist contains duplicate targets")
    for target in targets:
        target.relative_to(ROOT.resolve())

    return {
        "version": "BGEEReferenceV17",
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
            temporary = target.with_name(target.name + ".v17-installing")
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
    committed: list[tuple[Path, Path | None]] = []
    try:
        for temporary, target in staged:
            backup = target.with_name(target.name + ".v17-rollback")
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
        print(f"V17 preflight passed for {len(ALLOWLIST)} allowlisted targets")
        print("no runtime files changed (use --install)")
        return

    staged = _stage_atomic_copies()
    _commit_atomic_copies(staged)
    provenance["installed"] = [str(target.relative_to(ROOT)) for _, target in ALLOWLIST]
    provenance_path = STAGE / "office_reference_rebuild_install_v17.json"
    provenance_path.write_text(json.dumps(provenance, indent=2, sort_keys=True) + "\n")
    print(f"installed {len(ALLOWLIST)} exact V17 allowlist targets")
    print(f"wrote {provenance_path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

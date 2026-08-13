#!/usr/bin/env python3
"""Rebind provenance routes to explicitly approved replacement authorities."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "Generated/Characters/Detective/PreRendered3DV20"
MANIFEST = ROOT / "voss_v20_manifest.json"
PROVENANCE = ROOT / "imagegen_provenance_v20.json"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


manifest = json.loads(MANIFEST.read_text())
provenance = json.loads(PROVENANCE.read_text())
replacements = manifest["pose_authorities"].get("replacements", {})
updated = 0
for record in provenance["calls"]:
    definition = manifest["master_inventory"].get(record["output"])
    if not definition:
        continue
    pose_path = definition["pose_authority"]["path"]
    if pose_path not in replacements:
        continue
    current = digest(ROOT / pose_path)
    if current != replacements[pose_path]["authority_sha256"]:
        raise SystemExit(f"replacement authority hash drift: {pose_path}")
    reference = next(ref for ref in record["references"] if ref["path"] == pose_path)
    if reference["sha256"] != current:
        reference["sha256"] = current
        updated += 1

PROVENANCE.write_text(json.dumps(provenance, indent=2, sort_keys=True) + "\n")
print({"replacement_routes_rebound": updated})

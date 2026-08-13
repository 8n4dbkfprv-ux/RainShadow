#!/usr/bin/env python3
"""Record the user's explicit Gate 6 approval against locked hashes."""
from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "Generated/Characters/Detective/PreRendered3DV20"
MANIFEST = ROOT / "voss_v20_manifest.json"
LEDGER = ROOT / "approval_ledger_v20.json"
PHASE = "phase_6_smooth_paperdoll_and_scene_qa"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


approved_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
manifest = json.loads(MANIFEST.read_text())
ledger = json.loads(LEDGER.read_text())
approved = []
for record in ledger["approvals"]:
    if record.get("phase") != PHASE:
        continue
    path = ROOT / record["output"]
    actual = digest(path)
    if actual != record.get("output_sha256"):
        raise SystemExit(f"hash drift before Gate 6 approval: {record['output']}")
    record.update({
        "approved": True,
        "approved_at_utc": approved_at,
        "approved_by": "user",
    })
    approved.append(record["output"])

if len(approved) != 5:
    raise SystemExit(f"expected five Gate 6 approval outputs, found {len(approved)}")
review = ledger["review_artifacts"][PHASE]
for artifact in review["artifacts"]:
    if digest(ROOT / artifact["path"]) != artifact["sha256"]:
        raise SystemExit(f"Gate 6 review hash drift: {artifact['path']}")
review.update({
    "approved_at_utc": approved_at,
    "approved_by": "user",
    "status": "approved",
})
manifest["production_phases"]["current"] = "phase_7_hash_lock_stage_install"
MANIFEST.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
LEDGER.write_text(json.dumps(ledger, indent=2, sort_keys=True) + "\n")
print({"phase": PHASE, "approved_outputs": len(approved), "approved_at_utc": approved_at})

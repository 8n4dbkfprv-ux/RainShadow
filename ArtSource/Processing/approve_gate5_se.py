#!/usr/bin/env python3
"""Record the user's explicit Gate 5 SE approval against locked hashes."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "Generated/Characters/Detective/PreRendered3DV20"
LEDGER = ROOT / "approval_ledger_v20.json"
PROVENANCE = ROOT / "imagegen_provenance_v20.json"
APPROVED_AT = "2026-08-13T09:25:34Z"
PHASE = "phase_5_se_seated_chain"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


ledger = json.loads(LEDGER.read_text())
provenance = json.loads(PROVENANCE.read_text())
approved = []
for record in ledger["approvals"]:
    if record.get("phase") != PHASE:
        continue
    if not record.get("output", "").startswith("Frames/"):
        continue
    path = ROOT / record["output"]
    actual = digest(path)
    if actual != record.get("output_sha256"):
        raise SystemExit(f"hash drift before approval: {record['output']}")
    record.update({
        "approved": True,
        "approved_at_utc": APPROVED_AT,
        "approved_by": "user",
    })
    approved.append(record["output"])

review = ledger["review_artifacts"][PHASE]
for artifact in review["artifacts"]:
    if digest(ROOT / artifact["path"]) != artifact["sha256"]:
        raise SystemExit(f"review artifact hash drift: {artifact['path']}")
review.update({
    "approved_at_utc": APPROVED_AT,
    "approved_by": "user",
    "status": "approved",
})
for record in provenance["calls"]:
    if record.get("phase") == PHASE:
        if record["output"] not in approved:
            raise SystemExit(f"unmatched provenance output: {record['output']}")
        record["status"] = "approved"

if len(approved) != 20:
    raise SystemExit(f"expected 20 Gate 5 SE approvals, found {len(approved)}")

strip_entry = next(
    record for record in ledger["approvals"]
    if record.get("output") == "QA/qa_v20_stand_up_se_strip.png"
)
strip_path = ROOT / strip_entry["output"]
strip_entry.update({
    "approved": True,
    "approved_at_utc": APPROVED_AT,
    "approved_by": "user",
    "output_sha256": digest(strip_path),
})
LEDGER.write_text(json.dumps(ledger, indent=2, sort_keys=True) + "\n")
PROVENANCE.write_text(json.dumps(provenance, indent=2, sort_keys=True) + "\n")
print({"phase": PHASE, "approved_outputs": len(approved), "approved_at_utc": APPROVED_AT})

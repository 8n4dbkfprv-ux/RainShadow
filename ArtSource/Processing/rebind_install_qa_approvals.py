#!/usr/bin/env python3
"""Bind deterministic consolidated QA renders to their source gate approvals."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "Generated/Characters/Detective/PreRendered3DV20"
MANIFEST = ROOT / "voss_v20_manifest.json"
LEDGER = ROOT / "approval_ledger_v20.json"

PHASE_BY_OUTPUT = {
    "QA/qa_v20_front_profile_back_identity_shape.png": "phase_1_identity_anchors",
    "QA/qa_v20_16_facings_unlabelled.png": "phase_2_nine_idle_keys",
    "QA/qa_v20_16_facings_labelled.png": "phase_2_nine_idle_keys",
    "QA/qa_v20_sw_raw_processed_walk_proof.png": "phase_3_sw_n_walk_proofs",
    "QA/qa_v20_n_raw_processed_walk_proof.png": "phase_3_sw_n_walk_proofs",
    "QA/qa_v20_stand_up_ne_strip.png": "phase_5_ne_seated_chain",
}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


manifest = json.loads(MANIFEST.read_text())
ledger = json.loads(LEDGER.read_text())
by_output = {record["output"]: record for record in ledger["approvals"]}
for output, phase in PHASE_BY_OUTPUT.items():
    review = ledger["review_artifacts"][phase]
    if review.get("status") != "approved" or review.get("approved_by") != "user":
        raise SystemExit(f"source gate is not user-approved: {phase}")
    record = by_output[output]
    record.update({
        "approved": True,
        "approved_at_utc": review["approved_at_utc"],
        "approved_by": "user",
        "approval_basis": f"deterministic consolidated render of exact {phase} approved assets",
        "output_sha256": digest(ROOT / output),
        "phase": phase,
    })

# Every other install-QA output was approved directly in its own visual gate;
# assert its current deterministic render still matches the locked ledger.
for output in manifest["approval_requirements"]["install_qa_outputs"]:
    record = by_output[output]
    if record.get("approved") is not True:
        raise SystemExit(f"install QA remains unapproved: {output}")
    if record.get("output_sha256") != digest(ROOT / output):
        raise SystemExit(f"directly approved QA hash drift: {output}")

LEDGER.write_text(json.dumps(ledger, indent=2, sort_keys=True) + "\n")
print({"consolidated_qa_rebound": len(PHASE_BY_OUTPUT)})

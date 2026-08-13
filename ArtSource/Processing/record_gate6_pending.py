#!/usr/bin/env python3
"""Hash-lock Gate 6 paperdoll and previews as pending user approval."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "Generated/Characters/Detective/PreRendered3DV20"
MANIFEST = ROOT / "voss_v20_manifest.json"
LEDGER = ROOT / "approval_ledger_v20.json"
PHASE = "phase_6_smooth_paperdoll_and_scene_qa"
OUTPUTS = (
    "UI/voss_paperdoll_front_rgba_v01.png",
    "QA/qa_v20_inventory_220x315_vs_actor_180x180.png",
    "QA/qa_v20_office_actor_180x180.png",
    "QA/qa_v20_city_actor_180x180.png",
    "QA/qa_v20_seated_one_world_chair.png",
)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


manifest = json.loads(MANIFEST.read_text())
ledger = json.loads(LEDGER.read_text())
by_output = {record["output"]: record for record in ledger["approvals"]}
for output in OUTPUTS:
    by_output[output].update({
        "approved": False,
        "approved_at_utc": None,
        "approved_by": None,
        "output_sha256": digest(ROOT / output),
        "phase": PHASE,
    })
manifest["ui_outputs"]["paperdoll"]["sha256"] = digest(ROOT / OUTPUTS[0])
manifest["production_phases"]["current"] = PHASE
report = ROOT / "QA/qa_v20_gate6_report.json"
ledger["review_artifacts"][PHASE] = {
    "approved_at_utc": None,
    "approved_by": None,
    "artifacts": [
        {"path": output, "sha256": digest(ROOT / output)} for output in OUTPUTS
    ] + [{"path": report.relative_to(ROOT).as_posix(), "sha256": digest(report)}],
    "manual_gate": "Approve the refreshed portrait-first paperdoll, inventory scale comparison, warm-office and cool-city actor read, clean chroma edges, and the one-world-chair desk scene.",
    "status": "pending",
}
MANIFEST.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
LEDGER.write_text(json.dumps(ledger, indent=2, sort_keys=True) + "\n")
print({"pending_outputs": len(OUTPUTS), "phase": PHASE})

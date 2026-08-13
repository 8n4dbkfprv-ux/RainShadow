#!/usr/bin/env python3
"""Hash-lock final Gate 5 SE sources and their exact ImageGen provenance."""
from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ROOT = REPO / "ArtSource/Generated/Characters/Detective/PreRendered3DV20"
MANIFEST = ROOT / "voss_v20_manifest.json"
PROVENANCE = ROOT / "imagegen_provenance_v20.json"
LEDGER = ROOT / "approval_ledger_v20.json"
SESSION = Path("/Users/laurensvanoorschot/.codex/sessions/2026/08/09/rollout-2026-08-09T16-22-23-019fe71e-2fe4-71f1-b606-defcef13dae7.jsonl")
GENERATED = Path("/Users/laurensvanoorschot/.codex/generated_images/019fe71e-2fe4-71f1-b606-defcef13dae7")
REJECTED = ROOT / "Proofs/RejectedGate5Seat/se"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def session_events() -> dict[str, dict]:
    events: dict[str, dict] = {}
    for line in SESSION.read_text().splitlines():
        row = json.loads(line)
        payload = row.get("payload", {})
        if payload.get("type") != "image_generation_end":
            continue
        timestamp = row.get("timestamp", "")
        if timestamp < "2026-08-13T07:48:05Z":
            continue
        call_id = payload.get("call_id")
        if call_id:
            events[call_id] = {
                "call_id": call_id,
                "prompt": payload.get("revised_prompt", ""),
                "status": payload.get("status"),
                "timestamp": timestamp,
            }
    return events


def final_call_ids() -> dict[str, str]:
    by_hash = {
        digest(path): path.stem
        for path in GENERATED.glob("exec-*.png")
    }
    result = {}
    for path in sorted(ROOT.joinpath("Frames").glob("voss_*_se_*_chroma_v20.png")):
        result[path.name] = by_hash[digest(path)]
    return result


def route(manifest: dict, filename: str) -> list[str]:
    output = f"Frames/{filename}"
    pose = manifest["master_inventory"][output]["pose_authority"]["path"]
    phase = int(filename.split("_")[-3])
    refs = [
        pose,
        "References/dialogue_portrait_harlan_voss_v01.png",
        "Anchors/voss_anchor_dimetric_sw_chroma_v20.png",
    ]
    if "seated_idle" in filename:
        if phase:
            refs.append("Frames/voss_seated_idle_se_00_chroma_v20.png")
        refs.append("Keys/voss_key_sw_chroma_v20.png")
    else:
        refs.append("Frames/voss_seated_idle_se_00_chroma_v20.png")
        refs.append(
            "Keys/voss_key_sw_chroma_v20.png"
            if phase == 11
            else "Frames/voss_stand_up_se_11_chroma_v20.png"
        )
    return refs


def main() -> None:
    manifest = json.loads(MANIFEST.read_text())
    provenance = json.loads(PROVENANCE.read_text())
    ledger = json.loads(LEDGER.read_text())
    events = session_events()
    calls = final_call_ids()

    assets = manifest["pose_authorities"]["assets"]
    for phase in range(1, 11):
        rel = f"PoseAuthorities/stand_up_se_{phase:02d}_pose_v17.png"
        assets[rel] = digest(ROOT / rel)
        manifest["master_inventory"][f"Frames/voss_stand_up_se_{phase:02d}_chroma_v20.png"]["pose_authority"]["sha256"] = assets[rel]
    for path in sorted((ROOT / "PoseAuthorities/OriginalMisorderedSEStand").glob("*.png")):
        rel = path.relative_to(ROOT).as_posix()
        manifest["generation_input_inventory"][rel] = {
            "role": "preserved_original_misordered_gate5_se_stand_authority",
            "sha256": digest(path),
        }

    records = {record["output"]: record for record in provenance["calls"]}
    approvals = {record["output"]: record for record in ledger["approvals"]}
    accepted_ids = set()
    for filename, call_id in calls.items():
        output = f"Frames/{filename}"
        path = ROOT / output
        sha = digest(path)
        refs = route(manifest, filename)
        event = events[call_id]
        accepted_ids.add(call_id)
        manifest["master_inventory"][output]["sha256"] = sha
        manifest["master_inventory"][output]["references"] = refs
        records[output].update({
            "call_id": call_id,
            "output_sha256": sha,
            "phase": "phase_5_se_seated_chain",
            "prompt": event["prompt"],
            "references": [
                {"path": rel, "sha256": digest(ROOT / rel)} for rel in refs
            ],
            "status": "accepted_pending_user_approval",
        })
        approvals[output].update({
            "approved": False,
            "approved_at_utc": None,
            "output_sha256": sha,
            "phase": "phase_5_se_seated_chain",
        })

    known_ids = {
        record.get("call_id")
        for section in (provenance["calls"], provenance.get("rejected_calls", []), provenance.get("failed_calls", []))
        for record in section
    }
    for call_id, event in sorted(events.items(), key=lambda item: item[1]["timestamp"]):
        if call_id in known_ids or call_id in accepted_ids:
            continue
        if event["status"] == "failed":
            provenance.setdefault("failed_calls", []).append({
                **event,
                "phase": "phase_5_se_seated_chain",
                "reason": "built-in ImageGen returned no output",
            })
            continue
        source = GENERATED / f"{call_id}.png"
        if not source.exists():
            continue
        destination = REJECTED / f"{call_id}.png"
        if not destination.exists():
            shutil.copy2(source, destination)
        provenance.setdefault("rejected_calls", []).append({
            "call_id": call_id,
            "output": destination.relative_to(ROOT).as_posix(),
            "output_sha256": digest(destination),
            "phase": "phase_5_se_seated_chain",
            "prompt": event["prompt"],
            "references": [],
            "rejection_reason": "superseded during strict Gate 5 SE pose, routing, continuity, or geometry validation",
            "status": "rejected",
        })
        manifest["generation_input_inventory"][destination.relative_to(ROOT).as_posix()] = {
            "role": "rejected_gate5_se_imagegen_output",
            "sha256": digest(destination),
        }

    for record in provenance.get("rejected_calls", []):
        if record.get("phase") != "phase_5_se_seated_chain":
            continue
        record.setdefault("references", [])
        output = record.get("output")
        if isinstance(output, str) and (ROOT / output).is_file():
            manifest["generation_input_inventory"][output] = {
                "role": "rejected_gate5_se_imagegen_output",
                "sha256": digest(ROOT / output),
            }

    strip = ROOT / "QA/qa_v20_stand_up_se_strip.png"
    report = ROOT / "QA/qa_v20_gate5_se_report.json"
    ledger["review_artifacts"]["phase_5_se_seated_chain"] = {
        "approved_at_utc": None,
        "approved_by": None,
        "artifacts": [
            {"path": strip.relative_to(ROOT).as_posix(), "sha256": digest(strip)},
            {"path": report.relative_to(ROOT).as_posix(), "sha256": digest(report)},
        ],
        "manual_gate": "Approve the processed SE seated idle and stand-up chain for stable identity, coat construction, front-right facing, smooth rise, chairless silhouettes, and exact reverse sit-down.",
        "status": "pending",
    }
    provenance["accepted_outputs_to_date"] = sum(bool(record.get("call_id")) for record in provenance["calls"])
    provenance["successful_calls_to_date"] = provenance["accepted_outputs_to_date"] + len(provenance.get("rejected_calls", []))

    MANIFEST.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    PROVENANCE.write_text(json.dumps(provenance, indent=2, sort_keys=True) + "\n")
    LEDGER.write_text(json.dumps(ledger, indent=2, sort_keys=True) + "\n")
    print({"accepted": len(calls), "rejected": len(provenance["rejected_calls"]), "failed": len(provenance["failed_calls"])})


if __name__ == "__main__":
    main()

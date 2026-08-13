#!/usr/bin/env python3
"""Replace reconstructed V20 prompts with Codex's exact ImageGen event records."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "Generated/Characters/Detective/PreRendered3DV20"
PROVENANCE = ROOT / "imagegen_provenance_v20.json"
SESSIONS = Path("/Users/laurensvanoorschot/.codex/sessions")

events: dict[str, dict] = {}
for session in SESSIONS.rglob("*.jsonl"):
    try:
        lines = session.open(errors="ignore")
    except OSError:
        continue
    with lines:
        for line in lines:
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            payload = row.get("payload", {})
            if payload.get("type") == "image_generation_end" and payload.get("call_id"):
                events[payload["call_id"]] = payload

provenance = json.loads(PROVENANCE.read_text())
reconciled = 0
for record in provenance["calls"]:
    event = events.get(record.get("call_id"))
    if not event or event.get("status") != "completed" or not event.get("revised_prompt"):
        raise SystemExit(f"missing completed ImageGen event for {record.get('output')}")
    if record.get("prompt") != event["revised_prompt"]:
        record["prompt"] = event["revised_prompt"]
        reconciled += 1
    record.pop("prompt_record_status", None)

PROVENANCE.write_text(json.dumps(provenance, indent=2, sort_keys=True) + "\n")
print({"calls": len(provenance["calls"]), "exact_prompts_reconciled": reconciled})

#!/usr/bin/env python3
"""Build the isolated processed Gate 5 SE proof and strict metrics report."""
from __future__ import annotations

import hashlib
import json
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "ArtSource/Processing"))
import install_voss_v16 as core  # noqa: E402
import install_voss_v20 as v20  # noqa: E402
import qa_voss_v20 as qa  # noqa: E402

ROOT = REPO / "ArtSource/Generated/Characters/Detective/PreRendered3DV20"
FRAMES = ROOT / "Frames"
STAGE = ROOT / "Proofs/Gate5SEStage"
QA = ROOT / "QA"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(name: str) -> Image.Image:
    with Image.open(FRAMES / name) as image:
        return core.normalise_source_resolution(core.key_chroma(image.convert("RGB"))).transpose(
            Image.Transpose.FLIP_LEFT_RIGHT
        )


def save(atlas: str, name: str, image: Image.Image) -> None:
    core.save_png(image, STAGE / atlas / name)


def main() -> None:
    if STAGE.exists():
        shutil.rmtree(STAGE)
    seated_sources = [load(f"voss_seated_idle_se_{phase:02d}_chroma_v20.png") for phase in range(8)]
    stand_sources = [load(f"voss_stand_up_se_{phase:02d}_chroma_v20.png") for phase in range(12)]
    standing_height = core.source_opaque_height(stand_sources[-1])
    manifest = v20.load_manifest()
    seated_height = int(
        manifest.get("processing", {})
        .get("seated_source_opaque_height_by_direction", {})
        .get("se", core.source_opaque_height(seated_sources[0]) - 1)
    )
    seated = [
        v20.process_keyed_figure(v20.normalise_keyed_opaque_height(source, seated_height), reference_height=standing_height)
        for source in seated_sources
    ]
    targets = [round(seated_height + phase * (standing_height - seated_height) / 11) for phase in range(12)]
    stand = [
        v20.process_keyed_figure(v20.normalise_keyed_opaque_height(source, targets[phase]), reference_height=standing_height)
        for phase, source in enumerate(stand_sources)
    ]
    for phase, cell in enumerate(seated):
        save("VossSeatedIdle.atlas", f"voss_seated_idle_se_{phase:02d}.png", cell)
        save("VossSeatedArms.atlas", f"voss_seated_arms_se_{phase:02d}.png", core._empty_runtime_cell())
    for phase, cell in enumerate(stand):
        save("VossSeatTransitions.atlas", f"voss_stand_up_se_{phase:02d}.png", cell)
        save("VossSeatTransitions.atlas", f"voss_sit_down_se_{11-phase:02d}.png", cell)

    qa.QA = QA
    # Build this isolated SE strip directly; NE was approved separately.
    tiles = [qa.tile(cell, f"SE {phase:02d}", size=(140, 220)) for phase, cell in enumerate(stand)]
    strip = QA / "qa_v20_stand_up_se_strip.png"
    qa.grid(tiles, 12).convert("RGB").save(strip, optimize=True)

    idle_metrics = [core.frame_metrics(cell) for cell in seated]
    stand_metrics = [core.frame_metrics(cell) for cell in stand]
    neutral = idle_metrics[0]
    centroid_drifts = [
        max(abs(metric.centroid_x-neutral.centroid_x), abs(metric.centroid_y-neutral.centroid_y))
        for metric in idle_metrics
    ]
    ious = [core.intersection_over_union(seated[0], cell) for cell in seated]
    crown_retreat = max(after.crown_y-before.crown_y for before, after in zip(stand_metrics, stand_metrics[1:]))
    total_rise = stand_metrics[0].crown_y - stand_metrics[-1].crown_y
    head_widths = [metric.head_width for metric in idle_metrics + stand_metrics]
    exact_reverse = all(
        np.array_equal(
            np.asarray(Image.open(STAGE/"VossSeatTransitions.atlas"/f"voss_sit_down_se_{phase:02d}.png")),
            np.asarray(stand[11-phase]),
        ) for phase in range(12)
    )
    report = {
        "status": "passed",
        "seated_heights": [m.height for m in idle_metrics],
        "stand_heights": [m.height for m in stand_metrics],
        "stand_crowns": [m.crown_y for m in stand_metrics],
        "idle_centroid_drift_px": max(centroid_drifts),
        "minimum_neutral_iou": min(ious),
        "maximum_adjacent_crown_retreat_px": crown_retreat,
        "total_rise_px": total_rise,
        "head_widths": head_widths,
        "head_width_drift_ratio": max(head_widths)/min(head_widths),
        "sit_down_exact_reverse": exact_reverse,
        "qa_sha256": sha256(strip),
    }
    errors=[]
    if any(not 150 <= h <= 160 for h in report["seated_heights"]): errors.append("seated height")
    if report["idle_centroid_drift_px"] > 2: errors.append("idle centroid")
    if report["minimum_neutral_iou"] < .86: errors.append("idle IoU")
    if crown_retreat > 4: errors.append("crown retreat")
    if not 38 <= total_rise <= 50: errors.append("total rise")
    if any(not 19 <= w <= 29 for w in head_widths): errors.append("head widths")
    if report["head_width_drift_ratio"] > 1.30: errors.append("head drift")
    if abs(stand_metrics[0].height-idle_metrics[0].height)>3: errors.append("seated handoff")
    if not 198 <= stand_metrics[-1].height <= 202: errors.append("standing endpoint")
    if not exact_reverse: errors.append("reverse")
    if errors:
        report["status"]="failed"
        report["errors"]=errors
    path=QA/"qa_v20_gate5_se_report.json"
    path.write_text(json.dumps(report,indent=2,sort_keys=True)+"\n")
    print(json.dumps(report,indent=2,sort_keys=True))
    if errors: raise SystemExit(1)


if __name__ == "__main__":
    main()

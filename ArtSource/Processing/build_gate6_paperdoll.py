#!/usr/bin/env python3
"""Derive the V20 paperdoll and isolated Gate 6 review previews."""
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
import install_voss_v20 as v20  # noqa: E402
import qa_voss_v20 as qa  # noqa: E402

ROOT = v20.V20_ROOT
UI = ROOT / "UI"
QA = ROOT / "QA"
STAGE = ROOT / "Proofs/Gate6Stage"
WORK = UI / "voss_anchor_front_rgba_v20_work.png"
PAPER = UI / "voss_paperdoll_front_rgba_v01.png"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fit_paperdoll() -> None:
    with Image.open(WORK) as opened:
        image = opened.convert("RGBA")
    alpha = np.asarray(image)[..., 3]
    ys, xs = np.where(alpha >= 8)
    if not len(xs):
        raise SystemExit("paperdoll matte has no subject")
    subject = image.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))
    # Retain the approved full-height composition and stable ID while giving
    # the soft matte a small transparent safety margin on all sides.
    target = (920, 1460)
    scale = min(target[0] / subject.width, target[1] / subject.height)
    resized = subject.resize(
        (max(1, round(subject.width * scale)), max(1, round(subject.height * scale))),
        Image.Resampling.LANCZOS,
    )
    canvas = Image.new("RGBA", (1024, 1536), (0, 0, 0, 0))
    canvas.alpha_composite(resized, ((1024 - resized.width) // 2, 1536 - 38 - resized.height))
    canvas.save(PAPER, optimize=True)


def prepare_stage() -> None:
    if STAGE.exists():
        shutil.rmtree(STAGE)
    STAGE.mkdir(parents=True)
    sources = [
        ROOT / "Proofs/Gate4Stage/VossIdle.atlas",
        ROOT / "Proofs/Gate5NEStage/VossSeatedIdle.atlas",
        ROOT / "Proofs/Gate5NEStage/VossSeatedArms.atlas",
        ROOT / "Proofs/Gate5NEStage/VossSeatTransitions.atlas",
        ROOT / "Proofs/Gate5SEStage/VossSeatedIdle.atlas",
        ROOT / "Proofs/Gate5SEStage/VossSeatedArms.atlas",
        ROOT / "Proofs/Gate5SEStage/VossSeatTransitions.atlas",
    ]
    for source in sources:
        destination = STAGE / source.name
        destination.mkdir(parents=True, exist_ok=True)
        for path in source.glob("*.png"):
            shutil.copy2(path, destination / path.name)


def main() -> None:
    manifest = v20.load_manifest()
    fit_paperdoll()
    prepare_stage()
    outputs = [qa.make_inventory_preview(STAGE, manifest, QA), *qa.make_world_previews(STAGE, QA)]
    with Image.open(PAPER) as opened:
        rgba = np.asarray(opened.convert("RGBA"))
    report = {
        "asset_version": "v20",
        "status": "passed",
        "paperdoll": {
            "path": PAPER.relative_to(ROOT).as_posix(),
            "sha256": digest(PAPER),
            "size": list(Image.open(PAPER).size),
            "mode": Image.open(PAPER).mode,
            "transparent_corners": [
                int(rgba[0, 0, 3]), int(rgba[0, -1, 3]),
                int(rgba[-1, 0, 3]), int(rgba[-1, -1, 3]),
            ],
            "partially_transparent_pixels": int(((rgba[..., 3] > 0) & (rgba[..., 3] < 255)).sum()),
        },
        "previews": {path.relative_to(ROOT).as_posix(): digest(path) for path in outputs},
    }
    if report["paperdoll"]["size"] != [1024, 1536] or report["paperdoll"]["mode"] != "RGBA":
        raise SystemExit("paperdoll contract failed")
    if any(report["paperdoll"]["transparent_corners"]):
        raise SystemExit("paperdoll corners are not transparent")
    path = QA / "qa_v20_gate6_report.json"
    path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print(json.dumps(report, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

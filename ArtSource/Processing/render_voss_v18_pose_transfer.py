#!/usr/bin/env python3
"""Bulk-produce V18 locomotion masters from high-res pose authorities.

All idle and walk Frames are produced by the proven V17 material restyle on
1024px PoseAuthorities. Imagine-authored keys/anchors remain under Keys/ and
Anchors/; superseded Imagine frame backups live in Proofs/ImagineAuthored/.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import sys
from typing import Any, Sequence

PROCESSING_DIR = Path(__file__).resolve().parent
ROOT = PROCESSING_DIR.parents[1]
if str(PROCESSING_DIR) not in sys.path:
    sys.path.insert(0, str(PROCESSING_DIR))

import render_voss_v17_pose_controlled as v17r  # noqa: E402

V18_ROOT = ROOT / "ArtSource/Generated/Characters/Detective/PreRendered3DV18"
PA = ROOT / "ArtSource/Generated/Characters/Detective/PreRendered3DV17/PoseAuthorities"
V17_FRAMES = ROOT / "ArtSource/Generated/Characters/Detective/PreRendered3DV17/Frames"
FRAMES = V18_ROOT / "Frames"
WESTERN = ["s", "ssw", "sw", "wsw", "w", "wnw", "nw", "nnw", "n"]
SEAT = ["ne", "se"]
REAR = {"n", "nnw", "nw"}


def render(*, with_seat: bool, force: bool) -> dict[str, Any]:
    FRAMES.mkdir(parents=True, exist_ok=True)
    written: list[str] = []
    skipped: list[str] = []
    errors: list[str] = []

    jobs: list[tuple[str, Path, Path, bool, bool]] = []
    # idle 01-03
    for d in WESTERN:
        for p in range(1, 4):
            jobs.append(
                (
                    f"idle_{d}_{p:02d}",
                    PA / f"idle_{d}_{p:02d}_pose_v17.png",
                    FRAMES / f"voss_idle_{d}_{p:02d}_chroma_v18.png",
                    d == "s",
                    d in REAR,
                )
            )
    # idle phase 00 (craft-unified restyle; Imagine copies live in Proofs/)
    for d in WESTERN:
        jobs.append(
            (
                f"idle_{d}_00",
                PA / f"idle_{d}_00_pose_v17.png",
                FRAMES / f"voss_idle_{d}_00_chroma_v18.png",
                d == "s",
                d in REAR,
            )
        )
    # walk all directions including SW
    for d in WESTERN:
        for p in range(8):
            jobs.append(
                (
                    f"walk_{d}_{p:02d}",
                    PA / f"walk_{d}_{p:02d}_pose_v17.png",
                    FRAMES / f"voss_walk_{d}_{p:02d}_chroma_v18.png",
                    d == "s",
                    d in REAR,
                )
            )
    if with_seat:
        # Seat geometry must come from V17 Frames (1024x1536), not PoseAuthorities:
        # authorities are uniform full-body height and fail the 150-160 seated band.
        for d in SEAT:
            for p in range(8):
                jobs.append(
                    (
                        f"seated_{d}_{p:02d}",
                        V17_FRAMES / f"voss_seated_idle_{d}_{p:02d}_chroma_v17.png",
                        FRAMES / f"voss_seated_idle_{d}_{p:02d}_chroma_v18.png",
                        False,
                        d == "ne",
                    )
                )
            for p in range(12):
                jobs.append(
                    (
                        f"standup_{d}_{p:02d}",
                        V17_FRAMES / f"voss_stand_up_{d}_{p:02d}_chroma_v17.png",
                        FRAMES / f"voss_stand_up_{d}_{p:02d}_chroma_v18.png",
                        False,
                        d == "ne",
                    )
                )

    for label, src, dest, front, rear in jobs:
        if not src.is_file():
            errors.append(f"missing pose {src.name}")
            continue
        try:
            master = v17r.restyle(src, front=front, rear=rear)
            master.save(dest, format="PNG", optimize=True)
            written.append(dest.name)
        except Exception as exc:  # noqa: BLE001
            errors.append(f"{dest.name}: {exc}")

    report = {
        "renderer": "v18 restyle of V17 PoseAuthorities (Imagine keys/SW walk preserved)",
        "written": written,
        "skipped": skipped,
        "errors": errors,
        "with_seat": with_seat,
        "rendered_at_utc": datetime.now(timezone.utc).isoformat(),
    }
    (V18_ROOT / "render_report_pose_transfer_v18.json").write_text(
        json.dumps(report, indent=2) + "\n", encoding="utf-8"
    )
    return report


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--with-seat", action="store_true")
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args(argv)
    report = render(with_seat=args.with_seat, force=args.force)
    print(
        f"V18 restyle wrote {len(report['written'])} masters; "
        f"skipped {len(report['skipped'])}; errors {len(report['errors'])}"
    )
    for err in report["errors"][:20]:
        print(f" - {err}", file=sys.stderr)
    return 1 if report["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Drive Grok Imagine image_edit for missing V19 chroma masters.

One master per grok invocation. Skips files that already exist unless --force.
Normalizes accepted RGB outputs onto 832x1248 with #00ff00 padding.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

from PIL import Image

PROCESSING_DIR = Path(__file__).resolve().parent
ROOT = PROCESSING_DIR.parents[1]
V19 = ROOT / "ArtSource/Generated/Characters/Detective/PreRendered3DV19"
REF = V19 / "References"
PA = V19 / "PoseAuthorities"
V18 = ROOT / "ArtSource/Generated/Characters/Detective/PreRendered3DV18"

TARGET = (832, 1248)
PORTRAIT = REF / "dialogue_portrait_harlan_voss_v01.png"
PROMPT_LOCK = (
    "Keep this exact detective — same stern face, pale blue-gray eyes, swept auburn "
    "hair and long sideburns as the portrait reference. Full-body pre-rendered "
    "late-1990s Infinity Engine avatar on a perfectly flat uniform #00ff00 field: "
    "dark chocolate double-breasted belted mid-calf trench with epaulettes and cuff "
    "straps, cream open shirt, loose black tie, charcoal cuffed trousers, brown "
    "lace-ups. Soft matte baked upper-left light, broad folds, restrained craft "
    "detail — not photoreal, not modern PBR, not pixel art. {pose}. One complete "
    "uncropped figure with green clearance; no chair, floor, shadow, hat, weapon, "
    "text, suspenders, scenery, or border."
)

WESTERN = ["s", "ssw", "sw", "wsw", "w", "wnw", "nw", "nnw", "n"]
SEAT = ["ne", "se"]


def normalize_master(path: Path) -> None:
    im = Image.open(path).convert("RGB")
    if im.size == TARGET:
        return
    canvas = Image.new("RGB", TARGET, (0, 255, 0))
    max_h = int(TARGET[1] * 0.92)
    max_w = int(TARGET[0] * 0.85)
    scale = min(max_w / im.width, max_h / im.height)
    nw = max(1, int(im.width * scale))
    nh = max(1, int(im.height * scale))
    resized = im.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas.paste(resized, ((TARGET[0] - nw) // 2, (TARGET[1] - nh) // 2))
    canvas.save(path)


def pose_authority(*candidates: Path) -> Path | None:
    for path in candidates:
        if path.is_file():
            return path
    return None


def jobs() -> list[dict]:
    out: list[dict] = []
    # Anchors
    out.append(
        {
            "id": "anchor_front",
            "out": V19 / "Anchors/voss_anchor_front_chroma_v19.png",
            "refs": [PORTRAIT, REF / "voss_target_front_three_quarter.png"],
            "pose": "Standing idle front three-quarter view, feet planted, arms relaxed at sides",
        }
    )
    out.append(
        {
            "id": "anchor_profile_w",
            "out": V19 / "Anchors/voss_anchor_profile_w_chroma_v19.png",
            "refs": [PORTRAIT, REF / "voss_target_profile_w.png"],
            "pose": "Standing idle exact west profile view, viewer sees left side of face and near-side sideburn only, coat buttons not visible",
        }
    )
    out.append(
        {
            "id": "anchor_back",
            "out": V19 / "Anchors/voss_anchor_back_chroma_v19.png",
            "refs": [REF / "voss_target_back.png", PORTRAIT],
            "pose": "Standing idle rear view, hair only no face, centered rear storm flap and vent, no shirt or tie invented",
        }
    )
    out.append(
        {
            "id": "anchor_dimetric_se",
            "out": V19 / "Anchors/voss_anchor_dimetric_se_chroma_v19.png",
            "refs": [
                PORTRAIT,
                REF / "voss_target_front_three_quarter.png",
                pose_authority(
                    PA / "voss_key_sw_chroma_v18.png",
                    PA / "voss_key_sw_chroma_v17.png",
                    V18 / "Keys/voss_key_sw_chroma_v18.png",
                ),
            ],
            "pose": "Standing idle south-east dimetric three-quarter view matching isometric game camera, left sideburn more visible, right-of-figure button column stronger",
        }
    )
    # Idle keys (phase 00) — SE is mirror, not generated
    for direction in WESTERN:
        refs = [
            PORTRAIT,
            V19 / "Anchors/voss_anchor_front_chroma_v19.png",
            pose_authority(
                PA / f"voss_key_{direction}_chroma_v18.png",
                PA / f"voss_key_{direction}_chroma_v17.png",
                PA / f"idle_{direction}_00_pose_v17.png",
                V18 / f"Keys/voss_key_{direction}_chroma_v18.png",
                V18 / f"Frames/voss_idle_{direction}_00_chroma_v18.png",
            ),
        ]
        out.append(
            {
                "id": f"key_{direction}",
                "out": V19 / f"Keys/voss_key_{direction}_chroma_v19.png",
                "frame": V19 / f"Frames/voss_idle_{direction}_00_chroma_v19.png",
                "refs": [r for r in refs if r is not None],
                "pose": f"Standing idle {direction.upper()} facing phase 00; preserve pose authority camera, feet, and limb silhouette; identity and wardrobe from portrait/anchor only",
            }
        )
    # Remaining idle phases 01-03
    for direction in WESTERN:
        for phase in range(1, 4):
            refs = [
                PORTRAIT,
                V19 / f"Keys/voss_key_{direction}_chroma_v19.png",
                pose_authority(
                    PA / f"idle_{direction}_{phase:02d}_pose_v17.png",
                    V18 / f"Frames/voss_idle_{direction}_{phase:02d}_chroma_v18.png",
                ),
            ]
            out.append(
                {
                    "id": f"idle_{direction}_{phase:02d}",
                    "out": V19 / f"Frames/voss_idle_{direction}_{phase:02d}_chroma_v19.png",
                    "refs": [r for r in refs if r is not None],
                    "pose": f"Standing idle {direction.upper()} micro-phase {phase:02d}; tiny breathing/weight shift only; same identity as key",
                }
            )
    # Walks
    for direction in WESTERN:
        for phase in range(8):
            refs = [
                PORTRAIT,
                V19 / f"Keys/voss_key_{direction}_chroma_v19.png",
                pose_authority(
                    PA / f"walk_{direction}_{phase:02d}_pose_v17.png",
                    V18 / f"Frames/voss_walk_{direction}_{phase:02d}_chroma_v18.png",
                ),
            ]
            out.append(
                {
                    "id": f"walk_{direction}_{phase:02d}",
                    "out": V19 / f"Frames/voss_walk_{direction}_{phase:02d}_chroma_v19.png",
                    "refs": [r for r in refs if r is not None],
                    "pose": f"Walk cycle {direction.upper()} phase {phase:02d} of 08; natural alternating gait in place, coat sways; locked camera; no travel",
                }
            )
    # Seated + stand-up
    for direction in SEAT:
        for phase in range(8):
            refs = [
                PORTRAIT,
                pose_authority(
                    V18 / f"Frames/voss_seated_idle_{direction}_{phase:02d}_chroma_v18.png",
                    PA / f"seated_idle_{direction}_{phase:02d}_pose_v17.png",
                ),
            ]
            out.append(
                {
                    "id": f"seated_{direction}_{phase:02d}",
                    "out": V19 / f"Frames/voss_seated_idle_{direction}_{phase:02d}_chroma_v19.png",
                    "refs": [r for r in refs if r is not None],
                    "pose": f"Seated idle {direction.upper()} phase {phase:02d}; chairless floating sit pose; mid-calf trench draped over seated legs; no chair prop",
                }
            )
        for phase in range(12):
            refs = [
                PORTRAIT,
                pose_authority(
                    V18 / f"Frames/voss_stand_up_{direction}_{phase:02d}_chroma_v18.png",
                    PA / f"stand_up_{direction}_{phase:02d}_pose_v17.png",
                ),
            ]
            out.append(
                {
                    "id": f"standup_{direction}_{phase:02d}",
                    "out": V19 / f"Frames/voss_stand_up_{direction}_{phase:02d}_chroma_v19.png",
                    "refs": [r for r in refs if r is not None],
                    "pose": f"Stand-up transition {direction.upper()} phase {phase:02d} of 12; chairless; rising from sit to stand",
                }
            )
    return out


def run_image_edit(job: dict) -> None:
    out: Path = job["out"]
    out.parent.mkdir(parents=True, exist_ok=True)
    refs = "\n".join(f"- {path}" for path in job["refs"])
    prompt = PROMPT_LOCK.format(pose=job["pose"])
    agent_prompt = f"""Use the image_edit tool (Grok Imagine 2.0) exactly once to create ONE master.

Save the result to this exact path:
{out}

Attach these reference images to image_edit:
{refs}

Use this prompt verbatim for image_edit:
{prompt}

After image_edit returns, copy/move the generated image to {out} with a shell command if needed.
Then reply with only: SAVED {out}
"""
    cmd = [
        "grok",
        "-p",
        agent_prompt,
        "--permission-mode",
        "auto",
        "--max-turns",
        "6",
        "--tools",
        "image_edit,run_terminal_command",
        "--output-format",
        "plain",
        "--cwd",
        str(ROOT),
    ]
    subprocess.run(cmd, check=False)
    if not out.is_file():
        raise RuntimeError(f"image_edit did not produce {out}")
    normalize_master(out)
    # Idle keys also install as idle phase 00 frames
    frame = job.get("frame")
    if frame is not None:
        frame.parent.mkdir(parents=True, exist_ok=True)
        Image.open(out).convert("RGB").save(frame)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", action="append", default=[], help="Job id substring filter")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--list", action="store_true")
    args = parser.parse_args()
    selected = jobs()
    if args.only:
        selected = [j for j in selected if any(token in j["id"] for token in args.only)]
    if args.list:
        for job in selected:
            exists = job["out"].is_file()
            print(("OK" if exists else ".."), job["id"], job["out"].relative_to(V19))
        return 0
    done = 0
    for job in selected:
        if job["out"].is_file() and not args.force:
            print(f"skip {job['id']}")
            continue
        print(f"generate {job['id']} -> {job['out'].relative_to(V19)}", flush=True)
        run_image_edit(job)
        done += 1
        if args.limit and done >= args.limit:
            break
    # Progress file
    present = sum(1 for j in jobs() if j["out"].is_file())
    report = {"present_outputs": present, "total_jobs": len(jobs()), "generated_this_run": done}
    (V19 / "imagine_rebuild_progress.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report))
    return 0


if __name__ == "__main__":
    sys.exit(main())

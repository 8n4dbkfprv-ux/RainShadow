#!/usr/bin/env python3
"""Generate the strict V20 Voss review sheets and quarter-speed walk loops.

Only the hash-bound V20 staging tree and V20 source authorities are read.  All
outputs land under ``PreRendered3DV20/QA``; runtime art is never modified.
"""

from __future__ import annotations

import argparse
import math
from pathlib import Path
import sys
from typing import Any, Mapping, Sequence

import numpy as np
from PIL import Image, ImageDraw, ImageFont


PROCESSING_DIR = Path(__file__).resolve().parent
if str(PROCESSING_DIR) not in sys.path:
    sys.path.insert(0, str(PROCESSING_DIR))

import install_voss_v20 as v20  # noqa: E402


ROOT = v20.ROOT
V20_ROOT = v20.V20_ROOT
ACTOR_NODE = (180, 180)
PAPERDOLL_DISPLAY = (220, 315)
BG_DARK = (24, 28, 31, 255)
BG_COOL = (38, 48, 58, 255)

GATE2_LABELLED_FILENAME = "qa_v20_gate2_16_facings_labelled.png"
GATE2_UNLABELLED_FILENAME = "qa_v20_gate2_16_facings_unlabelled.png"

OFFICE = ROOT / "ArtSource/References/UI/Map/office_runtime_clean_v02.png"
CITY_GROUND = (
    ROOT
    / "RainShadow Shared/Resources/Art/Areas/CityDistrict/V2/city_harborpoint_pd_ground_v02.png"
)
CITY_BLOCK = (
    ROOT
    / "RainShadow Shared/Resources/Art/Areas/CityDistrict/V2/city_harborpoint_pd_block_v02.png"
)
OFFICE_CHAIR = (
    ROOT / "RainShadow Shared/Resources/Art/Props/Office/office_desk_chair.png"
)


def font() -> ImageFont.ImageFont:
    return ImageFont.load_default()


def label(
    draw: ImageDraw.ImageDraw,
    xy: tuple[int, int],
    text: str,
    fill: tuple[int, int, int, int] = (230, 226, 216, 255),
) -> None:
    draw.text(xy, text, fill=fill, font=font())


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def crop_subject(image: Image.Image, pad: int = 4) -> Image.Image:
    alpha = np.asarray(image.convert("RGBA"))[..., 3]
    mask = alpha >= 16
    if mask.shape == (512, 512):
        mask = v20.visible_mask(image)
    ys, xs = np.where(mask)
    if not len(xs):
        return Image.new("RGBA", (1, 1), (0, 0, 0, 0))
    return image.crop(
        (
            max(0, int(xs.min()) - pad),
            max(0, int(ys.min()) - pad),
            min(image.width, int(xs.max()) + 1 + pad),
            min(image.height, int(ys.max()) + 1 + pad),
        )
    )


def fit_subject(
    image: Image.Image,
    size: tuple[int, int],
    *,
    resample: Image.Resampling = Image.Resampling.NEAREST,
) -> Image.Image:
    subject = crop_subject(image)
    scale = min(size[0] / subject.width, size[1] / subject.height)
    resized = subject.resize(
        (max(1, round(subject.width * scale)), max(1, round(subject.height * scale))),
        resample,
    )
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.alpha_composite(resized, ((size[0] - resized.width) // 2, size[1] - resized.height))
    return canvas


def checker(size: tuple[int, int], square: int = 16) -> Image.Image:
    yy, xx = np.indices((size[1], size[0]))
    alternate = ((xx // square + yy // square) % 2)[..., None]
    first = np.asarray((48, 52, 57, 255), dtype=np.uint8)
    second = np.asarray((67, 71, 75, 255), dtype=np.uint8)
    return Image.fromarray(np.where(alternate, first, second).astype(np.uint8), "RGBA")


def tile(
    image: Image.Image,
    title: str,
    size: tuple[int, int] = (220, 300),
    *,
    smooth: bool = False,
) -> Image.Image:
    canvas = checker(size)
    content = fit_subject(
        image,
        (size[0] - 20, size[1] - 42),
        resample=Image.Resampling.LANCZOS if smooth else Image.Resampling.NEAREST,
    )
    canvas.alpha_composite(content, (10, 26))
    label(ImageDraw.Draw(canvas), (7, 7), title)
    return canvas


def grid(
    images: Sequence[Image.Image],
    columns: int,
    *,
    gap: int = 6,
    background: tuple[int, int, int, int] = BG_DARK,
) -> Image.Image:
    if not images:
        return Image.new("RGBA", (1, 1), background)
    width = max(image.width for image in images)
    height = max(image.height for image in images)
    rows = math.ceil(len(images) / columns)
    sheet = Image.new(
        "RGBA",
        (columns * width + (columns - 1) * gap, rows * height + (rows - 1) * gap),
        background,
    )
    for index, image in enumerate(images):
        sheet.alpha_composite(
            image,
            ((index % columns) * (width + gap), (index // columns) * (height + gap)),
        )
    return sheet


def stage_cell(stage: Path, atlas: str, name: str) -> Image.Image:
    return load_rgba(stage / atlas / name)


def raw_master(manifest: dict[str, Any], group: str, direction: str, phase: int) -> Image.Image:
    spec = next(
        spec
        for spec in v20.master_specs(manifest)
        if spec.group == group and spec.direction == direction and spec.phase == phase
    )
    return v20.key_chroma(load_rgba(V20_ROOT / manifest["source_root"] / spec.filename))


def make_identity_shape_sheet(stage: Path, manifest: dict[str, Any], qa: Path) -> Path:
    anchors = {
        name: v20.key_chroma(load_rgba(V20_ROOT / relative))
        for name, relative in v20.ANCHOR_PATHS.items()
    }
    tiles = [
        tile(anchors["front"], "approved front anchor", smooth=True),
        tile(stage_cell(stage, "VossIdle.atlas", "voss_standing_idle_s_00.png"), "V14 front"),
        tile(anchors["profile_w"], "approved west profile", smooth=True),
        tile(stage_cell(stage, "VossIdle.atlas", "voss_standing_idle_w_00.png"), "V14 west"),
        tile(anchors["back"], "approved back anchor", smooth=True),
        tile(stage_cell(stage, "VossIdle.atlas", "voss_standing_idle_n_00.png"), "V14 rear"),
        tile(anchors["dimetric_sw"], "approved SW dimetric", smooth=True),
        tile(stage_cell(stage, "VossIdle.atlas", "voss_standing_idle_sw_00.png"), "V14 SW"),
    ]
    path = qa / "qa_v20_front_profile_back_identity_shape.png"
    grid(tiles, 4).convert("RGB").save(path, optimize=True)
    return path


def displayed_facings_from_western(
    western: Mapping[str, Image.Image],
) -> list[tuple[str, Image.Image]]:
    """Expand nine authored western keys to the stable 16-facing review order.

    Every eastern presentation is a pixel-exact in-memory mirror of its western
    authority. No generated or processed key is rewritten.
    """
    missing = set(v20.WESTERN_DIRECTIONS) - set(western)
    if missing:
        raise v20.V20ValidationError(
            "Gate 2 is missing processed idle phase-00 keys: " + ", ".join(sorted(missing))
        )
    return [
        ("s", western["s"]),
        ("sse", western["ssw"].transpose(Image.Transpose.FLIP_LEFT_RIGHT)),
        ("se", western["sw"].transpose(Image.Transpose.FLIP_LEFT_RIGHT)),
        ("ese", western["wsw"].transpose(Image.Transpose.FLIP_LEFT_RIGHT)),
        ("e", western["w"].transpose(Image.Transpose.FLIP_LEFT_RIGHT)),
        ("ene", western["wnw"].transpose(Image.Transpose.FLIP_LEFT_RIGHT)),
        ("ne", western["nw"].transpose(Image.Transpose.FLIP_LEFT_RIGHT)),
        ("nne", western["nnw"].transpose(Image.Transpose.FLIP_LEFT_RIGHT)),
        ("n", western["n"]),
        ("nnw", western["nnw"]),
        ("nw", western["nw"]),
        ("wnw", western["wnw"]),
        ("w", western["w"]),
        ("wsw", western["wsw"]),
        ("sw", western["sw"]),
        ("ssw", western["ssw"]),
    ]


def displayed_facings(stage: Path) -> list[tuple[str, Image.Image]]:
    western = {
        direction: stage_cell(
            stage, "VossIdle.atlas", f"voss_standing_idle_{direction}_00.png"
        )
        for direction in v20.WESTERN_DIRECTIONS
    }
    return displayed_facings_from_western(western)


def _write_facing_sheets(
    facings: Sequence[tuple[str, Image.Image]],
    qa: Path,
    *,
    labelled_filename: str,
    unlabelled_filename: str,
) -> list[Path]:
    unlabeled: list[Image.Image] = []
    labeled: list[Image.Image] = []
    for name, image in facings:
        body = fit_subject(image, (116, 150))
        blank = checker((128, 162), square=12)
        blank.alpha_composite(body, (6, 6))
        unlabeled.append(blank)
        titled = blank.copy()
        label(ImageDraw.Draw(titled), (5, 4), name.upper())
        labeled.append(titled)
    paths = [
        qa / unlabelled_filename,
        qa / labelled_filename,
    ]
    qa.mkdir(parents=True, exist_ok=True)
    grid(unlabeled, 8).convert("RGB").save(paths[0], optimize=True)
    grid(labeled, 8).convert("RGB").save(paths[1], optimize=True)
    return paths


def make_facing_sheets(stage: Path, qa: Path) -> list[Path]:
    return _write_facing_sheets(
        displayed_facings(stage),
        qa,
        labelled_filename="qa_v20_16_facings_labelled.png",
        unlabelled_filename="qa_v20_16_facings_unlabelled.png",
    )


def load_gate2_processed_keys(
    manifest: dict[str, Any], *, keys_root: Path | None = None
) -> dict[str, Image.Image]:
    """Validate and V14-process the nine Gate 2 chroma keys without writing them."""
    root = keys_root or (V20_ROOT / "Keys")
    processed: dict[str, Image.Image] = {}
    errors: list[str] = []
    for direction in v20.WESTERN_DIRECTIONS:
        filename = f"voss_key_{direction}_chroma_v20.png"
        path = root / filename
        if not path.is_file():
            errors.append(f"missing Gate 2 key {path}")
            continue
        image_errors, keyed = v20._source_chroma_errors(path, manifest)
        errors.extend(image_errors)
        alias = manifest["key_aliases"][f"Keys/{filename}"]
        declared = manifest["master_inventory"][alias].get("sha256")
        if declared is not None and v20.sha256(path) != declared:
            errors.append(f"{filename}: bytes differ from its idle phase-00 inventory hash")
        if keyed is not None:
            processed[direction] = v20.process_keyed_figure(keyed)
    if errors:
        raise v20.V20ValidationError(errors)
    return processed


def make_gate2_facing_sheets(
    manifest: dict[str, Any],
    *,
    qa: Path | None = None,
    keys_root: Path | None = None,
) -> list[Path]:
    """Write only the Gate 2 labelled/unlabelled 16-facing proof sheets."""
    western = load_gate2_processed_keys(manifest, keys_root=keys_root)
    return _write_facing_sheets(
        displayed_facings_from_western(western),
        qa or (V20_ROOT / manifest["qa_root"]),
        labelled_filename=GATE2_LABELLED_FILENAME,
        unlabelled_filename=GATE2_UNLABELLED_FILENAME,
    )


def make_raw_processed_walk_proof(
    stage: Path, manifest: dict[str, Any], qa: Path, direction: str
) -> Path:
    tiles: list[Image.Image] = []
    for phase in range(8):
        tiles.append(tile(raw_master(manifest, "walk", direction, phase), f"raw {phase:02d}", smooth=True))
    for phase in range(8):
        tiles.append(
            tile(
                stage_cell(stage, "VossWalk.atlas", f"voss_walk_{direction}_{phase:02d}.png"),
                f"V14 {phase:02d}",
            )
        )
    path = qa / f"qa_v20_{direction}_raw_processed_walk_proof.png"
    grid(tiles, 8).convert("RGB").save(path, optimize=True)
    return path


def make_seat_transition_strips(stage: Path, qa: Path) -> list[Path]:
    paths: list[Path] = []
    for direction in v20.SEAT_DIRECTIONS:
        tiles = [
            tile(
                stage_cell(
                    stage,
                    "VossSeatTransitions.atlas",
                    f"voss_stand_up_{direction}_{phase:02d}.png",
                ),
                f"{direction.upper()} {phase:02d}",
                size=(140, 220),
            )
            for phase in range(12)
        ]
        path = qa / f"qa_v20_stand_up_{direction}_strip.png"
        grid(tiles, 12).convert("RGB").save(path, optimize=True)
        paths.append(path)
    return paths


def make_inventory_preview(stage: Path, manifest: dict[str, Any], qa: Path) -> Path:
    paper_path = V20_ROOT / manifest["ui_root"] / v20.PAPERDOLL_RELATIVE.name
    paper = load_rgba(paper_path).resize(PAPERDOLL_DISPLAY, Image.Resampling.LANCZOS)
    actor = stage_cell(stage, "VossIdle.atlas", "voss_standing_idle_s_00.png").resize(
        ACTOR_NODE, Image.Resampling.NEAREST
    )
    canvas = checker((520, 370), square=18)
    canvas.alpha_composite(paper, (24, 38))
    canvas.alpha_composite(actor, (310, 102))
    draw = ImageDraw.Draw(canvas)
    label(draw, (24, 14), "paperdoll: exact 220 x 315 display")
    label(draw, (310, 78), "actor: exact 180 x 180 node")
    path = qa / "qa_v20_inventory_220x315_vs_actor_180x180.png"
    canvas.convert("RGB").save(path, optimize=True)
    return path


def _fit_background(path: Path, size: tuple[int, int] = (960, 600)) -> Image.Image:
    if not path.is_file():
        return Image.new("RGBA", size, BG_DARK)
    image = load_rgba(path)
    scale = max(size[0] / image.width, size[1] / image.height)
    image = image.resize(
        (max(1, round(image.width * scale)), max(1, round(image.height * scale))),
        Image.Resampling.LANCZOS,
    )
    left = max(0, (image.width - size[0]) // 2)
    top = max(0, (image.height - size[1]) // 2)
    return image.crop((left, top, left + size[0], top + size[1]))


def _actor_at_root(background: Image.Image, actor: Image.Image, root: tuple[int, int]) -> Image.Image:
    out = background.copy()
    actor = actor.resize(ACTOR_NODE, Image.Resampling.NEAREST)
    ImageDraw.Draw(out, "RGBA").ellipse(
        (root[0] - 20, root[1] - 5, root[0] + 20, root[1] + 5), fill=(0, 0, 0, 74)
    )
    top_left = (root[0] - ACTOR_NODE[0] // 2, root[1] - round(433 / 512 * ACTOR_NODE[1]))
    out.alpha_composite(actor, top_left)
    return out


def make_world_previews(stage: Path, qa: Path) -> list[Path]:
    actor = stage_cell(stage, "VossIdle.atlas", "voss_standing_idle_sw_00.png")
    office = _actor_at_root(_fit_background(OFFICE), actor, (520, 420))
    city = _fit_background(CITY_GROUND)
    if CITY_BLOCK.is_file():
        city.alpha_composite(_fit_background(CITY_BLOCK))
    city = _actor_at_root(city, actor, (500, 410))
    label(ImageDraw.Draw(office), (12, 12), "warm office / exact 180x180 actor")
    label(ImageDraw.Draw(city), (12, 12), "cool city / exact 180x180 actor")
    paths = [qa / "qa_v20_office_actor_180x180.png", qa / "qa_v20_city_actor_180x180.png"]
    office.convert("RGB").save(paths[0], optimize=True)
    city.convert("RGB").save(paths[1], optimize=True)

    seated = stage_cell(stage, "VossSeatedIdle.atlas", "voss_seated_idle_ne_00.png")
    desk_background = _fit_background(OFFICE)
    if OFFICE_CHAIR.is_file():
        chair = load_rgba(OFFICE_CHAIR)
        chair = chair.resize(
            (max(1, round(chair.width * .135)), max(1, round(chair.height * .135))),
            Image.Resampling.NEAREST,
        )
        desk_background.alpha_composite(
            chair,
            (520 - chair.width // 2, 420 - round(chair.height * .96)),
        )
    desk = _actor_at_root(desk_background, seated, (520, 420))
    label(ImageDraw.Draw(desk), (12, 12), "desk check: one world-owned chair; no chair in Voss")
    desk_path = qa / "qa_v20_seated_one_world_chair.png"
    desk.convert("RGB").save(desk_path, optimize=True)
    paths.append(desk_path)
    return paths


def make_walk_gifs(
    stage: Path,
    qa: Path,
    directions: Sequence[str] = v20.WESTERN_DIRECTIONS,
) -> list[Path]:
    paths: list[Path] = []
    for direction in directions:
        frames: list[Image.Image] = []
        for phase in range(8):
            actor = stage_cell(
                stage, "VossWalk.atlas", f"voss_walk_{direction}_{phase:02d}.png"
            ).resize(ACTOR_NODE, Image.Resampling.NEAREST)
            background = Image.new("RGBA", (220, 200), BG_COOL)
            ImageDraw.Draw(background, "RGBA").ellipse((88, 171, 132, 181), fill=(0, 0, 0, 76))
            background.alpha_composite(actor, (20, 20))
            frames.append(background.convert("RGB"))
        path = qa / f"qa_v20_walk_{direction}_quarter_speed.gif"
        frames[0].save(
            path,
            save_all=True,
            append_images=frames[1:],
            duration=360,
            loop=0,
            disposal=2,
        )
        paths.append(path)
    return paths


def make_gate3_walk_proofs(
    manifest: dict[str, Any],
    *,
    stage: Path,
    qa: Path | None = None,
) -> list[Path]:
    """Write only the early SW/N Gate 3 strips and quarter-speed loops."""
    output_root = qa or (V20_ROOT / manifest["qa_root"])
    output_root.mkdir(parents=True, exist_ok=True)
    paths = [
        make_raw_processed_walk_proof(stage, manifest, output_root, direction)
        for direction in ("sw", "n")
    ]
    paths.extend(make_walk_gifs(stage, output_root, ("sw", "n")))
    return paths


def generate(stage: Path, manifest: dict[str, Any]) -> dict[str, Any]:
    gate_report = v20.validate_staging(stage, manifest)
    qa = V20_ROOT / manifest["qa_root"]
    qa.mkdir(parents=True, exist_ok=True)
    outputs: list[Path] = []
    outputs.append(make_identity_shape_sheet(stage, manifest, qa))
    outputs.extend(make_facing_sheets(stage, qa))
    outputs.append(make_raw_processed_walk_proof(stage, manifest, qa, "sw"))
    outputs.append(make_raw_processed_walk_proof(stage, manifest, qa, "n"))
    outputs.extend(make_walk_gifs(stage, qa))
    outputs.extend(make_seat_transition_strips(stage, qa))
    outputs.append(make_inventory_preview(stage, manifest, qa))
    outputs.extend(make_world_previews(stage, qa))
    output_hashes = {str(path.relative_to(V20_ROOT)): v20.sha256(path) for path in outputs}
    expected = set(manifest["approval_requirements"]["install_qa_outputs"])
    if set(output_hashes) != expected:
        raise v20.V20ValidationError("generated QA files differ from approval_requirements.install_qa_outputs")
    report = {
        "asset_version": "v20",
        "status": "passed",
        "strict_no_waivers": True,
        "staging": str(stage.relative_to(ROOT)),
        "stage_report_sha256": v20.sha256(stage / v20.STAGE_REPORT_NAME),
        "gate_summary": {
            "runtime_pngs": gate_report["counts"]["runtime_pngs"],
            "strict_no_waivers": gate_report["strict_no_waivers"],
        },
        "output_hashes": output_hashes,
        "manual_acceptance": {
            "facings": "Recognize at least 12 of 16 before consulting labels.",
            "motion": "Approve SW/N proofs and every 0.25x loop for gait, identity, and closure.",
            "rear": "Approve all rear facings as away-facing with no front garment/face leakage.",
            "seat": "Approve NE before SE and confirm exactly one world-owned chair.",
            "scale": "Approve paperdoll, exact 180x180 actors, and warm/cool scene read.",
        },
    }
    v20.write_json(qa / v20.QA_REPORT_NAME, report)
    return report


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--gate2-facing-sheets",
        action="store_true",
        help="write only the early nine-key Gate 2 facing sheets; no complete stage required",
    )
    parser.add_argument(
        "--gate3-walk-proofs",
        action="store_true",
        help="write only the early SW/N Gate 3 strips and quarter-speed loops",
    )
    parser.add_argument(
        "--keys-root",
        type=Path,
        default=None,
        help="alternate directory containing nine voss_key_*_chroma_v20.png inputs",
    )
    parser.add_argument(
        "--qa-root",
        type=Path,
        default=None,
        help="alternate QA output directory (primarily for Gate 2 review/tests)",
    )
    parser.add_argument(
        "--staging",
        type=Path,
        default=None,
        help="alternate V20 staging root (default: manifest staging_root)",
    )
    args = parser.parse_args(argv)
    try:
        manifest = v20.load_manifest()
        if args.gate2_facing_sheets:
            paths = make_gate2_facing_sheets(
                manifest,
                qa=args.qa_root,
                keys_root=args.keys_root,
            )
            print(
                "V20 Gate 2 facing QA written: "
                + ", ".join(str(path.relative_to(ROOT)) if path.is_relative_to(ROOT) else str(path) for path in paths)
            )
            return 0
        stage = args.staging or (V20_ROOT / manifest["staging_root"])
        if args.gate3_walk_proofs:
            if args.keys_root is not None:
                parser.error("--keys-root requires --gate2-facing-sheets")
            paths = make_gate3_walk_proofs(manifest, stage=stage, qa=args.qa_root)
            print(
                "V20 Gate 3 walk QA written: "
                + ", ".join(str(path.relative_to(ROOT)) if path.is_relative_to(ROOT) else str(path) for path in paths)
            )
            return 0
        if args.keys_root is not None or args.qa_root is not None:
            parser.error("--keys-root/--qa-root require an early-gate QA mode")
        report = generate(stage, manifest)
    except v20.V20ValidationError as error:
        v20._print_validation_error(error)
        return 1
    print(
        f"V20 QA passed: {len(report['output_hashes'])} hash-bound review files under "
        f"{(V20_ROOT / manifest['qa_root']).relative_to(ROOT)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

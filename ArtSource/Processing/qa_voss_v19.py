#!/usr/bin/env python3
"""Generate V19 gate reports, contact sheets, previews, and 0.25x walk GIFs.

Every output lands under ``PreRendered3DV19/QA``.  Runtime atlases are never read
or written: this script reviews only the gated V19 staging tree and immutable
paperdoll/world references.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import sys
from typing import Any, Sequence

import numpy as np
from PIL import Image, ImageDraw, ImageFont


PROCESSING_DIR = Path(__file__).resolve().parent
if str(PROCESSING_DIR) not in sys.path:
    sys.path.insert(0, str(PROCESSING_DIR))

import install_voss_v19 as v19  # noqa: E402


ROOT = v19.ROOT
V19_ROOT = v19.V19_ROOT
PAPERDOLL = V19_ROOT / "UI/voss_paperdoll_front_rgba_v01.png"
PORTRAIT = V19_ROOT / "UI/dialogue_portrait_harlan_voss_v01.png"
OFFICE = ROOT / "ArtSource/References/UI/Map/office_runtime_clean_v02.png"
CITY_GROUND = (
    ROOT
    / "RainShadow Shared/Resources/Art/Areas/CityDistrict/V2/city_harborpoint_pd_ground_v02.png"
)
CITY_BLOCK = (
    ROOT
    / "RainShadow Shared/Resources/Art/Areas/CityDistrict/V2/city_harborpoint_pd_block_v02.png"
)

ACTOR_NODE = (180, 180)
PAPERDOLL_DISPLAY = (220, 315)
BG_DARK = (24, 28, 31, 255)
BG_WARM = (77, 61, 45, 255)
BG_COOL = (38, 48, 58, 255)


def font() -> ImageFont.ImageFont:
    return ImageFont.load_default()


def label(draw: ImageDraw.ImageDraw, xy: tuple[int, int], text: str, fill=(230, 226, 216, 255)) -> None:
    draw.text(xy, text, fill=fill, font=font())


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def crop_subject(image: Image.Image, pad: int = 4) -> Image.Image:
    mask = v19.visible_mask(image)
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


def fit_subject(image: Image.Image, size: tuple[int, int], *, resample=Image.Resampling.NEAREST) -> Image.Image:
    subject = crop_subject(image)
    scale = min(size[0] / subject.width, size[1] / subject.height)
    resized = subject.resize(
        (max(1, round(subject.width * scale)), max(1, round(subject.height * scale))),
        resample,
    )
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.alpha_composite(
        resized,
        ((size[0] - resized.width) // 2, size[1] - resized.height),
    )
    return canvas


def checker(size: tuple[int, int], square: int = 16) -> Image.Image:
    yy, xx = np.indices((size[1], size[0]))
    alternate = ((xx // square + yy // square) % 2)[..., None]
    first = np.asarray((48, 52, 57, 255), dtype=np.uint8)
    second = np.asarray((67, 71, 75, 255), dtype=np.uint8)
    pixels = np.where(alternate, first, second).astype(np.uint8)
    return Image.fromarray(pixels, "RGBA")


def tile(image: Image.Image, title: str, size=(250, 330), *, smooth: bool = False) -> Image.Image:
    canvas = checker(size)
    content = fit_subject(
        image,
        (size[0] - 24, size[1] - 44),
        resample=Image.Resampling.LANCZOS if smooth else Image.Resampling.NEAREST,
    )
    canvas.alpha_composite(content, (12, 26))
    label(ImageDraw.Draw(canvas), (8, 7), title)
    return canvas


def grid(images: Sequence[Image.Image], columns: int, *, gap: int = 6, background=BG_DARK) -> Image.Image:
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
        x = (index % columns) * (width + gap)
        y = (index // columns) * (height + gap)
        sheet.alpha_composite(image, (x, y))
    return sheet


def stage_cell(stage: Path, atlas: str, name: str) -> Image.Image:
    return load_rgba(stage / atlas / name)


def make_identity_shape_sheet(stage: Path, manifest: dict[str, Any], qa: Path) -> Path:
    anchor_root = V19_ROOT / manifest["anchors_root"]
    front_anchor = v19.key_chroma(load_rgba(anchor_root / "voss_anchor_front_chroma_v19.png"))
    profile_anchor = v19.key_chroma(load_rgba(anchor_root / "voss_anchor_profile_w_chroma_v19.png"))
    back_anchor = v19.key_chroma(load_rgba(anchor_root / "voss_anchor_back_chroma_v19.png"))
    front_cell = stage_cell(stage, "VossIdle.atlas", "voss_standing_idle_s_00.png")
    profile_cell = stage_cell(stage, "VossIdle.atlas", "voss_standing_idle_w_00.png")
    back_cell = stage_cell(stage, "VossIdle.atlas", "voss_standing_idle_n_00.png")
    tiles = [
        tile(front_anchor, "approved front anchor", smooth=True),
        tile(front_cell, "processed front / V14"),
        tile(profile_anchor, "approved west profile", smooth=True),
        tile(profile_cell, "processed west / V14"),
        tile(back_anchor, "approved back anchor", smooth=True),
        tile(back_cell, "processed rear / V14"),
    ]
    sheet = grid(tiles, 6)
    path = qa / "qa_v19_front_profile_back_identity_shape.png"
    sheet.convert("RGB").save(path, quality=96)
    return path


def displayed_facings(stage: Path) -> list[tuple[str, Image.Image]]:
    def idle(direction: str) -> Image.Image:
        return stage_cell(stage, "VossIdle.atlas", f"voss_standing_idle_{direction}_00.png")

    return [
        ("s", idle("s")),
        ("sse", idle("ssw").transpose(Image.Transpose.FLIP_LEFT_RIGHT)),
        ("se", idle("se")),
        ("ese", idle("wsw").transpose(Image.Transpose.FLIP_LEFT_RIGHT)),
        ("e", idle("w").transpose(Image.Transpose.FLIP_LEFT_RIGHT)),
        ("ene", idle("wnw").transpose(Image.Transpose.FLIP_LEFT_RIGHT)),
        ("ne", idle("nw").transpose(Image.Transpose.FLIP_LEFT_RIGHT)),
        ("nne", idle("nnw").transpose(Image.Transpose.FLIP_LEFT_RIGHT)),
        ("n", idle("n")),
        ("nnw", idle("nnw")),
        ("nw", idle("nw")),
        ("wnw", idle("wnw")),
        ("w", idle("w")),
        ("wsw", idle("wsw")),
        ("sw", idle("sw")),
        ("ssw", idle("ssw")),
    ]


def make_facing_sheets(stage: Path, qa: Path) -> list[Path]:
    facings = displayed_facings(stage)
    unlabeled_tiles = []
    labeled_tiles = []
    for name, image in facings:
        body = fit_subject(image, (116, 150))
        blank = checker((128, 162), square=12)
        blank.alpha_composite(body, (6, 6))
        unlabeled_tiles.append(blank)
        titled = blank.copy()
        label(ImageDraw.Draw(titled), (5, 4), name.upper())
        labeled_tiles.append(titled)
    paths = [
        qa / "qa_v19_16_facings_unlabelled.png",
        qa / "qa_v19_16_facings_labelled.png",
    ]
    grid(unlabeled_tiles, 8).convert("RGB").save(paths[0], optimize=True)
    grid(labeled_tiles, 8).convert("RGB").save(paths[1], optimize=True)

    keys = [
        tile(stage_cell(stage, "VossIdle.atlas", "voss_standing_idle_sw_00.png"), "authored SW"),
        tile(stage_cell(stage, "VossIdle.atlas", "voss_standing_idle_se_00.png"), "derived SE = exact SW mirror"),
        tile(stage_cell(stage, "VossIdle.atlas", "voss_standing_idle_nw_00.png"), "authored rear NW"),
    ]
    key_path = qa / "qa_v19_mirrored_se_authored_rear_nw.png"
    grid(keys, 3).convert("RGB").save(key_path, quality=96)
    paths.append(key_path)
    return paths


def make_sw_proof(stage: Path, qa: Path) -> Path:
    cells = [
        stage_cell(stage, "VossWalk.atlas", f"voss_walk_sw_{phase:02d}.png")
        for phase in range(8)
    ]
    tiles = [tile(cell, f"SW gait {phase:02d}", size=(180, 250)) for phase, cell in enumerate(cells)]
    path = qa / "qa_v19_sw_walk_proof.png"
    grid(tiles, 8).convert("RGB").save(path, quality=96)
    return path


def make_inventory_preview(stage: Path, qa: Path) -> Path:
    if not PAPERDOLL.is_file():
        raise v19.V19ValidationError(f"missing V19 paperdoll {PAPERDOLL}")
    paper = load_rgba(PAPERDOLL).resize(PAPERDOLL_DISPLAY, Image.Resampling.LANCZOS)
    actor = stage_cell(stage, "VossIdle.atlas", "voss_standing_idle_s_00.png").resize(
        ACTOR_NODE, Image.Resampling.NEAREST
    )
    canvas = checker((520, 370), square=18)
    canvas.alpha_composite(paper, (24, 38))
    canvas.alpha_composite(actor, (310, 102))
    draw = ImageDraw.Draw(canvas)
    label(draw, (24, 14), "inventory paperdoll: exact 220 x 315 display")
    label(draw, (310, 78), "game actor: exact 180 x 180 node")
    path = qa / "qa_v19_inventory_220x315_vs_actor_180x180.png"
    canvas.convert("RGB").save(path, optimize=True)
    return path


def make_dialogue_hud_preview(qa: Path) -> Path:
    if not PORTRAIT.is_file():
        raise v19.V19ValidationError(f"missing V19 portrait {PORTRAIT}")
    portrait = load_rgba(PORTRAIT)
    canvas = Image.new("RGBA", (760, 350), BG_COOL)
    dialogue = portrait.resize((280, 280), Image.Resampling.LANCZOS)
    hud = portrait.resize((128, 128), Image.Resampling.LANCZOS)
    canvas.alpha_composite(dialogue, (32, 42))
    canvas.alpha_composite(hud, (430, 104))
    draw = ImageDraw.Draw(canvas)
    label(draw, (32, 16), "dialogue crop / smooth 512 master")
    label(draw, (430, 78), "HUD portrait preview")
    path = qa / "qa_v19_dialogue_hud_preview.png"
    canvas.convert("RGB").save(path, quality=96)
    return path


def make_seat_transition_strips(stage: Path, qa: Path) -> list[Path]:
    paths: list[Path] = []
    for direction in v19.SEAT_DIRECTIONS:
        cells = [
            stage_cell(
                stage,
                "VossSeatTransitions.atlas",
                f"voss_stand_up_{direction}_{phase:02d}.png",
            )
            for phase in range(12)
        ]
        tiles = [tile(cell, f"{direction.upper()} {phase:02d}", size=(140, 220)) for phase, cell in enumerate(cells)]
        path = qa / f"qa_v19_stand_up_{direction}_strip.png"
        grid(tiles, 12).convert("RGB").save(path, quality=95)
        paths.append(path)
    return paths


def _fit_background(path: Path, size=(960, 600)) -> Image.Image:
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
    draw = ImageDraw.Draw(out, "RGBA")
    draw.ellipse((root[0] - 20, root[1] - 5, root[0] + 20, root[1] + 5), fill=(0, 0, 0, 74))
    # FOOT_Y 433 maps to row 152.23 on the 180px node.  This is the same root
    # registration as anchor (0.5, 40/256); the two differ only by sub-pixel trim.
    top_left = (root[0] - ACTOR_NODE[0] // 2, root[1] - round(433 / 512 * ACTOR_NODE[1]))
    out.alpha_composite(actor, top_left)
    return out


def make_world_previews(stage: Path, qa: Path) -> list[Path]:
    actor = stage_cell(stage, "VossIdle.atlas", "voss_standing_idle_sw_00.png")
    office = _actor_at_root(_fit_background(OFFICE), actor, (520, 420))
    city = _fit_background(CITY_GROUND)
    if CITY_BLOCK.is_file():
        block = _fit_background(CITY_BLOCK)
        city.alpha_composite(block)
    city = _actor_at_root(city, actor, (500, 410))
    for preview, title in ((office, "warm office / 180x180 actor"), (city, "cool city / 180x180 actor")):
        label(ImageDraw.Draw(preview), (12, 12), title)
    paths = [qa / "qa_v19_office_actor_180x180.png", qa / "qa_v19_city_actor_180x180.png"]
    office.convert("RGB").save(paths[0], quality=95)
    city.convert("RGB").save(paths[1], quality=95)

    # The reference office owns its chair.  Only the full seated body is added;
    # the compatibility arms atlas is transparent by contract.
    seated = stage_cell(stage, "VossSeatedIdle.atlas", "voss_seated_idle_ne_00.png")
    seat_preview = _actor_at_root(_fit_background(OFFICE), seated, (520, 420))
    label(ImageDraw.Draw(seat_preview), (12, 12), "seat check: one world chair; no chair in Voss body")
    seat_path = qa / "qa_v19_seated_one_world_chair.png"
    seat_preview.convert("RGB").save(seat_path, quality=95)
    paths.append(seat_path)
    return paths


def make_walk_gifs(stage: Path, qa: Path) -> list[Path]:
    output: list[Path] = []
    for direction in v19.WESTERN_DIRECTIONS:
        frames: list[Image.Image] = []
        for phase in range(8):
            cell = stage_cell(stage, "VossWalk.atlas", f"voss_walk_{direction}_{phase:02d}.png")
            actor = cell.resize(ACTOR_NODE, Image.Resampling.NEAREST)
            background = Image.new("RGBA", (220, 200), BG_COOL)
            draw = ImageDraw.Draw(background, "RGBA")
            draw.ellipse((88, 171, 132, 181), fill=(0, 0, 0, 76))
            background.alpha_composite(actor, (20, 20))
            frames.append(background.convert("RGB"))
        path = qa / f"qa_v19_walk_{direction}_quarter_speed.gif"
        # Standard review playback is 90ms/cell; four times that is 0.25x.
        frames[0].save(
            path,
            save_all=True,
            append_images=frames[1:],
            duration=360,
            loop=0,
            disposal=2,
        )
        output.append(path)
    return output


def generate(stage: Path, manifest: dict[str, Any], *, allow_failing_gates: bool) -> dict[str, Any]:
    qa = V19_ROOT / manifest["qa_root"]
    qa.mkdir(parents=True, exist_ok=True)
    gate_failures: list[str] = []
    try:
        gate_report = v19.validate_staging(stage, manifest)
    except v19.V19ValidationError as error:
        if not allow_failing_gates:
            raise
        gate_failures = error.errors
        gate_report = {"status": "failed", "errors": gate_failures}

    outputs: list[Path] = []
    outputs.append(make_identity_shape_sheet(stage, manifest, qa))
    outputs.extend(make_facing_sheets(stage, qa))
    outputs.append(make_sw_proof(stage, qa))
    outputs.append(make_inventory_preview(stage, qa))
    outputs.append(make_dialogue_hud_preview(qa))
    outputs.extend(make_seat_transition_strips(stage, qa))
    outputs.extend(make_world_previews(stage, qa))
    outputs.extend(make_walk_gifs(stage, qa))
    report = {
        "asset_version": "v19",
        "status": "failed" if gate_failures else "passed",
        "staging": str(stage.relative_to(ROOT)),
        "gate_report": gate_report,
        "outputs": [str(path.relative_to(ROOT)) for path in outputs],
        "manual_acceptance": {
            "facings": "recognize at least 12 of 16 cells before opening the labelled sheet",
            "motion": "review every 0.25x GIF for foot plant, identity pulse, and loop closure",
            "world_scale": "review both 180x180 previews over warm and cool backgrounds",
            "seat": "confirm exactly one visible world chair through the entire chain",
        },
    }
    v19.write_json(qa / "qa_v19_report.json", report)
    return report


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--staging",
        type=Path,
        default=None,
        help="alternate staged atlas root (default: manifest staging_root)",
    )
    parser.add_argument(
        "--allow-failing-gates",
        action="store_true",
        help="write diagnostic sheets for a complete but gate-failing stage",
    )
    args = parser.parse_args(argv)
    manifest = v19.load_manifest()
    stage = args.staging or (V19_ROOT / manifest["staging_root"])
    try:
        report = generate(stage, manifest, allow_failing_gates=args.allow_failing_gates)
    except v19.V19ValidationError as error:
        v19._print_validation_error(error)
        return 1
    print(
        f"V19 QA {report['status']}: {len(report['outputs'])} review files under "
        f"{(V19_ROOT / manifest['qa_root']).relative_to(ROOT)}"
    )
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())

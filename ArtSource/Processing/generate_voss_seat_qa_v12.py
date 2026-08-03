#!/usr/bin/env python3
"""Build deterministic Voss V12 seated/transition QA from runtime assets.

This script is intentionally presentation-only: it reads the final shipped atlas
cells and never rewrites, repairs, recolors, or resizes them in place.  Any
resampling used by a QA layout is nearest-neighbour.  It also enforces the exact
sit-down == reversed stand-up contract before writing any output.

Run after both V12 seat processors have installed their final NE and SE cells:

    python3 ArtSource/Processing/generate_voss_seat_qa_v12.py

Outputs are written beneath ``PreRendered3DV12``.  Existing V12 QA filenames are
preserved for SE and the established ``DeskNE`` variants are refreshed for NE.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Sequence

from PIL import Image, ImageDraw, ImageFont, UnidentifiedImageError


ROOT = Path(__file__).resolve().parents[2]
RUNTIME_ART = ROOT / "RainShadow Shared" / "Resources" / "Art"
ATLASES = RUNTIME_ART / "Atlases"
V12 = (
    ROOT
    / "ArtSource"
    / "Generated"
    / "Characters"
    / "Detective"
    / "PreRendered3DV12"
)
DESK_NE = V12 / "DeskNE"

PAPERDOLL = RUNTIME_ART / "UI" / "Inventory" / "voss_paperdoll_front_rgba_v01.png"
OFFICE_REFERENCE = (
    ROOT / "ArtSource" / "References" / "UI" / "Map" / "office_runtime_clean_v02.png"
)
WORLD_CHAIR = RUNTIME_ART / "Props" / "Office" / "office_desk_chair.png"

FRAME_SIZE = (512, 512)
ALPHA_THRESHOLD = 16
BACKGROUND = (24, 28, 31, 255)
PANEL_BACKGROUND = (31, 36, 40, 255)
INK = (232, 225, 207, 255)
MUTED_INK = (165, 174, 174, 255)
ACCENT_SE = (212, 157, 85, 255)
ACCENT_NE = (106, 178, 187, 255)

# DetectiveActorNode runtime presentation contract.
ACTOR_NODE_SIZE = (232, 232)
ACTOR_ANCHOR = (0.5, 40 / 256)
ACTOR_SCALE = 1.0
SEATED_LOCAL_Y = -82 + 16

# addDepthProp runtime presentation contract for office_desk_chair.
CHAIR_SCALE = 0.135
CHAIR_ANCHOR = (0.5, 0.04)

# Sample an open-floor area of the clean office reference that contains no desk
# or chair.  Each crop is an independent scene; the actor and exactly one
# overlaid world-chair instance are registered to a shared seat anchor.
OFFICE_CROP = (350, 520, 770, 880)
OFFICE_SEAT_ANCHOR = (210, 282)

FONT = ImageFont.load_default()


@dataclass(frozen=True)
class SpriteMetrics:
    left: int
    top: int
    right: int
    bottom: int

    @property
    def width(self) -> int:
        return self.right - self.left

    @property
    def height(self) -> int:
        return self.bottom - self.top

    @property
    def center_x(self) -> float:
        return (self.left + self.right - 1) / 2


@dataclass(frozen=True)
class DirectionSpec:
    slug: str
    title: str
    standing_slug: str
    output_dir: Path
    accent: tuple[int, int, int, int]

    @property
    def standing_note(self) -> str:
        if self.slug == "ne":
            return "mirrored-NW facing-aware handoff"
        return "SE facing-aware handoff"


@dataclass(frozen=True)
class DirectionAssets:
    spec: DirectionSpec
    seated_idle: tuple[Image.Image, ...]
    stand_up: tuple[Image.Image, ...]
    sit_down: tuple[Image.Image, ...]
    standing_idle: Image.Image


DIRECTIONS = (
    DirectionSpec("se", "Southeast", "se", V12, ACCENT_SE),
    DirectionSpec("ne", "Northeast", "nw", DESK_NE, ACCENT_NE),
)


def require_file(path: Path, purpose: str) -> Path:
    if not path.is_file():
        raise FileNotFoundError(f"Missing {purpose}: {path}")
    return path


def load_png(path: Path, purpose: str) -> Image.Image:
    require_file(path, purpose)
    try:
        with Image.open(path) as source:
            source.load()
            return source.convert("RGBA")
    except (OSError, UnidentifiedImageError) as error:
        raise RuntimeError(f"Could not read {purpose} at {path}: {error}") from error


def load_atlas_cell(atlas: str, filename: str) -> Image.Image:
    path = ATLASES / f"{atlas}.atlas" / filename
    cell = load_png(path, f"runtime atlas cell {atlas}/{filename}")
    if cell.size != FRAME_SIZE:
        raise ValueError(
            f"Runtime atlas cell must be {FRAME_SIZE[0]}x{FRAME_SIZE[1]}, "
            f"got {cell.size[0]}x{cell.size[1]}: {path}"
        )
    return cell


def visible_metrics(image: Image.Image) -> SpriteMetrics:
    alpha = image.getchannel("A").point(
        lambda value: 255 if value >= ALPHA_THRESHOLD else 0
    )
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError("QA input has no visible pixels above the alpha threshold")
    return SpriteMetrics(*bbox)


def load_direction(spec: DirectionSpec) -> DirectionAssets:
    seated = tuple(
        load_atlas_cell(
            "VossSeatedIdle", f"voss_seated_idle_{spec.slug}_{index:02d}.png"
        )
        for index in range(8)
    )
    stand = tuple(
        load_atlas_cell(
            "VossSeatTransitions", f"voss_stand_up_{spec.slug}_{index:02d}.png"
        )
        for index in range(12)
    )
    sit = tuple(
        load_atlas_cell(
            "VossSeatTransitions", f"voss_sit_down_{spec.slug}_{index:02d}.png"
        )
        for index in range(12)
    )
    standing = load_atlas_cell(
        "VossIdle", f"voss_standing_idle_{spec.standing_slug}_00.png"
    )

    for index, sit_cell in enumerate(sit):
        stand_index = 11 - index
        if sit_cell.tobytes() != stand[stand_index].tobytes():
            raise ValueError(
                f"{spec.title} sit-down is not an exact decoded-pixel reverse: "
                f"sit {index:02d} differs from stand {stand_index:02d}"
            )

    return DirectionAssets(spec, seated, stand, sit, standing)


def draw_text(
    draw: ImageDraw.ImageDraw,
    xy: tuple[int, int],
    text: str,
    fill: tuple[int, int, int, int] = INK,
) -> None:
    x, y = xy
    draw.text((x + 1, y + 1), text, font=FONT, fill=(0, 0, 0, 210))
    draw.text((x, y), text, font=FONT, fill=fill)


def frame_label(prefix: str, index: int, frame: Image.Image) -> str:
    metrics = visible_metrics(frame)
    return (
        f"{prefix} {index:02d}  h={metrics.height}px  "
        f"cx={metrics.center_x:.1f}"
    )


def make_contact_sheet(
    title: str,
    frames: Sequence[Image.Image],
    labels: Sequence[str],
    columns: int,
    accent: tuple[int, int, int, int],
) -> Image.Image:
    if len(frames) != len(labels):
        raise ValueError("Contact sheet frame and label counts differ")
    rows = (len(frames) + columns - 1) // columns
    title_height = 42
    label_height = 28
    row_gap = 10
    row_height = label_height + FRAME_SIZE[1]
    width = columns * FRAME_SIZE[0]
    height = title_height + rows * row_height + max(0, rows - 1) * row_gap
    sheet = Image.new("RGBA", (width, height), BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    draw.rectangle((0, 0, width, 3), fill=accent)
    draw_text(draw, (12, 13), title)

    for index, (frame, label) in enumerate(zip(frames, labels)):
        column = index % columns
        row = index // columns
        x = column * FRAME_SIZE[0]
        y = title_height + row * (row_height + row_gap)
        draw.rectangle((x, y, x + FRAME_SIZE[0] - 1, y + label_height - 1), fill=PANEL_BACKGROUND)
        draw_text(draw, (x + 8, y + 8), label, MUTED_INK)
        sheet.alpha_composite(frame, (x, y + label_height))
        draw.rectangle(
            (
                x,
                y + label_height,
                x + FRAME_SIZE[0] - 1,
                y + label_height + FRAME_SIZE[1] - 1,
            ),
            outline=(58, 65, 69, 255),
            width=1,
        )
    return sheet


def nearest_fit(image: Image.Image, box: tuple[int, int]) -> Image.Image:
    max_width, max_height = box
    scale = min(max_width / image.width, max_height / image.height)
    size = (
        max(1, round(image.width * scale)),
        max(1, round(image.height * scale)),
    )
    return image.resize(size, Image.Resampling.NEAREST)


def visible_crop(image: Image.Image, padding: int = 6) -> Image.Image:
    metrics = visible_metrics(image)
    box = (
        max(0, metrics.left - padding),
        max(0, metrics.top - padding),
        min(image.width, metrics.right + padding),
        min(image.height, metrics.bottom + padding),
    )
    return image.crop(box)


def make_paperdoll_comparison(
    title: str,
    paperdoll: Image.Image,
    entries: Sequence[tuple[str, Image.Image]],
    accent: tuple[int, int, int, int],
) -> Image.Image:
    panel_width = 320
    panel_height = 420
    title_height = 48
    total_entries = [("paperdoll identity", paperdoll), *entries]
    sheet = Image.new(
        "RGBA",
        (panel_width * len(total_entries), title_height + panel_height),
        BACKGROUND,
    )
    draw = ImageDraw.Draw(sheet)
    draw.rectangle((0, 0, sheet.width, 3), fill=accent)
    draw_text(draw, (12, 15), title)

    for index, (label, image) in enumerate(total_entries):
        x = index * panel_width
        draw.rectangle(
            (x + 4, title_height + 4, x + panel_width - 5, sheet.height - 5),
            fill=PANEL_BACKGROUND,
            outline=(58, 65, 69, 255),
            width=1,
        )
        crop = visible_crop(image, padding=8)
        rendered = nearest_fit(crop, (280, 348))
        render_x = x + (panel_width - rendered.width) // 2
        render_y = title_height + 18 + (348 - rendered.height)
        sheet.alpha_composite(rendered, (render_x, render_y))
        if image.size == FRAME_SIZE:
            metrics = visible_metrics(image)
            details = f"{label} | h={metrics.height}px"
        else:
            details = label
        draw_text(draw, (x + 12, sheet.height - 30), details, MUTED_INK)
    return sheet


def paste_anchored_nearest(
    canvas: Image.Image,
    image: Image.Image,
    size: tuple[int, int],
    anchor_position: tuple[int, int],
    normalized_anchor: tuple[float, float],
) -> tuple[int, int, int, int]:
    rendered = image.resize(size, Image.Resampling.NEAREST)
    anchor_x, anchor_y = anchor_position
    normalized_x, normalized_y = normalized_anchor
    left = round(anchor_x - normalized_x * size[0])
    top = round(anchor_y - (1 - normalized_y) * size[1])
    canvas.alpha_composite(rendered, (left, top))
    return (left, top, left + size[0], top + size[1])


def make_office_panel(
    office: Image.Image,
    chair: Image.Image,
    actor: Image.Image,
    label: str,
    accent: tuple[int, int, int, int],
) -> Image.Image:
    crop = office.crop(OFFICE_CROP).convert("RGBA")
    panel = Image.new("RGBA", (crop.width, crop.height + 48), BACKGROUND)
    panel.alpha_composite(crop, (0, 48))
    draw = ImageDraw.Draw(panel)
    draw.rectangle((0, 0, panel.width, 3), fill=accent)
    draw_text(draw, (10, 10), label)
    draw_text(
        draw,
        (10, 27),
        "232x232 actor node, scale 1; one separate world chair",
        MUTED_INK,
    )

    seat_anchor = (OFFICE_SEAT_ANCHOR[0], OFFICE_SEAT_ANCHOR[1] + 48)
    chair_size = (
        max(1, round(chair.width * CHAIR_SCALE)),
        max(1, round(chair.height * CHAIR_SCALE)),
    )
    paste_anchored_nearest(panel, chair, chair_size, seat_anchor, CHAIR_ANCHOR)
    node_rect = paste_anchored_nearest(
        panel,
        actor,
        ACTOR_NODE_SIZE,
        seat_anchor,
        ACTOR_ANCHOR,
    )
    draw.rectangle(node_rect, outline=accent, width=1)
    draw.line(
        (
            seat_anchor[0] - 5,
            seat_anchor[1],
            seat_anchor[0] + 5,
            seat_anchor[1],
        ),
        fill=accent,
        width=1,
    )
    draw.line(
        (
            seat_anchor[0],
            seat_anchor[1] - 5,
            seat_anchor[0],
            seat_anchor[1] + 5,
        ),
        fill=accent,
        width=1,
    )
    return panel


def make_real_size_office_sheet(
    assets: DirectionAssets,
    office: Image.Image,
    chair: Image.Image,
) -> Image.Image:
    key_poses = (
        ("seated idle 00", assets.seated_idle[0]),
        ("stand-up 00", assets.stand_up[0]),
        ("stand-up 03", assets.stand_up[3]),
        ("stand-up 07", assets.stand_up[7]),
        ("stand-up 11", assets.stand_up[11]),
        (assets.spec.standing_note, assets.standing_idle),
    )
    panels = [
        make_office_panel(office, chair, frame, label, assets.spec.accent)
        for label, frame in key_poses
    ]
    sheet = Image.new(
        "RGBA",
        (sum(panel.width for panel in panels), panels[0].height),
        BACKGROUND,
    )
    x = 0
    for panel in panels:
        sheet.alpha_composite(panel, (x, 0))
        x += panel.width
    return sheet


def save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=False, compress_level=9)
    print(f"wrote {path.relative_to(ROOT)}")


def write_direction_qa(
    assets: DirectionAssets,
    paperdoll: Image.Image,
    office: Image.Image,
    chair: Image.Image,
) -> None:
    spec = assets.spec
    idle_labels = [
        frame_label(f"{spec.slug.upper()} idle", index, frame)
        for index, frame in enumerate(assets.seated_idle)
    ]
    seated_sheet = make_contact_sheet(
        f"Voss V12 {spec.title} seated idle - final runtime cells",
        assets.seated_idle,
        idle_labels,
        columns=8,
        accent=spec.accent,
    )

    transition_frames = (*assets.stand_up, *assets.sit_down)
    transition_labels = [
        frame_label(f"{spec.slug.upper()} stand", index, frame)
        for index, frame in enumerate(assets.stand_up)
    ] + [
        frame_label(f"{spec.slug.upper()} sit", index, frame)
        for index, frame in enumerate(assets.sit_down)
    ]
    transition_sheet = make_contact_sheet(
        (
            f"Voss V12 {spec.title} seat transition - stand-up 00..11; "
            "sit-down is exact reverse"
        ),
        transition_frames,
        transition_labels,
        columns=6,
        accent=spec.accent,
    )

    idle_comparison = make_paperdoll_comparison(
        f"Voss V12 {spec.title} paperdoll vs seated-idle key poses",
        paperdoll,
        [
            (f"idle {index:02d}", assets.seated_idle[index])
            for index in (0, 2, 4, 6)
        ]
        + [(spec.standing_note, assets.standing_idle)],
        spec.accent,
    )
    transition_comparison = make_paperdoll_comparison(
        f"Voss V12 {spec.title} paperdoll vs stand-up key poses",
        paperdoll,
        [
            (f"stand {index:02d}", assets.stand_up[index])
            for index in (0, 3, 7, 11)
        ]
        + [(spec.standing_note, assets.standing_idle)],
        spec.accent,
    )
    office_sheet = make_real_size_office_sheet(assets, office, chair)

    if spec.slug == "se":
        paths = (
            (seated_sheet, V12 / "preview_seated_idle_v12.png"),
            (transition_sheet, V12 / "preview_seat_transitions_v12.png"),
            (idle_comparison, V12 / "qa_paperdoll_vs_seated_idle_v12.png"),
            (
                transition_comparison,
                V12 / "qa_paperdoll_vs_seat_transitions_v12.png",
            ),
            (office_sheet, V12 / "preview_voss_in_office_v12.png"),
        )
    else:
        paths = (
            (seated_sheet, DESK_NE / "preview_seated_idle_ne_v12.png"),
            (transition_sheet, DESK_NE / "preview_seat_transitions_ne_v12.png"),
            (
                idle_comparison,
                DESK_NE / "qa_paperdoll_vs_seated_idle_ne_v12.png",
            ),
            (
                transition_comparison,
                DESK_NE / "qa_paperdoll_vs_seat_transitions_ne_v12.png",
            ),
            (office_sheet, DESK_NE / "preview_voss_in_office_ne_v12.png"),
        )

    for image, path in paths:
        save_png(image, path)


def main() -> None:
    # Load and validate every required input before writing the first QA image.
    directions = tuple(load_direction(spec) for spec in DIRECTIONS)
    paperdoll = load_png(PAPERDOLL, "runtime Voss inventory paperdoll")
    office = load_png(OFFICE_REFERENCE, "clean office runtime reference")
    chair = load_png(WORLD_CHAIR, "separate runtime office desk chair")

    crop_left, crop_top, crop_right, crop_bottom = OFFICE_CROP
    if not (
        0 <= crop_left < crop_right <= office.width
        and 0 <= crop_top < crop_bottom <= office.height
    ):
        raise ValueError(
            f"Office QA crop {OFFICE_CROP} does not fit runtime reference {office.size}"
        )
    if ACTOR_SCALE != 1.0 or ACTOR_NODE_SIZE != (232, 232):
        raise AssertionError("Voss QA must preserve the fixed 232x232 node at scale 1")
    if SEATED_LOCAL_Y != -66:
        raise AssertionError("Voss/chair QA registration drifted from the runtime seat offset")

    for assets in directions:
        write_direction_qa(assets, paperdoll, office, chair)


if __name__ == "__main__":
    main()
